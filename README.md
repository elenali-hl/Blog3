# Blog3
# Blog Post 3: Gender Wage Gaps Across Education Levels

## Research Question

How does the gender wage gap vary across education levels in the United States?

This project uses U.S. Current Population Survey (CPS) microdata to examine differences in weekly earnings between men and women from 2015 to 2025. The analysis focuses on whether the female-to-male earnings ratio varies across education groups and how these patterns change over time.

---

## Data

The data come from the **Current Population Survey (CPS)** provided through **IPUMS CPS**.

- **Data source:** IPUMS Current Population Survey (CPS)
- **Years:** 2015–2025
- **Population:** U.S. adults ages 25–64
- **Employment status:** Employed individuals
- **Unit of observation:** Individual respondents
- **Key variables:**
  - `YEAR`: Survey year
  - `AGE`: Respondent age
  - `SEX`: Sex
  - `EDUC`: Educational attainment
  - `EMPSTAT`: Employment status
  - `EARNWEEK2`: Weekly earnings
  - `EARNWT`: Earnings weight

The analysis uses `EARNWT` to calculate weighted mean weekly earnings so that the results better represent the U.S. population rather than treating every CPS observation as equally representative.

---

## Sample Selection

The analysis restricts the CPS sample to:

- Adults ages **25–64**
- Years **2015–2025**
- Individuals who are employed
- Valid positive weekly earnings
- Positive earnings weights

Employed individuals are defined using the CPS `EMPSTAT` codes:

- `10`: At work
- `12`: Has a job but was not at work

Invalid or unavailable earnings values are excluded from the analysis.

---

## Education Groups

Educational attainment is grouped into five categories:

1. Less than high school
2. High school
3. Some college / Associate
4. Bachelor's
5. Advanced degree

---

## Methodology

For each year and demographic group, weighted mean weekly earnings are calculated using the CPS earnings weight:

```r
weighted.mean(EARNWEEK2, EARNWT)