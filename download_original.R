# coppock_2017a/download_original.R
# Output: original/ (the deposited replication archive, not redistributed in this repo)
# Depends on: original_manifest.csv
# Description: Fetch the deposited archive from the Yale Dataverse and verify
#   every file. Run this once before running anything in maintained/. Re-running
#   is free: files already present with the right checksum are not downloaded
#   again.
#
#   This deposit is not on Harvard Dataverse, which is where the rest of this
#   program's archives live. It began life in the Yale ISPS Data Archive under
#   the handle hdl:10079/zw3r2f9 and now sits in the Yale Dataverse, a separate
#   installation of the same software with its own DOI prefix. The API call and
#   the ?format=original convention are identical; only the host and the dataset
#   DOI differ.
#
#   The manifest carries two checksums per file. md5_served is the MD5 of the
#   bytes Dataverse returns for ?format=original, which is what this code was
#   written against. md5_published is the checksum Dataverse displays. Here all
#   three agree, but they do not always: other deposits in this program carry
#   published checksums that verify neither the original nor the derived tabular
#   file, so verification runs against md5_served and any disagreement is
#   reported rather than allowed to fail the check for the wrong reason.

library(tidyverse)
library(here)

here::i_am("download_original.R")

dataset_doi <- "doi:10.60600/YU/Z88TZQ"
base_url <- "https://dataverse.yale.edu/api/access/datafile"

# Manifest ----
manifest <- read_csv(here::here("original_manifest.csv"), show_col_types = FALSE)

dir.create(here::here("original"), showWarnings = FALSE)

# Download what is missing or wrong ----
# format=original asks for the deposited bytes rather than the tabular
# representation Dataverse derives for ingested files. shy_trump_cleaned.csv is
# ingested and is served as shy_trump_cleaned.tab without it.
planned <- manifest |>
  mutate(
    path = here::here("original", file),
    url = str_glue("{base_url}/{dataverse_file_id}?format=original"),
    md5_local = unname(tools::md5sum(path)),
    needs_download = is.na(md5_local) | md5_local != md5_served
  )

walk2(
  planned$url[planned$needs_download],
  planned$path[planned$needs_download],
  function(url, path) download.file(url, destfile = path, mode = "wb", quiet = TRUE)
)

print(str_glue("Downloaded {sum(planned$needs_download)} of {nrow(planned)} files; ",
               "{sum(!planned$needs_download)} already present and verified."))

# Verify ----
verified <- planned |>
  mutate(
    md5_downloaded = unname(tools::md5sum(path)),
    bytes_local = file.size(path),
    match = md5_downloaded == md5_served,
    size_match = bytes_local == bytes,
    published_agrees = md5_served == md5_published
  ) |>
  select(file, bytes, bytes_local, md5_served, md5_downloaded, match, size_match,
         published_agrees)

print(verified, n = nrow(verified))

if (!all(verified$match) || !all(verified$size_match)) {
  stop("Checksum or size mismatch: the downloaded archive does not match what Dataverse served when this code was written.")
}

print(str_glue("All {nrow(verified)} files match. ",
               "{sum(!verified$published_agrees)} carry a published checksum that disagrees."))

# original/ holds the deposit and nothing else ----
# A name check on its own would pass a deposited file that had been renamed by
# hand, so the checksums above do the real work and this catches strays: an
# Rplots.pdf, a bulk-download zip, anything a run left behind.
strays <- setdiff(
  list.files(here::here("original"), recursive = TRUE, all.files = TRUE, no.. = TRUE),
  manifest$file
)

if (length(strays) > 0) {
  stop(str_glue("original/ contains files that are not in the deposit: ",
                "{paste(strays, collapse = ', ')}"))
}

print(str_glue("Archive: {dataset_doi}"))
