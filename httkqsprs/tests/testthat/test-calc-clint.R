test_that("clint predictions match the pre-refactor golden output", {
  expected <- readRDS(test_path("fixtures", "expected-clint.rds"))
  got <- calc_clint(load_fixture_descriptors())

  expect_equal(
    align_to(got$output, expected$output),
    align_to(expected$output, expected$output),
    ignore_attr = TRUE
  )
})

test_that("clint reports incomplete chemicals in $missing", {
  expected <- readRDS(test_path("fixtures", "expected-clint.rds"))
  got <- calc_clint(load_fixture_descriptors())

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
  descriptors <- load_fixture_descriptors()[0, , drop = FALSE]

  got <- calc_clint(descriptors)
  expect_equal(nrow(got$output), 0L)
  expect_equal(nrow(got$missing), 0L)
})
