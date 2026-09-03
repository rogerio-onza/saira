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

testthat::test_that("upstream reset signal clears coordinate corrections and result", {
    mapped_df <- data.frame(
        decimalLatitude = c(-10),
        decimalLongitude = c(-50),
        country = c("Brasil"),
        stringsAsFactors = FALSE
    )
    signal <- shiny::reactiveVal(0L)

    shiny::testServer(
        mod_validate_coords_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en"),
            reset_signal_r = signal
        ),
        {
            # Seed a completed run with pending/applied corrections.
            coord_validation_r(mapped_df)
            rv$coords_corrections <- list(corrections = data.frame(occurrenceID = "1"))
            rv$country_fills <- list(country = data.frame(occurrenceID = "1"))
            rv$transposed_applied <- TRUE
            rv$stream_filter <- "problems"
            session$flushReact()

            signal(1L)
            session$flushReact()

            testthat::expect_null(coord_validation_r())
            testthat::expect_null(rv$coords_corrections)
            testthat::expect_null(rv$country_fills)
            testthat::expect_false(rv$transposed_applied)
            testthat::expect_identical(rv$stream_filter, "all")
        }
    )
})

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

testthat::test_that("UTM conversion writes a corrections payload for the picked zone", {
    # Easting filed under decimalLatitude, northing under decimalLongitude:
    # the shape a spreadsheet produces when it publishes projected coordinates.
    mapped_df <- data.frame(
        occurrenceID = c("occ-1", "occ-2"),
        decimalLatitude = c(574699, 578357),
        decimalLongitude = c(7805441, 7800408),
        country = c("Brasil", "Brasil"),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_validate_coords_server,
        args = list(
            mapped_data_r = shiny::reactive(mapped_df),
            lang_r = shiny::reactive("en")
        ),
        {
            rv$validation_occ_ids <- mapped_df$occurrenceID
            rv$utm_rows <- 1:2
            rv$utm_axes <- coords_utm_assign_axes(
                mapped_df$decimalLatitude, mapped_df$decimalLongitude
            )
            session$setInputs(utm_zone = "21", utm_datum = "SIRGAS2000")
            session$flushReact()

            converted <- utm_converted_r()
            testthat::expect_identical(nrow(converted), 2L)
            testthat::expect_identical(converted$occurrenceID, c("occ-1", "occ-2"))
            testthat::expect_equal(converted$decimalLatitude[[1]], -19.84565, tolerance = 1e-4)
            testthat::expect_equal(converted$decimalLongitude[[1]], -56.28660, tolerance = 1e-4)

            session$setInputs(apply_utm = 1)
            session$flushReact()

            testthat::expect_true(isTRUE(rv$utm_applied))
            payload <- rv$coords_corrections$corrections
            testthat::expect_identical(nrow(payload), 2L)
            testthat::expect_true(all(c("occurrenceID", "decimalLatitude", "decimalLongitude") %in% names(payload)))

            # The projected pair and the picked system travel with the payload,
            # so the original reading survives the overwrite (ADR-122). Axes go
            # to the term they mean: the northing is the latitude, even though
            # the upload filed it under decimalLongitude.
            testthat::expect_identical(payload$verbatimLatitude, c("7805441", "7800408"))
            testthat::expect_identical(payload$verbatimLongitude, c("574699", "578357"))
            testthat::expect_identical(unique(payload$verbatimCoordinateSystem), "UTM zone 21S")
            testthat::expect_identical(unique(payload$verbatimSRS), "EPSG:31981")

            # Picking another zone moves the points six degrees of longitude.
            session$setInputs(utm_zone = "22")
            session$flushReact()
            testthat::expect_equal(
                utm_converted_r()$decimalLongitude[[1]], -50.28660, tolerance = 1e-4
            )
        }
    )
})
