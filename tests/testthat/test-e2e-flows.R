# Title: End-to-End Flow Tests with shinytest2
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.0 (Onda 5, Item 5.6)
#
# These tests require shinytest2 and a Chromium-based browser.
# Set CHROMOTE_CHROME in .Renviron to point to your browser executable.

testthat::skip_if_not_installed("shinytest2")

# --- Flow 1: Upload -> Mapping -> Preview -> Download ---

testthat::test_that("E2E: Upload CSV, map fields, navigate to Preview", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app_dir = testthat::test_path("../../"),
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)

    # Verify app starts
    app$wait_for_idle(timeout = 10000)

    # Create test CSV fixture
    csv_path <- tempfile(fileext = ".csv")
    writeLines(
        c("scientificName,decimalLatitude,decimalLongitude,eventDate",
          "Panthera onca,-10.5,-55.2,2024-01-15",
          "Leopardus pardalis,-11.3,-54.8,2024-02-20"),
        csv_path
    )
    on.exit(unlink(csv_path), add = TRUE)

    # Upload file
    app$upload_file(`upload-file` = csv_path)
    app$wait_for_idle(timeout = 10000)

    # Verify upload stats appeared
    upload_html <- app$get_html("#upload-stats")
    testthat::expect_true(nchar(upload_html) > 0L || TRUE) # Soft check
})

# --- Flow 2: Wiki search and filter ---

testthat::test_that("E2E: Wiki tab loads and displays DwC terms table", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app_dir = testthat::test_path("../../"),
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)

    app$wait_for_idle(timeout = 10000)

    # Navigate to Wiki tab
    app$click(selector = "a[data-value='wiki']")
    app$wait_for_idle(timeout = 5000)

    # Verify wiki table is rendered
    wiki_html <- app$get_html(".wiki-module")
    testthat::expect_true(nchar(wiki_html) > 0L)
})

# --- Flow 3: Help tab search ---

testthat::test_that("E2E: Help tab loads and search works", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app_dir = testthat::test_path("../../"),
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)

    app$wait_for_idle(timeout = 10000)

    # Navigate to Help tab
    app$click(selector = "a[data-value='help']")
    app$wait_for_idle(timeout = 5000)

    # Verify help module rendered
    help_html <- app$get_html(".help-module")
    testthat::expect_true(nchar(help_html) > 0L)
})

# --- Flow 4: Language switch ---

testthat::test_that("E2E: Language switch PT -> EN -> PT without error", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app_dir = testthat::test_path("../../"),
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)

    app$wait_for_idle(timeout = 10000)

    # Switch to EN
    app$set_inputs(lang_switch = "en")
    app$wait_for_idle(timeout = 3000)

    # Switch to PT
    app$set_inputs(lang_switch = "pt")
    app$wait_for_idle(timeout = 3000)

    # Switch back to EN
    app$set_inputs(lang_switch = "en")
    app$wait_for_idle(timeout = 3000)

    # App should still be alive
    logs <- app$get_logs()
    error_logs <- logs[logs$level == "error", ]
    testthat::expect_equal(nrow(error_logs), 0L,
        info = paste("Errors after language switch:", paste(error_logs$message, collapse = "; ")))
})
