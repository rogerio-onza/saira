# Title: Tests for the theme switch (ADR-144)
# Author: Rogerio Nunes Oliveira
# Date: 2026-10-05

testthat::test_that("theme switch has the three modes, with a label per language", {
    html <- as.character(theme_switch_ui())

    for (mode in c("light", "dark", "system")) {
        testthat::expect_match(html, sprintf('data-theme="%s"', mode), fixed = TRUE)
    }
    # theme-switch.js swaps aria-label from these when the language changes.
    for (lang in get_languages()) {
        attr <- paste0("data-label-", lang, "=")
        testthat::expect_equal(lengths(regmatches(html, gregexpr(attr, html, fixed = TRUE))), 4L)
    }
})

testthat::test_that("app_ui paints the stored theme before the stylesheets load", {
    head_html <- as.character(htmltools::renderTags(app_ui())$head)
    boot <- regexpr("saira-theme", head_html, fixed = TRUE)
    css <- regexpr("www/custom.css", head_html, fixed = TRUE)

    testthat::expect_gt(boot, 0)
    testthat::expect_lt(boot, css)
    testthat::expect_match(head_html, "www/theme-switch.js?v=", fixed = TRUE)
})
