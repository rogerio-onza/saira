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
    installed_path <- system.file("app", "www", "custom.css", package = "saira")
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

    testthat::expect_lte(important_count, 13L)
    if (important_count > 13L) {
        testthat::fail(sprintf("Too many !important declarations: %d", important_count))
    }
})

testthat::test_that("custom.css removes hardcoded IBM font-family declarations", {
    css_path <- resolve_css_path()
    css_text <- paste(readLines(css_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

    hardcoded_ibm <- extract_all_matches(
        css_text,
        "font-family\\s*:\\s*['\\\"]IBM Plex (Mono|Sans)['\\\"][^;]*;"
    )

    testthat::expect_length(hardcoded_ibm, 0L)
    if (length(hardcoded_ibm) > 0L) {
        testthat::fail(
            paste("Hardcoded IBM declarations found:", paste(hardcoded_ibm, collapse = " | "))
        )
    }

    testthat::expect_true(
        grepl("--font-serif:\\s*'Cormorant Garamond',\\s*Georgia,\\s*serif;", css_text, perl = TRUE),
        info = "Missing --font-serif token for Cormorant Garamond"
    )
    testthat::expect_true(
        grepl("--font-mono:\\s*'Space Mono',\\s*'IBM Plex Mono',\\s*monospace;", css_text, perl = TRUE),
        info = "Missing --font-mono v5 token with Space Mono primary fallback stack"
    )
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

testthat::test_that("custom.css enforces navbar spacing and language dropdown guardrails", {
    css_path <- resolve_css_path()
    css_text <- paste(readLines(css_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

    testthat::expect_true(
        grepl("gap:\\s*var\\(--space-5\\)(\\s*!important)?;", css_text, perl = TRUE),
        info = "Navbar nav items should use gap var(--space-5)"
    )

    testthat::expect_true(
        grepl("\\.navbar\\s+\\.navbar-nav>li>a", css_text, perl = TRUE) &&
            grepl("padding:\\s*0\\.64rem\\s+1\\.3rem\\s*!important;", css_text, perl = TRUE),
        info = "Navbar links should use 0.64rem 1.3rem padding"
    )

    testthat::expect_true(
        grepl("\\.navbar\\s+\\.navbar-nav>li\\.dropdown>a\\.dropdown-toggle", css_text, perl = TRUE) &&
            grepl("padding:\\s*0\\.64rem\\s+1\\.3rem\\s*!important;", css_text, perl = TRUE),
        info = "Navbar dropdown toggle should use 0.64rem 1.3rem padding"
    )

    testthat::expect_true(
        grepl("\\.navbar\\s+#lang_switch", css_text, perl = TRUE) &&
            grepl("min-width:\\s*150px;", css_text, perl = TRUE),
        info = "Language select should have min-width 150px"
    )

    testthat::expect_true(
        grepl("\\.navbar\\s+#lang_switch", css_text, perl = TRUE) &&
            grepl("padding:\\s*0\\.5rem\\s+2\\.5rem\\s+0\\.5rem\\s+0\\.95rem;", css_text, perl = TRUE),
        info = "Language select should have increased right padding"
    )

    testthat::expect_true(
        grepl("\\.navbar\\s+#lang_switch", css_text, perl = TRUE) &&
            grepl("background-position:\\s*right\\s+0\\.75rem\\s+center;", css_text, perl = TRUE),
        info = "Language select should keep explicit arrow position"
    )

    testthat::expect_true(
        grepl("content:\\s*'\\\\25BE';", css_text, perl = TRUE),
        info = "Dropdown caret must use escaped content '\\25BE'"
    )
})

testthat::test_that("custom.css keeps validate-names tri-column workspace contracts", {
    css_path <- resolve_css_path()
    css_text <- paste(readLines(css_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

    testthat::expect_true(
        grepl("--validate-names-header-offset:\\s*166px;", css_text, perl = TRUE),
        info = "Missing validate-names header offset token"
    )

    testthat::expect_true(
        grepl("\\.validate-names-page \\.validate-names-workspace\\s*\\{", css_text, perl = TRUE) &&
            grepl("height:\\s*calc\\(100vh - var\\(--validate-names-header-offset\\)\\);", css_text, perl = TRUE),
        info = "Validate-names workspace must use viewport-height contract"
    )

    testthat::expect_true(
        grepl("\\.vn-config-panel\\s*\\{", css_text, perl = TRUE) &&
            grepl("width:\\s*240px;", css_text, perl = TRUE),
        info = "Config panel must keep fixed width 240px"
    )

    testthat::expect_true(
        grepl("\\.vn-report-panel\\s*\\{", css_text, perl = TRUE) &&
            grepl("width:\\s*340px;", css_text, perl = TRUE),
        info = "Report panel must keep fixed width 340px"
    )
})

