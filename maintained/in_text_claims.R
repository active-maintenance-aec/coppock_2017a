# coppock_2017a/maintained/in_text_claims.R
# Output: printed to the console; no file
# Depends on: output/figure_1_direct_vs_list_estimates.csv,
#             output/table_2_list_response_distribution.csv,
#             output/table_a1_subgroup_estimates.csv,
#             output/text_main_estimates.csv,
#             output/text_descriptive_claims.csv, helpers.R
# Description: Every number the article prints, paired with the sentence that
#   prints it and with the value this pipeline produces, in the article's own
#   units and rounding, in the order a reader meets them.
#
#   This file recomputes. It reads the same output/ files the ground truth reads
#   and does its own filtering, unit conversion and rounding, so the two arrive at
#   each number by separate paths and a disagreement between them is a finding
#   rather than a coincidence. It never reads the ground-truth CSV, and it never
#   refits a model: the pipeline has already produced the numbers.
#
#   Each block carries the article's sentence verbatim, then the value. Float
#   cells carry no sentence, because they are read off a table rather than out of
#   a sentence, and their block prints the whole reproduced table.
#
#   The "# claim_id:" line on each block is what ground_truth/build_ground_truth.R
#   checks coverage against: every pipeline and descriptive claim in
#   ground_truth/published_claims.csv must appear here. An id ending in * covers
#   every claim sharing that prefix, which is how one block covers a table.
#
#   cat() is used for scalars because a labelled line per claim is what makes the
#   output scannable beside the sentences; the two float blocks print tibbles,
#   because a table cell is not a scalar.

source(here::here("maintained", "helpers.R"))

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

# The verdict on a descriptive claim that reduces to one. Claims that do not
# reduce have no verdict and are never passed here.
holds_for <- function(claim) {
  value <- descriptive$holds[descriptive$claim_id == claim]
  stopifnot(length(value) == 1, !is.na(value))
  value == 1
}

# Every claim's line is counted as it is printed, and the count is checked at the
# end against the claim_id declarations above. A block that stops printing while
# its declaration stays behind would otherwise read as coverage to the gate in
# build_ground_truth.R, which can only see the comments.
printed_labels <- character(0)

report_value <- function(label, value, digits = 1) {
  printed_labels <<- c(printed_labels, label)
  cat(label, ": ", formatC(value, digits = digits, format = "f"), "\n", sep = "")
}

report_text <- function(label, value) {
  printed_labels <<- c(printed_labels, label)
  cat(label, ": ", value, "\n", sep = "")
}

# Abstract ----

# "I evaluate this hypothesis by comparing direct question and list experimental
# estimates of Trump support in a nationally representative survey of 5290
# American adults fielded from September 2 to September 13, 2016."
# claim_id: abstract_n_respondents
report_value("Abstract, respondents surveyed", text_value("n_respondents"), digits = 0)

# "Of these, 32.5% report supporting Trump's candidacy."
# claim_id: abstract_direct_share
report_value("Abstract, direct question Trump support (%)",
             100 * text_value("direct_share_trump"))

# "A list experiment conducted on the same respondents yields an estimate 29.6%,
# suggesting that Trump's poll numbers were not artificially deflated by social
# desirability bias as the list experiment estimate is actually lower than direct
# question estimate."
# claim_id: abstract_list_estimate
report_value("Abstract, list experiment estimate of Trump support (%)",
             100 * figure_value("Entire sample", "List experiment estimate"))

# claim_id: desc_list_below_direct
report_text("Abstract, is the list estimate below the direct estimate",
            if_else(figure_value("Entire sample", "List experiment estimate") <
                      figure_value("Entire sample", "Direct question estimate"),
                    "yes", "no"))
report_text("  evidence", evidence_for("desc_list_below_direct"))

# Introduction ----
# The introduction's numbers are the fivethirtyeight forecast, the certified
# returns, and a mode gap reported by Dropp (2015). Nothing in the deposit bears
# on any of them, so they are classified transcribed in published_claims.csv and
# carry no block here.

