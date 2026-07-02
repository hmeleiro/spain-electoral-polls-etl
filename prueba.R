#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg) > 0) {
  sub("^--file=", "", file_arg[[1]])
} else if (file.exists(file.path("scripts", "run_scraper.R"))) {
  file.path("scripts", "run_scraper.R")
} else {
  "."
}

root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!file.exists(file.path(root, "R", "utils.R"))) {
  root <- normalizePath(getwd(), mustWork = FALSE)
}
setwd(root)
source(file.path(root, "R", "utils.R"))
source_project_r_files(root)

page_key <- Sys.getenv("PAGE_KEY", unset = "next_spanish_general_election")
# result <- run_poll_scraper(page_key)
# print(result)

  config <- load_config()
  page <- get_page_definition(page_key)
  con <- NULL
  run_id <- NA_integer_
  revision <- NULL

raw_html <- fetch_wiki_html(page$url[[1]], config$wiki_user_agent)

html <- raw_html
wiki_page = "next_spanish_general_election"wiki_revision_id = NA_integer_

# parse_wiki_poll_html(raw_html, wiki_page = page_key, wiki_revision_id = revision$revision_id[[1]])

