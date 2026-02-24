# Title: Tests for Validate Names Module Server
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-19
# Version: 2.3

testthat::test_that("provider priority follows toggle order", {
    mapped_df <- data.frame(scientificName = c("Puma concolor"), stringsAsFactors = FALSE)

    shiny::testServer(
        mod_validate_names_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            testthat::expect_identical(rv$selected_providers, "gbif")

            toggle_provider_selection("itis")
            testthat::expect_identical(rv$selected_providers, c("gbif", "itis"))

            toggle_provider_selection("gbif")
            testthat::expect_identical(rv$selected_providers, "itis")

            toggle_provider_selection("gbif")
            testthat::expect_identical(rv$selected_providers, c("itis", "gbif"))
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
            testthat::expect_identical(as.integer(counts[["problems"]]), 5L)
            testthat::expect_identical(as.integer(counts[["not_found"]]), 1L)
            testthat::expect_identical(as.integer(counts[["ambiguous"]]), 1L)
            testthat::expect_identical(as.integer(counts[["synonym"]]), 1L)
            testthat::expect_identical(as.integer(counts[["ignored"]]), 2L)

            filtered <- filter_stream_df(stream_df, "problems")
            filtered_status <- vapply(filtered$validation_status, normalize_status_for_filter, FUN.VALUE = character(1))
            testthat::expect_true(all(filtered_status != "accepted"))
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
            testthat::expect_identical(as.integer(counts[["valid"]]), 2L)
            testthat::expect_identical(as.integer(counts[["invalid"]]), 1L)
            testthat::expect_identical(as.integer(counts[["unresolved"]]), 2L)
            testthat::expect_identical(as.integer(counts[["total"]]), 5L)
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
        .package = "finch",
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
        .package = "finch",
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
