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

    shiny::tagList(
        shiny::div(
            class = "container-fluid homepage-container",
            shiny::fluidRow(
                # Column 1: Data Upload Section
                shiny::column(
                    width = 5,
                    bslib::card(
                        bslib::card_header(
                            shiny::uiOutput(ns("data_title"))
                        ),
                        bslib::card_body(
                            # File input with dropzone and detached native progress row
                            shiny::div(
                                class = "upload-section",
                                shiny::div(
                                    class = "upload-dropzone",
                                    shiny::div(
                                        class = "upload-dropzone-copy",
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
                                        accept = c(".csv", "text/csv"),
                                        buttonLabel = shiny::icon("upload", class = "fa-solid"),
                                        placeholder = ""
                                    )
                                )
                            ),
                            # Upload info chips
                            shiny::div(
                                class = "upload-info-chips",
                            shiny::div(
                                class = "upload-info-chip upload-info-chip--neutral",
                                shiny::icon("code", class = "fa-solid upload-info-chip-icon"),
                                shiny::uiOutput(ns("encoding_text"), inline = TRUE)
                            ),
                            shiny::div(
                                class = "upload-info-chip upload-info-chip--privacy",
                                shiny::icon("lock", class = "fa-solid upload-info-chip-icon"),
                                shiny::uiOutput(ns("privacy_text"), inline = TRUE)
                            ),
                            shiny::div(
                                class = "upload-info-chip upload-info-chip--tip",
                                shiny::icon("lightbulb", class = "fa-solid upload-info-chip-icon"),
                                shiny::uiOutput(ns("recommendation_text"), inline = TRUE)
                            )
                            ),

                            # Stats after upload
                            shiny::uiOutput(ns("stats"))
                        )
                    )
                ),

                # Column 2: Welcome Section
                shiny::column(
                    width = 7,
                    bslib::card(
                        bslib::card_body(
                            shiny::uiOutput(ns("welcome_header")),

                            # Description
                            shiny::uiOutput(ns("welcome_description")),

                            # Workflow section
                            shiny::tags$h5(
                                shiny::icon("diagram-project", class = "fa-solid"),
                                shiny::uiOutput(ns("workflow_title"), inline = TRUE),
                                class = "text-mono mt-4 mb-3"
                            ),
                            shiny::div(
                                class = "workflow-steps",
                                # Step 1
                                shiny::div(
                                    class = "workflow-step is-active",
                                    shiny::div(class = "step-icon", shiny::icon("upload", class = "fa-solid")),
                                    shiny::div(class = "step-label", shiny::uiOutput(ns("step1_title"), inline = TRUE)),
                                    shiny::div(class = "step-sublabel", shiny::uiOutput(ns("step1_desc"), inline = TRUE))
                                ),
                                # Step 2
                                shiny::div(
                                    class = "workflow-step",
                                    shiny::div(class = "step-icon", shiny::icon("arrows-alt", class = "fa-solid")),
                                    shiny::div(class = "step-label", shiny::uiOutput(ns("step2_title"), inline = TRUE)),
                                    shiny::div(class = "step-sublabel", shiny::uiOutput(ns("step2_desc"), inline = TRUE))
                                ),
                                # Step 3
                                shiny::div(
                                    class = "workflow-step",
                                    shiny::div(class = "step-icon", shiny::icon("check-circle", class = "fa-solid")),
                                    shiny::div(class = "step-label", shiny::uiOutput(ns("step3_title"), inline = TRUE)),
                                    shiny::div(class = "step-sublabel", shiny::uiOutput(ns("step3_desc"), inline = TRUE))
                                ),
                                # Step 4
                                shiny::div(
                                    class = "workflow-step",
                                    shiny::div(class = "step-icon", shiny::icon("download", class = "fa-solid")),
                                    shiny::div(class = "step-label", shiny::uiOutput(ns("step4_title"), inline = TRUE)),
                                    shiny::div(class = "step-sublabel", shiny::uiOutput(ns("step4_desc"), inline = TRUE))
                                )
                            ),

                            # Required DwC fields
                            shiny::uiOutput(ns("dwc_required"))
                        )
                    )
                )
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
        output$data_title <- shiny::renderUI({
            shiny::h3(
                shiny::icon("database", class = "fa-solid"),
                tr("upload_data_title", lang_r()),
                class = "text-mono"
            )
        })

        output$upload_btn_text <- shiny::renderUI({
            shiny::tags$span(tr("upload_btn_label", lang_r()))
        })

        output$file_placeholder_text <- shiny::renderUI({
            shiny::tags$span(tr("upload_no_file", lang_r()))
        })

        output$dropzone_hint_text <- shiny::renderUI({
            shiny::tags$span(tr("upload_dropzone_cta", lang_r()))
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

        output$recommendation_text <- shiny::renderUI({
            shiny::tags$span(tr("upload_recommendation", lang_r()))
        })

        # Column 2: Welcome Section UI
        output$welcome_header <- shiny::renderUI({
            shiny::div(
                class = "welcome-header",
                shiny::div(
                    class = "welcome-eyebrow",
                    tr("welcome_eyebrow", lang_r())
                ),
                shiny::tags$h1(
                    class = "welcome-main-title",
                    tr("welcome_title_prefix", lang_r()),
                    " ",
                    shiny::tags$span("Sa\u00EDra", class = "welcome-main-title-brand")
                )
            )
        })

        output$welcome_description <- shiny::renderUI({
            shiny::p(tr("welcome_description", lang_r()), class = "text-accent")
        })

        output$workflow_title <- shiny::renderUI({
            shiny::tags$span(tr("workflow_title", lang_r()))
        })

        output$step1_title <- shiny::renderUI({
            shiny::tags$span(tr("workflow_step1", lang_r()))
        })
        output$step1_desc <- shiny::renderUI({
            shiny::tags$span(tr("workflow_step1_desc", lang_r()))
        })

        output$step2_title <- shiny::renderUI({
            shiny::tags$span(tr("workflow_step2", lang_r()))
        })
        output$step2_desc <- shiny::renderUI({
            shiny::tags$span(tr("workflow_step2_desc", lang_r()))
        })

        output$step3_title <- shiny::renderUI({
            shiny::tags$span(tr("workflow_step3", lang_r()))
        })
        output$step3_desc <- shiny::renderUI({
            shiny::tags$span(tr("workflow_step3_desc", lang_r()))
        })

        output$step4_title <- shiny::renderUI({
            shiny::tags$span(tr("workflow_step4", lang_r()))
        })
        output$step4_desc <- shiny::renderUI({
            shiny::tags$span(tr("workflow_step4_desc", lang_r()))
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
                message("[Sa\u00EDra] Failed to load DwC terms: ", e$message)
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

        output$dwc_required <- shiny::renderUI({
            lang <- lang_r()

            if (nrow(required_terms) == 0) {
                return(shiny::div(
                    class = "alert alert-warning",
                    shiny::icon("exclamation-triangle"),
                    " ",
                    tr("dwc_required_empty", lang)
                ))
            }

            class_labels <- c(
                "Record-level" = tr("class_record", lang),
                "Occurrence" = tr("class_occurrence", lang),
                "Location" = tr("class_location", lang),
                "Taxon" = tr("class_taxon", lang)
            )
            required_terms_view <- required_terms
            fallback_classes <- unname(class_fallback[required_terms_view$term])
            invalid_class <- !required_terms_view$class %in% names(class_labels)
            required_terms_view$class[invalid_class] <- fallback_classes[invalid_class]
            required_terms_view$class[is.na(required_terms_view$class)] <- "Record-level"
            categories_available <- category_order[category_order %in% unique(required_terms_view$class)]

            groups_ui <- lapply(categories_available, function(category_name) {
                category_label <- class_labels[[category_name]]
                group_df <- required_terms_view[required_terms_view$class == category_name, , drop = FALSE]
                category_slug <- switch(
                    category_name,
                    "Record-level" = "record-level",
                    "Occurrence" = "occurrence",
                    "Taxon" = "taxon",
                    "Location" = "location",
                    "record-level"
                )

                chips_ui <- lapply(seq_len(nrow(group_df)), function(i) {
                    term <- group_df$term[i]
                    definition <- if (lang == "pt") group_df$definition_pt[i] else group_df$definition_en[i]

                    shiny::tags$span(
                        class = "dwc-term-chip",
                        title = if (is.na(definition)) "" else definition,
                        term
                    )
                })

                shiny::div(
                    class = paste("dwc-inline-group", paste0("dwc-inline-group--", category_slug)),
                    shiny::div(
                        class = paste("dwc-inline-group-label", paste0("dwc-group-badge--", category_slug)),
                        category_label
                    ),
                    shiny::div(class = "dwc-term-chip-list", chips_ui)
                )
            })

            shiny::div(
                class = "dwc-required",
                shiny::tags$h5(
                    shiny::icon("list-check", class = "fa-solid"),
                    " ",
                    tr("dwc_required_title", lang),
                    class = "text-mono mb-2"
                ),
                shiny::tags$p(
                    tr("dwc_required_hint", lang),
                    class = "dwc-required-hint"
                ),
                shiny::div(
                    class = "dwc-inline-groups",
                    groups_ui
                )
            )
        })

        # File Upload Logic
        raw_data <- shiny::reactive({
            shiny::req(input$file)

            # Validate file extension
            ext <- tools::file_ext(input$file$name)
            shiny::validate(
                shiny::need(
                    tolower(ext) == "csv",
                    tr("err_invalid_format", lang_r())
                )
            )

            # Read file using utility function
            tryCatch(
                {
                    df <- read_biodiversity_csv(input$file$datapath)

                    # Show success notification
                    shiny::showNotification(
                        tr("success_upload", lang_r()),
                        type = "message",
                        duration = 3
                    )

                    return(df)
                },
                error = function(e) {
                    shiny::showNotification(
                        paste(tr("err_read_failed", lang_r()), ":", e$message),
                        type = "error",
                        duration = 5
                    )
                    return(NULL)
                }
            )
        })

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
                    shiny::div(class = "stat-value", format(nrow(df), big.mark = ".")),
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
