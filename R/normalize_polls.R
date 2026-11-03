clean_wiki_text <- function(x) {
  x <- as.character(x %||% NA_character_)
  x <- gsub("\\[[^]]*\\]", "", x, perl = TRUE)
  x <- gsub("\u00a0", " ", x, fixed = TRUE)
  x <- gsub("[\r\n\t]+", " ", x)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

normalize_text <- function(x) {
  x <- clean_wiki_text(x)
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT")
  x <- tolower(x)
  x <- gsub("&", " and ", x, fixed = TRUE)
  x <- gsub("[^a-z0-9]+", " ", x)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

slug_key <- function(x, fallback = "unknown") {
  out <- normalize_text(x)
  out <- gsub("\\s+", "_", out)
  out <- gsub("^_+|_+$", "", out)
  ifelse(is.na(out) | out == "", fallback, out)
}

normalize_pollster <- function(x) {
  x <- clean_wiki_text(x)
  x <- gsub("\\s*\\([^)]*\\)\\s*", " ", x)
  x <- gsub("\\bS\\.?A\\.?\\b|\\bSL\\b|\\bS\\.L\\.\\b", "", x, ignore.case = TRUE)
  slug_key(x)
}

normalize_media <- function(x) {
  if (is_blank(x)) {
    return(NA_character_)
  }
  slug_key(x)
}

party_dictionary <- function() {
  c(
    "psoe" = "psoe",
    "spanish socialist workers party" = "psoe",
    "pp" = "pp",
    "people s party" = "pp",
    "vox" = "vox",
    "fa" = "fa",
    "broad front" = "fa",
    "frente amplio" = "fa",
    "fv" = "fv",
    "valencian front" = "fv",
    "front valencia" = "fv",
    "compromis front valencia" = "fv",
    "commitment valencian front" = "fv",
    "sumar" = "sumar",
    "podemos" = "podemos",
    "unidas podemos" = "podemos",
    "cs" = "cs",
    "ciudadanos" = "cs",
    "erc" = "erc",
    "erc sobiranistes" = "erc",
    "republican left of catalonia" = "erc",
    "junts" = "junts",
    "juntsxcat" = "junts",
    "adelante andalucia 2021" = "adelante_andalucia",
    "together for catalonia 2020" = "junts",
    "together for catalonia" = "junts",
    "eh bildu" = "eh_bildu",
    "bildu" = "eh_bildu",
    "eaj pnv" = "eaj_pnv",
    "pnv" = "eaj_pnv",
    "basque nationalist party" = "eaj_pnv",
    "bng" = "bng",
    "galician nationalist bloc" = "bng",
    "cup" = "cup",
    "cca" = "cca",
    "cc" = "cca",
    "cc nca" = "cca",
    "coalicion canaria" = "cca",
    "canarian coalition" = "cca",
    "upn" = "upn",
    "navarrese people s union" = "upn",
    "prc" = "prc",
    "ev" = "ev",
    "mas pais" = "mas_pais",
    "compromis" = "compromis",
    "jxcat" = "junts",
    "pacma" = "pacma",
    "others" = "others",
    "other" = "others",
    "otros" = "others"
  )
}

normalize_party <- function(x) {
  key <- normalize_text(x)
  dict <- party_dictionary()
  ifelse(key %in% names(dict), unname(dict[key]), slug_key(key))
}

is_missing_value <- function(x) {
  value <- clean_wiki_text(x)
  is.na(value) | value == "" | value %in% c("-", "\u2013", "\u2014", "?", "N/A", "n/a")
}

parse_percent <- function(x) {
  if (is_missing_value(x)) {
    return(NA_real_)
  }
  value <- clean_wiki_text(x)
  value <- gsub(",", ".", value)
  match <- regmatches(value, regexpr("\\d+(?:\\.\\d+)?", value, perl = TRUE))
  if (length(match) == 0 || match == "") {
    return(NA_real_)
  }
  as.numeric(match)
}

parse_sample_size <- function(x) {
  if (is_missing_value(x)) {
    return(NA_integer_)
  }
  value <- clean_wiki_text(x)
  value <- gsub("[^0-9]", "", value)
  if (value == "") {
    return(NA_integer_)
  }
  as.integer(value)
}

parse_result_cell <- function(x) {
  raw <- clean_wiki_text(x)
  if (is_missing_value(raw)) {
    return(list(vote_share = NA_real_, seats_min = NA_integer_, seats_max = NA_integer_, raw_value = raw))
  }

  lines <- strsplit(gsub("\r\n|\r", "\n", as.character(x)), "\n", fixed = FALSE)[[1]]
  lines <- clean_wiki_text(lines)
  lines <- lines[nzchar(lines)]
  if (length(lines) >= 2) {
    vote_share <- parse_percent(lines[[1]])
    seat_text <- paste(lines[-1], collapse = " ")
    seat_numbers <- regmatches(seat_text, gregexpr("\\d+", seat_text, perl = TRUE))[[1]]
    seats_min <- NA_integer_
    seats_max <- NA_integer_
    if (length(seat_numbers) >= 1) {
      seats_min <- as.integer(seat_numbers[[1]])
      seats_max <- seats_min
    }
    if (length(seat_numbers) >= 2) {
      seats_max <- as.integer(seat_numbers[[2]])
    }
    return(list(
      vote_share = vote_share,
      seats_min = seats_min,
      seats_max = seats_max,
      raw_value = paste(lines, collapse = "\n")
    ))
  }

  collapsed_match <- regexec("^(\\d{1,2}\\.\\d)(\\d{1,3})(?:/(\\d{1,3}))?$", raw, perl = TRUE)
  collapsed_parts <- regmatches(raw, collapsed_match)[[1]]
  if (length(collapsed_parts) >= 3) {
    seats_min <- as.integer(collapsed_parts[[3]])
    seats_max <- seats_min
    if (length(collapsed_parts) >= 4 && nzchar(collapsed_parts[[4]])) {
      seats_max <- as.integer(collapsed_parts[[4]])
    }
    seats_text <- if (identical(seats_min, seats_max)) as.character(seats_min) else paste(seats_min, seats_max, sep = "/")
    return(list(
      vote_share = as.numeric(collapsed_parts[[2]]),
      seats_min = seats_min,
      seats_max = seats_max,
      raw_value = paste(collapsed_parts[[2]], seats_text, sep = "\n")
    ))
  }

  numbers <- regmatches(raw, gregexpr("\\d+(?:\\.\\d+)?", raw, perl = TRUE))[[1]]
  if (length(numbers) == 0) {
    return(list(vote_share = NA_real_, seats_min = NA_integer_, seats_max = NA_integer_, raw_value = raw))
  }

  first_number <- as.numeric(numbers[[1]])
  if (!is.na(first_number) && first_number > 100) {
    vote_share <- NA_real_
    seat_numbers <- numbers
  } else {
    vote_share <- first_number
    seat_numbers <- numbers[-1]
  }
  seats_min <- NA_integer_
  seats_max <- NA_integer_
  if (length(seat_numbers) >= 1) {
    seats_min <- as.integer(as.numeric(seat_numbers[[1]]))
    seats_max <- seats_min
  }
  if (length(seat_numbers) >= 2) {
    seats_max <- as.integer(as.numeric(seat_numbers[[2]]))
  }

  list(
    vote_share = vote_share,
    seats_min = seats_min,
    seats_max = seats_max,
    raw_value = raw
  )
}

month_number <- function(x) {
  key <- substr(tolower(x), 1, 3)
  months <- c(
    jan = 1, feb = 2, mar = 3, apr = 4, may = 5, jun = 6,
    jul = 7, aug = 8, sep = 9, oct = 10, nov = 11, dec = 12
  )
  unname(months[key])
}

parse_date_part <- function(part, default_month = NA_integer_, default_year = NA_integer_) {
  part <- clean_wiki_text(part)
  tokens <- strsplit(part, "\\s+")[[1]]
  tokens <- tokens[nzchar(tokens)]
  if (length(tokens) == 0) {
    return(as.Date(NA))
  }

  day <- suppressWarnings(as.integer(gsub("[^0-9]", "", tokens[[1]])))
  month <- default_month
  year <- default_year

  if (length(tokens) >= 2 && !grepl("^\\d{4}$", tokens[[2]])) {
    parsed_month <- month_number(tokens[[2]])
    if (!is.na(parsed_month)) {
      month <- parsed_month
    }
  }

  year_tokens <- tokens[grepl("^\\d{4}$", tokens)]
  if (length(year_tokens) > 0) {
    year <- as.integer(year_tokens[[length(year_tokens)]])
  }

  if (is.na(day) || is.na(month) || is.na(year)) {
    return(as.Date(NA))
  }
  as.Date(sprintf("%04d-%02d-%02d", year, month, day))
}

parse_fieldwork_date <- function(x, year) {
  if (is_missing_value(x)) {
    return(list(start = as.Date(NA), end = as.Date(NA)))
  }

  value <- clean_wiki_text(x)
  value <- gsub("\u2013|\u2014|\u2212", "-", value)
  value <- gsub("\\s*-\\s*", "-", value)
  parts <- strsplit(value, "-", fixed = TRUE)[[1]]

  end_part <- parts[[length(parts)]]
  end_tokens <- strsplit(clean_wiki_text(end_part), "\\s+")[[1]]
  end_month <- NA_integer_
  if (length(end_tokens) >= 2) {
    end_month <- month_number(end_tokens[[2]])
  }
  end_date <- parse_date_part(end_part, default_month = end_month, default_year = as.integer(year))

  if (length(parts) == 1) {
    return(list(start = end_date, end = end_date))
  }

  start_part <- parts[[1]]
  start_tokens <- strsplit(clean_wiki_text(start_part), "\\s+")[[1]]
  start_month <- end_month
  if (length(start_tokens) >= 2) {
    parsed_start_month <- month_number(start_tokens[[2]])
    if (!is.na(parsed_start_month)) {
      start_month <- parsed_start_month
    }
  }

  start_year <- as.integer(year)
  if (!is.na(start_month) && !is.na(end_month) && start_month > end_month) {
    start_year <- start_year - 1L
  }
  start_date <- parse_date_part(start_part, default_month = start_month, default_year = start_year)
  list(start = start_date, end = end_date)
}

parse_publication_date <- function(x, fallback_year = NA_integer_) {
  if (is_blank(x)) {
    return(as.Date(NA))
  }
  value <- clean_wiki_text(x)
  parsed <- suppressWarnings(lubridate::ymd(value))
  if (is.na(parsed)) {
    parsed <- suppressWarnings(lubridate::dmy(value, locale = "C"))
  }
  if (is.na(parsed)) {
    parsed <- suppressWarnings(lubridate::mdy(value, locale = "C"))
  }
  if (is.na(parsed) && !is.na(fallback_year)) {
    parsed <- parse_date_part(value, default_year = fallback_year)
  }
  as.Date(parsed)
}

split_pollster_media <- function(x) {
  value <- clean_wiki_text(x)
  if (grepl("/", value, fixed = TRUE)) {
    parts <- strsplit(value, "/", fixed = TRUE)[[1]]
    return(list(pollster = trimws(parts[[1]]), media = trimws(paste(parts[-1], collapse = "/"))))
  }

  paren <- regmatches(value, regexpr("\\(([^)]*)\\)", value, perl = TRUE))
  if (length(paren) == 1 && nzchar(paren)) {
    media <- gsub("^\\(|\\)$", "", paren)
    pollster <- trimws(gsub("\\s*\\([^)]*\\)\\s*", " ", value))
    return(list(pollster = pollster, media = media))
  }

  list(pollster = value, media = NA_character_)
}

metadata_text <- function(metadata) {
  if (is.null(metadata) || length(metadata) == 0) {
    return("")
  }
  values <- unlist(metadata, use.names = FALSE)
  values <- values[!is.na(values)]
  paste(as.character(values), collapse = " ")
}

alternative_projection_base_key <- function(record) {
  note_text <- normalize_text(paste(
    record$notes %||% "",
    record$source_title %||% "",
    metadata_text(record$source_metadata %||% list()),
    collapse = " "
  ))
  match <- regexec("alternative projection based on raw ([a-z0-9 ]+) data", note_text, perl = TRUE)
  parts <- regmatches(note_text, match)[[1]]
  if (length(parts) < 2 || is_blank(parts[[2]])) {
    return(NA_character_)
  }
  slug_key(parts[[2]])
}

is_alternative_projection_reestimate <- function(record, pollster_media) {
  if (is_blank(pollster_media$media)) {
    return(FALSE)
  }
  base_key <- alternative_projection_base_key(record)
  !is.na(base_key) && identical(normalize_pollster(pollster_media$pollster), base_key)
}

apply_pollster_media_overrides <- function(record, pollster_media) {
  if (is_alternative_projection_reestimate(record, pollster_media)) {
    base_pollster <- clean_wiki_text(pollster_media$pollster)
    base_pollster_key <- normalize_pollster(base_pollster)
    estimator <- clean_wiki_text(pollster_media$media)
    return(list(
      pollster = estimator,
      media = base_pollster,
      estimate_type = "reestimate",
      base_pollster = base_pollster,
      base_pollster_key = base_pollster_key,
      base_data_source = base_pollster,
      base_data_source_key = base_pollster_key,
      estimate_note = paste0("Alternative projection based on raw ", base_pollster, " data.")
    ))
  }

  c(pollster_media, list(
    estimate_type = NA_character_,
    base_pollster = NA_character_,
    base_pollster_key = NA_character_,
    base_data_source = NA_character_,
    base_data_source_key = NA_character_,
    estimate_note = NA_character_
  ))
}

normalize_poll_record <- function(record, election_key = "congreso_espana_2026") {
  pollster_media <- split_pollster_media(record$pollster_raw)
  pollster_media <- apply_pollster_media_overrides(record, pollster_media)
  dates <- parse_fieldwork_date(record$fieldwork_raw, record$year)
  publication_date <- parse_publication_date(record$publication_date_raw %||% NA_character_, fallback_year = record$year)
  if (is.na(publication_date)) {
    publication_date <- dates$end
  }
  results <- lapply(record$results %||% list(), function(result) {
    parsed <- parse_result_cell(result$raw_value)
    list(
      party_key = normalize_party(result$party_raw),
      party_raw = clean_wiki_text(result$party_raw),
      vote_share = parsed$vote_share,
      seats_min = parsed$seats_min,
      seats_max = parsed$seats_max,
      raw_value = parsed$raw_value
    )
  })
  source_metadata <- record$source_metadata %||% list()
  if (!is_blank(record$polling_context %||% NA_character_)) {
    source_metadata$polling_context <- record$polling_context
  }
  if (!is.na(pollster_media$estimate_type)) {
    source_metadata$estimate_type <- pollster_media$estimate_type
    source_metadata$base_pollster <- pollster_media$base_pollster
    source_metadata$base_pollster_key <- pollster_media$base_pollster_key
    source_metadata$base_data_source <- pollster_media$base_data_source
    source_metadata$base_data_source_key <- pollster_media$base_data_source_key
    source_metadata$estimate_note <- pollster_media$estimate_note
  }

  poll <- list(
    election_key = election_key,
    pollster_raw = pollster_media$pollster,
    pollster_key = normalize_pollster(pollster_media$pollster),
    media_raw = pollster_media$media,
    media_key = normalize_media(pollster_media$media),
    media = ifelse(is_blank(pollster_media$media), NA_character_, clean_wiki_text(pollster_media$media)),
    fieldwork_start = dates$start,
    fieldwork_end = dates$end,
    publication_date = publication_date,
    sample_size = parse_sample_size(record$sample_size_raw),
    turnout = parse_percent(record$turnout_raw),
    lead = parse_percent(record$lead_raw),
    wiki_page = record$wiki_page %||% "next_spanish_general_election",
    wiki_revision_id = record$wiki_revision_id %||% NA_integer_,
    source_url = record$source_url %||% NA_character_,
    source_title = record$source_title %||% NA_character_,
    source_reference_ids = record$source_reference_ids %||% character(),
    source_metadata = source_metadata,
    notes = ifelse(is_blank(record$notes %||% NA_character_), pollster_media$estimate_note, record$notes),
    poll_variant = pollster_media$estimate_type,
    base_pollster_key = pollster_media$base_pollster_key,
    base_data_source_key = pollster_media$base_data_source_key,
    year = as.integer(record$year),
    row_number = record$row_number %||% NA_integer_,
    results = results
  )
  poll$poll_key_strict <- generate_poll_key_strict(poll)
  poll$poll_signature <- generate_poll_signature(poll)
  poll$row_hash <- generate_row_hash(poll)
  poll
}

resolve_duplicate_poll_keys <- function(polls) {
  keys <- vapply(polls, function(x) x$poll_key_strict, character(1))
  duplicated_keys <- unique(keys[duplicated(keys)])
  if (length(duplicated_keys) == 0) {
    return(polls)
  }

  for (key in duplicated_keys) {
    idx <- which(keys == key)
    suffixes <- vapply(polls[idx], function(poll) {
      digest::digest(
        as_json(list(
          source_url = poll$source_url,
          lead = poll$lead,
          results = poll$results
        )),
        algo = "xxhash32",
        serialize = FALSE
      )
    }, character(1))

    if (any(duplicated(suffixes))) {
      suffixes <- paste0(suffixes, "_", seq_along(suffixes))
    }

    for (j in seq_along(idx)) {
      polls[[idx[[j]]]]$poll_key_strict <- paste(key, paste0("dup_", suffixes[[j]]), sep = "__")
    }
  }
  polls
}

normalize_poll_records <- function(records, election_key = "congreso_espana_2026") {
  polls <- lapply(records, normalize_poll_record, election_key = election_key)
  resolve_duplicate_poll_keys(polls)
}
