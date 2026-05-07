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
            shiny::uiOutput(ns("readiness_checklist")),
            shiny::br(),

            # Download button
            shiny::div(
                class = "mb-4",
                shiny::uiOutput(ns("download_btn_container"))
            ),

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
#' @return Reactive preview data frame
#' @export
mod_preview_server <- function(id, mapped_data_r, lang_r, download_data_r = mapped_data_r, name_review_payload_r = NULL) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns
        required_fields <- c(
            "scientificName",
            "eventDate",
            "decimalLatitude",
            "decimalLongitude",
            "basisOfRecord",
            "occurrenceID"
        )
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

        preview_readiness <- shiny::reactive({
            shiny::req(preview_data())
            compute_preview_readiness(
                preview_data(),
                required_fields = required_fields
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
                footer = NULL,
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

        output$readiness_checklist <- shiny::renderUI({
            df <- mapped_data_r()
            if (is.null(df) || !is.data.frame(df) || ncol(df) == 0L || nrow(df) == 0L) {
                return(NULL)
            }

            readiness <- preview_readiness()
            cards <- lapply(required_fields, function(field) {
                is_present <- isTRUE(readiness$required_status[[field]])
                status_label <- if (is_present) {
                    tr("preview_readiness_present", lang_r())
                } else {
                    tr("preview_readiness_missing", lang_r())
                }
                card_class <- if (is_present) "preview-readiness-card-ok" else "preview-readiness-card-missing"
                status_class <- if (is_present) "preview-readiness-state-ok" else "preview-readiness-state-missing"
                icon_class <- if (is_present) {
                    "fa-solid fa-circle-check preview-readiness-icon"
                } else {
                    "fa-solid fa-circle-xmark preview-readiness-icon"
                }

                shiny::div(
                    class = paste("preview-readiness-card", card_class),
                    shiny::div(class = "preview-readiness-card-term", field),
                    shiny::div(
                        class = "preview-readiness-card-status",
                        shiny::div(
                            class = paste("preview-readiness-state", status_class),
                            title = status_label,
                            `aria-label` = status_label,
                            shiny::tags$i(class = icon_class)
                        )
                    )
                )
            })

            shiny::div(
                class = "preview-readiness-panel mb-4",
                shiny::h4(
                    class = "preview-readiness-title",
                    shiny::icon("clipboard-check"),
                    tr("preview_readiness_title", lang_r()),
                ),
                shiny::div(class = "preview-readiness-grid", cards)
            )
        })

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
                paste0("dwc_export_", Sys.Date(), ".csv")
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
                        full_data <- process_for_export(review_ready)
                        readr::write_csv(full_data, file, na = "")
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
                            sprintf(tr("preview_download_failed", lang_r()), e$message),
                            type = "error"
                        )
                        stop(e)
                    },
                    finally = {
                        is_exporting(FALSE)
                    }
                )
            }
        )

        attr(preview_data, "download_data") <- download_data
        return(preview_data)
    })
}
