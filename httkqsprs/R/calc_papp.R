#' Calculate Caco-2 apparent permeability (Papp) predictions
#'
#' Imputes missing descriptors with training-set means, calculates Roy et al.
#' applicability domain status, and predicts a Papp class with the selected
#' random forest model.
#'
#' The function also maps predicted bins to summary quantitative ranges in
#' `qspr.summary`, producing three numeric columns (`Pab.Quant.Pred.Median`,
#' `Pab.Quant.Pred.LowerCI`, `Pab.Quant.Pred.UpperCI`).
#'
#' @param descriptors A data frame keyed on `MoleculeID` containing at least
#'   the columns named by `required_descriptors("papp")`. Extra columns are
#'   ignored.
#'
#' @return A named list with two elements:
#' \describe{
#'   \item{output}{Data frame with one row per chemical and columns:
#'     `MoleculeID` (identifier carried over from the input frame),
#'     `Pab.Class.Pred` (predicted Papp class/bin),
#'     `Pab.Pred.AD` (applicability-domain flag; `1` = OUTSIDE the
#'     applicability domain, `0` = inside, matching the `Outlier` convention
#'     in [calc_roy_ad()]), and
#'     `Pab.Quant.Pred.Median` (median log Papp for the predicted bin),
#'     `Pab.Quant.Pred.LowerCI` (lower percentile bound), and
#'     `Pab.Quant.Pred.UpperCI` (upper percentile bound), all from `qspr.summary`.}
#'   \item{missing}{`NULL`; Papp handles missing descriptors via mean
#'     imputation rather than case exclusion.}
#' }
#'
#' @details
#' Required descriptor names are taken from `opt.desc` and expected training-set
#' means/SDs from `train_msd`. If a required descriptor is absent in the
#' supplied frame, it is created as `NA` and then imputed from `train_msd`
#' (row 1 means), matching the original workflow behavior.
#'
#' If `pKa_a_pred` and `pKa_b_pred` are present, `fraction_neutral` is
#' recalculated at pH 7.4 via [httk::calc_ionization()]. If ionization inputs
#' are absent, `fraction_neutral` is handled through mean imputation.
#'
#' Applicability domain follows the Roy et al. (2015) rule as implemented in
#' the source RMarkdown:
#'
#' * in-domain when `SImax <= 3`
#' * out-of-domain when `SImax > 3` and `SImin > 3`
#' * otherwise in/out based on `SInew = SImean + 1.28 * SIsd` threshold 3.
#'
#' @author Greg Honda and John Wambaugh
#'
#' @references
#' Honda, G., and Wambaugh, J. (unsubmitted). Machine learning QSPR for
#' Caco-2 permeability.
#'
#' Roy, K., Kar, S., and Ambure, P. (2015). On a simple approach for
#' determining applicability domain of QSAR models.
#' \emph{Chemometrics and Intelligent Laboratory Systems}, 145, 22-29.
#'
#' @export calc_papp
calc_papp <- function(descriptors) {
  # Load these from package in case user hasn't loaded whole package:
  papp_opt_desc <- httkqsprs::papp_opt_desc
  papp_classmodopt <- httkqsprs::papp_classmodopt
  papp_qspr_summary <- httkqsprs::papp_qspr_summary

  papp_desc <- prepare_papp_descriptors(descriptors)

  # `papp_classmodopt` is a legacy caret::train object. Its internal
  # `modelInfo$predict` closure was saved with `.GlobalEnv` as its enclosing
  # environment and calls `predict()` unqualified, so R resolves that call
  # starting in the CALLER's global environment. Any object named `predict`
  # there -- a user variable, or another package's function assigned globally
  # -- would be picked up instead of `stats::predict` and break the
  # prediction. Re-parent the closure onto an environment that supplies the
  # correct `predict` before its lookup can escape to the user's workspace.
  # This mutates our local copy only; the packaged data object is untouched.
  predict_env <- new.env(parent = globalenv())
  predict_env$predict <- stats::predict
  environment(papp_classmodopt$modelInfo$predict) <- predict_env

  pred <- stats::predict(papp_classmodopt, papp_desc)

  ad <- calc_roy_ad(
    data = papp_desc,
    model_vars = papp_opt_desc
  )

  papp_pred <- data.frame(
    MoleculeID = descriptors[["MoleculeID"]],
    Pab.Class.Pred = pred,
    Pab.Pred.AD = ad$Outlier,
    stringsAsFactors = FALSE
  )

  re_pattern <- "([0-9.]+)\\s*\\(([0-9.]+)\\s*-\\s*([0-9.]+)\\)"
  for (this_bin in sort(as.character(unique(papp_pred$Pab.Class.Pred)))) {
    bin_value <- papp_qspr_summary[paste0("Bin", this_bin), "LogPab3Bin"]
    parts <- regmatches(bin_value, regexec(re_pattern, bin_value))[[1]]
    rows <- as.character(papp_pred$Pab.Class.Pred) == this_bin
    papp_pred[rows, "Pab.Quant.Pred.Median"] <- parts[2]
    papp_pred[rows, "Pab.Quant.Pred.LowerCI"] <- parts[3]
    papp_pred[rows, "Pab.Quant.Pred.UpperCI"] <- parts[4]
  }
  papp_pred$Pab.Pred.AD <- as.integer(papp_pred$Pab.Pred.AD)
  papp_pred$Pab.Quant.Pred.Median <- as.numeric(papp_pred$Pab.Quant.Pred.Median)
  papp_pred$Pab.Quant.Pred.LowerCI <- as.numeric(
    papp_pred$Pab.Quant.Pred.LowerCI
  )
  papp_pred$Pab.Quant.Pred.UpperCI <- as.numeric(
    papp_pred$Pab.Quant.Pred.UpperCI
  )

  return(list(output = papp_pred, missing = NULL))
}

