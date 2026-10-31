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
# The function also carries its environment chain, and its parent holds the
# package functions that helper-source-utils.R copies, with their sources.
# After ADR-160 the same startup failure came back in every flow. Only
# app_root goes with it now.
environment(build_e2e_app) <- list2env(list(app_root = app_root), parent = globalenv())
# Poll from R. wait_for_js() polls with timers inside the page, and late in a
# long run Chrome stopped them: a button that was already enabled timed out.
wait_until_js <- function(app, script, timeout = 30000) {
    deadline <- Sys.time() + timeout / 1000
    repeat {
        if (isTRUE(app$get_js(script))) return(invisible(TRUE))
        if (Sys.time() > deadline) stop("Timed out waiting for: ", script, call. = FALSE)
        Sys.sleep(0.25)
    }
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
    testthat::expect_identical(app$get_js("document.documentElement.lang"), "pt-BR")

    # Switch to EN
    app$set_inputs(lang_switch = "en")
    app$wait_for_idle(timeout = 5000)
    nav_en <- strip_html(app$get_html("#nav_upload_title"))
    testthat::expect_identical(app$get_js("document.documentElement.lang"), "en")

    # Switch to PT
    app$set_inputs(lang_switch = "pt")
    app$wait_for_idle(timeout = 5000)
    nav_pt_final <- strip_html(app$get_html("#nav_upload_title"))
    testthat::expect_identical(app$get_js("document.documentElement.lang"), "pt-BR")

    testthat::expect_true(nzchar(nav_pt_initial))
    testthat::expect_true(nzchar(nav_en))
    testthat::expect_true(nzchar(nav_pt_final))
    testthat::expect_false(identical(nav_pt_initial, nav_en))
    testthat::expect_equal(nav_pt_initial, nav_pt_final)
})

# ADR-133: Spanish is the third UI language. The test visits every tab in
# Spanish, because a key without "es" text only shows on the tab that uses it.
testthat::test_that("E2E: Spanish UI renders every tab and sets the page language", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app = build_e2e_app,
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)
    app$wait_for_idle(timeout = 10000)

    app$set_inputs(lang_switch = "es")
    app$wait_for_idle(timeout = 10000)

    testthat::expect_identical(app$get_js("document.documentElement.lang"), "es")
    nav_es <- trimws(gsub("<[^>]+>", "", as.character(app$get_html("#nav_upload_title"))))
    testthat::expect_identical(nav_es, tr("nav_home", "es"))

    tabs <- c("upload", "mapping", "preview", "validate_names", "validate_coords",
              "sensitive_coords", "export", "wiki", "help")
    for (tab in tabs) {
        app$click(selector = sprintf("a[data-value='%s']", tab))
        app$wait_for_idle(timeout = 10000)
        testthat::expect_identical(
            app$get_js("document.querySelectorAll('.shiny-output-error:not(.shiny-output-error-validation)').length"),
            0L,
            info = tab
        )
    }
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
    # license is required since #143, and the sheet has no license column.
    app$set_inputs(`mapping-custom_license` = "CC BY 4.0")

    app$click(selector = "a[data-value='export']")
    app$wait_for_idle(timeout = 15000)

    # The out-of-range year is named on screen, with its row.
    summary_html <- app$get_html("#export-summary")
    testthat::expect_true(grepl("2098", summary_html, fixed = TRUE))
    testthat::expect_true(grepl("eventDate", summary_html, fixed = TRUE))

    # ... and the export is not blocked by it.
    # A user can click only an enabled button. The gate can still be catching
    # up with the last mapping change when the tab opens.
    wait_until_js(
        app,
        "(function () { var b = document.getElementById('export-download_trigger'); return !!b && !b.disabled; })()"
    )
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

# --- Flow 7b: an exact copy left out in the Preview stays out of the zip ---
#
# The Preview only stores the choice. The rows leave in the download handler,
# after the unmapped columns join by row, so only a browser run covers it.

