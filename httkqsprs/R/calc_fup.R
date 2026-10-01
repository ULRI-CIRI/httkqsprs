#' Calculate Fup predictions and Roy AD metrics
#'
#' Harmonizes descriptor names to match the Fup model conventions,
#' standardizes model inputs, predicts transformed Fup, back-transforms
#' predictions, and computes Roy et al. applicability-domain metrics.
#'
#' @param descriptors A data frame keyed on `MoleculeID` containing at least
#'   the columns named by `required_descriptors("fup")`. Extra columns are
#'   ignored.
#'
#' @return A named list with two elements:
#' \describe{
#'   \item{output}{Data frame of complete-case Fup predictions with columns
#'     for `Fup.RF.pred` and Roy AD metrics (`SImin`, `SImax`, `SImean`,
#'     `SIsd`, `SI90`, `Outlier`).}
#'   \item{missing}{Data frame of chemicals excluded due to incomplete
#'     descriptor data.}
#' }
#'
#' @details
#' Workflow:
#' \enumerate{
#'   \item Derive model variables from `RF.fit$importance`.
#'   \item Subset `descriptors` to only the required OPERA and PaDEL columns.
#'   \item Prefix matching PaDEL descriptors with `padel_` and OPERA
#'   descriptors with `Opera_`.
#'   \item Restrict to required model descriptors and standardize using
#'   `fup.msd` means/SDs.
#'   \item Remove incomplete rows (returned in `$missing`).
#'   \item Predict transformed Fup and back-transform by squaring.
#'   \item Compute Roy AD metrics with [calc_roy_ad()].
#' }
#'
#' A zero-row `descriptors` frame returns zero-row `output` and `missing`
#' frames with the full column set rather than erroring.
#'
#' @author Daniel E. Dawson and John Wambaugh
#'
#' @references
#' Dawson, Daniel E., et al. (2021). Designing QSARs for parameters of
#' high-throughput toxicokinetic models using open-source descriptors.
#' \emph{Environmental Science & Technology}, 55(9), 6505-6517.
#'
#' @importFrom stats complete.cases
#' @export calc_fup
calc_fup <- function(descriptors) {
  # Load these from package in case user hasn't loaded whole package:
  RF.fit <- httkqsprs::RF.fit
  msd <- httkqsprs::fup.msd

  fupmodvars <- row.names(RF.fit$importance)
  needs <- required_descriptors("fup")
  fup_opera_desc <- needs$opera
  fup_padel_base <- needs$padel

  # Subset BEFORE the prefixing loop below, which renames every column it
  # is handed and would otherwise mis-prefix unrelated union columns.
  fupchemlist <- subset_descriptors(
    descriptors,
    c(fup_opera_desc, fup_padel_base)
  )

  Padeldesc <- which(
    names(fupchemlist) %in% stringr::str_remove(fupmodvars, "padel_")
  )
  Operadesc <- which(
    stringr::str_remove(names(fupchemlist), "_pred") %in%
      stringr::str_remove(fupmodvars, "Opera_")
  )
  names(fupchemlist) <- stringr::str_remove(names(fupchemlist), "_pred")

  for (i in Padeldesc) {
    names(fupchemlist)[i] <- paste0("padel_", names(fupchemlist)[i])
  }
  for (i in Operadesc) {
    names(fupchemlist)[i] <- paste0("Opera_", names(fupchemlist)[i])
  }

  # Restrict to only the columns required for the Fup model
  chemlistfupmodvars <- which(names(fupchemlist) %in% fupmodvars)
  IDcolstart <- 1
  IDcolend <- 1
  fupchemlist <- fupchemlist[, c(IDcolstart:IDcolend, chemlistfupmodvars)]

  # Standardize descriptors using means/SDs from training data
  chemlistfupsc <- fupchemlist
  for (i in fupmodvars) {
    sub1 <- subset(msd, select = c(names(msd) == i))
    chemlistfupsc[, i] <- (chemlistfupsc[, i] - sub1[1, 1]) / sub1[2, 1]
  }

  fupscComplete <- complete.cases(chemlistfupsc)
  chemlistsc_fup_narm <- chemlistfupsc[which(fupscComplete == TRUE), ]
  Incompletescfup <- chemlistfupsc[which(fupscComplete == FALSE), ]

  # randomForest's predict() errors on zero-row newdata, so short-circuit --
  # but still build the full column set. An empty result has to be a drop-in
  # for a populated one, or generate_preds() writes a CSV whose header row
  # differs from a normal run.
  if (nrow(chemlistsc_fup_narm) == 0) {
    chemlistsc_fup_narm$Fup.RF.pred <- numeric(0)
    SIdf <- calc_roy_ad(
      data = chemlistsc_fup_narm,
      model_vars = fupmodvars
    )
    return(list(
      output = data.frame(chemlistsc_fup_narm, SIdf),
      missing = Incompletescfup
    ))
  }

  # `RF.fit` is a regression forest and consumes no randomness, so the seed
  # is inert here. Kept for symmetry with the two classification endpoints,
  # and routed through with_seed() so it cannot disturb the caller's RNG.
  chemlistpredictfup <- with_seed(
    1255,
    stats::predict(RF.fit, chemlistsc_fup_narm)
  )
  chemlistsc_fup_narm$Fup.RF.pred <- chemlistpredictfup^2
  chemlistsc_fup_narm$Fup.RF.pred <- signif(
    chemlistsc_fup_narm$Fup.RF.pred,
    digits = 3
  )

  SIdf <- calc_roy_ad(
    data = chemlistsc_fup_narm,
    model_vars = fupmodvars
  )

  chemlistsc_fup_narm <- data.frame(chemlistsc_fup_narm, SIdf)

  return(list(output = chemlistsc_fup_narm, missing = Incompletescfup))
}
