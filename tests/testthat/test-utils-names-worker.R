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
