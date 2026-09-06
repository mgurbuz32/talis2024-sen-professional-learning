# TALIS 2024: SEN-focused professional learning and teacher self-efficacy

Reproducibility materials for the manuscript **“Professional Learning and Teachers' Self-Efficacy for Educating Students with Special Education Needs Across 54 Education Systems.”**

**Author:** Mehmet Gürbüz  
Department of Special Education, Faculty of Education, Uşak University, Türkiye  
ORCID: https://orcid.org/0000-0003-2811-9946

## Overview

This repository contains analysis code, variable documentation, and aggregate verification outputs for a cross-national secondary analysis of OECD TALIS 2024. The study examines the association between professional learning focused on teaching students with special education needs (SEN) and teachers' SEN-specific self-efficacy.

The primary analytic sample contains **114,140 lower-secondary teachers in 54 non-overlapping education systems**. The national Belgium aggregate is excluded because it combines the same Flemish- and French-Community teacher records that are represented separately; retaining all three would violate independence of the meta-analytic units. The four-profile professional-learning need/participation analysis contains 113,482 teachers; 30,415 report high SEN-related professional-learning need.

## Data access

**Individual-level TALIS 2024 public-use data are not redistributed in this repository.** Users must obtain the TALIS 2024 public-use teacher data directly from OECD. For the R workflow, place `ttgintt4.rds` at:

```text
data/raw/ttgintt4.rds
```

The repository `.gitignore` excludes `data/raw/`, derived individual-level data, and common microdata formats to reduce the risk of accidental redistribution.

## Reproduction workflow

Run the scripts in numerical order:

```text
R/00_setup.R
R/01_data_preparation.R
R/02_descriptive_analysis.R
R/03_system_regressions_brr.R
R/04_random_effects_meta_analysis.R
R/05_need_participation_analysis.R
R/06_sensitivity_analyses.R
R/07_figures_tables.R
```

The scripts implement restriction to ISCED Level 2 and Forms B/C, routing-aware coding of `TT4G21K`, exclusion of the overlapping national Belgium aggregate, final teacher weights (`TCHWGT`), 100 teacher replicate weights (`TRWGT1`–`TRWGT100`), Fay-BRR variance estimation (Fay = 0.50), education-system-specific weighted regressions, REML random-effects synthesis, need × participation analyses, and robustness checks.

## Main variables

| Role | TALIS variable | Description |
|---|---|---|
| Outcome | `T4SESEN` | Self-efficacy in special education needs |
| Main predictor | `TT4G21K` / `SEN_PL` | SEN-focused professional learning in previous 12 months |
| Professional-learning need | `TT4G24K` | Current need for learning in teaching students with SEN |
| Covariate | `T4TYEXPTT` | Total teaching-experience category |
| Covariate | `T4TCSIZE` | Target-class size category |
| Covariate | `TT4G47E` | SEN concentration in target class |
| Survey form | `IDTQUEST` | Teacher questionnaire form |
| Final weight | `TCHWGT` | Final teacher sampling weight |
| Replicate weights | `TRWGT1`–`TRWGT100` | Teacher replicate weights |

## Routing-aware professional-learning coding

The original `TT4G21K` variable is retained unchanged. Derived `SEN_PL` is coded 1 for `TT4G21K = Yes`, 0 for `TT4G21K = No`, and 0 when `TT4G21K` is structurally missing because all preceding professional-learning activity items indicate no participation. Other missing values remain missing.

## Main verification results

Primary 54-system random-effects synthesis:

- N = 114,140
- B = 0.798
- SE = 0.034
- 95% CI [0.731, 0.866]
- I² = 84.0%
- 95% prediction interval [0.344, 1.253]

High-need subgroup:

- N = 30,415
- B = 0.791
- 95% CI [0.703, 0.878]

The pooled `SEN_PL × high need` interaction was small and non-significant (B = 0.016, 95% CI [-0.067, 0.099]).

### Robustness checks

- **General teacher self-efficacy:** after adding `T4SELF`, N = 114,047 and the pooled coefficient remained positive (B = 0.625, 95% CI [0.568, 0.682], I² = 81.2%).
- **Gender and educational attainment:** in the 18-system restricted sample (N = 22,598), B = 0.930 with the primary covariates and B = 0.931 after adding gender and highest educational attainment.
- **Teacher-data adjudication:** retaining only education systems rated Good or Fair yielded 48 systems (N = 108,347) and B = 0.817 (95% CI [0.747, 0.887]).
- **Leave-one-system-out:** pooled coefficients ranged from 0.785 to 0.806.
- **Ceiling-effect diagnostic:** neither the Pearson nor Spearman association between system mean T4SESEN and the system-specific coefficient supported a simple ceiling-effect explanation.
- **T4SESEN source-item reliability:** design-weighted Cronbach alpha across the 54 systems ranged from 0.782 to 0.940 (median = 0.862; mean = 0.863). These coefficients describe internal consistency and are not a test of cross-system measurement invariance.

Rounded manuscript-level targets are also provided in `results/verification_summary.csv`.

## License

Analysis code and repository documentation are released under the MIT License. OECD TALIS data remain subject to OECD's terms and are not covered by this repository license.

## Citation

Please cite the associated manuscript when available. Repository citation metadata are in `CITATION.cff`.
