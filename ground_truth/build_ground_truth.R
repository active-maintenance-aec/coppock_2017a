# coppock_2017a/ground_truth/build_ground_truth.R
# Output: ground_truth/coppock_2017a_ground_truth.csv,
#         ground_truth/sampler_comparison.csv,
#         ground_truth/rewrite_vs_archive.csv
# Depends on: ground_truth/published_claims.csv,
#             ground_truth/original_archive_estimates.csv,
#             ground_truth/original_archive_scalars.csv,
#             maintained/output/ (run run_all.R first)
# Description: Assemble the ground truth table. value_paper is the string the
#   article prints, read from ground_truth/published_claims.csv and used only as a
#   comparison target; no published number is an input to any computation here or
#   anywhere in maintained/. value_script is read back from the deposited script's
#   own run and value_rewrite from maintained/output/, so neither column can drift
#   from the code that produced it. Nothing here refits a model: every estimate is
#   read from the script that owns it.
#
#   value_paper is a string rather than a number because the precision each
#   comparison is made at is derived from it. A double does not record how many
#   decimals a page printed: 0.80 and 0.8 are the same double, and reading the
#   precision off the double compares a published 0.80 ten times too loosely. That
#   failure is silent and it is permissive, which is the worst combination.

library(here)
library(tidyverse)

here::i_am("ground_truth/build_ground_truth.R")

# The extraction ----
# Every numeric token in the article and its appendix, classified by hand, and the
# only place a published number is written down. value_paper is read as text
# because the number of decimals the page shows is what sets the precision each
# comparison is made at, and a double does not record it.
published_claims <- read_csv(
  here::here("ground_truth", "published_claims.csv"),
  col_types = cols(.default = col_character())
)

rewrite_ests <- read_csv(
  here::here("maintained", "output", "figure_1_direct_vs_list_estimates.csv"),
  show_col_types = FALSE
)
rewrite_descriptive <- read_csv(
  here::here("maintained", "output", "text_descriptive_claims.csv"),
  show_col_types = FALSE
)
rewrite_table_a1 <- read_csv(
  here::here("maintained", "output", "table_a1_subgroup_estimates.csv"),
  show_col_types = FALSE
)
rewrite_text <- read_csv(
  here::here("maintained", "output", "text_main_estimates.csv"),
  show_col_types = FALSE
)
rewrite_table_2 <- read_csv(
  here::here("maintained", "output", "table_2_list_response_distribution.csv"),
  show_col_types = FALSE
)
archive_ests_all <- read_csv(
  here::here("ground_truth", "original_archive_estimates.csv"),
  show_col_types = FALSE
)
archive_scalars_all <- read_csv(
  here::here("ground_truth", "original_archive_scalars.csv"),
  show_col_types = FALSE
)

stopifnot(all(c("current", "rounding", "shipped") %in% archive_ests_all$run_id))

# value_script is the deposited script run today at the article's 2,000
# replicates under today's sampler. The other two runs answer a different
# question and are used only in sampler_comparison.csv at the bottom of this file.
archive_ests <- filter(archive_ests_all, run_id == "current")
archive_scalars <- filter(archive_scalars_all, run_id == "current")

# The deposited script, the rewrite and the article each punctuate and capitalise
# the subgroup and estimator names differently. Matching on a stripped key keeps
# the join from turning a typographic difference into a missing row.
norm_key <- function(x) str_remove_all(str_to_lower(x), "[^a-z0-9]")

# claim_ids for float cells are built from the label the pipeline itself carries,
# so the key on the published side and the key on the pipeline side are generated
# by the same function from the same string and cannot drift apart by a hyphen.
slug <- function(x) str_replace_all(str_remove_all(str_to_lower(x), "[^a-z0-9 ]"), " +", "_")

# Every join goes through here ----
# A join between a published transcription and a pipeline output is where a
# ground truth silently loses rows: a label that matches nothing produces a
# missing value, which then reads as a quantity the pipeline does not produce.
# The helper asserts the key is unique on whichever sides the stated relationship
# requires and that the row count is the one expected, so a duplicated or
# unmatched label stops the build instead of changing the comparison.
join_checked <- function(x, y, by, relationship = "one-to-one",
                         expected_rows = nrow(x)) {
  stopifnot(relationship %in% c("one-to-one", "many-to-one", "one-to-many"))
  if (relationship %in% c("one-to-one", "one-to-many")) {
    stopifnot(!any(duplicated(x[by])))
  }
  if (relationship %in% c("one-to-one", "many-to-one")) {
    stopifnot(!any(duplicated(y[by])))
  }
  out <- left_join(x, y, by = by, relationship = relationship)
  stopifnot(nrow(out) == expected_rows)
  out
}

