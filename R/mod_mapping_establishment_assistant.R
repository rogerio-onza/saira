# Title: Mapping Module - establishmentMeans / degreeOfEstablishment Assistant
# Author: Rogerio Nunes Oliveira
#
# Per-SPECIES assistant for the two TDWG controlled vocabularies. The
# basisOfRecord assistant translates the unique values of a mapped column; this
# one asks once per taxon and expands the answer to every record of that taxon,
# which is what makes a spreadsheet with thousands of rows tractable.
#
# Species already on the bundled invasive list are pre-filled with
# establishmentMeans = "introduced". degreeOfEstablishment is never suggested:
# captive, released and invasive are properties of the record, not of the
# species, so that choice stays with the user.

#' Register establishment assistant outputs and observers
#'
#' Called once from mod_mapping_server. Mirrors
#' setup_basis_of_record_assistant(): pagination with snapshot sync (ADR-017),
#' no continuous observers over the row inputs.
#'
#' @param input,output,session Shiny module scope
#' @param rv reactiveValues from parent module
#' @param ns namespace function
#' @param lang_r reactive language code
#' @param establishment_page_size integer page size
#' @param establishment_page_count function returning page count
#' @param get_establishment_page_entries function returning current page entries
#' @param establishment_choices function(field) returning selectInput choices
#' @param get_effective_establishment_map function returning the effective map
#' @param get_establishment_species function returning the species vector
#' @param sync_establishment_page_to_draft function syncing page inputs to draft
#' @noRd
setup_establishment_assistant <- function(
  input, output, session, rv, ns, lang_r,
  establishment_page_size,
  establishment_page_count,
  get_establishment_page_entries,
  establishment_choices,
  get_effective_establishment_map,
  get_establishment_species,
  sync_establishment_page_to_draft
) {
    # --- Progress + pairing warning ---
    # Reads the visible page's inputs directly (at most `page_size` of them), so
    # the counts move as the user picks without any observer writing rv. That
    # keeps ADR-017's "no reactive cascade" property while still feeling live.
    output$establishment_assistant_progress <- shiny::renderUI({
        entries <- rv$establishment_entries
        total <- nrow(entries)
        if (total == 0) {
            return(NULL)
        }

        effective <- get_effective_establishment_map()
        page_entries <- get_establishment_page_entries()
        means <- effective$means[entries$key]
        degree <- effective$degree[entries$key]
        means[is.na(means)] <- ""
        degree[is.na(degree)] <- ""

        # Overlay the live page inputs on top of the committed/draft state.
        if (nrow(page_entries) > 0) {
            for (i in seq_len(nrow(page_entries))) {
                idx <- page_entries$idx[[i]]
                pos <- match(page_entries$key[[i]], entries$key)
                if (is.na(pos)) next
                live_means <- input[[paste0("est_means_", idx)]]
                live_degree <- input[[paste0("est_degree_", idx)]]
                if (!is.null(live_means)) means[[pos]] <- as.character(live_means)[[1]]
                if (!is.null(live_degree)) degree[[pos]] <- as.character(live_degree)[[1]]
            }
        }

        answered <- sum(nzchar(means))
        missing_degree <- sum(nzchar(means) & !nzchar(degree))
        progress_pct <- as.integer(round((answered / total) * 100))

        shiny::tagList(
            shiny::div(
                class = "bor-assistant-progress-wrap",
                shiny::div(
                    class = "bor-assistant-progress-text",
                    sprintf(tr("est_assistant_progress", lang_r()), answered, total)
                ),
                shiny::div(
                    class = "bor-assistant-progress",
                    shiny::div(
                        class = "bor-assistant-progress-bar",
                        style = paste0("width: ", progress_pct, "%;")
                    )
                )
            ),
            if (missing_degree > 0L) {
                shiny::div(
                    class = "est-assistant-pair-warning",
                    sprintf(tr("est_assistant_missing_degree", lang_r()), missing_degree)
                )
            }
        )
    })

    # --- Pagination ---
    output$establishment_assistant_pagination <- shiny::renderUI({
        entries <- rv$establishment_entries
        if (nrow(entries) <= establishment_page_size) {
            return(NULL)
        }
        shiny::div(
            class = "bor-assistant-pagination",
            shiny::actionButton(
                ns("establishment_page_prev"),
                label = tr("bor_assistant_prev", lang_r()),
                class = "btn btn-secondary btn-sm"
            ),
            shiny::actionButton(
                ns("establishment_page_next"),
                label = tr("bor_assistant_next", lang_r()),
                class = "btn btn-secondary btn-sm"
            )
        )
    })

    # --- Species rows ---
    output$establishment_assistant_rows <- shiny::renderUI({
        entries <- get_establishment_page_entries()
        if (nrow(entries) == 0) {
            return(shiny::div(
                class = "alert alert-info",
                tr("est_assistant_no_species", lang_r())
            ))
        }

        means_choices <- establishment_choices("means")
        degree_choices <- establishment_choices("degree")
        effective <- get_effective_establishment_map()

        shiny::tags$table(
            class = "table table-sm bor-assistant-table est-assistant-table",
            shiny::tags$thead(
                shiny::tags$tr(
                    shiny::tags$th(tr("est_assistant_col_species", lang_r())),
                    shiny::tags$th(tr("est_assistant_col_means", lang_r())),
                    shiny::tags$th(tr("est_assistant_col_degree", lang_r()))
                )
            ),
            shiny::tags$tbody(
                lapply(seq_len(nrow(entries)), function(i) {
                    key <- entries$key[[i]]
                    idx <- entries$idx[[i]]
                    species <- entries$raw[[i]]
                    # Single-bracket: yields NA for an absent name instead of
                    # erroring, so a stale key can never break the modal.
                    current_means <- unname(effective$means[key])
                    current_degree <- unname(effective$degree[key])
                    if (is.na(current_means)) current_means <- ""
                    if (is.na(current_degree)) current_degree <- ""

                    shiny::tags$tr(
                        shiny::tags$td(
                            shiny::div(class = "bor-assistant-raw-value", species),
                            shiny::div(
                                class = "est-assistant-species-meta",
                                sprintf(
                                    tr("est_assistant_record_count", lang_r()),
                                    entries$n_records[[i]]
                                )
                            ),
                            local({
                                origin_class <- entries$origin_class[[i]]
                                if (is.na(origin_class)) {
                                    return(NULL)
                                }
                                alien <- identical(origin_class, "alien")
                                shiny::span(
                                    class = paste(
                                        "vn-status-badge est-assistant-invasive",
                                        if (alien) "badge-error" else "badge-translocated"
                                    ),
                                    tr(
                                        if (alien) {
                                            "est_assistant_invasive_hint"
                                        } else {
                                            "est_assistant_translocated_hint"
                                        },
                                        lang_r()
                                    )
                                )
                            })
                        ),
                        shiny::tags$td(
                            shiny::selectInput(
                                ns(paste0("est_means_", idx)),
                                label = shiny::tags$span(
                                    sprintf(tr("a11y_est_means_label", lang_r()), species),
                                    class = "visually-hidden"
                                ),
                                choices = means_choices,
                                selected = current_means,
                                multiple = FALSE, selectize = FALSE, width = "100%"
                            )
                        ),
                        shiny::tags$td(
                            shiny::selectInput(
                                ns(paste0("est_degree_", idx)),
                                label = shiny::tags$span(
                                    sprintf(tr("a11y_est_degree_label", lang_r()), species),
                                    class = "visually-hidden"
                                ),
                                choices = degree_choices,
                                selected = current_degree,
                                multiple = FALSE, selectize = FALSE, width = "100%"
                            )
                        )
                    )
                })
            )
        )
    })

    # --- Page prev/next ---
    shiny::observeEvent(input$establishment_page_prev, {
        sync_establishment_page_to_draft()
        rv$establishment_page <- max(1L, as.integer(rv$establishment_page) - 1L)
    }, ignoreInit = TRUE)

    shiny::observeEvent(input$establishment_page_next, {
        sync_establishment_page_to_draft()
        rv$establishment_page <- min(
            establishment_page_count(), as.integer(rv$establishment_page) + 1L
        )
    }, ignoreInit = TRUE)

    # --- Open ---
    shiny::observeEvent(input$open_establishment_assistant, {
        tryCatch(
            {
                species <- get_establishment_species()
                if (length(species) == 0L) {
                    shiny::showNotification(
                        tr("est_assistant_map_scientificname_first", lang_r()),
                        type = "warning", duration = 5
                    )
                    return(invisible(NULL))
                }

                entries <- extract_species_entries(species)
                if (nrow(entries) == 0L) {
                    shiny::showNotification(
                        tr("est_assistant_no_species", lang_r()),
                        type = "warning", duration = 5
                    )
                    return(invisible(NULL))
                }
                entries$origin_class <- invasive_origin_class_for(entries$raw)

                rv$establishment_entries <- entries
                rv$establishment_auto_map <- auto_suggest_establishment_means(entries$raw)
                rv$establishment_draft <- sanitize_establishment_map(rv$establishment_map)
                rv$establishment_page <- 1L

                shiny::showModal(shiny::modalDialog(
                    title = tr("est_assistant_title", lang_r()),
                    size = "l",
                    easyClose = TRUE,
                    shiny::div(
                        class = "bor-assistant-modal est-assistant-modal",
                        shiny::p(
                            class = "bor-assistant-subtitle",
                            tr("est_assistant_subtitle", lang_r())
                        ),
                        shiny::uiOutput(ns("establishment_assistant_progress")),
                        shiny::uiOutput(ns("establishment_assistant_pagination")),
                        shiny::div(
                            class = "bor-assistant-table-wrap",
                            shiny::uiOutput(ns("establishment_assistant_rows"))
                        )
                    ),
                    footer = shiny::tagList(
                        shiny::modalButton(tr("btn_cancel", lang_r())),
                        shiny::actionButton(
                            ns("save_establishment_assistant"),
                            tr("est_assistant_save", lang_r()),
                            class = "btn-primary"
                        )
                    )
                ))
            },
            error = function(e) {
                shiny::showNotification(
                    sprintf(tr("est_assistant_open_error", lang_r()), e$message),
                    type = "error", duration = 7
                )
            }
        )
    })

    # --- Save ---
    shiny::observeEvent(input$save_establishment_assistant, {
        sync_establishment_page_to_draft()
        entries <- rv$establishment_entries
        effective <- get_effective_establishment_map()

        final <- list(
            means = stats::setNames(character(0), character(0)),
            degree = stats::setNames(character(0), character(0))
        )
        if (nrow(entries) > 0) {
            means <- effective$means[entries$key]
            degree <- effective$degree[entries$key]
            means[is.na(means)] <- ""
            degree[is.na(degree)] <- ""
            # A degree without a means says nothing on its own, so it is dropped
            # rather than written to the data.
            degree[!nzchar(means)] <- ""
            final$means <- stats::setNames(as.character(means), entries$key)
            final$degree <- stats::setNames(as.character(degree), entries$key)
        }

        rv$establishment_map <- final
        missing_degree <- length(establishment_pairs_missing_degree(final))
        answered <- sum(nzchar(final$means))

        shiny::removeModal()
        shiny::showNotification(
            sprintf(tr("est_assistant_saved", lang_r()), answered, length(final$means)),
            type = "message", duration = 4
        )
        # Recommended, not required: Darwin Core does not mandate
        # degreeOfEstablishment, so this warns and the export proceeds.
        if (missing_degree > 0L) {
            shiny::showNotification(
                sprintf(tr("est_assistant_missing_degree", lang_r()), missing_degree),
                type = "warning", duration = 7
            )
        }
    })

    invisible(NULL)
}
