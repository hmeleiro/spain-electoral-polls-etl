key_value <- function(x) {
  if (length(x) == 0 || is.null(x) || all(is.na(x)) || identical(x, "")) "na" else as.character(x)
}

generate_poll_key_strict <- function(poll) {
  parts <- c(
    key_value(poll$election_key),
    key_value(poll$pollster_key),
    key_value(poll$media_key),
    key_value(safe_date_chr(poll$fieldwork_start)),
    key_value(safe_date_chr(poll$fieldwork_end)),
    key_value(poll$sample_size)
  )
  key <- paste(parts, collapse = "__")
  if (any(parts %in% c("na", ""))) {
    suffix <- digest::digest(
      paste(key, key_value(poll$source_url), key_value(poll$year), key_value(poll$row_number), sep = "__"),
      algo = "xxhash32",
      serialize = FALSE
    )
    key <- paste(key, paste0("partial_", suffix), sep = "__")
  }
  key
}

generate_poll_signature <- function(poll) {
  paste(
    key_value(poll$election_key),
    key_value(poll$pollster_key),
    key_value(poll$media_key),
    key_value(poll$sample_size),
    key_value(safe_date_chr(poll$publication_date)),
    sep = "__"
  )
}

stable_poll_payload <- function(poll) {
  results <- poll$results %||% list()
  if (length(results) > 0) {
    keys <- vapply(results, function(x) x$party_key %||% "", character(1))
    results <- results[order(keys)]
  }
  list(
    election_key = poll$election_key,
    pollster_key = poll$pollster_key,
    pollster_raw = poll$pollster_raw,
    media_key = poll$media_key,
    media = poll$media,
    fieldwork_start = safe_date_chr(poll$fieldwork_start),
    fieldwork_end = safe_date_chr(poll$fieldwork_end),
    publication_date = safe_date_chr(poll$publication_date),
    sample_size = poll$sample_size,
    turnout = poll$turnout,
    lead = poll$lead,
    source_url = poll$source_url,
    source_title = poll$source_title,
    source_reference_ids = poll$source_reference_ids,
    source_metadata = poll$source_metadata,
    notes = poll$notes,
    results = results
  )
}

generate_row_hash <- function(poll) {
  digest::digest(as_json(stable_poll_payload(poll)), algo = "sha256", serialize = FALSE)
}

date_distance <- function(a, b) {
  if (length(a) == 0 || length(b) == 0 || is.na(a) || is.na(b)) {
    return(Inf)
  }
  abs(as.integer(as.Date(a) - as.Date(b)))
}

sample_close <- function(a, b) {
  if (is.na(a) || is.na(b)) {
    return(FALSE)
  }
  abs(as.numeric(a) - as.numeric(b)) <= max(50, 0.05 * max(as.numeric(a), as.numeric(b)))
}

results_are_similar <- function(a_results, b_results) {
  if (length(a_results) == 0 || length(b_results) == 0) {
    return(FALSE)
  }
  a <- stats::setNames(
    vapply(a_results, function(x) as.numeric(x$vote_share %||% NA_real_), numeric(1)),
    vapply(a_results, function(x) x$party_key %||% "", character(1))
  )
  b <- stats::setNames(
    vapply(b_results, function(x) as.numeric(x$vote_share %||% NA_real_), numeric(1)),
    vapply(b_results, function(x) x$party_key %||% "", character(1))
  )
  common <- intersect(names(a), names(b))
  common <- common[!is.na(a[common]) & !is.na(b[common])]
  if (length(common) < 3) {
    return(FALSE)
  }
  mean(abs(a[common] - b[common])) <= 1.25
}

