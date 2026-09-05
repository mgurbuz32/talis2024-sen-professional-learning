# 05_need_participation_analysis.R ---------------------------------------
# RQ3: high-need subgroup contrast and direct high-need moderation test.

source("R/00_setup.R")
d <- readRDS("data/derived/talis2024_primary_analysis.rds")

base_covars <- "+ factor(T4TYEXPTT) + factor(T4TCSIZE) + factor(TT4G47E) + factor(IDTQUEST)"
high_need <- d %>% filter(HIGH_SEN_PL_NEED == 1)
high_need_formula <- as.formula(paste("T4SESEN ~ SEN_PL", base_covars))

system_high_need <- split(high_need, high_need$CNTRY) %>%
  purrr::imap_dfr(function(x, code) {
    est <- fay_brr_coefficient(x, high_need_formula, "SEN_PL")
    tibble(Code = code, `Education system` = unique(x$EDU_SYSTEM_NAME), N = nrow(x),
           B = est$B, SE = est$SE, CI_low = est$CI_low, CI_high = est$CI_high)
  }) %>% arrange(B)
readr::write_csv(system_high_need, "results/high_need_coefficients.csv")

fit <- reml_pool(system_high_need)
pred <- predict(fit)
summary_out <- tibble(
  k = fit$k, N = nrow(high_need), B = as.numeric(fit$b[1]), SE = fit$se,
  CI_low = fit$ci.lb, CI_high = fit$ci.ub, tau2 = fit$tau2, I2 = fit$I2,
  Q = fit$QE, Q_df = fit$k - 1, Q_p = fit$QEp,
  PI_low = pred$pi.lb, PI_high = pred$pi.ub
)
readr::write_csv(summary_out, "results/high_need_random_effects_summary.csv")

# Direct moderation test: does the SEN_PL association differ for high-need teachers?
need_complete <- d %>% filter(!is.na(HIGH_SEN_PL_NEED))
interaction_formula <- as.formula(paste(
  "T4SESEN ~ SEN_PL * HIGH_SEN_PL_NEED", base_covars
))
interaction_term <- "SEN_PL:HIGH_SEN_PL_NEED"

system_interaction <- split(need_complete, need_complete$CNTRY) %>%
  purrr::imap_dfr(function(x, code) {
    est <- fay_brr_coefficient(x, interaction_formula, interaction_term)
    tibble(Code = code, `Education system` = unique(x$EDU_SYSTEM_NAME), N = nrow(x),
           B = est$B, SE = est$SE, CI_low = est$CI_low, CI_high = est$CI_high)
  })
readr::write_csv(system_interaction, "results/need_moderation_interaction.csv")

fit_i <- reml_pool(system_interaction)
pred_i <- predict(fit_i)
interaction_summary <- tibble(
  k = fit_i$k, N = nrow(need_complete), B = as.numeric(fit_i$b[1]), SE = fit_i$se,
  CI_low = fit_i$ci.lb, CI_high = fit_i$ci.ub, tau2 = fit_i$tau2, I2 = fit_i$I2,
  Q = fit_i$QE, Q_df = fit_i$k - 1, Q_p = fit_i$QEp,
  PI_low = pred_i$pi.lb, PI_high = pred_i$pi.ub
)
readr::write_csv(interaction_summary, "results/need_moderation_interaction_summary.csv")

print(summary_out)
print(interaction_summary)
