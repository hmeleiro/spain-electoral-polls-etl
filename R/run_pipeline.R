run_poll_scraper <- function(page_key = "next_spanish_general_election", force_reprocess = FALSE) {
  require_packages(c(
    "DBI", "RPostgres", "digest", "dplyr", "httr2", "jsonlite",
    "lubridate", "rvest", "stringr", "xml2"
  ))

  config <- load_config()
  page <- get_page_definition(page_key)
  con <- NULL
  run_id <- NA_integer_
  revision <- NULL

  tryCatch({
    con <- db_connect(config)
    revision <- fetch_wiki_revision_info(page$page_title[[1]], config$wiki_user_agent)
    run_id <- insert_scraper_run(con, page_key, revision$revision_id)

    if (!force_reprocess && revision_processed(con, page_key, revision$revision_id)) {
      finish_scraper_run(con, run_id, "no_change", stats = list(rows_found = 0L))
      return(invisible(list(status = "no_change", revision_id = revision$revision_id)))
    }

    raw_html <- fetch_wiki_html(page$url[[1]], config$wiki_user_agent)
    raw_wikitext <- fetch_wiki_wikitext(page$page_title[[1]], revision$revision_id, config$wiki_user_agent)
    upsert_page_revision(con, page_key, revision, raw_html, raw_wikitext, parse_status = "fetched")

    DBI::dbWithTransaction(con, {
      parsed <- parse_wiki_poll_html(
        raw_html,
        wiki_page = page_key,
        wiki_revision_id = revision$revision_id,
        default_year = page$default_year[[1]]
      )
      normalized <- normalize_poll_records(parsed, election_key = page$election_key[[1]])
      validate_normalized_polls(normalized)
      stats <- upsert_normalized_polls(con, normalized, page_key, revision$revision_id)
      mark_page_revision_status(con, page_key, revision$revision_id, "success")
      finish_scraper_run(con, run_id, "success", stats = stats)
    })

    invisible(list(status = "success", revision_id = revision$revision_id))
  }, error = function(e) {
    if (!is.null(con) && DBI::dbIsValid(con)) {
      if (!is.null(revision)) {
        try(mark_page_revision_status(con, page_key, revision$revision_id, "failed", conditionMessage(e)), silent = TRUE)
      }
      if (!is.na(run_id)) {
        try(finish_scraper_run(con, run_id, "failed", error_message = conditionMessage(e)), silent = TRUE)
      }
    }
    stop(e)
  }, finally = {
    db_disconnect(con)
  })
}
