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
