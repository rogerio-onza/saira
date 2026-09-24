# Title: Upload Module Helpers
# Author: Rogerio Nunes Oliveira
# Date: 2026-05-20
# ADR-097: Pure UI builders for the format-requirements panel that swaps
# between CSV (Darwin Core terms) and Camtrap DP (expected files) modes.

#' Build the CSV mode "format requirements" body
#'
#' @param required_terms Data frame with columns `term`,
#'   `definition_pt`, `definition_en` filtered to the required DwC terms.
#' @param lang Language code, "pt" or "en".
#' @return A `shiny.tag` with one row per term (name and definition) and the
#'   upload tips.
#' @keywords internal
upload_csv_requirements_ui <- function(required_terms, lang) {
    if (!is.data.frame(required_terms) || nrow(required_terms) == 0L) {
        return(shiny::div(
            class = "alert alert-warning",
            ph_icon("exclamation-triangle"),
            " ",
            tr("dwc_required_empty", lang)
        ))
    }

    definitions <- if (lang == "pt") required_terms$definition_pt else required_terms$definition_en
    definitions[is.na(definitions)] <- ""

    rows_ui <- lapply(seq_len(nrow(required_terms)), function(i) {
        shiny::div(
            class = "home-term-row",
            shiny::tags$span(class = "home-term-name", required_terms$term[i]),
            shiny::tags$span(class = "home-term-def", definitions[i])
        )
    })

    shiny::tagList(
        shiny::tags$p(tr("home_required_hint", lang), class = "home-aside-hint"),
        shiny::div(class = "home-term-list", rows_ui),
        shiny::div(
            class = "home-aside-notes",
            shiny::tags$p(tr("upload_recommendation", lang)),
            shiny::tags$p(tr("home_guide_tip", lang)),
            # The navbar tab owns the navigation, so the link clicks it.
            shiny::tags$a(
                href = "#",
                class = "home-wiki-link",
                onclick = "document.querySelector('#main_nav a[data-value=\"wiki\"]').click(); return false;",
                tr("home_wiki_link", lang)
            )
        )
    )
}

#' Build the Camtrap mode "format requirements" body
#'
#' @param lang Language code, "pt" or "en".
#' @return A `shiny.tag` representing the file-row list for Camtrap DP and
#'   Wildlife Insights expected files.
#' @keywords internal
upload_camtrap_requirements_ui <- function(lang) {
    camtrap_rows <- list(
        list(name = "datapackage.json", badge = "required", meta_key = "upload_camtrap_file_descriptor"),
        list(name = "deployments.csv",  badge = "required", meta_key = "upload_camtrap_file_deployments"),
        list(name = "observations.csv", badge = "required", meta_key = "upload_camtrap_file_observations"),
        list(name = "media.csv",        badge = "optional", meta_key = "upload_camtrap_file_media")
    )
    wi_rows <- list(
        list(name = "deployments.csv", badge = "required", meta_key = "upload_camtrap_file_deployments"),
        list(name = "projects.csv",    badge = "required", meta_key = "upload_camtrap_file_wi_projects"),
        list(name = "images_*.csv",    badge = "required", meta_key = "upload_camtrap_file_wi_images"),
        list(name = "cameras.csv",     badge = "optional", meta_key = "upload_camtrap_file_wi_cameras")
    )

    row_ui <- function(r) {
        badge_class <- paste0("upload-file-row-badge is-", r$badge)
        badge_label <- tr(paste0("upload_camtrap_badge_", r$badge), lang)
        shiny::div(
            class = "upload-file-row",
            shiny::div(
                class = "upload-file-row-icon",
                ph_icon("file-lines")
            ),
            shiny::div(
                class = "upload-file-row-name-cell",
                shiny::div(class = "upload-file-row-name", r$name),
                shiny::div(class = "upload-file-row-meta", tr(r$meta_key, lang))
            ),
            shiny::tags$span(class = badge_class, badge_label)
        )
    }

    group_ui <- function(label_key, rows) {
        shiny::div(
            class = "upload-file-list-group",
            shiny::div(
                class = "upload-file-list-group-label",
                ph_icon("box-archive"),
                " ",
                tr(label_key, lang)
            ),
            lapply(rows, row_ui)
        )
    }

    shiny::div(
        class = "upload-file-list",
        group_ui("upload_camtrap_source_camtrap", camtrap_rows),
        group_ui("upload_camtrap_source_wi", wi_rows)
    )
}
