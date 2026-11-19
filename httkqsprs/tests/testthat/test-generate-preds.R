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

test_that("a mis-keyed OPERA file errors naming the file and the column", {
  opera <- read.csv(test_path("fixtures", "subset-opera.csv"))
  padel <- read.csv(test_path("fixtures", "subset-padel.csv"))
  names(opera)[names(opera) == "MoleculeID"] <- "DTXSID"

  tmp <- withr::local_tempdir()
  write.csv(opera, file.path(tmp, "miskey-opera.csv"), row.names = FALSE)
  write.csv(padel, file.path(tmp, "miskey-padel.csv"), row.names = FALSE)

  expect_error(
    generate_preds(
      "miskey",
      input.folder = tmp,
      operapostfix = "-opera.csv",
      padelpostfix = "-padel.csv",
      write.files = FALSE
    ),
    regexp = "MoleculeID.*miskey-opera\\.csv"
  )
})

test_that("a mis-keyed PaDEL file errors naming the file and the column", {
  opera <- read.csv(test_path("fixtures", "subset-opera.csv"))
  padel <- read.csv(test_path("fixtures", "subset-padel.csv"))
  names(padel)[names(padel) == "Name"] <- "MoleculeID"

  tmp <- withr::local_tempdir()
  write.csv(opera, file.path(tmp, "miskey2-opera.csv"), row.names = FALSE)
  write.csv(padel, file.path(tmp, "miskey2-padel.csv"), row.names = FALSE)

  expect_error(
    generate_preds(
      "miskey2",
      input.folder = tmp,
      operapostfix = "-opera.csv",
      padelpostfix = "-padel.csv",
      write.files = FALSE
    ),
    regexp = "Name.*miskey2-padel\\.csv"
  )
})

test_that("a chemical missing from OPERA is reported, not silently dropped", {
  opera <- read.csv(test_path("fixtures", "subset-opera.csv"))
  padel <- read.csv(test_path("fixtures", "subset-padel.csv"))

  orphan <- as.character(padel$Name)[1]
  opera <- opera[as.character(opera$MoleculeID) != orphan, , drop = FALSE]

  tmp <- withr::local_tempdir()
  write.csv(opera, file.path(tmp, "orphan2-opera.csv"), row.names = FALSE)
  write.csv(padel, file.path(tmp, "orphan2-padel.csv"), row.names = FALSE)

  got <- generate_preds(
    "orphan2",
    input.folder = tmp,
    operapostfix = "-opera.csv",
    padelpostfix = "-padel.csv",
    write.files = FALSE
  )

  expect_false(orphan %in% as.character(got$Clint$output$MoleculeID))
  expect_true(orphan %in% as.character(got$Clint$missing$MoleculeID))
})

test_that("a duplicated identifier errors instead of fanning out the merge", {
  opera <- read.csv(test_path("fixtures", "subset-opera.csv"))
  padel <- read.csv(test_path("fixtures", "subset-padel.csv"))
  padel <- rbind(padel, padel[1, , drop = FALSE])

  tmp <- withr::local_tempdir()
  write.csv(opera, file.path(tmp, "dupe-opera.csv"), row.names = FALSE)
  write.csv(padel, file.path(tmp, "dupe-padel.csv"), row.names = FALSE)

  expect_error(
    generate_preds(
      "dupe",
      input.folder = tmp,
      operapostfix = "-opera.csv",
      padelpostfix = "-padel.csv",
      write.files = FALSE
    ),
    regexp = "duplicate `Name`"
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
