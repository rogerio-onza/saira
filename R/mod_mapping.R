# Title: Mapping Module - Darwin Core Field Mapping
# Author: RogÃ©rio Nunes Oliveira
# Date: 2026-02-09
# Version: 2.0 - Enhanced with filters and UUID generation

#' Mapping Module UI
#'
#' @param id Module namespace ID
#' @return Shiny UI tagList
#' @export
mod_mapping_ui <- function(id) {
    ns <- shiny::NS(id)

    bslib::layout_sidebar(
        sidebar = bslib::sidebar(
            width = 280,
            class = "mapping-sidebar",
            shiny::div(
                class = "stats-box",
                shiny::div(class = "stats-number", shiny::textOutput(ns("mapped_count"), inline = TRUE)),
                shiny::div(class = "stats-label", shiny::uiOutput(ns("label_mapped_fields"), inline = TRUE))
            ),
            shiny::div(
                class = "stats-box",
                shiny::div(class = "stats-number", shiny::textOutput(ns("total_fields"), inline = TRUE)),
                shiny::div(class = "stats-label", shiny::uiOutput(ns("label_total_fields"), inline = TRUE))
            ),
            shiny::hr(),
            shiny::div(
                class = "rostrum-switch-block",
                bslib::input_switch(
                    ns("enable_automap_v1"),
                    shiny::uiOutput(ns("toggle_automap_v1_label"), inline = TRUE),
                    value = FALSE
                )
            ),
            shiny::div(
                class = "mapping-beta-help",
                shiny::uiOutput(ns("toggle_automap_v1_help"), inline = TRUE)
            ),
            shiny::actionButton(
                ns("auto_map"),
                shiny::uiOutput(ns("btn_auto_map_label"), inline = TRUE),
                class = "btn-primary w-100 mb-2",
                icon = shiny::icon("wand-magic-sparkles")
            ),
            shiny::actionButton(
                ns("reset_mapping"),
                shiny::uiOutput(ns("btn_reset_label"), inline = TRUE),
                class = "btn-warning w-100 mb-2",
                icon = shiny::icon("rotate-left", class = "fa-solid")
            ),
            shiny::hr(),
            shiny::checkboxInput(
                ns("show_only_mapped"),
                shiny::uiOutput(ns("filter_mapped_label"), inline = TRUE),
                value = FALSE
            ),
            shiny::div(
                class = "category-filter-block",
                shiny::uiOutput(ns("filter_categories_label")),
                shiny::div(
                    class = "category-filter-select-all",
                    shiny::checkboxInput(
                        ns("select_all_categories"),
                        shiny::uiOutput(ns("filter_select_all_label"), inline = TRUE),
                        value = TRUE
                    )
                ),
                shiny::div(
                    class = "category-filter-options",
                    shiny::checkboxGroupInput(
                        ns("filter_categories"),
                        NULL,
                        choices = c(
                            "Record-level" = "Record-level",
                            "Occurrence" = "Occurrence",
                            "Event" = "Event",
                            "Location" = "Location",
                            "Taxon" = "Taxon",
                            "Identification" = "Identification"
                        ),
                        selected = c("Record-level", "Occurrence", "Event", "Location", "Taxon", "Identification")
                    )
                )
            )
        ),

        # Main content
        bslib::card(
            bslib::card_header(shiny::uiOutput(ns("card_title"))),
            bslib::card_body(
                min_height = "70vh",
                shiny::conditionalPanel(
                    condition = paste0("output['", ns("file_uploaded"), "']"),
                    shiny::div(
                        class = "mapping-scroll-container",
                        shiny::uiOutput(ns("mapping_ui"))
                    )
                ),
                shiny::conditionalPanel(
                    condition = paste0("!output['", ns("file_uploaded"), "']"),
                    shiny::div(
                        style = "text-align: center; padding: 60px; color: #95a5a6;",
                        shiny::icon("upload", style = "font-size: 4em; opacity: 0.3;"),
                        shiny::h4(shiny::uiOutput(ns("no_file_msg"))),
                        shiny::p(shiny::uiOutput(ns("upload_first_msg")))
                    )
                )
            )
        )
    )
}
#' Mapping Module Server
#'
#' @param id Module namespace ID
#' @param raw_data_r Reactive data frame from upload module
#' @param lang_r Reactive language code
#' @return Reactive containing processed/mapped data
#' @export
mod_mapping_server <- function(id, raw_data_r, lang_r) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        # Load dependencies

        # Reactive values
        rv <- shiny::reactiveValues(
            occurrence_ids = NULL,
            eventdate_parse_failures = 0L,
            last_eventdate_warn_count = NA_integer_,
            map_values = list(),
            map_meta = list(),
            basis_of_record_map = stats::setNames(character(0), character(0)),
            basis_of_record_auto_map = stats::setNames(character(0), character(0)),
            basis_of_record_source_col = "",
            basis_of_record_draft_map = stats::setNames(character(0), character(0)),
            basis_of_record_entries = data.frame(
                idx = integer(0),
                key = character(0),
                raw = character(0),
                stringsAsFactors = FALSE
            ),
            basis_of_record_page = 1L,
            is_programmatic_update = FALSE,
            programmatic_terms = character(0),
            automap_progress = 0L,
            automap_phrase_idx = 1L,
            automap_phrase_order = integer(0)
        )

        # Category filter options
        all_filter_categories <- c("Record-level", "Occurrence", "Event", "Location", "Taxon", "Identification")
        syncing_select_all <- shiny::reactiveVal(FALSE)

        category_labels <- function() {
            c(
                tr("class_record", lang_r()),
                tr("class_occurrence", lang_r()),
                tr("class_event", lang_r()),
                tr("class_location", lang_r()),
                tr("class_taxon", lang_r()),
                tr("class_identification", lang_r())
            )
        }

        category_choices <- function() {
            stats::setNames(all_filter_categories, category_labels())
        }

        category_label <- function(category_value) {
            idx <- match(category_value, all_filter_categories)
            if (is.na(idx)) {
                return(category_value)
            }

            category_labels()[[idx]]
        }

        custom_language_choices <- function() {
            stats::setNames(
                c("pt", "en", "es"),
                c(
                    sprintf("%s (pt)", tr("lang_pt", lang_r())),
                    sprintf("%s (en)", tr("lang_en", lang_r())),
                    sprintf("%s (es)", tr("lang_es", lang_r()))
                )
            )
        }

        # Load DwC terms as list (reactive to language)
        dwc_all <- shiny::reactive({
            get_dwc_terms_list(lang_r())
        })

        all_term_names <- shiny::reactive({
            vapply(dwc_all(), function(x) x$term, FUN.VALUE = character(1))
        })

        reason_key_from_code <- function(reason_code) {
            switch(as.character(reason_code),
                exact_match = "badge_reason_exact_match",
                known_synonym = "badge_reason_known_synonym",
                content_validated = "badge_reason_content_validated",
                manual_adjust = "badge_reason_manual_adjust",
                manual_cleared = "badge_reason_manual_cleared",
                type_incompatible = "badge_reason_type_incompatible",
                temporal_manual_only = "badge_reason_temporal_manual_only",
                conflict_lost = "badge_reason_conflict_lost",
                empty_column = "badge_reason_empty_column",
                low_name_confidence = "badge_reason_low_name_confidence",
                no_confident_match = "badge_reason_no_confident_match",
                "badge_reason_low_confidence"
            )
        }

        build_badge_info <- function(meta) {
            if (is.null(meta) || is.na(meta$status) || !nzchar(meta$status)) {
                return(NULL)
            }

            status <- toupper(as.character(meta$status)[1])
            badge_class <- switch(status,
                AUTO = "badge field-status-badge bg-success",
                SUGERIDO = "badge field-status-badge bg-warning",
                EDITADO = "badge field-status-badge bg-info",
                MANUAL = "badge field-status-badge bg-light text-muted border",
                "badge field-status-badge bg-light text-muted border"
            )

            badge_label <- switch(status,
                AUTO = tr("badge_auto", lang_r()),
                SUGERIDO = tr("badge_suggested", lang_r()),
                EDITADO = tr("badge_edited", lang_r()),
                MANUAL = tr("badge_manual", lang_r()),
                tr("badge_manual", lang_r())
            )

            reason_key <- reason_key_from_code(meta$reason)
            reason_text <- tr(reason_key, lang_r())
            score_value <- suppressWarnings(as.numeric(meta$score))

            tooltip <- reason_text
            if (!is.na(score_value)) {
                tooltip <- paste0(reason_text, " | score: ", sprintf("%.2f", score_value))
            }

            list(
                label = badge_label,
                class = badge_class,
                title = tooltip
            )
        }

        set_map_value <- function(term, value, update_input = TRUE) {
            sanitized_value <- sanitize_map_selection(term, value)
            rv$map_values[[term]] <- sanitized_value

            input_id <- paste0("map_", term)
            if (isTRUE(update_input) && !is.null(input[[input_id]])) {
                rv$programmatic_terms <- unique(c(rv$programmatic_terms, term))
                shiny::updateSelectInput(session, input_id, selected = sanitized_value)
            }
        }

        basis_of_record_page_size <- 20L

        get_basis_of_record_source_col <- function() {
            selected <- sanitize_map_selection("basisOfRecord", rv$map_values[["basisOfRecord"]])
            if (has_selected_value(selected)) {
                return(as.character(selected[[1]]))
            }

            input_selected <- sanitize_map_selection("basisOfRecord", input$map_basisOfRecord)
            if (has_selected_value(input_selected)) {
                return(as.character(input_selected[[1]]))
            }

            ""
        }

        basis_of_record_page_count <- function() {
            total_items <- nrow(rv$basis_of_record_entries)
            if (total_items <= 0) {
                return(1L)
            }

            max(1L, as.integer(ceiling(total_items / basis_of_record_page_size)))
        }

        get_basis_of_record_page_entries <- function() {
            entries <- rv$basis_of_record_entries
            if (nrow(entries) == 0) {
                return(entries)
            }

            total_pages <- basis_of_record_page_count()
            current_page <- max(1L, min(as.integer(rv$basis_of_record_page), total_pages))
            start_idx <- ((current_page - 1L) * basis_of_record_page_size) + 1L
            end_idx <- min(nrow(entries), start_idx + basis_of_record_page_size - 1L)
            entries[start_idx:end_idx, , drop = FALSE]
        }

        basis_of_record_target_choices <- function() {
            get_basis_of_record_term_choices(
                lang = lang_r(),
                include_skip = TRUE,
                with_description = TRUE,
                skip_label = tr("bor_assistant_skip_option", lang_r())
            )
        }

        get_effective_basis_of_record_map <- function() {
            entries <- rv$basis_of_record_entries
            if (nrow(entries) == 0) {
                return(stats::setNames(character(0), character(0)))
            }

            keys <- entries$key
            auto_map <- sanitize_basis_of_record_map(rv$basis_of_record_auto_map)
            draft_map <- sanitize_basis_of_record_map(rv$basis_of_record_draft_map)

            effective <- auto_map[keys]
            effective[is.na(effective)] <- ""

            draft_values <- draft_map[keys]
            has_draft <- !is.na(draft_values)
            effective[has_draft] <- draft_values[has_draft]

            effective <- sanitize_basis_of_record_terms(effective)
            stats::setNames(as.character(effective), keys)
        }

        sync_current_page_to_draft <- function() {
            entries <- get_basis_of_record_page_entries()
            if (nrow(entries) == 0) {
                return(invisible(NULL))
            }

            for (i in seq_len(nrow(entries))) {
                entry <- entries[i, , drop = FALSE]
                input_id <- paste0("basis_of_record_target_", entry$idx[[1]])
                input_value <- input[[input_id]]
                if (is.null(input_value)) {
                    next
                }

                sanitized_value <- sanitize_basis_of_record_term(input_value)
                key <- entry$key[[1]]
                has_key <- key %in% names(rv$basis_of_record_draft_map)
                current_value <- if (has_key) as.character(rv$basis_of_record_draft_map[[key]])[[1]] else NA_character_

                if (!has_key || !identical(current_value, sanitized_value)) {
                    rv$basis_of_record_draft_map[[entry$key[[1]]]] <- sanitized_value
                }
            }

            invisible(NULL)
        }

        loading_phrase_specs <- list(
            list(key = "loading_automap_phrase_1", icon = "language"),
            list(key = "loading_automap_phrase_2", icon = "microscope"),
            list(key = "loading_automap_phrase_3", icon = "seedling"),
            list(key = "loading_automap_phrase_4", icon = "dna"),
            list(key = "loading_automap_phrase_5", icon = "trophy"),
            list(key = "loading_automap_phrase_6", icon = "binoculars"),
            list(key = "loading_automap_phrase_7", icon = "flask"),
            list(key = "loading_automap_phrase_8", icon = "tree")
        )

        get_current_loading_phrase_spec <- function() {
            idx <- rv$automap_phrase_idx
            if (is.null(idx) || is.na(idx) || idx < 1 || idx > length(loading_phrase_specs)) {
                idx <- 1L
            }
            loading_phrase_specs[[idx]]
        }

        update_automap_loading <- function(step, total_steps) {
            total_steps <- max(1L, as.integer(total_steps))
            bounded_step <- max(0L, min(as.integer(step), total_steps))
            phrase_count <- length(loading_phrase_specs)
            phrase_order <- shiny::isolate(rv$automap_phrase_order)
            if (length(phrase_order) != phrase_count) {
                phrase_order <- seq_len(phrase_count)
            }

            rv$automap_progress <- as.integer(round((bounded_step / total_steps) * 100))
            phrase_pos <- ((bounded_step %% phrase_count) + 1L)
            rv$automap_phrase_idx <- as.integer(phrase_order[[phrase_pos]])
        }

        show_automap_loading_modal <- function() {
            phrase_count <- length(loading_phrase_specs)
            rv$automap_progress <- 0L
            rv$automap_phrase_order <- sample(seq_len(phrase_count))
            rv$automap_phrase_idx <- rv$automap_phrase_order[[1]]
            ordered_specs <- loading_phrase_specs[rv$automap_phrase_order]
            first_spec <- ordered_specs[[1]]
            status_template <- tr("loading_automap_status", lang_r())
            status_prefix <- trimws(gsub("%s%%", "", status_template, fixed = TRUE))
            if (!nzchar(status_prefix)) {
                status_prefix <- tr("loading", lang_r())
            }
            rotate_script <- sprintf(
                "(function () {
                    var iconEl = document.getElementById('%s');
                    var textEl = document.getElementById('%s');
                    var rowEl = document.getElementById('%s');
                    var poolRoot = document.getElementById('%s');
                    var progressEl = document.getElementById('%s');
                    var statusEl = document.getElementById('%s');
                    if (!iconEl || !textEl || !rowEl || !poolRoot) { return; }

                    var items = poolRoot.querySelectorAll('.automap-loading-phrase-item');
                    if (!items.length) { return; }

                    var timerKey = '%s';
                    var timeoutKey = timerKey + '_fade';
                    var progressKey = timerKey + '_progress';
                    var fadeMs = 280;
                    var stepMs = 2500;
                    var modalEl = poolRoot.closest('.modal');
                    var statusPrefix = %s;
                    var progressValue = %d;

                    var applyProgress = function (value) {
                        var pct = Math.max(0, Math.min(100, Math.round(value)));
                        if (progressEl) {
                            progressEl.style.width = pct + '%%';
                        }
                        if (statusEl) {
                            statusEl.textContent = statusPrefix ? (statusPrefix + ' ' + pct + '%%') : (pct + '%%');
                        }
                    };

                    if (modalEl) {
                        modalEl.classList.add('automap-loading-host');
                    }
                    if (document.body) {
                        document.body.classList.add('automap-loading-open');
                    }

                    if (window[timerKey]) {
                        window.clearInterval(window[timerKey]);
                        window[timerKey] = null;
                    }
                    if (window[timeoutKey]) {
                        window.clearTimeout(window[timeoutKey]);
                        window[timeoutKey] = null;
                    }
                    if (window[progressKey]) {
                        window.clearInterval(window[progressKey]);
                        window[progressKey] = null;
                    }

                    var applyPhrase = function (index) {
                        var item = items[index];
                        if (!item) { return; }
                        var nextIcon = item.getAttribute('data-icon') || 'gears';
                        iconEl.className = 'fa-solid fa-' + nextIcon + ' automap-loading-phrase-icon';
                        textEl.textContent = item.textContent || '';
                    };

                    var idx = 0;
                    applyPhrase(idx);
                    applyProgress(progressValue);

                    window[timerKey] = window.setInterval(function () {
                        rowEl.classList.add('is-fading');
                        window[timeoutKey] = window.setTimeout(function () {
                            idx = (idx + 1) %% items.length;
                            applyPhrase(idx);
                            rowEl.classList.remove('is-fading');
                            window[timeoutKey] = null;
                        }, fadeMs);
                    }, stepMs);

                    window[progressKey] = window.setInterval(function () {
                        if (progressValue < 92) {
                            progressValue += 1;
                            applyProgress(progressValue);
                        }
                    }, 240);

                    var clearTimer = function () {
                        if (window[timerKey]) {
                            window.clearInterval(window[timerKey]);
                            window[timerKey] = null;
                        }
                        if (window[timeoutKey]) {
                            window.clearTimeout(window[timeoutKey]);
                            window[timeoutKey] = null;
                        }
                        if (window[progressKey]) {
                            window.clearInterval(window[progressKey]);
                            window[progressKey] = null;
                        }
                        if (modalEl) {
                            modalEl.classList.remove('automap-loading-host');
                        }
                        if (document.body) {
                            document.body.classList.remove('automap-loading-open');
                        }
                    };

                    if (modalEl) {
                        modalEl.addEventListener('hidden.bs.modal', clearTimer, { once: true });
                    } else {
                        document.addEventListener('hidden.bs.modal', clearTimer, { once: true });
                    }
                })();",
                ns("automap_loading_phrase_icon"),
                ns("automap_loading_phrase_text"),
                ns("automap_loading_phrase_row"),
                ns("automap_loading_phrase_pool"),
                ns("automap_loading_progress_bar"),
                ns("automap_loading_status_text"),
                ns("automap_loading_phrase_timer"),
                jsonlite::toJSON(status_prefix, auto_unbox = TRUE),
                rv$automap_progress
            )
            shiny::showModal(shiny::modalDialog(
                shiny::div(
                    class = "automap-loading-modal",
                    shiny::div(
                        class = "automap-loading-brand-row",
                        shiny::img(
                            src = "www/images/finch_alone.svg",
                            class = "automap-loading-logo",
                            alt = "Finch"
                        )
                    ),
                    shiny::div(
                        class = "automap-loading-title",
                        tr("loading_automap_title", lang_r())
                    ),
                    shiny::div(
                        class = "automap-loading-progress",
                        shiny::div(
                            id = ns("automap_loading_progress_bar"),
                            class = "automap-loading-progress-bar",
                            style = paste0("width: ", rv$automap_progress, "%;")
                        )
                    ),
                    shiny::div(
                        class = "automap-loading-status",
                        shiny::span(
                            id = ns("automap_loading_status_text"),
                            sprintf(tr("loading_automap_status", lang_r()), rv$automap_progress)
                        )
                    ),
                    shiny::div(
                        class = "automap-loading-phrase",
                        shiny::div(
                            class = "automap-loading-phrase-row",
                            id = ns("automap_loading_phrase_row"),
                            shiny::icon(
                                first_spec$icon,
                                id = ns("automap_loading_phrase_icon"),
                                class = "fa-solid automap-loading-phrase-icon"
                            ),
                            shiny::span(
                                tr(first_spec$key, lang_r()),
                                id = ns("automap_loading_phrase_text")
                            )
                        ),
                        shiny::div(
                            id = ns("automap_loading_phrase_pool"),
                            style = "display: none;",
                            lapply(ordered_specs, function(spec) {
                                shiny::span(
                                    class = "automap-loading-phrase-item",
                                    `data-icon` = spec$icon,
                                    tr(spec$key, lang_r())
                                )
                            })
                        ),
                        shiny::tags$script(shiny::HTML(rotate_script))
                    )
                ),
                easyClose = FALSE,
                footer = NULL,
                fade = TRUE
            ))
        }

        hide_automap_loading_modal <- function() {
            shiny::removeModal()
        }

        # Translated labels
        output$label_mapped_fields <- shiny::renderUI({
            tr("stats_mapped_fields", lang_r())
        })

        output$label_total_fields <- shiny::renderUI({
            tr("stats_total_dwc_fields", lang_r())
        })

        output$btn_auto_map_label <- shiny::renderUI({
            tr("btn_auto_mapping", lang_r())
        })

        output$btn_reset_label <- shiny::renderUI({
            tr("btn_reset", lang_r())
        })

        output$filter_mapped_label <- shiny::renderUI({
            tr("filter_mapped_only", lang_r())
        })

        output$filter_categories_label <- shiny::renderUI({
            shiny::tags$label(tr("filter_categories", lang_r()), class = "form-label")
        })

        output$filter_select_all_label <- shiny::renderUI({
            tr("filter_select_all", lang_r())
        })

        output$toggle_automap_v1_label <- shiny::renderUI({
            tr("toggle_automap_v1_label", lang_r())
        })

        output$toggle_automap_v1_help <- shiny::renderUI({
            tr("toggle_automap_v1_help", lang_r())
        })

        output$card_title <- shiny::renderUI({
            tr("mapping_title", lang_r())
        })

        output$no_file_msg <- shiny::renderUI({
            tr("no_file_uploaded", lang_r())
        })

        output$upload_first_msg <- shiny::renderUI({
            tr("upload_csv_to_start", lang_r())
        })

        # File uploaded output for conditional panel
        output$file_uploaded <- shiny::reactive({
            !is.null(raw_data_r())
        })
        shiny::outputOptions(output, "file_uploaded", suspendWhenHidden = FALSE)

        output$basis_of_record_assistant_progress <- shiny::renderUI({
            entries <- rv$basis_of_record_entries
            total <- nrow(entries)
            if (total == 0) {
                return(NULL)
            }

            effective_map <- get_effective_basis_of_record_map()
            mapped_values <- effective_map[entries$key]
            mapped_values[is.na(mapped_values)] <- ""
            mapped_count <- sum(nzchar(mapped_values))
            progress_pct <- as.integer(round((mapped_count / total) * 100))

            shiny::div(
                class = "bor-assistant-progress-wrap",
                shiny::div(
                    class = "bor-assistant-progress-text",
                    sprintf(tr("bor_assistant_progress", lang_r()), mapped_count, total)
                ),
                shiny::div(
                    class = "bor-assistant-progress",
                    shiny::div(
                        class = "bor-assistant-progress-bar",
                        style = paste0("width: ", progress_pct, "%;")
                    )
                )
            )
        })

        output$basis_of_record_assistant_pagination <- shiny::renderUI({
            entries <- rv$basis_of_record_entries
            total <- nrow(entries)
            if (total <= basis_of_record_page_size) {
                return(NULL)
            }

            shiny::div(
                class = "bor-assistant-pagination",
                shiny::actionButton(
                    ns("basis_of_record_page_prev"),
                    label = tr("bor_assistant_prev", lang_r()),
                    class = "btn btn-secondary btn-sm"
                ),
                shiny::actionButton(
                    ns("basis_of_record_page_next"),
                    label = tr("bor_assistant_next", lang_r()),
                    class = "btn btn-secondary btn-sm"
                )
            )
        })

        output$basis_of_record_assistant_rows <- shiny::renderUI({
            entries <- get_basis_of_record_page_entries()
            if (nrow(entries) == 0) {
                return(shiny::div(
                    class = "alert alert-info",
                    tr("bor_assistant_no_values", lang_r())
                ))
            }

            choices <- basis_of_record_target_choices()
            effective_map <- get_effective_basis_of_record_map()

            shiny::tags$table(
                class = "table table-sm bor-assistant-table",
                shiny::tags$thead(
                    shiny::tags$tr(
                        shiny::tags$th(tr("bor_assistant_col_raw", lang_r())),
                        shiny::tags$th(tr("bor_assistant_col_target", lang_r()))
                    )
                ),
                shiny::tags$tbody(
                    lapply(seq_len(nrow(entries)), function(i) {
                        entry <- entries[i, , drop = FALSE]
                        current_target <- effective_map[[entry$key[[1]]]]
                        if (is.null(current_target)) {
                            current_target <- ""
                        }

                        shiny::tags$tr(
                            shiny::tags$td(
                                shiny::div(
                                    class = "bor-assistant-raw-value",
                                    entry$raw[[1]]
                                )
                            ),
                            shiny::tags$td(
                                shiny::selectInput(
                                    ns(paste0("basis_of_record_target_", entry$idx[[1]])),
                                    label = NULL,
                                    choices = choices,
                                    selected = current_target,
                                    multiple = FALSE,
                                    selectize = FALSE,
                                    width = "100%"
                                )
                            )
                        )
                    })
                )
            )
        })

        output$basis_of_record_assistant_preview <- shiny::renderUI({
            shiny::req(raw_data_r())
            source_col <- get_basis_of_record_source_col()
            if (!nzchar(source_col) || !(source_col %in% names(raw_data_r()))) {
                return(NULL)
            }

            all_raw <- as.character(raw_data_r()[[source_col]])
            all_raw[is.na(raw_data_r()[[source_col]])] <- ""
            effective_map <- get_effective_basis_of_record_map()

            preview_n <- min(5L, length(all_raw))
            if (preview_n == 0) {
                return(NULL)
            }

            preview_raw <- trimws(all_raw[seq_len(preview_n)])
            preview_mapped <- map_basis_of_record_values(
                all_raw[seq_len(preview_n)],
                effective_map
            )
            preview_mapped_display <- ifelse(
                nzchar(preview_mapped),
                preview_mapped,
                tr("bor_assistant_empty_value", lang_r())
            )

            keys <- normalize_basis_of_record_keys(all_raw)
            clean_map <- sanitize_basis_of_record_map(effective_map)
            mapped_all <- unname(clean_map[keys])
            mapped_all[is.na(mapped_all)] <- ""
            non_blank_raw <- nzchar(trimws(all_raw))
            unmapped_row_count <- sum(non_blank_raw & !nzchar(mapped_all))

            shiny::tagList(
                shiny::div(
                    class = "bor-assistant-preview-title",
                    tr("bor_assistant_preview_title", lang_r())
                ),
                shiny::tags$table(
                    class = "table table-sm bor-assistant-preview-table",
                    shiny::tags$thead(
                        shiny::tags$tr(
                            shiny::tags$th(tr("bor_assistant_preview_original", lang_r())),
                            shiny::tags$th(tr("bor_assistant_preview_result", lang_r()))
                        )
                    ),
                    shiny::tags$tbody(
                        lapply(seq_len(preview_n), function(i) {
                            shiny::tags$tr(
                                shiny::tags$td(preview_raw[[i]]),
                                shiny::tags$td(preview_mapped_display[[i]])
                            )
                        })
                    )
                ),
                shiny::div(
                    class = "bor-assistant-unmapped-count",
                    sprintf(tr("bor_assistant_unmapped_rows", lang_r()), unmapped_row_count)
                )
            )
        })

        shiny::observeEvent(input$basis_of_record_page_prev,
            {
                sync_current_page_to_draft()
                current_page <- as.integer(rv$basis_of_record_page)
                rv$basis_of_record_page <- max(1L, current_page - 1L)
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$basis_of_record_page_next,
            {
                sync_current_page_to_draft()
                current_page <- as.integer(rv$basis_of_record_page)
                rv$basis_of_record_page <- min(basis_of_record_page_count(), current_page + 1L)
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$open_basis_of_record_assistant, {
            shiny::req(raw_data_r())

            tryCatch(
                {
                    source_col <- get_basis_of_record_source_col()
                    if (!nzchar(source_col) || !(source_col %in% names(raw_data_r()))) {
                        shiny::showNotification(
                            tr("bor_assistant_select_column_first", lang_r()),
                            type = "warning",
                            duration = 4
                        )
                        return(invisible(NULL))
                    }

                    entries <- extract_basis_of_record_unique_entries(raw_data_r()[[source_col]])
                    existing_map <- sanitize_basis_of_record_map(rv$basis_of_record_map)
                    next_map <- existing_map
                    next_auto <- stats::setNames(character(0), character(0))

                    if (nrow(entries) > 0) {
                        allowed_terms <- get_basis_of_record_terms()
                        match_idx <- match(
                            tolower(trimws(entries$raw)),
                            tolower(allowed_terms)
                        )
                        suggested <- rep("", nrow(entries))
                        matched <- !is.na(match_idx)
                        suggested[matched] <- allowed_terms[match_idx[matched]]
                        next_auto <- stats::setNames(suggested, entries$key)
                    }

                    rv$basis_of_record_entries <- entries
                    rv$basis_of_record_auto_map <- next_auto
                    rv$basis_of_record_draft_map <- next_map
                    rv$basis_of_record_page <- 1L
                    rv$basis_of_record_source_col <- source_col

                    shiny::showModal(shiny::modalDialog(
                        title = tr("bor_assistant_title", lang_r()),
                        size = "l",
                        easyClose = TRUE,
                        shiny::div(
                            class = "bor-assistant-modal",
                            shiny::p(
                                class = "bor-assistant-subtitle",
                                tr("bor_assistant_subtitle", lang_r())
                            ),
                            shiny::uiOutput(ns("basis_of_record_assistant_progress")),
                            shiny::uiOutput(ns("basis_of_record_assistant_pagination")),
                            shiny::div(
                                class = "bor-assistant-table-wrap",
                                shiny::uiOutput(ns("basis_of_record_assistant_rows"))
                            ),
                            shiny::hr(),
                            shiny::uiOutput(ns("basis_of_record_assistant_preview"))
                        ),
                        footer = shiny::tagList(
                            shiny::modalButton(tr("btn_cancel", lang_r())),
                            shiny::actionButton(
                                ns("save_basis_of_record_assistant"),
                                tr("bor_assistant_save", lang_r()),
                                class = "btn-primary"
                            )
                        )
                    ))
                },
                error = function(e) {
                    shiny::showNotification(
                        sprintf(tr("bor_assistant_open_error", lang_r()), e$message),
                        type = "error",
                        duration = 7
                    )
                }
            )
        })

        shiny::observeEvent(input$save_basis_of_record_assistant, {
            sync_current_page_to_draft()
            entries <- rv$basis_of_record_entries
            effective_map <- get_effective_basis_of_record_map()
            final_map <- stats::setNames(character(0), character(0))

            if (nrow(entries) > 0) {
                final_map <- effective_map[entries$key]
                final_map[is.na(final_map)] <- ""
                final_map <- stats::setNames(as.character(final_map), entries$key)
            }

            rv$basis_of_record_map <- final_map
            rv$basis_of_record_source_col <- get_basis_of_record_source_col()

            shiny::removeModal()
            shiny::showNotification(
                sprintf(
                    tr("bor_assistant_saved", lang_r()),
                    sum(vapply(final_map, function(x) nzchar(x), FUN.VALUE = logical(1))),
                    length(final_map)
                ),
                type = "message",
                duration = 4
            )
        })

        shiny::observe({
            term_names <- all_term_names()
            if (length(term_names) == 0) {
                return()
            }

            if (length(rv$map_values) == 0) {
                rv$map_values <- empty_map_values(term_names)
            } else {
                missing_terms <- setdiff(term_names, names(rv$map_values))
                for (term in missing_terms) {
                    rv$map_values[[term]] <- ""
                }
            }

            if (length(rv$map_meta) == 0) {
                rv$map_meta <- empty_map_meta(term_names)
            } else {
                missing_meta <- setdiff(term_names, names(rv$map_meta))
                for (term in missing_meta) {
                    rv$map_meta[[term]] <- default_meta()
                }
            }
        })

        shiny::observeEvent(raw_data_r(),
            {
                shiny::req(raw_data_r())
                term_names <- all_term_names()

                rv$map_values <- empty_map_values(term_names)
                rv$map_meta <- empty_map_meta(term_names)
                rv$occurrence_ids <- ids::uuid(n = nrow(raw_data_r()))
                rv$eventdate_parse_failures <- 0L
                rv$last_eventdate_warn_count <- NA_integer_
                rv$programmatic_terms <- character(0)
                rv$basis_of_record_map <- stats::setNames(character(0), character(0))
                rv$basis_of_record_auto_map <- stats::setNames(character(0), character(0))
                rv$basis_of_record_source_col <- ""
                rv$basis_of_record_draft_map <- stats::setNames(character(0), character(0))
                rv$basis_of_record_entries <- data.frame(
                    idx = integer(0),
                    key = character(0),
                    raw = character(0),
                    stringsAsFactors = FALSE
                )
                rv$basis_of_record_page <- 1L
            },
            ignoreNULL = TRUE
        )

        shiny::observeEvent(input$enable_automap_v1,
            {
                if (!isTRUE(input$enable_automap_v1)) {
                    rv$map_meta <- empty_map_meta(all_term_names())
                }
            },
            ignoreInit = TRUE
        )

        shiny::observe({
            shiny::req(raw_data_r())
            term_names <- all_term_names()

            for (term in term_names) {
                input_id <- paste0("map_", term)
                input_value <- input[[input_id]]
                if (is.null(input_value)) {
                    next
                }

                sanitized <- sanitize_map_selection(term, input_value)

                if (term %in% c("scientificName", "basisOfRecord") && length(input_value) > 1) {
                    rv$is_programmatic_update <- TRUE
                    shiny::updateSelectInput(session, input_id, selected = sanitized)
                    rv$is_programmatic_update <- FALSE
                }

                old_value <- shiny::isolate(rv$map_values[[term]])
                if (is.null(old_value)) {
                    old_value <- ""
                }

                if (!identical(old_value, sanitized)) {
                    rv$map_values[[term]] <- sanitized

                    if (identical(term, "basisOfRecord")) {
                        next_source_col <- if (has_selected_value(sanitized)) {
                            as.character(sanitized[[1]])
                        } else {
                            ""
                        }
                        previous_source_col <- shiny::isolate(rv$basis_of_record_source_col)

                        if (!identical(previous_source_col, next_source_col)) {
                            rv$basis_of_record_source_col <- next_source_col
                            rv$basis_of_record_map <- stats::setNames(character(0), character(0))
                            rv$basis_of_record_auto_map <- stats::setNames(character(0), character(0))
                            rv$basis_of_record_draft_map <- stats::setNames(character(0), character(0))
                            rv$basis_of_record_entries <- data.frame(
                                idx = integer(0),
                                key = character(0),
                                raw = character(0),
                                stringsAsFactors = FALSE
                            )
                            rv$basis_of_record_page <- 1L
                        }
                    }

                    is_programmatic_term <- term %in% shiny::isolate(rv$programmatic_terms)
                    if (is_programmatic_term) {
                        rv$programmatic_terms <- setdiff(shiny::isolate(rv$programmatic_terms), term)
                    }

                    if (isTRUE(input$enable_automap_v1) &&
                        !isTRUE(rv$is_programmatic_update) &&
                        !is_programmatic_term) {
                        previous_meta <- shiny::isolate(rv$map_meta[[term]])
                        rv$map_meta[[term]] <- build_manual_meta(
                            previous_meta = previous_meta,
                            has_value = has_selected_value(sanitized)
                        )
                    }
                }
            }
        })

        set_custom_term_meta <- function(term, has_value) {
            if (!isTRUE(input$enable_automap_v1) || isTRUE(rv$is_programmatic_update)) {
                return(invisible(NULL))
            }

            previous_meta <- shiny::isolate(rv$map_meta[[term]])
            rv$map_meta[[term]] <- build_manual_meta(
                previous_meta = previous_meta,
                has_value = has_value
            )

            invisible(NULL)
        }

        shiny::observeEvent(input$custom_datasetName,
            {
                has_value <- !is.null(input$custom_datasetName) && nchar(trimws(input$custom_datasetName)) > 0
                set_custom_term_meta("datasetName", has_value)
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$modified_use_today,
            {
                has_value <- isTRUE(input$modified_use_today) || !is.null(input$custom_modified_date)
                set_custom_term_meta("modified", has_value)
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$custom_modified_date,
            {
                has_value <- isTRUE(input$modified_use_today) || !is.null(input$custom_modified_date)
                set_custom_term_meta("modified", has_value)
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(rv$eventdate_parse_failures,
            {
                current_count <- rv$eventdate_parse_failures

                if (is.null(current_count) || current_count <= 0) {
                    rv$last_eventdate_warn_count <- NA_integer_
                    return()
                }

                if (!identical(rv$last_eventdate_warn_count, current_count)) {
                    shiny::showNotification(
                        sprintf(tr("notif_eventdate_parse_warning", lang_r()), current_count),
                        type = "warning",
                        duration = 7
                    )
                    rv$last_eventdate_warn_count <- current_count
                }
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(lang_r(),
            {
                current <- shiny::isolate(input$filter_categories)
                if (is.null(current)) {
                    current <- all_filter_categories
                }

                shiny::updateCheckboxGroupInput(
                    session,
                    "filter_categories",
                    choices = category_choices(),
                    selected = current
                )
            },
            ignoreInit = FALSE
        )

        # Category filter: select all / unselect all
        shiny::observeEvent(input$select_all_categories,
            {
                if (isTRUE(syncing_select_all())) {
                    syncing_select_all(FALSE)
                    return()
                }

                target <- if (isTRUE(input$select_all_categories)) all_filter_categories else character(0)
                current <- input$filter_categories
                if (is.null(current)) {
                    current <- character(0)
                }

                same_selection <- length(current) == length(target) && all(sort(current) == sort(target))
                if (!same_selection) {
                    shiny::updateCheckboxGroupInput(session, "filter_categories", selected = target)
                }
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$filter_categories,
            {
                current <- input$filter_categories
                if (is.null(current)) {
                    current <- character(0)
                }

                is_all_selected <- length(current) == length(all_filter_categories) && all(all_filter_categories %in% current)

                if (!identical(isTRUE(input$select_all_categories), is_all_selected)) {
                    syncing_select_all(TRUE)
                    shiny::updateCheckboxInput(session, "select_all_categories", value = is_all_selected)
                }
            },
            ignoreInit = TRUE
        )

        # Mapping UI generation
        output$mapping_ui <- shiny::renderUI({
            shiny::req(raw_data_r())

            cols <- c("-- " = "", names(raw_data_r()))
            fields_to_show <- dwc_all()

            # Apply category filter
            selected_categories <- input$filter_categories
            if (is.null(selected_categories)) {
                selected_categories <- character(0)
            }

            if (length(selected_categories) == 0) {
                fields_to_show <- list()
            } else {
                fields_to_show <- Filter(function(x) x$category %in% selected_categories, fields_to_show)
            }

            # Extract unique categories - use vapply for reliable scalar extraction
            all_categories <- vapply(fields_to_show, function(x) x$category, FUN.VALUE = character(1))
            categories <- unique(all_categories)

            shiny::tagList(
                lapply(categories, function(cat) {
                    cat_fields <- Filter(function(x) x$category == cat, fields_to_show)
                    cat_class <- paste0("cat-", tolower(gsub("-", "", cat)))

                    shiny::tagList(
                        shiny::div(class = "category-header", category_label(cat)),
                        shiny::div(
                            class = "two-column-layout",
                            lapply(cat_fields, function(item) {
                                term <- item$term
                                current_val <- rv$map_values[[term]]
                                if (is.null(current_val)) {
                                    current_val <- input[[paste0("map_", term)]]
                                }
                                current_val <- sanitize_map_selection(term, current_val)
                                is_mapped <- has_selected_value(current_val)
                                field_meta <- rv$map_meta[[term]]
                                if (is.null(field_meta)) {
                                    field_meta <- default_meta()
                                }
                                badge_info <- if (isTRUE(input$enable_automap_v1)) build_badge_info(field_meta) else NULL

                                # Check custom field inputs for mapped status
                                if (term == "datasetName") {
                                    custom_val <- input$custom_datasetName
                                    if (!is.null(custom_val) && nchar(trimws(custom_val)) > 0) {
                                        is_mapped <- TRUE
                                    }
                                } else if (term == "occurrenceID") {
                                    is_mapped <- TRUE
                                } else if (term == "modified") {
                                    is_mapped <- isTRUE(input$modified_use_today) || !is.null(input$custom_modified_date)
                                } else if (term == "license") {
                                    is_mapped <- !is.null(input$custom_license) && length(input$custom_license) > 0
                                } else if (term == "language") {
                                    is_mapped <- !is.null(input$custom_language) && length(input$custom_language) > 0
                                }

                                # Apply "show only mapped" filter
                                if (isTRUE(input$show_only_mapped) && !is_mapped) {
                                    return(NULL)
                                }

                                shiny::div(
                                    class = paste("field-card no-break", cat_class, if (is_mapped) "field-mapped" else "field-unmapped"),
                                    shiny::div(
                                        class = "field-header-row",
                                        shiny::div(class = "field-header", term),
                                        if (!is.null(badge_info) && term != "occurrenceID") {
                                            shiny::span(
                                                class = badge_info$class,
                                                title = badge_info$title,
                                                badge_info$label
                                            )
                                        }
                                    ),
                                    shiny::div(class = "field-desc", item$desc),
                                    if (term == "occurrenceID") {
                                        shiny::div(
                                            class = "alert alert-info",
                                            style = "margin-top: 8px; padding: 8px; font-size: 0.85em;",
                                            shiny::icon("info-circle"),
                                            " ", tr("uuid_auto_generated", lang_r())
                                        )
                                    } else if (term == "datasetName") {
                                        # datasetName: dropdown + separate text input
                                        saved_custom <- shiny::isolate(input$custom_datasetName)
                                        shiny::tagList(
                                            shiny::selectInput(
                                                ns(paste0("map_", term)),
                                                NULL,
                                                choices = cols,
                                                selected = if (has_selected_value(current_val)) current_val else "",
                                                multiple = FALSE,
                                                selectize = TRUE,
                                                width = "100%"
                                            ),
                                            shiny::tags$label(
                                                class = "custom-field-label",
                                                tr("field_or_type_value", lang_r())
                                            ),
                                            shiny::textInput(
                                                ns("custom_datasetName"),
                                                NULL,
                                                value = if (!is.null(saved_custom)) saved_custom else "",
                                                placeholder = tr("mapping_dataset_placeholder", lang_r()),
                                                width = "100%"
                                            )
                                        )
                                    } else if (term == "modified") {
                                        # modified: checkbox "today" + date picker (ISO 8601)
                                        saved_check <- shiny::isolate(input$modified_use_today)
                                        saved_date <- shiny::isolate(input$custom_modified_date)
                                        shiny::tagList(
                                            shiny::checkboxInput(
                                                ns("modified_use_today"),
                                                tr("field_use_today_date", lang_r()),
                                                value = if (!is.null(saved_check)) saved_check else FALSE
                                            ),
                                            shiny::tags$label(
                                                class = "custom-field-label",
                                                tr("field_choose_date", lang_r())
                                            ),
                                            shiny::dateInput(
                                                ns("custom_modified_date"),
                                                NULL,
                                                value = if (!is.null(saved_date)) saved_date else Sys.Date(),
                                                format = "yyyy-mm-dd",
                                                width = "100%"
                                            )
                                        )
                                    } else if (term == "license") {
                                        # license: square checkboxes (single-select)
                                        saved_license <- shiny::isolate(input$custom_license)
                                        shiny::tagList(
                                            shiny::tags$label(
                                                class = "custom-field-label",
                                                tr("field_choose_license", lang_r())
                                            ),
                                            shiny::checkboxGroupInput(
                                                ns("custom_license"),
                                                NULL,
                                                choices = c(
                                                    "CC0 (Public Domain)" = "https://creativecommons.org/publicdomain/zero/1.0/legalcode",
                                                    "CC-BY 4.0" = "https://creativecommons.org/licenses/by/4.0/legalcode",
                                                    "CC-BY-NC 4.0" = "https://creativecommons.org/licenses/by-nc/4.0/legalcode"
                                                ),
                                                selected = if (!is.null(saved_license)) saved_license else character(0),
                                                inline = FALSE,
                                                width = "100%"
                                            )
                                        )
                                    } else if (term == "language") {
                                        # language: square checkboxes (single-select)
                                        saved_lang <- shiny::isolate(input$custom_language)
                                        shiny::tagList(
                                            shiny::tags$label(
                                                class = "custom-field-label",
                                                tr("field_choose_language", lang_r())
                                            ),
                                            shiny::checkboxGroupInput(
                                                ns("custom_language"),
                                                NULL,
                                                choices = custom_language_choices(),
                                                selected = if (!is.null(saved_lang)) saved_lang else character(0),
                                                inline = TRUE,
                                                width = "100%"
                                            )
                                        )
                                    } else if (term == "basisOfRecord") {
                                        basis_selected <- if (has_selected_value(current_val)) {
                                            as.character(current_val[[1]])
                                        } else {
                                            ""
                                        }

                                        shiny::tagList(
                                            shiny::selectInput(
                                                ns(paste0("map_", term)),
                                                NULL,
                                                choices = cols,
                                                selected = basis_selected,
                                                multiple = FALSE,
                                                selectize = TRUE,
                                                width = "100%"
                                            ),
                                            if (has_selected_value(basis_selected)) {
                                                shiny::actionButton(
                                                    ns("open_basis_of_record_assistant"),
                                                    tr("bor_assistant_button", lang_r()),
                                                    class = "btn btn-outline-primary btn-sm w-100 mt-2",
                                                    icon = shiny::icon("list-check")
                                                )
                                            }
                                        )
                                    } else {
                                        bslib::layout_columns(
                                            col_widths = if (item$sep != "") c(8, 4) else c(12),
                                            shiny::selectInput(
                                                ns(paste0("map_", term)),
                                                NULL,
                                                choices = cols,
                                                selected = if (has_selected_value(current_val)) {
                                                    if (term %in% c("scientificName", "basisOfRecord")) {
                                                        if (length(current_val) > 0) current_val[[1]] else ""
                                                    } else {
                                                        current_val
                                                    }
                                                } else {
                                                    ""
                                                },
                                                multiple = !(term %in% c("scientificName", "basisOfRecord")),
                                                selectize = TRUE,
                                                width = "100%"
                                            ),
                                            if (item$sep != "") {
                                                shiny::textInput(
                                                    ns(paste0("sep_", term)),
                                                    NULL,
                                                    value = item$sep,
                                                    placeholder = tr("mapping_separator_placeholder", lang_r()),
                                                    width = "100%"
                                                )
                                            }
                                        )
                                    }
                                )
                            })
                        )
                    )
                })
            )
        })

        # Auto-mapping
        shiny::observeEvent(input$auto_map, {
            shiny::req(raw_data_r())
            term_names <- all_term_names()
            terms <- dwc_all()
            special_fields <- c("occurrenceID", "modified", "license", "language")
            show_automap_loading_modal()
            on.exit(hide_automap_loading_modal(), add = TRUE)

            if (!isTRUE(input$enable_automap_v1)) {
                mapped_count <- 0L
                rv$is_programmatic_update <- TRUE
                on.exit(
                    {
                        rv$is_programmatic_update <- FALSE
                        rv$programmatic_terms <- character(0)
                    },
                    add = TRUE
                )

                total_terms <- max(1L, length(terms))
                for (i in seq_along(terms)) {
                    item <- terms[[i]]
                    term <- item$term

                    if (!(term %in% special_fields)) {
                        matching_col <- names(raw_data_r())[which(tolower(names(raw_data_r())) == tolower(term))[1]]
                        if (!is.na(matching_col) && nzchar(matching_col)) {
                            set_map_value(term, matching_col, update_input = TRUE)
                            mapped_count <- mapped_count + 1L
                        }
                    }

                    update_automap_loading(i, total_terms)
                }

                rv$map_meta <- empty_map_meta(term_names)

                shiny::showNotification(
                    paste(tr("notif_auto_mapping", lang_r()), "-", mapped_count, tr("stats_mapped_fields", lang_r())),
                    type = "message",
                    duration = 5
                )
                return(invisible(NULL))
            }

            auto_count <- 0L
            suggested_count <- 0L

            tryCatch(
                {
                    dwc_terms_df <- load_dwc_terms_rds()
                    synonyms_tbl <- load_dwc_synonyms_v1()
                    auto_results <- run_automap_v1(
                        df = raw_data_r(),
                        dwc_terms_df = dwc_terms_df,
                        synonyms_tbl = synonyms_tbl
                    )

                    rv$is_programmatic_update <- TRUE
                    on.exit(
                        {
                            rv$is_programmatic_update <- FALSE
                            rv$programmatic_terms <- character(0)
                        },
                        add = TRUE
                    )
                    next_meta <- empty_map_meta(term_names)
                    total_rows <- max(1L, nrow(auto_results))

                    for (i in seq_len(nrow(auto_results))) {
                        term <- as.character(auto_results$term[[i]])
                        status <- as.character(auto_results$status[[i]])
                        reason <- as.character(auto_results$reason[[i]])
                        score_value <- suppressWarnings(as.numeric(auto_results$final_score[[i]]))
                        selected_col <- as.character(auto_results$selected_col[[i]])
                        is_applied <- isTRUE(auto_results$applied[[i]])

                        next_meta[[term]] <- list(
                            status = status,
                            score = score_value,
                            reason = reason,
                            source = "auto"
                        )

                        if (!(term %in% special_fields) && is_applied && !is.na(selected_col) && nzchar(selected_col)) {
                            set_map_value(term, selected_col, update_input = TRUE)
                            if (identical(status, "AUTO")) {
                                auto_count <- auto_count + 1L
                            } else if (identical(status, "SUGERIDO")) {
                                suggested_count <- suggested_count + 1L
                            }
                        }

                        update_automap_loading(i, total_rows)
                    }

                    if (nrow(auto_results) == 0) {
                        update_automap_loading(1L, 1L)
                    }

                    rv$map_meta <- next_meta

                    shiny::showNotification(
                        sprintf(tr("notif_auto_mapping_v1", lang_r()), auto_count, suggested_count),
                        type = "message",
                        duration = 6
                    )
                },
                error = function(e) {
                    rv$is_programmatic_update <- FALSE
                    rv$programmatic_terms <- character(0)
                    shiny::showNotification(
                        sprintf(tr("notif_auto_mapping_v1_error", lang_r()), e$message),
                        type = "error",
                        duration = 7
                    )
                }
            )
        })

        # Reset mapping
        shiny::observeEvent(input$reset_mapping, {
            shiny::showModal(shiny::modalDialog(
                title = tr("modal_reset_title", lang_r()),
                tr("modal_reset_message", lang_r()),
                footer = shiny::tagList(
                    shiny::modalButton(tr("btn_cancel", lang_r())),
                    shiny::actionButton(ns("confirm_reset"), tr("btn_confirm_reset", lang_r()), class = "btn-danger")
                )
            ))
        })

        shiny::observeEvent(input$confirm_reset, {
            special_no_dropdown <- c("occurrenceID", "modified", "license", "language")
            rv$is_programmatic_update <- TRUE
            for (item in dwc_all()) {
                if (!(item$term %in% special_no_dropdown)) {
                    set_map_value(item$term, "", update_input = TRUE)
                }
            }
            for (term in intersect(all_term_names(), special_no_dropdown)) {
                rv$map_values[[term]] <- ""
            }
            rv$map_meta <- empty_map_meta(all_term_names())
            # Reset custom inputs
            shiny::updateTextInput(session, "custom_datasetName", value = "")
            shiny::updateCheckboxInput(session, "modified_use_today", value = FALSE)
            shiny::updateDateInput(session, "custom_modified_date", value = Sys.Date())
            shiny::updateCheckboxGroupInput(session, "custom_license", selected = character(0))
            shiny::updateCheckboxGroupInput(session, "custom_language", selected = character(0))
            rv$basis_of_record_map <- stats::setNames(character(0), character(0))
            rv$basis_of_record_auto_map <- stats::setNames(character(0), character(0))
            rv$basis_of_record_source_col <- ""
            rv$basis_of_record_draft_map <- stats::setNames(character(0), character(0))
            rv$basis_of_record_entries <- data.frame(
                idx = integer(0),
                key = character(0),
                raw = character(0),
                stringsAsFactors = FALSE
            )
            rv$basis_of_record_page <- 1L
            rv$is_programmatic_update <- FALSE
            rv$programmatic_terms <- character(0)
            shiny::removeModal()
            shiny::showNotification(tr("notif_mapping_reset", lang_r()), type = "warning", duration = 3)
        })

        # Enforce single-selection for license checkboxGroupInput
        shiny::observeEvent(input$custom_license,
            {
                if (length(input$custom_license) > 1) {
                    # Keep only the most recently selected item (last in the vector)
                    shiny::updateCheckboxGroupInput(
                        session, "custom_license",
                        selected = utils::tail(input$custom_license, 1)
                    )
                }

                has_value <- !is.null(input$custom_license) && length(input$custom_license) > 0
                set_custom_term_meta("license", has_value)
            },
            ignoreInit = TRUE
        )

        # Enforce single-selection for language checkboxGroupInput
        shiny::observeEvent(input$custom_language,
            {
                if (length(input$custom_language) > 1) {
                    shiny::updateCheckboxGroupInput(
                        session, "custom_language",
                        selected = utils::tail(input$custom_language, 1)
                    )
                }

                has_value <- !is.null(input$custom_language) && length(input$custom_language) > 0
                set_custom_term_meta("language", has_value)
            },
            ignoreInit = TRUE
        )

        # Statistics
        output$mapped_count <- shiny::renderText({
            shiny::req(raw_data_r())

            mapped <- 1 # occurrenceID always counted
            for (item in dwc_all()) {
                term <- item$term
                if (term == "occurrenceID") next
                # Check custom fields
                if (term == "datasetName") {
                    custom_val <- input$custom_datasetName
                    user_cols <- sanitize_map_selection(term, rv$map_values[[term]])
                    if ((!is.null(custom_val) && nchar(trimws(custom_val)) > 0) ||
                        has_selected_value(user_cols)) {
                        mapped <- mapped + 1
                    }
                } else if (term == "modified") {
                    if (isTRUE(input$modified_use_today) || !is.null(input$custom_modified_date)) {
                        mapped <- mapped + 1
                    }
                } else if (term == "license") {
                    if (!is.null(input$custom_license) && length(input$custom_license) > 0) {
                        mapped <- mapped + 1
                    }
                } else if (term == "language") {
                    if (!is.null(input$custom_language) && length(input$custom_language) > 0) {
                        mapped <- mapped + 1
                    }
                } else {
                    user_cols <- sanitize_map_selection(term, rv$map_values[[term]])
                    if (has_selected_value(user_cols)) {
                        mapped <- mapped + 1
                    }
                }
            }
            mapped
        })

        output$total_fields <- shiny::renderText({
            length(dwc_all())
        })

        build_mapped_result <- function(df_input, occurrence_ids_input) {
            build_processed_mapping_df(
                df = df_input,
                dwc_terms = dwc_all(),
                map_values = rv$map_values,
                occurrence_ids = occurrence_ids_input,
                custom_dataset_name = input$custom_datasetName,
                modified_use_today = isTRUE(input$modified_use_today),
                custom_modified_date = input$custom_modified_date,
                custom_license = input$custom_license,
                custom_language = input$custom_language,
                basis_of_record_map = rv$basis_of_record_map,
                now_utc = Sys.time(),
                out_sep = " | "
            )
        }

        # Full mapped data (used by export and validation modules)
        processed_data <- shiny::reactive({
            shiny::req(raw_data_r())

            df <- raw_data_r()
            if (is.null(rv$occurrence_ids) || length(rv$occurrence_ids) != nrow(df)) {
                rv$occurrence_ids <- ids::uuid(n = nrow(df))
            }

            processed_result <- build_mapped_result(
                df_input = df,
                occurrence_ids_input = rv$occurrence_ids
            )

            if (!identical(rv$eventdate_parse_failures, processed_result$eventdate_failure_count)) {
                rv$eventdate_parse_failures <- processed_result$eventdate_failure_count
            }

            processed_result$data
        })

        # Lightweight gate for validation modules: avoid materializing processed_data
        # just to know if scientificName mapping is ready.
        validation_gate_r <- shiny::reactive({
            raw_df <- raw_data_r()
            if (is.null(raw_df) || !is.data.frame(raw_df) || nrow(raw_df) == 0L) {
                return(list(status = "no_data", has_data = FALSE, scientific_col = ""))
            }

            selected <- sanitize_map_selection("scientificName", rv$map_values[["scientificName"]])
            if (!has_selected_value(selected)) {
                selected <- sanitize_map_selection("scientificName", input$map_scientificName)
            }

            scientific_col <- if (has_selected_value(selected)) as.character(selected[[1]]) else ""
            has_scientific <- nzchar(scientific_col) && scientific_col %in% names(raw_df)

            list(
                status = if (has_scientific) "ok" else "missing_scientific",
                has_data = TRUE,
                scientific_col = scientific_col
            )
        })

        # Lightweight gate for coordinate validation without materializing processed_data
        coord_validation_gate_r <- shiny::reactive({
            raw_df <- raw_data_r()
            if (is.null(raw_df) || !is.data.frame(raw_df) || nrow(raw_df) == 0L) {
                return(list(
                    coords_status = "no_data",
                    has_data = FALSE,
                    lat_col = "",
                    lon_col = "",
                    country_col = "",
                    has_lat = FALSE,
                    has_lon = FALSE,
                    has_country = FALSE
                ))
            }

            lat_selected <- sanitize_map_selection("decimalLatitude", rv$map_values[["decimalLatitude"]])
            if (!has_selected_value(lat_selected)) {
                lat_selected <- sanitize_map_selection("decimalLatitude", input$map_decimalLatitude)
            }
            lon_selected <- sanitize_map_selection("decimalLongitude", rv$map_values[["decimalLongitude"]])
            if (!has_selected_value(lon_selected)) {
                lon_selected <- sanitize_map_selection("decimalLongitude", input$map_decimalLongitude)
            }
            country_selected <- sanitize_map_selection("country", rv$map_values[["country"]])
            if (!has_selected_value(country_selected)) {
                country_selected <- sanitize_map_selection("country", input$map_country)
            }

            lat_col <- if (has_selected_value(lat_selected)) as.character(lat_selected[[1]]) else ""
            lon_col <- if (has_selected_value(lon_selected)) as.character(lon_selected[[1]]) else ""
            country_col <- if (has_selected_value(country_selected)) as.character(country_selected[[1]]) else ""

            has_lat <- nzchar(lat_col) && lat_col %in% names(raw_df)
            has_lon <- nzchar(lon_col) && lon_col %in% names(raw_df)
            has_country <- nzchar(country_col) && country_col %in% names(raw_df)

            missing_count <- sum(!c(has_lat, has_lon, has_country))
            status <- if (has_lat && has_lon && has_country) {
                "ok"
            } else if (missing_count >= 2L) {
                "missing_multiple"
            } else if (!has_lat) {
                "missing_lat"
            } else if (!has_lon) {
                "missing_lon"
            } else {
                "missing_country"
            }

            list(
                coords_status = status,
                has_data = TRUE,
                lat_col = lat_col,
                lon_col = lon_col,
                country_col = country_col,
                has_lat = has_lat,
                has_lon = has_lon,
                has_country = has_country
            )
        })

        # Lightweight mapped preview (first 100 raw rows only)
        preview_processed_data <- shiny::reactive({
            shiny::req(raw_data_r())

            preview_raw <- utils::head(raw_data_r(), 100L)
            preview_occurrence_ids <- if (nrow(preview_raw) > 0L) {
                sprintf("preview-%06d", seq_len(nrow(preview_raw)))
            } else {
                character(0)
            }

            preview_result <- build_mapped_result(
                df_input = preview_raw,
                occurrence_ids_input = preview_occurrence_ids
            )

            preview_result$data
        })

        attr(processed_data, "preview_data") <- preview_processed_data
        attr(processed_data, "validation_gate") <- validation_gate_r
        attr(processed_data, "validation_gate_coords") <- coord_validation_gate_r

        # Explicit return
        return(processed_data)
    })
}
