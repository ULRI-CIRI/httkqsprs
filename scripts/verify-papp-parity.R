# Manual Papp parity check. NOT part of the test suite and NOT run by
# `R CMD check`.
#
# These two checks need the full April-2026 OPERA and PaDEL CSVs in `scripts/`,
# which are ~74 MB and are not shipped in the package tarball. They lived in
# `tests/testthat/test-calc-papp.R` until that made `R CMD check` fail on a
# built tarball, where `../../../scripts/` does not exist.
#
# Run from the repo root:
#
#   Rscript scripts/verify-papp-parity.R
#
# Exits non-zero if either check fails.

suppressMessages(devtools::load_all("httkqsprs", quiet = TRUE))

opera_path <- "scripts/NewHTTK_April_2026-smi_OPERA2.9Pred.csv"
padel_path <- "scripts/NewHTTK_April_2026_QSAR-ready_smi_PadelDesc.csv"
baseline_path <- "scripts/papp-votes-pre-refactor.rds"

stopifnot(
  file.exists(opera_path),
  file.exists(padel_path),
  file.exists(baseline_path)
)

failures <- character()
check <- function(label, ok) {
  cat(if (isTRUE(ok)) "PASS" else "FAIL", "-", label, "\n")
  if (!isTRUE(ok)) {
    failures <<- c(failures, label)
  }
  invisible(ok)
}

# Reproduce the merge calc_papp() used to do internally, so row order matches
# the captured baseline.
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
baseline <- readRDS(baseline_path)

# Papp parity is asserted on the vote matrix, never on the predicted class.
# calc_papp() seeds the RNG, but that only makes a given input frame
# reproducible -- the draw a tied row receives still depends on how many rows
# precede it, so a class assertion would be brittle to row count and order.
# Votes are unaffected by the seed and are strictly more sensitive: they catch
# a single-vote shift that argmax would hide.
check(
  "papp vote matrix matches the pre-refactor baseline",
  identical(dim(votes), dim(baseline)) &&
    isTRUE(all.equal(unname(votes), unname(baseline)))
)

# The seed added to calc_papp() only claims reproducibility for a given input
# frame. Check exactly that, and no more: it deliberately does NOT claim that a
# chemical keeps its class across different batches.
#
# Needs the full inputs: the fixture subset contains no tied chemical, so a
# fixture-based version would pass whether or not the seed were present.
tied_ids <- c("DTXSID4060109", "DTXSID8062575")
top2 <- t(apply(
  votes[match(tied_ids, descriptors$MoleculeID), , drop = FALSE],
  1,
  function(v) sort(v, decreasing = TRUE)[1:2]
))

# Guard the premise: these two are tied only so long as the model and the
# inputs stay as captured. If the tie disappears this check silently stops
# checking anything, so fail instead.
check(
  "the two reference chemicals are still vote-tied",
  isTRUE(all.equal(unname(top2[, 1]), unname(top2[, 2])))
)

first <- calc_papp(descriptors)$output
second <- calc_papp(descriptors)$output
rows <- match(tied_ids, first$MoleculeID)

check(
  "repeated calc_papp() calls on one frame agree",
  isTRUE(all.equal(second, first))
)
check(
  "repeated calls agree on the tied chemicals' class",
  identical(
    as.character(second$Pab.Class.Pred[rows]),
    as.character(first$Pab.Class.Pred[rows])
  )
)

if (length(failures) > 0) {
  stop(
    "Papp parity failed:\n  ",
    paste(failures, collapse = "\n  "),
    call. = FALSE
  )
}
cat("\nAll Papp parity checks passed.\n")
