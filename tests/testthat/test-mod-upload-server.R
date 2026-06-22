# Title: Tests for Upload Module Server
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-24
# Version: 2.0 (Onda 5, Item 5.5 — expanded coverage)

testthat::test_that("mod_upload_server keeps startup stable when get_dwc_terms fails", {
    testthat::local_mocked_bindings(
        get_dwc_terms = function() stop("dwc terms unavailable"),
        .package = "saira"
    )

    # The DwC-terms load failure now surfaces as a warning (graceful
    # degradation); this test asserts startup stays error-free regardless.
    testthat::expect_no_error(
        suppressWarnings(shiny::testServer(
            mod_upload_server,
            args = list(
                lang_r = shiny::reactive("en")
            ),
            {
                returned <- session$getReturned()
                testthat::expect_true(shiny::is.reactive(returned))
                testthat::expect_no_error(session$flushReact())
            }
        ))
    )
})

testthat::test_that("mod_upload_server returns reactive NULL when no file uploaded", {
    shiny::testServer(
        mod_upload_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            returned <- session$getReturned()
            testthat::expect_true(shiny::is.reactive(returned))
        }
    )
})

testthat::test_that("mod_upload_server renders UI outputs in EN", {
    shiny::testServer(
        mod_upload_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            testthat::expect_true(!is.null(output$data_title))
            testthat::expect_true(!is.null(output$dropzone_hint_text))
            testthat::expect_true(!is.null(output$encoding_text))
            testthat::expect_true(!is.null(output$privacy_text))
            testthat::expect_true(!is.null(output$welcome_header))
            testthat::expect_true(!is.null(output$welcome_description))
            # ADR-097: mode tab strip outputs
            testthat::expect_true(!is.null(output$mode_csv_title))
            testthat::expect_true(!is.null(output$mode_camtrap_title))
            testthat::expect_true(!is.null(output$mode_change_text))
        }
    )
})

testthat::test_that("mod_upload_server renders DwC chips by default (CSV mode)", {
    shiny::testServer(
        mod_upload_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            html <- output$dwc_required$html
            testthat::expect_true(grepl("dwc-inline-groups", html))
            testthat::expect_false(grepl("upload-file-list", html))
            testthat::expect_true(grepl("format-requirements", html))
        }
    )
})

testthat::test_that("mod_upload_server renders Camtrap file rows when mode is camtrap", {
    shiny::testServer(
        mod_upload_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(upload_mode = "camtrap")
            session$flushReact()
            html <- output$dwc_required$html
            testthat::expect_true(grepl("upload-file-list", html))
            testthat::expect_false(grepl("dwc-inline-groups", html))
            testthat::expect_true(grepl("datapackage.json", html))
        }
    )
})

testthat::test_that("mod_upload_server rejects CSV upload while in camtrap mode", {
    csv_path <- tempfile(fileext = ".csv")
    on.exit(unlink(csv_path), add = TRUE)
    writeLines(
        c("scientificName,decimalLatitude,decimalLongitude",
          "Panthera onca,-10.5,-55.2"),
        csv_path
    )

    shiny::testServer(
        mod_upload_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(
                upload_mode = "camtrap",
                file = list(
                    name = "wrong.csv",
                    size = file.info(csv_path)$size,
                    type = "text/csv",
                    datapath = csv_path
                )
            )
            session$flushReact()

            returned <- session$getReturned()
            testthat::expect_error(returned(), regexp = "ZIP|invalid")
        }
    )
})

testthat::test_that("mod_upload_server renders UI outputs in PT", {
    shiny::testServer(
        mod_upload_server,
        args = list(
            lang_r = shiny::reactive("pt")
        ),
        {
            session$flushReact()
            testthat::expect_true(!is.null(output$data_title))
            testthat::expect_true(!is.null(output$welcome_header))
            testthat::expect_true(!is.null(output$dwc_required))
        }
    )
})

testthat::test_that("mod_upload_server reads valid CSV with recognizable columns", {
    csv_path <- tempfile(fileext = ".csv")
    on.exit(unlink(csv_path), add = TRUE)
    writeLines(
        c("scientificName,decimalLatitude,decimalLongitude",
          "Panthera onca,-10.5,-55.2",
          "Leopardus pardalis,-11.3,-54.8"),
        csv_path
    )

    shiny::testServer(
        mod_upload_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(file = list(
                name = "test.csv",
                size = file.info(csv_path)$size,
                type = "text/csv",
                datapath = csv_path
            ))
            session$flushReact()

            returned <- session$getReturned()
            df <- returned()
            testthat::expect_true(is.data.frame(df))
            testthat::expect_equal(nrow(df), 2L)
            testthat::expect_true("scientificName" %in% names(df))
        }
    )
})

testthat::test_that("mod_upload_server reads CSV with BOM UTF-8", {
    csv_path <- tempfile(fileext = ".csv")
    on.exit(unlink(csv_path), add = TRUE)
    bom <- as.raw(c(0xEF, 0xBB, 0xBF))
    content <- charToRaw("scientificName,eventDate\nPanthera onca,2024-01-15\n")
    writeBin(c(bom, content), csv_path)

    shiny::testServer(
        mod_upload_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(file = list(
                name = "bom_test.csv",
                size = file.info(csv_path)$size,
                type = "text/csv",
                datapath = csv_path
            ))
            session$flushReact()

            returned <- session$getReturned()
            df <- returned()
            testthat::expect_true(is.data.frame(df))
            testthat::expect_equal(nrow(df), 1L)
        }
    )
})

testthat::test_that("mod_upload_server reads semicolon-delimited CSV", {
    csv_path <- tempfile(fileext = ".csv")
    on.exit(unlink(csv_path), add = TRUE)
    writeLines(
        c("scientificName;decimalLatitude;decimalLongitude",
          "Panthera onca;-10.5;-55.2"),
        csv_path
    )

    shiny::testServer(
        mod_upload_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(file = list(
                name = "semicolon.csv",
                size = file.info(csv_path)$size,
                type = "text/csv",
                datapath = csv_path
            ))
            session$flushReact()

            returned <- session$getReturned()
            df <- returned()
            testthat::expect_true(is.data.frame(df))
            testthat::expect_true("scientificName" %in% names(df))
        }
    )
})

testthat::test_that("mod_upload_server reads tab-delimited TSV", {
    tsv_path <- tempfile(fileext = ".tsv")
    on.exit(unlink(tsv_path), add = TRUE)
    writeLines(
        c("scientificName\tdecimalLatitude\tdecimalLongitude",
          "Panthera onca\t-10.5\t-55.2",
          "Leopardus pardalis\t-11.3\t-54.8"),
        tsv_path
    )

    shiny::testServer(
        mod_upload_server,
        args = list(
            lang_r = shiny::reactive("en")
        ),
        {
            session$setInputs(file = list(
                name = "occurrences.tsv",
                size = file.info(tsv_path)$size,
                type = "text/tab-separated-values",
                datapath = tsv_path
            ))
            session$flushReact()

            returned <- session$getReturned()
            df <- returned()
            testthat::expect_true(is.data.frame(df))
            testthat::expect_equal(nrow(df), 2L)
            testthat::expect_true("scientificName" %in% names(df))
        }
    )
})
