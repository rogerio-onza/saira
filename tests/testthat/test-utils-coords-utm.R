testthat::test_that("coords_is_projected_pair separates projected values from degrees", {
    # The real shape of the reported upload: easting filed under decimalLatitude.
    testthat::expect_true(coords_is_projected_pair(574699, 7805441))
    testthat::expect_true(coords_is_projected_pair(7805441, 574699))

    # Valid degrees are left to the existing range diagnostics.
    testthat::expect_false(coords_is_projected_pair(-19.84, -56.28))
    testthat::expect_false(coords_is_projected_pair(0, 0))
    # An incomplete pair proves nothing.
    testthat::expect_false(coords_is_projected_pair(574699, NA))
    # Out-of-range degrees are not projected values either.
    testthat::expect_false(coords_is_projected_pair(200, 300))

    testthat::expect_identical(coords_is_projected_pair(numeric(0), numeric(0)), logical(0))
})

testthat::test_that("coords_utm_assign_axes tells easting from northing by magnitude", {
    both <- coords_utm_assign_axes(c(574699, 7805441), c(7805441, 574699))
    testthat::expect_identical(both$easting, c(574699, 574699))
    testthat::expect_identical(both$northing, c(7805441, 7805441))

    unresolved <- coords_utm_assign_axes(-19.84, -56.28)
    testthat::expect_true(is.na(unresolved$easting))
    testthat::expect_true(is.na(unresolved$northing))
})

testthat::test_that("coords_utm_epsg resolves known codes and rejects impossible ones", {
    testthat::expect_identical(coords_utm_epsg(21, "S", "SIRGAS2000"), 31981L)
    testthat::expect_identical(coords_utm_epsg(21, "S", "WGS84"), 32721L)
    testthat::expect_identical(coords_utm_epsg(21, "S", "SAD69"), 29191L)
    testthat::expect_identical(coords_utm_epsg(18, "N", "WGS84"), 32618L)

    # SIRGAS 2000 does not reach zone 5, and SAD69 has no northern zones.
    testthat::expect_error(coords_utm_epsg(5, "S", "SIRGAS2000"), "does not cover")
    testthat::expect_error(coords_utm_epsg(21, "N", "SAD69"), "no northern")
    testthat::expect_error(coords_utm_epsg(21, "S", "NOPE"), "Invalid UTM")
})

testthat::test_that("coords_utm_to_wgs84 converts the reported coordinates to Mato Grosso do Sul", {
    out <- coords_utm_to_wgs84(
        easting = c(574699, 578357),
        northing = c(7805441, 7800408),
        zone = 21, hemisphere = "S", datum = "SIRGAS2000"
    )

    testthat::expect_equal(out$decimalLatitude, c(-19.84565, -19.89099), tolerance = 1e-4)
    testthat::expect_equal(out$decimalLongitude, c(-56.28660, -56.25146), tolerance = 1e-4)

    # WGS 84 sits within a metre of SIRGAS 2000 in Brazil.
    wgs <- coords_utm_to_wgs84(574699, 7805441, zone = 21, datum = "WGS84")
    testthat::expect_equal(wgs$decimalLatitude, out$decimalLatitude[[1]], tolerance = 1e-5)

    # An incomplete pair yields NA rather than dropping the row.
    partial <- coords_utm_to_wgs84(c(574699, NA), c(7805441, 7800408), zone = 21)
    testthat::expect_identical(nrow(partial), 2L)
    testthat::expect_true(is.na(partial$decimalLatitude[[2]]))
})

testthat::test_that("coords_utm_zone_from_lon maps a longitude to its zone", {
    testthat::expect_identical(coords_utm_zone_from_lon(-56.28), 21L)
    testthat::expect_identical(coords_utm_zone_from_lon(-45), 23L)
    testthat::expect_true(is.na(coords_utm_zone_from_lon(NA)))
    testthat::expect_true(is.na(coords_utm_zone_from_lon(999)))
})

