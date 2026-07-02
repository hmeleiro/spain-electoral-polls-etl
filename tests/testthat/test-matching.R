sample_poll <- function() {
  poll <- list(
    election_key = "congreso_espana_2027",
    pollster_key = "40db",
    pollster_raw = "40dB",
    media_key = "prisa",
    media = "Prisa",
    fieldwork_start = as.Date("2026-06-01"),
    fieldwork_end = as.Date("2026-06-05"),
    publication_date = as.Date("2026-06-05"),
    sample_size = 1200L,
    turnout = NA_real_,
    lead = 4.5,
    source_url = "https://example.com",
    notes = NA_character_,
    results = list(
      list(party_key = "pp", party_raw = "PP", vote_share = 32.1, seats_min = NA_integer_, seats_max = NA_integer_, raw_value = "32.1"),
      list(party_key = "psoe", party_raw = "PSOE", vote_share = 27.6, seats_min = NA_integer_, seats_max = NA_integer_, raw_value = "27.6"),
      list(party_key = "vox", party_raw = "Vox", vote_share = 17.2, seats_min = NA_integer_, seats_max = NA_integer_, raw_value = "17.2")
    )
  )
  poll$poll_key_strict <- generate_poll_key_strict(poll)
  poll$poll_signature <- generate_poll_signature(poll)
  poll$row_hash <- generate_row_hash(poll)
  poll
}

as_existing <- function(poll, id = 1L) {
  data.frame(
    id = id,
    poll_key_strict = poll$poll_key_strict,
    poll_signature = poll$poll_signature,
    election_key = poll$election_key,
    pollster_key = poll$pollster_key,
    media = poll$media,
    media_key = poll$media_key,
    fieldwork_start = poll$fieldwork_start,
    fieldwork_end = poll$fieldwork_end,
    publication_date = poll$publication_date,
    sample_size = poll$sample_size,
    turnout = poll$turnout,
    lead = poll$lead,
    row_hash = poll$row_hash,
    results_json = as_json(poll$results),
    stringsAsFactors = FALSE
  )
}

test_that("keys, signatures, and row hashes are stable", {
  poll <- sample_poll()
  expect_match(poll$poll_key_strict, "congreso_espana_2027__40db__prisa")
  expect_match(poll$poll_signature, "2026-06-05")
  expect_equal(generate_row_hash(poll), poll$row_hash)

  changed <- poll
  changed$results[[1]]$vote_share <- 33.1
  expect_false(identical(generate_row_hash(changed), poll$row_hash))

  changed <- poll
  changed$fieldwork_start <- as.Date("2026-06-02")
  expect_false(identical(generate_row_hash(changed), poll$row_hash))

  changed <- poll
  changed$sample_size <- 1250L
  expect_false(identical(generate_row_hash(changed), poll$row_hash))
})

test_that("matching detects exact, probable corrections, and ambiguity", {
  poll <- sample_poll()
  existing <- as_existing(poll)
  exact <- match_existing_poll(poll, existing)
  expect_equal(exact$match_type, "exact")

  corrected_dates <- poll
  corrected_dates$fieldwork_start <- as.Date("2026-06-02")
  corrected_dates$poll_key_strict <- generate_poll_key_strict(corrected_dates)
  corrected_dates$poll_signature <- generate_poll_signature(corrected_dates)
  corrected_dates$row_hash <- generate_row_hash(corrected_dates)
  match <- match_existing_poll(corrected_dates, existing)
  expect_equal(match$match_type, "probable_match")
  expect_gte(match$confidence, 0.85)

  corrected_sample <- poll
  corrected_sample$sample_size <- 1230L
  corrected_sample$poll_key_strict <- generate_poll_key_strict(corrected_sample)
  corrected_sample$poll_signature <- generate_poll_signature(corrected_sample)
  corrected_sample$row_hash <- generate_row_hash(corrected_sample)
  match <- match_existing_poll(corrected_sample, existing)
  expect_equal(match$match_type, "probable_match")

  similar <- poll
  similar$fieldwork_start <- as.Date("2026-06-03")
  similar$fieldwork_end <- as.Date("2026-06-07")
  similar$poll_key_strict <- generate_poll_key_strict(similar)
  similar$poll_signature <- generate_poll_signature(similar)
  similar$row_hash <- generate_row_hash(similar)
  existing_two <- rbind(existing, as_existing(similar, id = 2L))
  ambiguous <- match_existing_poll(corrected_dates, existing_two)
  expect_equal(ambiguous$match_type, "manual_review")
})

test_that("low confidence is marked for review or treated as new", {
  poll <- sample_poll()
  other <- poll
  other$pollster_key <- "gad3"
  other$media_key <- "abc"
  other$media <- "ABC"
  other$publication_date <- as.Date("2026-07-20")
  other$fieldwork_start <- as.Date("2026-07-18")
  other$fieldwork_end <- as.Date("2026-07-20")
  other$sample_size <- 3000L
  other$poll_key_strict <- generate_poll_key_strict(other)
  other$poll_signature <- generate_poll_signature(other)
  other$row_hash <- generate_row_hash(other)

  match <- match_existing_poll(other, as_existing(poll))
  expect_true(match$match_type %in% c("new_poll", "manual_review"))
  expect_lt(match$confidence, 0.85)
})
