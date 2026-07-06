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
  expect_equal(exact$candidates[[1]]$poll_id, 1L)
  expect_equal(exact$candidates[[1]]$confidence, 1)

  corrected_dates <- poll
  corrected_dates$fieldwork_start <- as.Date("2026-06-02")
  corrected_dates$poll_key_strict <- generate_poll_key_strict(corrected_dates)
  corrected_dates$poll_signature <- generate_poll_signature(corrected_dates)
  corrected_dates$row_hash <- generate_row_hash(corrected_dates)
  match <- match_existing_poll(corrected_dates, existing)
  expect_equal(match$match_type, "probable_match")
  expect_gte(match$confidence, 0.85)
  expect_equal(match$candidates[[1]]$poll_id, 1L)
  expect_equal(match$candidates[[1]]$rank, 1L)
  expect_gte(match$candidates[[1]]$confidence, 0.85)

  corrected_sample <- poll
  corrected_sample$sample_size <- 1230L
  corrected_sample$poll_key_strict <- generate_poll_key_strict(corrected_sample)
  corrected_sample$poll_signature <- generate_poll_signature(corrected_sample)
  corrected_sample$row_hash <- generate_row_hash(corrected_sample)
  match <- match_existing_poll(corrected_sample, existing)
  expect_equal(match$match_type, "probable_match")
  expect_false("close_sample_size" %in% match$reasons)

  similar <- poll
  similar$fieldwork_start <- as.Date("2026-06-03")
  similar$fieldwork_end <- as.Date("2026-06-07")
  similar$poll_key_strict <- generate_poll_key_strict(similar)
  similar$poll_signature <- generate_poll_signature(similar)
  similar$row_hash <- generate_row_hash(similar)
  existing_two <- rbind(existing, as_existing(similar, id = 2L))
  ambiguous <- match_existing_poll(corrected_dates, existing_two)
  expect_equal(ambiguous$match_type, "manual_review")
  expect_gte(length(ambiguous$candidates), 2)
  expect_true(all(vapply(ambiguous$candidates, function(x) x$confidence >= 0.60, logical(1))))
  expect_equal(
    vapply(ambiguous$candidates, function(x) x$rank, integer(1)),
    seq_along(ambiguous$candidates)
  )
})

test_that("matching does not review recurring pollster/media/sample patterns without close dates", {
  poll <- sample_poll()
  recurring <- poll
  recurring$fieldwork_start <- as.Date("2026-09-01")
  recurring$fieldwork_end <- as.Date("2026-09-05")
  recurring$publication_date <- as.Date("2026-09-06")
  recurring$poll_key_strict <- generate_poll_key_strict(recurring)
  recurring$poll_signature <- generate_poll_signature(recurring)
  recurring$row_hash <- generate_row_hash(recurring)

  score <- candidate_score(recurring, poll)
  expect_true(all(c(
    "same_election",
    "same_pollster",
    "same_media",
    "same_sample_size",
    "identical_vote_results"
  ) %in% score$reasons))
  expect_lt(score$score, 0.60)

  match <- match_existing_poll(recurring, as_existing(poll))
  expect_equal(match$match_type, "new_poll")
  expect_length(match$candidates, 0)
})

test_that("reestimates do not match source pollster polls with the same dates", {
  cis <- sample_poll()
  cis$pollster_raw <- "CIS"
  cis$pollster_key <- "cis"
  cis$media <- NA_character_
  cis$media_key <- NA_character_
  cis$poll_key_strict <- generate_poll_key_strict(cis)
  cis$poll_signature <- generate_poll_signature(cis)
  cis$row_hash <- generate_row_hash(cis)

  reestimate <- cis
  reestimate$pollster_raw <- "Ateneo del Dato"
  reestimate$pollster_key <- "ateneo_del_dato"
  reestimate$media <- "CIS"
  reestimate$media_key <- "cis"
  reestimate$poll_variant <- "reestimate"
  reestimate$base_pollster_key <- "cis"
  reestimate$base_data_source_key <- "cis"
  reestimate$source_metadata <- list(
    estimate_type = "reestimate",
    base_pollster_key = "cis",
    estimate_note = "Alternative projection based on raw CIS data."
  )
  reestimate$poll_key_strict <- generate_poll_key_strict(reestimate)
  reestimate$poll_signature <- generate_poll_signature(reestimate)
  reestimate$row_hash <- generate_row_hash(reestimate)

  expect_false(identical(reestimate$poll_key_strict, cis$poll_key_strict))
  score <- candidate_score(reestimate, cis)
  expect_true(all(c("same_election", "same_sample_size", "same_publication_date", "same_fieldwork_dates") %in% score$reasons))
  expect_lt(score$score, 0.60)

  match <- match_existing_poll(reestimate, as_existing(cis))
  expect_equal(match$match_type, "new_poll")
  expect_length(match$candidates, 0)
})

