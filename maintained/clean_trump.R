# coppock_2017a/maintained/clean_trump.R
# Output: output/trump.rds, output/income_quintile_check.csv
# Depends on: original/shy_trump_cleaned.csv, helpers.R
# Description: Read the deposited respondent-level file, check it against what
#   the paper describes, and save the analysis frame the other scripts read.

source(here::here("maintained", "helpers.R"))

dir.create(here::here("maintained", "output"), showWarnings = FALSE)

trump <- read_csv(
  here::here("original", "shy_trump_cleaned.csv"),
  show_col_types = FALSE
)

# Checks ----
# The deposit is already an analysis file, so there is no recoding to do. What is
# worth doing is confirming it is the file the paper describes before any estimate
# is computed: 5,290 respondents, a binary list-experiment assignment, a control
# list of three items and a treatment list of four, and the subgroup variables
# Figure 1 and Table A1 are built from.
stopifnot(
  nrow(trump) == 5290,
  setequal(trump$Z, c(0, 1)),
  max(trump$list_Y[trump$Z == 0]) == 3,
  max(trump$list_Y[trump$Z == 1]) == 4,
  all(c("direct_Y", "vote_choice", "WEIGHTS") %in% names(trump)),
  all(setdiff(subgroup_vars, "entire_sample") %in% names(trump))
)

# Every subgroup the paper reports must exist in the data, and the data must not
# contain a subgroup the paper does not report. This is the check that catches
# the income-quintile mislabeling in the deposited script: it compares the keys
# the data actually carries against the keys the label table claims.
observed_keys <- trump |>
  mutate(entire_sample = 1L) |>
  pivot_longer(
    cols = all_of(subgroup_vars),
    names_to = "col",
    values_to = "value",
    values_transform = list(value = as.character)
  ) |>
  distinct(group_key = paste0(col, "_", value)) |>
  pull(group_key)

stopifnot(setequal(observed_keys, subgroups$group_key))

# The income quintiles must partition the 22-point income measure into contiguous
# blocks in the order their names claim. This is what makes the errata a fact
# about the deposited script rather than a guess about the data.
income_check <- trump |>
  summarize(min_income = min(USHHI2), max_income = max(USHHI2), n = n(),
            .by = income_quintile) |>
  arrange(min_income)

stopifnot(identical(
  income_check$income_quintile,
  c("Below 20th Income Percentile", "20th - 40th Income Percentile",
    "40th - 60th Income Percentile", "60th - 80th Income Percentile",
    "Above 80th Income Percentile")
))

write_csv(income_check,
          here::here("maintained", "output", "income_quintile_check.csv"))

write_rds(trump, here::here("maintained", "output", "trump.rds"))

print(str_glue("Saved maintained/output/trump.rds: {nrow(trump)} rows, {ncol(trump)} columns."))
