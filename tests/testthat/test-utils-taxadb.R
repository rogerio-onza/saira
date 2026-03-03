# Title: Tests for taxadb utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-15
# Version: 1.0

normalize_scientific_name <- function(...) saira:::normalize_scientific_name(...)
prepare_taxadb_inputs <- function(...) saira:::prepare_taxadb_inputs(...)
resolve_taxadb_matches <- function(...) saira:::resolve_taxadb_matches(...)
run_taxadb_cascade <- function(...) saira:::run_taxadb_cascade(...)
build_validation_report <- function(...) saira:::build_validation_report(...)
init_taxadb_run_state <- function(...) saira:::init_taxadb_run_state(...)
next_taxadb_run_step <- function(...) saira:::next_taxadb_run_step(...)
is_taxadb_run_done <- function(...) saira:::is_taxadb_run_done(...)
finalize_taxadb_run <- function(...) saira:::finalize_taxadb_run(...)
append_stream_items <- function(...) saira:::append_stream_items(...)

testthat::test_that("normalize_scientific_name removes authors and qualifiers", {
    out <- normalize_scientific_name("Puma concolor (Linnaeus, 1771)")
    testthat::expect_identical(out, "Puma concolor")

    out <- normalize_scientific_name("Abies cf. alba")
    testthat::expect_identical(out, "Abies alba")

    out <- normalize_scientific_name("Quercus sp.")
    testthat::expect_true(is.na(out))
})

testthat::test_that("prepare_taxadb_inputs marks blank and ignored values", {
    inputs <- prepare_taxadb_inputs(
        names_vec = c("Quercus sp.", "", NA_character_, "Puma concolor"),
        remove_authors = TRUE,
        ignore_qualifiers = TRUE
    )

    testthat::expect_identical(inputs$skip_reason[[1]], "ignored")
    testthat::expect_identical(inputs$skip_reason[[2]], "blank")
    testthat::expect_identical(inputs$skip_reason[[3]], "blank")
    testthat::expect_true(is.na(inputs$skip_reason[[4]]))
})

testthat::test_that("prepare_taxadb_inputs normalizes only unique raw names", {
    calls <- 0L

    testthat::with_mocked_bindings(
        normalize_scientific_name = function(name, remove_authors = TRUE, ignore_qualifiers = TRUE) {
            calls <<- calls + 1L
            if (is.na(name)) {
                return(NA_character_)
            }
            out <- tolower(trimws(as.character(name)))
            if (!nzchar(out)) {
                return(NA_character_)
            }
            out
        },
        .package = "saira",
        {
            names_vec <- c(" Puma concolor ", "Puma concolor", "Puma concolor", "Abies alba", "Abies alba", NA_character_, "")
            out <- prepare_taxadb_inputs(
                names_vec = names_vec,
                remove_authors = TRUE,
                ignore_qualifiers = TRUE
            )

            testthat::expect_identical(calls, length(unique(as.character(names_vec))))
            testthat::expect_identical(out$query_name[[1]], "puma concolor")
            testthat::expect_identical(out$query_name[[2]], "puma concolor")
            testthat::expect_identical(out$query_name[[3]], "puma concolor")
            testthat::expect_identical(out$query_name[[4]], "abies alba")
            testthat::expect_identical(out$query_name[[5]], "abies alba")
            testthat::expect_true(is.na(out$query_name[[6]]))
            testthat::expect_true(is.na(out$query_name[[7]]))
        }
    )
})

testthat::test_that("resolve_taxadb_matches detects ambiguity and acceptance", {
    matches <- data.frame(
        query_name = c("puma concolor", "abies alba", "abies alba"),
        scientificName = c("Puma concolor", "Abies alba", "Abies alba"),
        taxonomicStatus = c("accepted", "synonym", "accepted"),
        provider = c("gbif", "gbif", "gbif"),
        stringsAsFactors = FALSE
    )

    resolved <- resolve_taxadb_matches(matches)
    resolved <- resolved[order(resolved$query_name), , drop = FALSE]

    testthat::expect_identical(resolved$validation_status[[1]], "ambiguous")
    testthat::expect_identical(resolved$validation_status[[2]], "accepted")
})

