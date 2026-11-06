test_that("coords_run_points drops undrawable and repeated points", {
    pts <- coords_run_points(
        lat = c(-10, -10, NA, 95, -20.5),
        lon = c(-50, -50, -40, -40, -45.25)
    )
    expect_identical(pts$lon, c(-50, -45.25))
    expect_identical(pts$lat, c(-10, -20.5))

    many <- coords_run_points(lat = seq(-30, 0, length.out = 100), lon = rep(-50, 100), max = 10L)
    expect_length(many$lon, 10L)
})

test_that("coords_run_extent pads one span and stays on the globe", {
    ext <- coords_run_extent(lon = c(-50, -40), lat = c(-20, -10))
    expect_identical(unlist(ext), c(xmin = -60, xmax = -30, ymin = -30, ymax = 0))
    world <- coords_run_extent(lon = c(-170, 170), lat = c(-80, 80))
    expect_identical(unlist(world), c(xmin = -180, xmax = 180, ymin = -90, ymax = 90))
    expect_null(coords_run_extent(numeric(0), numeric(0)))
})

test_that("coords_run_progress counts tests and labels hits", {
    prep <- coords_run_progress(2L, integer(0), 1107L, "pt")
    expect_identical(prep$count, "Lendo 1.107 registros")
    expect_identical(vapply(prep$steps, `[[`, "", "state"), c("done", "active", rep("next", 4)))

    hits <- c(validity = 3L, sea = 7L, zero_equal = 0L, reference = 4L)
    sea <- coords_run_progress(4L, hits, 1107L, "en")
    expect_identical(sea$count, "Test 2 of 4 · 1,107 records")
    expect_identical(sea$steps[[3]]$state_label, "3 invalid")
    expect_true(sea$steps[[3]]$hit)

    done <- coords_run_progress(7L, hits, 1107L, "pt")
    expect_true(done$done)
    expect_equal(done$pct, 100)
    expect_identical(done$count, "14 de 1.107 registros com problema")
    expect_false(done$steps[[5]]$hit)
})

test_that("coords_run_reporter keeps the family of the first test", {
    sent <- list()
    report <- coords_run_reporter(function(msg) sent[[length(sent) + 1L]] <<- msg, n_records = 4L, lang = "en")
    lat <- c(-10, -11, -12, NA)
    lon <- c(-50, -51, -52, -53)
    report("validity", 4L, lat, lon)
    report("sea", c(1L, 4L), lat, lon)
    report("reference", c(1L, 2L), lat, lon)

    expect_identical(sent[[1]]$family, "validity")
    # Row 4 has no position, so the radar gets no flag for it.
    expect_length(sent[[1]]$flags, 0L)
    expect_identical(as.numeric(sent[[2]]$flags), c(-50, -10))
    expect_identical(as.numeric(sent[[3]]$flags), c(-51, -11))
    expect_identical(sent[[3]]$progress$steps[[4]]$state_label, "1 at sea")
})

test_that("validate_coords_cc_df reports every step in order", {
    skip_if_not_installed("CoordinateCleaner")
    keys <- character(0)
    df <- data.frame(
        decimalLatitude = c("-15.8", "abc", "-22.9"),
        decimalLongitude = c("-47.9", "-43.2", "-43.2"),
        country = c("Brazil", "Brazil", "Brazil"),
        stringsAsFactors = FALSE
    )
    validate_coords_cc_df(
        df, "decimalLatitude", "decimalLongitude", "country",
        on_step = function(key, rows, lat, lon) keys <<- c(keys, key)
    )
    expect_identical(keys, coords_run_step_keys())
})

test_that("an error in on_step does not stop the validation", {
    skip_if_not_installed("CoordinateCleaner")
    df <- data.frame(
        decimalLatitude = c("-15.8", "-22.9"),
        decimalLongitude = c("-47.9", "-43.2"),
        country = c("Brazil", "Brazil"),
        stringsAsFactors = FALSE
    )
    out <- validate_coords_cc_df(
        df, "decimalLatitude", "decimalLongitude", "country",
        on_step = function(key, rows, lat, lon) stop("stage failed")
    )
    expect_equal(nrow(out), 2L)
})