# Design ----

# "Reuters/IPSOS conducted a nationally-representative online poll of 5290 adult
# Americans from September 2 to September 13."
# claim_id: design_n_respondents
report_value("Design, respondents surveyed", text_value("n_respondents"), digits = 0)

# "Respondents split 32.5% for Donald Trump and 37.0% for Hillary Clinton, while
# 30.5% reported that they would vote for other candidates, would not vote, or
# were still undecided."
# claim_id: design_direct_share_trump
report_value("Design, direct question Trump support (%)",
             100 * text_value("direct_share_trump"))

# claim_id: design_direct_share_clinton
report_value("Design, direct question Clinton support (%)",
             100 * text_value("direct_share_clinton"))

# claim_id: design_direct_share_other
report_value("Design, other candidate, would not vote or undecided (%)",
             100 * text_value("direct_share_other"))

# "The list experiment (administered well after the direct question was asked)
# sheds light on the question of whether 32.5% is an underestimate because some
# people are ashamed to admit their support for Donald Trump."
# claim_id: design_direct_share_restated
report_value("Design, direct question Trump support restated (%)",
             100 * text_value("direct_share_trump"))

# Results ----

# The published table the results section opens by naming, as this pipeline
# reproduces it, at the two decimals the page prints. No sentence, because a table
# cell is not read out of one.
# claim_id: table_2_*
cat("\nTable 2, distribution of list experiment responses by treatment condition\n")
print(
  table_2 |>
    mutate(across(-items, \(x) if_else(items == "N",
                                       formatC(x, format = "d"),
                                       formatC(x, digits = 2, format = "f"))))
)

# "The average number of items subjects reported doing in the control group was
# 1.548, whereas in the treatment group the average was 1.843."
# claim_id: results_list_mean_control
report_value("Results, list experiment control group mean (items)",
             text_value("list_mean_control"), digits = 3)

# claim_id: results_list_mean_treatment
report_value("Results, list experiment treatment group mean (items)",
             text_value("list_mean_treatment"), digits = 3)

# "The difference in the averages forms the list experiment estimate of 0.296, or
# 29.6% support for Trump."
# claim_id: results_list_ate_proportion
report_value("Results, list experiment estimate (proportion)",
             figure_value("Entire sample", "List experiment estimate"), digits = 3)

# claim_id: results_list_ate_percent
report_value("Results, list experiment estimate (%)",
             100 * figure_value("Entire sample", "List experiment estimate"))

# "Recall that the direct question estimate of Trump support was 32.5%, for a 2.9
# percentage points difference."
# claim_id: results_direct_share_restated
report_value("Results, direct question Trump support (%)",
             100 * text_value("direct_share_trump"))

# claim_id: results_direct_minus_list
report_value("Results, direct question minus list experiment (pp)",
             100 * figure_value("Entire sample", "Difference"))

# "The bootstrapped standard error of this difference is 3.4 points, indicating
# that is not statistically significantly different from zero."
# claim_id: results_direct_minus_list_se
report_value("Results, bootstrap standard error of the difference (pp)",
             100 * figure_value("Entire sample", "Difference", "se"))

# claim_id: desc_direct_minus_list_not_significant
report_text("Results, does the difference interval contain zero",
            if_else(figure_value("Entire sample", "Difference", "li") <= 0 &
                      figure_value("Entire sample", "Difference", "ui") >= 0,
                    "yes", "no"))
report_text("  evidence", evidence_for("desc_direct_minus_list_not_significant"))

# "Among the 67.5% of the sample who did not state that they would vote for Trump
# when asked directly, the control group average was 1.610 and the treatment group
# average was 1.642."
# claim_id: results_share_not_reporting_trump
report_value("Results, share not reporting Trump support (%)",
             100 * text_value("share_not_reporting_trump"))

