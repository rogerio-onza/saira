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
