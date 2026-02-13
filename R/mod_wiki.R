# Title: Wiki Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-13
# Version: 1.1

#' Wiki Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_wiki_ui <- function(id) {
    ns <- shiny::NS(id)

    shiny::tagList(
        shiny::div(
            class = "container-fluid",
            shiny::uiOutput(ns("title")),
            shiny::uiOutput(ns("subtitle")),
            shiny::br(),

            # Search and filters
            shiny::fluidRow(
                shiny::column(
                    width = 6,
                    shiny::uiOutput(ns("search_input"))
                ),
                shiny::column(
                    width = 6,
                    shiny::uiOutput(ns("class_filter_input"))
                )
            ),

            # Terms table
            DT::dataTableOutput(ns("terms_table"))
        )
    )
}

#' Wiki Module Server
#'
#' @param id Module ID
#' @param lang_r Reactive language value
#' @export
mod_wiki_server <- function(id, lang_r) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        dwc_terms <- get_dwc_terms()
        class_values <- c("", "Record-level", "Occurrence", "Event", "Location", "Identification", "Taxon")

        class_labels <- shiny::reactive({
            c(
                tr("wiki_class_all", lang_r()),
                tr("class_record", lang_r()),
                tr("class_occurrence", lang_r()),
                tr("class_event", lang_r()),
                tr("class_location", lang_r()),
                tr("class_identification", lang_r()),
                tr("class_taxon", lang_r())
            )
        })

        output$title <- shiny::renderUI({
            shiny::h3(tr("wiki_title", lang_r()), class = "text-mono")
        })

        output$subtitle <- shiny::renderUI({
            shiny::p(tr("wiki_subtitle", lang_r()), class = "text-accent")
        })

        output$search_input <- shiny::renderUI({
            shiny::textInput(
                inputId = ns("search"),
                label = NULL,
                placeholder = tr("wiki_search_placeholder", lang_r()),
                width = "100%"
            )
        })

        output$class_filter_input <- shiny::renderUI({
            current_value <- input$class_filter
            if (is.null(current_value)) {
                current_value <- ""
            }

            shiny::selectInput(
                inputId = ns("class_filter"),
                label = NULL,
                choices = stats::setNames(class_values, class_labels()),
                selected = current_value,
                width = "100%"
            )
        })

        filtered_terms <- shiny::reactive({
            df <- dwc_terms

            if (!is.null(input$class_filter) && input$class_filter != "") {
                df <- df[df$class == input$class_filter, ]
            }

            if (!is.null(input$search) && nchar(input$search) > 0) {
                search_term <- tolower(input$search)
                df <- df[
                    grepl(search_term, tolower(df$term)) |
                        grepl(search_term, tolower(df$definition_pt)) |
                        grepl(search_term, tolower(df$definition_en)),
                ]
            }

            definition_col <- switch(
                lang_r(),
                pt = "definition_pt",
                en = "definition_en",
                "definition_en"
            )

            df <- df[, c("term", "class", definition_col, "examples", "required")]
            names(df) <- c(
                tr("wiki_term", lang_r()),
                tr("wiki_class", lang_r()),
                tr("wiki_definition", lang_r()),
                tr("wiki_example", lang_r()),
                tr("wiki_required", lang_r())
            )

            df
        })

        output$terms_table <- DT::renderDataTable({
            DT::datatable(
                filtered_terms(),
                options = list(
                    pageLength = 15,
                    scrollX = TRUE,
                    language = list(
                        search = tr("wiki_datatable_search", lang_r())
                    )
                ),
                class = "display compact",
                rownames = FALSE,
                escape = FALSE
            )
        })
    })
}
