# Title: Timed full flow on the roadkill dataset
#
# Runs the whole app flow on the Brazil roadkill dataset (21,512 rows x 28
# columns) in a real browser and prints the time of each step. Compare the
# numbers with a run on main before merging a change to the mapping, i18n or
# coordinate code: a step that goes from under 1 s to several seconds, or gets
# more than 20% slower, is a regression. Profile it before naming a cause
# (ADR-116).
#
# The dataset is not in the repository. Point SAIRA_ROADKILL_DIR at the folder
# that holds Brazil_Roadkill_20180527_dwc.csv and mapping_guide_2026-08-04.txt.
#
# Usage, from the repository root (without --vanilla, renv loads from .Rprofile):
#   SAIRA_ROADKILL_DIR=/path/to/roadkill-brazil Rscript tests/bench/flow_roadkill.R
#
# Optional:
#   SAIRA_BENCH_LANG  interface language of the run: pt (default) or en
#   SAIRA_BENCH_OUT   CSV file that receives the timings
#
# Importing the guide writes aliases, so the app runs with a throwaway
# SAIRA_DATA_DIR and the aliases of the maintainer stay untouched.

roadkill_dir <- Sys.getenv("SAIRA_ROADKILL_DIR")
if (!nzchar(roadkill_dir)) {
    stop("Set SAIRA_ROADKILL_DIR to the roadkill-brazil folder.")
}
data_path <- file.path(roadkill_dir, "Brazil_Roadkill_20180527_dwc.csv")
guide_path <- file.path(roadkill_dir, "mapping_guide_2026-08-04.txt")
stopifnot(file.exists(data_path), file.exists(guide_path))

lang <- Sys.getenv("SAIRA_BENCH_LANG", "pt")
stopifnot(lang %in% c("pt", "en"))
other_lang <- if (identical(lang, "pt")) "en" else "pt"

# Without NOT_CRAN, AppDriver skips, and a skip outside test_that() stops the
# script with "Reason: On CRAN".
if (!nzchar(Sys.getenv("NOT_CRAN"))) Sys.setenv(NOT_CRAN = "true")

# AppDriver needs the package loaded here to start an app from a function.
pkgload::load_all(".", quiet = TRUE)

data_dir <- tempfile("saira-bench-")
dir.create(data_dir)
Sys.setenv(SAIRA_DATA_DIR = data_dir)

# The app starts in a separate R process. A function defined at top level keeps
# only a reference to the global environment, so local() carries the root path.
# removeSource(): see build_e2e_app in tests/testthat/test-e2e-flows.R.
build_app <- local({
    root <- normalizePath(".", winslash = "/", mustWork = TRUE)
    utils::removeSource(function() {
        pkgload::load_all(root, export_all = FALSE, quiet = TRUE)
        # run_app() sets this limit. Without it, Shiny refuses the 11 MB CSV (5 MB default).
        options(shiny.maxRequestSize = 500 * 1024^2)
        shiny::shinyApp(app_ui(), app_server)
    })
})

app <- shinytest2::AppDriver$new(
    app_dir = build_app,
    timeout = 120000,
    load_timeout = 120000
)
app$wait_for_idle(timeout = 20000)

idle_ms <- 500
timings <- data.frame(step = character(0), seconds = numeric(0), note = character(0))
record <- function(step, seconds, note = "") {
    timings[nrow(timings) + 1L, ] <<- list(step, round(max(seconds, 0), 2), note)
}
timed <- function(step, action, timeout = 300000) {
    started <- Sys.time()
    action()
    app$wait_for_idle(duration = idle_ms, timeout = timeout)
    record(step, as.numeric(difftime(Sys.time(), started, units = "secs")) - idle_ms / 1000)
}
go_to <- function(tab) function() app$set_inputs(main_nav = tab, wait_ = FALSE)
set_input <- function(...) function() app$set_inputs(..., wait_ = FALSE)

