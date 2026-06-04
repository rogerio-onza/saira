# Tests for country-from-coordinates fill (reimplements the core of
# bdc::bdc_country_from_coordinates on the bundled Natural Earth layer).

testthat::test_that("coords_country_from_coordinates fills missing country from valid coords", {
    testthat::skip_if_not_installed("terra")
    testthat::skip_if_not_installed("rnaturalearth")
    testthat::skip_if_not_installed("rnaturalearthdata")

    df <- data.frame(
        occurrenceID = paste0("o", 1:5),
        decimalLatitude  = c(-22.9834, -39.857030, -17.06811, -46.69778, -15.79),
        decimalLongitude = c(-69.095, -68.443588, 37.438108, -13.82444, -47.88),
        country = c("", NA, NA, "Brazil", "Brasil"),
        stringsAsFactors = FALSE
    )

    res <- coords_country_from_coordinates(df)
    testthat::skip_if_not(isTRUE(res$available), "Natural Earth country layer unavailable")

    # Rows 1-3 had blank country and land coords -> filled; row 4/5 kept.
    testthat::expect_identical(res$filled, c(TRUE, TRUE, TRUE, FALSE, FALSE))
    testthat::expect_identical(res$n_filled, 3L)
    testthat::expect_identical(res$country_new[[1]], "Chile")
    testthat::expect_identical(res$country_new[[2]], "Argentina")
    testthat::expect_identical(res$country_new[[3]], "Mozambique")
    # Existing values never overwritten.
    testthat::expect_identical(res$country_new[[4]], "Brazil")
    testthat::expect_identical(res$country_new[[5]], "Brasil")
})

testthat::test_that("coords_country_from_coordinates does not fill sea points or invalid coords", {
    testthat::skip_if_not_installed("terra")
    testthat::skip_if_not_installed("rnaturalearthdata")

    df <- data.frame(
        decimalLatitude  = c(-30.0, NA),     # mid-Atlantic, then missing
        decimalLongitude = c(-25.0, -47.0),
        country = c("", ""),
        stringsAsFactors = FALSE
    )
    res <- coords_country_from_coordinates(df)
    testthat::skip_if_not(isTRUE(res$available))
    testthat::expect_identical(res$filled, c(FALSE, FALSE))
    testthat::expect_identical(res$n_filled, 0L)
})

testthat::test_that("coords_country_from_coordinates is a no-op when layer unavailable / empty", {
    empty <- coords_country_from_coordinates(
        data.frame(decimalLatitude = numeric(0), decimalLongitude = numeric(0),
                   country = character(0))
    )
    testthat::expect_identical(empty$n_filled, 0L)

    df <- data.frame(decimalLatitude = 1, decimalLongitude = 2, country = "")
    res <- coords_country_from_coordinates(df, ref = NA)
    testthat::expect_false(res$available)
    testthat::expect_identical(res$country_new, "")
})

testthat::test_that("coords_swap_and_fill recovers swapped sea points with blank country", {
    testthat::skip_if_not_installed("terra")
    testthat::skip_if_not_installed("rnaturalearthdata")

    # Brazilian/Mozambican coords with lat<->lon swapped and country deleted.
    df <- data.frame(
        occurrenceID = paste0("o", 1:3),
        decimalLatitude  = c(-41.90, -47.88, 37.44),   # actually the longitudes
        decimalLongitude = c(-13.25, -15.79, -17.07),  # actually the latitudes
        country = c("", "", ""),
        stringsAsFactors = FALSE
    )
    res <- coords_swap_and_fill(df)
    testthat::skip_if_not(isTRUE(res$available))

    testthat::expect_identical(res$n, 3L)
    testthat::expect_true(all(res$applies))
    testthat::expect_equal(res$lat_new, c(-13.25, -15.79, -17.07), tolerance = 1e-6)
    testthat::expect_identical(res$country_new[1:2], c("Brazil", "Brazil"))
    testthat::expect_identical(res$country_new[[3]], "Mozambique")
})

testthat::test_that("coords_swap_and_fill ignores rows whose verbatim point is already on land", {
    testthat::skip_if_not_installed("terra")
    testthat::skip_if_not_installed("rnaturalearthdata")

    # Correct Brazil point, blank country — handled by the plain country fill,
    # NOT by swap_and_fill (verbatim point is already on land).
    df <- data.frame(
        decimalLatitude = -15.79, decimalLongitude = -47.88, country = "",
        stringsAsFactors = FALSE
    )
    res <- coords_swap_and_fill(df)
    testthat::skip_if_not(isTRUE(res$available))
    testthat::expect_identical(res$n, 0L)
})

testthat::test_that("apply_country_fill_payload fills blanks by occurrenceID without overwriting", {
    df <- data.frame(
        occurrenceID = c("a", "b", "c"),
        country = c("", "Brazil", ""),
        stringsAsFactors = FALSE
    )
    payload <- list(country = data.frame(
        occurrenceID = c("a", "b", "c"),
        country = c("Chile", "Peru", "Bolivia"),
        stringsAsFactors = FALSE
    ))

    out <- apply_country_fill_payload(df, payload)
    # a and c were blank -> filled; b already had a value -> kept.
    testthat::expect_identical(out$country, c("Chile", "Brazil", "Bolivia"))

    # No-ops.
    testthat::expect_identical(apply_country_fill_payload(df, NULL), df)
    testthat::expect_identical(apply_country_fill_payload(df, list()), df)
})
