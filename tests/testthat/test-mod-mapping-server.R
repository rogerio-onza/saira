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

testthat::test_that("mod_mapping_server exposes lightweight preview_data alongside full reactive output", {
    df <- data.frame(
        scientificName = sprintf("name_%03d", seq_len(150)),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            returned <- session$getReturned()
            testthat::expect_true(shiny::is.reactive(returned))

            full_df <- returned()
            testthat::expect_true(is.data.frame(full_df))
            testthat::expect_equal(nrow(full_df), 150L)

            preview_r <- attr(returned, "preview_data")
            testthat::expect_true(shiny::is.reactive(preview_r))

            preview_df <- preview_r()
            testthat::expect_true(is.data.frame(preview_df))
            testthat::expect_equal(nrow(preview_df), 100L)
            testthat::expect_true("occurrenceID" %in% names(preview_df))
            testthat::expect_match(preview_df$occurrenceID[[1]], "^preview-", perl = TRUE)
        }
    )
})

testthat::test_that("mod_mapping_server exposes validation_gate reactive with expected transitions", {
    raw_data_state <- shiny::reactiveVal(NULL)

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(raw_data_state()),
            lang_r = shiny::reactive("en")
        ),
        {
            returned <- session$getReturned()
            validation_gate <- attr(returned, "validation_gate")

            testthat::expect_true(shiny::is.reactive(validation_gate))

            gate <- validation_gate()
            testthat::expect_identical(gate$status, "no_data")
            testthat::expect_false(gate$has_data)
            testthat::expect_identical(gate$scientific_col, "")

            raw_data_state(data.frame(scientificName = c("Puma concolor"), stringsAsFactors = FALSE))
            session$flushReact()

            gate <- validation_gate()
            testthat::expect_identical(gate$status, "missing_scientific")
            testthat::expect_true(gate$has_data)
            testthat::expect_identical(gate$scientific_col, "")

            session$setInputs(map_scientificName = "scientificName")
            session$flushReact()

            gate <- validation_gate()
            testthat::expect_identical(gate$status, "ok")
            testthat::expect_true(gate$has_data)
            testthat::expect_identical(gate$scientific_col, "scientificName")
        }
    )
})

testthat::test_that("mod_mapping_server exposes coordinate validation gate with expected transitions", {
    raw_data_state <- shiny::reactiveVal(NULL)

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(raw_data_state()),
            lang_r = shiny::reactive("en")
        ),
        {
            returned <- session$getReturned()
            coord_gate <- attr(returned, "validation_gate_coords")

            testthat::expect_true(shiny::is.reactive(coord_gate))

            gate <- coord_gate()
            testthat::expect_identical(gate$coords_status, "no_data")
            testthat::expect_false(gate$has_data)
            testthat::expect_identical(gate$lat_col, "")
            testthat::expect_identical(gate$lon_col, "")
            testthat::expect_identical(gate$country_col, "")

            raw_data_state(data.frame(
                decimalLatitude = c("-10.1"),
                decimalLongitude = c("-45.2"),
                country_name = c("Brasil"),
                stringsAsFactors = FALSE
            ))
            session$flushReact()

            gate <- coord_gate()
            testthat::expect_identical(gate$coords_status, "missing_multiple")
            testthat::expect_true(gate$has_data)
            testthat::expect_false(gate$has_lat)
            testthat::expect_false(gate$has_lon)
            testthat::expect_false(gate$has_country)

            session$setInputs(map_decimalLatitude = "decimalLatitude")
            session$flushReact()
            gate <- coord_gate()
            testthat::expect_identical(gate$coords_status, "missing_multiple")
            testthat::expect_identical(gate$lat_col, "decimalLatitude")
            testthat::expect_true(gate$has_lat)

            session$setInputs(map_decimalLongitude = "decimalLongitude")
            session$flushReact()
            gate <- coord_gate()
            testthat::expect_identical(gate$coords_status, "missing_country")
            testthat::expect_true(gate$has_lon)
            testthat::expect_identical(gate$lon_col, "decimalLongitude")

            session$setInputs(map_country = "country_name")
            session$flushReact()
            gate <- coord_gate()
            testthat::expect_identical(gate$coords_status, "ok")
            testthat::expect_true(gate$has_country)
            testthat::expect_identical(gate$country_col, "country_name")
        }
    )
})

