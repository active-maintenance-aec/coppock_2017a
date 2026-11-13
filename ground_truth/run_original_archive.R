# coppock_2017a/ground_truth/run_original_archive.R
# Output: ground_truth/original_archive_estimates.csv,
#         ground_truth/original_archive_scalars.csv,
#         ground_truth/original_archive_configurations.csv,
#         ground_truth/archive_run_status.csv,
#         ground_truth/archive_overwrites.csv
# Depends on: original/ (run download_original.R first)
# Description: Run the deposited analysis script as deposited and capture its
#   numbers, so the ground truth can compare the archive against the article
#   without anyone retyping either. This is the archive reproduction check and it
#   is a different question from whether the maintained rewrite works, so it lives
#   in its own script and writes its own output.
#
#   The script is run four times, each in its own Rscript process.
#     current   2,000 replicates, today's sampler. This is the configuration the
#               ground truth's value_script column comes from.
#     rounding  2,000 replicates under RNGkind(sample.kind = "Rounding"), which
#               restores the sample() of R before 3.6.0. The article appeared in
#               2017 and the sampler changed in April 2019, so the published
#               bootstrap standard errors were drawn under the old sampler and the
#               comparison is worth making.
#     shipped   200 replicates, today's sampler. 200 is what the deposit ships,
#               with 2,000 commented out one line above, so this run measures what
#               a reader who runs the deposit unedited gets.
#     shipped_as_deposited
#               the same 200 replicates, run against every file the deposit ships
#               rather than against code and data alone.
#   The first three are the stripped pass and the fourth the as-shipped pass, in
#   the vocabulary of archive_run_status.csv.
#   Running each in its own process means the sampler in this session is never
#   touched; the assertion at the end of this file records that.
#
#   The first three runs hold the deposited data and the deposited code and
#   nothing else. A script that runs against an archive as downloaded can pass by
#   loading an intermediate the archive ships rather than one it built, and the
#   only way to tell is to remove everything that is neither data nor code. This
#   deposit ships no intermediates at all, so the test passes trivially, but both
#   input sets are run and the outcome of each is recorded in
#   archive_run_status.csv rather than assumed.
#
#   Every run also records, by modification time, which deposited files it wrote
#   over. That is the measurement behind the rule against running an archive in
#   place, and it is cheap enough that there is no reason to assert it instead.
#
#   Four edits are made to the copy of the deposited script, and no others. Two
#   fill in lines the deposit itself marks as user-configurable:
#     setwd("")    the deposit says "Uncomment to set working directory"
#     sims <- 200  the deposit says "The article uses 2000 sims" one line above
#   The third reads the placebo estimate and standard error with pull() rather
#   than tidy(placebo_r)[2,2] and [2,3]. estimatr 2.0's tidy() returns a tibble,
#   which does not drop a one-cell index to a number, so the deposit's next line
#   stops in pnorm(). The values read are the same.
#   The fourth appends a block that saves objects the script has already computed,
#   and re-evaluates two expressions the script prints but does not store. Nothing
#   in the analysis is altered.

library(here)
library(tidyverse)

here::i_am("ground_truth/run_original_archive.R")

# The archive is run in a scratch directory outside the repository. Anyone can
# point it somewhere else with ARCHIVE_RUN_DIR; the default is this session's
# temporary directory, so the script is portable and carries no path from the
# machine it was written on. Only the named subdirectory is ever created or
# removed.
archive_run_dir <- Sys.getenv("ARCHIVE_RUN_DIR", unset = tempdir())

stopifnot(nzchar(archive_run_dir), dir.exists(archive_run_dir))

scratch <- file.path(archive_run_dir, "coppock_2017a_archive_run")

# The deposited code and the deposited data. README.txt is prose, and leaving it
# out is what makes the stripped runs a test: the copy the archive runs against
# then contains nothing that could stand in for something the script is supposed
# to build.
archive_code <- "shy_trump_analysis.r"
archive_data <- "shy_trump_cleaned.csv"
archive_readme <- "README.txt"

# The output path is written into the appended block rather than set beforehand,
# because the deposited script opens with rm(list = ls()) and would delete a
# variable holding it.
capture_block <- function(capture_path) {
  str_glue(
    '
# --- appended by ground_truth/run_original_archive.R ---
captured <- list(
  vote_shares = prop.table(svytable(formula = ~ vote_choice, design)),
  list_condition_ns = colSums(with(trump, table(list_Y, Z))),
  table_2 = as.data.frame(tab, stringsAsFactors = FALSE),
  list_fit = coef(fit_r),
  nondiscloser_fit = coef(fit_2_r),
  results_df = as.data.frame(results_df),
  combined_point = combined_estimator(trump),
  combined_boot = combined_boot,
  placebo = c(estimate = as.numeric(est), std.error = as.numeric(se),
              p_value = as.numeric(p_value))
)
saveRDS(captured, "[capture_path]")
',
    .open = "[", .close = "]"
  )
}

