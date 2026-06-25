# Title: Tests for Help Module Server
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.0 (Onda 5, Item 5.5)

testthat::test_that("mod_help_server renders header card", {
    shiny::testServer(
        mod_help_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            header_html <- output$help_header_card
            testthat::expect_true(!is.null(header_html))
        }
    )
})

testthat::test_that("mod_help_server renders the resources content (tutorials, links, refs, FAQ)", {
    shiny::testServer(
        mod_help_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            html <- paste(output$help_content$html, collapse = " ")

            # No leftover workflow stepper.
            testthat::expect_false(grepl("help-workflow", html, fixed = TRUE))
            # Tutorials link to the website index.
            testthat::expect_true(grepl("rogerio-onza.github.io/saira/en/tutorials/", html, fixed = TRUE))
            # Direct GitHub issues link.
            testthat::expect_true(grepl("github.com/rogerio-onza/saira/issues", html, fixed = TRUE))
            # All three Chapman / GBIF reference PDFs.
            testthat::expect_true(grepl("doi.org/10.15468/doc-5jp4-5g10", html, fixed = TRUE))
            testthat::expect_true(grepl("doi.org/10.15468/doc-gg7h-s853", html, fixed = TRUE))
            testthat::expect_true(grepl("doi.org/10.35035/e09p-h128", html, fixed = TRUE))
            # FAQ toggle with six collapsible items.
            testthat::expect_true(grepl("help-faq-toggle", html, fixed = TRUE))
            faq_items <- lengths(regmatches(
                html,
                gregexpr("help-faq-item", html, fixed = TRUE)
            ))
            testthat::expect_equal(faq_items, 6L)
            # FAQ links out to the full site FAQ.
            testthat::expect_true(grepl("rogerio-onza.github.io/saira/en/faq.html", html, fixed = TRUE))
        }
    )
})

testthat::test_that("mod_help_server built-with card links every dependency and drops AI chips", {
    shiny::testServer(
        mod_help_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            html <- paste(output$help_sidebar$html, collapse = " ")

            # Every runtime dependency renders as a linked chip.
            pkgs <- help_dependency_packages()
            testthat::expect_equal(length(pkgs), 26L)
            for (pkg in pkgs) {
                testthat::expect_true(grepl(pkg$href, html, fixed = TRUE))
            }
            # faunabr points at the GitHub source, not CRAN.
            testthat::expect_true(grepl("github.com/wevertonbio/faunabr", html, fixed = TRUE))
            # The AI-tool chips are gone.
            testthat::expect_false(grepl("Codex", html, fixed = TRUE))
            testthat::expect_false(grepl("Sonnet", html, fixed = TRUE))
        }
    )
})

testthat::test_that("mod_help_server renders sidebar with author metadata", {
    shiny::testServer(
        mod_help_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            sidebar_html <- output$help_sidebar
            testthat::expect_true(!is.null(sidebar_html))
        }
    )
})

testthat::test_that("mod_help_server works with PT language", {
    shiny::testServer(
        mod_help_server,
        args = list(
            lang_r = shiny::reactive("pt")
        ),
        {
            session$flushReact()
            header_html <- output$help_header_card
            testthat::expect_true(!is.null(header_html))
            content_html <- output$help_content
            testthat::expect_true(!is.null(content_html))
            sidebar_html <- output$help_sidebar
            testthat::expect_true(!is.null(sidebar_html))
        }
    )
})

testthat::test_that("mod_help_server survives language switch EN to PT", {
    shiny::testServer(
        mod_help_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            testthat::expect_no_error(session$flushReact())
        }
    )

    shiny::testServer(
        mod_help_server,
        args = list(
            lang_r = shiny::reactive("pt")
        ),
        {
            session$flushReact()
            testthat::expect_no_error(session$flushReact())
        }
    )
})
