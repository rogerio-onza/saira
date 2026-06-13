# Title: Tests for Validate Names Module Server
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-19
# Version: 2.3

testthat::test_that("provider priority follows toggle order", {
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
            testthat::expect_identical(rv$selected_providers, "florabr")

            toggle_provider_selection("gbif")
            testthat::expect_identical(rv$selected_providers, c("florabr", "gbif"))
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

testthat::test_that("report status counts classify valid, invalid and unresolved buckets", {
    mapped_df <- data.frame(scientificName = c("Puma concolor"), stringsAsFactors = FALSE)

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            mock_report <- data.frame(
                scientificName = c("A", "B", "C", "D", "E"),
                validation_status = c("accepted", "synonym", "ignored", "not_found", "ambiguous"),
                stringsAsFactors = FALSE
            )

            counts <- report_status_counts(mock_report)
            testthat::expect_identical(as.integer(counts[["valid"]]), 1L)
            testthat::expect_identical(as.integer(counts[["invalid"]]), 1L)
            testthat::expect_identical(as.integer(counts[["unresolved"]]), 3L)
            testthat::expect_identical(as.integer(counts[["total"]]), 5L)
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

            report_df <- data.frame(
                scientificName = c("A", "B"),
                query_name = c("A", "B"),
                validation_status = c("accepted", "not_found"),
                stringsAsFactors = FALSE
            )
            counts <- report_status_counts(within(report_df, {
                manual_review <- c(FALSE, TRUE)
            }))
            testthat::expect_identical(as.integer(counts[["unresolved"]]), 0L)
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

testthat::test_that("module stream state grows incrementally per processed batch", {
    mapped_df <- data.frame(
        scientificName = paste("Species", seq_len(250)),
        stringsAsFactors = FALSE
    )

    testthat::with_mocked_bindings(
        init_taxadb_provider = function(provider) list(provider = provider),
        query_taxadb_batch = function(query_names, provider, db) {
            data.frame(
                query_name = query_names,
                scientificName = query_names,
                taxonomicStatus = "accepted",
                provider = provider,
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
        scientificName = paste("Species", seq_len(240)),
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
        init_taxadb_provider = function(provider) list(provider = provider),
        query_taxadb_batch = function(query_names, provider, db) {
            data.frame(
                query_name = query_names,
                scientificName = query_names,
                taxonomicStatus = "accepted",
                provider = provider,
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
            testthat::expect_true(
                grepl("vn-cell-sensitive", scientific_render, fixed = TRUE)
            )
            testthat::expect_true(
                grepl("row[4]", scientific_render, fixed = TRUE)
            )
            # ADR-092: the resolved-name click target sits at hidden index 5.
            testthat::expect_true(5 %in% hidden_targets)
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

            # Researcher marks a non-MMA species sensitive (ADR-092). The
            # global Chapman tier is chosen on the Preview tab, so the
            # payload only needs to carry the boolean decision.
            register_sensitivity_override("Felis catus", TRUE)
            session$flushReact()

            df <- payload()
            testthat::expect_equal(df$scientificName, "Felis catus")
            testthat::expect_true(df$sensitive)
            testthat::expect_false("category" %in% names(df))
        }
    )
})
