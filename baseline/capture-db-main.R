# Captures the pre-refactor database path output from `main`.
#
# This is the baseline half of the Task 10 parity gate: it records what the
# unmodified `httkqsprs` database path returns for the eight CICHEMs that
# `scripts/CIWorkflowDemo.R` already exercises. The refactored `pipelines-r`
# path is compared against it by
# `../pipelines-r/scripts/verify_httkqspr_parity.R`.
#
# Run from a `main` worktree created as a sibling of this repo:
#
#   git worktree add ../httkqspr-main main
#   cd ../httkqspr-main
#   Rscript baseline/capture-db-main.R
#
# A fresh worktree has neither `rv/` nor `.Renviron` (both are git-ignored and
# so are absent from any checkout), so reuse the populated library and the
# credential file that already exist in the sibling repositories. Nothing is
# installed and nothing is written to either sibling.
.libPaths(normalizePath("../dawson2021-httkqspr/rv/library/4.6/x86_64"))
readRenviron("../pipelines-r/.Renviron")

devtools::load_all("httkqsprs")

chem_ids <- c(
  "CICHEM010017986",
  "CICHEM010028777",
  "CICHEM010057529",
  "CICHEM000200048",
  "CICHEM000200014",
  "CICHEM001945799",
  "CICHEM001587773",
  "CICHEM013599634"
)

out <- httkqsprs::generate_preds(
  "parity",
  chems = chem_ids,
  write.files = FALSE
)

saveRDS(
  list(
    clint = out$Clint$output,
    fup = out$Fup$output,
    papp = out$Papp$output
  ),
  "db-parity-main.rds"
)
cat("captured\n")
