# Runs the UNMODIFIED CSV path and compares against the committed Novel_* files.
devtools::load_all("httkqsprs")

label <- "NewHTTK_April_2026"
out <- httkqsprs::generate_preds(
  label,
  input.folder = "scripts",
  write.files = FALSE
)

dir.create("baseline", showWarnings = FALSE)
saveRDS(out$Clint$output, "baseline/golden-clint.rds")
saveRDS(out$Fup$output, "baseline/golden-fup.rds")
saveRDS(out$Papp$output, "baseline/golden-papp.rds")
saveRDS(out$Clint$missing, "baseline/incomplete-clint.rds")
saveRDS(out$Fup$missing, "baseline/incomplete-fup.rds")

# Compare against the committed CSVs. write.csv() wrote row names, so column 1
# of each committed file is the row name index.
compare <- function(fresh, path, id_col) {
  committed <- read.csv(path, row.names = 1, check.names = FALSE)
  cat("\n---", basename(path), "---\n")
  cat("fresh rows:", nrow(fresh), " committed rows:", nrow(committed), "\n")
  common <- intersect(names(fresh), names(committed))
  cat("shared columns:", length(common), "\n")
  ok <- isTRUE(all.equal(
    fresh[order(fresh[[id_col]]), common],
    committed[order(committed[[id_col]]), common],
    check.attributes = FALSE
  ))
  cat("MATCH:", ok, "\n")
  if (!ok) {
    print(all.equal(
      fresh[order(fresh[[id_col]]), common],
      committed[order(committed[[id_col]]), common],
      check.attributes = FALSE
    ))
  }
  ok
}

r1 <- compare(
  out$Clint$output,
  "scripts/Novel_clint_predictions_with_AD_NewHTTK_April_2026_descs_from_OPERA2.9.2.csv",
  "MoleculeID"
)
r2 <- compare(
  out$Fup$output,
  "scripts/Novel_fup_predictions_with_AD_NewHTTK_April_2026_descs_from_OPERA2.9.2.csv",
  "MoleculeID"
)
r3 <- compare(
  out$Papp$output,
  "scripts/Novel_papp_predictions_with_AD_NewHTTK_April_2026_descs_from_OPERA2.9.2.csv",
  "MoleculeID"
)
cat("\nALL MATCH:", all(r1, r2, r3), "\n")
