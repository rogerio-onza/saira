# Title: Tests for app_ui typography wiring
# Author: Codex
# Date: 2026-02-24

testthat::test_that("app_ui declares design-v5 Google Fonts and cache-busted custom.css", {
    body_text <- paste(deparse(body(app_ui)), collapse = "\n")

    testthat::expect_true(
        grepl("family=Cormorant\\+Garamond", body_text, perl = TRUE),
        info = "Missing Cormorant Garamond Google Fonts link in app_ui output"
    )
    testthat::expect_true(
        grepl("family=Space\\+Mono", body_text, perl = TRUE),
        info = "Missing Space Mono Google Fonts link in app_ui output"
    )
    testthat::expect_true(
        grepl("www/custom\\.css\\?v=", body_text, perl = TRUE),
        info = "Missing cache-busted custom.css link in app_ui output"
    )
})

testthat::test_that("app_ui theme no longer references IBM Plex in bs_theme fonts", {
    body_text <- paste(deparse(body(app_ui)), collapse = "\n")

    testthat::expect_true(
        grepl("base_font\\s*=\\s*bslib::font_collection\\(\"Cormorant Garamond\"", body_text, perl = TRUE),
        info = "base_font should use Cormorant Garamond font_collection"
    )
    testthat::expect_true(
        grepl("heading_font\\s*=\\s*bslib::font_collection\\(\"Cormorant Garamond\"", body_text, perl = TRUE),
        info = "heading_font should use Cormorant Garamond font_collection"
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
