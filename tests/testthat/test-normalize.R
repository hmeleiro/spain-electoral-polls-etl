test_that("text, pollster, media, and party names normalize", {
  expect_equal(normalize_text(" SocioMétrica [12] "), "sociometrica")
  expect_equal(normalize_pollster("40dB"), "40db")
  expect_equal(normalize_pollster("CIS (Ateneo del Dato)"), "cis")
  expect_equal(normalize_media("El País"), "el_pais")
  expect_equal(normalize_party("PSOE"), "psoe")
  expect_equal(normalize_party("EAJ/PNV"), "eaj_pnv")
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
