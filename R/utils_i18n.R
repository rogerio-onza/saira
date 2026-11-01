# Title: Internationalization Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-13
# Version: 1.1

# Resolve dictionary from current environment or package namespace
#
# The warm cache is read first: tr() calls this once per invocation and runs
# inside per-row renderers, where the two exists() scans below dominate the
# cost. They stay as the cold path (cache empty: partial test loads, or before
# .onLoad() has warmed it), so the legacy environment/namespace override still
# resolves when it is the only source available.
resolve_i18n_dict <- function() {
    cached <- i18n_cache$get()
    if (!is.null(cached)) {
        return(cached)
    }

    if (exists("i18n_dict", inherits = TRUE)) {
        dict <- get("i18n_dict", inherits = TRUE)
        if (is.list(dict)) {
            return(dict)
        }
    }

    if ("saira" %in% loadedNamespaces()) {
        ns <- asNamespace("saira")
        if (exists("i18n_dict", envir = ns, inherits = FALSE)) {
            dict <- get("i18n_dict", envir = ns, inherits = FALSE)
            if (is.list(dict)) {
                return(dict)
            }
        }
    }

    load_i18n_dict()
}

#' Translate a key to current language
#'
#' @param key Character. Key from i18n_dict
#' @param lang Character. A code from \code{get_languages()}
#' @return Character. Translated string
#' @examples
#' \dontrun{
#'   # Requires i18n_dict to be loaded (done by data_dictionary.R)
#'   tr("app_title", lang = "pt")  # Returns Portuguese translation
#'   tr("app_title", lang = "en")  # Returns English translation
#' }
#' @export
tr <- function(key, lang = "en") {
    dict <- resolve_i18n_dict()

    # Direct [[ lookup instead of `key %in% names(dict)`: names() materialises
    # an 869-element character vector on every call. dict is a list, so [[
    # returns NULL for an absent key instead of erroring.
    entry <- dict[[key]]

    # Fallback to key placeholder if key not found
    if (is.null(entry)) {
        warning(paste("Translation key not found:", key))
        return(paste0("[", key, "]"))
    }

    translation <- entry[[lang]]

    if (is.null(translation)) {
        warning(paste("Translation missing for", key, "in", lang))
        return(entry[["en"]]) # Fallback to English
    }

    return(translation)
}

#' Get all available languages
#'
#' The single list of interface languages. Everything that branches on the
#' language (dictionary validation, per-language data columns, the selector)
#' reads this list, so a new language is added here once.
#'
#' @return Character vector of language codes
#' @export
get_languages <- function() {
    c("pt", "en", "es")
}

#' Get language display name
#'
#' @param lang_code Character. Language code from \code{get_languages()}
#' @return Character. Display name
#' @export
get_language_name <- function(lang_code) {
    names <- list(
        pt = "Portugu\u00EAs",
        en = "English",
        es = "Espa\u00F1ol"
    )

    value <- names[[lang_code]]
    if (is.null(value)) {
        return(lang_code)
    }

    value
}

#' Pick the per-language column of a data frame
#'
#' Reads \code{<stem>_<lang>} (e.g. \code{definition_es}) and falls back to
#' \code{<stem>_en} for a blank cell or an absent column, the same fallback
#' \code{tr()} uses. An older cached rds without the language column keeps
#' working.
#'
#' @param df Data frame.
#' @param stem Column name without the language suffix.
#' @param lang Language code.
#' @return Character vector with one entry per row ("" when neither exists).
#' @noRd
lang_col <- function(df, stem, lang) {
    n <- nrow(df)
    en_col <- paste0(stem, "_en")
    en <- if (en_col %in% names(df)) as.character(df[[en_col]]) else rep("", n)
    en[is.na(en)] <- ""
    col <- paste0(stem, "_", lang)
    if (identical(lang, "en") || !col %in% names(df)) {
        return(en)
    }
    out <- as.character(df[[col]])
    blank <- is.na(out) | !nzchar(out)
    out[blank] <- en[blank]
    out
}

#' Format an integer with locale-aware thousands grouping
#'
#' @param n Numeric or integer scalar.
#' @param lang Character. Language code.
#' @return Character. Grouped integer string (\code{"1.234.567"} for pt and
#'   es, \code{"1,234,567"} for en).
#' @export
format_count <- function(n, lang = "en") {
    dot_group <- lang %in% c("pt", "es")
    big <- if (dot_group) "." else ","
    dec <- if (dot_group) "," else "."
    format(n, big.mark = big, decimal.mark = dec, scientific = FALSE, trim = TRUE)
}
