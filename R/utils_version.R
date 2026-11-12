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
#' @param lang Active language code.
#' @return Absolute URL string to the releases page.
#' @noRd
saira_releases_url <- function(lang = "pt") {
    help_site_url(lang, pt = "/novidades.html", en = "/en/releases.html", es = "/es/novedades.html")
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

# New release check (ADR-215) ---------------------------------------------

SAIRA_RELEASES_API <- "https://api.github.com/repos/rogerio-onza/saira/releases/latest"
SAIRA_RELEASES_PAGE <- "https://github.com/rogerio-onza/saira/releases/latest"
SAIRA_UPDATE_CHECK_TTL_S <- 24 * 60 * 60
SAIRA_UPDATE_CHECK_TIMEOUT_S <- 5

#' Whether this process may ask GitHub for the latest release
#'
#' A shared server (SAIRA_PUBLIC) is updated by its admin, not by its users.
#' SAIRA_NO_UPDATE_CHECK is the opt-out for a user who does not want the call.
#' @noRd
update_check_enabled <- function() {
    is_on <- function(var) {
        tolower(trimws(Sys.getenv(var, unset = ""))) %in% c("true", "1", "yes")
    }
    !is_on("SAIRA_PUBLIC") && !is_on("SAIRA_NO_UPDATE_CHECK")
}

#' Version from a release tag ("v1.0.1" -> "1.0.1"), NA for anything else
#' @noRd
release_tag_version <- function(tag) {
    if (!is.character(tag) || length(tag) != 1L || is.na(tag)) {
        return(NA_character_)
    }
    m <- regmatches(tag, regexec("^v?([0-9]+\\.[0-9]+\\.[0-9]+)$", trimws(tag)))[[1L]]
    if (length(m) == 2L) m[[2L]] else NA_character_
}

#' TRUE only when `latest` is a strictly higher version than `current`
#' @noRd
is_newer_release <- function(latest, current) {
    if (length(latest) != 1L || length(current) != 1L || is.na(latest) || is.na(current)) {
        return(FALSE)
    }
    isTRUE(tryCatch(
        package_version(latest) > package_version(current),
        error = function(e) FALSE
    ))
}

#' @noRd
update_check_cache_path <- function() {
    file.path(rostrum_resolve_data_dir(), "update_check.json")
}

#' Cached result of the last check
#'
#' @return NULL when there is no cache or it is older than one day (or in the
#'   future), else a list with `latest` (version string or NA when the last
#'   check failed). A failed check is cached too, so an offline machine asks
#'   once a day, not at every start.
#' @noRd
read_update_check_cache <- function(path, now = Sys.time()) {
    if (!file.exists(path)) {
        return(NULL)
    }
    x <- tryCatch(jsonlite::read_json(path), error = function(e) NULL)
    checked <- suppressWarnings(as.numeric(x$checked_at %||% NA))
    age <- as.numeric(now) - checked
    if (length(age) != 1L || is.na(age) || age < 0 || age > SAIRA_UPDATE_CHECK_TTL_S) {
        return(NULL)
    }
    list(latest = release_tag_version(x$latest %||% NA_character_))
}

#' @noRd
write_update_check_cache <- function(path, latest, now = Sys.time()) {
    tryCatch(
        {
            dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
            jsonlite::write_json(
                list(
                    checked_at = as.numeric(now), latest = latest,
                    shown_for = read_update_shown(path)
                ),
                path,
                auto_unbox = TRUE, na = "null"
            )
            TRUE
        },
        error = function(e) FALSE
    )
}

#' Version whose panel already opened by itself, or NA
#'
#' Read without the TTL: the mark must outlive the daily cache so the panel
#' opens only once per release.
#' @noRd
read_update_shown <- function(path) {
    x <- if (file.exists(path)) tryCatch(jsonlite::read_json(path), error = function(e) NULL)
    release_tag_version(x$shown_for %||% NA_character_)
}

#' @noRd
mark_update_shown <- function(path, version) {
    x <- if (file.exists(path)) tryCatch(jsonlite::read_json(path), error = function(e) NULL)
    x <- x %||% list()
    x$shown_for <- version
    tryCatch(
        {
            dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
            jsonlite::write_json(x, path, auto_unbox = TRUE, na = "null")
            TRUE
        },
        error = function(e) FALSE
    )
}

#' Ask GitHub for the tag of the latest release
#'
#' Runs in a callr process, so it uses only httr2 and base R: callr gives the
#' function a fresh environment without the saira namespace.
#' @return The tag name, or NA on any failure.
#' @noRd
update_check_job <- function(url, timeout_s) {
    resp <- tryCatch(
        httr2::request(url) |>
            httr2::req_headers(Accept = "application/vnd.github+json") |>
            httr2::req_user_agent("saira R package") |>
            httr2::req_timeout(timeout_s) |>
            httr2::req_error(is_error = function(resp) FALSE) |>
            httr2::req_perform(),
        error = function(e) NULL
    )
    if (is.null(resp) || httr2::resp_status(resp) != 200L) {
        return(NA_character_)
    }
    body <- tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)
    tag <- body$tag_name
    if (is.character(tag) && length(tag) == 1L) tag else NA_character_
}

#' Start the check in its own R process, so the session does not wait for
#' the network. NULL when the process cannot start.
#' @noRd
start_update_check_job <- function() {
    tryCatch(
        callr::r_bg(
            update_check_job,
            args = list(url = SAIRA_RELEASES_API, timeout_s = SAIRA_UPDATE_CHECK_TIMEOUT_S),
            libpath = .libPaths(),
            user_profile = FALSE,
            stdout = NULL,
            stderr = NULL,
            supervise = TRUE
        ),
        error = function(e) NULL
    )
}

