library(httkqsprs)

args <- commandArgs(trailingOnly = TRUE)
label      <- if (length(args) >= 1) args[1] else stop("Usage: Rscript entrypoint.R <label> [output.dir]")
output.dir <- if (length(args) >= 2) args[2] else "."

message("Processing OPERA and PaDEL descriptor files with label: ", label)
generate_preds(label, output.dir)
