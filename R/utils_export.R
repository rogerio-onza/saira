# Title: Export Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

#' Apply manual name-review payload to export data
#'
#' @param df Data frame to export
#' @param payload Optional list with `entries` and `normalize_opts`
#' @return Data frame with review columns and optional scientificName replacements
#' @export
apply_name_review_payload <- function(df, payload = NULL) {
    if (!is.data.frame(df)) {
        return(df)
    }

    out <- df
    n_rows <- nrow(out)
    out$validacao_manual <- rep(FALSE, n_rows)
    out$motivo_revisao <- rep("", n_rows)

    if (n_rows == 0L) {
        return(out)
    }
    if (!("scientificName" %in% names(out))) {
        return(out)
    }
    if (is.null(payload) || !is.list(payload) || is.null(payload$entries) || !is.data.frame(payload$entries)) {
        return(out)
    }

    entries <- payload$entries
    required_cols <- c("query_name", "review_type", "original_name", "corrected_name", "reason", "reviewed_at")
    for (col_name in required_cols) {
        if (!(col_name %in% names(entries))) {
            if (identical(col_name, "reviewed_at")) {
                entries[[col_name]] <- as.POSIXct(character(nrow(entries)), tz = "UTC")
            } else {
                entries[[col_name]] <- rep("", nrow(entries))
            }
        }
    }

    entries <- entries[, required_cols, drop = FALSE]
    entries$query_name <- as.character(entries$query_name)
    entries$review_type <- tolower(as.character(entries$review_type))
    entries$original_name <- as.character(entries$original_name)
    entries$corrected_name <- as.character(entries$corrected_name)
    entries$reason <- as.character(entries$reason)
    entries$reviewed_at <- as.POSIXct(entries$reviewed_at, tz = "UTC")

    keep <- !is.na(entries$query_name) &
        nzchar(entries$query_name) &
        entries$review_type %in% c("confirm", "correct")
    entries <- entries[keep, , drop = FALSE]
    if (nrow(entries) == 0L) {
        return(out)
    }

    ord <- order(entries$query_name, entries$reviewed_at, seq_len(nrow(entries)), na.last = TRUE)
    entries <- entries[ord, , drop = FALSE]
    entries <- entries[!duplicated(entries$query_name, fromLast = TRUE), , drop = FALSE]

    normalize_opts <- payload$normalize_opts
    remove_authors_opt <- TRUE
    ignore_qualifiers_opt <- TRUE
    if (is.list(normalize_opts)) {
        if (is.logical(normalize_opts$remove_authors) && length(normalize_opts$remove_authors) == 1L && !is.na(normalize_opts$remove_authors)) {
            remove_authors_opt <- isTRUE(normalize_opts$remove_authors)
        }
        if (is.logical(normalize_opts$ignore_qualifiers) && length(normalize_opts$ignore_qualifiers) == 1L && !is.na(normalize_opts$ignore_qualifiers)) {
            ignore_qualifiers_opt <- isTRUE(normalize_opts$ignore_qualifiers)
        }
    }

    scientific_name <- as.character(out$scientificName)
    scientific_name[is.na(scientific_name)] <- ""

    # Optimize: normalize only unique names to avoid redundant work on repeated values
    unique_names <- unique(scientific_name)
    unique_normalized <- vapply(unique_names, function(value) {
        normalized <- normalize_scientific_name(
            value,
            remove_authors = remove_authors_opt,
            ignore_qualifiers = ignore_qualifiers_opt
        )
        if (is.na(normalized) || !nzchar(normalized)) {
            trimws(as.character(value))
        } else {
            normalized
        }
    }, FUN.VALUE = character(1))
    query_name <- unique_normalized[match(scientific_name, unique_names)]

    match_idx <- match(query_name, entries$query_name)
    has_review <- !is.na(match_idx)
    if (!any(has_review)) {
        return(out)
    }

    out$validacao_manual[has_review] <- TRUE

    review_type_vec <- rep("", n_rows)
    review_type_vec[has_review] <- entries$review_type[match_idx[has_review]]

    confirm_mask <- has_review & review_type_vec == "confirm"
    if (any(confirm_mask)) {
        out$motivo_revisao[confirm_mask] <- "Confirmado pelo usu\u00E1rio"
    }

    correct_mask <- has_review & review_type_vec == "correct"
    if (any(correct_mask)) {
        correct_idx <- match_idx[correct_mask]
        correction_reason <- trimws(as.character(entries$reason[correct_idx]))
        correction_reason[is.na(correction_reason) | !nzchar(correction_reason)] <- "Corrigido pelo usu\u00E1rio"
        out$motivo_revisao[correct_mask] <- correction_reason

        corrected_name <- trimws(as.character(entries$corrected_name[correct_idx]))
        original_name <- trimws(as.character(entries$original_name[correct_idx]))
        current_name <- as.character(out$scientificName[correct_mask])
        replacement <- corrected_name
        replacement[is.na(replacement) | !nzchar(replacement)] <- original_name[is.na(replacement) | !nzchar(replacement)]
        replacement[is.na(replacement) | !nzchar(replacement)] <- current_name[is.na(replacement) | !nzchar(replacement)]
        out$scientificName[correct_mask] <- replacement
    }

    out
}

#' Process data for DwC-compliant export
#'
#' @param df Data frame with mapped columns
#' @return Data frame with ISO dates, cleaned separators, UUIDs
#' @examples
#' \dontrun{
#'   # Processes mapped data for export (uses taxadb, spatial packages)
#'   processed <- process_for_export(my_mapped_data)
#'   # Returns data with:
#'   # - eventDate in ISO format (YYYY-MM-DD)
#'   # - Coordinate separators normalized (comma -> dot)
#'   # - occurrenceID added if missing
#'   # - License URLs abbreviated
#' }
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
