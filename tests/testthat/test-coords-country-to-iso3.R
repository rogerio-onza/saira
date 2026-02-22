# Title: Tests for country to ISO3 coordinate helper
# Author: Codex
# Date: 2026-02-22

testthat::test_that("coords_country_to_iso3 resolves strict ISO layers", {
    testthat::skip_if_not_installed("countrycode")

    testthat::expect_identical(coords_country_to_iso3("BRA"), "BRA")
    testthat::expect_identical(coords_country_to_iso3("BR"), "BRA")
})

testthat::test_that("coords_country_to_iso3 resolves CLDR and country.name layers", {
    testthat::skip_if_not_installed("countrycode")

    testthat::expect_identical(coords_country_to_iso3("Alemanha"), "DEU")
    testthat::expect_identical(coords_country_to_iso3("Espanha"), "ESP")
    testthat::expect_identical(coords_country_to_iso3("Colombia"), "COL")
    testthat::expect_identical(coords_country_to_iso3("united states of america"), "USA")
})

testthat::test_that("coords_country_to_iso3 resolves custom aliases from rds", {
    testthat::skip_if_not_installed("countrycode")

    testthat::expect_identical(coords_country_to_iso3("eua"), "USA")
    testthat::expect_identical(coords_country_to_iso3("holanda"), "NLD")
    testthat::expect_identical(coords_country_to_iso3("uk"), "GBR")
})

testthat::test_that("coords_country_to_iso3 uses conservative fuzzy matching", {
    testthat::skip_if_not_installed("countrycode")

    testthat::expect_identical(coords_country_to_iso3("columbia"), "COL")
    testthat::expect_identical(coords_country_to_iso3("bresil"), "BRA")
    testthat::expect_true(is.na(coords_country_to_iso3("xyzxyz")))
    testthat::expect_true(is.na(coords_country_to_iso3("zz")))
})

testthat::test_that("coords_country_to_iso3 preserves cardinality and order", {
    testthat::skip_if_not_installed("countrycode")

    input <- c("BR", "eua", "Alemanha", "", NA_character_, "xyzxyz")
    out <- coords_country_to_iso3(input)

    testthat::expect_equal(length(out), length(input))
    testthat::expect_identical(out[[1]], "BRA")
    testthat::expect_identical(out[[2]], "USA")
    testthat::expect_identical(out[[3]], "DEU")
    testthat::expect_true(is.na(out[[4]]))
    testthat::expect_true(is.na(out[[5]]))
})

testthat::test_that("coords_country_to_iso3 handles repeated vectors within budget", {
    testthat::skip_if_not_installed("countrycode")
    testthat::skip_on_cran()

    # Warm-up to populate caches and reduce machine-dependent variance.
    invisible(coords_country_to_iso3(c("BRA", "eua", "Alemanha")))

    countries <- sample(c("BRA", "eua", "Alemanha"), 10000, replace = TRUE)
    elapsed <- system.time(coords_country_to_iso3(countries))[["elapsed"]]
    testthat::expect_lt(as.numeric(elapsed), 2)
})
