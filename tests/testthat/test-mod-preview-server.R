# Title: Tests for Preview Module Server
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-15
# Version: 1.0

testthat::test_that("mod_preview_server returns preview, checklist chips and single download icon", {
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

            readiness_ui <- output$readiness_checklist
            readiness_html <- paste(readiness_ui$html, collapse = " ")
            testthat::expect_true(grepl("preview-readiness-card-ok", readiness_html, fixed = TRUE))
            testthat::expect_true(grepl("preview-readiness-card-missing", readiness_html, fixed = TRUE))
            testthat::expect_true(grepl("preview-readiness-state-ok", readiness_html, fixed = TRUE))
            testthat::expect_true(grepl("preview-readiness-state-missing", readiness_html, fixed = TRUE))
            testthat::expect_false(grepl("preview-readiness-chip", readiness_html, fixed = TRUE))

            download_ui <- output$download_btn_container
            download_html <- paste(download_ui$html, collapse = " ")
            icon_hits <- gregexpr("fa-download", download_html, fixed = TRUE)[[1]]
            icon_count <- if (length(icon_hits) == 0L || icon_hits[1] < 0L) 0L else length(icon_hits)
            testthat::expect_equal(icon_count, 1L)
            testthat::expect_true(grepl("download_trigger", download_html, fixed = TRUE))
            testthat::expect_true(grepl("download_real", download_html, fixed = TRUE))
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
            readiness_ui <- output$readiness_checklist

            testthat::expect_true(grepl("preview-empty-state", html, fixed = TRUE))
            testthat::expect_true(grepl("No mapped data", html, fixed = TRUE))
            testthat::expect_null(readiness_ui)
        }
    )
})

testthat::test_that("mod_preview_server supports a dedicated full-data download source", {
    preview_df <- data.frame(
        scientificName = sprintf("preview_%03d", seq_len(20)),
        stringsAsFactors = FALSE
    )
    full_df <- data.frame(
        scientificName = sprintf("full_%03d", seq_len(140)),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_preview_server,
        args = list(
            mapped_data_r = shiny::reactive(preview_df),
            lang_r = shiny::reactive("en"),
            download_data_r = shiny::reactive(full_df)
        ),
        {
            returned <- session$getReturned()
            testthat::expect_true(shiny::is.reactive(returned))
            testthat::expect_equal(nrow(returned()), 20L)

            download_source_r <- attr(returned, "download_data")
            testthat::expect_true(shiny::is.reactive(download_source_r))
            testthat::expect_equal(nrow(download_source_r()), 140L)
        }
    )
})
