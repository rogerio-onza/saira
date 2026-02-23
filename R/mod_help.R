# Title: Help Module
# Author: Rogério Nunes Oliveira
# Date: 2026-02-08
# Version: 1.1

help_faq_item <- function(question, answer) {
    shiny::div(
        class = "help-faq-item",
        shiny::h5(question),
        shiny::p(answer, class = "mb-0")
    )
}

help_getting_started_content <- function(is_pt) {
    if (is_pt) {
        shiny::tagList(
            shiny::h5("Como usar o Finch"),
            shiny::tags$ol(
                shiny::tags$li(shiny::strong("Upload:"), " Faça upload do seu arquivo CSV com dados de biodiversidade."),
                shiny::tags$li(shiny::strong("Mapeamento:"), " Associe suas colunas aos termos Darwin Core. Use o botão 'Auto-mapear' para detecção automática."),
                shiny::tags$li(shiny::strong("Pré-visualização:"), " Verifique os dados mapeados antes de exportar."),
                shiny::tags$li(shiny::strong("Validação:"), " Valide nomes científicos e coordenadas."),
                shiny::tags$li(shiny::strong("Download:"), " Baixe o CSV no padrão DwC.")
            )
        )
    } else {
        shiny::tagList(
            shiny::h5("How to use Finch"),
            shiny::tags$ol(
                shiny::tags$li(shiny::strong("Upload:"), " Upload your CSV file with biodiversity data."),
                shiny::tags$li(shiny::strong("Mapping:"), " Map your columns to Darwin Core terms. Use the 'Auto-map' button for automatic detection."),
                shiny::tags$li(shiny::strong("Preview:"), " Check mapped data before exporting."),
                shiny::tags$li(shiny::strong("Validation:"), " Validate scientific names and coordinates."),
                shiny::tags$li(shiny::strong("Download:"), " Download the DwC-compliant CSV.")
            )
        )
    }
}

help_dwc_content <- function(is_pt) {
    if (is_pt) {
        shiny::tagList(
            shiny::p(
                "O ",
                shiny::strong("Darwin Core (DwC)"),
                " é um padrão de dados para compartilhamento de informações sobre biodiversidade, mantido pela ",
                shiny::tags$a(href = "https://www.tdwg.org/", target = "_blank", "TDWG"),
                "."
            ),
            shiny::p("Ele fornece um vocabulário estável de termos para descrever:"),
            shiny::tags$ul(
                shiny::tags$li("Ocorrências de espécies"),
                shiny::tags$li("Localizações geográficas"),
                shiny::tags$li("Taxonomia"),
                shiny::tags$li("Eventos de coleta")
            ),
            shiny::p("O SiBBr (Sistema de Informação sobre a Biodiversidade Brasileira) utiliza o Darwin Core como padrão para seus dados.")
        )
    } else {
        shiny::tagList(
            shiny::p(
                shiny::strong("Darwin Core (DwC)"),
                " is a data standard for sharing biodiversity information, maintained by ",
                shiny::tags$a(href = "https://www.tdwg.org/", target = "_blank", "TDWG"),
                "."
            ),
            shiny::p("It provides a stable vocabulary of terms to describe:"),
            shiny::tags$ul(
                shiny::tags$li("Species occurrences"),
                shiny::tags$li("Geographic locations"),
                shiny::tags$li("Taxonomy"),
                shiny::tags$li("Collection events")
            ),
            shiny::p("SiBBr (Brazilian Biodiversity Information System) uses Darwin Core as its data standard.")
        )
    }
}

help_faq_content <- function(is_pt) {
    if (is_pt) {
        shiny::div(
            class = "help-faq-grid",
            help_faq_item("Quais formatos de arquivo são aceitos?", "Apenas arquivos CSV (.csv) são aceitos."),
            help_faq_item("Qual o tamanho máximo de arquivo?", "O limite padrão é 30MB. Para arquivos maiores, entre em contato com o administrador."),
            help_faq_item("Como funciona o auto-mapeamento?", "O sistema compara os nomes das suas colunas com os termos DwC e sugere correspondências baseadas em similaridade."),
            help_faq_item("Os dados são salvos em algum servidor?", "Não. Todo o processamento é feito localmente na sua sessão. Nenhum dado é armazenado.")
        )
    } else {
        shiny::div(
            class = "help-faq-grid",
            help_faq_item("What file formats are accepted?", "Only CSV files (.csv) are accepted."),
            help_faq_item("What is the maximum file size?", "The default limit is 30MB. For larger files, contact the administrator."),
            help_faq_item("How does auto-mapping work?", "The system compares your column names with DwC terms and suggests matches based on similarity."),
            help_faq_item("Is my data saved on any server?", "No. All processing is done locally in your session. No data is stored.")
        )
    }
}

