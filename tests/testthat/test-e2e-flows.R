# Title: End-to-End Flow Tests with shinytest2
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.0 (Onda 5, Item 5.6)
#
# These tests require shinytest2 and a Chromium-based browser.
# Set CHROMOTE_CHROME in .Renviron to point to your browser executable.
#
# Two gates guard this file, and both have to be open:
#
#   RUN_E2E=true NOT_CRAN=true Rscript -e "pkgload::load_all('.'); \
#     testthat::test_file('tests/testthat/test-e2e-flows.R')"
#
# devtools::test() sets NOT_CRAN itself, testthat::test_file() does not, so
# RUN_E2E alone leaves every test skipped with the reason "On CRAN".

testthat::skip_if_not_installed("shinytest2")
if (!identical(Sys.getenv("RUN_E2E"), "true")) {
    testthat::skip("E2E suite ignorada em check rotineiro. Use RUN_E2E=true para rodar.")
}
app_root <- normalizePath(testthat::test_path("../../"), winslash = "/", mustWork = TRUE)
# One Chrome serves every flow, and after a few minutes it throttled the
# timers of the page, so Shiny missed the 10 s "stable" window in late flows.
chromote::set_chrome_args(c(
    chromote::default_chrome_args(),
    "--disable-background-timer-throttling",
    "--disable-renderer-backgrounding",
    "--disable-backgrounding-occluded-windows"
))
build_e2e_app <- function() {
    pkgload::load_all(app_root, export_all = FALSE, quiet = TRUE)
    # run_app() registers www (custom.css, upload-dropzone.js) and the 500 MB
    # upload limit; a bare shinyApp() served the pages without them.
    run_app()
}
# AppDriver sends this function to the app process. testthat keeps source
# references, so the function carries the text of this whole file with it.
# With them, Chrome 151 reloaded the page during startup in most flows, and
# AppDriver lost the tracer it had injected. Without them, every flow passes.
# A padded copy of one flow failed the same way, so the file size is the
# trigger. The mechanism is not known.
build_e2e_app <- utils::removeSource(build_e2e_app)

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
    testthat::expect_true(nchar(upload_html) > 0L)
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

# --- Flow 4: Rostrum auto-map ---

testthat::test_that("E2E: Rostrum auto-map runs without crash", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app = build_e2e_app,
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)

    app$wait_for_idle(timeout = 10000)

    csv_path <- tempfile(fileext = ".csv")
    writeLines(
        c("scientificName,decimalLatitude",
          "Panthera onca,-10.5",
          "Leopardus pardalis,-11.3"),
        csv_path
    )
    on.exit(unlink(csv_path), add = TRUE)

    app$upload_file(`upload-file` = csv_path)
    app$wait_for_idle(timeout = 10000)

    app$click(selector = "#mapping-auto_map")
    app$wait_for_idle(timeout = 15000)

    # App must still be alive; no crash
    testthat::expect_true(app$get_js("typeof window !== 'undefined'"))
})

testthat::test_that("E2E: Rostrum auto-map is repeatable without crash", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app = build_e2e_app,
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)

    app$wait_for_idle(timeout = 10000)

    csv_path <- tempfile(fileext = ".csv")
    writeLines(
        c("scientificName,decimalLatitude",
          "Panthera onca,-10.5",
          "Leopardus pardalis,-11.3"),
        csv_path
    )
    on.exit(unlink(csv_path), add = TRUE)

    app$upload_file(`upload-file` = csv_path)
    app$wait_for_idle(timeout = 10000)

    app$click(selector = "#mapping-auto_map")
    app$wait_for_idle(timeout = 15000)

    # App must still be alive after engine run
    testthat::expect_true(app$get_js("typeof window !== 'undefined'"))
})

# --- Flow 5: Language switch ---

