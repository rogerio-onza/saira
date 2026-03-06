# Title: Mapping Module - Darwin Core Field Mapping
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-09
# Version: 2.0 - Enhanced with filters and UUID generation

#' Mapping Module UI
#'
#' @param id Module namespace ID
#' @return Shiny UI tagList
#' @export
mod_mapping_ui <- function(id) {
    ns <- shiny::NS(id)

    bslib::layout_sidebar(
        sidebar = bslib::sidebar(
            width = 280,
            class = "mapping-sidebar",
            shiny::div(
                class = "stats-box",
                shiny::div(class = "stats-number", shiny::textOutput(ns("mapped_count"), inline = TRUE)),
                shiny::div(class = "stats-label", shiny::uiOutput(ns("label_mapped_fields"), inline = TRUE))
            ),
            shiny::div(
                class = "stats-box",
                shiny::div(class = "stats-number", shiny::textOutput(ns("total_fields"), inline = TRUE)),
                shiny::div(class = "stats-label", shiny::uiOutput(ns("label_total_fields"), inline = TRUE))
            ),
            shiny::hr(),
            shiny::uiOutput(ns("sidebar_actions_label")),
            shiny::actionButton(
                ns("auto_map"),
                shiny::uiOutput(ns("btn_auto_map_label"), inline = TRUE),
                class = "btn-primary w-100 mb-2",
                icon = shiny::icon("wand-magic-sparkles")
            ),
            shiny::actionButton(
                ns("reset_mapping"),
                shiny::uiOutput(ns("btn_reset_label"), inline = TRUE),
                class = "btn-warning w-100 mb-2",
                icon = shiny::icon("rotate-left", class = "fa-solid")
            ),
            shiny::hr(),
            shiny::uiOutput(ns("sidebar_filters_label")),
            shiny::checkboxInput(
                ns("show_only_mapped"),
                shiny::uiOutput(ns("filter_mapped_label"), inline = TRUE),
                value = FALSE
            ),
            shiny::div(
                class = "category-filter-block",
                shiny::uiOutput(ns("filter_categories_label")),
                shiny::div(
                    class = "category-filter-select-all",
                    shiny::checkboxInput(
                        ns("select_all_categories"),
                        shiny::uiOutput(ns("filter_select_all_label"), inline = TRUE),
                        value = TRUE
                    )
                ),
                shiny::div(
                    class = "category-filter-options",
                    shiny::checkboxGroupInput(
                        ns("filter_categories"),
                        NULL,
                        choices = c(
                            "Record-level" = "Record-level",
                            "Occurrence" = "Occurrence",
                            "Event" = "Event",
                            "Location" = "Location",
                            "Taxon" = "Taxon",
                            "Identification" = "Identification"
                        ),
                        selected = c("Record-level", "Occurrence", "Event", "Location", "Taxon", "Identification")
                    )
                )
            )
        ),

        # Main content
        bslib::card(
            bslib::card_header(shiny::uiOutput(ns("card_title"))),
            bslib::card_body(
                min_height = "70vh",
                shiny::conditionalPanel(
                    condition = paste0("output['", ns("file_uploaded"), "']"),
                    shiny::div(
                        class = "mapping-scroll-container",
                        shiny::uiOutput(ns("mapping_ui"))
                    )
                ),
                shiny::conditionalPanel(
                    condition = paste0("!output['", ns("file_uploaded"), "']"),
                    shiny::div(
                        class = "mapping-empty-state",
                        shiny::icon("upload", class = "mapping-empty-icon"),
                        shiny::h4(shiny::uiOutput(ns("no_file_msg"))),
                        shiny::p(shiny::uiOutput(ns("upload_first_msg")))
                    )
                )
            )
        )
    )
}
#' @noRd
reset_basis_of_record_state <- function(rv, reset_source_col = TRUE) {
    # Helper: reset basisOfRecord state to empty (consolidates 3 duplicated blocks)
    # If reset_source_col=FALSE, preserves the current source_col (used when changing column)
    rv$basis_of_record_map <- stats::setNames(character(0), character(0))
    rv$basis_of_record_auto_map <- stats::setNames(character(0), character(0))
    if (reset_source_col) {
        rv$basis_of_record_source_col <- ""
    }
    rv$basis_of_record_draft_map <- stats::setNames(character(0), character(0))
    rv$basis_of_record_entries <- data.frame(
        idx = integer(0),
        key = character(0),
        raw = character(0),
        stringsAsFactors = FALSE
    )
    rv$basis_of_record_page <- 1L
}

