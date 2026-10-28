test_that("measurement_value_source reads the per-column names", {
    names <- c("measurementValue [AREA_HA]", "measurementValue", "measurementValue [a [b]]",
               "scientificName")
    expect_equal(measurement_value_source(names), c("AREA_HA", NA, "a [b]", NA))
    expect_equal(is_measurement_value_term(names), c(TRUE, TRUE, TRUE, FALSE))
    expect_equal(measurement_value_column("AREA_HA"), "measurementValue [AREA_HA]")
})

test_that("the mapped frame keeps one column per measurementValue source", {
    raw <- data.frame(id = c("a", "b"), sp = "Cabassous unicinctus",
                      AREA_HA = c("10", ""), Annual_rainfall = c("993", "685"),
                      stringsAsFactors = FALSE)
    terms <- get_active_dwc_terms_list("measurementValue", "en")
    terms <- terms[c("occurrenceID", "scientificName", "measurementValue")]
    built <- build_processed_mapping_df(
        df = raw, dwc_terms = terms,
        map_values = list(scientificName = "sp",
                          measurementValue = c("AREA_HA", "Annual_rainfall")),
        occurrence_ids = raw$id
    )$data
    expect_false("measurementValue" %in% names(built))
    expect_equal(built[["measurementValue [AREA_HA]"]], c("10", ""))
    expect_equal(built[["measurementValue [Annual_rainfall]"]], c("993", "685"))

    one <- build_processed_mapping_df(
        df = raw, dwc_terms = terms,
        map_values = list(scientificName = "sp", measurementValue = "AREA_HA"),
        occurrence_ids = raw$id
    )$data
    expect_equal(one$measurementValue, c("10", ""))
    expect_true(all(is.na(measurement_value_source(names(one)))))
})

test_that("the canonical order keeps the measurement columns together", {
    df <- data.frame(`measurementValue [b]` = "1", occurrenceID = "o1",
                     `measurementValue [a]` = "2", measurementUnit = "mm", scientificName = "x",
                     check.names = FALSE, stringsAsFactors = FALSE)
    out <- names(order_columns_dwc_canonical(df))
    expect_equal(out[1], "occurrenceID")
    at <- match(c("measurementValue [b]", "measurementValue [a]"), out)
    expect_equal(diff(at), 1L)
    expect_true(match("scientificName", out) < at[1])
})

test_that("split_measurements gives one row per filled cell of each value column", {
    # The Preview corrected "10kg" to "10" in the AREA_HA column.
    df <- data.frame(
        occurrenceID = c("o1", "o2", "o3"),
        scientificName = "Cabassous unicinctus",
        `measurementValue [AREA_HA]` = c("10", "", "5"),
        `measurementValue [Annual_rainfall]` = c("993", "685", NA),
        measurementType = "joined",
        measurementMethod = "WorldClim v1.4",
        check.names = FALSE, stringsAsFactors = FALSE
    )
    specs <- list(AREA_HA = list(measurementType = "area of sampling site",
                                 measurementUnit = "ha", measurementMethod = ""))

    res <- split_measurements(df, specs = specs)
    mof <- res$measurements

    expect_equal(mof$occurrenceID, c("o1", "o1", "o2", "o3"))
    expect_equal(mof$measurementID,
                 c("o1:AREA_HA", "o1:Annual_rainfall", "o2:Annual_rainfall", "o3:AREA_HA"))
    # A type typed for a column wins; the other column keeps its name. The
    # mapped measurementType cannot name two columns, so it is not read.
    expect_equal(mof$measurementType,
                 c("area of sampling site", "Annual_rainfall", "Annual_rainfall",
                   "area of sampling site"))
    expect_equal(mof$measurementValue, c("10", "993", "685", "5"))
    expect_equal(mof$measurementUnit, c("ha", "", "", "ha"))
    expect_equal(mof$measurementMethod, rep("WorldClim v1.4", 4))
    expect_equal(names(mof)[1:5], c("occurrenceID", "measurementID", "measurementType",
                                    "measurementValue", "measurementUnit"))
    expect_equal(names(res$core), c("occurrenceID", "scientificName"))
})

test_that("split_measurements reads one value column from the export frame", {
    df <- data.frame(
        occurrenceID = c("o1", "o2", "o3"),
        measurementValue = c("1.2", "", "3"),
        measurementType = c("body mass", "", ""),
        measurementUnit = "kg",
        stringsAsFactors = FALSE
    )
    attr(df, "id_strategy") <- "user_supplied"

    res <- split_measurements(df, "mass")

    expect_equal(res$measurements$occurrenceID, c("o1", "o3"))
    expect_equal(res$measurements$measurementValue, c("1.2", "3"))
    expect_equal(res$measurements$measurementType, c("body mass", "mass"))
    expect_equal(res$measurements$measurementID, c("o1:mass", "o3:mass"))
    expect_equal(res$measurements$measurementUnit, c("kg", "kg"))
    expect_equal(names(res$core), "occurrenceID")
    expect_equal(attr(res$core, "id_strategy"), "user_supplied")

    # The type, unit and method of the card also serve one column.
    spec <- list(mass = list(measurementType = "weight", measurementUnit = "g"))
    res <- split_measurements(df, "mass", spec)
    expect_equal(res$measurements$measurementType, c("weight", "weight"))
    expect_equal(res$measurements$measurementUnit, c("g", "g"))
})

