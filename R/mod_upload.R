# Title: Upload Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-08
# Version: 2.0 - Two-column layout with welcome and financing

#' Upload Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_upload_ui <- function(id) {
    ns <- shiny::NS(id)

    # Home B: the upload panel on the left, the required columns on the right.
    shiny::div(
        class = "container-fluid homepage-container home-b",
        shiny::tags$section(
            class = "home-panel home-upload-panel",
            shiny::uiOutput(ns("home_header")),
            # ADR-097: tab strip replaces ADR-095 input_switch.
            # Native radioButtons drive the state. Shiny does
            # NOT assign per-option ids on the radio inputs, so
            # `<label for>` cannot forward clicks; instead a
            # tiny click delegator (script below) syncs the
            # visible tab clicks to the matching radio input.
            shiny::div(
                class = "upload-mode-tabs",
                role  = "tablist",
                `aria-labelledby` = ns("mode_tabs_label"),
                shiny::tags$span(
                    id = ns("mode_tabs_label"),
                    class = "visually-hidden",
                    shiny::uiOutput(ns("mode_tabs_a11y_label"), inline = TRUE)
                ),
                shiny::div(
                    class = "upload-mode-tabs-input",
                    shiny::radioButtons(
                        inputId = ns("upload_mode"),
                        label = NULL,
                        choices = c("csv" = "csv", "camtrap" = "camtrap"),
                        selected = "csv",
                        inline = TRUE
                    )
                ),
                shiny::tags$button(
                    type = "button",
                    class = "upload-mode-tab",
                    `data-mode` = "csv",
                    `aria-controls` = ns("upload_mode"),
                    ph_icon("file-csv"),
                    shiny::tags$span(
                        class = "upload-mode-tab-title",
                        shiny::uiOutput(ns("mode_csv_title"), inline = TRUE)
                    )
                ),
                shiny::tags$button(
                    type = "button",
                    class = "upload-mode-tab",
                    `data-mode` = "camtrap",
                    `aria-controls` = ns("upload_mode"),
                    ph_icon("box-archive"),
                    shiny::tags$span(
                        class = "upload-mode-tab-title",
                        shiny::uiOutput(ns("mode_camtrap_title"), inline = TRUE)
                    )
                )
            ),
            shiny::tags$script(shiny::HTML(
                "(function(){\n",
                "  if (window.__sairaUploadModeTabsWired) return;\n",
                "  window.__sairaUploadModeTabsWired = true;\n",
                "  document.addEventListener('click', function(e){\n",
                "    var tab = e.target.closest && e.target.closest('.upload-mode-tab');\n",
                "    if (!tab) return;\n",
                "    e.preventDefault();\n",
                "    var wrap = tab.closest('.upload-mode-tabs');\n",
                "    if (!wrap) return;\n",
                "    var mode = tab.getAttribute('data-mode');\n",
                "    var radio = wrap.querySelector('input[type=\"radio\"][value=\"' + mode + '\"]');\n",
                "    if (!radio || radio.checked) return;\n",
                "    radio.checked = true;\n",
                "    radio.dispatchEvent(new Event('change', {bubbles: true}));\n",
                "    radio.focus({preventScroll: true});\n",
                "  });\n",
                "})();"
            )),
            shiny::div(
                id = ns("mode_change_announce"),
                class = "visually-hidden",
                role = "status",
                `aria-live` = "polite",
                shiny::uiOutput(ns("mode_change_text"), inline = TRUE)
            ),
            # File input with dropzone and detached native progress row
            shiny::div(
                class = "upload-section",
                shiny::div(
                    class = "upload-dropzone",
                    shiny::div(
                        class = "upload-dropzone-copy",
                        ph_icon("arrow-up-from-bracket", class = "upload-dropzone-icon", weight = "light"),
                        shiny::div(
                            class = "upload-dropzone-hint",
                            shiny::uiOutput(ns("dropzone_hint_text"), inline = TRUE)
                        ),
                        shiny::div(
                            class = "upload-dropzone-max-size",
                            shiny::uiOutput(ns("max_size_text"), inline = TRUE)
                        )
                    )
                ),
                shiny::div(
                    class = "upload-native-input",
                    shiny::fileInput(
                        inputId = ns("file"),
                        label = shiny::tags$span(tr("a11y_upload_file_label", "pt"), class = "visually-hidden"),
                        accept = c(
                            ".csv", "text/csv",
                            ".tsv", "text/tab-separated-values",
                            ".txt", "text/plain"
                        ),
                        buttonLabel = ph_icon("upload"),
                        placeholder = ""
                    )
                )
            ),
            shiny::div(
                class = "home-upload-notes",
                shiny::div(
                    class = "home-upload-note",
                    ph_icon("code"),
                    shiny::uiOutput(ns("encoding_text"), inline = TRUE)
                ),
                shiny::div(
                    class = "home-upload-note",
                    ph_icon("lock"),
                    shiny::uiOutput(ns("privacy_text"), inline = TRUE)
                )
            ),

            # Stats after upload
            shiny::uiOutput(ns("stats"))
        ),
        shiny::tags$aside(
            class = "home-panel home-requirements-panel",
            shiny::uiOutput(ns("dwc_required"))
        )
    )
}

