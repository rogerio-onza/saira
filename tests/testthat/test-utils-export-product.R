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
