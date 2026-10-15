# Pure helpers behind the manual coordinate edit in the coordinates table
# (ADR-129).

testthat::test_that("parse_coord_edit accepts decimal point and comma", {
    testthat::expect_identical(parse_coord_edit("-15.8", "lat"), list(value = -15.8, error = NULL))
    testthat::expect_identical(parse_coord_edit(" -47,9 ", "lon")$value, -47.9)
    testthat::expect_identical(parse_coord_edit(12L, "lon")$value, 12)
})

testthat::test_that("parse_coord_edit refuses empty, non-numeric and out-of-range values", {
    testthat::expect_identical(parse_coord_edit("", "lat")$error, "validate_coords_edit_error_empty")
    testthat::expect_identical(parse_coord_edit(NA, "lat")$error, "validate_coords_edit_error_empty")
    testthat::expect_identical(parse_coord_edit(character(0), "lon")$error, "validate_coords_edit_error_empty")
    testthat::expect_identical(parse_coord_edit("15 S", "lat")$error, "validate_coords_edit_error_number")
    testthat::expect_identical(parse_coord_edit("-90.5", "lat")$error, "validate_coords_edit_error_range_lat")
    testthat::expect_identical(parse_coord_edit("181", "lon")$error, "validate_coords_edit_error_range_lon")
    # The limits themselves are valid.
    testthat::expect_null(parse_coord_edit("-90", "lat")$error)
    testthat::expect_null(parse_coord_edit("180", "lon")$error)
    testthat::expect_true(is.na(parse_coord_edit("abc", "lat")$value))
})

testthat::test_that("the error keys exist in every language", {
    for (key in c("validate_coords_edit_error_empty", "validate_coords_edit_error_number",
                  "validate_coords_edit_error_range_lat", "validate_coords_edit_error_range_lon")) {
        for (lang in c("pt", "en")) {
            testthat::expect_false(identical(tr(key, lang), key), info = paste(key, lang))
        }
    }
})

testthat::test_that("coords_edit_allowed blocks rows without a unique occurrenceID", {
    testthat::expect_identical(
        coords_edit_allowed(c("a", "b", "a", "", NA, "c")),
        c(FALSE, TRUE, FALSE, FALSE, FALSE, TRUE)
    )
    # Blank IDs repeated among themselves do not block anyone else.
    testthat::expect_identical(coords_edit_allowed(c("", "", "x")), c(FALSE, FALSE, TRUE))
})

testthat::test_that("merge_manual_coord_edits lets the manual edit win and keeps verbatim columns", {
    auto <- list(corrections = data.frame(
        occurrenceID = c("utm", "swap"),
        decimalLatitude = c(-19.84565, -15.8), decimalLongitude = c(-56.2866, -47.9),
        verbatimLatitude = c("7805441", NA), verbatimLongitude = c("574699", NA),
        stringsAsFactors = FALSE
    ))
    manual <- data.frame(
        occurrenceID = c("utm", "new"),
        decimalLatitude = c(-19.9, -3.1), decimalLongitude = c(-56.3, -60.0),
        stringsAsFactors = FALSE
    )

    out <- merge_manual_coord_edits(auto, manual)$corrections

    testthat::expect_identical(out$occurrenceID, c("utm", "swap", "new"))
    testthat::expect_identical(out$decimalLatitude, c("-19.9", "-15.8", "-3.1"))
    testthat::expect_identical(out$decimalLongitude, c("-56.3", "-47.9", "-60"))
    # The UTM row still sends its projected original.
    testthat::expect_identical(out$verbatimLatitude, c("7805441", NA, NA))
})

testthat::test_that("merge_manual_coord_edits works without automatic corrections", {
    manual <- data.frame(occurrenceID = c("a", "a"), decimalLatitude = c(1, 2),
                         decimalLongitude = c(3, 4), stringsAsFactors = FALSE)
    out <- merge_manual_coord_edits(NULL, manual)$corrections
    # The last edit of the same record wins.
    testthat::expect_identical(out$decimalLatitude, "2")
    auto <- list(corrections = data.frame(occurrenceID = "x", decimalLatitude = 1, decimalLongitude = 2))
    testthat::expect_identical(merge_manual_coord_edits(auto, NULL), auto)
    testthat::expect_null(merge_manual_coord_edits(NULL, NULL))
})

