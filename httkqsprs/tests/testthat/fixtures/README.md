# Test fixtures

These files are **frozen baselines**, captured from the pre-refactor code that
read descriptors from the internal database. They are what makes the test suite
a regression suite rather than a change detector.

**Do not regenerate them from the current code.** Doing so would make every
"matches the committed golden output" test assert that the code agrees with
itself. If a change makes one of these fixtures fail, that is the signal the
fixture exists to produce — investigate the change, do not rewrite the file.

## Inputs

| File | What it is |
| --- | --- |
| `subset-opera.csv` | OPERA descriptors for 33 chemicals |
| `subset-padel.csv` | PaDEL descriptors for the same 33 chemicals |

The 33 chemicals are a deliberate slice of the full April-2026 descriptor set
(`scripts/NewHTTK_April_2026-*.csv`), not a random sample. They were chosen to
exercise the paths where a refactor breaks:

- every chemical dropped as incomplete by Clint (9) and by Fup (4)
- several chemicals from each Clint prediction bin
- several chemicals from each Papp class
- Roy applicability-domain outliers from each endpoint
- chemicals with missing pKa, which exercise the `fraction_neutral` branch

The subset deliberately contains **no** chemical with a tied Papp vote; tie
handling is covered by the manual check described below.

## Expected outputs

| File | What it is |
| --- | --- |
| `expected-clint.rds` | `calc_clint()` `$output` / `$missing` for the 33-chemical subset |
| `expected-fup.rds` | `calc_fup()` `$output` / `$missing` for the subset |
| `expected-papp.rds` | `calc_papp()` `$output` / `$missing` for the subset |
| `expected-descriptor-names.rds` | The OPERA and PaDEL descriptor names each endpoint's model required, derived inline by the pre-refactor `calc_*()` functions. This is the expected value for `required_descriptors()`. |

## Not here

The full-set Papp vote matrix (4052 x 3) is the parity evidence behind the
"no predicted value changes" claim in `NEWS.md`. It lives outside the package,
with the script that checks it, because it needs the 74 MB April-2026 CSVs that
are not part of the package tarball:

- `scripts/papp-votes-pre-refactor.rds`
- `scripts/verify-papp-parity.R`
