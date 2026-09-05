# 00_setup.R ---------------------------------------------------------------
# Shared setup and helper functions for TALIS 2024 reproducibility workflow.

required_packages <- c(
  "dplyr", "readr", "purrr", "tibble", "haven", "metafor", "ggplot2"
)

missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop(
    "Install required packages before continuing: ",
    paste(missing_packages, collapse = ", ")
  )
}

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(tibble)
})

dir.create("data/derived", recursive = TRUE, showWarnings = FALSE)
dir.create("results", recursive = TRUE, showWarnings = FALSE)
dir.create("figures", recursive = TRUE, showWarnings = FALSE)

FAY <- 0.50
N_REPLICATES <- 100L
replicate_names <- paste0("TRWGT", seq_len(N_REPLICATES))

# Fit one weighted linear model and extract a named coefficient.
fit_weighted_coefficient <- function(data, formula, coefficient, weight_name) {
  fit <- stats::lm(formula, data = data, weights = data[[weight_name]], na.action = stats::na.fail)
  value <- unname(stats::coef(fit)[coefficient])
  if (length(value) != 1L || is.na(value)) {
    stop("Coefficient not estimable: ", coefficient)
  }
  value
}

# Fay-BRR point estimate and standard error using TCHWGT and TRWGT1-100.
fay_brr_coefficient <- function(data, formula, coefficient, fay = FAY) {
  point <- fit_weighted_coefficient(data, formula, coefficient, "TCHWGT")
  rep_est <- vapply(
    replicate_names,
    function(w) fit_weighted_coefficient(data, formula, coefficient, w),
    numeric(1)
  )
  se <- sqrt(sum((rep_est - point)^2) / (N_REPLICATES * (1 - fay)^2))
  tibble(
    B = point,
    SE = se,
    CI_low = point - 1.96 * se,
    CI_high = point + 1.96 * se
  )
}

# Fay-BRR weighted mean.
fay_brr_mean <- function(data, variable, fay = FAY) {
  y <- data[[variable]]
  point <- stats::weighted.mean(y, data$TCHWGT, na.rm = TRUE)
  rep_est <- vapply(
    replicate_names,
    function(w) stats::weighted.mean(y, data[[w]], na.rm = TRUE),
    numeric(1)
  )
  se <- sqrt(sum((rep_est - point)^2) / (N_REPLICATES * (1 - fay)^2))
  tibble(
    Mean = point,
    SE = se,
    CI_low = point - 1.96 * se,
    CI_high = point + 1.96 * se
  )
}

# Random-effects synthesis using REML.
reml_pool <- function(data, yi = "B", sei = "SE") {
  metafor::rma.uni(
    yi = data[[yi]],
    sei = data[[sei]],
    method = "REML"
  )
}

message("Setup complete. Fay coefficient = ", FAY, "; replicate weights = ", N_REPLICATES)