#' Reactive with the newer release version, NULL while there is none
#'
#' Reads the one-day cache first. Without a fresh cache it starts the check
#' in a background process and polls it once a second, for 30 s at most.
#'
#' @param session The Shiny session.
#' @param current Running version; injectable for tests.
#' @param enabled Result of `update_check_enabled()`; injectable for tests.
#' @param cache_path Cache file; injectable for tests.
#' @param start_job Function that returns a callr process or NULL.
#' @noRd
new_release_reactive <- function(session,
                                 current = saira_running_version(),
                                 enabled = update_check_enabled(),
                                 cache_path = update_check_cache_path(),
                                 start_job = start_update_check_job) {
    newer_rv <- shiny::reactiveVal(NULL)
    if (!isTRUE(enabled)) {
        return(newer_rv)
    }
    publish <- function(latest) {
        if (!is_newer_release(latest, current)) {
            return(invisible(NULL))
        }
        # The panel opens by itself once per release, then only the dot remains.
        auto_open <- !identical(read_update_shown(cache_path), latest)
        if (auto_open) mark_update_shown(cache_path, latest)
        newer_rv(structure(latest, auto_open = auto_open))
    }

    cached <- read_update_check_cache(cache_path)
    if (!is.null(cached)) {
        publish(cached$latest)
        return(newer_rv)
    }

    job <- start_job()
    if (is.null(job)) {
        return(newer_rv)
    }
    deadline <- Sys.time() + 30
    poller <- shiny::observe({
        alive <- tryCatch(job$is_alive(), error = function(e) FALSE)
        if (alive && Sys.time() < deadline) {
            shiny::invalidateLater(1000, session)
            return(invisible(NULL))
        }
        tag <- if (alive) {
            tryCatch(job$kill(), error = function(e) NULL)
            NA_character_
        } else {
            tryCatch(job$get_result(), error = function(e) NA_character_)
        }
        latest <- release_tag_version(tag)
        write_update_check_cache(cache_path, latest)
        poller$destroy()
        publish(latest)
    })
    newer_rv
}

SAIRA_R_UPDATE_COMMAND <- "pak::pak(\"rogerio-onza/saira\")"

#' TRUE in the desktop app: only its shell sets SAIRA_ACCESS_KEY (run_app())
#' @noRd
is_desktop_process <- function() {
    nzchar(Sys.getenv("SAIRA_ACCESS_KEY", unset = ""))
}

#' Navbar version badge, with the new-release panel when one is out
#'
#' Without a newer release this is the plain link to the releases page. With
#' one, the badge gets a dot and opens a panel: the desktop app links to the
#' installer, an R install shows the update command with a Copy button.
#'
#' @param version Running version, e.g. "1.0.0".
#' @param newer Newer release version, or NULL. Its `auto_open` attribute
#'   asks the page to open the panel once.
#' @param lang Active language code.
#' @param desktop TRUE in the desktop app.
#' @noRd
version_badge_ui <- function(version, newer, lang, desktop = is_desktop_process()) {
    label <- paste0("v", version)
    notes_link <- function(class) {
        shiny::tags$a(
            class = class,
            href = saira_releases_url(lang),
            target = "_blank",
            rel = "noopener",
            tr("update_see_notes", lang)
        )
    }
    if (is.null(newer)) {
        return(shiny::tags$a(
            label,
            class = "ver-badge",
            href = saira_releases_url(lang),
            target = "_blank",
            rel = "noopener",
            title = tr("version_badge_title", lang)
        ))
    }

    how_to <- if (isTRUE(desktop)) {
        shiny::div(
            class = "ver-update-actions",
            shiny::tags$a(
                class = "is-primary",
                href = SAIRA_RELEASES_PAGE,
                target = "_blank",
                rel = "noopener",
                tr("update_download_installer", lang)
            ),
            notes_link(NULL)
        )
    } else {
        shiny::tagList(
            shiny::div(class = "ver-update-hint", tr("update_r_hint", lang)),
            shiny::div(
                class = "ver-update-cmd",
                shiny::tags$code(SAIRA_R_UPDATE_COMMAND),
                shiny::tags$button(
                    type = "button",
                    class = "ver-update-copy",
                    `data-copy` = SAIRA_R_UPDATE_COMMAND,
                    `data-done` = tr("update_copied", lang),
                    `aria-label` = tr("update_copy_aria", lang),
                    shiny::tags$i(class = "ph ph-copy", `aria-hidden` = "true"),
                    shiny::tags$span(class = "copy-label", `aria-live` = "polite", tr("update_copy", lang))
                )
            ),
            shiny::div(class = "ver-update-actions", notes_link(NULL))
        )
    }

    shiny::div(
        class = "dropdown ver-update",
        `data-auto-open` = if (isTRUE(attr(newer, "auto_open"))) "true",
        shiny::tags$button(
            type = "button",
            class = "ver-badge has-update",
            `data-bs-toggle` = "dropdown",
            `data-bs-auto-close` = "outside",
            `aria-expanded` = "false",
            `aria-label` = sprintf(tr("update_badge_aria", lang), label, newer),
            label,
            shiny::tags$span(class = "ver-update-dot", `aria-hidden` = "true")
        ),
        shiny::div(
            class = "dropdown-menu dropdown-menu-end ver-update-panel",
            shiny::tags$button(
                type = "button",
                class = "ver-update-close",
                `data-dropdown-close` = "",
                `aria-label` = tr("close", lang),
                shiny::tags$i(class = "ph ph-x", `aria-hidden` = "true")
            ),
            shiny::div(class = "ver-update-title", sprintf(tr("update_available_title", lang), newer)),
            shiny::div(class = "ver-update-sub", sprintf(tr("update_available_running", lang), label)),
            how_to
        )
    )
}
