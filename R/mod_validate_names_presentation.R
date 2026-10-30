
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
            # Providers, options and the run button in one bar on top, as on
            # the Coordinates page (ADR-132).
            shiny::uiOutput(ns("config_panel")),
            shiny::div(
                class = "validate-names-workspace",
                shiny::uiOutput(ns("stream_panel")),
                shiny::uiOutput(ns("report_panel"))
            ),
            shiny::tags$script(module_behavior_html("namesBackdropCleanup"))
        )
    )
}

# mod_validate_names presentation. Views expose reactive reads; controllers own mutations.

mount_mod_validate_names_presentation <- function(
    active_stream_filter, br_provider_ids, can_run_validation, effective_report,
    exiting_query_keys, input, lang_r, ns,
    output, problem_status_values, provider_button_id, provider_catalog,
    provider_runtime_status_for, quick_inputs, reviewed_query_keys, sensitivity_entries_df,
    session, stream_window_limit, validation_meta, view,
    consume_report_fade
) {
    provider_runtime_badge <- function(status_obj) {
        key <- tolower(as.character(status_obj$status %||% "never_downloaded"))
        if (identical(key, "up_to_date")) {
            return(shiny::tags$span(class = "vn-status-badge badge-success", tr("validate_names_provider_status_up_to_date", lang_r())))
        }
        if (identical(key, "update_in_progress")) {
            return(shiny::tags$span(class = "vn-status-badge badge-info", tr("validate_names_provider_status_updating", lang_r())))
        }
        if (identical(key, "update_failed")) {
            return(shiny::tags$span(class = "vn-status-badge badge-warning", tr("validate_names_provider_status_update_failed", lang_r())))
        }
        shiny::tags$span(class = "vn-status-badge badge-muted", tr("validate_names_provider_status_not_downloaded", lang_r()))
    }

    output$config_panel <- shiny::renderUI({
        selected <- as.character(view$selected_providers())
        selected <- selected[!is.na(selected) & nzchar(selected)]
        is_busy <- isTRUE(view$running()) || isTRUE(view$starting())
        quick <- quick_inputs()
        # Deliberately does NOT read view$run_state() or validation_result().
        # The run loop rewrites view$run_state() every 60ms, and reactiveValues
        # invalidate on write whether or not the value changed -- so a
        # single read here, even one whose result is thrown away, rebuilds
        # this whole panel ~16 times a second during a run, recreating the
        # two option checkboxes below each time. The run card shows the
        # progress (ADR-160).
        run_label <- if (is_busy) tr("validate_names_run_running", lang_r()) else tr("validate_names_run_cta", lang_r())
        can_run <- isTRUE(can_run_validation())

        helper_text <- if (length(selected) == 0L) {
            tr("validate_names_providers_required", lang_r())
        } else if (!identical(quick$status, "ok")) {
            if (identical(quick$status, "missing_scientific")) {
                tr("validate_names_missing_scientific_name", lang_r())
            } else {
                ""
            }
        } else {
            ""
        }

        shiny::div(
            class = "vn-config-panel",
            shiny::div(
                class = "vn-config-section vn-config-section-providers",
                shiny::div(class = "vn-section-label", tr("validate_names_providers_card_title", lang_r())),
                shiny::div(
                    class = "vn-check-list",
                    lapply(provider_catalog, function(item) {
                        is_selected <- item$id %in% selected
                        is_locked <- isTRUE(item$locked)
                        step <- provider_query_step(item$id, selected, br_provider_ids)
                        status_ui <- if (identical(item$type, "br")) {
                            provider_runtime_badge(provider_runtime_status_for(item$id))
                        } else if (is_locked) {
                            shiny::tags$span(class = "vn-status-badge badge-muted", tr("validate_names_provider_always_on", lang_r()))
                        }
                        content <- shiny::div(
                            class = "vn-check-row-content",
                            shiny::span(class = "vn-check-step", if (is.na(step)) "" else step),
                            shiny::span(class = "vn-check-box", `aria-hidden` = "true"),
                            shiny::div(
                                class = "vn-check-text",
                                shiny::div(
                                    class = "vn-check-head",
                                    shiny::span(class = "vn-check-name", item$short),
                                    status_ui
                                )
                            )
                        )
                        row_class <- trimws(paste(
                            "vn-check-row vn-provider-row",
                            if (is_selected) "is-selected" else "",
                            if (is_locked) "is-locked" else "",
                            if (is_busy) "is-disabled" else ""
                        ))
                        if (is_locked) {
                            shiny::div(class = row_class, content)
                        } else {
                            shiny::actionButton(
                                inputId = ns(provider_button_id(item$id)),
                                icon = NULL,
                                label = content,
                                class = row_class,
                                `aria-pressed` = if (is_selected) "true" else "false",
                                disabled = is_busy
                            )
                        }
                    })
                ),
                {
                    in_progress <- br_provider_ids[vapply(
                        br_provider_ids,
                        function(id) {
                            status_obj <- provider_runtime_status_for(id)
                            identical(as.character(status_obj$status %||% ""), "update_in_progress")
                        },
                        FUN.VALUE = logical(1)
                    )]
                    if (length(in_progress) > 0L) {
                        label <- format_provider_labels(in_progress)
                        label <- label[!is.na(label) & nzchar(label)]
                        shiny::div(
                            class = "vn-provider-note",
                            shiny::span(class = "vn-note-icon", shiny::HTML("&#8635;")),
                            paste0("Background update in progress: ", paste(label, collapse = ", "))
                        )
                    }
                }
            ),
            shiny::div(
                class = "vn-config-section vn-config-section-options",
                shiny::div(class = "vn-section-label", tr("validate_names_options_card_title", lang_r())),
                shiny::div(
                    class = "vn-check-list",
                    # isolate() on both reads: this renderUI RECREATES these
                    # checkboxes, so an un-isolated read makes each click
                    # rebuild the widget that produced it. The value is still
                    # carried across a legitimate re-render (a language
                    # switch) because it is read back here -- it just no
                    # longer invalidates the panel. Checked against the
                    # ADR-111 trap before isolating: no observer needs to
                    # re-run in the same flush as this recreation, because
                    # nothing syncs these two inputs into rv -- they are read
                    # directly by report_df and review_export_payload.
                    shiny::div(
                        class = "vn-check-row vn-option-row",
                        shiny::checkboxInput(
                            ns("remove_authors"),
                            tr("validate_names_remove_authors", lang_r()),
                            value = isTRUE(shiny::isolate(input$remove_authors) %||% TRUE)
                        )
                    ),
                    shiny::div(
                        class = "vn-check-row vn-option-row",
                        shiny::checkboxInput(
                            ns("ignore_qualifiers"),
                            tr("validate_names_ignore_qualifiers", lang_r()),
                            value = isTRUE(shiny::isolate(input$ignore_qualifiers) %||% TRUE)
                        )
                    )
                )
            ),
            shiny::div(
                class = "vn-config-section vn-config-section-action",
                # Empty label line: the button lines up with the provider
                # rows, and the helper text goes under it.
                shiny::div(class = "vn-section-label", `aria-hidden` = "true", shiny::HTML("&nbsp;")),
                shiny::actionButton(
                    inputId = ns("validate"),
                    label = run_label,
                    icon = if (is_busy) ph_icon("spinner", class = "ph-spin") else ph_icon("play"),
                    class = "vn-run-btn",
                    disabled = !can_run
                ),
                if (nzchar(helper_text)) shiny::div(class = "vn-action-helper", helper_text)
            )
        )
    })

    stream_item_ui <- function(row, review_keys, exiting_keys, lang) {
        style <- status_style_map(row$validation_status[[1]])
        provider_label <- format_provider_labels(row$provider[[1]])
        if (length(provider_label) == 0L) provider_label <- tr("validate_names_loading_provider_unknown", lang) else provider_label <- provider_label[[1]]
        updated_value <- row$updated_at[[1]]
        updated_text <- if (inherits(updated_value, "POSIXct")) format(updated_value, "%H:%M:%S") else "--:--:--"
        status_text <- tr(style$label_key, lang)
        query_name <- as.character(row$query_name[[1]] %||% "")
        status_key <- normalize_status_for_filter(row$validation_status[[1]])
        is_problem_unreviewed <- status_key %in% problem_status_values && !(query_name %in% review_keys)
        is_exiting <- query_name %in% exiting_keys
        shiny::div(
            class = trimws(paste("vn-stream-item", style$item_class, if (isTRUE(is_exiting)) "vn-review-item-exit" else "")),
            `data-key` = query_name,
            shiny::span(class = trimws(paste("vn-stream-status-icon", paste0("vn-stream-status-icon-", style$key))), ph_icon(style$icon)),
            shiny::div(
                class = "vn-stream-item-main",
                shiny::div(class = "vn-stream-item-name", row$query_name[[1]]),
                invasive_stream_note_ui(query_name, lang),
                shiny::div(
                    class = "vn-stream-item-meta",
                    shiny::span(provider_label),
                    shiny::span(class = "vn-dot"),
                    shiny::span(updated_text)
                )
            ),
            shiny::div(
                class = "vn-stream-item-actions",
                if (isTRUE(is_problem_unreviewed) && !isTRUE(is_exiting)) {
                    shiny::tags$button(
                        type = "button",
                        class = "btn btn-secondary vn-review-trigger",
                        onclick = sprintf(
                            "Shiny.setInputValue('%s', %s, {priority: 'event'});",
                            ns("open_review_target"),
                            jsonlite::toJSON(query_name, auto_unbox = TRUE)
                        ),
                        ph_icon("pencil-simple"),
                        tr("validate_names_review_action", lang)
                    )
                },
                shiny::span(class = trimws(paste("vn-status-badge", style$badge_class)), status_text)
            )
        )
    }

    stream_view <- function() {
        review_keys <- reviewed_query_keys()
        exiting_keys <- exiting_query_keys()
        active_filter <- active_stream_filter()
        running <- isTRUE(view$running())
        meta <- if (running) NULL else validation_meta()
        unchecked <- as.character(meta$unchecked %||% character(0))
        settled_df <- vn_drop_unchecked(view$stream_df(), unchecked)
        stream_df <- stream_window(
            settled_df,
            limit = if (running) stream_window_limit else NULL
        )
        list(
            stream_df = stream_df,
            counts = stream_filter_counts(settled_df, reviewed_keys = review_keys),
            meta = meta,
            unchecked = unchecked,
            active_filter = active_filter,
            review_keys = review_keys,
            exiting_keys = exiting_keys,
            filtered_df = filter_stream_df(
                stream_df,
                active_filter,
                reviewed_keys = review_keys,
                exiting_keys = exiting_keys
            )
        )
    }

    output$stream_panel <- shiny::renderUI({
        # During a run the panel renders once per filter, and vnStreamSync
        # changes its rows and counts in place. A render per batch reset
        # the scroll and the focus of the list (DEP-07).
        running <- isTRUE(view$running())
        view <- if (running) {
            active_stream_filter()
            shiny::isolate(stream_view())
        } else {
            stream_view()
        }
        stream_df <- view$stream_df
        review_keys <- view$review_keys
        exiting_keys <- view$exiting_keys
        counts <- view$counts
        active_filter <- view$active_filter
        filtered_df <- view$filtered_df

        pill_defs <- list(
            list(key = "all", class = "pill-all", label_key = "validate_names_stream_filter_all"),
            list(key = "problems", class = "pill-problems", label_key = "validate_names_stream_filter_problems"),
            list(key = "not_found", class = "pill-error", label_key = "validate_names_stream_filter_not_found"),
            list(key = "ambiguous", class = "pill-warning", label_key = "validate_names_stream_filter_ambiguous"),
            list(key = "synonym", class = "pill-info", label_key = "validate_names_stream_filter_synonym"),
            list(key = "accepted", class = "pill-success", label_key = "validate_names_stream_filter_accepted"),
            list(key = "invasive", class = "pill-invasive", label_key = "validate_names_stream_filter_invasive"),
            list(key = "translocated", class = "pill-translocated", label_key = "validate_names_stream_filter_translocated")
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
                        shiny::tags$span(class = "vn-pill-label", tr(item$label_key, lang_r())),
                        shiny::tags$span(class = "vn-pill-count", count_value)
                    ),
                    class = trimws(paste("vn-stream-pill", item$class, if (is_active) "is-active" else ""))
                )
            })
        )

        unresolved_count <- suppressWarnings(as.integer(counts[["problems"]]))
        if (is.na(unresolved_count) || unresolved_count < 0L) unresolved_count <- 0L
        # The celebration answers the "problems" filter only. Any other
        # filter (invasive, translocated, accepted) asks to see names.
        # During a run more names can come, so it waits for the end.
        all_resolved <- !running && identical(active_filter, "problems") &&
            isTRUE(unresolved_count == 0L) && is.data.frame(stream_df) && nrow(stream_df) > 0L &&
            length(view$unchecked) == 0L
        unchecked_ui <- vn_unchecked_block_ui(view$unchecked, view$meta, ns("retry_unchecked"), lang_r())

        no_rows <- !is.data.frame(stream_df) || nrow(stream_df) == 0L
        stream_body <- if (no_rows && !is.null(unchecked_ui)) {
            NULL
        } else if (no_rows) {
            shiny::div(
                class = "vn-stream-empty",
                if (running) tr("validate_names_stream_waiting", lang_r()) else tr("validate_names_stream_empty", lang_r())
            )
        } else if (isTRUE(all_resolved)) {
            shiny::div(
                class = "vn-review-empty-state",
                shiny::div(class = "vn-review-empty-icon", ph_icon("party-horn")),
                shiny::div(class = "vn-review-empty-title", tr("validate_names_review_empty_title", lang_r())),
                shiny::div(class = "vn-review-empty-message", tr("validate_names_review_empty_message", lang_r())),
                shiny::actionButton(
                    ns("go_preview_export"),
                    label = tr("validate_names_review_empty_export", lang_r()),
                    class = "btn btn-primary vn-review-empty-export"
                )
            )
        } else if (!is.data.frame(filtered_df) || nrow(filtered_df) == 0L) {
            shiny::div(class = "vn-stream-empty", tr("validate_names_stream_empty_filter", lang_r()))
        } else {
            shiny::div(
                class = "vn-stream-list",
                lapply(seq_len(nrow(filtered_df)), function(i) {
                    stream_item_ui(filtered_df[i, , drop = FALSE], review_keys, exiting_keys, lang_r())
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
                unchecked_ui,
                stream_body
            )
        )
    })

    output$report_panel <- shiny::renderUI({
        # During a run the panel shows the name grid and the progress.
        # view$running() changes only at the start and the end of a run, and
        # the run state is read under isolate(): vnRunProgress updates
        # the card in place.
        if (isTRUE(view$running())) {
            progress <- vn_run_progress(shiny::isolate(view$run_state()), lang_r())
            return(vn_run_card_ui(progress, lang_r()))
        }

        report <- effective_report()
        has_report <- is.data.frame(report) && nrow(report) > 0L
        # The report fades in once, when a run ends.
        fade <- isTRUE(consume_report_fade())

        shiny::div(
            class = paste("vn-report-panel", if (fade) "is-entering" else ""),
            if (has_report) conservation_status_summary_ui(report, as.character(view$selected_providers()), br_provider_ids, lang_r()),
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
        report <- effective_report()
        shiny::req(is.data.frame(report), nrow(report) > 0L)

        status_vec <- if ("display_status" %in% names(report)) {
            as.character(report$display_status)
        } else {
            normalize_status_vec(report$validation_status)
        }
        # No provider could check these names: "not found" is not known.
        unchecked <- as.character(validation_meta()$unchecked %||% character(0))
        if (length(unchecked) > 0L && "query_name" %in% names(report)) {
            status_vec[status_vec == "not_found" & report$query_name %in% unchecked] <- "unchecked"
        }
        scientific_name <-if ("scientificName_display" %in% names(report)) as.character(report$scientificName_display) else if ("scientificName" %in% names(report)) as.character(report$scientificName) else rep("", nrow(report))
        taxonomic_status <- if ("taxonomicStatus" %in% names(report)) as.character(report$taxonomicStatus) else rep("", nrow(report))
        review_original_name <- if ("review_original_name" %in% names(report)) as.character(report$review_original_name) else rep("", nrow(report))
        sensitive_source <- if ("scientificName" %in% names(report)) as.character(report$scientificName) else scientific_name
        # Resolve over unique names only -- per-row normalisation is O(n)
        # per render; mapping back by index keeps the same result in
        # O(unique names).
        u_sens <- unique(sensitive_source)
        du <- sensitive_resolve(u_sens, sensitivity_entries_df())
        sens_idx <- match(sensitive_source, u_sens)
        # Pill shows MMA category as a visual hint when present; researcher
        # overrides for non-MMA species fall back to an em-dash so the
        # downstream JS template ("Sensible \u00b7 {cat}") stays clean.
        cat_for_pill <- du$category[sens_idx]
        cat_for_pill[is.na(cat_for_pill) | !nzchar(cat_for_pill)] <- "\u2014"
        is_sensitive_vec <- ifelse(du$sensitive[sens_idx], cat_for_pill, "")
        # Invasive species (Instituto Horus). The cell carries the
        # origin_class, not a boolean, so the badge can say "alien
        # invasive" only where the list actually asserts it.
        # invasive_info_for() dedupes internally, so the same unique-name
        # economy applies.
        is_invasive_vec <- invasive_origin_class_for(sensitive_source)
        is_invasive_vec[is.na(is_invasive_vec)] <- ""
        # Natural range and introduction reason, resolved over unique names
        # like everything else in this cell and joined with a newline the
        # renderer splits. Empty for taxa the source leaves blank.
        u_inv <- unique(sensitive_source)
        u_detail <- vapply(
            u_inv,
            function(nm) paste(invasive_detail_lines(nm, lang_r()), collapse = "\n"),
            FUN.VALUE = character(1),
            USE.NAMES = FALSE
        )
        invasive_reason_vec <- u_detail[match(sensitive_source, u_inv)]

        table_df <- data.frame(
            scientificName = scientific_name,
            validation_status = status_vec,
            taxonomicStatus = taxonomic_status,
            review_original_name = review_original_name,
            is_sensitive = is_sensitive_vec,
            sensitive_name = sensitive_source,
            is_invasive = is_invasive_vec,
            invasive_reason = invasive_reason_vec,
            stringsAsFactors = FALSE
        )

        status_labels <- list(
            accepted = tr("validate_names_status_badge_accepted", lang_r()),
            accepted_manual = tr("validate_names_status_badge_accepted", lang_r()),
            manual_revision = tr("validate_names_status_badge_manual_revision", lang_r()),
            synonym = tr("validate_names_status_badge_synonym", lang_r()),
            not_found = tr("validate_names_status_badge_not_found", lang_r()),
            unchecked = tr("validate_names_status_badge_unchecked", lang_r()),
            ambiguous = tr("validate_names_status_badge_ambiguous", lang_r()),
            ignored = tr("validate_names_status_badge_ignored", lang_r())
        )

        status_badge_js <- DT::JS(module_behavior_call("namesStatusBadge", list(labels = status_labels)))
        scientific_name_js <- DT::JS(module_behavior_call("namesScientificCell", list(
            replacedPrefix = tr("validate_names_review_replaced_prefix", lang_r()),
            sensitiveLabel = tr("validate_names_status_badge_sensitive", lang_r()),
            sensitiveMark = tr("sensitive_mark_label", lang_r()),
            invasiveLabel = tr("validate_names_status_badge_invasive", lang_r()),
            translocatedLabel = tr("validate_names_status_badge_translocated", lang_r()),
            invasiveTip = tr("validate_names_invasive_tooltip", lang_r()),
            translocatedTip = tr("validate_names_translocated_tooltip", lang_r())
        )))
        taxonomic_status_js <- DT::JS(module_behavior_call("namesTaxonomicCell"))
        row_callback_js <- DT::JS(module_behavior_call("namesRowClass"))
        header_callback_js <- DT::JS(module_behavior_call("namesTableHeader"))
        filter_callback_js <- DT::JS(module_behavior_call("namesTableFilters", list(
            searchId = ns("report_search"),
            pageId = ns("report_page_length"),
            sensitivityId = ns("open_sensitivity_target")
        ), table_context = TRUE))

        DT::datatable(
            table_df,
            # Translated headers only: the data keeps its column names, so a
            # server-side request sent before a language change still finds
            # its columns (DT alerts "column name not found" otherwise).
            colnames = c(
                tr("validate_names_table_col_scientific_name", lang_r()),
                tr("validate_names_table_col_status", lang_r()),
                tr("validate_names_table_col_taxonomic_status", lang_r()),
                ".review_original_name",
                ".is_sensitive",
                ".sensitive_name",
                ".is_invasive",
                ".invasive_reason"
            ),
            options = list(
                pageLength = 10,
                lengthMenu = c(10, 25, 50, 100),
                autoWidth = FALSE,
                dom = "t<'vn-report-pagination'ip>",
                columnDefs = list(
                    list(targets = 0, render = scientific_name_js, className = "vn-col-scientific", width = "56%"),
                    list(targets = 1, render = status_badge_js, className = "vn-col-status", width = "16%"),
                    list(targets = 2, render = taxonomic_status_js, className = "vn-col-taxonomic", width = "28%"),
                    list(targets = 3, visible = FALSE, searchable = FALSE),
                    list(targets = 4, visible = FALSE, searchable = FALSE),
                    list(targets = 5, visible = FALSE, searchable = FALSE),
                    list(targets = 6, visible = FALSE, searchable = FALSE),
                    list(targets = 7, visible = FALSE, searchable = FALSE)
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

    list(stream_item_ui = stream_item_ui, stream_view = stream_view, provider_runtime_badge = provider_runtime_badge)
}

#' Block of the names a run left unchecked
#'
#' The block stands above the answer list. Its button queries these names
#' again (ADR-169).
#' @param unchecked Character vector of unchecked query names.
#' @param meta The \code{meta} list of \code{finalize_taxadb_run()}.
#' @param retry_id Input id of the retry button.
#' @param lang Language code.
#' @param chip_limit Most names to show. A last chip counts the others.
#' @return A \code{div} tag, or NULL when every name was checked.
#' @noRd
vn_unchecked_block_ui <- function(unchecked, meta, retry_id, lang = "pt", chip_limit = 12L) {
    n <- length(unchecked)
    if (n == 0L) {
        return(NULL)
    }
    suffix <- if (n == 1L) "_one" else "_other"
    shown <- utils::head(unchecked, chip_limit)
    more <- n - length(shown)
    note <- paste(
        c(vn_provider_failure_message(meta, lang), tr(paste0("validate_names_unchecked_note", suffix), lang)),
        collapse = " "
    )
    shiny::div(
        class = "vn-unchecked-block",
        shiny::div(
            class = "vn-unchecked-head",
            shiny::span(class = "vn-stream-status-icon vn-stream-status-icon-unchecked", ph_icon("cloud-slash")),
            shiny::div(
                class = "vn-unchecked-text",
                shiny::span(
                    class = "vn-unchecked-title",
                    sprintf(tr(paste0("validate_names_unchecked_title", suffix), lang), format_count(n, lang))
                ),
                shiny::span(class = "vn-unchecked-note", note)
            ),
            shiny::actionButton(
                inputId = retry_id,
                label = tr("validate_names_unchecked_retry", lang),
                icon = ph_icon("arrow-clockwise"),
                class = "btn-secondary vn-review-trigger"
            )
        ),
        shiny::div(
            class = "vn-unchecked-chips",
            lapply(shown, function(name) shiny::span(class = "vn-unchecked-chip", name)),
            if (more > 0L) shiny::span(class = "vn-unchecked-chip is-more", paste0("+", format_count(more, lang)))
        )
    )
}

#' Run card of a names run
#'
#' The report panel renders this card once, at the start of a run.
#' vnRunProgress (run-progress.js) then writes the text and draws the grid
#' in place.
#' @param progress List from \code{vn_run_progress()}.
#' @param lang Language code.
#' @return A \code{div} tag.
#' @noRd
vn_run_card_ui <- function(progress, lang = "pt") {
    legend <- c(
        a = "validate_names_run_legend_accepted",
        s = "validate_names_run_legend_synonym",
        m = "validate_names_run_legend_ambiguous",
        n = "validate_names_run_legend_not_found"
    )
    shiny::div(
        class = "vn-report-panel vn-run-card",
        shiny::div(
            class = "vn-run-grid",
            `data-run` = progress$run_id,
            `data-cells` = progress$cells,
            `data-per` = tr("validate_names_run_grid_per", lang),
            shiny::div(class = "vn-run-grid-area", shiny::tags$canvas(`aria-hidden` = "true")),
            shiny::div(
                class = "vn-run-legend",
                lapply(names(legend), function(code) {
                    shiny::span(
                        class = "vn-run-legend-item",
                        `data-code` = code,
                        shiny::span(class = paste0("vn-run-legend-dot is-", code), `aria-hidden` = "true"),
                        tr(legend[[code]], lang),
                        shiny::tags$b(progress$tally[[code]] %||% "0")
                    )
                }),
                shiny::span(class = "vn-run-grid-per")
            )
        ),
        shiny::div(
            class = "vn-run-body",
            `aria-live` = "polite",
            shiny::div(class = "vn-run-eyebrow", progress$eyebrow),
            shiny::p(class = "vn-run-count", progress$count),
            shiny::div(
                class = paste("vn-run-bar", if (isTRUE(progress$waiting)) "is-waiting" else ""),
                shiny::div(class = "vn-run-bar-fill", style = paste0("width: ", progress$pct, "%;"))
            ),
            shiny::div(
                class = "vn-run-steps",
                lapply(progress$steps, function(step) {
                    shiny::div(
                        class = paste0("vn-run-step is-", step$state),
                        `data-step` = step$key,
                        shiny::span(class = "vn-run-step-dot", `aria-hidden` = "true"),
                        shiny::span(class = "vn-run-step-label", step$label),
                        shiny::span(class = "vn-run-step-state", step$state_label)
                    )
                })
            )
        )
    )
}

#' Invasive-list note for one processed-names row
#'
#' The same badge vocabulary the report table uses, so the two screens never
#' disagree about what the list says. The natural range and the Horus "motivo
#' da introducao" ride below it when the source records them.
#'
#' @param query_name Character scalar. The name as the user supplied it.
#' @param lang Language code.
#' @return A Shiny tag, or NULL when the name is not on the list.
#' @noRd
invasive_stream_note_ui <- function(query_name, lang) {
    origin_class <- invasive_origin_class_for(query_name)[[1]]
    if (is.na(origin_class)) {
        return(NULL)
    }
    alien <- identical(origin_class, "alien")
    detail_lines <- invasive_detail_lines(query_name, lang)
    shiny::div(
        class = "vn-stream-item-invasive",
        shiny::span(
            class = paste(
                "vn-status-badge",
                if (alien) "badge-invasive" else "badge-translocated"
            ),
            title = tr(
                if (alien) {
                    "validate_names_invasive_tooltip"
                } else {
                    "validate_names_translocated_tooltip"
                },
                lang
            ),
            tr(
                if (alien) {
                    "validate_names_status_badge_invasive"
                } else {
                    "validate_names_status_badge_translocated"
                },
                lang
            )
        ),
        lapply(detail_lines, function(line) {
            shiny::span(class = "vn-stream-item-invasive-reason", line)
        })
    )
}

#' Render scientific name with italic emphasis
#' @param value Scientific name string
#' @return Shiny HTML object
#' @noRd
render_review_name_em <- function(value) {
    shiny::HTML(sprintf("<em>%s</em>", htmltools::htmlEscape(as.character(value %||% ""))))
}

#' Summary of conservation status that export will add to dynamicProperties
#'
#' Shown above the validation report. MMA is an exact local count of records on
#' the national threatened list; IUCN is the number of resolved records GBIF
#' will be queried for on export (some may have no assessment). Returns NULL when
#' no source applies or there is nothing to count, so it drops out of the layout.
#'
#' @param report Validation report data frame (needs `scientificName`).
#' @param selected Character vector of selected provider IDs.
#' @param br_provider_ids Character vector of Brazilian provider IDs.
#' @param lang Active language code.
#' @return A Shiny tag or NULL.
#' @noRd
conservation_status_summary_ui <- function(report, selected, br_provider_ids, lang) {
    include_mma <- length(intersect(selected, br_provider_ids)) > 0L
    include_iucn <- "gbif" %in% selected
    name_col <- if (is.data.frame(report) && "scientificName" %in% names(report)) {
        as.character(report$scientificName)
    } else {
        character(0)
    }
    # The invasive count comes from a bundled list and is provider-independent,
    # so it is reported even when neither conservation provider is selected.
    if (length(name_col) == 0L) {
        return(NULL)
    }

    # Each fact is a label and its count, like the stream filter pills. The
    # full sentence stays in the tooltip.
    fact_tag <- function(n, label_key, sentence_key, kind, icon) {
        shiny::tags$span(
            class = paste("vn-conservation-tag", kind),
            title = sprintf(tr(sentence_key, lang), n),
            shiny::tags$span(class = "vn-conservation-tag-label", ph_icon(icon), tr(label_key, lang)),
            shiny::tags$span(class = "vn-conservation-tag-count", n)
        )
    }

    lines <- list()
    if (include_mma) {
        mma_n <- sum(!is.na(sensitive_category_for(name_col)))
        if (mma_n > 0L) {
            lines[[length(lines) + 1L]] <- fact_tag(
                mma_n, "validate_names_conservation_label_mma",
                "validate_names_conservation_summary_mma", "is-mma", "shield-warning"
            )
        }
    }
    if (include_iucn) {
        iucn_n <- sum(!is.na(name_col) & nzchar(trimws(name_col)))
        if (iucn_n > 0L) {
            lines[[length(lines) + 1L]] <- fact_tag(
                iucn_n, "validate_names_conservation_label_iucn",
                "validate_names_conservation_summary_iucn", "is-iucn", "globe-hemisphere-west"
            )
        }
    }
    # Counted apart: the list asserts "alien to Brazil" for one group and only
    # "invasive outside its natural range" for the other, so a single total
    # would overstate the first.
    origin_class <- invasive_origin_class_for(name_col)
    alien_n <- sum(!is.na(origin_class) & origin_class == "alien")
    if (alien_n > 0L) {
        lines[[length(lines) + 1L]] <- fact_tag(
            alien_n, "validate_names_conservation_label_invasive",
            "validate_names_conservation_summary_invasive", "is-invasive", "arrow-square-in"
        )
    }
    translocated_n <- sum(!is.na(origin_class) & origin_class == "translocated_native")
    if (translocated_n > 0L) {
        lines[[length(lines) + 1L]] <- fact_tag(
            translocated_n, "validate_names_conservation_label_translocated",
            "validate_names_conservation_summary_translocated", "is-translocated", "arrows-left-right"
        )
    }
    if (length(lines) == 0L) {
        return(NULL)
    }
    shiny::div(class = "vn-conservation-summary", lines)
}

show_names_review_modal <- function(mode, target, ns, lang_r) {
    if (is.null(target) || !is.list(target) || !nzchar(as.character(target$query_name %||% ""))) {
        return(invisible(NULL))
    }
    ctx <- review_status_context(target$status_key %||% "not_found", lang_r())

    lifecycle_script <- module_behavior_call("namesReviewModal", list(rootId = ns("review_modal_root")))

    if (identical(mode, "edit")) {
        input_id <- ns("review_corrected_name")
        save_id <- ns("review_save_correction")
        edit_script <- module_behavior_call("namesReviewEdit", list(
            inputId = input_id, saveId = save_id,
            original = as.character(target$scientific_name %||% "")
        ))
        # A BR provider suggestion fills the field. The hint keeps the typed name.
        suggested <- as.character(target$suggested_name %||% NA_character_)
        prefill <- if (length(suggested) == 1L && !is.na(suggested) && nzchar(suggested)) {
            suggested
        } else {
            as.character(target$scientific_name %||% "")
        }

        shiny::showModal(shiny::modalDialog(
            shiny::div(
                id = ns("review_modal_root"),
                class = "vn-review-modal",
                shiny::div(
                    class = "vn-review-back-row",
                    shiny::actionButton(
                        ns("review_back_to_confirm"),
                        label = tr("validate_names_review_back", lang_r()),
                        icon = ph_icon("arrow-left"),
                        class = "btn btn-secondary vn-review-back-btn"
                    )
                ),
                shiny::div(class = "vn-review-edit-label", tr("validate_names_review_edit_label", lang_r())),
                shiny::tags$input(
                    id = ns("review_corrected_name"),
                    type = "text",
                    class = "vn-review-edit-input form-control",
                    value = prefill,
                    spellcheck = "false",
                    autocomplete = "off"
                ),
                shiny::div(
                    class = "vn-review-edit-hint",
                    render_review_name_em(target$scientific_name)
                ),
                shiny::tags$textarea(
                    id = ns("review_correction_reason"),
                    class = "vn-review-edit-textarea form-control",
                    placeholder = tr("validate_names_review_reason_placeholder", lang_r())
                ),
                shiny::div(
                    class = "vn-review-footer",
                    shiny::tags$button(
                        type = "button",
                        class = "btn vn-review-cancel-btn",
                        `data-bs-dismiss` = "modal",
                        tr("btn_cancel", lang_r())
                    ),
                    shiny::actionButton(
                        ns("review_save_correction"),
                        label = tr("validate_names_review_save_correction", lang_r()),
                        class = "btn btn-success vn-review-save-btn",
                        disabled = TRUE
                    )
                ),
                shiny::tags$script(shiny::HTML(edit_script)),
                shiny::tags$script(shiny::HTML(lifecycle_script))
            ),
            easyClose = TRUE,
            footer = NULL,
            fade = TRUE
        ))
        return(invisible(NULL))
    }

    confirm_script <- module_behavior_call("namesReviewConfirm", list(
        blockId = ns("review_confirm_block"), checkboxId = ns("review_confirm_checkbox"),
        confirmId = ns("review_confirm_keep")
    ))

    shiny::showModal(shiny::modalDialog(
        shiny::div(
            id = ns("review_modal_root"),
            class = "vn-review-modal",
            shiny::div(
                class = trimws(paste("vn-review-header", ctx$header_class)),
                shiny::div(
                    class = "vn-review-header-icon",
                    ph_icon(status_style_map(target$status_key)$icon)
                ),
                shiny::div(
                    class = "vn-review-header-text",
                    shiny::div(
                        class = "vn-review-header-name",
                        render_review_name_em(target$scientific_name)
                    ),
                    shiny::div(
                        class = "vn-review-header-problem",
                        ctx$problem_label
                    )
                )
            ),
            shiny::div(
                class = "vn-review-body",
                shiny::div(class = "vn-review-question", ctx$question),
                shiny::div(class = "vn-review-helper", ctx$helper),
                shiny::div(
                    id = ns("review_confirm_block"),
                    class = "vn-review-confirm-block",
                    shiny::tags$input(
                        id = ns("review_confirm_checkbox"),
                        type = "checkbox",
                        class = "vn-review-confirm-checkbox"
                    ),
                    shiny::div(
                        class = "vn-review-confirm-text",
                        shiny::div(class = "vn-review-confirm-title", tr("validate_names_review_confirm_title", lang_r())),
                        shiny::div(class = "vn-review-confirm-subtitle", tr("validate_names_review_confirm_subtitle", lang_r()))
                    )
                ),
                shiny::actionButton(
                    ns("review_switch_to_edit"),
                    label = tr("validate_names_review_switch_to_edit", lang_r()),
                    icon = ph_icon("pencil-simple"),
                    class = "btn btn-secondary vn-review-edit-btn"
                )
            ),
            shiny::div(
                class = "vn-review-footer",
                shiny::tags$button(
                    type = "button",
                    class = "btn vn-review-cancel-btn",
                    `data-bs-dismiss` = "modal",
                    tr("btn_cancel", lang_r())
                ),
                shiny::actionButton(
                    ns("review_confirm_keep"),
                    label = tr("validate_names_review_confirm_btn", lang_r()),
                    class = "btn btn-success vn-review-confirm-btn",
                    disabled = TRUE
                )
            ),
            shiny::tags$script(shiny::HTML(confirm_script)),
            shiny::tags$script(shiny::HTML(lifecycle_script))
        ),
        easyClose = TRUE,
        footer = NULL,
        fade = TRUE
    ))
    invisible(NULL)
}