testthat::test_that("E2E: an exact copy left out in the Preview stays out of the zip", {
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
        c("occurrenceID,scientificName,decimalLatitude,decimalLongitude,basisOfRecord,eventDate",
          "r1,Panthera onca,-10.5,-55.2,HumanObservation,2023-12-25",
          "r2,Leopardus pardalis,-11.3,-54.8,HumanObservation,2023-11-02",
          "r1,Panthera onca,-10.5,-55.2,HumanObservation,2023-12-25",
          "r3,Puma concolor,-12.1,-53.4,HumanObservation,2023-10-01"),
        csv_path
    )
    on.exit(unlink(csv_path), add = TRUE)

    app$upload_file(`upload-file` = csv_path)
    app$wait_for_idle(timeout = 15000)
    app$click(selector = "a[data-value='mapping']")
    app$wait_for_idle(timeout = 10000)
    app$click(selector = "#mapping-auto_map")
    app$wait_for_idle(timeout = 20000)
    app$set_inputs(`mapping-custom_license` = "CC BY 4.0")

    app$click(selector = "a[data-value='preview']")
    app$wait_for_idle(timeout = 15000)
    app$set_inputs(`preview-mode` = "problems")
    wait_until_js(app, "!!document.getElementById('preview-fix_filter_copy')")
    app$click(selector = "#preview-fix_filter_copy")
    wait_until_js(app, "!!document.querySelector(\".preview-copy-set[data-row='all']\")")
    testthat::expect_match(app$get_html("#preview-copies_section"), "linha 1", fixed = TRUE)
    app$click(selector = ".preview-copy-set[data-row='all']")
    wait_until_js(app, "!!document.querySelector(\".preview-copy-set.is-out[data-row='3']\")")

    app$click(selector = "a[data-value='export']")
    app$wait_for_idle(timeout = 15000)
    testthat::expect_match(app$get_html("#export-summary"), "1 cópia(s) exata(s)", fixed = TRUE)

    wait_until_js(
        app,
        "(function () { var b = document.getElementById('export-download_trigger'); return !!b && !b.disabled; })()"
    )
    zip_path <- app$get_download("export-download_real")
    on.exit(unlink(zip_path), add = TRUE)
    unzip_dir <- tempfile()
    dir.create(unzip_dir)
    on.exit(unlink(unzip_dir, recursive = TRUE), add = TRUE)
    utils::unzip(zip_path, exdir = unzip_dir)
    occurrence <- utils::read.csv(
        file.path(unzip_dir, "occurrence.txt"), sep = ",", colClasses = "character", encoding = "UTF-8"
    )
    testthat::expect_identical(occurrence$occurrenceID, c("r1", "r2", "r3"))
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

testthat::test_that("E2E: the Mapping filter runs in the browser and Next pending shows a hidden card", {
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
        c("scientificName,decimalLatitude,decimalLongitude,eventDate",
          "Panthera onca,-10.5,-55.2,2024-01-15",
          "Leopardus pardalis,-11.3,-54.8,2024-02-20"),
        csv_path
    )
    on.exit(unlink(csv_path), add = TRUE)

    app$upload_file(`upload-file` = csv_path)
    app$wait_for_idle(timeout = 15000)
    app$click(selector = "a[data-value='mapping']")
    app$wait_for_idle(timeout = 15000)
    # A notification that closes also starts a check of hidden outputs.
    app$wait_for_js("document.querySelector('.shiny-notification') === null",
                    timeout = 20000)

    # A card that moves in the DOM is styled and laid out from zero, and its
    # tooltips connect again. The filter only toggles classes.
    app$run_js("window.__cardMoves = 0;
      new MutationObserver(function (records) {
        records.forEach(function (r) {
          Array.prototype.forEach.call(r.addedNodes, function (n) {
            if (n.classList && n.classList.contains('field-card')) { window.__cardMoves++; }
          });
        });
      }).observe(document.getElementById('mapping-mapping_ui'), { childList: true, subtree: true });")
    # Shiny 1.14 reports output visibility per element, with no check of all
    # outputs that blocks the page (0 long tasks measured on 2026-10-21), so
    # only a grid render is counted.
    app$run_js("window.__gridRenders = 0;
      $(document).on('shiny:value', function (e) {
        if (e.target.id === 'mapping-mapping_ui') { window.__gridRenders++; }
      });")
    shown <- function() {
        app$get_js("Array.prototype.filter.call(
          document.querySelectorAll('#mapping-mapping_ui .field-card'),
          function (card) { return card.getClientRects().length > 0; }).length")
    }
    count <- function(mode) {
        as.integer(app$get_text(paste0("#mapping-filter_n_", mode)))
    }
    pick <- function(mode) {
        # The server does nothing on a switch (ADR-157), so no output changes.
        app$set_inputs(`mapping-mapped_filter` = mode, wait_ = FALSE)
        app$wait_for_idle(timeout = 10000)
    }

    # The count on each option is the number of cards the option shows.
    for (mode in c("all", "mapped", "pending", "relevant", "all", "relevant")) {
        pick(mode)
        testthat::expect_identical(shown(), count(mode), label = mode)
    }
    testthat::expect_identical(app$get_js("window.__cardMoves"), 0L)
    testthat::expect_identical(app$get_js("window.__gridRenders"), 0L)

    # Mapped hides the missing required terms. Next pending goes to one of
    # them, so the filter changes to Relevant, which hides no card.
    pick("mapped")
    testthat::expect_gt(app$get_js("document.querySelectorAll('#mapping-mapping_ui .field-card[hidden]').length"), 0L)
    app$click("mapping-next_pending")
    app$wait_for_idle(timeout = 10000)
    testthat::expect_identical(app$get_value(input = "mapping-mapped_filter"), "relevant")
    testthat::expect_identical(app$get_js("document.querySelectorAll('#mapping-mapping_ui .field-card[hidden]').length"), 0L)

    # A card patch from the server keeps the picked filter on screen: a
    # pending card that gets a fixed value leaves Pending with no switch.
    hidden <- function(term) {
        app$get_js(sprintf("document.getElementById('mapping-fieldcard_%s').hidden", term))
    }
    pick("pending")
    testthat::expect_false(hidden("basisOfRecord"))
    app$set_inputs(`mapping-usecustom_basisOfRecord` = TRUE)
    app$set_inputs(`mapping-custom_basisOfRecord` = "HumanObservation")
    wait_until_js(app, "document.getElementById('mapping-fieldcard_basisOfRecord').hidden === true")
    app$set_inputs(`mapping-usecustom_basisOfRecord` = FALSE)
    wait_until_js(app, "document.getElementById('mapping-fieldcard_basisOfRecord').hidden === false")
    testthat::expect_identical(app$get_js("window.__gridRenders"), 0L)
})

testthat::test_that("E2E: the names report panel keeps its column in light and dark themes", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app = build_e2e_app,
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)

    app$wait_for_idle(timeout = 10000)
    app$click(selector = "a[data-value='validate_names']")
    wait_until_js(app, "!!document.querySelector('.vn-report-panel') && !!document.querySelector('.vn-stream-panel')")

    # test-css-guardrails.R finds a rule in the bundle, not the rule that wins
    # the cascade: a later `.vn-report-panel { width: 0 }` passed it. Shiny
    # 1.14 also makes each uiOutput a pass-through box, so a static page of
    # custom.css does not show the real layout.
    measure <- function(width, theme = "light") {
        app$set_window_size(width = width, height = 900)
        app$run_js(sprintf("document.documentElement.setAttribute('data-bs-theme', '%s');", theme))
        app$get_js("(function () {
          var r = document.querySelector('.vn-report-panel').getBoundingClientRect();
          var s = document.querySelector('.vn-stream-panel').getBoundingClientRect();
          return { report_left: r.left, report_top: r.top, report_width: r.width,
                   stream_right: s.right, stream_top: s.top, stream_width: s.width };
        })()")
    }
    # ADR-132: clamp(520px, 31vw, 640px) at the right of the stream panel.
    problems <- function(m) {
        as.character(c(
            if (m$report_width < 519.5 || m$report_width > 640.5) sprintf("report width %.0f px", m$report_width),
            if (m$report_left < m$stream_right) "report panel is not at the right of the stream panel",
            if (abs(m$report_top - m$stream_top) > 1) "report and stream panels are not on one row",
            if (m$stream_width < m$report_width) sprintf("stream width %.0f px", m$stream_width)
        ))
    }

    for (theme in c("light", "dark")) {
        for (width in c(1280, 1440, 1920)) {
            testthat::expect_identical(problems(measure(width, theme)), character(0), info = paste(theme, width))
        }
        testthat::expect_equal(measure(1920, theme)$report_width, 0.31 * 1920, tolerance = 1e-3)
        # Below 992 px the panels stack and the report panel takes the full width.
        m <- measure(800, theme)
        testthat::expect_gt(m$report_top, m$stream_top)
        testthat::expect_equal(m$report_width, m$stream_width, tolerance = 0.01)
    }

    # The same check fails on a later rule that collapses the panel.
    app$run_js("document.head.insertAdjacentHTML('beforeend',
      '<style>.vn-report-panel { width: 0; flex: 0 0 0; }</style>');")
    testthat::expect_match(problems(measure(1440)), "^report width", all = FALSE)
})