lookup <- function(df, quantity_value, column) {
  hit <- df[[column]][df$quantity == quantity_value]
  if (length(hit) == 0) NA_real_ else as.numeric(hit[1])
}

rw <- function(quantity_value, column = "estimate") lookup(rewrite_text, quantity_value, column)
ar <- function(quantity_value, column = "estimate") lookup(archive_scalars, quantity_value, column)

# Several in-text quantities are computed by the deposited script only as part of
# the subgroup table, so they are read from its entire-sample row.
ar_entire_sample <- function(estimator_label, column = "est") {
  rows <- archive_ests[[column]][
    norm_key(archive_ests$group_label) == norm_key("Entire sample") &
      norm_key(archive_ests$estimator) == norm_key(estimator_label)
  ]
  if (length(rows) == 0) NA_real_ else as.numeric(rows[1])
}

# Agreement at the precision the article prints ----
# A value agrees when printing it to the page's own precision gives the page's own
# digits. The comparison is between two strings, not between a number and a
# tolerance: a tolerance of half the last printed digit fails on exact rounding
# boundaries, where a value one part in a million under the boundary is called a
# match and the printed digits differ. The number of decimals is read off
# value_paper, which is why value_paper is stored as the string the page prints:
# a double does not record how many decimals were shown, since 3.0 and 3 are the
# same double.
printed_decimals <- function(value_paper) {
  decimals <- str_extract(value_paper, "(?<=\\.)[0-9]+$")
  if_else(is.na(decimals), 0L, nchar(decimals))
}

printed_at <- function(value, value_paper) {
  if_else(
    is.na(value) | is.na(value_paper),
    NA_character_,
    sprintf(paste0("%.", printed_decimals(value_paper), "f"), value)
  )
}

agrees <- function(value, value_paper) {
  printed <- printed_at(value, value_paper)
  # The target is run through the same formatter, so "-1.8" and "−1.8" and a
  # value_paper carrying more decimals than it prints cannot open a gap.
  target <- printed_at(suppressWarnings(as.numeric(value_paper)), value_paper)
  case_when(
    is.na(printed) | is.na(target) ~ NA_real_,
    printed == target ~ 1,
    .default = 0
  )
}

# Published Table A1 ----
# The article's appendix table, pages 10 and 11, in percentage points, read out of
# published_claims.csv. The claim_id of every cell is built here from the label
# the pipeline carries and the estimator column, and the set of ids built this way
# is asserted to be exactly the set the extraction holds, so a cell the article
# prints and the pipeline does not produce stops the build rather than going
# missing. The article prints the income labels in the order the deposit's script
# produced them; the Errata section of the README explains why the numbers beside
# them belong to the next quintile down.
estimator_names <- tribble(
  ~estimator_col, ~estimator,
  "direct_est", "Direct question estimate",
  "list_est", "List experiment estimate",
  "difference", "Difference",
  "direct_est_adj", "Adjusted direct question estimate",
  "list_est_adj", "Adjusted list experiment estimate",
  "difference_adj", "Adjusted difference"
)

# The subgroup labels, taken from the pipeline's own estimates file rather than
# retyped, which is what lets the claim_id built here and the claim_id in the
# extraction be generated from the same string. The file is written in the order
# the published table prints, so the ground truth comes out in that order too.
a1_group_labels <- unique(rewrite_ests$group_label)

paper_long <- expand_grid(
  group_label = a1_group_labels,
  estimator_names,
  kind = c("estimate", "standard error")
) |>
  mutate(
    col = if_else(kind == "standard error", paste0(estimator_col, "_se"), estimator_col),
    claim_id = paste0("table_a1_", slug(group_label), "_", col),
    join_key = paste0(norm_key(group_label), "|", norm_key(estimator), "|", kind)
  ) |>
  join_checked(filter(published_claims, location == "Table A1") |>
                 select(claim_id, value_paper), by = "claim_id")

paper_a1_n <- tibble(group_label = a1_group_labels) |>
  mutate(claim_id = paste0("table_a1_", slug(group_label), "_n")) |>
  join_checked(filter(published_claims, location == "Table A1") |>
                 select(claim_id, value_paper), by = "claim_id")

# Both directions: every cell the extraction holds is built here, and every cell
# built here is in the extraction. Either way round, a mismatch is a broken key.
stopifnot(
  setequal(c(paper_long$claim_id, paper_a1_n$claim_id),
           published_claims$claim_id[published_claims$location == "Table A1"]),
  !anyNA(paper_long$value_paper),
  !anyNA(paper_a1_n$value_paper)
)

