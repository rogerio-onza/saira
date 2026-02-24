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
                class = "validate-names-workspace",
                shiny::uiOutput(ns("config_panel")),
                shiny::uiOutput(ns("stream_panel")),
                shiny::uiOutput(ns("report_panel"))
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

            if (identical(status_key, "accepted")) return(list(
                key = "accepted",
                icon_symbol = "\u2713",
                label_key = "validate_names_stream_status_accepted",
                item_class = "vn-stream-item-accepted",
                badge_class = "badge-success",
                row_class = "vn-row-accepted"
            ))
            if (identical(status_key, "synonym")) return(list(
                key = "synonym",
                icon_symbol = "\u21C4",
                label_key = "validate_names_stream_status_synonym",
                item_class = "vn-stream-item-synonym",
                badge_class = "badge-info",
                row_class = "vn-row-synonym"
            ))
            if (status_key %in% c("ambiguous", "unresolved")) return(list(
                key = "ambiguous",
                icon_symbol = "?",
                label_key = "validate_names_stream_status_ambiguous",
                item_class = "vn-stream-item-ambiguous",
                badge_class = "badge-warning",
                row_class = "vn-row-ambiguous"
            ))
            if (status_key %in% c("invalid", "ignored")) return(list(
                key = "ignored",
                icon_symbol = "\u2014",
                label_key = "validate_names_stream_status_ignored",
                item_class = "vn-stream-item-ignored",
                badge_class = "badge-muted",
                row_class = "vn-row-ignored"
            ))
            list(
                key = "not_found",
                icon_symbol = "\u2715",
                label_key = "validate_names_stream_status_not_found",
                item_class = "vn-stream-item-not-found",
                badge_class = "badge-error",
                row_class = "vn-row-not-found"
            )
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

        report_status_counts <- function(report_df) {
            out <- c(valid = 0L, invalid = 0L, unresolved = 0L, total = 0L)
            if (!is.data.frame(report_df) || nrow(report_df) == 0L) return(out)

            status_vec <- vapply(report_df$validation_status, normalize_status_for_filter, FUN.VALUE = character(1))
            out[["total"]] <- as.integer(length(status_vec))
            out[["valid"]] <- as.integer(sum(status_vec %in% c("accepted", "synonym"), na.rm = TRUE))
            out[["invalid"]] <- as.integer(sum(status_vec == "ignored", na.rm = TRUE))
            out[["unresolved"]] <- as.integer(sum(status_vec %in% c("not_found", "ambiguous"), na.rm = TRUE))
            out
        }

        progress_snapshot <- function() {
            state <- rv$run_state
            report <- validation_result()
            total_unique <- 0L
            resolved_unique <- 0L
            batch_idx <- 0L
            batch_total <- 0L
            provider_text <- tr("validate_names_loading_provider_unknown", lang_r())
            phase_text <- tr("validate_names_progress_idle", lang_r())

            if (!is.null(state)) {
                total_unique <- suppressWarnings(as.integer(state$total_unique %||% 0L))
                resolved_unique <- suppressWarnings(as.integer(state$resolved_unique %||% 0L))
                batch_idx <- suppressWarnings(as.integer(state$provider_batch_idx %||% 0L))
                batch_total <- suppressWarnings(as.integer(state$provider_batch_total %||% 0L))
                if (is.na(total_unique) || total_unique < 0L) total_unique <- 0L
                if (is.na(resolved_unique) || resolved_unique < 0L) resolved_unique <- 0L
                if (is.na(batch_idx) || batch_idx < 0L) batch_idx <- 0L
                if (is.na(batch_total) || batch_total < 0L) batch_total <- 0L
                provider_label <- format_provider_labels(state$current_provider %||% "")
                if (length(provider_label) > 0L) provider_text <- provider_label[[1]]
                phase_text <- phase_label(state)
            } else if (is.data.frame(report) && nrow(report) > 0L) {
                total_unique <- nrow(report)
                resolved_unique <- total_unique
                phase_text <- tr("validate_names_progress_phase_done", lang_r())
            }

            progress_pct <- if (total_unique > 0L) as.integer(round((resolved_unique / total_unique) * 100)) else 0L
            progress_pct <- max(0L, min(100L, progress_pct))
            batch_text <- if (batch_total > 0L) sprintf("%d/%d", batch_idx, batch_total) else "-"

            list(
                total_unique = total_unique,
                resolved_unique = resolved_unique,
                progress_pct = progress_pct,
                provider_text = provider_text,
                phase_text = phase_text,
                batch_text = batch_text
            )
        }

        output$title <- shiny::renderUI({
            shiny::h3(
                shiny::icon("microscope", class = "me-2"),
                tr("validate_names_title", lang_r()),
                class = "text-mono mb-2"
            )
        })

        output$subtitle <- shiny::renderUI({
            shiny::p(tr("validate_names_subtitle", lang_r()), class = "text-accent mb-4")
        })

        output$config_panel <- shiny::renderUI({
            selected <- as.character(rv$selected_providers)
            selected <- selected[!is.na(selected) & nzchar(selected)]
            is_busy <- isTRUE(rv$running) || isTRUE(rv$starting)
            quick <- quick_inputs()
            snapshot <- progress_snapshot()
            run_label <- if (is_busy) tr("validate_names_run_running", lang_r()) else tr("validate_names_run_cta", lang_r())
            can_run <- isTRUE(can_run_validation())

            helper_text <- if (isTRUE(rv$running) && isTRUE(rv$abort_requested)) {
                tr("validate_names_cancel_requested", lang_r())
            } else if (isTRUE(rv$starting)) {
                tr("validate_names_run_running", lang_r())
            } else if (length(selected) == 0L) {
                tr("validate_names_providers_required", lang_r())
            } else if (!identical(quick$status, "ok")) {
                if (identical(quick$status, "missing_scientific")) {
                    tr("validate_names_missing_scientific_name", lang_r())
                } else {
                    tr("validate_names_no_data", lang_r())
                }
            } else {
                tr("validate_names_action_ready", lang_r())
            }

            shiny::div(
                class = "vn-config-panel",
                shiny::div(
                    class = "vn-config-section vn-config-section-providers",
                    shiny::div(class = "vn-section-label", tr("validate_names_providers_card_title", lang_r())),
                    shiny::div(
                        class = "vn-provider-list",
                        lapply(provider_catalog, function(item) {
                            priority <- match(item$id, selected)
                            is_selected <- !is.na(priority)
                            is_priority_one <- is_selected && identical(as.integer(priority), 1L)
                            card_class <- trimws(paste(
                                "vn-provider-card",
                                if (is_selected) "is-selected" else "",
                                if (is_priority_one) "is-priority-1" else "",
                                if (is_busy) "is-disabled" else ""
                            ))

                            badges <- list()
                            if (isTRUE(item$recommended)) {
                                badges[[length(badges) + 1L]] <- shiny::tags$span(
                                    class = "vn-status-badge badge-success",
                                    tr("validate_names_provider_recommended", lang_r())
                                )
                            }
                            if (is_priority_one) {
                                badges[[length(badges) + 1L]] <- shiny::tags$span(
                                    class = "vn-status-badge badge-info",
                                    sprintf(tr("validate_names_provider_priority_badge", lang_r()), 1L)
                                )
                            }

                            shiny::actionButton(
                                inputId = ns(provider_button_id(item$id)),
                                icon = NULL,
                                label = shiny::div(
                                    class = "vn-provider-card-content",
                                    shiny::span(
                                        class = "vn-provider-icon-wrap",
                                        shiny::icon(item$icon, class = "vn-provider-icon")
                                    ),
                                    shiny::div(
                                        class = "vn-provider-text-wrap",
                                        shiny::span(class = "vn-provider-name", item$short),
                                        shiny::span(class = "vn-provider-desc", tr(item$desc_key, lang_r()))
                                    ),
                                    shiny::div(class = "vn-provider-badges", badges)
                                ),
                                class = card_class,
                                disabled = is_busy
                            )
                        })
                    ),
                    shiny::div(
                        class = "vn-provider-note",
                        shiny::span(class = "vn-note-icon", shiny::HTML("&#8505;")),
                        tr("validate_names_priority_notice", lang_r())
                    )
                ),
                shiny::div(
                    class = "vn-config-section vn-config-section-options",
                    shiny::div(class = "vn-section-label", tr("validate_names_options_card_title", lang_r())),
                    shiny::div(
                        class = "vn-toggle-list",
                        shiny::div(
                            class = "vn-toggle-item",
                            bslib::input_switch(
                                ns("remove_authors"),
                                tr("validate_names_remove_authors", lang_r()),
                                value = isTRUE(input$remove_authors %||% TRUE)
                            ),
                            shiny::p(tr("validate_names_remove_authors_desc", lang_r()), class = "vn-toggle-desc")
                        ),
                        shiny::div(
                            class = "vn-toggle-item",
                            bslib::input_switch(
                                ns("ignore_qualifiers"),
                                tr("validate_names_ignore_qualifiers", lang_r()),
                                value = isTRUE(input$ignore_qualifiers %||% TRUE)
                            ),
                            shiny::p(tr("validate_names_ignore_qualifiers_desc", lang_r()), class = "vn-toggle-desc")
                        )
                    ),
                    shiny::div(
                        class = "vn-options-note",
                        shiny::span(class = "vn-note-icon", shiny::HTML("&#11015;")),
                        tr("validate_names_download_notice", lang_r())
                    )
                ),
                shiny::div(
                    class = "vn-config-section vn-config-section-action",
                    shiny::actionButton(
                        inputId = ns("validate"),
                        label = run_label,
                        class = "vn-run-btn w-100",
                        disabled = !can_run
                    ),
                    if (isTRUE(rv$running)) {
                        shiny::actionButton(
                            inputId = ns("cancel_validation"),
                            label = tr("validate_names_cancel", lang_r()),
                            icon = shiny::icon("stop"),
                            class = "vn-cancel-btn w-100 mt-2",
                            disabled = isTRUE(rv$abort_requested)
                        )
                    },
                    shiny::div(
                        class = "vn-mini-stats",
                        shiny::div(
                            class = "vn-mini-stat",
                            shiny::div(class = "vn-mini-stat-value", as.integer(length(selected))),
                            shiny::div(class = "vn-mini-stat-label", tr("validate_names_action_metric_providers", lang_r()))
                        ),
                        shiny::div(
                            class = "vn-mini-stat",
                            shiny::div(class = "vn-mini-stat-value", as.integer(active_options_count())),
                            shiny::div(class = "vn-mini-stat-label", tr("validate_names_action_metric_options", lang_r()))
                        )
                    ),
                    shiny::div(
                        class = "vn-progress-block",
                        shiny::div(
                            class = "vn-progress-header",
                            shiny::span(class = "vn-progress-title", tr("validate_names_progress_label", lang_r())),
                            shiny::span(class = "vn-progress-percent", sprintf("%d%%", snapshot$progress_pct))
                        ),
                        shiny::div(
                            class = "vn-progress-track",
                            shiny::div(class = "vn-progress-fill", style = paste0("width: ", snapshot$progress_pct, "%;"))
                        ),
                        shiny::div(
                            class = "vn-progress-meta",
                            shiny::div(
                                class = "vn-progress-meta-line",
                                sprintf(tr("validate_names_progress_meta_line1", lang_r()), snapshot$phase_text, snapshot$batch_text)
                            ),
                            shiny::div(
                                class = "vn-progress-meta-line",
                                sprintf(
                                    tr("validate_names_progress_meta_line2", lang_r()),
                                    snapshot$provider_text,
                                    snapshot$resolved_unique,
                                    snapshot$total_unique
                                )
                            )
                        )
                    ),
                    shiny::div(class = "vn-action-helper", helper_text)
                )
            )
        })

        output$stream_panel <- shiny::renderUI({
            stream_df <- stream_window(rv$stream_df, limit = stream_window_limit)
            counts <- stream_filter_counts(stream_df)
            active_filter <- active_stream_filter()
            filtered_df <- filter_stream_df(stream_df, active_filter)

            pill_defs <- list(
                list(key = "all", class = "pill-all", label_key = "validate_names_stream_filter_all"),
                list(key = "problems", class = "pill-problems", label_key = "validate_names_stream_filter_problems"),
                list(key = "not_found", class = "pill-error", label_key = "validate_names_stream_filter_not_found"),
                list(key = "ambiguous", class = "pill-warning", label_key = "validate_names_stream_filter_ambiguous"),
                list(key = "synonym", class = "pill-info", label_key = "validate_names_stream_filter_synonym")
            )

            pills_ui <- shiny::div(
                class = "vn-stream-pills",
                lapply(pill_defs, function(item) {
                    count_value <- suppressWarnings(as.integer(counts[[item$key]]))
                    if (is.na(count_value) || count_value < 0L) count_value <- 0L
                    is_active <- identical(active_filter, item$key)
                    shiny::actionButton(
                        inputId = ns(paste0("stream_filter_", item$key)),
                        label = shiny::tagList(
                            tr(item$label_key, lang_r()),
                            shiny::tags$span(class = "vn-pill-count", count_value)
                        ),
                        class = trimws(paste("vn-stream-pill", item$class, if (is_active) "is-active" else ""))
                    )
                })
            )

            stream_body <- if (!is.data.frame(stream_df) || nrow(stream_df) == 0L) {
                shiny::div(
                    class = "vn-stream-empty",
                    if (isTRUE(rv$running)) tr("validate_names_stream_waiting", lang_r()) else tr("validate_names_stream_empty", lang_r())
                )
            } else if (!is.data.frame(filtered_df) || nrow(filtered_df) == 0L) {
                shiny::div(class = "vn-stream-empty", tr("validate_names_stream_empty_filter", lang_r()))
            } else {
                shiny::div(
                    class = "vn-stream-list",
                    lapply(seq_len(nrow(filtered_df)), function(i) {
                        row <- filtered_df[i, , drop = FALSE]
                        style <- status_style_map(row$validation_status[[1]])
                        provider_label <- format_provider_labels(row$provider[[1]])
                        if (length(provider_label) == 0L) provider_label <- tr("validate_names_loading_provider_unknown", lang_r()) else provider_label <- provider_label[[1]]
                        updated_value <- row$updated_at[[1]]
                        updated_text <- if (inherits(updated_value, "POSIXct")) format(updated_value, "%H:%M:%S") else "--:--:--"
                        status_text <- tr(style$label_key, lang_r())

                        shiny::div(
                            class = trimws(paste("vn-stream-item", style$item_class)),
                            shiny::span(class = trimws(paste("vn-stream-status-icon", paste0("vn-stream-status-icon-", style$key))), style$icon_symbol),
                            shiny::div(
                                class = "vn-stream-item-main",
                                shiny::div(class = "vn-stream-item-name", row$query_name[[1]]),
                                shiny::div(
                                    class = "vn-stream-item-meta",
                                    shiny::span(status_text),
                                    shiny::span(class = "vn-dot"),
                                    shiny::span(provider_label),
                                    shiny::span(class = "vn-dot"),
                                    shiny::span(updated_text)
                                )
                            ),
                            shiny::span(class = trimws(paste("vn-status-badge", style$badge_class)), status_text)
                        )
                    })
                )
            }

            shiny::div(
                class = "vn-stream-panel",
                shiny::div(
                    class = "vn-stream-header",
                    shiny::div(class = "vn-stream-title", tr("validate_names_stream_panel_title", lang_r())),
                    pills_ui
                ),
                shiny::div(
                    class = "vn-stream-body",
                    stream_body
                )
            )
        })

        output$report_panel <- shiny::renderUI({
            report <- validation_result()
            has_report <- is.data.frame(report) && nrow(report) > 0L
            counts <- report_status_counts(report)

            shiny::div(
                class = "vn-report-panel",
                shiny::div(
                    class = "vn-report-statbar",
                    shiny::div(
                        class = "vn-report-statcell",
                        shiny::div(class = "vn-report-statvalue vn-report-statvalue-valid", as.integer(counts[["valid"]])),
                        shiny::div(class = "vn-report-statlabel", tr("validate_names_valid", lang_r()))
                    ),
                    shiny::div(
                        class = "vn-report-statcell",
                        shiny::div(class = "vn-report-statvalue vn-report-statvalue-invalid", as.integer(counts[["invalid"]])),
                        shiny::div(class = "vn-report-statlabel", tr("validate_names_invalid", lang_r()))
                    ),
                    shiny::div(
                        class = "vn-report-statcell",
                        shiny::div(class = "vn-report-statvalue vn-report-statvalue-unresolved", as.integer(counts[["unresolved"]])),
                        shiny::div(class = "vn-report-statlabel", tr("validate_names_unresolved", lang_r()))
                    )
                ),
                shiny::div(
                    class = "vn-report-header",
                    shiny::div(class = "vn-report-title", tr("validate_names_report_title", lang_r())),
                    shiny::div(
                        class = "vn-report-controls",
                        shiny::tags$input(
                            id = ns("report_search"),
                            type = "search",
                            class = "vn-report-search",
                            placeholder = tr("validate_names_report_search_placeholder", lang_r()),
                            autocomplete = "off",
                            spellcheck = "false"
                        ),
                        shiny::tags$select(
                            id = ns("report_page_length"),
                            class = "vn-report-select",
                            lapply(c(10L, 25L, 50L, 100L), function(size) {
                                if (identical(size, 10L)) {
                                    shiny::tags$option(value = size, selected = "selected", sprintf(tr("validate_names_report_show_n", lang_r()), size))
                                } else {
                                    shiny::tags$option(value = size, sprintf(tr("validate_names_report_show_n", lang_r()), size))
                                }
                            })
                        )
                    )
                ),
                shiny::div(
                    class = "vn-report-table-shell",
                    if (has_report) {
                        DT::dataTableOutput(ns("report_table"))
                    } else {
                        shiny::div(class = "vn-report-empty", tr("validate_names_report_empty", lang_r()))
                    }
                )
            )
        })

        output$report_table <- DT::renderDataTable({
            report <- validation_result()
            shiny::req(is.data.frame(report), nrow(report) > 0L)

            status_vec <- vapply(report$validation_status, normalize_status_for_filter, FUN.VALUE = character(1))
            scientific_name <- if ("scientificName" %in% names(report)) as.character(report$scientificName) else rep("", nrow(report))
            taxonomic_status <- if ("taxonomicStatus" %in% names(report)) as.character(report$taxonomicStatus) else rep("", nrow(report))

            table_df <- data.frame(
                scientificName = scientific_name,
                validation_status = status_vec,
                taxonomicStatus = taxonomic_status,
                stringsAsFactors = FALSE
            )

            colnames(table_df) <- c(
                tr("validate_names_table_col_scientific_name", lang_r()),
                tr("validate_names_table_col_status", lang_r()),
                tr("validate_names_table_col_taxonomic_status", lang_r())
            )

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
                        "  var status = String(data === null || data === undefined ? '' : data).toLowerCase();",
                        "  if (type !== 'display') return status;",
                        "  var labels = %s;",
                        "  var clsMap = {accepted:'badge-success', synonym:'badge-info', not_found:'badge-error', ambiguous:'badge-warning', ignored:'badge-muted'};",
                        "  var cls = clsMap[status] || 'badge-muted';",
                        "  var label = labels[status] || String(data || '');",
                        "  var escaped = $('<div/>').text(label).html();",
                        "  return '<span class=\"vn-status-badge ' + cls + '\">' + escaped + '</span>';",
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
                "  return '<span class=\"vn-cell-scientific\" title=\"' + escaped + '\">' + escaped + '</span>';",
                "}"
            )

            row_callback_js <- DT::JS(
                "function(row, data) {",
                "  var status = String(data[1] === null || data[1] === undefined ? '' : data[1]).toLowerCase();",
                "  var classes = ['vn-row-accepted','vn-row-synonym','vn-row-not-found','vn-row-ambiguous','vn-row-ignored'];",
                "  for (var i = 0; i < classes.length; i++) { $(row).removeClass(classes[i]); }",
                "  var classMap = {accepted:'vn-row-accepted', synonym:'vn-row-synonym', not_found:'vn-row-not-found', ambiguous:'vn-row-ambiguous', ignored:'vn-row-ignored'};",
                "  var cls = classMap[status];",
                "  if (cls) { $(row).addClass(cls); }",
                "}"
            )

            header_callback_js <- DT::JS(
                paste0(
                    "function(thead) {",
                    "  $(thead).find('th').each(function() {",
                    "    var $th = $(this);",
                    "    var label = $th.text();",
                    "    if ($th.find('.vn-th-content').length === 0) {",
                    "      $th.html(\"<span class='vn-th-content'><span class='vn-th-label'>\" + label + \"</span><span class='vn-th-sort'>&#8597;</span></span>\");",
                    "    }",
                    "  });",
                    "}"
                )
            )

            filter_callback_js <- DT::JS(
                sprintf(
                    paste0(
                        "var searchId = %s;",
                        "var pageId = %s;",
                        "var searchSelector = '#' + searchId;",
                        "var pageSelector = '#' + pageId;",
                        "var nsSafe = searchId.replace(/[^a-zA-Z0-9_-]/g, '');",
                        "var eventNs = '.vnReport.' + nsSafe;",
                        "var $doc = $(document);",
                        "$doc.off('input' + eventNs, searchSelector);",
                        "$doc.off('keyup' + eventNs, searchSelector);",
                        "$doc.off('search' + eventNs, searchSelector);",
                        "$doc.off('change' + eventNs, pageSelector);",
                        "$doc.on('input' + eventNs, searchSelector, function() {",
                        "  table.search(String(this.value || '')).draw(false);",
                        "});",
                        "$doc.on('keyup' + eventNs, searchSelector, function() {",
                        "  table.search(String(this.value || '')).draw(false);",
                        "});",
                        "$doc.on('search' + eventNs, searchSelector, function() {",
                        "  table.search(String(this.value || '')).draw(false);",
                        "});",
                        "$doc.on('change' + eventNs, pageSelector, function() {",
                        "  var len = parseInt(this.value, 10);",
                        "  if (!isNaN(len) && len > 0) {",
                        "    if (table.page.len() !== len) { table.page.len(len); }",
                        "    table.page('first').draw('page');",
                        "  }",
                        "});",
                        "var $search = $(searchSelector);",
                        "if ($search.length) { table.search(String($search.val() || '')).draw(false); }",
                        "var $page = $(pageSelector);",
                        "if ($page.length) {",
                        "  var selectedLen = parseInt($page.val(), 10);",
                        "  if (isNaN(selectedLen) || selectedLen <= 0) {",
                        "    selectedLen = table.page.len();",
                        "    $page.val(String(selectedLen));",
                        "  }",
                        "  table.page.len(selectedLen);",
                        "  table.page('first').draw('page');",
                        "}"
                    ),
                    jsonlite::toJSON(ns("report_search"), auto_unbox = TRUE),
                    jsonlite::toJSON(ns("report_page_length"), auto_unbox = TRUE)
                )
            )

            DT::datatable(
                table_df,
                options = list(
                    pageLength = 10,
                    lengthMenu = c(10, 25, 50, 100),
                    autoWidth = FALSE,
                    scrollX = TRUE,
                    dom = "t<'vn-report-pagination'ip>",
                    columnDefs = list(
                        list(targets = 0, render = scientific_name_js),
                        list(targets = 1, render = status_badge_js)
                    ),
                    rowCallback = row_callback_js,
                    headerCallback = header_callback_js,
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
                callback = filter_callback_js,
                class = "display compact validate-results-table vn-report-table",
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