testthat::test_that("coords_utm_zone_candidates ranks zones and keeps ties", {
    testthat::skip_if_not_installed("rnaturalearth")
    testthat::skip_on_cran()

    # The same pair is valid in every zone, six degrees of longitude apart. The
    # country narrows the field but cannot break the tie across a country as
    # wide as Brazil, which is why the caller must confirm the choice.
    cand <- coords_utm_zone_candidates(
        easting = 574699, northing = 7805441,
        country_iso3 = "BRA", hemisphere = "S", datum = "SIRGAS2000"
    )

    testthat::skip_if(nrow(cand) == 0L, "Natural Earth reference unavailable")
    testthat::expect_true(21L %in% cand$zone)
    testthat::expect_true(all(cand$share > 0))
    # Ordered by descending share.
    testthat::expect_false(is.unsorted(rev(cand$share)))
})

testthat::test_that("coords_utm_zone_candidates returns empty without a country", {
    testthat::expect_identical(
        nrow(coords_utm_zone_candidates(574699, 7805441, country_iso3 = NULL)),
        0L
    )
    testthat::expect_identical(
        nrow(coords_utm_zone_candidates(NA_real_, NA_real_, country_iso3 = "BRA")),
        0L
    )
})

testthat::test_that("coords_utm_srs_label describes the confirmed projection", {
    label <- coords_utm_srs_label(21, "S", "SIRGAS2000")
    testthat::expect_identical(label$system, "UTM zone 21S")
    testthat::expect_identical(label$srs, "EPSG:31981")

    # A combination with no EPSG code yields NULL rather than a made-up label.
    testthat::expect_null(coords_utm_srs_label(5, "S", "SIRGAS2000"))
})

testthat::test_that("a UTM payload creates the verbatim columns the upload lacks", {
    # The reported upload carries no verbatim columns, so the projected pair had
    # nowhere to go and was lost on conversion (ADR-122).
    df <- data.frame(
        occurrenceID = c("o1", "o2"),
        decimalLatitude = c("574699", "1"),
        decimalLongitude = c("7805441", "2"),
        stringsAsFactors = FALSE
    )
    corr <- data.frame(
        occurrenceID = "o1",
        decimalLatitude = -19.84565, decimalLongitude = -56.28660,
        verbatimLatitude = "7805441", verbatimLongitude = "574699",
        verbatimCoordinateSystem = "UTM zone 21S", verbatimSRS = "EPSG:31981",
        stringsAsFactors = FALSE
    )

    out <- apply_coords_correction_payload(df, list(corrections = corr))

    testthat::expect_identical(out$verbatimLatitude, c("7805441", NA_character_))
    testthat::expect_identical(out$verbatimLongitude, c("574699", NA_character_))
    testthat::expect_identical(out$verbatimSRS, c("EPSG:31981", NA_character_))
    testthat::expect_identical(out$decimalLatitude[[1]], "-19.84565")
    # The untouched row keeps its own values.
    testthat::expect_identical(out$decimalLatitude[[2]], "1")
})

testthat::test_that("a payload without verbatim columns keeps the old preservation", {
    # The transposed/swap cards send no verbatim columns, so the pre-existing
    # behaviour (fill from the value being overwritten) must still apply.
    df <- data.frame(
        occurrenceID = "o1",
        decimalLatitude = "-10", decimalLongitude = "-50",
        verbatimLatitude = "", verbatimLongitude = "",
        stringsAsFactors = FALSE
    )
    corr <- data.frame(
        occurrenceID = "o1", decimalLatitude = -11, decimalLongitude = -51,
        stringsAsFactors = FALSE
    )

    out <- apply_coords_correction_payload(df, list(corrections = corr))

    testthat::expect_identical(out$verbatimLatitude, "-10")
    testthat::expect_identical(out$verbatimLongitude, "-50")
    testthat::expect_identical(out$decimalLatitude, "-11")
})