archive_long <- archive_ests |>
  pivot_longer(c(est, se), names_to = "col", values_to = "value_script") |>
  mutate(
    kind = if_else(col == "se", "standard error", "estimate"),
    value_script = 100 * value_script,
    join_key = paste0(norm_key(group_label), "|", norm_key(estimator), "|", kind)
  ) |>
  select(join_key, value_script)

rewrite_long <- rewrite_ests |>
  pivot_longer(c(est, se), names_to = "col", values_to = "value_rewrite") |>
  mutate(
    kind = if_else(col == "se", "standard error", "estimate"),
    value_rewrite = 100 * value_rewrite,
    join_key = paste0(norm_key(group_label), "|", norm_key(estimator), "|", kind)
  ) |>
  select(join_key, value_rewrite)

# Each of the three sides carries one row per subgroup per estimator per kind, so
# every join below is one to one and the three key sets are the same set. The
# join helper asserts uniqueness and the row count; the set equality here is the
# stronger statement, that no side has a label the others lack.
stopifnot(
  setequal(paper_long$join_key, archive_long$join_key),
  setequal(paper_long$join_key, rewrite_long$join_key)
)

# Published Table A1 is the same numbers as published Figure 1, and the rewrite
# writes them to two files. Both are read here, and the table's own file is
# checked against the figure's, so a row claiming to verify Table A1 cannot in
# fact be reading only Figure 1.
table_a1_parsed <- rewrite_table_a1 |>
  pivot_longer(-c(group_label, n), names_to = "estimator", values_to = "entry") |>
  mutate(
    table_est = as.numeric(str_extract(entry, "^[^ ]+")),
    table_se = as.numeric(str_extract(entry, "(?<=\\()[^)]+")),
    join_est = paste0(norm_key(group_label), "|", norm_key(estimator), "|estimate"),
    join_se = paste0(norm_key(group_label), "|", norm_key(estimator), "|standard error")
  )

table_a1_check <- table_a1_parsed |>
  join_checked(rename(rewrite_long, join_est = join_key, fig_est = value_rewrite),
               by = "join_est", relationship = "many-to-one") |>
  join_checked(rename(rewrite_long, join_se = join_key, fig_se = value_rewrite),
               by = "join_se", relationship = "many-to-one")

stopifnot(
  !anyNA(table_a1_check$fig_est),
  !anyNA(table_a1_check$fig_se),
  all(abs(table_a1_check$table_est - table_a1_check$fig_est) <= 0.05 + 1e-9),
  all(abs(table_a1_check$table_se - table_a1_check$fig_se) <= 0.05 + 1e-9)
)

a1_rows <- paper_long |>
  join_checked(archive_long, by = "join_key") |>
  join_checked(rewrite_long, by = "join_key") |>
  transmute(
    claim_id,
    table_figure = "Figure 1 and Table A1",
    claim = str_glue("{group_label}: {estimator}, {kind} (pp)"),
    value_script, value_paper, value_rewrite,
    is_income = str_detect(group_label, "income percentile"),
    is_se = kind == "standard error",
    expected_source = "pipeline",
    notes = ""
  )

stopifnot(nrow(a1_rows) == nrow(paper_long))

# Sample sizes ----
# The N column of Table A1, which Figure 1's estimates file and Table A1's own
# file both carry. Both are read; they must agree.
archive_n <- archive_ests |>
  distinct(join_key = norm_key(group_label), value_script = n)
rewrite_n <- rewrite_ests |>
  distinct(join_key = norm_key(group_label), value_rewrite = n)
table_a1_n <- rewrite_table_a1 |>
  distinct(join_key = norm_key(group_label), table_n = n)

n_agreement <- rewrite_n |>
  join_checked(table_a1_n, by = "join_key")

stopifnot(all(n_agreement$value_rewrite == n_agreement$table_n))

a1_n_rows <- paper_a1_n |>
  transmute(
    claim_id,
    table_figure = "Figure 1 and Table A1",
    claim = str_glue("{group_label}: N"),
    join_key = norm_key(group_label),
    value_paper,
    is_income = str_detect(group_label, "income percentile"),
    is_se = FALSE,
    expected_source = "pipeline",
    notes = ""
  ) |>
  join_checked(archive_n, by = "join_key") |>
  join_checked(rewrite_n, by = "join_key") |>
  select(claim_id, table_figure, claim, value_script, value_paper, value_rewrite,
         is_income, is_se, expected_source, notes)

