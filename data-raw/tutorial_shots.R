# Title: Tutorial screenshots for the help site
#
# Drives the app with shinytest2, draws numbered marks over real elements
# (data-raw/tutorial_marks.js), and writes the PNGs that the pages in
# website/tutoriais/ (and the en/ and es/ mirrors) show.
#
# When to run:
#   After a UI change that a tutorial screenshot shows, and at each release cut
#   (the navbar badge shows the version).
#
# Usage (from the repo root, NOT_CRAN=true, Chrome installed):
#   Rscript data-raw/tutorial_shots.R [langs] [app_root]
#   langs     comma list of pt, en, es (default: all three)
#   app_root  package root of the app to capture (default: the repo root)
#
# Output: website/assets/img/tNN-name.png (PT), tNN-name-EN.png, tNN-name-ES.png.
# The names step downloads the Flora/Fauna do Brasil databases into a temporary
# SAIRA_DATA_DIR, so the first language takes a few minutes longer.

args <- commandArgs(trailingOnly = TRUE)
langs <- if (length(args) >= 1L) strsplit(args[[1]], ",")[[1]] else c("pt", "en", "es")
app_root <- normalizePath(if (length(args) >= 2L) args[[2]] else ".", mustWork = TRUE)
repo <- normalizePath(".", mustWork = TRUE)
img_dir <- file.path(repo, "website", "assets", "img")
demo_csv <- file.path(repo, "website", "assets", "exemplo", "ocorrencias-demo.csv")
marks_js <- paste(readLines(file.path(repo, "data-raw", "tutorial_marks.js")), collapse = "\n")

if (!nzchar(Sys.getenv("NOT_CRAN"))) Sys.setenv(NOT_CRAN = "true")
# One data dir for all languages: the provider downloads happen once, and the
# user's real rostrum.sqlite stays untouched.
data_dir <- tempfile("saira-shots-")
dir.create(data_dir)
Sys.setenv(SAIRA_DATA_DIR = data_dir)

# AppDriver needs the package loaded in this process too, else app_dir fails
# with "`env` must be an environment, not NULL".
pkgload::load_all(app_root, quiet = TRUE)
build_app <- local({
    root <- app_root
    utils::removeSource(function() {
        pkgload::load_all(root, export_all = FALSE, quiet = TRUE)
        run_app()
    })
})
chromote::set_chrome_args(c(
    chromote::default_chrome_args(),
    "--disable-background-timer-throttling", "--disable-renderer-backgrounding",
    "--disable-backgrounding-occluded-windows"
))

