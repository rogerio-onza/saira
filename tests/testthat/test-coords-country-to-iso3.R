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

# --- Testes Onda 4 (batch fuzzy equivalence) ---

testthat::test_that("batch fuzzy produces identical results to reference cases", {
    testthat::skip_if_not_installed("countrycode")

    reference_input <- c(
        "Brasil", "Brasiel", "columbia", "xyzxyz", NA, "",
        "united states", "Alemanha", "Frankreich", "zz",
        "Argnetina", "Chlie"
    )
    out <- coords_country_to_iso3(reference_input)

    testthat::expect_equal(length(out), length(reference_input))
    testthat::expect_identical(out[[1]], "BRA")
    testthat::expect_identical(out[[2]], "BRA")
    testthat::expect_identical(out[[3]], "COL")
    testthat::expect_true(is.na(out[[4]]))
    testthat::expect_true(is.na(out[[5]]))
    testthat::expect_true(is.na(out[[6]]))
})

testthat::test_that("adversarial: many unrecognized countries produce no false positives", {
    testthat::skip_if_not_installed("countrycode")
    testthat::skip_on_cran()

    garbage <- c(
        "abcdef", "qqwwee", "zzyyxx", "testtest",
        "notacountry", "randomtext", "foobar",
        "xxxxxxxxx", "1234567890", "!@#$%^&"
    )
    out <- coords_country_to_iso3(garbage)
    testthat::expect_true(all(is.na(out)))
})

testthat::test_that("ambiguous fuzzy matches are rejected", {
    testthat::skip_if_not_installed("countrycode")

    out <- coords_country_to_iso3("Ira")
    testthat::expect_true(is.na(out) || out %in% c("IRN", "IRQ"))
})

testthat::test_that("heterogeneous batch with 50+ countries completes", {
    testthat::skip_if_not_installed("countrycode")
    testthat::skip_on_cran()

    countries <- c(
        "Brasil", "Argentina", "Colombia", "Peru", "Chile",
        "Ecuador", "Venezuela", "Bolivia", "Paraguay", "Uruguay",
        "Mexico", "Cuba", "Jamaica", "Panama", "Costa Rica",
        "Alemanha", "Franca", "Espanha", "Italia", "Portugal",
        "Holanda", "Belgica", "Austria", "Suica", "Noruega",
        "Suecia", "Dinamarca", "Finlandia", "Islandia", "Irlanda",
        "United States", "Canada", "Australia", "New Zealand", "Japan",
        "China", "India", "Russia", "South Africa", "Nigeria",
        "Egypt", "Kenya", "Morocco", "Ghana", "Tanzania",
        "Thailand", "Vietnam", "Indonesia", "Philippines", "Malaysia",
        "xyzgarbage1", "notacountry2", "fakeland3", NA, ""
    )
    out <- coords_country_to_iso3(countries)

    testthat::expect_equal(length(out), length(countries))
    testthat::expect_identical(out[[1]], "BRA")
    testthat::expect_identical(out[[31]], "USA")
    testthat::expect_true(is.na(out[[51]]))
    testthat::expect_true(is.na(out[[54]]))
    testthat::expect_true(is.na(out[[55]]))
})

testthat::test_that("performance: diverse non-recognized tokens within budget", {
    testthat::skip_if_not_installed("countrycode")
    testthat::skip_on_cran()

    invisible(coords_country_to_iso3(c("BRA", "eua")))

    set.seed(42)
    test_vec <- c(
        sample(c("Brasil", "BRA", "Alemanha", "Colombia"), 200, replace = TRUE),
        vapply(seq_len(300), function(i) {
            paste0(sample(letters, 6, replace = TRUE), collapse = "")
        }, FUN.VALUE = character(1))
    )
    elapsed <- system.time(coords_country_to_iso3(test_vec))[["elapsed"]]
    testthat::expect_lt(as.numeric(elapsed), 5)
})
