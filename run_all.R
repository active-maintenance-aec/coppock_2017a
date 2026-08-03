# coppock_2017a/run_all.R
# Output: run_timings.csv
# Runs the whole reproduction in order: fetch and verify the deposited archive,
# build the analysis frame, then the published table, figure, appendix table and
# in-text quantities, then the archive reproduction check and the ground truth,
# and finally verifies the deposited archive again.
# Every script is self-contained and can also be run on its own.

library(here)
here::i_am("run_all.R")

# Each step is timed, and the timings are written to run_timings.csv at the end.
# The report quotes what the run cost rather than an estimate of it, which is the
# only way a stated runtime cannot drift from the code that incurs it. Base R
# only, because the first step is what loads the tidyverse.
step_name <- character(0)
step_minutes <- numeric(0)

run_step <- function(path, label = path) {
  started <- Sys.time()
  source(here::here(path))
  step_name <<- c(step_name, label)
  step_minutes <<- c(step_minutes,
                     as.numeric(difftime(Sys.time(), started, units = "mins")))
}

# Deposited archive ----
# Downloads from the Yale Dataverse on a fresh clone; verifies checksums either way.
run_step("download_original.R")

# Analysis frame ----
run_step("maintained/clean_trump.R")

# Tables and figures ----
run_step("maintained/table_2_list_response_distribution.R")

# figure_1 is the slow step of the rewrite: 2,000 bootstrap replicates of six
# estimators in each of 25 subgroups. Table A1 and the in-text quantities read its
# estimates rather than repeating the bootstrap, so they run after it.
run_step("maintained/figure_1_direct_vs_list_estimates.R")
run_step("maintained/table_a1_subgroup_estimates.R")

# In-text quantities ----
run_step("maintained/text_main_estimates.R")
run_step("maintained/text_descriptive_claims.R")

# Archive reproduction check ----
# Runs the deposited script itself, four times: at 2,000 replicates under the
# current sampler, at 2,000 under the one R used before version 3.6.0, at the 200
# the deposit ships, and once more at 200 against every file the deposit contains
# rather than against code and data alone. The deposited code is slower than the
# rewrite at the same work and repeats it, so this is by far the slowest step in
# the file. Each run happens in its own process, so this session's sampler is
# never touched.
run_step("ground_truth/run_original_archive.R")

# Ground truth ----
# Rebuilds the comparison table from the outputs above, so it cannot go stale.
run_step("ground_truth/build_ground_truth.R")

# In-text claims ----
# Every number the article prints, beside the sentence that prints it and the
# value this pipeline produces, in reading order. It recomputes from the same
# output/ files the ground truth reads, by its own path, so a disagreement between
# the two is a finding rather than a repetition.
run_step("maintained/in_text_claims.R")

# Deposited archive, verified again ----
# The check at the top of this file is a precondition. Running it again at the end
# is what catches a script that damaged original/ during the run, which otherwise
# goes unnoticed until the next run, possibly months later.
run_step("download_original.R", "download_original.R (re-verify)")

# Timings ----
readr::write_csv(
  tibble::tibble(step = step_name, minutes = step_minutes),
  here::here("run_timings.csv")
)

print(tibble::tibble(step = step_name, minutes = round(step_minutes, 2)), n = 100)
