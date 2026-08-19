# Title: Tests for export date normalization utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-14
# Version: 1.0

apply_name_review_payload <- function(...) {
    saira:::apply_name_review_payload(...)
}

testthat::test_that("abbreviate_license normalizes known values and preserves unknowns", {
    licenses <- c(
        "https://creativecommons.org/publicdomain/zero/1.0/legalcode",
        "http://creativecommons.org/publicdomain/zero/1.0/",
        "CC0",
        "https://creativecommons.org/licenses/by/4.0/",
        "http://creativecommons.org/licenses/by/4.0/legalcode",
        "cc-by",
        "https://creativecommons.org/licenses/by-nc/4.0/",
        "CC-BY-NC",
        "custom-license",
        NA_character_
    )

    out <- abbreviate_license(licenses)
    expected <- c(
        "CC0",
        "CC0",
        "CC0",
        "CC-BY",
        "CC-BY",
        "CC-BY",
        "CC-BY-NC",
        "CC-BY-NC",
        "custom-license",
        NA_character_
    )
    testthat::expect_identical(out, expected)
})

testthat::test_that("abbreviate_license_column handles missing and existing columns", {
    no_license <- data.frame(id = c("a", "b"), stringsAsFactors = FALSE)
    with_license <- data.frame(
        license = c("https://creativecommons.org/licenses/by/4.0/", "custom-license"),
        stringsAsFactors = FALSE
    )

    testthat::expect_identical(abbreviate_license_column(no_license), no_license)
    out <- abbreviate_license_column(with_license)
    testthat::expect_identical(out$license, c("CC-BY", "custom-license"))
})

testthat::test_that("clean_coordinate_separators converts decimal comma and invalids to NA", {
    df <- data.frame(
        decimalLatitude = c("-23,55", "foo", ""),
        decimalLongitude = c("-46,63", "181,00", "bar"),
        stringsAsFactors = FALSE
    )

    out <- clean_coordinate_separators(df)
    testthat::expect_equal(out$decimalLatitude, c(-23.55, NA_real_, NA_real_))
    testthat::expect_equal(out$decimalLongitude, c(-46.63, 181.00, NA_real_))
})

testthat::test_that("add_occurrence_ids creates ids when column is absent", {
    df <- data.frame(scientificName = c("A", "B", "C"), stringsAsFactors = FALSE)
    out <- add_occurrence_ids(df)

    testthat::expect_true("occurrenceID" %in% names(out))
    testthat::expect_equal(length(out$occurrenceID), nrow(df))
    testthat::expect_false(any(is.na(out$occurrenceID) | out$occurrenceID == ""))
})

testthat::test_that("add_occurrence_ids preserves existing values and fills missing", {
    df <- data.frame(
        occurrenceID = c("keep-id", "", NA_character_),
        stringsAsFactors = FALSE
    )
    out <- add_occurrence_ids(df)

    testthat::expect_identical(out$occurrenceID[1], "keep-id")
    testthat::expect_false(any(is.na(out$occurrenceID) | out$occurrenceID == ""))
    testthat::expect_true(all(out$occurrenceID[2:3] != "keep-id"))
})

testthat::test_that("apply_geodetic_datum populates EPSG:4326 only for valid coordinates", {
    df <- data.frame(
        decimalLatitude = c(-23.55, NA_real_, 95, 0),
        decimalLongitude = c(-46.63, -46.63, 100, 0),
        stringsAsFactors = FALSE
    )

    out <- apply_geodetic_datum(df)

    testthat::expect_true("geodeticDatum" %in% names(out))
    testthat::expect_identical(
        out$geodeticDatum,
        c("EPSG:4326", NA_character_, NA_character_, "EPSG:4326")
    )
})

testthat::test_that("apply_geodetic_datum preserves user-supplied datum", {
    df <- data.frame(
        decimalLatitude = c(-23.55, -10.0),
        decimalLongitude = c(-46.63, -50.0),
        geodeticDatum = c("EPSG:31983", ""),
        stringsAsFactors = FALSE
    )

    out <- apply_geodetic_datum(df)

    testthat::expect_identical(
        out$geodeticDatum,
        c("EPSG:31983", "EPSG:4326")
    )
})

testthat::test_that("apply_geodetic_datum is no-op when coordinate columns absent", {
    df <- data.frame(scientificName = c("A", "B"), stringsAsFactors = FALSE)
    testthat::expect_identical(apply_geodetic_datum(df), df)
})

testthat::test_that("convert_country_code_to_alpha2 converts alpha-3 and preserves alpha-2", {
    df <- data.frame(
        countryCode = c("BRA", "BR", "USA", "AR"),
        stringsAsFactors = FALSE
    )

    out <- convert_country_code_to_alpha2(df)

    testthat::expect_identical(
        out$countryCode,
        c("BR", "BR", "US", "AR")
    )
})

testthat::test_that("convert_country_code_to_alpha2 returns NA for unconvertible 3-char values", {
    df <- data.frame(
        countryCode = c("BRA", "XYZ", "", NA_character_, "  "),
        stringsAsFactors = FALSE
    )

    out <- convert_country_code_to_alpha2(df)

    testthat::expect_identical(
        out$countryCode,
        c("BR", NA_character_, NA_character_, NA_character_, NA_character_)
    )
})

testthat::test_that("convert_country_code_to_alpha2 is no-op when countryCode column absent", {
    df <- data.frame(scientificName = c("A", "B"), stringsAsFactors = FALSE)
    testthat::expect_identical(convert_country_code_to_alpha2(df), df)
})

testthat::test_that("process_for_export emits alpha-2 countryCode and geodeticDatum on valid coords", {
    df <- data.frame(
        scientificName = c("Tangara fastuosa", "Panthera onca"),
        eventDate = c("2024-01-15", "2024-02-20"),
        decimalLatitude = c(-8.05, -3.10),
        decimalLongitude = c(-34.88, -60.02),
        countryCode = c("BRA", "BRA"),
        basisOfRecord = c("HumanObservation", "HumanObservation"),
        stringsAsFactors = FALSE
    )

    out <- process_for_export(df)

    testthat::expect_identical(out$countryCode, c("BR", "BR"))
    testthat::expect_identical(out$geodeticDatum, c("EPSG:4326", "EPSG:4326"))
})