help_support_content <- function(is_pt) {
    if (is_pt) {
        shiny::tagList(
            shiny::p("Para dúvidas ou sugestões, entre em contato:"),
            shiny::tags$ul(
                shiny::tags$li("Email: suporte@finch.org.br"),
                shiny::tags$li(
                    "GitHub: ",
                    shiny::tags$a(href = "https://github.com/finch-project", target = "_blank", "github.com/finch-project")
                )
            )
        )
    } else {
        shiny::tagList(
            shiny::p("For questions or suggestions, contact us:"),
            shiny::tags$ul(
                shiny::tags$li("Email: support@finch.org.br"),
                shiny::tags$li(
                    "GitHub: ",
                    shiny::tags$a(href = "https://github.com/finch-project", target = "_blank", "github.com/finch-project")
                )
            )
        )
    }
}

help_panels <- function(is_pt) {
    list(
        list(
            value = "getting_started",
            title = if (is_pt) "1. Começando" else "1. Getting Started",
            icon = "play-circle",
            search_text = if (is_pt) {
                "começando iniciar upload mapeamento pré-visualização validação download"
            } else {
                "getting started upload mapping preview validation download"
            },
            content = help_getting_started_content(is_pt)
        ),
        list(
            value = "dwc",
            title = if (is_pt) "2. O que é Darwin Core?" else "2. What is Darwin Core?",
            icon = "info-circle",
            search_text = if (is_pt) {
                "darwin core dwc padrão biodiversidade tdwg ocorrências taxonomia coleta"
            } else {
                "darwin core dwc standard biodiversity tdwg occurrences taxonomy collection"
            },
            content = help_dwc_content(is_pt)
        ),
        list(
            value = "faq",
            title = if (is_pt) "3. Perguntas Frequentes" else "3. FAQ",
            icon = "question-circle",
            search_text = if (is_pt) {
                "faq perguntas frequentes formato csv tamanho arquivo auto-mapeamento servidor privacidade"
            } else {
                "faq file format csv file size auto-mapping server privacy"
            },
            content = help_faq_content(is_pt)
        ),
        list(
            value = "support",
            title = if (is_pt) "4. Suporte" else "4. Support",
            icon = "envelope",
            search_text = if (is_pt) {
                "suporte contato email github"
            } else {
                "support contact email github"
            },
            content = help_support_content(is_pt)
        )
    )
}

#' Help Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_help_ui <- function(id) {
    ns <- shiny::NS(id)

    shiny::tagList(
        shiny::div(
            class = "container-fluid",
            style = "max-width: 1100px; margin: 0 auto;",
            shiny::uiOutput(ns("title")),
            shiny::uiOutput(ns("subtitle")),
            shiny::div(
                class = "help-search-container",
                shiny::icon("search", class = "help-search-icon"),
                shiny::uiOutput(ns("help_search_input"))
            ),
            shiny::uiOutput(ns("help_content"))
        )
    )
}

#' Help Module Server
#'
#' @param id Module ID
#' @param lang_r Reactive language value
#' @export
mod_help_server <- function(id, lang_r) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        output$title <- shiny::renderUI({
            shiny::h3(tr("help_title", lang_r()), class = "text-mono")
        })

        output$subtitle <- shiny::renderUI({
            shiny::p(tr("help_subtitle", lang_r()), class = "text-accent")
        })

        output$help_search_input <- shiny::renderUI({
            shiny::textInput(
                inputId = ns("help_search"),
                label = shiny::tags$span(tr("a11y_help_search_label", lang_r()), class = "visually-hidden"),
                placeholder = tr("a11y_help_search_label", lang_r()),
                width = "100%"
            )
        })

        output$help_content <- shiny::renderUI({
            is_pt <- identical(lang_r(), "pt")
            search_query <- tolower(trimws(input$help_search %||% ""))

            panels <- help_panels(is_pt)
            if (!identical(search_query, "")) {
                panels <- Filter(
                    f = function(panel) grepl(search_query, tolower(panel$search_text), fixed = TRUE),
                    x = panels
                )
            }

            if (length(panels) == 0) {
                return(
                    shiny::div(
                        class = "alert alert-info",
                        if (is_pt) "Nenhum conteúdo encontrado para a busca informada." else "No help content matched your search."
                    )
                )
            }

            panel_values <- vapply(panels, function(panel) panel$value, character(1))
            open_panel <- if ("getting_started" %in% panel_values) "getting_started" else FALSE

            panel_tags <- lapply(panels, function(panel) {
                bslib::accordion_panel(
                    title = panel$title,
                    value = panel$value,
                    icon = shiny::icon(panel$icon),
                    panel$content
                )
            })

            do.call(
                bslib::accordion,
                c(
                    list(
                        id = ns("help_accordion"),
                        class = "help-accordion",
                        open = open_panel
                    ),
                    panel_tags
                )
            )
        })
    })
}
