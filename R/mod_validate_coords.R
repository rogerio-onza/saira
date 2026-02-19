# Title: Validate Coordinates Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-13
# Version: 1.1

#' Validate Coordinates Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_validate_coords_ui <- function(id) {
    ns <- shiny::NS(id)

    shiny::tagList(
        shiny::div(
            class = "container-fluid",
            style = "max-width: 1000px;",
            shiny::uiOutput(ns("title")),
            shiny::uiOutput(ns("subtitle")),
            shiny::br(),

            # Action button
            shiny::actionButton(
                inputId = ns("validate"),
                label = shiny::uiOutput(ns("btn_label")),
                class = "btn-primary mb-4",
                icon = shiny::icon("map-marker-alt")
            ),

            # Stats
            shiny::uiOutput(ns("stats")),

            # Results
            shiny::uiOutput(ns("results"))
        )
    )
}

#' Validate Coordinates Module Server
#'
#' @param id Module ID
#' @param mapped_data_r Reactive data frame with mapped data
#' @param lang_r Reactive language value
#' @export
mod_validate_coords_server <- function(id, mapped_data_r, lang_r) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        validation_result <- shiny::reactiveVal(NULL)

        output$title <- shiny::renderUI({
            shiny::h3(tr("validate_coords_title", lang_r()), class = "text-mono")
        })

        output$subtitle <- shiny::renderUI({
            shiny::p(tr("validate_coords_subtitle", lang_r()), class = "text-accent")
        })

        output$btn_label <- shiny::renderUI({
            tr("validate_coords_run", lang_r())
        })

        shiny::observeEvent(input$validate, {
            shiny::req(mapped_data_r())

            df <- mapped_data_r()

            has_lat <- "decimalLatitude" %in% names(df)
            has_lon <- "decimalLongitude" %in% names(df)

            if (!has_lat || !has_lon) {
                shiny::showNotification(
                    tr("validate_coords_missing_columns", lang_r()),
                    type = "warning"
                )
                return()
            }

            result <- validate_coords(
                lat = df$decimalLatitude,
                lon = df$decimalLongitude
            )

            validation_result(result)
        })

        output$stats <- shiny::renderUI({
            res <- validation_result()
            if (is.null(res)) {
                return(NULL)
            }

            valid_count <- sum(res$valid, na.rm = TRUE)
            invalid_count <- sum(!res$valid & !is.na(res$valid), na.rm = TRUE)
            missing_count <- sum(is.na(res$valid))

            shiny::fluidRow(
                class = "mb-4",
                shiny::column(
                    width = 4,
                    shiny::div(
                        class = "stat-box",
                        shiny::div(class = "stat-value", style = "color: var(--success);", valid_count),
                        shiny::div(class = "stat-label", tr("validate_coords_valid", lang_r()))
                    )
                ),
                shiny::column(
                    width = 4,
                    shiny::div(
                        class = "stat-box",
                        shiny::div(class = "stat-value", style = "color: var(--error);", invalid_count),
                        shiny::div(class = "stat-label", tr("validate_coords_invalid", lang_r()))
                    )
                ),
                shiny::column(
                    width = 4,
                    shiny::div(
                        class = "stat-box",
                        shiny::div(class = "stat-value", style = "color: var(--warning);", missing_count),
                        shiny::div(class = "stat-label", tr("validate_coords_missing", lang_r()))
                    )
                )
            )
        })

        output$results <- shiny::renderUI({
            res <- validation_result()
            if (is.null(res)) {
                return(NULL)
            }

            issues <- res[!res$valid | is.na(res$valid), ]

            if (nrow(issues) == 0) {
                shiny::div(
                    class = "alert alert-success",
                    shiny::icon("check-circle"),
                    " ",
                    tr("validate_coords_all_valid", lang_r())
                )
            } else {
                shiny::div(
                    class = "finch-table-shell",
                    DT::dataTableOutput(ns("issues_table"))
                )
            }
        })

        output$issues_table <- DT::renderDataTable({
            res <- validation_result()
            shiny::req(res)

            issues <- res[!res$valid | is.na(res$valid), ]

            DT::datatable(
                issues,
                options = list(
                    pageLength = 10,
                    lengthMenu = c(10, 25, 50, 100),
                    scrollX = TRUE,
                    autoWidth = FALSE,
                    language = list(
                        search = tr("validate_coords_datatable_search", lang_r()),
                        lengthMenu = tr("validate_coords_datatable_length_menu", lang_r()),
                        info = tr("validate_coords_datatable_info", lang_r()),
                        emptyTable = tr("validate_coords_datatable_empty", lang_r()),
                        zeroRecords = tr("validate_coords_datatable_zero_records", lang_r()),
                        paginate = list(
                            first = tr("validate_coords_datatable_first", lang_r()),
                            last = tr("validate_coords_datatable_last", lang_r()),
                            `next` = tr("validate_coords_datatable_next", lang_r()),
                            previous = tr("validate_coords_datatable_prev", lang_r())
                        )
                    )
                ),
                class = "display compact stripe",
                rownames = FALSE
            )
        })
    })
}
