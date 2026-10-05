# Title: Tests for Export Module Server (summary + relocated download flow)
# Author: Rogerio Nunes Oliveira

complete_df <- function(n = 5) {
    data.frame(
        scientificName = sprintf("Genus species_%02d", seq_len(n)),
        eventDate = rep("2024-01-01", n),
        decimalLatitude = rep("-23.5", n),
        decimalLongitude = rep("-46.6", n),
        basisOfRecord = rep("HumanObservation", n),
        license = rep("CC-BY 4.0", n),
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
            testthat::expect_true(grepl("ph-file-zip", html, fixed = TRUE))
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
            testthat::expect_true(grepl("export-sev--block", summary_html, fixed = TRUE))
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
            testthat::expect_true(grepl("export-kpi", html, fixed = TRUE))
            testthat::expect_true(grepl("export-pending", html, fixed = TRUE))
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

# ADR-141: the package card shows what the last export taught Rostrum, and its
# undo reverses that export only.
testthat::test_that("mod_export_server shows the alias receipt and undoes that export", {
    withr::local_envvar(c(SAIRA_DATA_DIR = withr::local_tempdir(), SAIRA_USER = "test_export_undo"))
    conn <- rostrum_connect()
    on.exit(try(DBI::dbDisconnect(conn), silent = TRUE), add = TRUE)
    rostrum_commit_session_aliases(conn, list(fieldNotes = "Notes"), run_id = "run-1")
    committed <- rostrum_commit_session_aliases(conn, list(occurrenceRemarks = "Notes"), run_id = "run-2")
    receipt <- alias_export_receipt(committed, "run-2")

    shiny::testServer(
        mod_export_server,
        args = list(
            mapped_data_r = shiny::reactive(complete_df()),
            lang_r = shiny::reactive("pt"),
            alias_receipt_r = shiny::reactive(receipt)
        ),
        {
            session$flushReact()
            html <- paste(output$alias_memory$html, collapse = " ")
            testthat::expect_true(grepl("undo_alias_export", html, fixed = TRUE))
            testthat::expect_true(grepl("occurrenceRemarks", html, fixed = TRUE))

            session$setInputs(undo_alias_export = 1)
            html <- paste(output$alias_memory$html, collapse = " ")
            testthat::expect_false(grepl("undo_alias_export", html, fixed = TRUE))
            testthat::expect_true(grepl(tr("export_memory_undone", "pt"), html, fixed = TRUE))
        }
    )

    live <- DBI::dbGetQuery(
        conn, "SELECT dwc_term FROM rostrum_aliases WHERE col_name_norm = 'notes' AND deprecated = 0"
    )$dwc_term
    testthat::expect_identical(live, "fieldNotes")
})

testthat::test_that("mod_export_server shows no alias receipt before an export", {
    shiny::testServer(
        mod_export_server,
        args = list(
            mapped_data_r = shiny::reactive(complete_df()),
            lang_r = shiny::reactive("pt"),
            alias_receipt_r = shiny::reactive(NULL)
        ),
        {
            session$flushReact()
            testthat::expect_null(output$alias_memory)
        }
    )
})
