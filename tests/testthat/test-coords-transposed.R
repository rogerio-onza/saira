# Tests for transposed-coordinate detection/correction against the bundled
# Natural Earth layer.

testthat::test_that("coords_transposed_corrections corrects swapped/sign-flipped coords against country", {
    testthat::skip_if_not_installed("terra")
    testthat::skip_if_not_installed("rnaturalearth")
    testthat::skip_if_not_installed("rnaturalearthdata")

    df <- data.frame(
        occurrenceID = paste0("occ-", 1:4),
        decimalLatitude  = c(63.43333, -14.43333, -41.90000, -46.69778),
        decimalLongitude = c(-17.90000, -67.91667, -13.25000, -13.82444),
        country = c("BOLIVIA", "bolivia", "Brasil", "Brazil"),
        stringsAsFactors = FALSE
    )

    res <- coords_transposed_corrections(df)
    testthat::skip_if_not(isTRUE(res$available), "Natural Earth country layer unavailable")

    # Records 1, 3, 4 are transposed; record 2 is already inside Bolivia.
    testthat::expect_identical(res$corrected, c(TRUE, FALSE, TRUE, TRUE))
    testthat::expect_identical(res$n_corrected, 3L)
    testthat::expect_true(is.na(res$transform[[2]]))

    # Verbatim untouched on the non-corrected row.
    testthat::expect_equal(res$lat_new[[2]], -14.43333, tolerance = 1e-4)

    # Every corrected point now falls inside its informed country.
    ref <- coords_load_ne_land(50L)
    poly <- ref[toupper(as.character(ref$iso_a3_eh)) %in% c("BOL", "BRA"), ]
    inside <- coords_points_in_poly(res$lon_new, res$lat_new, poly)
    testthat::expect_true(all(inside[res$corrected]))
})

testthat::test_that("coords_transposed_corrections is a no-op without usable country/coords", {
    # Empty data frame.
    empty <- coords_transposed_corrections(
        data.frame(decimalLatitude = numeric(0), decimalLongitude = numeric(0),
                   country = character(0))
    )
    testthat::expect_identical(empty$n_corrected, 0L)
    testthat::expect_identical(empty$corrected, logical(0))

    # No reference layer available (offline) -> available = FALSE, nothing changed.
    df <- data.frame(
        decimalLatitude = c(10, 20), decimalLongitude = c(30, 40),
        country = c("Brazil", "Brazil"), stringsAsFactors = FALSE
    )
    res <- coords_transposed_corrections(df, ref = NA)  # NA is not a SpatVector
    testthat::expect_false(res$available)
    testthat::expect_identical(res$n_corrected, 0L)
    testthat::expect_identical(res$lat_new, c(10, 20))
})

testthat::test_that("apply_coords_correction_payload replaces coords by occurrenceID and preserves verbatim", {
    df <- data.frame(
        occurrenceID = c("a", "b", "c"),
        decimalLatitude  = c("63.4", "-14.4", "-41.9"),
        decimalLongitude = c("-17.9", "-67.9", "-13.2"),
        verbatimLatitude  = c("", "", ""),
        verbatimLongitude = c("", "", ""),
        stringsAsFactors = FALSE
    )
    payload <- list(corrections = data.frame(
        occurrenceID = c("a", "c"),
        decimalLatitude  = c(-17.9, -13.25),
        decimalLongitude = c(-63.43, -41.9),
        stringsAsFactors = FALSE
    ))

    out <- apply_coords_correction_payload(df, payload)

    # Corrected rows updated; untouched row preserved.
    testthat::expect_identical(out$decimalLatitude, c("-17.9", "-14.4", "-13.25"))
    testthat::expect_identical(out$decimalLongitude, c("-63.43", "-67.9", "-41.9"))
    # Verbatim captured for corrected rows only.
    testthat::expect_identical(out$verbatimLatitude, c("63.4", "", "-41.9"))
    testthat::expect_identical(out$verbatimLongitude, c("-17.9", "", "-13.2"))
})

testthat::test_that("apply_coords_correction_payload is a no-op on empty/invalid payload", {
    df <- data.frame(
        occurrenceID = c("a"), decimalLatitude = c("1"), decimalLongitude = c("2"),
        stringsAsFactors = FALSE
    )
    testthat::expect_identical(apply_coords_correction_payload(df, NULL), df)
    testthat::expect_identical(apply_coords_correction_payload(df, list()), df)
    empty_payload <- list(corrections = df[0, c("occurrenceID"), drop = FALSE])
    testthat::expect_identical(apply_coords_correction_payload(df, empty_payload), df)
})

testthat::test_that("apply_coord_corrections_to_result overlays corrections and country fills", {
    res <- data.frame(
        .row_index = 1:3,
        lat_num = c(-35.55, -8.80, -9.32),
        lon_num = c(-8.73, -35.85, -36.47),
        diagnostic = c("sea", "ok", "validity_bounds"),
        diagnostic_family = c("sea", "ok", "validity"),
        valid = c(FALSE, TRUE, FALSE),
        country = c("Brasil", "Brasil", ""),
        stringsAsFactors = FALSE
    )
    occ_ids <- c("A", "B", "C") # aligned to .row_index 1, 2, 3

    cc <- list(corrections = data.frame(
        occurrenceID = "A", decimalLatitude = -8.73, decimalLongitude = -35.55,
        stringsAsFactors = FALSE
    ))
    cf <- list(country = data.frame(
        occurrenceID = "C", country = "Brazil", stringsAsFactors = FALSE
    ))

    out <- apply_coord_corrections_to_result(res, cc, cf, occ_ids)
    # Corrected row moved + re-tagged as a resolved overlay.
    testthat::expect_equal(out$lat_num[1], -8.73)
    testthat::expect_equal(out$lon_num[1], -35.55)
    testthat::expect_equal(out$diagnostic_family[1], "corrected")
    testthat::expect_equal(out$diagnostic[1], "corrected")
    testthat::expect_true(out$valid[1])
    # Country fill updates only the value.
    testthat::expect_equal(out$country[3], "Brazil")
    testthat::expect_equal(out$diagnostic_family[3], "validity")
    # Untouched row unchanged.
    testthat::expect_equal(out$diagnostic_family[2], "ok")
    testthat::expect_equal(out$lat_num[2], -8.80)
})

testthat::test_that("apply_coord_corrections_to_result is a safe no-op without occ_ids/payloads", {
    res <- data.frame(
        .row_index = 1:2, lat_num = c(-4.33, -7.23), lon_num = c(-38.88, -39.41),
        diagnostic = c("ok", "ok"), diagnostic_family = c("ok", "ok"),
        stringsAsFactors = FALSE
    )
    testthat::expect_identical(apply_coord_corrections_to_result(res, NULL, NULL, NULL), res)
    testthat::expect_identical(apply_coord_corrections_to_result(res, NULL, NULL, character(0)), res)
    cc <- list(corrections = data.frame(
        occurrenceID = "Z", decimalLatitude = 1, decimalLongitude = 2, stringsAsFactors = FALSE
    ))
    # occurrenceID not present in occ_ids -> no change.
    testthat::expect_identical(apply_coord_corrections_to_result(res, cc, NULL, c("A", "B")), res)
})
