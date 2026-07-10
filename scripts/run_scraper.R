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
force_reprocess <- tolower(Sys.getenv("FORCE_REPROCESS", unset = "false")) %in% c("1", "true", "yes")
result <- run_poll_scraper(page_key, force_reprocess = force_reprocess)

result_file <- Sys.getenv("SCRAPER_RESULT_FILE", unset = NA_character_)
if (!is.na(result_file) && nzchar(result_file)) {
  result_dir <- dirname(result_file)
  if (!dir.exists(result_dir)) {
    dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)
  }

  writeLines(
    c(
      paste0("status=", result$status),
      paste0("revision_id=", result$revision_id),
      paste0("page_key=", page_key)
    ),
    con = result_file,
    useBytes = TRUE
  )
}

print(result)
