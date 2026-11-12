# Title: Tests for the export product built outside Shiny (SP-01, SP-08)

product_inputs <- function(notes = c("a", "a", "b")) {
    df <- data.frame(
        occurrenceID = c("o1", "o2", "o3"),
        scientificName = c("Aus bus", "Aus bus", "Cus dus"),
        eventDate = "2024-01-01",
        decimalLatitude = c("-23.5", "-23.5", "-22.1"),
        decimalLongitude = c("-46.6", "-46.6", "-45.0"),
        basisOfRecord = "HumanObservation",
        measurementValue = c("10", "10", "12"),
        stringsAsFactors = FALSE
    )
    raw <- data.frame(especie = df$scientificName, massa = df$measurementValue,
                      notas = notes, stringsAsFactors = FALSE)
    list(
        download_data = df, raw_data = raw,
        map_values = list(scientificName = "especie", measurementValue = "massa"),
        rows_left_out = 2L,
        measurement_specs = list(massa = list(measurementType = "body mass", measurementUnit = "g"))
    )
}

testthat::test_that("prepare_export_product composes the core, the measurements and the guide", {
    product <- prepare_export_product(product_inputs(), "en")

    # The exact copy is out, the unmapped column joins, the measurement leaves the core.
    testthat::expect_identical(product$core$occurrenceID, c("o1", "o3"))
    testthat::expect_identical(product$core$notas, c("a", "b"))
    testthat::expect_false("measurementValue" %in% names(product$core))
    testthat::expect_identical(product$measurements$occurrenceID, c("o1", "o3"))
    testthat::expect_identical(product$measurements$measurementType, c("body mass", "body mass"))
    testthat::expect_identical(product$measurements$measurementUnit, c("g", "g"))
    testthat::expect_true(is.character(product$mapping_guide) && length(product$mapping_guide) > 0L)
    testthat::expect_true(is.data.frame(product$real))
})

testthat::test_that("prepare_export_product takes a source table with one column", {
    inputs <- product_inputs()
    inputs$raw_data <- inputs$raw_data["especie"]
    product <- prepare_export_product(inputs, "en")
    testthat::expect_identical(product$core$occurrenceID, c("o1", "o3"))
})

testthat::test_that("prepare_export_product stops on a formula that the unmapped columns bring", {
    testthat::expect_error(
        prepare_export_product(product_inputs(notes = c("a", "a", "=1+1")), "en"),
        tr("export_download_blocked", "en"), fixed = TRUE
    )
})

testthat::test_that("prepare_masked_export stops on a generalization with no justification", {
    inputs <- product_inputs()
    inputs$generalization <- list(enabled = TRUE, needs_justification = TRUE, justification = " ")
    testthat::expect_error(
        prepare_masked_export(inputs, "en"),
        tr("preview_export_needs_justification", "en"), fixed = TRUE
    )
})

testthat::test_that("capture_sources tells an absent source from a failed one", {
    ok_r <- shiny::reactive(1L)
    not_ready_r <- shiny::reactive(shiny::req(FALSE))
    broken_r <- shiny::reactive(stop("injected failure"))
    src <- testthat::expect_warning(
        shiny::isolate(capture_sources(
            list(absent = NULL, ok = ok_r, not_ready = not_ready_r, broken = broken_r),
            defaults = list(absent = "none", not_ready = "wait")
        )),
        "Could not read broken"
    )
    testthat::expect_identical(src$values, list(absent = "none", ok = 1L, not_ready = "wait", broken = NULL))
    testthat::expect_identical(src$failed, c(broken = "injected failure"))
})

