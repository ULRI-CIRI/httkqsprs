load_fixture_descriptors <- function() {
  opera <- read.csv(test_path("fixtures", "subset-opera.csv"))
  padel <- read.csv(test_path("fixtures", "subset-padel.csv"))
  names(padel)[names(padel) == "Name"] <- "MoleculeID"

  needs <- lapply(c("clint", "fup", "papp"), required_descriptors)
  opera_desc <- unique(unlist(lapply(needs, `[[`, "opera")))
  padel_desc <- unique(unlist(lapply(needs, `[[`, "padel")))

  for (nm in setdiff(opera_desc, names(opera))) {
    opera[[nm]] <- NA_real_
  }
  for (nm in setdiff(padel_desc, names(padel))) {
    padel[[nm]] <- NA_real_
  }

  merge(
    opera[, c("MoleculeID", opera_desc), drop = FALSE],
    padel[, c("MoleculeID", padel_desc), drop = FALSE],
    by = "MoleculeID",
    all = TRUE
  )
}

# Asserts that an endpoint's zero-row `$output` is a drop-in for a populated
# one: same columns in the same order, same types, same factor levels.
#
# Each of the three endpoints short-circuits before its model call on empty
# input and hand-builds the result columns, so without this the empty frames
# would silently drift from the code paths that build the populated result --
# and generate_preds() would write a CSV whose header differs from a normal
# run. rbind() enforces column names, order and types at once; row names are
# not part of that contract.
expect_empty_output_parity <- function(empty, full) {
  expect_equal(nrow(empty), 0L)
  expect_identical(names(empty), names(full))
  expect_identical(
    vapply(empty, function(x) class(x)[1], character(1)),
    vapply(full, function(x) class(x)[1], character(1))
  )

  for (nm in names(full)[vapply(full, is.factor, logical(1))]) {
    expect_identical(levels(empty[[nm]]), levels(full[[nm]]))
  }

  expect_equal(rbind(empty, full), full, ignore_attr = "row.names")
}