testthat::test_that("run_taxadb_cascade respects provider priority", {
    calls <- list()

    fake_fetch <- function(query_names, provider) {
        calls[[length(calls) + 1L]] <<- list(provider = provider, names = query_names)
        if (identical(provider, "gbif")) {
            return(data.frame(
                query_name = "puma concolor",
                scientificName = "Puma concolor",
                taxonomicStatus = "accepted",
                provider = provider,
                stringsAsFactors = FALSE
            ))
        }
        if (identical(provider, "itis")) {
            return(data.frame(
                query_name = "abies alba",
                scientificName = "Abies alba",
                taxonomicStatus = "accepted",
                provider = provider,
                stringsAsFactors = FALSE
            ))
        }
        data.frame()
    }

    out <- run_taxadb_cascade(
        query_names = c("puma concolor", "abies alba"),
        providers = c("gbif", "itis"),
        fetch_fun = fake_fetch
    )

    testthat::expect_true(any(out$query_name == "puma concolor"))
    testthat::expect_true(any(out$query_name == "abies alba"))
    testthat::expect_identical(calls[[1]]$provider, "gbif")
    testthat::expect_identical(calls[[2]]$provider, "itis")
})

testthat::test_that("run_taxadb_cascade skips failed providers and keeps metadata", {
    calls <- character(0)

    fake_fetch <- function(query_names, provider) {
        calls <<- c(calls, provider)

        if (identical(provider, "gbif")) {
            return(data.frame())
        }

        if (identical(provider, "itis")) {
            stop("provider unavailable")
        }

        if (identical(provider, "col")) {
            return(data.frame(
                query_name = "abies alba",
                scientificName = "Abies alba",
                taxonomicStatus = "accepted",
                provider = provider,
                stringsAsFactors = FALSE
            ))
        }

        data.frame()
    }

    out <- run_taxadb_cascade(
        query_names = c("abies alba"),
        providers = c("gbif", "itis", "col"),
        fetch_fun = fake_fetch
    )

    failures <- attr(out, "provider_failures")
    attempted <- attr(out, "provider_attempted")

    testthat::expect_identical(calls, c("gbif", "itis", "col"))
    testthat::expect_true(any(out$query_name == "abies alba"))
    testthat::expect_identical(out$provider[[1]], "col")
    testthat::expect_true(is.data.frame(failures))
    testthat::expect_identical(nrow(failures), 1L)
    testthat::expect_identical(failures$provider[[1]], "itis")
    testthat::expect_identical(attempted, c("gbif", "itis", "col"))
})

testthat::test_that("build_validation_report preserves order and flags ignored", {
    input_df <- data.frame(
        row_id = 1:3,
        input_name = c("Quercus sp.", "Puma concolor", ""),
        query_name = c(NA_character_, "puma concolor", NA_character_),
        skip_reason = c("ignored", NA_character_, "blank"),
        stringsAsFactors = FALSE
    )
    cascade <- data.frame(
        query_name = "puma concolor",
        scientificName = "Puma concolor",
        taxonomicStatus = "accepted",
        provider = "gbif",
        stringsAsFactors = FALSE
    )

    report <- build_validation_report(input_df, cascade)
    testthat::expect_identical(report$validation_status[[1]], "ignored")
    testthat::expect_identical(report$validation_status[[2]], "accepted")
    testthat::expect_identical(report$validation_status[[3]], "invalid")
})

testthat::test_that("append_stream_items updates existing rows and appends new rows in one pass", {
    initial <- data.frame(
        query_name = c("puma concolor", "abies alba"),
        validation_status = c("accepted", "not_found"),
        provider = c("gbif", "gbif"),
        updated_at = as.POSIXct(c("2026-02-16 10:00:00", "2026-02-16 10:00:00"), tz = "UTC"),
        display_order = c(1L, 2L),
        stringsAsFactors = FALSE
    )

    updates <- data.frame(
        query_name = c("abies alba", "canis lupus", "canis lupus"),
        validation_status = c("accepted", "not_found", "synonym"),
        provider = c("itis", "gbif", "col"),
        stringsAsFactors = FALSE
    )

    out <- append_stream_items(
        stream_df = initial,
        resolved_df = updates,
        now = as.POSIXct("2026-02-16 10:05:00", tz = "UTC")
    )

    testthat::expect_identical(nrow(out), 3L)
    abies_idx <- match("abies alba", out$query_name)
    canis_idx <- match("canis lupus", out$query_name)

    testthat::expect_identical(out$validation_status[[abies_idx]], "accepted")
    testthat::expect_identical(out$provider[[abies_idx]], "itis")
    testthat::expect_identical(out$provider[[canis_idx]], "col")
    testthat::expect_identical(out$validation_status[[canis_idx]], "synonym")
    testthat::expect_true(out$display_order[[canis_idx]] > 2L)
})

