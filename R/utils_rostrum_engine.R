# Title: Rostrum Engine Orchestration (Stage Boundary)
# Author: Rogerio Nunes Oliveira
# Date: 2026-03-01
# Version: 1.0

empty_automap_result_df <- function() {
    data.frame(
        term = character(0),
        selected_col = character(0),
        name_score = numeric(0),
        value_score = numeric(0),
        penalty_score = numeric(0),
        veto_code = character(0),
        final_score = numeric(0),
        status = character(0),
        reason = character(0),
        applied = logical(0),
        alternatives_json = character(0),
        explain_json = character(0),
        stringsAsFactors = FALSE
    )
}

build_rostrum_stage_result <- function(
    success,
    data,
    warnings = character(0),
    errors = character(0),
    timing_ms = 0
) {
    list(
        success = isTRUE(success),
        data = data,
        warnings = as.character(warnings),
        errors = as.character(errors),
        timing_ms = as.numeric(timing_ms)
    )
}

rostrum_is_blank_selection <- function(value) {
    if (is.null(value) || length(value) == 0) {
        return(TRUE)
    }

    value_chr <- as.character(value)
    value_chr <- value_chr[!is.na(value_chr)]
    if (length(value_chr) == 0) {
        return(TRUE)
    }

    !any(nzchar(trimws(value_chr)))
}

rostrum_term_index <- function(decision_df, term) {
    if (!is.data.frame(decision_df) || !"term" %in% names(decision_df)) {
        return(NA_integer_)
    }

    idx <- which(as.character(decision_df$term) == term)
    if (length(idx) == 0) {
        return(NA_integer_)
    }

    as.integer(idx[[1]])
}

rostrum_selected_column <- function(decision_df, term) {
    idx <- rostrum_term_index(decision_df, term)
    if (is.na(idx) || !"selected_col" %in% names(decision_df)) {
        return(NA_character_)
    }

    selected <- as.character(decision_df$selected_col[[idx]])
    if (rostrum_is_blank_selection(selected)) {
        return(NA_character_)
    }

    trimws(selected)
}

rostrum_parse_manual_overrides <- function(manual_overrides) {
    if (is.null(manual_overrides)) {
        return(list())
    }

    if (is.list(manual_overrides)) {
        return(manual_overrides)
    }

    if (is.atomic(manual_overrides) && !is.null(names(manual_overrides))) {
        return(as.list(manual_overrides))
    }

    list()
}

rostrum_has_manual_override <- function(term, manual_overrides) {
    if (!is.list(manual_overrides) || length(manual_overrides) == 0) {
        return(FALSE)
    }

    value <- manual_overrides[[term]]
    if (is.null(value)) {
        return(FALSE)
    }

    !rostrum_is_blank_selection(value)
}

rostrum_parse_composed_from <- function(composed_from) {
    if (is.null(composed_from)) {
        return(list())
    }
    if (!is.list(composed_from)) {
        return(list())
    }

    out <- lapply(composed_from, function(value) {
        value_chr <- as.character(value)
        value_chr <- trimws(value_chr)
        value_chr <- value_chr[!is.na(value_chr) & nzchar(value_chr)]
        unique(value_chr)
    })

    out[nzchar(names(out))]
}

rostrum_depends_on_term <- function(composed_from, term, target_term, visited = character(0)) {
    if (identical(term, target_term)) {
        return(TRUE)
    }
    if (term %in% visited) {
        return(FALSE)
    }

    deps <- composed_from[[term]]
    if (is.null(deps) || length(deps) == 0) {
        return(FALSE)
    }

    deps <- unique(as.character(deps))
    deps <- deps[!is.na(deps) & nzchar(trimws(deps))]
    if (length(deps) == 0) {
        return(FALSE)
    }

    if (target_term %in% deps) {
        return(TRUE)
    }

    any(vapply(
        deps,
        FUN = function(dep) {
            rostrum_depends_on_term(
                composed_from = composed_from,
                term = dep,
                target_term = target_term,
                visited = c(visited, term)
            )
        },
        FUN.VALUE = logical(1)
    ))
}

rostrum_can_compose_term <- function(target_term, source_terms, composed_from) {
    if (length(source_terms) == 0) {
        return(FALSE)
    }

    !any(vapply(
        source_terms,
        FUN = function(source_term) {
            rostrum_depends_on_term(composed_from, source_term, target_term)
        },
        FUN.VALUE = logical(1)
    ))
}

rostrum_add_composed_from <- function(composed_from, target_term, source_terms) {
    source_terms <- unique(as.character(source_terms))
    source_terms <- source_terms[!is.na(source_terms) & nzchar(trimws(source_terms))]
    composed_from[[target_term]] <- source_terms
    composed_from
}

rostrum_parse_explain_json <- function(explain_json) {
    if (!is.character(explain_json) || length(explain_json) == 0 || rostrum_is_blank_selection(explain_json)) {
        return(list())
    }

    parsed <- tryCatch(
        jsonlite::fromJSON(explain_json[[1]], simplifyVector = FALSE),
        error = function(e) list()
    )

    if (!is.list(parsed)) {
        return(list())
    }

    parsed
}

rostrum_update_explain_json <- function(explain_json, patch) {
    current <- rostrum_parse_explain_json(explain_json)
    patch_names <- names(patch)
    if (is.null(patch_names) || length(patch_names) == 0) {
        return(as.character(jsonlite::toJSON(current, auto_unbox = TRUE, null = "null")))
    }

    for (name in patch_names) {
        current[[name]] <- patch[[name]]
    }

    as.character(jsonlite::toJSON(current, auto_unbox = TRUE, null = "null"))
}

rostrum_ensure_engine_columns <- function(decision_df) {
    data <- decision_df
    row_n <- nrow(data)

    if (!"selected_col" %in% names(data)) data$selected_col <- rep(NA_character_, row_n)
    if (!"name_score" %in% names(data)) data$name_score <- rep(0, row_n)
    if (!"value_score" %in% names(data)) data$value_score <- rep(0, row_n)
    if (!"penalty_score" %in% names(data)) data$penalty_score <- rep(0, row_n)
    if (!"veto_code" %in% names(data)) data$veto_code <- rep("", row_n)
    if (!"final_score" %in% names(data)) data$final_score <- rep(0, row_n)
    if (!"status" %in% names(data)) data$status <- rep("MANUAL", row_n)
    if (!"reason" %in% names(data)) data$reason <- rep("no_confident_match", row_n)
    if (!"applied" %in% names(data)) data$applied <- rep(FALSE, row_n)
    if (!"alternatives_json" %in% names(data)) data$alternatives_json <- rep("[]", row_n)
    if (!"explain_json" %in% names(data)) data$explain_json <- rep("{}", row_n)
    if (!"composed_from_json" %in% names(data)) data$composed_from_json <- rep(NA_character_, row_n)

    data
}

rostrum_extract_column <- function(df, column_name) {
    if (!is.character(column_name) || length(column_name) != 1L || is.na(column_name) || !nzchar(column_name)) {
        return(rep(NA_character_, nrow(df)))
    }
    if (!(column_name %in% names(df))) {
        return(rep(NA_character_, nrow(df)))
    }

    values <- as.character(df[[column_name]])
    values[is.na(df[[column_name]])] <- NA_character_
    values
}

rostrum_eventdate_parse_day <- function(values) {
    values_chr <- as.character(values)
    values_chr[is.na(values)] <- ""
    values_chr <- trimws(values_chr)

    out <- suppressWarnings(as.integer(values_chr))
    invalid <- !nzchar(values_chr) | is.na(out) | out < 1L | out > 31L
    out[invalid] <- NA_integer_
    out
}