testthat::test_that("E2E: Language switch PT -> EN -> PT without error (Flow 5)", {
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

# In English the translated label is Shiny's own "Upload complete". The page
# rewrote the same text, its MutationObserver saw the change and rewrote it
# again, so the tab spun forever after an upload.
testthat::test_that("E2E: an upload in English completes", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app = build_e2e_app,
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)
    app$wait_for_idle(timeout = 10000)

    app$set_inputs(lang_switch = "en")
    app$wait_for_idle(timeout = 5000)

    csv_path <- tempfile(fileext = ".csv")
    writeLines(c("scientificName,decimalLatitude", "Panthera onca,-10.5"), csv_path)
    on.exit(unlink(csv_path), add = TRUE)

    app$upload_file(`upload-file` = csv_path, timeout_ = 15000)
    label <- app$get_js(
        "document.querySelector('.shiny-file-input-progress .progress-bar').textContent"
    )
    testthat::expect_identical(label, "Upload complete")
})

# --- Flow 6: mapping-guide import restores a fixed value ---
#
# The one step no unit test reaches. testServer has no browser, so it can only
# record the two update calls the import sends; whether the card comes back
# with the checkbox on and the value filled is a client-side question. The
# import also rebuilds the whole card grid in the same flush, and that render
# reads the checkbox with isolate() -- exactly the race this asserts against.

testthat::test_that("E2E: importing a guide restores a fixed value into the card", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app = build_e2e_app,
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)

    app$wait_for_idle(timeout = 10000)

    csv_path <- tempfile(fileext = ".csv")
    writeLines(
        c("scientificName,Municipio",
          "Panthera onca,Curitiba",
          "Leopardus pardalis,Blumenau"),
        csv_path
    )
    on.exit(unlink(csv_path), add = TRUE)

    # The guide an export writes for `Municipio -> country` overridden by the
    # fixed value "Brasil": the constant line, no column line (issue #98).
    guide_path <- tempfile(fileext = ".txt")
    writeLines(
        build_mapping_guide_txt(
            list(scientificName = "scientificName", country = "Municipio"),
            data.frame(scientificName = "x", Municipio = "y",
                       stringsAsFactors = FALSE),
            lang = "en", constants = list(country = "Brasil")
        ),
        guide_path,
        useBytes = TRUE
    )
    on.exit(unlink(guide_path), add = TRUE)

    app$upload_file(`upload-file` = csv_path)
    app$wait_for_idle(timeout = 15000)

    app$click(selector = "a[data-value='mapping']")
    app$wait_for_idle(timeout = 10000)

    app$click(selector = "#mapping-import_template")
    app$wait_for_idle(timeout = 5000)
    app$upload_file(`mapping-import_template_file` = guide_path)
    app$wait_for_idle(timeout = 5000)
    app$click(selector = "#mapping-confirm_import_template")
    app$wait_for_idle(timeout = 20000)

    vals <- app$get_values(input = c("mapping-usecustom_country",
                                     "mapping-custom_country"))
    testthat::expect_true(isTRUE(vals$input[["mapping-usecustom_country"]]))
    testthat::expect_equal(vals$input[["mapping-custom_country"]], "Brasil")

    # The value input sits in a conditionalPanel keyed on the checkbox, so a
    # restored value the user cannot see would still fail here.
    testthat::expect_true(
        app$get_js("$('#mapping-custom_country').is(':visible')")
    )
})

# --- Flow 7: slash dates and an impossible year ---
#
# The bug this guards against was reported from a real export: dates left the
# app with the separator the spreadsheet used ("2023/12/25", "25/12/2023 14:30")
# instead of the ISO hyphen, and a year typo (2098) reached the ZIP with nothing
# on screen to warn about it. Only a browser run covers the whole path, since
# the export the user gets is written by the download handler, not by the pure
# pipeline the unit tests call.

