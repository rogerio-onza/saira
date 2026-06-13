# Title: Tests for build_export_summary (pure export review summary)
# Author: Rogerio Nunes Oliveira

# Install a synthetic sensitive list into the cache for the calling test, then
# restore the real one (mirrors the helper in test-mod-sensitive-coords-server.R).
local_sensitive_fixture <- function(species, category = "EN", env = parent.frame()) {
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

sample_mapped <- function() {
    data.frame(
        scientificName = c("Panthera onca", "Felis catus"),
        eventDate = c("2024-01-01", "2024-02-02"),
        decimalLatitude = c("-27.17", "-23.5"),
        decimalLongitude = c("-53.9", "-46.6"),
        basisOfRecord = c("HumanObservation", "HumanObservation"),
        stringsAsFactors = FALSE
    )
}

testthat::test_that("build_export_summary aggregates corrections, generalization, readiness and files", {
    local_sensitive_fixture("Panthera onca", category = "EN")

    name_payload <- list(entries = data.frame(
        query_name = c("Puma concolr", "Panthera onca"),
        review_type = c("correct", "confirm"),
        original_name = c("Puma concolr", "Panthera onca"),
        corrected_name = c("Puma concolor", "Panthera onca"),
        reason = c("typo", ""),
        stringsAsFactors = FALSE
    ))
    coords_payload <- list(corrections = data.frame(
        occurrenceID = c("a", "b"),
        decimalLatitude = c(-8.7, -9.1),
        decimalLongitude = c(-35.5, -36.0),
        stringsAsFactors = FALSE
    ))
    country_payload <- list(country = data.frame(
        occurrenceID = "c", country = "Brazil", stringsAsFactors = FALSE
    ))
    gen_payload <- list(
        levels = stats::setNames(c("high", "not_sensitive"), c("Panthera onca", "Felis catus")),
        enabled = TRUE, review_date = as.Date("2030-01-01"),
        justification = "endemic", needs_justification = TRUE
    )

    s <- saira:::build_export_summary(
        mapped_data = sample_mapped(),
        name_review_payload = name_payload,
        coords_correction_payload = coords_payload,
        country_fill_payload = country_payload,
        sensitivity_payload = NULL,
        generalization_payload = gen_payload,
        dataset_name = "Meu Data Set"
    )

    testthat::expect_equal(s$record_count, 2L)
    testthat::expect_equal(s$corrections$names_corrected, 1L)
    testthat::expect_equal(s$corrections$names_confirmed, 1L)
    testthat::expect_equal(s$corrections$coord_fixes, 2L)
    testthat::expect_equal(s$corrections$country_fills, 1L)

    # Only the generalized species appears (not_sensitive is excluded), tagged
    # with its MMA threat category.
    testthat::expect_equal(nrow(s$generalization), 1L)
    testthat::expect_equal(s$generalization$scientificName, "Panthera onca")
    testthat::expect_equal(s$generalization$tier, "high")
    testthat::expect_equal(s$generalization$category, "EN")

    # All required terms present and non-empty -> 100% ready, not blocked
    # (justification supplied).
    testthat::expect_true(s$all_required_present)
    testthat::expect_equal(s$readiness_pct, 100L)
    testthat::expect_length(s$missing_required, 0L)
    testthat::expect_false(s$justification_pending)
    testthat::expect_false(s$export_blocked)
    testthat::expect_setequal(
        s$readiness$term,
        c("scientificName", "eventDate", "decimalLatitude", "decimalLongitude", "basisOfRecord")
    )

    # Files: DwC-A core trio keeps standard names; auxiliary files are renamed
    # after the dataset (hyphenated) and include the real-coords CSV.
    testthat::expect_equal(s$files$dwca, c("occurrence.txt", "meta.xml", "eml.xml"))
    testthat::expect_equal(unname(s$files$auxiliary[["xlsx"]]), "meu-data-set-occurrences.xlsx")
    testthat::expect_equal(unname(s$files$auxiliary[["mapping_guide"]]), "meu-data-set-mapping-guide.txt")
    testthat::expect_equal(unname(s$files$auxiliary[["sensitive_coords"]]), "meu-data-set-sensitive-coords.csv")
})

testthat::test_that("build_export_summary handles empty payloads and missing required terms", {
    df <- data.frame(
        scientificName = c("Aus bus", ""),
        decimalLatitude = c("-10", "-11"),
        stringsAsFactors = FALSE
    )
    s <- saira:::build_export_summary(mapped_data = df)

    testthat::expect_equal(s$corrections$names_corrected, 0L)
    testthat::expect_equal(s$corrections$coord_fixes, 0L)
    testthat::expect_equal(s$corrections$country_fills, 0L)
    testthat::expect_equal(nrow(s$generalization), 0L)

    # eventDate / decimalLongitude / basisOfRecord absent -> not all present,
    # export is blocked, 2 of 5 required terms present -> 40%.
    testthat::expect_false(s$all_required_present)
    testthat::expect_true(s$export_blocked)
    testthat::expect_equal(s$readiness_pct, 40L)
    testthat::expect_setequal(
        s$missing_required,
        c("eventDate", "decimalLongitude", "basisOfRecord")
    )
    present_terms <- s$readiness$term[s$readiness$present]
    testthat::expect_true("scientificName" %in% present_terms)
    testthat::expect_false("eventDate" %in% present_terms)

    # No masking -> no real-coords CSV; fallback slug used (no dataset name).
    testthat::expect_null(s$files$auxiliary[["sensitive_coords"]])
    testthat::expect_equal(unname(s$files$auxiliary[["xlsx"]]), "saira-occurrences.xlsx")
})

testthat::test_that("build_export_summary excludes generalization when disabled", {
    gen_payload <- list(
        levels = stats::setNames("high", "Panthera onca"),
        enabled = FALSE
    )
    s <- saira:::build_export_summary(
        mapped_data = sample_mapped(),
        generalization_payload = gen_payload
    )
    testthat::expect_equal(nrow(s$generalization), 0L)
    testthat::expect_null(s$files$auxiliary[["sensitive_coords"]])
})

testthat::test_that("build_export_summary blocks export when justification is pending", {
    gen_payload <- list(
        levels = stats::setNames("high", "Panthera onca"),
        enabled = TRUE, needs_justification = TRUE, justification = "   "
    )
    s <- saira:::build_export_summary(
        mapped_data = sample_mapped(),
        generalization_payload = gen_payload
    )
    testthat::expect_true(s$all_required_present)
    testthat::expect_true(s$justification_pending)
    testthat::expect_true(s$export_blocked)
})

testthat::test_that("slugify_dataset_name folds accents and collapses separators", {
    testthat::expect_equal(saira:::slugify_dataset_name("Meu Data Set"), "meu-data-set")
    testthat::expect_equal(saira:::slugify_dataset_name("Coleção de Aves — 2024"), "colecao-de-aves-2024")
    testthat::expect_equal(saira:::slugify_dataset_name("  --A__B--  "), "a-b")
    testthat::expect_equal(saira:::slugify_dataset_name(NULL), "")
    testthat::expect_equal(saira:::slugify_dataset_name(NA_character_), "")
})

testthat::test_that("export_bundle_filenames keeps the DwC-A trio and renames auxiliaries", {
    f <- saira:::export_bundle_filenames(dataset_name = "Meu Data Set", has_sensitive = TRUE)
    testthat::expect_equal(f$slug, "meu-data-set")
    testthat::expect_equal(f$zip, "meu-data-set-dwc-archive.zip")
    testthat::expect_equal(f$dwca, c("occurrence.txt", "meta.xml", "eml.xml"))
    testthat::expect_equal(unname(f$auxiliary[["sensitive_coords"]]), "meu-data-set-sensitive-coords.csv")

    # No dataset name + no masking -> fallback slug, no real-coords CSV.
    f2 <- saira:::export_bundle_filenames(dataset_name = NULL, has_sensitive = FALSE)
    testthat::expect_equal(f2$slug, "saira")
    testthat::expect_null(f2$auxiliary[["sensitive_coords"]])
})