# claim_id: results_nondiscloser_mean_control
report_value("Results, non-disclosers, control group mean (items)",
             text_value("list_mean_control_nondisclosers"), digits = 3)

# claim_id: results_nondiscloser_mean_treatment
report_value("Results, non-disclosers, treatment group mean (items)",
             text_value("list_mean_treatment_nondisclosers"), digits = 3)

# "The list experiment therefore suggests that support for Donald Trump among this
# group was a mere 3.3%."
# claim_id: results_nondiscloser_list_ate
report_value("Results, list experiment estimate among non-disclosers (%)",
             100 * text_value("list_ate_nondisclosers"))

# "This estimate is very small, and is itself not statistically significantly
# different from zero."
# claim_id: desc_nondiscloser_not_significant
report_text("Results, is the non-discloser estimate distinguishable from zero",
            if_else(holds_for("desc_nondiscloser_not_significant"),
                    "no", "yes"))
report_text("  evidence", evidence_for("desc_nondiscloser_not_significant"))

# "A brief justification of this specification: all variables except for 7-point
# Party ID and 22-point Income are indicators, so not many modeling choices must
# be made."
# claim_id: results_party_id_points
report_value("Equation 1, points on the party identification scale",
             text_value("party_id_points"), digits = 0)

# claim_id: results_income_points
report_value("Equation 1, points on the income scale",
             text_value("income_points"), digits = 0)

# "Democrats are unlikely to support Trump while Republicans are likely to do so."
# claim_id: desc_party_gradient
report_text("Results, do the three democrat groups fall below and the three republican groups above 50 per cent",
            if_else(holds_for("desc_party_gradient"),
                    "yes", "no"))
report_text("  evidence", evidence_for("desc_party_gradient"))

# "Overall, more educated groups support Trump less, though the estimates for
# those who have not graduated high school are uncertain as this group is
# relatively small."
# claim_id: desc_education_gradient
report_text("Results, education gradient in direct question support (no verdict: the sentence sets no threshold)",
            evidence_for("desc_education_gradient"))

# claim_id: desc_less_than_high_school_smallest
report_text("Results, is the least educated group the smallest subgroup",
            if_else(holds_for("desc_less_than_high_school_smallest"),
                    "yes", "no"))
report_text("  evidence", evidence_for("desc_less_than_high_school_smallest"))

# "Different income groups did not diverge wildly in their support, nor did men
# and women."
# claim_id: desc_income_groups_similar
report_text("Results, spread across income groups (no verdict: wildly sets no threshold)",
            evidence_for("desc_income_groups_similar"))

# claim_id: desc_gender_similar
report_text("Results, men against women (no verdict: the sentence sets no threshold)",
            evidence_for("desc_gender_similar"))

# "By any measure, Whites were more likely to support Trump than any other racial
# or ethnic category."
# claim_id: desc_white_highest
report_text("Results, does White lead every other racial or ethnic category on every estimator",
            if_else(holds_for("desc_white_highest"),
                    "yes", "no"))
report_text("  evidence", evidence_for("desc_white_highest"))

# "Likely voters also expressed higher Trump support."
# claim_id: desc_likely_voters_higher
report_text("Results, do likely voters exceed unlikely voters on every estimator",
            if_else(holds_for("desc_likely_voters_higher"),
                    "yes", "no"))
report_text("  evidence", evidence_for("desc_likely_voters_higher"))

# "Most of the 95% confidence intervals around the difference in the unadjusted
# estimates contain zero."
# claim_id: desc_unadjusted_mostly_cover_zero
report_value("Results, unadjusted difference intervals containing zero",
             sum(figure_1$estimator == "Difference" & figure_1$li <= 0 & figure_1$ui >= 0),
             digits = 0)
report_text("  evidence", evidence_for("desc_unadjusted_mostly_cover_zero"))

# "When we sharpen up the list experiment estimates with covariate-adjusted NLS
# regression, the confidence intervals do indeed shrink substantially, all but one
# (Hispanic) contain zero."
# claim_id: desc_adjusted_intervals_shrink
report_text("Results, interval widths unadjusted against adjusted (no verdict: substantially sets no threshold)",
            evidence_for("desc_adjusted_intervals_shrink"))

