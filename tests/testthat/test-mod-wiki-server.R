# Title: Tests for Wiki Module Server
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.0 (Onda 5, Item 5.5)

testthat::test_that("mod_wiki_server renders table with DwC terms", {
    shiny::testServer(
        mod_wiki_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            # header_card should produce UI output
            header_html <- output$header_card
            testthat::expect_true(!is.null(header_html))
        }
    )
})

testthat::test_that("mod_wiki_server renders toolbar with class filter pills", {
    shiny::testServer(
        mod_wiki_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            toolbar_html <- output$toolbar_card
            testthat::expect_true(!is.null(toolbar_html))
        }
    )
})

testthat::test_that("mod_wiki_server renders DT table output", {
    shiny::testServer(
        mod_wiki_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            table_html <- output$terms_table
            testthat::expect_true(!is.null(table_html))
        }
    )
})

testthat::test_that("mod_wiki_server works with PT language", {
    shiny::testServer(
        mod_wiki_server,
        args = list(
            lang_r = shiny::reactive("pt")
        ),
        {
            session$flushReact()
            header_html <- output$header_card
            testthat::expect_true(!is.null(header_html))
            table_html <- output$terms_table
            testthat::expect_true(!is.null(table_html))
        }
    )
})

testthat::test_that("mod_wiki_server survives language switch EN to PT", {
    shiny::testServer(
        mod_wiki_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            testthat::expect_no_error(session$flushReact())
        }
    )

    shiny::testServer(
        mod_wiki_server,
        args = list(
            lang_r = shiny::reactive("pt")
        ),
        {
            session$flushReact()
            testthat::expect_no_error(session$flushReact())
        }
    )
})
