# Title: IUCN lookup of the Export tab (ADR-213)
# Author: Rogerio Nunes Oliveira
#
# Looks up the IUCN category of the corrected names before the download. The
# names worker sends the requests, so the session stays free while GBIF is
# slow. The download reads only the snapshot and sends no request.

# Total GBIF wait of one lookup. Past it, the Pending card offers a retry or
# an export without the IUCN category.
EXPORT_IUCN_BUDGET_S <- 120

#' Mount the IUCN lookup inside the Export module server
#'
#' @param names_r Reactive with the corrected scientific names of the export.
#' @param include_r Reactive, TRUE when the user picked the GBIF IUCN source.
#' @param active_r Reactive, TRUE while the Export tab shows. A new lookup
#'   starts only then, so the upload of a file sends no GBIF request.
#' @param worker Names worker of this lookup, apart from the one of the Names tab.
#' @return Reactive list: `status` ("off", "pending", "failed", "skipped",
#'   "done"), the counts and `snapshot` (IUCN code by name).
#' @noRd
mount_export_iucn <- function(input, session, names_r, include_r,
                              active_r = function() TRUE,
                              worker = names_worker_new(),
                              budget_s = getOption("saira.export_iucn_budget_s", EXPORT_IUCN_BUDGET_S),
                              tick_ms = 100,
                              start = names_worker_start, poll = names_worker_poll) {
    state_rv <- shiny::reactiveVal(NULL)
    run_rv <- shiny::reactiveVal(0L)
    skipped <- shiny::reactiveVal(FALSE)
    session$onSessionEnded(function() names_worker_stop(worker))

    # A new run id makes the worker drop the batch of the run before.
    start_run <- function(names) {
        run <- shiny::isolate(run_rv()) + 1L
        state_rv(iucn_lookup_new(names, paste0("export-iucn-", run)))
        run_rv(run)
    }

    key_r <- shiny::reactive({
        on <- tryCatch(isTRUE(include_r()), error = function(e) FALSE)
        if (!on) {
            return(character(0))
        }
        sort(colxr_clean_names(tryCatch(names_r(), error = function(e) character(0))))
    })
    # A data change or a name review gives new names, and the answers for the
    # old names no longer count. A lookup that runs goes on when the user
    # leaves the tab.
    shiny::observeEvent(list(key_r(), active_r()), {
        key <- key_r()
        if (identical(key, shiny::isolate(state_rv())$names)) {
            return(invisible(NULL))
        }
        skipped(FALSE)
        if (length(key) == 0L || !isTRUE(active_r())) {
            names_worker_cancel(worker)
            state_rv(NULL)
            return(invisible(NULL))
        }
        start_run(key)
    }, ignoreNULL = FALSE)

    # The state is read under isolate(): the tick writes it (ADR-159).
    shiny::observe({
        run_rv()
        state <- shiny::isolate(state_rv())
        if (is.null(state) || identical(state$phase, "done")) {
            return(invisible(NULL))
        }
        shiny::invalidateLater(tick_ms, session)
        fetch_for <- function(misses) {
            names_worker_fetch(worker, state$run_id, misses, budget_s = budget_s,
                               start = start, poll = poll)
        }
        next_state <- tryCatch(iucn_lookup_step(state, fetch_for), error = function(e) {
            state$snapshot <- stats::setNames(rep(NA_character_, length(state$names)), state$names)
            state$unanswered <- state$names
            state$phase <- "done"
            state
        })
        if (identical(next_state$phase, "done")) names_worker_cancel(worker)
        if (!identical(next_state, state)) state_rv(next_state)
    })

    shiny::observeEvent(input$go_iucn_retry, {
        state <- state_rv()
        if (!is.null(state)) {
            skipped(FALSE)
            start_run(state$names)
        }
    }, ignoreInit = TRUE)
    shiny::observeEvent(input$go_iucn_skip, skipped(TRUE), ignoreInit = TRUE)
    shiny::observeEvent(input$go_iucn_undo, skipped(FALSE), ignoreInit = TRUE)

    shiny::reactive({
        state <- state_rv()
        if (is.null(state)) {
            return(list(status = "off", snapshot = NULL))
        }
        if (!identical(state$phase, "done")) {
            progress <- iucn_lookup_progress(state)
            return(list(status = "pending", done = progress$done, total = progress$total,
                        snapshot = NULL))
        }
        n <- length(state$unanswered)
        status <- if (n == 0L) "done" else if (isTRUE(skipped())) "skipped" else "failed"
        list(status = status, unanswered = n, total = length(state$names),
             snapshot = state$snapshot)
    })
}