rostrum_is_leap_year <- function(year_values) {
    year_num <- suppressWarnings(as.integer(year_values))
    valid <- !is.na(year_num)
    out <- rep(FALSE, length(year_num))
    out[valid] <- ((year_num[valid] %% 4L == 0L) & (year_num[valid] %% 100L != 0L)) |
        (year_num[valid] %% 400L == 0L)
    out
}

rostrum_days_in_month <- function(year_values, month_values) {
    month_num <- suppressWarnings(as.integer(month_values))
    year_num <- suppressWarnings(as.integer(year_values))

    out <- rep(NA_integer_, length(month_num))
    valid_month <- !is.na(month_num) & month_num >= 1L & month_num <= 12L

    out[valid_month & month_num %in% c(1L, 3L, 5L, 7L, 8L, 10L, 12L)] <- 31L
    out[valid_month & month_num %in% c(4L, 6L, 9L, 11L)] <- 30L

    feb_mask <- valid_month & month_num == 2L
    if (any(feb_mask)) {
        leap_mask <- rostrum_is_leap_year(year_num[feb_mask])
        out[feb_mask] <- ifelse(leap_mask, 29L, 28L)
    }

    out
}

rostrum_compose_eventdate_values <- function(df, source_columns) {
    n_rows <- nrow(df)
    if (n_rows == 0) {
        return(list(
            values = character(0),
            valid_mask = logical(0),
            partial_mask = logical(0),
            has_any_input = logical(0)
        ))
    }

    year_values <- rostrum_extract_column(df, source_columns[["year"]])
    month_values <- rostrum_extract_column(df, source_columns[["month"]])
    day_values <- rostrum_extract_column(df, source_columns[["day"]])

    year_blank <- is.na(year_values) | !nzchar(trimws(year_values))
    month_blank <- is.na(month_values) | !nzchar(trimws(month_values))
    day_blank <- is.na(day_values) | !nzchar(trimws(day_values))
    has_any_input <- !(year_blank & month_blank & day_blank)

    parsed_year <- vapply(year_values, parse_year_to_number, FUN.VALUE = integer(1))
    parsed_month <- vapply(month_values, parse_month_to_number, FUN.VALUE = character(1))
    parsed_month_num <- suppressWarnings(as.integer(parsed_month))
    parsed_day <- rostrum_eventdate_parse_day(day_values)

    max_days <- rostrum_days_in_month(parsed_year, parsed_month_num)

    valid_year_only <- !year_blank & month_blank & day_blank & !is.na(parsed_year)
    valid_year_month <- !year_blank & !month_blank & day_blank &
        !is.na(parsed_year) & !is.na(parsed_month_num)
    valid_full <- !year_blank & !month_blank & !day_blank &
        !is.na(parsed_year) & !is.na(parsed_month_num) & !is.na(parsed_day) &
        !is.na(max_days) & parsed_day <= max_days

    valid_mask <- valid_year_only | valid_year_month | valid_full
    partial_mask <- valid_year_only | valid_year_month

    composed <- rep(NA_character_, n_rows)
    if (any(valid_year_only)) {
        composed[valid_year_only] <- sprintf("%04d", parsed_year[valid_year_only])
    }
    if (any(valid_year_month)) {
        composed[valid_year_month] <- sprintf("%04d-%02d", parsed_year[valid_year_month], parsed_month_num[valid_year_month])
    }
    if (any(valid_full)) {
        composed[valid_full] <- sprintf("%04d-%02d-%02d", parsed_year[valid_full], parsed_month_num[valid_full], parsed_day[valid_full])
    }

    list(
        values = composed,
        valid_mask = valid_mask,
        partial_mask = partial_mask,
        has_any_input = has_any_input
    )
}

rostrum_compose_scientific_name_values <- function(df, source_columns) {
    n_rows <- nrow(df)
    if (n_rows == 0) {
        return(list(
            values = character(0),
            valid_mask = logical(0),
            has_any_input = logical(0)
        ))
    }

    genus_values <- rostrum_extract_column(df, source_columns[["genus"]])
    specific_values <- rostrum_extract_column(df, source_columns[["specificEpithet"]])
    infra_values <- rostrum_extract_column(df, source_columns[["infraspecificEpithet"]])
    authorship_values <- rostrum_extract_column(df, source_columns[["scientificNameAuthorship"]])

    genus_fmt <- vapply(genus_values, format_genus_token, FUN.VALUE = character(1))
    specific_fmt <- vapply(specific_values, format_epithet_token, FUN.VALUE = character(1))
    infra_fmt <- vapply(infra_values, format_epithet_token, FUN.VALUE = character(1))

    genus_fmt[!is.na(genus_fmt) & !nzchar(genus_fmt)] <- NA_character_
    specific_fmt[!is.na(specific_fmt) & !nzchar(specific_fmt)] <- NA_character_
    infra_fmt[!is.na(infra_fmt) & !nzchar(infra_fmt)] <- NA_character_

    auth_fmt <- as.character(authorship_values)
    auth_fmt[is.na(authorship_values)] <- NA_character_
    auth_fmt <- trimws(auth_fmt)
    auth_fmt[!nzchar(auth_fmt)] <- NA_character_

    has_any_input <- (!is.na(genus_values) & nzchar(trimws(genus_values))) |
        (!is.na(specific_values) & nzchar(trimws(specific_values)))
    valid_mask <- !is.na(genus_fmt) & !is.na(specific_fmt)

    composed <- rep(NA_character_, n_rows)
    if (any(valid_mask)) {
        base <- paste(genus_fmt[valid_mask], specific_fmt[valid_mask])
        with_infra <- !is.na(infra_fmt[valid_mask])
        base[with_infra] <- paste(base[with_infra], infra_fmt[valid_mask][with_infra])

        with_author <- !is.na(auth_fmt[valid_mask])
        base[with_author] <- paste(base[with_author], auth_fmt[valid_mask][with_author])
        composed[valid_mask] <- base
    }

    list(
        values = composed,
        valid_mask = valid_mask,
        has_any_input = has_any_input
    )
}

rostrum_collect_source_cols <- function(decision_df, terms) {
    stats::setNames(vapply(
        terms,
        FUN = function(term) rostrum_selected_column(decision_df, term),
        FUN.VALUE = character(1)
    ), terms)
}

