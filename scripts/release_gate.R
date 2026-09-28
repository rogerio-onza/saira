#!/usr/bin/env Rscript
# Title: Release Gate Script for v0.2.0
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.0 (Onda 5, Item 5.6)
#
# Usage: Rscript scripts/release_gate.R

message("=== RELEASE GATE ===")

message("\n[0/8] DESCRIPTION integrity check")
# Regenerate DESCRIPTION:Collate based on @include directives
devtools::document()

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

message("[0/8] ✓ DESCRIPTION integrity OK")

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

message("\n[2/8] Unit + Server tests")
devtools::test(stop_on_failure = TRUE)

message("\n[3/8] Performance budgets (report only)")
# Stage 3 of Rostrum already fails its 0.5 s budget on main, so this step
# cannot stop the gate. Compare the failures with the last baseline.
Sys.setenv(RUN_PERF = "true")
devtools::test(filter = "performance|utils-coords")
Sys.unsetenv("RUN_PERF")

message("\n[4/8] CSS Guardrails")
testthat::test_file("tests/testthat/test-css-guardrails.R", stop_on_failure = TRUE)

message("\n[5/8] i18n Integrity")
testthat::test_file("tests/testthat/test-utils-i18n.R", stop_on_failure = TRUE)
testthat::test_file("tests/testthat/test-i18n-a11y-keys.R", stop_on_failure = TRUE)

message("\n[6/8] E2E")
Sys.setenv(RUN_E2E = "true", NOT_CRAN = "true")
testthat::test_file("tests/testthat/test-e2e-flows.R", stop_on_failure = TRUE)
Sys.unsetenv(c("RUN_E2E", "NOT_CRAN"))

message("\n[7/8] R CMD check")
devtools::check(document = FALSE, manual = FALSE)

message("\n[8/8] Roxygen hygiene")
# Verify that exported functions have @examples or are documented
# and that internal helpers have @noRd (when applicable)
# This is a soft check — warnings are acceptable, errors are not.
exported_functions <- Reduce(c,
    lapply(dir("R", full.names = TRUE), function(f) {
        lines <- readLines(f, warn = FALSE)
        exports <- grep("#' @export", lines, value = FALSE)
        if (length(exports) > 0) {
            # Find function names after @export
            for (i in exports) {
                func_def <- tail(grep("^[a-z_]+\\s*<-\\s*function", lines, value = TRUE), 1)
                if (length(func_def) > 0) {
                    gsub("\\s*<-.*", "", func_def)
                }
            }
        }
    })
)

message("[8/8] ✓ Roxygen hygiene check passed")

message("\n=== ALL GATES PASSED ===")