# Published Table 2 ----
# The cells the rewrite produces, keyed the same way the extraction keys them, so
# the published value is read rather than retyped.
table_2_long <- rewrite_table_2 |>
  pivot_longer(-items, names_to = "condition", values_to = "value_rewrite") |>
  mutate(claim_id = paste0("table_2_", slug(condition), "_", slug(items)))

paper_table_2 <- filter(published_claims, location == "Table 2") |>
  select(claim_id, value_paper)

stopifnot(setequal(table_2_long$claim_id, paper_table_2$claim_id))

table_2_rows <- table_2_long |>
  join_checked(paper_table_2, by = "claim_id") |>
  mutate(
    archive_quantity = if_else(
      items == "N",
      if_else(condition == "Control list", "n_control", "n_treatment"),
      str_glue("table_2_{str_replace_all(str_to_lower(condition), ' ', '_')}_{str_extract(items, '^[0-9]+')}_items")
    ),
    value_script = map_dbl(archive_quantity, \(q) ar(q))
  ) |>
  transmute(
    claim_id,
    table_figure = "Table 2",
    claim = str_glue("{condition}, {items}"),
    value_script, value_paper, value_rewrite,
    is_income = FALSE,
    is_se = FALSE,
    expected_source = "pipeline",
    notes = if_else(items == "4 items" & condition == "Control list",
                    "The article leaves this cell blank. A three-item control list cannot produce four, so the value is zero by construction and there is nothing to compare",
                    "")
  )

