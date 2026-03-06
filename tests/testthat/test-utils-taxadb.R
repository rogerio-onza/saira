# Title: Tests for taxadb utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-15
# Version: 1.0

normalize_scientific_name   <- function(...) saira:::normalize_scientific_name(...)
prepare_taxadb_inputs       <- function(...) saira:::prepare_taxadb_inputs(...)
resolve_taxadb_matches      <- function(...) saira:::resolve_taxadb_matches(...)
run_taxadb_cascade          <- function(...) saira:::run_taxadb_cascade(...)
build_validation_report     <- function(...) saira:::build_validation_report(...)
init_taxadb_run_state       <- function(...) saira:::init_taxadb_run_state(...)
next_taxadb_run_step        <- function(...) saira:::next_taxadb_run_step(...)
is_taxadb_run_done          <- function(...) saira:::is_taxadb_run_done(...)
finalize_taxadb_run         <- function(...) saira:::finalize_taxadb_run(...)
append_stream_items         <- function(...) saira:::append_stream_items(...)
normalize_brprovider_result <- function(...) saira:::normalize_brprovider_result(...)
brprovider_ensure_data      <- function(...) saira:::brprovider_ensure_data(...)

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

testthat::test_that("build_validation_report collapses duplicate cascade rows by best effective status", {
    input_df <- data.frame(
        row_id = 1:2,
        input_name = c("Abies alba", "Canis lupus"),
        query_name = c("abies alba", "canis lupus"),
        skip_reason = c(NA_character_, NA_character_),
        stringsAsFactors = FALSE
    )
    cascade <- data.frame(
        query_name = c("abies alba", "abies alba", "canis lupus", "canis lupus"),
        scientificName = c("Abies alba", "Abies alba", "Canis lupus", "Canis lupus familiaris"),
        taxonomicStatus = c("synonym", "accepted", "synonym", NA_character_),
        provider = c("florabr", "gbif", "florabr", NA_character_),
        validation_status = c("synonym", "accepted", "synonym", "not_found"),
        stringsAsFactors = FALSE
    )

    report <- build_validation_report(input_df, cascade)

    testthat::expect_identical(nrow(report), 2L)
    abies_idx <- match("abies alba", report$query_name)
    canis_idx <- match("canis lupus", report$query_name)

    testthat::expect_identical(report$validation_status[[abies_idx]], "accepted")
    testthat::expect_identical(report$nameAccordingTo[[abies_idx]], "GBIF")
    testthat::expect_identical(report$validation_status[[canis_idx]], "synonym")
    testthat::expect_identical(report$nameAccordingTo[[canis_idx]], "FLORABR")
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

testthat::test_that("append_stream_items does not downgrade BR findings to fallback not_found", {
    initial <- data.frame(
        query_name = "abies alba",
        validation_status = "synonym",
        provider = "florabr",
        updated_at = as.POSIXct("2026-02-16 10:00:00", tz = "UTC"),
        display_order = 1L,
        stringsAsFactors = FALSE
    )
    updates <- data.frame(
        query_name = "abies alba",
        validation_status = "not_found",
        provider = "gbif",
        stringsAsFactors = FALSE
    )

    out <- append_stream_items(
        stream_df = initial,
        resolved_df = updates,
        now = as.POSIXct("2026-02-16 10:05:00", tz = "UTC")
    )

    testthat::expect_identical(out$validation_status[[1]], "synonym")
    testthat::expect_identical(out$provider[[1]], "florabr")
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

# ---------------------------------------------------------------------------
# Two-phase cascade: provider_types + cascade_phase
# ---------------------------------------------------------------------------

testthat::test_that("init_taxadb_run_state: BR providers classified correctly", {
    input_df <- data.frame(
        row_id      = 1L,
        input_name  = "Panthera onca",
        query_name  = "Panthera onca",
        skip_reason = NA_character_,
        stringsAsFactors = FALSE
    )
    state <- init_taxadb_run_state(input_df, providers = c("florabr", "gbif"))
    testthat::expect_equal(state$provider_types[["florabr"]], "br")
    testthat::expect_equal(state$provider_types[["gbif"]], "taxadb")
    testthat::expect_equal(state$cascade_phase, "br")
})

testthat::test_that("init_taxadb_run_state: GBIF auto-added as fallback when only BR selected", {
    input_df <- data.frame(
        row_id      = 1L,
        input_name  = "Panthera onca",
        query_name  = "Panthera onca",
        skip_reason = NA_character_,
        stringsAsFactors = FALSE
    )
    state <- init_taxadb_run_state(input_df, providers = c("florabr"))
    testthat::expect_true("gbif" %in% state$providers)
    testthat::expect_equal(state$provider_types[["gbif"]], "taxadb")
})

testthat::test_that("init_taxadb_run_state: BR providers ordered before GBIF", {
    input_df <- data.frame(
        row_id      = 1L,
        input_name  = "Panthera onca",
        query_name  = "Panthera onca",
        skip_reason = NA_character_,
        stringsAsFactors = FALSE
    )
    state <- init_taxadb_run_state(
        input_df,
        providers = c("gbif", "florabr", "faunabr")
    )
    br_pos    <- which(state$providers %in% c("florabr", "faunabr"))
    taxadb_pos <- which(state$providers == "gbif")
    testthat::expect_true(all(br_pos < taxadb_pos))
})

testthat::test_that("init_taxadb_run_state: only GBIF gives cascade_phase fallback", {
    input_df <- data.frame(
        row_id      = 1L,
        input_name  = "Panthera onca",
        query_name  = "Panthera onca",
        skip_reason = NA_character_,
        stringsAsFactors = FALSE
    )
    state <- init_taxadb_run_state(input_df, providers = c("gbif"))
    testthat::expect_equal(state$cascade_phase, "fallback")
})

testthat::test_that("next_taxadb_run_step: only BR accepted names leave pending_queries", {
    input_df <- data.frame(
        row_id      = 1:4,
        input_name  = c("Acceptedus br", "Synonymus br", "Ambiguous br", "Unknownus br"),
        query_name  = c("acceptedus br", "synonymus br", "ambiguous br", "unknownus br"),
        skip_reason = NA_character_,
        stringsAsFactors = FALSE
    )

    testthat::with_mocked_bindings(
        brprovider_ensure_data = function(provider_id, verbose = FALSE, ...) {
            list(ok = TRUE, available = TRUE, provider_id = provider_id)
        },
        brprovider_load_data = function(provider_id, force_reload = FALSE) {
            data.frame(provider = provider_id, stringsAsFactors = FALSE)
        },
        query_brprovider = function(query_names, provider_id, data = NULL, max_distance = 0.1) {
            status_lookup <- c(
                "acceptedus br" = "accepted",
                "synonymus br" = "synonym",
                "ambiguous br" = "ambiguous",
                "unknownus br" = "not_found"
            )
            data.frame(
                query_name = query_names,
                scientificName = tools::toTitleCase(query_names),
                taxonomicStatus = c("accepted", "synonym", "accepted", NA_character_)[match(query_names, names(status_lookup))],
                family = c("A", "B", "C", NA_character_)[match(query_names, names(status_lookup))],
                provider = provider_id,
                validation_status = unname(status_lookup[query_names]),
                match_count = c(1L, 1L, 2L, 0L)[match(query_names, names(status_lookup))],
                stringsAsFactors = FALSE
            )
        },
        .package = "saira",
        {
            state <- init_taxadb_run_state(
                input_df,
                providers = c("florabr"),
                batch_size = 200L
            )
            state <- next_taxadb_run_step(state) # prepare -> provider_init
            state <- next_taxadb_run_step(state) # init/load BR provider
            state <- next_taxadb_run_step(state) # query BR batch

            testthat::expect_false("acceptedus br" %in% state$pending_queries)
            testthat::expect_true(all(c("synonymus br", "ambiguous br", "unknownus br") %in% state$pending_queries))
            testthat::expect_true("gbif" %in% state$providers)

            stream_status <- stats::setNames(
                as.character(state$stream_df$validation_status),
                as.character(state$stream_df$query_name)
            )
            testthat::expect_identical(stream_status[["synonymus br"]], "synonym")
            testthat::expect_identical(stream_status[["ambiguous br"]], "ambiguous")
            testthat::expect_identical(stream_status[["unknownus br"]], "not_found")
        }
    )
})

testthat::test_that("next_taxadb_run_step: BR provider init uses ensure_data and loads cache", {
    input_df <- data.frame(
        row_id = 1L,
        input_name = "Panthera onca",
        query_name = "Panthera onca",
        skip_reason = NA_character_,
        stringsAsFactors = FALSE
    )

    testthat::with_mocked_bindings(
        brprovider_ensure_data = function(provider_id, verbose = FALSE, ...) {
            list(
                ok = TRUE,
                available = TRUE,
                provider_id = provider_id,
                status = "up_to_date",
                bootstrap = FALSE,
                background_started = TRUE
            )
        },
        brprovider_load_data = function(provider_id, force_reload = FALSE) {
            data.frame(
                scientificName = "Panthera onca",
                taxonomicStatus = "accepted",
                stringsAsFactors = FALSE
            )
        },
        .package = "saira",
        {
            state <- init_taxadb_run_state(input_df, providers = c("faunabr"), batch_size = 50L)
            state <- next_taxadb_run_step(state) # prepare -> provider_init
            state <- next_taxadb_run_step(state) # provider_init resolves BR bootstrap/load

            testthat::expect_true(is.data.frame(state$current_provider_data))
            testthat::expect_identical(as.character(state$current_provider), "faunabr")
            testthat::expect_true(state$phase %in% c("provider_query_batch", "provider_finalize"))
        }
    )
})

testthat::test_that("next_taxadb_run_step: ensure_data failure is captured in provider_failures", {
    input_df <- data.frame(
        row_id = 1L,
        input_name = "Panthera onca",
        query_name = "Panthera onca",
        skip_reason = NA_character_,
        stringsAsFactors = FALSE
    )

    testthat::with_mocked_bindings(
        brprovider_ensure_data = function(provider_id, verbose = FALSE, ...) {
            list(
                ok = FALSE,
                available = FALSE,
                provider_id = provider_id,
                status = "update_failed",
                error = "bootstrap failed"
            )
        },
        .package = "saira",
        {
            state <- init_taxadb_run_state(input_df, providers = c("faunabr"), batch_size = 50L)
            state <- next_taxadb_run_step(state) # prepare -> provider_init
            state <- next_taxadb_run_step(state) # provider_init should fail gracefully

            testthat::expect_identical(state$phase, "provider_finalize")
            testthat::expect_true(is.data.frame(state$provider_failures))
            testthat::expect_identical(nrow(state$provider_failures), 1L)
            testthat::expect_match(as.character(state$provider_failures$error[[1L]]), "bootstrap failed")
        }
    )
})