test_that("same media and dates with a different pollster does not trigger review", {
  existing_poll <- sample_poll()
  existing_poll$pollster_raw <- "CIS"
  existing_poll$pollster_key <- "cis"
  existing_poll$media <- "CIS"
  existing_poll$media_key <- "cis"
  existing_poll$poll_key_strict <- generate_poll_key_strict(existing_poll)
  existing_poll$poll_signature <- generate_poll_signature(existing_poll)
  existing_poll$row_hash <- generate_row_hash(existing_poll)

  new_poll <- existing_poll
  new_poll$pollster_raw <- "LogosLab"
  new_poll$pollster_key <- "logoslab"
  new_poll$poll_key_strict <- generate_poll_key_strict(new_poll)
  new_poll$poll_signature <- generate_poll_signature(new_poll)
  new_poll$row_hash <- generate_row_hash(new_poll)

  score <- candidate_score(new_poll, existing_poll)
  expect_true(all(c(
    "same_election",
    "same_media",
    "same_sample_size",
    "same_publication_date",
    "same_fieldwork_dates",
    "identical_vote_results"
  ) %in% score$reasons))
  expect_false("same_pollster" %in% score$reasons)
  expect_lt(score$score, 0.60)

  match <- match_existing_poll(new_poll, as_existing(existing_poll))
  expect_equal(match$match_type, "new_poll")
  expect_length(match$candidates, 0)
})

test_that("vote result signal requires identical comparable party values", {
  poll <- sample_poll()

  subset_poll <- poll
  subset_poll$results <- subset_poll$results[1:3]
  expect_true(results_are_identical_subset(subset_poll$results, poll$results))

  similar_poll <- poll
  similar_poll$results[[1]]$vote_share <- similar_poll$results[[1]]$vote_share + 0.1
  expect_false(results_are_identical_subset(similar_poll$results, poll$results))

  score <- candidate_score(similar_poll, poll)
  expect_false("identical_vote_results" %in% score$reasons)
  expect_false("similar_vote_results" %in% score$reasons)
})

test_that("sample size signal requires exact equality", {
  october <- sample_poll()
  october$fieldwork_start <- as.Date("2025-10-01")
  october$fieldwork_end <- as.Date("2025-10-07")
  october$publication_date <- as.Date("2025-11-19")
  october$sample_size <- 4029L

  november <- sample_poll()
  november$fieldwork_start <- as.Date("2025-11-03")
  november$fieldwork_end <- as.Date("2025-11-12")
  november$publication_date <- as.Date("2025-11-19")
  november$sample_size <- 4028L

  score <- candidate_score(october, november)
  expect_false("close_sample_size" %in% score$reasons)
  expect_false("same_sample_size" %in% score$reasons)
  expect_true("same_publication_date" %in% score$reasons)

  november$fieldwork_start <- as.Date("2025-10-02")
  november$fieldwork_end <- as.Date("2025-10-08")
  score <- candidate_score(october, november)
  expect_true("close_fieldwork_dates" %in% score$reasons)
  expect_false("close_sample_size" %in% score$reasons)
  expect_false("same_sample_size" %in% score$reasons)
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
  if (identical(match$match_type, "new_poll")) {
    expect_length(match$candidates, 0)
  }
})

test_that("candidate scoring returns candidates ordered by confidence", {
  poll <- sample_poll()
  close <- poll
  close$fieldwork_start <- as.Date("2026-06-02")
  close$poll_key_strict <- generate_poll_key_strict(close)
  close$poll_signature <- generate_poll_signature(close)
  close$row_hash <- generate_row_hash(close)

  far <- poll
  far$media_key <- "abc"
  far$media <- "ABC"
  far$publication_date <- as.Date("2026-06-11")
  far$fieldwork_start <- as.Date("2026-06-08")
  far$fieldwork_end <- as.Date("2026-06-11")
  far$poll_key_strict <- generate_poll_key_strict(far)
  far$poll_signature <- generate_poll_signature(far)
  far$row_hash <- generate_row_hash(far)

  existing <- rbind(as_existing(far, id = 2L), as_existing(close, id = 1L))
  candidates <- score_existing_poll_candidates(poll, existing)

  expect_gte(length(candidates), 2)
  expect_equal(candidates[[1]]$poll_id, 1L)
  expect_gt(candidates[[1]]$confidence, candidates[[2]]$confidence)
})