# In-text quantities ----
# Everything the article states in prose rather than in a table or figure, in the
# units the sentence uses.
# Several quantities are stated more than once. The article gives the direct
# question estimate in the abstract, twice in the design section and again in the
# results, and the sample size in the abstract and the design section. Each
# statement is its own row, keyed to its own place in the article, because a
# quantity stated twice can disagree with itself and checking each against the
# pipeline separately is exactly what cannot reveal that.
text_rows <- tribble(
  ~claim_id, ~claim, ~value_script, ~value_rewrite, ~notes,
  "abstract_n_respondents", "Respondents surveyed (abstract)",
    ar_entire_sample("Direct question estimate", "n"), rw("n_respondents"), "",
  "abstract_direct_share", "Direct question, Trump support (%), abstract",
    100 * ar("direct_share_trump"), 100 * rw("direct_share_trump"), "",
  "abstract_list_estimate", "List experiment estimate of Trump support (%), abstract",
    100 * ar_entire_sample("List experiment estimate"), 100 * rw("list_ate"), "",
  "design_n_respondents", "Respondents surveyed (design)",
    ar_entire_sample("Direct question estimate", "n"), rw("n_respondents"), "",
  "design_direct_share_trump", "Direct question, Trump support (%)",
    100 * ar("direct_share_trump"), 100 * rw("direct_share_trump"), "",
  "design_direct_share_clinton", "Direct question, Clinton support (%)",
    100 * ar("direct_share_clinton"), 100 * rw("direct_share_clinton"), "",
  "design_direct_share_other", "Direct question, other or undecided (%)",
    100 * ar("direct_share_other"), 100 * rw("direct_share_other"),
    "The article's 30.5 is 100 minus the two rounded shares. The three remaining response categories carry 30.4 per cent of the weight",
  "design_direct_share_restated", "Direct question, Trump support (%), restated in the design section",
    100 * ar("direct_share_trump"), 100 * rw("direct_share_trump"), "",
  "results_list_mean_control", "List experiment, control group mean (items)",
    ar("list_mean_control"), rw("list_mean_control"), "",
  "results_list_mean_treatment", "List experiment, treatment group mean (items)",
    ar("list_mean_treatment"), rw("list_mean_treatment"), "",
  "results_list_ate_proportion", "List experiment estimate of Trump support (proportion)",
    ar_entire_sample("List experiment estimate"), rw("list_ate"), "",
  "results_list_ate_percent", "List experiment estimate of Trump support (%)",
    100 * ar_entire_sample("List experiment estimate"), 100 * rw("list_ate"), "",
  "results_direct_share_restated", "Direct question, Trump support (%), restated in the results section",
    100 * ar("direct_share_trump"), 100 * rw("direct_share_trump"), "",
  "results_direct_minus_list", "Direct minus list experiment (pp)",
    100 * ar_entire_sample("Difference"), 100 * rw("direct_minus_list"),
    "The article's sentence gives 2.9, the difference of the two rounded shares. Table A1 gives 3.0 for the same quantity, which is the rounded difference, and 3.0 is what both the deposited script and the rewrite produce",
  "results_direct_minus_list_se", "Bootstrap SE of direct minus list (pp)",
    100 * ar_entire_sample("Difference", "se"), 100 * rw("direct_minus_list", "std_error"), "",
  "results_share_not_reporting_trump", "Share not reporting Trump support (%)",
    100 * (1 - ar("direct_share_trump")), 100 * rw("share_not_reporting_trump"), "",
  "results_nondiscloser_mean_control", "Non-disclosers, control group mean (items)",
    ar("list_mean_control_nondisclosers"), rw("list_mean_control_nondisclosers"), "",
  "results_nondiscloser_mean_treatment", "Non-disclosers, treatment group mean (items)",
    ar("list_mean_treatment_nondisclosers"), rw("list_mean_treatment_nondisclosers"), "",
  "results_nondiscloser_list_ate", "List experiment estimate among non-disclosers (%)",
    100 * ar("list_ate_nondisclosers"), 100 * rw("list_ate_nondisclosers"), "",
  "results_n_subgroups", "Subgroups compared",
    n_distinct(archive_ests$group_label), rw("n_subgroups_compared"),
    "The article calls these 25 opportunities to find a difference",
  "results_party_id_points", "Points on the party identification scale entering the response model",
    NA_real_, rw("party_id_points"),
    "Equation 1 calls the party identification term a 7-point measure, and the deposited pid_7 takes exactly seven values. The deposited script does not print this quantity",
  "results_income_points", "Points on the income scale entering the response model",
    NA_real_, rw("income_points"),
    "Equation 1 calls USHHI2 a 22-point income measure. The deposited variable takes 24 distinct values, 1 to 24, with every value present. The deposited script does not print this quantity, so there is nothing to read from the archive run",
  "combined_estimate", "Combined estimate of Trump support (%)",
    100 * ar("combined_est"), 100 * rw("combined_est"), "",
  "combined_estimate_se", "SE of the combined estimate (pp)",
    100 * ar("combined_est", "std_error"), 100 * rw("combined_est", "std_error"), "",
  "combined_minus_direct", "Combined minus direct (pp)",
    100 * ar("combined_minus_direct"), 100 * rw("combined_minus_direct"), "",
  "combined_minus_direct_se", "SE of combined minus direct (pp)",
    100 * ar("combined_minus_direct", "std_error"), 100 * rw("combined_minus_direct", "std_error"), "",
  "placebo_estimate", "Joint test: list estimate among admitted supporters (%)",
    100 * ar("placebo_ate"), 100 * rw("placebo_ate"), "",
  "placebo_estimate_se", "Joint test: standard error (pp)",
    100 * ar("placebo_ate", "std_error"), 100 * rw("placebo_ate", "std_error"), "",
  "placebo_p_value", "Joint test: two-sided p-value",
    ar("placebo_p_value"), rw("placebo_p_value"), ""
) |>
  join_checked(select(published_claims, claim_id, value_paper), by = "claim_id") |>
  mutate(table_figure = "In-text", is_income = FALSE,
         is_se = str_detect(claim, "\\bSE\\b|standard error"),
         expected_source = "pipeline", .before = 1)

stopifnot(!anyNA(text_rows$value_paper))

# Claims about shape, sign and count ----
# Sentences with no number in them, which nothing in a number-by-number comparison
# reaches. value_paper is empty because the article prints no value; the verdict
# comes from the pipeline, and the note carries the evidence it rests on. Claims
# whose wording sets no threshold ("wildly", "substantially") get evidence and no
# verdict, because inventing a threshold would put a number in the article's mouth.
descriptive_rows <- rewrite_descriptive |>
  transmute(
    claim_id,
    table_figure = "Descriptive",
    claim,
    value_script = NA_real_,
    value_paper = NA_character_,
    value_rewrite = computed,
    holds,
    is_income = FALSE,
    is_se = FALSE,
    expected_source = "pipeline",
    notes = evidence
  )

stopifnot(
  setequal(descriptive_rows$claim_id,
           published_claims$claim_id[published_claims$claim_type == "descriptive"]),
  all(nzchar(descriptive_rows$notes))
)

