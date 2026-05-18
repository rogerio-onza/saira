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
