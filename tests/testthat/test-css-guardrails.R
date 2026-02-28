# Title: CSS guardrail tests
# Author: Codex
# Date: 2026-02-20
# Updated: 2026-02-28 (Onda 5, Item 5.1 — modular CSS guardrails)

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
        grepl("--font-serif:\\s*'Source Serif 4',\\s*Georgia,\\s*serif;", css_text, perl = TRUE),
        info = "Missing --font-serif token for Source Serif 4"
    )
    testthat::expect_true(
        grepl("--font-mono:\\s*'Space Mono',\\s*'IBM Plex Mono',\\s*monospace;", css_text, perl = TRUE),
        info = "Missing --font-mono v5 token with Space Mono primary fallback stack"
    )
})

testthat::test_that("custom.css enforces design-v7 typography scale and optical sizing", {
    css_path <- resolve_css_path()
    css_text <- paste(readLines(css_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

    testthat::expect_true(grepl("--text-xs:\\s*0\\.75rem;", css_text, perl = TRUE))
    testthat::expect_true(grepl("--text-sm:\\s*0\\.8rem;", css_text, perl = TRUE))
    testthat::expect_true(grepl("--text-base:\\s*1\\.05rem;", css_text, perl = TRUE))
    testthat::expect_true(grepl("--text-md:\\s*1\\.1rem;", css_text, perl = TRUE))
    testthat::expect_true(grepl("--text-lg:\\s*1\\.25rem;", css_text, perl = TRUE))
    testthat::expect_true(grepl("--text-xl:\\s*1\\.5rem;", css_text, perl = TRUE))
    testthat::expect_true(grepl("--text-2xl:\\s*1\\.75rem;", css_text, perl = TRUE))
    testthat::expect_true(grepl("--weight-regular:\\s*400;", css_text, perl = TRUE))
    testthat::expect_true(grepl("--weight-medium:\\s*500;", css_text, perl = TRUE))
    testthat::expect_true(grepl("--weight-semibold:\\s*600;", css_text, perl = TRUE))
    testthat::expect_true(grepl("--leading-tight:\\s*1\\.25;", css_text, perl = TRUE))
    testthat::expect_true(grepl("--leading-normal:\\s*1\\.6;", css_text, perl = TRUE))
    testthat::expect_true(grepl("--leading-relaxed:\\s*1\\.75;", css_text, perl = TRUE))
    testthat::expect_true(grepl("(?s)body,\\s*p,\\s*\\.body-text\\s*\\{[^}]*font-optical-sizing:\\s*auto;", css_text, perl = TRUE))
    testthat::expect_true(grepl("(?s)h1,\\s*h2,\\s*h3,\\s*h4,\\s*h5,\\s*h6\\s*\\{[^}]*font-optical-sizing:\\s*auto;", css_text, perl = TRUE))
    testthat::expect_true(grepl("(?s)h1\\s*\\{[^}]*font-size:\\s*2rem;", css_text, perl = TRUE))
    testthat::expect_true(grepl("(?s)h2\\s*\\{[^}]*font-size:\\s*1\\.6rem;", css_text, perl = TRUE))
    testthat::expect_true(grepl("(?s)h3\\s*\\{[^}]*font-size:\\s*1\\.3rem;", css_text, perl = TRUE))
    testthat::expect_true(grepl("(?s)h4\\s*\\{[^}]*font-size:\\s*1\\.15rem;", css_text, perl = TRUE))
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
            grepl("width:\\s*clamp\\(340px,\\s*22vw,\\s*420px\\);", css_text, perl = TRUE),
        info = "Config panel must keep responsive clamp width (340px, 22vw, 420px)"
    )

    testthat::expect_true(
        grepl("\\.vn-report-panel\\s*\\{", css_text, perl = TRUE) &&
            grepl("width:\\s*clamp\\(520px,\\s*31vw,\\s*640px\\);", css_text, perl = TRUE),
        info = "Report panel must keep responsive clamp width (520px, 31vw, 640px)"
    )

    testthat::expect_true(
        grepl("\\.validate-names-page\\s*\\{", css_text, perl = TRUE) &&
            grepl("max-width:\\s*none;", css_text, perl = TRUE),
        info = "Validate-names page should use full-width shell"
    )

    testthat::expect_true(
        grepl("\\.tab-content\\s*>\\s*\\.tab-pane:has\\(\\.validate-names-page\\)\\s*\\{", css_text, perl = TRUE) &&
            grepl("padding-left:\\s*0;", css_text, perl = TRUE) &&
            grepl("padding-right:\\s*0;", css_text, perl = TRUE),
        info = "Validate-names tab pane must remove lateral padding for full-width layout"
    )
})

testthat::test_that("custom.css includes review modal tokens and reduced-motion guardrail", {
    css_path <- resolve_css_path()
    css_text <- paste(readLines(css_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

    required_selectors <- c(
        "\\.vn-review-modal",
        "\\.vn-review-trigger\\.btn",
        "\\.vn-review-confirm-block",
        "\\.vn-review-empty-state",
        "\\.vn-review-item-exit"
    )

    for (selector in required_selectors) {
        testthat::expect_true(
            grepl(selector, css_text, perl = TRUE),
            info = paste("Missing review selector:", selector)
        )
    }

    token_checks <- c(
        "var\\(--space-",
        "var\\(--radius-",
        "var\\(--shadow-",
        "var\\(--error-",
        "var\\(--warning-",
        "var\\(--info-",
        "var\\(--success-",
        "var\\(--overlay\\)"
    )

    for (token_pattern in token_checks) {
        testthat::expect_true(
            grepl(token_pattern, css_text, perl = TRUE),
            info = paste("Expected token usage missing for pattern:", token_pattern)
        )
    }

    testthat::expect_true(
        grepl("@media\\s*\\(prefers-reduced-motion:\\s*reduce\\)", css_text, perl = TRUE),
        info = "Missing prefers-reduced-motion media query"
    )
    testthat::expect_true(
        grepl("(?s)@media\\s*\\(prefers-reduced-motion:\\s*reduce\\)\\s*\\{[^}]*\\.vn-review-item-exit\\s*\\{[^}]*animation:\\s*none;", css_text, perl = TRUE),
        info = "Review exit animation is not disabled under prefers-reduced-motion"
    )
})

# --- Onda 5 / Item 5.1: Modular CSS bundle guardrails ---

resolve_css_dir <- function() {
    installed_dir <- system.file("app", "www", "css", package = "saira")
    if (nzchar(installed_dir) && dir.exists(installed_dir)) {
        return(installed_dir)
    }
    file.path(pkg_root, "inst", "app", "www", "css")
}

testthat::test_that("custom.css starts with GENERATED FILE header", {
    css_path <- resolve_css_path()
    first_line <- readLines(css_path, n = 1L, warn = FALSE, encoding = "UTF-8")
    testthat::expect_true(
        grepl("GENERATED FILE", first_line, fixed = TRUE),
        info = "custom.css should start with GENERATED FILE header (run data-raw/build_css.R)"
    )
})

testthat::test_that("all CSS modules in css/ are included in the bundle", {
    css_dir <- resolve_css_dir()
    testthat::skip_if_not(dir.exists(css_dir), "CSS modules directory not found")

    module_files <- sort(list.files(css_dir, pattern = "\\.css$"))
    testthat::expect_true(
        length(module_files) > 0L,
        info = "No CSS module files found in css/ directory"
    )

    css_path <- resolve_css_path()
    bundle_text <- paste(readLines(css_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

    for (mod_file in module_files) {
        mod_path <- file.path(css_dir, mod_file)
        mod_lines <- readLines(mod_path, warn = FALSE, encoding = "UTF-8")
        # Check that at least the first non-empty line of each module appears in the bundle
        first_content <- trimws(mod_lines[nzchar(trimws(mod_lines))][[1]])
        testthat::expect_true(
            grepl(first_content, bundle_text, fixed = TRUE),
            info = paste("CSS module not found in bundle:", mod_file)
        )
    }
})

