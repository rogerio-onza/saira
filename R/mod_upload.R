# Title: Upload Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-08
# Version: 3.0 - One upload panel across the page

#' Upload Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_upload_ui <- function(id) {
    ns <- shiny::NS(id)

    # Home: header, format cards and dropzone on the page, then the notes
    # (ADR-136). The text outputs start with the Portuguese content, which is
    # the default language, so the home shows before the server is ready.
    shiny::div(
        class = "container-fluid homepage-container home-b",
        shiny::tags$section(
            class = "home-upload-panel",
            # The bird sits on the bottom edge of this block, so its branch
            # touches the top border of the dropzone.
            shiny::div(
                class = "home-top",
                prefilled_ui_output(ns("home_header"), home_header_ui("pt")),
                shiny::tags$img(
                    src = "www/images/saira_bird.webp",
                    class = "home-bird",
                    alt = "",
                    `aria-hidden` = "true",
                    width = 640,
                    height = 407
                ),
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
                        prefilled_ui_output(
                            ns("mode_tabs_a11y_label"),
                            shiny::tags$span(tr("upload_mode_tabs_a11y_label", "pt")),
                            inline = TRUE
                        )
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
                            class = "upload-mode-tab-text",
                            shiny::tags$span(
                                class = "upload-mode-tab-title",
                                prefilled_ui_output(
                                    ns("mode_csv_title"),
                                    shiny::tags$span(tr("upload_mode_csv_title", "pt")),
                                    inline = TRUE
                                )
                            ),
                            shiny::tags$span(class = "upload-mode-tab-sub", "CSV \u00B7 XLSX \u00B7 TXT")
                        )
                    ),
                    shiny::tags$button(
                        type = "button",
                        class = "upload-mode-tab",
                        `data-mode` = "camtrap",
                        `aria-controls` = ns("upload_mode"),
                        ph_icon("box-archive"),
                        shiny::tags$span(
                            class = "upload-mode-tab-text",
                            shiny::tags$span(
                                class = "upload-mode-tab-title",
                                prefilled_ui_output(
                                    ns("mode_camtrap_title"),
                                    shiny::tags$span(tr("upload_mode_camtrap_title", "pt")),
                                    inline = TRUE
                                )
                            ),
                            shiny::tags$span(class = "upload-mode-tab-sub", "ZIP")
                        )
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
                # The dropzone is the only file picker, so it takes keyboard
                # focus (upload-dropzone.js opens the picker on Enter/Space).
                shiny::div(
                    class = "upload-dropzone",
                    tabindex = "0",
                    role = "button",
                    `aria-labelledby` = ns("dropzone_hint_text"),
                    shiny::div(
                        class = "upload-dropzone-copy",
                        ph_icon("arrow-up-from-bracket", class = "upload-dropzone-icon"),
                        prefilled_ui_output(
                            ns("dropzone_hint_text"),
                            home_dropzone_hint_ui("csv", "pt")
                        ),
                        shiny::div(
                            class = "upload-dropzone-max-size",
                            prefilled_ui_output(
                                ns("max_size_text"),
                                shiny::tags$span(tr("upload_max_size", "pt")),
                                inline = TRUE
                            )
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
                            ".txt", "text/plain",
                            ".xlsx",
                            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                        ),
                        buttonLabel = ph_icon("upload"),
                        placeholder = ""
                    )
                )
            ),

            # Stats after upload
            shiny::uiOutput(ns("stats"), class = "home-stats"),
            prefilled_ui_output(
                ns("upload_notes"),
                home_notes_ui("csv", "pt"),
                class = "home-before"
            )
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
            home_dropzone_hint_ui(input$upload_mode %||% "csv", lang_r())
        })

        output$max_size_text <- shiny::renderUI({
            shiny::tags$span(tr("upload_max_size", lang_r()))
        })

        output$home_header <- shiny::renderUI({
            home_header_ui(lang_r())
        })

        # Label for Shiny's own progress bar, which writes "Upload complete"
        # in English (upload-dropzone.js swaps it).
        shiny::observe({
            session$sendCustomMessage(
                "saira-upload-complete-label",
                list(label = tr("upload_complete_label", lang_r()))
            )
        })

        # Notes under the dropzone, for the selected mode.
        output$upload_notes <- shiny::renderUI({
            home_notes_ui(input$upload_mode %||% "csv", lang_r())
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
            if (ext == "xlsx") return("data")
            if (!ext %in% c("csv", "tsv", "txt")) return("invalid")
            if (is_saira_mapping_guide(input$file$datapath)) return("guide")
            "data"
        })

        invalid_upload_msg_key <- function() {
            if (identical(input$upload_mode %||% "csv", "camtrap")) {
                "err_camtrap_invalid_zip"
            } else {
                "err_invalid_format"
            }
        }

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
                shiny::validate(
                    shiny::need(FALSE, tr(invalid_upload_msg_key(), lang))
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
                    df <- if (identical(tolower(tools::file_ext(input$file$name)), "xlsx")) {
                        read_biodiversity_xlsx(input$file$datapath)
                    } else {
                        read_biodiversity_csv(input$file$datapath)
                    }
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
            shiny::req(input$file)
            # Without this the validate() in raw_data() shows the message as
            # plain grey text, which reads as a hint and not as an error.
            if (identical(file_kind(), "invalid")) {
                return(shiny::div(
                    class = "alert alert-danger upload-format-error",
                    role = "alert",
                    ph_icon("triangle-exclamation"),
                    shiny::tags$span(tr(invalid_upload_msg_key(), lang_r()))
                ))
            }
            shiny::req(raw_data())

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

# Home content builders. The server renders them in the current language, and
# mod_upload_ui() renders them in Portuguese as the first content.
home_header_ui <- function(lang) {
    shiny::div(
        class = "home-header",
        shiny::div(class = "home-eyebrow", tr("welcome_eyebrow", lang)),
        shiny::tags$h1(class = "home-title", tr("home_title", lang)),
        shiny::tags$p(class = "home-subtitle", tr("home_subtitle", lang))
    )
}

home_dropzone_hint_ui <- function(mode, lang) {
    camtrap <- identical(mode, "camtrap")
    key <- if (camtrap) "upload_camtrap_dropzone_hint" else "upload_dropzone_cta"
    formats <- if (camtrap) "ZIP" else "CSV \u00B7 XLSX \u00B7 TXT"
    shiny::tagList(
        shiny::tags$h2(class = "upload-dropzone-title", tr(key, lang)),
        shiny::div(class = "upload-dropzone-hint", tr("upload_dropzone_click", lang)),
        shiny::div(class = "upload-dropzone-formats", formats)
    )
}

home_notes_ui <- function(mode, lang) {
    # Text between backticks is a format token and shows in mono. One HTML
    # string, so no whitespace goes between a token and a comma.
    tokens <- function(text) {
        parts <- htmltools::htmlEscape(strsplit(text, "`", fixed = TRUE)[[1]])
        even <- seq_along(parts) %% 2 == 0
        parts[even] <- sprintf('<span class="home-note-token">%s</span>', parts[even])
        shiny::HTML(paste(parts, collapse = ""))
    }
    note <- function(icon, key) {
        shiny::div(
            class = "home-note",
            ph_icon(icon, class = "home-note-icon"),
            shiny::div(class = "home-note-title", tr(paste0("home_note_", key, "_title"), lang)),
            shiny::div(class = "home-note-text", tokens(tr(paste0("home_note_", key, "_text"), lang)))
        )
    }
    notes <- if (identical(mode, "camtrap")) {
        list(
            note("box-archive", "camtrap_format"),
            note("file-zipper", "camtrap_files"),
            note("lock", "privacy")
        )
    } else {
        list(
            note("file-lines", "formats"),
            note("code", "encoding"),
            note("table-list", "separator"),
            note("file-import", "guide"),
            note("lock", "privacy")
        )
    }
    shiny::tagList(
        shiny::tags$h3(class = "home-section-title", tr("home_before_title", lang)),
        shiny::div(class = "home-notes-grid", notes)
    )
}

# A uiOutput that shows `content` until the server sends its first value.
prefilled_ui_output <- function(id, content, inline = FALSE, ...) {
    out <- shiny::uiOutput(id, inline = inline, ...)
    out$children <- list(content)
    out
}
