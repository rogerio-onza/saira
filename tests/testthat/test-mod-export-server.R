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

testthat::test_that("simultaneous export warnings have unique working navigation buttons", {
    df <- complete_df(3)
    df$scientificName[1] <- ""
    df$decimalLatitude[1] <- "100"
    df$eventDate <- c("3020-01-01", "unreadable", "2024-01-01")
    df$recordedBy <- c("=1+1", "", "")
    navigations <- character(0)
    shiny::testServer(mod_export_server, args = list(
        mapped_data_r = shiny::reactive(df), lang_r = shiny::reactive("en"),
        preview_problems_n_r = shiny::reactive(3L),
        coords_correction_payload_r = shiny::reactive(list(stale = 1L)),
        coord_validation_r = shiny::reactive(data.frame(.row_index = 2L, diagnostic_family = "sea")),
        on_navigate = function(tab, term = NULL) navigations <<- c(navigations, tab)
    ), {
        session$flushReact()
        html <- xml2::read_html(paste(output$summary$html, collapse = " "))
        ids <- xml2::xml_attr(xml2::xml_find_all(html, "//*[@id]"), "id")
        testthat::expect_identical(anyDuplicated(ids), 0L)
        buttons <- xml2::xml_attr(xml2::xml_find_all(html, "//button[contains(@id, 'go_preview_')]"), "id")
        testthat::expect_length(buttons, 6L)
        for (id in buttons) {
            # testServer inputs use local IDs. The HTML has the module prefix.
            local_id <- sub(paste0("^", session$ns("")), "", id)
            do.call(session$setInputs, stats::setNames(list(1L), local_id))
        }
        session$setInputs(go_coords_stale = 1L)
        session$setInputs(go_coords_flags = 1L)
    })
    testthat::expect_identical(navigations, c(rep("preview", 6L), rep("validate_coords", 2L)))
})

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
            testthat::expect_no_match(html, "<button(?=[^>]*download_trigger)[^>]*\\sdisabled[\\s>]", perl = TRUE)
        }
    )
})

testthat::test_that("mod_export_server tells the page when the data change after a bundle", {
    data_rv <- shiny::reactiveVal(complete_df())
    shiny::testServer(
        mod_export_server,
        args = list(
            mapped_data_r = shiny::reactive(data_rv()),
            lang_r = shiny::reactive("pt")
        ),
        {
            sent <- character(0)
            real_session <- base::.subset2(session, "parent")
            real_session$sendCustomMessage <- function(type, message) {
                if (identical(type, "saira-bundle-state")) sent[[length(sent) + 1L]] <<- message
                invisible(NULL)
            }
            session$flushReact()
            testthat::expect_length(sent, 0L)

            zip_path <- output$download_real
            testthat::expect_true("occurrence.txt" %in% zip::zip_list(zip_path)$filename)
            session$flushReact()
            testthat::expect_identical(sent, "current")

            data_rv(complete_df(6))
            session$flushReact()
            testthat::expect_identical(sent, c("current", "stale"))
            data_rv(complete_df(7))
            session$flushReact()
            testthat::expect_identical(sent, c("current", "stale"))

            zip_path <- output$download_real
            session$flushReact()
            testthat::expect_identical(sent, c("current", "stale", "current"))
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
            testthat::expect_match(btn_html, "<button(?=[^>]*download_trigger)[^>]*\\sdisabled[\\s>]", perl = TRUE)
            testthat::expect_true(grepl("is-inert", btn_html, fixed = TRUE))
            testthat::expect_false(grepl("btn-success", btn_html, fixed = TRUE))

            # The actionable CTA lives in the red banner instead.
            summary_html <- paste(output$summary$html, collapse = " ")
            testthat::expect_true(grepl("export-sev--block", summary_html, fixed = TRUE))
            testthat::expect_true(grepl("go_fix_terms", summary_html, fixed = TRUE))
        }
    )
})

testthat::test_that("mod_export_server refuses a direct download while the export is blocked", {
    incomplete <- data.frame(
        scientificName = c("Aus bus", "Cus dus"),
        stringsAsFactors = FALSE
    )
    learned <- FALSE
    shiny::testServer(
        mod_export_server,
        args = list(
            mapped_data_r = shiny::reactive(incomplete),
            download_data_r = shiny::reactive(incomplete),
            lang_r = shiny::reactive("pt"),
            on_export_success = function() learned <<- TRUE
        ),
        {
            session$flushReact()
            # The hidden link works without the disabled button.
            zip_path <- output$download_real
            testthat::expect_identical(zip::zip_list(zip_path)$filename, "export_error.csv")
        }
    )
    testthat::expect_false(learned)
})

