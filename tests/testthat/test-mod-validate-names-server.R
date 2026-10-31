# Title: Tests for Validate Names Module Server
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-19
# Version: 2.3

testthat::test_that("upstream reset signal clears reviews but keeps providers", {
    mapped_df <- data.frame(scientificName = c("Puma concolor"), stringsAsFactors = FALSE)
    testthat::local_mocked_bindings(
        brprovider_data_available = function(provider_id) FALSE,
        .package = "saira"
    )
    signal <- shiny::reactiveVal(0L)

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en"),
            reset_signal_r = signal
        ),
        {
            # Seed decision state for a prior dataset.
            rv$manual_reviews <- data.frame(
                query_name = "Puma concolor",
                review_type = "confirm",
                original_name = "Puma concolor",
                corrected_name = NA_character_,
                reason = "ok",
                reviewed_at = Sys.time(),
                stringsAsFactors = FALSE
            )
            rv$sensitivity_overrides <- list("Puma concolor" = list(sensitive = TRUE, category = "EN"))
            validation_result(mapped_df)
            session$flushReact()
            testthat::expect_identical(nrow(rv$manual_reviews), 1L)

            # A re-upload or a confirmed Mapping reset wipes the decisions.
            signal(1L)
            session$flushReact()

            testthat::expect_identical(nrow(rv$manual_reviews), 0L)
            testthat::expect_length(rv$sensitivity_overrides, 0L)
            testthat::expect_null(validation_result())
            # Provider selection mirrors the on-disk cache, not dataset work: kept.
            testthat::expect_identical(rv$selected_providers, "gbif")
        }
    )
})

testthat::test_that("BR providers toggle and GBIF stays locked", {
    mapped_df <- data.frame(scientificName = c("Puma concolor"), stringsAsFactors = FALSE)
    # Pin the on-disk cache to "nothing downloaded" so the default is
    # deterministically GBIF-only regardless of the test machine's cache.
    testthat::local_mocked_bindings(
        brprovider_data_available = function(provider_id) FALSE,
        .package = "saira"
    )

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            testthat::expect_identical(rv$selected_providers, "gbif")

            toggle_provider_selection("florabr")
            testthat::expect_identical(rv$selected_providers, c("gbif", "florabr"))

            toggle_provider_selection("gbif")
            testthat::expect_identical(rv$selected_providers, c("gbif", "florabr"))

            toggle_provider_selection("florabr")
            testthat::expect_identical(rv$selected_providers, "gbif")
        }
    )
})

testthat::test_that("already-downloaded BR providers are pre-selected with GBIF on open", {
    mapped_df <- data.frame(scientificName = c("Puma concolor"), stringsAsFactors = FALSE)
    # Simulate Flora BR already downloaded to the on-disk cache, Fauna BR not.
    testthat::local_mocked_bindings(
        brprovider_data_available = function(provider_id) identical(provider_id, "florabr"),
        .package = "saira"
    )

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            # GBIF stays first (priority 1); the downloaded provider is appended.
            testthat::expect_identical(rv$selected_providers, c("gbif", "florabr"))
        }
    )
})

testthat::test_that("validation gate enables run state without touching mapped_data_r", {
    mapped_data_calls <- 0L
    gate_state <- shiny::reactiveVal(list(status = "missing_scientific", has_data = TRUE, scientific_col = ""))

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive({
                mapped_data_calls <<- mapped_data_calls + 1L
                data.frame(scientificName = c("Puma concolor"), stringsAsFactors = FALSE)
            }),
            lang_r = shiny::reactive("en"),
            validation_gate_r = shiny::reactive(gate_state())
        ),
        {
            state <- quick_inputs()
            testthat::expect_identical(state$status, "missing_scientific")
            testthat::expect_false(can_run_validation())
            testthat::expect_identical(mapped_data_calls, 0L)

            gate_state(list(status = "ok", has_data = TRUE, scientific_col = "scientificName"))
            session$flushReact()

            state <- quick_inputs()
            testthat::expect_identical(state$status, "ok")
            testthat::expect_true(can_run_validation())
            testthat::expect_identical(mapped_data_calls, 0L)
        }
    )
})

