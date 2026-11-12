# Title: Tests for the IUCN lookup of the Export tab (ADR-213)
# Author: Rogerio Nunes Oliveira
#
# The names worker sends the requests to a local HTTP server that answers
# with the recorded COL XR fixtures, slowly for a "Slow" name and with 503
# for a "Down" name.

local_colxr_server <- function(env = parent.frame()) {
    port <- httpuv::randomPort()
    server <- callr::r_bg(function(port, dir) {
        httpuv::runServer("127.0.0.1", port, list(call = function(req) {
            name <- utils::URLdecode(sub(".*scientificName=([^&]*).*", "\\1", req$QUERY_STRING))
            name <- gsub("+", " ", name, fixed = TRUE)
            if (startsWith(name, "Down")) {
                return(list(status = 503L, headers = list("Content-Type" = "application/json"), body = "{}"))
            }
            if (startsWith(name, "Slow")) {
                Sys.sleep(2)
                name <- "Pantera onca"
            }
            file <- file.path(dir, paste0(gsub(" ", "_", name), ".json"))
            list(status = 200L, headers = list("Content-Type" = "application/json"),
                 body = paste(readLines(file, warn = FALSE), collapse = "\n"))
        }))
    }, args = list(port = port, dir = normalizePath(testthat::test_path("fixtures", "colxr"))))
    withr::defer(server$kill(), envir = env)
    base <- sprintf("http://127.0.0.1:%d/v2", port)
    for (i in 1:50) {
        up <- tryCatch({
            httr2::req_perform(httr2::request(paste0(base, "/species/match?scientificName=Panthera+onca")))
            TRUE
        }, error = function(e) FALSE)
        if (up) break
        Sys.sleep(0.2)
    }
    base
}

# The job of the worker, sent to the local server.
local_worker_start <- function(base) {
    job <- eval(bquote(function(names, source_path) {
        if (!"saira" %in% loadedNamespaces()) {
            if (is.null(source_path)) {
                loadNamespace("saira")
            } else {
                pkgload::load_all(source_path, quiet = TRUE, export_all = FALSE)
            }
        }
        ns <- asNamespace("saira")
        utils::assignInNamespace("GBIF_API_BASE", .(base), ns = "saira")
        ns$gbif_api_get_many(lapply(names, ns$colxr_match_request))
    }))
    function(worker, run_id, names, limit_s) {
        saira:::names_worker_start(worker, run_id, names, job = job, limit_s = limit_s)
    }
}

# A worker that has loaded saira, so the budget of a run is not spent there.
warm_worker <- function(env = parent.frame()) {
    worker <- saira:::names_worker_new()
    withr::defer(saira:::names_worker_stop(worker), envir = env)
    saira:::names_worker_warm(worker)
    for (i in 1:600) {
        if (identical(worker$session$poll_process(100), "ready")) break
    }
    worker$session$read()
    worker
}

testthat::test_that("the Export IUCN lookup keeps the session free and drops the answers of old names", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("httpuv")
    saira:::colxr_match_cache$reset()
    withr::defer(saira:::colxr_match_cache$reset())
    start <- local_worker_start(local_colxr_server())
    worker <- warm_worker()

    names_rv <- shiny::reactiveVal(c("Slow genus", "Slow other"))
    module <- function(id) {
        shiny::moduleServer(id, function(input, output, session) {
            iucn <- saira:::mount_export_iucn(input, session, names_r = names_rv,
                                              include_r = function() TRUE, worker = worker,
                                              budget_s = 30, start = start)
        })
    }
    shiny::testServer(module, {
        tick <- function() {
            t0 <- Sys.time()
            session$elapse(100)
            as.numeric(difftime(Sys.time(), t0, units = "secs"))
        }
        run_until_done <- function(max_s = 30) {
            slowest <- 0
            t0 <- Sys.time()
            while (identical(iucn()$status, "pending") &&
                   difftime(Sys.time(), t0, units = "secs") < max_s) {
                slowest <- max(slowest, tick())
                Sys.sleep(0.05)
            }
            slowest
        }

        session$flushReact()
        tick()
        testthat::expect_identical(iucn()$status, "pending")
        testthat::expect_identical(iucn()$total, 2L)

        # A new name review while the slow batch waits.
        names_rv(c("Panthera onca", "Caesalpinia echinata"))
        session$flushReact()
        slowest <- run_until_done()
        # The server sleeps 2 s per slow name, and no tick waits for it.
        testthat::expect_lt(slowest, 1)
        testthat::expect_identical(iucn()$status, "done")
        testthat::expect_identical(
            iucn()$snapshot, c("Caesalpinia echinata" = "EN", "Panthera onca" = "NT")
        )
    })
})

