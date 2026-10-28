# ============================================================
# Blog Post 3: Gender Earnings Gaps Across Education Levels
# Main script: code/01_gender_earnings_analysis.R
#
# First run:
# Select the original CPS CSV or CSV.GZ file when prompted.
#
# Subsequent runs:
# Run this script from the repository root.
# ============================================================

library(tidyverse)

# ------------------------------------------------------------
# 1. Locate the project and create the folder structure
# ------------------------------------------------------------

input_file <- file.path("data-raw", "cps_00002.csv.gz")

if (!file.exists(input_file)) {
  message("Please select the original CPS CSV or CSV.GZ file.")
  input_file <- normalizePath(
    file.choose(),
    winslash = "/",
    mustWork = TRUE
  )
  
  input_folder <- dirname(input_file)
  
  if (!basename(input_folder) %in% c("data", "data-raw")) {
    stop(
      "Place the original data file inside Blog3/data-raw/ ",
      "or Blog3/data/, then run the script again."
    )
  }
  
  project_dir <- dirname(input_folder)
  setwd(project_dir)
}

folders <- c(
  "code",
  "data-raw",
  "data",
  "results/figures",
  "results/tables"
)

for (folder in folders) {
  dir.create(
    folder,
    recursive = TRUE,
    showWarnings = FALSE
  )
}

# All paths below are relative to the repository root.
message("Project directory: ", getwd())

# ------------------------------------------------------------
# 2. Load the original data
# ------------------------------------------------------------

cps <- read_csv(
  input_file,
  col_select = c(
    YEAR, AGE, SEX, EDUC,
    EMPSTAT, EARNWT, EARNWEEK2
  ),
  show_col_types = FALSE
)

# Record the education codes before recoding.
education_codes <- cps %>%
  count(YEAR, EDUC, name = "observations")

write_csv(
  education_codes,
  "results/tables/education_codes.csv"
)

# ------------------------------------------------------------
# 3. Define the sample and recode education
# ------------------------------------------------------------

education_levels <- c(
  "Less than high school",
  "High school",
  "Some college / Associate",
  "Bachelor's",
  "Advanced degree"
)

# Apply the original sample restrictions.
# Confirm the earnings scale and special codes against the
# extract codebook before interpreting the final results.
cps_eligible <- cps %>%
  filter(
    between(YEAR, 2015, 2025),
    between(AGE, 25, 64),
    EMPSTAT %in% c(10, 12),
    SEX %in% c(1, 2),
    is.finite(EARNWEEK2),
    EARNWEEK2 > 0,
    EARNWEEK2 < 999999,
    is.finite(EARNWT),
    EARNWT > 0
  ) %>%
  mutate(
    gender = if_else(SEX == 1, "Male", "Female"),
    
    education = case_when(
      EDUC %in% c(2, 10, 20, 30, 40, 50, 60, 71) ~
        "Less than high school",
      EDUC == 73 ~
        "High school",
      EDUC %in% c(81, 91, 92) ~
        "Some college / Associate",
      EDUC == 111 ~
        "Bachelor's",
      EDUC %in% c(123, 124, 125) ~
        "Advanced degree",
      TRUE ~ NA_character_
    ),
    
    education = factor(
      education,
      levels = education_levels
    )
  )

# Export any education codes not covered by the original mapping.
unmapped_education <- cps_eligible %>%
  filter(is.na(education)) %>%
  count(YEAR, EDUC, name = "observations")

write_csv(
  unmapped_education,
  "results/tables/unmapped_education_codes.csv"
)

if (nrow(unmapped_education) > 0) {
  warning(
    "Some education codes were not classified. ",
    "Review results/tables/unmapped_education_codes.csv ",
    "and the extract codebook before finalizing the analysis."
  )
}

# Use the same classified sample for all three figures.
cps_clean <- cps_eligible %>%
  filter(!is.na(education))

if (nrow(cps_clean) == 0) {
  stop("No observations remain after sample selection.")
}

write_csv(
  cps_clean,
  "data/cps_analysis_sample.csv.gz"
)

# ------------------------------------------------------------
# 4. Export sample diagnostics
# ------------------------------------------------------------

sample_summary <- cps_clean %>%
  group_by(YEAR, gender, education) %>%
  summarise(
    observations = n(),
    earnings_weight_sum = sum(EARNWT),
    min_weekly_earnings = min(EARNWEEK2),
    max_weekly_earnings = max(EARNWEEK2),
    .groups = "drop"
  )

