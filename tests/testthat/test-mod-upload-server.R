# Title: Tests for Upload Module Server
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-24
# Version: 1.0

testthat::test_that("mod_upload_server keeps startup stable when get_dwc_terms fails", {
    testthat::local_mocked_bindings(
        get_dwc_terms = function() stop("dwc terms unavailable"),
        .package = "saira"
    )

    testthat::expect_no_error(
        shiny::testServer(
            mod_upload_server,
            args = list(
                lang_r = shiny::reactive("en")
            ),
            {
                returned <- session$getReturned()
                testthat::expect_true(shiny::is.reactive(returned))
                testthat::expect_no_error(session$flushReact())
            }
        )
    )
})
