#' Calculate Clint predictions and Roy AD metrics
#'
#' Standardizes descriptor inputs for the Clint random forest classifier,
#' predicts Clint bins, maps bins to median and SD clearance values from the
#' training data, computes Roy et al. applicability-domain metrics, and writes
#' Clint output CSV files.
#'
#' @param chemlist Data frame of input chemicals and descriptors. The first
#'   column is treated as an identifier and descriptor columns are matched to
#'   the Clint model requirements.
#' @param descnames Character vector of descriptor column names to standardize
#'   using `clint.msd`.
#' @param datalabel Character scalar used in output filenames.
#' @param opera_version Character scalar used in output filenames.
#'
#' @return Data frame of complete-case Clint predictions with columns for
#'   `ClintPredictBin`, `ClintPredictBin_MD`, `ClintPredictBin_SD`, and
#'   Roy AD metrics (`SImin`, `SImax`, `SImean`, `SIsd`, `SI90`, `Outlier`).
#'
#' @details
#' Workflow:
#' \enumerate{
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
#' @keywords internal
calc_clint <- function(chemlist, descnames, datalabel, opera_version) {
  msd <- clint.msd
  submsd <- msd[, which(names(msd) %in% names(chemlist))]

  chemlistsc <- chemlist
  for (i in descnames) {
    sub1 <- subset(submsd, select = c(names(submsd) == i))
    chemlistsc[, i] <- (chemlist[, i] - sub1[1, 1]) / sub1[2, 1]
  }

  Clintmodvars <- row.names(importance(ClintClass3Mod))
  chemlistClintmodvars <- which(names(chemlistsc) %in% Clintmodvars)

  IDcolstart <- 1
  IDcolend <- 1
  chemlistsc_Clint <- chemlistsc[, c(IDcolstart:IDcolend, chemlistClintmodvars)]

  ClintComplete <- complete.cases(chemlistsc_Clint)
  chemlistsc_Clint_narm <- chemlistsc_Clint[which(ClintComplete == TRUE), ]
  IncompleteClint <- chemlistsc[which(ClintComplete == FALSE), ]
  write.csv(
    IncompleteClint,
    file = paste0("Incomplete_Opera_PaDEL_Clint_predictions_", datalabel, ".csv")
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
    model_vars = Clintmodvars
  )

  chemlistsc_Clint_narm <- data.frame(chemlistsc_Clint_narm, SIdf)
  write.csv(
    chemlistsc_Clint_narm,
    file = paste0(
      "Novel_clint_predictions_with_AD_",
      datalabel,
      "_descs_from_OPERA",
      opera_version,
      ".csv"
    )
  )

  chemlistsc_Clint_narm
}
