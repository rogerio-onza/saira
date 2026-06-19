# Title: Tests for the Sensitive Coordinates (Generalization) module server
# Author: Rogerio Nunes Oliveira

# Install a synthetic sensitive list into the cache for the calling test, then
# restore the real one. Mirrors the helper in test-utils-sensitive.R.
local_sensitive_fixture <- function(species, category = "CR",
                                    env = parent.frame()) {
    fixture <- data.frame(
        scientificName = species,
        match_key = saira:::build_sensitive_match_keys(species),
        category = rep_len(category, length(species)),
        stringsAsFactors = FALSE
    )
    saira:::sensitive_species_cache$set(fixture, path = "test-fixture")
    withr::defer(saira:::sensitive_species_cache$reset(), envir = env)
    fixture
}

sample_occurrence_df <- function() {
    data.frame(
        scientificName = c("Panthera onca", "Panthera onca", "Felis catus"),
        decimalLatitude = c("-27.1700", "-27.2000", "-23.5"),
        decimalLongitude = c("-53.9000", "-53.8000", "-46.6"),
        stringsAsFactors = FALSE
    )
}

testthat::test_that("upstream reset signal clears the generalization determination", {
    local_sensitive_fixture("Panthera onca", category = "EN")
    df <- sample_occurrence_df()
    signal <- shiny::reactiveVal(0L)

    shiny::testServer(
        saira:::mod_sensitive_coords_server,
        args = list(
            data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en"),
            reset_signal_r = signal
        ),
        {
            # Seed a determination + per-species exception for a prior dataset
            # (overrides hold a tier string, as the exc_apply handlers write).
            group_levels_rv(list(cr = "high"))
            species_overrides_rv(list("Panthera onca" = "extreme"))
            preview_tier_rv("high")
            result_filter_rv("cr")
            session$flushReact()

            signal(1L)
            session$flushReact()

            testthat::expect_length(group_levels_rv(), 0L)
            testthat::expect_length(species_overrides_rv(), 0L)
            testthat::expect_null(preview_tier_rv())
            testthat::expect_identical(result_filter_rv(), "all")
        }
    )
})

testthat::test_that("payload starts disabled (publish) with no levels", {
    local_sensitive_fixture("Panthera onca", category = "EN")
    df <- sample_occurrence_df()
    shiny::testServer(
        saira:::mod_sensitive_coords_server,
        args = list(
            data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            ov <- sensitive_species_overview()
            testthat::expect_false(is.null(ov))
            testthat::expect_true("Panthera onca" %in% ov$scientificName)
            # The non-sensitive species is not picked up.
            testthat::expect_false("Felis catus" %in% ov$scientificName)

            returned <- session$getReturned()
            p <- returned()
            testthat::expect_false(isTRUE(p$enabled))
            testthat::expect_length(p$levels, 0L)
        }
    )
})

testthat::test_that("group cascade resolves to a tier carried per species in the payload", {
    local_sensitive_fixture("Panthera onca", category = "EN")
    df <- sample_occurrence_df()
    shiny::testServer(
        saira:::mod_sensitive_coords_server,
        args = list(
            data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            returned <- session$getReturned()
            session$setInputs(sensitive_mode = "generalize")
            # EN -> group code "en"; the cascade is capped at Cat 2: 4.3 yes -> high.
            session$setInputs(q43_en = "yes")
            session$flushReact()

            testthat::expect_identical(group_levels_rv()[["en"]], "high")
            testthat::expect_identical(unname(species_levels_r()[["Panthera onca"]]), "high")

            p <- returned()
            testthat::expect_true(isTRUE(p$enabled))
            testthat::expect_identical(unname(p$levels[["Panthera onca"]]), "high")
            # Cat 1/2/3 -> justification becomes mandatory (none typed yet).
            testthat::expect_true(isTRUE(p$needs_justification))

            # One preview row per masked record (two onca records); border-cross
            # and uncertainty-radius columns are present even when the spatial
            # backend is unavailable.
            prev <- actual_preview_r()
            testthat::expect_true(is.data.frame(prev))
            testthat::expect_gte(nrow(prev), 1L)
            testthat::expect_true(all(c("gen_lat", "gen_lon", "unc_m", "crosses") %in% names(prev)))
            testthat::expect_true(all(prev$unc_m > 0))
        }
    )
})

testthat::test_that("precision-lock banner appears when the chosen tier is finer than the data", {
    local_sensitive_fixture("Panthera onca", category = "EN")
    # Integer coords -> existing precision 1 deg; the cascade resolves to `high`
    # (0.1 deg, q43 yes -> Cat 2), finer than the data, so every row is clamped
    # to 1 deg (still generalized, just not at false precision).
    df <- data.frame(
        scientificName = c("Panthera onca", "Panthera onca"),
        decimalLatitude = c("-27", "-28"),
        decimalLongitude = c("-53", "-54"),
        stringsAsFactors = FALSE
    )
    shiny::testServer(
        saira:::mod_sensitive_coords_server,
        args = list(
            data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(sensitive_mode = "generalize")
            session$setInputs(q43_en = "yes")
            session$flushReact()

            prev <- actual_preview_r()
            # Clamped, not dropped: the rows are still shown, generalized at 1 deg.
            testthat::expect_equal(nrow(prev), 2L)
            testthat::expect_equal(attr(prev, "n_clamped_to_precision"), 2L)
            # The banner renders the count; publish mode would suppress it.
            banner <- output$precision_lock_alert
            banner_html <- if (is.list(banner)) banner$html else as.character(banner)
            testthat::expect_true(nzchar(banner_html))
            testthat::expect_match(banner_html, "real precision", fixed = TRUE)
        }
    )
})

