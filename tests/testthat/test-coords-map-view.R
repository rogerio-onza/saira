# Map framing for the coordinates tab (ADR-130): only drawable points count.

testthat::test_that("coords_plottable rejects out-of-range and missing values", {
    testthat::expect_identical(
        coords_plottable(c(-15, -95.2, NA, 10), c(-47, -50, -40, -198.4)),
        c(TRUE, FALSE, FALSE, FALSE)
    )
})

testthat::test_that("coords_map_view ignores points outside the world", {
    view <- coords_map_view(c(-15, -95.2, 0, -20), c(-47, -50, -198.4, -40))
    testthat::expect_identical(view$type, "bounds")
    testthat::expect_identical(c(view$lng1, view$lng2), c(-47, -40))
    testthat::expect_identical(c(view$lat1, view$lat2), c(-20, -15))
})

testthat::test_that("coords_map_view clamps pole latitudes and handles one point", {
    testthat::expect_identical(coords_map_view(c(-89, 10), c(0, 0))$lat1, -85)
    one <- coords_map_view(c(-15, -15), c(-47, -47))
    testthat::expect_identical(one$type, "point")
    testthat::expect_null(coords_map_view(-95, -198))
})

testthat::test_that("leaflet_fill_world bounds the view and hooks the minimum zoom", {
    map <- leaflet_fill_world(leaflet::leaflet())
    calls <- vapply(map$x$calls, function(x) x$method, character(1))
    testthat::expect_true("setMaxBounds" %in% calls)
    testthat::expect_true(any(grepl("leafletFillWorld", unlist(map$jsHooks), fixed = TRUE)))
    asset <- system.file("app", "www", "module-utils-coords.js", package = "saira")
    testthat::expect_true(any(grepl("setMinZoom", readLines(asset), fixed = TRUE)))
})

testthat::test_that("coords_map_view trims far points when asked and the set is large", {
    lat <- c(rep(-15, 30), seq(-20, -10, length.out = 30), 10)
    lon <- c(rep(-47, 30), seq(-50, -40, length.out = 30), 0)
    full <- coords_map_view(lat, lon)
    testthat::expect_identical(full$lng2, 0)
    core <- coords_map_view(lat, lon, trim = 0.02)
    testthat::expect_lt(core$lng2, -39)
    testthat::expect_lt(core$lat2, -9)
    few <- coords_map_view(c(-15, -16, 10), c(-47, -48, 0), trim = 0.02)
    testthat::expect_identical(few$lng2, 0)
})
