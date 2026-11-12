testthat::test_that("the worker returns the bodies of a batch and tags them with the run", {
    testthat::skip_on_cran()
    worker <- names_worker_new()
    on.exit(names_worker_stop(worker), add = TRUE)
    job <- function(names) lapply(names, function(n) list(name = n))
    names_worker_warm(worker, load = function(source_path) NULL)
    sent <- "starting"
    for (i in seq_len(100)) {
        sent <- names_worker_start(worker, run_id = 7, names = c("A a", "B b"), job = job)
        if (!identical(sent, "starting")) break
        Sys.sleep(0.1)
    }
    testthat::expect_identical(sent, "sent")
    done <- NULL
    for (i in seq_len(100)) {
        done <- names_worker_poll(worker)
        if (!is.null(done)) break
        Sys.sleep(0.1)
    }
    testthat::expect_identical(done$run_id, 7)
    testthat::expect_identical(done$names, c("A a", "B b"))
    testthat::expect_identical(done$bodies[[2]]$name, "B b")
    testthat::expect_null(worker$call)
})

testthat::test_that("a batch past the limit ends the worker and comes back unanswered", {
    testthat::skip_on_cran()
    worker <- names_worker_new()
    on.exit(names_worker_stop(worker), add = TRUE)
    job <- function(names) {
        Sys.sleep(30)
        list()
    }
    names_worker_warm(worker, load = function(source_path) NULL)
    for (i in seq_len(100)) {
        if (!identical(names_worker_start(worker, run_id = 1, names = c("A a", "B b"), job = job), "starting")) break
        Sys.sleep(0.1)
    }
    testthat::expect_false(is.null(worker$call))
    testthat::expect_null(names_worker_poll(worker, limit_s = 60))
    done <- names_worker_poll(worker, limit_s = 0)
    testthat::expect_identical(done$bodies, list(NULL, NULL))
    testthat::expect_null(worker$session)
})

testthat::test_that("the memo keeps the fetched answers and the offline fetch sends nothing", {
    colxr_match_cache$reset()
    on.exit(colxr_match_cache$reset(), add = TRUE)
    body <- list(usage = list(name = "Puma concolor", rank = "SPECIES", status = "ACCEPTED"))
    testthat::expect_identical(colxr_unmemoized(c("Puma concolor", "Cebus apella")),
                               c("Puma concolor", "Cebus apella"))
    unanswered <- colxr_store_bodies(c("Puma concolor", "Cebus apella"), list(body, NULL))
    testthat::expect_identical(unanswered, "Cebus apella")
    testthat::expect_identical(colxr_unmemoized(c("Puma concolor", "Cebus apella")), "Cebus apella")
    out <- colxr_match_names(c("Puma concolor", "Cebus apella"), fetch = gbif_offline_fetch)
    testthat::expect_identical(out$query_name, "Puma concolor")
    testthat::expect_identical(attr(out, "unanswered"), "Cebus apella")
})

testthat::test_that("next_colxr_batch names only a GBIF batch", {
    state <- init_taxadb_run_state(data.frame(query_name = c("A a", "B b")), providers = "gbif", batch_size = 20L)
    testthat::expect_null(next_colxr_batch(state))
    state <- next_taxadb_run_step(state, adapters = list(poll = function() NULL))
    state <- next_taxadb_run_step(state, adapters = list(poll = function() NULL, load = function(...) list(data = NULL, error = NULL)))
    testthat::expect_identical(next_colxr_batch(state), c("A a", "B b"))
})

# A worker with a fake process. start and poll come as arguments.
fake_worker <- function(call = NULL, run_id = NULL, started_s_ago = 0) {
    worker <- names_worker_new()
    worker$session <- list(kill = function() NULL)
    worker$call <- call
    worker$run_id <- run_id
    if (!is.null(run_id)) worker$run_started <- Sys.time() - started_s_ago
    worker
}

testthat::test_that("a new run ends the batch of the run before it", {
    worker <- fake_worker(call = list(run_id = 1, names = "A a", started = Sys.time()), run_id = 1)
    kills <- 0L
    worker$session <- list(kill = function() kills <<- kills + 1L)
    sent <- NULL
    start <- function(worker, run_id, names, limit_s) {
        sent <<- list(run_id = run_id, names = names)
        "sent"
    }
    testthat::expect_null(names_worker_fetch(worker, 2, "B b", start = start))
    testthat::expect_identical(kills, 1L)
    testthat::expect_identical(sent, list(run_id = 2, names = "B b"))
    testthat::expect_identical(worker$run_id, 2)
})

