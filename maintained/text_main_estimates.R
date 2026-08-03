# coppock_2017a/maintained/text_main_estimates.R
# Output: output/text_main_estimates.csv
# Depends on: output/trump.rds, output/figure_1_direct_vs_list_estimates.csv, helpers.R
# Description: Every quantity the paper states in the running text rather than in
#   a table or figure: the direct-question vote shares, the list-experiment
#   condition means, the estimate among respondents who do not report supporting
#   Trump, the Aronow et al. (2015) combined estimator, the joint test of the
#   list-experiment assumptions, and the width of the income scale the response
#   model uses.

source(here::here("maintained", "helpers.R"))

trump <- read_rds(here::here("maintained", "output", "trump.rds"))

# The entire-sample estimates and their bootstrap standard errors are Figure 1's,
# read here rather than recomputed so the text and the figure cannot disagree.
figure_1 <- read_csv(
  here::here("maintained", "output", "figure_1_direct_vs_list_estimates.csv"),
  show_col_types = FALSE
)

entire_sample <- figure_1 |> filter(group_label == "Entire sample")
entire_sample_est <- deframe(select(entire_sample, estimator, est))
entire_sample_se <- deframe(select(entire_sample, estimator, se))

# Direct question ----
design <- svydesign(ids = ~1, weights = ~WEIGHTS, data = trump)
vote_shares <- prop.table(svytable(~vote_choice, design))

trump_share <- unname(vote_shares["1"])
clinton_share <- unname(vote_shares["2"])
other_share <- 1 - trump_share - clinton_share

# List experiment ----
condition_means <- trump |>
  summarize(mean_items = weighted.mean(list_Y, WEIGHTS), .by = Z) |>
  arrange(Z) |>
  deframe()

nondiscloser_means <- trump |>
  filter(direct_Y == 0) |>
  summarize(mean_items = weighted.mean(list_Y, WEIGHTS), .by = Z) |>
  arrange(Z) |>
  deframe()

# The article calls the list experiment estimate among non-disclosers not
# statistically distinguishable from zero and prints no standard error for it, so
# one is fitted here. Every estimation in this pipeline happens in an analysis
# script; the scripts that check claims only read and derive.
fit_nondisclosers <- lm_robust(list_Y ~ Z, weights = WEIGHTS,
                               data = filter(trump, direct_Y == 0))
nondiscloser_ate <- tidy(fit_nondisclosers) |> filter(term == "Z")

# Combined estimator ----
# Aronow, Coppock, Crawford and Green (2015): the direct question estimate plus
# the list experiment estimate among those who do not report supporting Trump,
# scaled by their share of the sample. Uncertainty by nonparametric bootstrap,
# at the same 2,000 replicates and seed as Figure 1.
combined_estimator <- function(df) {
  list_fit_nondisclosers <- lm(list_Y ~ Z, weights = WEIGHTS, data = filter(df, direct_Y == 0))
  direct_est <- coef(lm(direct_Y ~ 1, weights = WEIGHTS, data = df))[["(Intercept)"]]
  combined_est <- direct_est + (1 - direct_est) * coef(list_fit_nondisclosers)[["Z"]]
  tibble(direct_est = direct_est,
         combined_est = combined_est,
         difference = combined_est - direct_est)
}

set.seed(343)
sims <- 2000
combined_point <- combined_estimator(trump)
combined_boot <- bootstraps(trump, times = sims)$splits |>
  map(\(s) combined_estimator(as.data.frame(s))) |>
  list_rbind()

# Joint test of the list experiment assumptions ----
# Under No Liars, No Design Effects and No False Confessions the list experiment
# estimate among those who do report supporting Trump equals 1.
fit_placebo <- lm_robust(list_Y ~ Z, weights = WEIGHTS, data = filter(trump, direct_Y == 1))
placebo <- tidy(fit_placebo) |> filter(term == "Z")
placebo_p <- 2 * pnorm(abs((placebo$estimate - 1) / placebo$std.error), lower.tail = FALSE)

# Coverage claims ----
# The paper says most unadjusted difference intervals contain zero and that among
# the adjusted differences all but one do.
covers_zero <- figure_1 |>
  filter(estimator %in% c("Difference", "Adjusted difference")) |>
  summarize(n_excluding_zero = sum(li > 0 | ui < 0), .by = estimator) |>
  deframe()

# Save ----
results <- tribble(
  ~quantity, ~estimate, ~std_error,
  "n_respondents", nrow(trump), NA_real_,
  "n_subgroups_compared", nrow(subgroups), NA_real_,
  "party_id_points", n_distinct(trump$pid_7), NA_real_,
  "income_points", n_distinct(trump$USHHI2), NA_real_,
  "direct_share_trump", trump_share, NA_real_,
  "direct_share_clinton", clinton_share, NA_real_,
  "direct_share_other", other_share, NA_real_,
  "list_mean_control", condition_means[["0"]], NA_real_,
  "list_mean_treatment", condition_means[["1"]], NA_real_,
  "list_ate", entire_sample_est[["List experiment estimate"]], entire_sample_se[["List experiment estimate"]],
  "direct_minus_list", entire_sample_est[["Difference"]], entire_sample_se[["Difference"]],
  "share_not_reporting_trump", 1 - trump_share, NA_real_,
  "list_mean_control_nondisclosers", nondiscloser_means[["0"]], NA_real_,
  "list_mean_treatment_nondisclosers", nondiscloser_means[["1"]], NA_real_,
  "list_ate_nondisclosers", nondiscloser_ate$estimate, nondiscloser_ate$std.error,
  "direct_est", combined_point$direct_est, NA_real_,
  "combined_est", combined_point$combined_est, sd(combined_boot$combined_est),
  "combined_minus_direct", combined_point$difference, sd(combined_boot$difference),
  "placebo_ate", placebo$estimate, placebo$std.error,
  "placebo_p_value", placebo_p, NA_real_,
  "unadjusted_differences_excluding_zero", covers_zero[["Difference"]], NA_real_,
  "adjusted_differences_excluding_zero", covers_zero[["Adjusted difference"]], NA_real_
)

write_csv(results, here::here("maintained", "output", "text_main_estimates.csv"))

print(results, n = nrow(results))
