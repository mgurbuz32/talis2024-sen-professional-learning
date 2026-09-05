# 01_data_preparation.R ----------------------------------------------------
# Build the local analysis-ready teacher file from the OECD TALIS 2024 R PUF.
# The derived file is written to data/derived/ and is ignored by git.

source("R/00_setup.R")

raw_path <- "data/raw/ttgintt4.rds"
if (!file.exists(raw_path)) {
  stop("Missing raw file: ", raw_path, "\nObtain the TALIS 2024 teacher R PUF from OECD and place it there.")
}

raw <- readRDS(raw_path)
lookup <- readr::read_csv("codebook/system_lookup.csv", show_col_types = FALSE)

pl_items <- paste0("TT4G20", LETTERS[1:10])
needed_core <- c(
  "CNTRY", "IDCNTRY", "IDPOP", "IDSCHOOL", "IDTEACH", "IDTQUEST",
  "T4SESEN", "TT4G21K", "TT4G24K", "T4TYEXPTT", "T4TCSIZE", "TT4G47E",
  "TCHWGT", pl_items, paste0("TRWGT", 1:100)
)

missing_core <- setdiff(needed_core, names(raw))
if (length(missing_core) > 0) {
  stop("Required variables missing from the teacher file: ", paste(missing_core, collapse = ", "))
}

# Restrict to the lower-secondary target population and rotated Forms B/C.
eligible <- raw %>%
  filter(IDPOP == 2, IDTQUEST %in% c(2, 3)) %>%
  left_join(lookup, by = c("CNTRY" = "Code")) %>%
  rename(EDU_SYSTEM_NAME = `Education system`)

# Routing-aware coding: TT4G21K is structurally absent when the teacher reported
# no participation in any professional-learning activity in TT4G20A-J.
all_no_pl <- apply(
  as.data.frame(eligible[, pl_items, drop = FALSE]),
  1,
  function(x) all(!is.na(x) & x == 4)
)

eligible <- eligible %>%
  mutate(
    SEN_PL_ROUTED_ZERO = as.integer(is.na(TT4G21K) & all_no_pl),
    SEN_PL = case_when(
      TT4G21K == 1 ~ 1L,
      TT4G21K == 2 ~ 0L,
      is.na(TT4G21K) & all_no_pl ~ 0L,
      TRUE ~ NA_integer_
    ),
    HIGH_SEN_PL_NEED = case_when(
      TT4G24K == 4 ~ 1L,
      TT4G24K %in% 1:3 ~ 0L,
      TRUE ~ NA_integer_
    ),
    NEED_PL_PROFILE = case_when(
      HIGH_SEN_PL_NEED == 0 & SEN_PL == 0 ~ "No high need + No SEN-focused PL",
      HIGH_SEN_PL_NEED == 0 & SEN_PL == 1 ~ "No high need + SEN-focused PL",
      HIGH_SEN_PL_NEED == 1 & SEN_PL == 0 ~ "High need + No SEN-focused PL",
      HIGH_SEN_PL_NEED == 1 & SEN_PL == 1 ~ "High need + SEN-focused PL",
      TRUE ~ NA_character_
    ),
    NEED_PROFILE_ELIGIBLE = as.integer(!is.na(TT4G24K))
  )

# Eligible outcome sample used as denominator for system-specific retention.
eligible_outcome <- eligible %>% filter(!is.na(T4SESEN))

# Primary analytic sample: complete on outcome, focal exposure, and prespecified
# teacher/classroom covariates. Planned Form-A non-administration is already
# handled by the B/C restriction above.
primary <- eligible_outcome %>%
  filter(
    !is.na(SEN_PL),
    !is.na(T4TYEXPTT),
    !is.na(T4TCSIZE),
    !is.na(TT4G47E)
  )

# Retain sensitivity-analysis variables if supplied in the PUF.
optional_vars <- intersect(c("T4SELF", "TT4G01", "T4THEDAT"), names(primary))
keep_vars <- unique(c(
  needed_core,
  "EDU_SYSTEM_NAME", "SEN_PL", "SEN_PL_ROUTED_ZERO", "HIGH_SEN_PL_NEED",
  "NEED_PL_PROFILE", "NEED_PROFILE_ELIGIBLE", optional_vars
))
primary <- primary %>% select(any_of(keep_vars))

saveRDS(primary, "data/derived/talis2024_primary_analysis.rds")

retention <- eligible_outcome %>%
  count(CNTRY, EDU_SYSTEM_NAME, name = "Eligible_N") %>%
  left_join(
    primary %>% count(CNTRY, EDU_SYSTEM_NAME, name = "Analytic_N"),
    by = c("CNTRY", "EDU_SYSTEM_NAME")
  ) %>%
  mutate(
    Analytic_N = ifelse(is.na(Analytic_N), 0L, Analytic_N),
    Retention_pct = 100 * Analytic_N / Eligible_N
  ) %>%
  rename(Code = CNTRY, `Education system` = EDU_SYSTEM_NAME)

readr::write_csv(retention, "results/system_retention.csv")

cat("Primary analytic N:", nrow(primary), "\n")
cat("Education systems:", dplyr::n_distinct(primary$CNTRY), "\n")
cat("Need/profile eligible N:", sum(primary$NEED_PROFILE_ELIGIBLE == 1, na.rm = TRUE), "\n")
cat("Routing-based SEN_PL zero recodes retained:", sum(primary$SEN_PL_ROUTED_ZERO == 1, na.rm = TRUE), "\n")
