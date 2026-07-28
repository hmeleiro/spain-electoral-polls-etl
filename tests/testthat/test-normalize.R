test_that("text, pollster, media, and party names normalize", {
  expect_equal(normalize_text(" SocioMétrica [12] "), "sociometrica")
  expect_equal(normalize_pollster("40dB"), "40db")
  expect_equal(normalize_pollster("CIS (Ateneo del Dato)"), "cis")
  expect_equal(normalize_media("El País"), "el_pais")
  expect_equal(normalize_party("PSOE"), "psoe")
  expect_equal(normalize_party("EAJ/PNV"), "eaj_pnv")
  expect_equal(normalize_party("Compromís"), "compromis")
  expect_equal(normalize_party("A New Party"), "a_new_party")
})

test_that("special values parse to typed values", {
  expect_true(is.na(parse_percent("\u2013")))
  expect_true(is.na(parse_percent("\u2014")))
  expect_true(is.na(parse_percent("?")))
  expect_equal(parse_percent("32.4%"), 32.4)
  expect_equal(parse_sample_size("2,000"), 2000L)

  result <- parse_result_cell("32.0 139/141")
  expect_equal(result$vote_share, 32.0)
  expect_equal(result$seats_min, 139L)
  expect_equal(result$seats_max, 141L)

  result <- parse_result_cell("32.0\n139/141")
  expect_equal(result$vote_share, 32.0)
  expect_equal(result$seats_min, 139L)
  expect_equal(result$seats_max, 141L)

  result <- parse_result_cell("33.0136")
  expect_equal(result$vote_share, 33.0)
  expect_equal(result$seats_min, 136L)
  expect_equal(result$seats_max, 136L)
})

test_that("fieldwork dates parse with implicit years", {
  range <- parse_fieldwork_date("1-5 Jun", 2026)
  expect_equal(range$start, as.Date("2026-06-01"))
  expect_equal(range$end, as.Date("2026-06-05"))

  range <- parse_fieldwork_date("24 May-5 Jun", 2026)
  expect_equal(range$start, as.Date("2026-05-24"))
  expect_equal(range$end, as.Date("2026-06-05"))

  range <- parse_fieldwork_date("?", 2026)
  expect_true(is.na(range$start))
  expect_true(is.na(range$end))
})

test_that("publication dates parse from citation-like values", {
  expect_equal(parse_publication_date("2026-06-02"), as.Date("2026-06-02"))
  expect_equal(parse_publication_date("2 June 2026"), as.Date("2026-06-02"))
})

test_that("CIS alternative projections normalize estimator and source roles", {
  record <- list(
    year = 2026L,
    pollster_raw = "CIS (Ateneo del Dato)",
    fieldwork_raw = "1-5 Jun",
    sample_size_raw = "2,000",
    turnout_raw = "?",
    lead_raw = "4.0",
    source_url = "https://example.com/cis-ateneo",
    source_title = "CIS reestimate",
    source_reference_ids = c("cite_note-a"),
    source_metadata = list(
      cite_note_a = list(
        reference_text = "Alternative projection based on raw CIS data."
      )
    ),
    notes = NA_character_,
    row_number = 1L,
    wiki_page = "next_spanish_general_election",
    wiki_revision_id = 123L,
    results = list(
      list(party_raw = "PP", raw_value = "32.0"),
      list(party_raw = "PSOE", raw_value = "28.0"),
      list(party_raw = "Vox", raw_value = "15.0")
    )
  )

  poll <- normalize_poll_record(record)

  expect_equal(poll$pollster_raw, "Ateneo del Dato")
  expect_equal(poll$pollster_key, "ateneo_del_dato")
  expect_equal(poll$media, "CIS")
  expect_equal(poll$media_key, "cis")
  expect_equal(poll$poll_variant, "reestimate")
  expect_equal(poll$base_pollster_key, "cis")
  expect_equal(poll$source_metadata$estimate_type, "reestimate")
  expect_match(poll$poll_key_strict, "ateneo_del_dato__cis")
  expect_match(poll$poll_key_strict, "reestimate__cis__cis")

  record$pollster_raw <- "CIS (LogosLab)"
  record$source_url <- "https://example.com/cis-logoslab"
  poll <- normalize_poll_record(record)

  expect_equal(poll$pollster_raw, "LogosLab")
  expect_equal(poll$pollster_key, "logoslab")
  expect_equal(poll$media, "CIS")
  expect_equal(poll$media_key, "cis")
  expect_equal(poll$poll_variant, "reestimate")
  expect_equal(poll$base_pollster_key, "cis")
  expect_match(poll$poll_key_strict, "logoslab__cis")
  expect_match(poll$poll_key_strict, "reestimate__cis__cis")
})
