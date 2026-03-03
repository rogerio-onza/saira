# Title: Common Utility Functions
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.0

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

normalize_for_matching <- function(x) {
    x_chr <- as.character(x)
    normalized <- tolower(x_chr)
    translit <- iconv(normalized, to = "ASCII//TRANSLIT")
    normalized[!is.na(translit)] <- translit[!is.na(translit)]
    normalized <- gsub("[^a-z0-9]+", " ", normalized)
    trimws(normalized)
}

tokenize_for_matching <- function(x) {
    normalized <- normalize_for_matching(x)
    if (is_blank_value(normalized) || !nzchar(normalized)) {
        return(character(0))
    }

    parts <- strsplit(normalized, " ", fixed = TRUE)[[1]]
    parts <- trimws(parts)
    parts[nzchar(parts)]
}
