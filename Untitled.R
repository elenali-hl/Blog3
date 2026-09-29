# ============================================================
# Blog Post 3: Gender Wage Gap and Education
# ============================================================

# ------------------------------------------------------------
# 1. Load packages and data
# ------------------------------------------------------------

library(tidyverse)

cps <- read_csv(
  "data/cps_00002.csv.gz",
  col_select = c(
    YEAR,
    AGE,
    SEX,
    EDUC,
    EMPSTAT,
    EARNWT,
    EARNWEEK2
  )
)

# Quick check
glimpse(cps)


# ------------------------------------------------------------
# 2. Define the sample
# ------------------------------------------------------------

# Sample:
# - Adults ages 25–64
# - Employed
# - Years 2015–2025
# - Positive earnings weight
# - Valid weekly earnings

cps_clean <- cps %>%
  filter(
    YEAR >= 2015,
    YEAR <= 2025,
    AGE >= 25,
    AGE <= 64,
    EMPSTAT %in% c(10, 12),
    EARNWEEK2 > 0,
    EARNWEEK2 < 999999,
    EARNWT > 0
  )


# ------------------------------------------------------------
# 3. Recode gender and education
# ------------------------------------------------------------

cps_clean <- cps_clean %>%
  mutate(
    gender = case_when(
      SEX == 1 ~ "Male",
      SEX == 2 ~ "Female",
      TRUE ~ NA_character_
    ),
    
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
    )
  ) %>%
  mutate(
    education = factor(
      education,
      levels = c(
        "Less than high school",
        "High school",
        "Some college / Associate",
        "Bachelor's",
        "Advanced degree"
      )
    )
  )


# Check the cleaned sample
dim(cps_clean)
table(cps_clean$YEAR)
table(cps_clean$gender)
table(cps_clean$education, useNA = "ifany")


# ------------------------------------------------------------
# 4. Overall gender wage gap
# ------------------------------------------------------------

# Calculate weighted average weekly earnings by year and gender

wage_by_gender <- cps_clean %>%
  group_by(YEAR, gender) %>%
  summarise(
    mean_weekly_earnings = weighted.mean(
      EARNWEEK2,
      EARNWT,
      na.rm = TRUE
    ),
    .groups = "drop"
  )

wage_by_gender


# Calculate female-to-male weekly earnings ratio

wage_gap <- wage_by_gender %>%
  group_by(YEAR) %>%
  summarise(
    female_wage = mean_weekly_earnings[gender == "Female"],
    male_wage = mean_weekly_earnings[gender == "Male"],
    female_male_ratio = female_wage / male_wage,
    .groups = "drop"
  )

wage_gap


# ------------------------------------------------------------
# Figure 1: Overall gender wage gap over time
# ------------------------------------------------------------

ggplot(
  wage_gap,
  aes(x = YEAR, y = female_male_ratio)
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_y_continuous(
    labels = scales::percent,
    limits = c(0.65, 0.85)
  ) +
  labs(
    title = "Female-to-Male Weekly Earnings Ratio, 2015–2025",
    x = "Year",
    y = "Female / Male Weekly Earnings"
  ) +
  theme_minimal()


# ------------------------------------------------------------
# 5. Gender wage gap by education
# ------------------------------------------------------------

# Calculate weighted average weekly earnings
# by education and gender

wage_by_education <- cps_clean %>%
  group_by(education, gender) %>%
  summarise(
    mean_weekly_earnings = weighted.mean(
      EARNWEEK2,
      EARNWT,
      na.rm = TRUE
    ),
    .groups = "drop"
  )

wage_by_education


# Calculate female-to-male earnings ratio
# for each education group

wage_gap_education <- wage_by_education %>%
  group_by(education) %>%
  summarise(
    female_wage = mean_weekly_earnings[gender == "Female"],
    male_wage = mean_weekly_earnings[gender == "Male"],
    female_male_ratio = female_wage / male_wage,
    .groups = "drop"
  )

wage_gap_education


# ------------------------------------------------------------
# Figure 2: Gender wage gap by education
# ------------------------------------------------------------

ggplot(
  wage_gap_education,
  aes(x = education, y = female_male_ratio)
) +
  geom_col() +
  scale_y_continuous(
    labels = scales::percent,
    limits = c(0, 0.85)
  ) +
  labs(
    title = "Female-to-Male Weekly Earnings Ratio by Education",
    x = "Education Level",
    y = "Female / Male Weekly Earnings"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 20, hjust = 1)
  )


# ------------------------------------------------------------
# 6. Gender wage gap by education and year
# ------------------------------------------------------------

# Calculate weighted average weekly earnings
# by year, education, and gender

wage_by_education_year <- cps_clean %>%
  group_by(YEAR, education, gender) %>%
  summarise(
    mean_weekly_earnings = weighted.mean(
      EARNWEEK2,
      EARNWT,
      na.rm = TRUE
    ),
    .groups = "drop"
  )


# Calculate female-to-male earnings ratio
# for each education group and year

wage_gap_education_year <- wage_by_education_year %>%
  group_by(YEAR, education) %>%
  summarise(
    female_wage = mean_weekly_earnings[gender == "Female"],
    male_wage = mean_weekly_earnings[gender == "Male"],
    female_male_ratio = female_wage / male_wage,
    .groups = "drop"
  )

wage_gap_education_year


# ------------------------------------------------------------
# Figure 3: Education-specific gender wage gap over time
# ------------------------------------------------------------

ggplot(
  wage_gap_education_year,
  aes(
    x = YEAR,
    y = female_male_ratio,
    group = education,
    linetype = education
  )
) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.8) +
  scale_y_continuous(
    labels = scales::percent,
    limits = c(0.60, 0.85)
  ) +
  labs(
    title = "Female-to-Male Weekly Earnings Ratio by Education",
    subtitle = "2015–2025",
    x = "Year",
    y = "Female / Male Weekly Earnings",
    linetype = "Education"
  ) +
  theme_minimal()