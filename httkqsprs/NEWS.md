# httkqsprs 0.0.5

## Database decoupling

The package no longer connects to a database. Descriptor retrieval is now the
caller's responsibility: `calc_clint()`, `calc_fup()` and `calc_papp()` take a
descriptor data frame keyed on `MoleculeID`, and `generate_preds()` reads the
OPERA and PaDEL CSVs directly. The `get_opera()`, `get_padel()`,
`pg_query()`, `pg_connection_from_env()`, `pg_escape_vector()` and
`install_if_missing()` functions have been removed, along with the `RPostgres`
and `DBI` dependencies. No predicted value changes as a result.

## New features

* `required_descriptors()` reports the OPERA and PaDEL descriptor names each
  endpoint's model needs, so callers can retrieve exactly those columns from
  whatever source they have.
* `read_descriptor_csvs()` is now exported. It reads the OPERA/PaDEL file pair
  and returns the merged descriptor frame, for callers who want the frame
  itself rather than all three sets of predictions from `generate_preds()`.

## Breaking changes

* Output column ORDER has changed relative to the previous release. The
  standardized descriptor block is now emitted in the order the models
  themselves declare their variables, rather than the order the retired
  database query happened to return them in. Column names, column set, and
  every predicted value are unchanged, and the new order no longer depends on
  the column order of the input files. Select columns by name.
* `generate_preds()` no longer accepts `output.path`. The argument was
  documented and defaulted but never read; `output.folder` has always been the
  parameter that controls where files are written.
* `generate_preds(write.files = TRUE)` now writes five CSVs rather than six.
  The `Incomplete_papp_predictions_*.csv` file was always empty, because
  `calc_papp()` mean-imputes missing descriptors instead of excluding cases.

## Bug fixes

* `calc_papp()` now clamps infinite descriptors to +/-100 standard deviations,
  preserving sign. The clamp runs after standardization, where the frame is
  already in z-units and "100 SDs" is literally 100, but it multiplied by the
  raw training SD -- and read that SD from the mean/SD table by column
  POSITION, while the surrounding standardization loop reads it by NAME. The
  two tables carry different column orders (25 columns versus 98), so 24 of
  the 25 positions resolved to an unrelated descriptor's SD, leaving each
  descriptor clamped to a different distance from the mean. The clamp also
  discarded the sign, pushing a `-Inf` to the high end of the model's range
  rather than the low end. **No predicted value changes**: the Papp vote
  matrix for all 4052 April-2026 chemicals is identical to the pre-refactor
  baseline, as are the Roy applicability-domain flags. `MAXDN` is the only
  model descriptor carrying infinities in that dataset and all four of its
  infinite values are positive, so the sign defect was latent rather than
  active.
* `calc_papp()` no longer fails when the caller has an object named `predict`
  in their global environment. The packaged model carries a `caret` closure
  enclosed in `.GlobalEnv` that calls `predict()` unqualified; that call is now
  resolved against `stats::predict` explicitly.
* Corrected the `calc_papp()` documentation of `Pab.Pred.AD`, which described
  the flag backwards. `1` means OUTSIDE the applicability domain, matching the
  `Outlier` convention in `calc_roy_ad()`. The values themselves never changed.
* Corrected the `calc_papp()` documentation of the identifier column, which
  named it `DTXSID`; the function emits `MoleculeID`.

## Reproducibility

* `calc_papp()` now seeds the RNG with `set.seed(1255)` before predicting, as
  `calc_clint()` already did. `randomForest` breaks a tied class vote by
  drawing from the RNG, and exactly 2 of the 4052 April-2026 chemicals
  (`DTXSID4060109`, `DTXSID8062575`) have perfect ties, so their
  `Pab.Class.Pred` -- and the `Pab.Quant.Pred.*` values keyed on it -- used to
  flip between runs. Predicted values for all 4052 chemicals are unchanged
  against the pre-refactor baseline.

  Note the scope of the guarantee: seeding makes a given input frame
  reproducible, not a given chemical. The draw a tied row receives depends on
  how many rows precede it, so a tied chemical can still be classified
  differently in a different batch. Papp regression tests therefore assert on
  the vote matrix, which no RNG touches, rather than on the predicted class.

  `calc_fup()` also calls `set.seed(1255)`, but `RF.fit` is a regression
  forest and consumes no randomness, so that call has never had any effect.

* `calc_clint()`, `calc_fup()` and `calc_papp()` no longer disturb the
  caller's RNG stream. `set.seed()` writes to `.Random.seed` in the global
  environment, so seeding for our own reproducibility silently reset the
  stream of whoever called us -- every subsequent random draw in their
  session became a function of our seed rather than theirs, which matters to
  anyone calling these functions from inside a simulation. The seed is now
  saved and restored on exit, including the case where the caller had never
  used the RNG at all and `.Random.seed` must be restored to not existing.
  Predicted values are unchanged.

## Input validation

* A descriptor CSV missing its identifier column (`MoleculeID` for OPERA,
  `Name` for PaDEL) now fails with an error naming both the file and the
  expected column, rather than `undefined columns selected` from the
  downstream column subset.
* Duplicate identifiers in either descriptor CSV are now an error. A repeated
  key fanned out the merge, producing more prediction rows than input
  chemicals with nothing downstream detecting it.
* `generate_preds()` now merges the two CSVs with a full outer join, matching
  the frame `pipelines-r` builds from the database. A chemical present in
  PaDEL but absent from OPERA is reported in `$missing` rather than dropped
  without comment. Chemicals present in both files are unaffected.

# httkqsprs 0.0.4 (2026-07-16)
Initial public (CRAN) release (September 2026)
This package is intended to allow reproducible prediction using the
[Dawson et al. (2021)](https://doi.org/10.1021/acs.est.0c06117) and [Honda et al. (2025)](https://doi.org/10.14573/altex.2403271)
HTTK QSPR models. Functions were built from original GitHub scripts
[https://github.com/HumanExposure/Dawson-et-al.-2021_Clint_fup_predictions](https://github.com/HumanExposure/Dawson-et-al.-2021_Clint_fup_predictions) and
[https://github.com/USEPA/CompTox-Expocast-Caco2/](https://github.com/USEPA/CompTox-Expocast-Caco2/))
modified both manually and with help from GitHub CoPilot (GPT-5.3-Codex).
