# Title: Tests for Preview Module Server
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-15
# Version: 2.0

testthat::test_that("mod_preview_server returns the preview transform and has no download control", {
    df <- data.frame(
        scientificName = sprintf("name_%03d", seq_len(120)),
        license = rep("https://creativecommons.org/publicdomain/zero/1.0/legalcode", 120),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_preview_server,
        args = list(
            mapped_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            returned <- session$getReturned()
            testthat::expect_true(shiny::is.reactive(returned))

            preview_df <- returned()
            testthat::expect_equal(nrow(preview_df), 100L)
            testthat::expect_true(all(preview_df$license == "CC0"))

            session$flushReact()

            # Preview is now read-only: it renders the table shell and no
            # download control (that moved to the Export tab, ADR-103).
            table_html <- paste(output$table_or_message$html, collapse = " ")
            testthat::expect_true(grepl("preview-table-shell", table_html, fixed = TRUE))
            testthat::expect_false(grepl("download", table_html, ignore.case = TRUE))
        }
    )
})

testthat::test_that("mod_preview_server renders enhanced empty state when no mapped data exists", {
    shiny::testServer(
        mod_preview_server,
        args = list(
            mapped_data_r = shiny::reactive(NULL),
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            empty_ui <- output$table_or_message
            html <- paste(empty_ui$html, collapse = " ")

            testthat::expect_true(grepl("preview-empty-state", html, fixed = TRUE))
            testthat::expect_true(grepl("No mapped data", html, fixed = TRUE))
        }
    )
})
