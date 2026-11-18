# $missing contract: a data frame of the chemicals excluded for incomplete
# descriptors. Every input chemical must land in exactly one of the two
# frames, so a caller can account for anything that has no prediction.
test_that("clint reports incomplete chemicals in $missing", {
  descriptors <- load_fixture_descriptors()
  got <- calc_clint(descriptors)

  expect_s3_class(got$missing, "data.frame")
  expect_gt(nrow(got$missing), 0L)
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

test_that("extra union columns do not change the result", {
  descriptors <- load_fixture_descriptors()
  base <- calc_clint(descriptors)

  padded <- descriptors
  padded$zzz_unrelated_pred <- 1.5
  padded$zzz_unrelated <- 2.5
  padded_result <- calc_clint(padded)

  expect_equal(padded_result$output, base$output)
})

# Review Focus 2: missing required descriptor column
test_that("a missing required column errors naming the column", {
  descriptors <- load_fixture_descriptors()
  dropped <- required_descriptors("clint")$padel[1]
  descriptors[[dropped]] <- NULL

  expect_error(calc_clint(descriptors), regexp = dropped, fixed = TRUE)
})

# Review Focus 1: zero-row input
test_that("a zero-row descriptor frame returns empty results, not an error", {
  descriptors <- load_fixture_descriptors()
  full <- calc_clint(descriptors)

  got <- calc_clint(descriptors[0, , drop = FALSE])
  expect_empty_output_parity(got$output, full$output)

  expect_s3_class(got$missing, "data.frame")
  expect_equal(nrow(got$missing), 0L)
  expect_identical(names(got$missing), names(full$missing))
})
