test_that("generate_preds reproduces the golden output from CSVs", {
  got <- generate_preds(
    "subset",
    input.folder = test_path("fixtures"),
    operapostfix = "-opera.csv",
    padelpostfix = "-padel.csv",
    write.files = FALSE
  )

  for (endpoint in c("Clint", "Fup", "Papp")) {
    expected <- readRDS(test_path(
      "fixtures",
      paste0("expected-", tolower(endpoint), ".rds")
    ))
    expect_golden_output(got[[endpoint]]$output, expected$output, endpoint)
  }
})

test_that("write.files = TRUE writes five CSVs into output.folder", {
  out_dir <- withr::local_tempdir()

  generate_preds(
    "subset",
    input.folder = test_path("fixtures"),
    operapostfix = "-opera.csv",
    padelpostfix = "-padel.csv",
    write.files = TRUE,
    output.folder = out_dir
  )

  written <- list.files(out_dir, pattern = "\\.csv$")
  expect_length(written, 5)
  expect_true(any(grepl("^Novel_clint_predictions_with_AD_subset", written)))
  expect_true(any(grepl("^Incomplete_Clint_predictions_subset", written)))
  # Papp imputes rather than excluding, so it has no incomplete-cases file.
  expect_false(any(grepl("^Incomplete_papp_predictions", written)))
})

# Review Focus 3: a chemical in OPERA but absent from PaDEL
test_that("a chemical missing from PaDEL is reported, not silently predicted", {
  opera <- read.csv(test_path("fixtures", "subset-opera.csv"))
  padel <- read.csv(test_path("fixtures", "subset-padel.csv"))

  orphan <- setdiff(as.character(opera$MoleculeID), as.character(padel$Name))[1]
  if (is.na(orphan)) {
    orphan <- as.character(opera$MoleculeID)[1]
    padel <- padel[as.character(padel$Name) != orphan, , drop = FALSE]
  }

  tmp <- withr::local_tempdir()
  write.csv(opera, file.path(tmp, "orphan-opera.csv"), row.names = FALSE)
  write.csv(padel, file.path(tmp, "orphan-padel.csv"), row.names = FALSE)

  got <- generate_preds(
    "orphan",
    input.folder = tmp,
    operapostfix = "-opera.csv",
    padelpostfix = "-padel.csv",
    write.files = FALSE
  )

  expect_false(orphan %in% as.character(got$Clint$output$MoleculeID))
  expect_true(orphan %in% as.character(got$Clint$missing$MoleculeID))
})

test_that("descriptors absent from the user's CSV are backfilled as NA", {
  opera <- read.csv(test_path("fixtures", "subset-opera.csv"))
  padel <- read.csv(test_path("fixtures", "subset-padel.csv"))

  drop_col <- required_descriptors("clint")$padel[1]
  padel[[drop_col]] <- NULL

  tmp <- withr::local_tempdir()
  write.csv(opera, file.path(tmp, "thin-opera.csv"), row.names = FALSE)
  write.csv(padel, file.path(tmp, "thin-padel.csv"), row.names = FALSE)

  expect_no_error(
    generate_preds(
      "thin",
      input.folder = tmp,
      operapostfix = "-opera.csv",
      padelpostfix = "-padel.csv",
      write.files = FALSE
    )
  )
})

test_that("a missing descriptor file errors naming the path", {
  tmp <- withr::local_tempdir()

  expect_error(
    generate_preds(
      "absent",
      input.folder = tmp,
      operapostfix = "-opera.csv",
      padelpostfix = "-padel.csv",
      write.files = FALSE
    ),
    regexp = "absent-opera.csv",
    fixed = TRUE
  )
})

# Review Focus 7: the CSV reader must not source the six unavailable papp
# descriptors from OPERA, where five of them do exist. Doing so would change
# every Papp prediction.
test_that("papp descriptors unavailable in PaDEL stay constant after reading", {
  descriptors <- read_descriptor_csvs(
    datalabel = "subset",
    input.folder = test_path("fixtures"),
    operapostfix = "-opera.csv",
    padelpostfix = "-padel.csv"
  )

  prepared <- prepare_papp_descriptors(descriptors)
  for (nm in c(
    "RT_pred",
    "MDEC_23",
    "WTPT_3",
    "MDEO_11",
    "nbRotBd",
    "WTPT_4"
  )) {
    expect_length(unique(prepared[[nm]]), 1L)
  }
})