# Numbers the article takes from outside the data ----
# fivethirtyeight's final forecast and the certified returns. Nothing in the
# deposit bears on them, so they are declared unverifiable rather than omitted,
# and the declaration is what keeps them apart from a row whose rewrite value
# went missing by accident.
external_rows <- tribble(
  ~claim_id, ~claim,
  "intro_wisconsin_forecast_clinton", "Wisconsin, forecast Clinton share (%)",
  "intro_wisconsin_forecast_trump", "Wisconsin, forecast Trump share (%)",
  "intro_wisconsin_actual_clinton", "Wisconsin, actual Clinton share (%)",
  "intro_wisconsin_actual_trump", "Wisconsin, actual Trump share (%)",
  "intro_wisconsin_error", "Wisconsin, prediction error (pp)",
  "intro_michigan_error", "Michigan, prediction error (pp)",
  "intro_pennsylvania_error", "Pennsylvania, prediction error (pp)",
  "intro_popular_vote_actual_clinton", "National popular vote, actual Clinton share (%)",
  "intro_popular_vote_actual_trump", "National popular vote, actual Trump share (%)",
  "intro_popular_vote_forecast_clinton", "National popular vote, forecast Clinton share (%)",
  "intro_popular_vote_forecast_trump", "National popular vote, forecast Trump share (%)",
  "intro_dropp_mode_gap", "Survey mode gap reported by Dropp (2015) (pp)"
) |>
  join_checked(select(published_claims, claim_id, value_paper), by = "claim_id") |>
  transmute(claim_id, table_figure = "External to the data", claim, value_script = NA_real_,
            value_paper, value_rewrite = NA_real_, is_income = FALSE, is_se = FALSE,
            expected_source = "external",
            notes = "Transcribed from fivethirtyeight's final pre-election forecast, the certified returns, or Dropp (2015); outside the deposited data")

stopifnot(
  !anyNA(external_rows$value_paper),
  setequal(external_rows$claim_id,
           published_claims$claim_id[published_claims$claim_type == "transcribed"])
)

gt <- bind_rows(a1_rows, a1_n_rows, table_2_rows, text_rows, descriptive_rows,
                external_rows) |>
  mutate(claim = as.character(claim), value_paper = as.character(value_paper))

# A published value with no rewrite counterpart is a broken join, not a finding ----
# Without this gate a mistyped label yields value_rewrite = NA, then
# match_rewrite = NA, and the row lands in the unverifiable bucket looking exactly
# like a quantity the pipeline genuinely does not produce.
missing_rewrite <- gt |>
  filter(expected_source == "pipeline", !is.na(value_paper), is.na(value_rewrite))

if (nrow(missing_rewrite) > 0) {
  print(missing_rewrite |> select(table_figure, claim, value_paper), n = 50)
  stop(str_glue("{nrow(missing_rewrite)} published values have no counterpart in ",
                "maintained/output/. Every one is a join that found nothing."))
}

gt <- gt |>
  mutate(
    paper_id = "coppock_2017a",
    match = agrees(value_script, value_paper),
    # A descriptive claim prints no number, so there is nothing to compare digits
    # against. Its verdict is whether the article's description holds in the data,
    # computed in maintained/text_descriptive_claims.R, and it is NA wherever the
    # wording sets no threshold.
    match_rewrite = if_else(table_figure == "Descriptive", holds,
                            agrees(value_rewrite, value_paper))
  )

# Where the disagreements live ----
# income: the deposited script's factor labels are rotated by one, so the article
#   prints each income block's numbers under the quintile below it. The rewrite
#   prints the label the data supports and therefore disagrees with the page.
# standard error: the deposit's header records that its resampling code was
#   rewritten in October 2019, two years after publication. Where the deposited
#   script cannot reproduce a published standard error either, the published value
#   came from code the archive no longer contains. Where the deposit reproduces it
#   and the rewrite does not, the difference is a property of the environment.
# in-text: the two rounding claims and the income scale are the article
#   disagreeing with itself or with its own data, and each is named rather than
#   swept up by a default.
paper_internal_claims <- c(
  "Direct question, other or undecided (%)",
  "Direct minus list experiment (pp)",
  "Points on the income scale entering the response model"
)

gt <- gt |>
  mutate(
    defect_locus = case_when(
      is.na(match_rewrite) | match_rewrite == 1 ~ NA_character_,
      is_income ~ "archive",
      is_se & match == 0 ~ "archive",
      is_se & match == 1 ~ "environment",
      table_figure == "Descriptive" ~ "paper_internal",
      claim %in% paper_internal_claims ~ "paper_internal",
      match == 0 ~ "archive",
      .default = "unresolved"
    ),
    notes = case_when(
      is_income & match_rewrite == 0 & notes == "" ~
        "Errata: the rewrite prints the income label the data supports, so it disagrees with the published label by construction. Intentional correction, not a defect in the rewrite",
      is_se & match_rewrite == 0 & notes == "" ~
        "Bootstrap standard error. The deposited resampling code postdates publication by two years and no configuration of it recovers the published value exactly",
      .default = notes
    )
  ) |>
  select(paper_id, claim_id, table_figure, claim, value_script, value_paper, match,
         value_rewrite, match_rewrite, defect_locus, notes)