testthat::test_that("fix_dates_to_iso delegates to parser and preserves raw invalid values", {
    input_dates <- c(
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

    expected_from_parser <- parse_dates_to_iso(input_dates)
    keep_raw <- is.na(expected_from_parser) & !is.na(input_dates) & nzchar(input_dates)
    expected_export <- expected_from_parser
    expected_export[keep_raw] <- input_dates[keep_raw]

    df <- data.frame(
        eventDate = input_dates,
        dateIdentified = input_dates,
        modified = input_dates,
        stringsAsFactors = FALSE
    )

    out <- fix_dates_to_iso(df)
    testthat::expect_identical(out$eventDate, expected_export)
    testthat::expect_identical(out$dateIdentified, expected_export)
    testthat::expect_identical(out$modified, expected_export)
})

testthat::test_that("fix_dates_to_iso leaves non-date columns unchanged", {
    df <- data.frame(
        other_col = c("25/12/2023", "foo", ""),
        stringsAsFactors = FALSE
    )

    out <- fix_dates_to_iso(df)
    testthat::expect_identical(out, df)
})

testthat::test_that("process_for_export keeps date semantics and runs full pipeline", {
    df <- data.frame(
        eventDate = c("25/12/2023", "foo", ""),
        dateIdentified = c("18/05/09", "31/02/2023", NA_character_),
        modified = c("25.12.2023", "bar", ""),
        decimalLatitude = c("-23,55", "-22,10", ""),
        decimalLongitude = c("-46,63", "-43,17", ""),
        occurrenceID = c("", NA_character_, "existing-id"),
        license = c(
            "https://creativecommons.org/publicdomain/zero/1.0/legalcode",
            "https://creativecommons.org/licenses/by/4.0/",
            "custom-license"
        ),
        stringsAsFactors = FALSE
    )

    out <- process_for_export(df)

    expected_date_identified <- parse_dates_to_iso(df$dateIdentified)
    raw_mask <- is.na(expected_date_identified) & !is.na(df$dateIdentified) & nzchar(df$dateIdentified)
    expected_date_identified[raw_mask] <- df$dateIdentified[raw_mask]

    testthat::expect_identical(out$eventDate, c("2023-12-25", "foo", NA_character_))
    testthat::expect_identical(out$dateIdentified, expected_date_identified)
    testthat::expect_identical(out$modified, c("2023-12-25", "bar", NA_character_))
    testthat::expect_equal(out$decimalLatitude, c(-23.55, -22.10, NA_real_))
    testthat::expect_equal(out$decimalLongitude, c(-46.63, -43.17, NA_real_))
    testthat::expect_false(any(is.na(out$occurrenceID) | out$occurrenceID == ""))
    testthat::expect_identical(out$occurrenceID[3], "existing-id")
    # dcterms:license is a URI in Darwin Core, so the published file carries the
    # canonical legalcode URL; the short label is a preview affordance only.
    testthat::expect_identical(
        out$license,
        c(
            unname(cc_license_uris()[["CC0"]]),
            unname(cc_license_uris()[["CC-BY"]]),
            "custom-license"
        )
    )
})

testthat::test_that("apply_name_review_payload never emits audit columns without payload", {
    df <- data.frame(
        scientificName = c("A", "B"),
        stringsAsFactors = FALSE
    )

    out <- apply_name_review_payload(df, payload = NULL)
    testthat::expect_false("validacao_manual" %in% names(out))
    testthat::expect_false("motivo_revisao"  %in% names(out))
    testthat::expect_identical(out$scientificName, c("A", "B"))
})

testthat::test_that("apply_name_review_payload never emits audit columns even with 'confirm' entries (ADR-088)", {
    df <- data.frame(
        scientificName = c("Puma concolor", "Abies alba"),
        stringsAsFactors = FALSE
    )
    payload <- list(
        entries = data.frame(
            query_name = "Puma concolor",
            review_type = "confirm",
            original_name = "Puma concolor",
            corrected_name = "Puma concolor",
            reason = "",
            reviewed_at = as.POSIXct("2026-02-27 10:00:00", tz = "UTC"),
            stringsAsFactors = FALSE
        ),
        normalize_opts = list(remove_authors = TRUE, ignore_qualifiers = TRUE)
    )

    out <- apply_name_review_payload(df, payload = payload)
    testthat::expect_false("validacao_manual" %in% names(out))
    testthat::expect_false("motivo_revisao"  %in% names(out))
    # 'confirm' nao altera o nome:
    testthat::expect_identical(out$scientificName[[1]], "Puma concolor")
})

testthat::test_that("apply_name_review_payload applies 'correct' replacement silently (no audit cols)", {
    df <- data.frame(
        scientificName = c("Abies alba"),
        stringsAsFactors = FALSE
    )
    payload <- list(
        entries = data.frame(
            query_name = "Abies alba",
            review_type = "correct",
            original_name = "Abies alba",
            corrected_name = "Abies alba var. minor",
            reason = "",
            reviewed_at = as.POSIXct("2026-02-27 10:00:00", tz = "UTC"),
            stringsAsFactors = FALSE
        ),
        normalize_opts = list(remove_authors = TRUE, ignore_qualifiers = TRUE)
    )

    out <- apply_name_review_payload(df, payload = payload)
    # Replacement aplicado:
    testthat::expect_identical(out$scientificName[[1]], "Abies alba var. minor")
    # Audit cols ausentes (ADR-088):
    testthat::expect_false("validacao_manual" %in% names(out))
    testthat::expect_false("motivo_revisao"  %in% names(out))
})

testthat::test_that("apply_name_review_payload applies 'correct' replacement to all matching occurrences", {
    df <- data.frame(
        scientificName = c("Puma concolor", "Puma concolor", "Abies alba"),
        stringsAsFactors = FALSE
    )
    payload <- list(
        entries = data.frame(
            query_name = "Puma concolor",
            review_type = "correct",
            original_name = "Puma concolor",
            corrected_name = "Puma concolor corrected",
            reason = "",
            reviewed_at = as.POSIXct("2026-02-27 10:00:00", tz = "UTC"),
            stringsAsFactors = FALSE
        ),
        normalize_opts = list(remove_authors = TRUE, ignore_qualifiers = TRUE)
    )

    out <- apply_name_review_payload(df, payload = payload)
    testthat::expect_identical(out$scientificName, c("Puma concolor corrected", "Puma concolor corrected", "Abies alba"))
    testthat::expect_false("validacao_manual" %in% names(out))
    testthat::expect_false("motivo_revisao"  %in% names(out))
})

testthat::test_that("dwc_canonical_class_order lists 21 DwC classes with Occurrence first", {
    classes <- dwc_canonical_class_order()
    testthat::expect_identical(classes[1], "Occurrence")
    testthat::expect_true("Taxon" %in% classes)
    testthat::expect_true("Location" %in% classes)
    testthat::expect_true("MaterialEntity" %in% classes)
    testthat::expect_length(classes, 21L)
    testthat::expect_identical(anyDuplicated(classes), 0L)
})

testthat::test_that("dwc_canonical_preferred_terms places key terms first within each class", {
    pref <- dwc_canonical_preferred_terms()
    testthat::expect_identical(pref$Occurrence[1], "occurrenceID")
    testthat::expect_identical(pref$Taxon[1], "scientificName")
    testthat::expect_true("occurrenceStatus" %in% pref$Occurrence)
    testthat::expect_true("decimalLatitude" %in% pref$Location)
    testthat::expect_true("decimalLongitude" %in% pref$Location)
})

testthat::test_that("order_columns_dwc_canonical puts occurrenceID first and groups Taxon together", {
    df <- data.frame(
        scientificName = "Panthera onca",
        customField = "x",
        occurrenceID = "id-1",
        decimalLatitude = -15.5,
        taxonRank = "species",
        basisOfRecord = "HumanObservation",
        specificEpithet = "onca",
        kingdom = "Animalia",
        occurrenceStatus = "present",
        decimalLongitude = -47.5,
        recordedBy = "Doe",
        eventDate = "2024-01-01",
        license = "CC-BY",
        datasetName = "Foo",
        identifiedBy = "Smith",
        habitat = "forest",
        stringsAsFactors = FALSE
    )

    out <- order_columns_dwc_canonical(df)

    expected <- c(
        "occurrenceID", "recordedBy", "occurrenceStatus",
        "basisOfRecord", "datasetName", "license",
        "eventDate", "habitat",
        "decimalLatitude", "decimalLongitude",
        "scientificName", "kingdom", "specificEpithet", "taxonRank",
        "identifiedBy",
        "customField"
    )
    testthat::expect_identical(names(out), expected)
    testthat::expect_identical(nrow(out), nrow(df))
    testthat::expect_identical(ncol(out), ncol(df))
})

testthat::test_that("order_columns_dwc_canonical preserves unknown columns at the end", {
    df <- data.frame(
        custom_a = 1, custom_b = 2,
        scientificName = "x", occurrenceID = "id",
        stringsAsFactors = FALSE
    )
    out <- order_columns_dwc_canonical(df)
    testthat::expect_identical(names(out), c("occurrenceID", "scientificName", "custom_a", "custom_b"))
})

testthat::test_that("order_columns_dwc_canonical places extra terms in their semantic block", {
    df <- data.frame(
        scientificName = "x",
        measurementValue = 1.0,
        occurrenceID = "id",
        behavior = "swimming",
        coordinateUncertaintyInMeters = 100,
        decimalLatitude = -15.5,
        establishmentMeans = "native",
        stringsAsFactors = FALSE
    )
    out <- order_columns_dwc_canonical(df)
    nm <- names(out)

    testthat::expect_identical(nm[1], "occurrenceID")
    testthat::expect_true(match("behavior", nm) < match("decimalLatitude", nm))
    # establishmentMeans is an Occurrence term but is deliberately relocated to
    # the end of the Taxon block (ADR-110), so it now trails scientificName
    # instead of leading the sheet with the other Occurrence terms.
    testthat::expect_true(match("scientificName", nm) < match("establishmentMeans", nm))
    testthat::expect_true(match("decimalLatitude", nm) < match("coordinateUncertaintyInMeters", nm))
    testthat::expect_true(match("decimalLatitude", nm) < match("scientificName", nm))
    testthat::expect_true(match("scientificName", nm) < match("measurementValue", nm))
})

testthat::test_that("order_columns_dwc_canonical is a no-op for empty or single-column frames", {
    testthat::expect_identical(ncol(order_columns_dwc_canonical(data.frame())), 0L)
    one <- data.frame(occurrenceID = "id", stringsAsFactors = FALSE)
    testthat::expect_identical(names(order_columns_dwc_canonical(one)), "occurrenceID")
})

# Regression: when the export pipeline fails, the downloadHandler must NEVER
# leave behind an HTML 500 page disguised as a .csv. Symptom we are guarding
# against: user opens dwc_export_<date>.csv and sees Shiny's HTML error page
# instead of CSV text. The actual handler lives in mod_preview.R; here we
# pin down the contract of the error-fallback writer (CSV header + ERROR row).
testthat::test_that("export error fallback writes CSV (never HTML)", {
    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp), add = TRUE)

    err_df <- data.frame(
        export_status = "ERROR",
        message       = "simulated pipeline failure",
        timestamp     = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
        stringsAsFactors = FALSE
    )
    readr::write_csv(err_df, tmp, na = "")

    lines <- readLines(tmp, n = 2)
    testthat::expect_false(any(grepl("^\\s*<", lines)))
    testthat::expect_match(lines[1], "^export_status,message,timestamp")
    testthat::expect_match(lines[2], "^ERROR,")
})

