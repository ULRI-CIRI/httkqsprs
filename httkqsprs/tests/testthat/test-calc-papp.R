test_that("papp predictions match the pre-refactor golden output", {
  expected <- readRDS(test_path("fixtures", "expected-papp.rds"))
  got <- calc_papp(load_fixture_descriptors())

  expect_golden_output(got$output, expected$output, "Papp")
})

# $missing contract: unlike Clint and Fup, Papp never excludes a chemical --
# it mean-imputes absent descriptors -- so $missing is documented as always
# NULL. Every input chemical must therefore appear in $output.
test_that("papp returns NULL for missing, since it imputes", {
  descriptors <- load_fixture_descriptors()
  got <- calc_papp(descriptors)

  expect_null(got$missing)
  expect_equal(nrow(got$output), nrow(descriptors))
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

# Review Focus 1: zero-row input. generate_preds() calls all three endpoints,
# so a header-only CSV pair must not take the pipeline down.
test_that("a zero-row descriptor frame returns empty results, not an error", {
  descriptors <- load_fixture_descriptors()
  full <- calc_papp(descriptors)

  got <- calc_papp(descriptors[0, , drop = FALSE])
  expect_empty_output_parity(got$output, full$output)

  # NULL on empty input too, matching the documented contract above.
  expect_null(got$missing)
})

# The crash this guards was inside prepare_papp_descriptors(): with no rows,
# httk::calc_ionization() is never called, so `fraction_neutral` -- a required
# model descriptor -- was never created and the papp_opt_desc subset failed.
test_that("prepare_papp_descriptors() keeps every model column on zero rows", {
  prepared <- prepare_papp_descriptors(
    load_fixture_descriptors()[0, , drop = FALSE]
  )

  expect_equal(nrow(prepared), 0L)
  expect_identical(names(prepared), httkqsprs::papp_opt_desc)
  expect_true("fraction_neutral" %in% names(prepared))
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

# Regression guard for the infinity clamp in prepare_papp_descriptors().
#
# The clamp runs AFTER standardization, so the frame is in z-units and "100
# SDs" is literally 100. Two earlier forms of this line were wrong: it scaled
# by the training SD (leaving each descriptor at a different distance, and
# reading the SD by POSITION from a table whose column order does not match
# `papp_opt_desc`), and it dropped the sign, so a -Inf was clamped to a large
# POSITIVE value at the opposite end of the model's range.
#
# `MAXDN` is the descriptor that actually carries infinities in the April-2026
# inputs; the injected cases below cover the sign handling that real data does
# not currently reach.
test_that("an infinite descriptor is clamped to +/-100 SDs, preserving sign", {
  descriptors <- load_fixture_descriptors()

  # Opposite signs, in different rows and different columns, so neither a
  # dropped sign nor a value broadcast across the frame can pass.
  descriptors[["MLFER_BO"]][1] <- Inf
  descriptors[["TopoPSA"]][2] <- -Inf

  prepared <- prepare_papp_descriptors(descriptors)

  expect_equal(prepared[["MLFER_BO"]][1], 100)
  expect_equal(prepared[["TopoPSA"]][2], -100)

  # The clamp must not depend on the descriptor's own SD. These two differ by
  # ~50x (1.46 vs 74.88), so any reintroduction of an SD factor would push the
  # magnitudes apart and fail here.
  expect_equal(
    abs(prepared[["MLFER_BO"]][1]),
    abs(prepared[["TopoPSA"]][2])
  )
  expect_false(
    isTRUE(all.equal(
      as.numeric(papp_train_msd[2, "MLFER_BO"]),
      as.numeric(papp_train_msd[2, "TopoPSA"])
    ))
  )
})

# The clamp is load-bearing: randomForest's compiled predictor and
# calc_roy_ad() both reject non-finite input, so an unclamped infinity would
# abort the whole frame rather than degrade one row.
test_that("an infinite descriptor still yields predictions for every row", {
  descriptors <- load_fixture_descriptors()
  descriptors[["MLFER_BO"]][1] <- Inf
  descriptors[["TopoPSA"]][2] <- -Inf

  got <- calc_papp(descriptors)

  expect_equal(nrow(got$output), nrow(descriptors))
  expect_false(anyNA(got$output$Pab.Class.Pred))
  expect_false(anyNA(got$output$Pab.Pred.AD))
})

# The seed added to calc_papp() only claims reproducibility for a given input
# frame. Assert exactly that, and no more: it deliberately does NOT assert
# that a chemical keeps its class across different batches, because the seed
# does not provide that.
#
# Must use the full April-2026 inputs: the fixture subset contains no tied
# chemical, so a fixture-based version of this test would pass whether or not
# the seed were present.
test_that("repeated calc_papp() calls on one frame agree on a tied chemical", {
  root <- test_path("..", "..", "..")
  descriptors <- read_descriptor_csvs(
    "NewHTTK_April_2026",
    input.folder = file.path(root, "scripts"),
    operapostfix = "-smi_OPERA2.9Pred.csv",
    padelpostfix = "_QSAR-ready_smi_PadelDesc.csv"
  )

  # Guard the premise: these two are tied only so long as the model and the
  # inputs stay as captured. If the tie disappears this test silently stops
  # testing anything, so fail instead.
  tied_ids <- c("DTXSID4060109", "DTXSID8062575")
  votes <- stats::predict(
    httkqsprs::papp_classmodopt$finalModel,
    prepare_papp_descriptors(descriptors),
    type = "vote",
    norm.votes = FALSE
  )
  top2 <- t(apply(
    votes[match(tied_ids, descriptors$MoleculeID), , drop = FALSE],
    1,
    function(v) sort(v, decreasing = TRUE)[1:2]
  ))
  expect_equal(top2[, 1], top2[, 2], ignore_attr = TRUE)

  first <- calc_papp(descriptors)$output
  second <- calc_papp(descriptors)$output
  expect_equal(second, first)

  rows <- match(tied_ids, first$MoleculeID)
  expect_equal(
    as.character(second$Pab.Class.Pred[rows]),
    as.character(first$Pab.Class.Pred[rows])
  )
})

# Tie handling (see Global Constraints): Papp parity is asserted on the vote
# matrix, never on the predicted class. calc_papp() now seeds the RNG, but
# that only makes a given input frame reproducible -- the draw a tied row
# receives still depends on how many rows precede it, so a class assertion
# would be brittle to row count and order. Votes are unaffected by the seed
# and are strictly more sensitive: they catch a single-vote shift that argmax
# would hide.
test_that("papp vote matrix matches the pre-refactor baseline", {
  root <- test_path("..", "..", "..")
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
  baseline <- readRDS(test_path("fixtures", "expected-papp-votes.rds"))

  expect_equal(dim(votes), dim(baseline))
  expect_equal(unname(votes), unname(baseline))
})
