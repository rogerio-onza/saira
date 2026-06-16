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

    output$nav_generalize_title <- shiny::renderUI({
        tr("nav_generalize", lang_r())
    })

    output$nav_export_title <- shiny::renderUI({
        tr("nav_export", lang_r())
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
    # Bumped on re-upload or a confirmed Mapping reset: tells the downstream tabs
    # to discard the decisions made for the previous dataset (ADR-054 slot).
    reset_signal <- mapping_result$reset_signal_r
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

    validate_names_r <- mod_validate_names_server("validate_names", mapped_data, lang_r, validation_gate_r = validation_gate, reset_signal_r = reset_signal)
    name_review_payload_r <- attr(validate_names_r, "review_export_payload")
    sensitivity_payload_r <- attr(validate_names_r, "sensitivity_payload")

    # Coordinate validation runs before preview so its transposed-coordinate
    # correction payload can be applied at export (mirrors name review).
    coord_validation_r <- mod_validate_coords_server(
        "validate_coords",
        mapped_data,
        lang_r,
        validation_gate_r = coord_validation_gate,
        reset_signal_r = reset_signal
    )
    coords_correction_payload_r <- attr(coord_validation_r, "coords_correction_payload")
    country_fill_payload_r <- attr(coord_validation_r, "country_fill_payload")

    # Dedicated sensitive-species generalization stage (Chapman 2020, Table 5).
    # Consumes the Name-tab sensitivity marks plus the coordinate corrections so
    # its map preview matches the published point; returns the export decision.
    sensitive_generalization_payload_r <- mod_sensitive_coords_server(
        "sensitive_coords",
        mapped_data,
        lang_r,
        sensitivity_payload_r = sensitivity_payload_r,
        coords_correction_payload_r = coords_correction_payload_r,
        country_fill_payload_r = country_fill_payload_r,
        reset_signal_r = reset_signal
    )

    # Preview is read-only (the download/export flow lives in the Export tab).
    mod_preview_server("preview", preview_data, lang_r)

    # Export review + publish hub: the same validation/generalization payloads
    # feed the summary, and the DwC-A download flow lives here (ADR-103).
    mod_export_server(
        "export",
        mapped_data,
        lang_r,
        download_data_r                    = mapped_data,
        name_review_payload_r              = name_review_payload_r,
        coords_correction_payload_r        = coords_correction_payload_r,
        country_fill_payload_r             = country_fill_payload_r,
        sensitivity_payload_r              = sensitivity_payload_r,
        sensitive_generalization_payload_r = sensitive_generalization_payload_r,
        raw_data_r                         = raw_data,
        map_values_r                       = mapping_result$map_values_r,
        custom_values_r                    = mapping_result$custom_values_r,
        # Bind the root session: this callback fires inside the export module's
        # reactive context, so without an explicit session nav_select would
        # namespace "main_nav" and silently no-op. When a term is given, also
        # scroll the Mapping tab to that field card and flash it.
        on_navigate                        = function(tab, term = NULL) {
            bslib::nav_select("main_nav", selected = tab, session = session)
            if (!is.null(term) && length(term) == 1L && nzchar(term)) {
                session$sendCustomMessage(
                    "saira_focus_field",
                    list(id = paste0("mapping-fieldcard_", term))
                )
            }
        }
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