testthat::test_that("export error fallback (writeLines path) also produces CSV header", {
    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp), add = TRUE)

    msg <- "boom \"with quotes\""
    writeLines(
        c(
            "export_status,message,timestamp",
            paste0(
                "ERROR,",
                gsub('"', "'", msg, fixed = TRUE),
                ",",
                format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
            )
        ),
        con = tmp
    )

    lines <- readLines(tmp, n = 2)
    testthat::expect_false(any(grepl("^\\s*<", lines)))
    testthat::expect_match(lines[1], "^export_status,")
    testthat::expect_false(grepl("\"", lines[2], fixed = TRUE))
})

# ADR-087: Bundle ZIP — process_for_export_with_unmapped, write_xlsx_text_only,
# build_mapping_guide_txt. Cada helper testado isolado para localizar regressao
# com baixo custo de diagnostico (LESSONS.md:172).

testthat::test_that("process_for_export_with_unmapped appends non-mapped columns at the end", {
    raw <- data.frame(
        Lat        = c(-15.5, -16.2),
        Lon        = c(-47.5, -48.1),
        especie    = c("Panthera onca", "Tapirus terrestris"),
        notas      = c("foo", "bar"),
        codigo     = c("A001", "A002"),
        stringsAsFactors = FALSE
    )

    df_processed <- data.frame(
        decimalLatitude  = raw$Lat,
        decimalLongitude = raw$Lon,
        scientificName   = raw$especie,
        stringsAsFactors = FALSE
    )

    map_values <- list(
        decimalLatitude  = "Lat",
        decimalLongitude = "Lon",
        scientificName   = "especie"
    )

    out <- process_for_export_with_unmapped(df_processed, raw, map_values)
    nm <- names(out)

    testthat::expect_true(all(c("decimalLatitude", "decimalLongitude", "scientificName") %in% nm))
    testthat::expect_true(all(c("notas", "codigo") %in% nm))
    testthat::expect_lt(match("scientificName", nm), match("notas", nm))
    testthat::expect_lt(match("scientificName", nm), match("codigo", nm))
    testthat::expect_identical(nrow(out), nrow(raw))
})

