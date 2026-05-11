# Title: Main Application Server
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-13
# Version: 1.2

#' Main Application Server
#'
#' Orchestrates all modules - NO business logic here
#'
#' @param input Shiny input
#' @param output Shiny output
#' @param session Shiny session
#' @export
app_server <- function(input, output, session) {
    # Reactive: Selected language (debounced after first render)
    lang_initialized <- shiny::reactiveVal(FALSE)
    lang_raw_r <- shiny::reactive({
        input$lang_switch %||% "pt"
    })
    lang_debounced_r <- lang_raw_r |> shiny::debounce(150)
    lang_r <- shiny::reactive({
        if (!lang_initialized()) {
            lang_initialized(TRUE)
            lang_raw_r()
        } else {
            lang_debounced_r()
        }
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
    mapping_result <- mod_mapping_server("mapping", raw_data, lang_r)
    # ADR-054: mod_mapping_server returns named list of reactives
    mapped_data <- mapping_result$processed_data_r
    preview_data <- mapping_result$preview_data_r
    validation_gate <- mapping_result$validation_gate_r
    coord_validation_gate <- mapping_result$validation_gate_coords_r
    if (is.null(preview_data) || !shiny::is.reactive(preview_data)) {
        warning("[Sa\u00EDra] preview_data slot missing from mapping module, using mapped_data fallback")
        preview_data <- mapped_data
    }
    if (is.null(validation_gate) || !shiny::is.reactive(validation_gate)) {
        warning("[Sa\u00EDra] validation_gate slot missing, gate disabled")
        validation_gate <- NULL
    }
    if (is.null(coord_validation_gate) || !shiny::is.reactive(coord_validation_gate)) {
        warning("[Sa\u00EDra] coord_validation_gate slot missing, gate disabled")
        coord_validation_gate <- NULL
    }

    validate_names_r <- mod_validate_names_server("validate_names", mapped_data, lang_r, validation_gate_r = validation_gate)
    name_review_payload_r <- attr(validate_names_r, "review_export_payload")

    # Consumers of mapped_data
    mod_preview_server(
        "preview",
        preview_data,
        lang_r,
        download_data_r = mapped_data,
        name_review_payload_r = name_review_payload_r,
        raw_data_r = raw_data,
        map_values_r = mapping_result$map_values_r
    )
    coord_validation_r <- mod_validate_coords_server(
        "validate_coords",
        mapped_data,
        lang_r,
        validation_gate_r = coord_validation_gate
    )

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

    # Cleanup on session end
    session$onSessionEnded(function() {
        warning("[Sa\u00EDra] Session ended, cleanup complete")
    })
}
