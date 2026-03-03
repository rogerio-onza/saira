score_token_overlap <- saira:::score_token_overlap
apply_semantic_penalties <- saira:::apply_semantic_penalties
compute_value_score <- saira:::compute_value_score
run_rostrum_stage1 <- saira:::run_rostrum_stage1

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

testthat::test_that("record favors recordNumber over recordedBy in token overlap scoring", {
    exact_like <- score_token_overlap("record", "recordNumber")
    substring_like <- score_token_overlap("record", "recordedBy")

    testthat::expect_gt(exact_like, substring_like)
})

testthat::test_that("token overlap candidate is rejected when value_score is below 0.8", {
    df <- data.frame(
        decimal_lat = c("-10", "220", "350", "x"),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(term = "decimalLatitude", stringsAsFactors = FALSE)

    out <- run_rostrum_stage1(df, dwc_terms, empty_synonyms(), options = rostrum_options())

    testthat::expect_identical(out$status[[1]], "MANUAL")
    testthat::expect_true(is.na(out$selected_col[[1]]))
})

testthat::test_that("token overlap candidate is accepted when value_score is at least 0.8", {
    df <- data.frame(
        decimal_lat = c("-10", "-20", "15", "0"),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(term = "decimalLatitude", stringsAsFactors = FALSE)

    out <- run_rostrum_stage1(df, dwc_terms, empty_synonyms(), options = rostrum_options())

    testthat::expect_true(out$status[[1]] %in% c("AUTO", "SUGERIDO", "AMBIGUO"))
    testthat::expect_identical(out$selected_col[[1]], "decimal_lat")
})

testthat::test_that("semantic penalties are capped at -0.5", {
    penalty <- apply_semantic_penalties("temp_depth_count_campo1", "decimalLatitude")

    testthat::expect_identical(penalty$score, -0.5)
})

testthat::test_that("value score uses hard veto when validation ratio is below 0.3", {
    bad_values <- c("220", "350", "999", "x")
    res <- compute_value_score(bad_values, term = "decimalLatitude", name_score = 1.0)

    testthat::expect_identical(res$score, 0)
    testthat::expect_identical(res$reason, "veto_low_validation")
})

testthat::test_that("empty columns still trigger veto pathway", {
    res <- compute_value_score(c("", " ", NA_character_), term = "decimalLatitude", name_score = 1.0)

    testthat::expect_identical(res$score, 0)
    testthat::expect_identical(res$reason, "empty_column")
})

testthat::test_that("final_score stays in [0,1] for random inputs", {
    set.seed(42)
    df <- data.frame(
        decimal_lat = as.character(runif(100, -120, 120)),
        sci_name = sample(c("Panthera onca", "Leopardus pardalis", "foo"), 100, replace = TRUE),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(
        term = c("decimalLatitude", "scientificName"),
        stringsAsFactors = FALSE
    )

    out <- run_rostrum_stage1(df, dwc_terms, empty_synonyms(), options = rostrum_options())
    finite_scores <- out$final_score[!is.na(out$final_score)]

    testthat::expect_true(all(finite_scores >= 0 & finite_scores <= 1))
})

testthat::test_that("error boundary preserves stage 1 when stage 2 fails", {
    df <- data.frame(
        scientificName = c("Panthera onca", "Leopardus pardalis"),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(term = "scientificName", stringsAsFactors = FALSE)

    res <- run_rostrum_engine(
        df = df,
        dwc_terms_df = dwc_terms,
        options = rostrum_options(),
        context = list(force_stage2_error = TRUE),
        synonyms_tbl = empty_synonyms()
    )

    testthat::expect_false(res$stage2$success)
    testthat::expect_true(is.data.frame(res$stage1$data))
    testthat::expect_identical(res$data, res$stage1$data)
})

testthat::test_that("type incompatible column triggers veto for numeric-only terms", {
    # Column named exactly "decimalLatitude" (exact name match, score=1.0)
    # with mostly non-numeric values: numeric_ratio < 0.60 -> compatible_type=FALSE
    # and valid_ratio = 1/3 >= 0.30 so veto_low_validation does NOT fire.
    # resolve_candidate_veto_code must return "type_incompatible".
    df <- data.frame(
        decimalLatitude = c("-45", "north", "south"),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(term = "decimalLatitude", stringsAsFactors = FALSE)

    out <- run_rostrum_stage1(df, dwc_terms, empty_synonyms(), options = rostrum_options())

    testthat::expect_identical(out$veto_code[[1]], "type_incompatible")
    testthat::expect_identical(out$status[[1]], "MANUAL")
    testthat::expect_identical(out$final_score[[1]], 0)
})

testthat::test_that("temperature context penalty reduces latitude mapping score below AUTO", {
    # "lat_temperatura": token "lat" is a substring of "latitude" (token overlap
    # score ~0.51, which is >= 0.45 so value scoring IS triggered).
    # With all valid lat values, value_score = 1.0 and H1 gate does not fire
    # (1.0 >= 0.80). "temperatura" as a whole word triggers the -0.30 semantic
    # penalty. Combined: ~0.76 - 0.30 = ~0.46 -> final_score below AUTO (0.90).
    set.seed(1L)
    df <- data.frame(
        lat_temperatura = as.character(runif(50, -89, 89)),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(term = "decimalLatitude", stringsAsFactors = FALSE)

    out <- run_rostrum_stage1(df, dwc_terms, empty_synonyms(), options = rostrum_options())

    testthat::expect_true(
        is.na(out$final_score[[1]]) || out$final_score[[1]] < 0.90,
        info = paste("final_score was", out$final_score[[1]])
    )
    testthat::expect_false(isTRUE(out$status[[1]] == "AUTO"))
})

testthat::test_that("stage1 parallel multisession matches sequential decisions", {
    testthat::skip_if_not_installed("future")
    testthat::skip_if_not_installed("furrr")

    set.seed(99)
    df <- data.frame(
        scientificName = sample(c("Panthera onca", "Leopardus pardalis", "foo"), 200, replace = TRUE),
        scientific_name = sample(c("Panthera onca", "Leopardus pardalis", "foo"), 200, replace = TRUE),
        decimalLatitude = as.character(runif(200, -89, 89)),
        decimal_lat = as.character(runif(200, -89, 89)),
        recorded_by = sample(c("Ana", "Bruno", "Carlos"), 200, replace = TRUE),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(
        term = c("scientificName", "decimalLatitude", "recordedBy"),
        stringsAsFactors = FALSE
    )

    seq_out <- run_rostrum_stage1(
        df = df,
        dwc_terms_df = dwc_terms,
        synonyms_tbl = empty_synonyms(),
        options = rostrum_options(stage1_parallel = FALSE)
    )
    par_out <- run_rostrum_stage1(
        df = df,
        dwc_terms_df = dwc_terms,
        synonyms_tbl = empty_synonyms(),
        options = rostrum_options(
            stage1_parallel = TRUE,
            stage1_parallel_workers = 2L,
            stage1_parallel_strategy = "multisession"
        )
    )

    seq_cmp <- seq_out[order(seq_out$term), , drop = FALSE]
    par_cmp <- par_out[order(par_out$term), , drop = FALSE]

    testthat::expect_identical(seq_cmp$term, par_cmp$term)
    testthat::expect_identical(seq_cmp$selected_col, par_cmp$selected_col)
    testthat::expect_equal(seq_cmp$final_score, par_cmp$final_score, tolerance = 1e-12)
    testthat::expect_identical(seq_cmp$status, par_cmp$status)
    testthat::expect_identical(seq_cmp$reason, par_cmp$reason)
})
