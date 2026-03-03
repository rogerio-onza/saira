rostrum_compose_eventdate_values <- saira:::rostrum_compose_eventdate_values
rostrum_stage2_compositions <- saira:::rostrum_stage2_compositions
rostrum_stage3_resolve <- saira:::rostrum_stage3_resolve

make_stage_row <- function(
    term,
    selected_col = NA_character_,
    status = "MANUAL",
    reason = "no_confident_match",
    final_score = 0,
    applied = FALSE,
    name_score = 0.5,
    value_score = 0.5
) {
    data.frame(
        term = term,
        selected_col = selected_col,
        name_score = as.numeric(name_score),
        value_score = as.numeric(value_score),
        penalty_score = 0,
        veto_code = "",
        final_score = as.numeric(final_score),
        status = status,
        reason = reason,
        applied = applied,
        alternatives_json = "[]",
        explain_json = "{}",
        stringsAsFactors = FALSE
    )
}

testthat::test_that("scientificName is composed from genus + specificEpithet when absent", {
    stage1 <- do.call(rbind, list(
        make_stage_row("scientificName"),
        make_stage_row("genus", selected_col = "genus_col", status = "AUTO", reason = "exact_match", final_score = 0.95, applied = TRUE),
        make_stage_row("specificEpithet", selected_col = "specific_col", status = "AUTO", reason = "exact_match", final_score = 0.95, applied = TRUE)
    ))
    df <- data.frame(
        genus_col = c("Panthera", "Puma"),
        specific_col = c("onca", "concolor"),
        stringsAsFactors = FALSE
    )

    out <- rostrum_stage2_compositions(stage1_data = stage1, df = df, options = rostrum_options())
    idx <- which(out$data$term == "scientificName")

    testthat::expect_true(out$success)
    testthat::expect_identical(out$data$status[[idx]], "SUGERIDO")
    testthat::expect_identical(out$data$reason[[idx]], "composed_scientific_name")
    testthat::expect_false(out$data$applied[[idx]])
    testthat::expect_true(is.na(out$data$selected_col[[idx]]))
    testthat::expect_match(out$data$composed_from_json[[idx]], "genus")
    testthat::expect_match(out$data$composed_from_json[[idx]], "specificEpithet")
})

testthat::test_that("scientificName composition is skipped when scientificName is already mapped", {
    stage1 <- do.call(rbind, list(
        make_stage_row("scientificName", selected_col = "scientific_col", status = "AUTO", reason = "exact_match", final_score = 0.99, applied = TRUE),
        make_stage_row("genus", selected_col = "genus_col", status = "AUTO", reason = "exact_match", final_score = 0.95, applied = TRUE),
        make_stage_row("specificEpithet", selected_col = "specific_col", status = "AUTO", reason = "exact_match", final_score = 0.95, applied = TRUE)
    ))
    df <- data.frame(
        scientific_col = c("Panthera onca"),
        genus_col = c("Panthera"),
        specific_col = c("onca"),
        stringsAsFactors = FALSE
    )

    out <- rostrum_stage2_compositions(stage1_data = stage1, df = df, options = rostrum_options())
    idx <- which(out$data$term == "scientificName")

    testthat::expect_identical(out$data$selected_col[[idx]], "scientific_col")
    testthat::expect_identical(out$data$status[[idx]], "AUTO")
    testthat::expect_identical(out$data$reason[[idx]], "exact_match")
})

testthat::test_that("scientificName composition is skipped when manual override exists", {
    stage1 <- do.call(rbind, list(
        make_stage_row("scientificName"),
        make_stage_row("genus", selected_col = "genus_col", status = "AUTO", reason = "exact_match", final_score = 0.95, applied = TRUE),
        make_stage_row("specificEpithet", selected_col = "specific_col", status = "AUTO", reason = "exact_match", final_score = 0.95, applied = TRUE)
    ))
    df <- data.frame(
        genus_col = c("Panthera"),
        specific_col = c("onca"),
        stringsAsFactors = FALSE
    )

    out <- rostrum_stage2_compositions(
        stage1_data = stage1,
        df = df,
        options = rostrum_options(),
        context = list(manual_overrides = list(scientificName = "manual_col"))
    )
    idx <- which(out$data$term == "scientificName")

    testthat::expect_identical(out$data$status[[idx]], "MANUAL")
    testthat::expect_identical(out$data$reason[[idx]], "no_confident_match")
})

