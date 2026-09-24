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
    testthat::expect_true(any(grepl("setMinZoom", unlist(map$jsHooks), fixed = TRUE)))
})