testthat::test_that("state machine appends stream incrementally by batch", {
    input_df <- data.frame(
        row_id = 1:4,
        input_name = c("Puma concolor", "Abies alba", "Quercus robur", "Canis lupus"),
        query_name = c("puma concolor", "abies alba", "quercus robur", "canis lupus"),
        skip_reason = c(NA_character_, NA_character_, NA_character_, NA_character_),
        stringsAsFactors = FALSE
    )

    fake_query <- function(query_names, provider, db) {
        if (identical(sort(query_names), c("abies alba", "puma concolor"))) {
            return(data.frame(
                query_name = c("puma concolor", "abies alba"),
                scientificName = c("Puma concolor", "Abies alba"),
                taxonomicStatus = c("accepted", "accepted"),
                provider = provider,
                stringsAsFactors = FALSE
            ))
        }

        if (identical(sort(query_names), c("canis lupus", "quercus robur"))) {
            return(data.frame(
                query_name = c("quercus robur", "canis lupus"),
                scientificName = c("Quercus robur", "Canis lupus"),
                taxonomicStatus = c("accepted", "synonym"),
                provider = provider,
                stringsAsFactors = FALSE
            ))
        }

        data.frame()
    }

    testthat::with_mocked_bindings(
        init_taxadb_provider = function(provider) list(provider = provider),
        query_taxadb_batch = fake_query,
        .package = "saira",
        {
            state <- init_taxadb_run_state(
                input_df = input_df,
                providers = "gbif",
                batch_size = 2L
            )

            state <- next_taxadb_run_step(state) # prepare -> provider_init
            state <- next_taxadb_run_step(state) # provider_init -> provider_query_batch
            testthat::expect_identical(nrow(state$stream_df), 0L)

            state <- next_taxadb_run_step(state) # first batch
            testthat::expect_identical(nrow(state$stream_df), 2L)
            testthat::expect_identical(state$resolved_unique, 2L)

            state <- next_taxadb_run_step(state) # second batch
            testthat::expect_identical(nrow(state$stream_df), 4L)
            testthat::expect_identical(state$resolved_unique, 4L)

            while (!is_taxadb_run_done(state)) {
                state <- next_taxadb_run_step(state)
            }

            finalized <- finalize_taxadb_run(state)
            testthat::expect_true(is.data.frame(finalized$report))
            testthat::expect_identical(nrow(finalized$report), 4L)
        }
    )
})

testthat::test_that("aborted run moves to consolidate before next batch", {
    input_df <- data.frame(
        row_id = 1:3,
        input_name = c("Puma concolor", "Abies alba", "Quercus robur"),
        query_name = c("puma concolor", "abies alba", "quercus robur"),
        skip_reason = c(NA_character_, NA_character_, NA_character_),
        stringsAsFactors = FALSE
    )

    testthat::with_mocked_bindings(
        init_taxadb_provider = function(provider) list(provider = provider),
        query_taxadb_batch = function(query_names, provider, db) {
            data.frame(
                query_name = query_names[[1]],
                scientificName = query_names[[1]],
                taxonomicStatus = "accepted",
                provider = provider,
                stringsAsFactors = FALSE
            )
        },
        .package = "saira",
        {
            state <- init_taxadb_run_state(
                input_df = input_df,
                providers = "gbif",
                batch_size = 1L
            )
            state <- next_taxadb_run_step(state) # prepare -> provider_init
            state <- next_taxadb_run_step(state) # provider_init -> provider_query_batch
            state <- next_taxadb_run_step(state) # first query batch
            testthat::expect_identical(state$resolved_unique, 1L)

            state$aborted <- TRUE
            state <- next_taxadb_run_step(state)
            testthat::expect_identical(state$phase, "done")
            testthat::expect_true(isTRUE(state$aborted))

            finalized <- finalize_taxadb_run(state)
            testthat::expect_true(isTRUE(finalized$meta$aborted))
            testthat::expect_identical(nrow(finalized$report), 3L)
        }
    )
})
