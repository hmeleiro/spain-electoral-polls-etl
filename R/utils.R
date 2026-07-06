`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
}

now_utc <- function() {
  format(Sys.time(), "%Y-%m-%d %H:%M:%OS6%z", tz = "UTC")
}

as_json <- function(x) {
  jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null", digits = NA)
}

from_json_or_null <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x) || identical(x, "")) {
    return(NULL)
  }
  jsonlite::fromJSON(x, simplifyVector = FALSE)
}

source_project_r_files <- function(root = getwd()) {
  files <- c(
    "R/utils.R",
    "R/normalize_polls.R",
    "R/poll_matching.R",
    "R/wiki_fetch.R",
    "R/wiki_parse.R",
    "R/db_connect.R",
    "R/db_upsert.R",
    "R/manual_review.R",
    "R/run_pipeline.R"
  )
  for (file in files) {
    source(file.path(root, file), local = .GlobalEnv)
  }
}

require_packages <- function(packages) {
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop("Missing required R packages: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

page_registry <- function() {
  data.frame(
    page_key = c(
      "next_spanish_general_election",
      "spanish_general_election_2023",
      "spanish_general_election_2023_2022",
      "spanish_general_election_2023_2019_2021"
    ),
    page_title = c(
      "Opinion polling for the next Spanish general election",
      "Opinion polling for the 2023 Spanish general election",
      "Nationwide opinion polling for the 2023 Spanish general election (2022)",
      "Nationwide opinion polling for the 2023 Spanish general election (2019\u20132021)"
    ),
    url = c(
      "https://en.wikipedia.org/wiki/Opinion_polling_for_the_next_Spanish_general_election",
      "https://en.wikipedia.org/wiki/Opinion_polling_for_the_2023_Spanish_general_election",
      "https://en.wikipedia.org/wiki/Nationwide_opinion_polling_for_the_2023_Spanish_general_election_(2022)",
      "https://en.wikipedia.org/wiki/Nationwide_opinion_polling_for_the_2023_Spanish_general_election_(2019%E2%80%932021)"
    ),
    election_key = c(
      "congreso_espana_2027",
      "congreso_espana_2023",
      "congreso_espana_2023",
      "congreso_espana_2023"
    ),
    territory_code = c("ES", "ES", "ES", "ES"),
    default_year = c(2026L, 2023L, 2022L, 2021L),
    election_date = as.Date(c(NA, "2023-07-23", "2023-07-23", "2023-07-23")),
    stringsAsFactors = FALSE
  )
}

get_page_definition <- function(page_key) {
  pages <- page_registry()
  page <- pages[pages$page_key == page_key, , drop = FALSE]
  if (nrow(page) != 1) {
    stop("Unknown page_key: ", page_key, call. = FALSE)
  }
  page
}

is_blank <- function(x) {
  is.null(x) || length(x) == 0 || is.na(x) || !nzchar(trimws(as.character(x)))
}

coalesce_chr <- function(...) {
  values <- list(...)
  for (value in values) {
    if (!is_blank(value)) {
      return(as.character(value))
    }
  }
  NA_character_
}

safe_date_chr <- function(x) {
  if (length(x) == 0 || is.na(x)) {
    return(NA_character_)
  }
  as.character(as.Date(x))
}

compact_list <- function(x) {
  x[!vapply(x, function(value) length(value) == 0 || all(is.na(value)), logical(1))]
}

scalar_int <- function(x) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) {
    return(NA_integer_)
  }
  as.integer(x[1])
}

load_dot_env <- function(path = ".env", overwrite = FALSE) {
  if (!file.exists(path)) {
    return(invisible(FALSE))
  }

  lines <- readLines(path, warn = FALSE)
  for (line in lines) {
    line <- trimws(line)
    if (!nzchar(line) || grepl("^#", line)) {
      next
    }
    parts <- strsplit(line, "=", fixed = TRUE)[[1]]
    if (length(parts) < 2) {
      next
    }
    name <- trimws(parts[[1]])
    value <- trimws(paste(parts[-1], collapse = "="))
    value <- sub('^"(.*)"$', "\\1", value)
    value <- sub("^'(.*)'$", "\\1", value)
    if (overwrite || identical(Sys.getenv(name, unset = NA_character_), NA_character_)) {
      do.call(Sys.setenv, stats::setNames(list(value), name))
    }
  }
  invisible(TRUE)
}
