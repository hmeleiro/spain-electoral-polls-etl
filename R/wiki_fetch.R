wiki_api_url <- function() {
  "https://en.wikipedia.org/w/api.php"
}

wiki_request <- function(url, user_agent) {
  httr2::request(url) |>
    httr2::req_user_agent(user_agent) |>
    httr2::req_timeout(30) |>
    httr2::req_retry(max_tries = 3, backoff = ~ 2^.x)
}

fetch_wiki_revision_info <- function(page_title, user_agent) {
  response <- wiki_request(wiki_api_url(), user_agent) |>
    httr2::req_url_query(
      action = "query",
      format = "json",
      prop = "revisions",
      titles = page_title,
      rvprop = "ids|timestamp",
      rvslots = "main"
    ) |>
    httr2::req_perform() |>
    httr2::resp_body_json(simplifyVector = FALSE)

  pages <- response$query$pages
  page <- pages[[1]]
  revision <- page$revisions[[1]]
  list(
    page_id = page$pageid,
    page_title = page$title,
    revision_id = as.integer(revision$revid),
    parent_id = as.integer(revision$parentid %||% NA_integer_),
    revision_timestamp = revision$timestamp
  )
}

fetch_wiki_html <- function(url, user_agent) {
  wiki_request(url, user_agent) |>
    httr2::req_perform() |>
    httr2::resp_body_string()
}

fetch_wiki_wikitext <- function(page_title, revision_id, user_agent) {
  response <- wiki_request(wiki_api_url(), user_agent) |>
    httr2::req_url_query(
      action = "parse",
      format = "json",
      oldid = revision_id,
      prop = "wikitext"
    ) |>
    httr2::req_perform() |>
    httr2::resp_body_json(simplifyVector = FALSE)

  response$parse$wikitext$`*` %||% response$parse$wikitext %||% NA_character_
}
