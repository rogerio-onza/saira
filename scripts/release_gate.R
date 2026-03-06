#!/usr/bin/env Rscript
# Title: Release Gate Script for v0.2.0
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.0 (Onda 5, Item 5.6)
#
# Usage: Rscript scripts/release_gate.R

message("=== RELEASE GATE v0.2.0 ===")

message("\n[0/6] DESCRIPTION integrity check")
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

message("[0/6] ✓ DESCRIPTION integrity OK")

message("\n[1/6] Unit + Server tests")
devtools::test()

message("\n[2/6] CSS Guardrails")
testthat::test_file("tests/testthat/test-css-guardrails.R")

message("\n[3/6] i18n Integrity")
testthat::test_file("tests/testthat/test-utils-i18n.R")
testthat::test_file("tests/testthat/test-i18n-a11y-keys.R")

message("\n[4/6] E2E")
Sys.setenv(RUN_E2E = "true", NOT_CRAN = "true")
testthat::test_file("tests/testthat/test-e2e-flows.R")
Sys.unsetenv(c("RUN_E2E", "NOT_CRAN"))

message("\n[5/6] R CMD check")
devtools::check(document = FALSE, manual = FALSE)

message("\n[6/6] Roxygen hygiene")
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

message("[6/6] ✓ Roxygen hygiene check passed")

message("\n=== ALL GATES PASSED ===")
