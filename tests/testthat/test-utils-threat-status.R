# Title: Tests for conservation-status lookups (IUCN Red List from COL XR)
# Author: Rogerio Nunes Oliveira
#
# The GBIF calls are mocked at the gbif_api_get_many boundary with recorded
# COL XR responses, so the tests are deterministic and offline.

colxr_fixture_bodies <- function(requests) {
    lapply(requests, function(r) {
        file <- testthat::test_path(
            "fixtures", "colxr", paste0(gsub(" ", "_", r$query$scientificName), ".json")
        )
        if (file.exists(file)) jsonlite::read_json(file) else NULL
    })
}

testthat::test_that("colxr_iucn_category reads the code and uses the accepted name of a synonym", {
    saira:::colxr_match_cache$reset()
    withr::defer(saira:::colxr_match_cache$reset())
    testthat::local_mocked_bindings(gbif_api_get_many = colxr_fixture_bodies, .package = "saira")

    out <- saira:::colxr_iucn_category(
        c("Panthera onca", "Caesalpinia echinata", "Rhea americana americana", "Pantera onca", NA, "")
    )
    # Caesalpinia echinata is a synonym: the EN of Paubrasilia echinata applies.
    testthat::expect_equal(out, c("NT", "EN", NA, NA, NA, NA))
})

testthat::test_that("colxr_iucn_category gives NA when GBIF does not answer", {
    saira:::colxr_match_cache$reset()
    withr::defer(saira:::colxr_match_cache$reset())
    testthat::local_mocked_bindings(
        gbif_api_get_many = function(requests) vector("list", length(requests)),
        .package = "saira"
    )
    testthat::expect_equal(saira:::colxr_iucn_category(c("Panthera onca", "Sapajus apella")), c(NA_character_, NA_character_))
    testthat::expect_equal(saira:::colxr_iucn_category(character(0)), character(0))
})

# Runs the Export IUCN lookup to its end. `fetch_for` gets the misses of each
# batch, as names_worker_fetch() does.
run_iucn_lookup <- function(names, fetch_for, max_ticks = 50L) {
    state <- saira:::iucn_lookup_new(names, run_id = "test")
    for (i in seq_len(max_ticks)) {
        if (identical(state$phase, "done")) break
        state <- saira:::iucn_lookup_step(state, fetch_for)
    }
    state
}

testthat::test_that("the Export IUCN lookup gives the codes of accepted names and synonyms", {
    saira:::colxr_match_cache$reset()
    withr::defer(saira:::colxr_match_cache$reset())
    sent <- character(0)
    fetch_for <- function(misses) {
        sent <<- c(sent, misses)
        colxr_fixture_bodies
    }
    state <- run_iucn_lookup(c("Panthera onca", "Caesalpinia echinata", "Pantera onca", NA, ""), fetch_for)
    testthat::expect_identical(state$phase, "done")
    # Caesalpinia echinata is a synonym: the EN of Paubrasilia echinata applies.
    testthat::expect_identical(
        state$snapshot,
        c("Panthera onca" = "NT", "Caesalpinia echinata" = "EN", "Pantera onca" = NA)
    )
    testthat::expect_length(state$unanswered, 0L)
    testthat::expect_setequal(sent, c("Panthera onca", "Caesalpinia echinata", "Pantera onca",
                                      "Paubrasilia echinata"))

    # The download step reads the snapshot and sends no request.
    testthat::local_mocked_bindings(
        gbif_api_get_many = function(requests) stop("no request expected"),
        .package = "saira"
    )
    df <- data.frame(scientificName = c("Caesalpinia echinata", "Panthera onca", "Pantera onca"))
    out <- saira:::apply_conservation_status(
        df, list(include_iucn = TRUE, iucn_by_name = state$snapshot)
    )
    testthat::expect_identical(
        out$dynamicProperties,
        c("{\"iucnRedListCategory\":\"EN\"}", "{\"iucnRedListCategory\":\"NT\"}", "")
    )
})

testthat::test_that("the Export IUCN lookup asks a name without an answer once per run", {
    saira:::colxr_match_cache$reset()
    withr::defer(saira:::colxr_match_cache$reset())
    sent <- character(0)
    fetch_for <- function(misses) {
        sent <<- c(sent, misses)
        saira:::gbif_offline_fetch
    }
    names <- paste("Genus", sprintf("sp%02d", 1:25))
    state <- run_iucn_lookup(names, fetch_for)
    testthat::expect_identical(state$phase, "done")
    testthat::expect_identical(sort(sent), sort(names))
    testthat::expect_setequal(state$unanswered, names)
    testthat::expect_true(all(is.na(state$snapshot)))
    # A batch in flight leaves the state as it is.
    pending <- saira:::iucn_lookup_new(names, run_id = "test")
    testthat::expect_identical(saira:::iucn_lookup_step(pending, function(misses) NULL), pending)
    testthat::expect_identical(saira:::iucn_lookup_progress(pending), list(done = 0L, total = 25L))
})

testthat::test_that("the Export IUCN lookup repeats no query of a Names run", {
    saira:::colxr_match_cache$reset()
    withr::defer(saira:::colxr_match_cache$reset())
    saira:::colxr_match_names(c("Panthera onca", "Caesalpinia echinata"), fetch = colxr_fixture_bodies)
    sent <- character(0)
    fetch_for <- function(misses) {
        sent <<- c(sent, misses)
        colxr_fixture_bodies
    }
    state <- run_iucn_lookup(c("Panthera onca", "Caesalpinia echinata"), fetch_for)
    # Only the accepted name of the synonym was not in the memo.
    testthat::expect_identical(sent, "Paubrasilia echinata")
    testthat::expect_identical(state$snapshot, c("Panthera onca" = "NT", "Caesalpinia echinata" = "EN"))
})

testthat::test_that("gbif_api_get_many keeps order, drops non-200 and retries a 429", {
    testthat::skip_if_not_installed("httr2", minimum_version = "1.1.1")
    tries <- list()
    httr2::local_mocked_responses(function(req) {
        key <- basename(dirname(req$url))
        tries[[key]] <<- (tries[[key]] %||% 0L) + 1L
        if (identical(key, "404")) {
            return(httr2::response(status_code = 404L))
        }
        if (identical(key, "429") && tries[[key]] == 1L) {
            return(httr2::response(status_code = 429L, headers = list(`Retry-After` = "0")))
        }
        httr2::response_json(body = list(code = key))
    })
    requests <- lapply(c("111", "404", "429"), function(k) {
        list(segments = c("species", k, "iucnRedListCategory"))
    })
    out <- saira:::gbif_api_get_many(requests)
    testthat::expect_length(out, 3L)
    testthat::expect_equal(out[[1L]]$code, "111")
    testthat::expect_null(out[[2L]])
    testthat::expect_equal(out[[3L]]$code, "429")
    testthat::expect_equal(tries[["429"]], 2L)
})
