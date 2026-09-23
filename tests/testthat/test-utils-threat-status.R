# Title: Tests for conservation-status lookups (GBIF IUCN Red List)
# Author: Rogerio Nunes Oliveira
#
# The GBIF calls are mocked at the gbif_api_get_many / has_httr2 boundary so the
# tests are deterministic and offline: no real network is touched.

testthat::test_that("fetch_gbif_iucn_category returns the code and NA for misses", {
    saira:::gbif_iucn_cache$reset()
    withr::defer(saira:::gbif_iucn_cache$reset())
    testthat::local_mocked_bindings(
        has_httr2 = function() TRUE,
        gbif_api_get_many = function(requests) {
            lapply(requests, function(r) {
                key <- r$segments[[2L]]
                if (identical(key, "111")) {
                    list(category = "VULNERABLE", code = "VU")
                } else if (identical(key, "222")) {
                    list(category = "NEAR_THREATENED", code = "NT")
                } else {
                    NULL # taxon not assessed -> NULL body
                }
            })
        },
        .package = "saira"
    )
    out <- saira:::fetch_gbif_iucn_category(c("111", "222", "999", NA))
    testthat::expect_equal(out, c("VU", "NT", NA, NA))
})

testthat::test_that("fetch_gbif_iucn_category memoizes each usageKey once", {
    saira:::gbif_iucn_cache$reset()
    withr::defer(saira:::gbif_iucn_cache$reset())
    calls <- 0L
    testthat::local_mocked_bindings(
        has_httr2 = function() TRUE,
        gbif_api_get_many = function(requests) {
            calls <<- calls + length(requests)
            lapply(requests, function(r) list(code = "EN"))
        },
        .package = "saira"
    )
    saira:::fetch_gbif_iucn_category(c("500", "500"))
    saira:::fetch_gbif_iucn_category("500")
    testthat::expect_equal(calls, 1L)
})

testthat::test_that("fetch_gbif_iucn_category yields all NA when httr2 is absent", {
    saira:::gbif_iucn_cache$reset()
    withr::defer(saira:::gbif_iucn_cache$reset())
    testthat::local_mocked_bindings(has_httr2 = function() FALSE, .package = "saira")
    out <- saira:::fetch_gbif_iucn_category(c("111", "222"))
    testthat::expect_true(all(is.na(out)))
})

testthat::test_that("fetch_gbif_iucn_category handles empty input", {
    testthat::expect_equal(saira:::fetch_gbif_iucn_category(character(0)), character(0))
})

testthat::test_that("gbif_match_usage_keys resolves names to usage keys", {
    saira:::gbif_match_cache$reset()
    withr::defer(saira:::gbif_match_cache$reset())
    testthat::local_mocked_bindings(
        has_httr2 = function() TRUE,
        gbif_api_get_many = function(requests) {
            lapply(requests, function(r) {
                if (identical(r$query$name, "Panthera onca")) list(usageKey = 5219426L) else NULL
            })
        },
        .package = "saira"
    )
    out <- saira:::gbif_match_usage_keys(c("Panthera onca", "Nonexistent sp", NA))
    testthat::expect_equal(out, c("5219426", NA, NA))
})

testthat::test_that("gbif_match_usage_keys yields all NA when httr2 is absent", {
    saira:::gbif_match_cache$reset()
    withr::defer(saira:::gbif_match_cache$reset())
    testthat::local_mocked_bindings(has_httr2 = function() FALSE, .package = "saira")
    testthat::expect_true(all(is.na(saira:::gbif_match_usage_keys(c("A b", "C d")))))
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

testthat::test_that("gbif_api_get_many returns NULL bodies without httr2", {
    testthat::local_mocked_bindings(has_httr2 = function() FALSE, .package = "saira")
    out <- saira:::gbif_api_get_many(list(list(segments = "x"), list(segments = "y")))
    testthat::expect_equal(out, list(NULL, NULL))
})
