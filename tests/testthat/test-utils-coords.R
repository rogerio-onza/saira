# Title: Tests for CoordinateCleaner coordinate pipeline
# Author: Codex
# Date: 2026-02-21

testthat::test_that("coords_load_aliases validates force flag via canonical validator", {
    coords_load_aliases <- saira:::coords_load_aliases

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
    # Wall-clock budget assertions are machine-speed sensitive and would
    # false-fail on slower end-user hardware running devtools::test()/check().
    # Opt-in only, consistent with test-performance-regression.R.
    if (!identical(Sys.getenv("RUN_PERF"), "true")) {
        testthat::skip("Performance budget disabled by default. Use RUN_PERF=true to execute.")
    }
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

# --- coords_load_ne_land ---

clear_land_cache_key <- function(key) {
    old_val <- ne_land_env[[key]]
    list(
        old = old_val,
        restore = function() {
            if (is.null(old_val)) {
                if (exists(key, envir = ne_land_env, inherits = FALSE)) {
                    rm(list = key, envir = ne_land_env)
                }
            } else {
                ne_land_env[[key]] <<- old_val
            }
        }
    )
}

testthat::test_that("coords_load_ne_land loads embedded Americas reference for scale 10", {
    state <- clear_land_cache_key("land_10")
    on.exit(state$restore(), add = TRUE)

    entry <- coords_get_ne_land_entry(10L, download = FALSE)
    testthat::expect_type(entry, "list")
    testthat::expect_identical(entry$source, "embedded_americas_10m")
    testthat::expect_true(inherits(entry$ref, "SpatVector"))
    testthat::expect_true(inherits(entry$coverage_ref, "SpatVector"))
    testthat::expect_true(is.data.frame(entry$coverage_boxes))
    testthat::expect_true(nrow(entry$coverage_boxes) >= 1L)
    testthat::expect_true(file.exists(entry$path))
})

testthat::test_that("coords_load_ne_land uses in-memory cache on second call", {
    fake_entry <- list(
        ref = "sentinel_ref",
        coverage_ref = "sentinel_coverage",
        coverage_boxes = data.frame(xmin = 0, xmax = 1, ymin = 0, ymax = 1),
        source = "mock",
        path = NA_character_
    )
    key <- "land_50"
    state <- clear_land_cache_key(key)
    on.exit(state$restore(), add = TRUE)

    ne_land_env[[key]] <- fake_entry
    result <- coords_load_ne_land(50L)
    testthat::expect_identical(result, "sentinel_ref")
})

testthat::test_that("coords_points_in_coverage uses polygon coverage before bbox fallback", {
    coverage_ref <- terra::vect(sf::st_as_sf(
        data.frame(
            id = 1L,
            wkt = "POLYGON ((-60 -10, -40 -10, -40 10, -60 10, -60 -10))",
            stringsAsFactors = FALSE
        ),
        wkt = "wkt",
        crs = 4326
    ))

    x <- data.frame(
        decimalLatitude = c(0, 0, 50),
        decimalLongitude = c(-50, -20, 50),
        stringsAsFactors = FALSE
    )
    inside <- coords_points_in_coverage(
        x,
        coverage_ref = coverage_ref,
        coverage_boxes = data.frame(xmin = -5, xmax = 5, ymin = -5, ymax = 5)
    )
    testthat::expect_identical(inside, c(TRUE, FALSE, FALSE))
})

testthat::test_that("coords_cc_sea_flagged splits embedded Americas and global fallback rows", {
    calls <- list()

    testthat::local_mocked_bindings(
        coords_load_ne_land = function(scale, download = TRUE) {
            if (identical(as.integer(scale), 10L)) "ref10" else "ref50"
        },
        coords_ne_land_coverage_ref = function(scale = 10L, download = TRUE) "coverage10",
        coords_ne_land_coverage_boxes = function(scale = 10L, download = TRUE) NULL,
        coords_points_in_coverage = function(x, coverage_ref = NULL, coverage_boxes = NULL, margin = 0) {
            c(TRUE, FALSE, TRUE)
        },
        coords_cc_sea_run = function(x, ref = NULL, scale = NULL, timeout = NULL, crop_ref = FALSE) {
            calls[[length(calls) + 1L]] <<- list(ref = ref, scale = scale, n = nrow(x), crop_ref = crop_ref, timeout = timeout)
            if (identical(ref, "ref10")) {
                return(c(FALSE, TRUE))
            }
            rep(TRUE, nrow(x))
        },
        .package = "saira"
    )

    x <- data.frame(
        decimalLatitude = c(-10, 40, -11),
        decimalLongitude = c(-50, 20, -51),
        stringsAsFactors = FALSE
    )

    flagged <- coords_cc_sea_flagged(x, scale = 10L)
    testthat::expect_identical(flagged, c(FALSE, TRUE, TRUE))
    testthat::expect_length(calls, 2L)
    testthat::expect_identical(calls[[1]]$ref, "ref10")
    testthat::expect_true(isTRUE(calls[[1]]$crop_ref))
    testthat::expect_identical(calls[[2]]$ref, "ref50")
    testthat::expect_false(isTRUE(calls[[2]]$crop_ref))
})

testthat::test_that("coords_cc_sea_flagged falls back to scale 50 globally when embedded reference is missing", {
    calls <- list()

    testthat::local_mocked_bindings(
        coords_load_ne_land = function(scale, download = TRUE) {
            if (identical(as.integer(scale), 10L)) NULL else "ref50"
        },
        coords_ne_land_coverage_ref = function(scale = 10L, download = TRUE) NULL,
        coords_ne_land_coverage_boxes = function(scale = 10L, download = TRUE) NULL,
        coords_cc_sea_run = function(x, ref = NULL, scale = NULL, timeout = NULL, crop_ref = FALSE) {
            calls[[length(calls) + 1L]] <<- list(ref = ref, scale = scale, n = nrow(x))
            rep(FALSE, nrow(x))
        },
        .package = "saira"
    )

    x <- data.frame(
        decimalLatitude = c(-10, 10),
        decimalLongitude = c(-50, -51),
        stringsAsFactors = FALSE
    )

    flagged <- coords_cc_sea_flagged(x, scale = 10L)
    testthat::expect_identical(flagged, c(FALSE, FALSE))
    testthat::expect_length(calls, 1L)
    testthat::expect_identical(calls[[1]]$ref, "ref50")
    testthat::expect_identical(calls[[1]]$scale, 50L)
})

testthat::test_that("coords_crop_land_ref reduces geometry without changing cc_sea result", {
    testthat::skip_if_not_installed("CoordinateCleaner")
    ref <- coords_load_ne_land(10L, download = FALSE)
    testthat::expect_true(inherits(ref, "SpatVector"))

    pts <- data.frame(
        decimalLongitude = c(-48.5, -43.2, -60.1, -38.7, -34.9, -46.0),
        decimalLatitude = c(-26.2, -23.0, -3.1, -12.5, -7.9, -15.8),
        stringsAsFactors = FALSE
    )
    cropped <- coords_crop_land_ref(ref, pts)

    testthat::expect_lt(nrow(terra::geom(cropped)), nrow(terra::geom(ref)))
    full_flag <- coords_cc_flagged(
        "cc_sea",
        pts,
        lon = "decimalLongitude",
        lat = "decimalLatitude",
        ref = ref
    )
    cropped_flag <- coords_cc_flagged(
        "cc_sea",
        pts,
        lon = "decimalLongitude",
        lat = "decimalLatitude",
        ref = cropped
    )
    testthat::expect_identical(full_flag, cropped_flag)
})

testthat::test_that("embedded Americas reference keeps French Guiana sample points on land", {
    testthat::skip_if_not_installed("CoordinateCleaner")
    ref <- coords_load_ne_land(10L, download = FALSE)
    testthat::expect_true(inherits(ref, "SpatVector"))

    pts <- data.frame(
        decimalLongitude = c(-54.5, -53.5, -52.5, -53.0),
        decimalLatitude = c(4.0, 4.5, 4.0, 3.0),
        stringsAsFactors = FALSE
    )

    flagged <- coords_cc_flagged(
        "cc_sea",
        pts,
        lon = "decimalLongitude",
        lat = "decimalLatitude",
        ref = ref
    )
    testthat::expect_true(all(flagged))
})

testthat::test_that("coords_normalize_cc_sea_timeout is opt-in and reads env var", {
    testthat::expect_null(coords_normalize_cc_sea_timeout())

    withr::with_envvar(list(SAIRA_CC_SEA_TIMEOUT = "999"), {
        testthat::expect_equal(coords_normalize_cc_sea_timeout(), 999)
    })
})

testthat::test_that("coords_cc_sea_flagged passes explicit timeout when env var is set", {
    timeout_used <- NULL
    testthat::local_mocked_bindings(
        coords_load_ne_land = function(scale, download = TRUE) "ref50",
        coords_cc_sea_run = function(x, ref = NULL, scale = NULL, timeout = NULL, crop_ref = FALSE) {
            timeout_used <<- timeout
            rep(TRUE, nrow(x))
        },
        .package = "saira"
    )

    x <- data.frame(
        decimalLatitude = -10,
        decimalLongitude = -50,
        stringsAsFactors = FALSE
    )

    withr::with_envvar(list(SAIRA_CC_SEA_TIMEOUT = "999"), {
        result <- coords_cc_sea_flagged(x, scale = 50L)
        testthat::expect_true(all(result))
        testthat::expect_equal(timeout_used, 999)
    })
})

testthat::test_that("validate_coords_cc_df keeps seas_scale=10 without requiring rnaturalearthhires", {
    testthat::local_mocked_bindings(
        requireNamespace = function(package, quietly = FALSE) {
            if (identical(package, "rnaturalearthhires")) return(FALSE)
            TRUE
        },
        .package = "base"
    )
    testthat::local_mocked_bindings(
        coords_assert_cc_dependencies = function() NULL,
        coords_country_to_iso3 = function(country_values) rep("BRA", length(country_values)),
        coords_cc_sea_flagged = function(x, scale, timeout = NULL) {
            testthat::expect_identical(scale, 10L)
            rep(TRUE, nrow(x))
        },
        coords_cc_flagged = function(fun_name, x, ...) rep(TRUE, nrow(x)),
        .package = "saira"
    )

    df <- data.frame(
        decimalLatitude = c(-10, -11),
        decimalLongitude = c(-50, -51),
        country = c("Brasil", "Brasil"),
        stringsAsFactors = FALSE
    )

    out <- validate_coords_cc_df(
        df = df,
        lat_col = "decimalLatitude",
        lon_col = "decimalLongitude",
        country_col = "country",
        seas_scale = 10L
    )

    testthat::expect_identical(attr(out, "seas_scale"), 10L)
    testthat::expect_true(all(out$diagnostic == "ok"))
})

# Country fill: match the casing the column already uses -----------------

testthat::test_that("coords_match_country_case follows an all-caps column", {
    # Filling blanks with the Natural Earth `admin` attribute (Title Case) into
    # a column the publisher wrote in caps produced "BRAZIL" beside "Peru".
    testthat::expect_identical(
        saira:::coords_match_country_case(
            c("Peru", "Bolivia"), c("BRAZIL", "ARGENTINA", "BRAZIL")
        ),
        c("PERU", "BOLIVIA")
    )
})

testthat::test_that("coords_match_country_case follows a lower-case column", {
    testthat::expect_identical(
        saira:::coords_match_country_case(c("Peru"), c("brazil", "argentina")),
        "peru"
    )
})

testthat::test_that("coords_match_country_case leaves Title Case and mixed columns alone", {
    testthat::expect_identical(
        saira:::coords_match_country_case(c("Peru"), c("Brazil", "Argentina")),
        "Peru"
    )
    # A genuinely mixed column has no dominant casing to follow, so guessing
    # would be worse than leaving the reference value as it came.
    testthat::expect_identical(
        saira:::coords_match_country_case(c("Peru"), c("BRAZIL", "Argentina")),
        "Peru"
    )
})

testthat::test_that("coords_match_country_case ignores blanks and uncased values", {
    testthat::expect_identical(
        saira:::coords_match_country_case(c("Peru"), c(NA, "", "   ")),
        "Peru"
    )
    testthat::expect_identical(
        saira:::coords_match_country_case(c("Peru"), c("1234", "5678")),
        "Peru"
    )
})
