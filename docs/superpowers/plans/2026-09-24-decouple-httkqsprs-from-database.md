# Decoupling `httkqsprs` from the Internal Database Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all internal-database access out of the `httkqsprs` R package into `pipelines-r`, so the package becomes pure computation (descriptors in, predictions out) and is publishable, while producing bit-for-bit identical predictions.

**Architecture:** `httkqsprs` gains a `required_descriptors()` manifest that reports which OPERA/PaDEL descriptors each model needs; `calc_clint()`/`calc_fup()`/`calc_papp()` change from fetching descriptors to accepting a descriptor data frame; `generate_preds()` becomes a CSV-reading convenience wrapper for external users. `pipelines-r` gains `R/httkqspr_utils.R` exposing `get_descriptors(con, chem_ids)` and `predict(descriptors)`, mirroring the existing `qsur_utils.R`.

**Tech Stack:** R 4.5/4.6, `randomForest`, `caret`, `httk`, `stringr`, `testthat` (edition 3), `box`, `DBI`/`RPostgres` (in `pipelines-r` only), `rv` for dependency management, `air` for formatting.

**Spec:** [docs/superpowers/specs/2026-09-23-httkqspr-pipelines-r-integration-design.md](docs/superpowers/specs/2026-09-23-httkqspr-pipelines-r-integration-design.md)

## Global Constraints

- All work in this repo happens on branch `refactor/decouple-db-access`. **Never commit to `main`.**
- All work in `pipelines-r` happens on branch `feat/httkqspr-support`.
- The `pipelines` Python repo at `../pipelines` is **read-only for this plan**. Do not create, modify, or delete any file in it.
- `pipelines-r` lives at `../pipelines-r` relative to this repo's root. Both are sibling directories under `Projects/`.
- Predictions must be **bit-for-bit identical** to current `main`. Any numeric difference is a bug, not an improvement.
- Descriptor retrieval names: OPERA names always carry a `_pred` suffix; PaDEL names never do.
- `calc_fup()`'s `Opera_` / `padel_` column prefixing happens **after** retrieval, inside `calc_fup()`.
- `papp` requests `pKa_a_pred` and `pKa_b_pred` purely so `httk::calc_ionization()` can derive `fraction_neutral`; they are never model inputs.
- The PaDEL CSV keys on column `Name`; everything else keys on `MoleculeID`.
- SQL and schema name-mangling logic moved to `pipelines-r` must be copied **verbatim** apart from the two changes named in Task 9.
- `pipelines-r` helper modules follow the `<package_name>_utils.R` convention (e.g. `qsur_utils.R`, `httkqspr_utils.R`).
- Format R code with `uvx --from air-formatter air format .` before committing (see `justfile`).
- Branch is **held unmerged**; do not merge to `main` at the end of this plan.

## Review Focus

These are failure modes the spec implies but that the happy-path golden tests would not exercise. Each has a test assigned to the task that owns the code.

1. **Zero-row descriptor frame** — an empty `chem_ids` list, or all chemicals filtered out, reaches `stats::predict()` with zero rows and errors deep inside `randomForest`. Expect an empty result frame, not a crash. (Task 4)
2. **Missing required descriptor column** — `descriptors` lacks a column the model needs; today this yields `NA` predictions or a subscript error inside the standardization loop. Expect an immediate error naming the missing columns. (Task 4)
3. **Chemical present in OPERA but absent from PaDEL** — the CSV merge is `all.x = TRUE`, so the row survives with `NA` PaDEL values and must be reported in `$missing`, not silently predicted. (Task 7)
4. **`NA` pKa values** — `httk::calc_ionization()` receives `NA` donors/acceptors, so `fraction_neutral` becomes `NA` and must flow into the mean-imputation path rather than aborting. (Task 6)
5. **Duplicate `MoleculeID` rows from the database** — a chemical with two OPERA prediction rows silently fan-outs the merge, inflating row counts. Expect one row per `MoleculeID`. (Task 8)

---

## File Structure

**`httkqsprs/` (this repo)**

| File | Action | Responsibility |
|---|---|---|
| `R/descriptors.R` | create | `required_descriptors()` — the descriptor manifest |
| `R/read_descriptors.R` | create | `read_descriptor_csvs()` — internal CSV reader/merger |
| `R/calc_clint.R` | modify | Clint prediction from a descriptor frame |
| `R/calc_fup.R` | modify | Fup prediction from a descriptor frame |
| `R/calc_papp.R` | modify | Papp prediction from a descriptor frame |
| `R/generate_preds.R` | modify | CSV convenience wrapper for external users |
| `R/get_opera.R` | delete (Task 11) | moves to `pipelines-r` |
| `R/get_padel.R` | delete (Task 11) | moves to `pipelines-r` |
| `R/pg_utils.R` | delete (Task 11) | duplicate of `pipelines-r/R/pg_utils.R` |
| `DESCRIPTION`, `NAMESPACE` | modify | drop `DBI`/`RPostgres`, add `testthat` |
| `tests/testthat.R` | create | testthat entry point |
| `tests/testthat/fixtures/` | create | ~50-chemical inputs + golden `.rds` outputs |
| `tests/testthat/test-*.R` | create | manifest, per-endpoint, and wrapper tests |
| `data-raw/make-test-fixtures.R` | create | reproducible fixture generation |

**`../pipelines-r/`**

| File | Action | Responsibility |
|---|---|---|
| `R/httkqspr_utils.R` | create | `get_descriptors()`, `predict()`, private `get_opera()`/`get_padel()` |
| `scripts/run_httkqspr.R` | create | production entry point, mirrors `run_qsur.R` |
| `scripts/verify_httkqspr_parity.R` | create | manual DB parity check |
| `scripts/demo_httkqspr.R` | create | replaces this repo's `CIWorkflowDemo.R` |
| `rproject.toml` | modify | add `httkqsprs`, `stringr`, `tibble` |

**Repo root**

| File | Action |
|---|---|
| `scripts/CIWorkflowDemo.R` | delete (Task 12) — becomes `pipelines-r/scripts/demo_httkqspr.R` |
| `scripts/ExternalWorkflowDemo.R` | unchanged — already calls the retained `generate_preds()` signature |
| `baseline/` | create (Task 1), git-ignored — captured baseline artifacts |

---

### Task 1: Capture the baseline from `main`

Everything downstream compares against these artifacts. If they are wrong, every later test is meaningless.

**Files:**
- Create: `baseline/` (git-ignored working directory)
- Create: `.gitignore` entry for `baseline/`
- Modify: none (this task runs against unmodified code)

**Interfaces:**
- Consumes: nothing
- Produces: `baseline/descriptor-names.rds` (named list of the three `list(opera=, padel=)` pairs), `baseline/golden-clint.rds`, `baseline/golden-fup.rds`, `baseline/golden-papp.rds`, `baseline/incomplete-clint.rds`, `baseline/incomplete-fup.rds` — all captured from current `main` behaviour

- [ ] **Step 1: Confirm you are on the feature branch with a clean tree**

```bash
git branch --show-current   # must print: refactor/decouple-db-access
git status --short          # must print nothing
```

If the branch does not exist: `git checkout -b refactor/decouple-db-access`. Never work on `main`.

- [ ] **Step 2: Ignore the baseline directory**

Append to `.gitignore` (create the file if absent):

```gitignore
# Local baseline artifacts captured during the DB-decoupling refactor
baseline/
```

- [ ] **Step 3: Capture the descriptor names the current code derives**

Create `baseline/capture-descriptor-names.R`:

```r
# Captures the descriptor name sets that calc_* derive inline on main.
# These become the expected values for the required_descriptors() tests.
devtools::load_all("httkqsprs")

Descriptors <- httkqsprs::Descriptors
ClintClass3Mod <- httkqsprs::ClintClass3Mod
RF.fit <- httkqsprs::RF.fit
papp_opt_desc <- httkqsprs::papp_opt_desc

opera_desc_all <- paste0(Descriptors$Opera, "_pred")

# --- clint: lifted verbatim from calc_clint.R ---
clintmodvars <- row.names(randomForest::importance(ClintClass3Mod))
clint <- list(
  opera = intersect(opera_desc_all, clintmodvars),
  padel = intersect(Descriptors$Padel, clintmodvars)
)

# --- fup: lifted verbatim from calc_fup.R ---
fupmodvars <- row.names(RF.fit$importance)
fup_padel_base <- stringr::str_remove(
  fupmodvars[stringr::str_detect(fupmodvars, "^padel_")],
  "^padel_"
)
fup_opera_base <- stringr::str_remove(
  fupmodvars[stringr::str_detect(fupmodvars, "^Opera_")],
  "^Opera_"
)
fup <- list(
  opera = paste0(fup_opera_base, "_pred"),
  padel = fup_padel_base
)

# --- papp: lifted verbatim from calc_papp.R ---
papp_opera_desc <- unique(c(
  grep("_pred$", papp_opt_desc, value = TRUE),
  "pKa_a_pred",
  "pKa_b_pred"
))
papp <- list(
  opera = papp_opera_desc,
  padel = setdiff(papp_opt_desc, c("fraction_neutral", papp_opera_desc))
)

dir.create("baseline", showWarnings = FALSE)
saveRDS(
  list(clint = clint, fup = fup, papp = papp),
  "baseline/descriptor-names.rds"
)

str(list(clint = clint, fup = fup, papp = papp))
```

