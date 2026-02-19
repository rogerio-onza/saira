# Title: Wiki Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-19
# Version: 1.2

#' Wiki Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_wiki_ui <- function(id) {
    ns <- shiny::NS(id)

    shiny::tagList(
        shiny::div(
            class = "container-fluid wiki-module",
            shiny::uiOutput(ns("title")),
            shiny::uiOutput(ns("subtitle")),
            shiny::br(),

            # Search input (primary) + hidden class filter for compatibility
            shiny::uiOutput(ns("search_input")),
            shiny::div(
                class = "wiki-class-filter-compat",
                shiny::uiOutput(ns("class_filter_input"))
            ),
            shiny::uiOutput(ns("class_filter_pills")),

            # Terms table
            shiny::div(
                class = "wiki-table finch-table-shell",
                DT::dataTableOutput(ns("terms_table"))
            )
        )
    )
}

#' Wiki Module Server
#'
#' @param id Module ID
#' @param lang_r Reactive language value
#' @export
mod_wiki_server <- function(id, lang_r) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        dwc_terms <- get_dwc_terms()
        class_values <- c("", "Record-level", "Occurrence", "Event", "Location", "Identification", "Taxon")

        class_labels <- shiny::reactive({
            c(
                tr("wiki_class_all", lang_r()),
                tr("class_record", lang_r()),
                tr("class_occurrence", lang_r()),
                tr("class_event", lang_r()),
                tr("class_location", lang_r()),
                tr("class_identification", lang_r()),
                tr("class_taxon", lang_r())
            )
        })

        output$title <- shiny::renderUI({
            shiny::h3(tr("wiki_title", lang_r()), class = "text-mono")
        })

        output$subtitle <- shiny::renderUI({
            shiny::p(tr("wiki_subtitle", lang_r()), class = "text-accent")
        })

        output$search_input <- shiny::renderUI({
            shiny::textInput(
                inputId = ns("search"),
                label = NULL,
                placeholder = tr("wiki_search_placeholder", lang_r()),
                width = "100%"
            )
        })

        output$class_filter_input <- shiny::renderUI({
            current_value <- input$class_filter
            if (is.null(current_value)) {
                current_value <- ""
            }

            shiny::selectInput(
                inputId = ns("class_filter"),
                label = NULL,
                choices = stats::setNames(class_values, class_labels()),
                selected = current_value,
                width = "100%"
            )
        })

        output$class_filter_pills <- shiny::renderUI({
            labels <- class_labels()
            buttons <- lapply(seq_along(class_values), function(i) {
                is_active <- i == 1L
                shiny::tags$button(
                    type = "button",
                    class = paste(
                        "dwc-tab-btn wiki-filter-pill",
                        if (is_active) "active" else ""
                    ),
                    `data-filter` = class_values[[i]],
                    `aria-pressed` = if (is_active) "true" else "false",
                    labels[[i]]
                )
            })
            shiny::div(
                class = "wiki-filter-pills",
                buttons
            )
        })

        terms_table_data <- shiny::reactive({
            df <- dwc_terms

            definition_col <- switch(
                lang_r(),
                pt = "definition_pt",
                en = "definition_en",
                "definition_en"
            )

            df <- df[, c("term", "class", definition_col, "examples", "required")]
            names(df) <- c(
                tr("wiki_term", lang_r()),
                tr("wiki_class", lang_r()),
                tr("wiki_definition", lang_r()),
                tr("wiki_example", lang_r()),
                tr("wiki_required", lang_r())
            )

            df
        })

        output$terms_table <- DT::renderDataTable({
            required_badge_labels <- list(
                required = tr("wiki_required_badge_required", lang_r()),
                optional = tr("wiki_required_badge_optional", lang_r())
            )

            required_badge_js <- DT::JS(
                sprintf(
                    paste0(
                        "function(data, type, row) {",
                        "  if (type !== 'display') {",
                        "    return data;",
                        "  }",
                        "  var value = data;",
                        "  var normalized = String(value === null || value === undefined ? '' : value).trim().toLowerCase();",
                        "  var isRequired = (value === true || value === 1 || normalized === 'true' || normalized === '1' || normalized === 'yes' || normalized === 'sim');",
                        "  var labels = %s;",
                        "  if (isRequired) {",
                        "    return '<span class=\"dwc-required-badge dwc-required-true\">' + labels.required + '</span>';",
                        "  }",
                        "  return '<span class=\"dwc-required-badge dwc-required-false\">' + labels.optional + '</span>';",
                        "}"
                    ),
                    jsonlite::toJSON(required_badge_labels, auto_unbox = TRUE)
                )
            )

            filter_callback_js <- DT::JS(
                sprintf(
                    paste0(
                        "var searchInputId = %s;",
                        "var classFilterId = %s;",
                        "var $searchInput = $('#' + searchInputId);",
                        "var $classFilter = $('#' + classFilterId);",
                        "var $module = $(table.table().container()).closest('.wiki-module');",
                        "var $pills = $module.find('.wiki-filter-pill');",
                        "var setActivePill = function(filterValue) {",
                        "  var value = String(filterValue || '');",
                        "  $pills.removeClass('active').attr('aria-pressed', 'false');",
                        "  var $target = $pills.filter(function() {",
                        "    return String($(this).attr('data-filter') || '') === value;",
                        "  });",
                        "  if ($target.length === 0) {",
                        "    $target = $pills.filter('[data-filter=\"\"]');",
                        "  }",
                        "  $target.addClass('active').attr('aria-pressed', 'true');",
                        "};",
                        "var applyClassFilter = function(filterValue, syncSelect) {",
                        "  var value = String(filterValue || '');",
                        "  table.column(1).search(value).draw();",
                        "  setActivePill(value);",
                        "  if (syncSelect && $classFilter.length && String($classFilter.val() || '') !== value) {",
                        "    $classFilter.val(value).trigger('change');",
                        "  }",
                        "};",
                        "$searchInput.off('input.wikiFilter').on('input.wikiFilter', function() {",
                        "  table.search(this.value || '').draw();",
                        "});",
                        "$classFilter.off('change.wikiFilter').on('change.wikiFilter', function() {",
                        "  applyClassFilter($(this).val() || '', false);",
                        "});",
                        "$pills.off('click.wikiFilter').on('click.wikiFilter', function() {",
                        "  var value = $(this).attr('data-filter') || '';",
                        "  applyClassFilter(value, true);",
                        "});",
                        "if ($searchInput.length) {",
                        "  table.search($searchInput.val() || '');",
                        "}",
                        "if ($classFilter.length) {",
                        "  applyClassFilter($classFilter.val() || '', false);",
                        "} else {",
                        "  applyClassFilter('', false);",
                        "}"
                    ),
                    jsonlite::toJSON(ns("search"), auto_unbox = TRUE),
                    jsonlite::toJSON(ns("class_filter"), auto_unbox = TRUE)
                )
            )

            DT::datatable(
                terms_table_data(),
                options = list(
                    pageLength = 10,
                    lengthMenu = c(10, 25, 50, 100),
                    scrollX = TRUE,
                    columnDefs = list(
                        list(
                            targets = 4,
                            render = required_badge_js
                        )
                    ),
                    language = list(
                        search = tr("wiki_datatable_search", lang_r()),
                        lengthMenu = tr("wiki_datatable_length_menu", lang_r()),
                        info = tr("wiki_datatable_info", lang_r()),
                        emptyTable = tr("wiki_datatable_empty", lang_r()),
                        zeroRecords = tr("wiki_datatable_zero_records", lang_r()),
                        paginate = list(
                            first = tr("wiki_datatable_first", lang_r()),
                            last = tr("wiki_datatable_last", lang_r()),
                            `next` = tr("wiki_datatable_next", lang_r()),
                            previous = tr("wiki_datatable_prev", lang_r())
                        )
                    )
                ),
                callback = filter_callback_js,
                class = "display compact",
                rownames = FALSE,
                escape = FALSE
            )
        }, server = FALSE)
    })
}
