# Title: CSS guardrail tests
# Author: Codex
# Date: 2026-02-20

extract_all_matches <- function(text, pattern) {
    match_list <- gregexpr(pattern, text, perl = TRUE)
    matches <- regmatches(text, match_list)[[1]]
    if (identical(matches, character(1)) && !nzchar(matches[[1]])) {
        return(character(0))
    }
    matches
}

resolve_css_path <- function() {
    installed_path <- system.file("app", "www", "custom.css", package = "finch")
    if (nzchar(installed_path) && file.exists(installed_path)) {
        return(installed_path)
    }

    file.path(pkg_root, "inst", "app", "www", "custom.css")
}

testthat::test_that("custom.css does not use undefined CSS tokens", {
    css_path <- resolve_css_path()
    testthat::expect_true(file.exists(css_path), info = "custom.css not found")

    css_text <- paste(readLines(css_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

    defined_raw <- extract_all_matches(css_text, "--[a-z0-9-]+\\s*:")
    used_raw <- extract_all_matches(css_text, "var\\(--[a-z0-9-]+")

    defined <- unique(trimws(sub(":$", "", gsub("\\s+", "", defined_raw))))
    used <- unique(sub("^var\\(", "", used_raw))

    undefined <- setdiff(used, defined)
    testthat::expect_length(undefined, 0L)
    if (length(undefined) > 0L) {
        testthat::fail(paste("Undefined CSS tokens:", paste(undefined, collapse = ", ")))
    }
})

testthat::test_that("custom.css keeps !important usage under hard limit", {
    css_path <- resolve_css_path()
    css_text <- paste(readLines(css_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    important_count <- length(extract_all_matches(css_text, "!important"))

    testthat::expect_lte(important_count, 12L)
    if (important_count > 12L) {
        testthat::fail(sprintf("Too many !important declarations: %d", important_count))
    }
})

testthat::test_that("custom.css does not use opacity 0.45 in DataTables pagination disabled controls", {
    css_path <- resolve_css_path()
    css_lines <- readLines(css_path, warn = FALSE, encoding = "UTF-8")
    opacity_lines <- grep("opacity\\s*:\\s*0\\.45", css_lines, perl = TRUE)
    has_low_opacity_disabled_paginate <- FALSE

    if (length(opacity_lines) > 0L) {
        for (line_idx in opacity_lines) {
            start_idx <- max(1L, line_idx - 20L)
            context <- css_lines[start_idx:line_idx]
            in_paginate_block <- any(grepl("dataTables_paginate", context, fixed = TRUE)) &&
                any(grepl("disabled", context, fixed = TRUE))
            if (isTRUE(in_paginate_block)) {
                has_low_opacity_disabled_paginate <- TRUE
                break
            }
        }
    }

    testthat::expect_false(
        has_low_opacity_disabled_paginate,
        info = "Found opacity: 0.45 in disabled pagination controls"
    )
})
