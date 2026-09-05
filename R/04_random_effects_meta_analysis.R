# 04_random_effects_meta_analysis.R ---------------------------------------
# REML random-effects synthesis of the 55 education-system coefficients.

source("R/00_setup.R")
coef <- readr::read_csv("results/system_coefficients.csv", show_col_types = FALSE)

fit <- reml_pool(coef)
pred <- predict(fit)

summary_out <- tibble(
  k = fit$k,
  B = as.numeric(fit$b[1]),
  SE = fit$se,
  CI_low = fit$ci.lb,
  CI_high = fit$ci.ub,
  tau2 = fit$tau2,
  I2 = fit$I2,
  Q = fit$QE,
  Q_df = fit$k - 1,
  Q_p = fit$QEp,
  PI_low = pred$pi.lb,
  PI_high = pred$pi.ub
)

readr::write_csv(summary_out, "results/primary_random_effects_summary.csv")
print(fit)
print(summary_out)