rostrum_apply_scientific_name_stage2 <- function(data, df, options, manual_overrides, composed_from) {
    warnings <- character(0)
    sci_idx <- rostrum_term_index(data, "scientificName")
    if (is.na(sci_idx)) {
        return(list(data = data, warnings = warnings, composed_from = composed_from))
    }

    if (!is.na(rostrum_selected_column(data, "scientificName"))) {
        return(list(data = data, warnings = warnings, composed_from = composed_from))
    }
    if (rostrum_has_manual_override("scientificName", manual_overrides)) {
        return(list(data = data, warnings = warnings, composed_from = composed_from))
    }

    required_terms <- c("genus", "specificEpithet")
    optional_terms <- c("infraspecificEpithet", "scientificNameAuthorship")
    source_cols <- rostrum_collect_source_cols(data, c(required_terms, optional_terms))
    required_missing <- is.na(source_cols[required_terms]) | !nzchar(source_cols[required_terms])
    if (any(required_missing)) {
        return(list(data = data, warnings = warnings, composed_from = composed_from))
    }

    used_terms <- required_terms
    optional_in_use <- optional_terms[!is.na(source_cols[optional_terms]) & nzchar(source_cols[optional_terms])]
    used_terms <- c(used_terms, optional_in_use)

    if (!rostrum_can_compose_term("scientificName", used_terms, composed_from)) {
        warnings <- c(warnings, "Stage 2 skipped scientificName composition due to circularity guard.")
        return(list(data = data, warnings = warnings, composed_from = composed_from))
    }

    composed <- rostrum_compose_scientific_name_values(
        df = df,
        source_columns = as.list(source_cols)
    )
    input_n <- sum(composed$has_any_input)
    if (input_n == 0) {
        return(list(data = data, warnings = warnings, composed_from = composed_from))
    }

    valid_n <- sum(composed$valid_mask)
    valid_ratio <- valid_n / input_n
    if (!is.finite(valid_ratio) || valid_ratio < options$hard_veto_threshold) {
        warnings <- c(warnings, "Stage 2 skipped scientificName composition due to low validation ratio.")
        return(list(data = data, warnings = warnings, composed_from = composed_from))
    }

    preview_values <- composed$values[!is.na(composed$values)]
    preview <- if (length(preview_values) > 0) preview_values[[1]] else NA_character_
    score <- pmin(1, pmax(options$suggest_threshold, valid_ratio))

    data$name_score[[sci_idx]] <- as.numeric(score)
    data$value_score[[sci_idx]] <- as.numeric(valid_ratio)
    data$penalty_score[[sci_idx]] <- 0
    data$veto_code[[sci_idx]] <- ""
    data$final_score[[sci_idx]] <- as.numeric(score)
    data$status[[sci_idx]] <- "SUGERIDO"
    data$reason[[sci_idx]] <- "composed_scientific_name"
    data$selected_col[[sci_idx]] <- NA_character_
    data$applied[[sci_idx]] <- FALSE
    data$alternatives_json[[sci_idx]] <- as.character(jsonlite::toJSON(
        list(list(
            composition = "scientificName",
            source_columns = as.list(source_cols[used_terms]),
            score = as.numeric(score)
        )),
        auto_unbox = TRUE,
        null = "null"
    ))
    data$explain_json[[sci_idx]] <- rostrum_update_explain_json(
        data$explain_json[[sci_idx]],
        patch = list(stage2 = list(
            composition = "scientificName",
            source_terms = used_terms,
            source_columns = as.list(source_cols[used_terms]),
            valid_ratio = as.numeric(valid_ratio),
            valid_n = as.integer(valid_n),
            input_n = as.integer(input_n),
            output_preview = preview
        ))
    )

    composed_from <- rostrum_add_composed_from(
        composed_from = composed_from,
        target_term = "scientificName",
        source_terms = used_terms
    )

    list(data = data, warnings = warnings, composed_from = composed_from)
}

rostrum_apply_eventdate_stage2 <- function(data, df, options, manual_overrides, composed_from) {
    warnings <- character(0)
    event_idx <- rostrum_term_index(data, "eventDate")
    if (is.na(event_idx)) {
        return(list(data = data, warnings = warnings, composed_from = composed_from))
    }

    if (!is.na(rostrum_selected_column(data, "eventDate"))) {
        return(list(data = data, warnings = warnings, composed_from = composed_from))
    }
    if (rostrum_has_manual_override("eventDate", manual_overrides)) {
        return(list(data = data, warnings = warnings, composed_from = composed_from))
    }

    source_cols <- rostrum_collect_source_cols(data, c("year", "month", "day"))
    year_col <- source_cols[["year"]]
    month_col <- source_cols[["month"]]
    day_col <- source_cols[["day"]]

    if (is.na(year_col) || !nzchar(year_col)) {
        return(list(data = data, warnings = warnings, composed_from = composed_from))
    }
    if (!is.na(day_col) && nzchar(day_col) && (is.na(month_col) || !nzchar(month_col))) {
        warnings <- c(warnings, "Stage 2 skipped eventDate composition: day mapped without month.")
        return(list(data = data, warnings = warnings, composed_from = composed_from))
    }

    used_terms <- "year"
    if (!is.na(month_col) && nzchar(month_col)) used_terms <- c(used_terms, "month")
    if (!is.na(day_col) && nzchar(day_col)) used_terms <- c(used_terms, "day")

    if (!rostrum_can_compose_term("eventDate", used_terms, composed_from)) {
        warnings <- c(warnings, "Stage 2 skipped eventDate composition due to circularity guard.")
        return(list(data = data, warnings = warnings, composed_from = composed_from))
    }

    composed <- rostrum_compose_eventdate_values(
        df = df,
        source_columns = list(
            year = year_col,
            month = if (!is.na(month_col) && nzchar(month_col)) month_col else NA_character_,
            day = if (!is.na(day_col) && nzchar(day_col)) day_col else NA_character_
        )
    )
    input_n <- sum(composed$has_any_input)
    if (input_n == 0) {
        return(list(data = data, warnings = warnings, composed_from = composed_from))
    }

    valid_n <- sum(composed$valid_mask)
    valid_ratio <- valid_n / input_n
    if (!is.finite(valid_ratio) || valid_ratio < options$hard_veto_threshold) {
        warnings <- c(warnings, "Stage 2 skipped eventDate composition due to low validation ratio.")
        return(list(data = data, warnings = warnings, composed_from = composed_from))
    }

    preview_values <- composed$values[!is.na(composed$values)]
    preview <- if (length(preview_values) > 0) preview_values[[1]] else NA_character_
    has_partial <- any(composed$partial_mask & composed$valid_mask)
    score <- pmin(1, pmax(options$suggest_threshold, valid_ratio))

    can_apply_direct <- length(used_terms) == 1L

    data$name_score[[event_idx]] <- as.numeric(score)
    data$value_score[[event_idx]] <- as.numeric(valid_ratio)
    data$penalty_score[[event_idx]] <- 0
    data$veto_code[[event_idx]] <- ""
    data$final_score[[event_idx]] <- as.numeric(score)
    data$status[[event_idx]] <- "SUGERIDO"
    data$reason[[event_idx]] <- if (has_partial) "composed_eventdate_partial" else "composed_eventdate_ymd"
    data$selected_col[[event_idx]] <- if (can_apply_direct) year_col else NA_character_
    data$applied[[event_idx]] <- isTRUE(can_apply_direct)
    data$alternatives_json[[event_idx]] <- as.character(jsonlite::toJSON(
        list(list(
            composition = "eventDate",
            source_columns = as.list(source_cols[used_terms]),
            score = as.numeric(score)
        )),
        auto_unbox = TRUE,
        null = "null"
    ))
    data$explain_json[[event_idx]] <- rostrum_update_explain_json(
        data$explain_json[[event_idx]],
        patch = list(stage2 = list(
            composition = "eventDate",
            source_terms = used_terms,
            source_columns = as.list(source_cols[used_terms]),
            valid_ratio = as.numeric(valid_ratio),
            valid_n = as.integer(valid_n),
            input_n = as.integer(input_n),
            partial_supported = isTRUE(has_partial),
            output_preview = preview
        ))
    )

    composed_from <- rostrum_add_composed_from(
        composed_from = composed_from,
        target_term = "eventDate",
        source_terms = used_terms
    )

    list(data = data, warnings = warnings, composed_from = composed_from)
}

rostrum_apply_composed_from_column <- function(data, composed_from) {
    if (!is.list(composed_from) || length(composed_from) == 0 || nrow(data) == 0) {
        return(data)
    }
    if (!"composed_from_json" %in% names(data)) {
        data$composed_from_json <- rep(NA_character_, nrow(data))
    }

    for (term_name in names(composed_from)) {
        idx <- rostrum_term_index(data, term_name)
        if (is.na(idx)) {
            next
        }

        data$composed_from_json[[idx]] <- as.character(jsonlite::toJSON(
            unname(as.character(composed_from[[term_name]])),
            auto_unbox = FALSE
        ))
    }

    data
}

rostrum_ambiguity_gap_epsilon <- function(options) {
    gap <- suppressWarnings(as.numeric(options$ambiguity_gap))
    if (length(gap) != 1L || is.na(gap) || gap < 0) {
        gap <- 0.10
    }
    pmax(0, gap - (.Machine$double.eps^0.5))
}

