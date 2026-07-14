# This R script will allow a user to predict Fup and Clint values for chemicals based on the QSAR Models presented in Dawson et al. 2021: Designing QSARs for parameters of high throughput toxicokinetic models using open-source descriptors. Environmental Science and Technology.

# Data to accomplish this is contained in separate Clint and Fup random forest objects. We also have and use the means and standard deviations of the desscriptors for training set used to create the models. This allows conversion of descriptor values into z-scores.

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
#' @param Operaversion A character string that specifies the version of OPERA used
#' @param operapostfix A character string that specifies the postfix of the OPERA descriptor file for your chemicals of interest. The default is "-smi_OPERA2.9Pred.csv", which corresponds to the OPERA predictions for 200 chemicals included in this folder.
#' @param padelpostfix A character string that specifies the postfix of the PaDEL descriptor file for your chemicals of interest. The default is "_QSAR-ready_smi_PadelDesc.csv", which corresponds to the PaDEL descriptors for 200 chemicals included in this folder.
#' @return This function will output two csv files: one with the Clint predictions and applicability domain results, and one with the Fup predictions and applicability domain results. The files will be labeled with the Datalabel parameter and the version of OPERA used.
#'
#' @references
#' Dawson, Daniel E., et al. "Designing QSARs for parameters of high-throughput toxicokinetic models using open-source descriptors." Environmental science & technology 55.9 (2021): 6505-6517.
#'
#' Mansouri, Kamel, et al. "OPERA models for predicting physicochemical properties and environmental fate endpoints." Journal of cheminformatics 10.1 (2018): 10.
#'
#' Yap, Chun Wei. "PaDEL‐descriptor: An open source software to calculate molecular descriptors and fingerprints." Journal of computational chemistry 32.7 (2011): 1466-1474.
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

  ## LOAD PACKAGES
  #packages <- c("readxl", "httk","randomForest", "stringr","dplyr", "ctxR")
  #packages <- c("randomForest", "stringr","dplyr")
  #sapply(packages, require, character.only=TRUE)

  Descriptors <- httkqsprs::Descriptors
  #load("Dawson_et_al_2021_PredictionWorkflow/CombinedDescriptors_DED050621.RData") # descriptors in both models
  Descriptors$Opera <- paste0(Descriptors$Opera, "_pred")

  if (is.null(chems)) {
    ## Specify files with descriptors for new chemicals
    NEWOPERA <- paste0(Datalabel, operapostfix)
    NEWPADEL <- paste0(Datalabel, padelpostfix)

    #adding the new opera predictions
    Opera <- read.csv(NEWOPERA)

    #adding new padel predictors
    Padel <- read.csv(NEWPADEL)

    Opera <- Opera[, c(1, which(names(Opera) %in% Descriptors$Opera))]
    Padel <- Padel[, c(1, which(names(Padel) %in% Descriptors$Padel))]
    #Merge with truncated opera and padel lists
    chemlist <- merge(
      Opera,
      Padel,
      by.x = "MoleculeID",
      by.y = "Name",
      all.x = TRUE
    )
  } else {
    Padel <- get_padel(cichem_list = chems, descriptors = Descriptors$Padel)

    Opera <- get_opera(cichem_list = chems, descriptors = Descriptors$Opera)
    chemlist <- cbind(Padel, Opera)
  }

  desccols <- which(
    names(chemlist) %in%
      Descriptors$Padel |
      names(chemlist) %in% Descriptors$Opera
  )
  Descnames <- names(chemlist)[desccols]

  #
  # Intrinsic Clearance (Clint)
  #

  # Read in clint model object and training data mean and std.
  # Normalize your data using the training data. Then, use the predict function to predict clint bin. Use the training data from the included Revised S2 file from the Dawson et al. 2021 paper to calculate the bin median values. Finally, determine whether clint predictions are in or out of the AD, using the the method from Roy et al. 2015.

  #load("ClintModel_3Bin_040121.RData")
  msd <- httkqsprs::clint.msd
  submsd <- msd[, which(names(msd) %in% names(chemlist))]

  ##Standardize by training set mean and sd
  chemlistsc <- chemlist
  for (i in Descnames) {
    sub1 <- subset(submsd, select = c(names(submsd) == i))
    chemlistsc[, i] <- (chemlist[, i] - sub1[1, 1]) / sub1[2, 1]
  }

  #Subset to only Clint model
  Clintmodvars <- row.names(importance(httkqsprs::ClintClass3Mod))
  chemlistClintmodvars <- which(names(chemlistsc) %in% Clintmodvars)

  IDcolstart <- 1
  IDcolend <- 1
  chemlistsc_Clint <- chemlistsc[, c(IDcolstart:IDcolend, chemlistClintmodvars)]

  #filter for only important descriptors (drop the rest)

  #Take out incomplete descriptors (the issue is here that we are getting rid of incomplete descriptors i.e. all the 200 new chemicals)
  ClintComplete <- complete.cases(chemlistsc_Clint)
  chemlistsc_Clint_narm <- chemlistsc_Clint[which(ClintComplete == TRUE), ]
  IncompleteClint <- chemlistsc[which(ClintComplete == FALSE), ]
  # write.csv(
  #   IncompleteClint,
  #   file = paste0(
  #     "Incomplete_Opera_PaDEL_Clint_predictions_",
  #     Datalabel,
  #     ".csv"
  #   )
  # )

  #Make Predictions
  set.seed(1255)
  chemlistpredictClint <- predict(
    httkqsprs::ClintClass3Mod,
    chemlistsc_Clint_narm
  )
  chemlistsc_Clint_narm$ClintPredictBin <- chemlistpredictClint

  #Convert to clearance ul/10^6 hepatic cells based on training data
  #training <- httkqsprs::DawsonSupTable2
  #training$Bin3.Adj=ifelse(training$Bin3.Adj==4,3,training$Bin3.Adj)
  #tmeanagtable=aggregate(training$Clearance.Adj~training$Bin3.Adj, FUN="median")
  #tsdagtable=aggregate(training$Clearance.Adj~training$Bin3.Adj, FUN="sd")
  chemlistsc_Clint_narm$ClintPredictBin_MD <- ifelse(
    chemlistsc_Clint_narm$ClintPredictBin == 1,
    httkqsprs::tmeanagtable[1, 2],
    ifelse(
      chemlistsc_Clint_narm$ClintPredictBin == 2,
      httkqsprs::tmeanagtable[2, 2],
      httkqsprs::tmeanagtable[3, 2]
    )
  )
  chemlistsc_Clint_narm$ClintPredictBin_SD <- ifelse(
    chemlistsc_Clint_narm$ClintPredictBin == 1,
    httkqsprs::tsdagtable[1, 2],
    ifelse(
      chemlistsc_Clint_narm$ClintPredictBin == 2,
      httkqsprs::tsdagtable[2, 2],
      httkqsprs::tsdagtable[3, 2]
    )
  )

  ## Apply applicability domain
  # Using methodology of Roy et al 2015, apply applicability domain of Clint model to predictions of new chemicals and export

  a=chemlistsc_Clint_narm
  b=a[,c("MoleculeID")]
  a=a[,which(names(a)%in%Clintmodvars)]
  a=abs(a)
  SImin=apply(a,1,min) #Find the min, max, sd, and mean
  SImax=apply(a,1,max)
  SImean=apply(a,1,mean)
  SIsd=apply(a,1,sd)


  #Several are NA when SD is calculated
  SIdf=data.frame(SImin, SImax, SImean, SIsd)
  SIdf$SI90=SIdf$SImean + (1.28 * SIdf$SIsd)
  SIdf$Outlier=0 #something is assumed to be inside the AD unless it it found to not be

  #Based on algorithm specified in Roy et al. (2015)
  for(i in 1:length(SIdf[,1])){
    if(SIdf$SImax[i]<3){ next } else
      if (SIdf$SImin[i] > 3) {
        SIdf$Outlier[i] = 1 } else if
    (SIdf$SImean[i] + (1.28 * SIdf$SIsd[i]) > 3){
      SIdf$Outlier[i]=1}
  }

  chemlistsc_Clint_narm=data.frame(chemlistsc_Clint_narm, SIdf)
  # write.csv(chemlistsc_Clint_narm,
  #           file=paste0("Novel_clint_predictions_with_AD_",
  #                       Datalabel,
  #                       "_descs_from_OPERA",
  #                       Operaversion,
  #                       ".csv"))

  #
  ## Fraction unbound by plasma(fup)
  #

  # Read in the fup model object and training data mean and std.
  # Normalize your data using the training data. Then, use the predict function to predict fup values. After this, determine whether fup predictions are in or out of the AD, using the the method from Roy et al. 2015.
  fupchemlist <- chemlist
  #load("fup_RFmodel_30desc_select_by_sqrt_transform.RData")
  fupmodvars <- row.names(httkqsprs::RF.fit$importance)
  msd <- httkqsprs::fup.msd

  #substitute the correct names into the chemlist
  #Here, adapt descriptor names to the format expected in the fup random forest file.
  Padeldesc <- which(names(fupchemlist) %in% str_remove(fupmodvars, 'padel_'))
  Operadesc <- which(
    str_remove(names(fupchemlist), "_pred") %in%
      str_remove(fupmodvars, 'Opera_')
  )
  names(fupchemlist) <- str_remove(names(fupchemlist), '_pred')

  for (i in Padeldesc) {
    names(fupchemlist)[i] <- paste0("padel_", names(fupchemlist)[i])
  }
  for (i in Operadesc) {
    names(fupchemlist)[i] <- paste0("Opera_", names(fupchemlist)[i])
  }

  #Subset to only Fup model
  chemlistfupmodvars <- which(names(fupchemlist) %in% fupmodvars)
  IDcolstart <- 1
  IDcolend <- 1
  fupchemlist <- fupchemlist[, c(IDcolstart:IDcolend, chemlistfupmodvars)]

  ##Standardize by training set mean and sd
  chemlistfupsc <- fupchemlist
  for (i in fupmodvars) {
    sub1 <- subset(msd, select = c(names(msd) == i))
    chemlistfupsc[, i] <- (chemlistfupsc[, i] - sub1[1, 1]) / sub1[2, 1]
  }

  #Take out incomplete descriptors
  fupscComplete <- complete.cases(chemlistfupsc)
  chemlistsc_fup_narm <- chemlistfupsc[which(fupscComplete == TRUE), ]
  Incompletescfup <- chemlistfupsc[which(fupscComplete == FALSE), ]
  # write.csv(
  #   Incompletescfup,
  #   file = paste0("Incomplete_Opera_PaDEL_fup_predictions_", Datalabel, ".csv")
  # )

  #Make Predictions with only five chemicals
  set.seed(1255)
  chemlistpredictfup <- predict(httkqsprs::RF.fit, chemlistsc_fup_narm)
  chemlistsc_fup_narm$Fup.RF.pred <- chemlistpredictfup^2 #square-root transformation applied to model results.

  ### Apply applicability domain
  # Using methodology of Roy et al 2015, apply applicability domain of fup model to predictions of new chemicals and export
  a <- chemlistsc_fup_narm
  b <- a[, c("MoleculeID")]
  a <- a[, which(names(a) %in% fupmodvars)]
  a <- abs(a)
  SImin <- apply(a, 1, min) #Find the min, max, sd, and mean
  SImax <- apply(a, 1, max)
  SImean <- apply(a, 1, mean)
  SIsd <- apply(a, 1, sd)

  #Several are NA when SD is calculated
  SIdf=data.frame(SImin, SImax, SImean, SIsd)
  SIdf$SI90=SIdf$SImean + (1.28 * SIdf$SIsd)
  SIdf$Outlier=0 #something is assumed to be inside the AD unless it it found to not be

  #Based on algorithm specified in Roy et al. (2015)
  for(i in 1:length(SIdf[,1])){
    if(SIdf$SImax[i]<3){ next } else
      if (SIdf$SImin[i] > 3) {
        SIdf$Outlier[i] = 1 } else if
    (SIdf$SImean[i] + (1.28 * SIdf$SIsd[i]) > 3){
      SIdf$Outlier[i]=1}
  }

  chemlistsc_fup_narm=data.frame(chemlistsc_fup_narm, SIdf)
  # write.csv(chemlistsc_fup_narm,
  #           file=paste0("Novel_fup_predictions_with_AD_",
  #                       Datalabel,
  #                       "_descs_from_OPERA",
  #                       Operaversion,
  #                       ".csv"))

  return(list(
    Clint = chemlistsc_Clint_narm,
    Fup = chemlistsc_fup_narm
  ))
}
