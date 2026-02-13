# Title: Validate Names Module
# Author: RogÃ©rio Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

#' Validate Names Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_validate_names_ui <- function(id) {
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
                icon = shiny::icon("check")
            ),

            # Stats
            shiny::uiOutput(ns("stats")),

            # Results table
            shiny::uiOutput(ns("results"))
        )
    )
}

#' Validate Names Module Server
#'
#' @param id Module ID
#' @param mapped_data_r Reactive data frame with mapped data
#' @param lang_r Reactive language value
#' @export
mod_validate_names_server <- function(id, mapped_data_r, lang_r) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        # Load dependencies

        # Reactive values
        validation_result <- shiny::reactiveVal(NULL)

        # Dynamic UI elements
        output$title <- shiny::renderUI({
            shiny::h3(tr("validate_names_title", lang_r()), class = "text-mono")
        })

        output$subtitle <- shiny::renderUI({
            shiny::p(tr("validate_names_subtitle", lang_r()), class = "text-accent")
        })

        output$btn_label <- shiny::renderUI({
            tr("validate_names_run", lang_r())
        })

        # Validation action
        shiny::observeEvent(input$validate, {
            shiny::req(mapped_data_r())

            df <- mapped_data_r()

            # Check if scientificName column exists
            if (!"scientificName" %in% names(df)) {
                shiny::showNotification(
                    if (lang_r() == "pt") {
                        "Coluna 'scientificName' nÃ£o encontrada. Mapeie primeiro."
                    } else {
                        "'scientificName' column not found. Map it first."
                    },
                    type = "warning"
                )
                return()
            }

            # Simple validation (placeholder for taxadb integration)
            names_vec <- df$scientificName

            result <- data.frame(
                scientificName = names_vec,
                status = ifelse(
                    !is.na(names_vec) & nchar(trimws(names_vec)) > 2,
                    "valid",
                    "invalid"
                ),
                stringsAsFactors = FALSE
            )

            validation_result(result)
        })

        # Stats output
        output$stats <- shiny::renderUI({
            res <- validation_result()
            if (is.null(res)) {
                return(NULL)
            }

            valid_count <- sum(res$status == "valid")
            invalid_count <- sum(res$status == "invalid")
            unresolved_count <- sum(res$status == "unresolved", na.rm = TRUE)

            shiny::fluidRow(
                class = "mb-4",
                shiny::column(
                    width = 4,
                    shiny::div(
                        class = "stat-box",
                        shiny::div(class = "stat-value", style = "color: var(--success);", valid_count),
                        shiny::div(class = "stat-label", tr("validate_names_valid", lang_r()))
                    )
                ),
                shiny::column(
                    width = 4,
                    shiny::div(
                        class = "stat-box",
                        shiny::div(class = "stat-value", style = "color: var(--error);", invalid_count),
                        shiny::div(class = "stat-label", tr("validate_names_invalid", lang_r()))
                    )
                ),
                shiny::column(
                    width = 4,
                    shiny::div(
                        class = "stat-box",
                        shiny::div(class = "stat-value", style = "color: var(--warning);", unresolved_count),
                        shiny::div(class = "stat-label", tr("validate_names_unresolved", lang_r()))
                    )
                )
            )
        })

        # Results table
        output$results <- shiny::renderUI({
            res <- validation_result()
            if (is.null(res)) {
                return(NULL)
            }

            # Show only issues
            issues <- res[res$status != "valid", ]

            if (nrow(issues) == 0) {
                shiny::div(
                    class = "alert alert-success",
                    shiny::icon("check-circle"),
                    " ",
                    if (lang_r() == "pt") "Todos os nomes sÃ£o vÃ¡lidos!" else "All names are valid!"
                )
            } else {
                DT::dataTableOutput(ns("issues_table"))
            }
        })

        output$issues_table <- DT::renderDataTable({
            res <- validation_result()
            shiny::req(res)

            issues <- res[res$status != "valid", ]

            DT::datatable(
                issues,
                options = list(pageLength = 10, scrollX = TRUE),
                class = "display compact",
                rownames = FALSE
            )
        })
    })
}
