#!/usr/bin/env Rscript
# Title: Release Gate Script for v0.2.0
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.0 (Onda 5, Item 5.6)
#
# Usage: Rscript scripts/release_gate.R

message("=== RELEASE GATE v0.2.0 ===")

message("\n[1/5] Unit + Server tests")
devtools::test()

message("\n[2/5] CSS Guardrails")
testthat::test_file("tests/testthat/test-css-guardrails.R")

message("\n[3/5] i18n Integrity")
testthat::test_file("tests/testthat/test-utils-i18n.R")
testthat::test_file("tests/testthat/test-i18n-a11y-keys.R")

message("\n[4/5] E2E")
Sys.setenv(RUN_E2E = "true", NOT_CRAN = "true")
testthat::test_file("tests/testthat/test-e2e-flows.R")
Sys.unsetenv(c("RUN_E2E", "NOT_CRAN"))

message("\n[5/5] R CMD check")
devtools::check(document = FALSE, manual = FALSE)

message("\n=== ALL GATES PASSED ===")