testthat::test_that("E2E: Table | Problems in the Preview switches in the browser", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app = build_e2e_app,
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)

    app$wait_for_idle(timeout = 10000)

    # A date that does not exist is a problem, so the tab opens in Problems.
    # A blank eventDate is not one: the Export does not block it (B24).
    csv_path <- tempfile(fileext = ".csv")
    writeLines(
        c("scientificName,decimalLatitude,decimalLongitude,eventDate",
          "Panthera onca,-10.5,-55.2,2024-01-15",
          "Leopardus pardalis,-11.3,-54.8,2024-02-30"),
        csv_path
    )
    on.exit(unlink(csv_path), add = TRUE)

    app$upload_file(`upload-file` = csv_path)
    app$wait_for_idle(timeout = 15000)
    app$click(selector = "a[data-value='preview']")
    app$wait_for_idle(timeout = 15000)
    app$wait_for_js("document.querySelector('.shiny-notification') === null",
                    timeout = 20000)
    testthat::expect_identical(app$get_value(input = "preview-mode"), "problems")

    # The content of both modes is there before a switch (ADR-158), so a
    # switch renders no output.
    app$run_js("window.__previewRenders = 0;
      $(document).on('shiny:value', function (e) {
        if (/^preview-/.test(e.target.id)) { window.__previewRenders++; }
      });")
    shows <- function(part) {
        app$get_js(paste0("document.querySelector('#preview-mode_body [data-mode=\"", part,
                          "\"]').getBoundingClientRect().height > 0"))
    }
    rows <- function(table) {
        app$get_js(paste0("document.querySelectorAll('#preview-", table,
                          " .dataTables_scrollBody tbody tr').length"))
    }
    for (mode in c("table", "problems", "table")) {
        app$set_inputs(`preview-mode` = mode, wait_ = FALSE)
        app$wait_for_idle(timeout = 10000)
        other <- setdiff(c("table", "problems"), mode)
        testthat::expect_true(shows(mode), label = mode)
        testthat::expect_false(shows(other), label = other)
    }
    testthat::expect_gt(rows("datatable"), 0L)
    testthat::expect_gt(rows("rows_table"), 0L)
    testthat::expect_identical(app$get_js("window.__previewRenders"), 0L)
})

