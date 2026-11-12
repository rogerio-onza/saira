# Title: GBIF requests of a names run in a separate R process
# Author: Rogerio Nunes Oliveira
#
# req_perform_parallel() waits for every response before it returns, so a
# slow or silent GBIF API held the Shiny session until the batch ended
# (PERF-02). One callr session per Shiny session sends the requests. The app
# keeps the memo, the parsing and the run state. The worker gets only the
# query names, never the records or their locations.

# One batch can wait this long, then GBIF counts as not answering.
NAMES_WORKER_CALL_LIMIT_S <- 60
# Total GBIF wait of one run. Past it, the names left stay unchecked and the
# retry button offers a new run.
NAMES_RUN_NETWORK_BUDGET_S <- 300

names_worker_new <- function() {
    worker <- new.env(parent = emptyenv())
    worker$session <- NULL
    worker$call <- NULL
    worker$warm_started <- NULL
    # The run that owns the worker, and when its first GBIF batch went out.
    worker$run_id <- NULL
    worker$run_started <- NULL
    worker
}

# Load saira in the worker. callr sends a function without its environment,
# so every value comes in as an argument. pkgload runs the app from the source
# tree, without an installed saira, so the worker loads the same tree
# (ADR-177).
names_worker_load <- function(source_path) {
    if (!"saira" %in% loadedNamespaces()) {
        if (is.null(source_path)) {
            loadNamespace("saira")
        } else {
            pkgload::load_all(source_path, quiet = TRUE, export_all = FALSE)
        }
    }
    invisible(TRUE)
}

names_worker_job <- function(names, source_path) {
    if (!"saira" %in% loadedNamespaces()) {
        if (is.null(source_path)) {
            loadNamespace("saira")
        } else {
            pkgload::load_all(source_path, quiet = TRUE, export_all = FALSE)
        }
    }
    ns <- asNamespace("saira")
    ns$gbif_api_get_many(lapply(names, ns$colxr_match_request))
}

names_worker_source_path <- function() {
    path <- getNamespaceInfo("saira", "path")
    if (file.exists(file.path(path, "R", "utils_colxr.R"))) path
}

# Start the worker and let it load saira. The run calls this at its start, so
# the load happens while the BR providers answer. Starting the R process
# blocks ~0.3 s once per session.
names_worker_warm <- function(worker, load = names_worker_load) {
    if (!is.null(worker$session) && isTRUE(worker$session$is_alive())) {
        return(invisible(TRUE))
    }
    worker$session <- tryCatch({
        session <- callr::r_session$new(
            options = callr::r_session_options(libpath = .libPaths(), user_profile = FALSE),
            wait = TRUE
        )
        session$call(load, list(source_path = names_worker_source_path()))
        session
    }, error = function(e) NULL)
    worker$warm_started <- Sys.time()
    invisible(!is.null(worker$session))
}

# Send one batch. "sent", "starting" while the worker still loads, or
# "failed": the caller then sends the requests itself, as before PERF-02.
names_worker_start <- function(worker, run_id, names, job = names_worker_job,
                               limit_s = NAMES_WORKER_CALL_LIMIT_S) {
    names_worker_warm(worker)
    session <- worker$session
    status <- tryCatch({
        # A busy worker without a batch is still loading saira.
        if (identical(session$get_state(), "busy") && is.null(worker$call) &&
            identical(session$poll_process(0), "ready")) {
            session$read()
        }
        if (identical(session$get_state(), "idle")) {
            args <- list(names = names)
            if ("source_path" %in% names(formals(job))) args$source_path <- names_worker_source_path()
            session$call(job, args)
            "sent"
        } else if (difftime(Sys.time(), worker$warm_started, units = "secs") < limit_s) {
            "starting"
        } else {
            "failed"
        }
    }, error = function(e) "failed")
    if (identical(status, "failed")) {
        names_worker_stop(worker)
    } else if (identical(status, "sent")) {
        worker$call <- list(run_id = run_id, names = names, started = Sys.time(), limit_s = limit_s)
    }
    status
}

