# httkqpsrs

High throughput toxicokinetics ("HTTK") is the combination of in vitro TK data and generic mathematical models to predict absorption, distribution, metabolism, and excretion by the body, as decribed by [Pearce et al. (2017)](https://dx.doi.org/10.18637/jss.v079.i04) and [Breen et al. (2021)](https://dx.doi.org/10.1080/17425255.2021.1935867).

Chemical-specific in vitro TK data are available for only a few thousand chemicals. [Dawson et al. (2021)](https://dx.doi.org/10.1021/acs.est.0c06117) and [Honda et al. (2025)](https://dx.doi.org/10.14573/altex.2403271) developed a suite of random forest Quantitative Structure-Property Relationship (QSPR) models to predict these parameters for a broader set of chemicals.

The package `httkqsprs` is designed to help run the required QSPR models which are needed to run the HTTK package.

The QSPR models require structure-derived chemical-specific descriptors from [PaDEL](https://dx.doi.org/10.1002/jcc.21707) and [OPERA](https://dx.doi.org/10.1186/s13321-018-0263-1). Assuming the user can generate these descriptors, or has access to a database of pre-generated descriptors, then this package can be used to calculate the HTTK parameter Clint (intrinsic hepatic clearance), fup (fraction unbound in plasma), and Papp (apparent membrane permeability in a Caco-2 experiment).

## Quickstart

Examples are available using the R vignettes. To list all vignettes:

```r
vignette(package = "httkqsprs")
```

To display a specific vignette:

```r
vignette("IntroTohttkqsprs")
```

## Authors

* **Principal Investigator:** [John Wambaugh](mailto:John.Wambaugh@UL.org)
* **Package Support:** [Zachary Stanfield](mailto:Zachary.Stanfield@UL.org)
* **Application Support:** [Andy Shapiro](mailto:andy.shapiro@ul.org)

The authors would like to thank the Original QSPR Model Developers for their work which this package builds upon:

* Daniel Dawson
* [Rogelio Tornero-Velez](mailto:Tornero-Velez.Rogelio@epa.gov)
* [Greg Honda](mailto:honda.gregory@epa.gov)

## Developer installation

Common developer instructions are availabe in a [justfile](https://just.systems/man/en/).  If you have `just` installed, you can run the commands, otherwise view the just file commands to manually type commands.

The R environment is managed using [rv](https://a2-ai.github.io/rv-docs/).  To install the packages and dependencies, run the command:

```bash
just install
```

For code formatting, use [air](https://posit-dev.github.io/air/cli.html)

```bash
# check if changes are needed
just lint

# format code in place
just format
```

For tests and documentation:

```bash
just test
just document
```

Finally, to build a package:

```bash
just build
```
