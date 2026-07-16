#' Calculate Caco-2 apparent permeability (Papp) predictions
#'
#' Retrieves only the descriptors required by the Papp model workflow,
#' imputes missing descriptors with training-set means, calculates Roy et al.
#' applicability domain status, and predicts a Papp class with the selected
#' random forest model.
#'
#' The function also maps predicted bins to summary quantitative ranges in
#' `qspr.summary`, producing a character column (`Pab.Quant.Pred`) of the form
#' `"median,lower,upper"`.
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
#'
#' @return A data frame with one row per chemical and columns:
#'
#' * `DTXSID` (identifier copied from the first input column)
#' * `Pab.Class.Pred` (predicted Papp class/bin)
#' * `Pab.Pred.AD` (applicability-domain flag; `1` = in-domain, `0` = out-of-domain)
#' * `Pab.Quant.Pred` (comma-delimited quantitative summary from `qspr.summary`)
#'
#' @details
#' Required descriptor names are taken from `opt.desc` and expected training-set
#' means/SDs from `train_msd`. If a required descriptor is absent in retrieved
#' inputs, it is created as `NA` and then imputed from `train_msd` (row 1 means),
#' matching the original workflow behavior.
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
calc_papp <- function(
  datalabel,
  opera_version,
  chems = NULL,
  operapostfix = "-smi_OPERA2.9Pred.csv",
  padelpostfix = "_QSAR-ready_smi_PadelDesc.csv"
) {
  opt_desc <- get("opt.desc", inherits = TRUE)
  train_msd_local <- get("train_msd", inherits = TRUE)
  qspr_summary_local <- get("qspr.summary", inherits = TRUE)

  # fraction_neutral is calculated from OPERA pKa by httk but is neither an OPERA nor Padel descriptor
  papp_opera_desc <- unique(c(grep("_pred$", opt_desc, value = TRUE), "pKa_a_pred", "pKa_b_pred"))
  papp_padel_desc <- setdiff(opt_desc, c("fraction_neutral",papp_opera_desc))
  papp_mod_vars <- c(papp_opera_desc, papp_padel_desc, "fraction neutral")

  if (is.null(chems)) {
    NEWOPERA <- paste0(datalabel, operapostfix)
    NEWPADEL <- paste0(datalabel, padelpostfix)

    Opera <- read.csv(NEWOPERA)
    Padel <- read.csv(NEWPADEL)

    missing_opera <- setdiff(papp_opera_desc, names(Opera))
    if (length(missing_opera) > 0) {
      for (nm in missing_opera) Opera[[nm]] <- NA_real_
    }

    missing_padel <- setdiff(papp_padel_desc, names(Padel))
    if (length(missing_padel) > 0) {
      for (nm in missing_padel) Padel[[nm]] <- NA_real_
    }

    Opera <- Opera[, c(1, which(names(Opera) %in% papp_opera_desc)), drop = FALSE]
    Padel <- Padel[, c(1, which(names(Padel) %in% papp_padel_desc)), drop = FALSE]
    papp_df <- merge(Opera, Padel, by.x = "MoleculeID", by.y = "Name", all.x = TRUE)
  } else {
    Padel <- get_padel(
      cichem_list = chems,
      descriptors = papp_padel_desc
    )
    Opera <- get_opera(
      cichem_list = chems,
      descriptors = papp_opera_desc
    )
    papp_df <- merge(Padel, Opera, by = "MoleculeID", all = TRUE)
  }

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
  papp_desc <- papp_df[, opt_desc, drop = FALSE]

  # Standardize descriptors using means/SDs from training data
  for (this_col in opt_desc) {
    if (is.numeric(train_msd_local[1, this_col])) {
      papp_desc[, this_col] <- 
        (papp_desc[, this_col] - 
        train_msd_local[1, this_col]) /
        train_msd_local[2, this_col]
    }
  }

  # Assign NA values the mean (0 after standardization) for any missing descriptors:
  papp_desc[is.na(papp_desc)] <- 0

  browser()
  pred <- predict(classmodopt, papp_desc)

  ad <- calc_roy_ad(
    data = papp_desc,
    model_vars = papp_mod_vars
  )

  papp_pred <- data.frame(
   MoleculeID = papp_df$MoleculeI,
    Pab.Class.Pred = pred,
    Pab.Pred.AD = ad$Outlier,
    stringsAsFactors = FALSE
  )

  for (this_bin in sort(as.character(unique(papp_pred$Pab.Class.Pred)))) {
    bin_value <- qspr_summary_local[paste0("Bin", this_bin), "LogPab3Bin"]
    bin_value <- gsub(" \\(", ",", bin_value)
    bin_value <- gsub(" - ", ",", bin_value)
    bin_value <- gsub("\\)", "", bin_value)
    papp_pred[as.character(papp_pred$Pab.Class.Pred) == this_bin, "Pab.Quant.Pred"] <- bin_value
  }

  write.csv(
    papp_pred,
    file = paste0(
      "Novel_papp_predictions_with_AD_",
      datalabel,
      "_descs_from_OPERA",
      opera_version,
      ".csv"
    )
  )

  return(papp_pred)
}