- [ ] **Step 4: Run it and record the output**

Run: `Rscript baseline/capture-descriptor-names.R`
Expected: prints three `$opera` / `$padel` character vectors and writes `baseline/descriptor-names.rds`. Every `$opera` entry must end in `_pred`; no `$padel` entry may. If that invariant fails, stop and report — the spec's union assumption is void.

- [ ] **Step 5: Regenerate the committed `Novel_*` outputs from `main` and verify they reproduce**

Create `baseline/capture-golden.R`:

```r
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
```

- [ ] **Step 6: Run it and act on the result**

Run: `Rscript baseline/capture-golden.R`
Expected: `ALL MATCH: TRUE`.

If any comparison is `FALSE`: **do not proceed silently.** The committed `Novel_*` files are stale. Report to the human partner which endpoint differs and how. The freshly captured `baseline/golden-*.rds` files become the authoritative baseline regardless — they are what `main` actually produces today, which is what this refactor must preserve.

- [ ] **Step 7: Commit the capture scripts**

```bash
git add .gitignore baseline/capture-descriptor-names.R baseline/capture-golden.R
git commit -m "chore: add baseline capture scripts for DB-decoupling refactor"
```

Note `baseline/*.rds` are git-ignored by design — they are large and locally reproducible.

---

### Task 2: Build the test scaffolding and fixtures

**Files:**
- Create: `httkqsprs/tests/testthat.R`
- Create: `data-raw/make-test-fixtures.R`
- Create: `httkqsprs/tests/testthat/fixtures/opera-subset.csv`
- Create: `httkqsprs/tests/testthat/fixtures/padel-subset.csv`
- Create: `httkqsprs/tests/testthat/fixtures/expected-clint.rds`
- Create: `httkqsprs/tests/testthat/fixtures/expected-fup.rds`
- Create: `httkqsprs/tests/testthat/fixtures/expected-papp.rds`
- Create: `httkqsprs/tests/testthat/fixtures/expected-descriptor-names.rds`
- Create: `httkqsprs/tests/testthat/helper-descriptors.R`
- Modify: `httkqsprs/DESCRIPTION`

**Interfaces:**
- Consumes: `baseline/golden-*.rds` and `baseline/descriptor-names.rds` from Task 1
- Produces: fixture files under `httkqsprs/tests/testthat/fixtures/`, loadable in tests via `testthat::test_path("fixtures", "<name>")`; `load_fixture_descriptors()` and `align_to()` helpers available to every test file. Tasks 4–7 use all of these.

- [ ] **Step 1: Add testthat to DESCRIPTION**

In `httkqsprs/DESCRIPTION`, after the `Imports:` line, add:

```dcf
Suggests: testthat (>= 3.0.0)
Config/testthat/edition: 3
```

- [ ] **Step 2: Create the testthat entry point**

Create `httkqsprs/tests/testthat.R`:

```r
library(testthat)
library(httkqsprs)

test_check("httkqsprs")
```

- [ ] **Step 3: Write the fixture generation script**

Create `data-raw/make-test-fixtures.R`:

```r
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

message("Fixture sizes:")
print(file.size(list.files(
  "httkqsprs/tests/testthat/fixtures",
  full.names = TRUE
)))
```

The golden `.rds` files store exact doubles and preserve the factor class of `ClintPredictBin`, avoiding CSV round-trip precision loss.

- [ ] **Step 4: Write the shared test helper**

Create `httkqsprs/tests/testthat/helper-descriptors.R`. `testthat` sources every `helper-*.R` file before each test file, so all four test files share this one definition rather than repeating it.

