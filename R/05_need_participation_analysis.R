# 05_need_participation_analysis.R ---------------------------------------
# High-need subgroup contrast: SEN-focused PL vs no SEN-focused PL.

source("R/00_setup.R")
d <- readRDS("data/derived/talis2024_primary_analysis.rds")

high_need <- d %>% filter(HIGH_SEN_PL_NEED == 1)

high_need_formula <- T4SESEN ~ SEN_PL + factor(T4TYEXPTT) + factor(T4TCSIZE) +
  factor(TT4G47E) + factor(IDTQUEST)

system_high_need <- split(high_need, high_need$CNTRY) %>%
  purrr::imap_dfr(function(x, code) {
    est <- fay_brr_coefficient(x, high_need_formula, "SEN_PL")
    tibble(
      Code = code,
      `Education system` = unique(x$EDU_SYSTEM_NAME),
      N = nrow(x),
      B = est$B,
      SE = est$SE,
      CI_low = est$CI_low,
      CI_high = est$CI_high
    )
  }) %>% arrange(B)

readr::write_csv(system_high_need, "results/high_need_coefficients.csv")

fit <- reml_pool(system_high_need)
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
readr::write_csv(summary_out, "results/high_need_random_effects_summary.csv")

print(system_high_need)
print(summary_out)
