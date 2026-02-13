# Title: Main Application Server
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-13
# Version: 1.1

#' Main Application Server
#'
#' Orchestrates all modules - NO business logic here
#'
#' @param input Shiny input
#' @param output Shiny output
#' @param session Shiny session
#' @export
app_server <- function(input, output, session) {
    # Reactive: Selected language
    lang_r <- shiny::reactive({
        input$lang_switch %||% "pt"
    })

    # Dynamic navigation titles based on language
    output$nav_upload_title <- shiny::renderUI({
        tr("nav_home", lang_r())
    })

    output$nav_mapping_title <- shiny::renderUI({
        tr("nav_mapping", lang_r())
    })

    output$nav_preview_title <- shiny::renderUI({
        tr("nav_preview", lang_r())
    })

    output$nav_validate_title <- shiny::renderUI({
        tr("nav_validate", lang_r())
    })

    output$nav_validate_names_title <- shiny::renderUI({
        tr("nav_validate_names", lang_r())
    })

    output$nav_validate_coords_title <- shiny::renderUI({
        tr("nav_validate_coords", lang_r())
    })

    output$nav_wiki_title <- shiny::renderUI({
        tr("nav_wiki", lang_r())
    })

    output$nav_help_title <- shiny::renderUI({
        tr("nav_help", lang_r())
    })

    # Chain of Reactivity: Data Flow
    raw_data <- mod_upload_server("upload", lang_r)
    mapped_data <- mod_mapping_server("mapping", raw_data, lang_r)

    # Consumers of mapped_data
    mod_preview_server("preview", mapped_data, lang_r)
    mod_validate_names_server("validate_names", mapped_data, lang_r)
    mod_validate_coords_server("validate_coords", mapped_data, lang_r)

    # Independent modules (no data dependency)
    mod_wiki_server("wiki", lang_r)
    mod_help_server("help", lang_r)

    # Auto-navigation after upload
    shiny::observeEvent(raw_data(),
        {
            if (!is.null(raw_data()) && nrow(raw_data()) > 0) {
                bslib::nav_select("main_nav", selected = "mapping")
            }
        },
        ignoreNULL = TRUE,
        ignoreInit = TRUE
    )
}
