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
        license = c("CC-BY 4.0", "CC-BY 4.0"),
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
        c("scientificName", "eventDate", "decimalLatitude", "decimalLongitude", "basisOfRecord", "license")
    )

    # Files: DwC-A core trio keeps standard names; auxiliary files are renamed
    # after the dataset (hyphenated). The real coordinates are a private file
    # outside the bundle (ADR-163).
    testthat::expect_equal(s$files$dwca, c("occurrence.txt", "meta.xml", "eml.xml"))
    testthat::expect_equal(unname(s$files$auxiliary[["xlsx"]]), "meu-data-set-occurrences.xlsx")
    testthat::expect_equal(unname(s$files$auxiliary[["mapping_guide"]]), "meu-data-set-mapping-guide.txt")
    testthat::expect_length(s$files$auxiliary, 2L)
    testthat::expect_equal(s$files$private, "meu-data-set-sensitive-coords.xlsx")
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

    # eventDate / decimalLongitude / basisOfRecord / license absent -> not all
    # present, export is blocked, 2 of 6 required terms present -> 33%.
    testthat::expect_false(s$all_required_present)
    testthat::expect_true(s$export_blocked)
    testthat::expect_equal(s$readiness_pct, 33L)
    testthat::expect_setequal(
        s$missing_required,
        c("eventDate", "decimalLongitude", "basisOfRecord", "license")
    )
    present_terms <- s$readiness$term[s$readiness$present]
    testthat::expect_true("scientificName" %in% present_terms)
    testthat::expect_false("eventDate" %in% present_terms)

    # No masking -> no real-coords CSV; fallback slug used (no dataset name).
    testthat::expect_null(s$files$private)
    testthat::expect_equal(unname(s$files$auxiliary[["xlsx"]]), "saira-occurrences.xlsx")
})