write_csv(
  sample_summary,
  "results/tables/sample_summary.csv"
)

# ------------------------------------------------------------
# 5. Calculate weighted earnings and earnings ratios
# ------------------------------------------------------------

# This helper converts male and female means into a ratio.
calculate_ratio <- function(summary_data) {
  summary_data %>%
    pivot_wider(
      names_from = gender,
      values_from = mean_weekly_earnings
    ) %>%
    mutate(
      female_male_ratio = Female / Male
    ) %>%
    rename(
      female_mean_weekly_earnings = Female,
      male_mean_weekly_earnings = Male
    )
}

# Overall annual means and ratios.
wage_by_gender <- cps_clean %>%
  group_by(YEAR, gender) %>%
  summarise(
    mean_weekly_earnings = weighted.mean(
      EARNWEEK2, EARNWT
    ),
    .groups = "drop"
  )

wage_gap <- calculate_ratio(wage_by_gender)

# Education-group means and ratios pooled across 2015-2025.
# These are pooled nominal earnings ratios, not averages of
# the annual ratios.
wage_by_education <- cps_clean %>%
  group_by(education, gender) %>%
  summarise(
    mean_weekly_earnings = weighted.mean(
      EARNWEEK2, EARNWT
    ),
    .groups = "drop"
  )

wage_gap_education <- calculate_ratio(wage_by_education)

# Annual education-group means and ratios.
wage_by_education_year <- cps_clean %>%
  group_by(YEAR, education, gender) %>%
  summarise(
    mean_weekly_earnings = weighted.mean(
      EARNWEEK2, EARNWT
    ),
    .groups = "drop"
  )

wage_gap_education_year <- calculate_ratio(
  wage_by_education_year
)

# Check that both sexes have valid estimates in each group.
ratio_tables <- list(
  wage_gap,
  wage_gap_education,
  wage_gap_education_year
)

if (any(vapply(
  ratio_tables,
  function(x) any(!is.finite(x$female_male_ratio)),
  logical(1)
))) {
  stop(
    "A group is missing a valid male or female estimate. ",
    "Review sample_summary.csv."
  )
}

# ------------------------------------------------------------
# 6. Check education composition and overall consistency
# ------------------------------------------------------------

# Calculate education shares separately for men and women.
education_shares <- cps_clean %>%
  group_by(YEAR, gender, education) %>%
  summarise(
    group_weight = sum(EARNWT),
    .groups = "drop"
  ) %>%
  group_by(YEAR, gender) %>%
  mutate(
    education_share = group_weight / sum(group_weight)
  ) %>%
  ungroup()

# Reconstruct each overall mean using education-group means
# and the education shares for the same sex and year.
reconstructed_means <- education_shares %>%
  left_join(
    wage_by_education_year,
    by = c("YEAR", "gender", "education")
  ) %>%
  group_by(YEAR, gender) %>%
  summarise(
    reconstructed_mean = sum(
      education_share * mean_weekly_earnings
    ),
    .groups = "drop"
  )

consistency_check <- wage_by_gender %>%
  left_join(
    reconstructed_means,
    by = c("YEAR", "gender")
  ) %>%
  mutate(
    difference = mean_weekly_earnings -
      reconstructed_mean
  )

stopifnot(
  all(
    abs(consistency_check$difference) <
      1e-8 * pmax(
        1,
        abs(consistency_check$mean_weekly_earnings)
      )
  )
)

# ------------------------------------------------------------
# 7. Save result tables
# ------------------------------------------------------------

write_csv(
  wage_gap,
  "results/tables/overall_earnings_ratio.csv"
)

write_csv(
  wage_gap_education,
  "results/tables/education_earnings_ratio_pooled.csv"
)

write_csv(
  wage_gap_education_year,
  "results/tables/education_earnings_ratio_by_year.csv"
)

write_csv(
  education_shares,
  "results/tables/education_shares_by_sex_year.csv"
)

write_csv(
  consistency_check,
  "results/tables/overall_consistency_check.csv"
)

# ------------------------------------------------------------
# 8. Figure 1: Overall earnings ratio over time
# ------------------------------------------------------------