# The files the download handler writes, as text per file name.
public_bundle_text <- function(product, env = parent.frame()) {
    dir <- tempfile("bundle_")
    dir.create(dir)
    withr::defer(unlink(dir, recursive = TRUE), envir = env)
    names <- export_bundle_filenames(
        dataset_name = product$dataset_name, n_records = nrow(product$core),
        has_changes = nrow(product$changes) > 0L, has_measurements = !is.null(product$measurements)
    )
    extras <- list()
    xlsx <- file.path(dir, names$auxiliary$xlsx)
    write_xlsx_text_only(product$core, xlsx)
    extras[[basename(xlsx)]] <- xlsx
    guide <- file.path(dir, names$auxiliary[["mapping_guide"]])
    writeLines(product$mapping_guide, guide, useBytes = TRUE)
    extras[[basename(guide)]] <- guide
    if (!is.null(names$auxiliary$changes)) {
        changes <- file.path(dir, names$auxiliary$changes)
        write_change_log_csv(product$changes, changes)
        extras[[basename(changes)]] <- changes
    }
    zip_path <- file.path(dir, "bundle.zip")
    build_dwca_bundle(product$core, zip_path, metadata = product$metadata,
                      extras = extras, measurements = product$measurements)
    out <- file.path(dir, "out")
    utils::unzip(zip_path, exdir = out)
    files <- list.files(out, full.names = TRUE)
    stats::setNames(lapply(files, function(path) {
        if (grepl("\\.xlsx$", path)) {
            sheets <- lapply(readxl::excel_sheets(path), function(sheet) {
                unlist(readxl::read_xlsx(path, sheet = sheet, col_types = "text"))
            })
            return(paste(unlist(sheets), collapse = "\n"))
        }
        paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    }), basename(files))
}

local_panthera_fixture <- function(env = parent.frame()) {
    species <- "Panthera onca"
    sensitive_species_cache$set(
        data.frame(scientificName = species, match_key = build_sensitive_match_keys(species),
                   category = "CR", stringsAsFactors = FALSE),
        path = "test-fixture"
    )
    withr::defer(sensitive_species_cache$reset(), envir = env)
}

testthat::test_that("no public file keeps the point, from any text input (ADR-190)", {
    local_panthera_fixture()
    # Moved twice, already coarse, withheld, and one row that is not sensitive.
    lat <- c("-23.55052", "-10.51234", "-5.1", "95.12345", "-1.5")
    lon <- c("-46.63331", "-55.23456", "-40.2", "-47.77777", "-50.5")
    own <- c(
        "GPS -23.55052, -46.63331; -2.355052e1; 23 33 1.872 S; 46\u00b037'59.916\" W",
        "GPS -10.51234, -55.23456",
        "GPS -5.12345, -40.23456",
        "GPS 95.12345, -47.77777",
        ""
    )
    shared <- "Base -23.55052, -46.63331, -10.51234, -55.23456, -5.12345, -40.23456, 95.12345, -47.77777"
    real <- c("23.55052", "46.63331", "2.355052", "23 33 1.872", "59.916", "10.51234", "55.23456",
              "5.12345", "40.23456", "95.12345", "47.77777")

    df <- data.frame(
        occurrenceID = paste0("o", 1:5),
        scientificName = c(rep("Panthera onca", 4), "Aus bus"),
        decimalLatitude = lat, decimalLongitude = lon,
        stringsAsFactors = FALSE
    )
    # Every term of the catalog holds the point of its own row.
    terms <- setdiff(get_dwc_full_catalog()$term, names(df))
    for (term in terms) df[[term]] <- own
    fixed <- list(references = shared, bibliographicCitation = shared, datasetName = shared)
    for (term in names(fixed)) df[[term]] <- fixed[[term]]
    raw <- data.frame(especie = df$scientificName, massa = own, notas = own, stringsAsFactors = FALSE)
    attr(raw, "source_file") <- "site_-23.55052_-46.63331.csv"

    product <- prepare_export_product(list(
        download_data = df, raw_data = raw,
        generalization = list(enabled = TRUE, levels = "high", needs_justification = TRUE,
                              justification = shared),
        map_values = list(scientificName = "especie", measurementValue = "massa"),
        custom_values = fixed,
        measurement_specs = list(massa = list(
            measurementType = shared, measurementUnit = shared, measurementMethod = shared
        )),
        preview_changes = data.frame(row = 1L, term = "occurrenceRemarks", from = own[1], to = "x",
                                     stringsAsFactors = FALSE)
    ), "en")

    files <- public_bundle_text(product)
    testthat::expect_true(all(c("occurrence.txt", "measurementorfact.txt", "eml.xml", "meta.xml") %in% names(files)))
    testthat::expect_true(any(grepl("mapping", names(files))))
    testthat::expect_true(any(grepl("\\.xlsx$", names(files))))
    for (name in names(files)) {
        found <- real[vapply(real, grepl, logical(1), x = files[[name]], fixed = TRUE)]
        testthat::expect_identical(found, character(0), info = name)
    }
    # The filter did not clear the text by removing it.
    testthat::expect_true(all(grepl("Base -23.6, -46.6", product$core$references, fixed = TRUE)))
    testthat::expect_true(all(grepl("Base -23.6, -46.6", product$measurements$measurementMethod, fixed = TRUE)))
    testthat::expect_true(any(grepl("Base -23.6, -46.6", product$mapping_guide, fixed = TRUE)))
})

