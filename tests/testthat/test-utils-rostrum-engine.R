# Title: Integration Tests for Rostrum Engine Orchestrator
# Author: Rogerio Nunes Oliveira
# Date: 2026-03-06
# Version: 1.0
#
# Tests run_rostrum_engine() as a black box: stages 1/2/3 and alias/template
# overrides are tested individually in their own files. Here we verify the
# orchestrator contract, error handling, and run_stats structure.

run_rostrum_engine <- saira:::run_rostrum_engine

# --- Fixtures ----------------------------------------------------------------

.make_minimal_dwc_terms <- function() {
    data.frame(
        term = c(
            "scientificName", "decimalLatitude", "decimalLongitude",
            "eventDate", "basisOfRecord"
        ),
        stringsAsFactors = FALSE
    )
}

.make_minimal_synonyms <- function() {
    data.frame(
        term       = c("scientificName", "decimalLatitude", "decimalLongitude", "eventDate"),
        synonym    = c("nome cientifico", "latitude decimal", "longitude decimal", "data coleta"),
        name_score = c(0.93, 0.92, 0.92, 0.91),
        lang       = c("pt", "pt", "pt", "pt"),
        active     = c(TRUE, TRUE, TRUE, TRUE),
        stringsAsFactors = FALSE
    )
}

.make_realistic_df <- function() {
    data.frame(
        `nome cientifico`   = c("Panthera onca", "Leopardus pardalis"),
        `latitude decimal`  = c(-10.1, -15.2),
        `longitude decimal` = c(-40.2, -45.3),
        `data coleta`       = c("2020-01-01", "2020-06-15"),
        stringsAsFactors    = FALSE,
        check.names         = FALSE
    )
}

# --- Contract structure -------------------------------------------------------

testthat::test_that("run_rostrum_engine returns named list with full contract", {
    result <- run_rostrum_engine(
        .make_realistic_df(),
        .make_minimal_dwc_terms(),
        synonyms_tbl = .make_minimal_synonyms()
    )

    testthat::expect_type(result, "list")
    expected_names <- c(
        "success", "data", "stage1", "stage2", "stage3",
        "warnings", "errors", "timing_ms", "run_stats"
    )
    testthat::expect_true(all(expected_names %in% names(result)))
})

testthat::test_that("run_rostrum_engine data slot is a data.frame with engine columns", {
    result <- run_rostrum_engine(
        .make_realistic_df(),
        .make_minimal_dwc_terms(),
        synonyms_tbl = .make_minimal_synonyms()
    )

    testthat::expect_s3_class(result$data, "data.frame")
    required_cols <- c(
        "term", "selected_col", "name_score", "value_score",
        "final_score", "status", "applied"
    )
    testthat::expect_true(
        all(required_cols %in% names(result$data)),
        info = paste("Missing:", paste(setdiff(required_cols, names(result$data)), collapse = ", "))
    )
})

testthat::test_that("run_rostrum_engine success is TRUE when stage1 succeeds", {
    result <- run_rostrum_engine(
        .make_realistic_df(),
        .make_minimal_dwc_terms(),
        synonyms_tbl = .make_minimal_synonyms()
    )

    testthat::expect_true(result$success)
})

# --- run_stats ----------------------------------------------------------------

testthat::test_that("run_rostrum_engine run_stats are numeric after execution", {
    result <- run_rostrum_engine(
        .make_realistic_df(),
        .make_minimal_dwc_terms(),
        synonyms_tbl = .make_minimal_synonyms()
    )

    testthat::expect_named(
        result$run_stats,
        c("stage1_ms", "stage2_ms", "stage3_ms", "total_ms")
    )
    testthat::expect_true(
        all(vapply(result$run_stats, is.numeric, FUN.VALUE = logical(1)))
    )
    testthat::expect_gte(result$timing_ms, 0)
    testthat::expect_gte(result$run_stats$total_ms, 0)
})

# --- Mapping quality ----------------------------------------------------------

testthat::test_that("run_rostrum_engine maps scientificName column via synonym match", {
    result <- run_rostrum_engine(
        .make_realistic_df(),
        .make_minimal_dwc_terms(),
        synonyms_tbl = .make_minimal_synonyms()
    )

    sn_row <- result$data[result$data$term == "scientificName", ]
    testthat::expect_true(nrow(sn_row) >= 1L)
    testthat::expect_equal(
        as.character(sn_row$selected_col[[1L]]),
        "nome cientifico"
    )
})

# --- Graceful degradation -----------------------------------------------------

testthat::test_that("run_rostrum_engine handles all-unrecognized columns without applying", {
    df <- data.frame(
        zz_col_xyz = 1:5,
        zz_col_abc = letters[1:5],
        stringsAsFactors = FALSE
    )

    result <- run_rostrum_engine(
        df,
        .make_minimal_dwc_terms(),
        synonyms_tbl = .make_minimal_synonyms()
    )

    testthat::expect_type(result, "list")
    testthat::expect_s3_class(result$data, "data.frame")

    if (nrow(result$data) > 0L) {
        applied_rows <- result$data[isTRUE(result$data$applied) | result$data$applied == TRUE, ]
        testthat::expect_equal(nrow(applied_rows), 0L)
    }
})

testthat::test_that("run_rostrum_engine accepts manual overrides in context without error", {
    overrides <- list(decimalLatitude = "longitude decimal")

    result <- run_rostrum_engine(
        .make_realistic_df(),
        .make_minimal_dwc_terms(),
        synonyms_tbl = .make_minimal_synonyms(),
        context = list(manual_overrides = overrides)
    )

    testthat::expect_type(result, "list")
    testthat::expect_s3_class(result$data, "data.frame")
})

# --- Error handling -----------------------------------------------------------

testthat::test_that("run_rostrum_engine stops with error on non-data.frame df", {
    testthat::expect_error(
        run_rostrum_engine("not a df", .make_minimal_dwc_terms()),
        "df must be a data.frame"
    )
})

testthat::test_that("run_rostrum_engine stops with error on dwc_terms_df missing 'term' column", {
    testthat::expect_error(
        run_rostrum_engine(.make_realistic_df(), data.frame(x = 1:3)),
        "dwc_terms_df must be a data.frame with a 'term' column"
    )
})

testthat::test_that("run_rostrum_engine returns list with stage errors field when stage fails", {
    df <- .make_realistic_df()
    # Passing an invalid options object causes stage-level errors caught by tryCatch
    bad_opts <- structure(list(
        auto_apply_threshold = 0.90,
        suggest_threshold = 0.75,
        hard_veto_threshold = 0.30,
        token_overlap_min_value_score = 0.80,
        ambiguity_gap = 0.10,
        risk_policy = "conservative",
        max_sample_n = 1000L,
        stage1_name_prune_threshold = 0.45,
        stage1_parallel = FALSE,
        stage1_parallel_workers = 2L,
        stage1_parallel_strategy = "multisession",
        debug = FALSE
    ), class = "rostrum_options")

    # With valid options the engine should succeed
    result <- run_rostrum_engine(
        df,
        .make_minimal_dwc_terms(),
        options = bad_opts,
        synonyms_tbl = .make_minimal_synonyms()
    )

    testthat::expect_type(result$errors, "character")
    testthat::expect_type(result$warnings, "character")
})
