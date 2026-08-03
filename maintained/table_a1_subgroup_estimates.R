# coppock_2017a/maintained/table_a1_subgroup_estimates.R
# Output: output/table_a1_subgroup_estimates.csv,
#         output/table_a1_subgroup_estimates.tex
# Depends on: output/figure_1_direct_vs_list_estimates.csv, helpers.R
# Description: The Figure 1 estimates as a table. Reproduces published Table A1.
#   Runs after figure_1_direct_vs_list_estimates.R, whose bootstrap it reads
#   rather than repeating.

source(here::here("maintained", "helpers.R"))

ests <- read_csv(
  here::here("maintained", "output", "figure_1_direct_vs_list_estimates.csv"),
  show_col_types = FALSE
)

tab <- ests |>
  mutate(
    entry = fmt_pct_se(est, se),
    estimator = factor(estimator, levels = estimator_labels),
    subgroup = factor(subgroup, levels = subgroup_order),
    group_label = factor(group_label, levels = subgroups$group_label)
  ) |>
  select(group_label, subgroup, n, estimator, entry) |>
  pivot_wider(names_from = estimator, values_from = entry) |>
  arrange(subgroup, group_label) |>
  select(-subgroup)

write_csv(tab, here::here("maintained", "output", "table_a1_subgroup_estimates.csv"))

# A rule below the entire-sample row and below each subgroup block, matching the
# published table.
block_ends <- ests |>
  distinct(group_label, subgroup) |>
  mutate(subgroup = factor(subgroup, levels = subgroup_order),
         group_label = factor(group_label, levels = subgroups$group_label)) |>
  arrange(subgroup, group_label) |>
  mutate(row = row_number()) |>
  slice_max(row, by = subgroup) |>
  pull(row)

tab |>
  kable(
    format = "latex",
    booktabs = TRUE,
    col.names = c("Subgroup", "N", "Direct question", "List experiment", "Difference",
                  "Adjusted direct question", "Adjusted list experiment",
                  "Adjusted difference"),
    align = c("l", "r", rep("r", 6)),
    caption = "Comparing Direct Question and List Experimental Estimates of Trump Support",
    label = "subgroup_estimates"
  ) |>
  kable_styling(latex_options = c("hold_position", "scale_down"), font_size = 8) |>
  row_spec(head(block_ends, -1), hline_after = TRUE) |>
  add_footnote(
    c("All estimates incorporate sampling weights and are in percentage points.",
      "Bootstrapped standard errors (2,000 replicates) are in parentheses.",
      "Adjusted direct question estimates are predictions from a logistic regression.",
      "Adjusted list experiment estimates are predictions from Imai's (2011) NLS regression model."),
    notation = "none"
  ) |>
  write_lines(here::here("maintained", "output", "table_a1_subgroup_estimates.tex"))

print(tab, n = nrow(tab))
