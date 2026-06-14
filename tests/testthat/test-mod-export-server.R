# Title: Tests for Export Module Server (summary + relocated download flow)
# Author: Rogerio Nunes Oliveira

complete_df <- function(n = 5) {
    data.frame(
        scientificName = sprintf("Genus species_%02d", seq_len(n)),
        eventDate = rep("2024-01-01", n),
        decimalLatitude = rep("-23.5", n),
        decimalLongitude = rep("-46.6", n),
        basisOfRecord = rep("HumanObservation", n),
        stringsAsFactors = FALSE
    )
}

testthat::test_that("mod_export_server enables the .ZIP download once required terms are present", {
    shiny::testServer(
        mod_export_server,
        args = list(
            mapped_data_r = shiny::reactive(complete_df()),
            lang_r = shiny::reactive("pt")
        ),
        {
            session$flushReact()
            ui <- output$download_btn_container
            html <- paste(ui$html, collapse = " ")

            testthat::expect_true(grepl("download_trigger", html, fixed = TRUE))
            testthat::expect_true(grepl("download_real", html, fixed = TRUE))
            testthat::expect_true(grepl("fa-file-zipper", html, fixed = TRUE))
            # Ready -> active green button, not inert/disabled.
            testthat::expect_true(grepl("btn-success", html, fixed = TRUE))
            testthat::expect_false(grepl("is-inert", html, fixed = TRUE))
        }
    )
})

testthat::test_that("mod_export_server blocks the download and offers a fix CTA in the banner", {
    incomplete <- data.frame(
        scientificName = c("Aus bus", "Cus dus"),
        stringsAsFactors = FALSE
    )
    shiny::testServer(
        mod_export_server,
        args = list(
            mapped_data_r = shiny::reactive(incomplete),
            lang_r = shiny::reactive("pt")
        ),
        {
            session$flushReact()
            btn_html <- paste(output$download_btn_container$html, collapse = " ")
            # Button is inert (grey, not green) and disabled.
            testthat::expect_true(grepl("disabled", btn_html, fixed = TRUE))
            testthat::expect_true(grepl("is-inert", btn_html, fixed = TRUE))
            testthat::expect_false(grepl("btn-success", btn_html, fixed = TRUE))

            # The actionable CTA lives in the red banner instead.
            summary_html <- paste(output$summary$html, collapse = " ")
            testthat::expect_true(grepl("export-banner--danger", summary_html, fixed = TRUE))
            testthat::expect_true(grepl("go_fix_terms", summary_html, fixed = TRUE))
        }
    )
})

testthat::test_that("mod_export_server renders the readiness summary and an empty state without data", {
    shiny::testServer(
        mod_export_server,
        args = list(
            mapped_data_r = shiny::reactive(complete_df()),
            lang_r = shiny::reactive("pt")
        ),
        {
            session$flushReact()
            html <- paste(output$summary$html, collapse = " ")
            testthat::expect_true(grepl("export-summary", html, fixed = TRUE))
            testthat::expect_true(grepl("export-readiness-counts", html, fixed = TRUE))
            testthat::expect_true(grepl("export-term-chip", html, fixed = TRUE))
        }
    )

    shiny::testServer(
        mod_export_server,
        args = list(
            mapped_data_r = shiny::reactive(data.frame()),
            lang_r = shiny::reactive("pt")
        ),
        {
            session$flushReact()
            html <- paste(output$summary$html, collapse = " ")
            testthat::expect_true(grepl("export-empty", html, fixed = TRUE))
        }
    )
})
