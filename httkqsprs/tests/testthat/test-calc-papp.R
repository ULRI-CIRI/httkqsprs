test_that("papp predictions match the pre-refactor golden output", {
  expected <- readRDS(test_path("fixtures", "expected-papp.rds"))
  got <- calc_papp(load_fixture_descriptors())

  expect_golden_output(got$output, expected$output, "Papp")
})

test_that("papp returns NULL for missing, since it imputes", {
  got <- calc_papp(load_fixture_descriptors())
  expect_null(got$missing)
})

# The packaged caret model's internal `modelInfo$predict` closure is enclosed
# in .GlobalEnv and calls `predict()` unqualified, so before the fix in
# calc_papp() any object named `predict` in the caller's workspace hijacked
# that call and the prediction died. `predict` is a plausible user variable
# name, so this has to keep working.
test_that("a user object named 'predict' does not break calc_papp", {
  descriptors <- load_fixture_descriptors()
  clean <- calc_papp(descriptors)

  assign("predict", function(...) stop("hijacked"), envir = globalenv())
  withr::defer(rm("predict", envir = globalenv()))

  hijacked <- calc_papp(descriptors)
  expect_equal(hijacked$output, clean$output)
})

test_that("MoleculeID is carried through exactly, not by partial matching", {
  descriptors <- load_fixture_descriptors()
  got <- calc_papp(descriptors)

  expect_setequal(
    as.character(got$output$MoleculeID),
    as.character(descriptors$MoleculeID)
  )
  expect_false(anyNA(got$output$MoleculeID))
})

# Review Focus 4: NA pKa must flow into mean imputation, not abort
test_that("NA pKa values produce predictions via mean imputation", {
  descriptors <- load_fixture_descriptors()
  descriptors$pKa_a_pred <- NA_real_
  descriptors$pKa_b_pred <- NA_real_

  got <- calc_papp(descriptors)
  expect_equal(nrow(got$output), nrow(descriptors))
  expect_false(anyNA(got$output$Pab.Class.Pred))
})

test_that("extra union columns do not change the result", {
  descriptors <- load_fixture_descriptors()
  base <- calc_papp(descriptors)

  padded <- descriptors
  padded$zzz_unrelated_pred <- 1.5
  expect_equal(calc_papp(padded)$output, base$output)
})

test_that("a missing required column errors naming the column", {
  descriptors <- load_fixture_descriptors()
  dropped <- required_descriptors("papp")$padel[1]
  descriptors[[dropped]] <- NULL

  expect_error(calc_papp(descriptors), regexp = dropped, fixed = TRUE)
})

# Review Focus 7: the six descriptors calc_papp() can never source are
# mean-imputed to a constant. That is pre-refactor behaviour and must stay.
test_that("the six unsourceable descriptors stay constant after preparation", {
  prepared <- prepare_papp_descriptors(load_fixture_descriptors())
  constant_by_construction <- c(
    "RT_pred",
    "MDEC_23",
    "WTPT_3",
    "MDEO_11",
    "nbRotBd",
    "WTPT_4"
  )

  for (nm in constant_by_construction) {
    expect_length(unique(prepared[[nm]]), 1L)
  }
})

# Tie handling (see Global Constraints): Papp parity is asserted on the vote
# matrix, never on the predicted class. Needs the full April-2026 inputs and
# the Task 1 baseline, so it skips where those are absent.
test_that("papp vote matrix matches the pre-refactor baseline", {
  root <- test_path("..", "..", "..")
  votes_path <- file.path(root, "baseline", "golden-papp-votes.rds")
  opera_path <- file.path(
    root,
    "scripts",
    "NewHTTK_April_2026-smi_OPERA2.9Pred.csv"
  )
  padel_path <- file.path(
    root,
    "scripts",
    "NewHTTK_April_2026_QSAR-ready_smi_PadelDesc.csv"
  )

  skip_if_not(
    all(file.exists(votes_path, opera_path, padel_path)),
    "full April-2026 inputs or vote baseline not available"
  )

  # Reproduce the merge calc_papp() used to do internally, so row order
  # matches the captured baseline.
  needs <- required_descriptors("papp")
  opera <- read.csv(opera_path)
  padel <- read.csv(padel_path)
  for (nm in setdiff(needs$opera, names(opera))) {
    opera[[nm]] <- NA_real_
  }
  for (nm in setdiff(needs$padel, names(padel))) {
    padel[[nm]] <- NA_real_
  }
  descriptors <- merge(
    opera[, c("MoleculeID", needs$opera), drop = FALSE],
    padel[, c("Name", needs$padel), drop = FALSE],
    by.x = "MoleculeID",
    by.y = "Name",
    all.x = TRUE
  )

  # papp_classmodopt is a caret `train` object and predict.train() rejects
  # type = "vote", so go to the randomForest it wraps.
  votes <- stats::predict(
    httkqsprs::papp_classmodopt$finalModel,
    prepare_papp_descriptors(descriptors),
    type = "vote",
    norm.votes = FALSE
  )
  baseline <- readRDS(votes_path)

  expect_equal(dim(votes), dim(baseline))
  expect_equal(unname(votes), unname(baseline))
})