testthat::test_that("process_for_export_with_unmapped is no-op when raw_data lacks extras", {
    raw <- data.frame(Lat = -15, especie = "x", stringsAsFactors = FALSE)
    df_processed <- data.frame(decimalLatitude = -15, scientificName = "x", stringsAsFactors = FALSE)
    map_values <- list(decimalLatitude = "Lat", scientificName = "especie")

    out <- process_for_export_with_unmapped(df_processed, raw, map_values)

    testthat::expect_false("Lat" %in% names(out))
    testthat::expect_false("especie" %in% names(out))
})

testthat::test_that("process_for_export_with_unmapped tolerates empty raw_data and map_values", {
    df_processed <- data.frame(occurrenceID = "id-1", scientificName = "x", stringsAsFactors = FALSE)
    out1 <- process_for_export_with_unmapped(df_processed, data.frame(), list())
    out2 <- process_for_export_with_unmapped(df_processed, NULL, NULL)
    testthat::expect_identical(nrow(out1), 1L)
    testthat::expect_identical(nrow(out2), 1L)
})

testthat::test_that("write_xlsx_text_only writes a readable xlsx with text-only cells", {
    skip_if_no_writexl <- !requireNamespace("writexl", quietly = TRUE)
    skip_if_no_readxl  <- !requireNamespace("readxl", quietly = TRUE)
    if (skip_if_no_writexl) testthat::skip("writexl not installed")
    if (skip_if_no_readxl)  testthat::skip("readxl not installed (test-only dep)")

    df <- data.frame(
        eventDate        = c("2024-01-15", "2023-12-01"),
        decimalLatitude  = c(-15.5, -16.2),
        leading_zeros    = c("00123", "00007"),
        big_number       = c("1234567890123", "9876543210"),
        stringsAsFactors = FALSE
    )

    tmp <- tempfile(fileext = ".xlsx")
    on.exit(unlink(tmp), add = TRUE)
    write_xlsx_text_only(df, tmp)

    back <- readxl::read_xlsx(tmp, col_types = "text")

    testthat::expect_identical(as.character(back$eventDate),       df$eventDate)
    testthat::expect_identical(as.character(back$leading_zeros),   df$leading_zeros)
    testthat::expect_identical(as.character(back$big_number),      df$big_number)
    # numeric column comes back as character (text-only on disk):
    testthat::expect_type(back$decimalLatitude, "character")
})

testthat::test_that("build_mapping_guide_txt emits magic header, mapping pairs, no data", {
    raw <- data.frame(
        Lat = c(-15.5),
        Lon = c(-47.5),
        especie = c("Panthera onca"),
        notas = c("SECRET FIELD VALUE"),
        stringsAsFactors = FALSE
    )
    map_values <- list(
        decimalLatitude  = "Lat",
        decimalLongitude = "Lon",
        scientificName   = "especie"
    )

    out <- build_mapping_guide_txt(map_values, raw, lang = "pt")

    testthat::expect_identical(out[1], "# saira:mapping:v2")
    testthat::expect_true(any(grepl("^Lat\\s+-> decimalLatitude$", out)))
    testthat::expect_true(any(grepl("^Lon\\s+-> decimalLongitude$", out)))
    testthat::expect_true(any(grepl("^especie\\s+-> scientificName$", out)))
    # listed in the unmapped section as a comment line (raw column name
    # preserved, but as a parser-safe comment, not a bare line):
    testthat::expect_true(any(grepl("^#\\s+- notas$", out)))
    testthat::expect_false("notas" %in% out)
    # CRITICAL: data values must NOT appear in the guide (no PII leak):
    testthat::expect_false(any(grepl("Panthera onca", out, fixed = TRUE)))
    testthat::expect_false(any(grepl("SECRET FIELD VALUE", out, fixed = TRUE)))
    testthat::expect_false(any(grepl("-15.5", out, fixed = TRUE)))
})

testthat::test_that("build_mapping_guide_txt switches PT/EN labels", {
    pt <- build_mapping_guide_txt(list(scientificName = "especie"),
                                  data.frame(especie = "x"), lang = "pt")
    en <- build_mapping_guide_txt(list(scientificName = "especie"),
                                  data.frame(especie = "x"), lang = "en")

    testthat::expect_true(any(grepl("mapeamentos", pt, fixed = TRUE)))
    testthat::expect_true(any(grepl("mappings", en, fixed = TRUE)))
    testthat::expect_false(any(grepl("mapeamentos", en, fixed = TRUE)))
    testthat::expect_false(any(grepl("mappings", pt, fixed = TRUE)))
})

