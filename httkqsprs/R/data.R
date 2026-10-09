#' Random Forest model for Clint from Dawson et al. 2021
#'
#' This is a classification random forest model that predicts intrinsic hepatic clearance as occurring at one of three rates: slow, medium, or fast.
#'
#' @docType data
#' @references
#' Dawson, J. S., Wambaugh, J. F., Isaacs, K. K., & Setzer, R. W. (2021). A random forest model for predicting intrinsic hepatic clearance of organic chemicals. Environmental Science & Technology, 55(8), 4979-4988.
"ClintClass3Mod"

#' List of specific descriptors needed for the Clint and Fup QSPRS
#'
#' @docType data
#' @references
#' Dawson, J. S., Wambaugh, J. F., Isaacs, K. K., & Setzer, R. W. (2021). A random forest model for predicting intrinsic hepatic clearance of organic chemicals. Environmental Science & Technology, 55(8), 4979-4988.
"Descriptors"

#' Random Forest model for Fup from Dawson et al. 2021
#' This is a regression random forest model that predicts the fraction unbound in plasma (Fup) for organic chemicals.
#' @docType data
#' @references
#' Dawson, J. S., Wambaugh, J. F., Isaacs, K. K., & Setzer, R. W. (2021). A random forest model for predicting intrinsic hepatic clearance of organic chemicals. Environmental Science & Technology, 55(8), 4979-4988.
"RF.fit"

#' The mean value for each bin in the Dawson 2021 Clint model
#'
#' @docType data
#' @references
#' Dawson, J. S., Wambaugh, J. F., Isaacs, K. K., & Setzer, R. W. (2021). A random forest model for predicting intrinsic hepatic clearance of organic chemicals. Environmental Science & Technology, 55(8), 4979-4988.
"tmeanagtable"

#' The standard deviation of the values in each bin for the Dawson 2021 Clint model
#'
#' @docType data
#' @references
#' Dawson, J. S., Wambaugh, J. F., Isaacs, K. K., & Setzer, R. W. (2021). A random forest model for predicting intrinsic hepatic clearance of organic chemicals. Environmental Science & Technology, 55(8), 4979-4988.
"tsdagtable"

#' The mean and standard deviation of the descriptors in the training set for the Dawson 2021 Fup Model
#' @docType data
#' @references
#' Dawson, J. S., Wambaugh, J. F., Isaacs, K. K., & Setzer, R. W. (2021). A random forest model for predicting intrinsic hepatic clearance of organic chemicals. Environmental Science & Technology, 55(8), 4979-4988.
"fup.msd"

#' The mean and standard deviation of the descriptors in the training set for the Dawson 2021 Clint Model
#' @docType data
#' @references
#' Dawson, J. S., Wambaugh, J. F., Isaacs, K. K., & Setzer, R. W. (2021). A random forest model for predicting intrinsic hepatic clearance of organic chemicals. Environmental Science & Technology, 55(8), 4979-4988.
"clint.msd"

#' Optimal Caco-2 permeability (Papp) classification model
#'
#' A \pkg{caret} \code{train} object wrapping a classification random forest
#' that predicts log apparent membrane permeability as one of three bins.
#' Used by [calc_papp()].
#'
#' @docType data
#' @references
#' Honda, G. S., et al. (2025). Impact of gut permeability on estimates of oral
#' bioavailability in high throughput toxicokinetics. \emph{Toxicology in
#' Vitro}, 106150.
"papp_classmodopt"

#' Descriptors used by the optimal Papp model
#'
#' Character vector naming the 25 descriptors `papp_classmodopt` was fit on.
#' OPERA-derived names carry the `_pred` suffix; PaDEL names do not. These are
#' also the variables [calc_roy_ad()] evaluates for the Papp applicability
#' domain.
#'
#' @docType data
"papp_opt_desc"

#' Name of the selected Papp binning scheme
#'
#' Character scalar identifying which candidate binning scheme was chosen
#' during model selection. Its value, `"LogPab3Bin"`, is the column of
#' `papp_qspr_summary` that [calc_papp()] reads bin values from.
#'
#' @docType data
"papp_chosen_model"

#' Performance summary for the candidate Papp models
#'
#' Data frame comparing the candidate binning schemes (continuous, 2-bin,
#' 3-bin and 4-bin). Rows hold `Accuracy` and `Kappa` for each scheme,
#' followed by one row per bin giving that bin's median predicted permeability
#' and its lower and upper bounds. [calc_papp()] reads the quantitative
#' predictions for each predicted class from the `LogPab3Bin` column.
#'
#' @docType data
"papp_qspr_summary"

#' Descriptor means and standard deviations for the Papp training set
#'
#' Two-row data frame covering 98 descriptors: row 1 holds the training-set
#' mean and row 2 the standard deviation. Used to standardize incoming
#' descriptors to z-scores before prediction.
#'
#' @docType data
"papp_train_msd"
