# coppock_2017a/maintained/in_text_claims.R
# Output: printed CLAIM lines and a CLAIM SUMMARY line; no file
# Depends on: output/figure_1_direct_vs_list_estimates.csv,
#             output/table_2_list_response_distribution.csv,
#             output/table_a1_subgroup_estimates.csv,
#             output/text_main_estimates.csv,
#             output/text_descriptive_claims.csv,
#             ground_truth/published_claims.csv, errata_entries.csv, helpers.R,
#             excheckr
# Description: Every number the article states in its prose, paired with the
#   sentence that states it and with the value this pipeline produces, in the
#   article's own units and rounding, in the order a reader meets them.
#
#   This file recomputes. It reads the same output/ files the ground truth reads
#   and does its own filtering, unit conversion and rounding, so the two arrive at
#   each number by separate paths and a disagreement between them is a finding
#   rather than a coincidence. It never reads the ground-truth CSV, and it never
#   refits a model: the pipeline has already produced the numbers.
#
#   Each block carries the article's sentence verbatim, then one claim() call per
#   claim, which prints a line of the form
#
#       CLAIM <claim_id> = <value> || [verdict] <label>
#
#   The expectation is derived, never typed here: published_claims.csv says what
#   the article prints, and errata_entries.csv says which of those a published
#   quantity erratum corrects and to what. The verdicts that pass are [match],
#   [corrected], [range] and [shape]; a [shape] claim is one the article states
#   without a number, and its value is the count, the magnitude, or the 0/1 truth
#   value the sentence reduces to. Float cells carry no sentence, because they are
#   read off a table rather than out of a sentence; build_ground_truth.R compares
#   them cell by cell, and their blocks here print the whole reproduced table as
#   evidence.
#
#   ground_truth/build_ground_truth.R checks that every extraction row with
#   needs_block = TRUE has a claim() call here, and assert_claims() fails the run
#   on any MISMATCH, STALE, DRIFT or MISSING.

source(here::here("maintained", "helpers.R"))
library(excheckr)

options(width = 200)

figure_1 <- read_csv(
  here::here("maintained", "output", "figure_1_direct_vs_list_estimates.csv"),
  show_col_types = FALSE
)
table_2 <- read_csv(
  here::here("maintained", "output", "table_2_list_response_distribution.csv"),
  show_col_types = FALSE
)
table_a1 <- read_csv(
  here::here("maintained", "output", "table_a1_subgroup_estimates.csv"),
  show_col_types = FALSE
)
text_estimates <- read_csv(
  here::here("maintained", "output", "text_main_estimates.csv"),
  show_col_types = FALSE
)
descriptive <- read_csv(
  here::here("maintained", "output", "text_descriptive_claims.csv"),
  show_col_types = FALSE
)

# The extraction and the errata spine, every column as character: value_paper and
# corrected_values carry "37.0" and "3.0", and a reader left to guess would return
# 37 and 3 and destroy the precision every comparison depends on.
published <- read_csv(here::here("ground_truth", "published_claims.csv"),
                      col_types = cols(.default = col_character()))
errata <- read_csv(here::here("errata_entries.csv"),
                   col_types = cols(.default = col_character()))

claim_start(published = published, errata = errata, format = "id")

# Accessors ----
# Every value below comes through one of these, so a claim cannot quietly read a
# row that is not there: each stops if the filter does not select exactly one.
text_value <- function(quantity_value, column = "estimate") {
  value <- text_estimates[[column]][text_estimates$quantity == quantity_value]
  stopifnot(length(value) == 1, !is.na(value))
  value
}

figure_value <- function(group, estimator_label, column = "est") {
  value <- figure_1[[column]][figure_1$group_label == group &
                                figure_1$estimator == estimator_label]
  stopifnot(length(value) == 1, !is.na(value))
  value
}

evidence_for <- function(claim) {
  value <- descriptive$evidence[descriptive$claim_id == claim]
  stopifnot(length(value) == 1, !is.na(value))
  value
}

# The verdict on a descriptive claim that reduces to one, as 1 or 0. Claims that
# do not reduce have no verdict and are never passed here.
holds_for <- function(claim) {
  value <- descriptive$holds[descriptive$claim_id == claim]
  stopifnot(length(value) == 1, !is.na(value))
  value
}

# The magnitude, in points, that a descriptive claim with no threshold is about.
# It is printed with its evidence and asserted against nothing.
computed_for <- function(claim) {
  value <- descriptive$computed[descriptive$claim_id == claim]
  stopifnot(length(value) == 1, !is.na(value))
  value
}