#' Mapping Module Server
#'
#' @param id Module namespace ID
#' @param raw_data_r Reactive data frame from upload module
#' @param lang_r Reactive language code
#' @return Reactive containing processed/mapped data
#' @export
mod_mapping_server <- function(id, raw_data_r, lang_r) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        # Load dependencies

        # Reactive values
        rv <- shiny::reactiveValues(
            occurrence_ids = NULL,
            eventdate_parse_failures = 0L,
            last_eventdate_warn_count = NA_integer_,
            map_values = list(),
            map_meta = list(),
            rostrum_decisions = NULL,
            rostrum_run_stats = list(),
            basis_of_record_map = stats::setNames(character(0), character(0)),
            basis_of_record_auto_map = stats::setNames(character(0), character(0)),
            basis_of_record_source_col = "",
            basis_of_record_draft_map = stats::setNames(character(0), character(0)),
            basis_of_record_entries = data.frame(
                idx = integer(0),
                key = character(0),
                raw = character(0),
                stringsAsFactors = FALSE
            ),
            basis_of_record_page = 1L,
            is_programmatic_update = FALSE,
            programmatic_terms = character(0),
            automap_progress = 0L,
            automap_phrase_idx = 1L,
            automap_phrase_order = integer(0),
            ambiguity_queue = list()
        )

        # SQLite connection for alias and template persistence
        conn <- tryCatch(
            rostrum_connect(),
            error = function(e) {
                message("[rostrum] Failed to open SQLite connection: ", e$message)
                NULL
            }
        )
        session$onSessionEnded(function() {
            if (!is.null(conn) && DBI::dbIsValid(conn)) {
                DBI::dbDisconnect(conn)
            }
        })

        # Category filter options
        all_filter_categories <- c("Record-level", "Occurrence", "Event", "Location", "Taxon", "Identification")
        syncing_select_all <- shiny::reactiveVal(FALSE)

        category_labels <- function() {
            c(
                tr("class_record", lang_r()),
                tr("class_occurrence", lang_r()),
                tr("class_event", lang_r()),
                tr("class_location", lang_r()),
                tr("class_taxon", lang_r()),
                tr("class_identification", lang_r())
            )
        }

        category_choices <- function() {
            stats::setNames(all_filter_categories, category_labels())
        }

        category_label <- function(category_value) {
            idx <- match(category_value, all_filter_categories)
            if (is.na(idx)) {
                return(category_value)
            }

            category_labels()[[idx]]
        }


        # Load DwC terms as list (reactive to language)
        dwc_all <- shiny::reactive({
            get_dwc_terms_list(lang_r())
        })

        all_term_names <- shiny::reactive({
            vapply(dwc_all(), function(x) x$term, FUN.VALUE = character(1))
        })

        reason_key_from_code <- function(reason_code) {
            switch(as.character(reason_code),
                exact_match = "rostrum_reason_exact_match",
                known_synonym = "rostrum_reason_known_synonym",
                token_overlap = "rostrum_reason_token_overlap",
                text_similarity = "rostrum_reason_text_similarity",
                veto_hard = "rostrum_reason_veto_hard",
                veto_soft = "rostrum_reason_veto_soft",
                semantic_penalty = "rostrum_reason_semantic_penalty",
                ambiguity_detected = "rostrum_reason_ambiguity_detected",
                ambiguity_resolved_manual = "rostrum_reason_ambiguity_detected",
                conflict_won = "rostrum_reason_conflict_won",
                conflict_lost = "rostrum_reason_conflict_lost",
                fallback_verbatim_from_loser = "rostrum_reason_conflict_won",
                fallback_verbatim_from_primary = "rostrum_reason_conflict_won",
                template_priority_override = "rostrum_reason_template_override",
                content_validated = "badge_reason_content_validated",
                manual_adjust = "badge_reason_manual_adjust",
                manual_cleared = "badge_reason_manual_cleared",
                type_incompatible = "badge_reason_type_incompatible",
                temporal_manual_only = "badge_reason_temporal_manual_only",
                empty_column = "badge_reason_empty_column",
                low_name_confidence = "badge_reason_low_name_confidence",
                no_confident_match = "badge_reason_no_confident_match",
                "badge_reason_low_confidence"
            )
        }

        build_badge_info <- function(meta) {
            if (is.null(meta) || is.na(meta$status) || !nzchar(meta$status)) {
                return(NULL)
            }

            status <- toupper(as.character(meta$status)[1])
            badge_class <- switch(status,
                AUTO = "badge field-status-badge bg-success",
                SUGERIDO = "badge field-status-badge bg-warning",
                AMBIGUO = "badge field-status-badge badge-ambiguous",
                EDITADO = "badge field-status-badge bg-info",
                ALIAS = "badge field-status-badge bg-primary",
                TEMPLATE = "badge field-status-badge badge-template",
                MANUAL = "badge field-status-badge bg-light text-muted border",
                "badge field-status-badge bg-light text-muted border"
            )

            badge_label <- switch(status,
                AUTO = tr("rostrum_badge_auto", lang_r()),
                SUGERIDO = tr("rostrum_badge_suggested", lang_r()),
                AMBIGUO = tr("rostrum_badge_ambiguous", lang_r()),
                EDITADO = tr("badge_edited", lang_r()),
                ALIAS = tr("rostrum_badge_alias", lang_r()),
                TEMPLATE = tr("rostrum_badge_template", lang_r()),
                MANUAL = tr("rostrum_badge_manual", lang_r()),
                tr("rostrum_badge_manual", lang_r())
            )

            reason_key <- reason_key_from_code(meta$reason)
            reason_text <- tr(reason_key, lang_r())
            score_value <- suppressWarnings(as.numeric(meta$score))

            tooltip <- reason_text
            if (!is.na(score_value)) {
                tooltip <- paste0(reason_text, " | score: ", sprintf("%.2f", score_value))
            }

            list(
                label = badge_label,
                class = badge_class,
                title = tooltip
            )
        }

        parse_ambiguity_candidates <- function(alternatives_json) {
            if (is.null(alternatives_json) || is.na(alternatives_json) || !nzchar(alternatives_json)) {
                return(list())
            }

            parsed <- tryCatch(
                jsonlite::fromJSON(alternatives_json, simplifyVector = FALSE),
                error = function(e) NULL
            )

            if (is.null(parsed) || length(parsed) == 0) {
                return(list())
            }

            Filter(function(item) {
                !is.null(item$column_name) && nzchar(as.character(item$column_name))
            }, parsed)
        }

        preview_values_for_column <- function(col_name, n = 5L) {
            df <- raw_data_r()
            if (!is.data.frame(df) || !(col_name %in% names(df))) {
                return(character(0))
            }

            vals <- as.character(df[[col_name]])
            vals <- vals[!is.na(vals)]
            vals <- trimws(vals)
            vals <- vals[nzchar(vals)]
            utils::head(vals, as.integer(n))
        }

        show_next_ambiguity_modal <- function() {
            if (length(rv$ambiguity_queue) == 0) {
                return(invisible(NULL))
            }

            item <- rv$ambiguity_queue[[1]]
            term <- as.character(item$term)
            candidates <- item$candidates
            if (length(candidates) == 0) {
                rv$ambiguity_queue <- rv$ambiguity_queue[-1]
                return(show_next_ambiguity_modal())
            }

            choice_values <- vapply(candidates, function(x) as.character(x$column_name), FUN.VALUE = character(1))
            choice_labels <- vapply(candidates, function(x) {
                score <- suppressWarnings(as.numeric(x$final_score))
                if (is.na(score)) {
                    return(as.character(x$column_name))
                }
                sprintf("%s (%.2f)", as.character(x$column_name), score)
            }, FUN.VALUE = character(1))
            choices <- stats::setNames(choice_values, choice_labels)

            samples_ui <- lapply(candidates, function(candidate) {
                col_name <- as.character(candidate$column_name)
                sample_values <- preview_values_for_column(col_name, n = 5L)
                shiny::tags$div(
                    class = "mb-2",
                    shiny::tags$strong(col_name),
                    shiny::tags$div(
                        class = "small text-muted",
                        if (length(sample_values) == 0) {
                            tr("rostrum_ambiguity_no_sample", lang_r())
                        } else {
                            paste(sample_values, collapse = " | ")
                        }
                    )
                )
            })

            shiny::showModal(shiny::modalDialog(
                title = sprintf(tr("rostrum_ambiguity_title", lang_r()), term),
                shiny::p(tr("rostrum_ambiguity_question", lang_r())),
                shiny::radioButtons(
                    ns("ambiguity_choice"),
                    label = NULL,
                    choices = choices,
                    selected = choice_values[[1]]
                ),
                shiny::tags$hr(),
                shiny::tags$div(
                    class = "small text-muted mb-2",
                    tr("rostrum_ambiguity_samples", lang_r())
                ),
                shiny::tagList(samples_ui),
                easyClose = FALSE,
                footer = shiny::tagList(
                    shiny::actionButton(ns("skip_ambiguity_choice"), tr("btn_cancel", lang_r())),
                    shiny::actionButton(ns("confirm_ambiguity_choice"), tr("rostrum_ambiguity_confirm", lang_r()), class = "btn-primary")
                )
            ))
        }

        set_map_value <- function(term, value, update_input = TRUE) {
            sanitized_value <- sanitize_map_selection(term, value)
            rv$map_values[[term]] <- sanitized_value

            input_id <- paste0("map_", term)
            if (isTRUE(update_input) && !is.null(input[[input_id]])) {
                rv$programmatic_terms <- unique(c(rv$programmatic_terms, term))
                shiny::updateSelectInput(session, input_id, selected = sanitized_value)
            }
        }

        basis_of_record_page_size <- 20L

        get_basis_of_record_source_col <- function() {
            selected <- sanitize_map_selection("basisOfRecord", rv$map_values[["basisOfRecord"]])
            if (has_selected_value(selected)) {
                return(as.character(selected[[1]]))
            }

            input_selected <- sanitize_map_selection("basisOfRecord", input$map_basisOfRecord)
            if (has_selected_value(input_selected)) {
                return(as.character(input_selected[[1]]))
            }

            ""
        }

        basis_of_record_page_count <- function() {
            total_items <- nrow(rv$basis_of_record_entries)
            if (total_items <= 0) {
                return(1L)
            }

            max(1L, as.integer(ceiling(total_items / basis_of_record_page_size)))
        }

        get_basis_of_record_page_entries <- function() {
            entries <- rv$basis_of_record_entries
            if (nrow(entries) == 0) {
                return(entries)
            }

            total_pages <- basis_of_record_page_count()
            current_page <- max(1L, min(as.integer(rv$basis_of_record_page), total_pages))
            start_idx <- ((current_page - 1L) * basis_of_record_page_size) + 1L
            end_idx <- min(nrow(entries), start_idx + basis_of_record_page_size - 1L)
            entries[start_idx:end_idx, , drop = FALSE]
        }

        basis_of_record_target_choices <- function() {
            get_basis_of_record_term_choices(
                lang = lang_r(),
                include_skip = TRUE,
                with_description = TRUE,
                skip_label = tr("bor_assistant_skip_option", lang_r())
            )
        }

        get_effective_basis_of_record_map <- function() {
            entries <- rv$basis_of_record_entries
            if (nrow(entries) == 0) {
                return(stats::setNames(character(0), character(0)))
            }

            keys <- entries$key
            auto_map <- sanitize_basis_of_record_map(rv$basis_of_record_auto_map)
            draft_map <- sanitize_basis_of_record_map(rv$basis_of_record_draft_map)

            effective <- auto_map[keys]
            effective[is.na(effective)] <- ""

            draft_values <- draft_map[keys]
            has_draft <- !is.na(draft_values)
            effective[has_draft] <- draft_values[has_draft]

            effective <- sanitize_basis_of_record_terms(effective)
            stats::setNames(as.character(effective), keys)
        }

        sync_current_page_to_draft <- function() {
            entries <- get_basis_of_record_page_entries()
            if (nrow(entries) == 0) {
                return(invisible(NULL))
            }

            for (i in seq_len(nrow(entries))) {
                entry <- entries[i, , drop = FALSE]
                input_id <- paste0("basis_of_record_target_", entry$idx[[1]])
                input_value <- input[[input_id]]
                if (is.null(input_value)) {
                    next
                }

                sanitized_value <- sanitize_basis_of_record_term(input_value)
                key <- entry$key[[1]]
                has_key <- key %in% names(rv$basis_of_record_draft_map)
                current_value <- if (has_key) as.character(rv$basis_of_record_draft_map[[key]])[[1]] else NA_character_

                if (!has_key || !identical(current_value, sanitized_value)) {
                    rv$basis_of_record_draft_map[[entry$key[[1]]]] <- sanitized_value
                }
            }

            invisible(NULL)
        }

        # Loading modal helpers (delegated to mod_mapping_loading.R)
        loading_phrase_specs <- mapping_loading_phrase_specs()


        # Translated labels
        output$label_mapped_fields <- shiny::renderUI({
            tr("stats_mapped_fields", lang_r())
        })

        output$label_total_fields <- shiny::renderUI({
            tr("stats_total_dwc_fields", lang_r())
        })

        output$btn_auto_map_label <- shiny::renderUI({
            tr("btn_auto_mapping", lang_r())
        })

        output$btn_reset_label <- shiny::renderUI({
            tr("btn_reset", lang_r())
        })

        output$sidebar_actions_label <- shiny::renderUI({
            shiny::tags$label(tr("mapping_sidebar_actions", lang_r()), class = "form-label")
        })

        output$sidebar_filters_label <- shiny::renderUI({
            shiny::tags$label(tr("mapping_sidebar_filters", lang_r()), class = "form-label")
        })

        output$filter_mapped_label <- shiny::renderUI({
            tr("filter_mapped_only", lang_r())
        })

        output$filter_categories_label <- shiny::renderUI({
            shiny::tags$label(tr("filter_categories", lang_r()), class = "form-label")
        })

        output$filter_select_all_label <- shiny::renderUI({
            tr("filter_select_all", lang_r())
        })

        output$card_title <- shiny::renderUI({
            tr("mapping_title", lang_r())
        })

        output$no_file_msg <- shiny::renderUI({
            tr("no_file_uploaded", lang_r())
        })

        output$upload_first_msg <- shiny::renderUI({
            tr("upload_csv_to_start", lang_r())
        })

        # File uploaded output for conditional panel
        output$file_uploaded <- shiny::reactive({
            !is.null(raw_data_r())
        })
        shiny::outputOptions(output, "file_uploaded", suspendWhenHidden = FALSE)

        # BasisOfRecord assistant (delegated to mod_mapping_basis_assistant.R)
        setup_basis_of_record_assistant(
            input = input, output = output, session = session,
            rv = rv, ns = ns, lang_r = lang_r, raw_data_r = raw_data_r,
            basis_of_record_page_size = basis_of_record_page_size,
            basis_of_record_page_count = basis_of_record_page_count,
            get_basis_of_record_page_entries = get_basis_of_record_page_entries,
            basis_of_record_target_choices = basis_of_record_target_choices,
            get_effective_basis_of_record_map = get_effective_basis_of_record_map,
            get_basis_of_record_source_col = get_basis_of_record_source_col,
            sync_current_page_to_draft = sync_current_page_to_draft
        )


        shiny::observe({
            term_names <- all_term_names()
            if (length(term_names) == 0) {
                return()
            }

            if (length(rv$map_values) == 0) {
                rv$map_values <- empty_map_values(term_names)
            } else {
                missing_terms <- setdiff(term_names, names(rv$map_values))
                for (term in missing_terms) {
                    rv$map_values[[term]] <- ""
                }
            }

            if (length(rv$map_meta) == 0) {
                rv$map_meta <- empty_map_meta(term_names)
            } else {
                missing_meta <- setdiff(term_names, names(rv$map_meta))
                for (term in missing_meta) {
                    rv$map_meta[[term]] <- default_meta()
                }
            }
        })

        shiny::observeEvent(raw_data_r(),
            {
                shiny::req(raw_data_r())
                term_names <- all_term_names()

                rv$map_values <- empty_map_values(term_names)
                rv$map_meta <- empty_map_meta(term_names)
                rv$occurrence_ids <- ids::uuid(n = nrow(raw_data_r()))
                rv$eventdate_parse_failures <- 0L
                rv$last_eventdate_warn_count <- NA_integer_
                rv$programmatic_terms <- character(0)
                rv$ambiguity_queue <- list()
                rv$rostrum_decisions <- NULL
                rv$rostrum_run_stats <- list()
                reset_basis_of_record_state(rv)
            },
            ignoreNULL = TRUE
        )

        shiny::observe({
            shiny::req(raw_data_r())
            term_names <- all_term_names()

            for (term in term_names) {
                input_id <- paste0("map_", term)
                input_value <- input[[input_id]]
                if (is.null(input_value)) {
                    next
                }

                sanitized <- sanitize_map_selection(term, input_value)

                if (term %in% c("scientificName", "basisOfRecord") && length(input_value) > 1) {
                    rv$is_programmatic_update <- TRUE
                    shiny::updateSelectInput(session, input_id, selected = sanitized)
                    rv$is_programmatic_update <- FALSE
                }

                old_value <- shiny::isolate(rv$map_values[[term]])
                if (is.null(old_value)) {
                    old_value <- ""
                }

                if (!identical(old_value, sanitized)) {
                    rv$map_values[[term]] <- sanitized

                    if (identical(term, "basisOfRecord")) {
                        next_source_col <- if (has_selected_value(sanitized)) {
                            as.character(sanitized[[1]])
                        } else {
                            ""
                        }
                        previous_source_col <- shiny::isolate(rv$basis_of_record_source_col)

                        if (!identical(previous_source_col, next_source_col)) {
                            rv$basis_of_record_source_col <- next_source_col
                            reset_basis_of_record_state(rv, reset_source_col = FALSE)
                        }
                    }

                    is_programmatic_term <- term %in% shiny::isolate(rv$programmatic_terms)
                    if (is_programmatic_term) {
                        rv$programmatic_terms <- setdiff(shiny::isolate(rv$programmatic_terms), term)
                    }

                    if (!isTRUE(rv$is_programmatic_update) && !is_programmatic_term) {
                        previous_meta <- shiny::isolate(rv$map_meta[[term]])
                        rv$map_meta[[term]] <- build_manual_meta(
                            previous_meta = previous_meta,
                            has_value = has_selected_value(sanitized)
                        )
                        # Record alias override when user manually selects a column
                        if (!is.null(conn) && DBI::dbIsValid(conn) &&
                            has_selected_value(sanitized) && nzchar(sanitized[[1]])) {
                            col_selected <- as.character(sanitized[[1]])
                            run_id <- shiny::isolate(rv$rostrum_run_stats[["run_id"]])
                            tryCatch(
                                rostrum_record_alias_override(
                                    conn = conn,
                                    col_name = col_selected,
                                    dwc_term = term,
                                    run_id = run_id
                                ),
                                error = function(e) {
                                    message("[rostrum] Could not record alias override: ", e$message)
                                }
                            )
                        }
                    }
                }
            }
        })

        set_custom_term_meta <- function(term, has_value) {
            if (isTRUE(rv$is_programmatic_update)) {
                return(invisible(NULL))
            }

            previous_meta <- shiny::isolate(rv$map_meta[[term]])
            rv$map_meta[[term]] <- build_manual_meta(
                previous_meta = previous_meta,
                has_value = has_value
            )

            invisible(NULL)
        }

        shiny::observeEvent(input$custom_datasetName,
            {
                has_value <- !is.null(input$custom_datasetName) && nchar(trimws(input$custom_datasetName)) > 0
                set_custom_term_meta("datasetName", has_value)
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$modified_use_today,
            {
                has_value <- isTRUE(input$modified_use_today) || !is.null(input$custom_modified_date)
                set_custom_term_meta("modified", has_value)
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$custom_modified_date,
            {
                has_value <- isTRUE(input$modified_use_today) || !is.null(input$custom_modified_date)
                set_custom_term_meta("modified", has_value)
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$confirm_ambiguity_choice, {
            if (length(rv$ambiguity_queue) == 0) {
                shiny::removeModal()
                return(invisible(NULL))
            }

            item <- rv$ambiguity_queue[[1]]
            term <- as.character(item$term)
            selected_col <- input$ambiguity_choice
            if (is.null(selected_col) || length(selected_col) == 0 || is.na(selected_col)) {
                selected_col <- ""
            }
            selected_col <- as.character(selected_col[[1]])

            if (nzchar(selected_col)) {
                rv$is_programmatic_update <- TRUE
                on.exit(
                    {
                        rv$is_programmatic_update <- FALSE
                        rv$programmatic_terms <- character(0)
                    },
                    add = TRUE
                )

                set_map_value(term, selected_col, update_input = TRUE)

                selected_candidate <- Filter(function(candidate) {
                    identical(as.character(candidate$column_name), selected_col)
                }, item$candidates)

                selected_score <- NA_real_
                if (length(selected_candidate) > 0) {
                    selected_score <- suppressWarnings(as.numeric(selected_candidate[[1]]$final_score))
                }

                rv$map_meta[[term]] <- list(
                    status = "EDITADO",
                    score = selected_score,
                    reason = "ambiguity_resolved_manual",
                    source = "manual",
                    alternatives_json = jsonlite::toJSON(item$candidates, auto_unbox = TRUE)
                )

                # Record alias: confirmation if top candidate chosen, override otherwise
                if (!is.null(conn) && DBI::dbIsValid(conn)) {
                    run_id <- shiny::isolate(rv$rostrum_run_stats[["run_id"]])
                    top_col <- if (length(item$candidates) > 0) {
                        as.character(item$candidates[[1]]$column_name)
                    } else {
                        ""
                    }
                    tryCatch(
                        if (identical(selected_col, top_col) && !is.na(selected_score)) {
                            rostrum_record_alias_confirmation(
                                conn = conn,
                                col_name = selected_col,
                                dwc_term = term,
                                score_original = selected_score,
                                run_id = run_id
                            )
                        } else {
                            rostrum_record_alias_override(
                                conn = conn,
                                col_name = selected_col,
                                dwc_term = term,
                                run_id = run_id
                            )
                        },
                        error = function(e) {
                            message("[rostrum] Could not record alias from ambiguity: ", e$message)
                        }
                    )
                }
            }

            rv$ambiguity_queue <- rv$ambiguity_queue[-1]
            shiny::removeModal()
            show_next_ambiguity_modal()
        })

        shiny::observeEvent(input$skip_ambiguity_choice, {
            if (length(rv$ambiguity_queue) == 0) {
                shiny::removeModal()
                return(invisible(NULL))
            }

            rv$ambiguity_queue <- rv$ambiguity_queue[-1]
            shiny::removeModal()
            show_next_ambiguity_modal()
        })

        shiny::observeEvent(rv$eventdate_parse_failures,
            {
                current_count <- rv$eventdate_parse_failures

                if (is.null(current_count) || current_count <= 0) {
                    rv$last_eventdate_warn_count <- NA_integer_
                    return()
                }

                if (!identical(rv$last_eventdate_warn_count, current_count)) {
                    shiny::showNotification(
                        sprintf(tr("notif_eventdate_parse_warning", lang_r()), current_count),
                        type = "warning",
                        duration = 7
                    )
                    rv$last_eventdate_warn_count <- current_count
                }
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(lang_r(),
            {
                current <- shiny::isolate(input$filter_categories)
                if (is.null(current)) {
                    current <- all_filter_categories
                }

                shiny::updateCheckboxGroupInput(
                    session,
                    "filter_categories",
                    choices = category_choices(),
                    selected = current
                )
            },
            ignoreInit = FALSE
        )

        # Category filter: select all / unselect all
        shiny::observeEvent(input$select_all_categories,
            {
                if (isTRUE(syncing_select_all())) {
                    syncing_select_all(FALSE)
                    return()
                }

                target <- if (isTRUE(input$select_all_categories)) all_filter_categories else character(0)
                current <- input$filter_categories
                if (is.null(current)) {
                    current <- character(0)
                }

                same_selection <- length(current) == length(target) && all(sort(current) == sort(target))
                if (!same_selection) {
                    shiny::updateCheckboxGroupInput(session, "filter_categories", selected = target)
                }
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$filter_categories,
            {
                current <- input$filter_categories
                if (is.null(current)) {
                    current <- character(0)
                }

                is_all_selected <- length(current) == length(all_filter_categories) && all(all_filter_categories %in% current)

                if (!identical(isTRUE(input$select_all_categories), is_all_selected)) {
                    syncing_select_all(TRUE)
                    shiny::updateCheckboxInput(session, "select_all_categories", value = is_all_selected)
                }
            },
            ignoreInit = TRUE
        )

        # Mapping UI generation (card builder delegated to mod_mapping_cards.R)
        output$mapping_ui <- shiny::renderUI({
            shiny::req(raw_data_r())

            cols <- c("-- " = "", names(raw_data_r()))
            fields_to_show <- dwc_all()

            # Apply category filter
            selected_categories <- input$filter_categories
            if (is.null(selected_categories)) {
                selected_categories <- character(0)
            }

            if (length(selected_categories) == 0) {
                fields_to_show <- list()
            } else {
                fields_to_show <- Filter(function(x) x$category %in% selected_categories, fields_to_show)
            }

            all_categories <- vapply(fields_to_show, function(x) x$category, FUN.VALUE = character(1))
            categories <- unique(all_categories)
            lang <- lang_r()

            shiny::tagList(
                lapply(categories, function(cat) {
                    cat_fields <- Filter(function(x) x$category == cat, fields_to_show)
                    cat_class <- paste0("cat-", tolower(gsub("-", "", cat)))

                    shiny::tagList(
                        shiny::div(class = "category-header", category_label(cat)),
                        shiny::div(
                            class = "two-column-layout",
                            lapply(cat_fields, function(item) {
                                term <- item$term
                                current_val <- rv$map_values[[term]]
                                if (is.null(current_val)) {
                                    current_val <- input[[paste0("map_", term)]]
                                }
                                current_val <- sanitize_map_selection(term, current_val)
                                is_mapped <- is_field_mapped(term, current_val, input)
                                field_meta <- rv$map_meta[[term]]
                                if (is.null(field_meta)) {
                                    field_meta <- default_meta()
                                }
                                badge_info <- build_badge_info(field_meta)

                                # Apply "show only mapped" filter
                                if (isTRUE(input$show_only_mapped) && !is_mapped) {
                                    return(NULL)
                                }

                                build_field_card(
                                    item = item, cols = cols,
                                    current_val = current_val,
                                    is_mapped = is_mapped,
                                    badge_info = badge_info,
                                    ns = ns, lang_r = lang,
                                    input = input, cat_class = cat_class
                                )
                            })
                        )
                    )
                })
            )
        })


        # Auto-mapping
        shiny::observeEvent(input$auto_map, {
            shiny::req(raw_data_r())
            term_names <- all_term_names()
            special_fields <- c("occurrenceID", "modified", "license", "language")
            show_automap_loading_modal(rv, ns, lang_r)
            on.exit(hide_automap_loading_modal(), add = TRUE)

            auto_count <- 0L
            suggested_count <- 0L

            tryCatch(
                {
                    dwc_terms_df <- load_dwc_terms_rds()
                    engine_result <- run_rostrum_engine(
                        df = raw_data_r(),
                        dwc_terms_df = dwc_terms_df,
                        options = rostrum_options(),
                        context = list(),
                        conn = conn
                    )
                    auto_results <- engine_result$data
                    rv$rostrum_decisions <- engine_result$data
                    rv$rostrum_run_stats <- engine_result$run_stats

                    rv$is_programmatic_update <- TRUE
                    on.exit(
                        {
                            rv$is_programmatic_update <- FALSE
                            rv$programmatic_terms <- character(0)
                        },
                        add = TRUE
                    )
                    next_meta <- empty_map_meta(term_names)
                    total_rows <- max(1L, nrow(auto_results))
                    ambiguity_queue <- list()

                    for (i in seq_len(nrow(auto_results))) {
                        term <- as.character(auto_results$term[[i]])
                        status <- as.character(auto_results$status[[i]])
                        reason <- as.character(auto_results$reason[[i]])
                        score_value <- suppressWarnings(as.numeric(auto_results$final_score[[i]]))
                        selected_col <- as.character(auto_results$selected_col[[i]])
                        is_applied <- isTRUE(auto_results$applied[[i]])
                        alternatives_json <- if ("alternatives_json" %in% names(auto_results)) {
                            as.character(auto_results$alternatives_json[[i]])
                        } else {
                            "[]"
                        }

                        next_meta[[term]] <- list(
                            status = status,
                            score = score_value,
                            reason = reason,
                            source = if (identical(status, "TEMPLATE")) "template" else if (identical(status, "ALIAS")) "alias" else "auto",
                            alternatives_json = alternatives_json
                        )

                        if (identical(status, "AMBIGUO")) {
                            candidates <- parse_ambiguity_candidates(alternatives_json)
                            if (length(candidates) > 0) {
                                ambiguity_queue[[length(ambiguity_queue) + 1L]] <- list(
                                    term = term,
                                    candidates = candidates
                                )
                            }
                        }

                        if (!(term %in% special_fields) && is_applied && !is.na(selected_col) && nzchar(selected_col)) {
                            set_map_value(term, selected_col, update_input = TRUE)
                            if (identical(status, "AUTO")) {
                                auto_count <- auto_count + 1L
                            } else if (identical(status, "SUGERIDO")) {
                                suggested_count <- suggested_count + 1L
                            }
                        }

                        update_automap_loading(rv, i, total_rows)
                    }

                    if (nrow(auto_results) == 0) {
                        update_automap_loading(rv, 1L, 1L)
                    }

                    rv$map_meta <- next_meta
                    rv$ambiguity_queue <- ambiguity_queue

                    if (!isTRUE(engine_result$stage2$success)) {
                        shiny::showNotification(
                            tr("rostrum_warning_stage2_fallback", lang_r()),
                            type = "warning",
                            duration = 6
                        )
                    }
                    if (!isTRUE(engine_result$stage3$success)) {
                        shiny::showNotification(
                            tr("rostrum_warning_stage3_fallback", lang_r()),
                            type = "warning",
                            duration = 6
                        )
                    }

                    shiny::showNotification(
                        sprintf(tr("notif_auto_mapping_v1", lang_r()), auto_count, suggested_count),
                        type = "message",
                        duration = 6
                    )

                    if (length(rv$ambiguity_queue) > 0) {
                        show_next_ambiguity_modal()
                    }
                },
                error = function(e) {
                    rv$is_programmatic_update <- FALSE
                    rv$programmatic_terms <- character(0)
                    shiny::showNotification(
                        sprintf(tr("notif_auto_mapping_v1_error", lang_r()), e$message),
                        type = "error",
                        duration = 7
                    )
                }
            )
        })

        # Reset mapping
        shiny::observeEvent(input$reset_mapping, {
            shiny::showModal(shiny::modalDialog(
                title = tr("modal_reset_title", lang_r()),
                tr("modal_reset_message", lang_r()),
                footer = shiny::tagList(
                    shiny::modalButton(tr("btn_cancel", lang_r())),
                    shiny::actionButton(ns("confirm_reset"), tr("btn_confirm_reset", lang_r()), class = "btn-danger")
                )
            ))
        })

        shiny::observeEvent(input$confirm_reset, {
            special_no_dropdown <- c("occurrenceID", "modified", "license", "language")
            rv$is_programmatic_update <- TRUE
            for (item in dwc_all()) {
                if (!(item$term %in% special_no_dropdown)) {
                    set_map_value(item$term, "", update_input = TRUE)
                }
            }
            for (term in intersect(all_term_names(), special_no_dropdown)) {
                rv$map_values[[term]] <- ""
            }
            rv$map_meta <- empty_map_meta(all_term_names())
            rv$ambiguity_queue <- list()
            rv$rostrum_decisions <- NULL
            rv$rostrum_run_stats <- list()
            # Reset custom inputs
            shiny::updateTextInput(session, "custom_datasetName", value = "")
            shiny::updateCheckboxInput(session, "modified_use_today", value = FALSE)
            shiny::updateDateInput(session, "custom_modified_date", value = Sys.Date())
            shiny::updateCheckboxGroupInput(session, "custom_license", selected = character(0))
            shiny::updateCheckboxGroupInput(session, "custom_language", selected = character(0))
            reset_basis_of_record_state(rv)
            rv$is_programmatic_update <- FALSE
            rv$programmatic_terms <- character(0)
            shiny::removeModal()
            shiny::showNotification(tr("notif_mapping_reset", lang_r()), type = "warning", duration = 3)
        })

        # Enforce single-selection for license checkboxGroupInput
        shiny::observeEvent(input$custom_license,
            {
                if (length(input$custom_license) > 1) {
                    # Keep only the most recently selected item (last in the vector)
                    shiny::updateCheckboxGroupInput(
                        session, "custom_license",
                        selected = utils::tail(input$custom_license, 1)
                    )
                }

                has_value <- !is.null(input$custom_license) && length(input$custom_license) > 0
                set_custom_term_meta("license", has_value)
            },
            ignoreInit = TRUE
        )

        # Enforce single-selection for language checkboxGroupInput
        shiny::observeEvent(input$custom_language,
            {
                if (length(input$custom_language) > 1) {
                    shiny::updateCheckboxGroupInput(
                        session, "custom_language",
                        selected = utils::tail(input$custom_language, 1)
                    )
                }

                has_value <- !is.null(input$custom_language) && length(input$custom_language) > 0
                set_custom_term_meta("language", has_value)
            },
            ignoreInit = TRUE
        )

        # Statistics
        output$mapped_count <- shiny::renderText({
            shiny::req(raw_data_r())

            mapped <- 1 # occurrenceID always counted
            for (item in dwc_all()) {
                term <- item$term
                if (term == "occurrenceID") next
                # Check custom fields
                if (term == "datasetName") {
                    custom_val <- input$custom_datasetName
                    user_cols <- sanitize_map_selection(term, rv$map_values[[term]])
                    if ((!is.null(custom_val) && nchar(trimws(custom_val)) > 0) ||
                        has_selected_value(user_cols)) {
                        mapped <- mapped + 1
                    }
                } else if (term == "modified") {
                    if (isTRUE(input$modified_use_today) || !is.null(input$custom_modified_date)) {
                        mapped <- mapped + 1
                    }
                } else if (term == "license") {
                    if (!is.null(input$custom_license) && length(input$custom_license) > 0) {
                        mapped <- mapped + 1
                    }
                } else if (term == "language") {
                    if (!is.null(input$custom_language) && length(input$custom_language) > 0) {
                        mapped <- mapped + 1
                    }
                } else {
                    user_cols <- sanitize_map_selection(term, rv$map_values[[term]])
                    if (has_selected_value(user_cols)) {
                        mapped <- mapped + 1
                    }
                }
            }
            mapped
        })

        output$total_fields <- shiny::renderText({
            length(dwc_all())
        })

        build_mapped_result <- function(df_input, occurrence_ids_input) {
            build_processed_mapping_df(
                df = df_input,
                dwc_terms = dwc_all(),
                map_values = rv$map_values,
                occurrence_ids = occurrence_ids_input,
                custom_dataset_name = input$custom_datasetName,
                modified_use_today = isTRUE(input$modified_use_today),
                custom_modified_date = input$custom_modified_date,
                custom_license = input$custom_license,
                custom_language = input$custom_language,
                basis_of_record_map = rv$basis_of_record_map,
                now_utc = Sys.time(),
                out_sep = " | "
            )
        }

        # Full mapped data (used by export and validation modules)
        processed_data <- shiny::reactive({
            shiny::req(raw_data_r())

            df <- raw_data_r()
            if (is.null(rv$occurrence_ids) || length(rv$occurrence_ids) != nrow(df)) {
                rv$occurrence_ids <- ids::uuid(n = nrow(df))
            }

            processed_result <- build_mapped_result(
                df_input = df,
                occurrence_ids_input = rv$occurrence_ids
            )

            if (!identical(rv$eventdate_parse_failures, processed_result$eventdate_failure_count)) {
                rv$eventdate_parse_failures <- processed_result$eventdate_failure_count
            }

            processed_result$data
        })

        # Gates must survive upstream `req()` (e.g., upload without file) and
        # report a stable "no_data" state instead of aborting UI render.
        safe_raw_data_for_gate <- function() {
            tryCatch(
                raw_data_r(),
                error = function(e) {
                    if (inherits(e, "shiny.silent.error")) {
                        return(NULL)
                    }
                    stop(e)
                }
            )
        }

        # Lightweight gate for validation modules: avoid materializing processed_data
        # just to know if scientificName mapping is ready.
        validation_gate_r <- shiny::reactive({
            raw_df <- safe_raw_data_for_gate()
            if (is.null(raw_df) || !is.data.frame(raw_df) || nrow(raw_df) == 0L) {
                return(list(status = "no_data", has_data = FALSE, scientific_col = ""))
            }

            selected <- sanitize_map_selection("scientificName", rv$map_values[["scientificName"]])
            if (!has_selected_value(selected)) {
                selected <- sanitize_map_selection("scientificName", input$map_scientificName)
            }

            scientific_col <- if (has_selected_value(selected)) as.character(selected[[1]]) else ""
            has_scientific <- nzchar(scientific_col) && scientific_col %in% names(raw_df)

            list(
                status = if (has_scientific) "ok" else "missing_scientific",
                has_data = TRUE,
                scientific_col = scientific_col
            )
        })

        # Lightweight gate for coordinate validation without materializing processed_data
        coord_validation_gate_r <- shiny::reactive({
            raw_df <- safe_raw_data_for_gate()
            if (is.null(raw_df) || !is.data.frame(raw_df) || nrow(raw_df) == 0L) {
                return(list(
                    coords_status = "no_data",
                    has_data = FALSE,
                    lat_col = "",
                    lon_col = "",
                    country_col = "",
                    has_lat = FALSE,
                    has_lon = FALSE,
                    has_country = FALSE
                ))
            }

            lat_selected <- sanitize_map_selection("decimalLatitude", rv$map_values[["decimalLatitude"]])
            if (!has_selected_value(lat_selected)) {
                lat_selected <- sanitize_map_selection("decimalLatitude", input$map_decimalLatitude)
            }
            lon_selected <- sanitize_map_selection("decimalLongitude", rv$map_values[["decimalLongitude"]])
            if (!has_selected_value(lon_selected)) {
                lon_selected <- sanitize_map_selection("decimalLongitude", input$map_decimalLongitude)
            }
            country_selected <- sanitize_map_selection("country", rv$map_values[["country"]])
            if (!has_selected_value(country_selected)) {
                country_selected <- sanitize_map_selection("country", input$map_country)
            }

            lat_col <- if (has_selected_value(lat_selected)) as.character(lat_selected[[1]]) else ""
            lon_col <- if (has_selected_value(lon_selected)) as.character(lon_selected[[1]]) else ""
            country_col <- if (has_selected_value(country_selected)) as.character(country_selected[[1]]) else ""

            has_lat <- nzchar(lat_col) && lat_col %in% names(raw_df)
            has_lon <- nzchar(lon_col) && lon_col %in% names(raw_df)
            has_country <- nzchar(country_col) && country_col %in% names(raw_df)

            missing_count <- sum(!c(has_lat, has_lon, has_country))
            status <- if (has_lat && has_lon && has_country) {
                "ok"
            } else if (missing_count >= 2L) {
                "missing_multiple"
            } else if (!has_lat) {
                "missing_lat"
            } else if (!has_lon) {
                "missing_lon"
            } else {
                "missing_country"
            }

            list(
                coords_status = status,
                has_data = TRUE,
                lat_col = lat_col,
                lon_col = lon_col,
                country_col = country_col,
                has_lat = has_lat,
                has_lon = has_lon,
                has_country = has_country
            )
        })

        # Lightweight mapped preview (first 100 raw rows only)
        preview_processed_data <- shiny::reactive({
            shiny::req(raw_data_r())

            preview_raw <- utils::head(raw_data_r(), 100L)
            preview_occurrence_ids <- if (nrow(preview_raw) > 0L) {
                sprintf("preview-%06d", seq_len(nrow(preview_raw)))
            } else {
                character(0)
            }

            preview_result <- build_mapped_result(
                df_input = preview_raw,
                occurrence_ids_input = preview_occurrence_ids
            )

            preview_result$data
        })

        # Return named list of reactives (ADR-054: replaces attr()-based contract)
        # Slots kept for 1-release transition: processed_data_r, preview_data_r,
        #   validation_gate_r, validation_gate_coords_r.
        # New Rostrum slots (Onda 2): rostrum_decisions_r, rostrum_explain_r,
        #   rostrum_run_stats_r.
        return(list(
            processed_data_r         = processed_data,
            preview_data_r           = preview_processed_data,
            validation_gate_r        = validation_gate_r,
            validation_gate_coords_r = coord_validation_gate_r,
            rostrum_decisions_r      = shiny::reactive(rv$rostrum_decisions),
            rostrum_explain_r        = shiny::reactive(rv$map_meta),
            rostrum_run_stats_r      = shiny::reactive(rv$rostrum_run_stats)
        ))
    })
}
