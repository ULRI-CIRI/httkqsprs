#' Read OPERA and PaDEL descriptor CSVs into one descriptor frame
#'
#' Reads the two descriptor files an external user supplies, backfills any
#' descriptor the models need but the files lack with `NA_real_`, and merges
#' them into the single wide frame that [calc_clint()], [calc_fup()], and
#' [calc_papp()] consume.
#'
#' The PaDEL file keys its identifier column as `Name` while OPERA uses
#' `MoleculeID`; the merge is a full outer join, so a chemical present in
#' only one of the two files survives with `NA` values from the other and is
#' later reported as incomplete rather than silently dropped. This matches
#' the frame `pipelines-r` builds from the database.
#'
#' Identifiers must be unique within each file. A duplicated key would fan
#' out the merge and yield more prediction rows than input chemicals.
#'
#' Descriptors are taken from whichever source [required_descriptors()]
#' assigns them to, never from the other file. Several PaDEL-assigned Papp
#' descriptors also appear as columns in the OPERA export; sourcing them from
#' there would change every Papp prediction, so they are deliberately
#' backfilled as `NA` and mean-imputed downstream instead.
#'
#' [generate_preds()] calls this and then all three `calc_*()` functions.
#' Call it directly when you want the descriptor frame itself -- to predict a
#' single endpoint, to inspect what was backfilled, or to merge in
#' descriptors from another source before predicting.
#'
#' @param datalabel Character scalar prefixing both filenames.
#' @param input.folder Directory containing the two files.
#' @param operapostfix Filename postfix of the OPERA CSV.
#' @param padelpostfix Filename postfix of the PaDEL CSV.
#' @return A data frame keyed on `MoleculeID`.
#'
#' @seealso [required_descriptors()] for the descriptor names each endpoint
#'   needs, and [generate_preds()] for the all-endpoint workflow.
#'
#' @examples
#' \dontrun{
#' descriptors <- read_descriptor_csvs(
#'   "NewHTTK_April_2026",
#'   input.folder = "path/to/descriptor/files",
#'   operapostfix = "-smi_OPERA2.9Pred.csv",
#'   padelpostfix = "_QSAR-ready_smi_PadelDesc.csv"
#' )
#' calc_fup(descriptors)$output
#' }
#'
#' @importFrom utils read.csv
#' @export read_descriptor_csvs
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

  require_key_column(Opera, "MoleculeID", opera_path)
  require_key_column(Padel, "Name", padel_path)

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

  # Full outer join, matching pipelines-r's get_descriptors(). A chemical
  # present in only one file survives with `NA` from the other and is
  # reported as incomplete downstream.
  merge(
    Opera,
    Padel,
    by.x = "MoleculeID",
    by.y = "Name",
    all = TRUE
  )
}

#' Fail loudly when a descriptor CSV lacks its identifier column
#'
#' The OPERA and PaDEL exports key on different column names. Without this
#' check a mis-keyed file reaches the column subset and fails with
#' `undefined columns selected`, which names neither the file nor the
#' column the user has to fix.
#'
#' Also rejects duplicate identifiers. A repeated key fans out the merge --
#' two PaDEL rows for one chemical silently produce two prediction rows for
#' it -- which no downstream step detects.
#'
#' @param df The data frame read from `path`.
#' @param col Name of the identifier column the file must carry.
#' @param path Path the frame was read from, for the error message.
#' @return `NULL`, invisibly. Called for its side effect.
#' @noRd
require_key_column <- function(df, col, path) {
  if (!col %in% names(df)) {
    stop(
      "Descriptor file is missing its `",
      col,
      "` identifier column: ",
      path,
      call. = FALSE
    )
  }

  dupes <- unique(df[[col]][duplicated(df[[col]])])
  if (length(dupes) > 0) {
    shown <- as.character(dupes)[seq_len(min(5L, length(dupes)))]
    stop(
      "Descriptor file has duplicate `",
      col,
      "` values: ",
      path,
      "\n  ",
      paste(shown, collapse = ", "),
      if (length(dupes) > length(shown)) {
        paste0(" (and ", length(dupes) - length(shown), " more)")
      },
      call. = FALSE
    )
  }

  invisible(NULL)
}