# Abstract ----

# "I evaluate this hypothesis by comparing direct question and list experimental
# estimates of Trump support in a nationally representative survey of 5290
# American adults fielded from September 2 to September 13, 2016."
claim("abstract_n_respondents", text_value("n_respondents"),
      "Abstract, respondents surveyed")

# "Of these, 32.5% report supporting Trump's candidacy."
claim("abstract_direct_share", 100 * text_value("direct_share_trump"),
      "Abstract, direct question Trump support (%)")

# "A list experiment conducted on the same respondents yields an estimate 29.6%,
# suggesting that Trump's poll numbers were not artificially deflated by social
# desirability bias as the list experiment estimate is actually lower than direct
# question estimate."
claim("abstract_list_estimate",
      100 * figure_value("Entire sample", "List experiment estimate"),
      "Abstract, list experiment estimate of Trump support (%)")

claim("desc_list_below_direct",
      as.numeric(figure_value("Entire sample", "List experiment estimate") <
                   figure_value("Entire sample", "Direct question estimate")),
      "Abstract, 1 if the list estimate is below the direct estimate", digits = 0)
claim_evidence(evidence_for("desc_list_below_direct"))

# Introduction ----
# The introduction's numbers are the fivethirtyeight forecast, the certified
# returns, and a mode gap reported by Dropp (2015). Nothing in the deposit bears
# on any of them, so they are classified transcribed in published_claims.csv and
# carry no block here.

# Design ----

# "Reuters/IPSOS conducted a nationally-representative online poll of 5290 adult
# Americans from September 2 to September 13."
claim("design_n_respondents", text_value("n_respondents"),
      "Design, respondents surveyed")

# "Respondents split 32.5% for Donald Trump and 37.0% for Hillary Clinton, while
# 30.5% reported that they would vote for other candidates, would not vote, or
# were still undecided."
claim("design_direct_share_trump", 100 * text_value("direct_share_trump"),
      "Design, direct question Trump support (%)")
claim("design_direct_share_clinton", 100 * text_value("direct_share_clinton"),
      "Design, direct question Clinton support (%)")
claim("design_direct_share_other", 100 * text_value("direct_share_other"),
      "Design, other candidate, would not vote or undecided (%)")

# "The list experiment (administered well after the direct question was asked)
# sheds light on the question of whether 32.5% is an underestimate because some
# people are ashamed to admit their support for Donald Trump."
claim("design_direct_share_restated", 100 * text_value("direct_share_trump"),
      "Design, direct question Trump support restated (%)")

# Results ----

# The published table the results section opens by naming, as this pipeline
# reproduces it, at the two decimals the page prints. No sentence, because a table
# cell is not read out of one.
claim_evidence(
  "Table 2, distribution of list experiment responses by treatment condition",
  table_2 |>
    mutate(across(-items, \(x) if_else(items == "N",
                                       formatC(x, format = "d"),
                                       formatC(x, digits = 2, format = "f"))))
)

# "The average number of items subjects reported doing in the control group was
# 1.548, whereas in the treatment group the average was 1.843."
claim("results_list_mean_control", text_value("list_mean_control"),
      "Results, list experiment control group mean (items)")
claim("results_list_mean_treatment", text_value("list_mean_treatment"),
      "Results, list experiment treatment group mean (items)")

# "The difference in the averages forms the list experiment estimate of 0.296, or
# 29.6% support for Trump."
claim("results_list_ate_proportion",
      figure_value("Entire sample", "List experiment estimate"),
      "Results, list experiment estimate (proportion)")
claim("results_list_ate_percent",
      100 * figure_value("Entire sample", "List experiment estimate"),
      "Results, list experiment estimate (%)")

# "Recall that the direct question estimate of Trump support was 32.5%, for a 2.9
# percentage points difference."
claim("results_direct_share_restated", 100 * text_value("direct_share_trump"),
      "Results, direct question Trump support (%)")
claim("results_direct_minus_list", 100 * figure_value("Entire sample", "Difference"),
      "Results, direct question minus list experiment (pp)")

# "The bootstrapped standard error of this difference is 3.4 points, indicating
# that is not statistically significantly different from zero."
claim("results_direct_minus_list_se",
      100 * figure_value("Entire sample", "Difference", "se"),
      "Results, bootstrap standard error of the difference (pp)")

