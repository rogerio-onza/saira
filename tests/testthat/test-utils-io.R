# Title: Tests for I/O date parsing utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-14
# Version: 1.0

expected_year_from_two_digits <- function(two_digits) {
    current_yy <- as.integer(format(Sys.Date(), "%y"))
    ifelse(
        two_digits <= current_yy,
        2000L + two_digits,
        1900L + two_digits
    )
}

testthat::test_that("parse_dates_to_iso parses supported formats and keeps invalid as NA", {
    input <- c(
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

    yy_year <- expected_year_from_two_digits(23L)
    expected <- c(
        "2023-12-25",
        "2023-12-25",
        "2023-12-25",
        "2023-12-25",
        sprintf("%04d-12-25", yy_year),
        NA_character_,
        NA_character_,
        NA_character_,
        NA_character_
    )

    out <- parse_dates_to_iso(input)
    testthat::expect_identical(out, expected)
})

testthat::test_that("parse_dates_to_iso applies dynamic cutoff for DD/MM/YY", {
    current_yy <- as.integer(format(Sys.Date(), "%y"))
    next_yy <- as.integer((current_yy + 1L) %% 100L)

    input <- c(
        sprintf("18/05/%02d", current_yy),
        sprintf("18/05/%02d", next_yy),
        "18/05/99",
        "18/05/09"
    )

    expected_years <- c(
        expected_year_from_two_digits(current_yy),
        expected_year_from_two_digits(next_yy),
        expected_year_from_two_digits(99L),
        expected_year_from_two_digits(9L)
    )
    expected <- sprintf("%04d-05-18", expected_years)

    out <- parse_dates_to_iso(input)
    testthat::expect_identical(out, expected)
})

testthat::test_that("parse_dates_to_iso handles factors and empty inputs", {
    input <- factor(c("25/12/2023", "foo", ""))
    out <- parse_dates_to_iso(input)
    testthat::expect_identical(out, c("2023-12-25", NA_character_, NA_character_))

    out_empty <- parse_dates_to_iso(character())
    testthat::expect_identical(out_empty, character())
})