testthat::test_that("mod_export_server blocks a blank name and a formula in an unmapped column (AUD-04, AUD-12)", {
    df <- complete_df(3)
    df$scientificName[2] <- ""
    raw <- data.frame(especie = df$scientificName, anotacao = c("ok", "ok", "=1+1"),
                      stringsAsFactors = FALSE)
    shiny::testServer(
        mod_export_server,
        args = list(
            mapped_data_r = shiny::reactive(df),
            download_data_r = shiny::reactive(df),
            raw_data_r = shiny::reactive(raw),
            map_values_r = shiny::reactive(list(scientificName = "especie")),
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            html <- paste(output$summary$html, collapse = " ")
            testthat::expect_match(html, "scientificName is empty in 1 record", fixed = TRUE)
            testthat::expect_match(html, "1 cell(s) in unmapped columns", fixed = TRUE)
            testthat::expect_match(html, "go_map_unmapped", fixed = TRUE)
            zip_path <- output$download_real
            testthat::expect_identical(zip::zip_list(zip_path)$filename, "export_error.csv")
        }
    )
})

testthat::test_that("mod_export_server counts the coordinate fixes that left the package (AUD-05)", {
    payload <- list(corrections = data.frame(occurrenceID = character(0), decimalLatitude = character(0),
                                             decimalLongitude = character(0)), stale = 2L)
    shiny::testServer(
        mod_export_server,
        args = list(
            mapped_data_r = shiny::reactive(complete_df()),
            coords_correction_payload_r = shiny::reactive(payload),
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            testthat::expect_identical(summary_r()$corrections$coord_fixes_stale, 2L)
            html <- paste(output$summary$html, collapse = " ")
            testthat::expect_match(html, "2 fix(es) from the Coordinates tab left the package", fixed = TRUE)
            testthat::expect_match(html, "go_coords", fixed = TRUE)
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

testthat::test_that("mod_export_server blocks the summary and the download when a decision fails (SP-01)", {
    learned <- FALSE
    shiny::testServer(
        mod_export_server,
        args = list(
            mapped_data_r = shiny::reactive(complete_df()),
            coords_correction_payload_r = shiny::reactive(stop("injected correction failure")),
            lang_r = shiny::reactive("en"),
            on_export_success = function() learned <<- TRUE
        ),
        {
            suppressWarnings(session$flushReact())
            s <- suppressWarnings(summary_r())
            testthat::expect_true(s$export_blocked)
            testthat::expect_identical(s$failed_sources, "coords_correction")
            html <- paste(suppressWarnings(output$summary$html), collapse = " ")
            testthat::expect_match(html, "could not be read: Coordinates", fixed = TRUE)
            zip_path <- suppressWarnings(output$download_real)
            testthat::expect_identical(zip::zip_list(zip_path)$filename, "export_error.csv")
        }
    )
    testthat::expect_false(learned)
})

testthat::test_that("every export source that fails blocks the summary and the download (SP-01)", {
    arg_of <- c(
        name_review = "name_review_payload_r", coords_correction = "coords_correction_payload_r",
        country_fill = "country_fill_payload_r", sensitivity = "sensitivity_payload_r",
        generalization = "sensitive_generalization_payload_r", conservation = "conservation_payload_r",
        raw_data = "raw_data_r", map_values = "map_values_r", custom_values = "custom_values_r",
        rows_left_out = "rows_left_out_r", preview_changes = "preview_changes_r",
        measurement_specs = "measurement_specs_r", occurrence_id_info = "occurrence_id_info_r"
    )
    for (source in names(arg_of)) {
        args <- list(mapped_data_r = shiny::reactive(complete_df()), lang_r = shiny::reactive("en"))
        args[[arg_of[[source]]]] <- shiny::reactive(stop("injected failure"))
        shiny::testServer(mod_export_server, args = args, {
            suppressWarnings(session$flushReact())
            s <- suppressWarnings(summary_r())
            testthat::expect_true(s$export_blocked, info = source)
            testthat::expect_identical(s$failed_sources, source, info = source)
            zip_path <- suppressWarnings(output$download_real)
            testthat::expect_identical(zip::zip_list(zip_path)$filename, "export_error.csv", info = source)
        })
    }
})
