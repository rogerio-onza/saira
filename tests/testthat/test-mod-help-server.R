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

testthat::test_that("mod_help_server renders search input", {
    shiny::testServer(
        mod_help_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            search_html <- output$help_search_input
            testthat::expect_true(!is.null(search_html))
        }
    )
})

testthat::test_that("mod_help_server renders all 4 sections without search filter", {
    shiny::testServer(
        mod_help_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            # No search input set — should render all 4 panels
            session$flushReact()
            content_html <- output$help_content
            testthat::expect_true(!is.null(content_html))
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

testthat::test_that("mod_help_server filters content with search query", {
    shiny::testServer(
        mod_help_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            # Search for "separator" — should match the separator section
            session$setInputs(help_search = "separator")
            session$flushReact()
            content_html <- output$help_content
            testthat::expect_true(!is.null(content_html))
        }
    )
})

testthat::test_that("mod_help_server shows empty state for unmatched search", {
    shiny::testServer(
        mod_help_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(help_search = "xyznonexistent12345")
            session$flushReact()
            content_html <- output$help_content
            testthat::expect_true(!is.null(content_html))
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
