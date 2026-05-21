# Title: Upload Module Helpers
# Author: Rogerio Nunes Oliveira
# Date: 2026-05-20
# ADR-097: Pure UI builders for the format-requirements panel that swaps
# between CSV (Darwin Core terms) and Camtrap DP (expected files) modes.

#' Build the CSV mode "format requirements" body
#'
#' @param required_terms Data frame with columns `term`, `class`,
#'   `definition_pt`, `definition_en` filtered to the required DwC terms.
#' @param lang Language code, "pt" or "en".
#' @return A `shiny.tag` representing the colored DwC term groups.
#' @keywords internal
upload_csv_requirements_ui <- function(required_terms, lang) {
    if (!is.data.frame(required_terms) || nrow(required_terms) == 0L) {
        return(shiny::div(
            class = "alert alert-warning",
            shiny::icon("exclamation-triangle"),
            " ",
            tr("dwc_required_empty", lang)
        ))
    }

    class_labels <- c(
        "Record-level" = tr("class_record", lang),
        "Occurrence" = tr("class_occurrence", lang),
        "Location" = tr("class_location", lang),
        "Taxon" = tr("class_taxon", lang)
    )
    category_order <- c("Record-level", "Occurrence", "Taxon", "Location")
    class_fallback <- c(
        "scientificName" = "Taxon",
        "eventDate" = "Occurrence",
        "decimalLatitude" = "Location",
        "decimalLongitude" = "Location",
        "basisOfRecord" = "Record-level",
        "occurrenceID" = "Occurrence"
    )

    view <- required_terms
    fallback_classes <- unname(class_fallback[view$term])
    invalid_class <- !view$class %in% names(class_labels)
    view$class[invalid_class] <- fallback_classes[invalid_class]
    view$class[is.na(view$class)] <- "Record-level"
    categories_available <- category_order[category_order %in% unique(view$class)]

    groups_ui <- lapply(categories_available, function(category_name) {
        category_label <- class_labels[[category_name]]
        group_df <- view[view$class == category_name, , drop = FALSE]
        category_slug <- switch(
            category_name,
            "Record-level" = "record-level",
            "Occurrence" = "occurrence",
            "Taxon" = "taxon",
            "Location" = "location",
            "record-level"
        )

        chips_ui <- lapply(seq_len(nrow(group_df)), function(i) {
            term <- group_df$term[i]
            definition <- if (lang == "pt") group_df$definition_pt[i] else group_df$definition_en[i]
            shiny::tags$span(
                class = "dwc-term-chip",
                title = if (is.na(definition)) "" else definition,
                term
            )
        })

        shiny::div(
            class = paste("dwc-inline-group", paste0("dwc-inline-group--", category_slug)),
            shiny::div(
                class = paste("dwc-inline-group-label", paste0("dwc-group-badge--", category_slug)),
                category_label
            ),
            shiny::div(class = "dwc-term-chip-list", chips_ui)
        )
    })

    shiny::tagList(
        shiny::tags$p(
            tr("dwc_required_hint", lang),
            class = "dwc-required-hint"
        ),
        shiny::div(
            class = "dwc-inline-groups",
            groups_ui
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
                shiny::icon("file-lines", class = "fa-regular")
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
                shiny::icon("box-archive", class = "fa-solid"),
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
