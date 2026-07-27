# How to use httkqsprs with files written by OPERA

# Top-level assignments automatically become CLI flags
label <- "NewHTTK_April_2026" # becomes --input-file
output.dir <- "./"

cat(getwd(),"\n")

message("Processing OPERA and Padel descriptor files starting with text: ", label)

httkqsprs::generate_preds(label, output.folder=output.dir)