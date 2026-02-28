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