testthat::test_that("stream filter counts and problem-only filter are computed server-side", {
    mapped_df <- data.frame(scientificName = c("Puma concolor"), stringsAsFactors = FALSE)

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            rv$stream_df <- data.frame(
                query_name = c("A", "B", "C", "D", "E", "F"),
                validation_status = c("accepted", "not_found", "ambiguous", "synonym", "ignored", "invalid"),
                provider = c("gbif", "gbif", "gbif", "gbif", "gbif", "gbif"),
                updated_at = rep(as.POSIXct("2026-02-19 12:00:00", tz = "UTC"), 6),
                display_order = seq_len(6),
                stringsAsFactors = FALSE
            )

            stream_df <- stream_window(rv$stream_df, limit = 100L)
            counts <- stream_filter_counts(stream_df)

            testthat::expect_identical(as.integer(counts[["all"]]), 6L)
            testthat::expect_identical(as.integer(counts[["problems"]]), 3L)
            testthat::expect_identical(as.integer(counts[["not_found"]]), 1L)
            testthat::expect_identical(as.integer(counts[["ambiguous"]]), 1L)
            testthat::expect_identical(as.integer(counts[["synonym"]]), 1L)
            testthat::expect_identical(as.integer(counts[["ignored"]]), 2L)

            filtered <- filter_stream_df(stream_df, "problems")
            filtered_status <- vapply(filtered$validation_status, normalize_status_for_filter, FUN.VALUE = character(1))
            testthat::expect_true(all(filtered_status %in% c("not_found", "ambiguous", "synonym")))
        }
    )
})

testthat::test_that("completed validation defaults stream filter to problems", {
    mapped_df <- data.frame(scientificName = c("Puma concolor"), stringsAsFactors = FALSE)

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            testthat::expect_identical(stream_filter_after_completion(data.frame()), "all")
            testthat::expect_identical(
                stream_filter_after_completion(data.frame(validation_status = c("not_found"), stringsAsFactors = FALSE)),
                "problems"
            )
        }
    )
})

testthat::test_that("manual confirm review decrements unresolved and problem filter counts", {
    mapped_df <- data.frame(scientificName = c("A", "B"), stringsAsFactors = FALSE)

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            rv$stream_df <- data.frame(
                query_name = c("A", "B"),
                validation_status = c("accepted", "not_found"),
                provider = c("gbif", "gbif"),
                updated_at = rep(as.POSIXct("2026-02-27 10:00:00", tz = "UTC"), 2),
                display_order = c(1L, 2L),
                stringsAsFactors = FALSE
            )

            before_counts <- stream_filter_counts(rv$stream_df, reviewed_keys = reviewed_query_keys())
            testthat::expect_identical(as.integer(before_counts[["problems"]]), 1L)

            register_manual_review(
                query_name = "B",
                review_type = "confirm",
                original_name = "B",
                corrected_name = "B",
                reason = "Confirmed by user"
            )

            after_counts <- stream_filter_counts(rv$stream_df, reviewed_keys = reviewed_query_keys())
            testthat::expect_identical(as.integer(after_counts[["problems"]]), 0L)
        }
    )
})

testthat::test_that("manual correction saves only when name actually changes", {
    mapped_df <- data.frame(scientificName = c("Abies alba"), stringsAsFactors = FALSE)

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            rv$review_target <- list(
                query_name = "Abies alba",
                status_key = "not_found",
                scientific_name = "Abies alba"
            )
            session$setInputs(review_corrected_name = "Abies alba")
            session$setInputs(review_save_correction = 1)
            testthat::expect_identical(nrow(rv$manual_reviews), 0L)

            session$setInputs(review_corrected_name = "Abies alba var. minor")
            session$setInputs(review_correction_reason = "")
            session$setInputs(review_save_correction = 2)
            testthat::expect_identical(nrow(rv$manual_reviews), 1L)
            testthat::expect_identical(rv$manual_reviews$review_type[[1]], "correct")
            testthat::expect_identical(rv$manual_reviews$corrected_name[[1]], "Abies alba var. minor")
        }
    )
})

testthat::test_that("review modal render works for confirm and edit modes", {
    mapped_df <- data.frame(scientificName = c("Abies alba"), stringsAsFactors = FALSE)

    testthat::with_mocked_bindings(
        showModal = function(...) NULL,
        .package = "shiny",
        {
            shiny::testServer(
                mod_validate_names_server,
                args = list(
                    mapped_data_r = shiny::reactive(mapped_df),
                    lang_r = shiny::reactive("en")
                ),
                {
                    rv$review_target <- list(
                        query_name = "O'Hara \"Alpha\" <beta>",
                        status_key = "not_found",
                        scientific_name = "O'Hara \"Alpha\" <beta>"
                    )

                    testthat::expect_no_error(show_review_modal("confirm"))
                    testthat::expect_no_error(show_review_modal("edit"))
                }
            )
        }
    )
})

