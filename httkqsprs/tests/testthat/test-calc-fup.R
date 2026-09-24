test_that("fup predictions match the pre-refactor golden output", {
  expected <- readRDS(test_path("fixtures", "expected-fup.rds"))
  got <- calc_fup(load_fixture_descriptors())

  expect_equal(
    align_to(got$output, expected$output),
    align_to(expected$output, expected$output),
    ignore_attr = TRUE
  )
})

test_that("fup reports incomplete chemicals in $missing", {
  expected <- readRDS(test_path("fixtures", "expected-fup.rds"))
  got <- calc_fup(load_fixture_descriptors())

  expect_setequal(
    as.character(got$missing$MoleculeID),
    as.character(expected$missing$MoleculeID)
  )
})

# This is the specific hazard the union frame introduces for fup: its
# prefixing loop runs across every column it is handed.
test_that("extra union columns are not mis-prefixed", {
  descriptors <- load_fixture_descriptors()
  base <- calc_fup(descriptors)

  padded <- descriptors
  padded$zzz_unrelated_pred <- 1.5
  padded$zzz_unrelated <- 2.5
  padded_result <- calc_fup(padded)

  expect_equal(padded_result$output, base$output)
  expect_false(any(grepl("zzz_unrelated", names(padded_result$output))))
})

test_that("output columns use the Opera_ and padel_ prefixes", {
  got <- calc_fup(load_fixture_descriptors())
  modvars <- row.names(httkqsprs::RF.fit$importance)
  expect_true(all(modvars %in% names(got$output)))
})

test_that("a missing required column errors naming the column", {
  descriptors <- load_fixture_descriptors()
  dropped <- required_descriptors("fup")$padel[1]
  descriptors[[dropped]] <- NULL

  expect_error(calc_fup(descriptors), regexp = dropped, fixed = TRUE)
})
