# Title: Export download controller (ADR-103, ADR-170)
# Author: Rogerio Nunes Oliveira
#
# Handles Shiny confirmation, progress and success/failure. Preparation and policy
# live in utils_publication.R; build_dwca_bundle() owns the archive core trio.
# Real coordinates are written only by the separate private download.

#' Mount the DwC-A export download flow inside a module server
#' @param sources Named list of the export decision sources (reactives or
#'   NULL), the one list the export summary also captures.
#' @noRd
mount_export_download <- function(input, output, session, lang_r,
                                  mapped_data_r,
                                  download_data_r,
                                  sources = list(),
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
                    mapped_data_r(), name_review_payload = optional_reactive_value(sources$name_review),
                    coords_correction_payload = optional_reactive_value(sources$coords_correction),
                    country_fill_payload = optional_reactive_value(sources$country_fill),
                    generalization_payload = optional_reactive_value(sources$generalization),
                    raw_data = optional_reactive_value(sources$raw_data),
                    map_values = optional_reactive_value(sources$map_values),
                    overridden_terms = overridden_mapping_terms(optional_reactive_value(sources$custom_values))
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
        # Every export source, read once. A source that fails stops the
        # download with the message the summary shows (SP-01). The product
        # itself is built outside Shiny (prepare_export_product()).
        capture_export_inputs <- function() {
            src <- capture_sources(
                sources,
                defaults = list(raw_data = data.frame(), map_values = list(),
                                custom_values = list(), rows_left_out = integer(0))
            )
            if (length(src$failed)) {
                stop(sprintf(tr("export_blocked_source_failed", lang_r()),
                             export_source_steps(names(src$failed), lang_r())), call. = FALSE)
            }
            c(list(download_data = download_data()), src$values)
        }

        # The desktop shell asks before it closes when the data changed after
        # the last bundle. The watcher starts after a bundle and suspends at
        # the first change of its inputs, so it never computes them again.
        bundle_inputs <- c(download_data, Filter(shiny::is.reactive, sources))
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
                cv_fn <- if (shiny::is.reactive(sources$custom_values)) {
                    tryCatch(sources$custom_values(), error = function(e) list())
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
                        product <- prepare_export_product(capture_export_inputs(), lang_r())

                        tmpdir <- tempfile("saira_export_")
                        dir.create(tmpdir, showWarnings = FALSE, recursive = TRUE)
                        on.exit(unlink(tmpdir, recursive = TRUE), add = TRUE)

                        # File names shared with the Export tab summary: the
                        # DwC-A core trio (occurrence.txt + meta.xml + eml.xml)
                        # and the measurement extension keep their standard
                        # names at archive root; the Excel
                        # mirror and mapping guide are renamed after the dataset.
                        # The real coordinates have their own download (ADR-163).
                        fnames <- export_bundle_filenames(dataset_name = product$dataset_name,
                                                          n_records = nrow(product$core),
                                                          has_changes = nrow(product$changes) > 0L,
                                                          has_measurements = !is.null(product$measurements))
                        xlsx_path  <- if (!is.null(fnames$auxiliary$xlsx)) {
                            file.path(tmpdir, fnames$auxiliary$xlsx)
                        }
                        guide_path <- file.path(tmpdir, fnames$auxiliary[["mapping_guide"]])

                        if (!is.null(xlsx_path)) write_xlsx_text_only(product$core, xlsx_path)
                        writeLines(product$mapping_guide, guide_path, useBytes = TRUE)

                        extras <- list()
                        if (!is.null(xlsx_path)) extras[[basename(xlsx_path)]] <- xlsx_path
                        extras[[basename(guide_path)]] <- guide_path
                        if (!is.null(fnames$auxiliary$changes)) {
                            changes_path <- file.path(tmpdir, fnames$auxiliary$changes)
                            write_change_log_csv(product$changes, changes_path)
                            extras[[basename(changes_path)]] <- changes_path
                        }
                        build_dwca_bundle(product$core, file, metadata = product$metadata,
                                          extras = extras, measurements = product$measurements)

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
                cv_fn <- if (shiny::is.reactive(sources$custom_values)) {
                    tryCatch(sources$custom_values(), error = function(e) list())
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
                prep <- prepare_masked_export(capture_export_inputs(), lang_r())
                write_sensitive_coords_xlsx(
                    prep$masked$real,
                    notice = tr("sensitive_real_coords_notice", lang_r()),
                    path = file
                )
            }
        )

    invisible(NULL)
}