# --- Flow 10: re-upload and Reset clear the Mapping ---
#
# Both bump the downstream reset signal. testServer sees the server state, but
# only a browser shows whether the recreated cards come back empty, or whether
# a select keeps a column the new sheet does not have.

testthat::test_that("E2E: a re-upload and a Reset clear the picked columns", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app = build_e2e_app,
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)
    app$wait_for_idle(timeout = 10000)

    first_path <- tempfile(fileext = ".csv")
    writeLines(c("especie,ambiente", "Panthera onca,forest"), first_path)
    second_path <- tempfile(fileext = ".csv")
    writeLines(c("nome,local", "Puma concolor,Curitiba"), second_path)
    on.exit(unlink(c(first_path, second_path)), add = TRUE)

    picked <- function() {
        app$get_values(input = "mapping-map_habitat")$input[["mapping-map_habitat"]] %||% ""
    }
    card_is_mapped <- function() {
        isTRUE(app$get_js(
            "document.getElementById('mapping-fieldcard_habitat').classList.contains('field-mapped')"
        ))
    }
    pick_habitat <- function() {
        app$set_inputs(`mapping-map_habitat` = "ambiente")
        app$wait_for_idle(timeout = 10000)
        testthat::expect_identical(picked(), "ambiente")
        testthat::expect_true(card_is_mapped())
    }

    app$upload_file(`upload-file` = first_path)
    app$wait_for_idle(timeout = 15000)
    app$click(selector = "a[data-value='mapping']")
    app$wait_for_idle(timeout = 10000)
    pick_habitat()

    app$click(selector = "#mapping-reset_mapping")
    app$wait_for_idle(timeout = 5000)
    app$click(selector = "#mapping-confirm_reset")
    app$wait_for_idle(timeout = 15000)
    testthat::expect_identical(picked(), "")
    testthat::expect_false(card_is_mapped())

    pick_habitat()
    app$upload_file(`upload-file` = second_path)
    app$wait_for_idle(timeout = 15000)
    app$click(selector = "a[data-value='mapping']")
    app$wait_for_idle(timeout = 10000)
    testthat::expect_identical(picked(), "")
    testthat::expect_false(card_is_mapped())
    # The select offers the columns of the new sheet only.
    testthat::expect_identical(
        app$get_js("$('#mapping-map_habitat option[value=\"ambiente\"]').length"), 0L
    )
})

# --- Flow 11: a card after a guide import ---
#
# A guide restore sends updates the client echoes one flush later (ADR-104).
# The card has to show the restored column even when the user cleared it first
# (#205), and a pick made after the import has to stay.

testthat::test_that("E2E: a guide fills a cleared card, and a later pick stays", {
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
        c("especie,latitude,lat_gps",
          "Panthera onca,-10.1,-10.2",
          "Leopardus pardalis,-11.1,-11.2"),
        csv_path
    )
    guide_path <- tempfile(fileext = ".txt")
    writeLines(
        build_mapping_guide_txt(
            list(scientificName = "especie", decimalLatitude = "latitude"),
            data.frame(especie = "x", latitude = "y", stringsAsFactors = FALSE),
            lang = "en"
        ),
        guide_path,
        useBytes = TRUE
    )
    on.exit(unlink(c(csv_path, guide_path)), add = TRUE)

    picked <- function() {
        app$get_values(input = "mapping-map_decimalLatitude")$input[["mapping-map_decimalLatitude"]] %||% ""
    }
    # The items the select draws, which is what the user sees on the card. The
    # select takes several columns, so this is a vector.
    shown <- function() {
        unlist(app$get_js(
            "$('#mapping-map_decimalLatitude').parent().find('.selectize-control .item')
               .map(function () { return $(this).attr('data-value'); }).get()"
        ))
    }

    app$upload_file(`upload-file` = csv_path)
    app$wait_for_idle(timeout = 15000)
    app$click(selector = "a[data-value='mapping']")
    app$wait_for_idle(timeout = 10000)

    # Clear the card as a user does, from the select itself.
    app$run_js("$('#mapping-map_decimalLatitude')[0].selectize.clear()")
    app$wait_for_idle(timeout = 10000)
    testthat::expect_identical(picked(), "")

    app$click(selector = "#mapping-import_template")
    app$wait_for_idle(timeout = 5000)
    app$upload_file(`mapping-import_template_file` = guide_path)
    app$wait_for_idle(timeout = 5000)
    app$click(selector = "#mapping-confirm_import_template")
    app$wait_for_idle(timeout = 20000)
    testthat::expect_identical(picked(), "latitude")
    testthat::expect_identical(shown(), "latitude")

    app$set_inputs(`mapping-map_decimalLatitude` = "lat_gps")
    app$wait_for_idle(timeout = 10000)
    testthat::expect_identical(picked(), "lat_gps")
    testthat::expect_identical(shown(), "lat_gps")
})

