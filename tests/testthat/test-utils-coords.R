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
        # The mock calls inland points sea; the real coastline would undo that.
        coords_coastal_tolerance = function(x, land, ...) land,
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

testthat::test_that("validate_coords_cc_df names a zero point at sea zero_equal", {
    testthat::local_mocked_bindings(
        coords_assert_cc_dependencies = function() NULL,
        coords_country_to_iso3 = function(country_values) rep("BRA", length(country_values)),
        coords_cc_flagged = function(fun_name, x, ...) {
            n <- nrow(x)
            if (fun_name == "cc_sea") return(c(FALSE, FALSE))
            if (fun_name == "cc_zero") return(c(FALSE, TRUE))
            rep(TRUE, n)
        },
        coords_coastal_tolerance = function(x, land, ...) land,
        .package = "saira"
    )
    df <- data.frame(decimalLatitude = c(0, -11), decimalLongitude = c(0, -51),
                     country = "Brasil", stringsAsFactors = FALSE)
    out <- validate_coords_cc_df(df, "decimalLatitude", "decimalLongitude", "country",
                                 profile = "complete")
    testthat::expect_identical(out$diagnostic, c("zero_equal", "sea"))
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
            if (fun_name == "cc_sea") {
                return(rep(FALSE, nrow(x)))
            }
            rep(TRUE, nrow(x))
        },
        # The mock calls inland points sea; the real coastline would undo that.
        coords_coastal_tolerance = function(x, land, ...) land,
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

testthat::test_that("coords_points_in_coverage agrees with terra::extract on the embedded Americas layer", {
    coverage_ref <- coords_read_embedded_ne_land()$coverage_ref
    testthat::skip_if(is.null(coverage_ref), "embedded Natural Earth layer not available")
    set.seed(42)
    x <- data.frame(
        decimalLongitude = stats::runif(2000, -130, 10),
        decimalLatitude = stats::runif(2000, -60, 40)
    )
    pts <- terra::vect(x, geom = c("decimalLongitude", "decimalLatitude"),
                       crs = "+proj=longlat +datum=WGS84 +no_defs")
    extracted <- terra::extract(coverage_ref, pts)
    expected <- !is.na(extracted[!duplicated(extracted[, 1]), 2])
    testthat::expect_identical(coords_points_in_coverage(x, coverage_ref = coverage_ref), expected)
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

testthat::test_that("coords_cc_sea_flagged marks the rows of a failed run as unchecked (SP-06)", {
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
            if (identical(ref, "ref10")) simpleError("forced sea failure") else rep(FALSE, nrow(x))
        },
        .package = "saira"
    )
    x <- data.frame(decimalLatitude = c(-10, 40, -11), decimalLongitude = c(-50, 20, -51))

    flagged <- testthat::expect_warning(coords_cc_sea_flagged(x, scale = 10L), "not run for 2 row")
    testthat::expect_identical(as.vector(flagged), c(TRUE, FALSE, TRUE))
    testthat::expect_identical(attr(flagged, "unchecked"), c(TRUE, FALSE, TRUE))
    testthat::expect_identical(attr(flagged, "errors"), "forced sea failure")
})

testthat::test_that("a sea check timeout marks every row as unchecked", {
    testthat::local_mocked_bindings(
        coords_load_ne_land = function(scale, download = TRUE) "ref50",
        coords_with_optional_time_limit = function(fn, timeout = NULL) stop("reached elapsed time limit"),
        .package = "saira"
    )
    x <- data.frame(decimalLatitude = c(-10, 10), decimalLongitude = c(-50, -51))
    flagged <- testthat::expect_warning(coords_cc_sea_flagged(x, scale = 50L), "time limit")
    testthat::expect_identical(attr(flagged, "unchecked"), c(TRUE, TRUE))
})

testthat::test_that("validate_coords_cc_df reports a sea check that did not run (SP-06)", {
    testthat::local_mocked_bindings(
        coords_assert_cc_dependencies = function() NULL,
        coords_country_to_iso3 = function(country_values) rep("BRA", length(country_values)),
        coords_cc_sea_flagged = function(x, scale, timeout = NULL) {
            structure(rep(TRUE, nrow(x)), unchecked = rep(TRUE, nrow(x)), errors = "forced sea failure")
        },
        coords_cc_flagged = function(fun_name, x, ...) rep(TRUE, nrow(x)),
        .package = "saira"
    )
    df <- data.frame(decimalLatitude = c(-10, -11, NA), decimalLongitude = c(-50, -51, NA),
                     country = "Brasil", stringsAsFactors = FALSE)
    out <- validate_coords_cc_df(df = df, lat_col = "decimalLatitude", lon_col = "decimalLongitude",
                                 country_col = "country", profile = "fast")
    testthat::expect_identical(out$flag_sea_unchecked, c(TRUE, TRUE, FALSE))
    testthat::expect_identical(attr(out, "sea_check"),
                               list(status = "failed", unchecked = 2L, errors = "forced sea failure"))

    # Valid, but never approved: no OK count, no green marker, in the problems.
    testthat::expect_identical(out$diagnostic, c("sea_unchecked", "sea_unchecked", "validity_missing"))
    testthat::expect_identical(out$diagnostic_family, c("unchecked", "unchecked", "validity"))
    testthat::expect_identical(out$valid, c(TRUE, TRUE, FALSE))
    counts <- count_coords_diagnostics(out)
    testthat::expect_identical(counts$ok, 0L)
    testthat::expect_identical(counts$unchecked, 2L)
    testthat::expect_identical(counts$problems, 3L)
    for (filter in c("problems", "unchecked")) {
        markers <- build_leaflet_data(out, filter = filter, popups = FALSE)
        testthat::expect_identical(markers$.row_index, 1:2, info = filter)
        testthat::expect_false(any(markers$color == "#00A86B"), info = filter)
    }
    testthat::expect_match(build_leaflet_data(out, popup_labels = list())$popup_html[[1]], "Sea not checked")
})

testthat::test_that("a publication check lists a point with no sea check", {
    df <- data.frame(decimalLatitude = c("-10", "-11"), decimalLongitude = c("-50", "-51"))
    cv <- data.frame(.row_index = 1:2, diagnostic_family = c("unchecked", "ok"))
    testthat::expect_identical(coord_export_issues(df, coord_validation = cv)$flags$rows, 1L)
})

# One marker per place -----------------------------------------------------

coords_map_rows <- function(row, lat, lon, color = "#00A86B") {
    data.frame(.row_index = row, lat_num = lat, lon_num = lon, color = color, stringsAsFactors = FALSE)
}

testthat::test_that("coords_map_markers draws one marker per place and color", {
    rows <- coords_map_rows(1:5, c(-10, -10, -10, -20, 95), c(-50, -50, -50, -60, 0),
                            c("#00A86B", "#00A86B", "#C0392B", "#00A86B", "#00A86B"))
    markers <- coords_map_markers(rows)
    testthat::expect_identical(markers$layer_id, c("r1", "r3", "r4"))
    testthat::expect_identical(markers$color, c("#00A86B", "#C0392B", "#00A86B"))
    testthat::expect_identical(nrow(coords_map_markers(rows[5L, ])), 0L)

    testthat::expect_identical(coords_records_at_marker(rows, rows[1L, ]), 2L)
    testthat::expect_identical(coords_records_at_marker(rows, rows[3L, ]), 1L)
})

testthat::test_that("coords_marker_changes sends only what changed", {
    all_rows <- coords_map_rows(1:6, -(1:6), -(1:6))
    drawn <- coords_map_markers(all_rows)

    same <- coords_marker_changes(drawn, drawn)
    testthat::expect_false(same$clear)
    testthat::expect_length(same$remove, 0L)
    testthat::expect_identical(nrow(same$add), 0L)

    # One record moved: only its marker goes and comes back.
    moved <- all_rows
    moved$lat_num[[2]] <- 40
    one <- coords_marker_changes(drawn, coords_map_markers(moved))
    testthat::expect_false(one$clear)
    testthat::expect_identical(one$remove, "r2")
    testthat::expect_identical(one$add$layer_id, "r2")

    # A narrow filter leaves few markers, so one clear replaces the removals.
    narrow <- coords_marker_changes(drawn, coords_map_markers(all_rows[1L, ]))
    testthat::expect_true(narrow$clear)
    testthat::expect_identical(narrow$add$layer_id, "r1")

    # A map with no known state gets all the markers.
    unknown <- coords_marker_changes(NULL, drawn)
    testthat::expect_true(unknown$clear)
    testthat::expect_identical(unknown$add, drawn)
})

testthat::test_that("coords_marker_changes draws the points with problems over the OK points", {
    rows <- coords_map_rows(1:4, -(1:4), -(1:4))
    rows$color <- c("#252659", coords_map_ok_color, "#252659", coords_map_ok_color)
    markers <- coords_map_markers(rows)

    testthat::expect_identical(coords_marker_changes(NULL, markers)$add$layer_id, c("r2", "r4", "r1", "r3"))

    # A new OK point would cover the drawn problems, so they go again after it.
    problems_only <- markers[markers$color != coords_map_ok_color, ]
    wider <- coords_marker_changes(problems_only, markers)
    testthat::expect_false(wider$clear)
    testthat::expect_identical(wider$add$layer_id, c("r2", "r4", "r1", "r3"))

    # A new problem needs nothing else: it goes on top.
    new_problem <- coords_marker_changes(markers[markers$layer_id != "r3", ], markers)
    testthat::expect_identical(new_problem$add$layer_id, "r3")
})

testthat::test_that("the first record of a shared marker can move and the others stay drawn", {
    rows <- coords_map_rows(1:3, c(-10, -10, -10), c(-50, -50, -50))
    drawn <- coords_map_markers(rows)
    testthat::expect_identical(drawn$layer_id, "r1")
    rows$lat_num[[1]] <- -11
    changes <- coords_marker_changes(drawn, coords_map_markers(rows))
    testthat::expect_setequal(changes$add$layer_id, c("r1", "r2"))
    testthat::expect_true(changes$clear || identical(changes$remove, "r1"))
})

testthat::test_that("coords_map_sample limits only the OK markers, and a closer view adds to the drawn ones", {
    n <- 1000L
    markers <- coords_map_markers(coords_map_rows(
        seq_len(n), seq(-40, 10, length.out = n), seq(-70, -30, length.out = n),
        rep(c("#00A86B", "#00A86B", "#00A86B", "#C0392B"), length.out = n)
    ))
    problems <- markers$layer_id[markers$color == "#C0392B"]

    all_in <- coords_map_sample(markers, limit = n)
    testthat::expect_false(all_in$limited)
    testthat::expect_identical(all_in$markers, markers)

    far <- coords_map_sample(markers, limit = 100L)
    testthat::expect_true(far$limited)
    testthat::expect_identical(far$ok_shown, 100L)
    testthat::expect_identical(far$ok_total, 750L)
    testthat::expect_true(all(problems %in% far$markers$layer_id))
    testthat::expect_identical(far$markers, coords_map_sample(markers, limit = 100L)$markers)

    # Lat -30 to -20 plus a margin of 2.5 degrees holds 150 OK markers.
    close <- coords_map_sample(markers, list(north = -20, south = -30, east = -30, west = -70), limit = 100L)
    testthat::expect_lt(close$ok_total, far$ok_total)
    testthat::expect_true(all(problems %in% close$markers$layer_id))
    near_ok <- far$markers[far$markers$color == "#00A86B" & far$markers$lat_num >= -32.5 & far$markers$lat_num <= -17.5, ]
    testthat::expect_true(all(near_ok$layer_id %in% close$markers$layer_id))

    # A partial bounds report counts as no view.
    testthat::expect_identical(coords_map_sample(markers, list(north = 0), limit = 100L)$ok_total, 750L)
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

test_that("parse_coordinate_text() reads DMS, hemisphere letters and the Unicode minus (B08)", {
  v <- c("23°33'S", "23°33'44\"S", "23.5505 S", "-23.5°", "−23.5", "29°58' N",
         "aprox. -23.5", "-23.5,-46.6", "-23.5", "-23.5 N", "23.5 E", "99° S")
  expect_equal(parse_coordinate_text(v, "lat"),
               c(-23.55, -23.562222, -23.5505, -23.5, -23.5, 29.966667, rep(NA, 6)))
  expect_equal(parse_coordinate_text(c("46°38'W", "46.6 O", "46,6 L"), "lon"),
               c(-46.633333, -46.6, 46.6))
  df <- data.frame(a = c("23°33'S", "-46,6559"), stringsAsFactors = FALSE)
  expect_equal(build_term_value("decimalLatitude", df, "a")$values, c("-23.55", "-46,6559"))
})

test_that("coords_transposed_corrections() marks points outside the country with no fix (B04)", {
  skip_if_not_installed("terra")
  df <- data.frame(decimalLatitude = c("23.5", "40.713", "-23.5"),
                   decimalLongitude = c("46.6", "-74.0", "-46.6"),
                   country = rep("Brasil", 3), stringsAsFactors = FALSE)
  r <- coords_transposed_corrections(df)
  skip_if_not(isTRUE(r$available), "country layer not available")
  expect_equal(r$corrected, c(TRUE, FALSE, FALSE))
  expect_equal(r$outside, c(FALSE, TRUE, FALSE))
})

test_that("a point next to a generalized coastline is not sea (B13)", {
  ref <- tryCatch(coords_load_ne_land(10L), error = function(e) NULL)
  skip_if(is.null(ref), "land layer not available")
  x <- data.frame(decimalLatitude = c(-1.4558, -15.79, -10, 0),
                  decimalLongitude = c(-48.5039, -47.88, -30, -48.5039 + 30), species = "a")
  land <- c(FALSE, TRUE, FALSE, FALSE)
  expect_equal(coords_coastal_tolerance(x, land, ref, 10L), c(TRUE, TRUE, FALSE, FALSE))
})

testthat::test_that("parse_coordinate_pair splits one cell into latitude and longitude", {
    pair <- saira:::parse_coordinate_pair
    v <- c("23°33'S 46°38'W", "46°38'W, 23°33'S", "S23°33' W46°38'",
           "-23.55, -46.63", "-23,55; -46,63", "23.55 S, 46.63 W", "-95.1, -23.55")
    res <- pair(v)
    testthat::expect_equal(res$lat, rep(-23.55, 7L))
    # With no letter, the latitude comes first unless it cannot be one.
    testthat::expect_equal(res$lon, c(rep(-46.63333, 3L), rep(-46.63, 3L), -95.1), tolerance = 1e-5)
    # Dates, ranges, integers, one axis and two latitudes are no pair.
    no <- pair(c("2024-03-10", "10/20", "-23 -46", "23°33'S", "-23.55",
                 "23.5 N 10.2 S", "", NA))
    testthat::expect_true(all(is.na(no$lat) & is.na(no$lon)))
    # Degrees and minutes with no letter: 23 degrees 33 minutes is no 2333.
    dm <- pair("-23\u00b033' -46\u00b038'")
    testthat::expect_equal(c(dm$lat, dm$lon), c(-23.55, -46.63333), tolerance = 1e-5)
})

testthat::test_that("convert_coordinate_text gives each card its own axis of a pair", {
    v <- c("23°33'S 46°38'W", "-23.55, -46.63", "23°33'S", "-23.55")
    testthat::expect_identical(saira:::convert_coordinate_text(v, "lat"),
                               c("-23.55", "-23.55", "-23.55", "-23.55"))
    testthat::expect_identical(saira:::convert_coordinate_text(v, "lon"),
                               c("-46.633333", "-46.63", "23°33'S", "-23.55"))
})

testthat::test_that("convert_coordinate_text keeps the decimals of each point", {
    conv <- function(x, axis) saira:::convert_coordinate_text(x, axis, pair_column = TRUE)
    v <- c("-23.123456, -123.123456", "23.12, 46.1", "-1.5, 120.125", "0.00001, -0.5")
    lat <- c("-23.123456", "23.12", "-1.5", "0.00001")
    lon <- c("-123.123456", "46.1", "120.125", "-0.5")
    for (d in c(3L, 7L, 15L)) {
        withr::with_options(list(digits = d), {
            testthat::expect_identical(conv(v, "lat"), lat)
            testthat::expect_identical(conv(v, "lon"), lon)
        })
    }
    # A point keeps its text when other rows come or go.
    testthat::expect_identical(conv(v[1L], "lon"), lon[1L])
    testthat::expect_identical(conv(c(v[1L], "-1.123456, -2.123456"), "lon")[1L], lon[1L])
    # A degree value keeps the six decimals of the text parser.
    dms <- withr::with_options(list(digits = 3L), conv("23\u00b033'30\"S 46\u00b038'10\"W", "lat"))
    testthat::expect_identical(dms, "-23.558333")
})

testthat::test_that("convert_coordinate_text gives no point to one value in a column of pairs", {
    v <- c(sprintf("-23.%02d, -46.%02d", 1:9, 1:9), "-23.55")
    conv <- function(x, axis) saira:::convert_coordinate_text(x, axis, pair_column = TRUE)
    testthat::expect_identical(conv(v, "lat")[10L], "")
    testthat::expect_identical(conv(v, "lon")[10L], "")
    # The rule holds per cell: many repeated values, or a slice with no pair.
    testthat::expect_identical(unique(conv(c(v[1:9], rep("-23.55", 10)), "lon")[10:19]), "")
    testthat::expect_identical(conv(rep("-23.55", 5), "lat"), rep("", 5))
    # Each form that the coordinate check reads as a number.
    odd <- c("-2.355e1", "-.55", "-23.", " +23,5 ")
    testthat::expect_identical(conv(c(v[1:9], odd), "lat")[10:13], rep("", 4))
    testthat::expect_identical(conv(c(v[1:9], odd), "lon")[10:13], rep("", 4))
    # Text that is no coordinate stays for the coordinate check.
    v[10L] <- "sem GPS"
    testthat::expect_identical(conv(v, "lat")[10L], "sem GPS")
    # On one card only, a plain number keeps its text.
    plain <- c("-23,000001", "-23.5", "-23.55, -46.63")
    testthat::expect_identical(saira:::convert_coordinate_text(plain, "lat"), c("-23,000001", "-23.5", "-23.55"))
})

testthat::test_that("coordinate_pair_columns counts rows, not distinct values", {
    pairs <- sprintf("-23.%02d, -46.%02d", 1:9, 1:9)
    df <- data.frame(c = c(pairs, rep("-23.55", 10)), stringsAsFactors = FALSE)
    testthat::expect_identical(saira:::coordinate_pair_columns(df, max_values = 500L), character(0))
    df <- data.frame(c = c(rep(pairs[1], 10), "-23.55"), stringsAsFactors = FALSE)
    testthat::expect_identical(saira:::coordinate_pair_columns(df, max_values = 500L), "c")
})

testthat::test_that("coordinate_pair_columns finds a column of pairs", {
    df <- data.frame(
        coords = c("-23.55, -46.63", "-23.50, -46.60", ""),
        lat = c("-23.55", "-23.50", ""),
        stringsAsFactors = FALSE
    )
    testthat::expect_identical(saira:::coordinate_pair_columns(df), "coords")
    df$coords[2L] <- "no GPS"
    testthat::expect_identical(saira:::coordinate_pair_columns(df), character(0))
})