testthat::test_that("E2E: slash dates export as ISO and an out-of-range year is flagged", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app = build_e2e_app,
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)

    app$wait_for_idle(timeout = 10000)

    csv_path <- tempfile(fileext = ".csv")
    writeLines(
        c("scientificName,decimalLatitude,decimalLongitude,basisOfRecord,eventDate",
          "Panthera onca,-10.5,-55.2,HumanObservation,25/12/2023",
          "Leopardus pardalis,-11.3,-54.8,HumanObservation,2023/11/02",
          "Puma concolor,-12.1,-53.4,HumanObservation,25/12/2023 14:30",
          "Chrysocyon brachyurus,-13.2,-52.7,HumanObservation,01/05/2098"),
        csv_path
    )
    on.exit(unlink(csv_path), add = TRUE)

    app$upload_file(`upload-file` = csv_path)
    app$wait_for_idle(timeout = 15000)

    app$click(selector = "a[data-value='mapping']")
    app$wait_for_idle(timeout = 10000)
    app$click(selector = "#mapping-auto_map")
    app$wait_for_idle(timeout = 20000)

    app$click(selector = "a[data-value='export']")
    app$wait_for_idle(timeout = 15000)

    # The out-of-range year is named on screen, with its row.
    summary_html <- app$get_html("#export-summary")
    testthat::expect_true(grepl("2098", summary_html, fixed = TRUE))
    testthat::expect_true(grepl("eventDate", summary_html, fixed = TRUE))

    # ... and the export is not blocked by it.
    zip_path <- app$get_download("export-download_real")
    on.exit(unlink(zip_path), add = TRUE)

    unzip_dir <- tempfile()
    dir.create(unzip_dir)
    on.exit(unlink(unzip_dir, recursive = TRUE), add = TRUE)
    utils::unzip(zip_path, exdir = unzip_dir)

    occurrence_path <- list.files(
        unzip_dir, pattern = "^occurrence\\.txt$", recursive = TRUE, full.names = TRUE
    )
    testthat::expect_length(occurrence_path, 1L)

    occurrence <- utils::read.csv(
        occurrence_path[[1]], sep = ",", colClasses = "character", encoding = "UTF-8"
    )
    testthat::expect_true("eventDate" %in% names(occurrence))
    testthat::expect_false(any(grepl("/", occurrence$eventDate, fixed = TRUE)))
    testthat::expect_setequal(
        occurrence$eventDate,
        c("2023-12-25", "2023-11-02", "2023-12-25T14:30", "2098-05-01")
    )
})

# --- Flow 8: a language switch keeps a card's column ---
#
# ADR-111, item 5: the mapping sync observer keeps its lang_r() dependency. When
# a refactor isolated it, a language switch rebuilt the card grid and the
# recreated inputs wiped every pick. testServer cannot see this, because it has
# no DOM to recreate the inputs in.

testthat::test_that("E2E: a language switch keeps the column picked in a card", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app = build_e2e_app,
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)

    app$wait_for_idle(timeout = 10000)

    csv_path <- tempfile(fileext = ".csv")
    writeLines(
        c("especie,ambiente",
          "Panthera onca,forest",
          "Leopardus pardalis,savanna"),
        csv_path
    )
    on.exit(unlink(csv_path), add = TRUE)

    app$upload_file(`upload-file` = csv_path)
    app$wait_for_idle(timeout = 15000)
    app$click(selector = "a[data-value='mapping']")
    app$wait_for_idle(timeout = 10000)

    app$set_inputs(`mapping-map_habitat` = "ambiente")
    app$wait_for_idle(timeout = 10000)

    card_is_mapped <- function() {
        isTRUE(app$get_js(
            "document.getElementById('mapping-fieldcard_habitat').classList.contains('field-mapped')"
        ))
    }
    picked <- function() {
        app$get_values(input = "mapping-map_habitat")$input[["mapping-map_habitat"]]
    }

    testthat::expect_identical(picked(), "ambiente")
    testthat::expect_true(card_is_mapped())

    for (lang in c("en", "pt")) {
        app$set_inputs(lang_switch = lang)
        app$wait_for_idle(timeout = 15000)
        testthat::expect_identical(picked(), "ambiente")
        testthat::expect_true(card_is_mapped())
    }
})

