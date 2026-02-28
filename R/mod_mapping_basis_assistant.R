# Title: Mapping Module - BasisOfRecord Assistant
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.0
# Extracted from mod_mapping.R (Onda 5, Item 5.2)

#' Register basisOfRecord assistant outputs and observers
#'
#' Called once from mod_mapping_server to set up all basisOfRecord
#' assistant UI outputs, pagination, and save/open observers.
#'
#' @param input,output,session Shiny module scope
#' @param rv reactiveValues from parent module
#' @param ns namespace function
#' @param lang_r reactive language code
#' @param raw_data_r reactive raw data frame
#' @param basis_of_record_page_size integer page size
#' @param basis_of_record_page_count function returning page count
#' @param get_basis_of_record_page_entries function returning current page entries
#' @param basis_of_record_target_choices function returning selectInput choices
#' @param get_effective_basis_of_record_map function returning effective map
#' @param get_basis_of_record_source_col function returning source column name
#' @param sync_current_page_to_draft function syncing page inputs to draft
#' @noRd
setup_basis_of_record_assistant <- function(
  input, output, session, rv, ns, lang_r, raw_data_r,
  basis_of_record_page_size,
  basis_of_record_page_count,
  get_basis_of_record_page_entries,
  basis_of_record_target_choices,
  get_effective_basis_of_record_map,
  get_basis_of_record_source_col,
  sync_current_page_to_draft
) {
    # --- Progress bar output ---
    output$basis_of_record_assistant_progress <- shiny::renderUI({
        entries <- rv$basis_of_record_entries
        total <- nrow(entries)
        if (total == 0) {
            return(NULL)
        }

        effective_map <- get_effective_basis_of_record_map()
        mapped_values <- effective_map[entries$key]
        mapped_values[is.na(mapped_values)] <- ""
        mapped_count <- sum(nzchar(mapped_values))
        progress_pct <- as.integer(round((mapped_count / total) * 100))

        shiny::div(
            class = "bor-assistant-progress-wrap",
            shiny::div(
                class = "bor-assistant-progress-text",
                sprintf(tr("bor_assistant_progress", lang_r()), mapped_count, total)
            ),
            shiny::div(
                class = "bor-assistant-progress",
                shiny::div(
                    class = "bor-assistant-progress-bar",
                    style = paste0("width: ", progress_pct, "%;")
                )
            )
        )
    })

    # --- Pagination output ---
    output$basis_of_record_assistant_pagination <- shiny::renderUI({
        entries <- rv$basis_of_record_entries
        total <- nrow(entries)
        if (total <= basis_of_record_page_size) {
            return(NULL)
        }

        shiny::div(
            class = "bor-assistant-pagination",
            shiny::actionButton(
                ns("basis_of_record_page_prev"),
                label = tr("bor_assistant_prev", lang_r()),
                class = "btn btn-secondary btn-sm"
            ),
            shiny::actionButton(
                ns("basis_of_record_page_next"),
                label = tr("bor_assistant_next", lang_r()),
                class = "btn btn-secondary btn-sm"
            )
        )
    })

    # --- Mapping rows table output ---
    output$basis_of_record_assistant_rows <- shiny::renderUI({
        entries <- get_basis_of_record_page_entries()
        if (nrow(entries) == 0) {
            return(shiny::div(
                class = "alert alert-info",
                tr("bor_assistant_no_values", lang_r())
            ))
        }

        choices <- basis_of_record_target_choices()
        effective_map <- get_effective_basis_of_record_map()

        shiny::tags$table(
            class = "table table-sm bor-assistant-table",
            shiny::tags$thead(
                shiny::tags$tr(
                    shiny::tags$th(tr("bor_assistant_col_raw", lang_r())),
                    shiny::tags$th(tr("bor_assistant_col_target", lang_r()))
                )
            ),
            shiny::tags$tbody(
                lapply(seq_len(nrow(entries)), function(i) {
                    entry <- entries[i, , drop = FALSE]
                    current_target <- effective_map[[entry$key[[1]]]]
                    if (is.null(current_target)) {
                        current_target <- ""
                    }

                    shiny::tags$tr(
                        shiny::tags$td(
                            shiny::div(
                                class = "bor-assistant-raw-value",
                                entry$raw[[1]]
                            )
                        ),
                        shiny::tags$td(
                            shiny::selectInput(
                                ns(paste0("basis_of_record_target_", entry$idx[[1]])),
                                label = shiny::tags$span(
                                    sprintf(tr("a11y_bor_target_label", lang_r()), entry$raw[[1]]),
                                    class = "visually-hidden"
                                ),
                                choices = choices,
                                selected = current_target,
                                multiple = FALSE,
                                selectize = FALSE,
                                width = "100%"
                            )
                        )
                    )
                })
            )
        )
    })

    # --- Preview table output ---
    output$basis_of_record_assistant_preview <- shiny::renderUI({
        shiny::req(raw_data_r())
        source_col <- get_basis_of_record_source_col()
        if (!nzchar(source_col) || !(source_col %in% names(raw_data_r()))) {
            return(NULL)
        }

        all_raw <- as.character(raw_data_r()[[source_col]])
        all_raw[is.na(raw_data_r()[[source_col]])] <- ""
        effective_map <- get_effective_basis_of_record_map()

        preview_n <- min(5L, length(all_raw))
        if (preview_n == 0) {
            return(NULL)
        }

        preview_raw <- trimws(all_raw[seq_len(preview_n)])
        preview_mapped <- map_basis_of_record_values(
            all_raw[seq_len(preview_n)],
            effective_map
        )
        preview_mapped_display <- ifelse(
            nzchar(preview_mapped),
            preview_mapped,
            tr("bor_assistant_empty_value", lang_r())
        )

        keys <- normalize_basis_of_record_keys(all_raw)
        clean_map <- sanitize_basis_of_record_map(effective_map)
        mapped_all <- unname(clean_map[keys])
        mapped_all[is.na(mapped_all)] <- ""
        non_blank_raw <- nzchar(trimws(all_raw))
        unmapped_row_count <- sum(non_blank_raw & !nzchar(mapped_all))

        shiny::tagList(
            shiny::div(
                class = "bor-assistant-preview-title",
                tr("bor_assistant_preview_title", lang_r())
            ),
            shiny::tags$table(
                class = "table table-sm bor-assistant-preview-table",
                shiny::tags$thead(
                    shiny::tags$tr(
                        shiny::tags$th(tr("bor_assistant_preview_original", lang_r())),
                        shiny::tags$th(tr("bor_assistant_preview_result", lang_r()))
                    )
                ),
                shiny::tags$tbody(
                    lapply(seq_len(preview_n), function(i) {
                        shiny::tags$tr(
                            shiny::tags$td(preview_raw[[i]]),
                            shiny::tags$td(preview_mapped_display[[i]])
                        )
                    })
                )
            ),
            shiny::div(
                class = "bor-assistant-unmapped-count",
                sprintf(tr("bor_assistant_unmapped_rows", lang_r()), unmapped_row_count)
            )
        )
    })

    # --- Page prev/next observers ---
    shiny::observeEvent(input$basis_of_record_page_prev,
        {
            sync_current_page_to_draft()
            current_page <- as.integer(rv$basis_of_record_page)
            rv$basis_of_record_page <- max(1L, current_page - 1L)
        },
        ignoreInit = TRUE
    )

    shiny::observeEvent(input$basis_of_record_page_next,
        {
            sync_current_page_to_draft()
            current_page <- as.integer(rv$basis_of_record_page)
            rv$basis_of_record_page <- min(basis_of_record_page_count(), current_page + 1L)
        },
        ignoreInit = TRUE
    )

    # --- Open assistant observer ---
    shiny::observeEvent(input$open_basis_of_record_assistant, {
        shiny::req(raw_data_r())

        tryCatch(
            {
                source_col <- get_basis_of_record_source_col()
                if (!nzchar(source_col) || !(source_col %in% names(raw_data_r()))) {
                    shiny::showNotification(
                        tr("bor_assistant_select_column_first", lang_r()),
                        type = "warning",
                        duration = 4
                    )
                    return(invisible(NULL))
                }

                entries <- extract_basis_of_record_unique_entries(raw_data_r()[[source_col]])
                existing_map <- sanitize_basis_of_record_map(rv$basis_of_record_map)
                next_map <- existing_map
                next_auto <- stats::setNames(character(0), character(0))

                if (nrow(entries) > 0) {
                    allowed_terms <- get_basis_of_record_terms()
                    match_idx <- match(
                        tolower(trimws(entries$raw)),
                        tolower(allowed_terms)
                    )
                    suggested <- rep("", nrow(entries))
                    matched <- !is.na(match_idx)
                    suggested[matched] <- allowed_terms[match_idx[matched]]
                    next_auto <- stats::setNames(suggested, entries$key)
                }

                rv$basis_of_record_entries <- entries
                rv$basis_of_record_auto_map <- next_auto
                rv$basis_of_record_draft_map <- next_map
                rv$basis_of_record_page <- 1L
                rv$basis_of_record_source_col <- source_col

                shiny::showModal(shiny::modalDialog(
                    title = tr("bor_assistant_title", lang_r()),
                    size = "l",
                    easyClose = TRUE,
                    shiny::div(
                        class = "bor-assistant-modal",
                        shiny::p(
                            class = "bor-assistant-subtitle",
                            tr("bor_assistant_subtitle", lang_r())
                        ),
                        shiny::uiOutput(ns("basis_of_record_assistant_progress")),
                        shiny::uiOutput(ns("basis_of_record_assistant_pagination")),
                        shiny::div(
                            class = "bor-assistant-table-wrap",
                            shiny::uiOutput(ns("basis_of_record_assistant_rows"))
                        ),
                        shiny::hr(),
                        shiny::uiOutput(ns("basis_of_record_assistant_preview"))
                    ),
                    footer = shiny::tagList(
                        shiny::modalButton(tr("btn_cancel", lang_r())),
                        shiny::actionButton(
                            ns("save_basis_of_record_assistant"),
                            tr("bor_assistant_save", lang_r()),
                            class = "btn-primary"
                        )
                    )
                ))
            },
            error = function(e) {
                shiny::showNotification(
                    sprintf(tr("bor_assistant_open_error", lang_r()), e$message),
                    type = "error",
                    duration = 7
                )
            }
        )
    })

    # --- Save assistant observer ---
    shiny::observeEvent(input$save_basis_of_record_assistant, {
        sync_current_page_to_draft()
        entries <- rv$basis_of_record_entries
        effective_map <- get_effective_basis_of_record_map()
        final_map <- stats::setNames(character(0), character(0))

        if (nrow(entries) > 0) {
            final_map <- effective_map[entries$key]
            final_map[is.na(final_map)] <- ""
            final_map <- stats::setNames(as.character(final_map), entries$key)
        }

        rv$basis_of_record_map <- final_map
        rv$basis_of_record_source_col <- get_basis_of_record_source_col()

        shiny::removeModal()
        shiny::showNotification(
            sprintf(
                tr("bor_assistant_saved", lang_r()),
                sum(vapply(final_map, function(x) nzchar(x), FUN.VALUE = logical(1))),
                length(final_map)
            ),
            type = "message",
            duration = 4
        )
    })

    invisible(NULL)
}