# Coverage against the extraction ----
# published_claims.csv is the exhaustive list of numeric claims in the article and
# its appendix. Every claim classified pipeline or descriptive must be checked in
# both instruments: a row here, and a block in maintained/in_text_claims.R, which
# reaches the same number by its own path. A claim in the extraction with neither
# is the coverage failure this gate exists to catch, and it stops the build.
# Definitional, structural and transcribed claims are exempt by classification:
# nothing in the pipeline can move them.
claims_file <- read_lines(here::here("maintained", "in_text_claims.R"))

covered_ids <- str_trim(str_remove(str_subset(claims_file, "^#\\s*claim_id:"),
                                   "^#\\s*claim_id:"))

covers <- function(claim) {
  prefixes <- str_remove(str_subset(covered_ids, "\\*$"), "\\*$")
  claim %in% covered_ids | any(str_starts(claim, fixed(prefixes)))
}

coverage <- published_claims |>
  filter(claim_type %in% c("pipeline", "descriptive")) |>
  mutate(
    in_ground_truth = claim_id %in% gt$claim_id,
    in_claims_script = map_lgl(claim_id, covers)
  )

uncovered <- filter(coverage, !in_ground_truth | !in_claims_script)

if (nrow(uncovered) > 0) {
  print(uncovered, n = 50)
  stop(str_glue("{nrow(uncovered)} published claims are missing from the ground ",
                "truth, from maintained/in_text_claims.R, or from both."))
}

# And nothing in the ground truth may claim an id the extraction does not hold.
stopifnot(all(gt$claim_id %in% published_claims$claim_id),
          !any(duplicated(gt$claim_id)))

# defect_locus and match_rewrite == 0 go together, both ways ----
# A zero without a locus reads as a failure of the rewrite, which it almost never
# is. A locus without a zero is a verdict nothing supports. Either is a defect in
# this file rather than a finding about the paper, so either stops the build.
locus_gate <- gt |>
  filter(xor(!is.na(defect_locus), !is.na(match_rewrite) & match_rewrite == 0))

if (nrow(locus_gate) > 0) {
  print(locus_gate |> select(claim, value_paper, value_rewrite, match_rewrite,
                             defect_locus), n = 50)
  stop(str_glue("{nrow(locus_gate)} rows carry a defect_locus without a ",
                "match_rewrite of 0, or the reverse."))
}

# A note may not contradict the verdict beside it ----
# Generating value_rewrite closes one drift channel and leaves this one open: a
# generated note can still name a number the generated verdict says matches. Any
# note on a matching row that quotes a value must quote a matching one.
contradictions <- gt |>
  filter(match_rewrite == 1, notes != "", !is.na(value_paper)) |>
  mutate(
    quoted = map(notes, \(txt) as.numeric(str_extract_all(txt, "-?[0-9]+\\.?[0-9]*")[[1]])),
    contradicts = map2_lgl(quoted, value_paper,
                           \(q, p) length(q) > 0 && !any(agrees(q, p) == 1))
  ) |>
  filter(contradicts)

if (nrow(contradictions) > 0) {
  print(contradictions |> select(claim, value_paper, value_rewrite, notes), n = 50)
  stop("A row carries match_rewrite = 1 while its note names a value that does not match.")
}

write_csv(gt, here::here("ground_truth", "coppock_2017a_ground_truth.csv"))

# Published float coverage ----
# The floats the article numbers, enumerated from the article itself rather than
# from what the pipeline happens to produce. There are four: Table 1 (the wording
# of the two list treatments, which carries no numbers and so has nothing to
# compare), Table 2, Figure 1, and Appendix Table A1. Figure 1 and Table A1 print
# the same estimates and share their rows. The check runs both ways: every float
# carrying numbers must have rows, and no block of the ground truth may name a
# float this list does not.
published_floats <- tribble(
  ~float, ~carries_numbers, ~block,
  "Table 1", FALSE, NA_character_,
  "Table 2", TRUE, "Table 2",
  "Figure 1", TRUE, "Figure 1 and Table A1",
  "Table A1", TRUE, "Figure 1 and Table A1"
)

float_coverage <- published_floats |>
  filter(carries_numbers) |>
  mutate(rows = map_int(block, \(b) sum(gt$table_figure == b)))

float_blocks <- setdiff(unique(gt$table_figure),
                        c("In-text", "Descriptive", "External to the data"))