testthat::test_that("circularity guard blocks scientificName composition when source depends on scientificName", {
    stage1 <- do.call(rbind, list(
        make_stage_row("scientificName"),
        make_stage_row("genus", selected_col = "genus_col", status = "AUTO", reason = "exact_match", final_score = 0.95, applied = TRUE),
        make_stage_row("specificEpithet", selected_col = "specific_col", status = "AUTO", reason = "exact_match", final_score = 0.95, applied = TRUE)
    ))
    df <- data.frame(
        genus_col = c("Panthera"),
        specific_col = c("onca"),
        stringsAsFactors = FALSE
    )

    out <- rostrum_stage2_compositions(
        stage1_data = stage1,
        df = df,
        options = rostrum_options(),
        context = list(composed_from = list(genus = "scientificName"))
    )
    idx <- which(out$data$term == "scientificName")

    testthat::expect_identical(out$data$status[[idx]], "MANUAL")
    testthat::expect_true(any(grepl("circular", out$warnings, ignore.case = TRUE)))
})

testthat::test_that("eventDate composition builds strict ISO YYYY-MM-DD from year/month/day", {
    stage1 <- do.call(rbind, list(
        make_stage_row("eventDate"),
        make_stage_row("year", selected_col = "year_col", status = "AUTO", reason = "exact_match", final_score = 0.95, applied = TRUE),
        make_stage_row("month", selected_col = "month_col", status = "AUTO", reason = "exact_match", final_score = 0.95, applied = TRUE),
        make_stage_row("day", selected_col = "day_col", status = "AUTO", reason = "exact_match", final_score = 0.95, applied = TRUE)
    ))
    df <- data.frame(
        year_col = c("2024", "2026"),
        month_col = c("2", "03"),
        day_col = c("29", "01"),
        stringsAsFactors = FALSE
    )

    out <- rostrum_stage2_compositions(stage1_data = stage1, df = df, options = rostrum_options())
    idx <- which(out$data$term == "eventDate")
    explain <- jsonlite::fromJSON(out$data$explain_json[[idx]], simplifyVector = FALSE)

    testthat::expect_identical(out$data$status[[idx]], "SUGERIDO")
    testthat::expect_identical(out$data$reason[[idx]], "composed_eventdate_ymd")
    testthat::expect_false(out$data$applied[[idx]])
    testthat::expect_true(is.na(out$data$selected_col[[idx]]))
    testthat::expect_equal(as.numeric(explain$stage2$valid_ratio), 1)
})

testthat::test_that("eventDate supports partial composition using year only", {
    stage1 <- do.call(rbind, list(
        make_stage_row("eventDate"),
        make_stage_row("year", selected_col = "year_col", status = "AUTO", reason = "exact_match", final_score = 0.95, applied = TRUE)
    ))
    df <- data.frame(
        year_col = c("2024", "2025"),
        stringsAsFactors = FALSE
    )

    out <- rostrum_stage2_compositions(stage1_data = stage1, df = df, options = rostrum_options())
    idx <- which(out$data$term == "eventDate")

    testthat::expect_identical(out$data$reason[[idx]], "composed_eventdate_partial")
    testthat::expect_identical(out$data$selected_col[[idx]], "year_col")
    testthat::expect_true(out$data$applied[[idx]])
})

