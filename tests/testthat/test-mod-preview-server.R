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

testthat::test_that("mod_preview_server corrections reach the edited data and reset with the upload", {
    df <- data.frame(
        occurrenceID = c("a1", "a2", "a3"),
        scientificName = c("Puma concolor", "Nasua nasua", "Tapirus terrestris"),
        eventDate = c("2020-05-01", "2020-05-02", "2020-05-03"),
        individualCount = c("2", "cerca de 10", "cerca de 10"),
        lifeStage = c("adult", "filhote", "filhote"),
        stringsAsFactors = FALSE
    )
    reset_rv <- shiny::reactiveVal(0L)

    shiny::testServer(
        mod_preview_server,
        args = list(
            mapped_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en"),
            reset_signal_r = shiny::reactive(reset_rv())
        ),
        {
            edited_r <- attr(session$getReturned(), "edited_data_r")
            testthat::expect_true(shiny::is.reactive(edited_r))
            testthat::expect_identical(edited_r(), df)

            session$setInputs(mode = "problems")
            p <- problems_r()
            count_id <- which(p$term == "individualCount")[1]
            vocab_id <- which(p$term == "lifeStage")[1]

            # "Use" with "same value" on fixes both count cells at once.
            session$setInputs(use = count_id)
            testthat::expect_equal(edited_r()$individualCount, c("2", "10", "10"))

            # The user picks the reading of an ambiguous vocabulary value.
            session$setInputs(vocab_apply = list(id = vocab_id, to = "nestling"))
            testthat::expect_equal(edited_r()$lifeStage, c("adult", "nestling", "nestling"))

            session$setInputs(vocab_apply = list(id = vocab_id, to = "macho"))
            testthat::expect_equal(edited_r()$lifeStage, c("adult", "nestling", "nestling"))

            session$setInputs(undo = count_id)
            testthat::expect_equal(edited_r()$individualCount, df$individualCount)

            reset_rv(1L)
            session$flushReact()
            testthat::expect_identical(edited_r(), df)
        }
    )
})

testthat::test_that("mod_preview_server fixes a differing year per row and replaces repeated ids", {
    df <- data.frame(
        occurrenceID = c("a1", "a1", "a3", "a4"),
        scientificName = "Puma concolor",
        eventDate = c("2022-05-01", "2022-06-01", "2019-05-03", "2021-05-04"),
        year = c("2019", "2019", "2019", "2019"),
        individualCount = c("2", "muitos", "muitos", "3"),
        stringsAsFactors = FALSE
    )
    shiny::testServer(
        mod_preview_server,
        args = list(mapped_data_r = shiny::reactive(df), lang_r = shiny::reactive("en")),
        {
            edited_r <- attr(session$getReturned(), "edited_data_r")
            ids <- edited_r()$occurrenceID
            testthat::expect_true(all(startsWith(ids[1:2], "urn:uuid:")))
            testthat::expect_identical(ids[3:4], c("a3", "a4"))

            session$setInputs(mode = "problems")
            p <- problems_r()
            # Row 3 has the right year. "Use" on row 1 also fixes row 2, the
            # other row with 2019 for 2022, and leaves row 4 (2021) open.
            session$setInputs(use = which(p$term == "year" & p$row == 1L))
            testthat::expect_equal(edited_r()$year, c("2022", "2022", "2019", "2019"))

            # "Leave empty" on an optional term, for both rows with the value.
            session$setInputs(blank = which(p$term == "individualCount" & p$row == 2L))
            testthat::expect_equal(edited_r()$individualCount, c("2", NA, NA, "3"))

            # A repeated id left as it is shows the id the export writes.
            dup <- which(p$type == "id_duplicate")
            testthat::expect_identical(build_rows_df(dup)$auto, edited_r()$occurrenceID[1:2])

            # A typed id that makes the other row unique gives that row its id back.
            id_pos <- match(which(p$term == "occurrenceID" & p$row == 2L), rows_base_r())
            session$setInputs(rows_table_cell_edit = list(row = id_pos, col = 4L, value = "a2"))
            testthat::expect_identical(edited_r()$occurrenceID, c("a1", "a2", "a3", "a4"))
        }
    )
})

