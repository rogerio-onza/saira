# Title: Tests for CoordinateCleaner coordinate pipeline
# Author: Codex
# Date: 2026-02-21

testthat::test_that("coords_load_aliases validates force flag via canonical validator", {
    coords_load_aliases <- getFromNamespace("coords_load_aliases", "saira")

    testthat::expect_error(coords_load_aliases(force = NA), "force must be a single TRUE or FALSE value")
    testthat::expect_error(coords_load_aliases(force = c(TRUE, FALSE)), "force must be a single TRUE or FALSE value")
    testthat::expect_error(coords_load_aliases(force = "TRUE"), "force must be a single TRUE or FALSE value")
})

testthat::test_that("validate_coords_cc_df handles empty pipeline", {
    testthat::local_mocked_bindings(
        coords_assert_cc_dependencies = function() NULL,
        coords_country_to_iso3 = function(country_values) rep(NA_character_, length(country_values)),
        .package = "saira"
    )

    df <- data.frame(
        decimalLatitude = numeric(0),
        decimalLongitude = numeric(0),
        country = character(0),
        stringsAsFactors = FALSE
    )

    out <- validate_coords_cc_df(
        df = df,
        lat_col = "decimalLatitude",
        lon_col = "decimalLongitude",
        country_col = "country",
        profile = "complete",
        seas_scale = 110L
    )

    testthat::expect_s3_class(out, "data.frame")
    testthat::expect_equal(nrow(out), 0L)
    testthat::expect_true(all(c("diagnostic", "diagnostic_family", "country_iso3") %in% names(out)))
})

testthat::test_that("validate_coords_cc_df parses decimal comma and preserves cardinality", {
    testthat::local_mocked_bindings(
        coords_assert_cc_dependencies = function() NULL,
        coords_country_to_iso3 = function(country_values) rep("BRA", length(country_values)),
        coords_cc_flagged = function(fun_name, x, ...) rep(TRUE, nrow(x)),
        .package = "saira"
    )

    df <- data.frame(
        decimalLatitude = c("-23,55", "10,10"),
        decimalLongitude = c("-46,63", "-50,10"),
        country = c("Brasil", "Brasil"),
        stringsAsFactors = FALSE
    )

    out <- validate_coords_cc_df(
        df = df,
        lat_col = "decimalLatitude",
        lon_col = "decimalLongitude",
        country_col = "country"
    )

    testthat::expect_equal(nrow(out), nrow(df))
    testthat::expect_equal(out$lat_num[[1]], -23.55)
    testthat::expect_equal(out$lon_num[[1]], -46.63)
    testthat::expect_identical(out$diagnostic, c("ok", "ok"))
})

testthat::test_that("validate_coords_cc_df resolves country_iso3 but does not emit country diagnostics", {
    testthat::skip_if_not_installed("countrycode")
    testthat::local_mocked_bindings(
        coords_assert_cc_dependencies = function() NULL,
        coords_cc_flagged = function(fun_name, x, ...) rep(TRUE, nrow(x)),
        .package = "saira"
    )

    df <- data.frame(
        decimalLatitude = c(-10, -11),
        decimalLongitude = c(-50, -51),
        country = c("Brasil", "Atlantida"),
        stringsAsFactors = FALSE
    )

    out <- validate_coords_cc_df(
        df = df,
        lat_col = "decimalLatitude",
        lon_col = "decimalLongitude",
        country_col = "country"
    )

    testthat::expect_identical(out$country_iso3[[1]], "BRA")
    testthat::expect_true(is.na(out$country_iso3[[2]]) || !nzchar(out$country_iso3[[2]]))
    testthat::expect_identical(out$diagnostic[[2]], "ok")
})

testthat::test_that("validate_coords_cc_df flags validity_missing and validity_bounds", {
    testthat::local_mocked_bindings(
        coords_assert_cc_dependencies = function() NULL,
        coords_country_to_iso3 = function(country_values) rep("BRA", length(country_values)),
        coords_cc_flagged = function(fun_name, x, ...) rep(TRUE, nrow(x)),
        .package = "saira"
    )

    df <- data.frame(
        decimalLatitude = c(NA_real_, 10, 120),
        decimalLongitude = c(-45, 200, -20),
        country = c("Brasil", "Brasil", "Brasil"),
        stringsAsFactors = FALSE
    )

    out <- validate_coords_cc_df(
        df = df,
        lat_col = "decimalLatitude",
        lon_col = "decimalLongitude",
        country_col = "country"
    )

    testthat::expect_identical(out$diagnostic[[1]], "validity_missing")
    testthat::expect_identical(out$diagnostic[[2]], "validity_bounds")
    testthat::expect_identical(out$diagnostic[[3]], "swapped")
})

testthat::test_that("validate_coords_cc_df maps cc flags to sea, zero_equal and reference", {
    testthat::local_mocked_bindings(
        coords_assert_cc_dependencies = function() NULL,
        coords_country_to_iso3 = function(country_values) rep("BRA", length(country_values)),
        coords_cc_flagged = function(fun_name, x, ...) {
            n <- nrow(x)
            if (fun_name == "cc_val") return(rep(TRUE, n))
            if (fun_name == "cc_sea") return(c(TRUE, FALSE, TRUE, TRUE, TRUE))
            if (fun_name == "cc_zero") return(c(TRUE, TRUE, FALSE, TRUE, TRUE))
            if (fun_name == "cc_equ") return(rep(TRUE, n))
            if (fun_name == "cc_cap") return(c(TRUE, TRUE, TRUE, FALSE, TRUE))
            if (fun_name %in% c("cc_cen", "cc_gbif", "cc_inst")) return(rep(TRUE, n))
            rep(TRUE, n)
        },
        .package = "saira"
    )

    df <- data.frame(
        decimalLatitude = c(-10, -11, -12, -13, -14),
        decimalLongitude = c(-50, -51, -52, -53, -54),
        country = rep("Brasil", 5),
        stringsAsFactors = FALSE
    )

    out <- validate_coords_cc_df(
        df = df,
        lat_col = "decimalLatitude",
        lon_col = "decimalLongitude",
        country_col = "country",
        profile = "complete"
    )

    testthat::expect_identical(out$diagnostic, c("ok", "sea", "zero_equal", "reference", "ok"))
    testthat::expect_identical(out$diagnostic_family, c("ok", "sea", "zero_equal", "reference", "ok"))
})

