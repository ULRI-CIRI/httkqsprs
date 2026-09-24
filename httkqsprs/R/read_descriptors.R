#' Read OPERA and PaDEL descriptor CSVs into one descriptor frame
#'
#' Reads the two descriptor files an external user supplies, backfills any
#' descriptor the models need but the files lack with `NA_real_`, and merges
#' them into the single wide frame that [calc_clint()], [calc_fup()], and
#' [calc_papp()] consume.
#'
#' The PaDEL file keys its identifier column as `Name` while OPERA uses
#' `MoleculeID`; the merge is left-outer on OPERA, so a chemical present in
#' OPERA but absent from PaDEL survives with `NA` PaDEL values and is later
#' reported as incomplete rather than predicted.
#'
#' Descriptors are taken from whichever source [required_descriptors()]
#' assigns them to, never from the other file. Several PaDEL-assigned Papp
#' descriptors also appear as columns in the OPERA export; sourcing them from
#' there would change every Papp prediction, so they are deliberately
#' backfilled as `NA` and mean-imputed downstream instead.
#'
#' @param datalabel Character scalar prefixing both filenames.
#' @param input.folder Directory containing the two files.
#' @param operapostfix Filename postfix of the OPERA CSV.
#' @param padelpostfix Filename postfix of the PaDEL CSV.
#' @return A data frame keyed on `MoleculeID`.
#' @noRd
read_descriptor_csvs <- function(
  datalabel,
  input.folder,
  operapostfix,
  padelpostfix
) {
  opera_path <- file.path(input.folder, paste0(datalabel, operapostfix))
  padel_path <- file.path(input.folder, paste0(datalabel, padelpostfix))

  for (p in c(opera_path, padel_path)) {
    if (!file.exists(p)) {
      stop("Descriptor file not found: ", p, call. = FALSE)
    }
  }

  Opera <- read.csv(opera_path)
  Padel <- read.csv(padel_path)

  needs <- lapply(c("clint", "fup", "papp"), required_descriptors)
  opera_desc <- unique(unlist(lapply(needs, `[[`, "opera")))
  padel_desc <- unique(unlist(lapply(needs, `[[`, "padel")))

  # Backfill descriptors the user's files do not carry.
  for (nm in setdiff(opera_desc, names(Opera))) {
    Opera[[nm]] <- NA_real_
  }
  for (nm in setdiff(padel_desc, names(Padel))) {
    Padel[[nm]] <- NA_real_
  }

  Opera <- Opera[, c("MoleculeID", opera_desc), drop = FALSE]
  Padel <- Padel[, c("Name", padel_desc), drop = FALSE]

  merge(
    Opera,
    Padel,
    by.x = "MoleculeID",
    by.y = "Name",
    all.x = TRUE
  )
}
