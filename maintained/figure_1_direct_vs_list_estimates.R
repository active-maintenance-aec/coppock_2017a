# coppock_2017a/maintained/figure_1_direct_vs_list_estimates.R
# Output: output/figure_1_direct_vs_list_estimates.csv,
#         output/figure_1_direct_vs_list_estimates.pdf,
#         output/figure_1_direct_vs_list_estimates.png,
#         output/figure_1_bootstrap_diagnostics.csv
# Depends on: output/trump.rds, helpers.R
# Description: Direct question and list experiment estimates of Trump support in
#   each subgroup, unadjusted and covariate adjusted, with nonparametric
#   bootstrap standard errors and percentile intervals. Reproduces published
#   Figure 1; the estimates CSV is also what Table A1 prints.

source(here::here("maintained", "helpers.R"))

trump <- read_rds(here::here("maintained", "output", "trump.rds"))

# The deposited script ships 200 replicates with a comment saying the article used
# 2,000. The article itself never states a replicate count, so that comment is the
# only statement of 2,000 in the record and it is the one followed here. This is
# the slow step of the rewrite; run_timings.csv records what the last full run of
# it cost.
set.seed(343)
sims <- 2000
splits <- bootstraps(trump, times = sims)$splits

# Estimators ----
# Four estimates of Trump support per subgroup, plus the two direct-minus-list
# differences. Written to take a data frame so the same function serves both the
# point estimates and the bootstrap replicates.
four_ests <- function(df) {
  direct_fit_adj <- glm(
    direct_Y ~ pid_7 + republican + democrat + LV_INDEX_DUMMY +
      black + hispanic + white + female +
      educ_1 + educ_2 + educ_3 + USHHI2,
    family = binomial(),
    weights = WEIGHTS,
    data = df
  )

  # Imai (2011) NLS regression for the list experiment. It fails outright on a
  # large share of bootstrap draws, with a singular gradient or a singular system,
  # and figure_1_bootstrap_diagnostics.csv counts how often.
  list_fit_adj <- try(
    ictreg(
      list_Y ~ pid_7 + republican + democrat + LV_INDEX_DUMMY +
        black + hispanic + white + female +
        educ_1 + educ_2 + educ_3 + USHHI2,
      weights = "WEIGHTS",
      treat = "Z",
      J = 3,
      method = "nls",
      data = as.data.frame(df)
    ),
    silent = TRUE
  )

  # Reshaping to one row per respondent per subgroup drops the three covariates
  # that are themselves subgroup variables, so they are set aside and rejoined
  # before the adjusted predictions are formed.
  pred_covs <- df |>
    mutate(.row = row_number()) |>
    select(.row, pid_7, female, LV_INDEX_DUMMY)

  df |>
    mutate(entire_sample = 1L, .row = row_number()) |>
    pivot_longer(
      cols = all_of(subgroup_vars),
      names_to = "col",
      values_to = "value",
      values_transform = list(value = as.character)
    ) |>
    mutate(group_key = paste0(col, "_", value)) |>
    left_join(pred_covs, by = ".row") |>
    nest_by(group_key) |>
    reframe(
      n = nrow(data),
      direct_est = weighted.mean(data$direct_Y, data$WEIGHTS),
      list_est = coef(lm(list_Y ~ Z, weights = WEIGHTS, data = data))[["Z"]],
      difference = direct_est - list_est,
      direct_est_adj = mean(plogis(predict(direct_fit_adj, newdata = data))),
      list_est_adj = tryCatch(
        mean(predict(list_fit_adj, newdata = as.data.frame(data))$fit),
        error = \(e) NA_real_
      ),
      difference_adj = direct_est_adj - list_est_adj
    )
}

to_long <- function(df) {
  pivot_longer(df, cols = all_of(estimator_levels),
               names_to = "estimator", values_to = "est")
}

# Point estimates ----
ests <- four_ests(trump) |>
  to_long()

# Bootstrap ----
boot_replicates <- splits |>
  set_names(seq_along(splits)) |>
  map(\(s) to_long(four_ests(as.data.frame(s)))) |>
  list_rbind(names_to = "replicate")

boot_summary <- boot_replicates |>
  summarize(
    se = sd(est, na.rm = TRUE),
    li = quantile(est, 0.025, na.rm = TRUE),
    ui = quantile(est, 0.975, na.rm = TRUE),
    .by = c(group_key, estimator)
  )

