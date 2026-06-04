# Tests for transposed-coordinate detection/correction (reimplements the core
# of bdc::bdc_coordinates_transposed on the bundled Natural Earth layer).

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
