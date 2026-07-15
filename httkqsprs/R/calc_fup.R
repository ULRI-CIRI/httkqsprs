#' Calculate Fup predictions and Roy AD metrics
#'
#' Harmonizes descriptor names to match the Fup model conventions, standardizes
#' Fup model inputs, predicts transformed Fup, back-transforms predictions,
#' computes Roy et al. applicability-domain metrics, and writes Fup output CSV
#' files.
#'
#' @param chemlist Data frame of input chemicals and descriptors. The first
#'   column is treated as an identifier and descriptor columns are transformed
#'   and matched to Fup model requirements.
#' @param datalabel Character scalar used in output filenames.
#' @param opera_version Character scalar used in output filenames.
#'
#' @return Data frame of complete-case Fup predictions with columns for
#'   `Fup.RF.pred` and Roy AD metrics (`SImin`, `SImax`, `SImean`, `SIsd`,
#'   `SI90`, `Outlier`).
#'
#' @details
#' Workflow:
#' \enumerate{
#'   \item Derive model variables from `RF.fit$importance`.
#'   \item Prefix matching PaDEL descriptors with `padel_` and OPERA
#'   descriptors with `Opera_`.
#'   \item Restrict to required model descriptors and standardize using
#'   `fup.msd` means/SDs.
#'   \item Remove incomplete rows and write an incomplete-records file.
#'   \item Predict transformed Fup and back-transform by squaring.
#'   \item Compute Roy AD metrics with [calc_roy_ad()].
#'   \item Write Fup predictions with AD annotations to disk.
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
calc_fup <- function(chemlist, datalabel, opera_version) {
  fupchemlist <- chemlist
  fupmodvars <- row.names(RF.fit$importance)
  msd <- fup.msd

  Padeldesc <- which(names(fupchemlist) %in% str_remove(fupmodvars, "padel_"))
  Operadesc <- which(str_remove(names(fupchemlist), "_pred") %in% str_remove(fupmodvars, "Opera_"))
  names(fupchemlist) <- str_remove(names(fupchemlist), "_pred")

  for (i in Padeldesc) {
    names(fupchemlist)[i] <- paste0("padel_", names(fupchemlist)[i])
  }
  for (i in Operadesc) {
    names(fupchemlist)[i] <- paste0("Opera_", names(fupchemlist)[i])
  }

  chemlistfupmodvars <- which(names(fupchemlist) %in% fupmodvars)
  IDcolstart <- 1
  IDcolend <- 1
  fupchemlist <- fupchemlist[, c(IDcolstart:IDcolend, chemlistfupmodvars)]

  chemlistfupsc <- fupchemlist
  for (i in fupmodvars) {
    sub1 <- subset(msd, select = c(names(msd) == i))
    chemlistfupsc[, i] <- (chemlistfupsc[, i] - sub1[1, 1]) / sub1[2, 1]
  }

  fupscComplete <- complete.cases(chemlistfupsc)
  chemlistsc_fup_narm <- chemlistfupsc[which(fupscComplete == TRUE), ]
  Incompletescfup <- chemlistfupsc[which(fupscComplete == FALSE), ]
  write.csv(
    Incompletescfup,
    file = paste0("Incomplete_Opera_PaDEL_fup_predictions_", datalabel, ".csv")
  )

  set.seed(1255)
  chemlistpredictfup <- predict(RF.fit, chemlistsc_fup_narm)
  chemlistsc_fup_narm$Fup.RF.pred <- chemlistpredictfup^2
  chemlistsc_fup_narm$Fup.RF.pred <- signif(chemlistsc_fup_narm$Fup.RF.pred, digits = 3)

  SIdf <- calc_roy_ad(
    data = chemlistsc_fup_narm,
    model_vars = fupmodvars
  )

  chemlistsc_fup_narm <- data.frame(chemlistsc_fup_narm, SIdf)
  write.csv(
    chemlistsc_fup_narm,
    file = paste0(
      "Novel_fup_predictions_with_AD_",
      datalabel,
      "_descs_from_OPERA",
      opera_version,
      ".csv"
    )
  )

  return(chemlistsc_fup_narm)
}