rostrum_term_expected_type <- function(term) {
    term_chr <- as.character(term)
    if (term_chr %in% c("decimalLatitude", "decimalLongitude", "individualCount", "year", "month", "day")) {
        return("numeric")
    }
    if (term_chr %in% c("verbatimLatitude", "verbatimLongitude", "verbatimEventDate", "verbatimCoordinates")) {
        return("text")
    }
    "any"
}

rostrum_column_quality_metrics <- function(df, column_name) {
    if (!is.data.frame(df) || !(column_name %in% names(df))) {
        return(list(completeness = 0, numeric_ratio = 0))
    }

    values <- as.character(df[[column_name]])
    values[is.na(df[[column_name]])] <- NA_character_
    non_blank_mask <- !is.na(values) & nzchar(trimws(values))
    completeness <- if (length(non_blank_mask) == 0) 0 else mean(non_blank_mask)

    if (!any(non_blank_mask)) {
        return(list(completeness = as.numeric(completeness), numeric_ratio = 0))
    }

    non_blank_values <- values[non_blank_mask]
    numeric_values <- suppressWarnings(as.numeric(gsub(",", ".", non_blank_values)))
    numeric_ratio <- mean(!is.na(numeric_values))

    list(
        completeness = as.numeric(completeness),
        numeric_ratio = as.numeric(numeric_ratio)
    )
}

rostrum_type_match_score <- function(term, numeric_ratio) {
    expected <- rostrum_term_expected_type(term)
    ratio <- suppressWarnings(as.numeric(numeric_ratio))
    if (!is.finite(ratio) || ratio < 0 || ratio > 1) {
        ratio <- 0
    }

    if (identical(expected, "numeric")) {
        return(ratio)
    }
    if (identical(expected, "text")) {
        return(1 - ratio)
    }
    0.5
}

rostrum_candidates_from_row <- function(row_data) {
    selected_col <- as.character(row_data$selected_col[[1]])
    if (rostrum_is_blank_selection(selected_col)) {
        selected_col <- NA_character_
    } else {
        selected_col <- trimws(selected_col)
    }

    alternatives_json <- as.character(row_data$alternatives_json[[1]])
    parsed <- tryCatch(
        jsonlite::fromJSON(alternatives_json, simplifyVector = FALSE),
        error = function(e) list()
    )
    if (!is.list(parsed)) {
        parsed <- list()
    }

    candidates <- lapply(parsed, function(item) {
        col_name <- if (!is.null(item$column_name)) as.character(item$column_name) else NA_character_
        if (is.na(col_name) || !nzchar(trimws(col_name))) {
            return(NULL)
        }

        score <- suppressWarnings(as.numeric(item$final_score))
        if (!is.finite(score) && !is.null(item$score)) {
            score <- suppressWarnings(as.numeric(item$score))
        }
        if (!is.finite(score)) {
            score <- suppressWarnings(as.numeric(row_data$final_score[[1]]))
        }

        name_score <- suppressWarnings(as.numeric(item$name_score))
        if (!is.finite(name_score)) {
            name_score <- suppressWarnings(as.numeric(row_data$name_score[[1]]))
        }

        value_score <- suppressWarnings(as.numeric(item$value_score))
        if (!is.finite(value_score)) {
            value_score <- suppressWarnings(as.numeric(row_data$value_score[[1]]))
        }

        data.frame(
            column_name = trimws(col_name),
            final_score = as.numeric(score),
            name_score = as.numeric(name_score),
            value_score = as.numeric(value_score),
            stringsAsFactors = FALSE
        )
    })
    candidates <- Filter(Negate(is.null), candidates)

    selected_score <- suppressWarnings(as.numeric(row_data$final_score[[1]]))
    selected_name_score <- suppressWarnings(as.numeric(row_data$name_score[[1]]))
    selected_value_score <- suppressWarnings(as.numeric(row_data$value_score[[1]]))
    if (!is.na(selected_col) && nzchar(selected_col)) {
        has_selected <- any(vapply(
            candidates,
            FUN = function(item) identical(as.character(item$column_name[[1]]), selected_col),
            FUN.VALUE = logical(1)
        ))
        if (!has_selected) {
            candidates[[length(candidates) + 1L]] <- data.frame(
                column_name = selected_col,
                final_score = as.numeric(selected_score),
                name_score = as.numeric(selected_name_score),
                value_score = as.numeric(selected_value_score),
                stringsAsFactors = FALSE
            )
        }
    }

    if (length(candidates) == 0L) {
        return(data.frame(
            column_name = character(0),
            final_score = numeric(0),
            name_score = numeric(0),
            value_score = numeric(0),
            stringsAsFactors = FALSE
        ))
    }

    candidate_df <- do.call(rbind, candidates)
    candidate_df <- candidate_df[!is.na(candidate_df$column_name) & nzchar(candidate_df$column_name), , drop = FALSE]
    if (nrow(candidate_df) == 0L) {
        return(candidate_df)
    }

    ordering <- order(
        candidate_df$column_name,
        -candidate_df$final_score,
        -candidate_df$value_score,
        -candidate_df$name_score
    )
    candidate_df <- candidate_df[ordering, , drop = FALSE]
    candidate_df <- candidate_df[!duplicated(candidate_df$column_name), , drop = FALSE]
    rownames(candidate_df) <- NULL
    candidate_df
}

rostrum_rank_candidate_rows <- function(candidate_df, tie_label = "column_name") {
    if (!is.data.frame(candidate_df) || nrow(candidate_df) == 0L) {
        return(integer(0))
    }

    order(
        -candidate_df$final_score,
        -candidate_df$value_score,
        -candidate_df$type_match,
        -candidate_df$completeness,
        -candidate_df$specificity,
        -candidate_df$exact_hits,
        candidate_df$substring_hits,
        as.character(candidate_df[[tie_label]])
    )
}

rostrum_status_from_score <- function(previous_status, score, options) {
    status_chr <- toupper(as.character(previous_status))
    if (status_chr %in% c("ALIAS", "TEMPLATE", "EDITADO")) {
        return(status_chr)
    }

    score_num <- suppressWarnings(as.numeric(score))
    if (!is.finite(score_num)) {
        return("MANUAL")
    }
    if (score_num >= options$auto_apply_threshold) {
        return("AUTO")
    }
    if (score_num >= options$suggest_threshold) {
        return("SUGERIDO")
    }
    "MANUAL"
}

rostrum_is_applied_status <- function(status) {
    toupper(as.character(status)) %in% c("AUTO", "SUGERIDO", "ALIAS", "TEMPLATE", "EDITADO")
}

rostrum_is_technical_tie <- function(first_row, second_row, ambiguity_gap) {
    first_score <- suppressWarnings(as.numeric(first_row$final_score[[1]]))
    second_score <- suppressWarnings(as.numeric(second_row$final_score[[1]]))
    if (!is.finite(first_score) || !is.finite(second_score)) {
        return(FALSE)
    }

    score_gap <- abs(first_score - second_score)
    if (!is.finite(score_gap) || score_gap >= ambiguity_gap) {
        return(FALSE)
    }
    TRUE
}

