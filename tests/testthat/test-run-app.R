testthat::test_that("run_app takes Shiny options without a clash with its defaults", {
    withr::local_options(shiny.maxRequestSize = NULL, shiny.error = NULL)
    app <- run_app(options = list(port = 4000))
    testthat::expect_identical(app$options$port, 4000)
    testthat::expect_true("launch.browser" %in% names(app$options))

    app <- run_app(options = list(launch.browser = FALSE))
    testthat::expect_false(app$options$launch.browser)
})