# --- Flow 12: the public package and the private file ---
#
# ADR-163: a generalized record leaves the zip with a coarse point, and its
# exact point goes only into the separate .xlsx. Both downloads run the same
# masking step, and only the browser run reaches the two download handlers.

testthat::test_that("E2E: the zip carries generalized points and the private file the real ones", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    app <- shinytest2::AppDriver$new(
        app = build_e2e_app,
        timeout = 30000,
        load_timeout = 30000
    )
    on.exit(app$stop(), add = TRUE)
    app$wait_for_idle(timeout = 10000)

    # Both species are VU on the MMA list, so they form the "vu" group.
    csv_path <- tempfile(fileext = ".csv")
    writeLines(
        c("scientificName,decimalLatitude,decimalLongitude,basisOfRecord,eventDate",
          "Panthera onca,-10.512345,-55.234567,HumanObservation,2023-12-25",
          "Chrysocyon brachyurus,-13.276543,-52.712345,HumanObservation,2023-11-02"),
        csv_path
    )
    on.exit(unlink(csv_path), add = TRUE)
    real_lat <- c("-10.512345", "-13.276543")

    app$upload_file(`upload-file` = csv_path)
    app$wait_for_idle(timeout = 15000)
    app$click(selector = "a[data-value='mapping']")
    app$wait_for_idle(timeout = 10000)
    app$click(selector = "#mapping-auto_map")
    app$wait_for_idle(timeout = 20000)
    app$set_inputs(`mapping-custom_license` = "CC BY 4.0")

    app$set_inputs(main_nav = "sensitive_coords", wait_ = FALSE)
    wait_until_js(app, "!!document.getElementById('sensitive_coords-sensitive_mode')")
    app$set_inputs(`sensitive_coords-sensitive_mode` = "generalize")
    app$wait_for_idle(timeout = 10000)
    # 4.3 "yes" puts the group at Category 2, which needs a justification.
    app$set_inputs(`sensitive_coords-q43_vu` = "yes")
    app$wait_for_idle(timeout = 10000)
    app$set_inputs(`sensitive_coords-sensitive_justification` = "Hunting pressure.")
    app$wait_for_idle(timeout = 10000)

    app$set_inputs(main_nav = "export", wait_ = FALSE)
    wait_until_js(
        app,
        "(function () { var b = document.getElementById('export-download_trigger'); return !!b && !b.disabled; })()"
    )
    wait_until_js(app, "!!document.getElementById('export-download_private')")

    zip_path <- app$get_download("export-download_real")
    private_path <- app$get_download("export-download_private")
    unzip_dir <- tempfile()
    dir.create(unzip_dir)
    on.exit(unlink(c(zip_path, private_path, unzip_dir), recursive = TRUE), add = TRUE)
    utils::unzip(zip_path, exdir = unzip_dir)

    zipped <- list.files(unzip_dir, recursive = TRUE)
    testthat::expect_false(any(grepl("sensitive", zipped, fixed = TRUE)))
    occurrence_path <- list.files(
        unzip_dir, pattern = "^occurrence\\.txt$", recursive = TRUE, full.names = TRUE
    )
    testthat::expect_length(occurrence_path, 1L)
    occurrence <- utils::read.csv(
        occurrence_path[[1]], sep = ",", colClasses = "character", encoding = "UTF-8"
    )
    testthat::expect_identical(nrow(occurrence), 2L)
    testthat::expect_false(any(occurrence$decimalLatitude %in% real_lat))
    # The exact points are nowhere in the package, not only off the column.
    for (file in list.files(unzip_dir, recursive = TRUE, full.names = TRUE, pattern = "\\.(txt|xml)$")) {
        text <- paste(readLines(file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
        testthat::expect_false(any(vapply(real_lat, grepl, logical(1), x = text, fixed = TRUE)))
    }

    testthat::expect_true(grepl("-sensitive-coords\\.xlsx$", private_path))
    testthat::expect_setequal(readxl::excel_sheets(private_path), c("coordinates", "README"))
    real <- readxl::read_xlsx(private_path, sheet = "coordinates", col_types = "text")
    testthat::expect_setequal(real$decimalLatitude, real_lat)
})

# --- Flow 8c: the change list never shows a value of a generalized record ---
#
# Row 1 (generalized) and row 3 (not generalized) each get a Preview fix. The
# panel and the changes file show row 3, and never the values of row 1.

testthat::test_that("E2E: the change list shows a Preview fix and hides a generalized record", {
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
        c("scientificName,decimalLatitude,decimalLongitude,basisOfRecord,eventDate,individualCount",
          "Panthera onca,-10.512345,-55.234567,HumanObservation,2023-12-25,muitos",
          "Chrysocyon brachyurus,-13.276543,-52.712345,HumanObservation,2023-11-02,1",
          "Didelphis albiventris,-195.5,-50.1,HumanObservation,2023-10-01,2"),
        csv_path
    )
    on.exit(unlink(csv_path), add = TRUE)
    secret <- c("-10.512345", "-55.234567", "muitos")

    app$upload_file(`upload-file` = csv_path)
    app$wait_for_idle(timeout = 15000)
    app$click(selector = "a[data-value='mapping']")
    app$wait_for_idle(timeout = 10000)
    app$click(selector = "#mapping-auto_map")
    app$wait_for_idle(timeout = 20000)
    app$set_inputs(`mapping-custom_license` = "CC BY 4.0")

    app$set_inputs(main_nav = "preview", wait_ = FALSE)
    wait_until_js(app, "!!document.getElementById('preview-mode')")
    app$set_inputs(`preview-mode` = "problems", wait_ = FALSE)
    app$wait_for_idle(duration = 800, timeout = 30000)
    for (value in c("muitos", "-195.5")) {
        app$run_js(sprintf("$('#preview-rows_table table').DataTable().search('%s').draw();", value))
        wait_until_js(app, sprintf(
            "Array.from(document.querySelectorAll('#preview-rows_table tbody tr')).some(function (r) {
               return r.innerText.indexOf('%s') >= 0 && r.querySelector('.preview-fix-blank'); })", value))
        app$run_js(sprintf(
            "Array.from(document.querySelectorAll('#preview-rows_table tbody tr')).filter(function (r) {
               return r.innerText.indexOf('%s') >= 0; })[0].querySelector('.preview-fix-blank').click();", value))
        app$wait_for_idle(duration = 800, timeout = 30000)
    }

    app$set_inputs(main_nav = "sensitive_coords", wait_ = FALSE)
    wait_until_js(app, "!!document.getElementById('sensitive_coords-sensitive_mode')")
    app$set_inputs(`sensitive_coords-sensitive_mode` = "generalize")
    app$wait_for_idle(timeout = 10000)
    app$set_inputs(`sensitive_coords-q43_vu` = "yes")
    app$wait_for_idle(timeout = 10000)
    app$set_inputs(`sensitive_coords-sensitive_justification` = "Hunting pressure.")
    app$wait_for_idle(timeout = 10000)

    app$set_inputs(main_nav = "export", wait_ = FALSE)
    wait_until_js(app, "!!document.querySelector('.export-kpi-toggle')")
    app$click(selector = ".export-kpi-toggle")
    wait_until_js(app, "!!document.querySelector('#export-changes_panel.show')")
    panel <- app$get_html("#export-changes_panel")
    testthat::expect_match(panel, "Linha 3", fixed = TRUE)
    testthat::expect_match(panel, "-195.5", fixed = TRUE)
    testthat::expect_match(panel, "-changes.csv", fixed = TRUE)
    for (value in secret) testthat::expect_false(grepl(value, panel, fixed = TRUE))

    wait_until_js(
        app,
        "(function () { var b = document.getElementById('export-download_trigger'); return !!b && !b.disabled; })()"
    )
    zip_path <- app$get_download("export-download_real")
    unzip_dir <- tempfile()
    dir.create(unzip_dir)
    on.exit(unlink(c(zip_path, unzip_dir), recursive = TRUE), add = TRUE)
    utils::unzip(zip_path, exdir = unzip_dir)

    changes_path <- list.files(unzip_dir, pattern = "-changes\\.csv$", full.names = TRUE)
    testthat::expect_length(changes_path, 1L)
    text <- paste(readLines(changes_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    for (value in secret) testthat::expect_false(grepl(value, text, fixed = TRUE))
    changes <- utils::read.csv(changes_path, colClasses = "character")
    testthat::expect_identical(changes$row, c("1", "3"))
    testthat::expect_identical(changes$kind, c("preview", "preview"))
    testthat::expect_identical(changes$generalized, c("TRUE", "FALSE"))
    testthat::expect_identical(changes$from, c("", "-195.5"))
})

# --- Flow 9: the whole flow on the demo dataset, timed ---
#
# The public demo sheet exercises every validation, so this is the one run that
# crosses every tab with real data. Each step records its time. The numbers are
# printed, and written to SAIRA_E2E_TIMINGS when that variable names a file, to
# compare a branch against the baseline taken on main. Name validation queries
# the GBIF API over the network, so it stays out of this flow.

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
    # license is required since #143, and the demo sheet has no license column.
    app$set_inputs(`mapping-custom_license` = "CC BY 4.0")
    # The suite runs on an empty alias store, so this checks that auto-map
    # finds the demo date column through the bundled synonyms alone.
    mapped_date <- app$get_values(input = "mapping-map_eventDate")$input
    testthat::expect_identical(mapped_date[["mapping-map_eventDate"]], "data_registro")
    # A blank basisOfRecord blocks the download since #161. "Coleta" can name
    # more than one term, so the assistant asks, as a user would answer it.
    app$click("mapping-open_basis_of_record_assistant")
    wait_until_js(app, "document.querySelectorAll('.bor-assistant-raw-value').length > 0")
    coleta_id <- app$get_js("(function () {
      var cells = document.querySelectorAll('.bor-assistant-raw-value');
      for (var i = 0; i < cells.length; i++) {
        if (cells[i].textContent.trim() === 'Coleta') {
          return cells[i].closest('tr').querySelector('select').id;
        }
      }
      return '';
    })()")
    testthat::expect_true(nzchar(coleta_id))
    do.call(app$set_inputs, stats::setNames(list("PreservedSpecimen"), coleta_id))
    app$click("mapping-save_basis_of_record_assistant")
    wait_until_js(app, "document.querySelector('.bor-assistant-modal') === null")
    app$wait_for_idle(timeout = 10000)

    timed("open preview", go_to("preview"))
    testthat::expect_true(nchar(app$get_html("#preview-datatable")) > 0L)
    # The demo has two out-of-range coordinates, and they block the Export
    # (ADR-162). Blank both cells in the Problems mode, as a user does.
    app$set_inputs(`preview-mode` = "problems", wait_ = FALSE)
    app$wait_for_idle(duration = 800, timeout = 30000)
    for (value in c("-95.24310", "-198.40220")) {
        app$run_js(sprintf("$('#preview-rows_table table').DataTable().search('%s').draw();", value))
        wait_until_js(app, sprintf(
            "Array.from(document.querySelectorAll('#preview-rows_table tbody tr')).some(function (r) {
               return r.innerText.indexOf('%s') >= 0 && r.querySelector('.preview-fix-blank'); })", value))
        app$run_js(sprintf(
            "Array.from(document.querySelectorAll('#preview-rows_table tbody tr')).filter(function (r) {
               return r.innerText.indexOf('%s') >= 0; })[0].querySelector('.preview-fix-blank').click();", value))
        app$wait_for_idle(duration = 800, timeout = 30000)
    }

    timed("open coordinates", go_to("validate_coords"))
    timed("validate coordinates", function() app$click(selector = "#validate_coords-validate"),
          timeout = 300000)
    testthat::expect_true(nchar(app$get_html("#validate_coords-filter_pills")) > 0L)

    timed("open generalization", go_to("sensitive_coords"))
    testthat::expect_true(nchar(app$get_html(".sensitive-coords-page")) > 0L)

    timed("open export", go_to("export"))
    # A user can click only an enabled button. The gate can still be catching
    # up with the last mapping change when the tab opens.
    wait_until_js(
        app,
        "(function () { var b = document.getElementById('export-download_trigger'); return !!b && !b.disabled; })()"
    )
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

# --- Flow: the answer list during a names run (DEP-07) ---
#
# GBIF is replaced by the recorded COL XR answers, and each GBIF batch waits
# until the test releases it. So the test reads the list at fixed points of the
# run, with no network and no timing guess.

testthat::test_that("E2E: the names list shows settled names and keeps its rows during a run", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("shinytest2")

    gate_dir <- withr::local_tempdir()
    build_gated_app <- function() {
        pkgload::load_all(app_root, export_all = FALSE, quiet = TRUE)
        fixtures <- file.path(app_root, "tests", "testthat", "fixtures", "colxr")
        calls <- 0L
        gated_gbif <- function(requests) {
            calls <<- calls + 1L
            file.create(file.path(gate_dir, paste0("waiting_", calls)))
            deadline <- Sys.time() + 120
            repeat {
                released <- suppressWarnings(as.integer(
                    readLines(file.path(gate_dir, "released"), warn = FALSE)
                ))
                if (isTRUE(released[1] >= calls) || Sys.time() > deadline) break
                Sys.sleep(0.1)
            }
            # A name with no recording gets an accepted answer. A "no match"
            # answer keeps a name in the queue until the run ends.
            lapply(requests, function(r) {
                file <- file.path(fixtures, paste0(gsub(" ", "_", r$query$scientificName), ".json"))
                if (!file.exists(file)) file <- file.path(fixtures, "Panthera_onca.json")
                jsonlite::read_json(file)
            })
        }
        utils::assignInNamespace("gbif_api_get_many", gated_gbif, ns = "saira")
        run_app()
    }
    build_gated_app <- utils::removeSource(build_gated_app)
    environment(build_gated_app) <- list2env(
        list(app_root = app_root, gate_dir = gate_dir),
        parent = globalenv()
    )
    writeLines("0", file.path(gate_dir, "released"))
    release <- function(n) writeLines(as.character(n), file.path(gate_dir, "released"))
    wait_for_gbif_call <- function(n, timeout = 180) {
        deadline <- Sys.time() + timeout
        while (!file.exists(file.path(gate_dir, paste0("waiting_", n)))) {
            if (Sys.time() > deadline) stop("GBIF call ", n, " did not start", call. = FALSE)
            Sys.sleep(0.25)
        }
    }

    # Fauna BR accepts Panthera onca. Flora BR gives Caesalpinia echinata as a
    # synonym, so GBIF must answer it too. No BR list has the other names, and
    # each one costs the BR fuzzy match about 1 s, so there are only enough of
    # them for two GBIF batches of 20. Auto-map skips a column of names with
    # digits, so the epithets are letters.
    names_in <- c("Panthera onca", "Caesalpinia echinata", paste0("Gatedgenus ", letters[1:20], "ensis"))
    csv_path <- tempfile(fileext = ".csv")
    writeLines(c("occurrenceID,scientificName", sprintf("e2e-%02d,%s", seq_along(names_in), names_in)), csv_path)
    on.exit(unlink(csv_path), add = TRUE)

    app <- shinytest2::AppDriver$new(app = build_gated_app, timeout = 60000, load_timeout = 30000)
    on.exit(app$stop(), add = TRUE)
    app$wait_for_idle(timeout = 20000)

    app$upload_file(`upload-file` = csv_path)
    app$wait_for_idle(timeout = 20000)
    app$set_inputs(main_nav = "mapping", wait_ = FALSE)
    app$wait_for_idle(timeout = 20000)
    app$click(selector = "#mapping-auto_map")
    app$wait_for_idle(timeout = 20000)
    mapped <- app$get_values(input = "mapping-map_scientificName")$input
    testthat::expect_identical(mapped[["mapping-map_scientificName"]], "scientificName")
    app$set_inputs(main_nav = "validate_names", wait_ = FALSE)
    wait_until_js(app, "!!document.getElementById('validate_names-validate')")
    app$click("validate_names-validate")

    list_keys <- "Array.from(document.querySelectorAll('#validate_names-stream_panel .vn-stream-list [data-key]'))
                    .map(function (el) { return el.getAttribute('data-key'); })"
    all_count <- "document.querySelector('#validate_names-stream_filter_all .vn-pill-count').textContent.trim()"

    # The BR providers are done and the first GBIF batch waits. Only the name
    # that a BR list accepts has its last answer.
    wait_for_gbif_call(1)
    wait_until_js(app, sprintf("%s.length === 1", list_keys))
    Sys.sleep(0.5)
    testthat::expect_identical(unlist(app$get_js(list_keys)), "Panthera onca")
    app$run_js("document.querySelector('[data-key=\"Panthera onca\"]').setAttribute('data-e2e-mark', '1');")

    # The first GBIF batch adds its 20 names in place, and the marked row stays.
    release(1)
    wait_for_gbif_call(2)
    wait_until_js(app, sprintf("%s.length === 21", list_keys))
    testthat::expect_identical(app$get_js(all_count), "21")
    testthat::expect_true(app$get_js(
        "(function () { var el = document.querySelector('[data-e2e-mark]');
           return !!el && el.getAttribute('data-key') === 'Panthera onca'; })()"
    ))
    testthat::expect_true("Caesalpinia echinata" %in% unlist(app$get_js(list_keys)))

    release(999)
    wait_until_js(app, sprintf("%s === '22'", all_count), timeout = 60000)
    app$wait_for_idle(timeout = 20000)
    # Every name has an answer, so the run is complete, not partial.
    testthat::expect_false(app$get_js("!!document.querySelector('.shiny-notification-warning')"))
})

testthat::test_that("E2E: the Preview table shows a value as it is in the file", {
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
        c("scientificName,occurrenceRemarks",
          "Panthera onca,Mata & cerrado <borda>",
          "Leopardus pardalis,curto"),
        csv_path
    )
    on.exit(unlink(csv_path), add = TRUE)

    app$upload_file(`upload-file` = csv_path)
    app$wait_for_idle(timeout = 15000)
    app$click(selector = "a[data-value='preview']")
    wait_until_js(app, "document.querySelectorAll('#preview-datatable tbody td').length > 2")

    cells <- unlist(app$get_js(
        "Array.from(document.querySelectorAll('#preview-datatable tbody td')).map(function (td) { return td.textContent; })"
    ))
    testthat::expect_true("Mata & cerrado <borda>" %in% cells)
})
