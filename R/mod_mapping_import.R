# Mapping-guide import controller. Decisions are applied through mapping commands.
mount_mapping_import <- function(input, session, lang_r, raw_data_r, commands,
                                  show_loading, hide_loading, seed_aliases) {
    ns <- session$ns
    shiny::observeEvent(input$import_template, {
        shiny::showModal(shiny::modalDialog(
            title = tr("modal_import_template_title", lang_r()),
            # Same dropzone and progress row as the Home upload
            # (upload-dropzone.js binds any .upload-dropzone).
            shiny::div(
                class = "import-template-modal",
                shiny::p(
                    class = "import-template-help",
                    tr("modal_import_template_help", lang_r())
                ),
                shiny::div(
                    class = "upload-section",
                    shiny::div(
                        class = "upload-dropzone import-template-dropzone",
                        shiny::div(
                            class = "upload-dropzone-copy",
                            ph_icon("file-import", class = "upload-dropzone-icon", weight = "light"),
                            shiny::div(
                                class = "upload-dropzone-hint upload-dropzone-when-empty",
                                tr("modal_import_template_dropzone_hint", lang_r())
                            ),
                            shiny::div(class = "upload-dropzone-filename upload-dropzone-when-file"),
                            shiny::div(
                                class = "upload-dropzone-max-size upload-dropzone-when-file",
                                tr("modal_import_template_replace_hint", lang_r())
                            )
                        )
                    ),
                    shiny::div(
                        class = "upload-native-input",
                        shiny::fileInput(
                            inputId = ns("import_template_file"),
                            label = shiny::tags$span(
                                tr("modal_import_template_label", lang_r()),
                                class = "visually-hidden"
                            ),
                            accept = c(".txt", "text/plain"),
                            buttonLabel = ph_icon("upload"),
                            placeholder = ""
                        )
                    )
                )
            ),
            footer = shiny::tagList(
                shiny::modalButton(tr("btn_cancel", lang_r())),
                shiny::actionButton(
                    ns("confirm_import_template"),
                    tr("modal_import_template_confirm", lang_r()),
                    class = "btn-primary"
                )
            ),
            easyClose = TRUE
        ))
    })

    shiny::observeEvent(input$confirm_import_template, {
        f <- input$import_template_file
        if (is.null(f) || !nzchar(f$datapath)) {
            shiny::showNotification(
                tr("modal_import_template_no_file", lang_r()),
                type = "warning",
                duration = 5
            )
            return(invisible(NULL))
        }

        if (!is_saira_mapping_guide(f$datapath)) {
            shiny::showNotification(
                tr("modal_import_template_invalid_magic", lang_r()),
                type = "error",
                duration = 8
            )
            return(invisible(NULL))
        }

        payload <- tryCatch(
            parse_mapping_guide_txt(f$datapath),
            error = function(e) e
        )
        if (inherits(payload, "error")) {
            shiny::showNotification(
                sprintf(tr("upload_guide_invalid", lang_r()), conditionMessage(payload)),
                type = "error",
                duration = 8
            )
            return(invisible(NULL))
        }

        # From here on the import is committed and takes a couple of
        # seconds: the alias upserts, then a full grid rebuild (restoring
        # scientificName flips rv$scientificname_mapped, one of the four
        # structural dependencies of output$mapping_ui). Nothing above this
        # line is slow, so the modal opens here and no early return has to
        # take it back down. showModal writes to the socket immediately, so
        # it paints while the loop below still runs.
        show_loading()
        # The modal has no footer and no easyClose, so anything that throws
        # before the handover below would strand the user behind it.
        handed_to_flush <- FALSE
        on.exit({
            if (!handed_to_flush) hide_loading()
        }, add = TRUE)

        # Faithful restore: rebuild the exact mapping in the cards by
        # matching the guide's source columns to the loaded dataset.
        available_columns <- tryCatch(names(raw_data_r()), error = function(e) character(0))
        plan <- plan_mapping_guide_restore(payload, available_columns)

        commands$restore(plan)

        consts <- plan$constants
        if (!is.null(consts$datasetName)) {
            shiny::updateTextInput(session, "custom_datasetName", value = consts$datasetName)
            commands$manual_meta("datasetName")
        }
        if (!is.null(consts$license)) {
            shiny::updateCheckboxGroupInput(session, "custom_license", selected = consts$license)
        }
        if (!is.null(consts$language)) {
            shiny::updateCheckboxGroupInput(session, "custom_language", selected = consts$language)
        }
        # Fixed values from the constant_value_terms() allowlist. A term
        # overridden by one is written to the guide as a constant and no
        # longer as a column mapping, so without this the import restores
        # it nowhere and the term leaves the next export.
        for (term in intersect(names(consts), constant_value_terms())) {
            commands$fixed_value(term, consts[[term]])
            commands$manual_meta(term)
        }

        # Seed personal aliases for cross-dataset auto-mapping (ADR-087);
        # non-fatal if it fails (the faithful restore already happened).
        # Reuses the module's connection: opening a second one to the same
        # file re-runs the schema migration check and makes the two contend
        # for the same write lock through BEGIN IMMEDIATE.
        tryCatch(
            seed_aliases(payload, available_columns),
            error = function(e) NULL
        )

        n_terms <- length(plan$applied_terms)
        msg <- if (n_terms == 0L) {
            tr("modal_import_template_none_applied", lang_r())
        } else {
            sprintf(tr("modal_import_template_restored", lang_r()), n_terms)
        }
        # Green only when every template column was found.
        notif_type <- if (n_terms == 0L) {
            "error"
        } else if (length(plan$missing_columns) > 0L) {
            "warning"
        } else {
            "message"
        }
        if (length(plan$missing_columns) > 0L) {
            msg <- paste0(msg, " ", sprintf(
                tr("modal_import_template_missing_cols", lang_r()),
                length(plan$missing_columns),
                paste(utils::head(plan$missing_columns, 5L), collapse = ", ")
            ))
        }

        # The grid rebuild happens in the output pass of this same flush,
        # after the observer returns. Closing the modal here would hand the
        # user back a stale screen and let them click into cards that are
        # about to be replaced, so hold it until the flush is done.
        session$onFlushed(function() {
            hide_loading()
            shiny::showNotification(
                msg, type = notif_type, duration = 10, session = session
            )
        }, once = TRUE)
        handed_to_flush <- TRUE
    }, ignoreInit = TRUE)

    invisible(NULL)
}