```r
# Builds the descriptor frame the way a caller would: read the fixture CSVs,
# take the union of what the three endpoints need, merge into one wide frame.
# This mirrors what pipelines-r's get_descriptors() produces from the database.
load_fixture_descriptors <- function() {
  opera <- read.csv(test_path("fixtures", "subset-opera.csv"))
  padel <- read.csv(test_path("fixtures", "subset-padel.csv"))
  names(padel)[names(padel) == "Name"] <- "MoleculeID"

  needs <- lapply(c("clint", "fup", "papp"), required_descriptors)
  opera_desc <- unique(unlist(lapply(needs, `[[`, "opera")))
  padel_desc <- unique(unlist(lapply(needs, `[[`, "padel")))

  for (nm in setdiff(opera_desc, names(opera))) opera[[nm]] <- NA_real_
  for (nm in setdiff(padel_desc, names(padel))) padel[[nm]] <- NA_real_

  merge(
    opera[, c("MoleculeID", opera_desc), drop = FALSE],
    padel[, c("MoleculeID", padel_desc), drop = FALSE],
    by = "MoleculeID",
    all = TRUE
  )
}

# Orders a frame by MoleculeID and restricts it to the golden column set, so
# expect_equal() compares content rather than row or column order.
align_to <- function(df, reference) {
  df[order(as.character(df$MoleculeID)), names(reference), drop = FALSE]
}
```

- [ ] **Step 5: Run the fixture generator**

Run: `Rscript data-raw/make-test-fixtures.R`
Expected: reports roughly 40–60 selected chemicals and a total fixture footprint under ~500 KB. If the footprint exceeds 1 MB, reduce the per-group `pick(n)` counts and rerun.

- [ ] **Step 6: Commit the scaffolding and fixtures**

```bash
git add httkqsprs/DESCRIPTION httkqsprs/tests data-raw/make-test-fixtures.R
git commit -m "test: add testthat scaffolding and golden fixtures"
```

---

### Task 3: Add `required_descriptors()`

**Files:**
- Create: `httkqsprs/R/descriptors.R`
- Create: `httkqsprs/tests/testthat/test-descriptors.R`
- Modify: `httkqsprs/NAMESPACE` (via roxygen)

**Interfaces:**
- Consumes: package data `Descriptors`, `ClintClass3Mod`, `RF.fit`, `papp_opt_desc`
- Produces: `required_descriptors(endpoint)` returning `list(opera = <character>, padel = <character>)`, where `endpoint` is one of `"clint"`, `"fup"`, `"papp"`. Tasks 4–7 and `pipelines-r` Task 8 all call this.

- [ ] **Step 1: Write the failing test**

Create `httkqsprs/tests/testthat/test-descriptors.R`:

```r
expected <- readRDS(test_path("fixtures", "expected-descriptor-names.rds"))

test_that("clint descriptors match the pre-refactor derivation", {
  got <- required_descriptors("clint")
  expect_equal(got$opera, expected$clint$opera)
  expect_equal(got$padel, expected$clint$padel)
})

test_that("fup descriptors match the pre-refactor derivation", {
  got <- required_descriptors("fup")
  expect_equal(got$opera, expected$fup$opera)
  expect_equal(got$padel, expected$fup$padel)
})

test_that("papp descriptors match the pre-refactor derivation", {
  got <- required_descriptors("papp")
  expect_equal(got$opera, expected$papp$opera)
  expect_equal(got$padel, expected$papp$padel)
})

test_that("papp requests pKa inputs but excludes fraction_neutral", {
  got <- required_descriptors("papp")
  expect_true(all(c("pKa_a_pred", "pKa_b_pred") %in% got$opera))
  expect_false("fraction_neutral" %in% c(got$opera, got$padel))
})

test_that("opera names carry _pred and padel names do not", {
  for (endpoint in c("clint", "fup", "papp")) {
    got <- required_descriptors(endpoint)
    expect_true(
      all(grepl("_pred$", got$opera)),
      info = paste(endpoint, "opera")
    )
    expect_false(
      any(grepl("_pred$", got$padel)),
      info = paste(endpoint, "padel")
    )
  }
})

test_that("opera and padel name sets never collide", {
  for (endpoint in c("clint", "fup", "papp")) {
    got <- required_descriptors(endpoint)
    expect_length(intersect(got$opera, got$padel), 0)
  }
})

test_that("an unknown endpoint is rejected", {
  expect_error(required_descriptors("clearance"))
})
```

- [ ] **Step 2: Run it to verify it fails**

Run: `R -e "devtools::test('httkqsprs', filter = 'descriptors')"`
Expected: FAIL — `could not find function "required_descriptors"`.

- [ ] **Step 3: Implement `required_descriptors()`**

Create `httkqsprs/R/descriptors.R`:

```r
#' Descriptors required by each QSPR model
#'
#' Reports the OPERA and PaDEL descriptor names a given endpoint's model
#' needs. Callers use this to retrieve exactly those descriptors from
#' whatever source they have, then pass the resulting data frame to
#' [calc_clint()], [calc_fup()], or [calc_papp()].
#'
#' The returned names are *retrieval* names. OPERA names carry a `_pred`
#' suffix and PaDEL names do not, so the two sets never collide and may be
#' merged into a single wide data frame.
#'
#' For `"papp"`, `pKa_a_pred` and `pKa_b_pred` are included even though the
#' model never consumes them directly: [calc_papp()] passes them to
#' [httk::calc_ionization()] to derive `fraction_neutral`, which is neither
#' an OPERA nor a PaDEL descriptor and so is never retrieved.
#'
#' @param endpoint One of `"clint"`, `"fup"`, or `"papp"`.
#'
#' @return A named list with elements `opera` and `padel`, each a character
#'   vector of descriptor names.
#'
#' @examples
#' required_descriptors("clint")
#'
#' @import randomForest
#' @import stringr
#' @export required_descriptors
required_descriptors <- function(endpoint = c("clint", "fup", "papp")) {
  endpoint <- match.arg(endpoint)

  Descriptors <- httkqsprs::Descriptors
  opera_desc_all <- paste0(Descriptors$Opera, "_pred")

  if (endpoint == "clint") {
    clintmodvars <- row.names(importance(httkqsprs::ClintClass3Mod))
    return(list(
      opera = intersect(opera_desc_all, clintmodvars),
      padel = intersect(Descriptors$Padel, clintmodvars)
    ))
  }

  if (endpoint == "fup") {
    fupmodvars <- row.names(httkqsprs::RF.fit$importance)
    fup_padel_base <- stringr::str_remove(
      fupmodvars[stringr::str_detect(fupmodvars, "^padel_")],
      "^padel_"
    )
    fup_opera_base <- stringr::str_remove(
      fupmodvars[stringr::str_detect(fupmodvars, "^Opera_")],
      "^Opera_"
    )
    return(list(
      opera = paste0(fup_opera_base, "_pred"),
      padel = fup_padel_base
    ))
  }

  papp_opt_desc <- httkqsprs::papp_opt_desc
  papp_opera_desc <- unique(c(
    grep("_pred$", papp_opt_desc, value = TRUE),
    "pKa_a_pred",
    "pKa_b_pred"
  ))
  list(
    opera = papp_opera_desc,
    padel = setdiff(papp_opt_desc, c("fraction_neutral", papp_opera_desc))
  )
}
```

- [ ] **Step 4: Regenerate docs and run the tests**

Run:
```bash
R -e "devtools::document('httkqsprs')"
R -e "devtools::test('httkqsprs', filter = 'descriptors')"
```
Expected: PASS, 7 tests. `NAMESPACE` now contains `export(required_descriptors)`.

- [ ] **Step 5: Commit**

```bash
uvx --from air-formatter air format .
git add httkqsprs/R/descriptors.R httkqsprs/NAMESPACE httkqsprs/man httkqsprs/tests
git commit -m "feat: add required_descriptors() descriptor manifest"
```

---

### Task 4: Convert `calc_clint()` to accept a descriptor frame

**Files:**
- Modify: `httkqsprs/R/calc_clint.R`
- Create: `httkqsprs/tests/testthat/test-calc-clint.R`

**Interfaces:**
- Consumes: `required_descriptors("clint")` from Task 3
- Produces: `calc_clint(descriptors)` returning `list(output = <data.frame>, missing = <data.frame>)`. `output` carries `MoleculeID`, standardized descriptor columns, `ClintPredictBin`, `ClintPredictBin_MD`, `ClintPredictBin_SD`, and Roy AD columns `SImin`, `SImax`, `SImean`, `SIsd`, `SI90`, `Outlier`. Task 7 and `pipelines-r` Task 9 both call this.

- [ ] **Step 1: Write the failing test**

Create `httkqsprs/tests/testthat/test-calc-clint.R`. `load_fixture_descriptors()` and `align_to()` come from `helper-descriptors.R` (Task 2).

```r
test_that("clint predictions match the pre-refactor golden output", {
  expected <- readRDS(test_path("fixtures", "expected-clint.rds"))
  got <- calc_clint(load_fixture_descriptors())

  expect_equal(
    align_to(got$output, expected$output),
    align_to(expected$output, expected$output),
    ignore_attr = TRUE
  )
})

test_that("clint reports incomplete chemicals in $missing", {
  expected <- readRDS(test_path("fixtures", "expected-clint.rds"))
  got <- calc_clint(load_fixture_descriptors())

  expect_setequal(
    as.character(got$missing$MoleculeID),
    as.character(expected$missing$MoleculeID)
  )
  expect_length(
    intersect(
      as.character(got$output$MoleculeID),
      as.character(got$missing$MoleculeID)
    ),
    0
  )
})

test_that("extra union columns do not change the result", {
  descriptors <- load_fixture_descriptors()
  base <- calc_clint(descriptors)

  padded <- descriptors
  padded$zzz_unrelated_pred <- 1.5
  padded$zzz_unrelated <- 2.5
  padded_result <- calc_clint(padded)

  expect_equal(padded_result$output, base$output)
})

# Review Focus 2: missing required descriptor column
test_that("a missing required column errors naming the column", {
  descriptors <- load_fixture_descriptors()
  dropped <- required_descriptors("clint")$padel[1]
  descriptors[[dropped]] <- NULL

  expect_error(calc_clint(descriptors), regexp = dropped, fixed = TRUE)
})

# Review Focus 1: zero-row input
test_that("a zero-row descriptor frame returns empty results, not an error", {
  descriptors <- load_fixture_descriptors()[0, , drop = FALSE]

  got <- calc_clint(descriptors)
  expect_equal(nrow(got$output), 0L)
  expect_equal(nrow(got$missing), 0L)
})
```

- [ ] **Step 2: Run it to verify it fails**

Run: `R -e "devtools::test('httkqsprs', filter = 'calc-clint')"`
Expected: FAIL — `calc_clint()` still requires `datalabel` and tries to read CSVs.

- [ ] **Step 3: Rewrite the head of `calc_clint()`**

In `httkqsprs/R/calc_clint.R`, replace the signature and the entire descriptor-acquisition block (from `calc_clint <- function(` through the closing brace of the `if (is.null(chems)) { ... } else { ... }` pair that assigns `chemlist`) with:

```r
calc_clint <- function(descriptors) {
  # Load these from package in case user hasn't loaded whole package:
  ClintClass3Mod <- httkqsprs::ClintClass3Mod
  clint.msd <- httkqsprs::clint.msd
  tmeanagtable <- httkqsprs::tmeanagtable
  tsdagtable <- httkqsprs::tsdagtable

  needs <- required_descriptors("clint")
  clint_opera_desc <- needs$opera
  clint_padel_desc <- needs$padel
  clintmodvars <- row.names(importance(ClintClass3Mod))

  # Subset to this endpoint's columns before any further processing, so a
  # wide union frame behaves identically to a per-endpoint frame.
  chemlist <- subset_descriptors(
    descriptors,
    c(clint_padel_desc, clint_opera_desc)
  )
```

Everything from `# Standardize descriptors using means/SDs from training data` onward is unchanged.

Update the roxygen block above the function: replace the `@param datalabel`, `@param chems`, `@param operapostfix`, `@param padelpostfix`, and `@param input.folder` tags with a single tag, and drop the now-false `[get_padel()]`/`[get_opera()]` references from the description:

```r
#' @param descriptors A data frame keyed on `MoleculeID` containing at least
#'   the columns named by `required_descriptors("clint")`. Extra columns are
#'   ignored.
```

- [ ] **Step 4: Add the shared subsetting and validation helper**

Append to `httkqsprs/R/descriptors.R`:

```r
#' Subset a descriptor frame to one endpoint's columns
#'
#' Validates that every required descriptor is present, then returns
#' `MoleculeID` plus exactly those columns. Subsetting before any renaming
#' or standardization keeps a wide union frame behaving identically to a
#' per-endpoint frame.
#'
#' @param descriptors A data frame keyed on `MoleculeID`.
#' @param required Character vector of required descriptor column names.
#' @return A data frame with `MoleculeID` first, then `required`.
#' @noRd
subset_descriptors <- function(descriptors, required) {
  if (!is.data.frame(descriptors)) {
    stop("`descriptors` must be a data frame.", call. = FALSE)
  }
  if (!"MoleculeID" %in% names(descriptors)) {
    stop("`descriptors` must contain a `MoleculeID` column.", call. = FALSE)
  }
  absent <- setdiff(required, names(descriptors))
  if (length(absent) > 0) {
    stop(
      "`descriptors` is missing required columns: ",
      paste(absent, collapse = ", "),
      call. = FALSE
    )
  }
  descriptors[, c("MoleculeID", required), drop = FALSE]
}
```

- [ ] **Step 5: Guard the zero-row case**

`randomForest::predict()` errors on a zero-row newdata. Immediately after the `chemlistsc_Clint_narm <- ...` assignment in `calc_clint()`, insert:

```r
  if (nrow(chemlistsc_Clint_narm) == 0) {
    return(list(output = chemlistsc_Clint_narm, missing = IncompleteClint))
  }
```

- [ ] **Step 6: Run the tests**

Run: `R -e "devtools::document('httkqsprs'); devtools::test('httkqsprs', filter = 'calc-clint')"`
Expected: PASS, 5 tests. If the golden comparison fails, the diff printed by `expect_equal` names the offending column — investigate before moving on. A numeric difference here means the refactor changed the math.

- [ ] **Step 7: Commit**

```bash
uvx --from air-formatter air format .
git add httkqsprs/R httkqsprs/man httkqsprs/NAMESPACE httkqsprs/tests
git commit -m "refactor: calc_clint() accepts a descriptor frame"
```

---

### Task 5: Convert `calc_fup()` to accept a descriptor frame

**Files:**
- Modify: `httkqsprs/R/calc_fup.R`
- Create: `httkqsprs/tests/testthat/test-calc-fup.R`

**Interfaces:**
- Consumes: `required_descriptors("fup")`, `subset_descriptors()` from Tasks 3–4
- Produces: `calc_fup(descriptors)` returning `list(output = <data.frame>, missing = <data.frame>)`. `output` carries `MoleculeID`, `Opera_`/`padel_`-prefixed standardized columns, `Fup.RF.pred`, and the Roy AD columns.

- [ ] **Step 1: Write the failing test**

Create `httkqsprs/tests/testthat/test-calc-fup.R`:

```r
test_that("fup predictions match the pre-refactor golden output", {
  expected <- readRDS(test_path("fixtures", "expected-fup.rds"))
  got <- calc_fup(load_fixture_descriptors())

  expect_equal(
    align_to(got$output, expected$output),
    align_to(expected$output, expected$output),
    ignore_attr = TRUE
  )
})

test_that("fup reports incomplete chemicals in $missing", {
  expected <- readRDS(test_path("fixtures", "expected-fup.rds"))
  got <- calc_fup(load_fixture_descriptors())

  expect_setequal(
    as.character(got$missing$MoleculeID),
    as.character(expected$missing$MoleculeID)
  )
})

# This is the specific hazard the union frame introduces for fup: its
# prefixing loop runs across every column it is handed.
test_that("extra union columns are not mis-prefixed", {
  descriptors <- load_fixture_descriptors()
  base <- calc_fup(descriptors)

  padded <- descriptors
  padded$zzz_unrelated_pred <- 1.5
  padded$zzz_unrelated <- 2.5
  padded_result <- calc_fup(padded)

  expect_equal(padded_result$output, base$output)
  expect_false(any(grepl("zzz_unrelated", names(padded_result$output))))
})

test_that("output columns use the Opera_ and padel_ prefixes", {
  got <- calc_fup(load_fixture_descriptors())
  modvars <- row.names(httkqsprs::RF.fit$importance)
  expect_true(all(modvars %in% names(got$output)))
})

test_that("a missing required column errors naming the column", {
  descriptors <- load_fixture_descriptors()
  dropped <- required_descriptors("fup")$padel[1]
  descriptors[[dropped]] <- NULL

  expect_error(calc_fup(descriptors), regexp = dropped, fixed = TRUE)
})
```

- [ ] **Step 2: Run it to verify it fails**

Run: `R -e "devtools::test('httkqsprs', filter = 'calc-fup')"`
Expected: FAIL — `calc_fup()` still requires `datalabel`.

- [ ] **Step 3: Rewrite the head of `calc_fup()`**

In `httkqsprs/R/calc_fup.R`, replace the signature and the descriptor-acquisition block (through the `if (is.null(chems)) { ... } else { ... }` that assigns `fupchemlist`) with:

```r
calc_fup <- function(descriptors) {
  # Load these from package in case user hasn't loaded whole package:
  RF.fit <- httkqsprs::RF.fit
  msd <- httkqsprs::fup.msd

  fupmodvars <- row.names(RF.fit$importance)
  needs <- required_descriptors("fup")
  fup_opera_desc <- needs$opera
  fup_padel_base <- needs$padel

  # Subset BEFORE the prefixing loop below, which renames every column it
  # is handed and would otherwise mis-prefix unrelated union columns.
  fupchemlist <- subset_descriptors(
    descriptors,
    c(fup_opera_desc, fup_padel_base)
  )
```

Everything from `Padeldesc <- which(` onward is unchanged.

Update the roxygen block the same way as Task 4: replace the five removed `@param` tags with the single `@param descriptors` tag and drop the `[get_padel()]`/`[get_opera()]` references.

- [ ] **Step 4: Guard the zero-row case**

Immediately after the `chemlistsc_fup_narm <- ...` assignment, insert:

```r
  if (nrow(chemlistsc_fup_narm) == 0) {
    return(list(output = chemlistsc_fup_narm, missing = Incompletescfup))
  }
```

- [ ] **Step 5: Run the tests**

Run: `R -e "devtools::document('httkqsprs'); devtools::test('httkqsprs', filter = 'calc-fup')"`
Expected: PASS, 5 tests.

- [ ] **Step 6: Commit**

```bash
uvx --from air-formatter air format .
git add httkqsprs/R httkqsprs/man httkqsprs/tests
git commit -m "refactor: calc_fup() accepts a descriptor frame"
```

---

### Task 6: Convert `calc_papp()` to accept a descriptor frame

**Files:**
- Modify: `httkqsprs/R/calc_papp.R`
- Create: `httkqsprs/tests/testthat/test-calc-papp.R`

**Interfaces:**
- Consumes: `required_descriptors("papp")`, `subset_descriptors()` from Tasks 3–4
- Produces: `calc_papp(descriptors)` returning `list(output = <data.frame>, missing = NULL)`. `output` carries `MoleculeID`, `Pab.Class.Pred`, `Pab.Pred.AD`, `Pab.Quant.Pred.Median`, `Pab.Quant.Pred.LowerCI`, `Pab.Quant.Pred.UpperCI`.

- [ ] **Step 1: Write the failing test**

Create `httkqsprs/tests/testthat/test-calc-papp.R`:

```r
test_that("papp predictions match the pre-refactor golden output", {
  expected <- readRDS(test_path("fixtures", "expected-papp.rds"))
  got <- calc_papp(load_fixture_descriptors())

  expect_equal(
    align_to(got$output, expected$output),
    align_to(expected$output, expected$output),
    ignore_attr = TRUE
  )
})

test_that("papp returns NULL for missing, since it imputes", {
  got <- calc_papp(load_fixture_descriptors())
  expect_null(got$missing)
})

test_that("MoleculeID is carried through exactly, not by partial matching", {
  descriptors <- load_fixture_descriptors()
  got <- calc_papp(descriptors)

  expect_setequal(
    as.character(got$output$MoleculeID),
    as.character(descriptors$MoleculeID)
  )
  expect_false(anyNA(got$output$MoleculeID))
})

# Review Focus 4: NA pKa must flow into mean imputation, not abort
test_that("NA pKa values produce predictions via mean imputation", {
  descriptors <- load_fixture_descriptors()
  descriptors$pKa_a_pred <- NA_real_
  descriptors$pKa_b_pred <- NA_real_

  got <- calc_papp(descriptors)
  expect_equal(nrow(got$output), nrow(descriptors))
  expect_false(anyNA(got$output$Pab.Class.Pred))
})

test_that("extra union columns do not change the result", {
  descriptors <- load_fixture_descriptors()
  base <- calc_papp(descriptors)

  padded <- descriptors
  padded$zzz_unrelated_pred <- 1.5
  expect_equal(calc_papp(padded)$output, base$output)
})

test_that("a missing required column errors naming the column", {
  descriptors <- load_fixture_descriptors()
  dropped <- required_descriptors("papp")$padel[1]
  descriptors[[dropped]] <- NULL

  expect_error(calc_papp(descriptors), regexp = dropped, fixed = TRUE)
})
```

- [ ] **Step 2: Run it to verify it fails**

Run: `R -e "devtools::test('httkqsprs', filter = 'calc-papp')"`
Expected: FAIL — `calc_papp()` still requires `datalabel`.

- [ ] **Step 3: Rewrite the head of `calc_papp()`**

In `httkqsprs/R/calc_papp.R`, replace the signature and the descriptor-acquisition block (through the `if (is.null(chems)) { ... } else { ... }` that assigns `papp_df`) with:

```r
calc_papp <- function(descriptors) {
  # Load these from package in case user hasn't loaded whole package:
  papp_opt_desc <- httkqsprs::papp_opt_desc
  papp_classmodopt <- httkqsprs::papp_classmodopt
  papp_train_msd <- httkqsprs::papp_train_msd
  papp_qspr_summary <- httkqsprs::papp_qspr_summary

  # fraction_neutral is calculated from OPERA pKa by httk and is neither an
  # OPERA nor a PaDEL descriptor, so it is not retrieved.
  needs <- required_descriptors("papp")
  papp_opera_desc <- needs$opera
  papp_padel_desc <- needs$padel

  papp_df <- subset_descriptors(
    descriptors,
    c(papp_opera_desc, papp_padel_desc)
  )
```

Everything from `# Calculate fraction_neutral from pKa if available` onward is unchanged **except** the typo fix in Step 4.

Update the roxygen block as in Tasks 4–5.

- [ ] **Step 4: Fix the `MoleculeI` partial-matching typo**

In the `papp_pred <- data.frame(` call, change:

```r
    MoleculeID = papp_df$MoleculeI,
```

to:

```r
    MoleculeID = papp_df$MoleculeID,
```

- [ ] **Step 5: Run the tests**

Run: `R -e "devtools::document('httkqsprs'); devtools::test('httkqsprs', filter = 'calc-papp')"`
Expected: PASS, 6 tests.

- [ ] **Step 6: Commit**

```bash
uvx --from air-formatter air format .
git add httkqsprs/R httkqsprs/man httkqsprs/tests
git commit -m "refactor: calc_papp() accepts a descriptor frame; fix MoleculeID typo"
```

---

### Task 7: Rewrite `generate_preds()` as the CSV wrapper

**Files:**
- Modify: `httkqsprs/R/generate_preds.R`
- Create: `httkqsprs/R/read_descriptors.R`
- Create: `httkqsprs/tests/testthat/test-generate-preds.R`

**Interfaces:**
- Consumes: `required_descriptors()`, `calc_clint()`, `calc_fup()`, `calc_papp()`
- Produces: `read_descriptor_csvs(datalabel, input.folder, operapostfix, padelpostfix)` (internal) returning a wide descriptor frame; `generate_preds(Datalabel, ...)` returning `list(Clint =, Fup =, Papp =)` with the same shape as before. `scripts/ExternalWorkflowDemo.R` depends on this signature.

- [ ] **Step 1: Write the failing test**

Create `httkqsprs/tests/testthat/test-generate-preds.R`:

```r
test_that("generate_preds reproduces the golden output from CSVs", {
  got <- generate_preds(
    "subset",
    input.folder = test_path("fixtures"),
    operapostfix = "-opera.csv",
    padelpostfix = "-padel.csv",
    write.files = FALSE
  )

  for (endpoint in c("Clint", "Fup", "Papp")) {
    expected <- readRDS(test_path(
      "fixtures",
      paste0("expected-", tolower(endpoint), ".rds")
    ))
    expect_equal(
      align_to(got[[endpoint]]$output, expected$output),
      align_to(expected$output, expected$output),
      ignore_attr = TRUE,
      info = endpoint
    )
  }
})

test_that("write.files = TRUE writes six CSVs into output.folder", {
  out_dir <- withr::local_tempdir()

  generate_preds(
    "subset",
    input.folder = test_path("fixtures"),
    operapostfix = "-opera.csv",
    padelpostfix = "-padel.csv",
    write.files = TRUE,
    output.folder = out_dir
  )

  written <- list.files(out_dir, pattern = "\\.csv$")
  expect_length(written, 6)
  expect_true(any(grepl("^Novel_clint_predictions_with_AD_subset", written)))
  expect_true(any(grepl("^Incomplete_Clint_predictions_subset", written)))
})

# Review Focus 3: a chemical in OPERA but absent from PaDEL
test_that("a chemical missing from PaDEL is reported, not silently predicted", {
  opera <- read.csv(test_path("fixtures", "subset-opera.csv"))
  padel <- read.csv(test_path("fixtures", "subset-padel.csv"))

  orphan <- setdiff(as.character(opera$MoleculeID), as.character(padel$Name))[1]
  if (is.na(orphan)) {
    orphan <- as.character(opera$MoleculeID)[1]
    padel <- padel[as.character(padel$Name) != orphan, , drop = FALSE]
  }

  tmp <- withr::local_tempdir()
  write.csv(opera, file.path(tmp, "orphan-opera.csv"), row.names = FALSE)
  write.csv(padel, file.path(tmp, "orphan-padel.csv"), row.names = FALSE)

  got <- generate_preds(
    "orphan",
    input.folder = tmp,
    operapostfix = "-opera.csv",
    padelpostfix = "-padel.csv",
    write.files = FALSE
  )

  expect_false(orphan %in% as.character(got$Clint$output$MoleculeID))
  expect_true(orphan %in% as.character(got$Clint$missing$MoleculeID))
})

test_that("descriptors absent from the user's CSV are backfilled as NA", {
  opera <- read.csv(test_path("fixtures", "subset-opera.csv"))
  padel <- read.csv(test_path("fixtures", "subset-padel.csv"))

  drop_col <- required_descriptors("clint")$padel[1]
  padel[[drop_col]] <- NULL

  tmp <- withr::local_tempdir()
  write.csv(opera, file.path(tmp, "thin-opera.csv"), row.names = FALSE)
  write.csv(padel, file.path(tmp, "thin-padel.csv"), row.names = FALSE)

  expect_no_error(
    generate_preds(
      "thin",
      input.folder = tmp,
      operapostfix = "-opera.csv",
      padelpostfix = "-padel.csv",
      write.files = FALSE
    )
  )
})
```

Add `withr` to `Suggests` in `httkqsprs/DESCRIPTION`:

```dcf
Suggests: testthat (>= 3.0.0), withr
```

- [ ] **Step 2: Run it to verify it fails**

Run: `R -e "devtools::test('httkqsprs', filter = 'generate-preds')"`
Expected: FAIL — `generate_preds()` still calls `calc_clint(datalabel = ...)`.

- [ ] **Step 3: Write the CSV reader**

Create `httkqsprs/R/read_descriptors.R`:

```r
#' Read OPERA and PaDEL descriptor CSVs into one descriptor frame
#'
#' Reads the two descriptor files an external user supplies, backfills any
#' descriptor the models need but the files lack with `NA_real_`, and merges
#' them into the single wide frame that [calc_clint()], [calc_fup()], and
#' [calc_papp()] consume.
#'
#' The PaDEL file keys its identifier column as `Name` while OPERA uses
#' `MoleculeID`; the merge is left-outer on OPERA, so a chemical present in
#' OPERA but absent from PaDEL survives with `NA` PaDEL values and is later
#' reported as incomplete rather than predicted.
#'
#' @param datalabel Character scalar prefixing both filenames.
#' @param input.folder Directory containing the two files.
#' @param operapostfix Filename postfix of the OPERA CSV.
#' @param padelpostfix Filename postfix of the PaDEL CSV.
#' @return A data frame keyed on `MoleculeID`.
#' @noRd
read_descriptor_csvs <- function(
  datalabel,
  input.folder,
  operapostfix,
  padelpostfix
) {
  opera_path <- file.path(input.folder, paste0(datalabel, operapostfix))
  padel_path <- file.path(input.folder, paste0(datalabel, padelpostfix))

  for (p in c(opera_path, padel_path)) {
    if (!file.exists(p)) {
      stop("Descriptor file not found: ", p, call. = FALSE)
    }
  }

  Opera <- read.csv(opera_path)
  Padel <- read.csv(padel_path)

  needs <- lapply(c("clint", "fup", "papp"), required_descriptors)
  opera_desc <- unique(unlist(lapply(needs, `[[`, "opera")))
  padel_desc <- unique(unlist(lapply(needs, `[[`, "padel")))

  # Backfill descriptors the user's files do not carry.
  for (nm in setdiff(opera_desc, names(Opera))) Opera[[nm]] <- NA_real_
  for (nm in setdiff(padel_desc, names(Padel))) Padel[[nm]] <- NA_real_

  Opera <- Opera[, c("MoleculeID", opera_desc), drop = FALSE]
  Padel <- Padel[, c("Name", padel_desc), drop = FALSE]

  merge(
    Opera,
    Padel,
    by.x = "MoleculeID",
    by.y = "Name",
    all.x = TRUE
  )
}
```

- [ ] **Step 4: Rewrite `generate_preds()`**

In `httkqsprs/R/generate_preds.R`, replace the function body's three `calc_*` calls and the signature with:

```r
generate_preds <- function(
  Datalabel,
  output.path = NULL,
  Operaversion = "2.9.2",
  operapostfix = "-smi_OPERA2.9Pred.csv",
  padelpostfix = "_QSAR-ready_smi_PadelDesc.csv",
  input.folder = getwd(),
  write.files = TRUE,
  output.folder = tempdir()
) {
  if (is.null(output.path)) {
    output.path <- tempdir()
  }

  descriptors <- read_descriptor_csvs(
    datalabel = Datalabel,
    input.folder = input.folder,
    operapostfix = operapostfix,
    padelpostfix = padelpostfix
  )

  clint <- calc_clint(descriptors)
  fup <- calc_fup(descriptors)
  papp <- calc_papp(descriptors)
```

The `if (write.files)` block and the `return(list(...))` are unchanged **except** that every `paste0(output.folder, "Incomplete_...` must become `file.path(output.folder, "Incomplete_...`, since `output.folder` has no trailing separator and the current `paste0` silently concatenates. Apply this to all six `write.csv()` calls, for example:

```r
    write.csv(
      clint$missing,
      file = file.path(
        output.folder,
        paste0("Incomplete_Clint_predictions_", Datalabel, ".csv")
      )
    )
```

Remove the `@param chems` roxygen tag and the `@import DBI` / `@import RPostgres` tags from this file's roxygen block.

- [ ] **Step 5: Run the tests**

Run: `R -e "devtools::document('httkqsprs'); devtools::test('httkqsprs', filter = 'generate-preds')"`
Expected: PASS, 4 tests.

- [ ] **Step 6: Run the whole suite**

Run: `R -e "devtools::test('httkqsprs')"`
Expected: PASS, all tests across all five test files, 0 failures.

- [ ] **Step 7: Commit**

```bash
uvx --from air-formatter air format .
git add httkqsprs
git commit -m "refactor: generate_preds() reads CSVs and delegates to calc_*"
```

---

### Task 8: Add `get_descriptors()` to `pipelines-r`

**Files:**
- Create: `../pipelines-r/R/httkqspr_utils.R`
- Create: `../pipelines-r/scripts/check_get_descriptors.R`
- Modify: `../pipelines-r/rproject.toml`, `../pipelines-r/rv.lock`

**Interfaces:**
- Consumes: `pipelines-r/R/pg_utils.R` exports `pg_query()`, `pg_escape_vector()`, `pg_connection_from_env()`; `httkqsprs::required_descriptors()` from Task 3
- Produces: `get_descriptors(con, chem_ids, opera_version = "2.9")` returning a wide data frame keyed on `MoleculeID`. Task 9 consumes it.

- [ ] **Step 1: Create the `pipelines-r` branch**

```bash
cd ../pipelines-r
git status --short          # must print nothing
git checkout -b feat/httkqspr-support
git branch --show-current   # must print: feat/httkqspr-support
```

- [ ] **Step 2: Add the dependencies**

In `../pipelines-r/rproject.toml`, extend the `dependencies` array:

```toml
dependencies = [
    "dplyr",
    "box",
    "RPostgres",
    "DBI",
    "stringr",
    "tibble",
    { name = "QSUR", git = "https://github.com/HumanExposure/qsur" , branch = "main"},
    { name = "httkqsprs", git = "https://github.com/ULRI-CIRI/dawson2021-httkqspr", branch = "refactor/decouple-db-access", directory = "httkqsprs" },
]
```

The `branch` pin flips to `main` only when the human partner merges; the plan leaves it on the feature branch.

- [ ] **Step 3: Sync and confirm the private dependency resolves**

Run: `rv sync`
Expected: `httkqsprs` installs from the subdirectory. If it fails with an authentication error, stop and report — this is the deployment risk the spec flags, and it must be resolved with the human partner before continuing.

- [ ] **Step 4: Copy the two retrieval functions into `pipelines-r`**

Do this as a mechanical file copy followed by a short list of edits, so the SQL and name-mangling logic cannot drift.

```bash
cd ../pipelines-r
cat ../dawson2021-httkqspr/httkqsprs/R/get_opera.R \
    ../dawson2021-httkqspr/httkqsprs/R/get_padel.R \
    > R/httkqspr_utils.R
```

Now apply exactly these edits to `R/httkqspr_utils.R`. Change nothing else — every `gsub()` name-mangling line, the `Opera.SQL.suffix` assignments, the `var.names` construction, the full multi-line `LEFT OUTER JOIN` query, the `col_defs` construction, the `get_padel_descriptors()` `sprintf`, and the `valid.descs` lookup query must survive byte-identical.

**Edit 1 — `get_opera()` signature and connection.** Replace:

```r
get_opera <- function(
  cichem_list = NULL,
  descriptors = NULL,
  opera_version = "2.9"
) {
  if (nchar(Sys.getenv("PIPELINES_CONN_STR")) == 0) {
    stop("Environmental variable PIPELINES_CONN_STR is not set")
  }

  conn <- pg_connection_from_env('PIPELINES_CONN_STR')
```

with:

```r
get_opera <- function(con, cichem_list, descriptors, opera_version = "2.9") {
  box::use(./pg_utils[pg_query, pg_escape_vector])
```

**Edit 2 — `get_opera()` query call.** Drop the `try()` wrapper so a failed query surfaces its real message instead of erroring later on the `colnames()` assignment, and use `con`:

```r
  Opera <- as.data.frame(pg_query(
    con,
    query,
    schema = "public",
    opera_version = opera_version,
    cichems = pg_escape_vector(cichem_list)
  ))
```

**Edit 3 — `get_padel()` signature and connection.** Replace:

```r
get_padel <- function(
  cichem_list = NULL,
  descriptors = NULL,
  opera_version = "2.9"
) {
  if (nchar(Sys.getenv("PIPELINES_CONN_STR")) == 0) {
    stop("Environmental variable PIPELINES_CONN_STR is not set")
  }

  conn <- pg_connection_from_env('PIPELINES_CONN_STR')
```

with:

```r
get_padel <- function(con, cichem_list, descriptors, opera_version = "2.9") {
  box::use(./pg_utils[pg_query, pg_escape_vector])
```

**Edit 4 — `get_padel()` unknown-descriptor branch.** An interactive debugger prompt would hang a parallel worker process. Replace:

```r
  if (!all(selected %in% valid.descs)) {
    cat(
      "The following requested descriptors are not available for PaDEL version ",
      opera_version,
      ":\n"
    )
    cat(setdiff(selected, valid.descs), sep = "\n")
    browser()
  }
```

with:

```r
  if (!all(selected %in% valid.descs)) {
    stop(
      "The following requested descriptors are not available for PaDEL ",
      "version ",
      opera_version,
      ": ",
      paste(setdiff(selected, valid.descs), collapse = ", ")
    )
  }
```

**Edit 5 — `get_padel()` query call.** Change the first argument of the two `pg_query()` calls from `conn` to `con`.

**Edit 6 — roxygen tags.** Replace each function's `#' @export get_opera` / `#' @export get_padel` tag with `#' @noRd`. These are private helpers in `pipelines-r`; only `get_descriptors()` and `predict()` are exported.

- [ ] **Step 5: Append `get_descriptors()`**

Add to the end of `R/httkqspr_utils.R`:

```r
#' Retrieve every descriptor the httkqsprs models require
#'
#' Asks `httkqsprs` which OPERA and PaDEL descriptors each endpoint needs,
#' unions those sets, and retrieves them in two queries rather than six.
#'
#' The union is collision-free because every OPERA descriptor name carries a
#' `_pred` suffix and no PaDEL name does.
#'
#' @param con A `DBIConnection`.
#' @param chem_ids Character vector of CICHEM identifiers.
#' @param opera_version OPERA version string.
#' @return A data frame keyed on `MoleculeID`.
#' @export
get_descriptors <- function(con, chem_ids, opera_version = "2.9") {
  needs <- lapply(
    c("clint", "fup", "papp"),
    httkqsprs::required_descriptors
  )
  opera_desc <- unique(unlist(lapply(needs, `[[`, "opera")))
  padel_desc <- unique(unlist(lapply(needs, `[[`, "padel")))

  opera <- get_opera(con, chem_ids, opera_desc, opera_version)
  padel <- get_padel(con, chem_ids, padel_desc, opera_version)

  merged <- merge(padel, opera, by = "MoleculeID", all = TRUE)

  # A chemical with more than one prediction row would fan out the merge and
  # inflate row counts; keep the first row per identifier.
  merged <- merged[!duplicated(merged$MoleculeID), , drop = FALSE]
  rownames(merged) <- merged$MoleculeID
  merged
}
```

- [ ] **Step 6: Verify against the database**

Create and run `../pipelines-r/scripts/check_get_descriptors.R`:

```r
source("rv/scripts/rvr.R")
source("rv/scripts/activate.R")
readRenviron(".Renviron")

box::use(
  R / pg_utils[pg_connection_from_env],
  R / httkqspr_utils[get_descriptors],
)

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

con <- pg_connection_from_env("PIPELINES_CONN_STR")
descriptors <- get_descriptors(con, chem_ids)

cat("rows:", nrow(descriptors), "(expected <=", length(chem_ids), ")\n")
cat("duplicate ids:", anyDuplicated(descriptors$MoleculeID), "(expected 0)\n")

needs <- lapply(c("clint", "fup", "papp"), httkqsprs::required_descriptors)
required <- unique(unlist(lapply(needs, function(x) c(x$opera, x$padel))))
cat("missing columns:", paste(setdiff(required, names(descriptors)), collapse = ", "), "\n")
stopifnot(
  length(setdiff(required, names(descriptors))) == 0,
  anyDuplicated(descriptors$MoleculeID) == 0
)
cat("OK\n")
```

Run: `Rscript scripts/check_get_descriptors.R` from `../pipelines-r`
Expected: `OK`, zero duplicate ids, zero missing columns. This is Review Focus 5.

- [ ] **Step 7: Commit in `pipelines-r`**

```bash
cd ../pipelines-r
uvx --from air-formatter air format .
git add R/httkqspr_utils.R scripts/check_get_descriptors.R rproject.toml rv.lock
git commit -m "feat: add get_descriptors() for httkqsprs"
```

---

### Task 9: Add `predict()` and the run script to `pipelines-r`

**Files:**
- Modify: `../pipelines-r/R/httkqspr_utils.R`
- Create: `../pipelines-r/scripts/run_httkqspr.R`

**Interfaces:**
- Consumes: `get_descriptors()` from Task 8; `httkqsprs::calc_clint()`/`calc_fup()`/`calc_papp()` from Tasks 4–6
- Produces: `predict(descriptors)` returning `list(clint =, fup =, papp =)` with the DB-facing column names; `run_httkqspr.R` defining `clint_csv_str`, `fup_csv_str`, `papp_csv_str` in the global environment

- [ ] **Step 1: Append `predict()` to `httkqspr_utils.R`**

```r
#' Predict Clint, Fup, and Papp from a descriptor frame
#'
#' Calls the three `httkqsprs` endpoint functions and renames their output to
#' the column contract the pipelines database expects.
#'
#' @param descriptors A data frame from [get_descriptors()].
#' @return A named list with `clint`, `fup`, and `papp` data frames.
#' @export
predict <- function(descriptors) {
  box::use(dplyr)

  clint <- httkqsprs::calc_clint(descriptors)$output |>
    dplyr::select(
      cichem = MoleculeID,
      bin = ClintPredictBin,
      bin_md = ClintPredictBin_MD,
      bin_sd = ClintPredictBin_SD,
      si_min = SImin,
      si_max = SImax,
      si_mean = SImean,
      si_sd = SIsd,
      si_90 = SI90,
      is_outlier = Outlier
    ) |>
    dplyr::mutate(is_outlier = as.logical(is_outlier))

  fup <- httkqsprs::calc_fup(descriptors)$output |>
    dplyr::select(
      cichem = MoleculeID,
      prediction = Fup.RF.pred,
      si_min = SImin,
      si_max = SImax,
      si_mean = SImean,
      si_sd = SIsd,
      si_90 = SI90,
      is_outlier = Outlier
    ) |>
    dplyr::mutate(is_outlier = as.logical(is_outlier))

  papp <- httkqsprs::calc_papp(descriptors)$output |>
    dplyr::select(
      cichem = MoleculeID,
      prediction = Pab.Class.Pred,
      class_median = Pab.Quant.Pred.Median,
      class_lower_ci = Pab.Quant.Pred.LowerCI,
      class_upper_ci = Pab.Quant.Pred.UpperCI,
      is_outlier = Pab.Pred.AD
    ) |>
    dplyr::mutate(is_outlier = as.logical(is_outlier))

  list(clint = clint, fup = fup, papp = papp)
}
```

These `dplyr::select()` blocks are transcribed from `pipelines/src/pipelines/tasks/httkqspr/run.R`. Do not modify that file.

- [ ] **Step 2: Write the run script**

Create `../pipelines-r/scripts/run_httkqspr.R`, mirroring `scripts/run_qsur.R`:

```r
# Requires the following values to be set prior to starting:
#
# * working_dir:        working directory for the environment
# * pipelines_conn_str: pipeline connection string
# * chem_ids:           list of cichems to execute

# change to where this is installed on machine
#setwd(working_dir)

# activate rv environment
source("rv/scripts/rvr.R")
source("rv/scripts/activate.R")
readRenviron(".Renviron")

# set db credentials
#Sys.setenv(PIPELINES_CONN_STR = pipelines_conn_str)

# run httkqspr script
box::use(
  R / pg_utils[pg_connection_from_env],
  R / httkqspr_utils[get_descriptors, predict],
)
con <- pg_connection_from_env("PIPELINES_CONN_STR")
descriptors <- get_descriptors(con, chem_ids)
result <- predict(descriptors)

# save CSVs to strings which we can load in polars
clint_csv_str <- paste(
  capture.output(write.csv(result$clint, row.names = FALSE)),
  collapse = "\n"
)

fup_csv_str <- paste(
  capture.output(write.csv(result$fup, row.names = FALSE)),
  collapse = "\n"
)

papp_csv_str <- paste(
  capture.output(write.csv(result$papp, row.names = FALSE)),
  collapse = "\n"
)
```

The three string names match what `pipelines/src/pipelines/tasks/httkqspr/run.py` already reads via `r.csv_to_df(name = ...)`.

- [ ] **Step 3: Smoke-test the run script**

Run from `../pipelines-r`:

```bash
Rscript -e 'chem_ids <- c("CICHEM010017986","CICHEM010028777","CICHEM010057529","CICHEM000200048","CICHEM000200014","CICHEM001945799","CICHEM001587773","CICHEM013599634"); source("scripts/run_httkqspr.R"); cat(substr(clint_csv_str,1,400),"\n\n",substr(fup_csv_str,1,300),"\n\n",substr(papp_csv_str,1,300),"\n")'
```

Expected: three CSV headers matching the spec's column contract exactly — `cichem,bin,bin_md,bin_sd,si_min,si_max,si_mean,si_sd,si_90,is_outlier`, then `cichem,prediction,si_min,si_max,si_mean,si_sd,si_90,is_outlier`, then `cichem,prediction,class_median,class_lower_ci,class_upper_ci,is_outlier`. `is_outlier` values must read `TRUE`/`FALSE`, not `0`/`1`.

- [ ] **Step 4: Commit**

```bash
cd ../pipelines-r
uvx --from air-formatter air format .
git add R/httkqspr_utils.R scripts/run_httkqspr.R
git commit -m "feat: add predict() and run_httkqspr.R"
```

---

### Task 10: Verify database parity

This is the gate for Task 11. Do not delete the package's database code until this passes.

**Files:**
- Create: `../pipelines-r/scripts/verify_httkqspr_parity.R`
- Create: `baseline/db-parity-main.rds` (git-ignored, captured in Step 1)

**Interfaces:**
- Consumes: `get_descriptors()`, `predict()` from Tasks 8–9; the unmodified database path on `main`
- Produces: a pass/fail parity report

- [ ] **Step 1: Capture the `main` database path output**

From this repo, using a worktree so the feature branch stays checked out:

```bash
git worktree add ../httkqspr-main main
```

Create `baseline/capture-db-main.R` and run it **from the worktree** (`../httkqspr-main`), with `PIPELINES_CONN_STR` set in the environment:

```r
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
```

Run: `Rscript baseline/capture-db-main.R` from `../httkqspr-main`, then copy `db-parity-main.rds` into this repo's `baseline/`.

- [ ] **Step 2: Write the parity script**

Create `../pipelines-r/scripts/verify_httkqspr_parity.R`:

```r
# Manual parity check. Requires live database access; NOT part of CI.
#
# Compares the refactored pipelines-r path against output captured from the
# pre-refactor httkqsprs database path (baseline/db-parity-main.rds in the
# dawson2021-httkqspr repo).
#
# Usage:
#   Rscript scripts/verify_httkqspr_parity.R <path-to-db-parity-main.rds>

source("rv/scripts/rvr.R")
source("rv/scripts/activate.R")
readRenviron(".Renviron")

args <- commandArgs(trailingOnly = TRUE)
baseline_path <- if (length(args) > 0) {
  args[[1]]
} else {
  "../dawson2021-httkqspr/baseline/db-parity-main.rds"
}

box::use(
  R / pg_utils[pg_connection_from_env],
  R / httkqspr_utils[get_descriptors, predict],
)

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

baseline <- readRDS(baseline_path)
con <- pg_connection_from_env("PIPELINES_CONN_STR")
fresh <- predict(get_descriptors(con, chem_ids))

# Map the renamed columns back to the original names so the two are comparable.
unrename <- list(
  clint = c(
    cichem = "MoleculeID",
    bin = "ClintPredictBin",
    bin_md = "ClintPredictBin_MD",
    bin_sd = "ClintPredictBin_SD",
    si_min = "SImin",
    si_max = "SImax",
    si_mean = "SImean",
    si_sd = "SIsd",
    si_90 = "SI90",
    is_outlier = "Outlier"
  ),
  fup = c(
    cichem = "MoleculeID",
    prediction = "Fup.RF.pred",
    si_min = "SImin",
    si_max = "SImax",
    si_mean = "SImean",
    si_sd = "SIsd",
    si_90 = "SI90",
    is_outlier = "Outlier"
  ),
  papp = c(
    cichem = "MoleculeID",
    prediction = "Pab.Class.Pred",
    class_median = "Pab.Quant.Pred.Median",
    class_lower_ci = "Pab.Quant.Pred.LowerCI",
    class_upper_ci = "Pab.Quant.Pred.UpperCI",
    is_outlier = "Pab.Pred.AD"
  )
)

all_ok <- TRUE
for (endpoint in c("clint", "fup", "papp")) {
  map <- unrename[[endpoint]]
  new <- as.data.frame(fresh[[endpoint]])
  old <- baseline[[endpoint]][, unname(map), drop = FALSE]

  names(new) <- unname(map[names(new)])
  new <- new[order(as.character(new$MoleculeID)), unname(map), drop = FALSE]
  old <- old[order(as.character(old$MoleculeID)), unname(map), drop = FALSE]

  # Both sides carry the same information in different storage types
  # (logical vs integer outlier flags, factor vs character bins).
  for (df_name in c("new", "old")) {
    df <- get(df_name)
    for (col in names(df)) {
      if (is.logical(df[[col]])) df[[col]] <- as.integer(df[[col]])
      if (is.factor(df[[col]])) df[[col]] <- as.character(df[[col]])
    }
    assign(df_name, df)
  }

  cmp <- all.equal(new, old, check.attributes = FALSE)
  ok <- isTRUE(cmp)
  all_ok <- all_ok && ok
  cat("---", endpoint, "--- rows:", nrow(new), "vs", nrow(old), "MATCH:", ok, "\n")
  if (!ok) print(cmp)
}

cat("\nPARITY:", all_ok, "\n")
if (!all_ok) quit(status = 1)
```

- [ ] **Step 3: Run the parity check**

Run from `../pipelines-r`: `Rscript scripts/verify_httkqspr_parity.R`
Expected: `PARITY: TRUE` with all three endpoints matching.

If it fails, the moved SQL or name-mangling diverged. Do not proceed to Task 11. Report which endpoint and column differ.

- [ ] **Step 4: Remove the worktree and commit**

```bash
cd ../dawson2021-httkqspr
git worktree remove ../httkqspr-main
git add baseline/capture-db-main.R
git commit -m "chore: add database parity baseline capture script"

cd ../pipelines-r
git add scripts/verify_httkqspr_parity.R
git commit -m "test: add manual httkqspr database parity check"
```

---

### Task 11: Delete the database code from `httkqsprs`

Only start this task after Task 10 reports `PARITY: TRUE`.

**Files:**
- Delete: `httkqsprs/R/get_opera.R`, `httkqsprs/R/get_padel.R`, `httkqsprs/R/pg_utils.R`
- Delete: `httkqsprs/man/get_opera.Rd`, `get_padel.Rd`, `pg_connection_from_env.Rd`, `pg_escape_vector.Rd`, `pg_query.Rd`, `install_if_missing.Rd`
- Modify: `httkqsprs/DESCRIPTION`, `httkqsprs/NAMESPACE`

**Interfaces:**
- Consumes: nothing
- Produces: a package with no database dependency

- [ ] **Step 1: Confirm nothing still references the removed functions**

```bash
grep -rn "get_opera\|get_padel\|pg_query\|pg_escape_vector\|pg_connection_from_env\|install_if_missing" httkqsprs/R httkqsprs/tests scripts/ExternalWorkflowDemo.R
```

Expected: no matches. If `scripts/CIWorkflowDemo.R` matches, that is fine — Task 12 deletes it.

- [ ] **Step 2: Delete the files**

```bash
git rm httkqsprs/R/get_opera.R httkqsprs/R/get_padel.R httkqsprs/R/pg_utils.R
git rm httkqsprs/man/get_opera.Rd httkqsprs/man/get_padel.Rd
git rm httkqsprs/man/pg_connection_from_env.Rd httkqsprs/man/pg_escape_vector.Rd
git rm httkqsprs/man/pg_query.Rd httkqsprs/man/install_if_missing.Rd
```

- [ ] **Step 3: Drop the database dependencies**

In `httkqsprs/DESCRIPTION`, change:

```dcf
Imports: randomForest, caret, RPostgres, httk
```

to:

```dcf
Imports: randomForest, caret, httk, stringr
```

`stringr` moves from an implicit `@import` to a declared import; `RPostgres` and `DBI` are gone.

- [ ] **Step 4: Regenerate NAMESPACE and confirm it is clean**

Run: `R -e "devtools::document('httkqsprs')"`
Then: `cat httkqsprs/NAMESPACE`
Expected: no `export(get_opera)`, no `export(get_padel)`, no `import(DBI)`, no `import(RPostgres)`. It should contain `export(calc_clint)`, `export(calc_fup)`, `export(calc_papp)`, `export(generate_preds)`, `export(required_descriptors)`, `import(randomForest)`, `import(stringr)`.

- [ ] **Step 5: Run the full check**

```bash
R -e "devtools::test('httkqsprs')"
R -e "devtools::check('httkqsprs', vignettes = FALSE)"
```

Expected: tests pass; `check` reports 0 errors and 0 warnings. Notes about the missing LICENSE field are pre-existing and out of scope.

- [ ] **Step 6: Commit**

```bash
uvx --from air-formatter air format .
git add -A httkqsprs
git commit -m "refactor: remove database access from httkqsprs"
```

---

### Task 12: Migrate the demo scripts

**Files:**
- Delete: `scripts/CIWorkflowDemo.R`
- Create: `../pipelines-r/scripts/demo_httkqspr.R`
- Modify: `httkqsprs/vignette/IntroTohttkqsprs.Rmd` (only if it references the removed API)
- Modify: `README.md` and `httkqsprs/README.md` (only if they reference the removed API)

**Interfaces:**
- Consumes: `get_descriptors()`, `predict()` from Tasks 8–9; `generate_preds()` from Task 7
- Produces: a working internal demo in `pipelines-r` and a working external demo in this repo

- [ ] **Step 1: Confirm `ExternalWorkflowDemo.R` still works unmodified**

Run: `Rscript -e 'setwd("scripts"); source("ExternalWorkflowDemo.R")'`
Expected: runs to completion. It calls `generate_preds(label, output.folder = output.dir)`, a signature Task 7 preserved, so no edit is required.

- [ ] **Step 2: Write the `pipelines-r` demo**

Create `../pipelines-r/scripts/demo_httkqspr.R`, replacing this repo's `CIWorkflowDemo.R`:

```r
# Demonstrates predicting Clint, Fup, and Papp for a list of CICHEM ids
# using the internal descriptor database.
#
# Replaces CIWorkflowDemo.R from the dawson2021-httkqspr repo, which called
# the database path that httkqsprs no longer provides.

source("rv/scripts/rvr.R")
source("rv/scripts/activate.R")
readRenviron(".Renviron")

box::use(
  R / pg_utils[pg_connection_from_env],
  R / httkqspr_utils[get_descriptors, predict],
)

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

con <- pg_connection_from_env("PIPELINES_CONN_STR")
descriptors <- get_descriptors(con, chem_ids)
result <- predict(descriptors)

result$clint[, c("cichem", "bin", "bin_md", "is_outlier")]
result$fup[, c("cichem", "prediction", "is_outlier")]
result$papp
```

- [ ] **Step 3: Run the demo**

Run from `../pipelines-r`: `Rscript scripts/demo_httkqspr.R`
Expected: three frames printed, eight rows each (or fewer where a chemical lacks complete descriptors).

- [ ] **Step 4: Delete the superseded demo and check the docs**

```bash
cd ../dawson2021-httkqspr
git rm scripts/CIWorkflowDemo.R
grep -rn "chems *=\|get_opera\|get_padel" README.md httkqsprs/README.md httkqsprs/vignette/
```

For each match, update the prose and code to the new API: descriptors come from `pipelines-r` internally, or from user-supplied OPERA/PaDEL CSVs via `generate_preds()` externally. If there are no matches, no documentation change is needed.

- [ ] **Step 5: Final full verification**

```bash
R -e "devtools::test('httkqsprs')"
R -e "devtools::check('httkqsprs', vignettes = FALSE)"
git status --short
git log --oneline main..HEAD
```

Expected: all tests pass, check is clean, working tree is clean, and the log shows the full task sequence on `refactor/decouple-db-access`.

- [ ] **Step 6: Commit both repos**

```bash
git add -A
git commit -m "docs: migrate CI demo to pipelines-r, update docs for new API"

cd ../pipelines-r
git add scripts/demo_httkqspr.R
git commit -m "docs: add httkqspr internal demo script"
```

- [ ] **Step 7: Stop — do not merge**

Per the spec, the branch is **held unmerged** until the `pipelines` Python repo is ready to cut over. Report completion to the human partner with:
- the parity result from Task 10,
- confirmation that `main` has no commits from this work,
- the note that `pipelines-r/rproject.toml` still pins `httkqsprs` to `branch = "refactor/decouple-db-access"` and must flip to `main` at merge time.
