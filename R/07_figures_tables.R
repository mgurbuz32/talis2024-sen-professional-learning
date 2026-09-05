# 07_figures_tables.R -----------------------------------------------------
# Recreate the main forest plot from aggregate system-specific estimates.

source("R/00_setup.R")
coef <- readr::read_csv("results/system_coefficients.csv", show_col_types = FALSE)
meta <- readr::read_csv("results/primary_random_effects_summary.csv", show_col_types = FALSE)

coef <- coef %>% arrange(B) %>% mutate(`Education system` = factor(`Education system`, levels = `Education system`))
pooled <- meta$B[1]

p <- ggplot2::ggplot(coef, ggplot2::aes(x = B, y = `Education system`)) +
  ggplot2::geom_vline(xintercept = pooled, linetype = 2, linewidth = 0.5) +
  ggplot2::geom_errorbarh(ggplot2::aes(xmin = CI_low, xmax = CI_high), height = 0.18, linewidth = 0.45) +
  ggplot2::geom_point(size = 1.6) +
  ggplot2::labs(
    x = "Adjusted coefficient (B) with 95% CI",
    y = NULL,
    title = "SEN-focused professional learning and SEN-specific teacher self-efficacy",
    subtitle = "Education-system-specific Fay-BRR estimates; dashed line = pooled REML estimate"
  ) +
  ggplot2::theme_minimal(base_size = 10) +
  ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())

ggplot2::ggsave("figures/Figure_1_Forest_Plot.pdf", p, width = 8.5, height = 11)
ggplot2::ggsave("figures/Figure_1_Forest_Plot.png", p, width = 8.5, height = 11, dpi = 600)

message("Figure files written to figures/.")
