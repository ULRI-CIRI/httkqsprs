#' Calculate Clint predictions and Roy AD metrics
#'
#' Retrieves only the descriptors required by the Clint model, standardizes
#' descriptor inputs for the Clint random forest classifier, predicts Clint
#' bins, maps bins to median and SD clearance values from the training data,
#' computes Roy et al. applicability-domain metrics, and writes Clint output
#' CSV files.
#'
#' @param datalabel Character scalar used in output filenames.
#' @param opera_version Character scalar used in output filenames.
#' @param chems Optional character vector of CICHEM identifiers. If provided,
#'   descriptors are retrieved from the database using [get_padel()] and
#'   [get_opera()].
#' @param operapostfix Character postfix of the OPERA descriptor CSV when
#'   `chems` is `NULL`.
#' @param padelpostfix Character postfix of the PaDEL descriptor CSV when
#'   `chems` is `NULL`.
#' @param input.folder The folder containing the input files (OPERA and PaDEL descriptors).
#'   Defaults to \code{\link{getwd}}.
#' @param output.folder The folder where the output file is placed.
#'   Defaults to \code{\link{tempdir}}.
#'
#' @return Data frame of complete-case Clint predictions with columns for
#'   `ClintPredictBin`, `ClintPredictBin_MD`, `ClintPredictBin_SD`, and
#'   Roy AD metrics (`SImin`, `SImax`, `SImean`, `SIsd`, `SI90`, `Outlier`).
#'
#' @details
#' Workflow:
#' \enumerate{
#'   \item Determine Clint-required descriptor names from `ClintClass3Mod`.
#'   \item Retrieve only those OPERA and PaDEL descriptors from CSV files or
#'   database helpers.
#'   \item Standardize descriptors using `clint.msd` means/SDs.
#'   \item Restrict to `ClintClass3Mod` predictors.
#'   \item Remove incomplete rows and write an incomplete-records file.
#'   \item Predict Clint bins using `predict(ClintClass3Mod, ...)`.
#'   \item Convert bins to median/SD clearance values using `tmeanagtable` and
#'   `tsdagtable`.
#'   \item Compute Roy AD metrics with [calc_roy_ad()].
#'   \item Write Clint predictions with AD annotations to disk.
#' }
#'
#' @author Daniel E. Dawson and John Wambaugh
#'
#' @references
#' Dawson, Daniel E., et al. (2021). Designing QSARs for parameters of
#' high-throughput toxicokinetic models using open-source descriptors.
#' \emph{Environmental Science \& Technology}, 55(9), 6505-6517.
#'
#' @export calc_clint
calc_clint <- function(
  datalabel,
  opera_version,
  chems = NULL,
  operapostfix = "-smi_OPERA2.9Pred.csv",
  padelpostfix = "_QSAR-ready_smi_PadelDesc.csv",
  input.folder = getwd(),
  output.folder = tempdir()
  )
{
  # Load these from package in case user hasn't loaded whole package:
  Descriptors <- httkqsprs::Descriptors
  ClintClass3Mod <- httkqsprs::ClintClass3Mod
  clint.msd <- httkqsprs::clint.msd
  tmeanagtable <- httkqsprs::tmeanagtable
  tsdagtable <- httkqsprs::tsdagtable

  opera_desc_all <- paste0(Descriptors$Opera, "_pred")
  clintmodvars <- row.names(importance(ClintClass3Mod))

  clint_opera_desc <- intersect(opera_desc_all, clintmodvars)
  clint_padel_desc <- intersect(Descriptors$Padel, clintmodvars)

  if (is.null(chems)) {
    NEWOPERA <- paste0(input.folder, "/", datalabel, operapostfix)
    NEWPADEL <- paste0(input.folder, "/", datalabel, padelpostfix)

    Opera <- read.csv(NEWOPERA)
    Padel <- read.csv(NEWPADEL)

    missing_opera <- setdiff(clint_opera_desc, names(Opera))
    if (length(missing_opera) > 0) {
      for (nm in missing_opera) Opera[[nm]] <- NA_real_
    }

    missing_padel <- setdiff(clint_padel_desc, names(Padel))
    if (length(missing_padel) > 0) {
      for (nm in missing_padel) Padel[[nm]] <- NA_real_
    }

    Opera <- Opera[, c(1, which(names(Opera) %in% clint_opera_desc)), drop = FALSE]
    Padel <- Padel[, c(1, which(names(Padel) %in% clint_padel_desc)), drop = FALSE]
    chemlist <- merge(Opera, Padel, by.x = "MoleculeID", by.y = "Name", all.x = TRUE)
  } else {
    Padel <- get_padel(
      cichem_list = chems,
      descriptors = clint_padel_desc
    )
    Opera <- get_opera(
      cichem_list = chems,
      descriptors = clint_opera_desc
    )
    chemlist <- merge(Padel, Opera, by = "MoleculeID", all = TRUE)
  }

  # Standardize descriptors using means/SDs from training data
  msd <- clint.msd
  submsd <- msd[, which(names(msd) %in% names(chemlist))]

  chemlistsc <- chemlist
  descnames <- intersect(c(clint_padel_desc, clint_opera_desc), names(chemlistsc))
  for (i in descnames) {
    sub1 <- subset(submsd, select = c(names(submsd) == i))
    chemlistsc[, i] <- (chemlist[, i] - sub1[1, 1]) / sub1[2, 1]
  }

  chemlistClintmodvars <- which(names(chemlistsc) %in% clintmodvars)

  # Restrict to only the columns required for the Clint model
  IDcolstart <- 1
  IDcolend <- 1
  chemlistsc_Clint <- chemlistsc[, c(IDcolstart:IDcolend, chemlistClintmodvars)]

  ClintComplete <- complete.cases(chemlistsc_Clint)
  chemlistsc_Clint_narm <- chemlistsc_Clint[which(ClintComplete == TRUE), ]
  IncompleteClint <- chemlistsc[which(ClintComplete == FALSE), ]
  write.csv(
    IncompleteClint,
    file = paste0(output.folder,
                  "Incomplete_Opera_PaDEL_Clint_predictions_",
                  datalabel,
                  ".csv")
  )

  set.seed(1255)
  chemlistpredictClint <- predict(ClintClass3Mod, chemlistsc_Clint_narm)
  chemlistsc_Clint_narm$ClintPredictBin <- chemlistpredictClint

  chemlistsc_Clint_narm$ClintPredictBin_MD <- ifelse(
    chemlistsc_Clint_narm$ClintPredictBin == 1,
    tmeanagtable[1, 2],
    ifelse(chemlistsc_Clint_narm$ClintPredictBin == 2, tmeanagtable[2, 2], tmeanagtable[3, 2])
  )
  chemlistsc_Clint_narm$ClintPredictBin_SD <- ifelse(
    chemlistsc_Clint_narm$ClintPredictBin == 1,
    tsdagtable[1, 2],
    ifelse(chemlistsc_Clint_narm$ClintPredictBin == 2, tsdagtable[2, 2], tsdagtable[3, 2])
  )

  chemlistsc_Clint_narm$ClintPredictBin_MD <- signif(chemlistsc_Clint_narm$ClintPredictBin_MD, digits = 3)
  chemlistsc_Clint_narm$ClintPredictBin_SD <- signif(chemlistsc_Clint_narm$ClintPredictBin_SD, digits = 3)

  SIdf <- calc_roy_ad(
    data = chemlistsc_Clint_narm,
    model_vars = clintmodvars
  )

  chemlistsc_Clint_narm <- data.frame(chemlistsc_Clint_narm, SIdf)
  output.file <- paste0(
    output.folder,
    "Novel_clint_predictions_with_AD_",
    datalabel,
    "_descs_from_OPERA",
    opera_version,
    ".csv"
    )
  write.csv(
    chemlistsc_Clint_narm,
    file = output.file
    )
  cat("Clint preditions written to", output.file,"\n")

  return(chemlistsc_Clint_narm)
}
