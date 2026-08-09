# coppock_2017a/maintained/helpers.R
# Shared packages, subgroup definitions and formatting helpers sourced by every
# script in maintained/.

library(here)
library(tidyverse)
library(estimatr)
library(survey)
library(list)
library(rsample)
library(knitr)
library(kableExtra)

here::i_am("maintained/helpers.R")

# Subgroup definitions ----
# One row per subgroup shown in Figure 1 and Appendix Table A1, in the order the
# published table prints them. group_key is what the analysis scripts build as
# paste0(variable, "_", value) after reshaping to one row per respondent per
# subgroup; group_label is the label the paper prints.
#
# The income rows are where the deposited script goes wrong: its labels vector is
# in substantive order while its levels vector is alphabetical, so each income
# level is printed under the label of the quintile below it. The mapping below is
# the one the deposited data supports. income_quintile is a self-describing
# character variable whose five categories partition the household income measure
# USHHI2 into contiguous, correctly ordered blocks, so the group the data calls
# "Below 20th Income Percentile" is the bottom quintile and nothing else. See the
# Errata section of the report.
subgroups <- tribble(
  ~group_key, ~group_label, ~subgroup,
  "entire_sample_1", "Entire sample", "Entire sample",
  "pid_7_1", "Strong democrat", "Party ID",
  "pid_7_2", "Not very strong democrat", "Party ID",
  "pid_7_3", "Lean democrat", "Party ID",
  "pid_7_4", "Independent", "Party ID",
  "pid_7_5", "Lean republican", "Party ID",
  "pid_7_6", "Not very strong republican", "Party ID",
  "pid_7_7", "Strong republican", "Party ID",
  "EDUATT_1", "Less than high school", "Education",
  "EDUATT_2", "High school or some college", "Education",
  "EDUATT_3", "College", "Education",
  "EDUATT_4", "Graduate school", "Education",
  "income_quintile_Below 20th Income Percentile", "Below 20th income percentile", "Income",
  "income_quintile_20th - 40th Income Percentile", "20th-40th income percentile", "Income",
  "income_quintile_40th - 60th Income Percentile", "40th-60th income percentile", "Income",
  "income_quintile_60th - 80th Income Percentile", "60th-80th income percentile", "Income",
  "income_quintile_Above 80th Income Percentile", "Above 80th income percentile", "Income",
  "female_0", "Men", "Gender",
  "female_1", "Women", "Gender",
  "race_4_White", "White", "Race",
  "race_4_Black", "Black", "Race",
  "race_4_Hispanic", "Hispanic", "Race",
  "race_4_Other Race", "Other race", "Race",
  "LV_INDEX_DUMMY_0", "Unlikely voter", "Vote propensity",
  "LV_INDEX_DUMMY_1", "Likely voter", "Vote propensity"
)

subgroup_order <- c("Entire sample", "Party ID", "Education", "Income",
                    "Gender", "Race", "Vote propensity")

# The variables that define the subgroups, reshaped to long form by the analysis
# scripts. entire_sample is added as a constant so the whole sample is one more
# group rather than a special case.
subgroup_vars <- c("pid_7", "female", "race_4", "LV_INDEX_DUMMY",
                   "EDUATT", "income_quintile", "entire_sample")

# The six estimators, in the order the paper's legend and table columns use.
estimator_levels <- c("direct_est", "list_est", "difference",
                      "direct_est_adj", "list_est_adj", "difference_adj")

estimator_labels <- c("Direct question estimate",
                      "List experiment estimate",
                      "Difference",
                      "Adjusted direct question estimate",
                      "Adjusted list experiment estimate",
                      "Adjusted difference")

# Formatting ----
# Table A1 prints percentage points to one decimal with the bootstrap standard
# error in parentheses.
fmt_pct <- function(x, digits = 1) formatC(x * 100, digits = digits, format = "f")

fmt_pct_se <- function(est, se, digits = 1) {
  paste0(fmt_pct(est, digits), " (", fmt_pct(se, digits), ")")
}

# Blank a figure PDF's embedded timestamps ----
# R's pdf() device stamps /CreationDate and /ModDate with the wall clock, so an
# otherwise deterministic pipeline writes a different file on every run. The epoch
# string is the same width as what it replaces, which keeps the cross-reference byte
# offsets valid, and a file with no timestamp is left alone.
blank_pdf_timestamps <- function(path) {
  epoch <- charToRaw("D:19700101000000")
  raw_pdf <- readBin(path, "raw", file.size(path))
  hits <- grepRaw("D:[0-9]{14}", raw_pdf, all = TRUE)
  if (length(hits) == 0) return(invisible(path))
  for (h in hits) raw_pdf[h:(h + length(epoch) - 1L)] <- epoch
  writeBin(raw_pdf, path)
  invisible(path)
}