# A pick or a keystroke must update its own card only. If the grid renders
# again, the marked card is a new element and the mark is gone.
mark_grid <- function() {
    app$run_js(
        "document.getElementById('mapping-fieldcard_scientificName').dataset.benchMark = '1';"
    )
}
grid_note <- function() {
    kept <- app$get_js(
        "(function() {
            var el = document.getElementById('mapping-fieldcard_scientificName');
            return !!(el && el.dataset.benchMark === '1');
        })()"
    )
    if (isTRUE(kept)) "grid kept" else "GRID REBUILT"
}
note_last <- function(note) timings$note[nrow(timings)] <<- note
picked <- function(id) app$get_values(input = id)$input[[id]]

if (!identical(lang, "pt")) {
    app$set_inputs(lang_switch = lang)
    app$wait_for_idle(timeout = 20000)
}

# i. Upload until the card grid is usable.
timed("i. upload", function() app$upload_file(`upload-file` = data_path))
go_to("mapping")()
app$wait_for_idle(timeout = 60000)

# ii. Import the mapping guide until the modal closes.
app$click(selector = "#mapping-import_template")
app$wait_for_idle(timeout = 10000)
app$upload_file(`mapping-import_template_file` = guide_path)
app$wait_for_idle(timeout = 10000)
timed("ii. import guide", function() app$click(selector = "#mapping-confirm_import_template"))
mapped_name <- picked("mapping-map_scientificName")
stopifnot(length(mapped_name) > 0L, nzchar(mapped_name[[1]]))

# iii. Pick a column in one card (the ADR-116 symptom).
mark_grid()
timed("iii. pick a column", set_input(`mapping-map_habitat` = "Reference_ID"))
note_last(grid_note())

# iv. Type a dataset name and a fixed value.
timed("iv. type dataset name", set_input(`mapping-custom_datasetName` = "Brazil Roadkill"))
note_last(grid_note())
app$set_inputs(`mapping-usecustom_country` = TRUE)
app$wait_for_idle(timeout = 20000)
timed("iv. type fixed value", set_input(`mapping-custom_country` = "Brasil"))
note_last(grid_note())

# v. Rebuilds that are expected: the mapped-only filter and the list view.
timed("v. only mapped on", set_input(`mapping-show_only_mapped` = TRUE))
timed("v. only mapped off", set_input(`mapping-show_only_mapped` = FALSE))
timed("v. list view", set_input(`mapping-view_mode` = "list"))
timed("v. cards view", set_input(`mapping-view_mode` = "cards"))

# vi. Switch the language and back: the mapping stays.
timed("vi. switch language", set_input(lang_switch = other_lang))
timed("vi. switch back", set_input(lang_switch = lang))
stopifnot(identical(picked("mapping-map_scientificName"), mapped_name))
stopifnot(identical(picked("mapping-map_habitat"), "Reference_ID"))

# vii. Open the preview.
timed("vii. open preview", go_to("preview"))

# viii. Visit the generalization tab, then pick a column again (ADR-114).
timed("viii. open generalization", go_to("sensitive_coords"))
timed("viii. back to mapping", go_to("mapping"))
mark_grid()
timed("viii. pick after generalization", set_input(`mapping-map_habitat` = "Road_length"))
note_last(grid_note())

# ix. Export: download the ZIP and count the rows.
timed("ix. open export", go_to("export"))
started <- Sys.time()
zip_path <- app$get_download("export-download_real")
record("ix. download zip", as.numeric(difftime(Sys.time(), started, units = "secs")))

unzip_dir <- tempfile()
utils::unzip(zip_path, exdir = unzip_dir)
occurrence_path <- list.files(
    unzip_dir, pattern = "^occurrence\\.txt$", recursive = TRUE, full.names = TRUE
)
occurrence <- utils::read.csv(occurrence_path[[1]], colClasses = "character", encoding = "UTF-8")
note_last(sprintf("%d rows", nrow(occurrence)))
app$stop()

cat(sprintf("\nRoadkill flow, language %s (seconds):\n", lang))
print(timings, row.names = FALSE)

out_file <- Sys.getenv("SAIRA_BENCH_OUT")
if (nzchar(out_file)) {
    utils::write.csv(timings, out_file, row.names = FALSE)
}
