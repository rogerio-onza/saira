# Title: Preview Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-15
# Version: 1.4

#' Preview Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_preview_ui <- function(id) {
    ns <- shiny::NS(id)

    shiny::tagList(
        shiny::div(
            class = "container-fluid preview-page",
            shiny::uiOutput(ns("title")),
            shiny::uiOutput(ns("subtitle")),

            # Download button
            shiny::div(
                class = "mb-4",
                shiny::uiOutput(ns("download_btn_container"))
            ),

            # Sensitive-species masking control (ADR-092); shows only when
            # the dataset has sensitive records.
            shiny::uiOutput(ns("sensitive_panel")),

            # Data table
            shiny::uiOutput(ns("table_or_message"))
        )
    )
}

#' Preview Module Server
#'
#' @param id Module ID
#' @param mapped_data_r Reactive data frame with mapped data
#' @param lang_r Reactive language value
#' @param download_data_r Reactive data frame with full mapped data for download
#' @param name_review_payload_r Optional reactive payload from name manual review
#' @param sensitivity_payload_r Optional reactive data.frame of per-species
#'   sensitivity overrides (scientificName, sensitive) from the Validation >
#'   Names tab (ADR-092).
#' @param sensitive_overview_input_r Optional reactive returning a lightweight
#'   data.frame (`scientificName`, `decimalLatitude`, `decimalLongitude`)
#'   projected directly from raw_data + map_values. Used by the masking
#'   overview card so that the Preview tab does NOT pull the heavy
#'   `processed_data_r` reactive (ADR-020, LESSONS.md:31).
#' @param raw_data_r Optional reactive with the original uploaded data.frame
#'   (for ZIP bundle: appending non-mapped raw cols and the mapping_guide.txt).
#' @param map_values_r Optional reactive with the current mapping list
#'   (DwC term -> source column(s)). Required for the mapping_guide.txt.
#' @return Reactive preview data frame
#' @export
mod_preview_server <- function(id, mapped_data_r, lang_r,
                               download_data_r = mapped_data_r,
                               sensitive_overview_input_r = NULL,
                               name_review_payload_r = NULL,
                               sensitivity_payload_r = NULL,
                               raw_data_r = NULL,
                               map_values_r = NULL,
                               custom_values_r = NULL,
                               coords_correction_payload_r = NULL) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns
        required_download_fields <- c(
            "scientificName",
            "eventDate",
            "decimalLatitude",
            "decimalLongitude",
            "basisOfRecord"
        )
        warning_download_fields <- c("occurrenceID")
        download_click_channel <- paste0("preview-download-click-", ns("download_real"))
        download_finish_channel <- paste0("preview-download-finish-", ns("download_real"))
        is_exporting <- shiny::reactiveVal(FALSE)
        loading_phrase_specs <- list(
            list(key = "preview_export_phrase_1", icon = "seedling"),
            list(key = "preview_export_phrase_2", icon = "dna"),
            list(key = "preview_export_phrase_3", icon = "calendar-days"),
            list(key = "preview_export_phrase_4", icon = "earth-americas"),
            list(key = "preview_export_phrase_5", icon = "list-check"),
            list(key = "preview_export_phrase_6", icon = "flask"),
            list(key = "preview_export_phrase_7", icon = "box-archive"),
            list(key = "preview_export_phrase_8", icon = "shield-check"),
            list(key = "preview_export_phrase_9", icon = "file-csv"),
            list(key = "preview_export_phrase_10", icon = "download")
        )

        output$title <- shiny::renderUI({
            shiny::h3(tr("preview_title", lang_r()), class = "text-mono")
        })

        output$subtitle <- shiny::renderUI({
            shiny::p(tr("preview_subtitle", lang_r()), class = "text-accent")
        })

        output$download_btn_container <- shiny::renderUI({
            register_handlers_script <- sprintf(
                "(function () {
                    var clickChannel = %s;
                    var finishChannel = %s;
                    window.__sairaPreviewDownloadHandlers = window.__sairaPreviewDownloadHandlers || {};
                    if (window.__sairaPreviewDownloadHandlers[clickChannel]) {
                        return;
                    }
                    window.__sairaPreviewDownloadHandlers[clickChannel] = true;

                    Shiny.addCustomMessageHandler(clickChannel, function (payload) {
                        var btn = document.getElementById(payload.id);
                        if (btn) {
                            btn.click();
                        }
                    });

                    Shiny.addCustomMessageHandler(finishChannel, function (payload) {
                        var progressEl = payload.progress_id ? document.getElementById(payload.progress_id) : null;
                        var statusEl = payload.status_id ? document.getElementById(payload.status_id) : null;
                        var phraseIconEl = payload.phrase_icon_id ? document.getElementById(payload.phrase_icon_id) : null;
                        var phraseTextEl = payload.phrase_text_id ? document.getElementById(payload.phrase_text_id) : null;
                        var poolRoot = payload.modal_root_id ? document.getElementById(payload.modal_root_id) : null;
                        var modalEl = poolRoot ? poolRoot.closest('.modal') : null;
                        var timerKey = payload.timer_key || null;
                        var progressKey = timerKey ? (timerKey + '_progress') : null;

                        if (timerKey && window[timerKey]) {
                            window.clearInterval(window[timerKey]);
                            window[timerKey] = null;
                        }
                        if (progressKey && window[progressKey]) {
                            window.clearInterval(window[progressKey]);
                            window[progressKey] = null;
                        }

                        if (progressEl) {
                            progressEl.style.width = '100%%';
                        }
                        if (statusEl && payload.status_text) {
                            statusEl.textContent = payload.status_text;
                        }
                        if (phraseIconEl && payload.final_icon) {
                            phraseIconEl.className = 'fa-solid fa-' + payload.final_icon + ' automap-loading-phrase-icon';
                        }
                        if (phraseTextEl && payload.final_phrase) {
                            phraseTextEl.textContent = payload.final_phrase;
                        }

                        var closeModal = function () {
                            if (!modalEl) { return; }
                            if (window.bootstrap && window.bootstrap.Modal) {
                                var instance = window.bootstrap.Modal.getInstance(modalEl);
                                if (instance) {
                                    instance.hide();
                                } else if (window.jQuery) {
                                    window.jQuery(modalEl).modal('hide');
                                }
                            } else if (window.jQuery) {
                                window.jQuery(modalEl).modal('hide');
                            }
                        };

                        window.setTimeout(closeModal, payload.delay_ms || 320);
                    });
                })();",
                jsonlite::toJSON(download_click_channel, auto_unbox = TRUE),
                jsonlite::toJSON(download_finish_channel, auto_unbox = TRUE)
            )

            shiny::tagList(
                shiny::actionButton(
                    inputId = ns("download_trigger"),
                    label = shiny::tagList(
                        shiny::icon("download"),
                        " ",
                        tr("preview_download", lang_r())
                    ),
                    class = "btn btn-success action-button preview-download-btn",
                    disabled = if (isTRUE(is_exporting())) "disabled" else NULL
                ),
                shiny::div(
                    style = "display: none;",
                    shiny::downloadButton(
                        outputId = ns("download_real"),
                        label = tr("preview_download", lang_r()),
                        icon = NULL
                    )
                ),
                shiny::tags$script(shiny::HTML(register_handlers_script))
            )
        })

        preview_data <- shiny::reactive({
            shiny::req(mapped_data_r())
            prepare_preview_data(mapped_data_r(), max_rows = 100L)
        })

        download_data <- shiny::reactive({
            shiny::req(download_data_r())
            download_data_r()
        })

        export_name_review_payload <- shiny::reactive({
            if (is.null(name_review_payload_r) || !shiny::is.reactive(name_review_payload_r)) {
                return(NULL)
            }
            name_review_payload_r()
        })

        export_sensitivity_payload <- shiny::reactive({
            if (is.null(sensitivity_payload_r) ||
                !shiny::is.reactive(sensitivity_payload_r)) {
                return(NULL)
            }
            sensitivity_payload_r()
        })

        # Chapman 2020 generalization level (single global tier). Default
        # "not_sensitive": masking is a deliberate opt-in exception, never the
        # default, since generalized coordinates can mislead future analyses
        # and conservation policy. The researcher must choose to mask.
        sensitive_generalization_rv <- shiny::reactiveVal("not_sensitive")

        shiny::observeEvent(input$sensitive_generalization, {
            val <- as.character(input$sensitive_generalization)
            if (length(val) == 1L && val %in% sensitive_generalization_levels()) {
                sensitive_generalization_rv(val)
            }
        })

        # How many records would be masked. Resolved over UNIQUE names and
        # sourced from a lightweight (scientificName + coords) projection
        # of the raw data, so the Preview tab does NOT materialise the heavy
        # `processed_data_r` reactive (ADR-020, LESSONS.md:31).
        sensitive_overview <- shiny::reactive({
            df <- if (is.null(sensitive_overview_input_r) ||
                      !shiny::is.reactive(sensitive_overview_input_r)) {
                NULL
            } else {
                tryCatch(sensitive_overview_input_r(), error = function(e) NULL)
            }
            need <- c("scientificName", "decimalLatitude", "decimalLongitude")
            if (!is.data.frame(df) || nrow(df) == 0L ||
                !all(need %in% names(df))) {
                return(0L)
            }
            sci <- as.character(df$scientificName)
            keep <- !is.na(sci) & nzchar(sci)
            u <- unique(sci[keep])
            if (length(u) == 0L) {
                return(0L)
            }
            dec <- sensitive_resolve(u, export_sensitivity_payload())
            sens_names <- u[dec$sensitive]
            if (length(sens_names) == 0L) {
                return(0L)
            }
            lat <- suppressWarnings(as.numeric(df$decimalLatitude))
            lon <- suppressWarnings(as.numeric(df$decimalLongitude))
            sum(sci %in% sens_names & !is.na(lat) & !is.na(lon))
        })

        output$sensitive_panel <- shiny::renderUI({
            n <- sensitive_overview()
            if (is.null(n) || n == 0L) {
                return(NULL)
            }
            lang <- lang_r()
            current <- sensitive_generalization_rv()

            # `sensitive_generalization_levels()` returns the Chapman tiers in
            # order, with "not_sensitive" last. The CSS in 17-sensitive-panel.css
            # uses `.form-check:last-child` to demote the opt-out card, so the
            # order here must mirror that contract; do not reorder.
            levels <- sensitive_generalization_levels()
            active_levels <- setdiff(levels, "not_sensitive")

            fmt_grid_cell <- function(level) {
                g <- sensitive_generalization_grid(level)
                if (is.na(g)) {
                    return(tr("sensitive_grid_unmasked", lang))
                }
                km <- round(g * 111.32, 1)
                sprintf(
                    "%s\u00b0 (~%s km)",
                    format(g, trim = TRUE, scientific = FALSE),
                    format(km, trim = TRUE)
                )
            }

            # `warn` adds an in-card policy-impact alert; set for the
            # aggressive tiers (high/extreme) only while one is selected.
            card_label <- function(level, warn = FALSE) {
                g <- sensitive_generalization_grid(level)
                deg_txt <- sprintf(
                    "%s\u00b0",
                    format(g, trim = TRUE, scientific = FALSE)
                )
                km_txt <- sprintf(
                    "~%s km",
                    format(round(g * 111.32, 1), trim = TRUE)
                )
                shiny::HTML(as.character(shiny::tagList(
                    shiny::div(
                        class = "sp-card-num",
                        tr(paste0("sensitive_card_num_", level), lang)
                    ),
                    shiny::div(
                        class = "sp-card-name",
                        tr(paste0("sensitive_card_name_", level), lang)
                    ),
                    shiny::div(
                        class = "sp-card-precision",
                        shiny::span(class = "sp-card-deg", deg_txt),
                        shiny::span(class = "sp-card-km", km_txt)
                    ),
                    shiny::div(
                        class = "sp-card-impact",
                        tr(paste0("sensitive_card_impact_", level), lang)
                    ),
                    if (warn) {
                        shiny::div(
                            class = "sp-card-warning",
                            tr("sensitive_policy_warning", lang)
                        )
                    }
                )))
            }

            optout_label <- shiny::HTML(as.character(
                shiny::span(
                    class = "sp-optout-text",
                    tr("sensitive_card_optout", lang)
                )
            ))

            aggressive_levels <- c("high", "extreme")
            choice_names <- c(
                lapply(active_levels, function(lv) {
                    card_label(
                        lv,
                        warn = lv %in% aggressive_levels &&
                            identical(lv, current)
                    )
                }),
                list(optout_label)
            )
            choice_values <- c(active_levels, "not_sensitive")

            table_rows <- lapply(levels, function(level) {
                shiny::tags$tr(
                    shiny::tags$td(tr(paste0("sensitive_gen_", level), lang)),
                    shiny::tags$td(fmt_grid_cell(level))
                )
            })

            shiny::div(
                class = "sensitive-panel",
                shiny::div(
                    class = "sp-header",
                    shiny::h5(
                        class = "sp-title",
                        tr("sensitive_panel_title", lang)
                    ),
                    shiny::span(
                        class = "sp-count-chip",
                        sprintf(tr("sensitive_panel_records_chip", lang), n)
                    )
                ),
                shiny::p(
                    class = "sp-lead",
                    tr("sensitive_panel_lead", lang)
                ),
                shiny::div(
                    class = "alert alert-info",
                    tr("sensitive_panel_guidance", lang)
                ),
                shiny::div(
                    class = "sp-radio-wrap",
                    shiny::radioButtons(
                        ns("sensitive_generalization"),
                        label = NULL,
                        choiceNames = choice_names,
                        choiceValues = choice_values,
                        selected = current
                    )
                ),
                shiny::tags$details(
                    class = "sp-disclosure",
                    shiny::tags$summary(
                        class = "sp-disclosure-summary",
                        tr("sensitive_disclosure_title", lang)
                    ),
                    shiny::div(
                        class = "sp-disclosure-body",
                        shiny::tags$table(
                            class = "table table-sm sensitive-grid-table",
                            shiny::tags$caption(tr("sensitive_table_caption", lang)),
                            shiny::tags$thead(
                                shiny::tags$tr(
                                    shiny::tags$th(tr("sensitive_table_col_category", lang)),
                                    shiny::tags$th(tr("sensitive_table_col_grid", lang))
                                )
                            ),
                            shiny::tags$tbody(table_rows)
                        )
                    )
                )
            )
        })

        download_validation <- shiny::reactive({
            df <- mapped_data_r()
            if (is.null(df) || !is.data.frame(df) || ncol(df) == 0L || nrow(df) == 0L) {
                return(list(
                    ok = FALSE,
                    has_rows = FALSE,
                    blocking_missing = character(0),
                    warning_missing = character(0)
                ))
            }
            validate_preview_download_requirements(
                df,
                blocking_fields = required_download_fields,
                warning_fields = warning_download_fields
            )
        })

        show_download_validation_modal <- function(validation_result) {
            body_blocks <- list()

            if (!isTRUE(validation_result$has_rows)) {
                body_blocks[[length(body_blocks) + 1L]] <- shiny::p(
                    tr("preview_download_validation_no_data", lang_r())
                )
            }

            if (length(validation_result$blocking_missing) > 0L) {
                body_blocks[[length(body_blocks) + 1L]] <- shiny::div(
                    class = "preview-export-validation-card",
                    shiny::div(
                        class = "preview-export-validation-card-title",
                        tr("preview_download_validation_blocking", lang_r())
                    ),
                    shiny::tags$ul(
                        class = "preview-export-validation-list",
                        lapply(validation_result$blocking_missing, function(field) {
                            shiny::tags$li(shiny::tags$code(field))
                        })
                    )
                )
            }

            if (length(validation_result$warning_missing) > 0L) {
                body_blocks[[length(body_blocks) + 1L]] <- shiny::p(
                    class = "text-accent mb-0",
                    shiny::icon("info-circle"),
                    " ",
                    tr("preview_download_validation_warning", lang_r())
                )
            }

            shiny::showModal(shiny::modalDialog(
                title = tr("preview_download_validation_title", lang_r()),
                shiny::div(
                    class = "preview-export-validation-modal",
                    do.call(shiny::tagList, body_blocks)
                ),
                easyClose = TRUE,
                footer = shiny::modalButton(tr("close", lang_r()))
            ))
        }

        show_download_confirmation_modal <- function(validation_result) {
            shiny::showModal(shiny::modalDialog(
                title = tr("preview_download_confirm_title", lang_r()),
                shiny::div(
                    class = "preview-export-confirm-modal",
                    shiny::p(
                        class = "mb-3",
                        tr("preview_download_confirm_message", lang_r())
                    ),
                    shiny::p(
                        class = "preview-export-confirm-question mb-2",
                        shiny::strong(tr("preview_download_confirm_question", lang_r()))
                    ),
                    shiny::p(
                        class = "preview-export-confirm-warning mb-0",
                        shiny::icon("triangle-exclamation"),
                        " ",
                        tr("preview_download_confirm_warning", lang_r())
                    ),
                    if (length(validation_result$warning_missing) > 0L) {
                        shiny::p(
                            class = "text-accent mt-2 mb-0",
                            shiny::icon("info-circle"),
                            " ",
                            tr("preview_download_validation_warning", lang_r())
                        )
                    }
                ),
                easyClose = TRUE,
                footer = shiny::tagList(
                    shiny::modalButton(tr("preview_download_confirm_no", lang_r())),
                    shiny::actionButton(
                        ns("confirm_download_yes"),
                        tr("preview_download_confirm_yes", lang_r()),
                        class = "btn-success"
                    )
                )
            ))
        }

        show_preview_export_loading_modal <- function() {
            first_spec <- loading_phrase_specs[[1]]
            status_template <- tr("preview_export_loading_status", lang_r())
            status_prefix <- trimws(gsub("%s%%", "", status_template, fixed = TRUE))
            if (!nzchar(status_prefix)) {
                status_prefix <- tr("loading", lang_r())
            }
            rotate_script <- sprintf(
                "(function () {
                    var iconEl = document.getElementById('%s');
                    var textEl = document.getElementById('%s');
                    var poolRoot = document.getElementById('%s');
                    var progressEl = document.getElementById('%s');
                    var statusEl = document.getElementById('%s');
                    if (!iconEl || !textEl || !poolRoot || !progressEl || !statusEl) { return; }

                    var items = poolRoot.querySelectorAll('.automap-loading-phrase-item');
                    if (!items.length) { return; }

                    var timerKey = '%s';
                    var progressKey = timerKey + '_progress';
                    var modalEl = poolRoot.closest('.modal');
                    var progressValue = 0;
                    var statusPrefix = %s;

                    var applyProgress = function (value) {
                        var pct = Math.max(0, Math.min(100, Math.round(value)));
                        progressEl.style.width = pct + '%%';
                        statusEl.textContent = statusPrefix ? (statusPrefix + ' ' + pct + '%%') : (pct + '%%');
                    };

                    var applyPhrase = function (index) {
                        var item = items[index];
                        if (!item) { return; }
                        var nextIcon = item.getAttribute('data-icon') || 'gears';
                        iconEl.className = 'fa-solid fa-' + nextIcon + ' automap-loading-phrase-icon';
                        textEl.textContent = item.textContent || '';
                    };

                    if (window[timerKey]) {
                        window.clearInterval(window[timerKey]);
                        window[timerKey] = null;
                    }
                    if (window[progressKey]) {
                        window.clearInterval(window[progressKey]);
                        window[progressKey] = null;
                    }

                    applyPhrase(0);
                    applyProgress(0);

                    window[progressKey] = window.setInterval(function () {
                        if (progressValue < 90) {
                            progressValue += 10;
                            applyProgress(progressValue);
                            var phraseIdx = Math.min(items.length - 1, Math.max(0, Math.floor(progressValue / 10) - 1));
                            applyPhrase(phraseIdx);
                        }
                    }, 900);

                    if (modalEl) {
                        modalEl.classList.add('automap-loading-host');
                    }
                    if (document.body) {
                        document.body.classList.add('automap-loading-open');
                    }

                    var clearState = function () {
                        if (window[timerKey]) {
                            window.clearInterval(window[timerKey]);
                            window[timerKey] = null;
                        }
                        if (window[progressKey]) {
                            window.clearInterval(window[progressKey]);
                            window[progressKey] = null;
                        }
                        if (modalEl) {
                            modalEl.classList.remove('automap-loading-host');
                        }
                        if (document.body) {
                            document.body.classList.remove('automap-loading-open');
                        }
                    };

                    if (modalEl) {
                        modalEl.addEventListener('hidden.bs.modal', clearState, { once: true });
                    } else {
                        document.addEventListener('hidden.bs.modal', clearState, { once: true });
                    }
                })();",
                ns("preview_export_phrase_icon"),
                ns("preview_export_phrase_text"),
                ns("preview_export_phrase_pool"),
                ns("preview_export_progress_bar"),
                ns("preview_export_status_text"),
                ns("preview_export_phrase_timer"),
                jsonlite::toJSON(status_prefix, auto_unbox = TRUE)
            )

            shiny::showModal(shiny::modalDialog(
                shiny::div(
                    class = "automap-loading-modal preview-export-loading-modal",
                    shiny::div(
                        class = "automap-loading-brand-row",
                        shiny::icon("dove", class = "fa-solid automap-loading-brand-icon")
                    ),
                    shiny::div(
                        class = "automap-loading-title",
                        tr("preview_export_loading_title", lang_r())
                    ),
                    shiny::div(
                        class = "automap-loading-progress",
                        shiny::div(
                            id = ns("preview_export_progress_bar"),
                            class = "automap-loading-progress-bar",
                            style = "width: 0%;"
                        )
                    ),
                    shiny::div(
                        class = "automap-loading-status",
                        shiny::span(
                            id = ns("preview_export_status_text"),
                            sprintf(tr("preview_export_loading_status", lang_r()), 0)
                        )
                    ),
                    shiny::div(
                        class = "automap-loading-phrase",
                        shiny::div(
                            class = "automap-loading-phrase-row",
                            shiny::icon(
                                first_spec$icon,
                                id = ns("preview_export_phrase_icon"),
                                class = "fa-solid automap-loading-phrase-icon"
                            ),
                            shiny::span(
                                tr(first_spec$key, lang_r()),
                                id = ns("preview_export_phrase_text")
                            )
                        ),
                        shiny::div(
                            id = ns("preview_export_phrase_pool"),
                            style = "display: none;",
                            lapply(loading_phrase_specs, function(spec) {
                                shiny::span(
                                    class = "automap-loading-phrase-item",
                                    `data-icon` = spec$icon,
                                    tr(spec$key, lang_r())
                                )
                            })
                        ),
                        shiny::tags$script(shiny::HTML(rotate_script))
                    )
                ),
                easyClose = FALSE,
                footer = shiny::actionButton(
                    ns("export_modal_cancel"),
                    tr("preview_export_cancel", lang_r()),
                    class = "btn btn-outline-secondary"
                ),
                fade = TRUE
            ))
        }

        shiny::observeEvent(input$download_trigger, {
            if (isTRUE(is_exporting())) {
                return(invisible(NULL))
            }

            validation_result <- download_validation()
            if (!isTRUE(validation_result$ok)) {
                show_download_validation_modal(validation_result)
                return(invisible(NULL))
            }

            show_download_confirmation_modal(validation_result)
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$confirm_download_yes, {
            if (isTRUE(is_exporting())) {
                return(invisible(NULL))
            }

            shiny::removeModal()
            show_preview_export_loading_modal()
            is_exporting(TRUE)
            session$sendCustomMessage(
                download_click_channel,
                list(id = ns("download_real"))
            )
        }, ignoreInit = TRUE)

        # Manual escape from the loading modal. ADR-009 requires
        # easyClose = FALSE on the loading modal (no accidental dismiss).
        # This explicit Cancel button restores user control without
        # weakening that guarantee. The R-side download callback (if
        # already running) will still complete eventually; resetting
        # is_exporting here is safe because the finally block in
        # downloadHandler also sets it to FALSE (idempotent).
        shiny::observeEvent(input$export_modal_cancel, {
            shiny::removeModal()
            is_exporting(FALSE)
            shiny::showNotification(
                tr("preview_export_cancelled", lang_r()),
                type = "warning"
            )
        }, ignoreInit = TRUE)

        output$table_or_message <- shiny::renderUI({
            df <- mapped_data_r()
            if (is.null(df) || !is.data.frame(df) || ncol(df) == 0L || nrow(df) == 0L) {
                shiny::div(
                    class = "preview-empty-state",
                    shiny::icon("table", class = "fa-3x"),
                    shiny::h4(tr("preview_no_data_title", lang_r())),
                    shiny::p(tr("preview_no_data", lang_r()))
                )
            } else {
                shiny::div(
                    class = "preview-table-shell saira-table-shell",
                    DT::dataTableOutput(ns("datatable"))
                )
            }
        })

        output$datatable <- DT::renderDataTable({
            shiny::req(preview_data())

            preview_df <- preview_data()
            empty_mask <- vapply(
                preview_df,
                FUN = is_preview_empty_column,
                FUN.VALUE = logical(1)
            )
            empty_indices <- which(empty_mask) - 1L

            truncation_js <- DT::JS(
                "function(data, type, row, meta) {",
                "  if (data === null || data === undefined) { return data; }",
                "  var text = String(data);",
                "  if (type === 'display') {",
                "    var escaped = $('<div/>').text(text).html();",
                "    if (text.length > 80) {",
                "      return '<span title=\"' + escaped + '\">' + escaped.substr(0, 80) + '...</span>';",
                "    }",
                "    return escaped;",
                "  }",
                "  return data;",
                "}"
            )

            column_defs <- list(
                list(
                    targets = "_all",
                    render = truncation_js
                )
            )

            if (length(empty_indices) > 0L) {
                column_defs[[length(column_defs) + 1L]] <- list(
                    targets = as.integer(empty_indices),
                    className = "preview-col-empty"
                )
            }

            init_complete_js <- DT::JS(
                sprintf(
                    paste0(
                        "function(settings, json) {",
                        "  var emptyCols = %s;",
                        "  if (!Array.isArray(emptyCols) || emptyCols.length === 0) { return; }",
                        "  var api = this.api();",
                        "  api.columns().every(function(idx) {",
                        "    if (emptyCols.indexOf(idx) !== -1) {",
                        "      $(api.column(idx).header()).addClass('preview-col-empty');",
                        "    }",
                        "  });",
                        "}"
                    ),
                    jsonlite::toJSON(as.integer(empty_indices))
                )
            )

            DT::datatable(
                preview_df,
                options = list(
                    pageLength = 10,
                    lengthMenu = c(10, 25, 50, 100),
                    scrollX = TRUE,
                    autoWidth = FALSE,
                    columnDefs = column_defs,
                    initComplete = init_complete_js,
                    language = list(
                        search = tr("preview_datatable_search", lang_r()),
                        lengthMenu = tr("preview_datatable_length_menu", lang_r()),
                        info = tr("preview_datatable_info", lang_r()),
                        emptyTable = tr("preview_datatable_empty", lang_r()),
                        zeroRecords = tr("preview_datatable_zero_records", lang_r()),
                        paginate = list(
                            first = tr("preview_datatable_first", lang_r()),
                            last = tr("preview_datatable_last", lang_r()),
                            `next` = tr("preview_datatable_next", lang_r()),
                            previous = tr("preview_datatable_prev", lang_r())
                        )
                    )
                ),
                class = "display compact stripe",
                rownames = FALSE
            )
        })

        shiny::outputOptions(output, "datatable", priority = 10)

        output$download_real <- shiny::downloadHandler(
            filename = function() {
                paste0("dwc_export_", Sys.Date(), ".zip")
            },
            content = function(file) {
                shiny::req(download_data())
                status_100 <- sprintf(tr("preview_export_loading_status", lang_r()), 100)
                finish_payload <- list(
                    progress_id = ns("preview_export_progress_bar"),
                    status_id = ns("preview_export_status_text"),
                    phrase_icon_id = ns("preview_export_phrase_icon"),
                    phrase_text_id = ns("preview_export_phrase_text"),
                    modal_root_id = ns("preview_export_phrase_pool"),
                    timer_key = ns("preview_export_phrase_timer"),
                    status_text = status_100,
                    final_icon = "download",
                    final_phrase = tr("preview_export_phrase_10", lang_r()),
                    delay_ms = 320
                )

                tryCatch(
                    {
                        review_ready <- apply_name_review_payload(
                            download_data(),
                            payload = export_name_review_payload()
                        )

                        # Apply transposed-coordinate corrections approved in the
                        # coordinate validation tab (preserves verbatim coords).
                        coords_payload <- if (!is.null(coords_correction_payload_r) &&
                                              shiny::is.reactive(coords_correction_payload_r)) {
                            tryCatch(coords_correction_payload_r(), error = function(e) NULL)
                        } else {
                            NULL
                        }
                        review_ready <- apply_coords_correction_payload(review_ready, coords_payload)

                        raw_df <- if (!is.null(raw_data_r) && shiny::is.reactive(raw_data_r)) {
                            tryCatch(raw_data_r(), error = function(e) data.frame())
                        } else {
                            data.frame()
                        }
                        mv <- if (!is.null(map_values_r) && shiny::is.reactive(map_values_r)) {
                            tryCatch(map_values_r(), error = function(e) list())
                        } else {
                            list()
                        }
                        cv <- if (!is.null(custom_values_r) && shiny::is.reactive(custom_values_r)) {
                            tryCatch(custom_values_r(), error = function(e) list())
                        } else {
                            list()
                        }

                        full_data <- process_for_export_with_unmapped(
                            review_ready,
                            raw_data = raw_df,
                            map_values = mv
                        )

                        # Generalize coordinates of sensitive/threatened
                        # species before they reach the IPT bundle; the real
                        # coordinates go to a separate companion file.
                        gen_level <- sensitive_generalization_rv()
                        masked <- mask_sensitive_coordinates(
                            full_data,
                            decisions = export_sensitivity_payload(),
                            generalization = gen_level,
                            enabled = gen_level != "not_sensitive",
                            lang = lang_r()
                        )
                        export_data <- masked$masked

                        ts <- format(Sys.Date(), "%Y-%m-%d")
                        tmpdir <- tempfile("saira_export_")
                        dir.create(tmpdir, showWarnings = FALSE, recursive = TRUE)
                        on.exit(unlink(tmpdir, recursive = TRUE), add = TRUE)

                        # DwC-A core layout: occurrence.txt + meta.xml + eml.xml
                        # at archive root. The Excel mirror and mapping guide
                        # are dated convenience siblings; the private
                        # sensitive-coords CSV stays out of meta.xml so it is
                        # never advertised as part of the archive.
                        core_path  <- file.path(tmpdir, "occurrence.txt")
                        meta_path  <- file.path(tmpdir, "meta.xml")
                        eml_path   <- file.path(tmpdir, "eml.xml")
                        xlsx_path  <- file.path(tmpdir, paste0("dwc_export_", ts, ".xlsx"))
                        guide_path <- file.path(tmpdir, paste0("mapping_guide_", ts, ".txt"))

                        id_strategy <- attr(export_data, "id_strategy")
                        if (is.null(id_strategy)) id_strategy <- NA_character_

                        readr::write_csv(export_data, core_path, na = "")
                        writeLines(
                            build_meta_xml(export_data, core_filename = "occurrence.txt"),
                            meta_path,
                            useBytes = TRUE
                        )
                        writeLines(
                            build_eml_xml(export_data, metadata = list()),
                            eml_path,
                            useBytes = TRUE
                        )
                        write_xlsx_text_only(export_data, xlsx_path)
                        writeLines(
                            build_mapping_guide_txt(
                                mv, raw_df,
                                lang = lang_r(),
                                id_strategy = id_strategy,
                                constants = cv
                            ),
                            guide_path,
                            useBytes = TRUE
                        )

                        zip_files <- c(core_path, meta_path, eml_path,
                                       xlsx_path, guide_path)
                        if (masked$n_masked > 0L) {
                            real_path <- file.path(
                                tmpdir,
                                paste0("sensitive_real_coords_", ts, ".csv")
                            )
                            real_csv <- readr::format_csv(masked$real, na = "")
                            writeLines(
                                c(
                                    paste0(
                                        "# ",
                                        tr("sensitive_real_coords_notice", lang_r())
                                    ),
                                    real_csv
                                ),
                                real_path,
                                useBytes = TRUE
                            )
                            zip_files <- c(zip_files, real_path)
                        }

                        zip::zipr(
                            zipfile = file,
                            files = zip_files
                        )

                        session$sendCustomMessage(download_finish_channel, finish_payload)
                        shiny::showNotification(
                            tr("success_download", lang_r()),
                            type = "message"
                        )
                    },
                    error = function(e) {
                        fail_payload <- finish_payload
                        fail_payload$final_icon <- "triangle-exclamation"
                        fail_payload$final_phrase <- tr("preview_export_failed_phrase", lang_r())
                        session$sendCustomMessage(download_finish_channel, fail_payload)
                        shiny::showNotification(
                            sprintf(tr("preview_download_failed", lang_r()), conditionMessage(e)),
                            type = "error",
                            duration = 15
                        )
                        # Do not call stop(e): Shiny would serve its 500
                        # HTML page as the body while keeping the .zip name
                        # already sent in Content-Disposition, so the user
                        # would get HTML disguised as .zip. Wrap a tiny
                        # CSV-of-error inside a valid zip so the file name
                        # stays consistent.
                        err_df <- data.frame(
                            export_status = "ERROR",
                            message       = conditionMessage(e),
                            timestamp     = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
                            stringsAsFactors = FALSE
                        )
                        err_dir <- tempfile("saira_export_err_")
                        dir.create(err_dir, showWarnings = FALSE, recursive = TRUE)
                        on.exit(unlink(err_dir, recursive = TRUE), add = TRUE)
                        err_csv <- file.path(err_dir, "export_error.csv")
                        readr::write_csv(err_df, err_csv, na = "")
                        tryCatch(
                            zip::zipr(zipfile = file, files = err_csv),
                            error = function(.) readr::write_csv(err_df, file, na = "")
                        )
                    },
                    finally = {
                        is_exporting(FALSE)
                    }
                )
            }
        )

        # Hidden downloadButton (wrapped in display:none div) needs the URL
        # bound even when not visible. Without this, Shiny suspends the
        # output, the <a href> stays empty, and clicking it downloads the
        # current page (the app's own HTML) as the .csv filename.
        shiny::outputOptions(output, "download_real", suspendWhenHidden = FALSE)

        attr(preview_data, "download_data") <- download_data
        return(preview_data)
    })
}
