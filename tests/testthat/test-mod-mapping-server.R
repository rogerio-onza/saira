# Title: Tests for Mapping Module Server
# Author: RogÃ©rio Nunes Oliveira
# Date: 2026-02-12
# Version: 1.0

testthat::test_that("legacy auto-map works with toggle off and keeps badges hidden", {
    df <- data.frame(
        scientificName = c("Panthera onca", "Leopardus pardalis"),
        decimalLatitude = c("-10.1", "-11.2"),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(enable_automap_v1 = FALSE)
            session$setInputs(auto_map = 1)
            session$flushReact()

            testthat::expect_identical(rv$map_values$scientificName, "scientificName")
            testthat::expect_identical(rv$map_values$decimalLatitude, "decimalLatitude")
            testthat::expect_true(all(vapply(rv$map_meta, function(x) is.na(x$status), FUN.VALUE = logical(1))))
        }
    )
})

testthat::test_that("v1 auto-map applies metadata and manual override becomes EDITADO", {
    df <- data.frame(
        scientificName = c("Panthera onca", "Leopardus pardalis"),
        taxon_name = c("Leopardus geoffroyi", "Leopardus wiedii"),
        recorded_by = c("A", "B"),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(enable_automap_v1 = TRUE)
            session$setInputs(auto_map = 1)
            session$flushReact()

            testthat::expect_true(rv$map_meta$scientificName$status %in% c("AUTO", "SUGERIDO", "MANUAL"))

            session$setInputs(map_scientificName = "taxon_name")
            session$flushReact()

            testthat::expect_identical(rv$map_values$scientificName, "taxon_name")
            testthat::expect_identical(rv$map_meta$scientificName$status, "EDITADO")
        }
    )
})

testthat::test_that("reset clears mapping state and keeps processed_data contract", {
    df <- data.frame(
        scientificName = c("Panthera onca", "Leopardus pardalis"),
        individualCount = c("1", "2"),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(enable_automap_v1 = TRUE)
            session$setInputs(auto_map = 1)
            session$flushReact()

            out_before <- processed_data()
            testthat::expect_true(is.data.frame(out_before))
            testthat::expect_true("occurrenceID" %in% names(out_before))

            session$setInputs(confirm_reset = 1)
            session$flushReact()

            testthat::expect_identical(rv$map_values$scientificName, "")
            testthat::expect_true(is.na(rv$map_meta$scientificName$status))

            out_after <- processed_data()
            testthat::expect_true(is.data.frame(out_after))
            testthat::expect_true("occurrenceID" %in% names(out_after))
        }
    )
})

testthat::test_that("mapping state survives filter changes in server state", {
    df <- data.frame(
        scientificName = c("Panthera onca", "Leopardus pardalis"),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(map_scientificName = "scientificName")
            session$flushReact()

            session$setInputs(filter_categories = character(0))
            session$flushReact()
            session$setInputs(filter_categories = c("Taxon", "Occurrence"))
            session$flushReact()

            testthat::expect_identical(rv$map_values$scientificName, "scientificName")
        }
    )
})

testthat::test_that("badge metadata survives select-all category toggling after v1 automap", {
    df <- data.frame(
        scientificName = c("Panthera onca", "Leopardus pardalis"),
        stringsAsFactors = FALSE
    )

    all_categories <- c("Record-level", "Occurrence", "Event", "Location", "Taxon", "Identification")

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(enable_automap_v1 = TRUE)
            session$setInputs(auto_map = 1)
            session$flushReact()

            status_before <- rv$map_meta$scientificName$status
            testthat::expect_false(is.na(status_before))

            session$setInputs(select_all_categories = FALSE, filter_categories = character(0))
            session$flushReact()
            session$setInputs(select_all_categories = TRUE, filter_categories = all_categories)
            session$flushReact()

            status_after <- rv$map_meta$scientificName$status
            testthat::expect_false(is.na(status_after))
            testthat::expect_identical(status_after, status_before)
        }
    )
})

testthat::test_that("processed_data keeps eventDate interval parsing contract and updates warning counter", {
    df <- data.frame(
        COL_START_MO = c("Aug", "foo"),
        COL_START_YR = c("2017", "2017"),
        COL_END_MO = c("Jun", "Jun"),
        COL_END_YR = c("2018", "2018"),
        scientific_col = c("Panthera onca", "Leopardus"),
        recorded_by = c("Ana; Bruno", NA_character_),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(map_eventDate = c("COL_START_MO", "COL_START_YR", "COL_END_MO", "COL_END_YR"))
            session$setInputs(map_scientificName = "scientific_col")
            session$setInputs(map_recordedBy = "recorded_by")
            session$flushReact()

            out <- processed_data()
            testthat::expect_true(is.data.frame(out))
            testthat::expect_identical(rv$eventdate_parse_failures, 1L)
            testthat::expect_identical(out$eventDate[[1]], "2017-08/2018-06")
            testthat::expect_identical(out$eventDate[[2]], "foo | 2017 | Jun | 2018")
            testthat::expect_identical(out$recordedBy[[1]], "Ana | Bruno")
            testthat::expect_identical(out$recordedBy[[2]], "")
            testthat::expect_identical(out$genus, c("Panthera", "Leopardus"))
            testthat::expect_identical(out$specificEpithet, c("onca", ""))
            testthat::expect_identical(out$taxonRank, c("species", "genus"))
        }
    )
})

testthat::test_that("reactive mapping state remains consistent after filter toggles and reset", {
    df <- data.frame(
        scientificName = c("Panthera onca", "Leopardus pardalis"),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(enable_automap_v1 = TRUE)
            session$setInputs(auto_map = 1)
            session$flushReact()

            session$setInputs(custom_datasetName = "Dataset Manual")
            session$flushReact()

            testthat::expect_identical(rv$map_meta$datasetName$status, "EDITADO")
            testthat::expect_identical(rv$map_meta$datasetName$reason, "manual_adjust")

            session$setInputs(filter_categories = character(0))
            session$flushReact()
            session$setInputs(filter_categories = c("Record-level", "Taxon", "Occurrence"))
            session$flushReact()

            out_before_reset <- processed_data()
            testthat::expect_true(is.data.frame(out_before_reset))
            testthat::expect_true("occurrenceID" %in% names(out_before_reset))
            testthat::expect_identical(rv$map_values$scientificName, "scientificName")

            session$setInputs(confirm_reset = 1)
            session$flushReact()

            out_after_reset <- processed_data()
            testthat::expect_true(is.data.frame(out_after_reset))
            testthat::expect_true("occurrenceID" %in% names(out_after_reset))
            testthat::expect_identical(rv$map_values$scientificName, "")
            testthat::expect_true(is.na(rv$map_meta$datasetName$status))
        }
    )
})
