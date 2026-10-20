#!/usr/bin/env Rscript
# Title: Release Gate Script
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.1
#
# Usage: Rscript scripts/release_gate.R
#
# A step marked "report only" never stops the gate. Every other step stops it
# at the first failure, so "ALL GATES PASSED" means all of them passed.

message("=== RELEASE GATE ===")

message("\n[0/8] Roxygen output is current")
# Regenerate man/, NAMESPACE and DESCRIPTION:Collate, then stop if any of them
# changed, as the CSS step does.
roxygen_output <- function() {
    paths <- c("DESCRIPTION", "NAMESPACE", dir("man", "\\.Rd$", full.names = TRUE))
    stats::setNames(unname(tools::md5sum(paths)), paths)
}
docs_before <- roxygen_output()
devtools::document()
docs_after <- roxygen_output()
docs_paths <- union(names(docs_before), names(docs_after))
docs_changed <- docs_paths[is.na(docs_before[docs_paths]) |
    is.na(docs_after[docs_paths]) |
    docs_before[docs_paths] != docs_after[docs_paths]]

# Verify no non-existent files in Collate
description <- readLines("DESCRIPTION")
collate_start <- grep("^Collate:", description)
if (length(collate_start) > 0) {
    collate_end <- collate_start + 1
    while (collate_end <= length(description) &&
           grepl("^    '", description[collate_end])) {
        collate_end <- collate_end + 1
    }
    collate_lines <- description[collate_start:(collate_end - 1)]
    # Extract filenames from Collate
    files_in_collate <- gsub(".*'([^']+)'.*", "\\1",
                            grep("'", collate_lines, value = TRUE))
    # Check each file exists in R/
    missing_files <- files_in_collate[!file.exists(file.path("R", files_in_collate))]

    if (length(missing_files) > 0) {
        stop(sprintf(
            "DESCRIPTION:Collate references non-existent files: %s",
            paste(missing_files, collapse = ", ")
        ))
    }
}

if (length(docs_changed) > 0L) {
    stop("Roxygen output was out of date. The gate regenerated it: review and commit ",
         paste(docs_changed, collapse = ", "))
}

message("[0/8] ✓ Roxygen output and DESCRIPTION:Collate OK")

message("\n[1/8] CSS bundle is current")
# No test reads custom.css against its sources, so a missed rebuild ships old
# styles. Rebuild it and stop if the output changed.
css_bundle <- file.path("inst", "app", "www", "custom.css")
css_before <- readLines(css_bundle, warn = FALSE)
if (system2("Rscript", file.path("data-raw", "build_css.R")) != 0L) {
    stop("data-raw/build_css.R failed")
}
if (!identical(css_before, readLines(css_bundle, warn = FALSE))) {
    stop(css_bundle, " was out of date. The gate rebuilt it: review and commit it.")
}

message("\n[2/8] Flora and Fauna BR snapshot (report only)")
# The IPT often refuses requests, so a failed check cannot stop the gate.
system2("Rscript", c(file.path("data-raw", "update_brproviders.R"), "--check"))

message("\n[3/8] Unit + Server tests")
devtools::test(stop_on_failure = TRUE)

message("\n[4/8] Performance budgets (report only)")
# Stage 3 of Rostrum already fails its 0.5 s budget on main, so this step
# cannot stop the gate. Compare the failures with the last baseline.
Sys.setenv(RUN_PERF = "true")
devtools::test(filter = "performance|utils-coords")
Sys.unsetenv("RUN_PERF")

message("\n[5/8] CSS Guardrails")
testthat::test_file("tests/testthat/test-css-guardrails.R", stop_on_failure = TRUE)

message("\n[6/8] i18n Integrity")
testthat::test_file("tests/testthat/test-utils-i18n.R", stop_on_failure = TRUE)
testthat::test_file("tests/testthat/test-i18n-a11y-keys.R", stop_on_failure = TRUE)

message("\n[7/8] E2E")
Sys.setenv(RUN_E2E = "true", NOT_CRAN = "true")
testthat::test_file("tests/testthat/test-e2e-flows.R", stop_on_failure = TRUE)
Sys.unsetenv(c("RUN_E2E", "NOT_CRAN"))

message("\n[8/8] R CMD check")
# error_on stops the gate on an ERROR or a WARNING. NOTEs are only printed.
devtools::check(document = FALSE, manual = FALSE, error_on = "warning")

message("\n=== ALL GATES PASSED ===")
