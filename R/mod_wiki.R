# Title: Wiki Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-23
# Version: 1.3

#' Wiki Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_wiki_ui <- function(id) {
    ns <- shiny::NS(id)

    htmltools::attachDependencies(shiny::tagList(
        shiny::div(
            class = "container-fluid wiki-module",
            shiny::uiOutput(ns("header_card")),
            shiny::uiOutput(ns("toolbar_card")),
            shiny::div(
                class = "wiki-table saira-table-shell",
                DT::dataTableOutput(ns("terms_table"))
            )
        )
    ), module_behavior_dependency())
}

#' Wiki Module Server
#'
#' @param id Module ID
#' @param lang_r Reactive language value
#' @export
mod_wiki_server <- function(id, lang_r) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        dwc_terms <- get_dwc_full_catalog()

        # i18n keys for all 21 catalog classes. Falls back to raw class name
        # if a future class isn't covered.
        class_tr_keys <- dwc_class_translation_keys()

        get_class_label <- function(cls, lang) {
            key <- unname(class_tr_keys[cls])
            if (is.na(key)) cls else tr(key, lang)
        }

        catalog_classes <- sort(unique(dwc_terms$class))
        class_values    <- c("", catalog_classes)
        class_slug_map  <- stats::setNames(
            c("all", tolower(gsub("[^a-zA-Z0-9]+", "-", catalog_classes))),
            class_values
        )

        info_icon_svg <- paste0(
            "<svg width='13' height='13' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'>",
            "<circle cx='12' cy='12' r='9'></circle>",
            "<path d='M12 8h.01'></path>",
            "<path d='M11 12h1v4h1'></path>",
            "</svg>"
        )

        list_icon_svg <- paste0(
            "<svg width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2.3'>",
            "<line x1='8' y1='6' x2='20' y2='6'></line>",
            "<line x1='8' y1='12' x2='20' y2='12'></line>",
            "<line x1='8' y1='18' x2='20' y2='18'></line>",
            "<circle cx='4' cy='6' r='1'></circle>",
            "<circle cx='4' cy='12' r='1'></circle>",
            "<circle cx='4' cy='18' r='1'></circle>",
            "</svg>"
        )

        check_icon_svg <- paste0(
            "<svg width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2.4'>",
            "<polyline points='20 6 9 17 4 12'></polyline>",
            "</svg>"
        )

        grid_icon_svg <- paste0(
            "<svg width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2.3'>",
            "<rect x='4' y='4' width='6' height='6'></rect>",
            "<rect x='14' y='4' width='6' height='6'></rect>",
            "<rect x='4' y='14' width='6' height='6'></rect>",
            "<rect x='14' y='14' width='6' height='6'></rect>",
            "</svg>"
        )

        class_labels <- shiny::reactive({
            lang <- lang_r()
            c(
                tr("wiki_class_all", lang),
                vapply(
                    catalog_classes,
                    function(cls) get_class_label(cls, lang),
                    FUN.VALUE = character(1)
                )
            )
        })

        build_stat_pill <- function(icon_svg, value, label) {
            shiny::tags$div(
                class = "wiki-stat-pill",
                shiny::tags$span(class = "wiki-stat-icon", shiny::HTML(icon_svg)),
                shiny::tags$span(class = "wiki-stat-value", as.character(value)),
                shiny::tags$span(class = "wiki-stat-label", label)
            )
        }

        output$header_card <- shiny::renderUI({
            term_count <- nrow(dwc_terms)
            required_count <- sum(as.logical(dwc_terms$required), na.rm = TRUE)
            class_count <- length(unique(as.character(dwc_terms$class)))

            title_text <- tr("wiki_title", lang_r())
            highlight_word <- tr("wiki_title_accent", lang_r())
            highlighted_title <- title_text
            if (grepl(highlight_word, title_text, fixed = TRUE)) {
                highlighted_title <- sub(
                    highlight_word,
                    paste0("<span class='wiki-title-accent'>", highlight_word, "</span>"),
                    title_text,
                    fixed = TRUE
                )
            }

            shiny::tags$div(
                class = "wiki-header-card",
                shiny::tags$div(
                    class = "wiki-header-left",
                    shiny::tags$div(class = "wiki-header-eyebrow", tr("wiki_header_eyebrow", lang_r())),
                    shiny::tags$h1(class = "wiki-header-title", shiny::HTML(highlighted_title)),
                    shiny::tags$div(
                        class = "wiki-header-subtitle",
                        shiny::tags$span(class = "wiki-header-subtitle-icon", shiny::HTML(info_icon_svg)),
                        shiny::tags$span(tr("wiki_subtitle", lang_r())),
                        shiny::tags$a(
                            href = "https://sibbr.gov.br",
                            class = "wiki-header-link",
                            target = "_blank",
                            rel = "noopener noreferrer",
                            tr("wiki_header_link_label", lang_r())
                        )
                    )
                ),
                shiny::tags$div(
                    class = "wiki-header-stats",
                    build_stat_pill(list_icon_svg, term_count, tr("wiki_stats_terms_label", lang_r())),
                    build_stat_pill(check_icon_svg, required_count, tr("wiki_stats_required_label", lang_r())),
                    build_stat_pill(grid_icon_svg, class_count, tr("wiki_stats_classes_label", lang_r()))
                )
            )
        })

        output$toolbar_card <- shiny::renderUI({
            labels <- class_labels()

            pills <- lapply(seq_along(class_values), function(i) {
                value <- class_values[[i]]
                slug <- if (!nzchar(value)) "all" else unname(class_slug_map[value])
                if (is.na(slug) || !nzchar(slug)) {
                    slug <- "all"
                }
                is_active <- identical(value, "")
                shiny::tags$button(
                    type = "button",
                    class = paste(
                        "wiki-filter-pill",
                        paste0("wiki-filter-pill--", slug),
                        if (is_active) "active" else ""
                    ),
                    `data-filter` = value,
                    `aria-pressed` = if (is_active) "true" else "false",
                    shiny::tags$span(class = "wiki-filter-pill-dot"),
                    shiny::tags$span(class = "wiki-filter-pill-text", labels[[i]])
                )
            })

            shiny::tags$div(
                class = "wiki-toolbar-card",
                shiny::tags$div(
                    class = "wiki-toolbar-row wiki-toolbar-row-top",
                    shiny::tags$div(
                        class = "wiki-search-wrap",
                        shiny::tags$label(
                            `for` = ns("search"),
                            class = "visually-hidden",
                            tr("a11y_wiki_search_label", lang_r())
                        ),
                        shiny::tags$span(
                            class = "wiki-search-icon",
                            shiny::HTML(
                                paste0(
                                    "<svg width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2.2'>",
                                    "<circle cx='11' cy='11' r='7'></circle>",
                                    "<path d='m20 20-3.5-3.5'></path>",
                                    "</svg>"
                                )
                            )
                        ),
                        shiny::tags$input(
                            id = ns("search"),
                            type = "search",
                            class = "wiki-search-input",
                            placeholder = tr("wiki_search_placeholder", lang_r()),
                            autocomplete = "off",
                            spellcheck = "false"
                        )
                    ),
                    shiny::tags$div(
                        class = "wiki-show-wrap",
                        shiny::tags$label(class = "wiki-show-label", tr("wiki_show_label", lang_r())),
                        shiny::tags$label(
                            `for` = ns("page_length"),
                            class = "visually-hidden",
                            tr("a11y_wiki_page_length_label", lang_r())
                        ),
                        shiny::tags$select(
                            id = ns("page_length"),
                            class = "wiki-show-select",
                            `aria-label` = tr("a11y_wiki_page_length_label", lang_r()),
                            lapply(c(10, 15, 25, 50, 100), function(size) {
                                shiny::tags$option(value = size, size)
                            })
                        ),
                        shiny::tags$span(class = "wiki-show-records", tr("wiki_records_label", lang_r()))
                    )
                ),
                shiny::tags$div(
                    class = "wiki-toolbar-row wiki-toolbar-row-bottom",
                    shiny::tags$span(class = "wiki-filter-label", tr("wiki_class", lang_r())),
                    shiny::tags$div(class = "wiki-filter-pills", pills)
                ),
                shiny::tags$div(
                    class = "wiki-class-filter-compat",
                    shiny::tags$label(
                        `for` = ns("class_filter"),
                        class = "visually-hidden",
                        tr("a11y_wiki_class_filter_label", lang_r())
                    ),
                    shiny::tags$select(
                        id = ns("class_filter"),
                        class = "wiki-class-filter-select",
                        lapply(seq_along(class_values), function(i) {
                            value <- class_values[[i]]
                            label <- labels[[i]]
                            if (identical(value, "")) {
                                shiny::tags$option(value = value, selected = "selected", label)
                            } else {
                                shiny::tags$option(value = value, label)
                            }
                        })
                    )
                )
            )
        })

        terms_table_data <- shiny::reactive({
            df <- dwc_terms

            df$definition <- lang_col(df, "definition", lang_r())
            df <- df[, c("term", "class", "definition", "required")]
            names(df) <- c(
                tr("wiki_term", lang_r()),
                tr("wiki_class", lang_r()),
                tr("wiki_definition", lang_r()),
                tr("wiki_required", lang_r())
            )

            df
        })

        # JS lookup map: lowercase class name -> CSS slug (covers all 12 catalog
        # classes; built from R so new TDWG classes pick up the right badge slug
        # without editing JS literals).
        class_slug_js_map <- as.list(stats::setNames(
            unname(class_slug_map[catalog_classes]),
            tolower(catalog_classes)
        ))

        output$terms_table <- DT::renderDataTable({
            required_badge_labels <- list(
                required = tr("wiki_required_badge_required", lang_r()),
                optional = tr("wiki_required_badge_optional", lang_r())
            )

            row_callback_js <- DT::JS(module_behavior_call("wikiTermRow", list(
                labels = required_badge_labels,
                termUrl = "https://sibbr.gov.br",
                classSlugs = class_slug_js_map
            )))
            header_callback_js <- DT::JS(module_behavior_call("wikiTableHeader"))
            filter_callback_js <- DT::JS(module_behavior_call("wikiTableFilters", list(
                searchId = ns("search"), classId = ns("class_filter"), pageId = ns("page_length")
            ), table_context = TRUE))

            DT::datatable(
                terms_table_data(),
                options = list(
                    pageLength = 10,
                    lengthMenu = c(10, 15, 25, 50, 100),
                    dom = "t<'wiki-table-footer'ip>",
                    scrollX = TRUE,
                    autoWidth = FALSE,
                    rowCallback = row_callback_js,
                    headerCallback = header_callback_js,
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
                class = "display",
                rownames = FALSE,
                escape = FALSE
            )
        }, server = FALSE)
    })
}
