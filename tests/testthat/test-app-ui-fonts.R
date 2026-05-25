# Title: Tests for app_ui typography wiring
# Author: Codex
# Date: 2026-02-24

testthat::test_that("app_ui references local vendored fonts and cache-busted custom.css", {
    body_text <- paste(deparse(body(app_ui)), collapse = "\n")

    testthat::expect_true(
        grepl("www/vendor/fonts/source-fonts\\.css", body_text, perl = TRUE),
        info = "Missing local Source Serif 4 / Space Mono CSS link in app_ui output"
    )
    testthat::expect_true(
        grepl("www/vendor/fontawesome/css/all\\.min\\.css", body_text, perl = TRUE),
        info = "Missing local FontAwesome CSS link in app_ui output"
    )
    testthat::expect_false(
        grepl("fonts\\.googleapis\\.com|cdnjs\\.cloudflare\\.com|unpkg\\.com", body_text, perl = TRUE),
        info = "app_ui should not reference any CDN (offline-first per ADR-100)"
    )
    testthat::expect_true(
        grepl("www/custom\\.css\\?v=", body_text, perl = TRUE),
        info = "Missing cache-busted custom.css link in app_ui output"
    )
})

testthat::test_that("app_ui theme no longer references IBM Plex in bs_theme fonts", {
    body_text <- paste(deparse(body(app_ui)), collapse = "\n")

    testthat::expect_true(
        grepl("base_font\\s*=\\s*bslib::font_collection\\(\"Source Serif 4\"", body_text, perl = TRUE),
        info = "base_font should use Source Serif 4 font_collection"
    )
    testthat::expect_true(
        grepl("heading_font\\s*=\\s*bslib::font_collection\\(\"Source Serif 4\"", body_text, perl = TRUE),
        info = "heading_font should use Source Serif 4 font_collection"
    )
    testthat::expect_true(
        grepl("code_font\\s*=\\s*bslib::font_collection\\(\"Space Mono\"", body_text, perl = TRUE),
        info = "code_font should use Space Mono font_collection"
    )
    testthat::expect_false(
        grepl("font_google\\(\"IBM Plex", body_text, perl = TRUE),
        info = "app_ui should not reference IBM Plex via font_google in bs_theme"
    )
})
