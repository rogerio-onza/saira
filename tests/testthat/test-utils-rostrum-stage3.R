rostrum_stage3_resolve <- saira:::rostrum_stage3_resolve

make_stage3_row <- function(
    term,
    selected_col = NA_character_,
    status = "MANUAL",
    reason = "no_confident_match",
    final_score = 0,
    applied = FALSE,
    name_score = 0.5,
    value_score = 0.5,
    alternatives = list()
) {
    alternatives_json <- if (length(alternatives) == 0L) {
        "[]"
    } else {
        as.character(jsonlite::toJSON(alternatives, auto_unbox = TRUE, null = "null"))
    }

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
        alternatives_json = alternatives_json,
        explain_json = "{}",
        stringsAsFactors = FALSE
    )
}

testthat::test_that("two close candidates are marked AMBIGUO in stage 3", {
    stage2 <- make_stage3_row(
        term = "decimalLatitude",
        alternatives = list(
            list(column_name = "lat_a", final_score = 0.84, name_score = 0.84, value_score = 0.84),
            list(column_name = "lat_b", final_score = 0.80, name_score = 0.80, value_score = 0.80)
        )
    )
    df <- data.frame(
        lat_a = c("-10", "-20", "-30"),
        lat_b = c("-11", "-21", "-31"),
        stringsAsFactors = FALSE
    )

    out <- rostrum_stage3_resolve(
        stage2_data = stage2,
        df = df,
        options = rostrum_options()
    )

    testthat::expect_identical(out$data$status[[1]], "AMBIGUO")
    testthat::expect_true(is.na(out$data$selected_col[[1]]))
    testthat::expect_identical(out$data$reason[[1]], "ambiguity_detected")
})

testthat::test_that("higher score wins when gap is at least 0.1", {
    stage2 <- make_stage3_row(
        term = "decimalLatitude",
        alternatives = list(
            list(column_name = "lat_best", final_score = 0.92, name_score = 0.92, value_score = 0.92),
            list(column_name = "lat_other", final_score = 0.80, name_score = 0.80, value_score = 0.80)
        )
    )
    df <- data.frame(
        lat_best = c("-10", "-20", "-30"),
        lat_other = c("-11", "-21", "-31"),
        stringsAsFactors = FALSE
    )

    out <- rostrum_stage3_resolve(
        stage2_data = stage2,
        df = df,
        options = rostrum_options()
    )

    testthat::expect_identical(out$data$selected_col[[1]], "lat_best")
    testthat::expect_true(out$data$status[[1]] %in% c("AUTO", "SUGERIDO"))
})

testthat::test_that("stage 3 conflict resolution is deterministic across repeated runs", {
    stage2 <- do.call(rbind, list(
        make_stage3_row(
            term = "decimalLatitude",
            selected_col = "coord_col",
            status = "SUGERIDO",
            reason = "token_overlap",
            final_score = 0.88,
            applied = TRUE,
            name_score = 0.78,
            value_score = 0.98,
            alternatives = list(
                list(column_name = "coord_col", final_score = 0.88, name_score = 0.78, value_score = 0.98),
                list(column_name = "coord_aux", final_score = 0.78, name_score = 0.74, value_score = 0.82)
            )
        ),
        make_stage3_row(
            term = "verbatimLatitude",
            selected_col = "coord_col",
            status = "SUGERIDO",
            reason = "token_overlap",
            final_score = 0.88,
            applied = TRUE,
            name_score = 0.88,
            value_score = 0.88,
            alternatives = list(
                list(column_name = "coord_col", final_score = 0.88, name_score = 0.88, value_score = 0.88)
            )
        )
    ))
    df <- data.frame(
        coord_col = c("-10", "-20", "-30", "-40"),
        coord_aux = c("10", "20", "30", "40"),
        stringsAsFactors = FALSE
    )

    snapshots <- replicate(
        100,
        {
            out <- rostrum_stage3_resolve(stage2_data = stage2, df = df, options = rostrum_options())
            paste(out$data$term, out$data$selected_col, out$data$status, sep = "::", collapse = "|")
        }
    )

    testthat::expect_identical(length(unique(snapshots)), 1L)
})

testthat::test_that("loser candidate maps to related verbatim term when eligible", {
    stage2 <- do.call(rbind, list(
        make_stage3_row(
            term = "decimalLatitude",
            alternatives = list(
                list(column_name = "lat_clean", final_score = 0.93, name_score = 0.90, value_score = 0.96),
                list(column_name = "lat_raw", final_score = 0.78, name_score = 0.76, value_score = 0.80)
            )
        ),
        make_stage3_row(term = "verbatimLatitude")
    ))
    df <- data.frame(
        lat_clean = c("-10", "-20", "-30"),
        lat_raw = c("-10,20S", "-20,12S", "-30,50S"),
        stringsAsFactors = FALSE
    )

    out <- rostrum_stage3_resolve(
        stage2_data = stage2,
        df = df,
        options = rostrum_options()
    )
    idx <- which(out$data$term == "verbatimLatitude")

    testthat::expect_identical(out$data$selected_col[[idx]], "lat_raw")
    testthat::expect_identical(out$data$reason[[idx]], "fallback_verbatim_from_loser")
})