testthat::test_that("eventDate composition is rejected when validation ratio is below hard veto threshold", {
    stage1 <- do.call(rbind, list(
        make_stage_row("eventDate"),
        make_stage_row("year", selected_col = "year_col", status = "AUTO", reason = "exact_match", final_score = 0.95, applied = TRUE),
        make_stage_row("month", selected_col = "month_col", status = "AUTO", reason = "exact_match", final_score = 0.95, applied = TRUE),
        make_stage_row("day", selected_col = "day_col", status = "AUTO", reason = "exact_match", final_score = 0.95, applied = TRUE)
    ))
    df <- data.frame(
        year_col = c("2023", "2023", "2023"),
        month_col = c("2", "13", "2"),
        day_col = c("29", "01", "31"),
        stringsAsFactors = FALSE
    )

    out <- rostrum_stage2_compositions(stage1_data = stage1, df = df, options = rostrum_options())
    idx <- which(out$data$term == "eventDate")

    testthat::expect_identical(out$data$status[[idx]], "MANUAL")
    testthat::expect_identical(out$data$reason[[idx]], "no_confident_match")
    testthat::expect_true(any(grepl("low validation ratio", out$warnings, ignore.case = TRUE)))
})

testthat::test_that("eventDate leap year validation accepts 2024-02-29 and rejects 2023-02-29", {
    df <- data.frame(
        y = c("2024", "2023"),
        m = c("2", "2"),
        d = c("29", "29"),
        stringsAsFactors = FALSE
    )

    out <- rostrum_compose_eventdate_values(
        df = df,
        source_columns = list(year = "y", month = "m", day = "d")
    )

    testthat::expect_identical(out$values[[1]], "2024-02-29")
    testthat::expect_true(is.na(out$values[[2]]))
    testthat::expect_true(out$valid_mask[[1]])
    testthat::expect_false(out$valid_mask[[2]])
})

testthat::test_that("Stage 3.5 fallback maps primary term to verbatim term when eligible", {
    stage2 <- do.call(rbind, list(
        make_stage_row("decimalLatitude", selected_col = "lat_col", status = "AUTO", reason = "exact_match", final_score = 0.92, applied = TRUE),
        make_stage_row("verbatimLatitude")
    ))

    out <- rostrum_stage3_resolve(stage2_data = stage2, options = rostrum_options())
    idx <- which(out$data$term == "verbatimLatitude")

    testthat::expect_identical(out$data$selected_col[[idx]], "lat_col")
    testthat::expect_identical(out$data$status[[idx]], "SUGERIDO")
    testthat::expect_identical(out$data$reason[[idx]], "fallback_verbatim_from_primary")
    testthat::expect_true(out$data$applied[[idx]])
})

testthat::test_that("Stage 3.5 fallback does not override an existing verbatim mapping", {
    stage2 <- do.call(rbind, list(
        make_stage_row("decimalLatitude", selected_col = "lat_col", status = "AUTO", reason = "exact_match", final_score = 0.92, applied = TRUE),
        make_stage_row("verbatimLatitude", selected_col = "raw_lat_col", status = "AUTO", reason = "exact_match", final_score = 0.90, applied = TRUE)
    ))

    out <- rostrum_stage3_resolve(stage2_data = stage2, options = rostrum_options())
    idx <- which(out$data$term == "verbatimLatitude")

    testthat::expect_identical(out$data$selected_col[[idx]], "raw_lat_col")
    testthat::expect_identical(out$data$reason[[idx]], "exact_match")
})

testthat::test_that("Stage 3.5 fallback is skipped when primary score is below threshold", {
    stage2 <- do.call(rbind, list(
        make_stage_row("decimalLatitude", selected_col = "lat_col", status = "SUGERIDO", reason = "token_overlap", final_score = 0.70, applied = TRUE),
        make_stage_row("verbatimLatitude")
    ))

    out <- rostrum_stage3_resolve(stage2_data = stage2, options = rostrum_options())
    idx <- which(out$data$term == "verbatimLatitude")

    testthat::expect_true(is.na(out$data$selected_col[[idx]]))
    testthat::expect_identical(out$data$status[[idx]], "MANUAL")
    testthat::expect_identical(out$data$reason[[idx]], "no_confident_match")
})
