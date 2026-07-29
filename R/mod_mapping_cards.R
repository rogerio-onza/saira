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
#' @param scientificname_mapped Logical; when TRUE, taxonRank and specificEpithet
#'   are locked because they are derived from scientificName.
#' @param occurrence_id_preserved Logical; when TRUE, the uploaded data already
#'   carries occurrenceID values (e.g. a camera-trap observationID), so the card
#'   says those are preserved instead of auto-generated.
#'
#'   Selection-dependent content (the source sample, the basisOfRecord assistant
#'   button, and the dynamicProperties key inputs) is rendered into a per-term
#'   `carddyn_<term>` uiOutput slot, so picking a column updates only that card
#'   instead of rebuilding the whole 50-selectize grid (see mod_mapping.R).
#' @noRd
build_field_card <- function(item, cols, current_val, is_mapped, badge_info, ns, lang_r, input, cat_class, scientificname_mapped = FALSE, occurrence_id_preserved = FALSE) {
    term <- item$term

    # taxonRank/specificEpithet are inferred from scientificName (see
    # build_processed_mapping_df). When scientificName is mapped, lock these
    # cards with a UUID-style notice instead of a column selector.
    locked_taxon <- isTRUE(scientificname_mapped) &&
        term %in% c("taxonRank", "specificEpithet")

    shiny::div(
        id = ns(paste0("fieldcard_", term)),
        class = paste("field-card no-break", cat_class, if (is_mapped) "field-mapped" else "field-unmapped"),
        shiny::div(
            class = "field-header-row",
            shiny::div(class = "field-header", term),
            if (!is.null(badge_info) && term != "occurrenceID" && !locked_taxon) {
                shiny::span(
                    class = badge_info$class,
                    title = badge_info$title,
                    badge_info$label
                )
            }
        ),
        shiny::div(class = "field-desc", item$desc),
        if (locked_taxon) {
            shiny::div(
                class = "alert alert-info",
                style = "margin-top: 8px; padding: 8px; font-size: 0.85em;",
                shiny::icon("dna"),
                " ", tr("taxon_auto_derived", lang_r)
            )
        } else if (term == "occurrenceID") {
            occ_id_key <- if (isTRUE(occurrence_id_preserved)) {
                "occurrence_id_preserved"
            } else {
                "uuid_auto_generated"
            }
            shiny::div(
                class = "alert alert-info",
                style = "margin-top: 8px; padding: 8px; font-size: 0.85em;",
                shiny::icon("info-circle"),
                " ", tr(occ_id_key, lang_r)
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
                shiny::uiOutput(ns("carddyn_basisOfRecord"))
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
                shiny::uiOutput(ns("carddyn_dynamicProperties"))
            )
        } else {
            is_const_term <- term %in% constant_value_terms()
            map_block <- shiny::tagList(
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
                ),
                shiny::uiOutput(ns(paste0("carddyn_", term)))
            )
            shiny::tagList(
                if (is_const_term) {
                    # Mutually exclusive with the fixed value: while "use a fixed
                    # value" is on, hide the column selector (and its sample, plus
                    # the "OU" divider) so a mapped column cannot be silently
                    # overwritten by the constant at export -- the constant takes
                    # precedence in build_processed_mapping_df. Client-side toggle,
                    # no re-render.
                    shiny::conditionalPanel(
                        condition = paste0("!input.usecustom_", term),
                        ns = ns,
                        map_block,
                        shiny::div(
                            class = "field-or-divider",
                            shiny::span(tr("mapping_or_separator", lang_r))
                        )
                    )
                } else {
                    map_block
                },
                if (is_const_term) {
                    build_constant_value_input(term, ns, lang_r, input)
                }
            )
        }
    )
}

#' Build the opt-in fixed-value input for a constant-value term
#'
#' A `usecustom_<term>` checkbox (with a one-line hint that it ignores the
#' column mapping) reveals (client-side) a tinted "every row" note plus a
#' free-text `custom_<term>` input. Saved values are read with `isolate()` so
#' live typing never re-renders the mapping UI (ADR-098).
#'
#' @param term DwC term name (must be in `constant_value_terms()`).
#' @param ns Namespace function.
#' @param lang_r Reactive language code (already evaluated).
#' @param input Shiny input from parent module.
#' @noRd
build_constant_value_input <- function(term, ns, lang_r, input) {
    saved_use <- shiny::isolate(input[[paste0("usecustom_", term)]])
    saved_val <- shiny::isolate(input[[paste0("custom_", term)]])
    shiny::tagList(
        shiny::div(
            class = "fixed-value-toggle",
            shiny::checkboxInput(
                ns(paste0("usecustom_", term)),
                tr("mapping_use_fixed_value", lang_r),
                value = isTRUE(saved_use)
            ),
            # A div (not <p>): the global `.card p` rule (01-base.css) would win
            # by specificity and force this subtitle to --text-md. .field-desc
            # sidesteps the same rule the same way.
            shiny::div(
                class = "fixed-value-hint",
                tr("mapping_fixed_value_hint", lang_r)
            )
        ),
        shiny::conditionalPanel(
            condition = paste0("input.usecustom_", term),
            ns = ns,
            shiny::div(
                class = "field-allrows-note",
                shiny::icon("info-circle"),
                " ", tr("mapping_fills_every_row", lang_r)
            ),
            shiny::textInput(
                ns(paste0("custom_", term)),
                NULL,
                value = if (!is.null(saved_val)) saved_val else "",
                placeholder = tr(paste0("const_placeholder_", term), lang_r),
                width = "100%"
            )
        )
    )
}

