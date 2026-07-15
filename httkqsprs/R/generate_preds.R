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

#' Generate predictions for Clint and Fup for new chemicals based on the models in Dawson et al. 2021.
#' This function will read in the necessary predictors for novel chemicals, standardize the parameters of the chemical according to the training set(s), and predict Clint and Fup for those chemicals.
#' The function requires OPERA model predictions and PaDEL descriptions for your chemicals of interest.
#'
#' OPERA predictors include:
#' "LogP"   "LogWS"  "LogBCF" "LogKM"  "MP"     "LogVP"  "LogD55" "LogD74" "LogOH"
#'
#' PaDEL descriptors include:
#' "CrippenLogP"       "nBase"             "XLogP"
#' "ETA_EtaP_F"        "ZMIC2"             "maxHBa"            "minsssN"           "AATS1i"
#' "ETA_dEpsilon_B"    "GATS1i"            "ZMIC1"             "SsssN"             "nAromBond"
#' "AATSC0p"           "minHBd"            "LipoaffinityIndex" "AATS3v"            "AATS2i"
#' "C2SP2"             "AATS4v"            "Kier2"             "AATS6m"            "AATS6v"
#' "minssCH2"          "AATS5v"            "AATS5i"            "ATSC2c"            "ATSC6c"
#' "ATSC3m"            "ATSC3e"            "AATSC0c"           "AATSC0v"           "MATS1c"
#' "MATS8c"            "GATS5c"            "GATS1e"            "GATS5e"            "BCUTc.1l"         "BCUTp.1l"          "BCUTp.1h"          "nBondsM"           "SpMin2_Bhm"        "SpMax2_Bhp"
#' "minHaaCH"          "minaaCH"           "IC1"               "MLFER_BH"          "piPC8"            "R_TpiPCTPC"
#'
#' @param Datalabel A character string that will be used to label the output files. This should be the same as the prefix of the OPERA and PaDEL descriptor files for your chemicals of interest.
#' @param output.path Optional output directory path. Defaults to `tempdir()`.
#' @param Operaversion A character string that specifies the version of OPERA used.
#' @param operapostfix A character string that specifies the postfix of the OPERA descriptor file for your chemicals of interest. The default is "-smi_OPERA2.9Pred.csv", which corresponds to the OPERA predictions for 200 chemicals included in this folder.
#' @param padelpostfix A character string that specifies the postfix of the PaDEL descriptor file for your chemicals of interest. The default is "_QSAR-ready_smi_PadelDesc.csv", which corresponds to the PaDEL descriptors for 200 chemicals included in this folder.
#' @param conn_str Unused placeholder for connection string compatibility.
#' @param chems Optional character vector of CICHEM identifiers. If provided,
#'   descriptors are queried via database helper functions instead of CSV files.
#'
#' @return A named list with:
#' \describe{
#'   \item{Clint}{Data frame returned by [calc_clint()].}
#'   \item{Fup}{Data frame returned by [calc_fup()].}
#' }
#'
#' @references
#' Dawson, Daniel E., et al. "Designing QSARs for parameters of high-throughput toxicokinetic models using open-source descriptors." Environmental science & technology 55.9 (2021): 6505-6517.
#'
#' Mansouri, Kamel, et al. "OPERA models for predicting physicochemical properties and environmental fate endpoints." Journal of cheminformatics 10.1 (2018): 10.
#'
#' Yap, Chun Wei. "PaDEL-descriptor: An open source software to calculate molecular descriptors and fingerprints." Journal of computational chemistry 32.7 (2011): 1466-1474.
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
  chems = NULL
) {
  if (is.null(output.path)) {
    output.path <- tempdir()
  }

  Descriptors <- httkqsprs::Descriptors
  Descriptors$Opera <- paste0(Descriptors$Opera, "_pred")

  if (is.null(chems)) {
    NEWOPERA <- paste0(Datalabel, operapostfix)
    NEWPADEL <- paste0(Datalabel, padelpostfix)

    Opera <- read.csv(NEWOPERA)
    Padel <- read.csv(NEWPADEL)

    Opera <- Opera[, c(1, which(names(Opera) %in% Descriptors$Opera))]
    Padel <- Padel[, c(1, which(names(Padel) %in% Descriptors$Padel))]
    chemlist <- merge(Opera, Padel, by.x = "MoleculeID", by.y = "Name", all.x = TRUE)
  } else {
    Padel <- get_padel(cichem_list = chems, descriptors = Descriptors$Padel)
    Opera <- get_opera(cichem_list = chems, descriptors = Descriptors$Opera)
    chemlist <- cbind(Padel, Opera)
  }

  desccols <- which(names(chemlist) %in% Descriptors$Padel | names(chemlist) %in% Descriptors$Opera)
  descnames <- names(chemlist)[desccols]

  clint <- calc_clint(
    chemlist = chemlist,
    descnames = descnames,
    datalabel = Datalabel,
    opera_version = Operaversion
  )

  fup <- calc_fup(
    chemlist = chemlist,
    datalabel = Datalabel,
    opera_version = Operaversion
  )

  list(
    Clint = clint,
    Fup = fup
  )
}
