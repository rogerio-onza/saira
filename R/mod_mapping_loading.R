# Title: Mapping Module - Loading Modal Helpers
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.0
# Extracted from mod_mapping.R (Onda 5, Item 5.2)

#' Loading phrase specifications for the automap loading modal
#' @noRd
mapping_loading_phrase_specs <- function() {
    list(
        list(key = "loading_automap_phrase_1", icon = "table-list"),
        list(key = "loading_automap_phrase_2", icon = "microscope"),
        list(key = "loading_automap_phrase_3", icon = "seedling"),
        list(key = "loading_automap_phrase_4", icon = "calendar-days"),
        list(key = "loading_automap_phrase_5", icon = "list-check"),
        list(key = "loading_automap_phrase_6", icon = "right-left"),
        list(key = "loading_automap_phrase_7", icon = "filter"),
        list(key = "loading_automap_phrase_8", icon = "table")
    )
}

#' Loading phrase specifications for the template import modal
#'
#' A template import looks like an auto-mapping run from the outside (the
#' cards fill themselves in), so these phrases say that it is not one.
#' @noRd
mapping_import_phrase_specs <- function() {
    list(
        list(key = "loading_import_phrase_1", icon = "file-import"),
        list(key = "loading_import_phrase_2", icon = "table-list"),
        list(key = "loading_import_phrase_3", icon = "database"),
        list(key = "loading_import_phrase_4", icon = "table")
    )
}

#' Update automap loading progress and phrase index
#' @noRd
update_automap_loading <- function(rv, step, total_steps) {
    specs <- mapping_loading_phrase_specs()
    total_steps <- max(1L, as.integer(total_steps))
    bounded_step <- max(0L, min(as.integer(step), total_steps))
    phrase_count <- length(specs)
    phrase_order <- shiny::isolate(rv$automap_phrase_order)
    if (length(phrase_order) != phrase_count) {
        phrase_order <- seq_len(phrase_count)
    }

    rv$automap_progress <- as.integer(round((bounded_step / total_steps) * 100))
    phrase_pos <- ((bounded_step %% phrase_count) + 1L)
    rv$automap_phrase_idx <- as.integer(phrase_order[[phrase_pos]])
}

#' Show the mapping loading modal with animated phrases
#'
#' Shared by the auto-map run and the template import. The CSS hooks keep the
#' \code{automap-loading-*} names they were written with; only the phrases,
#' title and status line vary between the two callers.
#' @noRd
show_mapping_loading_modal <- function(
    rv, ns, lang_r,
    specs = mapping_loading_phrase_specs(),
    title_key = "loading_automap_title",
    status_key = "loading_automap_status"
) {
    phrase_count <- length(specs)
    rv$automap_progress <- 0L
    rv$automap_phrase_order <- sample(seq_len(phrase_count))
    rv$automap_phrase_idx <- rv$automap_phrase_order[[1]]
    ordered_specs <- specs[rv$automap_phrase_order]
    first_spec <- ordered_specs[[1]]
    status_template <- tr(status_key, lang_r())
    status_prefix <- trimws(gsub("%s%%", "", status_template, fixed = TRUE))
    if (!nzchar(status_prefix)) {
        status_prefix <- tr("loading", lang_r())
    }
    rotate_script <- module_behavior_call("mappingLoadingModal", list(
        iconId = ns("automap_loading_phrase_icon"),
        textId = ns("automap_loading_phrase_text"),
        rowId = ns("automap_loading_phrase_row"),
        poolId = ns("automap_loading_phrase_pool"),
        progressId = ns("automap_loading_progress_bar"),
        statusId = ns("automap_loading_status_text"),
        timerKey = ns("automap_loading_phrase_timer"),
        statusPrefix = status_prefix,
        progress = rv$automap_progress
    ))
    shiny::showModal(shiny::modalDialog(
        shiny::div(
            class = "automap-loading-modal",
            shiny::div(
                class = "automap-loading-brand-row",
                ph_icon("dove", class = "automap-loading-brand-icon")
            ),
            shiny::div(
                class = "automap-loading-title",
                tr(title_key, lang_r())
            ),
            shiny::div(
                class = "automap-loading-progress",
                shiny::div(
                    id = ns("automap_loading_progress_bar"),
                    class = "automap-loading-progress-bar",
                    style = paste0("width: ", rv$automap_progress, "%;")
                )
            ),
            shiny::div(
                class = "automap-loading-status",
                shiny::span(
                    id = ns("automap_loading_status_text"),
                    sprintf(tr(status_key, lang_r()), rv$automap_progress)
                )
            ),
            shiny::div(
                class = "automap-loading-phrase",
                shiny::div(
                    class = "automap-loading-phrase-row",
                    id = ns("automap_loading_phrase_row"),
                    ph_icon(
                        first_spec$icon,
                        id = ns("automap_loading_phrase_icon"),
                        class = "automap-loading-phrase-icon"
                    ),
                    shiny::span(
                        tr(first_spec$key, lang_r()),
                        id = ns("automap_loading_phrase_text")
                    )
                ),
                shiny::div(
                    id = ns("automap_loading_phrase_pool"),
                    style = "display: none;",
                    lapply(ordered_specs, function(spec) {
                        shiny::span(
                            class = "automap-loading-phrase-item",
                            `data-icon` = ph_icon_name(spec$icon),
                            tr(spec$key, lang_r())
                        )
                    })
                ),
                shiny::tags$script(shiny::HTML(rotate_script))
            )
        ),
        easyClose = FALSE,
        footer = NULL,
        fade = TRUE
    ))
}

#' Hide the mapping loading modal
#' @noRd
hide_mapping_loading_modal <- function(session = shiny::getDefaultReactiveDomain()) {
    shiny::removeModal(session = session)
}
