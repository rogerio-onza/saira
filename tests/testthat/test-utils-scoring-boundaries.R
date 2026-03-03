score_ratio_to_confidence <- saira:::score_ratio_to_confidence
validate_numeric_range <- saira:::validate_numeric_range
sample_values_for_scoring <- saira:::sample_values_for_scoring

testthat::test_that("score_ratio_to_confidence maps ratio directly to [0,1]", {
    testthat::expect_identical(score_ratio_to_confidence(0), 0)
    testthat::expect_identical(score_ratio_to_confidence(1), 1)
})

testthat::test_that("score_ratio_to_confidence handles NaN without crash", {
    testthat::expect_no_error(score_ratio_to_confidence(NaN))
})

testthat::test_that("validate_numeric_range accepts exact coordinate boundaries", {
    lat_result <- validate_numeric_range(c("-90", "0", "90"), min_value = -90, max_value = 90)
    lon_result <- validate_numeric_range(c("-180", "0", "180"), min_value = -180, max_value = 180)

    testthat::expect_identical(lat_result$valid_ratio, 1)
    testthat::expect_identical(lat_result$compatible_type, TRUE)
    testthat::expect_identical(lon_result$valid_ratio, 1)
    testthat::expect_identical(lon_result$compatible_type, TRUE)
})

testthat::test_that("validate_numeric_range handles empty input vectors", {
    result <- validate_numeric_range(character(0), min_value = -90, max_value = 90)

    testthat::expect_identical(result$valid_ratio, 0)
    testthat::expect_identical(result$numeric_ratio, 0)
    testthat::expect_identical(result$compatible_type, FALSE)
    testthat::expect_identical(result$score, 0)
})

testthat::test_that("sample_values_for_scoring is deterministic for same input", {
    values <- sprintf("value_%04d", seq_len(300))

    sampled_1 <- sample_values_for_scoring(values, name_score = 0.90)
    sampled_2 <- sample_values_for_scoring(values, name_score = 0.90)

    testthat::expect_identical(sampled_1, sampled_2)
})

testthat::test_that("golden scoring fixture stays stable", {
    fixture_path <- testthat::test_path("fixtures", "scoring_golden_cases.rds")
    testthat::expect_true(file.exists(fixture_path))

    cases <- readRDS(fixture_path)
    testthat::expect_length(cases, 30L)

    for (case in cases) {
        fn <- get(case$fn, envir = asNamespace("saira"), inherits = FALSE)
        observed <- do.call(fn, case$args)
        testthat::expect_equal(observed, case$expected, tolerance = 1e-8, info = case$id)
    }
})
