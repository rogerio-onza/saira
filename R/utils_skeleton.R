# Placeholders that a Shiny output shows until its first value (ADR-199).
# Shiny replaces the content of an output when the value arrives, so the
# placeholder needs no code to remove it.

#' Gray shapes in the place of content that is not ready
#'
#' @param kind "cards" (Mapping grid), "pills" (Problems filter), "vocab"
#'   (one vocabulary block) or "rows" (Problems list).
#' @return A tag. Screen readers skip it.
#' @noRd
loading_skeleton <- function(kind = c("cards", "pills", "vocab", "rows")) {
    kind <- match.arg(kind)
    line <- function(width) shiny::tags$span(class = "skeleton-line", style = sprintf("width: %d%%", width))
    card <- function(widths) {
        shiny::div(class = "skeleton-card", line(widths[[1]]), line(widths[[2]]),
                   shiny::div(class = "skeleton-box"))
    }
    body <- switch(kind,
        cards = shiny::div(
            class = "mapping-card-grid",
            lapply(list(c(60, 35), c(50, 30), c(70, 40), c(45, 35), c(55, 30), c(65, 40)), card)
        ),
        pills = shiny::div(
            class = "preview-fix-pills",
            lapply(c(4, 6, 4, 5), function(w) shiny::tags$span(class = "skeleton-pill", style = sprintf("width: %drem", w)))
        ),
        vocab = card(c(60, 90)),
        rows = shiny::div(
            class = "skeleton-rows",
            line(12),
            shiny::div(
                class = "skeleton-table",
                shiny::div(class = "skeleton-row skeleton-head"),
                lapply(c(80, 60, 70, 55, 65), function(w) shiny::div(class = "skeleton-row", line(w)))
            )
        )
    )
    shiny::div(class = "saira-skeleton", `aria-hidden` = "true", body)
}

#' A uiOutput that shows a skeleton until its first value
#' @param output A `shiny::uiOutput()` tag.
#' @param kinds One or more kinds of `loading_skeleton()`, top to bottom.
#' @return The output tag with the skeletons inside.
#' @noRd
with_loading_skeleton <- function(output, kinds) {
    htmltools::tagAppendChildren(output, lapply(kinds, loading_skeleton))
}