testthat::test_that("open_review_target first valid event resolves and stores target", {
    mapped_df <- data.frame(scientificName = c("Abies alba"), stringsAsFactors = FALSE)

    testthat::with_mocked_bindings(
        showModal = function(...) NULL,
        .package = "shiny",
        {
            shiny::testServer(
                mod_validate_names_server,
                args = list(
                    mapped_data_r = shiny::reactive(mapped_df),
                    lang_r = shiny::reactive("en")
                ),
                {
                    rv$stream_df <- data.frame(
                        query_name = "Abies alba",
                        validation_status = "not_found",
                        provider = "gbif",
                        updated_at = as.POSIXct("2026-02-27 12:00:00", tz = "UTC"),
                        display_order = 1L,
                        stringsAsFactors = FALSE
                    )

                    session$setInputs(open_review_target = "Abies alba")
                    session$flushReact()

                    testthat::expect_true(is.list(rv$review_target))
                    testthat::expect_identical(as.character(rv$review_target$query_name), "Abies alba")
                    testthat::expect_identical(as.character(rv$review_target$status_key), "not_found")
                    testthat::expect_identical(as.character(rv$review_target$scientific_name), "Abies alba")
                }
            )
        }
    )
})

testthat::test_that("open_review_target takes the BR suggestion from the report", {
    mapped_df <- data.frame(scientificName = c("Pantera onca"), stringsAsFactors = FALSE)

    testthat::with_mocked_bindings(
        showModal = function(...) NULL,
        .package = "shiny",
        {
            shiny::testServer(
                mod_validate_names_server,
                args = list(
                    mapped_data_r = shiny::reactive(mapped_df),
                    lang_r = shiny::reactive("en")
                ),
                {
                    validation_result(data.frame(
                        query_name = "Pantera onca",
                        scientificName = "Pantera onca",
                        suggestedName = "Panthera onca",
                        validation_status = "ambiguous",
                        stringsAsFactors = FALSE
                    ))

                    session$setInputs(open_review_target = "Pantera onca")
                    session$flushReact()

                    testthat::expect_identical(as.character(rv$review_target$scientific_name), "Pantera onca")
                    testthat::expect_identical(as.character(rv$review_target$suggested_name), "Panthera onca")
                }
            )
        }
    )
})

testthat::test_that("the edit modal fills the suggestion and keeps the typed name in the hint", {
    edit_html <- function(target) {
        shown <- NULL
        testthat::with_mocked_bindings(
            showModal = function(ui, ...) shown <<- ui,
            .package = "shiny",
            show_names_review_modal("edit", target, shiny::NS("vn"), function() "en")
        )
        as.character(shown)
    }

    html <- edit_html(list(query_name = "Pantera onca", status_key = "ambiguous",
                           scientific_name = "Pantera onca", suggested_name = "Panthera onca"))
    testthat::expect_match(html, 'value="Panthera onca"', fixed = TRUE)
    testthat::expect_match(html, "<em>Pantera onca</em>", fixed = TRUE)

    html <- edit_html(list(query_name = "Xyz abc", status_key = "not_found",
                           scientific_name = "Xyz abc", suggested_name = NA_character_))
    testthat::expect_match(html, 'value="Xyz abc"', fixed = TRUE)
})

testthat::test_that("open review handles modal open errors with notification", {
    mapped_df <- data.frame(scientificName = c("Abies alba"), stringsAsFactors = FALSE)
    notifications <- character(0)

    testthat::with_mocked_bindings(
        showModal = function(...) stop("modal failure"),
        showNotification = function(ui, type = "default", ...) {
            notifications <<- c(notifications, as.character(ui))
            NULL
        },
        .package = "shiny",
        {
            shiny::testServer(
                mod_validate_names_server,
                args = list(
                    mapped_data_r = shiny::reactive(mapped_df),
                    lang_r = shiny::reactive("en")
                ),
                {
                    rv$stream_df <- data.frame(
                        query_name = "Abies alba",
                        validation_status = "not_found",
                        provider = "gbif",
                        updated_at = as.POSIXct("2026-02-27 12:00:00", tz = "UTC"),
                        display_order = 1L,
                        stringsAsFactors = FALSE
                    )

                    session$setInputs(open_review_target = "Abies alba")
                    session$flushReact()
                }
            )
        }
    )

    testthat::expect_true(any(grepl("Failed to open manual review:", notifications, fixed = TRUE)))
    testthat::expect_true(any(grepl("modal failure", notifications, fixed = TRUE)))
})

