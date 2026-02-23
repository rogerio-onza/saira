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
    css_version <- as.integer(Sys.time())

    bslib::page_navbar(
        id = "main_nav",
        lang = "pt-BR",
        title = shiny::tags$div(
            class = "navbar-brand-wrapper",
            shiny::tags$img(
                src = "www/images/hexagon_logo.png",
                height = "72px",
                class = "navbar-logo",
                alt = "Finch Logo"
            ),
            shiny::tags$span("Finch", class = "navbar-title")
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
            base_font = bslib::font_google("IBM Plex Sans"),
            heading_font = bslib::font_google("IBM Plex Mono"),
            code_font = bslib::font_google("IBM Plex Mono")
        ),

        # Include custom CSS and FontAwesome
        shiny::tags$head(
            shiny::tags$link(
                rel = "stylesheet",
                href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css",
                integrity = "sha512-DTOQO9RWCH3ppGqcWaEA1BIZOC6xxalwEsw9c2QQeAIftl+Vegovlnee1c9QX4TctnWMn13TZye+giMm8e2LwA==",
                crossorigin = "anonymous"
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
                src = "https://unpkg.com/@lottiefiles/lottie-player@2.0.12/dist/lottie-player.js"
            ),
            shiny::tags$link(
                rel = "icon",
                type = "image/png",
                href = "www/images/hexagon_logo.png"
            )
        ),

        # Tab: Home
        bslib::nav_panel(
            title = shiny::tags$span(
                shiny::icon("home", class = "fa-solid"),
                " ",
                shiny::uiOutput("nav_upload_title", inline = TRUE)
            ),
            value = "upload",
            mod_upload_ui("upload")
        ),

        # Tab: Mapping
        bslib::nav_panel(
            title = shiny::uiOutput("nav_mapping_title"),
            value = "mapping",
            icon = shiny::icon("arrows-alt"),
            mod_mapping_ui("mapping")
        ),

        # Tab: Preview
        bslib::nav_panel(
            title = shiny::uiOutput("nav_preview_title"),
            value = "preview",
            icon = shiny::icon("table"),
            mod_preview_ui("preview")
        ),

        # Dropdown: Validation
        bslib::nav_menu(
            title = shiny::tags$span(
                shiny::icon("check-circle"),
                shiny::uiOutput("nav_validate_title", inline = TRUE)
            ),

            # Tab: Validate Names
            bslib::nav_panel(
                title = shiny::uiOutput("nav_validate_names_title"),
                value = "validate_names",
                icon = shiny::icon("dna"),
                mod_validate_names_ui("validate_names")
            ),

            # Tab: Validate Coords
            bslib::nav_panel(
                title = shiny::uiOutput("nav_validate_coords_title"),
                value = "validate_coords",
                icon = shiny::icon("map-marker-alt"),
                mod_validate_coords_ui("validate_coords")
            )
        ),

        # Tab: Wiki
        bslib::nav_panel(
            title = shiny::uiOutput("nav_wiki_title"),
            value = "wiki",
            icon = shiny::icon("book"),
            mod_wiki_ui("wiki")
        ),

        # Tab: Help
        bslib::nav_panel(
            title = shiny::uiOutput("nav_help_title"),
            value = "help",
            icon = shiny::icon("question-circle"),
            mod_help_ui("help")
        ),

        # Spacer pushes language selector to the right
        bslib::nav_spacer(),

        # Language selector
        bslib::nav_item(
            shiny::selectInput(
                inputId = "lang_switch",
                label = shiny::tags$span(tr("a11y_lang_switch_label", "pt"), class = "visually-hidden"),
                choices = c("Portuguese" = "pt", "English" = "en"),
                selected = "pt",
                width = "150px",
                selectize = FALSE
            )
        )
    )
}