test_that("split_measurements keeps a mapped measurementID for one value column", {
    df <- data.frame(occurrenceID = c("o1", "o2"), measurementID = c("m1", "m2"),
                     measurementValue = c("4", "5"), stringsAsFactors = FALSE)
    res <- split_measurements(df, "count")
    expect_equal(res$measurements$measurementID, c("m1", "m2"))

    # A fixed value has no column to name the measurement after.
    res <- split_measurements(df[, c("occurrenceID", "measurementValue")])
    expect_equal(res$measurements$measurementID, c("", ""))
    expect_equal(res$measurements$measurementType, c("", ""))
    expect_equal(split_measurements(df[, c("occurrenceID", "measurementValue")], NA)$measurements,
                 res$measurements)
})

test_that("split_measurements leaves the export unchanged without a measurement", {
    df <- data.frame(occurrenceID = c("o1", "o2"), measurementValue = c("", NA),
                     measurementUnit = "mm", stringsAsFactors = FALSE)
    res <- split_measurements(df, "x")
    expect_null(res$measurements)
    expect_identical(res$core, df)

    no_id <- data.frame(measurementValue = "4", stringsAsFactors = FALSE)
    expect_null(split_measurements(no_id, "x")$measurements)
    expect_null(split_measurements(data.frame(occurrenceID = "o1"))$measurements)
})

test_that("build_meta_xml declares the MeasurementOrFact extension", {
    df <- data.frame(occurrenceID = "o1", scientificName = "x", stringsAsFactors = FALSE)
    mof <- data.frame(occurrenceID = "o1", measurementID = "o1:a", measurementType = "a",
                      measurementValue = "1", measurementUnit = "", stringsAsFactors = FALSE)

    doc <- xml2::read_xml(build_meta_xml(df, measurements = mof))
    xml2::xml_ns_strip(doc)
    ext <- xml2::xml_find_first(doc, "/archive/extension")

    expect_equal(xml2::xml_attr(ext, "rowType"), "http://rs.tdwg.org/dwc/terms/MeasurementOrFact")
    expect_equal(xml2::xml_text(xml2::xml_find_first(ext, "files/location")), "measurementorfact.txt")
    expect_equal(xml2::xml_attr(xml2::xml_find_first(ext, "coreid"), "index"), "0")
    fields <- xml2::xml_find_all(ext, "field")
    expect_equal(xml2::xml_attr(fields, "index"), c("1", "2", "3", "4"))
    expect_equal(xml2::xml_attr(fields, "term")[[2]], "http://rs.tdwg.org/dwc/terms/measurementType")

    plain <- xml2::read_xml(build_meta_xml(df))
    xml2::xml_ns_strip(plain)
    expect_length(xml2::xml_find_all(plain, "/archive/extension"), 0L)
})

test_that("build_dwca_bundle writes measurementorfact.txt only with measurements", {
    df <- data.frame(occurrenceID = c("o1", "o2"), scientificName = "x",
                     `measurementValue [a]` = c("1", "2"), `measurementValue [b]` = c("3", ""),
                     check.names = FALSE, stringsAsFactors = FALSE)
    res <- split_measurements(df)

    zip_path <- tempfile(fileext = ".zip")
    build_dwca_bundle(res$core, zip_path, measurements = res$measurements)
    dir <- tempfile("bundle_")
    zip::unzip(zip_path, exdir = dir)

    expect_setequal(list.files(dir),
                    c("occurrence.txt", "meta.xml", "eml.xml", "measurementorfact.txt"))
    mof <- utils::read.csv(file.path(dir, "measurementorfact.txt"), colClasses = "character")
    expect_equal(mof$measurementID, c("o1:a", "o1:b", "o2:a"))
    core <- utils::read.csv(file.path(dir, "occurrence.txt"), colClasses = "character",
                            check.names = FALSE)
    expect_equal(names(core), c("occurrenceID", "scientificName"))

    zip_plain <- tempfile(fileext = ".zip")
    build_dwca_bundle(df[, 1:2], zip_plain)
    expect_false("measurementorfact.txt" %in% zip::zip_list(zip_plain)$filename)
})

test_that("export_bundle_filenames lists the extension with measurements", {
    expect_equal(export_bundle_filenames("x")$dwca, c("occurrence.txt", "meta.xml", "eml.xml"))
    expect_equal(export_bundle_filenames("x", has_measurements = TRUE)$dwca,
                 c("occurrence.txt", "meta.xml", "eml.xml", "measurementorfact.txt"))
})

test_that("suggest_measurement_columns reads the unit at the end of a column name", {
    df <- data.frame(
        AREA_HA = c("10", "5,5", "12 ha", ""),
        `peso (kg)` = c("1.2", "3", "4", "2"),
        temp_c = c("21", "22.5", "", "20"),
        dia_inicio = c("1", "2", "3", "4"),
        especie_ha = c("Puma", "Ateles", "Inia", "Lontra"),
        altitude_m = c("100", "200", "300", "400"),
        check.names = FALSE, stringsAsFactors = FALSE
    )

    # A name without a unit (dia_inicio) and text values (especie_ha) stay out.
    expect_equal(suggest_measurement_columns(df),
                 c(AREA_HA = "ha", `peso (kg)` = "kg", temp_c = "°C", altitude_m = "m"))
    # A column with a term stays out.
    expect_equal(names(suggest_measurement_columns(df, exclude = c("altitude_m", "temp_c"))),
                 c("AREA_HA", "peso (kg)"))
    expect_length(suggest_measurement_columns(df["dia_inicio"]), 0L)
})