testthat::test_that("prepare_export_product stops on a column name that reads as a formula", {
    inputs <- product_inputs()
    inputs$raw_data[["=1+1"]] <- "nota"
    testthat::expect_error(prepare_export_product(inputs, "en"),
                           saira:::tr("export_download_blocked", "en"), fixed = TRUE)
})

testthat::test_that("times, dates, numeric terms and measurements stay in the public files (ADR-190)", {
    local_panthera_fixture()
    df <- data.frame(
        occurrenceID = c("o1", "o2"), scientificName = "Panthera onca",
        decimalLatitude = c("-23.55052", "-12.05052"), decimalLongitude = c("-46.63331", "-46.63331"),
        eventDate = c("2024-05-12T23:33:01.872", "2024-05-12 23:33:01.872"),
        eventTime = c("23:33:01.872", "23:33:01"),
        verbatimEventDate = c("entre 23:33:01 e 23:40:12", "12.05.2024"),
        minimumElevationInMeters = "23.55",
        catalogNumber = "23.551",
        stringsAsFactors = FALSE
    )
    df[[measurement_value_column("mass")]] <- "23.551"
    df[[measurement_value_column("area")]] <- "46.634"
    raw <- data.frame(especie = df$scientificName, mass = "23.551", area = "46.634", stringsAsFactors = FALSE)

    product <- prepare_export_product(list(
        download_data = df, raw_data = raw,
        generalization = list(enabled = TRUE, levels = "high", needs_justification = FALSE),
        map_values = list(scientificName = "especie", measurementValue = c("mass", "area")),
        measurement_specs = list(mass = list(measurementType = "mass", measurementUnit = "g"),
                                 area = list(measurementType = "area", measurementUnit = "ha"))
    ), "en")

    testthat::expect_identical(as.character(product$core$decimalLatitude), c("-23.6", "-12.1"))
    # The space before the time becomes the ISO "T"; no digit of the date is rounded.
    iso_dates <- rep("2024-05-12T23:33:01.872", 2)
    testthat::expect_identical(product$core$eventDate, iso_dates)
    testthat::expect_identical(product$core$eventTime, df$eventTime)
    testthat::expect_identical(product$core$verbatimEventDate, df$verbatimEventDate)
    testthat::expect_identical(as.character(product$core$minimumElevationInMeters), c("23.55", "23.55"))
    testthat::expect_identical(product$core$catalogNumber, c("23.551", "23.551"))
    testthat::expect_identical(product$measurements$measurementValue, c("23.551", "46.634", "23.551", "46.634"))

    files <- public_bundle_text(product)
    occurrence <- utils::read.csv(text = files[["occurrence.txt"]], colClasses = "character", encoding = "UTF-8")
    testthat::expect_identical(occurrence$eventTime, df$eventTime)
    testthat::expect_identical(occurrence$eventDate, iso_dates)
    testthat::expect_true(grepl("23.551", files[["measurementorfact.txt"]], fixed = TRUE))
})

point_gap_inputs <- function() {
    df <- data.frame(
        occurrenceID = c("o1", "o2"), scientificName = "Panthera onca",
        eventDate = "2024-01-01", basisOfRecord = "HumanObservation", license = "CC0",
        decimalLatitude = c("-23.55052", ""), decimalLongitude = c("-46.63331", ""),
        verbatimCoordinates = "23.55052 S, 46.63331 W",
        footprintWKT = "POINT (-46.63331 -23.55052)", footprintSRS = "EPSG:4326",
        occurrenceRemarks = c("GPS -23.55052, -46.63331", "adult"),
        stringsAsFactors = FALSE
    )
    list(
        download_data = df,
        generalization = list(enabled = TRUE, levels = c("Panthera onca" = "high"),
                              needs_justification = TRUE, justification = "Test")
    )
}

