# Aggregate results

This directory is for aggregate, non-identifying outputs created by the R workflow. Individual-level TALIS records must not be committed.

For convenience, `verification_summary.csv` provides rounded manuscript-level targets that can be used as a quick reproducibility check after re-running the analyses from the OECD public-use file.

The analysis scripts will also create:

- `system_means.csv`
- `profiles.csv`
- `system_coefficients.csv`
- `primary_random_effects_summary.csv`
- `high_need_coefficients.csv`
- `high_need_random_effects_summary.csv`
- `system_retention.csv`
- sensitivity-analysis CSV files

Small differences in the last decimal places can occur across software/package versions.
