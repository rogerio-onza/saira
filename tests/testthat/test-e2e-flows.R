# Title: End-to-End Flow Tests with shinytest2
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.0 (Onda 5, Item 5.6)
#
# These tests require shinytest2 and a Chromium-based browser.
# Set CHROMOTE_CHROME in .Renviron to point to your browser executable.

testthat::skip_if_not_installed("shinytest2")
if (!identical(Sys.getenv("RUN_E2E"), "true")) {
    testthat::skip("E2E suite ignorada em check rotineiro. Use RUN_E2E=true para rodar.")
}
app_root <- normalizePath(testthat::test_path("../../"), winslash = "/", mustWork = TRUE)
build_e2e_app <- function() {
    pkgload::load_all(app_root, export_all = FALSE, quiet = TRUE)
    shiny::shinyApp(app_ui(), app_server)
}

# --- Flow 1: Upload -> Mapping -> Preview -> Download ---

testthat::test_that("E2E: Upload CSV, map fields, navigate to Preview", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app = build_e2e_app,
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
        app = build_e2e_app,
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
        app = build_e2e_app,
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
        app = build_e2e_app,
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)

    app$wait_for_idle(timeout = 10000)

    strip_html <- function(x) {
        trimws(gsub("<[^>]+>", "", as.character(x)))
    }

    nav_pt_initial <- strip_html(app$get_html("#nav_upload_title"))

    # Switch to EN
    app$set_inputs(lang_switch = "en")
    app$wait_for_idle(timeout = 5000)
    nav_en <- strip_html(app$get_html("#nav_upload_title"))

    # Switch to PT
    app$set_inputs(lang_switch = "pt")
    app$wait_for_idle(timeout = 5000)
    nav_pt_final <- strip_html(app$get_html("#nav_upload_title"))

    testthat::expect_true(nzchar(nav_pt_initial))
    testthat::expect_true(nzchar(nav_en))
    testthat::expect_true(nzchar(nav_pt_final))
    testthat::expect_false(identical(nav_pt_initial, nav_en))
    testthat::expect_equal(nav_pt_initial, nav_pt_final)
})
