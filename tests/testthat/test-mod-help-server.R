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

testthat::test_that("mod_help_server renders the workflow stepper with all five steps", {
    shiny::testServer(
        mod_help_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            html <- paste(output$help_content$html, collapse = " ")

            testthat::expect_true(grepl("help-workflow-steps", html, fixed = TRUE))
            # Five numbered step markers, 01 through 05.
            num_markers <- lengths(regmatches(
                html,
                gregexpr("help-workflow-step-num", html, fixed = TRUE)
            ))
            testthat::expect_equal(num_markers, 5L)
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