testthat::test_that("merged edits reach the export through apply_coords_correction_payload", {
    df <- data.frame(
        occurrenceID = c("a", "b"),
        decimalLatitude = c("-47.9", "-10"), decimalLongitude = c("-15.8", "-50"),
        verbatimLatitude = c("", ""), verbatimLongitude = c("", ""),
        stringsAsFactors = FALSE
    )
    manual <- data.frame(occurrenceID = "a", decimalLatitude = -15.8,
                         decimalLongitude = -47.9, stringsAsFactors = FALSE)

    out <- apply_coords_correction_payload(df, merge_manual_coord_edits(NULL, manual))

    testthat::expect_identical(out$decimalLatitude, c("-15.8", "-10"))
    testthat::expect_identical(out$verbatimLatitude, c("-47.9", ""))
})

testthat::test_that("drop_orphan_coord_edits keeps edits whose record is still there", {
    edits <- data.frame(occurrenceID = c("a", "gone", "b"), decimalLatitude = 1:3,
                        decimalLongitude = 4:6, stringsAsFactors = FALSE)
    res <- drop_orphan_coord_edits(edits, c("a", "b", "c"))
    testthat::expect_identical(res$edits$occurrenceID, c("a", "b"))
    testthat::expect_identical(res$dropped, 1L)
    testthat::expect_identical(drop_orphan_coord_edits(NULL, "a"), list(edits = NULL, dropped = 0L))
    testthat::expect_null(drop_orphan_coord_edits(edits, character(0))$edits)
})

testthat::test_that("revalidate_coord_rows keeps the row index of the full result", {
    testthat::skip_on_cran()
    testthat::local_mocked_bindings(
        coords_assert_cc_dependencies = function() NULL,
        coords_country_to_iso3 = function(country_values) rep("BRA", length(country_values)),
        coords_cc_flagged = function(fun_name, x, ...) rep(TRUE, nrow(x)),
        coords_cc_sea_flagged = function(x, scale, timeout = NULL) rep(TRUE, nrow(x)),
        .package = "saira"
    )
    rows <- data.frame(decimalLatitude = c("-15.8", "95"), decimalLongitude = c("-47.9", "-50"),
                       country = "Brasil", stringsAsFactors = FALSE)
    res <- revalidate_coord_rows(rows, row_index = c(42L, 7L))
    testthat::expect_identical(res$.row_index, c(42L, 7L))
    testthat::expect_identical(res$diagnostic[[1]], "ok")
    testthat::expect_false(res$valid[[2]])
    testthat::expect_identical(nrow(revalidate_coord_rows(rows[0, ], integer(0))), 0L)
})

testthat::test_that("apply_manual_coord_edits_to_result shows the edited point and its new diagnosis", {
    res <- data.frame(
        .row_index = 1:3, lat_num = c(-10, 20, -30), lon_num = c(-50, -40, -60),
        diagnostic = c("ok", "sea", "sea"), diagnostic_family = c("ok", "sea", "sea"),
        valid = c(TRUE, FALSE, FALSE), stringsAsFactors = FALSE
    )
    edits <- data.frame(
        occurrenceID = c("b", "c"), row_index = c(2L, 3L),
        decimalLatitude = c("-20", "-31"), decimalLongitude = c("-45", "-35"),
        diagnostic = c("ok", "sea"), diagnostic_family = c("ok", "sea"), valid = c(TRUE, FALSE),
        stringsAsFactors = FALSE
    )

    out <- apply_manual_coord_edits_to_result(res, edits)

    testthat::expect_identical(out$edited, c(FALSE, TRUE, TRUE))
    testthat::expect_identical(out$lat_num, c(-10, -20, -31))
    # A point that now passes reads as corrected; one still at sea keeps its problem.
    testthat::expect_identical(out$diagnostic_family, c("ok", "corrected", "sea"))
    testthat::expect_identical(out$valid, c(TRUE, TRUE, FALSE))
    testthat::expect_identical(apply_manual_coord_edits_to_result(res, NULL)$edited, rep(FALSE, 3))
})

testthat::test_that("build_leaflet_data keeps only edited rows under the edited filter", {
    res <- data.frame(
        .row_index = 1:2, lat_num = c(-10, -20), lon_num = c(-50, -45),
        diagnostic = c("ok", "corrected"), diagnostic_family = c("ok", "corrected"),
        edited = c(FALSE, TRUE), stringsAsFactors = FALSE
    )
    testthat::expect_identical(build_leaflet_data(res, filter = "edited")$.row_index, 2L)
    testthat::expect_identical(nrow(build_leaflet_data(res, filter = "all")), 2L)
})
