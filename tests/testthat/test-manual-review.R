test_that("manual review actions map to public identity statuses", {
  expect_equal(review_decision_to_identity_status("approved_new_poll"), "new_poll")
  expect_equal(review_decision_to_identity_status("approved_match"), "probable_match")
  expect_equal(review_decision_to_identity_status("rejected"), "manual_review")
  expect_equal(review_decision_to_identity_status("needs_fix"), "manual_review")
  expect_true(is.na(review_decision_to_identity_status("comment")))
})

test_that("manual review pagination is bounded", {
  expect_equal(validate_pagination(100, 0), list(limit = 100L, offset = 0L))
  expect_error(validate_pagination(0, 0), "limit must be between 1 and 1000")
  expect_error(validate_pagination(1001, 0), "limit must be between 1 and 1000")
  expect_error(validate_pagination(100, -1), "offset must be 0 or greater")
})
