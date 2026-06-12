# Tests for the DwC Archive helpers (PR-2, target v0.4.0):
# generate_occurrence_ids, build_meta_xml, build_eml_xml,
# compute_dataset_extents, build_dwca_bundle.

testthat::test_that("generate_occurrence_ids produces deterministic v5 when anchor present", {
    df <- data.frame(
        institutionCode = c("MZUSP", "MZUSP", "UFAM"),
        catalogNumber   = c("001", "002", "100"),
        scientificName  = c("A", "B", "C"),
        stringsAsFactors = FALSE
    )

    out1 <- generate_occurrence_ids(df)
    out2 <- generate_occurrence_ids(df)

    testthat::expect_identical(attr(out1, "id_strategy"), "stable_v5")
    testthat::expect_identical(out1$occurrenceID, out2$occurrenceID)
    testthat::expect_true(all(grepl("^urn:uuid:[0-9a-f-]+$", out1$occurrenceID)))
})

testthat::test_that("generate_occurrence_ids falls back to v4 when anchor absent", {
    df <- data.frame(scientificName = c("A", "B"), stringsAsFactors = FALSE)

    out <- generate_occurrence_ids(df)

    testthat::expect_identical(attr(out, "id_strategy"), "random_v4")
    testthat::expect_equal(length(out$occurrenceID), 2L)
    testthat::expect_true(all(!is.na(out$occurrenceID) & nzchar(out$occurrenceID)))
})

testthat::test_that("generate_occurrence_ids preserves user-supplied IDs", {
    df <- data.frame(
        occurrenceID = c("custom-id-1", "custom-id-2"),
        institutionCode = c("MZUSP", "MZUSP"),
        catalogNumber = c("001", "002"),
        stringsAsFactors = FALSE
    )

    out <- generate_occurrence_ids(df)

    testthat::expect_identical(attr(out, "id_strategy"), "user_supplied")
    testthat::expect_identical(out$occurrenceID, c("custom-id-1", "custom-id-2"))
})

testthat::test_that("generate_occurrence_ids mixes v5 and v4 when anchor is partial", {
    df <- data.frame(
        institutionCode = c("MZUSP", "", "MZUSP"),
        catalogNumber   = c("001", "002", ""),
        scientificName  = c("A", "B", "C"),
        stringsAsFactors = FALSE
    )

    out <- generate_occurrence_ids(df)

    testthat::expect_identical(attr(out, "id_strategy"), "stable_v5_with_random_fallback")
    testthat::expect_true(grepl("^urn:uuid:", out$occurrenceID[1]))
    testthat::expect_true(!grepl("^urn:uuid:", out$occurrenceID[2]))
    testthat::expect_true(!grepl("^urn:uuid:", out$occurrenceID[3]))
})

testthat::test_that("generate_occurrence_ids accepts eventID or recordNumber as anchor", {
    df_event <- data.frame(
        institutionCode = c("X", "X"),
        eventID = c("E1", "E2"),
        stringsAsFactors = FALSE
    )
    df_rec <- data.frame(
        institutionCode = c("X", "X"),
        recordNumber = c("R1", "R2"),
        stringsAsFactors = FALSE
    )

    testthat::expect_identical(
        attr(generate_occurrence_ids(df_event), "id_strategy"),
        "stable_v5"
    )
    testthat::expect_identical(
        attr(generate_occurrence_ids(df_rec), "id_strategy"),
        "stable_v5"
    )
})

testthat::test_that("dwc_term_uri maps DwC terms, DC terms, and rejects unknowns", {
    out <- dwc_term_uri(c("scientificName", "license", "type", "foobar"))
    testthat::expect_identical(
        out,
        c(
            "http://rs.tdwg.org/dwc/terms/scientificName",
            "http://purl.org/dc/terms/license",
            "http://purl.org/dc/terms/type",
            NA_character_
        )
    )
})

testthat::test_that("build_meta_xml emits the archive shell, id index, and DwC fields", {
    df <- data.frame(
        occurrenceID = "x",
        scientificName = "y",
        basisOfRecord = "z",
        unknown_col = "w",
        stringsAsFactors = FALSE
    )

    xml_str <- build_meta_xml(df)

    testthat::expect_true(grepl("<archive xmlns=\"http://rs.tdwg.org/dwc/text/\"", xml_str, fixed = TRUE))
    testthat::expect_true(grepl("rowType=\"http://rs.tdwg.org/dwc/terms/Occurrence\"", xml_str, fixed = TRUE))
    testthat::expect_true(grepl("<location>occurrence.txt</location>", xml_str, fixed = TRUE))
    testthat::expect_true(grepl("<id index=\"0\"/>", xml_str, fixed = TRUE))
    testthat::expect_true(grepl("term=\"http://rs.tdwg.org/dwc/terms/scientificName\"", xml_str, fixed = TRUE))
    testthat::expect_true(grepl("term=\"http://rs.tdwg.org/dwc/terms/basisOfRecord\"", xml_str, fixed = TRUE))
    # Unknown column is in occurrence.txt but NOT declared as a field.
    testthat::expect_false(grepl("unknown_col", xml_str, fixed = TRUE))
})

