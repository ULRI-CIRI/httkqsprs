# uninstall package httkqsprs if its already loaded
detach("package:httkqsprs",unload=TRUE)
# reinstall the package
devtools::install("httkqsprs")
# load library
library(httkqsprs)
# create list of chemical ids
chem.ids <- c("CICHEM010017986",
              "CICHEM010028777",
              "CICHEM010057529",
              "CICHEM000200048",
              "CICHEM000200014",
              "CICHEM001945799",
              "CICHEM001587773",
              "CICHEM013599634")
#debug(generate_preds)
# generate Clint and Fup values for the chemicals ()
out <- generate_preds("June2026",chems=chem.ids)
# Clint Values:
out$Clint$output[,c("MoleculeID","ClintPredictBin_MD","Outlier")]
# Fup Values:
out$Fup$output[,c("MoleculeID","Fup.RF.pred","Outlier")]
# Papp Values:
out$Papp$output