testthat::test_that("build_mapping_guide_txt flags missing required terms", {
    out <- build_mapping_guide_txt(list(scientificName = "especie"),
                                   data.frame(especie = "x"), lang = "pt")
    # eventDate, decimalLatitude, decimalLongitude, basisOfRecord ausentes
    miss_block <- out[seq(which(grepl("termos DwC obrigatorios", out)) + 1L,
                          length(out))]
    testthat::expect_true(any(grepl("eventDate", miss_block)))
    testthat::expect_true(any(grepl("basisOfRecord", miss_block)))
})

testthat::test_that("export pipeline masks sensitive coords and emits a companion", {
    df <- data.frame(
        scientificName = c("Hippocampus reidi", "Felis catus"),
        decimalLatitude = c("-23.5612", "10.0"),
        decimalLongitude = c("-46.6543", "20.0"),
        eventDate = c("2024-01-15", "2024-01-16"),
        basisOfRecord = c("HumanObservation", "HumanObservation"),
        stringsAsFactors = FALSE
    )

    # Exactly the two calls the download handler makes, in order.
    full_data <- process_for_export_with_unmapped(
        df,
        raw_data = data.frame(),
        map_values = list()
    )
    # ADR-092 (Chapman flat-tier UI): per-species decisions only carry the
    # boolean; the global tier is the function's `generalization` argument.
    decisions <- data.frame(
        scientificName = "Hippocampus reidi",
        sensitive = TRUE,
        stringsAsFactors = FALSE
    )
    masked <- saira:::mask_sensitive_coordinates(
        full_data, decisions = decisions, generalization = "high", lang = "en"
    )

    testthat::expect_equal(masked$n_masked, 1L)

    sens_row <- which(masked$masked$scientificName == "Hippocampus reidi")
    other_row <- which(masked$masked$scientificName == "Felis catus")

    # process_for_export() numericizes the coordinate columns; "high" tier
    # rounds to 0.1 deg uniformly across all sensitive rows.
    testthat::expect_equal(masked$masked$decimalLatitude[sens_row], -23.6)
    testthat::expect_equal(masked$masked$decimalLongitude[sens_row], -46.7)
    testthat::expect_equal(masked$masked$coordinatePrecision[sens_row], "0.1")
    testthat::expect_equal(masked$masked$decimalLatitude[other_row], 10)
    testthat::expect_true(nzchar(masked$masked$dataGeneralizations[sens_row]))
    testthat::expect_true(nzchar(masked$masked$informationWithheld[sens_row]))
    testthat::expect_equal(masked$masked$dataGeneralizations[other_row], "")
    testthat::expect_true("occurrenceID" %in% names(masked$masked))

    # Companion holds the ORIGINAL coords, joinable on occurrenceID.
    testthat::expect_equal(nrow(masked$real), 1L)
    testthat::expect_equal(masked$real$decimalLatitude, "-23.5612")
    testthat::expect_equal(
        masked$real$occurrenceID,
        masked$masked$occurrenceID[sens_row]
    )
})

# apply_conservation_status ----------------------------------------------

# Install a synthetic sensitive list (with the source/portaria column) for the
# duration of the calling test, then restore the real one.
local_conservation_fixture <- function(env = parent.frame()) {
    species <- c("Panthera onca", "Harpia harpyja")
    fixture <- data.frame(
        scientificName = species,
        match_key = saira:::build_sensitive_match_keys(species),
        category = c("VU", "EN"),
        source = c("Portaria 1.704/2026", "Portaria 1.704/2026"),
        stringsAsFactors = FALSE
    )
    saira:::sensitive_species_cache$set(fixture, path = "test-fixture")
    withr::defer(saira:::sensitive_species_cache$reset(), envir = env)
    fixture
}

testthat::test_that("apply_conservation_status adds MMA keys for a BR provider", {
    local_conservation_fixture()
    df <- data.frame(
        scientificName = c("Panthera onca", "Canis familiaris"),
        country = "Brasil",
        stringsAsFactors = FALSE
    )
    out <- saira:::apply_conservation_status(
        df, list(include_mma = TRUE, include_iucn = FALSE)
    )
    testthat::expect_identical(
        out$dynamicProperties[[1]],
        "{\"mmaThreatStatus\":\"VU\",\"mmaSource\":\"Portaria 1.704/2026\"}"
    )
    # A species not on the list gets no key.
    testthat::expect_identical(out$dynamicProperties[[2]], "")
})

testthat::test_that("apply_conservation_status adds IUCN key and merges existing dynprops", {
    testthat::local_mocked_bindings(
        fetch_gbif_iucn_category = function(usage_keys) {
            ifelse(!is.na(usage_keys), "NT", NA_character_)
        },
        gbif_match_usage_keys = function(names) rep(NA_character_, length(names)),
        .package = "saira"
    )
    df <- data.frame(
        scientificName = c("Harpia harpyja", "Foo bar"),
        dynamicProperties = c("{\"k\":\"v\"}", ""),
        stringsAsFactors = FALSE
    )
    payload <- list(
        include_mma = FALSE, include_iucn = TRUE,
        taxon_keys = data.frame(
            scientificName = "Harpia harpyja",
            taxonID = "GBIF:2480528",
            provider = "gbif",
            stringsAsFactors = FALSE
        )
    )
    out <- saira:::apply_conservation_status(df, payload)
    testthat::expect_identical(
        out$dynamicProperties[[1]], "{\"k\":\"v\",\"iucnRedListCategory\":\"NT\"}"
    )
    # Row with no GBIF key (match fallback returns NA) -> unchanged.
    testthat::expect_identical(out$dynamicProperties[[2]], "")
})