claim("desc_direct_minus_list_not_significant",
      as.numeric(figure_value("Entire sample", "Difference", "li") <= 0 &
                   figure_value("Entire sample", "Difference", "ui") >= 0),
      "Results, 1 if the difference interval contains zero", digits = 0)
claim_evidence(evidence_for("desc_direct_minus_list_not_significant"))

# "Among the 67.5% of the sample who did not state that they would vote for Trump
# when asked directly, the control group average was 1.610 and the treatment group
# average was 1.642."
claim("results_share_not_reporting_trump", 100 * text_value("share_not_reporting_trump"),
      "Results, share not reporting Trump support (%)")
claim("results_nondiscloser_mean_control", text_value("list_mean_control_nondisclosers"),
      "Results, non-disclosers, control group mean (items)")
claim("results_nondiscloser_mean_treatment",
      text_value("list_mean_treatment_nondisclosers"),
      "Results, non-disclosers, treatment group mean (items)")

# "The list experiment therefore suggests that support for Donald Trump among this
# group was a mere 3.3%."
claim("results_nondiscloser_list_ate", 100 * text_value("list_ate_nondisclosers"),
      "Results, list experiment estimate among non-disclosers (%)")

# "This estimate is very small, and is itself not statistically significantly
# different from zero."
claim("desc_nondiscloser_not_significant", holds_for("desc_nondiscloser_not_significant"),
      "Results, 1 if the non-discloser estimate is indistinguishable from zero",
      digits = 0)
claim_evidence(evidence_for("desc_nondiscloser_not_significant"))

# "A brief justification of this specification: all variables except for 7-point
# Party ID and 22-point Income are indicators, so not many modeling choices must
# be made."
claim("results_party_id_points", text_value("party_id_points"),
      "Equation 1, points on the party identification scale")

# Errata entry 4 corrects "22-point" to the length of the deposited scale. It is
# filed as a definition rather than a quantity, so claim_start() does not register
# it as a correction, and the corrected value is read here from the marked span of
# the entry's own corrected sentence instead.
income_points_corrected <- errata |>
  filter(map_lgl(str_split(claim_ids, ";"), \(ids) "results_income_points" %in% ids)) |>
  pull(corrected) |>
  str_match("\\[\\[([0-9]+)-point\\]\\]")

stopifnot(nrow(income_points_corrected) == 1, !is.na(income_points_corrected[, 2]))

claim("results_income_points", text_value("income_points"),
      "Equation 1, points on the income scale",
      corrected = income_points_corrected[, 2])

# "Democrats are unlikely to support Trump while Republicans are likely to do so."
claim("desc_party_gradient", holds_for("desc_party_gradient"),
      "Results, 1 if the three democrat groups fall below and the three republican groups above 50 per cent",
      digits = 0)
claim_evidence(evidence_for("desc_party_gradient"))

# "Overall, more educated groups support Trump less, though the estimates for
# those who have not graduated high school are uncertain as this group is
# relatively small."
claim("desc_education_gradient",
      100 * (figure_value("Graduate school", "Direct question estimate") -
               figure_value("Less than high school", "Direct question estimate")),
      "Results, graduate school minus less than high school direct question support (pp; no verdict: the sentence sets no threshold)",
      digits = 1)
claim_evidence(evidence_for("desc_education_gradient"))

claim("desc_less_than_high_school_smallest",
      holds_for("desc_less_than_high_school_smallest"),
      "Results, 1 if the least educated group is the smallest subgroup", digits = 0)
claim_evidence(evidence_for("desc_less_than_high_school_smallest"))

# "Different income groups did not diverge wildly in their support, nor did men
# and women."
claim("desc_income_groups_similar", computed_for("desc_income_groups_similar"),
      "Results, spread across income groups (pp; no verdict: wildly sets no threshold)",
      digits = 1)
claim_evidence(evidence_for("desc_income_groups_similar"))

claim("desc_gender_similar", computed_for("desc_gender_similar"),
      "Results, men minus women (pp; no verdict: the sentence sets no threshold)",
      digits = 1)
claim_evidence(evidence_for("desc_gender_similar"))

# "By any measure, Whites were more likely to support Trump than any other racial
# or ethnic category."
claim("desc_white_highest", holds_for("desc_white_highest"),
      "Results, 1 if White leads every other racial or ethnic category on every estimator",
      digits = 0)
claim_evidence(evidence_for("desc_white_highest"))

