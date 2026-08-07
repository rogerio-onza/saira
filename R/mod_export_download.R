# Title: Export download subsystem (relocated verbatim from mod_preview, ADR-103)
# Author: Rogerio Nunes Oliveira
#
# The full DwC-A download flow (field validation -> confirmation modal ->
# animated loading modal driven by custom message channels -> hidden
# downloadButton -> bundle downloadHandler) lives here so it can be mounted on
# the Export tab. Body is moved verbatim from mod_preview_server to preserve the
# exact JS/channel wiring; only the enclosing function differs. Call it from
# within a moduleServer, passing that module's input/output/session.

#' Mount the DwC-A export download flow inside a module server
#' @noRd
mount_export_download <- function(input, output, session, lang_r,
                                  mapped_data_r,
                                  download_data_r,
                                  name_review_payload_r = NULL,
                                  sensitivity_payload_r = NULL,
                                  sensitive_generalization_payload_r = NULL,
                                  conservation_payload_r = NULL,
                                  raw_data_r = NULL,
                                  map_values_r = NULL,
                                  custom_values_r = NULL,
                                  occurrence_id_info_r = NULL,
                                  coords_correction_payload_r = NULL,
                                  country_fill_payload_r = NULL,
                                  blocked_r = NULL,
                                  on_export_success = NULL) {
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

            # Disabled until the dataset is publishable. Uses the module-level
            # readiness (the same `export_blocked` the banner shows) so the
            # button and the banner never contradict each other; falls back to
            # the local required-term check when no readiness reactive is given.
            blocked <- if (!is.null(blocked_r) && shiny::is.reactive(blocked_r)) {
                isTRUE(blocked_r())
            } else {
                !isTRUE(download_validation()$ok)
            }
            inert <- isTRUE(is_exporting()) || blocked

            shiny::tagList(
                shiny::actionButton(
                    inputId = ns("download_trigger"),
                    label = shiny::tagList(
                        shiny::icon("file-zipper"),
                        " ",
                        tr("export_download_zip", lang_r())
                    ),
                    class = paste(
                        "btn action-button preview-download-btn export-download-btn",
                        if (inert) "is-inert" else "btn-success"
                    ),
                    disabled = if (inert) "disabled" else NULL
                ),
                shiny::div(
                    style = "display: none;",
                    shiny::downloadButton(
                        outputId = ns("download_real"),
                        label = tr("export_download_zip", lang_r()),
                        icon = NULL
                    )
                ),
                shiny::tags$script(shiny::HTML(register_handlers_script))
            )
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
        output$download_real <- shiny::downloadHandler(
            filename = function() {
                cv_fn <- if (!is.null(custom_values_r) && shiny::is.reactive(custom_values_r)) {
                    tryCatch(custom_values_r(), error = function(e) list())
                } else {
                    list()
                }
                export_bundle_filenames(dataset_name = cv_fn$datasetName)$zip
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

                        # Add conservation status (MMA and/or IUCN) to
                        # dynamicProperties, keyed to the providers chosen in the
                        # Name tab. Runs on the corrected scientificName; the GBIF
                        # IUCN call is optional/non-blocking (NA on any failure).
                        conservation_payload <- if (!is.null(conservation_payload_r) &&
                                                    shiny::is.reactive(conservation_payload_r)) {
                            tryCatch(conservation_payload_r(), error = function(e) NULL)
                        } else {
                            NULL
                        }
                        review_ready <- apply_conservation_status(review_ready, conservation_payload)

                        # Apply transposed-coordinate corrections approved in the
                        # coordinate validation tab (preserves verbatim coords).
                        coords_payload <- if (!is.null(coords_correction_payload_r) &&
                                              shiny::is.reactive(coords_correction_payload_r)) {
                            tryCatch(coords_correction_payload_r(), error = function(e) NULL)
                        } else {
                            NULL
                        }
                        review_ready <- apply_coords_correction_payload(review_ready, coords_payload)

                        # Fill country derived from coordinates (where missing).
                        country_payload <- if (!is.null(country_fill_payload_r) &&
                                               shiny::is.reactive(country_fill_payload_r)) {
                            tryCatch(country_fill_payload_r(), error = function(e) NULL)
                        } else {
                            NULL
                        }
                        review_ready <- apply_country_fill_payload(review_ready, country_payload)

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

                        # Generalize coordinates of sensitive/threatened species
                        # before they reach the IPT bundle, each to the grid its
                        # Chapman assessment derived (decided in the Validation >
                        # Coordinates tab, ADR-100); the real coordinates go to a
                        # separate companion file.
                        gen <- if (is.null(sensitive_generalization_payload_r) ||
                                   !shiny::is.reactive(sensitive_generalization_payload_r)) {
                            NULL
                        } else {
                            sensitive_generalization_payload_r()
                        }
                        # Mandatory justification: block export when any record is
                        # generalized to Category 1/2/3 without a written reason
                        # (decided in the Generalization tab).
                        if (is.list(gen) && isTRUE(gen$enabled) &&
                            isTRUE(gen$needs_justification) &&
                            !nzchar(trimws(gen$justification %||% ""))) {
                            shiny::showNotification(
                                tr("preview_export_needs_justification", lang_r()),
                                type = "error", duration = 8
                            )
                            shiny::req(FALSE)
                        }
                        gen_levels <- if (is.list(gen) && !is.null(gen$levels)) {
                            gen$levels
                        } else {
                            stats::setNames(character(0), character(0))
                        }
                        masked <- mask_sensitive_coordinates(
                            full_data,
                            decisions = export_sensitivity_payload(),
                            generalization = gen_levels,
                            enabled = is.list(gen) && isTRUE(gen$enabled),
                            lang = lang_r(),
                            justification = if (is.list(gen)) gen$justification else NULL
                        )
                        export_data <- masked$masked

                        tmpdir <- tempfile("saira_export_")
                        dir.create(tmpdir, showWarnings = FALSE, recursive = TRUE)
                        on.exit(unlink(tmpdir, recursive = TRUE), add = TRUE)

                        # File names shared with the Export tab summary: the
                        # DwC-A core trio (occurrence.txt + meta.xml + eml.xml)
                        # keeps its standard names at archive root; the Excel
                        # mirror, mapping guide and private sensitive-coords CSV
                        # are renamed after the dataset. The sensitive CSV stays
                        # out of meta.xml so it is never advertised as part of
                        # the archive.
                        fnames <- export_bundle_filenames(
                            dataset_name = cv$datasetName,
                            has_sensitive = masked$n_masked > 0L
                        )
                        core_path  <- file.path(tmpdir, "occurrence.txt")
                        meta_path  <- file.path(tmpdir, "meta.xml")
                        eml_path   <- file.path(tmpdir, "eml.xml")
                        xlsx_path  <- file.path(tmpdir, fnames$auxiliary[["xlsx"]])
                        guide_path <- file.path(tmpdir, fnames$auxiliary[["mapping_guide"]])

                        # The mapping stage is what actually resolves the
                        # identifiers, so it is the only place that knows how
                        # many came from the user's data. Reading the attribute
                        # off export_data only ever reported "user_supplied",
                        # because by then the column is always full.
                        id_info <- if (!is.null(occurrence_id_info_r) &&
                                       shiny::is.reactive(occurrence_id_info_r)) {
                            tryCatch(occurrence_id_info_r(), error = function(e) NULL)
                        } else {
                            NULL
                        }
                        id_strategy <- id_info$strategy %||% attr(export_data, "id_strategy")
                        if (is.null(id_strategy)) id_strategy <- NA_character_
                        id_counts <- id_info$counts

                        readr::write_csv(export_data, core_path, na = "")
                        writeLines(
                            build_meta_xml(export_data, core_filename = "occurrence.txt"),
                            meta_path,
                            useBytes = TRUE
                        )
                        # Record the dataset-level access constraint (Chapman
                        # sec. 5.1) in the EML when any record was generalized.
                        eml_metadata <- list()
                        # The EML intellectualRights must reflect the license the
                        # user chose in the mapping (constant card or a mapped
                        # column), carried in the export's license column — not
                        # the CC0 default. Use the most frequent non-empty value
                        # when a mapped column carries more than one.
                        if ("license" %in% names(export_data)) {
                            lic_vals <- trimws(as.character(export_data[["license"]]))
                            lic_vals <- lic_vals[!is.na(lic_vals) & nzchar(lic_vals)]
                            if (length(lic_vals) > 0L) {
                                eml_metadata$license <- names(
                                    sort(table(lic_vals), decreasing = TRUE)
                                )[[1]]
                            }
                        }
                        if (masked$n_masked > 0L) {
                            review_date <- if (is.list(gen)) gen$review_date else NULL
                            if (is.null(review_date) || length(review_date) == 0L) {
                                review_date <- Sys.Date() + 730
                            }
                            eml_metadata$sensitivity <- list(
                                n_masked = masked$n_masked,
                                review_date = format(as.Date(review_date), "%Y-%m-%d"),
                                lang = lang_r()
                            )
                        }
                        writeLines(
                            build_eml_xml(export_data, metadata = eml_metadata),
                            eml_path,
                            useBytes = TRUE
                        )
                        write_xlsx_text_only(export_data, xlsx_path)
                        writeLines(
                            build_mapping_guide_txt(
                                mv, raw_df,
                                lang = lang_r(),
                                id_strategy = id_strategy,
                                constants = cv,
                                id_counts = id_counts
                            ),
                            guide_path,
                            useBytes = TRUE
                        )

                        zip_files <- c(core_path, meta_path, eml_path,
                                       xlsx_path, guide_path)
                        if (masked$n_masked > 0L) {
                            real_path <- file.path(
                                tmpdir,
                                fnames$auxiliary[["sensitive_coords"]]
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

                        # The bundle is written: the mapping is now confirmed, so
                        # the mapping module may learn its aliases. Fires only
                        # here, never on the error branch below. Kept
                        # non-blocking -- a failed alias write must not turn a
                        # delivered export into a visible failure.
                        if (is.function(on_export_success)) {
                            tryCatch(
                                on_export_success(),
                                error = function(e) {
                                    warning("[rostrum] Could not commit aliases on export: ",
                                            conditionMessage(e))
                                }
                            )
                        }

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

    invisible(NULL)
}
