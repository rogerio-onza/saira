# Title: Upload Module
# Author: RogÃ©rio Nunes Oliveira
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
                            # File input with icon-only button
                            shiny::div(
                                class = "upload-section",
                                shiny::fileInput(
                                    inputId = ns("file"),
                                    label = NULL,
                                    accept = c(".csv", "text/csv"),
                                    buttonLabel = shiny::icon("upload", class = "fa-solid"),
                                    placeholder = ""
                                )
                            ),

                            # File specifications box
                            shiny::div(
                                class = "file-specs-box",
                                shiny::tags$p(
                                    shiny::icon("file", class = "fa-solid"),
                                    shiny::uiOutput(ns("max_size_text"), inline = TRUE)
                                ),
                                shiny::tags$p(
                                    shiny::icon("code", class = "fa-solid"),
                                    shiny::uiOutput(ns("encoding_text"), inline = TRUE)
                                )
                            ),

                            # Privacy alert
                            shiny::div(
                                class = "alert alert-info privacy-alert",
                                shiny::icon("lock", class = "fa-solid"),
                                shiny::uiOutput(ns("privacy_text"), inline = TRUE)
                            ),

                            # Recommendations
                            shiny::div(
                                class = "recommendation-box",
                                shiny::icon("lightbulb", class = "fa-solid"),
                                shiny::uiOutput(ns("recommendation_text"), inline = TRUE)
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
                        bslib::card_header(
                            shiny::uiOutput(ns("welcome_title"))
                        ),
                        bslib::card_body(
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
                                    class = "workflow-step",
                                    shiny::div(class = "step-icon", shiny::icon("upload", class = "fa-solid")),
                                    shiny::div(
                                        class = "step-content",
                                        shiny::uiOutput(ns("step1_title"), inline = TRUE),
                                        shiny::tags$small(shiny::uiOutput(ns("step1_desc")))
                                    )
                                ),
                                # Step 2
                                shiny::div(
                                    class = "workflow-step",
                                    shiny::div(class = "step-icon", shiny::icon("arrows-alt", class = "fa-solid")),
                                    shiny::div(
                                        class = "step-content",
                                        shiny::uiOutput(ns("step2_title"), inline = TRUE),
                                        shiny::tags$small(shiny::uiOutput(ns("step2_desc")))
                                    )
                                ),
                                # Step 3
                                shiny::div(
                                    class = "workflow-step",
                                    shiny::div(class = "step-icon", shiny::icon("check-circle", class = "fa-solid")),
                                    shiny::div(
                                        class = "step-content",
                                        shiny::uiOutput(ns("step3_title"), inline = TRUE),
                                        shiny::tags$small(shiny::uiOutput(ns("step3_desc")))
                                    )
                                ),
                                # Step 4
                                shiny::div(
                                    class = "workflow-step",
                                    shiny::div(class = "step-icon", shiny::icon("download", class = "fa-solid")),
                                    shiny::div(
                                        class = "step-content",
                                        shiny::uiOutput(ns("step4_title"), inline = TRUE),
                                        shiny::tags$small(shiny::uiOutput(ns("step4_desc")))
                                    )
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
        output$welcome_title <- shiny::renderUI({
            shiny::h3(tr("welcome_title", lang_r()), class = "text-mono")
        })

        output$welcome_description <- shiny::renderUI({
            shiny::p(tr("welcome_description", lang_r()), class = "text-accent")
        })

        output$workflow_title <- shiny::renderUI({
            shiny::tags$span(tr("workflow_title", lang_r()))
        })

        output$step1_title <- shiny::renderUI({
            shiny::tags$strong(tr("workflow_step1", lang_r()))
        })
        output$step1_desc <- shiny::renderUI({
            shiny::tags$span(tr("workflow_step1_desc", lang_r()))
        })

        output$step2_title <- shiny::renderUI({
            shiny::tags$strong(tr("workflow_step2", lang_r()))
        })
        output$step2_desc <- shiny::renderUI({
            shiny::tags$span(tr("workflow_step2_desc", lang_r()))
        })

        output$step3_title <- shiny::renderUI({
            shiny::tags$strong(tr("workflow_step3", lang_r()))
        })
        output$step3_desc <- shiny::renderUI({
            shiny::tags$span(tr("workflow_step3_desc", lang_r()))
        })

        output$step4_title <- shiny::renderUI({
            shiny::tags$strong(tr("workflow_step4", lang_r()))
        })
        output$step4_desc <- shiny::renderUI({
            shiny::tags$span(tr("workflow_step4_desc", lang_r()))
        })

        # Required DwC fields (static guidance)
        required_terms <- get_required_dwc_terms()

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
                "Event" = tr("class_event", lang),
                "Location" = tr("class_location", lang),
                "Identification" = tr("class_identification", lang),
                "Taxon" = tr("class_taxon", lang)
            )

            classes_order <- unique(required_terms$class)

            groups_ui <- lapply(classes_order, function(class_name) {
                group_df <- required_terms[required_terms$class == class_name, , drop = FALSE]
                group_label <- if (!is.null(class_labels[[class_name]])) class_labels[[class_name]] else class_name

                chips <- lapply(seq_len(nrow(group_df)), function(i) {
                    term <- group_df$term[i]
                    definition <- if (lang == "pt") group_df$definition_pt[i] else group_df$definition_en[i]

                    shiny::tags$span(
                        class = "dwc-term-chip",
                        title = definition,
                        term
                    )
                })

                shiny::div(
                    class = "dwc-group",
                    shiny::div(class = "dwc-group-title", group_label),
                    shiny::div(class = "dwc-group-list", chips)
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
                    class = "dwc-required-groups",
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