#' Upload Module Server
#'
#' @param id Module ID
#' @param lang_r Reactive language value
#' @return Reactive data frame with raw data
#' @export
mod_upload_server <- function(id, lang_r) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        # Load dependencies

        # Column 1: Data Section UI
        output$upload_btn_text <- shiny::renderUI({
            shiny::tags$span(tr("upload_btn_label", lang_r()))
        })

        output$file_placeholder_text <- shiny::renderUI({
            shiny::tags$span(tr("upload_no_file", lang_r()))
        })

        output$mode_csv_title <- shiny::renderUI({
            shiny::tags$span(tr("upload_mode_csv_title", lang_r()))
        })

        output$mode_camtrap_title <- shiny::renderUI({
            shiny::tags$span(tr("upload_mode_camtrap_title", lang_r()))
        })

        output$mode_tabs_a11y_label <- shiny::renderUI({
            shiny::tags$span(tr("upload_mode_tabs_a11y_label", lang_r()))
        })

        output$mode_change_text <- shiny::renderUI({
            mode <- input$upload_mode %||% "csv"
            label_key <- if (identical(mode, "camtrap")) {
                "upload_mode_camtrap_title"
            } else {
                "upload_mode_csv_title"
            }
            shiny::tags$span(sprintf(
                tr("a11y_mode_changed", lang_r()),
                tr(label_key, lang_r())
            ))
        })

        output$dropzone_hint_text <- shiny::renderUI({
            mode <- input$upload_mode %||% "csv"
            key <- if (identical(mode, "camtrap")) {
                "upload_camtrap_dropzone_hint"
            } else {
                "upload_dropzone_cta"
            }
            shiny::tags$span(tr(key, lang_r()))
        })

        output$max_size_text <- shiny::renderUI({
            shiny::tags$span(tr("upload_max_size", lang_r()))
        })

        output$encoding_text <- shiny::renderUI({
            shiny::tags$span(tr("upload_encoding_info", lang_r()))
        })

        output$privacy_text <- shiny::renderUI({
            shiny::tags$span(tr("upload_privacy_alert", lang_r()))
        })

        output$home_header <- shiny::renderUI({
            shiny::div(
                class = "home-header",
                shiny::div(class = "home-eyebrow", tr("welcome_eyebrow", lang_r())),
                shiny::tags$h1(class = "home-title", tr("home_title", lang_r()))
            )
        })

        # Required DwC fields aligned with preview readiness checklist
        required_fields <- c(
            "scientificName",
            "eventDate",
            "decimalLatitude",
            "decimalLongitude",
            "basisOfRecord",
            "occurrenceID"
        )
        class_fallback <- c(
            "scientificName" = "Taxon",
            "eventDate" = "Occurrence",
            "decimalLatitude" = "Location",
            "decimalLongitude" = "Location",
            "basisOfRecord" = "Record-level",
            "occurrenceID" = "Occurrence"
        )
        category_order <- c("Record-level", "Occurrence", "Taxon", "Location")
        required_terms_all <- tryCatch(
            get_dwc_terms(),
            error = function(e) {
                warning("[Sa\u00EDra] Failed to load DwC terms: ", e$message)
                data.frame(
                    term = character(0),
                    class = character(0),
                    required = logical(0),
                    definition_pt = character(0),
                    definition_en = character(0),
                    stringsAsFactors = FALSE
                )
            }
        )
        required_terms <- required_terms_all[required_terms_all$term %in% required_fields, , drop = FALSE]
        required_terms <- required_terms[match(required_fields, required_terms$term), , drop = FALSE]
        required_terms <- required_terms[!is.na(required_terms$term), , drop = FALSE]

        # ADR-097: unified scaffold — persistent header plus body that
        # crossfades between CSV (DwC term chips) and Camtrap (file rows).
        output$dwc_required <- shiny::renderUI({
            lang <- lang_r()
            mode <- input$upload_mode %||% "csv"
            body <- if (identical(mode, "camtrap")) {
                upload_camtrap_requirements_ui(lang)
            } else {
                upload_csv_requirements_ui(required_terms, lang)
            }
            title_key <- if (identical(mode, "camtrap")) {
                "upload_format_requirements_title"
            } else {
                "home_required_title"
            }
            shiny::div(
                class = "format-requirements",
                `data-mode` = mode,
                shiny::tags$h2(class = "format-requirements-title", tr(title_key, lang)),
                shiny::div(class = "format-requirements-body", body)
            )
        })

        # ADR-087: classify the upload as data CSV or Saira mapping guide.
        # ADR-095: when the Camtrap DP mode is selected, classify as
        # camtrap_dp if the zip is a valid Frictionless Data Package
        # descriptor bundle.
        # ADR-097: mode state lives in input$upload_mode ("csv" | "camtrap").
        # Reactive depends only on input$file; called at most once per upload.
        file_kind <- shiny::reactive({
            shiny::req(input$file)
            ext <- tolower(tools::file_ext(input$file$name))
            if (identical(input$upload_mode %||% "csv", "camtrap")) {
                if (ext != "zip") return("invalid")
                if (!is_camtrap_dp_zip(input$file$datapath)) return("invalid")
                return("camtrap_dp")
            }
            if (!ext %in% c("csv", "tsv", "txt")) return("invalid")
            if (is_saira_mapping_guide(input$file$datapath)) return("guide")
            if (ext == "txt") return("invalid")  # .txt without magic = bogus
            "data"
        })

        # File Upload Logic — only loads data for CSVs. Guides are handled
        # by the observers below (modal + alias import), and produce NULL
        # so downstream req(raw_data()) keeps the app in "no data" state
        # until the user uploads a real planilha.
        raw_data <- shiny::reactive({
            shiny::req(input$file)

            # The language is read ONCE, isolated: it only picks the wording of
            # notifications and errors, and no parsed value depends on it (every
            # lang argument below lands in a tr() for a message). Taking a
            # reactive dependency on lang_r() here made a language switch
            # invalidate this reactive, re-read the uploaded file from disk and
            # emit a NEW data frame -- which observeEvent(raw_data_r()) in
            # mod_mapping legitimately reads as a fresh upload, wiping the whole
            # mapping, both assistants and the caches. A notification is a
            # point-in-time event; it should not be re-emitted in another
            # language later either.
            lang <- shiny::isolate(lang_r())

            kind <- file_kind()
            if (identical(kind, "invalid")) {
                msg_key <- if (identical(input$upload_mode %||% "csv", "camtrap")) {
                    "err_camtrap_invalid_zip"
                } else {
                    "err_invalid_format"
                }
                shiny::validate(
                    shiny::need(FALSE, tr(msg_key, lang))
                )
            }
            if (identical(kind, "guide")) {
                # The guide flow handles its own UI (modal + import).
                # Return NULL so raw_data behaves as "nothing uploaded yet".
                return(NULL)
            }

            if (identical(kind, "camtrap_dp")) {
                return(tryCatch(
                    {
                        pkg <- read_camtrap_dp_zip(input$file$datapath, lang = lang)
                        df <- convert_camtrap_to_dwc_occurrence(pkg, lang = lang)
                        src <- attr(df, "saira_camtrap_source")
                        src_label <- switch(
                            src %||% "",
                            "wildlife_insights_zip" = tr("upload_camtrap_source_wi", lang),
                            "camtrap_csv_zip" = tr("upload_camtrap_source_camtrap", lang),
                            "datapackage_zip" = tr("upload_camtrap_source_camtrap", lang),
                            ""
                        )
                        msg <- sprintf(tr("upload_camtrap_success", lang), nrow(df))
                        if (nzchar(src_label)) {
                            msg <- paste0(msg, " (", src_label, ")")
                        }
                        shiny::showNotification(
                            msg, type = "message", duration = 4
                        )
                        df
                    },
                    error = function(e) {
                        shiny::showNotification(
                            paste(tr("err_camtrap_invalid_zip", lang), ":", e$message),
                            type = "error",
                            duration = 8
                        )
                        NULL
                    }
                ))
            }

            tryCatch(
                {
                    df <- read_biodiversity_csv(input$file$datapath)
                    shiny::showNotification(
                        tr("success_upload", lang),
                        type = "message",
                        duration = 3
                    )
                    return(df)
                },
                error = function(e) {
                    shiny::showNotification(
                        paste(tr("err_read_failed", lang), ":", e$message),
                        type = "error",
                        duration = 5
                    )
                    return(NULL)
                }
            )
        })

        # ADR-087: when a Saira mapping guide is uploaded, parse it and ask
        # the user whether to import its (col -> term) pairs as personal
        # aliases in the local rostrum.sqlite. The actual import runs on
        # the confirmation observer below.
        guide_payload_rv <- shiny::reactiveVal(NULL)

        shiny::observeEvent(file_kind(), {
            if (!identical(file_kind(), "guide")) {
                guide_payload_rv(NULL)
                return(invisible(NULL))
            }

            payload <- tryCatch(
                parse_mapping_guide_txt(input$file$datapath),
                error = function(e) e
            )
            if (inherits(payload, "error")) {
                guide_payload_rv(NULL)
                shiny::showNotification(
                    sprintf(tr("upload_guide_invalid", lang_r()), conditionMessage(payload)),
                    type = "error",
                    duration = 8
                )
                return(invisible(NULL))
            }

            n_pairs <- if (is.data.frame(payload$pairs)) nrow(payload$pairs) else 0L
            guide_payload_rv(payload)

            shiny::showModal(shiny::modalDialog(
                title = tr("upload_guide_detected_title", lang_r()),
                shiny::p(
                    sprintf(tr("upload_guide_detected_message", lang_r()), n_pairs)
                ),
                easyClose = TRUE,
                footer = shiny::tagList(
                    shiny::modalButton(tr("upload_guide_cancel_btn", lang_r())),
                    shiny::actionButton(
                        ns("confirm_guide_import"),
                        tr("upload_guide_import_btn", lang_r()),
                        class = "btn-primary"
                    )
                )
            ))
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$confirm_guide_import, {
            payload <- guide_payload_rv()
            shiny::removeModal()
            if (is.null(payload)) return(invisible(NULL))

            n_imported <- tryCatch(
                import_mapping_guide_to_aliases(payload),
                error = function(e) e
            )
            if (inherits(n_imported, "error")) {
                shiny::showNotification(
                    sprintf(tr("upload_guide_failed", lang_r()), conditionMessage(n_imported)),
                    type = "error",
                    duration = 10
                )
                return(invisible(NULL))
            }

            guide_payload_rv(NULL)
            shiny::showNotification(
                sprintf(tr("upload_guide_success", lang_r()), as.integer(n_imported)),
                type = "message",
                duration = 8
            )
        }, ignoreInit = TRUE)

        # Display stats after upload
        output$stats <- shiny::renderUI({
            shiny::req(raw_data())
            shiny::req(input$file)

            df <- raw_data()

            # Calculate file size
            file_size_bytes <- file.info(input$file$datapath)$size
            file_size_mb <- round(file_size_bytes / (1024 * 1024), 1)
            file_size_str <- paste0(file_size_mb, " MB")

            shiny::div(
                class = "stats-container",
                shiny::div(
                    class = "stat-box",
                    shiny::div(class = "stat-value", format_count(nrow(df), lang_r())),
                    shiny::div(class = "stat-label", tr("upload_stats_rows", lang_r()))
                ),
                shiny::div(
                    class = "stat-box",
                    shiny::div(class = "stat-value", ncol(df)),
                    shiny::div(class = "stat-label", tr("upload_stats_cols", lang_r()))
                ),
                shiny::div(
                    class = "stat-box",
                    shiny::div(class = "stat-value", file_size_str),
                    shiny::div(class = "stat-label", tr("upload_stats_size", lang_r()))
                )
            )
        })

        # Explicit return
        return(raw_data)
    })
}