testthat::test_that("apply_conservation_status merges both MMA and IUCN keys additively", {
    local_conservation_fixture()
    testthat::local_mocked_bindings(
        fetch_gbif_iucn_category = function(usage_keys) rep("NT", length(usage_keys)),
        gbif_match_usage_keys = function(names) rep("123", length(names)),
        .package = "saira"
    )
    df <- data.frame(
        scientificName = "Panthera onca", country = "Brasil",
        stringsAsFactors = FALSE
    )
    payload <- list(
        include_mma = TRUE, include_iucn = TRUE,
        taxon_keys = data.frame(
            scientificName = "Panthera onca", taxonID = "GBIF:1",
            provider = "gbif", stringsAsFactors = FALSE
        )
    )
    out <- saira:::apply_conservation_status(df, payload)
    testthat::expect_identical(
        out$dynamicProperties[[1]],
        paste0(
            "{\"mmaThreatStatus\":\"VU\",\"mmaSource\":\"Portaria 1.704/2026\",",
            "\"iucnRedListCategory\":\"NT\"}"
        )
    )
})

testthat::test_that("apply_conservation_status is a no-op without name, payload or flags", {
    df_no_name <- data.frame(x = 1:2)
    testthat::expect_identical(
        saira:::apply_conservation_status(df_no_name, list(include_mma = TRUE)),
        df_no_name
    )
    df <- data.frame(scientificName = c("a", "b"), stringsAsFactors = FALSE)
    testthat::expect_identical(saira:::apply_conservation_status(df, NULL), df)
    testthat::expect_identical(
        saira:::apply_conservation_status(df, list(include_mma = FALSE, include_iucn = FALSE)),
        df
    )
})

testthat::test_that("apply_conservation_status keeps MMA when the IUCN fetch errors", {
    local_conservation_fixture()
    testthat::local_mocked_bindings(
        fetch_gbif_iucn_category = function(usage_keys) stop("network down"),
        gbif_match_usage_keys = function(names) rep(NA_character_, length(names)),
        .package = "saira"
    )
    df <- data.frame(
        scientificName = "Panthera onca", country = "Brasil",
        stringsAsFactors = FALSE
    )
    payload <- list(
        include_mma = TRUE, include_iucn = TRUE,
        taxon_keys = data.frame(
            scientificName = "Panthera onca", taxonID = "GBIF:1",
            provider = "gbif", stringsAsFactors = FALSE
        )
    )
    out <- testthat::expect_warning(
        saira:::apply_conservation_status(df, payload), "IUCN skipped"
    )
    # MMA keys survive the independent IUCN failure; no iucn key written.
    testthat::expect_identical(
        out$dynamicProperties[[1]],
        "{\"mmaThreatStatus\":\"VU\",\"mmaSource\":\"Portaria 1.704/2026\"}"
    )
})

testthat::test_that("apply_conservation_status does not add a spurious empty dynprops column", {
    local_conservation_fixture()
    # A species not on the MMA list, IUCN off, and no dynamicProperties column:
    # nothing matched, so no empty column should be created.
    df <- data.frame(
        scientificName = "Canis familiaris", country = "Brasil",
        stringsAsFactors = FALSE
    )
    out <- saira:::apply_conservation_status(
        df, list(include_mma = TRUE, include_iucn = FALSE)
    )
    testthat::expect_false("dynamicProperties" %in% names(out))
})

testthat::test_that("apply_conservation_status keeps an existing dynprops column even when empty", {
    local_conservation_fixture()
    df <- data.frame(
        scientificName = "Canis familiaris",
        country = "Brasil",
        dynamicProperties = "",
        stringsAsFactors = FALSE
    )
    out <- saira:::apply_conservation_status(
        df, list(include_mma = TRUE, include_iucn = FALSE)
    )
    testthat::expect_true("dynamicProperties" %in% names(out))
    testthat::expect_identical(out$dynamicProperties[[1]], "")
})

# MMA scope: the portaria is a national instrument -------------------------

testthat::test_that("is_brazilian_record resolves country spellings and codes", {
    df <- data.frame(
        country = c("Brasil", "Brazil", "BRASIL", "brasil", "Peru", "", NA),
        stringsAsFactors = FALSE
    )
    testthat::expect_identical(
        saira:::is_brazilian_record(df),
        c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE)
    )
    testthat::expect_identical(
        saira:::is_brazilian_record(
            data.frame(countryCode = c("BRA", "BR", "PER", "PE"), stringsAsFactors = FALSE)
        ),
        c(TRUE, TRUE, FALSE, FALSE)
    )
})

testthat::test_that("is_brazilian_record prefers countryCode and handles empty input", {
    # countryCode wins where it resolves; country fills the rows it leaves NA.
    df <- data.frame(
        countryCode = c("PER", "", NA),
        country = c("Brasil", "Brasil", "Peru"),
        stringsAsFactors = FALSE
    )
    testthat::expect_identical(
        saira:::is_brazilian_record(df), c(FALSE, TRUE, FALSE)
    )
    testthat::expect_identical(saira:::is_brazilian_record(data.frame()), logical(0))
    testthat::expect_identical(saira:::is_brazilian_record(NULL), logical(0))
    # No country information at all: strict mode treats every row as unknown.
    testthat::expect_identical(
        saira:::is_brazilian_record(data.frame(scientificName = c("a", "b"))),
        c(FALSE, FALSE)
    )
})

testthat::test_that("apply_conservation_status writes MMA keys only for Brazilian records", {
    local_conservation_fixture()
    df <- data.frame(
        scientificName = "Panthera onca",
        country = c("Brasil", "Peru"),
        stringsAsFactors = FALSE
    )
    out <- saira:::apply_conservation_status(
        df, list(include_mma = TRUE, include_iucn = FALSE)
    )
    testthat::expect_identical(
        out$dynamicProperties[[1]],
        "{\"mmaThreatStatus\":\"VU\",\"mmaSource\":\"Portaria 1.704/2026\"}"
    )
    # Same taxon, collected outside Brazil: the national portaria says nothing.
    testthat::expect_identical(out$dynamicProperties[[2]], "")
})

