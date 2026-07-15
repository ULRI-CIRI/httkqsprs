# This R script will allow a user to predict Fup and Clint values for chemicals based on the QSAR Models presented in Dawson et al. 2021: Designing QSARs for parameters of high throughput toxicokinetic models using open-source descriptors. Environmental Science and Technology.

# Data to accomplish this is contained in separate Clint and Fup random forest objects. We also have and use the means and standard deviations of the descriptors for training set used to create the models. This allows conversion of descriptor values into z-scores.

# This script will read in the necessary predictors for novel chemicals, standardize the parameters of the chemical according to the training set(s), and predict Clint and Fup for those chemicals.

# To fit predictions from the Clint and Fup models, you will need OPERA model predictions and PaDEL descriptions for your chemicals of interest.

### OPERA predictors include:

# "LogP"   "LogWS"  "LogBCF" "LogKM"  "MP"     "LogVP"  "LogD55" "LogD74" "LogOH"

### PaDEL descriptors include:

# "CrippenLogP"       "nBase"             "XLogP"             "AATS1v"            "AATS0i"
# "ETA_EtaP_F"        "ZMIC2"             "maxHBa"            "minsssN"           "AATS1i"
# "ETA_dEpsilon_B"    "GATS1i"            "ZMIC1"             "SsssN"             "nAromBond"
# "AATSC0p"           "minHBd"            "LipoaffinityIndex" "AATS3v"            "AATS2i"
# "C2SP2"             "AATS4v"            "Kier2"             "AATS6m"            "AATS6v"
# "minssCH2"          "AATS5v"            "AATS5i"            "ATSC2c"            "ATSC6c"
# "ATSC3m"            "ATSC3e"            "AATSC0c"           "AATSC0v"           "MATS1c"
# "MATS8c"            "GATS5c"            "GATS1e"            "GATS5e"            "BCUTc.1l"
# "BCUTp.1l"          "BCUTp.1h"          "nBondsM"           "SpMin2_Bhm"        "SpMax2_Bhp"
# "minHaaCH"          "minaaCH"           "IC1"               "MLFER_BH"          "piPC8"
# "R_TpiPCTPC"

# These sets are included in the file "CombinedDescriptors_DED050621.RData", included in this folder.

#' Generate predictions for Clint, Fup, and optionally Papp
#'
#' This function orchestrates Clint, Fup, and optional Papp prediction
#' workflows. Descriptor retrieval is delegated to [calc_clint()],
#' [calc_fup()], and [calc_papp()] so each workflow requests only the
#' descriptors it needs.
#'
#' @param Datalabel A character string used to label output files.
#' @param output.path Optional output directory path. Defaults to `tempdir()`.
#' @param Operaversion A character string specifying the OPERA version.
#' @param operapostfix Postfix of the OPERA descriptor file when reading from
#'   CSV.
#' @param padelpostfix Postfix of the PaDEL descriptor file when reading from
#'   CSV.
#' @param conn_str Optional PostgreSQL connection string for descriptor
#'   retrieval when `chems` is provided.
#' @param chems Optional character vector of CICHEM identifiers. If provided,
#'   descriptors are queried via database helper functions.
#' @param papp_model Optional fitted Caco-2 Papp classification model. If
#'   `NULL`, `generate_preds()` attempts to use `classmodopt` if available.
#' @param papp_model_label Character scalar indicating which `qspr.summary`
#'   column to use for class-to-quantitative mapping in [calc_papp()].
#'
#' @return A named list with:
#' \describe{
#'   \item{Clint}{Data frame returned by [calc_clint()].}
#'   \item{Fup}{Data frame returned by [calc_fup()].}
#'   \item{Papp}{Data frame returned by [calc_papp()] when available;
#'   otherwise `NULL`.}
#' }
#'
#' @references
#' Dawson, Daniel E., et al. "Designing QSARs for parameters of high-throughput
#' toxicokinetic models using open-source descriptors."
#' \emph{Environmental Science \& Technology} 55.9 (2021): 6505-6517.
#'
#' Mansouri, Kamel, et al. "OPERA models for predicting physicochemical
#' properties and environmental fate endpoints."
#' \emph{Journal of Cheminformatics} 10.1 (2018): 10.
#'
#' Yap, Chun Wei. "PaDEL-descriptor: An open source software to calculate
#' molecular descriptors and fingerprints."
#' \emph{Journal of Computational Chemistry} 32.7 (2011): 1466-1474.
#'
#' @author John Wambaugh
#'
#' @import randomForest
#' @import stringr
#' @import Rapp
#' @import DBI
#' @import RPostgres
#' @export generate_preds
generate_preds <- function(
  Datalabel,
  output.path = NULL,
  Operaversion = "2.9.2",
  operapostfix = "-smi_OPERA2.9Pred.csv",
  padelpostfix = "_QSAR-ready_smi_PadelDesc.csv",
  conn_str = NULL,
  chems = NULL,
  papp_model = NULL,
  papp_model_label = "LogPab3Bin"
) {
  if (is.null(output.path)) {
    output.path <- tempdir()
  }

  clint <- calc_clint(
    datalabel = Datalabel,
    opera_version = Operaversion,
    chems = chems,
    operapostfix = operapostfix,
    padelpostfix = padelpostfix,
    conn_str = conn_str
  )

  fup <- calc_fup(
    datalabel = Datalabel,
    opera_version = Operaversion,
    chems = chems,
    operapostfix = operapostfix,
    padelpostfix = padelpostfix,
    conn_str = conn_str
  )

  papp <- calc_papp(
    datalabel = Datalabel,
    opera_version = Operaversion,
    chems = chems,
    operapostfix = operapostfix,
    padelpostfix = padelpostfix,
    conn_str = conn_str,
    class_model = papp_model,
    model_label = papp_model_label
  )

  return(list(
    Clint = clint,
    Fup = fup,
    Papp = papp
  ))
}
