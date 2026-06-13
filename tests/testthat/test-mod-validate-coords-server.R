# Title: Tests for validate coordinates module server
# Author: Codex
# Date: 2026-02-21

flush_validation_cycle <- function(session, n = 4L) {
    for (idx in seq_len(n)) {
        session$flushReact()
    }
}

prime_validate_button <- function(session) {
    session$setInputs(validate = 0)
    session$flushReact()
}

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

            prime_validate_button(session)
            session$setInputs(validate = 1)
            flush_validation_cycle(session, 3L)
            testthat::expect_null(returned())
        }
    )
})

testthat::test_that("validate coords does not auto-run on initialization", {
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

            prime_validate_button(session)
            flush_validation_cycle(session, 3L)

            testthat::expect_null(returned())
            testthat::expect_equal(runs, 0L)
        }
    )
})

testthat::test_that("validate coords runs with lat/lon/country and always uses the complete profile", {
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

            prime_validate_button(session)
            session$setInputs(validate = 1)
            flush_validation_cycle(session)
            out <- returned()
            testthat::expect_true(is.data.frame(out))
            testthat::expect_equal(nrow(out), nrow(mapped_df))
            # The quick/fast profile was removed; validation is always complete.
            testthat::expect_identical(captured_profile, "complete")
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

            prime_validate_button(session)
            session$setInputs(validate = 1)
            flush_validation_cycle(session)

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

            prime_validate_button(session)
            session$setInputs(validate = 1)
            flush_validation_cycle(session)

            out <- returned()
            testthat::expect_true(is.data.frame(out))
            testthat::expect_equal(nrow(out), nrow(mapped_df))
            testthat::expect_equal(runs, 1L)
        }
    )
})
