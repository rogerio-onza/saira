# Title: Tests for export date normalization utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-14
# Version: 1.0

testthat::test_that("abbreviate_license normalizes known values and preserves unknowns", {
    licenses <- c(
        "https://creativecommons.org/publicdomain/zero/1.0/legalcode",
        "http://creativecommons.org/publicdomain/zero/1.0/",
        "CC0",
        "https://creativecommons.org/licenses/by/4.0/",
        "http://creativecommons.org/licenses/by/4.0/legalcode",
        "cc-by",
        "https://creativecommons.org/licenses/by-nc/4.0/",
        "CC-BY-NC",
        "custom-license",
        NA_character_
    )

    out <- abbreviate_license(licenses)
    expected <- c(
        "CC0",
        "CC0",
        "CC0",
        "CC-BY",
        "CC-BY",
        "CC-BY",
        "CC-BY-NC",
        "CC-BY-NC",
        "custom-license",
        NA_character_
    )
    testthat::expect_identical(out, expected)
})

testthat::test_that("abbreviate_license_column handles missing and existing columns", {
    no_license <- data.frame(id = c("a", "b"), stringsAsFactors = FALSE)
    with_license <- data.frame(
        license = c("https://creativecommons.org/licenses/by/4.0/", "custom-license"),
        stringsAsFactors = FALSE
    )

    testthat::expect_identical(abbreviate_license_column(no_license), no_license)
    out <- abbreviate_license_column(with_license)
    testthat::expect_identical(out$license, c("CC-BY", "custom-license"))
})

testthat::test_that("clean_coordinate_separators converts decimal comma and invalids to NA", {
    df <- data.frame(
        decimalLatitude = c("-23,55", "foo", ""),
        decimalLongitude = c("-46,63", "181,00", "bar"),
        stringsAsFactors = FALSE
    )

    out <- clean_coordinate_separators(df)
    testthat::expect_equal(out$decimalLatitude, c(-23.55, NA_real_, NA_real_))
    testthat::expect_equal(out$decimalLongitude, c(-46.63, 181.00, NA_real_))
})

testthat::test_that("add_occurrence_ids creates ids when column is absent", {
    df <- data.frame(scientificName = c("A", "B", "C"), stringsAsFactors = FALSE)
    out <- add_occurrence_ids(df)

    testthat::expect_true("occurrenceID" %in% names(out))
    testthat::expect_equal(length(out$occurrenceID), nrow(df))
    testthat::expect_false(any(is.na(out$occurrenceID) | out$occurrenceID == ""))
})

testthat::test_that("add_occurrence_ids preserves existing values and fills missing", {
    df <- data.frame(
        occurrenceID = c("keep-id", "", NA_character_),
        stringsAsFactors = FALSE
    )
    out <- add_occurrence_ids(df)

    testthat::expect_identical(out$occurrenceID[1], "keep-id")
    testthat::expect_false(any(is.na(out$occurrenceID) | out$occurrenceID == ""))
    testthat::expect_true(all(out$occurrenceID[2:3] != "keep-id"))
})

testthat::test_that("fix_dates_to_iso delegates to parser and preserves raw invalid values", {
    input_dates <- c(
        "2023-12-25",
        "25/12/2023",
        "25-12-2023",
        "25.12.2023",
        "25/12/23",
        "31/02/2023",
        "foo",
        NA_character_,
        ""
    )

    expected_from_parser <- parse_dates_to_iso(input_dates)
    keep_raw <- is.na(expected_from_parser) & !is.na(input_dates) & nzchar(input_dates)
    expected_export <- expected_from_parser
    expected_export[keep_raw] <- input_dates[keep_raw]

    df <- data.frame(
        eventDate = input_dates,
        dateIdentified = input_dates,
        modified = input_dates,
        stringsAsFactors = FALSE
    )

    out <- fix_dates_to_iso(df)
    testthat::expect_identical(out$eventDate, expected_export)
    testthat::expect_identical(out$dateIdentified, expected_export)
    testthat::expect_identical(out$modified, expected_export)
})

testthat::test_that("fix_dates_to_iso leaves non-date columns unchanged", {
    df <- data.frame(
        other_col = c("25/12/2023", "foo", ""),
        stringsAsFactors = FALSE
    )

    out <- fix_dates_to_iso(df)
    testthat::expect_identical(out, df)
})

testthat::test_that("process_for_export keeps date semantics and runs full pipeline", {
    df <- data.frame(
        eventDate = c("25/12/2023", "foo", ""),
        dateIdentified = c("18/05/09", "31/02/2023", NA_character_),
        modified = c("25.12.2023", "bar", ""),
        decimalLatitude = c("-23,55", "-22,10", ""),
        decimalLongitude = c("-46,63", "-43,17", ""),
        occurrenceID = c("", NA_character_, "existing-id"),
        license = c(
            "https://creativecommons.org/publicdomain/zero/1.0/legalcode",
            "https://creativecommons.org/licenses/by/4.0/",
            "custom-license"
        ),
        stringsAsFactors = FALSE
    )

    out <- process_for_export(df)

    expected_date_identified <- parse_dates_to_iso(df$dateIdentified)
    raw_mask <- is.na(expected_date_identified) & !is.na(df$dateIdentified) & nzchar(df$dateIdentified)
    expected_date_identified[raw_mask] <- df$dateIdentified[raw_mask]

    testthat::expect_identical(out$eventDate, c("2023-12-25", "foo", NA_character_))
    testthat::expect_identical(out$dateIdentified, expected_date_identified)
    testthat::expect_identical(out$modified, c("2023-12-25", "bar", NA_character_))
    testthat::expect_equal(out$decimalLatitude, c(-23.55, -22.10, NA_real_))
    testthat::expect_equal(out$decimalLongitude, c(-46.63, -43.17, NA_real_))
    testthat::expect_false(any(is.na(out$occurrenceID) | out$occurrenceID == ""))
    testthat::expect_identical(out$occurrenceID[3], "existing-id")
    testthat::expect_identical(out$license, c("CC0", "CC-BY", "custom-license"))
})