#' Prepare the standardized descriptor matrix for the Papp model
#'
#' Subsets `descriptors` to the Papp model's columns, derives
#' `fraction_neutral` from pKa via [httk::calc_ionization()], standardizes
#' against the training means/SDs, mean-imputes missing values, and clamps
#' infinities to 100 SDs.
#'
#' Exposed separately from [calc_papp()] so the random forest vote matrix can
#' be asserted directly. Votes are deterministic, whereas the predicted class
#' is not when two classes tie.
#'
#' @param descriptors A data frame keyed on `MoleculeID`.
#' @return A data frame of standardized model inputs, one row per input row.
#' @noRd
prepare_papp_descriptors <- function(descriptors) {
  papp_opt_desc <- httkqsprs::papp_opt_desc
  papp_train_msd <- httkqsprs::papp_train_msd

  # fraction_neutral is calculated from OPERA pKa by httk but is neither an
  # OPERA nor a PaDEL descriptor, so it is never retrieved.
  needs <- required_descriptors("papp")
  papp_df <- subset_descriptors(
    descriptors,
    c(needs$opera, needs$padel)
  )

  # Calculate fraction_neutral from pKa if available
  if (all(c("pKa_a_pred", "pKa_b_pred") %in% names(papp_df))) {
    ion_list <- lapply(seq_len(nrow(papp_df)), function(i) {
      httk::calc_ionization(
        pH = 7.4,
        pKa_Donor = papp_df[i, "pKa_a_pred"],
        pKa_Accept = papp_df[i, "pKa_b_pred"]
      )
    })

    if (length(ion_list) > 0) {
      ion_names <- names(ion_list[[1]])
      for (nm in ion_names) {
        papp_df[[nm]] <- vapply(ion_list, function(x) x[[nm]], numeric(1))
      }
    }
  }

  # Restrict to only the columns required for the Papp model
  papp_desc <- papp_df[, papp_opt_desc, drop = FALSE]

  # Standardize descriptors using means/SDs from training data
  for (this_col in papp_opt_desc) {
    if (is.numeric(papp_train_msd[1, this_col])) {
      papp_desc[, this_col] <-
        (papp_desc[, this_col] -
          papp_train_msd[1, this_col]) /
        papp_train_msd[2, this_col]
    }
  }

  # Assign NA values the mean (0 after standardization) for any missing descriptors:
  papp_desc[is.na(papp_desc)] <- 0
  # Set any infinite descriptor to 100 sd's (outside of DOA):
  inf_cols <- which(sapply(papp_desc, function(x) any(is.infinite(x))))
  for (col in inf_cols) {
    inf_rows <- which(is.infinite(papp_desc[[col]]))
    # Index `papp_train_msd` by NAME, as the standardization loop above does.
    # `col` is a position in `papp_desc`, and the two frames do not share a
    # column order, so indexing by position could read a different
    # descriptor's SD.
    this_col <- names(papp_desc)[col]
    papp_desc[[col]][inf_rows] <- as.numeric(papp_train_msd[2, this_col]) * 100
  }

  papp_desc
}