testthat::test_that("effective report puts reviewed rows first with manual status badges", {
    mapped_df <- data.frame(scientificName = c("A", "B"), stringsAsFactors = FALSE)

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            validation_result(data.frame(
                scientificName = c("A", "B"),
                query_name = c("A", "B"),
                validation_status = c("not_found", "accepted"),
                taxonomicStatus = c(NA_character_, "accepted"),
                stringsAsFactors = FALSE
            ))

            register_manual_review(
                query_name = "A",
                review_type = "correct",
                original_name = "A",
                corrected_name = "A corrected",
                reason = "Typo"
            )

            eff <- effective_report()
            testthat::expect_identical(as.character(eff$query_name[[1]]), "A")
            testthat::expect_identical(as.character(eff$display_status[[1]]), "manual_revision")
            testthat::expect_identical(as.character(eff$scientificName_display[[1]]), "A corrected")
        }
    )
})

testthat::test_that("stream panel shows celebratory empty state when all problematic names are reviewed", {
    mapped_df <- data.frame(scientificName = c("A"), stringsAsFactors = FALSE)

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            rv$stream_df <- data.frame(
                query_name = "A",
                validation_status = "not_found",
                provider = "gbif",
                updated_at = as.POSIXct("2026-02-27 11:00:00", tz = "UTC"),
                display_order = 1L,
                stringsAsFactors = FALSE
            )
            register_manual_review(
                query_name = "A",
                review_type = "confirm",
                original_name = "A",
                corrected_name = "A",
                reason = "Confirmed by user"
            )
            rv$stream_filter <- "problems"
            session$flushReact()

            ui_obj <- output$stream_panel
            html <- paste(ui_obj$html, collapse = " ")
            testthat::expect_true(grepl("vn-review-empty-state", html, fixed = TRUE))
        }
    )
})

testthat::test_that("stream panel lists names under other filters when all problems are resolved", {
    mapped_df <- data.frame(scientificName = c("A"), stringsAsFactors = FALSE)

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            rv$stream_df <- data.frame(
                query_name = "A",
                validation_status = "accepted",
                provider = "gbif",
                updated_at = as.POSIXct("2026-02-27 11:00:00", tz = "UTC"),
                display_order = 1L,
                stringsAsFactors = FALSE
            )
            rv$stream_filter <- "accepted"
            session$flushReact()

            html <- paste(output$stream_panel$html, collapse = " ")
            testthat::expect_false(grepl("vn-review-empty-state", html, fixed = TRUE))
            testthat::expect_true(grepl("vn-stream-list", html, fixed = TRUE))
        }
    )
})

testthat::test_that("a run sends the answer list by key, and the panel renders once (DEP-07)", {
    mapped_df <- data.frame(scientificName = c("Puma concolor"), stringsAsFactors = FALSE)
    testthat::local_mocked_bindings(
        brprovider_data_available = function(provider_id) FALSE,
        .package = "saira"
    )
    stream_rows <- function(names, status) {
        data.frame(
            query_name = names,
            validation_status = status,
            provider = "gbif",
            updated_at = as.POSIXct("2026-10-22 10:00:00", tz = "UTC"),
            display_order = seq_along(names),
            stringsAsFactors = FALSE
        )
    }

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            sent <- list()
            root <- session$rootScope()
            root$sendCustomMessage <- function(type, message) {
                if (identical(type, "vnStreamSync")) sent[[length(sent) + 1L]] <<- message
            }
            rv$running <- TRUE
            session$flushReact()
            panel_before <- output$stream_panel

            rv$stream_df <- stream_rows(c("Puma concolor", "Abies alba"), c("accepted", "not_found"))
            session$flushReact()
            msg <- sent[[length(sent)]]
            testthat::expect_identical(msg$id, session$ns("stream_panel"))
            # Newest first, one key per name.
            testthat::expect_identical(vapply(msg$rows, `[[`, "", "key"), c("Abies alba", "Puma concolor"))
            testthat::expect_true(grepl('data-key="Abies alba"', msg$rows[[1]]$html, fixed = TRUE))
            testthat::expect_identical(msg$counts$all, 2L)
            testthat::expect_identical(msg$counts$problems, 1L)
            # The panel keeps its first render: the rows change in place.
            testthat::expect_identical(output$stream_panel, panel_before)

            rv$running <- FALSE
            session$flushReact()
            n_sent <- length(sent)
            testthat::expect_true(grepl("Abies alba", output$stream_panel$html, fixed = TRUE))
            rv$stream_df <- stream_rows("Puma concolor", "accepted")
            session$flushReact()
            testthat::expect_identical(length(sent), n_sent)
        }
    )
})

