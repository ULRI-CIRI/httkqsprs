#' Calculate Clint predictions and Roy AD metrics
#'
#' Standardizes descriptor inputs for the Clint random forest classifier,
#' predicts Clint bins, maps bins to median and SD clearance values from the
#' training data, and computes Roy et al. applicability-domain metrics.
#'
#' @param descriptors A data frame keyed on `MoleculeID` containing at least
#'   the columns named by `required_descriptors("clint")`. Extra columns are
#'   ignored.
#'
#' @return A named list with two elements:
#' \describe{
#'   \item{output}{Data frame of complete-case Clint predictions with columns
#'     for `ClintPredictBin`, `ClintPredictBin_MD`, `ClintPredictBin_SD`, and
#'     Roy AD metrics (`SImin`, `SImax`, `SImean`, `SIsd`, `SI90`, `Outlier`).}
#'   \item{missing}{Data frame of chemicals excluded due to incomplete
#'     descriptor data.}
#' }
#'
#' @details
#' Workflow:
#' \enumerate{
#'   \item Determine Clint-required descriptor names from `ClintClass3Mod`.
#'   \item Subset `descriptors` to only those OPERA and PaDEL columns.
#'   \item Standardize descriptors using `clint.msd` means/SDs.
#'   \item Restrict to `ClintClass3Mod` predictors.
#'   \item Remove incomplete rows (returned in `$missing`).
#'   \item Predict Clint bins using `predict(ClintClass3Mod, ...)`.
#'   \item Convert bins to median/SD clearance values using `tmeanagtable` and
#'   `tsdagtable`.
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
#' @export calc_clint
calc_clint <- function(descriptors) {
  # Load these from package in case user hasn't loaded whole package:
  ClintClass3Mod <- httkqsprs::ClintClass3Mod
  clint.msd <- httkqsprs::clint.msd
  tmeanagtable <- httkqsprs::tmeanagtable
  tsdagtable <- httkqsprs::tsdagtable

  needs <- required_descriptors("clint")
  clint_opera_desc <- needs$opera
  clint_padel_desc <- needs$padel
  clintmodvars <- row.names(importance(ClintClass3Mod))

  # Subset to this endpoint's columns before any further processing, so a
  # wide union frame behaves identically to a per-endpoint frame.
  chemlist <- subset_descriptors(
    descriptors,
    c(clint_padel_desc, clint_opera_desc)
  )

  # Standardize descriptors using means/SDs from training data
  msd <- clint.msd
  submsd <- msd[, which(names(msd) %in% names(chemlist))]

  chemlistsc <- chemlist
  descnames <- intersect(
    c(clint_padel_desc, clint_opera_desc),
    names(chemlistsc)
  )
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

  # randomForest's predict() errors on zero-row newdata, so short-circuit --
  # but still build the full column set. An empty result has to be a drop-in
  # for a populated one, or generate_preds() writes a CSV whose header row
  # differs from a normal run.
  if (nrow(chemlistsc_Clint_narm) == 0) {
    chemlistsc_Clint_narm$ClintPredictBin <- factor(
      character(0),
      levels = ClintClass3Mod$classes
    )
    chemlistsc_Clint_narm$ClintPredictBin_MD <- numeric(0)
    chemlistsc_Clint_narm$ClintPredictBin_SD <- numeric(0)
    SIdf <- calc_roy_ad(
      data = chemlistsc_Clint_narm,
      model_vars = clintmodvars
    )
    return(list(
      output = data.frame(chemlistsc_Clint_narm, SIdf),
      missing = IncompleteClint
    ))
  }

  # `ClintClass3Mod` is a classification forest, so randomForest draws from
  # the RNG to break a tied class vote. Seed for reproducibility, but restore
  # the caller's RNG stream afterwards rather than leaving our seed in place.
  chemlistpredictClint <- with_seed(
    1255,
    stats::predict(ClintClass3Mod, chemlistsc_Clint_narm)
  )
  chemlistsc_Clint_narm$ClintPredictBin <- chemlistpredictClint

  chemlistsc_Clint_narm$ClintPredictBin_MD <- ifelse(
    chemlistsc_Clint_narm$ClintPredictBin == 1,
    tmeanagtable[1, 2],
    ifelse(
      chemlistsc_Clint_narm$ClintPredictBin == 2,
      tmeanagtable[2, 2],
      tmeanagtable[3, 2]
    )
  )
  chemlistsc_Clint_narm$ClintPredictBin_SD <- ifelse(
    chemlistsc_Clint_narm$ClintPredictBin == 1,
    tsdagtable[1, 2],
    ifelse(
      chemlistsc_Clint_narm$ClintPredictBin == 2,
      tsdagtable[2, 2],
      tsdagtable[3, 2]
    )
  )

  chemlistsc_Clint_narm$ClintPredictBin_MD <- signif(
    chemlistsc_Clint_narm$ClintPredictBin_MD,
    digits = 3
  )
  chemlistsc_Clint_narm$ClintPredictBin_SD <- signif(
    chemlistsc_Clint_narm$ClintPredictBin_SD,
    digits = 3
  )

  SIdf <- calc_roy_ad(
    data = chemlistsc_Clint_narm,
    model_vars = clintmodvars
  )

  chemlistsc_Clint_narm <- data.frame(chemlistsc_Clint_narm, SIdf)

  return(list(output = chemlistsc_Clint_narm, missing = IncompleteClint))
}
