# Gender Earnings Gaps Across Education Levels

This project uses IPUMS Current Population Survey (CPS) microdata to examine how female-to-male mean weekly earnings ratios vary across education groups and over time, using available observations from 2015–2025.

The analysis generates four figures, summary tables, and a sensitivity analysis examining how a common earnings cap affects the overall trend.

## Repository Structure

```text
Blog3/
├── code/
│   └── 01_gender_earnings_analysis.R
├── data-raw/
│   ├── cps_00002.csv.gz              # Local IPUMS extract; not tracked
│   └── [extract codebook]            # Local extract documentation
├── data/
│   └── cps_analysis_sample.csv.gz    # Generated locally; not tracked
├── results/
│   ├── figures/
│   │   ├── figure1.png
│   │   ├── figure2.png
│   │   ├── figure3.png
│   │   └── figure4_topcode_sensitivity.png
│   ├── tables/
│   │   └── [generated CSV tables]
│   └── session_info.txt
├── .gitignore
└── README.md
```

The main analysis script is
[`code/01_gender_earnings_analysis.R`](code/01_gender_earnings_analysis.R).

The accompanying article is maintained separately in the course blog-post repository.

## Data Source and Access

The source is [IPUMS CPS](https://cps.ipums.org/cps/).

The original microdata are not included in this repository. Replication requires an IPUMS account and an authorized CPS extract.

To prepare the data:

1. Sign in to IPUMS CPS.
2. Select the relevant samples for 2015–2025.
3. Include the variables listed below.
4. Download the extract in CSV format, together with its codebook.
5. Place the compressed CSV in `data-raw/` and name it
   `cps_00002.csv.gz`.

For exact replication, use the original extract's sample selections,
available months, and variable definitions. Selecting the same years
alone does not guarantee an identical extract. Check the original
codebook and extract history for these details.

The script reads the compressed CSV directly using `readr::read_csv()`.
No spreadsheet editing or manual copying of results is required.

### Required Variables

| Variable | Description |
|---|---|
| `YEAR` | Survey year |
| `AGE` | Respondent age |
| `SEX` | Sex recorded in CPS |
| `EDUC` | Educational attainment |
| `EMPSTAT` | Employment status |
| `EARNWEEK2` | Rounded usual weekly earnings |
| `EARNWT` | Earnings sampling weight |

See the IPUMS documentation for
[`EARNWEEK2`](https://cps.ipums.org/cps-action/variables/EARNWEEK2),
[`EARNWT`](https://cps.ipums.org/cps-action/variables/EARNWT), and
[`EDUC`](https://cps.ipums.org/cps-action/variables/EDUC).

## Software Requirements

The analysis uses R and the `tidyverse` package collection.

Install the required packages once:

```r
install.packages("tidyverse")
```

The script uses functions from `dplyr`, `tidyr`, `readr`, `ggplot2`,
and `scales`. The recorded R session and package versions are saved
in `results/session_info.txt`.

## Replication Instructions

1. Clone or download this repository.
2. Place the original extract in `data-raw/cps_00002.csv.gz`.
3. Open R or RStudio and set the working directory to the repository root.
4. Run the entire main script:

```r
source("code/01_gender_earnings_analysis.R")
```

Alternatively, from a terminal opened at the repository root:

```bash
Rscript code/01_gender_earnings_analysis.R
```

The script creates missing output directories and overwrites generated
files with the current results.

If the expected data file is missing, the script opens a file-selection
dialog. This fallback is intended for interactive use in RStudio.
For terminal execution, place the data at the expected path first.

## Sample and Methods

The analysis restricts observations to:

- Survey years 2015–2025.
- Ages 25–64.
- Employed respondents: `EMPSTAT` equal to 10 or 12.
- `SEX` equal to 1 or 2.
- Finite, positive earnings weights.
- Finite weekly earnings greater than zero and below 999999.
- Educational attainment classified into one of the five groups below.

The earnings restrictions should be interpreted using the original
extract's codebook and monetary units.

The five education groups are:

1. Less than high school.
2. High school.
3. Some college / Associate.
4. Bachelor's.
5. Advanced degree.

The script exports any unclassified education codes for review.
All main figures use the same classified analysis sample.

Within each relevant group, mean weekly earnings are calculated using
`EARNWT`. The female-to-male earnings ratio is the weighted mean for
women divided by the weighted mean for men.

These estimates describe the selected earnings sample, rather than
all adults or all employed workers.

## Generated Figures

| File | Description |
|---|---|
| `figure1.png` | Overall annual female-to-male earnings ratio |
| `figure2.png` | Education-specific ratios using pooled 2015–2025 observations |
| `figure3.png` | Annual earnings ratios within education groups |
| `figure4_topcode_sensitivity.png` | Overall reported-earnings ratios compared with common-cap ratios |

Figure 2 uses pooled nominal earnings. It is not a comparison for a
single year or an average of annual ratios.

## Generated Tables

All tables are saved in `results/tables/`.

| File | Contents |
|---|---|
| `education_codes.csv` | Education-code frequencies in the imported data |
| `unmapped_education_codes.csv` | Unclassified education codes among otherwise eligible observations |
| `sample_summary.csv` | Observation counts, weight sums, and earnings ranges by year, sex, and education |
| `overall_earnings_ratio.csv` | Overall annual male and female means and their ratio |
| `education_earnings_ratio_pooled.csv` | Pooled means and ratios by education |
| `education_earnings_ratio_by_year.csv` | Annual means and ratios by education |
| `education_shares_by_sex_year.csv` | Weighted education shares within each sex and year |
| `overall_consistency_check.csv` | Direct overall means compared with means reconstructed from education groups |
| `topcode_sensitivity_overall.csv` | Overall ratios under the two earnings treatments |
| `topcode_sensitivity_education_year.csv` | Annual education-specific means and ratios under the common cap |

The cleaned analysis sample is saved locally as
`data/cps_analysis_sample.csv.gz`.

## Consistency and Sensitivity Checks

### Education Composition

The overall earnings ratio is not a simple average of education-specific
ratios because men and women have different education distributions.

The script reconstructs each overall mean using education-group means
and education shares calculated separately for men and women. It checks
that these reconstructed means match the directly calculated means
within numerical tolerance.

### Common Earnings Cap

The script also replaces weekly earnings above $2,884.61 with $2,884.61
in every year and recalculates the ratios using the same sample and
weights.

This check examines sensitivity to upper-tail earnings treatment.
The capped series measures a different earnings outcome; it does not
recover uncensored earnings or fully resolve measurement differences
across years.

## Main Findings and Interpretation

- Pooled reported-earnings ratios range from approximately 67.9% for
  workers with less than a high school education to 76.0% for workers
  with advanced degrees.
- Differences in education composition help explain why the overall
  ratio can exceed education-specific ratios.
- The reported-earnings ratio falls from approximately 80.6% in 2022
  to 73.9% in 2025.
- Under the common cap, the 2025 ratio is approximately 81.2%.
  The apparent post-2022 decline is therefore highly sensitive to
  upper-tail earnings treatment.

These are descriptive findings. Weekly earnings reflect both pay rates
and hours worked. The analysis does not identify causal effects of
education or measure discrimination. Annual comparisons also require
attention to extract month coverage and changes in earnings measurement.

## Data Handling

Keep the original microdata and generated person-level analysis sample
local. The `.gitignore` file excludes these data files from version
control while allowing code, documentation, figures, and summary tables
to be tracked.

Consult the applicable IPUMS data-use conditions before sharing
person-level data.