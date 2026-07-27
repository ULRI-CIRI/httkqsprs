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

dbGetQuery(con, "
SELECT COLUMN_NAME, DATA_TYPE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'opera_pka_endpoint'
")

dbGetQuery(conn, "
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'BASE TABLE';
")

dbGetQuery(conn, "
SELECT COLUMN_NAME 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'descriptor_padel';
")

dbGetQuery(conn, "
SELECT *
FROM descriptor_padel
LIMIT 3;
")

escriptor_padel