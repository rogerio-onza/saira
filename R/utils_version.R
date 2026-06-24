# Title: Package Version / Session Staleness Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-06-24
# Version: 1.0

#' Detect a stale R session (loaded namespace older than the installed package)
#'
#' After a user updates Saira (e.g. via \code{pak} or reinstall) without
#' restarting R, the running session keeps executing the previously loaded
#' namespace while the on-disk package is newer, so the app appears to behave
#' like the old version. The two versions then diverge:
#' \code{getNamespaceVersion()} reports the loaded version, while
#' \code{utils::packageVersion()} re-reads the installed DESCRIPTION from disk.
#' Under \code{pkgload::load_all()} both resolve to the same repo version, so dev
#' sessions are never flagged.
#'
#' @param loaded Loaded namespace version. Defaults to the live lookup.
#' @param installed Installed on-disk version. Defaults to the live lookup.
#' @return A list with \code{stale} (logical), \code{loaded} and \code{installed}
#'   (character; \code{NA} when a lookup failed).
#' @noRd
saira_session_is_stale <- function(loaded = NULL, installed = NULL) {
    if (is.null(loaded)) {
        loaded <- tryCatch(
            as.character(getNamespaceVersion("saira")),
            error = function(e) NA_character_
        )
    }
    if (is.null(installed)) {
        installed <- tryCatch(
            as.character(utils::packageVersion("saira")),
            error = function(e) NA_character_
        )
    }

    stale <- !is.na(loaded) && !is.na(installed) && !identical(loaded, installed)
    list(stale = stale, loaded = loaded, installed = installed)
}

#' Version actually loaded in this R session
#'
#' The running code is the loaded namespace, which may differ from the on-disk
#' version (see \code{saira_session_is_stale()}). Falls back to the installed
#' version if the namespace lookup fails.
#'
#' @return Character scalar, e.g. \code{"0.9.1"}.
#' @noRd
saira_running_version <- function() {
    tryCatch(
        as.character(getNamespaceVersion("saira")),
        error = function(e) tryCatch(
            as.character(utils::packageVersion("saira")),
            error = function(e2) NA_character_
        )
    )
}

#' URL of the release notes ("Atualizações") page on the help site
#'
#' Language-aware so an EN session links to the English releases page.
#'
#' @param lang Active language code (\code{"pt"} or \code{"en"}).
#' @return Absolute URL string to the releases page.
#' @noRd
saira_releases_url <- function(lang = "pt") {
    base <- "https://rogerio-onza.github.io/saira"
    if (identical(as.character(lang), "en")) {
        paste0(base, "/en/releases.html")
    } else {
        paste0(base, "/novidades.html")
    }
}

#' Warn in-app when the R session is running a stale Saira version
#'
#' Registers a one-time sticky warning notification (in the active language)
#' telling the user to restart R. No-op when the session is current. Kept out of
#' \code{app_server()} so the orchestrator stays free of conditional logic.
#'
#' @param session The Shiny session.
#' @param lang_r A reactive returning the active language code.
#' @param status Result of \code{saira_session_is_stale()}; injectable for tests.
#' @return Invisibly \code{TRUE} when a warning was scheduled, else \code{FALSE}.
#' @noRd
notify_session_stale <- function(session, lang_r, status = saira_session_is_stale()) {
    if (!isTRUE(status$stale)) {
        return(invisible(FALSE))
    }

    shiny::observeEvent(lang_r(),
        {
            lang <- lang_r()
            shiny::showNotification(
                ui = shiny::tags$div(
                    shiny::tags$strong(tr("session_stale_title", lang)),
                    shiny::tags$br(),
                    sprintf(
                        tr("session_stale_body", lang),
                        paste0("v", status$loaded),
                        paste0("v", status$installed)
                    )
                ),
                type = "warning",
                duration = NULL,
                id = "saira-session-stale",
                session = session
            )
        },
        once = TRUE,
        ignoreNULL = TRUE
    )

    invisible(TRUE)
}
