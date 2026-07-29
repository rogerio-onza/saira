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
#' @param lang Character. "pt" or "en"
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
#' @return Character vector of language codes
#' @export
get_languages <- function() {
    c("pt", "en")
}

#' Get language display name
#'
#' @param lang_code Character. Language code ("pt" or "en")
#' @return Character. Display name
#' @export
get_language_name <- function(lang_code) {
    names <- list(
        pt = "Portugu\u00EAs",
        en = "English"
    )

    value <- names[[lang_code]]
    if (is.null(value)) {
        return(lang_code)
    }

    value
}

#' Format an integer with locale-aware thousands grouping
#'
#' @param n Numeric or integer scalar.
#' @param lang Character. \code{"pt"} or \code{"en"}.
#' @return Character. Grouped integer string (\code{"1.234.567"} for pt,
#'   \code{"1,234,567"} for en).
#' @export
format_count <- function(n, lang = "en") {
    big <- if (identical(lang, "pt")) "." else ","
    dec <- if (identical(lang, "pt")) "," else "."
    format(n, big.mark = big, decimal.mark = dec, scientific = FALSE, trim = TRUE)
}