testthat::test_that("unchecked names leave the list for the block, and the retry checks them (ADR-169)", {
    mapped_df <- data.frame(scientificName = c("Puma concolor"), stringsAsFactors = FALSE)
    input_df <- data.frame(
        row_id = 1:3,
        input_name = c("Puma concolor", "Cebus apella", "Abies alba"),
        query_name = c("Puma concolor", "Cebus apella", "Abies alba"),
        skip_reason = NA_character_,
        stringsAsFactors = FALSE
    )
    gbif <- new.env()
    gbif$up <- FALSE
    testthat::local_mocked_bindings(
        brprovider_data_available = function(provider_id) FALSE,
        colxr_match_names = function(names) {
            answered <- if (gbif$up) names else intersect(names, "Puma concolor")
            out <- data.frame(
                query_name = answered,
                scientificName = answered,
                provider = "gbif",
                validation_status = "accepted",
                stringsAsFactors = FALSE
            )
            attr(out, "unanswered") <- setdiff(names, answered)
            out
        },
        .package = "saira"
    )
    state <- init_taxadb_run_state(input_df, providers = "gbif", batch_size = 20L)
    while (!is_taxadb_run_done(state)) {
        state <- next_taxadb_run_step(state)
    }
    finalized <- finalize_taxadb_run(state)

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            rv$run_state <- state
            validation_result(finalized$report)
            validation_meta(finalized$meta)
            rv$stream_df <- finalized$stream_df
            rv$stream_filter <- "all"
            session$flushReact()

            html <- paste(output$stream_panel$html, collapse = " ")
            testthat::expect_true(grepl("2 names with no answer", html, fixed = TRUE))
            testthat::expect_true(grepl('data-key="Puma concolor"', html, fixed = TRUE))
            testthat::expect_false(grepl('data-key="Cebus apella"', html, fixed = TRUE))
            testthat::expect_identical(stream_view()$counts[["not_found"]], 0L)

            gbif$up <- TRUE
            session$setInputs(retry_unchecked = 1)
            testthat::expect_true(isTRUE(rv$running))
            testthat::expect_identical(rv$run_state$total_unique, 2L)
            for (i in seq_len(50)) {
                if (!isTRUE(rv$running)) break
                session$elapse(100)
            }
            testthat::expect_false(isTRUE(rv$running))
            testthat::expect_identical(validation_meta()$unchecked, character(0))
            status <- stats::setNames(validation_result()$validation_status, validation_result()$query_name)
            testthat::expect_identical(unname(status[input_df$query_name]), rep("accepted", 3L))

            # Every name is checked now: the problems filter shows the end state.
            html <- paste(output$stream_panel$html, collapse = " ")
            testthat::expect_false(grepl("vn-unchecked-block", html, fixed = TRUE))
            testthat::expect_true(grepl("vn-review-empty-state", html, fixed = TRUE))
            rv$stream_filter <- "all"
            session$flushReact()
            testthat::expect_true(grepl('data-key="Cebus apella"', output$stream_panel$html, fixed = TRUE))
        }
    )
})

# Lowercase epithets "aa", "ab", ... so each fake name is a distinct binomial.
fake_epithets <- function(n) {
    i <- seq_len(n) - 1L
    paste0(letters[i %/% 26L + 1L], letters[i %% 26L + 1L])
}

testthat::test_that("module stream state grows incrementally per processed batch", {
    mapped_df <- data.frame(
        # Distinct binomials: a number after the genus is extra text, and
        # "Species 1" and "Species 2" both query "Species".
        scientificName = paste("Species", fake_epithets(250)),
        stringsAsFactors = FALSE
    )
    # Pin the default provider set to GBIF-only (no BR cache). With a real
    # Fauna BR cache, the 250 fake names reach the fuzzy matcher and the test
    # runs out of memory.
    testthat::local_mocked_bindings(
        brprovider_data_available = function(provider_id) FALSE,
        .package = "saira"
    )

    testthat::with_mocked_bindings(
        colxr_match_names = function(names) {
            data.frame(
                query_name = names,
                scientificName = names,
                provider = "gbif",
                validation_status = "accepted",
                stringsAsFactors = FALSE
            )
        },
        .package = "saira",
        {
            shiny::testServer(
                mod_validate_names_server,
                args = list(
                    mapped_data_r = shiny::reactive(mapped_df),
                    lang_r = shiny::reactive("en")
                ),
                {
                    prep <- prepared_inputs()
                    state <- init_taxadb_run_state(
                        input_df = prep$unique_df,
                        providers = rv$selected_providers,
                        batch_size = 200L
                    )

                    state <- next_taxadb_run_step(state) # prepare -> provider_init
                    state <- next_taxadb_run_step(state) # provider_init -> provider_query_batch
                    rv$stream_df <- state$stream_df
                    testthat::expect_identical(nrow(rv$stream_df), 0L)

                    state <- next_taxadb_run_step(state) # batch 1
                    rv$stream_df <- state$stream_df
                    testthat::expect_identical(nrow(rv$stream_df), 200L)

                    state <- next_taxadb_run_step(state) # batch 2
                    rv$stream_df <- state$stream_df
                    testthat::expect_identical(nrow(rv$stream_df), 250L)

                    while (!is_taxadb_run_done(state)) {
                        state <- next_taxadb_run_step(state)
                    }

                    finalized <- finalize_taxadb_run(state)
                    testthat::expect_true(is.data.frame(finalized$report))
                    testthat::expect_identical(nrow(finalized$report), 250L)
                }
            )
        }
    )
})

