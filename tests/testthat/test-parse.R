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

test_that("historical polling sections headed Polling are parsed", {
  html <- paste(c(
    "<html><body>",
    "<h2>Polling</h2>",
    "<h3>2022</h3>",
    "<table class='wikitable'>",
    "<tr><th>Polling firm/Commissioner</th><th>Fieldwork date</th><th>Sample size</th><th>Turnout</th><th>PSOE</th><th>PP</th><th>Vox</th><th>Lead</th></tr>",
    "<tr><td>40dB/Prisa</td><td>27-31 Dec</td><td>2,000</td><td>?</td><td>26.9</td><td>28.9</td><td>14.0</td><td>2.0</td></tr>",
    "</table>",
    "<h2>Notes</h2>",
    "<table class='wikitable'>",
    "<tr><th>Polling firm/Commissioner</th><th>Fieldwork date</th><th>Sample size</th><th>Turnout</th><th>PSOE</th><th>PP</th><th>Vox</th><th>Lead</th></tr>",
    "<tr><td>Ignored/Notes</td><td>1-2 Jan</td><td>1,000</td><td>?</td><td>20.0</td><td>30.0</td><td>10.0</td><td>10.0</td></tr>",
    "</table>",
    "</body></html>"
  ), collapse = "\n")

  records <- parse_wiki_poll_html(
    html,
    wiki_page = "spanish_general_election_2023_2022",
    default_year = 2022
  )
  polls <- normalize_poll_records(records, election_key = "congreso_espana_2023")

  expect_equal(length(polls), 1)
  expect_equal(records[[1]]$year, 2022L)
  expect_equal(polls[[1]]$pollster_key, "40db")
  expect_equal(polls[[1]]$fieldwork_start, as.Date("2022-12-27"))
  expect_equal(polls[[1]]$fieldwork_end, as.Date("2022-12-31"))
})

test_that("rowspanned CIS reestimate rows keep their own pollster and references", {
  html <- paste(c(
    "<html><body>",
    "<h4>Voting intention estimates</h4>",
    "<h5>2025</h5>",
    "<table class='wikitable'>",
    "<tr><th>Polling firm/Commissioner</th><th>Fieldwork date</th><th>Sample size</th><th>Turnout</th><th>PP</th><th>PSOE</th><th>Vox</th><th>Lead</th></tr>",
    "<tr>",
    "<td>CIS <span>(Opina 360)</span><sup class='reference'><a href='#cite_note-AltCIS-1'>[a]</a></sup><sup class='reference'><a href='#cite_note-Opina-2'>[127]</a></sup></td>",
    "<td rowspan='3'>1-7 Oct</td><td rowspan='3'>4,029</td><td>?</td><td>25.9</td><td>27.7</td><td>20.7</td><td>1.8</td>",
    "</tr>",
    "<tr>",
    "<td>CIS <span>(Logoslab)</span><sup class='reference'><a href='#cite_note-AltCIS-1'>[a]</a></sup><sup class='reference'><a href='#cite_note-Logoslab-3'>[147]</a></sup></td>",
    "<td>71</td><td>27.0</td><td>28.0</td><td>19.5</td><td>1.0</td>",
    "</tr>",
    "<tr>",
    "<td>CIS<sup class='reference'><a href='#cite_note-CISOct-4'>[148]</a></sup><sup class='reference'><a href='#cite_note-CISOctEst-5'>[149]</a></sup></td>",
    "<td>?</td><td>19.8</td><td>34.8</td><td>17.7</td><td>15.0</td>",
    "</tr>",
    "</table>",
    "<ol class='references'>",
    "<li id='cite_note-AltCIS-1'><span class='reference-text'>Alternative projection based on raw CIS data.</span></li>",
    "<li id='cite_note-Opina-2'><span class='reference-text'><cite><a class='external text' href='https://example.com/opina'>Opina projection</a>. <i>Opina 360</i>. 19 November 2025.</cite><span class='Z3988' title='rft.atitle=Opina+projection&amp;rft.jtitle=Opina+360&amp;rft.date=2025-11-19&amp;rft_id=https%3A%2F%2Fexample.com%2Fopina'></span></span></li>",
    "<li id='cite_note-Logoslab-3'><span class='reference-text'><cite><a class='external text' href='https://example.com/logos'>Logoslab projection</a>. <i>Logoslab</i>. 14 October 2025.</cite><span class='Z3988' title='rft.atitle=Logoslab+projection&amp;rft.jtitle=Logoslab&amp;rft.date=2025-10-14&amp;rft_id=https%3A%2F%2Fexample.com%2Flogos'></span></span></li>",
    "<li id='cite_note-CISOct-4'><span class='reference-text'><cite><a class='external text' href='https://example.com/cis'>CIS barometer</a>. <i>CIS</i>. 14 October 2025.</cite><span class='Z3988' title='rft.atitle=CIS+barometer&amp;rft.jtitle=CIS&amp;rft.date=2025-10-14&amp;rft_id=https%3A%2F%2Fexample.com%2Fcis'></span></span></li>",
    "<li id='cite_note-CISOctEst-5'><span class='reference-text'><cite><a class='external text' href='https://example.com/cis-est'>CIS estimate</a>. <i>CIS</i>. 14 October 2025.</cite><span class='Z3988' title='rft.atitle=CIS+estimate&amp;rft.jtitle=CIS&amp;rft.date=2025-10-14&amp;rft_id=https%3A%2F%2Fexample.com%2Fcis-est'></span></span></li>",
    "</ol>",
    "</body></html>"
  ), collapse = "\n")

  doc <- xml2::read_html(html)
  row_nodes <- xml2::xml_find_all(xml2::xml_find_first(doc, ".//table"), ".//tr[td]")
  expanded_rows <- extract_expanded_row_values(row_nodes, expected_cols = 8)
  expect_false(any(vapply(expanded_rows, is.null, logical(1))))
  expect_equal(vapply(expanded_rows, function(row) row[[2]], character(1)), rep("1-7 Oct", 3))
  expect_equal(vapply(expanded_rows, function(row) row[[3]], character(1)), rep("4,029", 3))

  records <- parse_wiki_poll_html(html, wiki_revision_id = 456, default_year = 2025)
  polls <- normalize_poll_records(records)

  expect_equal(vapply(records, function(record) record$pollster_raw, character(1)), c("CIS (Opina 360)", "CIS (Logoslab)", "CIS"))
  expect_equal(vapply(records, function(record) record$source_title, character(1)), c("Opina projection", "Logoslab projection", "CIS barometer"))
  expect_equal(vapply(polls, function(poll) poll$pollster_key, character(1)), c("opina_360", "logoslab", "cis"))
  expect_equal(vapply(polls, function(poll) poll$media_key %||% NA_character_, character(1)), c("cis", "cis", NA_character_))
  expect_equal(vapply(polls, function(poll) as.character(poll$fieldwork_start), character(1)), rep("2025-10-01", 3))
  expect_equal(vapply(polls, function(poll) as.character(poll$fieldwork_end), character(1)), rep("2025-10-07", 3))
})

