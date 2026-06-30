# Title: Preview Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-15
# Version: 2.0

#' Preview Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_preview_ui <- function(id) {
    ns <- shiny::NS(id)

    shiny::tagList(
        shiny::div(
            class = "container-fluid preview-page",
            shiny::uiOutput(ns("title")),
            shiny::uiOutput(ns("subtitle")),

            # Data table
            shiny::uiOutput(ns("table_or_message"))
        )
    )
}

#' Preview Module Server
#'
#' Read-only preview of the mapped Darwin Core data. The download/export flow
#' lives in the dedicated Export tab (ADR-103), so this module only renders the
#' preview table.
#'
#' @param id Module ID
#' @param mapped_data_r Reactive data frame with mapped data
#' @param lang_r Reactive language value
#' @return Reactive preview data frame
#' @export
mod_preview_server <- function(id, mapped_data_r, lang_r) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        output$title <- shiny::renderUI({
            shiny::h3(tr("preview_title", lang_r()), class = "text-mono")
        })

        output$subtitle <- shiny::renderUI({
            shiny::p(tr("preview_subtitle", lang_r()), class = "text-accent")
        })

        preview_data <- shiny::reactive({
            shiny::req(mapped_data_r())
            prepare_preview_data(mapped_data_r(), max_rows = 100L)
        })

        output$table_or_message <- shiny::renderUI({
            df <- mapped_data_r()
            if (is.null(df) || !is.data.frame(df) || ncol(df) == 0L || nrow(df) == 0L) {
                shiny::div(
                    class = "preview-empty-state",
                    shiny::icon("table", class = "fa-3x"),
                    shiny::h4(tr("preview_no_data_title", lang_r())),
                    shiny::p(tr("preview_no_data", lang_r()))
                )
            } else {
                shiny::div(
                    class = "preview-table-shell saira-table-shell",
                    DT::dataTableOutput(ns("datatable"))
                )
            }
        })

        output$datatable <- DT::renderDataTable({
            shiny::req(preview_data())

            preview_df <- preview_data()
            empty_mask <- vapply(
                preview_df,
                FUN = is_preview_empty_column,
                FUN.VALUE = logical(1)
            )
            empty_indices <- which(empty_mask) - 1L

            truncation_js <- DT::JS(
                "function(data, type, row, meta) {",
                "  if (data === null || data === undefined) { return data; }",
                "  var text = String(data);",
                "  if (type === 'display') {",
                "    var escaped = $('<div/>').text(text).html();",
                "    if (text.length > 80) {",
                "      return '<span title=\"' + escaped + '\">' + escaped.substr(0, 80) + '...</span>';",
                "    }",
                "    return escaped;",
                "  }",
                "  return data;",
                "}"
            )

            column_defs <- list(
                list(
                    targets = "_all",
                    render = truncation_js
                )
            )

            if (length(empty_indices) > 0L) {
                column_defs[[length(column_defs) + 1L]] <- list(
                    targets = as.integer(empty_indices),
                    className = "preview-col-empty"
                )
            }

            init_complete_js <- DT::JS(
                sprintf(
                    paste0(
                        "function(settings, json) {",
                        "  var emptyCols = %s;",
                        "  if (!Array.isArray(emptyCols) || emptyCols.length === 0) { return; }",
                        "  var api = this.api();",
                        "  api.columns().every(function(idx) {",
                        "    if (emptyCols.indexOf(idx) !== -1) {",
                        "      $(api.column(idx).header()).addClass('preview-col-empty');",
                        "    }",
                        "  });",
                        "}"
                    ),
                    jsonlite::toJSON(as.integer(empty_indices))
                )
            )

            DT::datatable(
                preview_df,
                options = list(
                    pageLength = 10,
                    lengthMenu = c(10, 25, 50, 100),
                    scrollX = TRUE,
                    # Frozen DwC header: the table owns its vertical scroll so the
                    # header row (the DwC term names) stays visible while scrolling
                    # rows. The preview tab is taken out of the page-scroll
                    # override (12-overrides.css), so only the table body scrolls.
                    # The offset reserves room for the navbar, title/subtitle and
                    # the DT search/info/pagination controls; tune it if the
                    # surrounding layout changes.
                    scrollY = "calc(100vh - 20rem)",
                    scrollCollapse = TRUE,
                    autoWidth = FALSE,
                    columnDefs = column_defs,
                    initComplete = init_complete_js,
                    language = list(
                        search = tr("preview_datatable_search", lang_r()),
                        lengthMenu = tr("preview_datatable_length_menu", lang_r()),
                        info = tr("preview_datatable_info", lang_r()),
                        emptyTable = tr("preview_datatable_empty", lang_r()),
                        zeroRecords = tr("preview_datatable_zero_records", lang_r()),
                        paginate = list(
                            first = tr("preview_datatable_first", lang_r()),
                            last = tr("preview_datatable_last", lang_r()),
                            `next` = tr("preview_datatable_next", lang_r()),
                            previous = tr("preview_datatable_prev", lang_r())
                        )
                    )
                ),
                class = "display compact stripe",
                rownames = FALSE
            )
        })

        shiny::outputOptions(output, "datatable", priority = 10)

        return(preview_data)
    })
}
