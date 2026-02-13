# Title: Wiki Module
# Author: RogÃ©rio Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

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
                    shiny::textInput(
                        inputId = ns("search"),
                        label = NULL,
                        placeholder = "Buscar termo...",
                        width = "100%"
                    )
                ),
                shiny::column(
                    width = 6,
                    shiny::selectInput(
                        inputId = ns("class_filter"),
                        label = NULL,
                        choices = c(
                            "Todas as classes" = "",
                            "Record-level" = "Record-level",
                            "Occurrence" = "Occurrence",
                            "Event" = "Event",
                            "Location" = "Location",
                            "Identification" = "Identification",
                            "Taxon" = "Taxon"
                        ),
                        width = "100%"
                    )
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

        # Load dependencies

        # Get DwC terms data
        dwc_terms <- get_dwc_terms()

        # Dynamic UI elements
        output$title <- shiny::renderUI({
            shiny::h3(tr("wiki_title", lang_r()), class = "text-mono")
        })

        output$subtitle <- shiny::renderUI({
            shiny::p(tr("wiki_subtitle", lang_r()), class = "text-accent")
        })

        # Filtered terms
        filtered_terms <- shiny::reactive({
            df <- dwc_terms

            # Apply class filter
            if (!is.null(input$class_filter) && input$class_filter != "") {
                df <- df[df$class == input$class_filter, ]
            }

            # Apply search filter
            if (!is.null(input$search) && nchar(input$search) > 0) {
                search_term <- tolower(input$search)
                df <- df[
                    grepl(search_term, tolower(df$term)) |
                        grepl(search_term, tolower(df$definition_pt)) |
                        grepl(search_term, tolower(df$definition_en)),
                ]
            }

            # Select columns based on language
            if (lang_r() == "pt") {
                df <- df[, c("term", "class", "definition_pt", "examples", "required")]
                names(df) <- c("Termo", "Classe", "DefiniÃ§Ã£o", "Exemplos", "ObrigatÃ³rio")
            } else {
                df <- df[, c("term", "class", "definition_en", "examples", "required")]
                names(df) <- c("Term", "Class", "Definition", "Examples", "Required")
            }

            return(df)
        })

        # Render table
        output$terms_table <- DT::renderDataTable({
            DT::datatable(
                filtered_terms(),
                options = list(
                    pageLength = 15,
                    scrollX = TRUE,
                    language = list(
                        search = tr("wiki_search", lang_r())
                    )
                ),
                class = "display compact",
                rownames = FALSE,
                escape = FALSE
            )
        })
    })
}