# "Likely voters also expressed higher Trump support."
claim("desc_likely_voters_higher", holds_for("desc_likely_voters_higher"),
      "Results, 1 if likely voters exceed unlikely voters on every estimator", digits = 0)
claim_evidence(evidence_for("desc_likely_voters_higher"))

# "Most of the 95% confidence intervals around the difference in the unadjusted
# estimates contain zero."
claim("desc_unadjusted_mostly_cover_zero",
      sum(figure_1$estimator == "Difference" & figure_1$li <= 0 & figure_1$ui >= 0),
      "Results, unadjusted difference intervals containing zero", digits = 0)
claim_evidence(evidence_for("desc_unadjusted_mostly_cover_zero"))

# "When we sharpen up the list experiment estimates with covariate-adjusted NLS
# regression, the confidence intervals do indeed shrink substantially, all but one
# (Hispanic) contain zero."
claim("desc_adjusted_intervals_shrink", computed_for("desc_adjusted_intervals_shrink"),
      "Results, mean list experiment interval width unadjusted minus adjusted (pp; no verdict: substantially sets no threshold)",
      digits = 1)
claim_evidence(evidence_for("desc_adjusted_intervals_shrink"))

claim("desc_adjusted_all_but_one",
      sum(figure_1$estimator == "Adjusted difference" &
            (figure_1$li > 0 | figure_1$ui < 0)),
      "Results, adjusted difference intervals excluding zero", digits = 0)
claim_evidence(evidence_for("desc_adjusted_all_but_one"))

# "While the possibility of social desirability affecting the direct responses of
# Hispanic voters in particular is theoretically interesting, a lone statistically
# significant difference out of 25 opportunities should not be overinterpreted."
claim("results_n_subgroups", n_distinct(figure_1$group_label),
      "Results, subgroups compared")

# Combined estimate ----

# "The combined estimate of Donald Trump support is 34.8% with a standard error of
# 2.9%."
claim("combined_estimate", 100 * text_value("combined_est"),
      "Combined estimate of Trump support (%)")
claim("combined_estimate_se", 100 * text_value("combined_est", "std_error"),
      "Combined estimate, standard error (pp)")

# "This estimate is 2.2 percentage points higher than the direct estimate, but
# this difference has a standard error of 2.9 percentage points, indicating that
# even with this more efficient estimator, we do not obtain a statistically
# significant difference between direct and indirect methods of measuring support
# for Donald Trump."
claim("combined_minus_direct", 100 * text_value("combined_minus_direct"),
      "Combined minus direct (pp)")

# A bootstrap standard error from resampling code the deposit no longer holds: the
# deposited script, rewritten in October 2019, gives the same value as this
# pipeline and no configuration of it recovers the published one. The published
# value is one draw of a bootstrap nobody can rerun, so agreement to printed digits
# is the wrong test.
claim("combined_minus_direct_se", 100 * text_value("combined_minus_direct", "std_error"),
      "Combined minus direct, standard error (pp)", expect = "range")

claim("desc_combined_not_significant", holds_for("desc_combined_not_significant"),
      "Combined estimate, 1 if the difference from the direct estimate is indistinguishable from zero",
      digits = 0)
claim_evidence(evidence_for("desc_combined_not_significant"))

# "The list experiment estimate among those who directly admit supporting Trump is
# 85.7% with an estimated standard error of 5.6%."
claim("placebo_estimate", 100 * text_value("placebo_ate"),
      "Joint test, list estimate among admitted supporters (%)")
claim("placebo_estimate_se", 100 * text_value("placebo_ate", "std_error"),
      "Joint test, standard error (pp)")

# "The two-sided p-value from a test of the null that the true parameter is 100%
# is 0.01, indicating that the joint test is failed in this case."
claim("placebo_p_value", text_value("placebo_p_value"), "Joint test, two-sided p-value")

# Discussion ----
# The discussion states no quantity of its own.

# Appendix Table A1 ----
# The published appendix table, as this pipeline reproduces it, at the one decimal
# the page prints, with the bootstrap standard error in parentheses. The income
# rows carry the labels the deposited data supports rather than the labels the
# page prints; see errata entry 5.
claim_evidence(
  "Table A1, direct question and list experimental estimates of Trump support",
  table_a1
)

# Gates and summary ----
# assert_claims() stops on a failing verdict, on a quantity erratum whose claim is
# not printed here, and on any difference between the claims printed and those the
# extraction marks needs_block. claim_summary() then prints the verdict counts.
assert_claims()
invisible(claim_summary())