testthat::test_that("compute_dataset_extents derives bbox and date range from valid rows", {
    df <- data.frame(
        decimalLatitude = c(-8.05, -3.10, NA, 95),
        decimalLongitude = c(-34.88, -60.02, -50, 0),
        eventDate = c("2024-01-15", "2024-02-20", "garbage", "2024-03-01T08:00:00Z"),
        stringsAsFactors = FALSE
    )

    ext <- compute_dataset_extents(df)

    testthat::expect_equal(ext$bbox[["west"]], -60.02)
    testthat::expect_equal(ext$bbox[["east"]], -34.88)
    testthat::expect_equal(ext$bbox[["north"]], -3.10)
    testthat::expect_equal(ext$bbox[["south"]], -8.05)
    testthat::expect_identical(ext$dates[["begin"]], "2024-01-15")
    testthat::expect_identical(ext$dates[["end"]], "2024-03-01")
})

testthat::test_that("compute_dataset_extents returns NA bbox/dates when columns absent", {
    df <- data.frame(scientificName = c("A"), stringsAsFactors = FALSE)
    ext <- compute_dataset_extents(df)
    testthat::expect_true(all(is.na(ext$bbox)))
    testthat::expect_true(all(is.na(ext$dates)))
})

testthat::test_that("build_eml_xml emits required EML fields with defaults", {
    df <- data.frame(
        scientificName = c("A", "B"),
        decimalLatitude = c(-8, -3),
        decimalLongitude = c(-34, -60),
        eventDate = c("2024-01-15", "2024-02-20"),
        stringsAsFactors = FALSE
    )

    xml_str <- build_eml_xml(df)
    doc <- xml2::read_xml(xml_str)
    ns <- c(eml = "https://eml.ecoinformatics.org/eml-2.1.1")

    testthat::expect_length(xml2::xml_find_all(doc, "//title"), 1L)
    testthat::expect_length(xml2::xml_find_all(doc, "//creator"), 1L)
    testthat::expect_length(xml2::xml_find_all(doc, "//pubDate"), 1L)
    testthat::expect_length(xml2::xml_find_all(doc, "//abstract"), 1L)
    testthat::expect_length(xml2::xml_find_all(doc, "//intellectualRights"), 1L)
    testthat::expect_length(xml2::xml_find_all(doc, "//contact"), 1L)
    testthat::expect_length(xml2::xml_find_all(doc, "//geographicCoverage"), 1L)
    testthat::expect_length(xml2::xml_find_all(doc, "//temporalCoverage"), 1L)
    # Title default includes today's date.
    title_text <- xml2::xml_text(xml2::xml_find_first(doc, "//title"))
    testthat::expect_true(grepl("^Saira export ", title_text))
})

testthat::test_that("build_eml_xml respects user-supplied metadata", {
    df <- data.frame(scientificName = "x", stringsAsFactors = FALSE)
    xml_str <- build_eml_xml(df, metadata = list(
        title = "My Dataset",
        creator = list(name = "Jane Doe", email = "jane@ex.org", organization = "Lab"),
        license = "CC-BY-4.0",
        abstract = "Short description."
    ))
    doc <- xml2::read_xml(xml_str)

    testthat::expect_identical(
        xml2::xml_text(xml2::xml_find_first(doc, "//title")),
        "My Dataset"
    )
    testthat::expect_identical(
        xml2::xml_text(xml2::xml_find_first(doc, "//givenName")),
        "Jane"
    )
    testthat::expect_identical(
        xml2::xml_text(xml2::xml_find_first(doc, "//surName")),
        "Doe"
    )
    testthat::expect_identical(
        xml2::xml_text(xml2::xml_find_first(doc, "//electronicMailAddress")),
        "jane@ex.org"
    )
    testthat::expect_true(grepl(
        "Attribution 4.0",
        xml2::xml_text(xml2::xml_find_first(doc, "//intellectualRights"))
    ))
    testthat::expect_identical(
        xml2::xml_text(xml2::xml_find_first(doc, "//abstract")),
        "Short description."
    )
})