testthat::test_that("the Export IUCN lookup offers a retry or an export without IUCN when GBIF does not answer", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("httpuv")
    saira:::colxr_match_cache$reset()
    withr::defer(saira:::colxr_match_cache$reset())
    start <- local_worker_start(local_colxr_server())
    worker <- warm_worker()

    module <- function(id) {
        shiny::moduleServer(id, function(input, output, session) {
            iucn <- saira:::mount_export_iucn(input, session,
                                              names_r = shiny::reactive("Down genus"),
                                              include_r = function() TRUE, worker = worker,
                                              budget_s = 8, start = start)
        })
    }
    shiny::testServer(module, {
        run_until_done <- function(max_s = 30) {
            t0 <- Sys.time()
            while (identical(iucn()$status, "pending") &&
                   difftime(Sys.time(), t0, units = "secs") < max_s) {
                session$elapse(100)
                Sys.sleep(0.05)
            }
        }
        session$flushReact()
        run_until_done()
        testthat::expect_identical(iucn()$status, "failed")
        testthat::expect_identical(iucn()$unanswered, 1L)
        testthat::expect_identical(iucn()$snapshot, c("Down genus" = NA_character_))

        session$setInputs(go_iucn_skip = 1)
        testthat::expect_identical(iucn()$status, "skipped")
        session$setInputs(go_iucn_undo = 1)
        testthat::expect_identical(iucn()$status, "failed")
        session$setInputs(go_iucn_retry = 1)
        testthat::expect_identical(iucn()$status, "pending")
        run_until_done()
        testthat::expect_identical(iucn()$status, "failed")
    })
})

testthat::test_that("the Export IUCN lookup offers the choice when GBIF stops answering, and a skip keeps the answers", {
    testthat::skip_on_cran()
    testthat::skip_if_not_installed("httpuv")
    saira:::colxr_match_cache$reset()
    withr::defer(saira:::colxr_match_cache$reset())
    start <- local_worker_start(local_colxr_server())
    worker <- warm_worker()
    # The Names run already has the answer for Panthera onca.
    saira:::colxr_match_names("Panthera onca", fetch = function(requests) {
        list(jsonlite::read_json(testthat::test_path("fixtures", "colxr", "Panthera_onca.json")))
    })

    module <- function(id) {
        shiny::moduleServer(id, function(input, output, session) {
            iucn <- saira:::mount_export_iucn(input, session,
                                              names_r = shiny::reactive(c("Panthera onca", "Slow genus")),
                                              include_r = function() TRUE, worker = worker,
                                              budget_s = 30, stall_s = 0.5, start = start)
        })
    }
    shiny::testServer(module, {
        wait_for <- function(ok, max_s = 10) {
            t0 <- Sys.time()
            while (!isTRUE(ok()) && difftime(Sys.time(), t0, units = "secs") < max_s) {
                session$elapse(100)
                Sys.sleep(0.05)
            }
        }
        session$flushReact()
        session$elapse(100)
        testthat::expect_identical(iucn()$status, "pending")
        testthat::expect_false(iucn()$stalled)

        # The server holds the slow name for 2 s, past the stall limit.
        wait_for(function() isTRUE(iucn()$stalled))
        testthat::expect_identical(iucn()$status, "pending")
        testthat::expect_true(iucn()$stalled)

        session$setInputs(go_iucn_retry = 1)
        testthat::expect_identical(iucn()$status, "pending")
        testthat::expect_false(iucn()$stalled)
        wait_for(function() isTRUE(iucn()$stalled))

        session$setInputs(go_iucn_skip = 1)
        testthat::expect_identical(iucn()$status, "skipped")
        testthat::expect_identical(iucn()$unanswered, 1L)
        testthat::expect_identical(iucn()$snapshot, c("Panthera onca" = "NT", "Slow genus" = NA))
        testthat::expect_null(worker$call)
    })
})
