validate_composition_df <- saira:::validate_composition_df

testthat::test_that("adapt_synonyms_v1_to_v2 preserves rows and maps any to mul", {
    v1 <- data.frame(
        term = c("decimalLatitude", "eventDate", "recordedBy"),
        synonym = c("lat", "date", "collector"),
        name_score = c(0.95, 0.93, 0.90),
        lang = c("any", "en", "pt"),
        active = c(TRUE, TRUE, FALSE),
        stringsAsFactors = FALSE
    )

    out <- adapt_synonyms_v1_to_v2(v1, updated_at = "2026-03-01T00:00:00Z")

    testthat::expect_identical(nrow(out), nrow(v1))
    testthat::expect_identical(out$language[[1]], "mul")
    testthat::expect_identical(out$language[[2]], "en")
    testthat::expect_identical(out$language[[3]], "pt")
    testthat::expect_identical(out$context, rep("unknown", 3))
    testthat::expect_identical(out$notes, rep("Migrated from v1 RDS", 3))
    testthat::expect_true(all(out$confidence >= 0.90 & out$confidence <= 0.98))
})

testthat::test_that("rostrum_options has conservative defaults", {
    opts <- rostrum_options()

    testthat::expect_s3_class(opts, "rostrum_options")
    testthat::expect_identical(opts$auto_apply_threshold, 0.90)
    testthat::expect_identical(opts$suggest_threshold, 0.75)
    testthat::expect_identical(opts$hard_veto_threshold, 0.30)
    testthat::expect_identical(opts$risk_policy, "conservative")
    testthat::expect_identical(opts$stage1_name_prune_threshold, 0.45)
    testthat::expect_identical(opts$stage1_parallel, FALSE)
    testthat::expect_identical(opts$stage1_parallel_workers, 2L)
    testthat::expect_identical(opts$stage1_parallel_strategy, "multisession")
    testthat::expect_identical(opts$debug, FALSE)
})

testthat::test_that("validate_candidate_df rejects missing required columns", {
    bad_df <- data.frame(
        term = "decimalLatitude",
        column_name = "lat",
        stringsAsFactors = FALSE
    )

    testthat::expect_error(
        validate_candidate_df(bad_df),
        "missing required columns"
    )
})

testthat::test_that("validate_decision_df rejects wrong column types", {
    bad_df <- data.frame(
        term = "decimalLatitude",
        selected_col = "lat",
        status = "AUTO",
        score = "0.91",
        score_gap = 0.01,
        ambiguity_flag = FALSE,
        source = "auto",
        provenance_id = "run-1",
        stringsAsFactors = FALSE
    )

    testthat::expect_error(
        validate_decision_df(bad_df),
        "decision_df\\$score must be numeric"
    )
})

testthat::test_that("validate_composition_df rejects missing required columns", {
    bad_df <- data.frame(
        term = "scientificName",
        stringsAsFactors = FALSE
    )

    testthat::expect_error(
        validate_composition_df(bad_df),
        "missing required columns"
    )
})

testthat::test_that("validate_composition_df rejects wrong type for applied", {
    bad_df <- data.frame(
        term = "scientificName",
        selected_col = NA_character_,
        status = "SUGERIDO",
        reason = "composed_scientific_name",
        applied = "FALSE",
        composed_from_json = NA_character_,
        stringsAsFactors = FALSE
    )

    testthat::expect_error(
        validate_composition_df(bad_df),
        "composition_df\\$applied must be logical"
    )
})

testthat::test_that("validate_composition_df rejects unsupported status", {
    bad_df <- data.frame(
        term = "scientificName",
        selected_col = NA_character_,
        status = "UNKNOWN",
        reason = "composed_scientific_name",
        applied = FALSE,
        composed_from_json = NA_character_,
        stringsAsFactors = FALSE
    )

    testthat::expect_error(
        validate_composition_df(bad_df),
        "unsupported values"
    )
})

testthat::test_that("validate_composition_df accepts valid composition stage data", {
    good_df <- data.frame(
        term = c("scientificName", "eventDate"),
        selected_col = c(NA_character_, "year_col"),
        status = c("SUGERIDO", "SUGERIDO"),
        reason = c("composed_scientific_name", "composed_eventdate_partial"),
        applied = c(FALSE, TRUE),
        composed_from_json = c("[\"genus\",\"specificEpithet\"]", NA_character_),
        stringsAsFactors = FALSE
    )

    testthat::expect_true(validate_composition_df(good_df))
})
