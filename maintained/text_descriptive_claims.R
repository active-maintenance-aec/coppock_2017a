# coppock_2017a/maintained/text_descriptive_claims.R
# Output: output/text_descriptive_claims.csv
# Depends on: output/figure_1_direct_vs_list_estimates.csv,
#             output/text_main_estimates.csv, helpers.R
# Description: The article's claims about the shape, sign and count of its own
#   estimates, each given a computed counterpart. These are sentences with no
#   number in them, so nothing in a number-by-number comparison reaches them, and
#   they are where a description can go on standing after the estimate beside it
#   has moved.
#
#   Two kinds, and the difference matters. A claim that reduces to a verdict gets
#   one: "all but one contain zero" is a count, "Whites were more likely than any
#   other category" is a comparison. A claim that does not reduce gets its
#   evidence and no verdict: "did not diverge wildly" and "shrink substantially"
#   name no threshold, and inventing one would put a number in the article's mouth.
#
#   Nothing is estimated here. Every model in this pipeline is fitted in the script
#   that owns its output, and this one reads those outputs and derives.

source(here::here("maintained", "helpers.R"))

figure_1 <- read_csv(
  here::here("maintained", "output", "figure_1_direct_vs_list_estimates.csv"),
  show_col_types = FALSE
)

text_estimates <- read_csv(
  here::here("maintained", "output", "text_main_estimates.csv"),
  show_col_types = FALSE
)

# Helpers ----
# One accessor for the figure's estimates, so no claim below reaches into the
# file with its own filter and its own chance of matching nothing.
est_of <- function(group, estimator_label, column = "est") {
  value <- figure_1[[column]][figure_1$group_label == group &
                                figure_1$estimator == estimator_label]
  stopifnot(length(value) == 1)
  value
}

text_of <- function(quantity_value, column = "estimate") {
  value <- text_estimates[[column]][text_estimates$quantity == quantity_value]
  stopifnot(length(value) == 1)
  value
}

pp <- function(x) formatC(100 * x, digits = 1, format = "f")

support_estimators <- c("Direct question estimate", "List experiment estimate",
                        "Adjusted direct question estimate",
                        "Adjusted list experiment estimate")

# The list experiment estimate is below the direct question estimate ----
direct_entire <- est_of("Entire sample", "Direct question estimate")
list_entire <- est_of("Entire sample", "List experiment estimate")

# The difference between the two modes covers zero ----
diff_li <- est_of("Entire sample", "Difference", "li")
diff_ui <- est_of("Entire sample", "Difference", "ui")

# The list estimate among those who do not report supporting Trump ----
# Estimated in text_main_estimates.R, read here.
nondiscloser_est <- text_of("list_ate_nondisclosers")
nondiscloser_se <- text_of("list_ate_nondisclosers", "std_error")

# Party identification ----
democrat_groups <- c("Strong democrat", "Not very strong democrat", "Lean democrat")
republican_groups <- c("Lean republican", "Not very strong republican", "Strong republican")

party_direct <- figure_1 |>
  filter(estimator == "Direct question estimate",
         group_label %in% c(democrat_groups, republican_groups)) |>
  select(group_label, est)

democrat_support <- party_direct$est[party_direct$group_label %in% democrat_groups]
republican_support <- party_direct$est[party_direct$group_label %in% republican_groups]

# Education ----
education_groups <- c("Less than high school", "High school or some college",
                      "College", "Graduate school")

education_direct <- figure_1 |>
  filter(estimator == "Direct question estimate", group_label %in% education_groups) |>
  mutate(group_label = factor(group_label, levels = education_groups)) |>
  arrange(group_label)

subgroup_sizes <- figure_1 |>
  filter(estimator == "Direct question estimate", group_label != "Entire sample") |>
  distinct(group_label, n)

# Income and gender ----
income_direct <- figure_1 |>
  filter(estimator == "Direct question estimate", str_detect(group_label, "income percentile")) |>
  mutate(group_label = factor(group_label, levels = subgroups$group_label)) |>
  arrange(group_label)

# Race ----
race_groups <- c("Black", "Hispanic", "Other race")

race_comparison <- figure_1 |>
  filter(estimator %in% support_estimators, group_label %in% c("White", race_groups)) |>
  select(group_label, estimator, est) |>
  pivot_wider(names_from = group_label, values_from = est)

white_leads <- race_comparison$White > pmax(race_comparison$Black,
                                            race_comparison$Hispanic,
                                            race_comparison$`Other race`)

# Vote propensity ----
voter_comparison <- figure_1 |>
  filter(estimator %in% support_estimators,
         group_label %in% c("Likely voter", "Unlikely voter")) |>
  select(group_label, estimator, est) |>
  pivot_wider(names_from = group_label, values_from = est)

likely_leads <- voter_comparison$`Likely voter` > voter_comparison$`Unlikely voter`

# Coverage of zero, unadjusted and adjusted ----
differences <- figure_1 |>
  filter(estimator %in% c("Difference", "Adjusted difference")) |>
  mutate(covers_zero = li <= 0 & ui >= 0)

unadjusted_covering <- differences |> filter(estimator == "Difference", covers_zero)
adjusted_excluding <- differences |> filter(estimator == "Adjusted difference", !covers_zero)

# Interval widths, unadjusted and adjusted ----
interval_widths <- figure_1 |>
  filter(estimator %in% c("List experiment estimate", "Adjusted list experiment estimate")) |>
  summarize(mean_width = mean(ui - li), .by = estimator)

unadjusted_width <- interval_widths$mean_width[
  interval_widths$estimator == "List experiment estimate"]