testthat::test_that("loser candidate is not mapped when loser score is below 0.75", {
    stage2 <- do.call(rbind, list(
        make_stage3_row(
            term = "decimalLatitude",
            alternatives = list(
                list(column_name = "lat_clean", final_score = 0.93, name_score = 0.90, value_score = 0.96),
                list(column_name = "lat_raw", final_score = 0.70, name_score = 0.70, value_score = 0.70)
            )
        ),
        make_stage3_row(term = "verbatimLatitude")
    ))
    df <- data.frame(
        lat_clean = c("-10", "-20", "-30"),
        lat_raw = c("-10,20S", "-20,12S", "-30,50S"),
        stringsAsFactors = FALSE
    )

    out <- rostrum_stage3_resolve(
        stage2_data = stage2,
        df = df,
        options = rostrum_options()
    )
    idx <- which(out$data$term == "verbatimLatitude")

    testthat::expect_true(is.na(out$data$selected_col[[idx]]))
    testthat::expect_identical(out$data$status[[idx]], "MANUAL")
})

testthat::test_that("loser candidate is not mapped when verbatim target is already occupied", {
    stage2 <- do.call(rbind, list(
        make_stage3_row(
            term = "decimalLatitude",
            alternatives = list(
                list(column_name = "lat_clean", final_score = 0.93, name_score = 0.90, value_score = 0.96),
                list(column_name = "lat_raw", final_score = 0.78, name_score = 0.76, value_score = 0.80)
            )
        ),
        make_stage3_row(
            term = "verbatimLatitude",
            selected_col = "existing_raw_lat",
            status = "AUTO",
            reason = "exact_match",
            final_score = 0.91,
            applied = TRUE,
            alternatives = list(
                list(column_name = "existing_raw_lat", final_score = 0.91, name_score = 0.91, value_score = 0.91)
            )
        )
    ))
    df <- data.frame(
        lat_clean = c("-10", "-20", "-30"),
        lat_raw = c("-10,20S", "-20,12S", "-30,50S"),
        existing_raw_lat = c("10S", "20S", "30S"),
        stringsAsFactors = FALSE
    )

    out <- rostrum_stage3_resolve(
        stage2_data = stage2,
        df = df,
        options = rostrum_options()
    )
    idx <- which(out$data$term == "verbatimLatitude")

    testthat::expect_identical(out$data$selected_col[[idx]], "existing_raw_lat")
    testthat::expect_identical(out$data$reason[[idx]], "exact_match")
})

testthat::test_that("cross-term conflict prefers numeric mapping for coordinate terms", {
    stage2 <- do.call(rbind, list(
        make_stage3_row(
            term = "decimalLatitude",
            selected_col = "coord_col",
            status = "SUGERIDO",
            reason = "token_overlap",
            final_score = 0.88,
            applied = TRUE,
            name_score = 0.88,
            value_score = 0.88,
            alternatives = list(
                list(column_name = "coord_col", final_score = 0.88, name_score = 0.88, value_score = 0.88),
                list(column_name = "coord_aux", final_score = 0.60, name_score = 0.60, value_score = 0.60)
            )
        ),
        make_stage3_row(
            term = "verbatimLatitude",
            selected_col = "coord_col",
            status = "SUGERIDO",
            reason = "token_overlap",
            final_score = 0.88,
            applied = TRUE,
            name_score = 0.88,
            value_score = 0.88,
            alternatives = list(
                list(column_name = "coord_col", final_score = 0.88, name_score = 0.88, value_score = 0.88)
            )
        )
    ))
    df <- data.frame(
        coord_col = c("-10", "-20", "-30"),
        coord_aux = c("a", "b", "c"),
        stringsAsFactors = FALSE
    )

    out <- rostrum_stage3_resolve(
        stage2_data = stage2,
        df = df,
        options = rostrum_options(ambiguity_gap = 0)
    )
    idx_num <- which(out$data$term == "decimalLatitude")
    idx_txt <- which(out$data$term == "verbatimLatitude")

    testthat::expect_identical(out$data$selected_col[[idx_num]], "coord_col")
    testthat::expect_true(is.na(out$data$selected_col[[idx_txt]]))
    testthat::expect_identical(out$data$reason[[idx_txt]], "conflict_lost")
})

testthat::test_that("term candidate resolution prefers higher completeness when scores tie", {
    stage2 <- make_stage3_row(
        term = "eventDate",
        alternatives = list(
            list(column_name = "date_full", final_score = 0.82, name_score = 0.82, value_score = 0.82),
            list(column_name = "date_sparse", final_score = 0.82, name_score = 0.82, value_score = 0.82)
        )
    )
    df <- data.frame(
        date_full = c("2024-01-01", "2024-01-02", "2024-01-03", "2024-01-04"),
        date_sparse = c("2024-01-01", "", NA_character_, ""),
        stringsAsFactors = FALSE
    )

    out <- rostrum_stage3_resolve(
        stage2_data = stage2,
        df = df,
        options = rostrum_options(ambiguity_gap = 0)
    )

    testthat::expect_identical(out$data$selected_col[[1]], "date_full")
    testthat::expect_false(identical(out$data$status[[1]], "AMBIGUO"))
})
