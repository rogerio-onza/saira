# Title: Translation Dictionary (i18n) — JSON Loader
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 2.0 (Onda 5, Item 5.7 — migrated from inline R list to JSON)
#
# The dictionary is now stored in inst/extdata/i18n.json.
# This file provides the loader with in-process cache (ADR-014 pattern).
# To regenerate the JSON from legacy R source, run: Rscript data-raw/export_i18n.R

# Cache environment for i18n dictionary
#' @include utils_common.R
NULL
i18n_cache <- create_rds_cache("i18n")

#' Load i18n dictionary from JSON
#'
#' Reads inst/extdata/i18n.json with in-process caching. Inline BOM removal
#' for encoding resilience. Validates that all keys have required language slots.
#'
#' @param force Logical; if TRUE, bypasses cache and reloads from disk.
#' @return Named list of named lists (key -> list(pt = ..., en = ...))
#' @noRd
load_i18n_dict <- function(force = FALSE) {
    if (!force && !is.null(i18n_cache$get())) {
        return(i18n_cache$get())
    }

    path <- system.file("extdata", "i18n.json", package = "saira")
    if (!nzchar(path)) {
        path <- file.path("inst", "extdata", "i18n.json") # dev fallback
    }

    if (!file.exists(path)) {
        stop("[Saira] i18n.json not found at: ", path)
    }

    raw <- readLines(path, encoding = "UTF-8", warn = FALSE)
    raw <- paste(raw, collapse = "\n")
    # Inline BOM removal (strip_bom may not be available due to load order)
    raw <- sub("^\uFEFF", "", raw)
    dict <- jsonlite::fromJSON(raw, simplifyVector = FALSE)

    # Validate that all keys have pt and en
    langs <- c("pt", "en")
    for (key in names(dict)) {
        missing <- setdiff(langs, names(dict[[key]]))
        if (length(missing) > 0L) {
            warning(sprintf(
                "[Saira] i18n key '%s' missing languages: %s",
                key, paste(missing, collapse = ", ")
            ))
        }
    }

    i18n_cache$set(dict, path = path)
    dict
}