# The deposit is run in a scratch copy, never in original/, because the script
# opens a graphics device and writes Rplots.pdf into its working directory. An
# archive that writes into itself silently overwrites part of the deposit.
run_archive <- function(run_id, sampler, sims, pass) {
  deposited <- if (pass == "as_shipped") {
    c(archive_code, archive_data, archive_readme)
  } else {
    c(archive_code, archive_data)
  }

  unlink(scratch, recursive = TRUE)
  dir.create(scratch, showWarnings = FALSE, recursive = TRUE)
  file.copy(here::here("original", deposited), scratch)

  stopifnot(setequal(list.files(scratch), deposited))

  # Which deposited files the run writes over, measured rather than asserted.
  mtimes_before <- file.mtime(file.path(scratch, deposited)) |> set_names(deposited)
  md5_before <- tools::md5sum(file.path(scratch, deposited)) |> set_names(deposited)

  capture_path <- file.path(scratch, str_glue("captured_{run_id}.rds"))
  log_path <- file.path(scratch, str_glue("log_{run_id}.txt"))

  src <- read_lines(file.path(scratch, archive_code))
  src <- str_replace(src, '^# setwd\\(""\\)$', str_glue('setwd("{scratch}")'))
  src <- str_replace(src, "^sims <- 200$", str_glue("sims <- {sims}"))
  src <- str_replace(src, "^est <- tidy\\(placebo_r\\)\\[2,2\\]$",
                     "est <- pull(tidy(placebo_r), estimate)[2]")
  src <- str_replace(src, "^se <- tidy\\(placebo_r\\)\\[2,3\\]$",
                     "se <- pull(tidy(placebo_r), std.error)[2]")
  stopifnot(any(str_detect(src, "^setwd\\(")),
            any(str_detect(src, str_glue("^sims <- {sims}$"))),
            sum(str_detect(src, "^(est|se) <- pull\\(tidy\\(placebo_r\\)")) == 2)

  preamble <- if (sampler == "rounding") 'suppressWarnings(RNGkind(sample.kind = "Rounding"))'

  runner <- file.path(scratch, str_glue("run_{run_id}.R"))
  write_lines(c(preamble, src, capture_block(capture_path)), runner)

  # Both streams are captured into one vector rather than redirected to a file,
  # so the order is preserved and neither can overwrite the other.
  started <- Sys.time()
  console <- system2("Rscript", c("--vanilla", shQuote(runner)),
                     stdout = TRUE, stderr = TRUE)
  elapsed <- as.numeric(difftime(Sys.time(), started, units = "mins"))
  write_lines(console, log_path)
  status <- attr(console, "status")

  if (!is.null(status) || !file.exists(capture_path)) {
    print(tail(console, 25))
    stop(str_glue("The deposited script failed in run {run_id}; see {log_path}."))
  }

  mtimes_after <- file.mtime(file.path(scratch, deposited)) |> set_names(deposited)
  md5_after <- tools::md5sum(file.path(scratch, deposited)) |> set_names(deposited)
  overwritten <- deposited[mtimes_after != mtimes_before]

  list(
    captured = read_rds(capture_path),
    log = console,
    exit_status = 0L,
    stray_files = setdiff(list.files(scratch, all.files = TRUE, no.. = TRUE),
                          c(deposited, basename(capture_path),
                            basename(log_path), basename(runner))),
    deposited_files_overwritten = overwritten,
    overwritten_matches_deposit = unname(md5_after[overwritten] == md5_before[overwritten]),
    minutes = elapsed
  )
}

run_plan <- tibble(
  run_id = c("current", "rounding", "shipped", "shipped_as_deposited"),
  sampler = c("current", "rounding", "current", "current"),
  sims = c(2000, 2000, 200, 200),
  pass = c("stripped", "stripped", "stripped", "as_shipped")
)

runs <- pmap(run_plan, run_archive) |>
  set_names(run_plan$run_id)

archive <- map(runs, "captured")

# What each run of the deposited script did ----
# The canonical archive tables are one row per script per pass, and three of the
# four runs share the stripped pass, so the pass is the unit here: a pass ran clean
# only if every run in it did, and a file it added or wrote over is listed once.
# The configurations, which differ by replicate count and sampler rather than by
# input set, are recorded with their run time in
# original_archive_configurations.csv, which the README reads.
configurations <- run_plan |>
  mutate(
    warning_blocks = map_int(runs, \(r) sum(str_detect(r$log, "^Warning message"))),
    minutes = map_dbl(runs, "minutes")
  ) |>
  select(run_id, pass, sims, sampler, warning_blocks, minutes)

write_csv(configurations,
          here::here("ground_truth", "original_archive_configurations.csv"))

