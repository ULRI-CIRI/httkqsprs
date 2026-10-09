# R Package "httkqpsrs"

High throughput toxicokinetics ("HTTK") is the
combination of in vitro TK data and generic mathematical models to
predict absorption, distribution, metabolism, and excretion by the
body, as decribed by Pearce et al. (2017)
(<doi:10.18637/jss.v079.i04>) and Breen et al. (2021) (<doi:10.1080/17425255.2021.1935867>).
Chemical-specific in vitro TK data are available for only a few thousand
chemicals. Dawson et al. (2021) (<doi:10.1021/acs.est.0c06117>) and Honda et al. (2025)
(<doi:10.14573/altex.2403271>)
developed a series of random forest Quantitative Structure-Property Relationship (QSPR)
models to predict these parameters for a broader set of chemicals.
The QSPR models require structure-derived chemical-specific descriptors from
Padel (<doi:10.1002/jcc.21707>) and OPERA (<doi:10.1186/s13321-018-0263-1>).
Assuming the user can generate these descriptors, or has access to a database of pre-generated
descriptors, then this package can be used to calculate the HTTK parameter Clint (intrinsic hepatic clearance),
fup (fraction unbound in plasma), and Papp (apparent membrane permeability in a Caco-2 experiment).

## Loading the example walkthrough ("vignette")
* List all vignettes for httkqsprs
```
vignette(package = "httkqsprs")
```
* Displays the vignette for a specified vignette
```
vignette("IntroTohttkqsprs")
```

## Authors

### Principal Investigator
John Wambaugh [John.Wambaugh@UL.org]

### Original QSPR Model Developers
Daniel Dawson
Rogelio Tornero-Velez [Tornero-Velez.Rogelio@epa.gov]
Greg Honda [honda.gregory@epa.gov]

### Model Workflow
Andy Shapiro [AndyShapiro@UL.org]