testthat::test_that("cancel path marks unresolved names after abort flag", {
    mapped_df <- data.frame(
        # Distinct binomials: a number after the genus is extra text, and
        # "Species 1" and "Species 2" both query "Species".
        scientificName = paste("Species", fake_epithets(240)),
        stringsAsFactors = FALSE
    )
    # Pin the default provider set to GBIF-only (no BR cache) so the single-
    # provider batch counts below are deterministic regardless of the test
    # machine's downloaded providers.
    testthat::local_mocked_bindings(
        brprovider_data_available = function(provider_id) FALSE,
        .package = "saira"
    )

    testthat::with_mocked_bindings(
        colxr_match_names = function(names) {
            data.frame(
                query_name = names,
                scientificName = names,
                provider = "gbif",
                validation_status = "accepted",
                stringsAsFactors = FALSE
            )
        },
        .package = "saira",
        {
            shiny::testServer(
                mod_validate_names_server,
                args = list(
                    mapped_data_r = shiny::reactive(mapped_df),
                    lang_r = shiny::reactive("en")
                ),
                {
                    prep <- prepared_inputs()
                    state <- init_taxadb_run_state(
                        input_df = prep$unique_df,
                        providers = rv$selected_providers,
                        batch_size = 200L
                    )

                    state <- next_taxadb_run_step(state) # prepare -> provider_init
                    state <- next_taxadb_run_step(state) # provider_init -> provider_query_batch
                    state <- next_taxadb_run_step(state) # batch 1 processed
                    testthat::expect_identical(state$resolved_unique, 200L)

                    state$aborted <- TRUE
                    state <- next_taxadb_run_step(state)
                    testthat::expect_identical(state$phase, "done")

                    finalized <- finalize_taxadb_run(state)
                    testthat::expect_true(isTRUE(finalized$meta$aborted))
                    testthat::expect_true(any(finalized$report$validation_status == "not_found"))
                }
            )
        }
    )
})

testthat::test_that("config panel shows BR provider runtime status badges", {
    mapped_df <- data.frame(scientificName = c("Panthera onca"), stringsAsFactors = FALSE)

    testthat::with_mocked_bindings(
        brprovider_cache_statuses = function(provider_ids = c("florabr", "faunabr"), poll = TRUE) {
            list(
                florabr = list(provider_id = "florabr", status = "update_in_progress", local_version = "393.319"),
                faunabr = list(provider_id = "faunabr", status = "up_to_date", local_version = "1.48")
            )
        },
        .package = "saira",
        {
            shiny::testServer(
                mod_validate_names_server,
                args = list(
                    mapped_data_r = shiny::reactive(mapped_df),
                    lang_r = shiny::reactive("en")
                ),
                {
                    ui_obj <- output$config_panel
                    html <- paste(ui_obj$html, collapse = " ")
                    testthat::expect_true(grepl("Updating...", html, fixed = TRUE))
                    testthat::expect_true(grepl("Up to date", html, fixed = TRUE))
                }
            )
        }
    )
})

