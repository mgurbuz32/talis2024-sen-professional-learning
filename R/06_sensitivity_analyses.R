# 06_sensitivity_analyses.R ----------------------------------------------
# Robustness and diagnostic checks reported in the manuscript.

source("R/00_setup.R")
d <- readRDS("data/derived/talis2024_primary_analysis.rds")
primary_formula <- T4SESEN ~ SEN_PL + factor(T4TYEXPTT) + factor(T4TCSIZE) +
  factor(TT4G47E) + factor(IDTQUEST)

pool_system_models <- function(dat, formula, term = "SEN_PL") {
  out <- split(dat, dat$CNTRY) %>%
    purrr::imap_dfr(function(x, code) {
      est <- fay_brr_coefficient(x, formula, term)
      tibble(Code = code, `Education system` = unique(x$EDU_SYSTEM_NAME), N = nrow(x),
             B = est$B, SE = est$SE, CI_low = est$CI_low, CI_high = est$CI_high)
    })
  fit <- reml_pool(out)
  pred <- predict(fit)
  summary <- tibble(
    k = fit$k, N = nrow(dat), B = as.numeric(fit$b[1]), SE = fit$se,
    CI_low = fit$ci.lb, CI_high = fit$ci.ub, tau2 = fit$tau2, I2 = fit$I2,
    PI_low = pred$pi.lb, PI_high = pred$pi.ub
  )
  list(system = out, summary = summary)
}

# 1) Additional adjustment for general teacher self-efficacy (T4SELF).
if ("T4SELF" %in% names(d)) {
  d_self <- d %>% filter(!is.na(T4SELF))
  f_self <- update(primary_formula, . ~ . + T4SELF)
  z <- pool_system_models(d_self, f_self)
  readr::write_csv(z$system, "results/sensitivity_general_self_efficacy.csv")
  readr::write_csv(z$summary, "results/sensitivity_general_self_efficacy_summary.csv")
}

# 2) Gender + highest education in the subset where both are available.
if (all(c("TT4G01", "T4THEDAT") %in% names(d))) {
  d_demo <- d %>% filter(!is.na(TT4G01), !is.na(T4THEDAT))
  # Retain systems with enough observations and within-system variation for both variables.
  eligible_codes <- split(d_demo, d_demo$CNTRY) %>%
    purrr::keep(~ nrow(.x) >= 50 && dplyr::n_distinct(.x$TT4G01) >= 2 && dplyr::n_distinct(.x$T4THEDAT) >= 2) %>%
    names()
  d_demo <- d_demo %>% filter(CNTRY %in% eligible_codes)
  f_demo <- update(primary_formula, . ~ . + factor(TT4G01) + factor(T4THEDAT))
  base <- pool_system_models(d_demo, primary_formula)
  adj <- pool_system_models(d_demo, f_demo)
  readr::write_csv(base$system, "results/sensitivity_gender_education_baseline.csv")
  readr::write_csv(adj$system, "results/sensitivity_gender_education_adjusted.csv")
  readr::write_csv(bind_rows(
    base$summary %>% mutate(specification = "Primary covariates in restricted sample"),
    adj$summary %>% mutate(specification = "Plus gender and highest education")
  ), "results/sensitivity_gender_education_summary.csv")
}

# 3) Simple system-level ceiling-effect diagnostic.
if (file.exists("results/system_means.csv") && file.exists("results/system_coefficients.csv")) {
  means <- readr::read_csv("results/system_means.csv", show_col_types = FALSE)
  coefs <- readr::read_csv("results/system_coefficients.csv", show_col_types = FALSE)
  mean_col <- intersect(c("Mean_T4SESEN", "Mean"), names(means))[1]
  z <- inner_join(means %>% select(Code, all_of(mean_col)), coefs %>% select(Code, B), by = "Code")
  p <- cor.test(z[[mean_col]], z$B, method = "pearson")
  s <- cor.test(z[[mean_col]], z$B, method = "spearman", exact = FALSE)
  readr::write_csv(tibble(test = c("Pearson", "Spearman"),
                          estimate = c(unname(p$estimate), unname(s$estimate)),
                          p_value = c(p$p.value, s$p.value)),
                   "results/sensitivity_ceiling_effect.csv")
}

# 4) TALIS adjudication sensitivity: exclude Poor/Insufficient ISCED-2 teacher datasets.
# Codes correspond to Alberta (Canada), Flemish Community of Belgium, Netherlands,
# New Zealand, Norway, and United States in the TALIS 2024 adjudication table.
low_quality_codes <- c("CAB", "BFL", "NLD", "NZL", "NOR", "USA")
d_quality <- d %>% filter(!CNTRY %in% low_quality_codes)
quality <- pool_system_models(d_quality, primary_formula)
readr::write_csv(quality$system, "results/sensitivity_good_fair_systems.csv")
readr::write_csv(quality$summary, "results/sensitivity_good_fair_systems_summary.csv")

# 5) Leave-one-system-out synthesis based on primary system coefficients.
if (file.exists("results/system_coefficients.csv")) {
  coefs <- readr::read_csv("results/system_coefficients.csv", show_col_types = FALSE)
  loo <- purrr::map_dfr(coefs$Code, function(code) {
    x <- coefs %>% filter(Code != code)
    fit <- reml_pool(x); pred <- predict(fit)
    tibble(excluded_code = code,
           excluded_system = coefs$`Education system`[coefs$Code == code][1],
           B = as.numeric(fit$b[1]), SE = fit$se,
           CI_low = fit$ci.lb, CI_high = fit$ci.ub,
           tau2 = fit$tau2, I2 = fit$I2,
           PI_low = pred$pi.lb, PI_high = pred$pi.ub)
  })
  readr::write_csv(loo, "results/sensitivity_leave_one_system_out.csv")
}

# 6) System-specific internal consistency of the six raw T4SESEN items.
items <- paste0("TT4G31", LETTERS[1:6])
if (all(items %in% names(d))) {
  weighted_alpha <- function(x) {
    cc <- complete.cases(x[, c(items, "TCHWGT")])
    z <- x[cc, c(items, "TCHWGT")]
    if (nrow(z) < 50) return(tibble(N = nrow(z), weighted_alpha = NA_real_))
    X <- as.matrix(z[, items]); w <- z$TCHWGT / sum(z$TCHWGT)
    mu <- colSums(X * w)
    C <- t(X - matrix(mu, nrow(X), length(mu), byrow = TRUE)) %*%
      ((X - matrix(mu, nrow(X), length(mu), byrow = TRUE)) * w)
    k <- length(items)
    alpha <- k / (k - 1) * (1 - sum(diag(C)) / sum(C))
    tibble(N = nrow(z), weighted_alpha = alpha)
  }
  reliability <- split(d, d$CNTRY) %>%
    purrr::imap_dfr(function(x, code) {
      a <- weighted_alpha(x)
      tibble(Code = code, `Education system` = unique(x$EDU_SYSTEM_NAME),
             N = a$N, weighted_alpha = a$weighted_alpha)
    })
  readr::write_csv(reliability, "results/t4sesen_reliability_by_system.csv")
}
