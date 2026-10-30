# Title: Export download controller (ADR-103, ADR-170)
# Author: Rogerio Nunes Oliveira
#
# Handles Shiny confirmation, progress and success/failure. Preparation and policy
# live in utils_publication.R; build_dwca_bundle() owns the archive core trio.
# Real coordinates are written only by the separate private download.

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
                                  rows_left_out_r = NULL,
                                  preview_changes_r = NULL,
                                  measurement_specs_r = NULL,
                                  blocked_r = NULL,
                                  on_export_success = NULL) {
    ns <- session$ns
        required_download_fields <- publication_required_terms()
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
            list(key = "preview_export_phrase_6", icon = "circle-check"),
            list(key = "preview_export_phrase_7", icon = "lock"),
            list(key = "preview_export_phrase_8", icon = "shield-check"),
            list(key = "preview_export_phrase_9", icon = "file-zipper"),
            list(key = "preview_export_phrase_10", icon = "download")
        )
        # Disabled until the dataset is publishable. Uses the module-level
        # readiness (the same `export_blocked` the banner shows) so the
        # button and the banner never contradict each other; falls back to
        # the local required-term check when no readiness reactive is given.
        # The server checks it again before it writes the bundle, because the
        # hidden download link works without the button.
        export_blocked <- shiny::reactive({
            if (!is.null(blocked_r) && shiny::is.reactive(blocked_r)) {
                isTRUE(blocked_r())
            } else {
                isTRUE(build_export_summary(
                    mapped_data_r(), name_review_payload = export_name_review_payload(),
                    coords_correction_payload = optional_reactive_value(coords_correction_payload_r),
                    country_fill_payload = optional_reactive_value(country_fill_payload_r),
                    generalization_payload = optional_reactive_value(sensitive_generalization_payload_r),
                    raw_data = optional_reactive_value(raw_data_r),
                    map_values = optional_reactive_value(map_values_r),
                    overridden_terms = overridden_mapping_terms(optional_reactive_value(custom_values_r))
                )$export_blocked)
            }
        })
        output$download_btn_container <- shiny::renderUI({
            register_handlers_script <- module_behavior_call("exportDownloadHandlers", list(
                clickChannel = download_click_channel, finishChannel = download_finish_channel
            ))

            blocked <- export_blocked()
            inert <- isTRUE(is_exporting()) || blocked

            shiny::tagList(
                shiny::actionButton(
                    inputId = ns("download_trigger"),
                    # A blocked bundle says what to do, the Pending card says what.
                    label = if (blocked) {
                        shiny::tagList(ph_icon("lock"), " ", tr("export_download_resolve", lang_r()))
                    } else {
                        shiny::tagList(ph_icon("file-zipper"), " ", tr("export_download_zip", lang_r()))
                    },
                    class = paste(
                        "btn action-button preview-download-btn export-download-btn",
                        if (inert) "is-inert" else "btn-success"
                    ),
                    disabled = inert
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
                    ph_icon("info-circle"),
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
                        ph_icon("triangle-exclamation"),
                        " ",
                        tr("preview_download_confirm_warning", lang_r())
                    ),
                    if (length(validation_result$warning_missing) > 0L) {
                        shiny::p(
                            class = "text-accent mt-2 mb-0",
                            ph_icon("info-circle"),
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
            rotate_script <- module_behavior_call("exportProgressModal", list(
                iconId = ns("preview_export_phrase_icon"),
                textId = ns("preview_export_phrase_text"),
                poolId = ns("preview_export_phrase_pool"),
                progressId = ns("preview_export_progress_bar"),
                statusId = ns("preview_export_status_text"),
                timerKey = ns("preview_export_phrase_timer"),
                statusPrefix = status_prefix
            ))

            shiny::showModal(shiny::modalDialog(
                shiny::div(
                    class = "automap-loading-modal preview-export-loading-modal",
                    shiny::div(
                        class = "automap-loading-brand-row",
                        ph_icon("dove", class = "automap-loading-brand-icon")
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
                            ph_icon(
                                first_spec$icon,
                                id = ns("preview_export_phrase_icon"),
                                class = "automap-loading-phrase-icon"
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
                                    `data-icon` = ph_icon_name(spec$icon),
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
            if (isTRUE(export_blocked())) {
                return(invisible(NULL))
            }

            show_download_confirmation_modal(validation_result)
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$confirm_download_yes, {
            if (isTRUE(is_exporting()) || isTRUE(export_blocked())) {
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
        # The steps both downloads share. The private file must hold the same
        # real points that the bundle generalizes.
        prepare_masked_rows <- function() {
            # Transposed-coordinate corrections approved in the coordinate
            # validation tab (preserves verbatim coords), and the country
            # derived from coordinates where missing.
            coords_payload <- if (!is.null(coords_correction_payload_r) &&
                                  shiny::is.reactive(coords_correction_payload_r)) {
                tryCatch(coords_correction_payload_r(), error = function(e) NULL)
            } else {
                NULL
            }
            country_payload <- if (!is.null(country_fill_payload_r) &&
                                   shiny::is.reactive(country_fill_payload_r)) {
                tryCatch(country_fill_payload_r(), error = function(e) NULL)
            } else {
                NULL
            }

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
            effective <- prepare_effective_records(
                download_data(), export_name_review_payload(), coords_payload, country_payload
            )
            assessment <- assess_publication(
                effective, gen, raw_df, mv, overridden_mapping_terms(cv),
                coords_correction_payload = drop_stale_coord_corrections(coords_payload, download_data())
            )
            if (isTRUE(assessment$export_blocked)) {
                stop(tr("export_download_blocked", lang_r()), call. = FALSE)
            }
            # Masks before process_for_export_with_unmapped(): that step turns
            # the coordinates into numbers, "-19.900" loses its trailing zeros,
            # and the precision clamp then picks a coarser grid than the
            # Generalization tab shows.
            masked <- prepare_publication_records(
                effective,
                sensitivity = rekey_sensitivity_decisions(export_sensitivity_payload(), export_name_review_payload()),
                generalization = gen, lang = lang_r()
            )
            # Exact copies the Preview left out. The rows go after the
            # unmapped columns join, which match the upload by row.
            drop <- intersect(optional_reactive_value(rows_left_out_r, integer(0)),
                              seq_len(nrow(effective)))
            if (length(drop) && nrow(masked$real)) {
                ids <- if ("occurrenceID" %in% names(effective)) {
                    as.character(effective$occurrenceID)
                } else {
                    as.character(seq_len(nrow(effective)))
                }
                masked$real <- masked$real[!masked$real$occurrenceID %in% ids[drop], , drop = FALSE]
            }
            changes <- build_change_log(
                download_data(), effective, optional_reactive_value(preview_changes_r, NULL),
                union(masked$rows, generalized_record_rows(effective, gen)), drop
            )
            list(masked = masked, gen = gen, cv = cv, raw_df = raw_df, mv = mv, drop = drop,
                 changes = changes)
        }

        # The desktop shell asks before it closes when the data changed after
        # the last bundle. The watcher starts after a bundle and suspends at
        # the first change of its inputs, so it never computes them again.
        bundle_inputs <- c(
            download_data, export_name_review_payload, export_sensitivity_payload,
            raw_data_r, map_values_r, custom_values_r, coords_correction_payload_r,
            country_fill_payload_r, sensitive_generalization_payload_r,
            conservation_payload_r, occurrence_id_info_r, rows_left_out_r,
            preview_changes_r, measurement_specs_r
        )
        bundle_watch <- shiny::observe({
            for (r in bundle_inputs) tryCatch(r(), error = function(e) NULL)
            session$sendCustomMessage("saira-bundle-state", "current")
        }, suspended = TRUE)
        bundle_watch$onInvalidate(function() {
            bundle_watch$suspend()
            session$sendCustomMessage("saira-bundle-state", "stale")
        })

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
                    final_icon = ph_icon_name("download"),
                    final_phrase = tr("preview_export_phrase_10", lang_r()),
                    delay_ms = 320
                )

                tryCatch(
                    {
                        # The error branch below writes an error zip, so a
                        # blocked dataset never ships and never teaches aliases.
                        if (isTRUE(export_blocked())) {
                            stop(tr("export_download_blocked", lang_r()), call. = FALSE)
                        }
                        prep <- prepare_masked_rows()
                        masked <- prep$masked
                        gen <- prep$gen
                        cv <- prep$cv
                        raw_df <- prep$raw_df
                        mv <- prep$mv

                        # Add conservation status (MMA and/or IUCN) to
                        # dynamicProperties, keyed to the providers chosen in the
                        # Name tab. Runs on the corrected scientificName and after
                        # the country fill, because the MMA list is national and is
                        # scoped to records that resolve to Brazil. The GBIF IUCN
                        # call is optional/non-blocking (NA on any failure).
                        conservation_payload <- if (!is.null(conservation_payload_r) &&
                                                    shiny::is.reactive(conservation_payload_r)) {
                            tryCatch(conservation_payload_r(), error = function(e) NULL)
                        } else {
                            NULL
                        }
                        # After the mask, so a generalized row outside Brazil
                        # still gets the MMA category its dataGeneralizations cites.
                        masked$masked <- apply_conservation_status(
                            masked$masked, conservation_payload,
                            generalized = seq_len(nrow(masked$masked)) %in% masked$rows
                        )
                        export_data <- process_for_export_with_unmapped(
                            masked$masked,
                            raw_data = raw_df,
                            map_values = mv,
                            overridden_terms = overridden_mapping_terms(cv),
                            sensitive_rows = masked$scrub_rows,
                            sensitive_points = masked$scrub_points
                        )

                        if (length(prep$drop)) {
                            id_attr <- attr(export_data, "id_strategy")
                            export_data <- export_data[-prep$drop, , drop = FALSE]
                            rownames(export_data) <- NULL
                            attr(export_data, "id_strategy") <- id_attr
                        }

                        # GBIF reads no measurement term in the core, so the
                        # measurements go to their own extension file.
                        value_column <- if ("measurementValue" %in% overridden_mapping_terms(cv)) {
                            NULL
                        } else {
                            map_value_sources(mv["measurementValue"])[1L]
                        }
                        measurement_specs <- if (shiny::is.reactive(measurement_specs_r)) {
                            tryCatch(measurement_specs_r(), error = function(e) NULL)
                        }
                        mof <- split_measurements(export_data, value_column, measurement_specs)
                        export_data <- mof$core

                        if (formula_like_cells(export_data)$count > 0L ||
                            formula_like_cells(mof$measurements)$count > 0L) {
                            stop(tr("export_download_blocked", lang_r()), call. = FALSE)
                        }

                        tmpdir <- tempfile("saira_export_")
                        dir.create(tmpdir, showWarnings = FALSE, recursive = TRUE)
                        on.exit(unlink(tmpdir, recursive = TRUE), add = TRUE)

                        # File names shared with the Export tab summary: the
                        # DwC-A core trio (occurrence.txt + meta.xml + eml.xml)
                        # and the measurement extension keep their standard
                        # names at archive root; the Excel
                        # mirror and mapping guide are renamed after the dataset.
                        # The real coordinates have their own download (ADR-163).
                        fnames <- export_bundle_filenames(dataset_name = cv$datasetName,
                                                          n_records = nrow(export_data),
                                                          has_changes = nrow(prep$changes) > 0L,
                                                          has_measurements = !is.null(mof$measurements))
                        xlsx_path  <- if (!is.null(fnames$auxiliary$xlsx)) {
                            file.path(tmpdir, fnames$auxiliary$xlsx)
                        }
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
                        # The Preview replaces the ids that still repeat
                        # after its corrections (ADR-152).
                        id_counts <- occurrence_id_counts_after_repeats(
                            id_info$counts, attr(download_data(), "ids_replaced")
                        )
                        if (!identical(id_counts, id_info$counts)) {
                            id_strategy <- occurrence_id_strategy_label(id_counts$preserved, id_counts$total)
                        }

                        eml_metadata <- publication_metadata(export_data, masked$real, gen, lang_r())
                        if (!is.null(xlsx_path)) write_xlsx_text_only(export_data, xlsx_path)
                        writeLines(
                            build_mapping_guide_txt(
                                mv, raw_df,
                                lang = lang_r(),
                                id_strategy = id_strategy,
                                constants = cv,
                                id_counts = id_counts,
                                source_file = attr(raw_df, "source_file") %||% NA_character_
                            ),
                            guide_path,
                            useBytes = TRUE
                        )

                        extras <- list()
                        if (!is.null(xlsx_path)) extras[[basename(xlsx_path)]] <- xlsx_path
                        extras[[basename(guide_path)]] <- guide_path
                        if (!is.null(fnames$auxiliary$changes)) {
                            changes_path <- file.path(tmpdir, fnames$auxiliary$changes)
                            write_change_log_csv(prep$changes, changes_path)
                            extras[[basename(changes_path)]] <- changes_path
                        }
                        build_dwca_bundle(export_data, file, metadata = eml_metadata, extras = extras,
                                          measurements = mof$measurements)

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
                        bundle_watch$resume()

                        session$sendCustomMessage(download_finish_channel, finish_payload)
                        shiny::showNotification(
                            tr("success_download", lang_r()),
                            type = "message"
                        )
                    },
                    error = function(e) {
                        fail_payload <- finish_payload
                        fail_payload$final_icon <- ph_icon_name("triangle-exclamation")
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

        # The real coordinates of the generalized records, apart from the IPT
        # bundle, so a shared .zip never carries the exact points (ADR-163).
        output$download_private <- shiny::downloadHandler(
            filename = function() {
                cv_fn <- if (!is.null(custom_values_r) && shiny::is.reactive(custom_values_r)) {
                    tryCatch(custom_values_r(), error = function(e) list())
                } else {
                    list()
                }
                export_bundle_filenames(dataset_name = cv_fn$datasetName, has_sensitive = TRUE)$private
            },
            content = function(file) {
                shiny::req(download_data())
                if (isTRUE(export_blocked())) {
                    stop(tr("export_download_blocked", lang_r()), call. = FALSE)
                }
                prep <- prepare_masked_rows()
                write_sensitive_coords_xlsx(
                    prep$masked$real,
                    notice = tr("sensitive_real_coords_notice", lang_r()),
                    path = file
                )
            }
        )

    invisible(NULL)
}