if (!all(float_coverage$rows > 0) || !all(float_blocks %in% published_floats$block)) {
  print(float_coverage)
  stop("Float coverage: a published float has no ground-truth rows, or the ground truth names a float the article does not.")
}

# How close does each run come to the published Table A1? ----
# Four runs are compared against the same published values: the deposited script
# at 2,000 replicates under the current sampler, the same at 2,000 under the
# sampler R used before 3.6.0, the same at the 200 replicates the deposit ships,
# and the maintained rewrite. The five income subgroups are dropped from the
# comparison because the rewrite prints them under different labels, so including
# them would make the rewrite look worse for a reason that has nothing to do with
# the arithmetic.
run_labels <- c(
  current = "Deposited script, 2,000 replicates",
  rounding = "Deposited script, 2,000 replicates, pre-3.6.0 sampler",
  shipped = "Deposited script, 200 replicates as shipped"
)

# The deposit is also run once at 200 replicates against every file it ships
# rather than against code and data alone. That run answers a question about the
# deposit's inputs, not about its arithmetic, and run_original_archive.R asserts
# it returns the same numbers as its stripped twin, so it is not a fourth column
# here.
comparison_runs <- bind_rows(
  archive_ests_all |>
    filter(run_id %in% names(run_labels)) |>
    mutate(run = unname(run_labels[run_id])),
  rewrite_ests |> mutate(run = "Maintained rewrite")
) |>
  pivot_longer(c(est, se), names_to = "col", values_to = "value") |>
  mutate(
    kind = if_else(col == "se", "standard error", "estimate"),
    value = 100 * value,
    join_key = paste0(norm_key(group_label), "|", norm_key(estimator), "|", kind)
  ) |>
  select(run, join_key, value)

n_runs <- n_distinct(comparison_runs$run)

stopifnot(!any(duplicated(paste0(comparison_runs$run, comparison_runs$join_key))))

paper_non_income <- paper_long |>
  filter(!str_detect(group_label, "income percentile")) |>
  select(join_key, kind, value_paper)

comparison_long <- paper_non_income |>
  join_checked(comparison_runs, by = "join_key", relationship = "one-to-many",
               expected_rows = nrow(paper_non_income) * n_runs)

sampler_comparison <- comparison_long |>
  summarize(
    cells = n(),
    matching_published = sum(agrees(value, value_paper) == 1),
    mean_abs_difference_pp = mean(abs(value - as.numeric(value_paper))),
    max_abs_difference_pp = max(abs(value - as.numeric(value_paper))),
    .by = c(run, kind)
  ) |>
  arrange(kind, run)

write_csv(sampler_comparison, here::here("ground_truth", "sampler_comparison.csv"))

# Does the rewrite reproduce the deposited script itself? ----
# A separate question from whether either reproduces the article. Every subgroup
# and estimator is compared, income rows included, since the labels are the only
# thing that differs there and the join is on the label the data supports for the
# rewrite and the label the deposit prints for the archive. Those five subgroups
# are therefore left out, as above.
paired <- paper_non_income |>
  join_checked(filter(comparison_runs, run == "Maintained rewrite") |>
                 select(join_key, rewrite = value), by = "join_key") |>
  join_checked(filter(comparison_runs, run == run_labels[["current"]]) |>
                 select(join_key, archive = value), by = "join_key")

stopifnot(!anyNA(paired$rewrite), !anyNA(paired$archive))

rewrite_vs_archive <- paired |>
  summarize(
    cells = n(),
    max_abs_difference_pp = max(abs(rewrite - archive)),
    identical_cells = sum(rewrite == archive),
    .by = kind
  )

stopifnot(nrow(rewrite_vs_archive) == 2)

write_csv(rewrite_vs_archive, here::here("ground_truth", "rewrite_vs_archive.csv"))

print(sampler_comparison, width = 200)

print(rewrite_vs_archive, width = 200)

print(gt |> filter(table_figure %in% c("Table 2", "In-text", "Descriptive")) |>
        select(claim, value_script, value_paper, match, value_rewrite, match_rewrite),
      n = 100, width = 200)

print(count(published_claims, claim_type), width = 200)

print(gt |>
        summarize(claims = n(),
                  script_checked = sum(!is.na(match)),
                  script_matches = sum(match == 1, na.rm = TRUE),
                  rewrite_checked = sum(!is.na(match_rewrite)),
                  rewrite_matches = sum(match_rewrite == 1, na.rm = TRUE),
                  .by = table_figure),
      width = 200)

print(gt |> count(defect_locus), width = 200)
