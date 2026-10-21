#!/usr/bin/env Rscript
# Title: Release Gate Script
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.2
#
# Usage: Rscript scripts/release_gate.R        (every step, before a release)
#        Rscript scripts/release_gate.R --ci   (the steps CI runs, see below)
#
# `steps` is the one list of checks for local runs and CI. A required step
# stops the gate at its first failure, so "ALL GATES PASSED" means all of them
# passed. A step with `required = FALSE` only reports.
#
# `ci = FALSE` marks a step CI does not run in the gate job: R CMD check runs
# the whole test suite in its own job, and the report-only steps need the IPT
# or a stable machine.
#
# No step writes to the working tree. The roxygen and CSS steps generate into a
# temp dir and compare.

ci <- "--ci" %in% commandArgs(trailingOnly = TRUE)

# Paths of a file set, named relative to `root`, with their md5 sums.
file_sums <- function(root, paths) {
    full <- file.path(root, paths)
    stats::setNames(unname(tools::md5sum(full)), paths)
}

check_roxygen <- function() {
    # document() rewrites man/, NAMESPACE and DESCRIPTION:Collate. Run it on a
    # copy, so a stale tree fails here without a change to the developer's files.
    copy <- tempfile("saira-roxygen-")
    dir.create(copy)
    on.exit(unlink(copy, recursive = TRUE), add = TRUE)
    file.copy(c("DESCRIPTION", "NAMESPACE", "R", "man", "inst"), copy, recursive = TRUE)

    rd_files <- function(root) file.path("man", dir(file.path(root, "man"), "\\.Rd$"))
    before <- file_sums(".", c("DESCRIPTION", "NAMESPACE", rd_files(".")))
    devtools::document(copy, quiet = TRUE)
    after <- file_sums(copy, c("DESCRIPTION", "NAMESPACE", rd_files(copy)))

    paths <- union(names(before), names(after))
    changed <- paths[is.na(before[paths]) | is.na(after[paths]) |
        before[paths] != after[paths]]
    if (length(changed) > 0L) {
        stop("Roxygen output is out of date. Run devtools::document() and commit: ",
             paste(changed, collapse = ", "), call. = FALSE)
    }

    description <- read.dcf("DESCRIPTION", fields = "Collate")[[1]]
    collate <- scan(text = description, what = "", quiet = TRUE)
    missing_files <- collate[!file.exists(file.path("R", collate))]
    if (length(missing_files) > 0L) {
        stop("DESCRIPTION:Collate references non-existent files: ",
             paste(missing_files, collapse = ", "), call. = FALSE)
    }
}

check_css <- function() {
    # No test reads custom.css against its sources, so a missed rebuild ships
    # old styles.
    built <- tempfile(fileext = ".css")
    on.exit(unlink(built), add = TRUE)
    if (system2("Rscript", c(file.path("data-raw", "build_css.R"), built)) != 0L) {
        stop("data-raw/build_css.R failed", call. = FALSE)
    }
    bundle <- file.path("inst", "app", "www", "custom.css")
    if (!identical(readLines(bundle, warn = FALSE), readLines(built, warn = FALSE))) {
        stop(bundle, " is out of date. Run data-raw/build_css.R and commit it.", call. = FALSE)
    }
}

check_br_snapshot <- function() {
    # The IPT often refuses requests, so this step only reports.
    status <- system2("Rscript", c(file.path("data-raw", "update_brproviders.R"), "--check"))
    if (status != 0L) stop("update_brproviders.R --check exited with ", status, call. = FALSE)
}

check_perf <- function() {
    # Stage 3 of Rostrum already fails its 0.5 s budget on main, so this step
    # only reports. Compare the failures with the last baseline.
    withr::with_envvar(c(RUN_PERF = "true"), {
        devtools::test(filter = "performance|utils-coords", stop_on_failure = TRUE)
    })
}

check_e2e <- function() {
    # test_file() does not load the package, and the flows call its functions.
    pkgload::load_all(".", quiet = TRUE)
    withr::with_envvar(c(RUN_E2E = "true", NOT_CRAN = "true"), {
        testthat::test_file("tests/testthat/test-e2e-flows.R", stop_on_failure = TRUE)
    })
}

steps <- list(
    list(name = "Roxygen output is current", required = TRUE, ci = TRUE,
         run = check_roxygen),
    list(name = "CSS bundle is current", required = TRUE, ci = TRUE,
         run = check_css),
    list(name = "Flora and Fauna BR snapshot", required = FALSE, ci = FALSE,
         run = check_br_snapshot),
    list(name = "Unit + Server tests", required = TRUE, ci = FALSE,
         run = function() devtools::test(stop_on_failure = TRUE)),
    list(name = "Performance budgets", required = FALSE, ci = FALSE,
         run = check_perf),
    list(name = "CSS guardrails", required = TRUE, ci = FALSE,
         run = function() testthat::test_file("tests/testthat/test-css-guardrails.R",
                                              stop_on_failure = TRUE)),
    list(name = "i18n integrity", required = TRUE, ci = FALSE,
         run = function() {
             testthat::test_file("tests/testthat/test-utils-i18n.R", stop_on_failure = TRUE)
             testthat::test_file("tests/testthat/test-i18n-a11y-keys.R", stop_on_failure = TRUE)
         }),
    list(name = "E2E", required = TRUE, ci = TRUE,
         run = check_e2e),
    # error_on stops the gate on an ERROR or a WARNING. NOTEs are only printed.
    list(name = "R CMD check", required = TRUE, ci = FALSE,
         run = function() devtools::check(document = FALSE, manual = FALSE,
                                          error_on = "warning"))
)

if (ci) steps <- Filter(function(step) step$ci, steps)

message("=== RELEASE GATE", if (ci) " (CI)", " ===")
reported <- character(0)
for (i in seq_along(steps)) {
    step <- steps[[i]]
    label <- sprintf("[%d/%d] %s", i, length(steps), step$name)
    message("\n", label, if (!step$required) " (report only)")
    if (step$required) {
        step$run()
    } else {
        tryCatch(step$run(), error = function(e) {
            reported <<- c(reported, step$name)
            message(label, ": ", conditionMessage(e))
        })
    }
    message(label, ": done")
}

if (length(reported) > 0L) {
    message("\nReport-only steps with failures: ", paste(reported, collapse = ", "))
}
message("\n=== ALL GATES PASSED ===")
