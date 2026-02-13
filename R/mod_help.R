# Title: Help Module
# Author: RogÃ©rio Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

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
            style = "max-width: 900px; margin: 0 auto;",
            shiny::uiOutput(ns("title")),
            shiny::uiOutput(ns("subtitle")),
            shiny::br(),

            # Accordion with help sections
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

        # Load dependencies

        # Dynamic UI elements
        output$title <- shiny::renderUI({
            shiny::h3(tr("help_title", lang_r()), class = "text-mono")
        })

        output$subtitle <- shiny::renderUI({
            shiny::p(tr("help_subtitle", lang_r()), class = "text-accent")
        })

        output$help_content <- shiny::renderUI({
            is_pt <- lang_r() == "pt"

            bslib::accordion(
                id = ns("help_accordion"),
                open = TRUE,

                # Getting Started
                bslib::accordion_panel(
                    title = if (is_pt) "1. ComeÃ§ando" else "1. Getting Started",
                    icon = shiny::icon("play-circle"),
                    shiny::div(
                        if (is_pt) {
                            shiny::HTML("
                <h5>Como usar o Finch</h5>
                <ol>
                  <li><strong>Upload:</strong> FaÃ§a upload do seu arquivo CSV com dados de biodiversidade.</li>
                  <li><strong>Mapeamento:</strong> Associe suas colunas aos termos Darwin Core. Use o botÃ£o 'Auto-mapear' para detecÃ§Ã£o automÃ¡tica.</li>
                  <li><strong>PrÃ©-visualizaÃ§Ã£o:</strong> Verifique os dados mapeados antes de exportar.</li>
                  <li><strong>ValidaÃ§Ã£o:</strong> Valide nomes cientÃ­ficos e coordenadas.</li>
                  <li><strong>Download:</strong> Baixe o CSV no padrÃ£o DwC.</li>
                </ol>
              ")
                        } else {
                            shiny::HTML("
                <h5>How to use Finch</h5>
                <ol>
                  <li><strong>Upload:</strong> Upload your CSV file with biodiversity data.</li>
                  <li><strong>Mapping:</strong> Map your columns to Darwin Core terms. Use the 'Auto-map' button for automatic detection.</li>
                  <li><strong>Preview:</strong> Check mapped data before exporting.</li>
                  <li><strong>Validation:</strong> Validate scientific names and coordinates.</li>
                  <li><strong>Download:</strong> Download the DwC-compliant CSV.</li>
                </ol>
              ")
                        }
                    )
                ),

                # What is Darwin Core
                bslib::accordion_panel(
                    title = if (is_pt) "2. O que Ã© Darwin Core?" else "2. What is Darwin Core?",
                    icon = shiny::icon("info-circle"),
                    shiny::div(
                        if (is_pt) {
                            shiny::HTML("
                <p>O <strong>Darwin Core (DwC)</strong> Ã© um padrÃ£o de dados para compartilhamento de informaÃ§Ãµes sobre biodiversidade, mantido pela <a href='https://www.tdwg.org/' target='_blank'>TDWG</a>.</p>
                <p>Ele fornece um vocabulÃ¡rio estÃ¡vel de termos para descrever:</p>
                <ul>
                  <li>OcorrÃªncias de espÃ©cies</li>
                  <li>LocalizaÃ§Ãµes geogrÃ¡ficas</li>
                  <li>Taxonomia</li>
                  <li>Eventos de coleta</li>
                </ul>
                <p>O SiBBr (Sistema de InformaÃ§Ã£o sobre a Biodiversidade Brasileira) utiliza o Darwin Core como padrÃ£o para seus dados.</p>
              ")
                        } else {
                            shiny::HTML("
                <p><strong>Darwin Core (DwC)</strong> is a data standard for sharing biodiversity information, maintained by <a href='https://www.tdwg.org/' target='_blank'>TDWG</a>.</p>
                <p>It provides a stable vocabulary of terms to describe:</p>
                <ul>
                  <li>Species occurrences</li>
                  <li>Geographic locations</li>
                  <li>Taxonomy</li>
                  <li>Collection events</li>
                </ul>
                <p>SiBBr (Brazilian Biodiversity Information System) uses Darwin Core as its data standard.</p>
              ")
                        }
                    )
                ),

                # FAQ
                bslib::accordion_panel(
                    title = if (is_pt) "3. Perguntas Frequentes" else "3. FAQ",
                    icon = shiny::icon("question-circle"),
                    shiny::div(
                        if (is_pt) {
                            shiny::HTML("
                <h6>Quais formatos de arquivo sÃ£o aceitos?</h6>
                <p>Apenas arquivos CSV (.csv) sÃ£o aceitos.</p>

                <h6>Qual o tamanho mÃ¡ximo de arquivo?</h6>
                <p>O limite padrÃ£o Ã© 30MB. Para arquivos maiores, entre em contato com o administrador.</p>

                <h6>Como funciona o auto-mapeamento?</h6>
                <p>O sistema compara os nomes das suas colunas com os termos DwC e sugere correspondÃªncias baseadas em similaridade.</p>

                <h6>Os dados sÃ£o salvos em algum servidor?</h6>
                <p>NÃ£o. Todo o processamento Ã© feito localmente na sua sessÃ£o. Nenhum dado Ã© armazenado.</p>
              ")
                        } else {
                            shiny::HTML("
                <h6>What file formats are accepted?</h6>
                <p>Only CSV files (.csv) are accepted.</p>

                <h6>What is the maximum file size?</h6>
                <p>The default limit is 30MB. For larger files, contact the administrator.</p>

                <h6>How does auto-mapping work?</h6>
                <p>The system compares your column names with DwC terms and suggests matches based on similarity.</p>

                <h6>Is my data saved on any server?</h6>
                <p>No. All processing is done locally in your session. No data is stored.</p>
              ")
                        }
                    )
                ),

                # Contact
                bslib::accordion_panel(
                    title = if (is_pt) "4. Suporte" else "4. Support",
                    icon = shiny::icon("envelope"),
                    shiny::div(
                        if (is_pt) {
                            shiny::HTML("
                <p>Para dÃºvidas ou sugestÃµes, entre em contato:</p>
                <ul>
                  <li>Email: suporte@finch.org.br</li>
                  <li>GitHub: <a href='https://github.com/finch-project' target='_blank'>github.com/finch-project</a></li>
                </ul>
              ")
                        } else {
                            shiny::HTML("
                <p>For questions or suggestions, contact us:</p>
                <ul>
                  <li>Email: support@finch.org.br</li>
                  <li>GitHub: <a href='https://github.com/finch-project' target='_blank'>github.com/finch-project</a></li>
                </ul>
              ")
                        }
                    )
                )
            )
        })
    })
}
