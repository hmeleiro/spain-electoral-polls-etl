heading_year <- function(text) {
  value <- clean_wiki_text(text)
  if (grepl("^20[0-9]{2}$", value)) {
    return(as.integer(value))
  }
  NA_integer_
}

header_role <- function(x) {
  key <- normalize_text(x)
  if (grepl("polling firm|pollster|commissioner", key)) {
    return("pollster")
  }
  if (grepl("fieldwork", key)) {
    return("fieldwork")
  }
  if (grepl("sample", key)) {
    return("sample_size")
  }
  if (grepl("turnout", key)) {
    return("turnout")
  }
  if (grepl("^lead$", key)) {
    return("lead")
  }
  key
}

first_nonblank <- function(values) {
  values <- values[!is.na(values)]
  values <- clean_wiki_text(values)
  values <- values[nzchar(values)]
  if (length(values) == 0) {
    return(NA_character_)
  }
  values[[1]]
}

clean_header_candidate <- function(x) {
  x <- clean_wiki_text(x)
  x <- gsub("^File:", "", x, ignore.case = TRUE)
  x <- gsub("\\.(svg|png|jpg|jpeg|webp)$", "", x, ignore.case = TRUE)
  x <- gsub("\\blogo\\b", "", x, ignore.case = TRUE)
  x <- gsub("_", " ", x, fixed = TRUE)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

header_label_from_th <- function(th_node) {
  text <- clean_wiki_text(xml2::xml_text(th_node))
  if (nzchar(text)) {
    return(text)
  }

  img_nodes <- xml2::xml_find_all(th_node, ".//img")
  link_nodes <- xml2::xml_find_all(th_node, ".//a")
  candidates <- c(
    xml2::xml_attr(img_nodes, "aria-label"),
    xml2::xml_attr(link_nodes, "title"),
    xml2::xml_attr(img_nodes, "title"),
    xml2::xml_attr(img_nodes, "alt")
  )
  candidate <- first_nonblank(candidates)
  if (!is.na(candidate)) {
    return(clean_header_candidate(candidate))
  }

  href <- first_nonblank(xml2::xml_attr(link_nodes, "href"))
  if (!is.na(href)) {
    href <- utils::URLdecode(basename(href))
    return(clean_header_candidate(href))
  }

  src <- first_nonblank(xml2::xml_attr(img_nodes, "src"))
  if (!is.na(src)) {
    src <- utils::URLdecode(basename(src))
    return(clean_header_candidate(src))
  }

  NA_character_
}

extract_table_headers <- function(table_node, fallback_names) {
  header_cells <- xml2::xml_find_all(table_node, ".//tr[th][1]/th")
  if (length(header_cells) == 0) {
    return(fallback_names)
  }

  headers <- character()
  for (cell in header_cells) {
    label <- header_label_from_th(cell)
    colspan <- suppressWarnings(as.integer(xml2::xml_attr(cell, "colspan")))
    if (is.na(colspan) || colspan < 1) {
      colspan <- 1L
    }
    headers <- c(headers, rep(label, colspan))
  }

  if (length(headers) != length(fallback_names)) {
    return(fallback_names)
  }

  headers <- clean_wiki_text(headers)
  empty <- is.na(headers) | headers == ""
  headers[empty] <- fallback_names[empty]
  headers
}

is_poll_table <- function(table) {
  roles <- vapply(names(table), header_role, character(1))
  all(c("pollster", "fieldwork", "sample_size", "lead") %in% roles)
}

normalise_table_names <- function(table) {
  roles <- vapply(names(table), header_role, character(1))
  names(table) <- make.unique(roles, sep = "_")
  table
}

extract_first_source_url <- function(row_node) {
  href <- xml2::xml_attr(xml2::xml_find_first(row_node, ".//td[1]//a[@href]"), "href")
  if (length(href) == 0 || is.na(href)) {
    return(NA_character_)
  }
  if (grepl("^https?://", href)) {
    href
  } else {
    paste0("https://en.wikipedia.org", href)
  }
}

parse_z3988_title <- function(title) {
  if (is_blank(title)) {
    return(list())
  }
  parts <- strsplit(title, "&", fixed = TRUE)[[1]]
  out <- list()
  for (part in parts) {
    kv <- strsplit(part, "=", fixed = TRUE)[[1]]
    if (length(kv) < 2) {
      next
    }
    name <- utils::URLdecode(kv[[1]])
    value <- utils::URLdecode(paste(kv[-1], collapse = "="))
    out[[name]] <- value
  }
  out
}

parse_reference_date <- function(x) {
  if (is_blank(x)) {
    return(NA_character_)
  }
  value <- clean_wiki_text(x)
  parsed <- suppressWarnings(lubridate::ymd(value))
  if (is.na(parsed)) {
    parsed <- suppressWarnings(lubridate::dmy(value, locale = "C"))
  }
  if (is.na(parsed)) {
    parsed <- suppressWarnings(lubridate::mdy(value, locale = "C"))
  }
  if (is.na(parsed)) {
    return(NA_character_)
  }
  as.character(parsed)
}

extract_citation_metadata <- function(reference_node) {
  z3988 <- xml2::xml_attr(xml2::xml_find_first(reference_node, ".//*[contains(@class, 'Z3988')]"), "title")
  z <- parse_z3988_title(z3988)

  external_url <- xml2::xml_attr(xml2::xml_find_first(reference_node, ".//a[contains(@class, 'external')]"), "href")
  title <- clean_wiki_text(xml2::xml_text(xml2::xml_find_first(reference_node, ".//a[contains(@class, 'external')]")))
  title <- gsub('^["\u201c\u201d]+|["\u201c\u201d]+$', "", title)
  publisher <- clean_wiki_text(xml2::xml_text(xml2::xml_find_first(reference_node, ".//cite//i")))
  reference_text <- clean_wiki_text(xml2::xml_text(reference_node))

  date_raw <- z[["rft.date"]] %||% NA_character_
  date <- parse_reference_date(date_raw)
  if (is.na(date)) {
    date_match <- regmatches(reference_text, regexpr("\\b\\d{1,2}\\s+[A-Z][a-z]+\\s+20\\d{2}\\b", reference_text, perl = TRUE))
    if (length(date_match) > 0 && nzchar(date_match)) {
      date_raw <- date_match
      date <- parse_reference_date(date_match)
    }
  }

  list(
    reference_id = xml2::xml_attr(reference_node, "id"),
    url = external_url %||% z[["rft_id"]] %||% NA_character_,
    title = title %||% z[["rft.atitle"]] %||% NA_character_,
    publisher = publisher %||% z[["rft.jtitle"]] %||% NA_character_,
    publication_date = date,
    publication_date_raw = date_raw,
    reference_text = reference_text
  )
}

build_reference_map <- function(doc) {
  refs <- xml2::xml_find_all(doc, "//*[@id and starts-with(@id, 'cite_note-')]")
  out <- list()
  for (ref in refs) {
    metadata <- extract_citation_metadata(ref)
    out[[metadata$reference_id]] <- metadata
  }
  out
}

extract_row_reference_ids <- function(row_node) {
  hrefs <- xml2::xml_attr(xml2::xml_find_all(row_node, ".//sup[contains(@class, 'reference')]//a[@href]"), "href")
  hrefs <- hrefs[!is.na(hrefs)]
  ids <- sub("^#", "", hrefs)
  unique(ids[nzchar(ids)])
}

extract_row_source_metadata <- function(row_node, reference_map) {
  reference_ids <- extract_row_reference_ids(row_node)
  references <- reference_map[reference_ids]
  references <- references[!vapply(references, is.null, logical(1))]

  first_with <- function(field) {
    values <- vapply(references, function(ref) ref[[field]] %||% NA_character_, character(1))
    values <- values[!is.na(values) & nzchar(values)]
    if (length(values) == 0) NA_character_ else values[[1]]
  }

  list(
    source_url = first_with("url"),
    source_title = first_with("title"),
    publication_date_raw = first_with("publication_date"),
    source_reference_ids = reference_ids,
    source_metadata = references
  )
}

cell_text_preserving_breaks <- function(cell_node) {
  pieces <- character()
  contents <- xml2::xml_contents(cell_node)

  if (length(contents) == 0) {
    return(clean_wiki_text(xml2::xml_text(cell_node)))
  }

  for (child in contents) {
    if (identical(xml2::xml_name(child), "br")) {
      if (length(pieces) > 0 && !identical(tail(pieces, 1), "\n")) {
        pieces <- c(pieces, "\n")
      }
    } else {
      text <- clean_wiki_text(xml2::xml_text(child))
      if (!nzchar(text)) {
        next
      }
      if (length(pieces) > 0 && !identical(tail(pieces, 1), "\n")) {
        pieces <- c(pieces, "\n")
      }
      pieces <- c(pieces, text)
    }
  }

  value <- paste0(pieces, collapse = "")
  lines <- strsplit(gsub("\r\n|\r", "\n", value), "\n", fixed = FALSE)[[1]]
  lines <- clean_wiki_text(lines)
  lines <- lines[nzchar(lines)]
  if (length(lines) == 0) {
    return("")
  }
  paste(lines, collapse = "\n")
}

party_columns <- function(table) {
  names <- names(table)
  start <- match("turnout", names)
  if (is.na(start)) {
    start <- match("sample_size", names)
  }
  end <- match("lead", names)
  if (is.na(start) || is.na(end) || end <= start + 1) {
    return(character())
  }
  names[(start + 1):(end - 1)]
}

extract_row_values <- function(row_node, expected_cols) {
  cells <- xml2::xml_find_all(row_node, "./td")
  if (length(cells) == 0) {
    return(NULL)
  }

  values <- character()
  for (cell in cells) {
    colspan <- suppressWarnings(as.integer(xml2::xml_attr(cell, "colspan")))
    if (is.na(colspan) || colspan < 1) {
      colspan <- 1L
    }
    values <- c(values, rep(cell_text_preserving_breaks(cell), colspan))
  }

  if (length(values) != expected_cols) {
    return(NULL)
  }
  values
}

is_non_poll_row <- function(row) {
  pollster_key <- normalize_text(row$pollster %||% "")
  fieldwork_key <- normalize_text(row$fieldwork %||% "")
  sample_key <- normalize_text(row$sample_size %||% "")
  row_key <- normalize_text(paste(
    row$pollster %||% "",
    row$fieldwork %||% "",
    row$sample_size %||% "",
    row$turnout %||% "",
    sep = " "
  ))

  if (is_blank(row$pollster)) {
    return(TRUE)
  }

  repeated_header_pattern <- "polling firm|pollster|commissioner|fieldwork date|sample size"
  if (grepl(repeated_header_pattern, row_key)) {
    return(TRUE)
  }

  aggregate_pattern <- "average|loess|projection|seat projection|model"
  if (grepl(aggregate_pattern, pollster_key)) {
    return(TRUE)
  }

  election_pattern <- paste(
    c(
      "\\belection\\b",
      "\\bgeneral election\\b",
      "\\belection result\\b",
      "\\bresult\\b",
      "\\bresults\\b",
      "\\bactual result\\b",
      "\\bprevious election\\b",
      "\\blast election\\b",
      "\\b2023 spanish general election\\b"
    ),
    collapse = "|"
  )
  if (grepl(election_pattern, row_key)) {
    return(TRUE)
  }

  election_date_pattern <- "^\\d{1,2}\\s+[a-z]{3,9}\\s+20\\d{2}$"
  has_election_like_date <- grepl(election_date_pattern, fieldwork_key)
  has_no_sample <- is_missing_value(row$sample_size %||% NA_character_) || sample_key %in% c("electorate", "registered voters")
  if (has_election_like_date && has_no_sample) {
    return(TRUE)
  }

  FALSE
}

parse_poll_table <- function(table_node, year, wiki_page, wiki_revision_id, reference_map = list()) {
  table <- rvest::html_table(table_node, fill = TRUE, trim = TRUE)
  names(table) <- extract_table_headers(table_node, names(table))
  if (!is_poll_table(table)) {
    return(list())
  }
  raw_names <- names(table)
  normalized_names <- make.unique(vapply(raw_names, header_role, character(1)), sep = "_")
  names(table) <- normalized_names
  parties <- party_columns(table)
  if (length(parties) == 0) {
    return(list())
  }

  row_nodes <- xml2::xml_find_all(table_node, ".//tr[td]")
  records <- list()
  for (i in seq_along(row_nodes)) {
    row_values <- extract_row_values(row_nodes[[i]], length(normalized_names))
    if (is.null(row_values)) {
      if (i > nrow(table)) {
        next
      }
      row_values <- as.character(table[i, normalized_names, drop = TRUE])
    }
    names(row_values) <- normalized_names
    row <- as.list(row_values)
    if (is_non_poll_row(row)) {
      next
    }

    source_metadata <- extract_row_source_metadata(row_nodes[[i]], reference_map)
    source_url <- source_metadata$source_url %||% extract_first_source_url(row_nodes[[i]])
    party_results <- lapply(parties, function(column) {
      column_position <- match(column, names(table))
      original_name <- raw_names[[column_position]]
      raw_value <- row[[column]]
      list(
        party_raw = original_name,
        raw_value = raw_value
      )
    })

    records[[length(records) + 1]] <- list(
      year = year,
      pollster_raw = clean_wiki_text(row$pollster),
      fieldwork_raw = clean_wiki_text(row$fieldwork),
      sample_size_raw = clean_wiki_text(row$sample_size),
      turnout_raw = if ("turnout" %in% names(row)) clean_wiki_text(row$turnout) else NA_character_,
      lead_raw = clean_wiki_text(row$lead),
      source_url = source_url,
      source_title = source_metadata$source_title,
      source_reference_ids = source_metadata$source_reference_ids,
      source_metadata = source_metadata$source_metadata,
      publication_date_raw = source_metadata$publication_date_raw,
      notes = NA_character_,
      row_number = i,
      wiki_page = wiki_page,
      wiki_revision_id = wiki_revision_id,
      results = party_results
    )
  }
  records
}

parse_wiki_poll_html <- function(
  html,
  wiki_page = "next_spanish_general_election",
  wiki_revision_id = NA_integer_,
  default_year = NA_integer_
) {
  doc <- xml2::read_html(html)
  reference_map <- build_reference_map(doc)
  nodes <- xml2::xml_find_all(doc, "//*[self::h2 or self::h3 or self::h4 or self::h5 or self::table]")

  in_voting_estimates <- FALSE
  current_year <- as.integer(default_year)
  records <- list()

  for (node in nodes) {
    node_name <- xml2::xml_name(node)
    text <- clean_wiki_text(xml2::xml_text(node))

    if (node_name %in% c("h2", "h3", "h4", "h5")) {
      if (grepl("Voting intention estimates", text, ignore.case = TRUE)) {
        in_voting_estimates <- TRUE
        next
      }
      if (in_voting_estimates && grepl("Voting preferences|Hypothetical|Sub-national|Leadership|Notes|References", text, ignore.case = TRUE)) {
        in_voting_estimates <- FALSE
      }
      year <- heading_year(text)
      if (in_voting_estimates && !is.na(year)) {
        current_year <- year
      }
      next
    }

    if (node_name == "table" && in_voting_estimates) {
      table_year <- if (!is.na(current_year)) current_year else as.integer(default_year)
      if (is.na(table_year)) {
        next
      }
      parsed <- parse_poll_table(node, table_year, wiki_page, wiki_revision_id, reference_map = reference_map)
      records <- c(records, parsed)
    }
  }

  if (length(records) == 0) {
    stop("No nationwide voting intention poll tables were detected.", call. = FALSE)
  }
  records
}

validate_normalized_polls <- function(polls) {
  if (length(polls) == 0) {
    stop("No polls parsed after normalization.", call. = FALSE)
  }

  keys <- vapply(polls, function(x) x$poll_key_strict, character(1))
  duplicated_keys <- keys[duplicated(keys) & keys != "na"]
  if (length(duplicated_keys) > 0) {
    stop("Duplicate strict poll keys detected in parsed revision: ", paste(unique(duplicated_keys), collapse = ", "), call. = FALSE)
  }

  bad_percent <- vapply(polls, function(poll) {
    result_values <- vapply(poll$results, function(x) x$vote_share %||% NA_real_, numeric(1))
    any(!is.na(result_values) & (result_values < 0 | result_values > 100)) ||
      (!is.na(poll$turnout) && (poll$turnout < 0 || poll$turnout > 100)) ||
      (!is.na(poll$lead) && (poll$lead < 0 || poll$lead > 100))
  }, logical(1))
  if (any(bad_percent)) {
    stop("One or more rows contain percentages outside 0-100.", call. = FALSE)
  }

  bad_dates <- vapply(polls, function(poll) {
    !is.na(poll$fieldwork_start) && !is.na(poll$fieldwork_end) && poll$fieldwork_start > poll$fieldwork_end
  }, logical(1))
  if (any(bad_dates)) {
    stop("One or more rows contain incoherent fieldwork dates.", call. = FALSE)
  }

  invisible(TRUE)
}
