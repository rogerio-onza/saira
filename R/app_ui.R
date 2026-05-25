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
                href = paste0("www/vendor/fontawesome/css/all.min.css?v=", css_version)
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
                src = paste0("www/help-accordion.js?v=", css_version)
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

            # Tab: Home
            bslib::nav_panel(
                title = shiny::tags$span(
                    shiny::icon("home", class = "fa-solid"),
                    " ",
                    shiny::tags$span(
                        class = "nav-title-container",
                        shiny::tags$span(tr("nav_home", "pt"), class = "nav-title-static"),
                        shiny::uiOutput("nav_upload_title", class = "nav-title-dynamic", inline = TRUE)
                    )
                ),
                value = "upload",
                mod_upload_ui("upload")
            ),

            # Tab: Mapping
            bslib::nav_panel(
                title = shiny::tags$span(
                    class = "nav-title-container",
                    shiny::tags$span(tr("nav_mapping", "pt"), class = "nav-title-static"),
                    shiny::uiOutput("nav_mapping_title", class = "nav-title-dynamic", inline = TRUE)
                ),
                value = "mapping",
                icon = shiny::icon("arrows-alt", class = "fa-solid"),
                mod_mapping_ui("mapping")
            ),

            # Tab: Preview
            bslib::nav_panel(
                title = shiny::tags$span(
                    class = "nav-title-container",
                    shiny::tags$span(tr("nav_preview", "pt"), class = "nav-title-static"),
                    shiny::uiOutput("nav_preview_title", class = "nav-title-dynamic", inline = TRUE)
                ),
                value = "preview",
                icon = shiny::icon("table", class = "fa-solid"),
                mod_preview_ui("preview")
            ),

            # Dropdown: Validation
            bslib::nav_menu(
                title = shiny::tags$span(
                    shiny::icon("check-circle", class = "fa-solid"),
                    shiny::tags$span(
                        class = "nav-title-container",
                        shiny::tags$span(tr("nav_validate", "pt"), class = "nav-title-static"),
                        shiny::uiOutput("nav_validate_title", class = "nav-title-dynamic", inline = TRUE)
                    )
                ),

                # Tab: Validate Names
                bslib::nav_panel(
                    title = shiny::tags$span(
                        class = "nav-title-container",
                        shiny::tags$span(tr("nav_validate_names", "pt"), class = "nav-title-static"),
                        shiny::uiOutput("nav_validate_names_title", class = "nav-title-dynamic", inline = TRUE)
                    ),
                    value = "validate_names",
                    icon = shiny::icon("dna", class = "fa-solid"),
                    mod_validate_names_ui("validate_names")
                ),

                # Tab: Validate Coords
                bslib::nav_panel(
                    title = shiny::tags$span(
                        class = "nav-title-container",
                        shiny::tags$span(tr("nav_validate_coords", "pt"), class = "nav-title-static"),
                        shiny::uiOutput("nav_validate_coords_title", class = "nav-title-dynamic", inline = TRUE)
                    ),
                    value = "validate_coords",
                    icon = shiny::icon("map-marker-alt", class = "fa-solid"),
                    mod_validate_coords_ui("validate_coords")
                )
            ),

            # Tab: Wiki
            bslib::nav_panel(
                title = shiny::tags$span(
                    class = "nav-title-container",
                    shiny::tags$span(tr("nav_wiki", "pt"), class = "nav-title-static"),
                    shiny::uiOutput("nav_wiki_title", class = "nav-title-dynamic", inline = TRUE)
                ),
                value = "wiki",
                icon = shiny::icon("book", class = "fa-solid"),
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
                icon = shiny::icon("question-circle", class = "fa-solid"),
                mod_help_ui("help")
            ),

            # Spacer pushes language selector to the right
            bslib::nav_spacer(),

            # Language selector
            bslib::nav_item(
                shiny::selectInput(
                    inputId = "lang_switch",
                    label = shiny::tags$span(tr("a11y_lang_switch_label", "pt"), class = "visually-hidden"),
                    choices = c("Portugu\u00EAs" = "pt", "English" = "en"),
                    selected = "pt",
                    width = "150px",
                    selectize = FALSE
                )
            )
        )
    )
}