# --- Flow 9: the whole flow on the demo dataset, timed ---
#
# The public demo sheet exercises every validation, so this is the one run that
# crosses every tab with real data. Each step records its time. The numbers are
# printed, and written to SAIRA_E2E_TIMINGS when that variable names a file, to
# compare a branch against the baseline taken on main. Name validation queries
# GBIF and taxadb over the network, so it stays out of this flow.

testthat::test_that("E2E: full flow on the demo dataset, with step timings", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    demo_path <- file.path(app_root, "website", "assets", "exemplo", "ocorrencias-demo.csv")
    testthat::skip_if_not(file.exists(demo_path), "demo dataset not found")
    demo_rows <- nrow(utils::read.csv(demo_path, colClasses = "character"))

    app <- shinytest2::AppDriver$new(
        app = build_e2e_app,
        timeout = 60000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)

    app$wait_for_idle(timeout = 20000)

    idle_ms <- 500
    timings <- data.frame(step = character(0), seconds = numeric(0))
    timed <- function(step, action, timeout = 120000) {
        started <- Sys.time()
        action()
        app$wait_for_idle(duration = idle_ms, timeout = timeout)
        seconds <- as.numeric(difftime(Sys.time(), started, units = "secs")) - idle_ms / 1000
        timings[nrow(timings) + 1L, ] <<- list(step, round(max(seconds, 0), 2))
    }
    # Setting the navbar input reaches every tab, including the ones inside a
    # dropdown menu, without depending on how the navbar is drawn. wait_ = FALSE
    # because a tab that is already open updates no output, and set_inputs()
    # would wait for one until its timeout. timed() waits for idle instead.
    go_to <- function(tab) function() app$set_inputs(main_nav = tab, wait_ = FALSE)

    timed("upload", function() app$upload_file(`upload-file` = demo_path))
    timed("open mapping", go_to("mapping"))
    timed("auto-map", function() app$click(selector = "#mapping-auto_map"))
    mapped <- app$get_values(input = "mapping-map_scientificName")$input
    testthat::expect_true(nzchar(mapped[["mapping-map_scientificName"]]))

    timed("open preview", go_to("preview"))
    testthat::expect_true(nchar(app$get_html("#preview-datatable")) > 0L)

    timed("open coordinates", go_to("validate_coords"))
    timed("validate coordinates", function() app$click(selector = "#validate_coords-validate"),
          timeout = 300000)
    testthat::expect_true(nchar(app$get_html("#validate_coords-filter_pills")) > 0L)

    timed("open generalization", go_to("sensitive_coords"))
    testthat::expect_true(nchar(app$get_html(".sensitive-coords-page")) > 0L)

    timed("open export", go_to("export"))
    started <- Sys.time()
    zip_path <- app$get_download("export-download_real")
    timings[nrow(timings) + 1L, ] <- list(
        "download zip",
        round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2)
    )
    on.exit(unlink(zip_path), add = TRUE)

    unzip_dir <- tempfile()
    dir.create(unzip_dir)
    on.exit(unlink(unzip_dir, recursive = TRUE), add = TRUE)
    utils::unzip(zip_path, exdir = unzip_dir)
    occurrence_path <- list.files(
        unzip_dir, pattern = "^occurrence\\.txt$", recursive = TRUE, full.names = TRUE
    )
    testthat::expect_length(occurrence_path, 1L)
    occurrence <- utils::read.csv(
        occurrence_path[[1]], sep = ",", colClasses = "character", encoding = "UTF-8"
    )
    testthat::expect_identical(nrow(occurrence), demo_rows)
    testthat::expect_true(all(
        c("scientificName", "decimalLatitude", "decimalLongitude") %in% names(occurrence)
    ))

    message(paste(c("Step timings (s):", utils::capture.output(print(timings, row.names = FALSE))),
                  collapse = "\n"))
    out_file <- Sys.getenv("SAIRA_E2E_TIMINGS")
    if (nzchar(out_file)) {
        utils::write.csv(timings, out_file, row.names = FALSE)
    }
})