test_that("consecutive rowspanned poll groups do not leak into each other", {
  html <- paste(c(
    "<html><body>",
    "<table class='wikitable'>",
    "<tr><th>Polling firm/Commissioner</th><th>Fieldwork date</th><th>Sample size</th><th>Turnout</th><th>PP</th><th>PSOE</th><th>Vox</th><th>Lead</th></tr>",
    "<tr>",
    "<td rowspan='2'>SocioMetrica/El Espanol</td><td rowspan='2'>5-7 Dec</td><td rowspan='2'>1,100</td><td>?</td><td>33.4</td><td>26.2</td><td>17.4</td><td>7.2</td>",
    "</tr>",
    "<tr>",
    "<td>?</td><td>33.4</td><td>26.2</td><td>17.4</td><td>7.2</td>",
    "</tr>",
    "<tr>",
    "<td>CIS <span>(Logoslab)</span></td><td rowspan='2'>1-5 Dec</td><td rowspan='2'>4,017</td><td>?</td><td>28.0</td><td>28.0</td><td>18.8</td><td>0.0</td>",
    "</tr>",
    "<tr>",
    "<td>CIS</td><td>?</td><td>22.4</td><td>31.4</td><td>17.6</td><td>9.0</td>",
    "</tr>",
    "</table>",
    "</body></html>"
  ), collapse = "\n")

  doc <- xml2::read_html(html)
  row_nodes <- xml2::xml_find_all(xml2::xml_find_first(doc, ".//table"), ".//tr[td]")
  expanded_rows <- extract_expanded_row_values(row_nodes, expected_cols = 8)

  expect_false(any(vapply(expanded_rows, is.null, logical(1))))
  expect_equal(vapply(expanded_rows, function(row) clean_wiki_text(row[[1]]), character(1)), c(
    "SocioMetrica/El Espanol",
    "SocioMetrica/El Espanol",
    "CIS (Logoslab)",
    "CIS"
  ))
  expect_equal(vapply(expanded_rows, function(row) row[[2]], character(1)), c("5-7 Dec", "5-7 Dec", "1-5 Dec", "1-5 Dec"))
  expect_equal(vapply(expanded_rows, function(row) row[[3]], character(1)), c("1,100", "1,100", "4,017", "4,017"))
})