run_status <- run_plan |>
  mutate(exit_status = map_int(runs, "exit_status")) |>
  summarize(exit_status = max(exit_status), .by = pass) |>
  transmute(pass, script = archive_code, role = "analysis", exit_status,
            outcome = if_else(exit_status == 0, "clean", "error"),
            stopped_at = NA_character_)

overwrites <- map2(runs, run_plan$pass, \(r, p) {
  tibble(
    pass = p,
    file = c(r$stray_files, r$deposited_files_overwritten),
    effect = rep(c("added", "overwritten"),
                 c(length(r$stray_files), length(r$deposited_files_overwritten))),
    matches_deposit = c(rep(NA, length(r$stray_files)), r$overwritten_matches_deposit)
  )
}) |>
  list_rbind() |>
  distinct() |>
  arrange(desc(pass), effect, file)

# A file written over in one run of a pass and left intact in another would appear
# twice above with two verdicts, which the one-row-per-file table cannot hold.
stopifnot(!any(duplicated(select(overwrites, pass, file, effect))))

write_csv(run_status, here::here("ground_truth", "archive_run_status.csv"))
write_csv(overwrites, here::here("ground_truth", "archive_overwrites.csv"))

# Subgroup estimates ----
# results_df carries the archive's own subgroup labels, which is what the
# published Figure 1 and Table A1 print. The income labels are rotated by one
# relative to the data; see the Errata section of the report.
estimates <- archive |>
  imap(\(a, run_id) {
    a$results_df |>
      as_tibble() |>
      transmute(run_id = run_id,
                group_label = as.character(group),
                estimator = as.character(estimator),
                n, est, se, li, ui)
  }) |>
  list_rbind()

# The two 200-replicate runs differ only in whether README.txt sat in the working
# directory, so every number they produce must be identical. Asserting it is what
# makes the stripped run a test with a result rather than a claim about intent.
stripped_200 <- filter(estimates, run_id == "shipped") |> select(-run_id)
shipped_200 <- filter(estimates, run_id == "shipped_as_deposited") |> select(-run_id)

stopifnot(identical(stripped_200, shipped_200))

write_csv(estimates, here::here("ground_truth", "original_archive_estimates.csv"))

# Scalar quantities ----
scalars <- archive |>
  imap(\(a, run_id) {
    tribble(
      ~quantity, ~estimate, ~std_error,
      "direct_share_trump", unname(a$vote_shares["1"]), NA_real_,
      "direct_share_clinton", unname(a$vote_shares["2"]), NA_real_,
      "direct_share_other", 1 - unname(a$vote_shares["1"]) - unname(a$vote_shares["2"]), NA_real_,
      "n_control", unname(a$list_condition_ns["0"]), NA_real_,
      "n_treatment", unname(a$list_condition_ns["1"]), NA_real_,
      "list_mean_control", unname(a$list_fit["(Intercept)"]), NA_real_,
      "list_mean_treatment", unname(sum(a$list_fit)), NA_real_,
      "list_mean_control_nondisclosers", unname(a$nondiscloser_fit["(Intercept)"]), NA_real_,
      "list_mean_treatment_nondisclosers", unname(sum(a$nondiscloser_fit)), NA_real_,
      "list_ate_nondisclosers", unname(a$nondiscloser_fit["Z"]), NA_real_,
      "direct_est", a$combined_point$direct_est, NA_real_,
      "combined_est", a$combined_point$combined_est, sd(a$combined_boot$combined_est),
      "combined_minus_direct", a$combined_point$diff, sd(a$combined_boot$diff),
      "placebo_ate", unname(a$placebo["estimate"]), unname(a$placebo["std.error"]),
      "placebo_p_value", unname(a$placebo["p_value"]), NA_real_
    ) |>
      mutate(run_id = run_id, .before = 1)
  }) |>
  list_rbind()

table_2 <- archive |>
  imap(\(a, run_id) {
    a$table_2 |>
      setNames(c("items", "condition", "share")) |>
      as_tibble() |>
      transmute(run_id = run_id,
                quantity = as.character(str_glue(
                  "table_2_{str_replace_all(str_to_lower(condition), ' ', '_')}_{parse_number(items)}_items"
                )),
                estimate = share,
                std_error = NA_real_)
  }) |>
  list_rbind()

write_csv(bind_rows(scalars, table_2),
          here::here("ground_truth", "original_archive_scalars.csv"))

# The four runs happened in separate processes, so this session's sampler is
# untouched. Assert it rather than assume it: run_all.R sources scripts in
# sequence and a leaked sampler would silently change every draw after this one.
stopifnot(identical(RNGkind()[3], "Rejection"))

print(configurations, width = 200)
print(run_status, width = 200)
print(overwrites, width = 200)

print(str_glue("Archive run captured: {nrow(estimates)} subgroup estimates and ",
               "{nrow(scalars) + nrow(table_2)} scalars across {nrow(run_plan)} runs."))
