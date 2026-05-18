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
    testthat::expect_identical(out$license, c("CC0", "CC-BY", "custom-license"))
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

testthat::test_that("dwc_canonical_class_order lists 12 DwC classes with Occurrence first", {
    classes <- dwc_canonical_class_order()
    testthat::expect_identical(classes[1], "Occurrence")
    testthat::expect_true("Taxon" %in% classes)
    testthat::expect_true("Location" %in% classes)
    testthat::expect_length(classes, 12L)
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
    testthat::expect_true(match("establishmentMeans", nm) < match("decimalLatitude", nm))
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

    testthat::expect_identical(out[1], "# saira:mapping:v1")
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
    masked <- saira:::mask_sensitive_coordinates(full_data, lang = "en")

    testthat::expect_equal(masked$n_masked, 1L)

    sens_row <- which(masked$masked$scientificName == "Hippocampus reidi")
    other_row <- which(masked$masked$scientificName == "Felis catus")

    # process_for_export() numericizes the coordinate columns.
    testthat::expect_equal(masked$masked$decimalLatitude[sens_row], -23.6)
    testthat::expect_equal(masked$masked$decimalLongitude[sens_row], -46.7)
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
