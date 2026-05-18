# Title: Tests for Mapping Module Server
# Author: RogÃ©rio Nunes Oliveira
# Date: 2026-02-12
# Version: 1.0

testthat::test_that("rostrum auto-map runs by default and fills badge metadata", {
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
            session$setInputs(auto_map = 1)
            session$flushReact()

            testthat::expect_identical(rv$map_values$scientificName, "scientificName")
            testthat::expect_identical(rv$map_values$decimalLatitude, "decimalLatitude")
            testthat::expect_false(is.na(rv$map_meta$scientificName$status))
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
            testthat::expect_true(is.list(returned))
            testthat::expect_named(
                returned,
                c(
                    "processed_data_r", "preview_data_r",
                    "validation_gate_r", "validation_gate_coords_r",
                    "rostrum_decisions_r", "rostrum_explain_r", "rostrum_run_stats_r",
                    "map_values_r"
                )
            )

            full_df <- returned$processed_data_r()
            testthat::expect_true(is.data.frame(full_df))
            testthat::expect_equal(nrow(full_df), 150L)

            preview_r <- returned$preview_data_r
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
            validation_gate <- returned$validation_gate_r

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
            coord_gate <- returned$validation_gate_coords_r

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
            validation_gate <- returned$validation_gate_r
            coord_gate <- returned$validation_gate_coords_r

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
    # Isolate from the user's real ~/.local/share/saira/rostrum.sqlite. Without
    # this, aliases the developer accumulated during interactive testing leak
    # into the test (the engine's alias-lookup hits them under user_id =
    # "anonymous"), which can flip auto-map status to ALIAS and break the
    # EDITADO assertion below.
    withr::local_envvar(c(SAIRA_USER = paste0("test_isolation_", as.integer(Sys.time()))))

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
            session$setInputs(auto_map = 1)
            session$flushReact()

            testthat::expect_true(rv$map_meta$scientificName$status %in% c("AUTO", "SUGERIDO", "AMBIGUO", "MANUAL"))

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

            session$setInputs(class_pill_taxon = 1)
            session$flushReact()
            session$setInputs(class_pill_all = 1)
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

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(auto_map = 1)
            session$flushReact()

            status_before <- rv$map_meta$scientificName$status
            testthat::expect_false(is.na(status_before))

            session$setInputs(class_pill_taxon = 1)
            session$flushReact()
            session$setInputs(class_pill_all = 1)
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
            session$setInputs(auto_map = 1)
            session$flushReact()

            session$setInputs(custom_datasetName = "Dataset Manual")
            session$flushReact()

            testthat::expect_identical(rv$map_meta$datasetName$status, "EDITADO")
            testthat::expect_identical(rv$map_meta$datasetName$reason, "manual_adjust")

            session$setInputs(class_pill_taxon = 1)
            session$flushReact()
            session$setInputs(class_pill_all = 1)
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

testthat::test_that("engine stage-1 failure does not overwrite rv$rostrum_decisions with empty result", {
    bad_string <- rawToChar(c(charToRaw("Pacaj"), as.raw(0xe1L)))
    df <- data.frame(MUNICIPALITY = bad_string, stringsAsFactors = FALSE)

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            original_decisions <- rv$rostrum_decisions
            session$setInputs(auto_map = 1)
            session$flushReact()

            testthat::expect_identical(rv$rostrum_decisions, original_decisions)
        }
    )
})

testthat::test_that("dynamicProperties observer captures per-column key overrides and propagates to processed_data", {
    df <- data.frame(
        scientificName = c("Puma concolor", "Panthera onca"),
        protectarea = c("yes", "no"),
        protect_area_type = c("IV", "II"),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()

            # Map two columns to dynamicProperties
            session$setInputs(map_dynamicProperties = c("protectarea", "protect_area_type"))
            session$flushReact()

            # Default: no overrides; processed_data uses auto-derived keys
            full_df <- session$getReturned()$processed_data_r()
            testthat::expect_true("dynamicProperties" %in% names(full_df))
            testthat::expect_identical(
                full_df$dynamicProperties[[1]],
                "{\"protectarea\":\"yes\",\"protect_area_type\":\"IV\"}"
            )

            # User overrides the second column's key
            session$setInputs(dynprops_key_protect_area_type = "type")
            session$flushReact()

            testthat::expect_identical(rv$dyn_props_keys[["protect_area_type"]], "type")

            full_df2 <- session$getReturned()$processed_data_r()
            testthat::expect_identical(
                full_df2$dynamicProperties[[1]],
                "{\"protectarea\":\"yes\",\"type\":\"IV\"}"
            )

            # Blanking the override returns to auto-derived
            session$setInputs(dynprops_key_protect_area_type = "")
            session$flushReact()

            testthat::expect_null(rv$dyn_props_keys[["protect_area_type"]])

            full_df3 <- session$getReturned()$processed_data_r()
            testthat::expect_identical(
                full_df3$dynamicProperties[[1]],
                "{\"protectarea\":\"yes\",\"protect_area_type\":\"IV\"}"
            )
        }
    )
})

