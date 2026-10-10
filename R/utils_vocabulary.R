# Title: Controlled Vocabulary Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-10-08
# Version: 1.0

#' @include utils_common.R
NULL

# Terms whose values Saira converts to a controlled vocabulary. The concepts
# for sex and lifeStage are the GBIF vocabularies (api.gbif.org/v1/vocabularies),
# written in lowercase as in the Darwin Core examples.
vocabulary_terms <- c("occurrenceStatus", "sex", "lifeStage")

vocabulary_cache <- create_rds_cache("vocabulary_values")

vocabulary_key <- function(x) {
    gsub("\\s+", " ", trimws(tolower(as.character(x))))
}

#' Load the controlled vocabulary table
#'
#' One row per spreadsheet value Saira knows for a term. `auto = TRUE` rows are
#' converted on mapping. `auto = FALSE` rows are only suggestions, because the
#' value has more than one plausible meaning ("filhote" is a juvenile or a
#' nestling), so the user picks.
#'
#' @return Data frame with columns `term`, `value`, `target`, `auto`, `key`.
#' @noRd
vocabulary_values_table <- function() {
    cached <- vocabulary_cache$get()
    if (!is.null(cached)) {
        return(cached)
    }
    candidates <- c(
        system.file("extdata", "vocabulary_values.csv", package = "saira"),
        file.path("inst", "extdata", "vocabulary_values.csv")
    )
    path <- candidates[nzchar(candidates) & file.exists(candidates)][1]
    if (is.na(path)) {
        stop("vocabulary_values.csv not found.", call. = FALSE)
    }
    tbl <- utils::read.csv(path, encoding = "UTF-8", stringsAsFactors = FALSE,
                           colClasses = "character")
    tbl$auto <- tbl$auto == "TRUE"
    tbl$key <- vocabulary_key(tbl$value)
    vocabulary_cache$set(tbl, path = path)
}

#' Concepts of a controlled vocabulary term
#'
#' @param term A name in `vocabulary_terms`.
#' @return Character vector of the accepted values, in table order.
#' @noRd
vocabulary_concepts <- function(term) {
    tbl <- vocabulary_values_table()
    rows <- tbl$term == term & tbl$value == tbl$target
    unique(tbl$target[rows])
}

#' Convert spreadsheet values to a controlled vocabulary
#'
#' A known value becomes its concept ("M" -> "male", "visto" -> "present").
#' An unknown or ambiguous value keeps its trimmed text, so the Preview can show
#' it to the user instead of guessing. Blank values become NA.
#'
#' @param term A name in `vocabulary_terms`.
#' @param raw_values Vector from the source column.
#' @return Character vector of the same length.
#' @noRd
map_vocabulary_values <- function(term, raw_values) {
    if (is.null(raw_values)) return(character(0))
    x <- trimws(as.character(raw_values))
    out <- x
    tbl <- vocabulary_values_table()
    tbl <- tbl[tbl$term == term & tbl$auto, , drop = FALSE]
    hit <- match(vocabulary_key(x), tbl$key)
    out[!is.na(hit)] <- tbl$target[hit[!is.na(hit)]]
    out[is.na(raw_values) | !nzchar(x)] <- NA_character_
    out
}

#' Suggested concepts for a value Saira did not convert
#'
#' @param term A name in `vocabulary_terms`.
#' @param value One spreadsheet value.
#' @return Character vector of concepts, empty when none is known.
#' @noRd
vocabulary_suggestions <- function(term, value) {
    tbl <- vocabulary_values_table()
    unique(tbl$target[tbl$term == term & tbl$key == vocabulary_key(value)])
}
