# coppock_2017a/maintained/table_2_list_response_distribution.R
# Output: output/table_2_list_response_distribution.csv,
#         output/table_2_list_response_distribution.tex
# Depends on: output/trump.rds, helpers.R
# Description: Weighted distribution of list-experiment responses by treatment
#   condition. Reproduces published Table 2. (The deposited script calls this
#   Table 1; Table 1 in the published paper is the wording of the two lists,
#   which is not computed from data.)

source(here::here("maintained", "helpers.R"))

trump <- read_rds(here::here("maintained", "output", "trump.rds"))

design <- svydesign(ids = ~1, weights = ~WEIGHTS, data = trump)

shares <- prop.table(svytable(~list_Y + Z, design), margin = 2) |>
  as_tibble() |>
  mutate(
    items = paste0(list_Y, if_else(list_Y == "1", " item", " items")),
    condition = if_else(Z == "0", "Control list", "Treatment list")
  ) |>
  select(items, condition, n) |>
  pivot_wider(names_from = condition, values_from = n)

counts <- trump |>
  summarize(n = n(), .by = Z) |>
  mutate(condition = if_else(Z == 0, "Control list", "Treatment list"), items = "N") |>
  select(items, condition, n) |>
  pivot_wider(names_from = condition, values_from = n)

tab <- bind_rows(shares, counts)

write_csv(tab, here::here("maintained", "output", "table_2_list_response_distribution.csv"))

tab |>
  mutate(across(-items, \(x) if_else(items == "N",
                                     formatC(x, format = "d"),
                                     formatC(x, digits = 2, format = "f")))) |>
  kable(
    format = "latex",
    booktabs = TRUE,
    col.names = c("", "Control list", "Treatment list"),
    align = c("l", "r", "r"),
    caption = "Distribution of List Experiment Responses by Treatment Condition",
    label = "list_response_distribution"
  ) |>
  kable_styling(latex_options = "hold_position") |>
  add_footnote("Entries are weighted proportions.", notation = "none") |>
  write_lines(here::here("maintained", "output", "table_2_list_response_distribution.tex"))

print(tab)
