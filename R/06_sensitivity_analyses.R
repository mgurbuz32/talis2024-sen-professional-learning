# 06_sensitivity_analyses.R ----------------------------------------------
# Sensitivity checks reported in the manuscript/revision materials.

source("R/00_setup.R")
d <- readRDS("data/derived/talis2024_primary_analysis.rds")
primary_formula <- T4SESEN ~ SEN_PL + factor(T4TYEXPTT) + factor(T4TCSIZE) +
  factor(TT4G47E) + factor(IDTQUEST)

# 1) Additional adjustment for general teacher self-efficacy (T4SELF).
if ("T4SELF" %in% names(d)) {
  d_self <- d %>% filter(!is.na(T4SELF))
  f_self <- update(primary_formula, . ~ . + T4SELF)
  self_system <- split(d_self, d_self$CNTRY) %>%
    purrr::imap_dfr(function(x, code) {
      est <- fay_brr_coefficient(x, f_self, "SEN_PL")
      tibble(Code = code, `Education system` = unique(x$EDU_SYSTEM_NAME), N = nrow(x),
             B = est$B, SE = est$SE, CI_low = est$CI_low, CI_high = est$CI_high)
    })
  readr::write_csv(self_system, "results/sensitivity_general_self_efficacy.csv")
  fit_self <- reml_pool(self_system)
  pred_self <- predict(fit_self)
  readr::write_csv(tibble(
    k = fit_self$k, N = nrow(d_self), B = as.numeric(fit_self$b[1]), SE = fit_self$se,
    CI_low = fit_self$ci.lb, CI_high = fit_self$ci.ub, tau2 = fit_self$tau2,
    I2 = fit_self$I2, PI_low = pred_self$pi.lb, PI_high = pred_self$pi.ub
  ), "results/sensitivity_general_self_efficacy_summary.csv")
}

# 2) Gender + highest education in the subset where both are available.
if (all(c("TT4G01", "T4THEDAT") %in% names(d))) {
  d_demo <- d %>% filter(!is.na(TT4G01), !is.na(T4THEDAT))
  f_demo <- update(primary_formula, . ~ . + factor(TT4G01) + factor(T4THEDAT))

  fit_by_system <- function(formula, suffix) {
    out <- split(d_demo, d_demo$CNTRY) %>%
      purrr::imap_dfr(function(x, code) {
        est <- fay_brr_coefficient(x, formula, "SEN_PL")
        tibble(Code = code, `Education system` = unique(x$EDU_SYSTEM_NAME), N = nrow(x),
               B = est$B, SE = est$SE, CI_low = est$CI_low, CI_high = est$CI_high)
      })
    readr::write_csv(out, paste0("results/sensitivity_gender_education_", suffix, ".csv"))
    out
  }

  demo_base <- fit_by_system(primary_formula, "baseline")
  demo_adj  <- fit_by_system(f_demo, "adjusted")
  base_fit <- reml_pool(demo_base)
  adj_fit <- reml_pool(demo_adj)
  readr::write_csv(tibble(
    specification = c("Primary covariates in restricted sample", "Plus gender and highest education"),
    systems = c(base_fit$k, adj_fit$k),
    N = c(nrow(d_demo), nrow(d_demo)),
    B = c(as.numeric(base_fit$b[1]), as.numeric(adj_fit$b[1])),
    SE = c(base_fit$se, adj_fit$se),
    CI_low = c(base_fit$ci.lb, adj_fit$ci.lb),
    CI_high = c(base_fit$ci.ub, adj_fit$ci.ub)
  ), "results/sensitivity_gender_education_summary.csv")
}

# 3) Simple ceiling-effect hypothesis: correlate system mean T4SESEN with B.
if (file.exists("results/system_means.csv") && file.exists("results/system_coefficients.csv")) {
  means <- readr::read_csv("results/system_means.csv", show_col_types = FALSE)
  coefs <- readr::read_csv("results/system_coefficients.csv", show_col_types = FALSE)
  z <- inner_join(means %>% select(Code, Mean_T4SESEN), coefs %>% select(Code, B), by = "Code")
  p <- cor.test(z$Mean_T4SESEN, z$B, method = "pearson")
  s <- cor.test(z$Mean_T4SESEN, z$B, method = "spearman", exact = FALSE)
  readr::write_csv(tibble(
    test = c("Pearson", "Spearman"),
    estimate = c(unname(p$estimate), unname(s$estimate)),
    p_value = c(p$p.value, s$p.value)
  ), "results/sensitivity_ceiling_effect.csv")
}