run_lang <- function(lang) {
    suffix <- if (identical(lang, "pt")) "" else paste0("-", toupper(lang))
    app <- shinytest2::AppDriver$new(
        app_dir = build_app, width = 1440, height = 900,
        timeout = 60000, load_timeout = 60000
    )
    on.exit(app$stop(), add = TRUE)
    b <- app$get_chromote_session()

    js <- function(code) app$run_js(code)
    idle <- function(t = 30000) {
        try(app$wait_for_idle(duration = 400, timeout = t), silent = TRUE)
    }
    wait_js <- function(cond, t = 1200) {
        t0 <- Sys.time()
        while (!isTRUE(app$get_js(cond)) && difftime(Sys.time(), t0, units = "secs") < t) {
            Sys.sleep(3)
        }
        if (!isTRUE(app$get_js(cond))) stop("timeout waiting for: ", cond)
    }
    window <- function(h) {
        app$set_window_size(1440, h)
        idle()
        Sys.sleep(0.6)
    }
    # The marks layer hangs off <body>, so one injection lasts the session.
    # screenshot() hides the scrollbars only during the capture, which widens
    # the page and can unwrap text after the marks are drawn. Hide them for the
    # whole session so the marks and the capture see the same layout.
    inject <- function() {
        js(marks_js)
        js("var s = document.createElement('style');
            s.textContent = 'html { scrollbar-width: none; } ::-webkit-scrollbar { display: none; }';
            document.head.appendChild(s);")
    }
    M <- function(code) js(code)
    scroll_to <- function(sel) {
        js(sprintf("document.querySelector('%s').scrollIntoView({block:'center'})", sel))
        Sys.sleep(0.4)
    }
    open_modal <- function(btn) {
        js(sprintf("document.querySelector('%s').click()", btn))
        idle()
        Sys.sleep(1)
    }
    close_modal <- function() {
        js("$('#shiny-modal').modal('hide')")
        idle()
        Sys.sleep(0.6)
    }
    go <- function(tab, pause = 2) {
        app$set_inputs(main_nav = tab, wait_ = FALSE)
        idle()
        Sys.sleep(pause)
    }
    shot <- function(name, clip = "body", pad = 40) {
        js(sprintf("tutMarks.clip(%s, %d)", jsonlite::toJSON(clip), pad))
        Sys.sleep(0.4)
        file <- file.path(img_dir, paste0(name, suffix, ".png"))
        b$screenshot(file, selector = "#tut-clip", scale = 2, show = FALSE, delay = 0.3)
        js("tutMarks.clear(); window.scrollTo(0, 0)")
        message("  ", basename(file))
    }
    # A failed shot must not stop the run; the log names it.
    safe <- function(name, expr) {
        tryCatch(expr, error = function(e) message("  FAIL ", name, ": ", conditionMessage(e)))
    }

    message("[", lang, "]")
    app$wait_for_idle(timeout = 20000)
    app$set_inputs(lang_switch = lang)
    idle()
    inject()

    # 02 Upload -----------------------------------------------------------
    app$upload_file(`upload-file` = demo_csv)
    idle()
    safe("t02-upload", {
        # The summary renders after the upload settles and sits below the fold.
        wait_js("!!document.querySelector('#upload-stats .stats-container')", 60)
        window(1200)
        # The dropzone is flex-filled to the viewport height, and the capture
        # resizes the viewport. Freeze its height so the marks stay on it.
        js("var d = document.querySelector('.upload-dropzone');
            d.style.height = d.offsetHeight + 'px'; d.style.flex = 'none';")
        # #upload-upload_mode is the hidden radio input, so mark the visible tabs.
        M("tutMarks.mark('.upload-mode-tabs', 1);
           tutMarks.mark('.upload-dropzone', 2, {radius: 16});
           tutMarks.mark('#upload-stats .stats-container', 3);")
        shot("t02-upload", c(".home-header", ".upload-mode-tabs", ".upload-dropzone", "#upload-stats .stats-container"))
        window(900)
    })

    # 03 Mapping ----------------------------------------------------------
    go("mapping", 1)
    js("document.querySelector('#mapping-auto_map').click()")
    idle(60000)
    safe("t03-automap", {
        M("tutMarks.spotlight(['#mapping-auto_map', '.next-pending-pill', '#mapping-fieldcard_recordedBy']);
           tutMarks.badge('#mapping-auto_map', 1, {corner: 'or', pad: 8});
           tutMarks.badge('.next-pending-pill', 2, {corner: 'or', pad: 8});
           tutMarks.badge('#mapping-fieldcard_recordedBy', 3, {corner: 'ot', pad: 8});")
        shot("t03-automap", "body", 0)
    })
    safe("t03-card", {
        C <- "#mapping-fieldcard_recordedBy"
        scroll_to(C)
        M(sprintf("tutMarks.tag('%1$s', 'ex.:', 'tut-ex');
           tutMarks.mark('%1$s .field-status-badge', 1, {corner: 'or'});
           tutMarks.mark('%1$s .selectize-control', 2);
           tutMarks.mark('#tut-ex', 3);", C))
        shot("t03-card", C, 44)
    })
    safe("t03-bor-card", {
        C <- "#mapping-fieldcard_basisOfRecord"
        scroll_to(C)
        M(sprintf("tutMarks.mark('%1$s .selectize-control', 1);
           tutMarks.mark('#mapping-open_basis_of_record_assistant', 2);", C))
        shot("t03-bor-card", C, 44)
    })
    window(1400)
    safe("t03-bor-modal", {
        open_modal("#mapping-open_basis_of_record_assistant")
        M("tutMarks.mark('.bor-assistant-raw-value', 1, {pad: 6});
           tutMarks.mark('.shiny-input-container:has(#mapping-basis_of_record_target_1)', 2);
           tutMarks.mark('#mapping-save_basis_of_record_assistant', 3, {corner: 'ot'});")
        shot("t03-bor-modal", ".modal-content", 36)
        close_modal()
    })
    safe("t03-est-modal", {
        open_modal("#mapping-open_establishment_assistant")
        M("tutMarks.up('.est-assistant-species-meta', 'td', 'tut-est-sp');
           tutMarks.mark('#tut-est-sp', 1);
           tutMarks.mark('.shiny-input-container:has(#mapping-est_means_1)', 2, {corner: 'ot'});
           tutMarks.mark('#mapping-save_establishment_assistant', 3, {corner: 'ot'});")
        shot("t03-est-modal", ".modal-content", 36)
        close_modal()
    })
    safe("t03-add", {
        open_modal("#mapping-add_term")
        M("tutMarks.mark('.shiny-input-container:has(#mapping-add_term_select) .selectize-control', 1);
           tutMarks.mark('#mapping-confirm_add_term', 2, {corner: 'ot'});")
        shot("t03-add", ".modal-content", 36)
        close_modal()
    })
    safe("t03-import", {
        open_modal("#mapping-import_template")
        M("tutMarks.mark('.import-template-dropzone', 1, {radius: 14});
           tutMarks.mark('#mapping-confirm_import_template', 2, {corner: 'ot'});")
        shot("t03-import", ".modal-content", 36)
        close_modal()
    })
    window(900)
    safe("t03-fixed", {
        C <- "#mapping-fieldcard_rightsHolder"
        scroll_to(C)
        app$set_inputs(`mapping-usecustom_rightsHolder` = TRUE)
        idle()
        app$set_inputs(`mapping-custom_rightsHolder` = "Museu Nacional")
        idle()
        scroll_to(C)
        M("tutMarks.mark('.shiny-input-container:has(#mapping-usecustom_rightsHolder)', 1);
           tutMarks.mark('#mapping-custom_rightsHolder', 2);")
        shot("t03-fixed", C, 44)
    })
    safe("t03-dyn", {
        C <- "#mapping-fieldcard_dynamicProperties"
        app$set_inputs(`mapping-map_dynamicProperties` = c("ambiente", "nome_comum"))
        idle()
        app$set_inputs(`mapping-dynprops_key_nome_comum` = "nomePopular")
        idle()
        Sys.sleep(1)
        scroll_to(C)
        M(sprintf("tutMarks.tag('%1$s', 'ex.:', 'tut-ex2');
           tutMarks.mark('%1$s .selectize-control', 1);
           tutMarks.mark('#mapping-dynprops_key_nome_comum', 2);
           tutMarks.mark('#tut-ex2', 3);", C))
        shot("t03-dyn", C, 44)
    })

    # 07a Preview (before the validations change the data) ---------------
    go("preview")
    safe("t07-preview", {
        M("tutMarks.mark('#preview-datatable .dataTables_scrollHead', 1);
           tutMarks.mark('#preview-datatable .dataTables_length', 2, {corner: 'ot'});
           tutMarks.mark('#preview-datatable .dataTables_filter', 3, {corner: 'ot'});")
        shot("t07-preview", "body", 0)
    })

    # 04 Names ------------------------------------------------------------
    go("validate_names")
    safe("t04-run", {
        M("tutMarks.mark('.vn-config-section-providers', 1, {corner: 'ot'});
           tutMarks.mark('.vn-config-section-options', 2, {corner: 'ot'});
           tutMarks.mark('#validate_names-validate', 3);")
        shot("t04-run", ".vn-config-panel", 24)
    })
    js("document.querySelector('#validate_names-validate').click()")
    wait_js(paste0(
        "!!document.querySelector('#validate_names-report_table table tbody tr td') && ",
        "!document.querySelector('#validate_names-cancel_validation:not([disabled])')"
    ))
    idle()
    Sys.sleep(3)
    safe("t04-results", {
        M("tutMarks.box('.vn-stream-pills', {pad: 6});
           tutMarks.badge('.vn-stream-pills', 1, {corner: 'ot', pad: 6});
           tutMarks.mark('.vn-review-trigger', 2, {corner: 'ol'});
           tutMarks.up('.vn-conservation-tag', 'div', 'tut-tags');
           tutMarks.box('#tut-tags', {pad: 6});
           tutMarks.badge('#tut-tags', 3, {corner: 'ot', pad: 6});
           tutMarks.mark('.vn-report-table-shell', 4, {corner: 'ot'});")
        shot("t04-results", "body", 0)
    })
    window(1400)
    safe("t04-review", {
        # Ateles paniscus paniscus, a "not found" name with an obvious fix.
        js("document.querySelectorAll('.vn-review-trigger')[6].click()")
        idle()
        Sys.sleep(1)
        M("tutMarks.mark('.vn-review-confirm-block', 1);
           tutMarks.mark('#validate_names-review_switch_to_edit', 2);")
        shot("t04-review", ".modal-content", 36)
    })
    safe("t04-review-edit", {
        js("document.querySelector('#validate_names-review_switch_to_edit').click()")
        idle()
        Sys.sleep(1)
        # The save button listens to the DOM input event, which set_inputs() does not fire.
        js("var el = document.getElementById('validate_names-review_corrected_name');
            el.value = 'Ateles paniscus'; el.dispatchEvent(new Event('input', {bubbles: true}));
            el.blur();")
        idle()
        Sys.sleep(0.6)
        M("tutMarks.mark('#validate_names-review_corrected_name', 1);
           tutMarks.mark('#validate_names-review_save_correction', 2, {corner: 'ot'});")
        shot("t04-review-edit", ".modal-content", 36)
        close_modal()
    })
    window(900)
    safe("t04-sensitive", {
        M("tutMarks.up('.vn-sensitive-trigger', 'tr', 'tut-sens-row');
           tutMarks.up('.vn-sensitive-add', 'tr', 'tut-add-row');
           tutMarks.mark('.vn-sensitive-trigger', 1, {corner: 'or'});
           tutMarks.mark('.vn-sensitive-add', 2, {corner: 'or'});")
        shot("t04-sensitive", c(".vn-report-header", "#tut-sens-row", "#tut-add-row"), 24)
    })
    safe("t04-invasive", {
        js("document.querySelector('#validate_names-stream_filter_invasive').click()")
        idle()
        Sys.sleep(1)
        M("tutMarks.mark('#validate_names-stream_filter_invasive', 1, {corner: 'or'});")
        shot("t04-invasive", c(".vn-stream-header", ".vn-stream-list"), 24)
        js("document.querySelector('#validate_names-stream_filter_all').click()")
        idle()
    })

    # 05 Coordinates ------------------------------------------------------
    go("validate_coords")
    js("document.querySelector('#validate_coords-validate').click()")
    idle(120000)
    Sys.sleep(4)
    safe("t05-results", {
        M("tutMarks.mark('#validate_coords-action_card', 1, {corner: 'ot'});
           tutMarks.mark('#validate_coords-transposed_panel', 2, {corner: 'ot'});
           tutMarks.mark('#validate_coords-country_panel', 3, {corner: 'ot'});
           tutMarks.mark('.coords-filter-pills', 4, {corner: 'or'});
           tutMarks.mark('#validate_coords-issues_table', 5, {corner: 'ot'});")
        shot("t05-results", "body", 0)
    })
    safe("t05-edit", {
        # Line 22 sits at sea (-10, -10). A new longitude puts it in Bahia.
        app$set_inputs(
            `validate_coords-issues_table_cell_edit` = list(row = 1, col = 3, value = "-40.00000"),
            allow_no_input_binding_ = TRUE
        )
        idle()
        Sys.sleep(2)
        js("document.querySelector('#validate_coords-coords_filter_edited').click()")
        idle()
        Sys.sleep(1.5)
        M("tutMarks.mark('.coords-edit-hint', 1);
           tutMarks.mark('#validate_coords-coords_filter_edited', 2, {corner: 'ot'});
           tutMarks.tag('#validate_coords-issues_table tbody', '-40', 'tut-lon');
           tutMarks.mark('#tut-lon', 3, {corner: 'ot'});")
        shot("t05-edit", c("#validate_coords-coords_filter_edited", ".coords-edit-hint",
            "#validate_coords-issues_table .dataTables_info"), 40)
    })

    # 06 Generalization ---------------------------------------------------
    go("sensitive_coords", 3)
    safe("t06-mode", {
        M("tutMarks.mark('label:has(input[value=\"publish\"])', 1, {corner: 'ot'});
           tutMarks.mark('label:has(input[value=\"generalize\"])', 2, {corner: 'ot'});")
        shot("t06-mode", ".sc-mode-card", 24)
    })
    app$set_inputs(`sensitive_coords-sensitive_mode` = "generalize")
    idle()
    Sys.sleep(2)
    app$set_inputs(`sensitive_coords-q43_cr` = "no")
    idle()
    app$set_inputs(`sensitive_coords-q44_cr` = "yes")
    idle()
    Sys.sleep(2)
    safe("t06-table", {
        M("tutMarks.up('#sensitive_coords-q43_cr', 'tr', 'tut-cr');
           tutMarks.mark('#tut-cr', 1);
           tutMarks.mark('#tut-cr .sc-matrix-result', 2, {corner: 'or'});
           tutMarks.mark('.sc-scale', 3);")
        shot("t06-table", ".sc-matrix-card", 24)
    })
    window(1300)
    safe("t06-exceptions", {
        M("tutMarks.mark('.sp-exceptions .selectize-control', 1);
           tutMarks.mark('.sp-exc-apply', 2);
           tutMarks.mark('.sp-justification', 3);")
        shot("t06-exceptions", c(".sp-exceptions", ".sc-confirm"), 24)
    })
    window(900)
    safe("t06-assess", {
        M("tutMarks.mark('.sc-mode-card', 1, {corner: 'ot'});
           tutMarks.mark('.sc-matrix-card', 2, {corner: 'ot'});
           tutMarks.mark('#sensitive_coords-gen_map', 3, {corner: 'ot'});")
        shot("t06-assess", "body", 0)
    })

    # 07b Export ----------------------------------------------------------
    go("export", 3)
    window(1100)
    safe("t07-export", {
        M("tutMarks.mark('.export-pending', 1, {corner: 'ot'});
           tutMarks.mark('#export-go_fix_terms', 2);
           tutMarks.mark('.export-files', 3, {corner: 'ot'});
           tutMarks.mark('.export-download-bar', 4, {corner: 'ot'});")
        shot("t07-export", "body", 0)
    })
    invisible(NULL)
}

for (lang in langs) run_lang(lang)