testthat::test_that("mod_preview_server record panel shows taxon clues for a scientificName row", {
    df <- data.frame(
        occurrenceID = c("a1", "a2"),
        scientificName = c("Puma concolor", ""),
        vernacularName = c("onca-parda", "gato-do-mato"),
        family = c("Felidae", "Felidae"),
        eventDate = c("2020-05-01", "2020-05-02"),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_preview_server,
        args = list(
            mapped_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en"),
            raw_data_r = shiny::reactive(df)
        ),
        {
            session$setInputs(mode = "problems")
            session$setInputs(focus = list(row = 2L, term = "scientificName"))
            html <- output$record_panel$html
            testthat::expect_match(html, "most specific taxon", fixed = TRUE)
            testthat::expect_match(html, "gato-do-mato", fixed = TRUE)

            # Other terms show the record only.
            session$setInputs(focus = list(row = 2L, term = "eventDate"))
            testthat::expect_no_match(output$record_panel$html, "most specific taxon", fixed = TRUE)
        }
    )
})

testthat::test_that("mod_preview_server opens Problems on entry only while a problem is open", {
    df <- data.frame(
        occurrenceID = c("a1", "a2"),
        scientificName = c("Puma concolor", "Nasua nasua"),
        individualCount = c("2", "cerca de 10"),
        stringsAsFactors = FALSE
    )
    active_rv <- shiny::reactiveVal(FALSE)

    shiny::testServer(
        mod_preview_server,
        args = list(
            mapped_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en"),
            active_r = shiny::reactive(active_rv())
        ),
        {
            active_rv(TRUE)
            session$flushReact()
            testthat::expect_identical(entry_mode_rv(), "problems")

            session$setInputs(mode = "problems")
            session$setInputs(use = which(problems_r()$term == "individualCount")[1])
            active_rv(FALSE)
            session$flushReact()
            active_rv(TRUE)
            session$flushReact()
            testthat::expect_identical(entry_mode_rv(), "table")
        }
    )
})

testthat::test_that("mod_preview_server counts open problems on refresh and after a fix", {
    df <- data.frame(
        occurrenceID = c("a1", "a2"),
        scientificName = c("Puma concolor", "Nasua nasua"),
        individualCount = c("2", "cerca de 10"),
        stringsAsFactors = FALSE
    )
    data_rv <- shiny::reactiveVal(NULL)
    refresh_rv <- shiny::reactiveVal(0L)

    shiny::testServer(
        mod_preview_server,
        args = list(
            mapped_data_r = shiny::reactive(data_rv()),
            lang_r = shiny::reactive("en"),
            refresh_r = shiny::reactive(refresh_rv())
        ),
        {
            n_r <- attr(session$getReturned(), "problems_n_r")
            testthat::expect_identical(n_r(), NA_integer_)

            # New data waits for the refresh signal.
            data_rv(df)
            session$flushReact()
            testthat::expect_identical(n_r(), NA_integer_)
            refresh_rv(1L)
            session$flushReact()
            testthat::expect_identical(n_r(), 1L)
            testthat::expect_match(output$problems_n$html, "seg-n is-act", fixed = TRUE)

            # A fix recounts at once.
            session$setInputs(mode = "problems")
            session$setInputs(use = which(problems_r()$term == "individualCount")[1])
            testthat::expect_identical(n_r(), 0L)
        }
    )
})

testthat::test_that("preview_nav_badge shows a count, a check or nothing", {
    testthat::expect_null(preview_nav_badge(NA_integer_, "en"))
    clear <- as.character(preview_nav_badge(0L, "en"))
    testthat::expect_match(clear, "nav-count is-clear", fixed = TRUE)
    testthat::expect_match(clear, "No problems to fix", fixed = TRUE)
    count <- as.character(preview_nav_badge(22L, "pt"))
    testthat::expect_match(count, ">22</span>", fixed = TRUE)
    testthat::expect_match(count, "22 problemas para corrigir", fixed = TRUE)
})
