# 03_system_regressions_brr.R --------------------------------------------
# Primary education-system-specific survey-weighted regressions.

source("R/00_setup.R")
d <- readRDS("data/derived/talis2024_primary_analysis.rds")

primary_formula <- T4SESEN ~ SEN_PL + factor(T4TYEXPTT) + factor(T4TCSIZE) +
  factor(TT4G47E) + factor(IDTQUEST)

system_coefficients <- split(d, d$CNTRY) %>%
  purrr::imap_dfr(function(x, code) {
    est <- fay_brr_coefficient(x, primary_formula, "SEN_PL")
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

readr::write_csv(system_coefficients, "results/system_coefficients.csv")
print(system_coefficients)