testthat::test_that("build_eml_xml emits a sensitivity access block when masking ran", {
    df <- data.frame(scientificName = "x", stringsAsFactors = FALSE)
    xml_str <- build_eml_xml(df, metadata = list(
        sensitivity = list(n_masked = 7L, review_date = "2028-06-10", lang = "en")
    ))
    doc <- xml2::read_xml(xml_str)

    ai <- xml2::xml_find_all(doc, "//additionalInfo")
    testthat::expect_length(ai, 1L)
    note <- xml2::xml_text(ai)
    testthat::expect_true(grepl("7", note))
    testthat::expect_true(grepl("2028-06-10", note))
    # additionalInfo must precede intellectualRights (EML 2.1.1 sequence).
    kids <- xml2::xml_name(xml2::xml_children(
        xml2::xml_find_first(doc, "//dataset")
    ))
    testthat::expect_lt(
        which(kids == "additionalInfo"),
        which(kids == "intellectualRights")
    )
})

testthat::test_that("build_eml_xml omits the access block without sensitivity data", {
    df <- data.frame(scientificName = "x", stringsAsFactors = FALSE)
    # Absent, and present-but-zero, both yield no additionalInfo.
    for (meta in list(list(), list(sensitivity = list(n_masked = 0L)))) {
        doc <- xml2::read_xml(build_eml_xml(df, metadata = meta))
        testthat::expect_length(xml2::xml_find_all(doc, "//additionalInfo"), 0L)
    }
})

testthat::test_that("build_dwca_bundle produces ZIP with occurrence.txt + meta.xml + eml.xml", {
    df <- data.frame(
        occurrenceID = c("a", "b"),
        scientificName = c("A", "B"),
        decimalLatitude = c(-8, -3),
        decimalLongitude = c(-34, -60),
        eventDate = c("2024-01-15", "2024-02-20"),
        stringsAsFactors = FALSE
    )

    zip_path <- tempfile(fileext = ".zip")
    on.exit(unlink(zip_path), add = TRUE)
    build_dwca_bundle(df, zip_path)

    files <- zip::zip_list(zip_path)$filename
    testthat::expect_true("occurrence.txt" %in% files)
    testthat::expect_true("meta.xml" %in% files)
    testthat::expect_true("eml.xml" %in% files)
})

testthat::test_that("build_dwca_bundle includes extras at archive root", {
    df <- data.frame(occurrenceID = "x", scientificName = "y", stringsAsFactors = FALSE)
    extra_file <- tempfile(fileext = ".txt")
    on.exit(unlink(extra_file), add = TRUE)
    writeLines("extra content", extra_file)

    zip_path <- tempfile(fileext = ".zip")
    on.exit(unlink(zip_path), add = TRUE)
    build_dwca_bundle(df, zip_path, extras = list("mapping_guide.txt" = extra_file))

    files <- zip::zip_list(zip_path)$filename
    testthat::expect_true("mapping_guide.txt" %in% files)
})

testthat::test_that("build_mapping_guide_txt emits identifier-strategy section when supplied", {
    out_en <- build_mapping_guide_txt(
        map_values = list(scientificName = "sci"),
        raw_data = data.frame(sci = "X", stringsAsFactors = FALSE),
        lang = "en",
        id_strategy = "random_v4"
    )
    out_pt <- build_mapping_guide_txt(
        map_values = list(scientificName = "sci"),
        raw_data = data.frame(sci = "X", stringsAsFactors = FALSE),
        lang = "pt",
        id_strategy = "stable_v5"
    )
    out_none <- build_mapping_guide_txt(
        map_values = list(scientificName = "sci"),
        raw_data = data.frame(sci = "X", stringsAsFactors = FALSE),
        lang = "en"
    )

    testthat::expect_true(any(grepl("identifier strategy", out_en, ignore.case = TRUE)))
    testthat::expect_true(any(grepl("Random UUIDs", out_en)))
    testthat::expect_true(any(grepl("estrategia de occurrenceID", out_pt)))
    testthat::expect_true(any(grepl("stable_v5", out_pt)))
    # Without id_strategy, no section emitted.
    testthat::expect_false(any(grepl("identifier strategy", out_none, ignore.case = TRUE)))
})

testthat::test_that("process_for_export preserves id_strategy attribute through pipeline", {
    df <- data.frame(
        scientificName = c("A", "B"),
        eventDate = c("2024-01-15", "2024-02-20"),
        decimalLatitude = c(-8, -3),
        decimalLongitude = c(-34, -60),
        institutionCode = c("MZUSP", "MZUSP"),
        catalogNumber = c("001", "002"),
        basisOfRecord = c("HumanObservation", "HumanObservation"),
        stringsAsFactors = FALSE
    )

    out <- process_for_export(df)
    testthat::expect_identical(attr(out, "id_strategy"), "stable_v5")
})
