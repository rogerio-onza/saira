# Title: Tests for validate coordinates module server
# Author: Codex
# Date: 2026-02-21

testthat::test_that("validate coords blocks execution when country is missing in gate", {
    mapped_df <- data.frame(
        decimalLatitude = c(-10),
        decimalLongitude = c(-50),
        country = c("Brasil"),
        stringsAsFactors = FALSE
    )

    gate_r <- shiny::reactive({
        list(
            coords_status = "missing_country",
            has_data = TRUE,
            lat_col = "decimalLatitude",
            lon_col = "decimalLongitude",
            country_col = "",
            has_lat = TRUE,
            has_lon = TRUE,
            has_country = FALSE
        )
    })

    shiny::testServer(
        mod_validate_coords_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en"),
            validation_gate_r = gate_r
        ),
        {
            returned <- session$getReturned()
            testthat::expect_true(shiny::is.reactive(returned))

            session$setInputs(validate = 1)
            session$flushReact()
            session$flushReact()
            testthat::expect_null(returned())
        }
    )
})

testthat::test_that("validate coords runs with lat/lon/country and respects profile toggle", {
    mapped_df <- data.frame(
        decimalLatitude = c(-10, -11),
        decimalLongitude = c(-50, -51),
        country = c("Brasil", "Brasil"),
        stringsAsFactors = FALSE
    )
    captured_profile <- NULL

    testthat::local_mocked_bindings(
        validate_coords_cc_df = function(df, lat_col, lon_col, country_col, profile, seas_scale) {
            captured_profile <<- profile
            data.frame(
                .row_index = seq_len(nrow(df)),
                lat_num = as.numeric(df[[lat_col]]),
                lon_num = as.numeric(df[[lon_col]]),
                country = as.character(df[[country_col]]),
                country_iso3 = rep("BRA", nrow(df)),
                diagnostic = c("ok", "reference"),
                diagnostic_family = c("ok", "reference"),
                valid = c(TRUE, FALSE),
                stringsAsFactors = FALSE
            )
        },
        .package = "saira"
    )

    gate_r <- shiny::reactive({
        list(
            coords_status = "ok",
            has_data = TRUE,
            lat_col = "decimalLatitude",
            lon_col = "decimalLongitude",
            country_col = "country",
            has_lat = TRUE,
            has_lon = TRUE,
            has_country = TRUE
        )
    })

    shiny::testServer(
        mod_validate_coords_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en"),
            validation_gate_r = gate_r
        ),
        {
            returned <- session$getReturned()
            testthat::expect_true(shiny::is.reactive(returned))

            session$setInputs(validate = 1)
            session$flushReact()
            session$flushReact()
            session$flushReact()
            out <- returned()
            testthat::expect_true(is.data.frame(out))
            testthat::expect_equal(nrow(out), nrow(mapped_df))
            testthat::expect_identical(captured_profile, "complete")

            session$setInputs(coord_profile = "fast")
            session$setInputs(validate = 2)
            session$flushReact()
            session$flushReact()
            session$flushReact()
            testthat::expect_identical(captured_profile, "fast")
        }
    )
})

testthat::test_that("family filter changes filtered output for map and table", {
    mapped_df <- data.frame(
        decimalLatitude = c(-10, -11, -12),
        decimalLongitude = c(-50, -51, -52),
        country = c("Brasil", "Brasil", "Brasil"),
        stringsAsFactors = FALSE
    )

    testthat::local_mocked_bindings(
        validate_coords_cc_df = function(df, lat_col, lon_col, country_col, profile, seas_scale) {
            data.frame(
                .row_index = seq_len(nrow(df)),
                lat_num = as.numeric(df[[lat_col]]),
                lon_num = as.numeric(df[[lon_col]]),
                country = as.character(df[[country_col]]),
                country_iso3 = rep("BRA", nrow(df)),
                diagnostic = c("ok", "reference", "validity_bounds"),
                diagnostic_family = c("ok", "reference", "validity"),
                valid = c(TRUE, FALSE, FALSE),
                stringsAsFactors = FALSE
            )
        },
        .package = "saira"
    )

    gate_r <- shiny::reactive({
        list(
            coords_status = "ok",
            has_data = TRUE,
            lat_col = "decimalLatitude",
            lon_col = "decimalLongitude",
            country_col = "country",
            has_lat = TRUE,
            has_lon = TRUE,
            has_country = TRUE
        )
    })

    shiny::testServer(
        mod_validate_coords_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en"),
            validation_gate_r = gate_r
        ),
        {
            returned <- session$getReturned()
            filtered_r <- attr(returned, "filtered_data")
            testthat::expect_true(shiny::is.reactive(filtered_r))

            session$setInputs(validate = 1)
            session$flushReact()
            session$flushReact()
            session$flushReact()

            problems_filtered <- filtered_r()
            testthat::expect_equal(nrow(problems_filtered), 2L)

            session$setInputs(coords_filter_all = 1)
            session$flushReact()
            all_filtered <- filtered_r()
            testthat::expect_equal(nrow(all_filtered), 3L)

            session$setInputs(coords_filter_reference = 1)
            session$flushReact()
            reference_filtered <- filtered_r()
            testthat::expect_true(all(reference_filtered$diagnostic_family == "reference"))

            session$setInputs(coords_filter_validity = 1)
            session$flushReact()
            validity_filtered <- filtered_r()
            testthat::expect_true(all(validity_filtered$diagnostic_family == "validity"))
        }
    )
})

testthat::test_that("validate coords keeps running when loading modal fails", {
    mapped_df <- data.frame(
        decimalLatitude = c(-10, -11),
        decimalLongitude = c(-50, -51),
        country = c("Brasil", "Brasil"),
        stringsAsFactors = FALSE
    )
    runs <- 0L

    testthat::local_mocked_bindings(
        validate_coords_cc_df = function(df, lat_col, lon_col, country_col, profile, seas_scale) {
            runs <<- runs + 1L
            data.frame(
                .row_index = seq_len(nrow(df)),
                lat_num = as.numeric(df[[lat_col]]),
                lon_num = as.numeric(df[[lon_col]]),
                country = as.character(df[[country_col]]),
                country_iso3 = rep("BRA", nrow(df)),
                diagnostic = rep("ok", nrow(df)),
                diagnostic_family = rep("ok", nrow(df)),
                valid = rep(TRUE, nrow(df)),
                stringsAsFactors = FALSE
            )
        },
        .package = "saira"
    )
    testthat::local_mocked_bindings(
        showModal = function(...) stop("modal failure"),
        .package = "shiny"
    )

    gate_r <- shiny::reactive({
        list(
            coords_status = "ok",
            has_data = TRUE,
            lat_col = "decimalLatitude",
            lon_col = "decimalLongitude",
            country_col = "country",
            has_lat = TRUE,
            has_lon = TRUE,
            has_country = TRUE
        )
    })

    shiny::testServer(
        mod_validate_coords_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en"),
            validation_gate_r = gate_r
        ),
        {
            returned <- session$getReturned()
            testthat::expect_true(shiny::is.reactive(returned))

            session$setInputs(validate = 1)
            session$flushReact()
            session$flushReact()
            session$flushReact()

            out <- returned()
            testthat::expect_true(is.data.frame(out))
            testthat::expect_equal(nrow(out), nrow(mapped_df))
            testthat::expect_equal(runs, 1L)
        }
    )
})