# How often the NLS fails ----
# The deposited script wraps the list-experiment NLS in try() and drops the
# replicate when it fails, and the rewrite keeps that behaviour. How often it
# fires is a claim about this data rather than a general one, so it is counted
# rather than assumed, and the two ways it fires are counted separately. A fit
# that fails outright costs the replicate every subgroup at once; a fit that
# succeeds can still leave a single subgroup without a prediction. What the
# adjusted standard errors actually rest on is the usable count per subgroup.
adjusted_by_replicate <- boot_replicates |>
  filter(estimator == "list_est_adj") |>
  summarize(missing = sum(is.na(est)), groups = n(), .by = replicate)

usable_per_subgroup <- boot_replicates |>
  filter(estimator == "list_est_adj") |>
  summarize(usable = sum(!is.na(est)), .by = group_key)

nls_diagnostics <- tibble(
  replicates = nrow(adjusted_by_replicate),
  replicates_with_no_adjusted_estimate =
    sum(adjusted_by_replicate$missing == adjusted_by_replicate$groups),
  replicates_missing_some_subgroup =
    sum(adjusted_by_replicate$missing > 0 &
          adjusted_by_replicate$missing < adjusted_by_replicate$groups),
  min_usable_replicates_per_subgroup = min(usable_per_subgroup$usable),
  max_usable_replicates_per_subgroup = max(usable_per_subgroup$usable)
)

write_csv(
  nls_diagnostics,
  here::here("maintained", "output", "figure_1_bootstrap_diagnostics.csv")
)

# Assemble ----
gg_df <- ests |>
  left_join(boot_summary, by = c("group_key", "estimator")) |>
  left_join(subgroups, by = "group_key") |>
  mutate(
    panel = if_else(str_detect(estimator, "difference"), "Differences", "Estimates"),
    panel = factor(panel, levels = c("Estimates", "Differences")),
    estimator = factor(estimator, levels = estimator_levels, labels = estimator_labels),
    subgroup = factor(subgroup, levels = subgroup_order),
    group_label = factor(group_label, levels = rev(subgroups$group_label))
  ) |>
  arrange(subgroup, desc(group_label), estimator)

write_csv(
  gg_df |> select(group_key, group_label, subgroup, estimator, panel, n, est, se, li, ui),
  here::here("maintained", "output", "figure_1_direct_vs_list_estimates.csv")
)

# Figure ----
# Six overlapping series in each panel, so the legend stays; there is no room to
# label them in place.
g <- ggplot(gg_df, aes(x = est, y = group_label, color = estimator, shape = estimator)) +
  geom_vline(
    data = tibble(panel = factor("Differences", levels = c("Estimates", "Differences"))),
    aes(xintercept = 0),
    linetype = "dashed"
  ) +
  geom_linerange(aes(xmin = li, xmax = ui), position = position_dodge(width = 0.6)) +
  geom_point(position = position_dodge(width = 0.6)) +
  facet_grid(subgroup ~ panel, scales = "free_y", space = "free_y") +
  scale_color_manual(values = c(
    "Direct question estimate" = "#1b7837",
    "List experiment estimate" = "#762a83",
    "Difference" = "#d97800",
    "Adjusted direct question estimate" = "#7fbf7b",
    "Adjusted list experiment estimate" = "#c2a5cf",
    "Adjusted difference" = "#f6b26b"
  )) +
  guides(color = guide_legend(ncol = 2), shape = guide_legend(ncol = 2)) +
  theme_bw() +
  theme(
    axis.title = element_blank(),
    legend.position = "bottom",
    legend.title = element_blank(),
    strip.background = element_blank(),
    strip.text.y = element_blank(),
    legend.key.width = unit(4, "lines")
  )

ggsave(
  here::here("maintained", "output", "figure_1_direct_vs_list_estimates.pdf"),
  plot = g, width = 9, height = 11
)
ggsave(
  here::here("maintained", "output", "figure_1_direct_vs_list_estimates.png"),
  plot = g, width = 9, height = 11, dpi = 300
)

print(gg_df |> filter(group_label == "Entire sample") |> select(estimator, est, se, li, ui))