testthat::test_that("a cancel ends the batch in flight and keeps an idle worker", {
    kills <- 0L
    worker <- fake_worker(call = list(run_id = 1, names = "A a", started = Sys.time()), run_id = 1)
    worker$session <- list(kill = function() kills <<- kills + 1L)
    names_worker_cancel(worker)
    testthat::expect_identical(kills, 1L)
    testthat::expect_null(worker$call)
    testthat::expect_null(worker$run_id)

    idle <- fake_worker(run_id = 1)
    idle$session <- list(kill = function() kills <<- kills + 1L)
    names_worker_cancel(idle)
    testthat::expect_identical(kills, 1L)
    testthat::expect_false(is.null(idle$session))
})

testthat::test_that("the answer of an earlier batch does not answer the next one", {
    colxr_match_cache$reset()
    on.exit(colxr_match_cache$reset(), add = TRUE)
    body <- list(usage = list(name = "Puma concolor", rank = "SPECIES", status = "ACCEPTED"))
    worker <- fake_worker(call = list(run_id = 1, names = "Puma concolor", started = Sys.time()), run_id = 1)
    poll <- function(worker) {
        call <- worker$call
        worker$call <- NULL
        list(run_id = call$run_id, names = call$names, bodies = list(body), elapsed = 0.1)
    }
    sent <- character(0)
    start <- function(worker, run_id, names, limit_s) {
        sent <<- c(sent, names)
        "sent"
    }
    # The run moved on to Panthera onca while Puma concolor was in flight.
    testthat::expect_null(names_worker_fetch(worker, 1, "Panthera onca", start = start, poll = poll))
    testthat::expect_identical(colxr_unmemoized("Puma concolor"), character(0))
    testthat::expect_null(names_worker_fetch(worker, 1, "Panthera onca", start = start, poll = poll))
    testthat::expect_identical(sent, "Panthera onca")
})

testthat::test_that("an answer the parser cannot read is an error of the provider", {
    colxr_match_cache$reset()
    on.exit(colxr_match_cache$reset(), add = TRUE)
    worker <- fake_worker(call = list(run_id = 1, names = "Puma concolor", started = Sys.time()), run_id = 1)
    poll <- function(worker) {
        worker$call <- NULL
        list(run_id = 1, names = "Puma concolor", bodies = list("text"), elapsed = 0.1)
    }
    fetch <- names_worker_fetch(worker, 1, "Puma concolor", poll = poll)
    testthat::expect_true(is.function(fetch))
    answer <- names_provider_query("Puma concolor", "gbif", "colxr", fetch = fetch)
    testthat::expect_false(is.null(answer$error))
})

testthat::test_that("the run budget limits the last batch and then sends nothing", {
    limit <- NULL
    start <- function(worker, run_id, names, limit_s) {
        limit <<- limit_s
        "sent"
    }
    worker <- fake_worker(run_id = 1, started_s_ago = 295)
    testthat::expect_null(names_worker_fetch(worker, 1, "A a", budget_s = 300, start = start))
    testthat::expect_lt(limit, 6)
    testthat::expect_gt(limit, 4)

    limit <- NULL
    spent <- fake_worker(run_id = 1, started_s_ago = 301)
    testthat::expect_identical(names_worker_fetch(spent, 1, "A a", budget_s = 300, start = start),
                               gbif_offline_fetch)
    testthat::expect_null(limit)
})

testthat::test_that("a worker that does not start leaves the names unchecked", {
    worker <- fake_worker(run_id = 1)
    start <- function(...) "failed"
    testthat::expect_identical(names_worker_fetch(worker, 1, "A a", start = start), gbif_offline_fetch)
})

testthat::test_that("a batch keeps its own limit when it is polled", {
    worker <- fake_worker(call = list(run_id = 1, names = "A a", started = Sys.time() - 10, limit_s = 5),
                          run_id = 1)
    worker$session <- list(poll_process = function(timeout) "timeout", kill = function() NULL)
    done <- names_worker_poll(worker)
    testthat::expect_identical(done$bodies, list(NULL))
    testthat::expect_null(worker$call)
})
