# Builds a ~50-chemical fixture set from the full April 2026 descriptor files.
# Run from the repo root on the pre-refactor code, AFTER Task 1 has produced
# baseline/golden-*.rds.
#
# Chemical selection is deliberate, not random: the subset must exercise the
# edge paths where a refactor breaks.

devtools::load_all("httkqsprs")

opera_all <- read.csv("scripts/NewHTTK_April_2026-smi_OPERA2.9Pred.csv")
padel_all <- read.csv("scripts/NewHTTK_April_2026_QSAR-ready_smi_PadelDesc.csv")

clint <- readRDS("baseline/golden-clint.rds")
fup <- readRDS("baseline/golden-fup.rds")
papp <- readRDS("baseline/golden-papp.rds")
inc_clint <- readRDS("baseline/incomplete-clint.rds")
inc_fup <- readRDS("baseline/incomplete-fup.rds")

pick <- function(ids, n) head(unique(as.character(ids)), n)

selected <- unique(c(
  # every chemical dropped as incomplete by Clint (9) and Fup (4)
  as.character(inc_clint$MoleculeID),
  as.character(inc_fup$MoleculeID),
  # a few from each Clint bin
  unlist(lapply(
    split(clint$MoleculeID, clint$ClintPredictBin),
    pick,
    n = 4
  )),
  # a few from each Papp class
  unlist(lapply(
    split(papp$MoleculeID, papp$Pab.Class.Pred),
    pick,
    n = 4
  )),
  # Roy AD outliers from each endpoint
  pick(clint$MoleculeID[clint$Outlier == 1], 3),
  pick(fup$MoleculeID[fup$Outlier == 1], 3),
  pick(papp$MoleculeID[papp$Pab.Pred.AD == 1], 3),
  # chemicals with missing pKa, exercising the fraction_neutral branch
  pick(opera_all$MoleculeID[is.na(opera_all$pKa_a_pred)], 3)
))
selected <- selected[!is.na(selected)]
message("Selected ", length(selected), " chemicals")

opera_sub <- opera_all[opera_all$MoleculeID %in% selected, , drop = FALSE]
padel_sub <- padel_all[padel_all$Name %in% selected, , drop = FALSE]

dir.create(
  "httkqsprs/tests/testthat/fixtures",
  recursive = TRUE,
  showWarnings = FALSE
)
write.csv(
  opera_sub,
  "httkqsprs/tests/testthat/fixtures/subset-opera.csv",
  row.names = FALSE
)
write.csv(
  padel_sub,
  "httkqsprs/tests/testthat/fixtures/subset-padel.csv",
  row.names = FALSE
)

# Golden outputs for exactly this subset, produced by the CURRENT code.
# The filenames above are already what these postfix arguments resolve to.
out <- httkqsprs::generate_preds(
  "subset",
  input.folder = "httkqsprs/tests/testthat/fixtures",
  operapostfix = "-opera.csv",
  padelpostfix = "-padel.csv",
  write.files = FALSE
)

saveRDS(
  out$Clint,
  "httkqsprs/tests/testthat/fixtures/expected-clint.rds"
)
saveRDS(out$Fup, "httkqsprs/tests/testthat/fixtures/expected-fup.rds")
saveRDS(out$Papp, "httkqsprs/tests/testthat/fixtures/expected-papp.rds")

file.copy(
  "baseline/descriptor-names.rds",
  "httkqsprs/tests/testthat/fixtures/expected-descriptor-names.rds",
  overwrite = TRUE
)

# The Papp vote matrix for the FULL April-2026 set, not the subset. It is the
# parity baseline behind the "no predicted value changes" claim, so it is
# tracked as a fixture rather than left in the gitignored baseline/ directory
# where only the machine that captured it would have a copy.
file.copy(
  "baseline/golden-papp-votes.rds",
  "httkqsprs/tests/testthat/fixtures/expected-papp-votes.rds",
  overwrite = TRUE
)

message("Fixture sizes:")
print(file.size(list.files(
  "httkqsprs/tests/testthat/fixtures",
  full.names = TRUE
)))
