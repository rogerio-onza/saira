# Title: Main Application UI
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-13
# Version: 1.1

#' Main Application UI
#'
#' Builds the main UI using bslib page_navbar
#'
#' @return A Shiny UI object
#' @export
app_ui <- function() {
    css_version <- as.character(utils::packageVersion("saira"))

    shiny::tagList(
        shiny::tags$head(
            shiny::tags$link(
                rel = "stylesheet",
                href = paste0("www/vendor/fonts/source-fonts.css?v=", css_version)
            ),
            shiny::tags$link(
                rel = "stylesheet",
                href = paste0("www/vendor/phosphor/regular/style.css?v=", css_version)
            ),
            shiny::tags$link(
                rel = "stylesheet",
                href = paste0("www/vendor/phosphor/light/style.css?v=", css_version)
            ),
            shiny::tags$link(
                rel = "stylesheet",
                type = "text/css",
                href = paste0("www/custom.css?v=", css_version)
            ),
            shiny::tags$script(
                src = paste0("www/upload-dropzone.js?v=", css_version)
            ),
            shiny::tags$script(
                src = paste0("www/vendor/lottie/lottie-player.js?v=", css_version)
            )
        ),
        bslib::page_navbar(
            id = "main_nav",
            lang = "pt-BR",
            title = shiny::tags$div(
                class = "navbar-brand-wrapper",
                shiny::tags$span("Sa\u00EDra", class = "navbar-title navbar-brand-name")
            ),
            theme = bslib::bs_theme(
                version = 5,
                bootswatch = "flatly",
                bg = "#f4f3ee",
                fg = "#1C1C26",
                primary = "#38CFF6",
                secondary = "#2833AC",
                success = "#00A86B",
                info = "#252659",
                warning = "#FFA204",
                danger = "#C0392B",
                base_font = bslib::font_collection("Source Serif 4", "Georgia", "serif"),
                heading_font = bslib::font_collection("Source Serif 4", "Georgia", "serif"),
                code_font = bslib::font_collection("Space Mono", "monospace")
            ),

            # Workflow steps: numbered, in order. The number is static markup, so a
            # language switch only re-renders the title (ADR-128).
            # Tab: Home
            bslib::nav_panel(
                title = shiny::tags$span(
                    class = "nav-title-container",
                    shiny::tags$span("1", class = "nav-step-num", `aria-hidden` = "true"),
                    shiny::tags$span(tr("nav_home", "pt"), class = "nav-title-static"),
                    shiny::uiOutput("nav_upload_title", class = "nav-title-dynamic", inline = TRUE)
                ),
                value = "upload",
                mod_upload_ui("upload")
            ),

            # Tab: Mapping
            bslib::nav_panel(
                title = shiny::tags$span(
                    class = "nav-title-container",
                    shiny::tags$span("2", class = "nav-step-num", `aria-hidden` = "true"),
                    shiny::tags$span(tr("nav_mapping", "pt"), class = "nav-title-static"),
                    shiny::uiOutput("nav_mapping_title", class = "nav-title-dynamic", inline = TRUE)
                ),
                value = "mapping",
                mod_mapping_ui("mapping")
            ),

            # Tab: Preview
            bslib::nav_panel(
                title = shiny::tags$span(
                    class = "nav-title-container",
                    shiny::tags$span("3", class = "nav-step-num", `aria-hidden` = "true"),
                    shiny::tags$span(tr("nav_preview", "pt"), class = "nav-title-static"),
                    shiny::uiOutput("nav_preview_title", class = "nav-title-dynamic", inline = TRUE)
                ),
                value = "preview",
                mod_preview_ui("preview")
            ),

            # Tab: Validate Names
            bslib::nav_panel(
                title = shiny::tags$span(
                    class = "nav-title-container",
                    shiny::tags$span("4", class = "nav-step-num", `aria-hidden` = "true"),
                    shiny::tags$span(tr("nav_validate_names", "pt"), class = "nav-title-static"),
                    shiny::uiOutput("nav_validate_names_title", class = "nav-title-dynamic", inline = TRUE)
                ),
                value = "validate_names",
                mod_validate_names_ui("validate_names")
            ),

            # Tab: Validate Coords
            bslib::nav_panel(
                title = shiny::tags$span(
                    class = "nav-title-container",
                    shiny::tags$span("5", class = "nav-step-num", `aria-hidden` = "true"),
                    shiny::tags$span(tr("nav_validate_coords", "pt"), class = "nav-title-static"),
                    shiny::uiOutput("nav_validate_coords_title", class = "nav-title-dynamic", inline = TRUE)
                ),
                value = "validate_coords",
                mod_validate_coords_ui("validate_coords")
            ),

            # Tab: Generalization (sensitive species)
            bslib::nav_panel(
                title = shiny::tags$span(
                    class = "nav-title-container",
                    shiny::tags$span("6", class = "nav-step-num", `aria-hidden` = "true"),
                    shiny::tags$span(tr("nav_generalize", "pt"), class = "nav-title-static"),
                    shiny::uiOutput("nav_generalize_title", class = "nav-title-dynamic", inline = TRUE)
                ),
                value = "sensitive_coords",
                mod_sensitive_coords_ui("sensitive_coords")
            ),

            # Tab: Export (review-before-publish summary; last workflow step)
            bslib::nav_panel(
                title = shiny::tags$span(
                    class = "nav-title-container",
                    shiny::tags$span("7", class = "nav-step-num", `aria-hidden` = "true"),
                    shiny::tags$span(tr("nav_export", "pt"), class = "nav-title-static"),
                    shiny::uiOutput("nav_export_title", class = "nav-title-dynamic", inline = TRUE)
                ),
                value = "export",
                mod_export_ui("export")
            ),

            # Spacer pushes the reference tabs, the language selector and the
            # version badge to the right of the first header row.
            bslib::nav_spacer(),

            # Reference tabs: first header row, right side.
            # Tab: Wiki
            bslib::nav_panel(
                title = shiny::tags$span(
                    class = "nav-title-container",
                    shiny::tags$span(tr("nav_wiki", "pt"), class = "nav-title-static"),
                    shiny::uiOutput("nav_wiki_title", class = "nav-title-dynamic", inline = TRUE)
                ),
                value = "wiki",
                mod_wiki_ui("wiki")
            ),

            # Tab: Help
            bslib::nav_panel(
                title = shiny::tags$span(
                    class = "nav-title-container",
                    shiny::tags$span(tr("nav_help", "pt"), class = "nav-title-static"),
                    shiny::uiOutput("nav_help_title", class = "nav-title-dynamic", inline = TRUE)
                ),
                value = "help",
                mod_help_ui("help")
            ),

            # Language selector
            bslib::nav_item(
                shiny::selectInput(
                    inputId = "lang_switch",
                    label = shiny::tags$span(tr("a11y_lang_switch_label", "pt"), class = "visually-hidden"),
                    # Short codes keep the header row compact; the hidden label
                    # names the control for screen readers.
                    choices = c("PT" = "pt", "EN" = "en"),
                    selected = "pt",
                    width = "auto",
                    selectize = FALSE
                )
            ),

            # Version badge \u2014 sits with the navbar items, beside the language
            # selector. Rendered server-side (output$version_badge) as a link to
            # the releases page, language-aware, mirroring the website navbar pill.
            bslib::nav_item(
                shiny::uiOutput("version_badge", inline = TRUE)
            )
        )
    )
}