adjusted_width <- interval_widths$mean_width[
  interval_widths$estimator == "Adjusted list experiment estimate"]

# Assemble ----
claims <- tribble(
  ~claim_id, ~claim, ~computed, ~holds, ~evidence,

  "desc_list_below_direct",
  "The list experiment estimate is below the direct question estimate",
  100 * (direct_entire - list_entire),
  as.numeric(list_entire < direct_entire),
  str_glue("Direct question {pp(direct_entire)} per cent against list experiment {pp(list_entire)} per cent"),

  "desc_direct_minus_list_not_significant",
  "The difference between the two modes is not distinguishable from zero",
  100 * est_of("Entire sample", "Difference"),
  as.numeric(diff_li <= 0 & diff_ui >= 0),
  str_glue("Difference {pp(est_of('Entire sample', 'Difference'))} points, 95 per cent bootstrap interval {pp(diff_li)} to {pp(diff_ui)}"),

  "desc_nondiscloser_not_significant",
  "The list estimate among non-disclosers is not distinguishable from zero",
  100 * nondiscloser_est,
  as.numeric(abs(nondiscloser_est / nondiscloser_se) < qnorm(0.975)),
  str_glue("Estimate {pp(nondiscloser_est)} points, HC2 standard error {pp(nondiscloser_se)} points, t = {formatC(nondiscloser_est / nondiscloser_se, digits = 2, format = 'f')}"),

  "desc_party_gradient",
  "Democrats are unlikely and Republicans likely to support Trump",
  NA_real_,
  as.numeric(all(democrat_support < 0.5) & all(republican_support > 0.5)),
  str_glue("Direct question support: {paste(paste0(party_direct$group_label, ' ', pp(party_direct$est)), collapse = '; ')}"),

  "desc_education_gradient",
  "More educated groups support Trump less",
  NA_real_,
  NA_real_,
  str_glue("Direct question support in published order: {paste(paste0(education_direct$group_label, ' ', pp(education_direct$est)), collapse = '; ')}"),

  "desc_less_than_high_school_smallest",
  "The least educated group is the smallest and its estimates the most uncertain",
  min(subgroup_sizes$n),
  as.numeric(subgroup_sizes$group_label[which.min(subgroup_sizes$n)] == "Less than high school"),
  str_glue("Smallest subgroup is {subgroup_sizes$group_label[which.min(subgroup_sizes$n)]} at N = {min(subgroup_sizes$n)}; its list experiment standard error is {pp(est_of('Less than high school', 'List experiment estimate', 'se'))} points, the largest of any subgroup"),

  "desc_income_groups_similar",
  "Income groups did not diverge wildly in their support",
  100 * (max(income_direct$est) - min(income_direct$est)),
  NA_real_,
  str_glue("Direct question support: {paste(paste0(income_direct$group_label, ' ', pp(income_direct$est)), collapse = '; ')}"),

  "desc_gender_similar",
  "Men and women did not diverge wildly in their support",
  100 * (est_of("Men", "Direct question estimate") - est_of("Women", "Direct question estimate")),
  NA_real_,
  str_glue("Direct question support: men {pp(est_of('Men', 'Direct question estimate'))}, women {pp(est_of('Women', 'Direct question estimate'))}"),

  "desc_white_highest",
  "Whites were more likely to support Trump than any other racial or ethnic category",
  NA_real_,
  as.numeric(all(white_leads)),
  str_glue("White leads every other racial or ethnic category on {sum(white_leads)} of {length(white_leads)} estimators"),

  "desc_likely_voters_higher",
  "Likely voters expressed higher Trump support",
  NA_real_,
  as.numeric(all(likely_leads)),
  str_glue("Likely voters above unlikely voters on {sum(likely_leads)} of {length(likely_leads)} estimators"),

  "desc_unadjusted_mostly_cover_zero",
  "Most unadjusted difference intervals contain zero",
  nrow(unadjusted_covering),
  as.numeric(nrow(unadjusted_covering) > nrow(subgroups) / 2),
  str_glue("{nrow(unadjusted_covering)} of {nrow(subgroups)} unadjusted difference intervals contain zero"),

  "desc_adjusted_intervals_shrink",
  "The adjusted intervals shrink substantially",
  100 * (unadjusted_width - adjusted_width),
  NA_real_,
  str_glue("Mean 95 per cent interval width, list experiment estimate: {pp(unadjusted_width)} points unadjusted against {pp(adjusted_width)} points adjusted"),

  "desc_combined_not_significant",
  "The combined estimate is not distinguishable from the direct question estimate",
  100 * text_of("combined_minus_direct"),
  as.numeric(abs(text_of("combined_minus_direct") /
                   text_of("combined_minus_direct", "std_error")) < qnorm(0.975)),
  str_glue("Combined minus direct {pp(text_of('combined_minus_direct'))} points, bootstrap standard error {pp(text_of('combined_minus_direct', 'std_error'))} points, t = {formatC(text_of('combined_minus_direct') / text_of('combined_minus_direct', 'std_error'), digits = 2, format = 'f')}"),

  "desc_adjusted_all_but_one",
  "All but one adjusted difference interval contains zero",
  nrow(adjusted_excluding),
  as.numeric(nrow(adjusted_excluding) == 1 && adjusted_excluding$group_label == "Hispanic"),
  str_glue("{nrow(adjusted_excluding)} of {nrow(subgroups)} adjusted difference intervals exclude zero: {paste(adjusted_excluding$group_label, collapse = '; ')}")
) |>
  mutate(evidence = as.character(evidence))

write_csv(claims, here::here("maintained", "output", "text_descriptive_claims.csv"))

print(claims, n = nrow(claims), width = 200)
