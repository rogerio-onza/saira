# Title: Export Utilities
# Author: Rogério Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

#' Process data for DwC-compliant export
#'
#' @param df Data frame with mapped columns
#' @return Data frame with ISO dates, cleaned separators, UUIDs
#' @export
process_for_export <- function(df) {
    # Fix dates to ISO format
    df <- fix_dates_to_iso(df)

    # Clean coordinate separators (comma to dot)
    df <- clean_coordinate_separators(df)

    # Add occurrence IDs if missing
    df <- add_occurrence_ids(df)

    # Normalize known Creative Commons license URLs to short labels
    df <- abbreviate_license_column(df)

    return(df)
}

#' Abbreviate Creative Commons license values
#'
#' @param x Character vector with license values
#' @return Character vector with known license URLs abbreviated
#' @export
abbreviate_license <- function(x) {
    x_chr <- as.character(x)
    missing_idx <- is.na(x_chr)
    normalized <- tolower(trimws(x_chr))

    # Normalize common URL variants for stable matching
    normalized <- gsub("^https?://", "", normalized)
    normalized <- gsub("/legalcode/?$", "", normalized)
    normalized <- gsub("/+$", "", normalized)

    out <- x_chr

    is_cc0 <- normalized %in% c(
        "creativecommons.org/publicdomain/zero/1.0",
        "cc0"
    )
    is_cc_by_nc <- normalized %in% c(
        "creativecommons.org/licenses/by-nc/4.0",
        "cc-by-nc"
    )
    is_cc_by <- normalized %in% c(
        "creativecommons.org/licenses/by/4.0",
        "cc-by"
    )

    out[is_cc0] <- "CC0"
    out[is_cc_by_nc] <- "CC-BY-NC"
    out[is_cc_by] <- "CC-BY"
    out[missing_idx] <- NA_character_

    return(out)
}

#' Abbreviate the license column in a data frame
#'
#' @param df Data frame
#' @param col Column name to abbreviate (default: "license")
#' @return Data frame with abbreviated license values when column exists
#' @export
abbreviate_license_column <- function(df, col = "license") {
    if (!(col %in% names(df))) {
        return(df)
    }

    df[[col]] <- abbreviate_license(df[[col]])
    return(df)
}

#' Convert dates to ISO 8601 format
#'
#' @param df Data frame
#' @return Data frame with converted dates
#' @export
fix_dates_to_iso <- function(df) {
    date_cols <- c("eventDate", "dateIdentified", "modified")

    for (col in date_cols) {
        if (col %in% names(df)) {
            original_values <- as.character(df[[col]])
            parsed_values <- parse_dates_to_iso(df[[col]])
            keep_raw <- is.na(parsed_values) & !is.na(original_values) & nzchar(original_values)
            parsed_values[keep_raw] <- original_values[keep_raw]
            df[[col]] <- parsed_values
        }
    }

    return(df)
}

#' Clean coordinate separators (comma to dot)
#'
#' @param df Data frame
#' @return Data frame with cleaned coordinates
#' @export
clean_coordinate_separators <- function(df) {
    coord_cols <- c("decimalLatitude", "decimalLongitude")

    for (col in coord_cols) {
        if (col %in% names(df)) {
            # Replace comma with dot
            df[[col]] <- gsub(",", ".", df[[col]])

            # Convert to numeric
            df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
        }
    }

    return(df)
}

#' Add occurrence IDs if missing
#'
#' @param df Data frame
#' @return Data frame with occurrenceID column
#' @export
add_occurrence_ids <- function(df) {
    if (!"occurrenceID" %in% names(df)) {
        # Generate UUIDs for each row
        df$occurrenceID <- ids::uuid(n = nrow(df))
    } else {
        # Fill missing IDs
        missing <- is.na(df$occurrenceID) | df$occurrenceID == ""
        if (any(missing)) {
            df$occurrenceID[missing] <- ids::uuid(n = sum(missing))
        }
    }

    return(df)
}

#' Validate and clean scientific names
#'
#' @param names_vector Character vector of scientific names
#' @return Character vector of cleaned names
#' @export
clean_scientific_names <- function(names_vector) {
    # Trim whitespace
    names_vector <- trimws(names_vector)

    # Remove multiple spaces
    names_vector <- gsub("\\s+", " ", names_vector)

    # Remove trailing/leading punctuation
    names_vector <- gsub("^[[:punct:]]+|[[:punct:]]+$", "", names_vector)

    return(names_vector)
}