# NULL while the batch is in flight. Then list(run_id, names, bodies, elapsed):
# one body per name, NULL for a name without an answer. A batch past the
# limit ends the worker, and all its names come back without an answer.
names_worker_poll <- function(worker, limit_s = NULL) {
    call <- worker$call
    if (is.null(call)) {
        return(NULL)
    }
    limit_s <- limit_s %||% call$limit_s %||% NAMES_WORKER_CALL_LIMIT_S
    elapsed <- as.numeric(difftime(Sys.time(), call$started, units = "secs"))
    unanswered <- vector("list", length(call$names))
    state <- tryCatch(worker$session$poll_process(0), error = function(e) "dead")
    if (identical(state, "ready")) {
        msg <- tryCatch(worker$session$read(), error = function(e) NULL)
        # Other message codes are output of the R process, not the result.
        if (!is.null(msg) && !identical(msg$code, 200L) && is.null(msg$error)) {
            return(NULL)
        }
        worker$call <- NULL
        bodies <- if (is.null(msg) || !is.null(msg$error)) unanswered else msg$result
        return(list(run_id = call$run_id, names = call$names, bodies = bodies, elapsed = elapsed))
    }
    if (identical(state, "dead") || elapsed > limit_s) {
        names_worker_stop(worker)
        return(list(run_id = call$run_id, names = call$names, bodies = unanswered, elapsed = elapsed))
    }
    NULL
}

# The GBIF step of one tick of a names run. NULL while the worker has a batch,
# and the tick then waits. Else the fetch for the step: answers come from the
# memo, and a name without one stays unchecked. The worker alone holds the
# batch, the run that sent it and the network budget of that run, so a
# change of run, a cancel or the budget cannot leave a batch without owner.
names_worker_fetch <- function(worker, run_id, misses,
                               budget_s = NAMES_RUN_NETWORK_BUDGET_S,
                               start = names_worker_start, poll = names_worker_poll) {
    if (!identical(worker$run_id, run_id)) {
        # An answer for an older run never reaches this one.
        names_worker_cancel(worker)
        worker$run_id <- run_id
        worker$run_started <- Sys.time()
    }
    left <- budget_s - as.numeric(difftime(Sys.time(), worker$run_started, units = "secs"))
    if (is.null(worker$call)) {
        if (left <= 0) {
            return(gbif_offline_fetch)
        }
        # A worker that does not start leaves the names unchecked. The app
        # session does not send them itself, because it cannot stop a wait.
        sent <- start(worker, run_id, misses, limit_s = min(NAMES_WORKER_CALL_LIMIT_S, left))
        if (identical(sent, "failed")) {
            return(gbif_offline_fetch)
        }
        return(NULL)
    }
    done <- poll(worker)
    if (is.null(done)) {
        return(NULL)
    }
    # An answer that the parser cannot read is an error of the provider, as
    # when the app session sends the requests.
    failed <- tryCatch({
        colxr_store_bodies(done$names, done$bodies)
        NULL
    }, error = function(e) conditionMessage(e))
    if (!is.null(failed)) {
        return(function(requests) stop(failed, call. = FALSE))
    }
    # The answer was for an earlier batch that the memo already had. The next
    # tick sends the names of this batch.
    if (length(setdiff(misses, done$names))) {
        return(NULL)
    }
    gbif_offline_fetch
}

# End the batch of a run that stops: stale, reset or done. The worker
# process ends only when it has a batch.
names_worker_cancel <- function(worker) {
    if (!is.null(worker$call)) {
        names_worker_stop(worker)
    }
    worker$run_id <- NULL
    worker$run_started <- NULL
    invisible(NULL)
}

names_worker_stop <- function(worker) {
    if (!is.null(worker$session)) {
        try(worker$session$kill(), silent = TRUE)
    }
    worker$session <- NULL
    worker$call <- NULL
    invisible(NULL)
}
