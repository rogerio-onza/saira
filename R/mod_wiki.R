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

    shiny::tagList(
        shiny::div(
            class = "container-fluid wiki-module",
            shiny::uiOutput(ns("header_card")),
            shiny::uiOutput(ns("toolbar_card")),
            shiny::div(
                class = "wiki-table saira-table-shell",
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

        dwc_terms <- get_dwc_full_catalog()

        # i18n keys for all 12 catalog classes. Falls back to raw class name
        # if a future class isn't covered.
        class_tr_keys <- c(
            "Record-level"         = "class_record",
            "Occurrence"           = "class_occurrence",
            "Event"                = "class_event",
            "Location"             = "class_location",
            "Identification"       = "class_identification",
            "Taxon"                = "class_taxon",
            "GeologicalContext"    = "class_geologicalcontext",
            "MaterialEntity"       = "class_materialentity",
            "MaterialSample"       = "class_materialsample",
            "MeasurementOrFact"    = "class_measurementorfact",
            "Organism"             = "class_organism",
            "ResourceRelationship" = "class_resourcerelationship"
        )

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
            highlight_word <- if (identical(lang_r(), "pt")) "Termos" else "Terms"
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

            definition_col <- switch(
                lang_r(),
                pt = "definition_pt",
                en = "definition_en",
                "definition_en"
            )

            df <- df[, c("term", "class", definition_col, "required")]
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

            row_callback_js <- DT::JS(
                sprintf(
                    paste0(
                        "function(row, data) {",
                        "  var labels = %s;",
                        "  var termUrl = %s;",
                        "  var classSlugMap = %s;",
                        "  var normalizeBoolean = function(value) {",
                        "    var normalized = String(value === null || value === undefined ? '' : value).trim().toLowerCase();",
                        "    return value === true || value === 1 || normalized === 'true' || normalized === '1' || normalized === 'yes' || normalized === 'sim';",
                        "  };",
                        "  var escapeHtml = function(value) {",
                        "    return String(value === null || value === undefined ? '' : value)",
                        "      .replace(/&/g, '&amp;')",
                        "      .replace(/</g, '&lt;')",
                        "      .replace(/>/g, '&gt;')",
                        "      .replace(/\\\"/g, '&quot;')",
                        "      .replace(/'/g, '&#39;');",
                        "  };",
                        "  var requiredIcon = \"<svg width='9' height='9' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='3'><polyline points='20 6 9 17 4 12'/></svg>\";",
                        "  var termText = String(data[0] === null || data[0] === undefined ? '' : data[0]);",
                        "  var classText = String(data[1] === null || data[1] === undefined ? '' : data[1]);",
                        "  var definitionText = String(data[2] === null || data[2] === undefined ? '' : data[2]);",
                        "  var isRequired = normalizeBoolean(data[3]);",
                        "  var classSlug = classSlugMap[classText.trim().toLowerCase()] || 'record-level';",
                        "  $('td:eq(0)', row).html(\"<a class='wiki-term-link' href='\" + termUrl + \"' target='_blank' rel='noopener noreferrer'>\" + escapeHtml(termText) + \"</a>\");",
                        "  $('td:eq(1)', row).html(\"<span class='wiki-class-badge wiki-class-badge--\" + classSlug + \"'>\" + escapeHtml(classText) + \"</span>\");",
                        "  var $definitionCell = $('td:eq(2)', row);",
                        "  $definitionCell.text(definitionText);",
                        "  $definitionCell.toggleClass('is-required', isRequired);",
                        "  if (isRequired) {",
                        "    $('td:eq(3)', row).html(\"<span class='wiki-required-badge wiki-required-badge--true'>\" + requiredIcon + escapeHtml(labels.required) + \"</span>\");",
                        "  } else {",
                        "    $('td:eq(3)', row).html(\"<span class='wiki-required-badge wiki-required-badge--false'>\" + escapeHtml(labels.optional) + \"</span>\");",
                        "  }",
                        "  $('td:eq(3)', row).addClass('wiki-required-cell');",
                        "}"
                    ),
                    jsonlite::toJSON(required_badge_labels, auto_unbox = TRUE),
                    jsonlite::toJSON("https://sibbr.gov.br", auto_unbox = TRUE),
                    jsonlite::toJSON(class_slug_js_map, auto_unbox = TRUE)
                )
            )

            header_callback_js <- DT::JS(
                paste0(
                    "function(thead) {",
                    "  var sortIcon = \"<svg class='wiki-sort-icon' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2.5'><path d='m7 15 5 5 5-5'></path><path d='m7 9 5-5 5 5'></path></svg>\";",
                    "  $(thead).find('th').each(function(index) {",
                    "    var $th = $(this);",
                    "    var label = $th.text();",
                    "    var centerClass = index === 3 ? ' wiki-th-content--center' : '';",
                    "    if ($th.find('.wiki-th-content').length === 0) {",
                    "      $th.html(\"<div class='wiki-th-content\" + centerClass + \"'><span class='wiki-th-label'>\" + label + \"</span>\" + sortIcon + \"</div>\");",
                    "    }",
                    "  });",
                    "}"
                )
            )

            filter_callback_js <- DT::JS(
                sprintf(
                    paste0(
                        "var searchInputId = %s;",
                        "var classFilterId = %s;",
                        "var pageLengthId = %s;",
                        "var searchSelector = '#' + searchInputId;",
                        "var classSelector = '#' + classFilterId;",
                        "var pageSelector = '#' + pageLengthId;",
                        "var pillsSelector = '.wiki-filter-pill';",
                        "var nsSafe = searchInputId.replace(/[^a-zA-Z0-9_-]/g, '');",
                        "var eventNs = '.wikiFilter.' + nsSafe;",
                        "var $doc = $(document);",
                        "var getModule = function() {",
                        "  var $candidate = $(searchSelector).closest('.wiki-module');",
                        "  if ($candidate.length) {",
                        "    return $candidate;",
                        "  }",
                        "  $candidate = $(classSelector).closest('.wiki-module');",
                        "  if ($candidate.length) {",
                        "    return $candidate;",
                        "  }",
                        "  $candidate = $(pageSelector).closest('.wiki-module');",
                        "  if ($candidate.length) {",
                        "    return $candidate;",
                        "  }",
                        "  return $(table.table().container()).closest('.wiki-module');",
                        "};",
                        "var $module = getModule();",
                        "var getPills = function() {",
                        "  return $module.length ? $module.find(pillsSelector) : $(pillsSelector);",
                        "};",
                        "var getClassFilter = function() { return $(classSelector); };",
                        "var getPageLength = function() { return $(pageSelector); };",
                        "var setActivePill = function(filterValue) {",
                        "  var value = String(filterValue || '');",
                        "  var $pills = getPills();",
                        "  if (!$pills.length) {",
                        "    return;",
                        "  }",
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
                        "  table.column(1).search(value).draw(false);",
                        "  setActivePill(value);",
                        "  if (syncSelect) {",
                        "    var $classFilter = getClassFilter();",
                        "    if ($classFilter.length && String($classFilter.val() || '') !== value) {",
                        "      $classFilter.val(value);",
                        "    }",
                        "  }",
                        "};",
                        "var applyGlobalSearch = function(value) {",
                        "  table.search(String(value || '')).draw(false);",
                        "};",
                        "var applyPageLength = function(value) {",
                        "  var len = parseInt(value, 10);",
                        "  if (!isNaN(len) && len > 0) {",
                        "    table.page.len(len).draw(false);",
                        "  }",
                        "};",
                        "$doc.off('input' + eventNs, searchSelector);",
                        "$doc.off('keyup' + eventNs, searchSelector);",
                        "$doc.off('search' + eventNs, searchSelector);",
                        "$doc.off('change' + eventNs, classSelector);",
                        "$doc.off('change' + eventNs, pageSelector);",
                        "$doc.off('click' + eventNs, pillsSelector);",
                        "$doc.on('input' + eventNs, searchSelector, function() {",
                        "  applyGlobalSearch(this.value);",
                        "});",
                        "$doc.on('keyup' + eventNs, searchSelector, function() {",
                        "  applyGlobalSearch(this.value);",
                        "});",
                        "$doc.on('search' + eventNs, searchSelector, function() {",
                        "  applyGlobalSearch(this.value);",
                        "});",
                        "$doc.on('change' + eventNs, classSelector, function() {",
                        "  applyClassFilter($(this).val() || '', false);",
                        "});",
                        "$doc.on('click' + eventNs, pillsSelector, function() {",
                        "  if ($module.length && $(this).closest('.wiki-module')[0] !== $module[0]) {",
                        "    return;",
                        "  }",
                        "  var value = $(this).attr('data-filter') || '';",
                        "  applyClassFilter(value, true);",
                        "});",
                        "$doc.on('change' + eventNs, pageSelector, function() {",
                        "  applyPageLength($(this).val());",
                        "});",
                        "table.off('length.dt' + eventNs).on('length.dt' + eventNs, function(e, settings, len) {",
                        "  var $pageLength = getPageLength();",
                        "  if ($pageLength.length) {",
                        "    $pageLength.val(String(len));",
                        "  }",
                        "});",
                        "var $searchInput = $(searchSelector);",
                        "if ($searchInput.length) {",
                        "  table.search($searchInput.val() || '');",
                        "}",
                        "var $classFilter = getClassFilter();",
                        "if ($classFilter.length) {",
                        "  applyClassFilter($classFilter.val() || '', false);",
                        "} else {",
                        "  applyClassFilter('', false);",
                        "}",
                        "var $pageLength = getPageLength();",
                        "if ($pageLength.length) {",
                        "  var selectedLen = parseInt($pageLength.val(), 10);",
                        "  if (!isNaN(selectedLen)) {",
                        "    table.page.len(selectedLen);",
                        "  }",
                        "  $pageLength.val(String(table.page.len()));",
                        "}",
                        "table.draw(false);"
                    ),
                    jsonlite::toJSON(ns("search"), auto_unbox = TRUE),
                    jsonlite::toJSON(ns("class_filter"), auto_unbox = TRUE),
                    jsonlite::toJSON(ns("page_length"), auto_unbox = TRUE)
                )
            )

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
