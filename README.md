# Dawson-et-al.-2021_Clint_fup_predictions

Supplemental material for Dawson et al. (2021), ["Designing QSARs for Parameters of High-Throughput Toxicokinetic Models Using Open-Source Descriptors"](https://doi.org/10.1021/acs.est.0c06117).

This repository hosts [`httkqsprs`](httkqsprs), an R package implementing the random forest Quantitative Structure-Property Relationship (QSPR) models that predict high-throughput toxicokinetic (HTTK) parameters for novel chemicals from open-source structural descriptors.

## The `httkqsprs` package

The models take structure-derived descriptors from [OPERA](https://doi.org/10.1186/s13321-018-0263-1) and [PaDEL](https://doi.org/10.1002/jcc.21707) and predict three HTTK parameters:

| Endpoint | Function | Description |
| --- | --- | --- |
| Clint | `calc_clint()` | Intrinsic hepatic clearance |
| Fup | `calc_fup()` | Fraction unbound in plasma |
| Papp | `calc_papp()` | Apparent membrane permeability (Caco-2) |
| all three | `generate_preds()` | Reads the descriptor CSVs and runs all three models |

The package does not generate these descriptors. Users must supply them, either by running OPERA and PaDEL or by drawing from a database of pre-generated descriptors.

See the [package README](httkqsprs/README.md) for background and authorship, and the `IntroTohttkqsprs` vignette for a worked example.

## Installation

### Installing the package

The package lives in the `httkqsprs` subdirectory, so install it with:

```r
# install.packages("remotes")
remotes::install_github("ULRI-CIRI/dawson2021-httkqspr", subdir = "httkqsprs")
```

### Setting up a development environment

To work on the package itself, install these programs and ensure they're available on the command line:

* [R](https://cran.r-project.org/): Version 4.5+
* [rv](https://a2-ai.github.io/rv-docs/): An R environment management system
* [Just](https://just.systems/man/en/introduction.html): A command-line runner for custom commands

Then, clone this GitHub repository, and then you can install:

```bash
# view available commands
just --list

# install this environment
just install
```

This will install all required packages.

## Usage

`generate_preds()` expects an OPERA file and a PaDEL file that share a common label and differ only by their suffix:

```
<label>-smi_OPERA2.9Pred.csv
<label>_QSAR-ready_smi_PadelDesc.csv
```

Given those, a full run is one call:

```r
library(httkqsprs)

preds <- generate_preds(
  "NewHTTK_April_2026",
  input.folder = "scripts",
  output.folder = "out"
)

preds$Clint$output   # complete-case predictions
preds$Clint$missing  # chemicals dropped for incomplete descriptors
```

Clint and Fup drop chemicals with missing descriptors and report them in `$missing`; Papp imputes instead, so its `$missing` is always `NULL`.

To see which descriptors an endpoint needs before you run it:

```r
required_descriptors("clint")
required_descriptors("fup")
required_descriptors("papp")
```

A runnable version of the example above is in [scripts/ExternalWorkflowDemo.R](scripts/ExternalWorkflowDemo.R), along with the descriptor files it reads.

## Repository layout

```
httkqsprs/   R package source: code, data, tests, vignette
scripts/     example driver scripts, example descriptor files, maintainer tools
rv/          rv-managed R library and activation scripts
justfile     developer task runner
```

## Development

```bash
just --list     # view available commands
just install    # sync the rv-managed library
just lint       # check whether code needs formatting
just format     # format all code in place
just document   # regenerate NAMESPACE and man/ with roxygen2
just build      # build a source tarball
```

Code is formatted with [air](https://posit-dev.github.io/air/) so it stays consistent regardless of who wrote it. You can configure RStudio or Positron to format on save, or use `just format`.

Run the test suite with:

```r
devtools::test("httkqsprs")
```

The tests compare current output against fixtures frozen before the package was decoupled from its original database backend. See [httkqsprs/tests/testthat/fixtures/README.md](httkqsprs/tests/testthat/fixtures/README.md) for what each fixture is and why it must not be regenerated from current code.

One Papp parity check cannot run under `R CMD check` because it reads large descriptor files from outside the package. Run it directly instead:

```bash
Rscript scripts/verify-papp-parity.R
```

## Citation

Dawson, D., B. Ingle, K. Phillips, J. Nichols, J. Wambaugh, and R. Tornero-Velez. Designing QSARs for Parameters of High-Throughput Toxicokinetic Models Using Open-Source Descriptors. *Environmental Science & Technology* 55(9):6505-6517 (2021). <https://doi.org/10.1021/acs.est.0c06117>

## Disclaimer

The views expressed here are those of the authors and do not necessarily represent the views or the policies of the U.S. Environmental Protection Agency.
