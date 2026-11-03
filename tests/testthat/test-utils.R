test_that("November 2019 election page is registered", {
  registry <- page_registry()
  expect_equal(anyDuplicated(registry$page_key), 0L)

  page <- get_page_definition("spanish_general_election_2019_11")

  expect_equal(page$page_title[[1]], "Opinion polling for the November 2019 Spanish general election")
  expect_equal(page$election_key[[1]], "congreso_espana_2019_11")
  expect_equal(page$territory_code[[1]], "ES")
  expect_equal(page$default_year[[1]], 2019L)
  expect_equal(page$election_date[[1]], as.Date("2019-11-10"))
})

test_that("current election page uses the canonical 2026 source", {
  page <- get_page_definition("next_spanish_general_election")

  expect_equal(page$page_title[[1]], "Opinion polling for the 2026 Spanish general election")
  expect_equal(
    page$url[[1]],
    "https://en.wikipedia.org/wiki/Opinion_polling_for_the_2026_Spanish_general_election"
  )
  expect_equal(page$election_key[[1]], "congreso_espana_2026")
  expect_equal(page$default_year[[1]], 2026L)
  expect_equal(page$election_date[[1]], as.Date("2026-11-29"))
})

test_that("revision requests resolve MediaWiki redirects", {
  request <- wiki_revision_request(
    "Opinion polling for the next Spanish general election",
    "spain-electoral-polls-tests"
  )

  expect_match(request$url, "redirects=1", fixed = TRUE)
})
