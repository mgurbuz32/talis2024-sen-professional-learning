# TALIS 2024: SEN-focused professional learning and teacher self-efficacy

Reproducibility materials for the manuscript **“Professional Learning and Teachers' Self-Efficacy for Educating Students with Special Education Needs Across 55 Education Systems.”**

**Author:** Mehmet Gürbüz  
Department of Special Education, Faculty of Education, Uşak University, Türkiye  
ORCID: https://orcid.org/0000-0003-2811-9946

## Overview

This repository contains the analysis code, variable documentation, and aggregate verification outputs for a cross-national secondary analysis of the OECD Teaching and Learning International Survey (TALIS) 2024. The study examines the association between professional learning focused on teaching students with special education needs (SEN) and teachers' SEN-specific self-efficacy across 55 education systems.

The primary analytic sample contains 117,303 lower-secondary (ISCED 2) teachers assigned to TALIS teacher questionnaire Forms B or C with complete data for the primary outcome, focal predictor, and prespecified covariates. A professional-learning need/participation analysis uses 116,627 teachers.

## Data access

**The individual-level TALIS 2024 public-use data are not redistributed in this repository.** Users must obtain the TALIS 2024 R public-use teacher file directly from the OECD and place `ttgintt4.rds` in:

```text
data/raw/ttgintt4.rds
```

The repository `.gitignore` excludes `data/raw/` and common individual-level data formats to reduce the risk of accidental redistribution.

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

The scripts implement:

- restriction to ISCED Level 2 and questionnaire Forms B/C;
- routing-aware coding of SEN-focused professional learning (`SEN_PL`);
- final teacher weights (`TCHWGT`);
- 100 TALIS teacher replicate weights (`TRWGT1`–`TRWGT100`);
- Fay balanced repeated replication with Fay coefficient 0.50;
- education-system-specific weighted regressions;
- REML random-effects synthesis of system-specific coefficients;
- professional-learning need × participation analyses;
- robustness checks reported in the manuscript;
- aggregate tables and the forest plot.

## Main analysis variables

| Role | TALIS variable | Description |
|---|---|---|
| Outcome | `T4SESEN` | Self-efficacy in special education needs |
| Main predictor | `TT4G21K` / derived `SEN_PL` | SEN-focused professional learning during the previous 12 months |
| Professional-learning need | `TT4G24K` | Current need for professional learning in teaching students with SEN |
| Covariate | `T4TYEXPTT` | Total teaching-experience category |
| Covariate | `T4TCSIZE` | Target-class size category |
| Covariate | `TT4G47E` | SEN concentration/category in the target class |
| Survey form | `IDTQUEST` | Teacher questionnaire form |
| Final weight | `TCHWGT` | Final teacher sampling weight |
| Replicate weights | `TRWGT1`–`TRWGT100` | Teacher replicate weights for Fay-BRR variance estimation |

See `codebook/analysis_variables.csv` for the full analysis codebook.

## Routing-aware professional-learning coding

`TT4G21K` is retained unchanged in the local analysis-ready data. The derived binary variable `SEN_PL` is coded as:

- `1`: `TT4G21K = 1` (Yes);
- `0`: `TT4G21K = 2` (No);
- `0`: `TT4G21K` is structurally missing because all professional-learning activity items `TT4G20A`–`TT4G20J` indicate no participation;
- missing otherwise.

This distinction prevents questionnaire-routing missingness from being treated as ordinary item nonresponse.

## Aggregate verification results

The `results/` directory contains only aggregate outputs and does **not** contain individual-level TALIS records. The primary pooled association reported in the manuscript is approximately `B = 0.793` (95% CI [0.726, 0.860]), with substantial cross-system heterogeneity (`I² ≈ 84.3%`).

## Software

The scripts are written for R and use common CRAN packages including `dplyr`, `readr`, `purrr`, `tibble`, `haven`, `metafor`, and `ggplot2`. Run `R/00_setup.R` first; it checks required packages and defines the Fay-BRR helper functions used throughout the workflow.

## Reproducibility and versioning

The aggregate CSV files in `results/` are supplied as verification targets. Re-running the workflow from the OECD public-use file should reproduce these outputs subject to ordinary numerical rounding and package-version differences.

## License

Analysis code and original repository documentation are released under the MIT License. The OECD TALIS data remain subject to the OECD's own terms and are **not** covered by this repository license.

## Citation

Please cite the associated manuscript when available. Repository citation metadata are provided in `CITATION.cff`.