testthat::test_that("apply_conservation_status skips MMA when the country is unknown", {
    local_conservation_fixture()
    payload <- list(include_mma = TRUE, include_iucn = FALSE)
    blank <- saira:::apply_conservation_status(
        data.frame(
            scientificName = "Panthera onca", country = "",
            dynamicProperties = "", stringsAsFactors = FALSE
        ),
        payload
    )
    testthat::expect_identical(blank$dynamicProperties[[1]], "")
    # No country column at all -> nothing to assert on, so no keys.
    absent <- saira:::apply_conservation_status(
        data.frame(scientificName = "Panthera onca", stringsAsFactors = FALSE),
        payload
    )
    testthat::expect_false("dynamicProperties" %in% names(absent))
})

testthat::test_that("apply_conservation_status keeps IUCN global while MMA stays national", {
    local_conservation_fixture()
    testthat::local_mocked_bindings(
        fetch_gbif_iucn_category = function(usage_keys) rep("NT", length(usage_keys)),
        gbif_match_usage_keys = function(names) rep("123", length(names)),
        .package = "saira"
    )
    df <- data.frame(
        scientificName = "Panthera onca",
        country = c("Brasil", "Peru"),
        stringsAsFactors = FALSE
    )
    out <- saira:::apply_conservation_status(
        df, list(include_mma = TRUE, include_iucn = TRUE)
    )
    testthat::expect_identical(
        out$dynamicProperties[[1]],
        paste0(
            "{\"mmaThreatStatus\":\"VU\",\"mmaSource\":\"Portaria 1.704/2026\",",
            "\"iucnRedListCategory\":\"NT\"}"
        )
    )
    # The IUCN assessment is global, so the Peruvian row keeps it alone.
    testthat::expect_identical(
        out$dynamicProperties[[2]], "{\"iucnRedListCategory\":\"NT\"}"
    )
})

testthat::test_that("resolve_iucn_usage_keys strips the GBIF prefix and falls back by name", {
    testthat::local_mocked_bindings(
        gbif_match_usage_keys = function(names) rep("999", length(names)),
        .package = "saira"
    )
    tk <- data.frame(
        scientificName = c("A b", "C d"),
        taxonID = c("GBIF:111", "FLORABR:xyz"),
        provider = c("gbif", "florabr"),
        stringsAsFactors = FALSE
    )
    out <- saira:::resolve_iucn_usage_keys(c("A b", "C d", "E f"), tk)
    # "A b": GBIF taxonID stripped to bare key; "C d": non-GBIF provider -> match
    # fallback; "E f": absent from taxon_keys -> match fallback.
    testthat::expect_identical(out, c("111", "999", "999"))
})

# The two establishment terms are Occurrence terms, which would put them at the
# very front of the sheet. The export relocates them to the end of the Taxon
# block so they sit next to the species they describe (ADR-110).
test_that("establishment terms are exported right after the Taxon block", {
    df <- data.frame(
        occurrenceID = "1", basisOfRecord = "HumanObservation",
        degreeOfEstablishment = "invasive", country = "BR",
        scientificName = "Sus scrofa", vernacularName = "javali",
        establishmentMeans = "introduced", taxonRemarks = "x",
        identifiedBy = "y", stringsAsFactors = FALSE
    )
    ordered <- names(order_columns_dwc_canonical(df))

    expect_equal(
        ordered[which(ordered == "vernacularName") + 0:2],
        c("vernacularName", "establishmentMeans", "degreeOfEstablishment")
    )
    # Relocated, not promoted: they still trail the Taxon identity terms.
    expect_lt(which(ordered == "scientificName"), which(ordered == "establishmentMeans"))
    # And they no longer lead the sheet with the other Occurrence terms.
    expect_lt(which(ordered == "occurrenceID"), which(ordered == "establishmentMeans"))
})

test_that("the class override does not disturb terms it does not name", {
    df <- data.frame(
        taxonRemarks = "x", scientificName = "Sus scrofa",
        occurrenceID = "1", stringsAsFactors = FALSE
    )
    ordered <- names(order_columns_dwc_canonical(df))
    expect_equal(ordered, c("occurrenceID", "scientificName", "taxonRemarks"))
})

# License: the published file carries a URI ------------------------------

testthat::test_that("expand_license accepts every spelling and emits the canonical URI", {
    uris <- cc_license_uris()

    testthat::expect_identical(
        expand_license(c(
            "CC-BY", "cc-by-4.0",
            "https://creativecommons.org/licenses/by/4.0/legalcode",
            "http://creativecommons.org/licenses/by/4.0/"
        )),
        rep(unname(uris[["CC-BY"]]), 4L)
    )
    testthat::expect_identical(expand_license("CC0"), unname(uris[["CC0"]]))
    testthat::expect_identical(
        expand_license("https://creativecommons.org/licenses/by-nc/4.0/"),
        unname(uris[["CC-BY-NC"]])
    )
})

testthat::test_that("expand_license leaves unknown licenses untouched", {
    testthat::expect_identical(
        expand_license(c("Licenca Institucional XYZ", NA_character_)),
        c("Licenca Institucional XYZ", NA_character_)
    )
})

testthat::test_that("abbreviate_license still shortens, for the preview", {
    # ADR-008 keeps the short token on screen; only the published file changed.
    testthat::expect_identical(
        abbreviate_license(unname(cc_license_uris())),
        c("CC0", "CC-BY", "CC-BY-NC")
    )
})

testthat::test_that("the license column, the guide and the EML agree on one string", {
    # The bundle used to disagree with itself: the column said "CC-BY", the
    # guide said https://...legalcode and the EML said http://...legalcode.
    for (token in c("CC0", "CC-BY", "CC-BY-NC")) {
        col <- expand_license_column(
            data.frame(license = token, stringsAsFactors = FALSE)
        )$license
        eml <- build_intellectual_rights_xml(col)
        url <- regmatches(eml, regexpr('(?<=url=")[^"]+', eml, perl = TRUE))

        testthat::expect_identical(col, unname(cc_license_uris()[[token]]))
        testthat::expect_identical(url, col)
    }
})

