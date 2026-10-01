test_that("fup predictions match the committed golden output", {
  expected <- readRDS(test_path("fixtures", "expected-fup.rds"))
  got <- calc_fup(load_fixture_descriptors())

  expect_golden_output(got$output, expected$output, "Fup")
})

# $missing contract: mirrors calc_clint(). A data frame of the chemicals
# excluded for incomplete descriptors, disjoint from $output and together
# accounting for every input chemical.
test_that("fup reports incomplete chemicals in $missing", {
  expected <- readRDS(test_path("fixtures", "expected-fup.rds"))
  descriptors <- load_fixture_descriptors()
  got <- calc_fup(descriptors)

  expect_s3_class(got$missing, "data.frame")
  expect_setequal(
    as.character(got$missing$MoleculeID),
    as.character(expected$missing$MoleculeID)
  )
  expect_length(
    intersect(
      as.character(got$output$MoleculeID),
      as.character(got$missing$MoleculeID)
    ),
    0
  )
  expect_setequal(
    c(
      as.character(got$output$MoleculeID),
      as.character(got$missing$MoleculeID)
    ),
    as.character(descriptors$MoleculeID)
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

# Review Focus 1: zero-row input
test_that("a zero-row descriptor frame returns empty results, not an error", {
  descriptors <- load_fixture_descriptors()
  full <- calc_fup(descriptors)

  got <- calc_fup(descriptors[0, , drop = FALSE])
  expect_empty_output_parity(got$output, full$output)

  expect_s3_class(got$missing, "data.frame")
  expect_equal(nrow(got$missing), 0L)
  expect_identical(names(got$missing), names(full$missing))
})