testthat::test_that("validation gates stay in no_data when upstream raw_data_r is req-gated", {
    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive({
                shiny::req(FALSE)
                data.frame(scientificName = "x", stringsAsFactors = FALSE)
            }),
            lang_r = shiny::reactive("en")
        ),
        {
            returned <- session$getReturned()
            validation_gate <- attr(returned, "validation_gate")
            coord_gate <- attr(returned, "validation_gate_coords")

            gate <- validation_gate()
            testthat::expect_identical(gate$status, "no_data")
            testthat::expect_false(gate$has_data)
            testthat::expect_identical(gate$scientific_col, "")

            cgate <- coord_gate()
            testthat::expect_identical(cgate$coords_status, "no_data")
            testthat::expect_false(cgate$has_data)
            testthat::expect_identical(cgate$lat_col, "")
            testthat::expect_identical(cgate$lon_col, "")
            testthat::expect_identical(cgate$country_col, "")
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

testthat::test_that("basisOfRecord assistant persists mapping and processed_data keeps single value", {
    df <- data.frame(
        basis_raw = c(
            "Active searching, Camera trap, Opportunistic",
            "humanobservation",
            "Unknown method"
        ),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(map_basisOfRecord = "basis_raw")
            session$flushReact()

            session$setInputs(open_basis_of_record_assistant = 1)
            session$flushReact()

            testthat::expect_true(nrow(rv$basis_of_record_entries) >= 2)

            first_idx <- rv$basis_of_record_entries$idx[[1]]
            first_key <- rv$basis_of_record_entries$key[[1]]
            dynamic_input <- list()
            dynamic_input[[paste0("basis_of_record_target_", first_idx)]] <- "HumanObservation"
            do.call(session$setInputs, dynamic_input)
            session$flushReact()

            testthat::expect_false(first_key %in% names(rv$basis_of_record_draft_map))

            session$setInputs(save_basis_of_record_assistant = 1)
            session$flushReact()

            testthat::expect_identical(rv$basis_of_record_map[[first_key]], "HumanObservation")

            out <- processed_data()
            testthat::expect_true("basisOfRecord" %in% names(out))
            testthat::expect_false(any(grepl("\\|", out$basisOfRecord)))
        }
    )
})

testthat::test_that("basisOfRecord assistant allows overriding auto-suggestion with skip", {
    df <- data.frame(
        basis_raw = c("humanobservation"),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(map_basisOfRecord = "basis_raw")
            session$setInputs(open_basis_of_record_assistant = 1)
            session$flushReact()

            testthat::expect_identical(nrow(rv$basis_of_record_entries), 1L)
            first_idx <- rv$basis_of_record_entries$idx[[1]]
            first_key <- rv$basis_of_record_entries$key[[1]]

            dynamic_input <- list()
            dynamic_input[[paste0("basis_of_record_target_", first_idx)]] <- ""
            do.call(session$setInputs, dynamic_input)
            session$setInputs(save_basis_of_record_assistant = 1)
            session$flushReact()

            testthat::expect_true(first_key %in% names(rv$basis_of_record_map))
            testthat::expect_identical(rv$basis_of_record_map[[first_key]], "")

            out <- processed_data()
            testthat::expect_identical(out$basisOfRecord[[1]], "")
        }
    )
})

testthat::test_that("basisOfRecord assistant map is cleared when source column changes", {
    df <- data.frame(
        bor_a = c("HumanObservation", "Unknown method"),
        bor_b = c("MachineObservation", "PreservedSpecimen"),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(map_basisOfRecord = "bor_a")
            session$setInputs(open_basis_of_record_assistant = 1)
            session$flushReact()

            if (nrow(rv$basis_of_record_entries) > 0) {
                first_idx <- rv$basis_of_record_entries$idx[[1]]
                dynamic_input <- list()
                dynamic_input[[paste0("basis_of_record_target_", first_idx)]] <- "HumanObservation"
                do.call(session$setInputs, dynamic_input)
                session$setInputs(save_basis_of_record_assistant = 1)
                session$flushReact()
                testthat::expect_true(length(rv$basis_of_record_map) > 0)
            }

            session$setInputs(map_basisOfRecord = "bor_b")
            session$flushReact()

            testthat::expect_identical(length(rv$basis_of_record_map), 0L)
            testthat::expect_identical(rv$basis_of_record_source_col, "bor_b")
        }
    )
})

testthat::test_that("basisOfRecord assistant opens using input fallback when rv map is not yet synced", {
    df <- data.frame(
        basis_raw = c("HumanObservation", "Unknown method", "MachineObservation"),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(map_basisOfRecord = "basis_raw")
            session$flushReact()

            rv$map_values$basisOfRecord <- ""
            session$setInputs(open_basis_of_record_assistant = 1)
            session$flushReact()

            testthat::expect_identical(rv$basis_of_record_source_col, "basis_raw")
            testthat::expect_true(nrow(rv$basis_of_record_entries) >= 2)
        }
    )
})
