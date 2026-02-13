# Title: Preview Module
# Author: RogÃ©rio Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

#' Preview Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_preview_ui <- function(id) {
    ns <- shiny::NS(id)

    shiny::tagList(
        shiny::div(
            class = "container-fluid",
            shiny::uiOutput(ns("title")),
            shiny::uiOutput(ns("subtitle")),
            shiny::br(),

            # Download button
            shiny::div(
                class = "mb-4",
                shiny::downloadButton(
                    outputId = ns("download"),
                    label = shiny::uiOutput(ns("download_label")),
                    class = "btn-success"
                )
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
#' @return Reactive preview data frame
#' @export
mod_preview_server <- function(id, mapped_data_r, lang_r) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        # Load dependencies

        # Dynamic UI elements
        output$title <- shiny::renderUI({
            shiny::h3(tr("preview_title", lang_r()), class = "text-mono")
        })

        output$subtitle <- shiny::renderUI({
            shiny::p(tr("preview_subtitle", lang_r()), class = "text-accent")
        })

        output$download_label <- shiny::renderUI({
            shiny::tags$span(
                shiny::icon("download"),
                tr("preview_download", lang_r())
            )
        })

        # Preview data: First 100 rows only (fast, vectorized)
        preview_data <- shiny::reactive({
            shiny::req(mapped_data_r())
            preview_df <- utils::head(mapped_data_r(), 100)
            preview_df <- abbreviate_license_column(preview_df)
            preview_df
        })

        # Render table or message
        output$table_or_message <- shiny::renderUI({
            if (is.null(mapped_data_r()) || ncol(mapped_data_r()) == 0) {
                shiny::div(
                    class = "alert alert-info",
                    shiny::icon("info-circle"),
                    " ",
                    tr("preview_no_data", lang_r())
                )
            } else {
                DT::dataTableOutput(ns("datatable"))
            }
        })

        # Data table output
        output$datatable <- DT::renderDataTable({
            shiny::req(preview_data())

            DT::datatable(
                preview_data(),
                options = list(
                    pageLength = 25,
                    scrollX = TRUE,
                    language = list(
                        search = tr("wiki_search", lang_r()),
                        lengthMenu = paste(
                            if (lang_r() == "pt") "Mostrar _MENU_ registros" else "Show _MENU_ entries"
                        ),
                        info = if (lang_r() == "pt") {
                            "Mostrando _START_ a _END_ de _TOTAL_ registros"
                        } else {
                            "Showing _START_ to _END_ of _TOTAL_ entries"
                        }
                    )
                ),
                class = "display compact",
                rownames = FALSE
            )
        })

        # Download handler - Full processing
        output$download <- shiny::downloadHandler(
            filename = function() {
                paste0("dwc_export_", Sys.Date(), ".csv")
            },
            content = function(file) {
                shiny::req(mapped_data_r())

                # Process full data for export
                full_data <- process_for_export(mapped_data_r())

                # Write CSV
                readr::write_csv(full_data, file, na = "")

                shiny::showNotification(
                    tr("success_download", lang_r()),
                    type = "message"
                )
            }
        )

        # Explicit return
        return(preview_data)
    })
}