testthat::test_that("build_export_summary blocks export until a license is chosen", {
    df <- sample_mapped()
    df$license <- NULL
    s <- saira:::build_export_summary(mapped_data = df)
    testthat::expect_identical(s$missing_required, "license")
    testthat::expect_true(s$export_blocked)
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
    testthat::expect_null(s$files$private)
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

testthat::test_that("build_export_summary blocks export when some basisOfRecord values are empty", {
    df <- sample_mapped()
    s_ok <- saira:::build_export_summary(mapped_data = df)
    testthat::expect_identical(s_ok$bor_blank_count, 0L)

    df$basisOfRecord[1] <- ""
    s <- saira:::build_export_summary(mapped_data = df)
    testthat::expect_true(s$all_required_present)
    testthat::expect_identical(s$bor_blank_count, 1L)
    testthat::expect_identical(s$bor_blank_rows, 1L)
    testthat::expect_true(s$export_blocked)
    testthat::expect_identical(saira:::format_row_list(1:12), "1, 2, 3, 4, 5, 6, 7, 8, 9, 10 (+2)")
})

testthat::test_that("build_export_summary blocks export when a record has no scientificName (AUD-12)", {
    df <- sample_mapped()
    testthat::expect_identical(saira:::build_export_summary(df)$sci_blank_rows, integer(0))

    df$scientificName[2] <- "  "
    s <- saira:::build_export_summary(mapped_data = df)
    testthat::expect_true(s$all_required_present)
    testthat::expect_identical(s$sci_blank_rows, 2L)
    testthat::expect_true(s$export_blocked)
})

testthat::test_that("build_export_summary blocks a formula in an unmapped column (AUD-04)", {
    df <- sample_mapped()
    raw <- data.frame(
        especie = df$scientificName,
        anotacao = c("ok", "=1+1"),
        vazia = c("", ""),
        stringsAsFactors = FALSE
    )
    map_values <- list(scientificName = "especie")

    s <- saira:::build_export_summary(mapped_data = df, raw_data = raw, map_values = map_values)
    testthat::expect_identical(s$formula_cells$count, 0L)
    testthat::expect_identical(s$formula_cells_unmapped$count, 1L)
    testthat::expect_identical(s$formula_cells_unmapped$sample$column, "anotacao")
    testthat::expect_identical(s$formula_cells_unmapped$sample$row, 2L)
    testthat::expect_true(s$export_blocked)

    # A mapped column is the Preview's to check, not this one.
    s2 <- saira:::build_export_summary(
        mapped_data = df, raw_data = raw,
        map_values = list(scientificName = "especie", occurrenceRemarks = "anotacao")
    )
    testthat::expect_identical(s2$formula_cells_unmapped$count, 0L)
    testthat::expect_false(s2$export_blocked)
})

testthat::test_that("export_bundle_filenames drops the Excel mirror above the sheet row limit (AUD-16)", {
    at_limit <- saira:::export_bundle_filenames(n_records = 1048575L)
    testthat::expect_identical(at_limit$auxiliary$xlsx, "saira-occurrences.xlsx")

    above <- saira:::export_bundle_filenames(n_records = 1048576L)
    testthat::expect_null(above$auxiliary$xlsx)
    testthat::expect_identical(names(above$auxiliary), "mapping_guide")
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
    testthat::expect_equal(f$private, "meu-data-set-sensitive-coords.xlsx")

    # No dataset name + no masking -> fallback slug, no private file.
    f2 <- saira:::export_bundle_filenames(dataset_name = NULL, has_sensitive = FALSE)
    testthat::expect_equal(f2$slug, "saira")
    testthat::expect_null(f2$private)
})

testthat::test_that("build_export_summary reports out-of-range years without blocking the export", {
    df <- sample_mapped()
    df$eventDate <- c("2098-05-01", "2024-02-02")

    summary <- saira:::build_export_summary(df)

    testthat::expect_identical(summary$date_issues$count, 1L)
    testthat::expect_identical(summary$date_issues$future_count, 1L)
    testthat::expect_identical(summary$date_issues$sample$column, "eventDate")
    testthat::expect_false(summary$export_blocked)

    clean <- saira:::build_export_summary(sample_mapped())
    testthat::expect_identical(clean$date_issues$count, 0L)
})

testthat::test_that("build_export_summary counts the dates the conversion left raw", {
    df <- sample_mapped()
    df$eventDate <- c("2020-13-45", "2024-02-02")

    summary <- saira:::build_export_summary(df)

    testthat::expect_identical(summary$date_unparsed$count, 1L)
    testthat::expect_identical(summary$date_unparsed$sample$value, "2020-13-45")
    testthat::expect_false(summary$export_blocked)
    testthat::expect_identical(saira:::build_export_summary(sample_mapped())$date_unparsed$count, 0L)
})

testthat::test_that("build_export_summary lists counts of 0 with no occurrenceStatus (D07)", {
    df <- sample_mapped()
    df$individualCount <- c("0", "0")
    df$occurrenceStatus <- c("", "absent")
    s <- saira:::build_export_summary(df)
    testthat::expect_equal(s$zero_count_rows, 1L)
    testthat::expect_false(s$export_blocked)
    df$occurrenceStatus <- NULL
    testthat::expect_equal(saira:::build_export_summary(df)$zero_count_rows, c(1L, 2L))
})

testthat::test_that("build_export_summary blocks an invalid coordinate and a formula (B50, B55)", {
    df <- sample_mapped()
    df$occurrenceID <- c("a", "b")
    df$decimalLatitude <- c("95", "-23.5")
    s <- saira:::build_export_summary(df)
    testthat::expect_equal(s$coord_invalid_rows, 1L)
    testthat::expect_true(s$export_blocked)

    # A correction accepted in the Coordinates tab clears the block.
    fix <- list(corrections = data.frame(occurrenceID = "a", decimalLatitude = "-25",
                                         decimalLongitude = "-53.9", stringsAsFactors = FALSE))
    s <- saira:::build_export_summary(df, coords_correction_payload = fix)
    testthat::expect_length(s$coord_invalid_rows, 0L)
    testthat::expect_false(s$export_blocked)

    df <- sample_mapped()
    df$scientificName[2] <- "=1+1"
    testthat::expect_true(saira:::build_export_summary(df)$export_blocked)
})

testthat::test_that("build_export_summary lists Coordinates flags with no correction (B50)", {
    df <- sample_mapped()
    df$occurrenceID <- c("a", "b")
    cv <- data.frame(.row_index = 1:2, diagnostic_family = c("sea", "ok"))
    s <- saira:::build_export_summary(df, coord_validation = cv, preview_problems_n = 3L)
    testthat::expect_equal(s$coord_flags$rows, 1L)
    testthat::expect_equal(s$preview_problems_n, 3L)
    testthat::expect_false(s$export_blocked)

    fix <- list(corrections = data.frame(occurrenceID = "a", decimalLatitude = "-27.17",
                                         decimalLongitude = "-53.9", stringsAsFactors = FALSE))
    s <- saira:::build_export_summary(df, coords_correction_payload = fix, coord_validation = cv)
    testthat::expect_equal(s$coord_flags$count, 0L)
    testthat::expect_null(saira:::build_export_summary(df)$coord_flags)
})

testthat::test_that("build_export_summary does not count the copies left out", {
    s <- saira:::build_export_summary(mapped_data = sample_mapped(), rows_left_out = c(2L, 9L))
    testthat::expect_equal(s$record_count, 1L)
    testthat::expect_identical(s$rows_left_out, 2L)
})
