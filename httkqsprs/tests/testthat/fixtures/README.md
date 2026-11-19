# Test inputs

| File | What it is |
| --- | --- |
| `subset-opera.csv` | OPERA descriptors for 33 chemicals |
| `subset-padel.csv` | PaDEL descriptors for the same 33 chemicals |

The 33 chemicals are a deliberate slice of the full April-2026 descriptor set
(`scripts/NewHTTK_April_2026-*.csv`), not a random sample. They include:

- every chemical dropped as incomplete by Clint (9) and by Fup (4)
- several chemicals from each Clint prediction bin
- several chemicals from each Papp class
- Roy applicability-domain outliers from each endpoint
- chemicals with missing pKa, which exercise the `fraction_neutral` branch

The subset contains no chemical with a tied Papp vote. Tests using these
inputs cover prediction and CSV-reading contracts.
