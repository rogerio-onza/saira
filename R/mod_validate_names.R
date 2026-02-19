# Title: Validate Names Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-19
# Version: 2.2

#' Validate Names Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_validate_names_ui <- function(id) {
    ns <- shiny::NS(id)

    shiny::tagList(
        shiny::div(
            class = "container-fluid validate-names-page",
            style = "max-width: 1320px;",
            shiny::uiOutput(ns("title")),
            shiny::uiOutput(ns("subtitle")),
            shiny::div(
                class = "row g-4 validate-names-layout",
                shiny::div(
                    class = "col-12 col-lg-6 validate-names-left",
                    shiny::uiOutput(ns("providers_card")),
                    shiny::uiOutput(ns("options_card")),
                    shiny::uiOutput(ns("run_summary")),
                    shiny::uiOutput(ns("stats")),
                    shiny::uiOutput(ns("results"))
                ),
                shiny::div(
                    class = "col-12 col-lg-6 validate-names-right",
                    shiny::uiOutput(ns("action_card")),
                    shiny::uiOutput(ns("pre_right_hint")),
                    shiny::uiOutput(ns("progress_panel")),
                    shiny::uiOutput(ns("stream_panel"))
                )
            )
        )
    )
}

#' Validate Names Module Server
#'
#' @param id Module ID
#' @param mapped_data_r Reactive data frame with mapped data
#' @param lang_r Reactive language value
#' @param validation_gate_r Optional lightweight gate reactive from mapping module
#' @return Reactive validation report data frame
#' @export
mod_validate_names_server <- function(id, mapped_data_r, lang_r, validation_gate_r = NULL) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        provider_catalog <- list(
            list(id = "gbif", short = "GBIF", full_key = "validate_names_provider_gbif_full", desc_key = "validate_names_provider_gbif_desc", icon = "earth-americas", recommended = TRUE),
            list(id = "itis", short = "ITIS", full_key = "validate_names_provider_itis_full", desc_key = "validate_names_provider_itis_desc", icon = "leaf", recommended = FALSE),
            list(id = "col", short = "COL", full_key = "validate_names_provider_col_full", desc_key = "validate_names_provider_col_desc", icon = "book-atlas", recommended = FALSE),
            list(id = "ncbi", short = "NCBI", full_key = "validate_names_provider_ncbi_full", desc_key = "validate_names_provider_ncbi_desc", icon = "dna", recommended = FALSE)
        )
        provider_ids <- vapply(provider_catalog, function(item) item$id, FUN.VALUE = character(1))
        provider_labels <- stats::setNames(vapply(provider_catalog, function(item) item$short, FUN.VALUE = character(1)), provider_ids)
        stream_window_limit <- 100L
        stream_filter_values <- c("all", "problems", "not_found", "ambiguous", "synonym", "ignored")

        validation_result <- shiny::reactiveVal(NULL)
        validation_meta <- shiny::reactiveVal(NULL)

        rv <- shiny::reactiveValues(
            selected_providers = c("gbif"),
            starting = FALSE,
            start_requested = FALSE,
            running = FALSE,
            abort_requested = FALSE,
            run_state = NULL,
            stream_df = empty_validation_stream(),
            stream_filter = "all",
            last_run_status = "idle",
            last_error = NA_character_
        )

        provider_button_id <- function(provider_id) paste0("provider_card_", provider_id)

        format_provider_labels <- function(provider_values) {
            values_chr <- as.character(provider_values)
            values_chr <- values_chr[!is.na(values_chr) & nzchar(values_chr)]
            if (length(values_chr) == 0L) return(character(0))
            labels <- unname(provider_labels[values_chr])
            missing_idx <- is.na(labels) | !nzchar(labels)
            labels[missing_idx] <- toupper(values_chr[missing_idx])
            unique(labels)
        }

        normalize_provider_failures <- function(raw_failures) {
            if (!is.data.frame(raw_failures) || nrow(raw_failures) == 0L) {
                return(data.frame(provider = character(0), error = character(0), stringsAsFactors = FALSE))
            }

            out <- raw_failures
            if (!"provider" %in% names(out)) out$provider <- NA_character_
            if (!"error" %in% names(out)) out$error <- NA_character_
            out$provider <- as.character(out$provider)
            out$error <- as.character(out$error)
            out <- out[!is.na(out$provider) & nzchar(out$provider), c("provider", "error"), drop = FALSE]
            rownames(out) <- NULL
            out
        }

        stream_window <- function(stream_df, limit = stream_window_limit) {
            if (!is.data.frame(stream_df) || nrow(stream_df) == 0L) return(empty_validation_stream())
            out <- stream_df
            if (!"display_order" %in% names(out)) out$display_order <- seq_len(nrow(out))
            out <- out[order(out$display_order, decreasing = TRUE), , drop = FALSE]
            limit_int <- suppressWarnings(as.integer(limit))
            if (is.na(limit_int) || limit_int <= 0L) limit_int <- 100L
            if (nrow(out) > limit_int) out <- out[seq_len(limit_int), , drop = FALSE]
            rownames(out) <- NULL
            out
        }

        provider_failure_lines <- function(failure_df, resolved_unique = 0L) {
            if (!is.data.frame(failure_df) || nrow(failure_df) == 0L) return(character(0))

            resolved_int <- suppressWarnings(as.integer(resolved_unique))
            if (is.na(resolved_int) || resolved_int < 0L) resolved_int <- 0L

            vapply(seq_len(nrow(failure_df)), function(i) {
                provider_label <- format_provider_labels(failure_df$provider[[i]])
                if (length(provider_label) == 0L) provider_label <- toupper(as.character(failure_df$provider[[i]]))
                else provider_label <- provider_label[[1]]
                error_text <- as.character(failure_df$error[[i]])
                if (is.na(error_text) || !nzchar(error_text)) error_text <- tr("validate_names_error_unknown", lang_r())
                sprintf(tr("validate_names_provider_failed_stream_item", lang_r()), provider_label, resolved_int, error_text)
            }, FUN.VALUE = character(1))
        }

        phase_label <- function(state) {
            phase_value <- as.character(state$phase %||% "")
            switch(phase_value,
                prepare = tr("validate_names_progress_phase_prepare", lang_r()),
                provider_init = tr("validate_names_progress_phase_provider_init", lang_r()),
                provider_query_batch = tr("validate_names_progress_phase_provider_query_batch", lang_r()),
                provider_finalize = tr("validate_names_progress_phase_provider_finalize", lang_r()),
                consolidate = tr("validate_names_progress_phase_consolidate", lang_r()),
                done = tr("validate_names_progress_phase_done", lang_r()),
                failed = tr("validate_names_progress_phase_failed", lang_r()),
                tr("validate_names_progress_phase_prepare", lang_r())
            )
        }

        status_style_map <- function(status_value) {
            status_key <- as.character(status_value)
            status_key <- ifelse(is.na(status_key) | !nzchar(status_key), "not_found", tolower(status_key))

            if (identical(status_key, "accepted")) return(list(icon = "fa-solid fa-circle-check validation-stream-icon validation-stream-icon-accepted", label_key = "validate_names_stream_status_accepted", item_class = "validation-stream-item-accepted"))
            if (identical(status_key, "synonym")) return(list(icon = "fa-solid fa-circle-info validation-stream-icon validation-stream-icon-synonym", label_key = "validate_names_stream_status_synonym", item_class = "validation-stream-item-synonym"))
            if (status_key %in% c("ambiguous", "unresolved")) return(list(icon = "fa-solid fa-circle-question validation-stream-icon validation-stream-icon-ambiguous", label_key = "validate_names_stream_status_ambiguous", item_class = "validation-stream-item-ambiguous"))
            if (status_key %in% c("invalid", "ignored")) return(list(icon = "fa-regular fa-circle-xmark validation-stream-icon validation-stream-icon-ignored", label_key = "validate_names_stream_status_ignored", item_class = "validation-stream-item-ignored"))
            list(icon = "fa-regular fa-circle-xmark validation-stream-icon validation-stream-icon-not-found", label_key = "validate_names_stream_status_not_found", item_class = "validation-stream-item-not-found")
        }

        normalize_status_for_filter <- function(status_value) {
            status_key <- tolower(as.character(status_value %||% ""))
            if (!nzchar(status_key) || is.na(status_key)) return("not_found")
            if (identical(status_key, "unresolved")) return("ambiguous")
            if (identical(status_key, "invalid")) return("ignored")
            if (status_key %in% c("accepted", "synonym", "not_found", "ambiguous", "ignored")) return(status_key)
            "not_found"
        }

        stream_filter_counts <- function(stream_df) {
            out <- c(
                all = 0L,
                problems = 0L,
                not_found = 0L,
                ambiguous = 0L,
                synonym = 0L,
                ignored = 0L
            )
            if (!is.data.frame(stream_df) || nrow(stream_df) == 0L) return(out)
            status_vec <- vapply(stream_df$validation_status, normalize_status_for_filter, FUN.VALUE = character(1))
            out[["all"]] <- as.integer(length(status_vec))
            out[["not_found"]] <- as.integer(sum(status_vec == "not_found", na.rm = TRUE))
            out[["ambiguous"]] <- as.integer(sum(status_vec == "ambiguous", na.rm = TRUE))
            out[["synonym"]] <- as.integer(sum(status_vec == "synonym", na.rm = TRUE))
            out[["ignored"]] <- as.integer(sum(status_vec == "ignored", na.rm = TRUE))
            out[["problems"]] <- as.integer(sum(status_vec != "accepted", na.rm = TRUE))
            out
        }

        filter_stream_df <- function(stream_df, filter_key = "all") {
            if (!is.data.frame(stream_df) || nrow(stream_df) == 0L) return(stream_df)
            key <- as.character(filter_key %||% "all")
            if (!(key %in% stream_filter_values)) key <- "all"
            if (identical(key, "all")) return(stream_df)

            status_vec <- vapply(stream_df$validation_status, normalize_status_for_filter, FUN.VALUE = character(1))
            keep_idx <- switch(key,
                problems = status_vec != "accepted",
                not_found = status_vec == "not_found",
                ambiguous = status_vec == "ambiguous",
                synonym = status_vec == "synonym",
                ignored = status_vec == "ignored",
                rep(TRUE, length(status_vec))
            )
            out <- stream_df[keep_idx, , drop = FALSE]
            rownames(out) <- NULL
            out
        }

        stream_filter_after_completion <- function(report_df) {
            if (!is.data.frame(report_df) || nrow(report_df) == 0L) return("all")
            "problems"
        }

        toggle_provider_selection <- function(provider_id) {
            selected <- as.character(rv$selected_providers)
            selected <- selected[!is.na(selected) & nzchar(selected)]
            if (provider_id %in% selected) selected <- selected[selected != provider_id] else selected <- c(selected, provider_id)
            rv$selected_providers <- selected
        }

        for (provider_id in provider_ids) {
            local({
                id_local <- provider_id
                shiny::observeEvent(input[[provider_button_id(id_local)]], {
                    if (isTRUE(rv$running)) return(invisible(NULL))
                    toggle_provider_selection(id_local)
                }, ignoreInit = TRUE)
            })
        }

        prepared_inputs <- shiny::reactive({
            df <- mapped_data_r()
            if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
                return(list(status = "no_data", unique_df = data.frame(), valid_queries = character(0), valid_count = 0L))
            }
            if (!"scientificName" %in% names(df)) {
                return(list(status = "missing_scientific", unique_df = data.frame(), valid_queries = character(0), valid_count = 0L))
            }

            input_df <- prepare_taxadb_inputs(
                names_vec = df$scientificName,
                remove_authors = isTRUE(input$remove_authors %||% TRUE),
                ignore_qualifiers = isTRUE(input$ignore_qualifiers %||% TRUE)
            )
            dedupe_key <- ifelse(is.na(input_df$query_name) | !nzchar(input_df$query_name), paste0("NA__", input_df$input_name), input_df$query_name)
            unique_df <- input_df[!duplicated(dedupe_key), , drop = FALSE]

            valid_queries <- unique(as.character(unique_df$query_name))
            valid_queries <- valid_queries[!is.na(valid_queries) & nzchar(valid_queries)]
            list(status = "ok", unique_df = unique_df, valid_queries = valid_queries, valid_count = length(valid_queries))
        })

        # Keep tab rendering fast: do not inspect scientific names on initial paint.
        quick_inputs <- shiny::reactive({
            if (!is.null(validation_gate_r) && shiny::is.reactive(validation_gate_r)) {
                gate <- validation_gate_r()
                gate_status <- as.character(gate$status %||% "")
                if (identical(gate_status, "ok")) return(list(status = "ok"))
                if (identical(gate_status, "no_data")) return(list(status = "no_data"))
                return(list(status = "missing_scientific"))
            }

            df <- mapped_data_r()
            if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
                return(list(status = "no_data"))
            }
            if (!"scientificName" %in% names(df)) {
                return(list(status = "missing_scientific"))
            }

            list(status = "ok")
        })

        active_options_count <- shiny::reactive({
            sum(c(isTRUE(input$remove_authors %||% TRUE), isTRUE(input$ignore_qualifiers %||% TRUE)))
        })

        can_run_validation <- shiny::reactive({
            prep <- quick_inputs()
            length(rv$selected_providers) > 0L && identical(prep$status, "ok") && !isTRUE(rv$running) && !isTRUE(rv$starting)
        })

        has_validation_output <- shiny::reactive({
            report <- validation_result()
            is.data.frame(report) && nrow(report) > 0L
        })

        is_pre_validation_state <- shiny::reactive({
            !isTRUE(rv$running) &&
                !isTRUE(rv$starting) &&
                is.null(rv$run_state) &&
                !isTRUE(has_validation_output())
        })

        active_stream_filter <- shiny::reactive({
            key <- as.character(rv$stream_filter %||% "all")
            if (!(key %in% stream_filter_values)) key <- "all"
            key
        })

        for (filter_key in stream_filter_values) {
            local({
                key_local <- filter_key
                shiny::observeEvent(input[[paste0("stream_filter_", key_local)]], {
                    rv$stream_filter <- key_local
                }, ignoreInit = TRUE)
            })
        }

        output$title <- shiny::renderUI({
            shiny::h3(shiny::icon("microscope", class = "me-2"), tr("validate_names_title", lang_r()), class = "text-mono mb-2")
        })

        output$subtitle <- shiny::renderUI({
            shiny::p(tr("validate_names_subtitle", lang_r()), class = "text-accent mb-4")
        })

        output$providers_card <- shiny::renderUI({
            selected <- as.character(rv$selected_providers)
            selected <- selected[!is.na(selected) & nzchar(selected)]

            bslib::card(
                class = "validate-names-card mb-3",
                bslib::card_header(shiny::div(class = "validate-card-title", shiny::icon("database", class = "me-2"), tr("validate_names_providers_card_title", lang_r()))),
                bslib::card_body(
                    shiny::div(
                        class = "provider-card-grid",
                        lapply(provider_catalog, function(item) {
                            priority <- match(item$id, selected)
                            is_selected <- !is.na(priority)
                            card_class <- paste("provider-card w-100", if (is_selected) "provider-card-selected" else "", if (isTRUE(rv$running) || isTRUE(rv$starting)) "provider-card-disabled" else "")

                            badges <- list()
                            if (isTRUE(item$recommended)) badges[[length(badges) + 1L]] <- shiny::tags$span(class = "provider-badge provider-badge-recommended", tr("validate_names_provider_recommended", lang_r()))
                            if (is_selected) badges[[length(badges) + 1L]] <- shiny::tags$span(class = "provider-badge provider-priority-badge", sprintf(tr("validate_names_provider_priority_badge", lang_r()), as.integer(priority)))

                            shiny::actionButton(
                                inputId = ns(provider_button_id(item$id)),
                                icon = shiny::icon(item$icon),
                                label = shiny::tagList(
                                    shiny::div(class = "provider-card-top",
                                        shiny::div(class = "provider-card-top-left", shiny::span(class = "provider-card-short", item$short), shiny::span(class = "provider-card-full", tr(item$full_key, lang_r()))),
                                        shiny::div(class = "provider-card-badges", badges)
                                    ),
                                    shiny::div(class = "provider-card-desc", tr(item$desc_key, lang_r()))
                                ),
                                class = card_class,
                                disabled = isTRUE(rv$running) || isTRUE(rv$starting)
                            )
                        })
                    ),
                    shiny::div(class = "validate-names-provider-notice mt-3", shiny::icon("circle-info", class = "me-2"), tr("validate_names_priority_notice", lang_r())),
                    shiny::div(class = "validate-names-provider-reset mt-2", tr("validate_names_priority_reset_notice", lang_r()))
                )
            )
        })

        output$options_card <- shiny::renderUI({
            bslib::card(
                class = "validate-names-card mb-3",
                bslib::card_header(shiny::div(class = "validate-card-title", shiny::icon("sliders", class = "me-2"), tr("validate_names_options_card_title", lang_r()))),
                bslib::card_body(
                    shiny::div(
                        class = "validate-options-grid",
                        shiny::div(class = "validate-option-row",
                            bslib::input_switch(ns("remove_authors"), tr("validate_names_remove_authors", lang_r()), value = isTRUE(input$remove_authors %||% TRUE)),
                            shiny::p(tr("validate_names_remove_authors_desc", lang_r()), class = "validate-option-desc")
                        ),
                        shiny::div(class = "validate-option-row",
                            bslib::input_switch(ns("ignore_qualifiers"), tr("validate_names_ignore_qualifiers", lang_r()), value = isTRUE(input$ignore_qualifiers %||% TRUE)),
                            shiny::p(tr("validate_names_ignore_qualifiers_desc", lang_r()), class = "validate-option-desc")
                        )
                    ),
                    shiny::div(class = "validate-option-row mt-3", shiny::span(class = "validate-option-help", shiny::icon("download", class = "me-2"), tr("validate_names_download_notice", lang_r())))
                )
            )
        })

        output$action_card <- shiny::renderUI({
            is_busy <- isTRUE(rv$running) || isTRUE(rv$starting)
            run_label <- if (is_busy) tr("validate_names_run_running", lang_r()) else tr("validate_names_run", lang_r())

            bslib::card(
                class = "validate-names-card mb-3",
                bslib::card_header(shiny::div(class = "validate-card-title", shiny::icon("bolt", class = "me-2"), tr("validate_names_action_card_title", lang_r()))),
                bslib::card_body(
                    shiny::div(
                        class = "validate-action-metrics",
                        shiny::div(class = "validate-action-metric", shiny::div(class = "metric-value", length(rv$selected_providers)), shiny::div(class = "metric-label", tr("validate_names_action_metric_providers", lang_r()))),
                        shiny::div(class = "validate-action-metric", shiny::div(class = "metric-value", active_options_count()), shiny::div(class = "metric-label", tr("validate_names_action_metric_options", lang_r())))
                    ),
                    shiny::actionButton(inputId = ns("validate"), label = run_label, icon = shiny::icon(if (is_busy) "spinner" else "play", class = if (is_busy) "fa-spin" else ""), class = "btn-primary w-100 validate-names-run-btn mt-3", disabled = !isTRUE(can_run_validation())),
                    if (isTRUE(rv$running)) shiny::actionButton(inputId = ns("cancel_validation"), label = tr("validate_names_cancel", lang_r()), icon = shiny::icon("stop"), class = "btn-outline-primary w-100 mt-2", disabled = isTRUE(rv$abort_requested)),
                    shiny::div(
                        class = "validate-action-help mt-3",
                        if (isTRUE(rv$running) && isTRUE(rv$abort_requested)) tr("validate_names_cancel_requested", lang_r())
                        else if (isTRUE(rv$starting)) tr("validate_names_run_running", lang_r())
                        else if (length(rv$selected_providers) == 0L) tr("validate_names_providers_required", lang_r())
                        else tr("validate_names_action_ready", lang_r())
                    )
                )
            )
        })

        output$pre_right_hint <- shiny::renderUI({
            if (!isTRUE(is_pre_validation_state())) return(NULL)
            shiny::div(
                class = "validate-pre-right",
                shiny::div(
                    class = "validate-ready-hint",
                    shiny::icon("circle-info"),
                    shiny::div(
                        shiny::strong(tr("validate_names_ready_hint_title", lang_r())),
                        shiny::p(tr("validate_names_ready_hint_body", lang_r()))
                    )
                )
            )
        })

        output$progress_panel <- shiny::renderUI({
            if (isTRUE(is_pre_validation_state())) {
                return(NULL)
            }
            state <- rv$run_state
            if (isTRUE(rv$starting) && is.null(state)) {
                return(
                    bslib::card(
                        class = "validate-names-card mb-3 validation-progress-panel",
                        bslib::card_body(
                            shiny::div(
                                class = "validation-progress-empty",
                                shiny::icon("spinner", class = "me-2 fa-spin"),
                                tr("validate_names_progress_status_running", lang_r())
                            )
                        )
                    )
                )
            }
            if (is.null(state) && !isTRUE(has_validation_output())) {
                return(
                    bslib::card(
                        class = "validate-names-card mb-3 validation-progress-panel",
                        bslib::card_body(shiny::div(class = "validation-progress-empty", shiny::icon("hourglass-half", class = "me-2"), tr("validate_names_progress_idle", lang_r())))
                    )
                )
            }
            if (is.null(state) && isTRUE(has_validation_output())) {
                return(NULL)
            }

            total_unique <- suppressWarnings(as.integer(state$total_unique %||% 0L))
            resolved_unique <- suppressWarnings(as.integer(state$resolved_unique %||% 0L))
            if (is.na(total_unique) || total_unique < 0L) total_unique <- 0L
            if (is.na(resolved_unique) || resolved_unique < 0L) resolved_unique <- 0L

            progress_pct <- if (total_unique > 0L) as.integer(round((resolved_unique / total_unique) * 100)) else 0L
            progress_pct <- max(0L, min(100L, progress_pct))

            provider_label <- format_provider_labels(state$current_provider %||% "")
            if (length(provider_label) == 0L) provider_label <- tr("validate_names_loading_provider_unknown", lang_r()) else provider_label <- provider_label[[1]]

            batch_idx <- suppressWarnings(as.integer(state$provider_batch_idx %||% 0L))
            batch_total <- suppressWarnings(as.integer(state$provider_batch_total %||% 0L))
            if (is.na(batch_idx) || batch_idx < 0L) batch_idx <- 0L
            if (is.na(batch_total) || batch_total < 0L) batch_total <- 0L

            status_text <- if (isTRUE(rv$running)) tr("validate_names_progress_status_running", lang_r()) else if (isTRUE(state$aborted)) tr("validate_names_progress_status_cancelled", lang_r()) else if (identical(rv$last_run_status, "failed")) tr("validate_names_progress_status_failed", lang_r()) else tr("validate_names_progress_status_done", lang_r())
            failure_lines <- provider_failure_lines(normalize_provider_failures(state$provider_failures), resolved_unique = resolved_unique)

            bslib::card(
                class = "validate-names-card mb-3 validation-progress-panel",
                bslib::card_header(shiny::div(class = "validate-card-title", shiny::icon("chart-line", class = "me-2"), tr("validate_names_progress_title", lang_r()))),
                bslib::card_body(
                    shiny::div(class = "validation-progress-status-row", shiny::span(class = "validation-progress-status", status_text), shiny::span(class = "validation-progress-counter", sprintf(tr("validate_names_progress_counter", lang_r()), resolved_unique, total_unique))),
                    shiny::div(class = "progress validation-progress-bar", shiny::div(class = "progress-bar", role = "progressbar", style = paste0("width:", progress_pct, "%;"), `aria-valuemin` = 0, `aria-valuemax` = 100, `aria-valuenow` = progress_pct)),
                    shiny::div(class = "validation-progress-meta mt-3",
                        shiny::div(class = "validation-progress-meta-item", shiny::span(class = "meta-label", tr("validate_names_progress_phase_label", lang_r())), shiny::span(class = "meta-value", phase_label(state))),
                        shiny::div(class = "validation-progress-meta-item", shiny::span(class = "meta-label", tr("validate_names_progress_provider_label", lang_r())), shiny::span(class = "meta-value", provider_label)),
                        shiny::div(class = "validation-progress-meta-item", shiny::span(class = "meta-label", tr("validate_names_progress_batch_label", lang_r())), shiny::span(class = "meta-value", if (batch_total > 0L) sprintf("%d/%d", batch_idx, batch_total) else "-"))
                    ),
                    if (length(failure_lines) > 0L) shiny::div(
                        class = "validation-progress-failures mt-3",
                        shiny::div(class = "validation-progress-failures-title", shiny::icon("triangle-exclamation", class = "me-2"), tr("validate_names_provider_failed_stream_title", lang_r())),
                        shiny::tags$ul(class = "validation-progress-failures-list", lapply(failure_lines, function(line) shiny::tags$li(line)))
                    )
                )
            )
        })

        output$stream_panel <- shiny::renderUI({
            if (isTRUE(is_pre_validation_state())) return(NULL)
            stream_df <- stream_window(rv$stream_df, limit = stream_window_limit)
            counts <- stream_filter_counts(stream_df)
            active_filter <- active_stream_filter()
            filtered_df <- filter_stream_df(stream_df, active_filter)

            pill_defs <- list(
                list(key = "all", class = "", label_key = "validate_names_stream_filter_all"),
                list(key = "problems", class = "", label_key = "validate_names_stream_filter_problems"),
                list(key = "not_found", class = "pill-error", label_key = "validate_names_stream_filter_not_found"),
                list(key = "ambiguous", class = "pill-warning", label_key = "validate_names_stream_filter_ambiguous"),
                list(key = "synonym", class = "pill-info", label_key = "validate_names_stream_filter_synonym"),
                list(key = "ignored", class = "pill-muted", label_key = "validate_names_stream_filter_ignored")
            )

            pills_ui <- shiny::div(
                class = "stream-filter-pills",
                lapply(pill_defs, function(item) {
                    count_value <- suppressWarnings(as.integer(counts[[item$key]]))
                    if (is.na(count_value) || count_value < 0L) count_value <- 0L
                    is_active <- identical(active_filter, item$key)
                    shiny::actionButton(
                        inputId = ns(paste0("stream_filter_", item$key)),
                        label = shiny::tagList(
                            tr(item$label_key, lang_r()),
                            shiny::tags$span(class = "pill-count", count_value)
                        ),
                        class = trimws(paste("stream-pill", item$class, if (is_active) "active" else "")),
                        disabled = FALSE
                    )
                })
            )

            if (!is.data.frame(stream_df) || nrow(stream_df) == 0L) {
                return(
                    bslib::card(
                        class = "validate-names-card validation-stream-card",
                        bslib::card_header(shiny::div(class = "validate-card-title", shiny::icon("list-check", class = "me-2"), tr("validate_names_stream_title", lang_r()))),
                        bslib::card_body(
                            pills_ui,
                            shiny::div(class = "validation-stream-empty", shiny::icon("stream", class = "me-2"), if (isTRUE(rv$running)) tr("validate_names_stream_waiting", lang_r()) else tr("validate_names_stream_empty", lang_r()))
                        )
                    )
                )
            }

            stream_items_ui <- if (!is.data.frame(filtered_df) || nrow(filtered_df) == 0L) {
                shiny::div(class = "validation-stream-empty", shiny::icon("filter", class = "me-2"), tr("validate_names_stream_empty_filter", lang_r()))
            } else {
                shiny::div(
                    class = "validation-stream-list",
                    lapply(seq_len(nrow(filtered_df)), function(i) {
                        row <- filtered_df[i, , drop = FALSE]
                        style <- status_style_map(row$validation_status[[1]])
                        provider_label <- format_provider_labels(row$provider[[1]])
                        if (length(provider_label) == 0L) provider_label <- tr("validate_names_loading_provider_unknown", lang_r()) else provider_label <- provider_label[[1]]
                        updated_value <- row$updated_at[[1]]
                        updated_text <- if (inherits(updated_value, "POSIXct")) format(updated_value, "%H:%M:%S") else ""

                        shiny::div(
                            class = paste("validation-stream-item", style$item_class),
                            shiny::tags$i(class = style$icon),
                            shiny::div(
                                class = "validation-stream-main",
                                shiny::div(class = "validation-stream-name", row$query_name[[1]]),
                                shiny::div(class = "validation-stream-meta", paste(tr(style$label_key, lang_r()), provider_label, updated_text, sep = " | "))
                            )
                        )
                    })
                )
            }

            bslib::card(
                class = "validate-names-card validation-stream-card",
                bslib::card_header(shiny::div(class = "validate-card-title", shiny::icon("list-check", class = "me-2"), tr("validate_names_stream_title", lang_r()))),
                bslib::card_body(
                    pills_ui,
                    shiny::div(class = "validation-stream-window-note", sprintf(tr("validate_names_stream_window_note", lang_r()), nrow(stream_df), stream_window_limit)),
                    stream_items_ui
                )
            )
        })

        output$run_summary <- shiny::renderUI({
            report <- validation_result()
            if (is.null(report) || !is.data.frame(report) || nrow(report) == 0L) return(NULL)

            meta <- validation_meta()
            attempted <- if (is.list(meta)) meta$provider_attempted else character(0)
            attempted_labels <- format_provider_labels(attempted)
            provider_line <- if (length(attempted_labels) > 0L) {
                sprintf(tr("validate_names_provider_used_summary", lang_r()), paste(attempted_labels, collapse = ", "))
            } else {
                tr("validate_names_provider_none_summary", lang_r())
            }

            failure_df <- if (is.list(meta)) normalize_provider_failures(meta$provider_failures) else normalize_provider_failures(NULL)
            failure_lines <- provider_failure_lines(failure_df, resolved_unique = nrow(stream_window(rv$stream_df, limit = stream_window_limit)))

            lines <- list(
                shiny::div(class = "validate-summary-line", shiny::icon("circle-info", class = "me-2"), tr("validate_names_unique_notice", lang_r())),
                shiny::div(class = "validate-summary-line", shiny::icon("database", class = "me-2"), provider_line)
            )

            if (isTRUE(rv$last_run_status == "cancelled")) {
                lines[[length(lines) + 1L]] <- shiny::div(class = "validate-summary-line validate-summary-line-warning", shiny::icon("ban", class = "me-2"), tr("validate_names_cancelled_notice", lang_r()))
            }
            if (length(failure_lines) > 0L) {
                lines[[length(lines) + 1L]] <- shiny::div(class = "validate-summary-line validate-summary-line-warning", shiny::icon("triangle-exclamation", class = "me-2"), tr("validate_names_provider_failed_stream_title", lang_r()))
                lines[[length(lines) + 1L]] <- shiny::tags$ul(class = "validate-summary-failure-list", lapply(failure_lines, function(line) shiny::tags$li(line)))
            }

            shiny::div(class = "alert alert-info validate-summary-box", lines)
        })

        output$stats <- shiny::renderUI({
            report <- validation_result()
            if (is.null(report) || !is.data.frame(report) || nrow(report) == 0L) return(NULL)

            status_vec <- tolower(as.character(report$validation_status %||% character(0)))
            status_vec[is.na(status_vec)] <- "not_found"

            valid_count <- sum(status_vec %in% c("accepted", "synonym"), na.rm = TRUE)
            invalid_count <- sum(status_vec %in% c("invalid", "ignored"), na.rm = TRUE)
            unresolved_count <- sum(status_vec %in% c("ambiguous", "unresolved", "not_found"), na.rm = TRUE)

            shiny::div(
                class = "stats-container mb-3",
                shiny::div(class = "stat-box", shiny::div(class = "stat-value", style = "color: var(--success);", valid_count), shiny::div(class = "stat-label", tr("validate_names_valid", lang_r()))),
                shiny::div(class = "stat-box", shiny::div(class = "stat-value", style = "color: var(--error);", invalid_count), shiny::div(class = "stat-label", tr("validate_names_invalid", lang_r()))),
                shiny::div(class = "stat-box", shiny::div(class = "stat-value", style = "color: var(--warning);", unresolved_count), shiny::div(class = "stat-label", tr("validate_names_unresolved", lang_r())))
            )
        })

        output$results <- shiny::renderUI({
            report <- validation_result()
            if (is.null(report) || !is.data.frame(report) || nrow(report) == 0L) return(NULL)

            status_vec <- tolower(as.character(report$validation_status %||% character(0)))
            status_vec[is.na(status_vec)] <- "not_found"
            issues <- report[status_vec != "accepted", , drop = FALSE]

            if (nrow(issues) == 0L) {
                shiny::div(class = "alert alert-success", shiny::icon("check-circle"), " ", tr("validate_names_all_valid", lang_r()))
            } else {
                shiny::div(
                    class = "finch-table-shell",
                    DT::dataTableOutput(ns("issues_table"))
                )
            }
        })

        output$issues_table <- DT::renderDataTable({
            report <- validation_result()
            shiny::req(report)

            status_vec <- tolower(as.character(report$validation_status %||% character(0)))
            status_vec[is.na(status_vec)] <- "not_found"
            issues <- report[status_vec != "accepted", , drop = FALSE]

            if (!"provider" %in% names(issues)) issues$provider <- NA_character_
            issues$provider_label <- vapply(as.character(issues$provider), function(provider_id) {
                labels <- format_provider_labels(provider_id)
                if (length(labels) == 0L) "" else labels[[1]]
            }, FUN.VALUE = character(1))

            keep_cols <- c("scientificName", "validation_status", "provider_label", "taxonomicStatus", "query_name", "input_name")
            keep_cols <- keep_cols[keep_cols %in% names(issues)]
            issues <- issues[, keep_cols, drop = FALSE]

            col_label_map <- c(
                scientificName = tr("validate_names_table_col_scientific_name", lang_r()),
                validation_status = tr("validate_names_table_col_status", lang_r()),
                provider_label = tr("validate_names_table_col_provider", lang_r()),
                taxonomicStatus = tr("validate_names_table_col_taxonomic_status", lang_r()),
                query_name = tr("validate_names_table_col_query_name", lang_r()),
                input_name = tr("validate_names_table_col_input_name", lang_r())
            )
            colnames(issues) <- unname(col_label_map[keep_cols])

            status_labels <- list(
                accepted = tr("validate_names_status_badge_accepted", lang_r()),
                synonym = tr("validate_names_status_badge_synonym", lang_r()),
                not_found = tr("validate_names_status_badge_not_found", lang_r()),
                ambiguous = tr("validate_names_status_badge_ambiguous", lang_r()),
                ignored = tr("validate_names_status_badge_ignored", lang_r())
            )

            status_badge_js <- DT::JS(
                sprintf(
                    paste0(
                        "function(data, type, row) {",
                        "  var status = (data === null || data === undefined) ? '' : String(data).toLowerCase();",
                        "  if (status === 'unresolved') status = 'ambiguous';",
                        "  if (status === 'invalid') status = 'ignored';",
                        "  if (type !== 'display') return status;",
                        "  var labels = %s;",
                        "  var cls = {accepted:'status-accepted', synonym:'status-synonym', not_found:'status-not-found', ambiguous:'status-ambiguous', ignored:'status-ignored'}[status] || 'status-ignored';",
                        "  var label = labels[status] || String(data || '');",
                        "  var escaped = $('<div/>').text(label).html();",
                        "  return '<span class=\"validation-status-badge ' + cls + '\">' + escaped + '</span>';",
                        "}"
                    ),
                    jsonlite::toJSON(status_labels, auto_unbox = TRUE)
                )
            )

            scientific_name_js <- DT::JS(
                "function(data, type, row) {",
                "  if (type !== 'display') return data;",
                "  if (data === null || data === undefined) return '';",
                "  var escaped = $('<div/>').text(String(data)).html();",
                "  return '<em>' + escaped + '</em>';",
                "}"
            )

            row_callback_js <- DT::JS(
                "function(row, data, index) {",
                "  var status = (data[1] === null || data[1] === undefined) ? '' : String(data[1]).toLowerCase();",
                "  if (status === 'unresolved') status = 'ambiguous';",
                "  if (status === 'invalid') status = 'ignored';",
                "  var classes = ['validate-accepted', 'validate-synonym', 'validate-not-found', 'validate-ambiguous', 'validate-invalid'];",
                "  for (var i = 0; i < classes.length; i++) { $(row).removeClass(classes[i]); }",
                "  var classMap = {accepted:'validate-accepted', synonym:'validate-synonym', not_found:'validate-not-found', ambiguous:'validate-ambiguous', ignored:'validate-invalid'};",
                "  var cls = classMap[status];",
                "  if (cls) $(row).addClass(cls);",
                "}"
            )

            DT::datatable(
                issues,
                options = list(
                    pageLength = 10,
                    lengthMenu = c(10, 25, 50, 100),
                    scrollX = TRUE,
                    autoWidth = FALSE,
                    columnDefs = list(
                        list(targets = 0, render = scientific_name_js),
                        list(targets = 1, render = status_badge_js)
                    ),
                    rowCallback = row_callback_js,
                    language = list(
                        search = tr("validate_names_datatable_search", lang_r()),
                        lengthMenu = tr("validate_names_datatable_length_menu", lang_r()),
                        info = tr("validate_names_datatable_info", lang_r()),
                        emptyTable = tr("validate_names_datatable_empty", lang_r()),
                        zeroRecords = tr("validate_names_datatable_zero_records", lang_r()),
                        paginate = list(
                            first = tr("validate_names_datatable_first", lang_r()),
                            last = tr("validate_names_datatable_last", lang_r()),
                            `next` = tr("validate_names_datatable_next", lang_r()),
                            previous = tr("validate_names_datatable_prev", lang_r())
                        )
                    )
                ),
                class = "display compact validate-results-table",
                rownames = FALSE,
                escape = FALSE
            )
        })

        shiny::observeEvent(input$validate, {
            if (isTRUE(rv$running) || isTRUE(rv$starting)) return(invisible(NULL))

            quick <- quick_inputs()
            if (!identical(quick$status, "ok")) {
                msg <- if (identical(quick$status, "missing_scientific")) tr("validate_names_missing_scientific_name", lang_r()) else tr("validate_names_no_data", lang_r())
                shiny::showNotification(msg, type = "warning")
                return(invisible(NULL))
            }
            if (length(rv$selected_providers) == 0L) {
                shiny::showNotification(tr("validate_names_providers_required", lang_r()), type = "warning")
                return(invisible(NULL))
            }
            # Enter "starting" phase first so the UI can show immediate feedback.
            rv$starting <- TRUE
            rv$last_run_status <- "starting"
            rv$last_error <- NA_character_
            validation_result(NULL)
            validation_meta(NULL)
            rv$stream_filter <- "all"
            shiny::showNotification(tr("validate_names_progress_status_running", lang_r()), type = "message", duration = 2)

            session$onFlushed(function() {
                rv$start_requested <- TRUE
            }, once = TRUE)
        }, ignoreInit = TRUE)

        shiny::observeEvent(rv$start_requested, {
            if (!isTRUE(rv$start_requested)) return(invisible(NULL))
            rv$start_requested <- FALSE

            # Heavy normalization stays deferred until explicit validate click.
            prep <- prepared_inputs()
            if (prep$valid_count == 0L) {
                rv$starting <- FALSE
                rv$last_run_status <- "idle"
                shiny::showNotification(tr("validate_names_no_valid_queries", lang_r()), type = "warning")
                return(invisible(NULL))
            }

            run_state <- tryCatch(
                init_taxadb_run_state(input_df = prep$unique_df, providers = rv$selected_providers, batch_size = 200L),
                error = function(e) {
                    shiny::showNotification(sprintf(tr("validate_names_failed", lang_r()), as.character(e$message)), type = "error")
                    NULL
                }
            )
            if (is.null(run_state)) {
                rv$starting <- FALSE
                rv$last_run_status <- "failed"
                return(invisible(NULL))
            }

            rv$running <- TRUE
            rv$starting <- FALSE
            rv$abort_requested <- FALSE
            rv$run_state <- run_state
            rv$stream_df <- empty_validation_stream()
            rv$last_run_status <- "running"
            rv$last_error <- NA_character_
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$cancel_validation, {
            if (!isTRUE(rv$running)) return(invisible(NULL))
            rv$abort_requested <- TRUE
        }, ignoreInit = TRUE)

        shiny::observe({
            if (!isTRUE(rv$running) || is.null(rv$run_state)) return(invisible(NULL))
            shiny::invalidateLater(60, session)

            state <- rv$run_state
            if (isTRUE(rv$abort_requested)) state$aborted <- TRUE

            state <- tryCatch(next_taxadb_run_step(state), error = function(e) {
                state$error_message <- as.character(e$message)
                state$phase <- "failed"
                state$completed <- TRUE
                state
            })

            rv$run_state <- state
            rv$stream_df <- state$stream_df
            if (!is_taxadb_run_done(state)) return(invisible(NULL))

            rv$running <- FALSE
            rv$starting <- FALSE
            rv$abort_requested <- FALSE

            if (identical(state$phase, "failed")) {
                rv$last_run_status <- "failed"
                rv$last_error <- sprintf(tr("validate_names_failed", lang_r()), as.character(state$error_message %||% tr("validate_names_error_unknown", lang_r())))
                shiny::showNotification(rv$last_error, type = "error")
                return(invisible(NULL))
            }

            finalized <- finalize_taxadb_run(state)
            validation_result(finalized$report)
            validation_meta(finalized$meta)
            rv$stream_df <- finalized$stream_df
            rv$stream_filter <- stream_filter_after_completion(finalized$report)

            if (isTRUE(finalized$meta$aborted)) {
                rv$last_run_status <- "cancelled"
                shiny::showNotification(tr("validate_names_cancelled_notice", lang_r()), type = "warning")
            } else {
                rv$last_run_status <- "success"
            }
        })

        shiny::reactive(validation_result())
    })
}
