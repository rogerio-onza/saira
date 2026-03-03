run_rostrum_stage1 <- getFromNamespace("run_rostrum_stage1", "saira")
run_rostrum_engine <- getFromNamespace("run_rostrum_engine", "saira")
rostrum_stage2_compositions <- getFromNamespace("rostrum_stage2_compositions", "saira")
rostrum_stage3_resolve <- getFromNamespace("rostrum_stage3_resolve", "saira")
rostrum_options <- getFromNamespace("rostrum_options", "saira")

if (!identical(Sys.getenv("RUN_PERF"), "true")) {
    testthat::skip("Performance suite disabled by default. Use RUN_PERF=true to execute.")
}

build_perf_dataset <- function(rows_n = 20000L, cols_n = 50L) {
    set.seed(20260302L)
    out <- data.frame(
        scientificName = sample(
            c("Panthera onca", "Leopardus pardalis", "Tapirus terrestris"),
            rows_n,
            replace = TRUE
        ),
        decimalLatitude = as.character(runif(rows_n, -33, 5)),
        decimalLongitude = as.character(runif(rows_n, -74, -34)),
        year = sample(2000:2025, rows_n, replace = TRUE),
        month = sample(1:12, rows_n, replace = TRUE),
        day = sample(1:28, rows_n, replace = TRUE),
        stringsAsFactors = FALSE
    )

    extra_n <- max(0L, as.integer(cols_n) - ncol(out))
    if (extra_n > 0L) {
        for (i in seq_len(extra_n)) {
            out[[sprintf("noise_%02d", i)]] <- sample(LETTERS, rows_n, replace = TRUE)
        }
    }

    out
}

empty_synonyms <- function() {
    data.frame(
        term = character(0),
        synonym = character(0),
        name_score = numeric(0),
        lang = character(0),
        active = logical(0),
        stringsAsFactors = FALSE
    )
}

testthat::test_that("Performance regression: Stage 1 remains under 7.5s for 50x20k", {
    df <- build_perf_dataset(rows_n = 20000L, cols_n = 50L)
    dwc_terms <- load_dwc_terms_rds()

    elapsed <- unname(system.time({
        run_rostrum_stage1(
            df = df,
            dwc_terms_df = dwc_terms,
            synonyms_tbl = empty_synonyms(),
            options = rostrum_options(stage1_parallel = FALSE)
        )
    })[["elapsed"]])

    testthat::expect_lt(elapsed, 7.5)
})

testthat::test_that("Performance regression: Stage 2 stays under 2s for scientificName + eventDate", {
    df <- build_perf_dataset(rows_n = 20000L, cols_n = 50L)
    stage1_seed <- data.frame(
        term = c("scientificName", "genus", "specificEpithet", "eventDate", "year", "month", "day"),
        selected_col = c(NA_character_, "scientificName", "scientificName", NA_character_, "year", "month", "day"),
        name_score = c(0, 1, 1, 0, 1, 1, 1),
        value_score = c(0, 0.9, 0.9, 0, 0.9, 0.9, 0.9),
        penalty_score = c(0, 0, 0, 0, 0, 0, 0),
        veto_code = c("", "", "", "", "", "", ""),
        final_score = c(0, 1, 1, 0, 1, 1, 1),
        status = c("MANUAL", "AUTO", "AUTO", "MANUAL", "AUTO", "AUTO", "AUTO"),
        reason = c("no_confident_match", "exact_match", "exact_match", "no_confident_match", "exact_match", "exact_match", "exact_match"),
        applied = c(FALSE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE),
        alternatives_json = rep("[]", 7),
        explain_json = rep("{}", 7),
        stringsAsFactors = FALSE
    )

    elapsed <- unname(system.time({
        rostrum_stage2_compositions(
            stage1_data = stage1_seed,
            df = df,
            options = rostrum_options()
        )
    })[["elapsed"]])

    testthat::expect_lt(elapsed, 2)
})

testthat::test_that("Performance regression: Stage 3 stays under 0.5s for 50 terms", {
    terms <- sprintf("term_%02d", seq_len(50))
    stage2_data <- data.frame(
        term = terms,
        selected_col = rep("scientificName", 50),
        name_score = runif(50, 0.7, 1),
        value_score = runif(50, 0.7, 1),
        penalty_score = rep(0, 50),
        veto_code = rep("", 50),
        final_score = runif(50, 0.75, 1),
        status = rep("SUGERIDO", 50),
        reason = rep("token_overlap", 50),
        applied = rep(TRUE, 50),
        alternatives_json = rep(
            "[{\"column_name\":\"scientificName\",\"final_score\":0.9,\"name_score\":0.9,\"value_score\":0.9}]",
            50
        ),
        explain_json = rep("{}", 50),
        stringsAsFactors = FALSE
    )
    df <- build_perf_dataset(rows_n = 20000L, cols_n = 50L)

    elapsed <- unname(system.time({
        rostrum_stage3_resolve(
            stage2_data = stage2_data,
            df = df,
            options = rostrum_options()
        )
    })[["elapsed"]])

    testthat::expect_lt(elapsed, 0.5)
})

testthat::test_that("Performance regression: full pipeline stays under 8s", {
    df <- build_perf_dataset(rows_n = 20000L, cols_n = 50L)
    dwc_terms <- load_dwc_terms_rds()

    elapsed <- unname(system.time({
        run_rostrum_engine(
            df = df,
            dwc_terms_df = dwc_terms,
            options = rostrum_options(stage1_parallel = FALSE),
            synonyms_tbl = empty_synonyms()
        )
    })[["elapsed"]])

    testthat::expect_lt(elapsed, 8)
})
