# httkqsprs 0.0.5 (2026-10-08)

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
  themselves declare their variables. Column names, column set, and
  every predicted value are unchanged, and the new order no longer depends on
  the column order of the input files (selects columns by name).
* `generate_preds()` no longer accepts `output.path`. The argument was
  documented and defaulted but never read; `output.folder` has always been the
  parameter that controls where files are written.
* `generate_preds(write.files = TRUE)` now writes five CSVs rather than six.
  The `Incomplete_papp_predictions_*.csv` file was always empty, because
  `calc_papp()` mean-imputes missing descriptors instead of excluding cases.

## Bug fixes

* `calc_papp()` now clamps infinite descriptors to +/-100 standard deviations,
  preserving sign. The clamp runs after standardization, where the frame is
  already in z-units ("100 SDs" is equivalent to 100).
* `calc_papp()` no longer fails when the caller has an object named `predict`
  in their global environment. 

## Reproducibility

* `calc_papp()` now seeds the RNG with `set.seed(1255)` before predicting, same as
  `calc_clint()`. This ensures run reproducibility in cases where `randomForest` has to break a tied class vote (by
  drawing from the RNG).

  Note: seeding makes a given input frame
  reproducible, not a given chemical. The draw a tied row receives depends on
  how many rows precede it, so a tied chemical can still be classified
  differently in a different batch.

* `calc_clint()`, `calc_fup()` and `calc_papp()` no longer disturb the
  caller's RNG stream. The seed is now
  saved (`set.seed()` writes to `.Random.seed` in the global
  environment) and restored on exit, including the case where the caller had never used the RNG at all.

## Input validation

* A descriptor CSV missing its identifier column (`MoleculeID` for OPERA,
  `Name` for PaDEL) now fails with an error naming both the file and the
  expected column.
* Duplicate identifiers in either descriptor CSV are now an error. Prevents a repeated
 key from being fanned out in the merge and producing more prediction rows than input
  chemicals.
* `generate_preds()` now merges the two CSVs with a full outer join to ensure that a chemical present in
  PaDEL but absent from OPERA is reported in `$missing` rather than dropped. Chemicals present in both files are unaffected.

# httkqsprs 0.0.4 (2026-07-16)
Initial public (CRAN) release (September 2026)
This package is intended to allow reproducible prediction using the
[Dawson et al. (2021)](https://doi.org/10.1021/acs.est.0c06117) and [Honda et al. (2025)](https://doi.org/10.14573/altex.2403271)
HTTK QSPR models. Functions were built from original GitHub scripts
[https://github.com/HumanExposure/Dawson-et-al.-2021_Clint_fup_predictions](https://github.com/HumanExposure/Dawson-et-al.-2021_Clint_fup_predictions) and
[https://github.com/USEPA/CompTox-Expocast-Caco2/](https://github.com/USEPA/CompTox-Expocast-Caco2/))
modified both manually and with help from GitHub CoPilot (GPT-5.3-Codex).