rostrum_build_stage3_candidate_df <- function(term, candidate_df, df) {
    if (!is.data.frame(candidate_df) || nrow(candidate_df) == 0L) {
        return(candidate_df)
    }

    out <- candidate_df
    metrics <- lapply(out$column_name, function(col_name) rostrum_column_quality_metrics(df, col_name))
    overlap <- lapply(out$column_name, function(col_name) {
        score_token_overlap(col_name = col_name, term = term, with_details = TRUE)
    })

    out$completeness <- vapply(metrics, function(x) as.numeric(x$completeness), FUN.VALUE = numeric(1))
    out$numeric_ratio <- vapply(metrics, function(x) as.numeric(x$numeric_ratio), FUN.VALUE = numeric(1))
    out$type_match <- vapply(out$numeric_ratio, function(x) rostrum_type_match_score(term, x), FUN.VALUE = numeric(1))
    out$specificity <- vapply(out$column_name, count_relevant_tokens, FUN.VALUE = integer(1))
    out$exact_hits <- vapply(overlap, function(x) as.integer(x$exact_hits), FUN.VALUE = integer(1))
    out$substring_hits <- vapply(overlap, function(x) as.integer(x$substring_hits), FUN.VALUE = integer(1))

    out$final_score <- suppressWarnings(as.numeric(out$final_score))
    out$value_score <- suppressWarnings(as.numeric(out$value_score))
    out$name_score <- suppressWarnings(as.numeric(out$name_score))
    out$final_score[!is.finite(out$final_score)] <- 0
    out$value_score[!is.finite(out$value_score)] <- 0
    out$name_score[!is.finite(out$name_score)] <- 0

    out
}

