test_that("fixture poll table parses and normalizes", {
  html <- paste(readLines(test_path("fixtures", "wiki-national-table.html"), warn = FALSE), collapse = "\n")
  records <- parse_wiki_poll_html(html, wiki_revision_id = 123)
  expect_equal(length(records), 2)
  expect_false(any(vapply(records, function(x) grepl("election", x$pollster_raw, ignore.case = TRUE), logical(1))))
  expect_equal(records[[1]]$year, 2026L)
  expect_equal(records[[1]]$pollster_raw, "40dB/Prisa")
  expect_equal(records[[1]]$publication_date_raw, "2026-06-02")
  expect_equal(records[[1]]$source_url, "https://example.com/poll-40db")
  expect_equal(records[[1]]$source_title, "40dB poll headline")
  expect_equal(records[[1]]$source_reference_ids, "cite_note-1")

  polls <- normalize_poll_records(records)
  validate_normalized_polls(polls)

  expect_equal(polls[[1]]$pollster_key, "40db")
  expect_equal(polls[[1]]$media_key, "prisa")
  expect_equal(polls[[1]]$sample_size, 2000L)
  expect_equal(polls[[1]]$fieldwork_start, as.Date("2026-05-28"))
  expect_equal(polls[[1]]$fieldwork_end, as.Date("2026-06-01"))
  expect_equal(polls[[1]]$publication_date, as.Date("2026-06-02"))
  expect_true(any(vapply(polls[[1]]$results, function(x) x$party_key == "pp" && x$vote_share == 32.4, logical(1))))
})

test_that("historical pages can use a default year without year headings", {
  html <- paste(c(
    "<html><body>",
    "<h2>Electoral polling</h2>",
    "<h3>Nationwide polling</h3>",
    "<h4>Voting intention estimates</h4>",
    "<table class='wikitable'>",
    "<tr><th>Polling firm/Commissioner</th><th>Fieldwork date</th><th>Sample size</th><th>Turnout</th><th>PSOE</th><th>PP</th><th>Vox</th><th>Lead</th></tr>",
    "<tr><td>2023 general election</td><td>23 Jul</td><td>Electorate</td><td>70.4</td><td>31.7</td><td>33.1</td><td>12.4</td><td>1.4</td></tr>",
    "<tr><td>40dB/Prisa</td><td>20-22 Jul</td><td>2,000</td><td>?</td><td>28.0</td><td>32.0</td><td>14.0</td><td>4.0</td></tr>",
    "</table>",
    "</body></html>"
  ), collapse = "\n")

  records <- parse_wiki_poll_html(
    html,
    wiki_page = "spanish_general_election_2023",
    default_year = 2023
  )
  polls <- normalize_poll_records(records, election_key = "congreso_espana_2023")

  expect_equal(length(polls), 1)
  expect_equal(polls[[1]]$fieldwork_start, as.Date("2023-07-20"))
  expect_equal(polls[[1]]$fieldwork_end, as.Date("2023-07-22"))
  expect_equal(polls[[1]]$election_key, "congreso_espana_2023")
})
