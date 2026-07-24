# Dawson-et-al.-2021_Clint_fup_predictions

This repository contains additional supplemental information for:
Dawson, D., B. Ingle, K. Phillips, J. Nichols, J. Wambaugh, AND R. Tornero-Velez. Designing QSARs for Parameters of High-Throughput Toxicokinetic Models Using Open-Source Descriptors. ENVIRONMENTAL SCIENCE & TECHNOLOGY. American Chemical Society, Washington, DC, 55(9):6505-6517, (2021). https://doi.org/10.1021/acs.est.0c06117

In the zip file are a script and information to allow for the prediction of intrinsic hepatic clearance (Clint) and fraction unbound by protein (fup) parameters for novel chemicals. Please see the file "Information_for_User.txt" for instructions and additional information on how to use the script.

The views expressed here are those of the authors and do not necessarily represent the views or the policies of the U.S. Environmental Protection Agency.

## Installation

Prior to installing, install these programs and ensure they're available on the command line:

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

### Code formatting

Code will be formatted so it is consistent regardless of the user who wrote the code. You can configure tools such as RStudio and Positron to automatically format code whenever you save the file. Alternatively, you can run a command to format all code:

```bash
just lint    # check if code needs to be formatted (optional)
just format  # format code and save all files
```
