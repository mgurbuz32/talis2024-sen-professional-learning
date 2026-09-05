# 02_descriptive_analysis.R ----------------------------------------------
# System-specific SEN self-efficacy means and equal-system profile descriptives.

source("R/00_setup.R")
d <- readRDS("data/derived/talis2024_primary_analysis.rds")

system_means <- split(d, d$CNTRY) %>%
  purrr::imap_dfr(function(x, code) {
    est <- fay_brr_mean(x, "T4SESEN")
    tibble(
      Code = code,
      `Education system` = unique(x$EDU_SYSTEM_NAME),
      N = nrow(x),
      Mean_T4SESEN = est$Mean,
      SE = est$SE,
      CI_low = est$CI_low,
      CI_high = est$CI_high
    )
  }) %>% arrange(Mean_T4SESEN)

readr::write_csv(system_means, "results/system_means.csv")

profile_order <- c(
  "No high need + No SEN-focused PL",
  "No high need + SEN-focused PL",
  "High need + No SEN-focused PL",
  "High need + SEN-focused PL"
)

profile_system <- d %>%
  filter(NEED_PROFILE_ELIGIBLE == 1, !is.na(NEED_PL_PROFILE)) %>%
  group_by(CNTRY, NEED_PL_PROFILE) %>%
  summarise(
    w = sum(TCHWGT),
    wy = sum(TCHWGT * T4SESEN),
    .groups = "drop"
  ) %>%
  group_by(CNTRY) %>%
  mutate(
    weighted_pct = 100 * w / sum(w),
    weighted_mean = wy / w
  ) %>%
  ungroup()

profiles <- profile_system %>%
  group_by(NEED_PL_PROFILE) %>%
  summarise(
    weighted_pct_equal_system = mean(weighted_pct),
    mean_T4SESEN_equal_system = mean(weighted_mean),
    .groups = "drop"
  ) %>%
  mutate(profile = match(NEED_PL_PROFILE, profile_order) - 1L) %>%
  arrange(profile) %>%
  select(profile, NEED_PL_PROFILE, weighted_pct_equal_system, mean_T4SESEN_equal_system)

readr::write_csv(profiles, "results/profiles.csv")

print(system_means)
print(profiles)
