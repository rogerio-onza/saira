# Title: Tests for Help Module Server
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 2.0 (ADR-146)

help_page_html <- function(lang) {
    html <- NULL
    shiny::testServer(
        mod_help_server,
        args = list(lang_r = shiny::reactive(lang)),
        {
            session$flushReact()
            html <<- paste(output$help_page$html, collapse = " ")
        }
    )
    html
}

testthat::test_that("the help page credits the author from DESCRIPTION, with a citation", {
    html <- help_page_html("en")
    meta <- credits_saira_meta()

    testthat::expect_match(html, meta$name, fixed = TRUE)
    testthat::expect_match(html, paste0("mailto:", meta$email), fixed = TRUE)
    testthat::expect_match(html, paste0("v", meta$version), fixed = TRUE)
    testthat::expect_match(html, "LICENSE.md", fixed = TRUE)
    # Both copy buttons carry their text for copy-button.js.
    testthat::expect_equal(lengths(regmatches(html, gregexpr("data-copy=", html, fixed = TRUE))), 2L)
    testthat::expect_match(html, "@Manual{saira", fixed = TRUE)
})

testthat::test_that("the help page links tutorials, FAQ, issues and methods", {
    html <- help_page_html("en")

    testthat::expect_match(html, "rogerio-onza.github.io/saira/en/tutorials/", fixed = TRUE)
    testthat::expect_match(html, "rogerio-onza.github.io/saira/en/faq.html", fixed = TRUE)
    testthat::expect_match(html, "rogerio-onza.github.io/saira/en/technologies.html", fixed = TRUE)
    testthat::expect_match(html, "github.com/rogerio-onza/saira/issues", fixed = TRUE)
    testthat::expect_equal(lengths(regmatches(html, gregexpr("help-faq-item", html, fixed = TRUE))), 4L)
    for (doi in c("10.1111/2041-210X.13868", "10.15468/doc-5jp4-5g10", "10.15468/doc-gg7h-s853", "10.35035/e09p-h128")) {
        testthat::expect_match(html, paste0("doi.org/", doi), fixed = TRUE)
    }
})

testthat::test_that("the help page links every package, with no AI tool chips", {
    html <- help_page_html("en")

    for (pkg in unlist(credits_package_groups())) {
        testthat::expect_match(html, credits_package_meta(pkg)$href, fixed = TRUE)
    }
    testthat::expect_match(html, "github.com/wevertonbio/faunabr", fixed = TRUE)
    testthat::expect_match(html, sprintf(tr("help_stack_body", "en"), length(unlist(credits_package_groups()))), fixed = TRUE)
    testthat::expect_false(grepl("Codex", html, fixed = TRUE))
    testthat::expect_false(grepl("Sonnet", html, fixed = TRUE))
})

testthat::test_that("the help page follows the language", {
    testthat::expect_match(help_page_html("pt"), tr("help_made_by", "pt"), fixed = TRUE)
    testthat::expect_match(help_page_html("es"), tr("help_made_by", "es"), fixed = TRUE)
    testthat::expect_match(help_page_html("es"), "/es/tutoriales/", fixed = TRUE)
})
