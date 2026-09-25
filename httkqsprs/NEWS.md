# httkqsprs 0.0.5

## Database decoupling

The package no longer connects to a database. Descriptor retrieval is now the
caller's responsibility: `calc_clint()`, `calc_fup()` and `calc_papp()` take a
descriptor data frame keyed on `MoleculeID`, and `generate_preds()` reads the
OPERA and PaDEL CSVs directly. The `get_opera()`, `get_padel()`,
`pg_query()`, `pg_connection_from_env()`, `pg_escape_vector()` and
`install_if_missing()` functions have been removed, along with the `RPostgres`
and `DBI` dependencies. No predicted value changes as a result.

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

* `calc_papp()` no longer fails when the caller has an object named `predict`
  in their global environment. The packaged model carries a `caret` closure
  enclosed in `.GlobalEnv` that calls `predict()` unqualified; that call is now
  resolved against `stats::predict` explicitly.
* Corrected the `calc_papp()` documentation of `Pab.Pred.AD`, which described
  the flag backwards. `1` means OUTSIDE the applicability domain, matching the
  `Outlier` convention in `calc_roy_ad()`. The values themselves never changed.
* Corrected the `calc_papp()` documentation of the identifier column, which
  named it `DTXSID`; the function emits `MoleculeID`.

# httkqsprs 0.0.4 (2026-07-16)
Initial public (CRAN) release (September 2026)
This package is intended to allow reproducible prediction using the
[Dawson et al. (2021)](https://doi.org/10.1021/acs.est.0c06117) and [Honda et al. (2025)](https://doi.org/10.14573/altex.2403271)
HTTK QSPR models. Functions were built from original GitHub scripts
[https://github.com/HumanExposure/Dawson-et-al.-2021_Clint_fup_predictions](https://github.com/HumanExposure/Dawson-et-al.-2021_Clint_fup_predictions) and
[https://github.com/USEPA/CompTox-Expocast-Caco2/](https://github.com/USEPA/CompTox-Expocast-Caco2/))
modified both manually and with help from GitHub CoPilot (GPT-5.3-Codex).
