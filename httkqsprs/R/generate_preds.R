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

#' Generate predictions for Clint, Fup, and Papp
#'
#' Reads the OPERA and PaDEL descriptor CSVs once, then hands the resulting
#' descriptor frame to [calc_clint()], [calc_fup()], and [calc_papp()].
#'
#' @param Datalabel A character string used to label input and output files.
#' @param Operaversion A character string specifying the OPERA version.
#' @param operapostfix Postfix of the OPERA descriptor file.
#' @param padelpostfix Postfix of the PaDEL descriptor file.
#' @param input.folder The folder containing the input files (OPERA and PaDEL descriptors).
#'   Defaults to \code{\link{getwd}}.
#' @param write.files If true, writes output files to `output.folder`. Defaults to true.
#' @param output.folder The folder where the output file is placed.
#'   Defaults to \code{\link{tempdir}}.
#'
#' @return A named list with:
#' \describe{
#'   \item{Clint}{Named list returned by [calc_clint()], with elements
#'     `$output` (complete-case predictions) and `$missing` (excluded
#'     incomplete cases).}
#'   \item{Fup}{Named list returned by [calc_fup()], with elements
#'     `$output` (complete-case predictions) and `$missing` (excluded
#'     incomplete cases).}
#'   \item{Papp}{Named list returned by [calc_papp()], with elements
#'     `$output` (predictions) and `$missing` (always `NULL`, as Papp uses
#'     imputation instead of exclusion).}
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
#' @export generate_preds
generate_preds <- function(
  Datalabel,
  Operaversion = "2.9.2",
  operapostfix = "-smi_OPERA2.9Pred.csv",
  padelpostfix = "_QSAR-ready_smi_PadelDesc.csv",
  input.folder = getwd(),
  write.files = TRUE,
  output.folder = tempdir()
) {
  descriptors <- read_descriptor_csvs(
    datalabel = Datalabel,
    input.folder = input.folder,
    operapostfix = operapostfix,
    padelpostfix = padelpostfix
  )

  clint <- calc_clint(descriptors)

  fup <- calc_fup(descriptors)

  papp <- calc_papp(descriptors)

  if (write.files) {
    cat("Outputs written to", output.folder, "\n")
    # write clint outputs
    write.csv(
      clint$missing,
      file = file.path(
        output.folder,
        paste0("Incomplete_Clint_predictions_", Datalabel, ".csv")
      )
    )
    write.csv(
      clint$output,
      file = file.path(
        output.folder,
        paste0(
          "Novel_clint_predictions_with_AD_",
          Datalabel,
          "_descs_from_OPERA",
          Operaversion,
          ".csv"
        )
      )
    )

    # write fup outputs
    write.csv(
      fup$missing,
      file = file.path(
        output.folder,
        paste0("Incomplete_fup_predictions_", Datalabel, ".csv")
      )
    )
    write.csv(
      fup$output,
      file = file.path(
        output.folder,
        paste0(
          "Novel_fup_predictions_with_AD_",
          Datalabel,
          "_descs_from_OPERA",
          Operaversion,
          ".csv"
        )
      )
    )

    # write papp outputs
    #
    # There is deliberately no "Incomplete_papp" file: `calc_papp()` mean-
    # imputes missing descriptors rather than excluding cases, so `$missing`
    # is always NULL and `write.csv(NULL)` produced a file whose entire
    # contents were `""`.
    write.csv(
      papp$output,
      file = file.path(
        output.folder,
        paste0(
          "Novel_papp_predictions_with_AD_",
          Datalabel,
          "_descs_from_OPERA",
          Operaversion,
          ".csv"
        )
      )
    )
  }

  return(list(
    Clint = clint,
    Fup = fup,
    Papp = papp
  ))
}