testthat::test_that("report table wires the sensitive-species pill column", {
    mapped_df <- data.frame(
        scientificName = c("Hippocampus reidi", "Homo sapiens"),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            validation_result(data.frame(
                scientificName = c("Hippocampus reidi", "Homo sapiens"),
                query_name = c("Hippocampus reidi", "Homo sapiens"),
                validation_status = c("accepted", "accepted"),
                taxonomicStatus = c("accepted", "accepted"),
                stringsAsFactors = FALSE
            ))
            session$flushReact()

            widget <- jsonlite::fromJSON(
                output$report_table,
                simplifyVector = FALSE
            )
            col_defs <- widget$x$options$columnDefs

            hidden_targets <- unlist(lapply(col_defs, function(cd) {
                if (isFALSE(cd$visible)) unlist(cd$targets) else NULL
            }))
            # The hidden .is_sensitive column sits at index 4.
            testthat::expect_true(4 %in% hidden_targets)

            scientific_render <- NULL
            for (cd in col_defs) {
                if (!is.null(cd$render) && 0 %in% unlist(cd$targets)) {
                    scientific_render <- paste(unlist(cd$render), collapse = " ")
                }
            }
            # The callback configuration points to a factory in the shared asset.
            # Inspect that factory while preserving the hidden-column contract.
            testthat::expect_match(scientific_render, "window.sairaModuleBehavior.", fixed = TRUE)
            factory <- sub("^window[.]sairaModuleBehavior[.]([a-zA-Z0-9_]+).*", "\\1", scientific_render)
            asset <- paste(readLines(system.file("app", "www", "module-validate-names.js", package = "saira")), collapse = "\n")
            marker <- paste0("behavior.", factory, " = function (cfg) {")
            testthat::expect_true(grepl(marker, asset, fixed = TRUE))
            scientific_render <- strsplit(asset, marker, fixed = TRUE)[[1L]][2L]
            scientific_render <- strsplit(scientific_render, "\n  behavior.", fixed = TRUE)[[1L]][1L]
            testthat::expect_true(
                grepl("vn-cell-sensitive", scientific_render, fixed = TRUE)
            )
            testthat::expect_true(
                grepl("row[4]", scientific_render, fixed = TRUE)
            )
            # ADR-092: the resolved-name click target sits at hidden index 5.
            testthat::expect_true(5 %in% hidden_targets)
            # ADR-109: the invasive-species flag sits at hidden index 6. It
            # carries the origin_class, not a boolean, so the badge can only
            # say "alien invasive" where the list asserts it.
            testthat::expect_true(6 %in% hidden_targets)
            testthat::expect_true(
                grepl("vn-cell-invasive", scientific_render, fixed = TRUE)
            )
            testthat::expect_true(
                grepl("row[6]", scientific_render, fixed = TRUE)
            )
            testthat::expect_true(
                grepl("invasive === 'alien'", scientific_render, fixed = TRUE)
            )
            testthat::expect_true(
                grepl("badge-translocated", scientific_render, fixed = TRUE)
            )
        }
    )
})

testthat::test_that("report table keeps its data column names when the language changes", {
    # A server-side request from the table on screen names the columns. If the
    # names follow the language, DT alerts "column name not found".
    data_names <- list()
    datatable <- DT::datatable
    testthat::local_mocked_bindings(
        datatable = function(data, ...) {
            data_names[[length(data_names) + 1L]] <<- names(data)
            datatable(data, ...)
        },
        .package = "DT"
    )
    lang <- shiny::reactiveVal("pt")

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(data.frame(scientificName = "Homo sapiens")),
            lang_r = lang
        ),
        {
            validation_result(data.frame(
                scientificName = "Homo sapiens",
                query_name = "Homo sapiens",
                validation_status = "accepted",
                taxonomicStatus = "accepted",
                stringsAsFactors = FALSE
            ))
            session$flushReact()
            pt <- jsonlite::fromJSON(output$report_table, simplifyVector = FALSE)$x$container
            lang("en")
            session$flushReact()
            en <- jsonlite::fromJSON(output$report_table, simplifyVector = FALSE)$x$container

            testthat::expect_match(pt, tr("validate_names_table_col_scientific_name", "pt"), fixed = TRUE)
            testthat::expect_match(en, tr("validate_names_table_col_scientific_name", "en"), fixed = TRUE)
            testthat::expect_length(data_names, 2L)
            testthat::expect_identical(data_names[[1]], data_names[[2]])
        }
    )
})

testthat::test_that("sensitivity payload reflects per-species overrides", {
    mapped_df <- data.frame(
        scientificName = "Felis catus",
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            validation_result(data.frame(
                scientificName = "Felis catus",
                query_name = "Felis catus",
                validation_status = "accepted",
                taxonomicStatus = "accepted",
                stringsAsFactors = FALSE
            ))
            session$flushReact()

            payload <- attr(session$returned, "sensitivity_payload")
            testthat::expect_true(shiny::is.reactive(payload))
            testthat::expect_equal(nrow(payload()), 0L)

            # Researcher marks a non-MMA species sensitive and picks a threat
            # level (item 8). The payload now carries that category so the
            # Generalization tab can group the species under the chosen level.
            register_sensitivity_override("Felis catus", TRUE, category = "EN")
            session$flushReact()

            df <- payload()
            testthat::expect_equal(df$scientificName, "Felis catus")
            testthat::expect_true(df$sensitive)
            testthat::expect_true("category" %in% names(df))
            testthat::expect_identical(df$category, "EN")

            # The chosen level resolves to the matching MMA group code, so the
            # off-list species joins that group instead of "Other".
            dec <- saira:::sensitive_resolve("Felis catus", df)
            testthat::expect_true(dec$sensitive[1])
            testthat::expect_identical(dec$category[1], "EN")
        }
    )
})

