# Title: Preview Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-15
# Version: 1.0

is_preview_filled_value <- function(x) {
    if (is.factor(x)) {
        x <- as.character(x)
    }

    if (is.character(x)) {
        return(!is.na(x) & nzchar(trimws(x)))
    }

    !is.na(x)
}

is_preview_empty_column <- function(x) {
    if (length(x) == 0L) {
        return(TRUE)
    }

    !any(is_preview_filled_value(x))
}

format_preview_percent <- function(num, den) {
    if (is.na(den) || den <= 0) {
        return(0)
    }

    (num / den) * 100
}

compute_preview_unique_id_status <- function(df, id_col = "occurrenceID") {
    if (!(id_col %in% names(df))) {
        return(list(ok = TRUE, duplicates = 0L, auto_generated = TRUE))
    }

    ids <- as.character(df[[id_col]])
    filled <- !is.na(ids) & nzchar(trimws(ids))

    if (!any(filled)) {
        return(list(ok = TRUE, duplicates = 0L, auto_generated = TRUE))
    }

    dup_count <- sum(duplicated(ids[filled]))
    list(
        ok = dup_count == 0L,
        duplicates = as.integer(dup_count),
        auto_generated = FALSE
    )
}

prepare_preview_data <- function(df, max_rows = 100L) {
    if (!is.data.frame(df)) {
        stop("df must be a data.frame.")
    }

    max_rows_int <- as.integer(max_rows)
    if (is.na(max_rows_int) || max_rows_int < 1L) {
        stop("max_rows must be a positive integer.")
    }

    preview_df <- utils::head(df, max_rows_int)
    preview_df <- abbreviate_license_column(preview_df)
    order_columns_dwc_canonical(preview_df)
}

compute_preview_readiness <- function(df, required_fields = character(0)) {
    if (!is.data.frame(df)) {
        stop("df must be a data.frame.")
    }

    total_rows <- nrow(df)

    has_lat <- "decimalLatitude" %in% names(df)
    has_lon <- "decimalLongitude" %in% names(df)
    with_coords <- if (has_lat && has_lon) {
        sum(
            is_preview_filled_value(df$decimalLatitude) &
                is_preview_filled_value(df$decimalLongitude)
        )
    } else {
        0L
    }

    has_event_date <- "eventDate" %in% names(df)
    with_date <- if (has_event_date) {
        sum(is_preview_filled_value(df$eventDate))
    } else {
        0L
    }

    unique_id_status <- compute_preview_unique_id_status(df)
    required_status <- stats::setNames(
        rep(FALSE, length(required_fields)),
        required_fields
    )

    for (field in required_fields) {
        if (field %in% names(df)) {
            required_status[[field]] <- any(is_preview_filled_value(df[[field]]))
        }
    }

    list(
        total_rows = total_rows,
        with_coords_pct = format_preview_percent(with_coords, total_rows),
        with_date_pct = format_preview_percent(with_date, total_rows),
        unique_id_status = unique_id_status,
        required_status = required_status
    )
}

validate_preview_download_requirements <- function(
    df,
    blocking_fields = c(
        "scientificName",
        "eventDate",
        "decimalLatitude",
        "decimalLongitude",
        "basisOfRecord"
    ),
    warning_fields = "occurrenceID"
) {
    if (!is.data.frame(df)) {
        stop("df must be a data.frame.")
    }

    has_rows <- nrow(df) > 0L
    existing_cols <- names(df)
    blocking_missing <- setdiff(blocking_fields, existing_cols)
    warning_missing <- setdiff(warning_fields, existing_cols)

    list(
        ok = has_rows && length(blocking_missing) == 0L,
        has_rows = has_rows,
        blocking_missing = unname(blocking_missing),
        warning_missing = unname(warning_missing)
    )
}
