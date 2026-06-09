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

            testthat::expect_true(grepl("preview-empty-state", html, fixed = TRUE))
            testthat::expect_true(grepl("No mapped data", html, fixed = TRUE))
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

testthat::test_that("mod_preview_server accepts name review payload reactive without breaking contracts", {
    preview_df <- data.frame(
        scientificName = c("Puma concolor", "Abies alba"),
        stringsAsFactors = FALSE
    )
    payload_r <- shiny::reactive({
        list(
            entries = data.frame(
                query_name = "Puma concolor",
                review_type = "confirm",
                original_name = "Puma concolor",
                corrected_name = "Puma concolor",
                reason = "Confirmado pelo usuário",
                reviewed_at = as.POSIXct("2026-02-27 10:00:00", tz = "UTC"),
                stringsAsFactors = FALSE
            ),
            normalize_opts = list(remove_authors = TRUE, ignore_qualifiers = TRUE)
        )
    })

    shiny::testServer(
        mod_preview_server,
        args = list(
            mapped_data_r = shiny::reactive(preview_df),
            lang_r = shiny::reactive("en"),
            download_data_r = shiny::reactive(preview_df),
            name_review_payload_r = payload_r
        ),
        {
            returned <- session$getReturned()
            testthat::expect_true(shiny::is.reactive(returned))
            testthat::expect_equal(nrow(returned()), 2L)

            download_source_r <- attr(returned, "download_data")
            testthat::expect_true(shiny::is.reactive(download_source_r))
            testthat::expect_equal(nrow(download_source_r()), 2L)
        }
    )
})

testthat::test_that("coordinate masking defaults to not_sensitive (deliberate opt-in)", {
    shiny::testServer(
        mod_preview_server,
        args = list(
            mapped_data_r = shiny::reactive(NULL),
            lang_r = shiny::reactive("en")
        ),
        {
            testthat::expect_identical(
                sensitive_generalization_rv(), "not_sensitive"
            )
        }
    )
})

testthat::test_that("two-step masking reduces mode + level to the export value", {
    shiny::testServer(
        mod_preview_server,
        args = list(
            mapped_data_r = shiny::reactive(NULL),
            lang_r = shiny::reactive("en")
        ),
        {
            # Entering "generalize" with the default level pre-selected.
            session$setInputs(sensitive_mode = "generalize",
                              sensitive_level = "medium")
            testthat::expect_identical(sensitive_generalization_rv(), "medium")

            # Picking a more aggressive level flows through.
            session$setInputs(sensitive_level = "high")
            testthat::expect_identical(sensitive_generalization_rv(), "high")

            # Switching back to "publish" returns to the no-op default; the
            # stale level value is ignored.
            session$setInputs(sensitive_mode = "publish")
            testthat::expect_identical(sensitive_generalization_rv(), "not_sensitive")
        }
    )
})