testthat::test_that("the public product holds no location field of a protected row with no point", {
    testthat::local_mocked_bindings(
        sensitive_resolve = function(names, decisions = NULL) {
            data.frame(sensitive = rep(TRUE, length(names)), category = "CR", stringsAsFactors = FALSE)
        }
    )
    product <- prepare_export_product(point_gap_inputs(), "en")
    core <- product$core
    testthat::expect_identical(core$verbatimCoordinates, c("", ""))
    testthat::expect_identical(core$footprintWKT[2], "")
    cells <- unlist(lapply(core, as.character), use.names = FALSE)
    testthat::expect_false(any(grepl("55052|63331", cells)))
    testthat::expect_false(any(grepl("55052|63331", product$mapping_guide)))
})

testthat::test_that("the export stops on a protected row with no point and a coordinate in text", {
    testthat::local_mocked_bindings(
        sensitive_resolve = function(names, decisions = NULL) {
            data.frame(sensitive = rep(TRUE, length(names)), category = "CR", stringsAsFactors = FALSE)
        }
    )
    inputs <- point_gap_inputs()
    inputs$download_data$occurrenceRemarks[2] <- "GPS -23.55052, -46.63331"
    testthat::expect_error(prepare_export_product(inputs, "en"),
                           saira:::tr("export_download_blocked", "en"), fixed = TRUE)
    # The row left out of the package does not count.
    inputs$rows_left_out <- 2L
    testthat::expect_identical(prepare_export_product(inputs, "en")$core$occurrenceID, "o1")
})

testthat::test_that("the export stops on a coordinate column of a protected row the mask leaves", {
    testthat::local_mocked_bindings(
        sensitive_resolve = function(names, decisions = NULL) {
            data.frame(sensitive = rep(TRUE, length(names)), category = "CR", stringsAsFactors = FALSE)
        }
    )
    inputs <- point_gap_inputs()
    inputs$download_data$verbatimCoordinates <- ""
    inputs$download_data$footprintWKT <- ""
    inputs$download_data$footprintSRS <- ""
    inputs$download_data$occurrenceRemarks <- ""
    inputs$raw_data <- data.frame(especie = "Panthera onca", gps = c("x", "-23.55052, -46.63331"),
                                  stringsAsFactors = FALSE)
    inputs$map_values <- list(scientificName = "especie")
    testthat::expect_error(prepare_export_product(inputs, "en"),
                           saira:::tr("export_download_blocked", "en"), fixed = TRUE)
    # On a row of the mask the export blanks the column by itself.
    inputs$download_data$locality <- c("", "Fazenda Azul")
    testthat::expect_true(is.na(prepare_export_product(inputs, "en")$core$gps[2]))
})

# Two protected rows and one that is not, for the copies of a point in other
# rows (ADR-204).
cross_row_inputs <- function() {
    df <- data.frame(
        occurrenceID = c("o1", "o2", "o3", "o4"),
        scientificName = c("Panthera onca", "Panthera onca", "Aus bus", "Aus bus"),
        decimalLatitude = c("-23.55052", "-10.51234", "-1.5", "-23.55052"),
        decimalLongitude = c("-46.63331", "-55.23456", "-50.5", "-46.63331"),
        occurrenceRemarks = c("Other station -10.51234, -55.23456",
                              "Other station -23.55052, -46.63331",
                              "Near 23°33'1.872\"S 46°37'59.916\"W, pH 6.5",
                              "Same station -23.55052, -46.63331"),
        stringsAsFactors = FALSE
    )
    raw <- data.frame(especie = df$scientificName,
                      notas = c("a", "b", "Base -10.51234 -55.23456", "length 23.551 cm"),
                      stringsAsFactors = FALSE)
    list(
        download_data = df, raw_data = raw,
        generalization = list(enabled = TRUE, levels = "high", needs_justification = FALSE),
        map_values = list(scientificName = "especie")
    )
}

testthat::test_that("no public file keeps the point of another row (ADR-204)", {
    local_panthera_fixture()
    product <- prepare_export_product(cross_row_inputs(), "en")
    testthat::expect_identical(product$core$occurrenceRemarks[1:3], c(
        "Other station -10.5, -55.2", "Other station -23.6, -46.6", "Near 23.6 S 46.6 W, pH 6.5"
    ))
    testthat::expect_identical(product$core$notas, c("a", "b", "Base -10.5 -55.2", "length 23.551 cm"))
    # A row that is not protected keeps its own point, also in its text.
    testthat::expect_identical(product$core$occurrenceRemarks[4], "Same station -23.55052, -46.63331")

    files <- public_bundle_text(product)
    for (name in names(files)) {
        testthat::expect_false(grepl("10.51234|55.23456|1.872", files[[name]]), info = name)
    }
})

