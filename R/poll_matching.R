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
  if (!is_blank(poll$poll_variant %||% NA_character_)) {
    parts <- c(
      parts,
      key_value(poll$poll_variant),
      key_value(poll$base_pollster_key),
      key_value(poll$base_data_source_key)
    )
  }
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
  parts <- c(
    key_value(poll$election_key),
    key_value(poll$pollster_key),
    key_value(poll$media_key),
    key_value(poll$sample_size),
    key_value(safe_date_chr(poll$publication_date))
  )
  if (!is_blank(poll$poll_variant %||% NA_character_)) {
    parts <- c(
      parts,
      key_value(poll$poll_variant),
      key_value(poll$base_pollster_key),
      key_value(poll$base_data_source_key)
    )
  }
  paste(parts, collapse = "__")
}

stable_poll_payload <- function(poll) {
  results <- poll$results %||% list()
  if (length(results) > 0) {
    keys <- vapply(results, function(x) x$party_key %||% "", character(1))
    results <- results[order(keys)]
  }
  payload <- list(
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
  if (!is_blank(poll$poll_variant %||% NA_character_)) {
    payload$poll_variant <- poll$poll_variant
    payload$base_pollster_key <- poll$base_pollster_key
    payload$base_data_source_key <- poll$base_data_source_key
  }
  payload
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

result_vote_shares <- function(results) {
  if (length(results) == 0) {
    return(numeric())
  }
  values <- stats::setNames(
    vapply(results, function(x) as.numeric(x$vote_share %||% NA_real_), numeric(1)),
    vapply(results, function(x) x$party_key %||% "", character(1))
  )
  values[!is.na(values) & nzchar(names(values))]
}

results_are_identical_subset <- function(a_results, b_results) {
  if (length(a_results) == 0 || length(b_results) == 0) {
    return(FALSE)
  }
  a <- result_vote_shares(a_results)
  b <- result_vote_shares(b_results)
  common <- intersect(names(a), names(b))
  if (length(common) < 3 || length(common) != min(length(a), length(b))) {
    return(FALSE)
  }
  all(abs(a[common] - b[common]) <= 1e-9)
}

candidate_score <- function(new_poll, existing_poll) {
  score <- 0
  reasons <- character()
  same_pollster <- identical(key_value(new_poll$pollster_key), key_value(existing_poll$pollster_key))
  same_media <- !is.na(new_poll$media_key) && identical(key_value(new_poll$media_key), key_value(existing_poll$media_key))
  publication_distance <- date_distance(new_poll$publication_date, existing_poll$publication_date)
  start_distance <- date_distance(new_poll$fieldwork_start, existing_poll$fieldwork_start)
  end_distance <- date_distance(new_poll$fieldwork_end, existing_poll$fieldwork_end)
  close_fieldwork <- max(start_distance, end_distance) <= 7

  if (identical(key_value(new_poll$election_key), key_value(existing_poll$election_key))) {
    score <- score + 0.15
    reasons <- c(reasons, "same_election")
  }
  if (same_pollster) {
    score <- score + 0.20
    reasons <- c(reasons, "same_pollster")
  }
  if (same_media) {
    score <- score + 0.10
    reasons <- c(reasons, "same_media")
  }
  if (!is.na(new_poll$sample_size) && !is.na(existing_poll$sample_size) &&
      identical(as.integer(new_poll$sample_size), as.integer(existing_poll$sample_size))) {
    score <- score + 0.05
    reasons <- c(reasons, "same_sample_size")
  }

  if (publication_distance == 0) {
    score <- score + 0.22
    reasons <- c(reasons, "same_publication_date")
  } else if (publication_distance <= 7) {
    score <- score + 0.10
    reasons <- c(reasons, "close_publication_date")
  }

  if (start_distance == 0 && end_distance == 0) {
    score <- score + 0.18
    reasons <- c(reasons, "same_fieldwork_dates")
  } else if (close_fieldwork) {
    score <- score + 0.10
    reasons <- c(reasons, "close_fieldwork_dates")
  }

  if (results_are_identical_subset(new_poll$results %||% list(), existing_poll$results %||% list())) {
    score <- score + 0.05
    reasons <- c(reasons, "identical_vote_results")
  }

  if (!same_pollster) {
    score <- min(score, 0.59)
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

score_existing_poll_candidates <- function(new_poll, existing_polls, min_confidence = 0.60, max_candidates = 5L) {
  if (is.null(existing_polls) || length(existing_polls) == 0 || nrow(existing_polls) == 0) {
    return(list())
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
  scored <- scored[vapply(scored, function(x) !is.na(x$poll_id) && x$confidence >= min_confidence, logical(1))]
  if (length(scored) == 0) {
    return(list())
  }

  confidences <- vapply(scored, function(x) x$confidence, numeric(1))
  poll_ids <- vapply(scored, function(x) x$poll_id, integer(1))
  scored <- scored[order(-confidences, poll_ids)]
  scored <- scored[seq_len(min(length(scored), as.integer(max_candidates)))]
  for (i in seq_along(scored)) {
    scored[[i]]$rank <- i
  }
  scored
}

match_existing_poll <- function(new_poll, existing_polls) {
  if (is.null(existing_polls) || length(existing_polls) == 0 || nrow(existing_polls) == 0) {
    return(list(
      poll_id = NA_integer_,
      match_type = "new_poll",
      confidence = 0,
      reasons = "no_existing_candidates",
      candidates = list()
    ))
  }

  exact_rows <- existing_polls[existing_polls$poll_key_strict == new_poll$poll_key_strict, , drop = FALSE]
  if (nrow(exact_rows) == 1) {
    exact_candidate <- list(list(
      poll_id = scalar_int(exact_rows$id),
      confidence = 1,
      reasons = c("same_poll_key_strict"),
      rank = 1L
    ))
    return(list(
      poll_id = scalar_int(exact_rows$id),
      match_type = "exact",
      confidence = 1,
      reasons = c("same_poll_key_strict"),
      candidates = exact_candidate
    ))
  }
  if (nrow(exact_rows) > 1) {
    exact_candidates <- lapply(seq_len(nrow(exact_rows)), function(i) {
      list(
        poll_id = scalar_int(exact_rows$id[[i]]),
        confidence = 1,
        reasons = c("same_poll_key_strict"),
        rank = i
      )
    })
    return(list(
      poll_id = NA_integer_,
      match_type = "manual_review",
      confidence = 0,
      reasons = c("duplicate_strict_key_candidates"),
      candidates = exact_candidates
    ))
  }

  scored <- score_existing_poll_candidates(new_poll, existing_polls, min_confidence = 0, max_candidates = nrow(existing_polls))
  confidences <- vapply(scored, function(x) x$confidence, numeric(1))
  if (length(confidences) == 0 || max(confidences) < 0.60) {
    return(list(
      poll_id = NA_integer_,
      match_type = "new_poll",
      confidence = 0,
      reasons = "no_probable_candidates",
      candidates = list()
    ))
  }

  order_idx <- order(confidences, decreasing = TRUE)
  best <- scored[[order_idx[[1]]]]
  second <- if (length(order_idx) >= 2) scored[[order_idx[[2]]]]$confidence else 0
  close_competitors <- sum(confidences >= 0.75 & (best$confidence - confidences) <= 0.05)
  candidates <- scored[order_idx]
  candidates <- candidates[vapply(candidates, function(x) x$confidence >= 0.60, logical(1))]
  candidates <- candidates[seq_len(min(length(candidates), 5L))]
  for (i in seq_along(candidates)) {
    candidates[[i]]$rank <- i
  }

  if (best$confidence >= 0.85 && close_competitors == 1 && (best$confidence - second) > 0.05) {
    return(list(
      poll_id = best$poll_id,
      match_type = "probable_match",
      confidence = best$confidence,
      reasons = best$reasons,
      candidates = candidates
    ))
  }

  list(
    poll_id = NA_integer_,
    match_type = "manual_review",
    confidence = best$confidence,
    reasons = unique(c("ambiguous_or_low_confidence", best$reasons)),
    candidates = candidates
  )
}