# claim_id: desc_adjusted_all_but_one
report_value("Results, adjusted difference intervals excluding zero",
             sum(figure_1$estimator == "Adjusted difference" &
                   (figure_1$li > 0 | figure_1$ui < 0)),
             digits = 0)
report_text("  evidence", evidence_for("desc_adjusted_all_but_one"))

# "While the possibility of social desirability affecting the direct responses of
# Hispanic voters in particular is theoretically interesting, a lone statistically
# significant difference out of 25 opportunities should not be overinterpreted."
# claim_id: results_n_subgroups
report_value("Results, subgroups compared", n_distinct(figure_1$group_label), digits = 0)

# Combined estimate ----

# "The combined estimate of Donald Trump support is 34.8% with a standard error of
# 2.9%."
# claim_id: combined_estimate
report_value("Combined estimate of Trump support (%)", 100 * text_value("combined_est"))

# claim_id: combined_estimate_se
report_value("Combined estimate, standard error (pp)",
             100 * text_value("combined_est", "std_error"))

# "This estimate is 2.2 percentage points higher than the direct estimate, but
# this difference has a standard error of 2.9 percentage points, indicating that
# even with this more efficient estimator, we do not obtain a statistically
# significant difference between direct and indirect methods of measuring support
# for Donald Trump."
# claim_id: combined_minus_direct
report_value("Combined minus direct (pp)", 100 * text_value("combined_minus_direct"))

# claim_id: combined_minus_direct_se
report_value("Combined minus direct, standard error (pp)",
             100 * text_value("combined_minus_direct", "std_error"))

# claim_id: desc_combined_not_significant
report_text("Combined estimate, is the difference from the direct estimate distinguishable from zero",
            if_else(holds_for("desc_combined_not_significant"),
                    "no", "yes"))
report_text("  evidence", evidence_for("desc_combined_not_significant"))

# "The list experiment estimate among those who directly admit supporting Trump is
# 85.7% with an estimated standard error of 5.6%."
# claim_id: placebo_estimate
report_value("Joint test, list estimate among admitted supporters (%)",
             100 * text_value("placebo_ate"))

# claim_id: placebo_estimate_se
report_value("Joint test, standard error (pp)", 100 * text_value("placebo_ate", "std_error"))

# "The two-sided p-value from a test of the null that the true parameter is 100%
# is 0.01, indicating that the joint test is failed in this case."
# claim_id: placebo_p_value
report_value("Joint test, two-sided p-value", text_value("placebo_p_value"), digits = 2)

# Discussion ----
# The discussion states no quantity of its own.

# Appendix Table A1 ----
# The published appendix table, as this pipeline reproduces it, at the one decimal
# the page prints, with the bootstrap standard error in parentheses. The income
# rows carry the labels the deposited data supports rather than the labels the
# page prints; see the Errata section of the report.
# claim_id: table_a1_*
cat("\nTable A1, direct question and list experimental estimates of Trump support\n")
print(table_a1, n = nrow(table_a1))

# Every declared claim printed a line ----
# The evidence lines are indented and belong to the claim above them, so the
# claims are the unindented labels. The two float blocks declare a prefix rather
# than an id and print a table each, and are counted separately.
declared <- str_subset(read_lines(here::here("maintained", "in_text_claims.R")),
                       "^#\\s*claim_id:")

exact_ids <- str_subset(declared, "\\*$", negate = TRUE)
claim_lines <- str_subset(printed_labels, "^ ", negate = TRUE)

stopifnot(length(claim_lines) == length(exact_ids),
          !any(duplicated(claim_lines)))

cat("\nPrinted ", length(claim_lines), " claims and ",
    length(declared) - length(exact_ids), " reproduced tables, against ",
    length(declared), " declarations.\n", sep = "")
