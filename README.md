# HTTK QSPRs

This repository hosts [`httkqsprs`](httkqsprs), an R package implementing the random forest Quantitative Structure-Property Relationship (QSPR) models that predict high-throughput toxicokinetic (HTTK) parameters for novel chemicals from open-source structural descriptors.

## Origin

This fraction unbound in plasma (fup) and intrinsic heaptic clearance (Clint) QPSR models are from the [supplemental material](https://github.com/HumanExposure/Dawson-et-al.-2021_Clint_fup_predictions) for Dawson et al. (2021), ["Designing QSARs for Parameters of High-Throughput Toxicokinetic Models Using Open-Source Descriptors"](https://doi.org/10.1021/acs.est.0c06117). The Caco-2 membrane permeability QSPR is from the [supplemental material](https://github.com/USEPA/CompTox-Expocast-Caco2) for Honda et al. (2025), ["Impact of Gut Permeability on Estimation of Oral Bioavailability for Chemicals in Commerce and the Environment"](https://doi.org/10.14573/altex.2403271).

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
remotes::install_github("ULRI-CIRI/httkqsprs", subdir = "httkqsprs")
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

## Authors

* John Wambaugh [John.Wambaugh@UL.org]
* Zach Stanfiled [Zach.Stanfield@UL.org]
* Andrew Shapiro [Andy.Shapiro@UL.org]

## Chemical Insights
[ULRI Chemical Insights]( https://chemicalinsights.org/) is an independent, non-profit research organization (501(c)(3)) dedicated to advancing the understanding of chemical exposures and their impacts on human health. We build on UL’s 130-year legacy in safety science. We are committed to producing peer-reviewed, open-access research that serves as a trusted resource for the public and scientific community. Our systems are completely separate from UL Solutions testing laboratories.

Chemical Insights develops data and tools that adhere to the FAIR principles – Findable, Accessible, Interoperable, and Reusable. Our mission is to provide trustworthy, scientifically grounded predictions of chemical behavior. 

We emphasize rigorous scientific peer review:
1.	Wherever possible, we integrate existing, peer-reviewed data and tools.
2.	When creating new data or methods, we submit them to external peer review to ensure quality and credibility.

Our goal is to inform standards, support evidence-based decision-making, and protect public health. We are passionate about advancing scientific discovery and applying it to real-world health challenges. 

## License

License: [MIT](https://en.wikipedia.org/wiki/MIT_License) <https://github.com/ULRI-CIRI/httkqsprs/blob/main/LICENSE>

## References

Daswson, Daniel E., Brandall L. Ingle, Katherine A. Phillips, John W. Nichols, John F. Wambaugh, and Rogelio Tornero-Velez. "Designing QSARs for Parameters of High-Throughput Toxicokinetic Models Using Open-Source Descriptors". *Environmental Science & Technology* 55(9):6505-6517 (2021). <https://doi.org/10.1021/acs.est.0c06117>

Honda, Gregory S., Elaina M Kenyon , Sarah Davidson-Fritz, Roger Dinallo, Hisham El-Masri, Evgenia Korol-Bexell, Li Li, Derek Angus, Robert G Pearce, Risa R Sayre, Christopher Strock, Russell S Thomas, Barbara A Wetmore, and John F Wambaugh. "Impact of gut permeability on estimation of oral bioavailability for chemicals in commerce and the environment." *ALTEX* 42.1 (2024): 56. <https://doi.org/10.14573/altex.2403271>

Wambaugh, John F., , Kristin K. Isaacs, Nathaniel Charest, Andrew J. Shapiro, Zach Stanfield, Jonathan T. Wall, Katie Paul Friedman, Mark Wilson, Russell S. Thomas. "The Toxicokinetic Data Landscape for a Global Chemical Collection." *submitted* (2026).

