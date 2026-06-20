# Title: Tests for conservation-status lookups (GBIF IUCN Red List)
# Author: Rogerio Nunes Oliveira
#
# The GBIF calls are mocked at the gbif_api_get / has_httr2 boundary so the
# tests are deterministic and offline: no real network is touched.

testthat::test_that("fetch_gbif_iucn_category returns the code and NA for misses", {
    saira:::gbif_iucn_cache$reset()
    withr::defer(saira:::gbif_iucn_cache$reset())
    testthat::local_mocked_bindings(
        has_httr2 = function() TRUE,
        gbif_api_get = function(segments, query = NULL) {
            key <- segments[[2L]]
            if (identical(key, "111")) {
                list(category = "VULNERABLE", code = "VU")
            } else if (identical(key, "222")) {
                list(category = "NEAR_THREATENED", code = "NT")
            } else {
                NULL # taxon not assessed -> NULL body
            }
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
        gbif_api_get = function(segments, query = NULL) {
            calls <<- calls + 1L
            list(code = "EN")
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
        gbif_api_get = function(segments, query = NULL) {
            if (identical(query$name, "Panthera onca")) list(usageKey = 5219426L) else NULL
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
