# Builds the descriptor frame the way a caller would: read the fixture CSVs,
# take the union of what the three endpoints need, merge into one wide frame.
# This mirrors what pipelines-r's get_descriptors() produces from the database.
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

# Orders a frame by MoleculeID and restricts it to the golden column set, so
# expect_equal() compares content rather than row or column order.
align_to <- function(df, reference) {
  df[order(as.character(df$MoleculeID)), names(reference), drop = FALSE]
}