testthat::test_that("a per-species exception overrides the group then clears back", {
    local_sensitive_fixture("Panthera onca", category = "EN")
    df <- sample_occurrence_df()
    shiny::testServer(
        saira:::mod_sensitive_coords_server,
        args = list(
            data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(sensitive_mode = "generalize")
            session$setInputs(q43_en = "yes")  # group -> Cat 2 (high)
            session$flushReact()
            testthat::expect_identical(unname(species_levels_r()[["Panthera onca"]]), "high")

            # Cascade exception: Cat 3 (medium) overrides the group.
            session$setInputs(exc_species = "Panthera onca",
                              q43_exc = "no", q44_exc = "yes", exc_apply = 1)
            session$flushReact()
            testthat::expect_identical(species_overrides_rv()[["Panthera onca"]], "medium")
            testthat::expect_identical(unname(species_levels_r()[["Panthera onca"]]), "medium")

            # Explicit Category-1 escape hatch -> extreme (the only path to extreme;
            # the capped cascade never yields it).
            session$setInputs(exc_apply_cat1 = 1)
            session$flushReact()
            testthat::expect_identical(species_overrides_rv()[["Panthera onca"]], "extreme")
            testthat::expect_identical(unname(species_levels_r()[["Panthera onca"]]), "extreme")

            # Clearing the override falls back to the group tier.
            session$setInputs(exc_clear = 1)
            session$flushReact()
            testthat::expect_length(species_overrides_rv(), 0L)
            testthat::expect_identical(unname(species_levels_r()[["Panthera onca"]]), "high")
        }
    )
})

testthat::test_that("threat-level filter narrows the result list to one group", {
    local_sensitive_fixture(
        c("Panthera onca", "Leopardus wiedii"),
        category = c("EN", "VU")
    )
    df <- data.frame(
        scientificName = c("Panthera onca", "Leopardus wiedii"),
        decimalLatitude = c("-27.17", "-10.00"),
        decimalLongitude = c("-53.90", "-50.00"),
        stringsAsFactors = FALSE
    )
    shiny::testServer(
        saira:::mod_sensitive_coords_server,
        args = list(
            data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(sensitive_mode = "generalize")
            session$flushReact()

            # Default: filter is "all" and both groups' species are listed.
            testthat::expect_identical(result_filter_rv(), "all")
            html_all <- paste(output$result_card$html, collapse = " ")
            testthat::expect_true(grepl("Panthera onca", html_all))
            testthat::expect_true(grepl("Leopardus wiedii", html_all))

            # Filter to VU: only the VU species remains in the result list.
            session$setInputs(rfilter_vu = 1)
            session$flushReact()
            testthat::expect_identical(result_filter_rv(), "vu")
            html_vu <- paste(output$result_card$html, collapse = " ")
            testthat::expect_true(grepl("Leopardus wiedii", html_vu))
            testthat::expect_false(grepl("Panthera onca", html_vu))

            # Back to all restores both.
            session$setInputs(rfilter_all = 1)
            session$flushReact()
            testthat::expect_identical(result_filter_rv(), "all")
            html_back <- paste(output$result_card$html, collapse = " ")
            testthat::expect_true(grepl("Panthera onca", html_back))
            testthat::expect_true(grepl("Leopardus wiedii", html_back))
        }
    )
})

testthat::test_that("no sensitive species yields an empty overview and no levels", {
    # Synthetic list contains a different species, so the data below is unlisted.
    local_sensitive_fixture("Xxxia exampla")
    df <- data.frame(
        scientificName = c("Felis catus", "Canis familiaris"),
        decimalLatitude = c("-23.5", "-22.9"),
        decimalLongitude = c("-46.6", "-43.2"),
        stringsAsFactors = FALSE
    )
    shiny::testServer(
        saira:::mod_sensitive_coords_server,
        args = list(
            data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en")
        ),
        {
            returned <- session$getReturned()
            session$setInputs(sensitive_mode = "generalize")
            session$flushReact()
            testthat::expect_null(sensitive_species_overview())
            testthat::expect_length(returned()$levels, 0L)
        }
    )
})

# Regression: a transposed-coordinate correction applied on the Coords tab must
# flow into the generalization's effective data (the origin-marker source) the
# moment the payload changes -- the data layer that the gen map paints from. The
# stale-marker bug was a Leaflet render artefact, not this data path; this guards
# the path itself. Uses the website example's transposed row (MN-0042821).
testthat::test_that("coords correction payload moves the origin coordinate reactively", {
    df <- data.frame(
        occurrenceID = "MN-0042821",
        scientificName = "Tangara fastuosa",
        decimalLatitude = "-35.5500",
        decimalLongitude = "-8.7300",
        country = "Brasil",
        stringsAsFactors = FALSE
    )
    payload_rv <- shiny::reactiveVal(NULL)
    shiny::testServer(
        saira:::mod_sensitive_coords_server,
        args = list(
            data_r = shiny::reactive(df),
            lang_r = shiny::reactive("en"),
            coords_correction_payload_r = payload_rv
        ),
        {
            session$flushReact()
            # Before correction: origin sits at the swapped (sea) coordinate.
            before <- effective_data_r()
            testthat::expect_equal(before$decimalLatitude[1], "-35.5500")
            testthat::expect_equal(before$decimalLongitude[1], "-8.7300")

            # Apply the transposed correction exactly as the Coords tab does.
            payload_rv(list(corrections = data.frame(
                occurrenceID = "MN-0042821",
                decimalLatitude = -8.73,
                decimalLongitude = -35.55,
                stringsAsFactors = FALSE
            )))
            session$flushReact()

            after <- effective_data_r()
            testthat::expect_equal(after$decimalLatitude[1], "-8.73")
            testthat::expect_equal(after$decimalLongitude[1], "-35.55")
        }
    )
})