testthat::test_that("validate_coords_cc_df preserves swapped and identical_all heuristics", {
    testthat::local_mocked_bindings(
        coords_assert_cc_dependencies = function() NULL,
        coords_country_to_iso3 = function(country_values) rep("BRA", length(country_values)),
        coords_cc_flagged = function(fun_name, x, ...) rep(TRUE, nrow(x)),
        .package = "saira"
    )

    df_swapped <- data.frame(
        decimalLatitude = c(120, -10),
        decimalLongitude = c(-30, -50),
        country = c("Brasil", "Brasil"),
        stringsAsFactors = FALSE
    )
    out_swapped <- validate_coords_cc_df(
        df = df_swapped,
        lat_col = "decimalLatitude",
        lon_col = "decimalLongitude",
        country_col = "country"
    )
    testthat::expect_identical(out_swapped$diagnostic[[1]], "swapped")

    df_identical <- data.frame(
        decimalLatitude = c(-10, -10, -10),
        decimalLongitude = c(-50, -50, -50),
        country = c("Brasil", "Brasil", "Brasil"),
        stringsAsFactors = FALSE
    )
    out_identical <- validate_coords_cc_df(
        df = df_identical,
        lat_col = "decimalLatitude",
        lon_col = "decimalLongitude",
        country_col = "country"
    )
    testthat::expect_true(all(out_identical$diagnostic == "identical_all"))
})

testthat::test_that("validate_coords_cc_df prioritizes sea without country diagnostics", {
    testthat::local_mocked_bindings(
        coords_assert_cc_dependencies = function() NULL,
        coords_country_to_iso3 = function(country_values) rep(NA_character_, length(country_values)),
        coords_cc_flagged = function(fun_name, x, ...) {
            if (fun_name %in% c("cc_sea", "cc_zero", "cc_equ")) {
                return(rep(FALSE, nrow(x)))
            }
            rep(TRUE, nrow(x))
        },
        .package = "saira"
    )

    df <- data.frame(
        decimalLatitude = c(-10),
        decimalLongitude = c(-50),
        country = c("Desconhecido"),
        stringsAsFactors = FALSE
    )

    out <- validate_coords_cc_df(
        df = df,
        lat_col = "decimalLatitude",
        lon_col = "decimalLongitude",
        country_col = "country"
    )

    testthat::expect_identical(out$diagnostic[[1]], "sea")
    testthat::expect_identical(out$diagnostic_family[[1]], "sea")
    testthat::expect_equal(nrow(out), nrow(df))
})

testthat::test_that("validate_coords_cc_df keeps cardinality for mixed scenarios", {
    testthat::local_mocked_bindings(
        coords_assert_cc_dependencies = function() NULL,
        coords_country_to_iso3 = function(country_values) rep("BRA", length(country_values)),
        coords_cc_flagged = function(fun_name, x, ...) rep(TRUE, nrow(x)),
        .package = "saira"
    )

    df <- data.frame(
        decimalLatitude = c(-10, -11, NA_real_, 140),
        decimalLongitude = c(-50, -51, -52, -30),
        country = c("Brasil", "Brasil", "Brasil", "Brasil"),
        stringsAsFactors = FALSE
    )

    out <- validate_coords_cc_df(
        df = df,
        lat_col = "decimalLatitude",
        lon_col = "decimalLongitude",
        country_col = "country",
        profile = "fast"
    )

    testthat::expect_equal(nrow(out), nrow(df))
})

testthat::test_that("performance budget for profile fast and complete (mocked CC)", {
    testthat::skip_on_cran()
    testthat::local_mocked_bindings(
        coords_assert_cc_dependencies = function() NULL,
        coords_country_to_iso3 = function(country_values) rep("BRA", length(country_values)),
        coords_cc_flagged = function(fun_name, x, ...) rep(TRUE, nrow(x)),
        .package = "saira"
    )

    n <- 100000L
    df <- data.frame(
        decimalLatitude = stats::runif(n, -20, 20),
        decimalLongitude = stats::runif(n, -60, -30),
        country = rep("Brasil", n),
        stringsAsFactors = FALSE
    )

    elapsed_fast <- system.time({
        out_fast <- validate_coords_cc_df(
            df = df,
            lat_col = "decimalLatitude",
            lon_col = "decimalLongitude",
            country_col = "country",
            profile = "fast"
        )
    })[["elapsed"]]

    elapsed_complete <- system.time({
        out_complete <- validate_coords_cc_df(
            df = df,
            lat_col = "decimalLatitude",
            lon_col = "decimalLongitude",
            country_col = "country",
            profile = "complete"
        )
    })[["elapsed"]]

    testthat::expect_equal(nrow(out_fast), n)
    testthat::expect_equal(nrow(out_complete), n)
    testthat::expect_lte(as.numeric(elapsed_fast), 10)
    testthat::expect_lte(as.numeric(elapsed_complete), 20)
})
