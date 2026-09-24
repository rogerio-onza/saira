# Title: Icon helpers (Phosphor)
# Author: Rogerio Nunes Oliveira
# Date: 2026-09-24
# Version: 1.0

# The app names icons with the Font Awesome names it used before the switch to
# Phosphor. This table translates them in one place, so the call sites and the
# names stored in data (phases, statuses, loading phrases) keep working.
ph_icon_names <- c(
    "arrow-right" = "arrow-right",
    "arrow-up-from-bracket" = "upload-simple",
    "arrow-up-right-from-square" = "arrow-square-out",
    "arrows-up-to-line" = "arrow-line-up",
    "binoculars" = "binoculars",
    "book-open" = "book-open",
    "box-archive" = "archive",
    "bug" = "bug",
    "calendar-days" = "calendar",
    "chevron-down" = "caret-down",
    "circle-check" = "check-circle",
    "circle-info" = "info",
    "circle-notch" = "circle-notch",
    "circle-question" = "question",
    "circle-xmark" = "x-circle",
    "code" = "code",
    "code-compare" = "arrows-left-right",
    "compass" = "compass",
    "database" = "database",
    "dna" = "dna",
    "dove" = "bird",
    "download" = "download-simple",
    "earth-americas" = "globe-hemisphere-west",
    "envelope" = "envelope",
    "exclamation-triangle" = "warning",
    "file-csv" = "file-csv",
    "file-import" = "file-arrow-up",
    "file-lines" = "file-text",
    "file-pdf" = "file-pdf",
    "file-zipper" = "file-zip",
    "filter" = "funnel",
    "flag-checkered" = "flag-checkered",
    "flask" = "flask",
    "gear" = "gear-six",
    "gears" = "gear-six",
    "github" = "github-logo",
    "globe" = "globe",
    "graduation-cap" = "graduation-cap",
    "info-circle" = "info",
    "language" = "translate",
    "layer-group" = "stack",
    "leaf" = "leaf",
    "lightbulb" = "lightbulb",
    "link" = "link",
    "list-check" = "list-checks",
    "lock" = "lock",
    "map-location-dot" = "map-trifold",
    "map-marker-alt" = "map-pin",
    "microscope" = "microscope",
    "party-horn" = "confetti",
    "paw" = "paw-print",
    "play" = "play",
    "plug" = "plug",
    "plus" = "plus",
    "right-left" = "arrows-left-right",
    "rotate-left" = "arrow-counter-clockwise",
    "seedling" = "plant",
    "shield-check" = "shield-check",
    "shield-halved" = "shield-check",
    "spinner" = "spinner-gap",
    "stop" = "stop",
    "table" = "table",
    "table-list" = "list-dashes",
    "tree" = "tree",
    "triangle-exclamation" = "warning",
    "trophy" = "trophy",
    "up-right-from-square" = "arrow-square-out",
    "upload" = "upload-simple",
    "wand-magic-sparkles" = "magic-wand",
    "water" = "waves"
)

#' Phosphor icon name for an app icon name
#'
#' @param name Character vector of icon names (the app's Font Awesome names,
#'   or Phosphor names, which pass through)
#' @return Character vector of Phosphor icon names
#' @noRd
ph_icon_name <- function(name) {
    out <- unname(ph_icon_names[name])
    out[is.na(out)] <- name[is.na(out)]
    out
}

#' Phosphor icon tag
#'
#' Replaces `shiny::icon()`. Regular weight for interface icons, light for the
#' large decorative ones.
#'
#' @param name Icon name, see `ph_icon_name()`
#' @param class Extra classes
#' @param weight "regular" or "light"
#' @param ... Other attributes for the `<i>` tag
#' @return A `shiny.tag`
#' @noRd
ph_icon <- function(name, class = NULL, weight = c("regular", "light"), ...) {
    weight <- match.arg(weight)
    base <- if (identical(weight, "light")) "ph-light" else "ph"
    extra <- if (length(class) > 0L) paste(class, collapse = " ") else ""
    cls <- trimws(gsub("\\s+", " ", paste(base, paste0("ph-", ph_icon_name(name)), extra)))
    shiny::tags$i(class = cls, `aria-hidden` = "true", ...)
}