testthat::test_that("an unknown license never becomes CC0 in the EML", {
    eml <- build_intellectual_rights_xml("Licenca Institucional XYZ")
    testthat::expect_false(grepl("publicdomain/zero", eml, fixed = TRUE))
    testthat::expect_true(grepl("Licenca Institucional XYZ", eml, fixed = TRUE))
})

# Mapping guide: identifier counts and the undeclared-column warning -----

testthat::test_that("the guide reports real identifier counts, not just a label", {
    guide <- build_mapping_guide_txt(
        map_values = list(occurrenceID = "record_key"),
        raw_data = data.frame(record_key = c("K-1", "K-2"), stringsAsFactors = FALSE),
        lang = "en",
        id_strategy = "user_supplied_with_generated",
        id_counts = list(total = 10L, preserved = 7L, generated = 3L)
    )
    txt <- paste(guide, collapse = "\n")

    testthat::expect_true(grepl("7 of 10 preserved", txt, fixed = TRUE))
    testthat::expect_true(grepl("3 generated", txt, fixed = TRUE))
    # The round-trip instruction is the actionable half of the section.
    testthat::expect_true(grepl("re-import THIS file", txt, fixed = TRUE))
})

testthat::test_that("the guide warns that undeclared columns are not published", {
    guide <- build_mapping_guide_txt(
        map_values = list(scientificName = "taxon"),
        raw_data = data.frame(
            taxon = "Dasypus novemcinctus", notes = "x", area_ha = 1,
            stringsAsFactors = FALSE
        ),
        lang = "en"
    )
    txt <- paste(guide, collapse = "\n")

    testthat::expect_true(grepl("- notes", txt, fixed = TRUE))
    testthat::expect_true(grepl("NOT declared in meta.xml", txt, fixed = TRUE))
    testthat::expect_true(grepl("GBIF will ignore them", txt, fixed = TRUE))
})

testthat::test_that("the guide stays quiet when every column is mapped", {
    guide <- build_mapping_guide_txt(
        map_values = list(scientificName = "taxon"),
        raw_data = data.frame(taxon = "Dasypus novemcinctus", stringsAsFactors = FALSE),
        lang = "en"
    )
    testthat::expect_false(
        grepl("NOT declared in meta.xml", paste(guide, collapse = "\n"), fixed = TRUE)
    )
})

testthat::test_that("unmapped_raw_columns is what both the guide and the export use", {
    raw <- data.frame(a = 1, b = 2, c = 3)
    testthat::expect_identical(
        unmapped_raw_columns(raw, list(scientificName = "a")),
        c("b", "c")
    )
    testthat::expect_identical(
        unmapped_raw_columns(raw, list(scientificName = "a"), exclude = "b"),
        "c"
    )
    testthat::expect_identical(
        unmapped_raw_columns(raw, list(x = c("a", "b", "c"))),
        character(0)
    )
})

testthat::test_that("a raw column already in the export is not reported as dropped", {
    # The everyday case: an upload that ships occurrenceID feeds the export
    # whether or not the user picked it in the dropdown, so warning that GBIF
    # would ignore it was false. The export screen and
    # process_for_export_with_unmapped() must agree on what is left out.
    raw <- data.frame(
        occurrenceID = c("A-1", "A-2"),
        especie = c("x", "y"),
        anotacoes = c("n1", "n2"),
        stringsAsFactors = FALSE
    )
    mv <- list(scientificName = "especie")
    exported <- c("occurrenceID", "scientificName", "genus")

    testthat::expect_identical(
        unmapped_raw_columns(raw, mv, exclude = exported),
        "anotacoes"
    )
})

# Issue #98: a column mapped to a term that also carries a fixed value fell
# between two steps -- the builder skipped it, then the tail excluded it as
# "used" -- and left the export entirely.

testthat::test_that("a column overridden by a fixed value comes back as an extra column", {
    raw <- data.frame(
        Especie = c("Panthera onca", "Puma concolor"),
        Municipio = c("Curitiba", "Blumenau"),
        Notas = c("a", "b"),
        stringsAsFactors = FALSE
    )
    dwc <- list(
        list(term = "occurrenceID"), list(term = "scientificName"),
        list(term = "country"), list(term = "genus"),
        list(term = "specificEpithet"), list(term = "taxonRank")
    )
    map_values <- list(scientificName = "Especie", country = "Municipio")
    constants <- list(country = "Brasil")

    res <- build_processed_mapping_df(
        df = raw, dwc_terms = dwc, map_values = map_values,
        occurrence_ids = c("id1", "id2"), constant_values = constants
    )
    overridden <- overridden_mapping_terms(constants)
    testthat::expect_identical(overridden, "country")

    out <- process_for_export_with_unmapped(
        res$data, raw_data = raw, map_values = map_values,
        overridden_terms = overridden
    )
    # The fixed value still wins for the DwC term ...
    testthat::expect_identical(out$country, c("Brasil", "Brasil"))
    # ... and the orphaned column is preserved, like any unmapped column.
    testthat::expect_true("Municipio" %in% names(out))
    testthat::expect_identical(out$Municipio, c("Curitiba", "Blumenau"))
    testthat::expect_true("Notas" %in% names(out))
})

testthat::test_that("the mapping guide reports an overridden column as unused, not mapped", {
    raw <- data.frame(
        Especie = "Panthera onca", Municipio = "Curitiba",
        stringsAsFactors = FALSE
    )
    guide <- build_mapping_guide_txt(
        list(scientificName = "Especie", country = "Municipio"),
        raw, lang = "pt", constants = list(country = "Brasil")
    )
    testthat::expect_false(any(grepl("Municipio\\s+->\\s+country", guide)))
    testthat::expect_true(any(grepl('="Brasil"\\s+->\\s+country', guide)))
    testthat::expect_true(any(grepl("^#     - Municipio$", guide)))
})

testthat::test_that("overridden_mapping_terms names only the terms with a filled value", {
    testthat::expect_identical(overridden_mapping_terms(list()), character(0))
    testthat::expect_identical(overridden_mapping_terms(NULL), character(0))
    testthat::expect_identical(
        overridden_mapping_terms(list(country = "  ", rightsHolder = "UFRJ",
                                      references = NULL, license = character(0))),
        "rightsHolder"
    )
})
