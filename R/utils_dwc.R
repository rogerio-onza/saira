# Title: Darwin Core Utilities
# Author: Rogério Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

#' Validate coordinates (WGS84)
#'
#' @param lat Numeric vector of latitudes
#' @param lon Numeric vector of longitudes
#' @return Data frame with validation results
#' @export
validate_coords <- function(lat, lon) {
    # Convert to numeric if needed
    lat <- suppressWarnings(as.numeric(gsub(",", ".", lat)))
    lon <- suppressWarnings(as.numeric(gsub(",", ".", lon)))

    # Check ranges
    lat_valid <- !is.na(lat) & lat >= -90 & lat <= 90
    lon_valid <- !is.na(lon) & lon >= -180 & lon <= 180

    # Combined validity
    valid <- lat_valid & lon_valid

    # Generate error messages
    error <- rep(NA_character_, length(lat))
    error[!lat_valid & !is.na(lat)] <- "Latitude out of range (-90 to 90)"
    error[!lon_valid & !is.na(lon)] <- "Longitude out of range (-180 to 180)"
    error[is.na(lat) | is.na(lon)] <- "Missing coordinates"

    return(data.frame(
        decimalLatitude = lat,
        decimalLongitude = lon,
        valid = valid,
        error = error,
        stringsAsFactors = FALSE
    ))
}

#' Check for unique occurrence IDs
#'
#' @param ids Character vector of occurrence IDs
#' @return Logical vector indicating uniqueness
#' @export
validate_occurrence_id <- function(ids) {
    !duplicated(ids) & !is.na(ids) & ids != ""
}

#' Load Darwin Core terms from RDS
#'
#' @return Data frame with DwC terms
#' @export
load_dwc_terms_rds <- function() {
    candidates <- c(
        system.file("data", "dwc_terms.rds", package = "finch"),
        here::here("data", "dwc_terms.rds"),
        file.path("data", "dwc_terms.rds"),
        file.path("..", "..", "data", "dwc_terms.rds")
    )
    candidates <- unique(candidates[nzchar(candidates)])
    path <- candidates[file.exists(candidates)][1]

    if (is.null(path) || !file.exists(path)) {
        stop("dwc_terms.rds not found in expected locations.")
    }

    readRDS(path)
}

#' Get Darwin Core terms for SiBBr
#'
#' @return Data frame with DwC terms
#' @export
get_dwc_terms <- function() {
    load_dwc_terms_rds()
}

#' Get required Darwin Core terms
#'
#' @return Data frame with required DwC terms
#' @export
get_required_dwc_terms <- function() {
    terms <- load_dwc_terms_rds()
    terms[terms$required, , drop = FALSE]
}

#' Get Darwin Core terms as list
#'
#' Returns DwC terms in list format for the mapping module UI.
#' Each item has: term, category, desc, sep
#'
#' @param lang Language code ("pt" or "en")
#' @return Named list of DwC term definitions
#' @export
get_dwc_terms_list <- function(lang = "en") {
    terms_df <- load_dwc_terms_rds()

    terms_list <- lapply(seq_len(nrow(terms_df)), function(i) {
        term_val <- as.character(terms_df$term[i])
        class_val <- as.character(terms_df$class[i])

        desc <- if (lang == "pt" && "definition_pt" %in% names(terms_df)) {
            as.character(terms_df$definition_pt[i])
        } else if ("definition_en" %in% names(terms_df)) {
            as.character(terms_df$definition_en[i])
        } else {
            ""
        }

        required_val <- if ("required" %in% names(terms_df)) {
            isTRUE(terms_df$required[i])
        } else {
            FALSE
        }

        list(
            term = term_val,
            category = class_val,
            desc = desc,
            sep = "",
            required = required_val
        )
    })

    names(terms_list) <- terms_df$term
    return(terms_list)
}
