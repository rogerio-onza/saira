# Title: Common Utility Functions
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.1

#' Create an in-process cache for RDS data
#'
#' Factory function that returns a list with $get(), $set(), $reset(), $state().
#' Eliminates boilerplate across utils_dwc, utils_mapping, utils_coords,
#' and data_dictionary cache implementations (ADR-014 pattern).
#'
#' @param name Character label for debug/logging purposes only
#' @return Named list with cache operations
#' @noRd
create_rds_cache <- function(name = "unnamed") {
    env <- new.env(parent = emptyenv())
    env$value <- NULL
    env$path <- NULL
    env$load_count <- 0L

    list(
        get = function() env$value,
        set = function(value, path = NULL) {
            env$value <- value
            if (!is.null(path)) env$path <- path
            env$load_count <- env$load_count + 1L
            invisible(value)
        },
        reset = function() {
            env$value <- NULL
            env$path <- NULL
            env$load_count <- 0L
            invisible(TRUE)
        },
        state = function() {
            list(
                has_value = !is.null(env$value),
                path = env$path,
                load_count = as.integer(env$load_count)
            )
        }
    )
}

#' Check if a value is blank (NULL, NA, empty, or whitespace-only)
#'
#' @param x A scalar value to check
#' @return TRUE if x is NULL, length-0, NA, or whitespace-only; FALSE otherwise
is_blank_value <- function(x) {
    if (is.null(x) || length(x) == 0) {
        return(TRUE)
    }
    if (is.na(x)) {
        return(TRUE)
    }
    nchar(trimws(as.character(x))) == 0
}

#' Normalize a string for fuzzy column matching
#'
#' Lowercases, transliterates accented characters to ASCII, and replaces all
#' non-alphanumeric characters with spaces. NA inputs propagate as NA.
#'
#' @param x Character scalar or vector to normalize
#' @return Character scalar/vector of the same length with normalized values
#' @noRd
normalize_for_matching <- function(x) {
    x_chr <- as.character(x)
    normalized <- tolower(x_chr)
    translit <- iconv(normalized, to = "ASCII//TRANSLIT")
    normalized[!is.na(translit)] <- translit[!is.na(translit)]
    normalized <- gsub("[^a-z0-9]+", " ", normalized)
    trimws(normalized)
}

#' Tokenize a string for fuzzy column matching
#'
#' Normalizes via \code{normalize_for_matching()} then splits on whitespace.
#' Returns \code{character(0)} for blank, NA, or empty inputs.
#'
#' @param x Character scalar to tokenize (length-1)
#' @return Character vector of lowercase alphanumeric tokens, possibly empty
#' @noRd
tokenize_for_matching <- function(x) {
    normalized <- normalize_for_matching(x)
    if (is_blank_value(normalized) || !nzchar(normalized)) {
        return(character(0))
    }

    parts <- strsplit(normalized, " ", fixed = TRUE)[[1]]
    parts <- trimws(parts)
    parts[nzchar(parts)]
}