testthat::test_that("dynamicProperties keys reset when raw_data_r changes", {
    raw_data_state <- shiny::reactiveVal(data.frame(
        protectarea = "yes",
        stringsAsFactors = FALSE
    ))

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(raw_data_state()),
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            session$setInputs(map_dynamicProperties = "protectarea")
            session$setInputs(dynprops_key_protectarea = "custom_key")
            session$flushReact()

            testthat::expect_identical(rv$dyn_props_keys[["protectarea"]], "custom_key")

            # Replace raw data + clear stale inputs (production: UI re-renders).
            # The reset observer must clear rv$dyn_props_keys; the sync observer
            # then sees no dyn props selected and leaves the empty list intact.
            session$setInputs(
                map_dynamicProperties = "",
                dynprops_key_protectarea = ""
            )
            raw_data_state(data.frame(other = "x", stringsAsFactors = FALSE))
            session$flushReact()

            testthat::expect_identical(rv$dyn_props_keys, list())
        }
    )
})

# Bug A do hotfix (clear de mapping persistia no export). Observer agora
# distingue `input = NULL` na carga inicial (rv$map_values era ""; no-op) de
# `input = NULL` apos clear pelo usuario (rv$map_values tinha valor; vira "").
testthat::test_that("clearing a previously-mapped field (selectInput devolve NULL) zera rv$map_values", {
    withr::local_envvar(c(SAIRA_USER = paste0("test_isolation_", as.integer(Sys.time()))))

    df <- data.frame(
        Tipo = c("Espécime preservado", "Observação"),
        Lat  = c("-15.5", "-16.2"),
        stringsAsFactors = FALSE
    )

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            # Setup: usuario seleciona "Tipo" para o termo `type`.
            session$setInputs(map_type = "Tipo")
            session$flushReact()
            testthat::expect_identical(as.character(rv$map_values$type), "Tipo")

            # Bug A repro: cliente limpa o select e devolve NULL ao servidor.
            session$setInputs(map_type = NULL)
            session$flushReact()

            # Esperado pos-fix: rv$map_values$type virou "", meta = MANUAL.
            testthat::expect_identical(as.character(rv$map_values$type), "")
            testthat::expect_identical(rv$map_meta$type$status, "MANUAL")
        }
    )
})

testthat::test_that("class pills are pure navigation anchors — all sections always rendered", {
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
            session$flushReact()

            # Pills render with stream-pill class and no active/filter state.
            pills_html <- paste(output$class_pills$html, collapse = " ")
            testthat::expect_true(grepl("stream-pill", pills_html, fixed = TRUE))

            all_cats <- all_filter_categories()
            testthat::expect_true("Taxon" %in% all_cats)

            # All category anchors always present before any click.
            mui_before <- paste(output$mapping_ui$html, collapse = " ")
            testthat::expect_true(grepl("cat_anchor_taxon", mui_before, fixed = TRUE))

            # Clicking a pill scrolls (sendCustomMessage) but never hides sections.
            session$setInputs(class_pill_taxon = 1)
            session$flushReact()
            mui_after <- paste(output$mapping_ui$html, collapse = " ")
            testthat::expect_true(grepl("cat_anchor_taxon", mui_after, fixed = TRUE))
        }
    )
})

testthat::test_that("required-fields strip reflects live mapped status", {
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
            session$flushReact()

            strip_before <- paste(output$required_fields_strip$html, collapse = " ")
            for (term in c(
                "scientificName", "eventDate", "decimalLatitude",
                "decimalLongitude", "basisOfRecord", "occurrenceID"
            )) {
                testthat::expect_true(grepl(term, strip_before, fixed = TRUE))
            }
            # occurrenceID is auto-UUID -> always mapped.
            testthat::expect_true(grepl(
                "mapping-required-chip is-mapped", strip_before,
                fixed = TRUE
            ))
            # scientificName not mapped yet -> a missing chip exists.
            testthat::expect_true(grepl(
                "mapping-required-chip is-missing", strip_before,
                fixed = TRUE
            ))

            session$setInputs(map_scientificName = "scientificName")
            session$flushReact()

            strip_after <- paste(output$required_fields_strip$html, collapse = " ")
            sci_idx <- regexpr("scientificName", strip_after, fixed = TRUE)
            chip_open <- regexpr(
                "mapping-required-chip is-mapped",
                substr(strip_after, 1, sci_idx[1]),
                fixed = TRUE
            )
            testthat::expect_true(chip_open[1] > 0)
        }
    )
})
