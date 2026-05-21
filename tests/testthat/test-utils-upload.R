# Title: Tests for Upload Module Helpers
# Author: Rogerio Nunes Oliveira
# Date: 2026-05-20
# ADR-097: Pure UI builders for the format-requirements panel.

sample_required_terms <- function() {
    data.frame(
        term = c("scientificName", "eventDate", "decimalLatitude",
                 "decimalLongitude", "basisOfRecord", "occurrenceID"),
        class = c("Taxon", "Occurrence", "Location",
                  "Location", "Record-level", "Occurrence"),
        definition_pt = c("nome cientifico", "data do evento", "latitude",
                          "longitude", "base do registro", "id da ocorrencia"),
        definition_en = c("scientific name", "event date", "latitude",
                          "longitude", "basis of record", "occurrence id"),
        stringsAsFactors = FALSE
    )
}

testthat::test_that("upload_csv_requirements_ui groups terms by 4 DwC classes (PT)", {
    tag <- upload_csv_requirements_ui(sample_required_terms(), "pt")
    html <- as.character(tag)

    testthat::expect_true(grepl("dwc-inline-groups", html))
    testthat::expect_true(grepl("dwc-group-badge--record-level", html))
    testthat::expect_true(grepl("dwc-group-badge--occurrence", html))
    testthat::expect_true(grepl("dwc-group-badge--taxon", html))
    testthat::expect_true(grepl("dwc-group-badge--location", html))
    testthat::expect_true(grepl("scientificName", html))
    testthat::expect_true(grepl("decimalLatitude", html))
})

testthat::test_that("upload_csv_requirements_ui swaps definitions per language", {
    tag_en <- upload_csv_requirements_ui(sample_required_terms(), "en")
    html_en <- as.character(tag_en)
    testthat::expect_true(grepl("scientific name", html_en))
    testthat::expect_false(grepl("nome cientifico", html_en))
})

testthat::test_that("upload_csv_requirements_ui returns warning alert when terms missing", {
    empty <- sample_required_terms()[0, , drop = FALSE]
    tag <- upload_csv_requirements_ui(empty, "en")
    html <- as.character(tag)
    testthat::expect_true(grepl("alert-warning", html))
})

testthat::test_that("upload_camtrap_requirements_ui builds 2 groups with 8 file rows (PT)", {
    tag <- upload_camtrap_requirements_ui("pt")
    html <- as.character(tag)

    testthat::expect_true(grepl("upload-file-list", html))
    testthat::expect_equal(length(gregexpr("upload-file-list-group", html, fixed = TRUE)[[1]]), 4L)
    testthat::expect_equal(length(gregexpr("upload-file-row\"", html, fixed = TRUE)[[1]]), 8L)
    testthat::expect_true(grepl("datapackage.json", html))
    testthat::expect_true(grepl("observations.csv", html))
    testthat::expect_true(grepl("images_\\*.csv", html))
})

testthat::test_that("upload_camtrap_requirements_ui marks 6 required and 2 optional badges", {
    tag <- upload_camtrap_requirements_ui("en")
    html <- as.character(tag)

    required_count <- length(gregexpr("is-required", html, fixed = TRUE)[[1]])
    optional_count <- length(gregexpr("is-optional", html, fixed = TRUE)[[1]])
    testthat::expect_equal(required_count, 6L)
    testthat::expect_equal(optional_count, 2L)
})

testthat::test_that("upload_camtrap_requirements_ui translates labels per language", {
    tag_pt <- upload_camtrap_requirements_ui("pt")
    tag_en <- upload_camtrap_requirements_ui("en")
    testthat::expect_true(grepl("monitoramento", as.character(tag_pt), fixed = TRUE))
    testthat::expect_true(grepl("Camera deployments", as.character(tag_en), fixed = TRUE))
    testthat::expect_true(grepl("obrigat", as.character(tag_pt), fixed = TRUE))
    testthat::expect_true(grepl("required", as.character(tag_en), fixed = TRUE))
})