testthat::test_that("one number of a point in another row stays", {
    local_panthera_fixture()
    inputs <- cross_row_inputs()
    inputs$download_data$occurrenceRemarks[3] <- "Depth 10.51234 m"
    product <- prepare_export_product(inputs, "en")
    testthat::expect_identical(product$core$occurrenceRemarks[3], "Depth 10.51234 m")
})

testthat::test_that("the export stops on a column name or occurrenceID with a protected point", {
    local_panthera_fixture()
    inputs <- cross_row_inputs()
    inputs$raw_data[["Station -23.55052 -46.63331"]] <- "10"
    testthat::expect_error(prepare_export_product(inputs, "en"),
                           tr("export_download_blocked", "en"), fixed = TRUE)
    # Also when the column feeds a measurement.
    inputs$map_values$measurementValue <- "Station -23.55052 -46.63331"
    testthat::expect_error(prepare_export_product(inputs, "en"),
                           tr("export_download_blocked", "en"), fixed = TRUE)
    review <- protected_copy_review(inputs$download_data, inputs$generalization,
                                    columns = names(inputs$raw_data))
    testthat::expect_identical(review$point_columns, "Station -23.55052 -46.63331")

    inputs <- cross_row_inputs()
    inputs$download_data$occurrenceID[3] <- "ST-10.51234-55.23456"
    testthat::expect_error(prepare_export_product(inputs, "en"),
                           tr("export_download_blocked", "en"), fixed = TRUE)
    # The occurrenceID of a row with the same point as its own stays.
    inputs <- cross_row_inputs()
    inputs$download_data$occurrenceID[4] <- "ST-23.55052-46.63331"
    testthat::expect_identical(prepare_export_product(inputs, "en")$core$occurrenceID[4],
                               "ST-23.55052-46.63331")
})

testthat::test_that("the export stops on projected coordinates in a protected row (ADR-204)", {
    local_panthera_fixture()
    blocked <- c(
        '{"epsg":31983,"easting":333286.919,"northing":7394586.092}',
        '{"type":"Point","coordinates":[333286.9,7394586.1]}',
        "POINT (333286.9 7394586.1)",
        "UTM 23K 333286 7394586"
    )
    for (value in blocked) {
        inputs <- cross_row_inputs()
        inputs$download_data$dynamicProperties <- c(value, "", "", "")
        testthat::expect_error(prepare_export_product(inputs, "en"),
                               tr("export_download_blocked", "en"), fixed = TRUE, info = value)
        review <- protected_copy_review(inputs$download_data, inputs$generalization)
        testthat::expect_identical(review$projected_rows, 1L, info = value)
    }
    # Also in an unmapped column.
    inputs <- cross_row_inputs()
    inputs$raw_data$notas[2] <- "x: 333286, y: 7394586"
    testthat::expect_error(prepare_export_product(inputs, "en"),
                           tr("export_download_blocked", "en"), fixed = TRUE)

    passed <- c("area 250000 m2, plot 120000", "EPSG:31983", "UTM zone 23K",
                '{"epsg":4326,"lat":-23.55052}')
    for (value in passed) {
        inputs <- cross_row_inputs()
        inputs$download_data$dynamicProperties <- c(value, "", value, "")
        testthat::expect_s3_class(prepare_export_product(inputs, "en")$core, "data.frame")
    }
    # A row that is not protected keeps its projected coordinates.
    inputs <- cross_row_inputs()
    inputs$download_data$dynamicProperties <- c("", "", blocked[1], "")
    testthat::expect_identical(prepare_export_product(inputs, "en")$core$dynamicProperties[3], blocked[1])
})

testthat::test_that("the export stops on projected coordinates in a protected row with no point", {
    testthat::local_mocked_bindings(
        sensitive_resolve = function(names, decisions = NULL) {
            data.frame(sensitive = rep(TRUE, length(names)), category = "CR", stringsAsFactors = FALSE)
        }
    )
    inputs <- point_gap_inputs()
    inputs$download_data$dynamicProperties <- c("", '{"easting":333286.9,"northing":7394586.1}')
    testthat::expect_error(prepare_export_product(inputs, "en"),
                           tr("export_download_blocked", "en"), fixed = TRUE)
})