figure1 <- ggplot(
  wage_gap,
  aes(x = YEAR, y = female_male_ratio)
) +
  geom_line(linewidth = 0.9, color = "#24476B") +
  geom_point(size = 2, color = "#24476B") +
  scale_x_continuous(
    breaks = seq(2015, 2025, by = 2)
  ) +
  scale_y_continuous(
    labels = scales::label_percent(accuracy = 1)
  ) +
  labs(
    title = "Overall Female-to-Male Weekly Earnings Ratio",
    subtitle = "2015–2025",
    x = "Year",
    y = "Female / male mean weekly earnings",
    caption = paste(
      "Source: IPUMS CPS.",
      "Employed adults ages 25–64;",
      "positive valid earnings and EARNWT.",
      "Means weighted using EARNWT."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.caption = element_text(hjust = 0)
  )

# ------------------------------------------------------------
# 9. Figure 2: Pooled earnings ratio by education
# ------------------------------------------------------------

figure2 <- ggplot(
  wage_gap_education,
  aes(x = education, y = female_male_ratio)
) +
  geom_col(fill = "#477A9F", width = 0.7) +
  geom_text(
    aes(
      label = scales::percent(
        female_male_ratio,
        accuracy = 0.1
      )
    ),
    hjust = -0.15,
    size = 3.5
  ) +
  coord_flip() +
  scale_y_continuous(
    labels = scales::label_percent(accuracy = 1),
    limits = c(
      0,
      max(
        1,
        max(wage_gap_education$female_male_ratio) * 1.15
      )
    )
  ) +
  labs(
    title = "Female-to-Male Weekly Earnings Ratio by Education",
    subtitle = "Pooled observations, 2015–2025",
    x = NULL,
    y = "Female / male mean weekly earnings",
    caption = paste(
      "Source: IPUMS CPS; means weighted using EARNWT.",
      "\nRatios use pooled nominal earnings,",
      "not averages of annual ratios."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.caption = element_text(hjust = 0)
  )

# ------------------------------------------------------------
# 10. Figure 3: Education-specific ratios over time
# ------------------------------------------------------------

figure3 <- ggplot(
  wage_gap_education_year,
  aes(
    x = YEAR,
    y = female_male_ratio,
    color = education,
    linetype = education,
    group = education
  )
) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.5) +
  scale_x_continuous(
    breaks = seq(2015, 2025, by = 2)
  ) +
  scale_y_continuous(
    labels = scales::label_percent(accuracy = 1)
  ) +
  labs(
    title = "Education-Specific Earnings Ratios over Time",
    subtitle = "2015–2025",
    x = "Year",
    y = "Female / male mean weekly earnings",
    color = "Education",
    linetype = "Education",
    caption = paste(
      "Source: IPUMS CPS.",
      "Same analysis sample as Figures 1 and 2;",
      "means weighted using EARNWT."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    plot.caption = element_text(hjust = 0)
  ) +
  guides(
    color = guide_legend(ncol = 2),
    linetype = guide_legend(ncol = 2)
  )

# ------------------------------------------------------------
# 11. Save figures and record the R environment
# ------------------------------------------------------------

ggsave(
  "results/figures/figure1.png",
  plot = figure1,
  width = 10,
  height = 6,
  dpi = 300,
  bg = "white"
)

ggsave(
  "results/figures/figure2.png",
  plot = figure2,
  width = 10,
  height = 6,
  dpi = 300,
  bg = "white"
)

ggsave(
  "results/figures/figure3.png",
  plot = figure3,
  width = 10,
  height = 7,
  dpi = 300,
  bg = "white"
)

writeLines(
  capture.output(sessionInfo()),
  "results/session_info.txt"
)

# Display the figures in RStudio.
print(figure1)
print(figure2)
print(figure3)

message(
  "Analysis completed. Figures and tables are saved in results/."
)

# Print key tables for review.
print(wage_gap)
print(wage_gap_education)
print(unmapped_education)




# Display all annual earnings ratios.
wage_gap %>%
  select(YEAR, female_male_ratio) %>%
  print(n = Inf, width = Inf)

# Display pooled earnings ratios by education.
wage_gap_education %>%
  select(education, female_male_ratio) %>%
  print(n = Inf, width = Inf)

# Compare education-specific ratios in selected years.
wage_gap_education_year %>%
  filter(YEAR %in% c(2022, 2023, 2025)) %>%
  select(YEAR, education, female_male_ratio) %>%
  print(n = Inf, width = Inf)

# Compare men's and women's education composition in 2023.
education_shares %>%
  filter(YEAR == 2023) %>%
  select(education, gender, education_share) %>%
  pivot_wider(
    names_from = gender,
    values_from = education_share
  ) %>%
  print(n = Inf, width = Inf)

# Inspect the earnings range for potential coding issues.
sample_summary %>%
  group_by(YEAR) %>%
  summarise(
    observations = sum(observations),
    min_weekly_earnings = min(min_weekly_earnings),
    max_weekly_earnings = max(max_weekly_earnings),
    .groups = "drop"
  ) %>%
  print(n = Inf, width = Inf)



# ------------------------------------------------------------
# 12. Sensitivity analysis: Apply a common earnings cap
# ------------------------------------------------------------

# Preserve the original estimates and compare them with estimates
# using a fixed cap across all years.
# This checks sensitivity to upper-tail earnings treatment;
# it does not fully harmonize all measurement changes.

common_cap <- 2884.61

cps_sensitivity <- cps_clean %>%
  mutate(
    weekly_earnings_capped = pmin(
      EARNWEEK2, common_cap
    )
  )

# Overall annual ratios using the common cap.
capped_overall <- cps_sensitivity %>%
  group_by(YEAR, gender) %>%
  summarise(
    mean_weekly_earnings = weighted.mean(
      weekly_earnings_capped, EARNWT
    ),
    .groups = "drop"
  ) %>%
  calculate_ratio()

# Annual education-specific ratios using the common cap.
capped_education_year <- cps_sensitivity %>%
  group_by(YEAR, education, gender) %>%
  summarise(
    mean_weekly_earnings = weighted.mean(
      weekly_earnings_capped, EARNWT
    ),
    .groups = "drop"
  ) %>%
  calculate_ratio()

# Compare original and capped overall estimates.
topcode_comparison <- wage_gap %>%
  select(
    YEAR,
    original_ratio = female_male_ratio
  ) %>%
  left_join(
    capped_overall %>%
      select(
        YEAR,
        common_cap_ratio = female_male_ratio
      ),
    by = "YEAR"
  ) %>%
  mutate(
    difference_percentage_points =
      100 * (common_cap_ratio - original_ratio)
  )

write_csv(
  topcode_comparison,
  "results/tables/topcode_sensitivity_overall.csv"
)

write_csv(
  capped_education_year,
  "results/tables/topcode_sensitivity_education_year.csv"
)

print(topcode_comparison, n = Inf, width = Inf)

capped_education_year %>%
  filter(YEAR %in% c(2022, 2023, 2025)) %>%
  select(YEAR, education, female_male_ratio) %>%
  print(n = Inf, width = Inf)


# ------------------------------------------------------------
# 13. Figure 4: Sensitivity to a common earnings cap
# ------------------------------------------------------------

sensitivity_plot_data <- topcode_comparison %>%
  select(
    YEAR,
    original_ratio,
    common_cap_ratio
  ) %>%
  pivot_longer(
    cols = c(original_ratio, common_cap_ratio),
    names_to = "series",
    values_to = "female_male_ratio"
  ) %>%
  mutate(
    series = factor(
      series,
      levels = c(
        "original_ratio",
        "common_cap_ratio"
      ),
      labels = c(
        "Reported earnings",
        "Earnings capped at $2,884.61"
      )
    )
  )

figure4 <- ggplot(
  sensitivity_plot_data,
  aes(
    x = YEAR,
    y = female_male_ratio,
    color = series,
    linetype = series
  )
) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2) +
  scale_color_manual(
    values = c("#24476B", "#B65C28")
  ) +
  scale_x_continuous(
    breaks = seq(2015, 2025, by = 2)
  ) +
  scale_y_continuous(
    labels = scales::label_percent(accuracy = 1)
  ) +
  labs(
    title = "How Sensitive Is the Trend to Earnings Capping?",
    subtitle = "Overall female-to-male weekly earnings ratio, 2015–2025",
    x = "Year",
    y = "Female / male mean weekly earnings",
    color = NULL,
    linetype = NULL,
    caption = paste(
      "Source: IPUMS CPS; means weighted using EARNWT.",
      "\nThe capped series replaces earnings above $2,884.61",
      "with $2,884.61 in every year.",
      "\nThis sensitivity check changes the earnings measure;",
      "it does not recover uncensored earnings."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    plot.caption = element_text(hjust = 0)
  )

ggsave(
  "results/figures/figure4_topcode_sensitivity.png",
  plot = figure4,
  width = 11,
  height = 7,
  dpi = 300,
  bg = "white"
)

print(figure4)

source("code/01_gender_earnings_analysis.R")