#' Selection-dependent content rendered into a card's `carddyn_<term>` slot.
#'
#' These build the fragments that used to live inline in `build_field_card` and
#' depend on the current selection. They are rendered by per-term `renderUI`
#' outputs in `mod_mapping_server`, so a selection updates only its own card.
#' @noRd
build_basis_assistant_button <- function(current_val, ns, lang_r) {
    basis_selected <- if (has_selected_value(current_val)) {
        as.character(current_val[[1]])
    } else {
        ""
    }
    if (!has_selected_value(basis_selected)) {
        return(NULL)
    }
    shiny::actionButton(
        ns("open_basis_of_record_assistant"),
        tr("bor_assistant_button", lang_r),
        class = "btn btn-outline-primary btn-sm w-100 mt-2",
        icon = shiny::icon("list-check")
    )
}

#' Assistant button, on the establishmentMeans card only.
#'
#' The assistant fills both establishment terms in one modal, so the button
#' belongs to the lead term alone -- rendering it on both cards would put two
#' inputs with the same id on the page. degreeOfEstablishment gets
#' build_establishment_degree_hint() instead.
#'
#' Unlike the basisOfRecord button, this one is always offered: the assistant
#' works off the scientificName column, so it is useful precisely when the
#' term's own column is empty (the common case -- most spreadsheets do not
#' carry establishmentMeans at all).
#' @noRd
build_establishment_assistant_button <- function(ns, lang_r) {
    shiny::actionButton(
        ns("open_establishment_assistant"),
        tr("est_assistant_button", lang_r),
        class = "btn btn-outline-primary btn-sm w-100 mt-2",
        icon = shiny::icon("seedling")
    )
}

#' Note on the degreeOfEstablishment card pointing at its lead term.
#'
#' Uses the same `alert alert-info` shell as the occurrenceID and locked-taxon
#' notices, which is the app's established way of saying "this field is filled
#' another way". The link is a plain anchor: no Shiny input, so no second id
#' competing with the assistant button, and the browser handles the jump.
#' @noRd
build_establishment_degree_hint <- function(ns, lang_r) {
    shiny::div(
        class = "alert alert-info est-degree-hint",
        shiny::icon("link"),
        " ",
        tr("est_degree_card_hint", lang_r),
        " ",
        shiny::tags$a(
            href = paste0("#", ns("fieldcard_establishmentMeans")),
            tr("est_degree_card_hint_link", lang_r)
        )
    )
}

#' "Filled by the assistant" state note on an establishment card.
#'
#' Without this the card reads as untouched after the assistant runs: the
#' column selector is still on "--" and the badge still says MANUAL. Reports
#' what the assistant actually did, and the pending pairs when there are any.
#' @noRd
build_establishment_status_note <- function(answered, missing_degree, lang_r) {
    # The pending line matters most when nothing has been answered yet, so it
    # renders on its own too.
    if (answered <= 0L && missing_degree <= 0L) {
        return(NULL)
    }
    shiny::div(
        class = "est-card-status",
        if (answered > 0L) {
            shiny::div(
                class = "est-card-status-line",
                shiny::icon("wand-magic-sparkles"),
                " ",
                sprintf(tr("est_card_filled_by_assistant", lang_r), answered)
            )
        },
        if (missing_degree > 0L) {
            shiny::div(
                class = "est-card-status-pending",
                sprintf(tr("est_card_pending_degree", lang_r), missing_degree)
            )
        }
    )
}

#' @noRd
build_dynprops_keys_block <- function(current_val, ns, lang_r, input) {
    selected_cols <- if (has_selected_value(current_val)) {
        as.character(current_val)
    } else {
        character(0)
    }
    if (length(selected_cols) == 0) {
        return(NULL)
    }
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
            input_id <- paste0("dynprops_key_", make.names(col_name))
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
                    value = if (!is.null(saved) && nzchar(saved)) saved else "",
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

#' Sample line shown under a card's column selector.
#'
#' Only called for a term that already has a column selected, so an empty
#' sample means "mapped, but the sampled rows are blank" -- previously rendered
#' as nothing, which was indistinguishable from an unmapped card. Purely
#' visual: the returned div never reaches the mapping pipeline. A mapped column
#' whose source rows are blank still exports as "" via replace_na_with_blank(),
#' the DwC blank convention.
#' @noRd
build_field_sample <- function(sample_preview, lang_r) {
    if (length(sample_preview) == 0) {
        return(shiny::div(
            class = "field-card-sample field-card-sample-empty",
            tr("mapping_card_sample_empty", lang_r)
        ))
    }
    shiny::div(
        class = "field-card-sample",
        paste0(
            tr("mapping_card_sample_prefix", lang_r), "  ",
            paste(sample_preview, collapse = "  ")
        )
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
        # Isolated: this free-text value is edited live. A reactive read would
        # re-render the mapping UI mid-typing and blur the field (see the
        # mapping_ui renderUI). The mapped border refreshes on the next render.
        # Checkbox/date custom inputs below stay reactive on purpose.
        custom_val <- shiny::isolate(input$custom_datasetName)
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
    } else if (term %in% constant_value_terms()) {
        # Mapped if a column is selected OR a fixed value is enabled and filled.
        # The checkbox read stays reactive so the mapped border updates live on
        # toggle (a discrete event, like license/language); the free-text value
        # is isolated so typing it does not re-render and blur the field (ADR-098,
        # like datasetName -- the border refreshes on the next render).
        use_const <- input[[paste0("usecustom_", term)]]
        const_val <- shiny::isolate(input[[paste0("custom_", term)]])
        if (isTRUE(use_const) && !is.null(const_val) && nchar(trimws(const_val)) > 0) {
            is_mapped <- TRUE
        }
    }

    is_mapped
}