testthat::test_that("config panel keeps the option switches across a language switch", {
    gate <- list(status = "ok", has_data = TRUE, scientific_col = "scientificName")
    lang <- shiny::reactiveVal("pt")

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(
                data.frame(scientificName = "Puma concolor", stringsAsFactors = FALSE)
            ),
            lang_r = lang,
            validation_gate_r = shiny::reactive(gate)
        ),
        {
            session$setInputs(remove_authors = FALSE, ignore_qualifiers = FALSE)
            session$flushReact()

            lang("en")
            session$flushReact()

            # The switches are recreated by the renderUI on a language change;
            # the isolate() must still read the user's value back, so the markup
            # must not come out checked. (The DOM rebinding that makes this
            # user-visible is only reproducible manually.)
            testthat::expect_false(isTRUE(input$remove_authors))
            testthat::expect_false(isTRUE(input$ignore_qualifiers))
            config_html <- paste(output$config_panel$html, collapse = " ")
            testthat::expect_true(grepl("vn-config-panel", config_html, fixed = TRUE))
        }
    )
})

testthat::test_that("a broken mapping pipeline reports instead of ending the session", {
    # An untrapped error inside an observer ends the Shiny session, which is how
    # a mapping defect closed the app on Validate instead of reporting itself.
    failing_data_r <- shiny::reactive({
        stop("replacement has 0 rows, data has 100")
    })

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = failing_data_r,
            lang_r = shiny::reactive("en")
        ),
        {
            rv$start_requested <- TRUE
            testthat::expect_no_error(session$flushReact())

            # The run is abandoned cleanly, leaving the tab usable.
            testthat::expect_false(isTRUE(rv$starting))
            testthat::expect_false(isTRUE(rv$running))
            testthat::expect_identical(rv$last_run_status, "idle")
        }
    )
})

testthat::test_that("a silent req() upstream leaves the tab idle without an error", {
    # req() upstream means "no data yet", not a failure: it must not surface as
    # an error notification.
    empty_data_r <- shiny::reactive({
        shiny::req(NULL)
    })

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = empty_data_r,
            lang_r = shiny::reactive("en")
        ),
        {
            rv$start_requested <- TRUE
            testthat::expect_no_error(session$flushReact())
            testthat::expect_identical(rv$last_run_status, "idle")
        }
    )
})

testthat::test_that("GBIF stays selected and has no toggle", {
    testthat::local_mocked_bindings(
        brprovider_data_available = function(provider_id) FALSE,
        .package = "saira"
    )

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(data.frame(scientificName = "Puma concolor")),
            lang_r = shiny::reactive("pt")
        ),
        {
            toggle_provider_selection("gbif")
            testthat::expect_identical(rv$selected_providers, "gbif")
            session$flushReact()

            config_html <- paste(output$config_panel$html, collapse = " ")
            testthat::expect_false(grepl("provider_card_gbif", config_html, fixed = TRUE))
            testthat::expect_true(grepl("provider_card_florabr", config_html, fixed = TRUE))
            testthat::expect_true(grepl("is-locked", config_html, fixed = TRUE))
        }
    )
})

testthat::test_that("the provider status poll runs only during a run or an update", {
    state <- new.env()
    state$calls <- 0L
    state$status <- "up_to_date"
    testthat::local_mocked_bindings(
        brprovider_data_available = function(provider_id) TRUE,
        brprovider_cache_statuses = function(provider_ids = c("florabr", "faunabr"), poll = TRUE) {
            if (isTRUE(poll)) state$calls <- state$calls + 1L
            list(
                florabr = list(provider_id = "florabr", status = state$status, local_version = "393.319"),
                faunabr = list(provider_id = "faunabr", status = "up_to_date", local_version = "1.48")
            )
        },
        .package = "saira"
    )

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(data.frame(scientificName = "Panthera onca")),
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            # Both providers are cached and selected, but nothing runs.
            before <- state$calls
            session$elapse(6000)
            testthat::expect_identical(state$calls, before)

            rv$running <- TRUE
            session$flushReact()
            before <- state$calls
            session$elapse(2500)
            testthat::expect_gt(state$calls, before)

            # The run starts an update that continues after the run.
            state$status <- "update_in_progress"
            session$elapse(1300)
            rv$running <- FALSE
            session$flushReact()
            before <- state$calls
            session$elapse(2500)
            testthat::expect_gt(state$calls, before)

            state$status <- "up_to_date"
            session$elapse(1300)
            before <- state$calls
            session$elapse(6000)
            testthat::expect_identical(state$calls, before)
        }
    )
})
