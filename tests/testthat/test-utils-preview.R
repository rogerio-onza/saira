# Title: Tests for Preview Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-15
# Version: 1.0

testthat::test_that("prepare_preview_data limits rows and abbreviates license", {
    prepare <- saira:::prepare_preview_data

    df <- data.frame(
        scientificName = sprintf("name_%03d", seq_len(120)),
        license = rep("https://creativecommons.org/publicdomain/zero/1.0/legalcode", 120),
        stringsAsFactors = FALSE
    )

    out <- prepare(df, max_rows = 100L)

    testthat::expect_s3_class(out, "data.frame")
    testthat::expect_equal(nrow(out), 100L)
    testthat::expect_true(all(out$license == "CC0"))
})

testthat::test_that("prepare_preview_data validates dataframe and max_rows", {
    prepare <- saira:::prepare_preview_data

    testthat::expect_error(
        prepare("not-a-dataframe", max_rows = 100L),
        "df must be a data.frame"
    )

    testthat::expect_error(
        prepare(data.frame(a = 1), max_rows = 0L),
        "max_rows must be a positive integer"
    )
})

testthat::test_that("validate_preview_download_requirements blocks missing mandatory fields", {
    validate_download <- saira:::validate_preview_download_requirements

    df <- data.frame(
        scientificName = c("Panthera onca", ""),
        eventDate = c("2020-01-01", ""),
        stringsAsFactors = FALSE
    )

    result <- validate_download(df)

    testthat::expect_false(result$ok)
    testthat::expect_true(result$has_rows)
    testthat::expect_true("decimalLatitude" %in% result$blocking_missing)
    testthat::expect_true("decimalLongitude" %in% result$blocking_missing)
    testthat::expect_true("basisOfRecord" %in% result$blocking_missing)
    testthat::expect_true("occurrenceID" %in% result$warning_missing)
})

testthat::test_that("validate_preview_download_requirements allows export when mandatory fields are present", {
    validate_download <- saira:::validate_preview_download_requirements

    df <- data.frame(
        scientificName = c("Panthera onca"),
        eventDate = c("2020-01-01"),
        decimalLatitude = c("-10.1"),
        decimalLongitude = c("-40.2"),
        basisOfRecord = c("HumanObservation"),
        stringsAsFactors = FALSE
    )

    result <- validate_download(df)

    testthat::expect_true(result$ok)
    testthat::expect_true(result$has_rows)
    testthat::expect_length(result$blocking_missing, 0L)
    testthat::expect_true("occurrenceID" %in% result$warning_missing)
})
