# Title: Mapping Module - Mapping Cards UI Builder
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.0
# Extracted from mod_mapping.R (Onda 5, Item 5.2)

#' Build one mapping field card UI
#'
#' @param item DwC term list element (with $term, $desc, $category, $sep)
#' @param cols Named character vector of column choices
#' @param current_val Current selected value for this field
#' @param is_mapped Logical, whether this field is currently mapped
#' @param badge_info Badge list or NULL
#' @param ns Namespace function
#' @param lang_r Reactive language code (already evaluated)
#' @param input Shiny input from parent module
#' @param cat_class CSS class for the category
#' @noRd
build_field_card <- function(item, cols, current_val, is_mapped, badge_info, ns, lang_r, input, cat_class) {
    term <- item$term

    shiny::div(
        class = paste("field-card no-break", cat_class, if (is_mapped) "field-mapped" else "field-unmapped"),
        shiny::div(
            class = "field-header-row",
            shiny::div(class = "field-header", term),
            if (!is.null(badge_info) && term != "occurrenceID") {
                shiny::span(
                    class = badge_info$class,
                    title = badge_info$title,
                    badge_info$label
                )
            }
        ),
        shiny::div(class = "field-desc", item$desc),
        if (term == "occurrenceID") {
            shiny::div(
                class = "alert alert-info",
                style = "margin-top: 8px; padding: 8px; font-size: 0.85em;",
                shiny::icon("info-circle"),
                " ", tr("uuid_auto_generated", lang_r)
            )
        } else if (term == "datasetName") {
            # datasetName: dropdown + separate text input
            saved_custom <- shiny::isolate(input$custom_datasetName)
            shiny::tagList(
                shiny::selectInput(
                    ns(paste0("map_", term)),
                    NULL,
                    choices = cols,
                    selected = if (has_selected_value(current_val)) current_val else "",
                    multiple = FALSE,
                    selectize = TRUE,
                    width = "100%"
                ),
                shiny::tags$label(
                    class = "custom-field-label",
                    tr("field_or_type_value", lang_r)
                ),
                shiny::textInput(
                    ns("custom_datasetName"),
                    NULL,
                    value = if (!is.null(saved_custom)) saved_custom else "",
                    placeholder = tr("mapping_dataset_placeholder", lang_r),
                    width = "100%"
                )
            )
        } else if (term == "modified") {
            # modified: checkbox "today" + date picker (ISO 8601)
            saved_check <- shiny::isolate(input$modified_use_today)
            saved_date <- shiny::isolate(input$custom_modified_date)
            shiny::tagList(
                shiny::checkboxInput(
                    ns("modified_use_today"),
                    tr("field_use_today_date", lang_r),
                    value = if (!is.null(saved_check)) saved_check else FALSE
                ),
                shiny::tags$label(
                    class = "custom-field-label",
                    tr("field_choose_date", lang_r)
                ),
                shiny::dateInput(
                    ns("custom_modified_date"),
                    NULL,
                    value = if (!is.null(saved_date)) saved_date else Sys.Date(),
                    format = "yyyy-mm-dd",
                    width = "100%"
                )
            )
        } else if (term == "license") {
            # license: square checkboxes (single-select)
            saved_license <- shiny::isolate(input$custom_license)
            shiny::tagList(
                shiny::tags$label(
                    class = "custom-field-label",
                    tr("field_choose_license", lang_r)
                ),
                shiny::checkboxGroupInput(
                    ns("custom_license"),
                    NULL,
                    choices = c(
                        "CC0 (Public Domain)" = "https://creativecommons.org/publicdomain/zero/1.0/legalcode",
                        "CC-BY 4.0" = "https://creativecommons.org/licenses/by/4.0/legalcode",
                        "CC-BY-NC 4.0" = "https://creativecommons.org/licenses/by-nc/4.0/legalcode"
                    ),
                    selected = if (!is.null(saved_license)) saved_license else character(0),
                    inline = FALSE,
                    width = "100%"
                )
            )
        } else if (term == "language") {
            # language: square checkboxes (single-select)
            saved_lang <- shiny::isolate(input$custom_language)
            shiny::tagList(
                shiny::tags$label(
                    class = "custom-field-label",
                    tr("field_choose_language", lang_r)
                ),
                shiny::checkboxGroupInput(
                    ns("custom_language"),
                    NULL,
                    choices = stats::setNames(
                        c("pt", "en"),
                        c(
                            sprintf("%s (pt)", tr("lang_pt", lang_r)),
                            sprintf("%s (en)", tr("lang_en", lang_r))
                        )
                    ),
                    selected = if (!is.null(saved_lang)) saved_lang else character(0),
                    inline = TRUE,
                    width = "100%"
                )
            )
        } else if (term == "basisOfRecord") {
            basis_selected <- if (has_selected_value(current_val)) {
                as.character(current_val[[1]])
            } else {
                ""
            }

            shiny::tagList(
                shiny::selectInput(
                    ns(paste0("map_", term)),
                    NULL,
                    choices = cols,
                    selected = basis_selected,
                    multiple = FALSE,
                    selectize = TRUE,
                    width = "100%"
                ),
                if (has_selected_value(basis_selected)) {
                    shiny::actionButton(
                        ns("open_basis_of_record_assistant"),
                        tr("bor_assistant_button", lang_r),
                        class = "btn btn-outline-primary btn-sm w-100 mt-2",
                        icon = shiny::icon("list-check")
                    )
                }
            )
        } else if (term == "dynamicProperties") {
            selected_cols <- if (has_selected_value(current_val)) {
                as.character(current_val)
            } else {
                character(0)
            }

            shiny::tagList(
                shiny::selectInput(
                    ns(paste0("map_", term)),
                    NULL,
                    choices = cols,
                    selected = selected_cols,
                    multiple = TRUE,
                    selectize = TRUE,
                    width = "100%"
                ),
                if (length(selected_cols) > 0) {
                    shiny::div(
                        class = "dynprops-keys-block",
                        shiny::tags$label(
                            class = "custom-field-label",
                            tr("dynprops_keys_header", lang_r)
                        ),
                        shiny::tags$p(
                            class = "dynprops-help",
                            tr("dynprops_help", lang_r)
                        ),
                        lapply(selected_cols, function(col_name) {
                            auto_key <- derive_dynprops_key(col_name)
                            input_id <- paste0(
                                "dynprops_key_", make.names(col_name)
                            )
                            saved <- shiny::isolate(input[[input_id]])
                            bslib::layout_columns(
                                col_widths = c(5, 7),
                                shiny::tags$div(
                                    class = "dynprops-source-col",
                                    col_name
                                ),
                                shiny::textInput(
                                    ns(input_id),
                                    NULL,
                                    value = if (!is.null(saved) && nzchar(saved)) {
                                        saved
                                    } else {
                                        ""
                                    },
                                    placeholder = sprintf(
                                        tr("dynprops_key_placeholder", lang_r),
                                        auto_key
                                    ),
                                    width = "100%"
                                )
                            )
                        })
                    )
                }
            )
        } else {
            bslib::layout_columns(
                col_widths = if (item$sep != "") c(8, 4) else c(12),
                shiny::selectInput(
                    ns(paste0("map_", term)),
                    NULL,
                    choices = cols,
                    selected = if (has_selected_value(current_val)) {
                        if (term %in% c("scientificName", "basisOfRecord")) {
                            if (length(current_val) > 0) current_val[[1]] else ""
                        } else {
                            current_val
                        }
                    } else {
                        ""
                    },
                    multiple = !(term %in% c("scientificName", "basisOfRecord")),
                    selectize = TRUE,
                    width = "100%"
                ),
                if (item$sep != "") {
                    shiny::textInput(
                        ns(paste0("sep_", term)),
                        NULL,
                        value = item$sep,
                        placeholder = tr("mapping_separator_placeholder", lang_r),
                        width = "100%"
                    )
                }
            )
        }
    )
}

#' Determine if a mapping field is considered mapped
#'
#' @param term DwC term name
#' @param current_val current mapping value
#' @param input Shiny input
#' @return logical
#' @noRd
is_field_mapped <- function(term, current_val, input) {
    is_mapped <- has_selected_value(current_val)

    if (term == "datasetName") {
        custom_val <- input$custom_datasetName
        if (!is.null(custom_val) && nchar(trimws(custom_val)) > 0) {
            is_mapped <- TRUE
        }
    } else if (term == "occurrenceID") {
        is_mapped <- TRUE
    } else if (term == "modified") {
        is_mapped <- isTRUE(input$modified_use_today) || !is.null(input$custom_modified_date)
    } else if (term == "license") {
        is_mapped <- !is.null(input$custom_license) && length(input$custom_license) > 0
    } else if (term == "language") {
        is_mapped <- !is.null(input$custom_language) && length(input$custom_language) > 0
    }

    is_mapped
}