rostrum_serialize_top_candidates <- function(candidate_df, top_n = 3L) {
    if (!is.data.frame(candidate_df) || nrow(candidate_df) == 0L) {
        return("[]")
    }

    n_take <- min(as.integer(top_n), nrow(candidate_df))
    payload <- lapply(seq_len(n_take), function(i) {
        list(
            column_name = as.character(candidate_df$column_name[[i]]),
            final_score = as.numeric(candidate_df$final_score[[i]]),
            name_score = as.numeric(candidate_df$name_score[[i]]),
            value_score = as.numeric(candidate_df$value_score[[i]])
        )
    })
    as.character(jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null"))
}

rostrum_related_verbatim_term <- function(term) {
    mapping <- c(
        decimalLatitude = "verbatimLatitude",
        decimalLongitude = "verbatimLongitude",
        eventDate = "verbatimEventDate",
        coordinates = "verbatimCoordinates"
    )
    target <- unname(mapping[as.character(term)])
    if (length(target) == 0L || is.na(target) || !nzchar(target)) {
        return(NA_character_)
    }
    target
}

rostrum_update_row_from_candidate <- function(data, idx, term, candidate_row, options, force_reason = NULL) {
    data$selected_col[[idx]] <- as.character(candidate_row$column_name[[1]])
    data$name_score[[idx]] <- as.numeric(candidate_row$name_score[[1]])
    data$value_score[[idx]] <- as.numeric(candidate_row$value_score[[1]])
    data$penalty_score[[idx]] <- 0
    data$veto_code[[idx]] <- ""
    data$final_score[[idx]] <- as.numeric(candidate_row$final_score[[1]])

    status <- rostrum_status_from_score(data$status[[idx]], candidate_row$final_score[[1]], options)
    data$status[[idx]] <- status
    data$applied[[idx]] <- rostrum_is_applied_status(status)
    if (!isTRUE(data$applied[[idx]])) {
        data$selected_col[[idx]] <- NA_character_
    }

    if (!is.null(force_reason)) {
        data$reason[[idx]] <- as.character(force_reason)
    }

    data$explain_json[[idx]] <- rostrum_update_explain_json(
        data$explain_json[[idx]],
        patch = list(stage3 = list(
            term = term,
            selected_col = as.character(candidate_row$column_name[[1]]),
            final_score = as.numeric(candidate_row$final_score[[1]]),
            value_score = as.numeric(candidate_row$value_score[[1]]),
            completeness = as.numeric(candidate_row$completeness[[1]]),
            type_match = as.numeric(candidate_row$type_match[[1]])
        ))
    )

    data
}

rostrum_apply_stage3_candidates <- function(stage2_data, df, options) {
    data <- rostrum_ensure_engine_columns(stage2_data)
    warnings <- character(0)
    proposals <- list()
    loser_pool <- list()
    terms_with_alternatives <- character(0)
    ambiguity_gap <- rostrum_ambiguity_gap_epsilon(options)

    if (nrow(data) == 0L) {
        return(list(
            data = data,
            proposals = data.frame(),
            loser_pool = data.frame(),
            warnings = warnings
        ))
    }

    for (idx in seq_len(nrow(data))) {
        term <- as.character(data$term[[idx]])
        candidate_seed <- rostrum_candidates_from_row(data[idx, , drop = FALSE])
        if (!is.data.frame(candidate_seed) || nrow(candidate_seed) == 0L) {
            next
        }

        candidate_df <- rostrum_build_stage3_candidate_df(term = term, candidate_df = candidate_seed, df = df)
        ranking <- rostrum_rank_candidate_rows(candidate_df, tie_label = "column_name")
        candidate_df <- candidate_df[ranking, , drop = FALSE]
        rownames(candidate_df) <- NULL

        data$alternatives_json[[idx]] <- rostrum_serialize_top_candidates(candidate_df, top_n = 3L)
        best <- candidate_df[1, , drop = FALSE]

        if (nrow(candidate_df) >= 2L) {
            terms_with_alternatives <- unique(c(terms_with_alternatives, term))
            first_row <- candidate_df[1, , drop = FALSE]
            second_row <- candidate_df[2, , drop = FALSE]
            score_gap <- abs(first_row$final_score[[1]] - second_row$final_score[[1]])
            if (first_row$final_score[[1]] >= options$suggest_threshold &&
                rostrum_is_technical_tie(first_row, second_row, ambiguity_gap)) {
                data$status[[idx]] <- "AMBIGUO"
                data$applied[[idx]] <- FALSE
                data$selected_col[[idx]] <- NA_character_
                data$reason[[idx]] <- "ambiguity_detected"
                data$explain_json[[idx]] <- rostrum_update_explain_json(
                    data$explain_json[[idx]],
                    patch = list(stage3 = list(
                        ambiguity_gap = as.numeric(score_gap),
                        threshold = as.numeric(ambiguity_gap)
                    ))
                )
                warnings <- c(
                    warnings,
                    sprintf("Stage 3 marked term '%s' as ambiguous (gap=%.4f).", term, score_gap)
                )
                next
            }
        }

        if (best$final_score[[1]] < options$suggest_threshold) {
            data$status[[idx]] <- "MANUAL"
            data$applied[[idx]] <- FALSE
            data$selected_col[[idx]] <- NA_character_
            if (!identical(as.character(data$reason[[idx]]), "manual_only_term")) {
                data$reason[[idx]] <- "no_confident_match"
            }
            next
        }

        data <- rostrum_update_row_from_candidate(
            data = data,
            idx = idx,
            term = term,
            candidate_row = best,
            options = options
        )

        proposals[[length(proposals) + 1L]] <- data.frame(
            idx = as.integer(idx),
            term = term,
            column_name = as.character(best$column_name[[1]]),
            final_score = as.numeric(best$final_score[[1]]),
            value_score = as.numeric(best$value_score[[1]]),
            type_match = as.numeric(best$type_match[[1]]),
            completeness = as.numeric(best$completeness[[1]]),
            specificity = as.numeric(best$specificity[[1]]),
            exact_hits = as.numeric(best$exact_hits[[1]]),
            substring_hits = as.numeric(best$substring_hits[[1]]),
            name_score = as.numeric(best$name_score[[1]]),
            stringsAsFactors = FALSE
        )

        if (nrow(candidate_df) >= 2L) {
            alt_rows <- candidate_df[2:nrow(candidate_df), , drop = FALSE]
            alt_rows <- alt_rows[alt_rows$final_score >= options$suggest_threshold, , drop = FALSE]
            if (nrow(alt_rows) > 0L) {
                loser_pool[[length(loser_pool) + 1L]] <- data.frame(
                    source_term = rep(term, nrow(alt_rows)),
                    column_name = as.character(alt_rows$column_name),
                    score = as.numeric(alt_rows$final_score),
                    name_score = as.numeric(alt_rows$name_score),
                    value_score = as.numeric(alt_rows$value_score),
                    origin = rep("term_alternative", nrow(alt_rows)),
                    stringsAsFactors = FALSE
                )
            }
        }
    }

    proposals_df <- if (length(proposals) > 0L) do.call(rbind, proposals) else data.frame(
        idx = integer(0),
        term = character(0),
        column_name = character(0),
        final_score = numeric(0),
        value_score = numeric(0),
        type_match = numeric(0),
        completeness = numeric(0),
        specificity = numeric(0),
        exact_hits = numeric(0),
        substring_hits = numeric(0),
        name_score = numeric(0),
        stringsAsFactors = FALSE
    )

    loser_df <- if (length(loser_pool) > 0L) do.call(rbind, loser_pool) else data.frame(
        source_term = character(0),
        column_name = character(0),
        score = numeric(0),
        name_score = numeric(0),
        value_score = numeric(0),
        origin = character(0),
        stringsAsFactors = FALSE
    )

    list(
        data = data,
        proposals = proposals_df,
        loser_pool = loser_df,
        terms_with_alternatives = terms_with_alternatives,
        warnings = warnings
    )
}

rostrum_resolve_cross_term_conflicts <- function(data, proposals_df, options) {
    if (!is.data.frame(proposals_df) || nrow(proposals_df) == 0L) {
        return(list(
            data = data,
            loser_pool = data.frame(
                source_term = character(0),
                column_name = character(0),
                score = numeric(0),
                name_score = numeric(0),
                value_score = numeric(0),
                origin = character(0),
                stringsAsFactors = FALSE
            ),
            warnings = character(0)
        ))
    }

    warnings <- character(0)
    loser_rows <- list()
    ambiguity_gap <- rostrum_ambiguity_gap_epsilon(options)

    columns <- unique(as.character(proposals_df$column_name))
    for (col_name in columns) {
        idx <- which(as.character(proposals_df$column_name) == col_name)
        if (length(idx) <= 1L) {
            next
        }

        contenders <- proposals_df[idx, , drop = FALSE]
        tie_order <- order(
            -contenders$final_score,
            -contenders$value_score,
            -contenders$type_match,
            -contenders$completeness,
            -contenders$specificity,
            -contenders$exact_hits,
            contenders$substring_hits,
            contenders$term
        )
        contenders <- contenders[tie_order, , drop = FALSE]
        rownames(contenders) <- NULL

        top_score <- as.numeric(contenders$final_score[[1]])
        first_row <- contenders[1, , drop = FALSE]
        second_row <- contenders[2, , drop = FALSE]
        score_gap <- abs(top_score - as.numeric(second_row$final_score[[1]]))

        if (top_score >= options$suggest_threshold &&
            rostrum_is_technical_tie(first_row, second_row, ambiguity_gap)) {
            ambiguous_mask <- abs(contenders$final_score - top_score) < ambiguity_gap
            ambiguous_rows <- contenders[ambiguous_mask, , drop = FALSE]
            for (k in seq_len(nrow(ambiguous_rows))) {
                row_idx <- as.integer(ambiguous_rows$idx[[k]])
                data$status[[row_idx]] <- "AMBIGUO"
                data$applied[[row_idx]] <- FALSE
                data$selected_col[[row_idx]] <- NA_character_
                data$reason[[row_idx]] <- "ambiguity_detected"
            }

            lose_rows <- contenders[!ambiguous_mask, , drop = FALSE]
            if (nrow(lose_rows) > 0L) {
                for (k in seq_len(nrow(lose_rows))) {
                    row_idx <- as.integer(lose_rows$idx[[k]])
                    data$status[[row_idx]] <- "MANUAL"
                    data$applied[[row_idx]] <- FALSE
                    data$selected_col[[row_idx]] <- NA_character_
                    data$reason[[row_idx]] <- "conflict_lost"
                }
            }

            warnings <- c(
                warnings,
                sprintf("Stage 3 found technical tie on column '%s' (gap=%.4f).", col_name, score_gap)
            )
            next
        }

        winner <- contenders[1, , drop = FALSE]
        winner_idx <- as.integer(winner$idx[[1]])
        if (!identical(as.character(data$reason[[winner_idx]]), "ambiguity_detected")) {
            data$reason[[winner_idx]] <- "conflict_won"
        }

        if (nrow(contenders) > 1L) {
            losers <- contenders[2:nrow(contenders), , drop = FALSE]
            for (k in seq_len(nrow(losers))) {
                row_idx <- as.integer(losers$idx[[k]])
                data$status[[row_idx]] <- "MANUAL"
                data$applied[[row_idx]] <- FALSE
                data$selected_col[[row_idx]] <- NA_character_
                data$reason[[row_idx]] <- "conflict_lost"

                loser_rows[[length(loser_rows) + 1L]] <- data.frame(
                    source_term = as.character(losers$term[[k]]),
                    column_name = as.character(losers$column_name[[k]]),
                    score = as.numeric(losers$final_score[[k]]),
                    name_score = as.numeric(losers$name_score[[k]]),
                    value_score = as.numeric(losers$value_score[[k]]),
                    origin = "cross_term_conflict",
                    stringsAsFactors = FALSE
                )
            }
        }
    }

    loser_df <- if (length(loser_rows) > 0L) do.call(rbind, loser_rows) else data.frame(
        source_term = character(0),
        column_name = character(0),
        score = numeric(0),
        name_score = numeric(0),
        value_score = numeric(0),
        origin = character(0),
        stringsAsFactors = FALSE
    )

    list(
        data = data,
        loser_pool = loser_df,
        warnings = warnings
    )
}

rostrum_apply_loser_fallback <- function(stage3_data, loser_pool, options) {
    if (!is.data.frame(stage3_data) || nrow(stage3_data) == 0) {
        return(list(data = stage3_data, warnings = character(0)))
    }

    data <- rostrum_ensure_engine_columns(stage3_data)
    warnings <- character(0)
    if (!is.data.frame(loser_pool) || nrow(loser_pool) == 0L) {
        return(list(data = data, warnings = warnings))
    }

    ordering <- order(-loser_pool$score, loser_pool$source_term, loser_pool$column_name)
    loser_pool <- loser_pool[ordering, , drop = FALSE]

    for (i in seq_len(nrow(loser_pool))) {
        source_term <- as.character(loser_pool$source_term[[i]])
        target_term <- rostrum_related_verbatim_term(source_term)
        if (is.na(target_term) || !nzchar(target_term)) {
            next
        }

        target_idx <- rostrum_term_index(data, target_term)
        if (is.na(target_idx)) {
            next
        }

        target_col <- rostrum_selected_column(data, target_term)
        if (!is.na(target_col) && nzchar(target_col)) {
            next
        }

        score <- suppressWarnings(as.numeric(loser_pool$score[[i]]))
        if (!is.finite(score) || score < options$suggest_threshold) {
            next
        }

        source_col <- as.character(loser_pool$column_name[[i]])
        if (is.na(source_col) || !nzchar(source_col)) {
            next
        }

        data$selected_col[[target_idx]] <- source_col
        data$status[[target_idx]] <- "SUGERIDO"
        data$reason[[target_idx]] <- "fallback_verbatim_from_loser"
        data$applied[[target_idx]] <- TRUE
        data$name_score[[target_idx]] <- as.numeric(loser_pool$name_score[[i]])
        data$value_score[[target_idx]] <- as.numeric(loser_pool$value_score[[i]])
        data$penalty_score[[target_idx]] <- 0
        data$veto_code[[target_idx]] <- ""
        data$final_score[[target_idx]] <- pmin(1, pmax(options$suggest_threshold, score))
        data$alternatives_json[[target_idx]] <- as.character(jsonlite::toJSON(
            list(list(
                from_term = source_term,
                from_column = source_col,
                score = as.numeric(score),
                origin = as.character(loser_pool$origin[[i]])
            )),
            auto_unbox = TRUE,
            null = "null"
        ))
        data$explain_json[[target_idx]] <- rostrum_update_explain_json(
            data$explain_json[[target_idx]],
            patch = list(stage3_loser_fallback = list(
                from_term = source_term,
                from_column = source_col,
                source_score = as.numeric(score)
            ))
        )
    }

    list(data = data, warnings = warnings)
}

rostrum_apply_verbatim_fallback <- function(stage3_data, min_score = 0.75, blocked_terms = character(0)) {
    if (!is.data.frame(stage3_data) || nrow(stage3_data) == 0) {
        return(list(data = stage3_data, warnings = character(0)))
    }

    data <- rostrum_ensure_engine_columns(stage3_data)
    warnings <- character(0)

    fallback_map <- c(
        decimalLatitude = "verbatimLatitude",
        decimalLongitude = "verbatimLongitude",
        eventDate = "verbatimEventDate"
    )

    for (primary_term in names(fallback_map)) {
        if (primary_term %in% blocked_terms) {
            next
        }
        target_term <- fallback_map[[primary_term]]
        source_idx <- rostrum_term_index(data, primary_term)
        target_idx <- rostrum_term_index(data, target_term)

        if (is.na(source_idx) || is.na(target_idx)) {
            next
        }

        source_col <- rostrum_selected_column(data, primary_term)
        if (is.na(source_col) || !nzchar(source_col)) {
            next
        }

        target_col <- rostrum_selected_column(data, target_term)
        if (!is.na(target_col) && nzchar(target_col)) {
            next
        }

        source_score <- suppressWarnings(as.numeric(data$final_score[[source_idx]]))
        if (!is.finite(source_score) || source_score < min_score) {
            next
        }

        data$selected_col[[target_idx]] <- source_col
        data$status[[target_idx]] <- "SUGERIDO"
        data$reason[[target_idx]] <- "fallback_verbatim_from_primary"
        data$applied[[target_idx]] <- TRUE
        data$name_score[[target_idx]] <- suppressWarnings(as.numeric(data$name_score[[source_idx]]))
        data$value_score[[target_idx]] <- suppressWarnings(as.numeric(data$value_score[[source_idx]]))
        data$penalty_score[[target_idx]] <- 0
        data$veto_code[[target_idx]] <- ""
        data$final_score[[target_idx]] <- pmin(1, pmax(min_score, source_score * 0.90))
        data$alternatives_json[[target_idx]] <- as.character(jsonlite::toJSON(
            list(list(
                from_term = primary_term,
                from_column = source_col,
                score = as.numeric(source_score)
            )),
            auto_unbox = TRUE,
            null = "null"
        ))
        data$explain_json[[target_idx]] <- rostrum_update_explain_json(
            data$explain_json[[target_idx]],
            patch = list(stage35_fallback = list(
                from_term = primary_term,
                from_column = source_col,
                source_score = as.numeric(source_score)
            ))
        )
    }

    list(data = data, warnings = warnings)
}

rostrum_apply_alias_overrides <- function(stage1_data, df, conn, options = rostrum_options(), context = list()) {
    if (!is.data.frame(stage1_data) || nrow(stage1_data) == 0L) {
        return(list(data = stage1_data, warnings = character(0)))
    }
    if (!is.data.frame(df) || ncol(df) == 0L) {
        return(list(data = stage1_data, warnings = character(0)))
    }
    if (is.null(conn) || !DBI::dbIsValid(conn)) {
        return(list(data = stage1_data, warnings = character(0)))
    }

    user_id <- if (!is.null(context$user_id)) context$user_id else Sys.getenv("SAIRA_USER", unset = "")
    institution_id <- if (!is.null(context$institution_id)) context$institution_id else Sys.getenv("SAIRA_INSTITUTION", unset = "")

    data <- rostrum_ensure_engine_columns(stage1_data)
    warnings <- character(0)

    for (col_name in names(df)) {
        alias_hit <- tryCatch(
            rostrum_lookup_alias(
                conn = conn,
                col_name = col_name,
                user_id = user_id,
                institution_id = institution_id
            ),
            error = function(e) NULL
        )
        if (is.null(alias_hit) || !is.data.frame(alias_hit) || nrow(alias_hit) == 0L) {
            next
        }

        term <- as.character(alias_hit$dwc_term[[1]])
        idx <- rostrum_term_index(data, term)
        if (is.na(idx)) {
            next
        }

        confidence <- suppressWarnings(as.numeric(alias_hit$confidence[[1]]))
        if (!is.finite(confidence)) {
            confidence <- options$suggest_threshold
        }
        confidence <- pmin(1, pmax(options$suggest_threshold, confidence))

        current_score <- suppressWarnings(as.numeric(data$final_score[[idx]]))
        if (is.finite(current_score) &&
            identical(toupper(as.character(data$status[[idx]])), "ALIAS") &&
            current_score > confidence) {
            next
        }

        data$selected_col[[idx]] <- as.character(col_name)
        data$name_score[[idx]] <- confidence
        data$value_score[[idx]] <- confidence
        data$penalty_score[[idx]] <- 0
        data$veto_code[[idx]] <- ""
        data$final_score[[idx]] <- confidence
        data$status[[idx]] <- "ALIAS"
        data$reason[[idx]] <- "known_synonym"
        data$applied[[idx]] <- TRUE
        data$alternatives_json[[idx]] <- as.character(jsonlite::toJSON(
            list(list(
                column_name = as.character(col_name),
                final_score = as.numeric(confidence),
                name_score = as.numeric(confidence),
                value_score = as.numeric(confidence),
                source = "alias",
                scope = as.character(alias_hit$scope[[1]])
            )),
            auto_unbox = TRUE,
            null = "null"
        ))
        data$explain_json[[idx]] <- rostrum_update_explain_json(
            data$explain_json[[idx]],
            patch = list(alias = list(
                alias_id = suppressWarnings(as.integer(alias_hit$alias_id[[1]])),
                scope = as.character(alias_hit$scope[[1]]),
                confidence = as.numeric(confidence),
                selected_col = as.character(col_name)
            ))
        )
    }

    list(data = data, warnings = warnings)
}

rostrum_stage1_candidates <- function(df, dwc_terms_df, synonyms_tbl, options = rostrum_options()) {
    start_time <- Sys.time()
    out <- run_rostrum_stage1(
        df = df,
        dwc_terms_df = dwc_terms_df,
        synonyms_tbl = synonyms_tbl,
        options = options
    )
    timing_ms <- as.numeric(difftime(Sys.time(), start_time, units = "secs")) * 1000

    build_rostrum_stage_result(
        success = TRUE,
        data = out,
        warnings = character(0),
        errors = character(0),
        timing_ms = timing_ms
    )
}

rostrum_stage2_compositions <- function(stage1_data, df, options = rostrum_options(), context = list()) {
    start_time <- Sys.time()
    force_fail <- isTRUE(options$force_stage2_error) || isTRUE(context$force_stage2_error)
    if (force_fail) {
        stop("Stage 2 forced failure")
    }

    if (!is.data.frame(stage1_data)) {
        stop("stage1_data must be a data.frame.")
    }
    if (!is.data.frame(df)) {
        stop("df must be a data.frame.")
    }

    data <- rostrum_ensure_engine_columns(stage1_data)
    manual_overrides <- rostrum_parse_manual_overrides(context$manual_overrides)
    composed_from <- rostrum_parse_composed_from(context$composed_from)
    warnings <- character(0)

    scientific_name_out <- rostrum_apply_scientific_name_stage2(
        data = data,
        df = df,
        options = options,
        manual_overrides = manual_overrides,
        composed_from = composed_from
    )
    data <- scientific_name_out$data
    composed_from <- scientific_name_out$composed_from
    warnings <- c(warnings, scientific_name_out$warnings)

    eventdate_out <- rostrum_apply_eventdate_stage2(
        data = data,
        df = df,
        options = options,
        manual_overrides = manual_overrides,
        composed_from = composed_from
    )
    data <- eventdate_out$data
    composed_from <- eventdate_out$composed_from
    warnings <- c(warnings, eventdate_out$warnings)
    composed_result <- tryCatch(
        list(data = rostrum_apply_composed_from_column(data, composed_from), error = NULL),
        error = function(e) list(data = data, error = e$message)
    )
    data <- composed_result$data
    if (!is.null(composed_result$error)) {
        warnings <- c(warnings, paste("composed_from_json serialization failed:", composed_result$error))
    }

    timing_ms <- as.numeric(difftime(Sys.time(), start_time, units = "secs")) * 1000
    build_rostrum_stage_result(
        success = TRUE,
        data = data,
        warnings = unique(warnings),
        errors = character(0),
        timing_ms = timing_ms
    )
}

rostrum_stage3_resolve <- function(stage2_data, df = NULL, options = rostrum_options(), context = list()) {
    start_time <- Sys.time()
    force_fail <- isTRUE(options$force_stage3_error) || isTRUE(context$force_stage3_error)
    if (force_fail) {
        stop("Stage 3 forced failure")
    }

    if (!is.data.frame(stage2_data)) {
        stop("stage2_data must be a data.frame.")
    }

    base_df <- if (is.data.frame(df)) {
        df
    } else if (is.data.frame(context$df)) {
        context$df
    } else {
        data.frame()
    }

    stage3_seed <- rostrum_apply_stage3_candidates(
        stage2_data = stage2_data,
        df = base_df,
        options = options
    )

    conflict_out <- rostrum_resolve_cross_term_conflicts(
        data = stage3_seed$data,
        proposals_df = stage3_seed$proposals,
        options = options
    )

    loser_pool <- if (nrow(stage3_seed$loser_pool) > 0L && nrow(conflict_out$loser_pool) > 0L) {
        rbind(stage3_seed$loser_pool, conflict_out$loser_pool)
    } else if (nrow(stage3_seed$loser_pool) > 0L) {
        stage3_seed$loser_pool
    } else {
        conflict_out$loser_pool
    }

    loser_fallback <- rostrum_apply_loser_fallback(
        stage3_data = conflict_out$data,
        loser_pool = loser_pool,
        options = options
    )

    stage35 <- rostrum_apply_verbatim_fallback(
        stage3_data = loser_fallback$data,
        min_score = options$suggest_threshold,
        blocked_terms = stage3_seed$terms_with_alternatives
    )

    timing_ms <- as.numeric(difftime(Sys.time(), start_time, units = "secs")) * 1000
    build_rostrum_stage_result(
        success = TRUE,
        data = stage35$data,
        warnings = unique(c(
            stage3_seed$warnings,
            conflict_out$warnings,
            loser_fallback$warnings,
            stage35$warnings
        )),
        errors = character(0),
        timing_ms = timing_ms
    )
}

run_rostrum_engine <- function(df, dwc_terms_df, options = rostrum_options(), context = list(), conn = NULL, synonyms_tbl = NULL) {
    start_time <- Sys.time()

    if (!is.data.frame(df)) {
        stop("df must be a data.frame.")
    }
    if (!is.data.frame(dwc_terms_df) || !"term" %in% names(dwc_terms_df)) {
        stop("dwc_terms_df must be a data.frame with a 'term' column.")
    }
    if (is.null(synonyms_tbl)) {
        if (!is.null(conn) && DBI::dbIsValid(conn)) {
            rostrum_seed_synonyms_if_empty(conn)
            synonyms_tbl <- rostrum_load_synonyms_from_db(conn)
        }
        if (is.null(synonyms_tbl)) {
            synonyms_tbl <- load_dwc_synonyms_v1()
        }
    }

    stage1 <- tryCatch(
        rostrum_stage1_candidates(
            df = df,
            dwc_terms_df = dwc_terms_df,
            synonyms_tbl = synonyms_tbl,
            options = options
        ),
        error = function(e) {
            build_rostrum_stage_result(
                success = FALSE,
                data = empty_automap_result_df(),
                warnings = character(0),
                errors = e$message,
                timing_ms = 0
            )
        }
    )

    stage1_data <- if (is.data.frame(stage1$data)) stage1$data else empty_automap_result_df()
    if (!is.null(conn) && DBI::dbIsValid(conn) && nrow(stage1_data) > 0L) {
        alias_out <- tryCatch(
            rostrum_apply_alias_overrides(
                stage1_data = stage1_data,
                df = df,
                conn = conn,
                options = options,
                context = context
            ),
            error = function(e) {
                list(
                    data = stage1_data,
                    warnings = paste("Alias override failed:", e$message)
                )
            }
        )
        stage1_data <- alias_out$data
        stage1$data <- stage1_data
        if (length(alias_out$warnings) > 0L) {
            stage1$warnings <- unique(c(stage1$warnings, alias_out$warnings))
        }
    }

    template_out <- tryCatch(
        rostrum_apply_template_overrides(
            stage_data = stage1_data,
            df = df,
            conn = conn,
            context = context,
            current_version = rostrum_app_version()
        ),
        error = function(e) {
            list(
                data = stage1_data,
                warnings = paste("Template override failed:", e$message),
                applied_n = 0L,
                conflict_n = 0L,
                template_id = NA_character_
            )
        }
    )
    stage1_data <- template_out$data
    stage1$data <- stage1_data
    if (length(template_out$warnings) > 0L) {
        stage1$warnings <- unique(c(stage1$warnings, template_out$warnings))
    }
    if (isTRUE(template_out$applied_n > 0L)) {
        stage1$warnings <- unique(c(
            stage1$warnings,
            sprintf(
                "Template '%s' applied to %d term(s) with %d conflict override(s).",
                as.character(template_out$template_id),
                as.integer(template_out$applied_n),
                as.integer(template_out$conflict_n)
            )
        ))
    }

    stage2 <- tryCatch(
        rostrum_stage2_compositions(
            stage1_data = stage1_data,
            df = df,
            options = options,
            context = context
        ),
        error = function(e) {
            build_rostrum_stage_result(
                success = FALSE,
                data = stage1_data,
                warnings = character(0),
                errors = e$message,
                timing_ms = 0
            )
        }
    )

    stage2_data <- if (is.data.frame(stage2$data)) stage2$data else stage1_data

    stage3 <- tryCatch(
        rostrum_stage3_resolve(
            stage2_data = stage2_data,
            df = df,
            options = options,
            context = context
        ),
        error = function(e) {
            build_rostrum_stage_result(
                success = FALSE,
                data = stage2_data,
                warnings = character(0),
                errors = e$message,
                timing_ms = 0
            )
        }
    )

    final_data <- if (!isTRUE(stage2$success)) {
        stage1_data
    } else if (isTRUE(stage3$success)) {
        stage3$data
    } else {
        stage2$data
    }

    timing_ms <- as.numeric(difftime(Sys.time(), start_time, units = "secs")) * 1000
    warnings <- unique(c(stage1$warnings, stage2$warnings, stage3$warnings))
    errors <- unique(c(stage1$errors, stage2$errors, stage3$errors))

    list(
        success = isTRUE(stage1$success),
        data = final_data,
        stage1 = stage1,
        stage2 = stage2,
        stage3 = stage3,
        warnings = warnings,
        errors = errors,
        timing_ms = timing_ms,
        run_stats = list(
            stage1_ms = stage1$timing_ms,
            stage2_ms = stage2$timing_ms,
            stage3_ms = stage3$timing_ms,
            total_ms = timing_ms
        )
    )
}