candidate_score <- function(new_poll, existing_poll) {
  score <- 0
  reasons <- character()

  if (identical(key_value(new_poll$election_key), key_value(existing_poll$election_key))) {
    score <- score + 0.20
    reasons <- c(reasons, "same_election")
  }
  if (identical(key_value(new_poll$pollster_key), key_value(existing_poll$pollster_key))) {
    score <- score + 0.25
    reasons <- c(reasons, "same_pollster")
  }
  if (!is.na(new_poll$media_key) && identical(key_value(new_poll$media_key), key_value(existing_poll$media_key))) {
    score <- score + 0.15
    reasons <- c(reasons, "same_media")
  }
  if (!is.na(new_poll$sample_size) && !is.na(existing_poll$sample_size) &&
      identical(as.integer(new_poll$sample_size), as.integer(existing_poll$sample_size))) {
    score <- score + 0.15
    reasons <- c(reasons, "same_sample_size")
  } else if (sample_close(new_poll$sample_size, existing_poll$sample_size)) {
    score <- score + 0.08
    reasons <- c(reasons, "close_sample_size")
  }

  publication_distance <- date_distance(new_poll$publication_date, existing_poll$publication_date)
  if (publication_distance == 0) {
    score <- score + 0.15
    reasons <- c(reasons, "same_publication_date")
  } else if (publication_distance <= 7) {
    score <- score + 0.08
    reasons <- c(reasons, "close_publication_date")
  }

  start_distance <- date_distance(new_poll$fieldwork_start, existing_poll$fieldwork_start)
  end_distance <- date_distance(new_poll$fieldwork_end, existing_poll$fieldwork_end)
  if (start_distance == 0 && end_distance == 0) {
    score <- score + 0.10
    reasons <- c(reasons, "same_fieldwork_dates")
  } else if (max(start_distance, end_distance) <= 7) {
    score <- score + 0.05
    reasons <- c(reasons, "close_fieldwork_dates")
  }

  if (results_are_similar(new_poll$results %||% list(), existing_poll$results %||% list())) {
    score <- score + 0.05
    reasons <- c(reasons, "similar_vote_results")
  }

  list(score = min(score, 1), reasons = reasons)
}

row_to_poll_list <- function(row) {
  if (is.list(row) && is.null(dim(row))) {
    return(row)
  }
  out <- as.list(row)
  if (!is.null(out$results_json)) {
    out$results <- from_json_or_null(out$results_json) %||% list()
  }
  out
}

match_existing_poll <- function(new_poll, existing_polls) {
  if (is.null(existing_polls) || length(existing_polls) == 0 || nrow(existing_polls) == 0) {
    return(list(poll_id = NA_integer_, match_type = "new_poll", confidence = 0, reasons = "no_existing_candidates"))
  }

  exact_rows <- existing_polls[existing_polls$poll_key_strict == new_poll$poll_key_strict, , drop = FALSE]
  if (nrow(exact_rows) == 1) {
    return(list(
      poll_id = scalar_int(exact_rows$id),
      match_type = "exact",
      confidence = 1,
      reasons = c("same_poll_key_strict")
    ))
  }
  if (nrow(exact_rows) > 1) {
    return(list(
      poll_id = NA_integer_,
      match_type = "manual_review",
      confidence = 0,
      reasons = c("duplicate_strict_key_candidates")
    ))
  }

  scored <- lapply(seq_len(nrow(existing_polls)), function(i) {
    candidate <- row_to_poll_list(existing_polls[i, , drop = FALSE])
    score <- candidate_score(new_poll, candidate)
    list(
      poll_id = scalar_int(candidate$id),
      confidence = score$score,
      reasons = score$reasons
    )
  })
  confidences <- vapply(scored, function(x) x$confidence, numeric(1))
  if (length(confidences) == 0 || max(confidences) < 0.60) {
    return(list(poll_id = NA_integer_, match_type = "new_poll", confidence = 0, reasons = "no_probable_candidates"))
  }

  order_idx <- order(confidences, decreasing = TRUE)
  best <- scored[[order_idx[[1]]]]
  second <- if (length(order_idx) >= 2) scored[[order_idx[[2]]]]$confidence else 0
  close_competitors <- sum(confidences >= 0.75 & (best$confidence - confidences) <= 0.05)

  if (best$confidence >= 0.85 && close_competitors == 1 && (best$confidence - second) > 0.05) {
    return(list(
      poll_id = best$poll_id,
      match_type = "probable_match",
      confidence = best$confidence,
      reasons = best$reasons
    ))
  }

  list(
    poll_id = NA_integer_,
    match_type = "manual_review",
    confidence = best$confidence,
    reasons = unique(c("ambiguous_or_low_confidence", best$reasons))
  )
}
