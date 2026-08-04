# Title: Mapping Module - Darwin Core Field Mapping
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-09
# Version: 2.0 - Enhanced with filters and UUID generation

#' Mapping Module UI
#'
#' @param id Module namespace ID
#' @return Shiny UI tagList
#' @export
mod_mapping_ui <- function(id) {
    ns <- shiny::NS(id)

    shiny::tagList(
    bslib::layout_sidebar(
        sidebar = bslib::sidebar(
            width = 280,
            class = "mapping-sidebar",
            shiny::uiOutput(ns("required_fields_strip")),
            shiny::hr(),
            shiny::uiOutput(ns("sidebar_actions_label")),
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
            shiny::actionButton(
                ns("add_term"),
                shiny::uiOutput(ns("btn_add_term_label"), inline = TRUE),
                class = "btn-outline-secondary w-100 mb-2",
                icon = shiny::icon("plus")
            ),
            shiny::actionButton(
                ns("import_template"),
                shiny::uiOutput(ns("btn_import_template_label"), inline = TRUE),
                class = "btn-outline-secondary w-100 mb-2",
                icon = shiny::icon("file-import")
            ),
            shiny::hr(),
            shiny::uiOutput(ns("sidebar_filters_label")),
            shiny::checkboxInput(
                ns("show_only_mapped"),
                shiny::uiOutput(ns("filter_mapped_label"), inline = TRUE),
                value = FALSE
            )
        ),

        # Main content
        bslib::card(
            bslib::card_header(
                shiny::uiOutput(ns("card_title"))
            ),
            bslib::card_body(
                min_height = "70vh",
                shiny::conditionalPanel(
                    condition = paste0("output['", ns("file_uploaded"), "']"),
                    shiny::div(
                        class = "mapping-scroll-container",
                        shiny::uiOutput(ns("duplicate_source_warning")),
                        shiny::uiOutput(ns("class_pills")),
                        shiny::uiOutput(ns("mapping_ui"))
                    )
                ),
                shiny::conditionalPanel(
                    condition = paste0("!output['", ns("file_uploaded"), "']"),
                    shiny::div(
                        class = "mapping-empty-state",
                        shiny::icon("upload", class = "mapping-empty-icon"),
                        shiny::h4(shiny::uiOutput(ns("no_file_msg"))),
                        shiny::p(shiny::uiOutput(ns("upload_first_msg")))
                    )
                )
            )
        )
    ),
    shiny::tags$script(shiny::HTML(
        "(function () {
          if (window.__sairaMappingScrollRegistered) { return; }
          window.__sairaMappingScrollRegistered = true;
          Shiny.addCustomMessageHandler('saira-mapping-scroll-to-class', function (payload) {
            var id = payload && payload.anchor_id;
            if (!id) { return; }
            // Poll until the target element exists, then scroll. For a class
            // anchor it is already in the DOM (resolves immediately); for a
            // freshly added term card the grid is still rebuilding (~50
            // selectize inputs), which can take a few seconds, so poll on a
            // time budget rather than a fixed frame count.
            var deadline = (window.performance ? performance.now() : Date.now()) + 8000;
            (function tryScroll() {
              var el = document.getElementById(id);
              if (el) {
                el.scrollIntoView({ behavior: 'smooth', block: payload.block || 'start' });
                // Optional highlight, used by the 'next pending' button so the
                // card that was scrolled to is identifiable among its
                // neighbours. Outline only, so nothing shifts.
                if (payload.flash) {
                  el.classList.remove('field-card-flash');
                  void el.offsetWidth;
                  el.classList.add('field-card-flash');
                  setTimeout(function () {
                    el.classList.remove('field-card-flash');
                  }, 2200);
                }
                return;
              }
              var now = (window.performance ? performance.now() : Date.now());
              if (now < deadline) { window.requestAnimationFrame(tryScroll); }
            })();
          });
          // Patch the class pills' state dots and the pending counter in place.
          // Same reason as saira-toggle-field-mapped below: re-rendering the
          // pill bar would recreate its actionButtons on every mapping change.
          Shiny.addCustomMessageHandler('saira-mapping-triage', function (payload) {
            if (!payload) { return; }
            // The first push can land before renderUI has put the pill bar in
            // the DOM (auto-map writes the mapping as the tab is drawn), so
            // poll on a short budget the same way the scroll handler does
            // rather than dropping the update.
            var deadline = (window.performance ? performance.now() : Date.now()) + 3000;
            (function apply() {
              var counter = document.getElementById(payload.count_id);
              if (!counter) {
                var now = (window.performance ? performance.now() : Date.now());
                if (now < deadline) { window.requestAnimationFrame(apply); }
                return;
              }
              counter.textContent = payload.count > 0 ? String(payload.count) : '';
              (payload.dots || []).forEach(function (item) {
                var dot = document.getElementById(item.id);
                if (!dot) { return; }
                dot.className = 'pill-state-dot is-' + item.state;
                dot.title = item.title || '';
              });
              var btn = document.getElementById(payload.button_id);
              if (btn) {
                btn.classList.toggle('is-idle', !(payload.count > 0));
              }
            })();
          });
          // Live-toggle a field card's mapped border without re-rendering the
          // whole mapping grid. Used for fixed-value terms whose free-text read
          // is isolated (ADR-098): the server recomputes is_field_mapped() after
          // typing settles and flips the class here, matching the next render.
          Shiny.addCustomMessageHandler('saira-toggle-field-mapped', function (payload) {
            var id = payload && payload.id;
            if (!id) { return; }
            var el = document.getElementById(id);
            if (!el) { return; }
            if (payload.mapped) {
              el.classList.add('field-mapped');
              el.classList.remove('field-unmapped');
            } else {
              el.classList.add('field-unmapped');
              el.classList.remove('field-mapped');
            }
            // Sync the status badge (e.g. -> EDITADO) without re-rendering. The
            // badge span carries a stable .field-status-badge hook; create it if
            // the term had no badge, remove it when the recomputed badge is null.
            var badge = payload.badge;
            if (badge) {
              var span = el.querySelector('.field-status-badge');
              if (badge.show) {
                if (!span) {
                  var row = el.querySelector('.field-header-row');
                  if (row) { span = document.createElement('span'); row.appendChild(span); }
                }
                if (span) {
                  span.className = badge.class;
                  span.title = badge.title || '';
                  span.textContent = badge.label || '';
                }
              } else if (span && span.parentNode) {
                span.parentNode.removeChild(span);
              }
            }
          });
        })();"
    ))
    )
}
#' @noRd
reset_basis_of_record_state <- function(rv, reset_source_col = TRUE) {
    # Helper: reset basisOfRecord state to empty (consolidates 3 duplicated blocks)
    # If reset_source_col=FALSE, preserves the current source_col (used when changing column)
    rv$basis_of_record_map <- stats::setNames(character(0), character(0))
    rv$basis_of_record_auto_map <- stats::setNames(character(0), character(0))
    if (reset_source_col) {
        rv$basis_of_record_source_col <- ""
    }
    rv$basis_of_record_draft_map <- stats::setNames(character(0), character(0))
    rv$basis_of_record_entries <- data.frame(
        idx = integer(0),
        key = character(0),
        raw = character(0),
        stringsAsFactors = FALSE
    )
    rv$basis_of_record_page <- 1L
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
            extra_terms = character(0),
            rostrum_decisions = NULL,
            rostrum_run_stats = list(),
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
            # Per-species establishment answers (ADR-110). Keyed on the species,
            # not on a source column: one answer covers every record of that
            # taxon. `map` is what reaches the data; `draft` is in-modal only.
            establishment_map = list(
                means = stats::setNames(character(0), character(0)),
                degree = stats::setNames(character(0), character(0))
            ),
            establishment_draft = list(
                means = stats::setNames(character(0), character(0)),
                degree = stats::setNames(character(0), character(0))
            ),
            establishment_auto_map = stats::setNames(character(0), character(0)),
            establishment_entries = data.frame(
                idx = integer(0),
                key = character(0),
                raw = character(0),
                n_records = integer(0),
                invasive = logical(0),
                stringsAsFactors = FALSE
            ),
            establishment_page = 1L,
            is_programmatic_update = FALSE,
            programmatic_terms = character(0),
            # Deduped boolean tracked by an observer below. Drives the only
            # selection that re-renders the whole mapping grid (taxonRank /
            # specificEpithet lock); every other selection updates its card
            # surgically without rebuilding the 50-selectize grid.
            scientificname_mapped = FALSE,
            automap_progress = 0L,
            automap_phrase_idx = 1L,
            automap_phrase_order = integer(0),
            ambiguity_queue = list(),
            dyn_props_keys = list(),
            # Counter bumped on every event that invalidates the dataset baseline
            # (re-upload or a confirmed Reset). Exposed as reset_signal_r so the
            # downstream tabs (names/coords/generalization) can wipe their retained
            # decision state. had_first_upload distinguishes the initial upload
            # (nothing downstream to clear) from a true re-upload.
            downstream_reset = 0L,
            had_first_upload = FALSE
        )

        # SQLite connection for alias and template persistence
        conn <- tryCatch(
            rostrum_connect(),
            error = function(e) {
                warning("[rostrum] Failed to open SQLite connection: ", e$message)
                NULL
            }
        )
        session$onSessionEnded(function() {
            if (!is.null(conn) && DBI::dbIsValid(conn)) {
                DBI::dbDisconnect(conn)
            }
        })

        # i18n keys for all 21 catalog classes (base + on-demand extras).
        # Falls back to raw class name if a future class isn't covered.
        class_tr_keys_map <- c(
            "Record-level"          = "class_record",
            "Occurrence"            = "class_occurrence",
            "Event"                 = "class_event",
            "Location"              = "class_location",
            "Taxon"                 = "class_taxon",
            "Identification"        = "class_identification",
            "GeologicalContext"     = "class_geologicalcontext",
            "MaterialEntity"        = "class_materialentity",
            "MaterialSample"        = "class_materialsample",
            "MeasurementOrFact"     = "class_measurementorfact",
            "Organism"              = "class_organism",
            "ResourceRelationship"  = "class_resourcerelationship",
            "Agent"                 = "class_agent",
            "Assertion"             = "class_assertion",
            "BibliographicResource" = "class_bibliographicresource",
            "MolecularProtocol"     = "class_molecularprotocol",
            "NucleotideAnalysis"    = "class_nucleotideanalysis",
            "NucleotideSequence"    = "class_nucleotidesequence",
            "OrganismInteraction"   = "class_organisminteraction",
            "Protocol"              = "class_protocol",
            "Provenance"            = "class_provenance"
        )

        # Required DwC terms surfaced as a live status strip in the sidebar
        required_fields_strip <- required_mapping_terms()

        # Derives the sorted class list from current active terms (reactive)
        all_filter_categories <- shiny::reactive({
            cats <- vapply(dwc_all(), function(x) x$category, FUN.VALUE = character(1))
            sort(unique(cats))
        })

        # Stable token for a class, shared by pill ids and section anchors
        slug <- function(x) tolower(gsub("[^a-z0-9]+", "", tolower(x)))

        category_label <- function(category_value) {
            key <- unname(class_tr_keys_map[category_value])
            if (is.na(key)) category_value else tr(key, lang_r())
        }

        category_labels <- function() {
            vapply(all_filter_categories(), category_label, FUN.VALUE = character(1))
        }


        # Active DwC terms list: base 50 + any extras added in this session
        dwc_all <- shiny::reactive({
            get_active_dwc_terms_list(extra = rv$extra_terms, lang = lang_r())
        })

        all_term_names <- shiny::reactive({
            vapply(dwc_all(), function(x) x$term, FUN.VALUE = character(1))
        })

        reason_key_from_code <- function(reason_code) {
            switch(as.character(reason_code),
                exact_match = "rostrum_reason_exact_match",
                known_synonym = "rostrum_reason_known_synonym",
                token_overlap = "rostrum_reason_token_overlap",
                text_similarity = "rostrum_reason_text_similarity",
                veto_hard = "rostrum_reason_veto_hard",
                veto_soft = "rostrum_reason_veto_soft",
                semantic_penalty = "rostrum_reason_semantic_penalty",
                ambiguity_detected = "rostrum_reason_ambiguity_detected",
                ambiguity_resolved_manual = "rostrum_reason_ambiguity_detected",
                conflict_won = "rostrum_reason_conflict_won",
                conflict_lost = "rostrum_reason_conflict_lost",
                fallback_verbatim_from_loser = "rostrum_reason_conflict_won",
                fallback_verbatim_from_primary = "rostrum_reason_conflict_won",
                template_priority_override = "rostrum_reason_template_override",
                content_validated = "badge_reason_content_validated",
                manual_adjust = "badge_reason_manual_adjust",
                manual_cleared = "badge_reason_manual_cleared",
                type_incompatible = "badge_reason_type_incompatible",
                temporal_manual_only = "badge_reason_temporal_manual_only",
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
                AMBIGUO = "badge field-status-badge badge-ambiguous",
                EDITADO = "badge field-status-badge bg-info",
                ALIAS = "badge field-status-badge bg-primary",
                TEMPLATE = "badge field-status-badge badge-template",
                ASSISTENTE = "badge field-status-badge badge-assistant",
                MANUAL = "badge field-status-badge bg-light text-muted border",
                "badge field-status-badge bg-light text-muted border"
            )

            badge_label <- switch(status,
                AUTO = tr("rostrum_badge_auto", lang_r()),
                SUGERIDO = tr("rostrum_badge_suggested", lang_r()),
                AMBIGUO = tr("rostrum_badge_ambiguous", lang_r()),
                EDITADO = tr("badge_edited", lang_r()),
                ALIAS = tr("rostrum_badge_alias", lang_r()),
                TEMPLATE = tr("rostrum_badge_template", lang_r()),
                ASSISTENTE = tr("rostrum_badge_assistant", lang_r()),
                MANUAL = tr("rostrum_badge_manual", lang_r()),
                tr("rostrum_badge_manual", lang_r())
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

        # Push a single card's mapped border + status badge to the client without
        # re-rendering the whole mapping grid. Reproduces exactly what the next
        # full render of build_field_card would produce for this term, via the
        # `saira-toggle-field-mapped` handler (ADR-098). Reads are isolated so
        # callers inside reactive observers do not gain extra dependencies.
        establishment_terms <- c("establishmentMeans", "degreeOfEstablishment")

        # Answers given in the per-species assistant make an establishment card
        # count as mapped even with no column selected, and give it its own
        # badge instead of the grey MANUAL one. Shared by the grid render and
        # push_card_state so the two never disagree about a card's state.
        apply_establishment_card_state <- function(term, current_val, is_mapped, meta) {
            if (!(term %in% establishment_terms)) {
                return(list(is_mapped = is_mapped, meta = meta))
            }
            field <- if (identical(term, "establishmentMeans")) "means" else "degree"
            if (establishment_answer_count(rv$establishment_map, field) > 0L) {
                is_mapped <- TRUE
                if (!has_selected_value(current_val)) {
                    meta$status <- "ASSISTENTE"
                }
            }
            list(is_mapped = is_mapped, meta = meta)
        }

        push_card_state <- function(term) {
            shiny::isolate({
                current_val <- sanitize_map_selection(term, rv$map_values[[term]])
                if (!has_selected_value(current_val)) {
                    current_val <- sanitize_map_selection(term, input[[paste0("map_", term)]])
                }
                meta <- rv$map_meta[[term]]
                if (is.null(meta)) {
                    meta <- default_meta()
                }
                card_state <- apply_establishment_card_state(
                    term, current_val, is_field_mapped(term, current_val, input), meta
                )
                meta <- card_state$meta
                badge <- build_badge_info(meta)
                badge_payload <- if (is.null(badge)) {
                    list(show = FALSE)
                } else {
                    list(
                        show = TRUE,
                        label = badge$label,
                        class = badge$class,
                        title = badge$title
                    )
                }
                session$sendCustomMessage(
                    "saira-toggle-field-mapped",
                    list(
                        id = ns(paste0("fieldcard_", term)),
                        mapped = isTRUE(card_state$is_mapped),
                        badge = badge_payload
                    )
                )
            })
            invisible(NULL)
        }

        parse_ambiguity_candidates <- function(alternatives_json) {
            if (is.null(alternatives_json) || is.na(alternatives_json) || !nzchar(alternatives_json)) {
                return(list())
            }

            parsed <- tryCatch(
                jsonlite::fromJSON(alternatives_json, simplifyVector = FALSE),
                error = function(e) NULL
            )

            if (is.null(parsed) || length(parsed) == 0) {
                return(list())
            }

            Filter(function(item) {
                !is.null(item$column_name) && nzchar(as.character(item$column_name))
            }, parsed)
        }

        preview_values_for_column <- function(col_name, n = 5L) {
            df <- raw_data_r()
            if (!is.data.frame(df) || !(col_name %in% names(df))) {
                return(character(0))
            }

            vals <- as.character(df[[col_name]])
            vals <- vals[!is.na(vals)]
            vals <- trimws(vals)
            vals <- vals[nzchar(vals)]
            utils::head(vals, as.integer(n))
        }

        # Returns n sample values as the *processed* output for a term — same
        # logic as build_processed_mapping_df, run on a head-slice for cost.
        # Memoize per-card sample previews by (term, columns, n): mapping_ui
        # re-renders ALL cards on any change, but only the edited card's preview
        # actually changes. Without this, editing one field recomputes the
        # head(200) sample for every mapped standard term (camtrap maps ~25-40 ->
        # noticeable lag). Dataset-scoped: cleared on a new upload. Restricted to
        # standard terms, whose preview depends only on (term, columns,
        # raw_data) -- never on rv$basis_of_record_map / rv$dyn_props_keys.
        preview_cache <- new.env(parent = emptyenv())

        # Tracks which map_<term> inputs have reported a non-NULL value at least
        # once (i.e. the card rendered and the client echoed it). The input-sync
        # observer needs this to tell "input not rendered yet" (skip) from "user
        # cleared a selectInput" (NULL after it had a value). Non-reactive on
        # purpose: writing here must not re-trigger the observer. Reset per
        # upload alongside preview_cache.
        rendered_map_inputs <- new.env(parent = emptyenv())

        processed_preview_for_term <- function(term, current_val, n = 3L) {
            df <- raw_data_r()
            if (!is.data.frame(df) || nrow(df) == 0) return(character(0))
            user_cols <- sanitize_map_selection(term, current_val)
            is_establishment <- term %in% establishment_terms
            # The establishment terms can have values with no column mapped, so
            # they are the one case where an empty selection is not the end.
            if (!has_selected_value(user_cols) && !is_establishment) return(character(0))
            missing <- setdiff(user_cols[nzchar(user_cols)], names(df))
            if (length(missing) > 0) return(character(0))

            cacheable <- !(term %in% c("basisOfRecord", "dynamicProperties", establishment_terms))
            key <- if (cacheable) {
                paste(term, paste(user_cols, collapse = ""), n, sep = "")
            } else {
                NA_character_
            }
            if (cacheable && exists(key, envir = preview_cache, inherits = FALSE)) {
                return(get(key, envir = preview_cache, inherits = FALSE))
            }

            slice <- utils::head(df, 200L)
            result <- tryCatch(
                if (is_establishment) {
                    species <- utils::head(get_establishment_species(), 200L)
                    list(values = build_establishment_term_value(
                        term = term,
                        df = slice,
                        user_cols = user_cols,
                        species_values = if (length(species) == nrow(slice)) species else NULL,
                        establishment_map = rv$establishment_map,
                        out_sep = " | "
                    ))
                } else {
                    build_term_value(
                        term = term,
                        df = slice,
                        user_cols = user_cols,
                        basis_of_record_map = rv$basis_of_record_map,
                        dyn_props_keys = rv$dyn_props_keys,
                        out_sep = " | "
                    )
                },
                error = function(e) list(values = character(0))
            )
            vals <- as.character(result$values)
            vals <- vals[!is.na(vals) & nzchar(vals)]
            out <- utils::head(vals, as.integer(n))
            if (cacheable) {
                assign(key, out, envir = preview_cache)
            }
            out
        }

        show_next_ambiguity_modal <- function() {
            if (length(rv$ambiguity_queue) == 0) {
                return(invisible(NULL))
            }

            item <- rv$ambiguity_queue[[1]]
            term <- as.character(item$term)
            candidates <- item$candidates
            if (length(candidates) == 0) {
                rv$ambiguity_queue <- rv$ambiguity_queue[-1]
                return(show_next_ambiguity_modal())
            }

            choice_values <- vapply(candidates, function(x) as.character(x$column_name), FUN.VALUE = character(1))
            choice_labels <- vapply(candidates, function(x) {
                score <- suppressWarnings(as.numeric(x$final_score))
                if (is.na(score)) {
                    return(as.character(x$column_name))
                }
                sprintf("%s (%.2f)", as.character(x$column_name), score)
            }, FUN.VALUE = character(1))
            choices <- stats::setNames(choice_values, choice_labels)

            samples_ui <- lapply(candidates, function(candidate) {
                col_name <- as.character(candidate$column_name)
                sample_values <- preview_values_for_column(col_name, n = 5L)
                shiny::tags$div(
                    class = "mb-2",
                    shiny::tags$strong(col_name),
                    shiny::tags$div(
                        class = "small text-muted",
                        if (length(sample_values) == 0) {
                            tr("rostrum_ambiguity_no_sample", lang_r())
                        } else {
                            paste(sample_values, collapse = " | ")
                        }
                    )
                )
            })

            shiny::showModal(shiny::modalDialog(
                title = sprintf(tr("rostrum_ambiguity_title", lang_r()), term),
                shiny::p(tr("rostrum_ambiguity_question", lang_r())),
                shiny::radioButtons(
                    ns("ambiguity_choice"),
                    label = NULL,
                    choices = choices,
                    selected = choice_values[[1]]
                ),
                shiny::tags$hr(),
                shiny::tags$div(
                    class = "small text-muted mb-2",
                    tr("rostrum_ambiguity_samples", lang_r())
                ),
                shiny::tagList(samples_ui),
                easyClose = FALSE,
                footer = shiny::tagList(
                    shiny::actionButton(ns("skip_ambiguity_choice"), tr("btn_cancel", lang_r())),
                    shiny::actionButton(ns("confirm_ambiguity_choice"), tr("rostrum_ambiguity_confirm", lang_r()), class = "btn-primary")
                )
            ))
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

        # --- establishmentMeans / degreeOfEstablishment assistant (ADR-110) ---
        # Same page size and snapshot-sync contract as the basisOfRecord
        # assistant, but keyed on the species read from the scientificName
        # column instead of on the unique values of the term's own column.
        establishment_page_size <- 20L

        get_establishment_species <- function() {
            df <- raw_data_r()
            if (!is.data.frame(df) || nrow(df) == 0L) {
                return(character(0))
            }
            selected <- sanitize_map_selection(
                "scientificName", rv$map_values[["scientificName"]]
            )
            if (!has_selected_value(selected)) {
                selected <- sanitize_map_selection(
                    "scientificName", input$map_scientificName
                )
            }
            if (!has_selected_value(selected)) {
                return(character(0))
            }
            col <- as.character(selected[[1]])
            if (!(col %in% names(df))) {
                return(character(0))
            }
            as.character(df[[col]])
        }

        establishment_page_count <- function() {
            total_items <- nrow(rv$establishment_entries)
            if (total_items <= 0) {
                return(1L)
            }
            max(1L, as.integer(ceiling(total_items / establishment_page_size)))
        }

        get_establishment_page_entries <- function() {
            entries <- rv$establishment_entries
            if (nrow(entries) == 0) {
                return(entries)
            }
            total_pages <- establishment_page_count()
            current_page <- max(1L, min(as.integer(rv$establishment_page), total_pages))
            start_idx <- ((current_page - 1L) * establishment_page_size) + 1L
            end_idx <- min(nrow(entries), start_idx + establishment_page_size - 1L)
            entries[start_idx:end_idx, , drop = FALSE]
        }

        establishment_choices <- function(field = "means") {
            catalog <- if (identical(field, "degree")) {
                degree_of_establishment_vocab_catalog
            } else {
                establishment_means_vocab_catalog
            }
            dwc_vocab_choices(
                catalog,
                lang = lang_r(),
                include_skip = TRUE,
                skip_label = tr("est_assistant_skip_option", lang_r())
            )
        }

        # Auto-suggestions overlaid by the user's in-modal edits. Only
        # establishmentMeans has suggestions; degreeOfEstablishment starts empty
        # by design (it depends on the record, not on the species).
        get_effective_establishment_map <- function() {
            entries <- rv$establishment_entries
            empty <- stats::setNames(character(0), character(0))
            if (nrow(entries) == 0) {
                return(list(means = empty, degree = empty))
            }

            keys <- entries$key
            auto <- sanitize_establishment_field_map(rv$establishment_auto_map, "means")
            draft <- sanitize_establishment_map(rv$establishment_draft)

            means <- auto[keys]
            means[is.na(means)] <- ""
            draft_means <- draft$means[keys]
            has_draft <- !is.na(draft_means)
            means[has_draft] <- draft_means[has_draft]

            degree <- draft$degree[keys]
            degree[is.na(degree)] <- ""

            list(
                means = stats::setNames(
                    as.character(sanitize_establishment_terms(means, "means")), keys
                ),
                degree = stats::setNames(
                    as.character(sanitize_establishment_terms(degree, "degree")), keys
                )
            )
        }

        sync_establishment_page_to_draft <- function() {
            entries <- get_establishment_page_entries()
            if (nrow(entries) == 0) {
                return(invisible(NULL))
            }
            for (i in seq_len(nrow(entries))) {
                key <- entries$key[[i]]
                idx <- entries$idx[[i]]
                for (field in c("means", "degree")) {
                    input_value <- input[[paste0("est_", field, "_", idx)]]
                    if (is.null(input_value)) {
                        next
                    }
                    sanitized <- sanitize_establishment_terms(
                        as.character(input_value)[[1]], field
                    )
                    # [[ ]] on a named character vector errors for an absent
                    # name (unlike a list), so gate the read like the
                    # basisOfRecord assistant does.
                    draft_field <- rv$establishment_draft[[field]]
                    has_key <- key %in% names(draft_field)
                    current <- if (has_key) as.character(draft_field[[key]]) else NA_character_
                    if (!has_key || !identical(current, sanitized)) {
                        rv$establishment_draft[[field]][[key]] <- sanitized
                    }
                }
            }
            invisible(NULL)
        }

        reset_establishment_state <- function() {
            empty <- stats::setNames(character(0), character(0))
            rv$establishment_map <- list(means = empty, degree = empty)
            rv$establishment_draft <- list(means = empty, degree = empty)
            rv$establishment_auto_map <- empty
            rv$establishment_entries <- data.frame(
                idx = integer(0), key = character(0), raw = character(0),
                n_records = integer(0), invasive = logical(0),
                stringsAsFactors = FALSE
            )
            rv$establishment_page <- 1L
            invisible(NULL)
        }

        # Loading modal helpers (delegated to mod_mapping_loading.R)
        loading_phrase_specs <- mapping_loading_phrase_specs()


        # Translated labels
        output$btn_auto_map_label <- shiny::renderUI({
            tr("btn_auto_mapping", lang_r())
        })

        output$btn_reset_label <- shiny::renderUI({
            tr("btn_reset", lang_r())
        })

        output$sidebar_actions_label <- shiny::renderUI({
            shiny::tags$label(tr("mapping_sidebar_actions", lang_r()), class = "form-label")
        })

        output$sidebar_filters_label <- shiny::renderUI({
            shiny::tags$label(tr("mapping_sidebar_filters", lang_r()), class = "form-label")
        })

        output$filter_mapped_label <- shiny::renderUI({
            tr("filter_mapped_only", lang_r())
        })

        output$card_title <- shiny::renderUI({
            tr("mapping_title", lang_r())
        })

        # Live required-fields status pills in the sidebar (mapped-based, reactive
        # on every mapping change). occurrenceID is auto-UUID -> is_field_mapped()
        # already returns TRUE for it.
        output$required_fields_strip <- shiny::renderUI({
            mapped_flags <- vapply(required_fields_strip, function(term) {
                current_val <- rv$map_values[[term]]
                if (is.null(current_val)) {
                    current_val <- input[[paste0("map_", term)]]
                }
                current_val <- sanitize_map_selection(term, current_val)
                is_field_mapped(term, current_val, input)
            }, FUN.VALUE = logical(1))

            chips <- lapply(required_fields_strip, function(term) {
                mapped <- mapped_flags[[term]]
                status_label <- if (mapped) {
                    tr("preview_readiness_present", lang_r())
                } else {
                    tr("preview_readiness_missing", lang_r())
                }
                shiny::span(
                    class = paste(
                        "mapping-required-chip",
                        if (mapped) "is-mapped" else "is-missing"
                    ),
                    title = status_label,
                    `aria-label` = paste(term, status_label),
                    shiny::tags$i(
                        class = if (mapped) {
                            "fa-solid fa-circle-check"
                        } else {
                            "fa-solid fa-circle-xmark"
                        }
                    ),
                    term
                )
            })

            n_total <- length(required_fields_strip)
            n_mapped <- sum(mapped_flags)

            shiny::div(
                class = "mapping-required-sidebar",
                shiny::div(
                    class = "mapping-required-header",
                    shiny::tags$span(
                        class = "mapping-required-strip-label",
                        tr("preview_readiness_title", lang_r())
                    ),
                    shiny::tags$span(
                        class = paste(
                            "mapping-required-count",
                            if (n_mapped == n_total) "is-complete" else ""
                        ),
                        paste0(n_mapped, "/", n_total)
                    )
                ),
                chips
            )
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

        # BasisOfRecord assistant (delegated to mod_mapping_basis_assistant.R)
        setup_basis_of_record_assistant(
            input = input, output = output, session = session,
            rv = rv, ns = ns, lang_r = lang_r, raw_data_r = raw_data_r,
            basis_of_record_page_size = basis_of_record_page_size,
            basis_of_record_page_count = basis_of_record_page_count,
            get_basis_of_record_page_entries = get_basis_of_record_page_entries,
            basis_of_record_target_choices = basis_of_record_target_choices,
            get_effective_basis_of_record_map = get_effective_basis_of_record_map,
            get_basis_of_record_source_col = get_basis_of_record_source_col,
            sync_current_page_to_draft = sync_current_page_to_draft
        )

        # The grid only re-renders on structural changes (ADR-098), so saving
        # the assistant would leave the two cards showing their old badge and
        # border. Refresh them surgically, the same way a column selection does.
        shiny::observeEvent(rv$establishment_map, {
            for (term in establishment_terms) {
                push_card_state(term)
            }
        }, ignoreInit = TRUE)

        setup_establishment_assistant(
            input = input, output = output, session = session,
            rv = rv, ns = ns, lang_r = lang_r,
            establishment_page_size = establishment_page_size,
            establishment_page_count = establishment_page_count,
            get_establishment_page_entries = get_establishment_page_entries,
            establishment_choices = establishment_choices,
            get_effective_establishment_map = get_effective_establishment_map,
            get_establishment_species = get_establishment_species,
            sync_establishment_page_to_draft = sync_establishment_page_to_draft
        )


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

        # Camtrap-origin uploads should auto-map without an "Auto-map" click, but
        # we cannot run the engine the instant data loads: the mapping field
        # cards have not rendered yet, so the programmatic selections would be
        # read back as NULL by the input-sync observer below and wiped (it treats
        # a not-yet-rendered input as a user clear). This flag defers the run
        # until the UI is up (see the scientificName-triggered observer).
        camtrap_automap_pending <- shiny::reactiveVal(FALSE)

        shiny::observeEvent(raw_data_r(),
            {
                shiny::req(raw_data_r())

                # Auto-register uploaded columns that are valid DwC terms outside
                # the base set (e.g. the extra terms camtrapdp::write_dwc() emits:
                # geodeticDatum, taxonID, organismID, coordinatePrecision, ...) so
                # they appear as mapping targets instead of unknown columns.
                rv$extra_terms <- detect_extra_dwc_terms(names(raw_data_r()))
                term_names <- names(get_active_dwc_terms_list(
                    extra = rv$extra_terms, lang = lang_r()
                ))

                rv$map_values <- empty_map_values(term_names)
                rv$map_meta <- empty_map_meta(term_names)
                rv$occurrence_ids <- resolve_occurrence_ids(raw_data_r())
                rv$eventdate_parse_failures <- 0L
                rv$last_eventdate_warn_count <- NA_integer_
                rv$programmatic_terms <- character(0)
                rv$ambiguity_queue <- list()
                rv$rostrum_decisions <- NULL
                rv$rostrum_run_stats <- list()
                rv$dyn_props_keys <- list()
                reset_basis_of_record_state(rv)
                reset_establishment_state()
                rm(list = ls(preview_cache, all.names = TRUE), envir = preview_cache)
                rm(
                    list = ls(rendered_map_inputs, all.names = TRUE),
                    envir = rendered_map_inputs
                )

                # Camtrap columns are Darwin Core terms already: queue the
                # automatic mapping (run once the cards render). Non-camtrap
                # uploads leave the flag FALSE and require the manual click.
                camtrap_automap_pending(
                    !is.null(attr(raw_data_r(), "saira_camtrap_source"))
                )

                # Signal the downstream tabs to clear their retained decisions.
                # The first upload has nothing downstream to clear (silent); a
                # re-upload warns the user why their validations disappeared.
                rv$downstream_reset <- rv$downstream_reset + 1L
                if (isTRUE(rv$had_first_upload)) {
                    shiny::showNotification(
                        tr("notif_reupload_cleared", lang_r()),
                        type = "warning", duration = 4
                    )
                } else {
                    rv$had_first_upload <- TRUE
                }
            },
            ignoreNULL = TRUE
        )

        # Consume the deferred camtrap auto-map: the first non-NULL scientificName
        # means the field cards have rendered, so perform_auto_map()'s selections
        # land on real inputs (and survive the sync observer). Fires only when the
        # flag was set by a camtrap upload; otherwise a no-op on every remap.
        shiny::observeEvent(input$map_scientificName, {
            if (!isTRUE(camtrap_automap_pending())) {
                return(invisible(NULL))
            }
            camtrap_automap_pending(FALSE)
            perform_auto_map()
        }, ignoreInit = TRUE, ignoreNULL = TRUE)

        shiny::observe({
            shiny::req(raw_data_r())
            # all_term_names() carries lang_r() through dwc_all(), and that
            # dependency is load-bearing -- do not isolate it to "save" a scan
            # over the terms on a language switch. output$mapping_ui also
            # depends on lang_r(), so switching language destroys and rebuilds
            # every map_<term> input. Re-running here in the same flush reaffirms
            # rv$map_values from the still-valid inputs before the grid is
            # rebuilt from it. Without it, this observer only wakes once the
            # client re-binds the new inputs, reads them as NULL with
            # rendered_map_inputs already TRUE, and takes the "user cleared the
            # field" branch below -- wiping the whole mapping (ADR-111).
            term_names <- all_term_names()

            for (term in term_names) {
                input_id <- paste0("map_", term)
                input_value <- input[[input_id]]
                if (is.null(input_value)) {
                    # NULL pode significar: (a) input ainda nao renderizado
                    # (carga inicial ou valor setado por codigo cujo card ainda
                    # nao ecoou — nao devemos sobrescrever map_values com ""), ou
                    # (b) usuario limpou um selectInput que estava setado (input
                    # devolve NULL, nao ""). So e (b) se o input ja reportou um
                    # valor antes (rendered_map_inputs); senao e (a). Sem esse
                    # gate, um valor programatico (ex.: auto-map camtrap em
                    # extra-terms) era apagado na janela entre o set e o eco do
                    # cliente.
                    if (!isTRUE(rendered_map_inputs[[term]])) {
                        next
                    }
                    old_value_isolated <- shiny::isolate(rv$map_values[[term]])
                    if (is.null(old_value_isolated) ||
                        !nzchar(trimws(as.character(old_value_isolated)[[1]]))) {
                        next
                    }
                    input_value <- ""
                } else {
                    # First non-NULL report for this input: the card rendered and
                    # the client echoed it. A later NULL is then a real clear.
                    rendered_map_inputs[[term]] <- TRUE
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
                            reset_basis_of_record_state(rv, reset_source_col = FALSE)
                        }
                    }

                    is_programmatic_term <- term %in% shiny::isolate(rv$programmatic_terms)
                    if (is_programmatic_term) {
                        rv$programmatic_terms <- setdiff(shiny::isolate(rv$programmatic_terms), term)
                    }

                    if (!isTRUE(rv$is_programmatic_update) && !is_programmatic_term) {
                        previous_meta <- shiny::isolate(rv$map_meta[[term]])
                        rv$map_meta[[term]] <- build_manual_meta(
                            previous_meta = previous_meta,
                            has_value = has_selected_value(sanitized)
                        )
                        # Record alias override when user manually selects a column
                        if (!is.null(conn) && DBI::dbIsValid(conn) &&
                            has_selected_value(sanitized) && nzchar(sanitized[[1]])) {
                            col_selected <- as.character(sanitized[[1]])
                            run_id <- shiny::isolate(rv$rostrum_run_stats[["run_id"]])
                            tryCatch(
                                rostrum_record_alias_override(
                                    conn = conn,
                                    col_name = col_selected,
                                    dwc_term = term,
                                    run_id = run_id
                                ),
                                error = function(e) {
                                    warning("[rostrum] Could not record alias override: ", e$message)
                                }
                            )
                        }
                    }
                    # Surgically refresh this card's border/badge (no grid re-render).
                    push_card_state(term)
                }
            }
        })

        # Deduped flag driving the single re-render path (taxon lock). Updates
        # only when scientificName's mapped-state flips, so changing the
        # scientificName column does not rebuild the grid.
        shiny::observe({
            mapped <- has_selected_value(
                sanitize_map_selection("scientificName", rv$map_values[["scientificName"]])
            )
            if (!identical(isTRUE(rv$scientificname_mapped), mapped)) {
                rv$scientificname_mapped <- mapped
            }
        })

        # Sync dynamicProperties per-column JSON key overrides.
        # Depends reactively on (a) selected columns and (b) each per-column
        # textInput. Pruning of stale entries happens automatically because
        # only currently-selected columns contribute to new_keys.
        shiny::observe({
            if (isTRUE(rv$is_programmatic_update)) {
                return(invisible(NULL))
            }
            selected_cols <- rv$map_values[["dynamicProperties"]]
            if (is.null(selected_cols)) {
                selected_cols <- character(0)
            }
            selected_cols <- as.character(selected_cols)
            selected_cols <- selected_cols[nzchar(selected_cols)]

            new_keys <- list()
            for (col_name in selected_cols) {
                input_id <- paste0("dynprops_key_", make.names(col_name))
                raw_value <- input[[input_id]]
                if (is.null(raw_value)) {
                    next
                }
                trimmed <- trimws(as.character(raw_value))
                if (!nzchar(trimmed)) {
                    next
                }
                new_keys[[col_name]] <- trimmed
            }

            current_keys <- shiny::isolate(rv$dyn_props_keys)
            if (!identical(current_keys, new_keys)) {
                rv$dyn_props_keys <- new_keys
            }
        })

        set_custom_term_meta <- function(term, has_value) {
            if (isTRUE(rv$is_programmatic_update)) {
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
                push_card_state("datasetName")
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$modified_use_today,
            {
                has_value <- isTRUE(input$modified_use_today) || !is.null(input$custom_modified_date)
                set_custom_term_meta("modified", has_value)
                push_card_state("modified")
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$custom_modified_date,
            {
                has_value <- isTRUE(input$modified_use_today) || !is.null(input$custom_modified_date)
                set_custom_term_meta("modified", has_value)
                push_card_state("modified")
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$confirm_ambiguity_choice, {
            if (length(rv$ambiguity_queue) == 0) {
                shiny::removeModal()
                return(invisible(NULL))
            }

            item <- rv$ambiguity_queue[[1]]
            term <- as.character(item$term)
            selected_col <- input$ambiguity_choice
            if (is.null(selected_col) || length(selected_col) == 0 || is.na(selected_col)) {
                selected_col <- ""
            }
            selected_col <- as.character(selected_col[[1]])

            if (nzchar(selected_col)) {
                rv$is_programmatic_update <- TRUE
                on.exit(
                    {
                        rv$is_programmatic_update <- FALSE
                        rv$programmatic_terms <- character(0)
                    },
                    add = TRUE
                )

                set_map_value(term, selected_col, update_input = TRUE)

                selected_candidate <- Filter(function(candidate) {
                    identical(as.character(candidate$column_name), selected_col)
                }, item$candidates)

                selected_score <- NA_real_
                if (length(selected_candidate) > 0) {
                    selected_score <- suppressWarnings(as.numeric(selected_candidate[[1]]$final_score))
                }

                rv$map_meta[[term]] <- list(
                    status = "EDITADO",
                    score = selected_score,
                    reason = "ambiguity_resolved_manual",
                    source = "manual",
                    alternatives_json = jsonlite::toJSON(item$candidates, auto_unbox = TRUE)
                )

                # Record alias: confirmation if top candidate chosen, override otherwise
                if (!is.null(conn) && DBI::dbIsValid(conn)) {
                    run_id <- shiny::isolate(rv$rostrum_run_stats[["run_id"]])
                    top_col <- if (length(item$candidates) > 0) {
                        as.character(item$candidates[[1]]$column_name)
                    } else {
                        ""
                    }
                    tryCatch(
                        if (identical(selected_col, top_col) && !is.na(selected_score)) {
                            rostrum_record_alias_confirmation(
                                conn = conn,
                                col_name = selected_col,
                                dwc_term = term,
                                score_original = selected_score,
                                run_id = run_id
                            )
                        } else {
                            rostrum_record_alias_override(
                                conn = conn,
                                col_name = selected_col,
                                dwc_term = term,
                                run_id = run_id
                            )
                        },
                        error = function(e) {
                            warning("[rostrum] Could not record alias from ambiguity: ", e$message)
                        }
                    )
                }
            }

            rv$ambiguity_queue <- rv$ambiguity_queue[-1]
            shiny::removeModal()
            show_next_ambiguity_modal()
        })

        shiny::observeEvent(input$skip_ambiguity_choice, {
            if (length(rv$ambiguity_queue) == 0) {
                shiny::removeModal()
                return(invisible(NULL))
            }

            rv$ambiguity_queue <- rv$ambiguity_queue[-1]
            shiny::removeModal()
            show_next_ambiguity_modal()
        })

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

        # Class pill bar: pure scroll-navigation anchors. Clicking a pill scrolls
        # to its category section. No filter toggle — all sections always render.
        # The state dots and the pending counter are NOT rendered here: this
        # output must not depend on rv$map_meta, or every column pick would
        # recreate the pill actionButtons. They are placeholders patched in
        # place by the saira-mapping-triage handler (see the observer below).
        output$class_pills <- shiny::renderUI({
            cats <- all_filter_categories()

            shiny::div(
                class = "mapping-class-pillbar",
                shiny::actionButton(
                    ns("class_pill_all"),
                    tr("mapping_pill_all", lang_r()),
                    class = "stream-pill",
                    icon = shiny::icon("arrows-up-to-line")
                ),
                lapply(cats, function(cat) {
                    shiny::actionButton(
                        ns(paste0("class_pill_", slug(cat))),
                        shiny::tagList(
                            shiny::span(
                                id = ns(paste0("pill_dot_", slug(cat))),
                                class = "pill-state-dot is-clear"
                            ),
                            category_label(cat)
                        ),
                        class = "stream-pill"
                    )
                }),
                shiny::actionButton(
                    ns("next_pending"),
                    shiny::tagList(
                        tr("mapping_next_pending", lang_r()),
                        shiny::span(
                            id = ns("next_pending_count"),
                            class = "next-pending-count"
                        )
                    ),
                    class = "stream-pill next-pending-pill is-idle",
                    icon = shiny::icon("arrow-right")
                )
            )
        })

        # Terms that still need the user, in grid order: a required term with no
        # mapping, or one the Rostrum was not sure about. Feeds both the pill
        # dots and the "next pending" queue, so the count and the jump target
        # can never disagree.
        # Fully isolated: the caller declares what it wakes on. Reading the 66
        # map_ and usecustom_ inputs here would make the triage observer depend
        # on all of them, and auto-map writes each term separately with
        # update_input = TRUE, so the client echo would re-run this 66-term loop
        # once per flush. rv$map_values is the source of truth anyway; the sync
        # observer fills it one flush after a selection, which is what the
        # observer below wakes on.
        pending_terms <- function() shiny::isolate({
            fields <- dwc_all()
            keep <- vapply(fields, function(item) {
                term <- item$term
                current_val <- rv$map_values[[term]]
                if (is.null(current_val)) {
                    current_val <- input[[paste0("map_", term)]]
                }
                current_val <- sanitize_map_selection(term, current_val)
                is_mapped <- is_field_mapped(term, current_val, input)
                if (isTRUE(rv$scientificname_mapped) &&
                    term %in% c("taxonRank", "specificEpithet")) {
                    is_mapped <- TRUE
                }
                field_meta <- rv$map_meta[[term]]
                if (is.null(field_meta)) {
                    field_meta <- default_meta()
                }
                card_state <- apply_establishment_card_state(
                    term, current_val, is_mapped, field_meta
                )
                !is.null(field_state_class(
                    term, card_state$is_mapped, card_state$meta,
                    required_fields_strip
                ))
            }, FUN.VALUE = logical(1))

            fields[keep]
        })

        # Push the dot states and the counter whenever the mapping changes.
        shiny::observe({
            rv$map_values
            rv$map_meta
            rv$extra_terms
            rv$scientificname_mapped
            lang <- lang_r()

            pending <- pending_terms()
            blocked <- vapply(
                pending, function(x) x$term %in% required_fields_strip,
                FUN.VALUE = logical(1)
            )
            blocked_cats <- unique(vapply(
                pending[blocked], function(x) x$category, FUN.VALUE = character(1)
            ))
            review_cats <- unique(vapply(
                pending[!blocked], function(x) x$category, FUN.VALUE = character(1)
            ))

            dots <- lapply(all_filter_categories(), function(cat) {
                state <- if (cat %in% blocked_cats) {
                    "blocked"
                } else if (cat %in% review_cats) {
                    "review"
                } else {
                    "clear"
                }
                list(
                    id = ns(paste0("pill_dot_", slug(cat))),
                    state = state,
                    title = tr(paste0("mapping_pill_state_", state), lang)
                )
            })

            session$sendCustomMessage("saira-mapping-triage", list(
                dots = dots,
                count = length(pending),
                count_id = ns("next_pending_count"),
                button_id = ns("next_pending")
            ))
        })

        # Cycles through the pending queue, one term per click.
        rv_pending_cursor <- shiny::reactiveVal(0L)
        shiny::observeEvent(input$next_pending,
            {
                pending <- pending_terms()
                if (length(pending) == 0L) {
                    shiny::showNotification(
                        tr("mapping_next_pending_none", lang_r()),
                        type = "message",
                        duration = 5
                    )
                    return()
                }
                nxt <- (rv_pending_cursor() %% length(pending)) + 1L
                rv_pending_cursor(nxt)
                session$sendCustomMessage(
                    "saira-mapping-scroll-to-class",
                    list(
                        anchor_id = ns(paste0("fieldcard_", pending[[nxt]]$term)),
                        block = "center",
                        flash = TRUE
                    )
                )
            },
            ignoreInit = TRUE
        )

        # Static observer loop over the full 12-class catalog. Clicking a pill
        # scrolls directly to that category's anchor. No filter toggle.
        for (cls in names(class_tr_keys_map)) {
            local({
                cl <- cls
                pill_id <- paste0("class_pill_", slug(cl))
                shiny::observeEvent(input[[pill_id]],
                    {
                        session$sendCustomMessage(
                            "saira-mapping-scroll-to-class",
                            list(anchor_id = ns(paste0("cat_anchor_", slug(cl))))
                        )
                    },
                    ignoreInit = TRUE
                )
            })
        }

        # "Todos" pill: scroll back to the first rendered category section.
        shiny::observeEvent(input$class_pill_all,
            {
                first_cat <- unique(vapply(
                    dwc_all(), function(x) x$category, FUN.VALUE = character(1)
                ))[1]
                session$sendCustomMessage(
                    "saira-mapping-scroll-to-class",
                    list(anchor_id = ns(paste0("cat_anchor_", slug(first_cat))))
                )
            },
            ignoreInit = TRUE
        )

        # Add Term button label
        output$btn_add_term_label <- shiny::renderUI({
            tr("btn_add_term", lang_r())
        })

        # Import mapping template button label (ADR-087: round-trip via aliases)
        output$btn_import_template_label <- shiny::renderUI({
            tr("btn_import_template", lang_r())
        })

        # "Import mapping template" modal — ADR-087 + PR-A3.
        # Opens a modal with a fileInput for the .txt mapping_guide produced
        # by the export bundle. On confirm, parses it and (1) faithfully
        # rebuilds the mapping in the cards — concatenations and typed
        # constants — by matching the guide's source columns to the loaded
        # dataset, and (2) seeds rostrum_aliases for cross-dataset auto-mapping.
        shiny::observeEvent(input$import_template, {
            shiny::showModal(shiny::modalDialog(
                title = tr("modal_import_template_title", lang_r()),
                shiny::p(
                    class = "mb-3",
                    tr("modal_import_template_help", lang_r())
                ),
                shiny::fileInput(
                    inputId = ns("import_template_file"),
                    label = tr("modal_import_template_label", lang_r()),
                    accept = c(".txt", "text/plain"),
                    buttonLabel = shiny::icon("upload", class = "fa-solid"),
                    placeholder = ""
                ),
                footer = shiny::tagList(
                    shiny::modalButton(tr("btn_cancel", lang_r())),
                    shiny::actionButton(
                        ns("confirm_import_template"),
                        tr("modal_import_template_confirm", lang_r()),
                        class = "btn-primary"
                    )
                ),
                easyClose = TRUE
            ))
        })

        shiny::observeEvent(input$confirm_import_template, {
            f <- input$import_template_file
            if (is.null(f) || !nzchar(f$datapath)) {
                shiny::showNotification(
                    tr("modal_import_template_no_file", lang_r()),
                    type = "warning",
                    duration = 5
                )
                return(invisible(NULL))
            }

            if (!is_saira_mapping_guide(f$datapath)) {
                shiny::showNotification(
                    tr("modal_import_template_invalid_magic", lang_r()),
                    type = "error",
                    duration = 8
                )
                return(invisible(NULL))
            }

            payload <- tryCatch(
                parse_mapping_guide_txt(f$datapath),
                error = function(e) e
            )
            if (inherits(payload, "error")) {
                shiny::showNotification(
                    sprintf(tr("upload_guide_invalid", lang_r()), conditionMessage(payload)),
                    type = "error",
                    duration = 8
                )
                return(invisible(NULL))
            }

            # Faithful restore: rebuild the exact mapping in the cards by
            # matching the guide's source columns to the loaded dataset.
            available_columns <- tryCatch(names(raw_data_r()), error = function(e) character(0))
            plan <- plan_mapping_guide_restore(payload, available_columns)

            # Register any catalog terms the guide maps that are outside the
            # default set, so their cards render (mirrors the Add-term flow).
            # Without this the value is restored into rv$map_values but no card
            # is ever shown for it.
            restore_extras <- detect_extra_dwc_terms(names(plan$map_values))
            if (length(restore_extras) > 0L) {
                rv$extra_terms <- unique(c(rv$extra_terms, restore_extras))
            }

            rv$is_programmatic_update <- TRUE
            on.exit({
                rv$is_programmatic_update <- FALSE
                rv$programmatic_terms <- character(0)
            }, add = TRUE)

            for (term in names(plan$map_values)) {
                set_map_value(term, plan$map_values[[term]], update_input = TRUE)
                rv$map_meta[[term]] <- build_manual_meta(previous_meta = NULL, has_value = TRUE)
            }

            consts <- plan$constants
            if (!is.null(consts$datasetName)) {
                shiny::updateTextInput(session, "custom_datasetName", value = consts$datasetName)
                rv$map_meta[["datasetName"]] <- build_manual_meta(previous_meta = NULL, has_value = TRUE)
            }
            if (!is.null(consts$license)) {
                shiny::updateCheckboxGroupInput(session, "custom_license", selected = consts$license)
            }
            if (!is.null(consts$language)) {
                shiny::updateCheckboxGroupInput(session, "custom_language", selected = consts$language)
            }

            # Seed personal aliases for cross-dataset auto-mapping (ADR-087);
            # non-fatal if it fails (the faithful restore already happened).
            tryCatch(import_mapping_guide_to_aliases(payload), error = function(e) NULL)

            shiny::removeModal()
            n_terms <- length(plan$applied_terms)
            msg <- sprintf(tr("modal_import_template_restored", lang_r()), n_terms)
            if (length(plan$missing_columns) > 0L) {
                msg <- paste0(msg, " ", sprintf(
                    tr("modal_import_template_missing_cols", lang_r()),
                    length(plan$missing_columns),
                    paste(utils::head(plan$missing_columns, 5L), collapse = ", ")
                ))
            }
            shiny::showNotification(msg, type = "message", duration = 10)
        }, ignoreInit = TRUE)

        # "Add term" modal
        shiny::observeEvent(input$add_term, {
            full_catalog <- get_dwc_full_catalog()
            active       <- all_term_names()
            available    <- full_catalog[!full_catalog$term %in% active, , drop = FALSE]

            # Group choices by DwC class for selectize <optgroup> rendering.
            # Shiny converts a named list of named character vectors into
            # <optgroup label="..."> blocks natively (>= 1.7).
            class_order <- c(
                "Record-level", "Occurrence", "Organism", "MaterialEntity",
                "MaterialSample", "Event", "Location", "GeologicalContext",
                "Identification", "Taxon", "MeasurementOrFact",
                "ResourceRelationship"
            )
            classes_present <- unique(available$class)
            classes_ordered <- c(
                intersect(class_order, classes_present),
                setdiff(classes_present, class_order)
            )

            choices <- lapply(classes_ordered, function(cls) {
                rows <- available[available$class == cls, , drop = FALSE]
                rows <- rows[order(rows$term), , drop = FALSE]
                stats::setNames(rows$term, rows$term)
            })
            names(choices) <- vapply(
                classes_ordered, category_label,
                FUN.VALUE = character(1), USE.NAMES = FALSE
            )

            shiny::showModal(shiny::modalDialog(
                title  = tr("modal_add_term_title", lang_r()),
                size   = "l",
                shiny::selectizeInput(
                    ns("add_term_select"),
                    tr("modal_add_term_label", lang_r()),
                    choices  = choices,
                    selected = NULL,
                    multiple = FALSE,
                    options  = list(
                        placeholder = tr("modal_add_term_placeholder", lang_r()),
                        allowEmptyOption = FALSE
                    )
                ),
                footer = shiny::tagList(
                    shiny::modalButton(tr("btn_cancel", lang_r())),
                    shiny::actionButton(
                        ns("confirm_add_term"),
                        tr("btn_confirm_add_term", lang_r()),
                        class = "btn-primary"
                    )
                ),
                easyClose = TRUE
            ))
        })

        shiny::observeEvent(input$confirm_add_term, {
            new_term <- input$add_term_select
            if (is.null(new_term) || !nzchar(new_term)) return()
            if (new_term %in% all_term_names()) return()

            rv$extra_terms <- c(rv$extra_terms, new_term)
            shiny::removeModal()
            # Scroll to the freshly added card once the grid re-renders. The
            # card may not be in the DOM yet, so the handler retries across
            # animation frames (reuses the class-scroll handler, which targets
            # any element id -- here the term's fieldcard_<term> anchor).
            session$sendCustomMessage(
                "saira-mapping-scroll-to-class",
                list(anchor_id = ns(paste0("fieldcard_", new_term)))
            )
            shiny::showNotification(
                paste(tr("notif_term_added", lang_r()), new_term),
                type     = "message",
                duration = 3
            )
        })

        # Flag when one source column feeds two or more DwC terms (allowed, but
        # usually a mistake -- e.g. a camtrap `type` column left on both
        # basisOfRecord and type). Amber, non-blocking; just reads rv$map_values
        # (no inputs recreated here, so no re-render loop).
        output$duplicate_source_warning <- shiny::renderUI({
            dups <- detect_duplicate_source_mappings(
                rv$map_values,
                exclude = c("occurrenceID", "datasetName", "modified",
                            "license", "language")
            )
            if (length(dups) == 0L) {
                return(NULL)
            }
            lang <- lang_r()
            rows <- lapply(names(dups), function(col) {
                shiny::tags$li(
                    shiny::tags$strong(col), " \u2192 ",
                    paste(dups[[col]], collapse = ", ")
                )
            })
            shiny::div(
                class = "alert alert-warning mapping-dup-warning",
                shiny::div(
                    shiny::icon("triangle-exclamation"), " ",
                    tr("mapping_dup_source_warning", lang)
                ),
                shiny::tags$ul(class = "mapping-dup-list", rows)
            )
        })

        # Mapping UI generation (card builder delegated to mod_mapping_cards.R).
        # All category sections always render so scroll-anchors are always in DOM.
        output$mapping_ui <- shiny::renderUI({
            shiny::req(raw_data_r())

            # The grid (50 selectize inputs) is expensive to rebuild, so it is
            # rendered only on a real structural change: a new upload, a language
            # switch, the show-only-mapped toggle, a change to the active term set
            # (Add-term modal, template import, reset), or when scientificName's
            # mapped-state flips (which locks/unlocks taxonRank/specificEpithet).
            # These are the only reactive dependencies. Everything else --
            # per-term map_values, fixed-value inputs, meta -- is read inside the
            # isolate() below, so selecting a column updates just that card via
            # its carddyn_<term> output and push_card_state(), never the grid.
            lang <- lang_r()
            show_only_mapped <- isTRUE(input$show_only_mapped)
            scientificname_mapped <- isTRUE(rv$scientificname_mapped)
            # Structural dependency: adding/removing terms must rebuild the grid
            # so the new card actually appears. dwc_all() carries rv$extra_terms
            # but is read inside isolate() below, so depend on the term set
            # explicitly here (read outside the isolate). Without this, terms
            # added via the "Add term" modal/template import never render.
            rv$extra_terms

            shiny::isolate({
                cols <- c("-- " = "", names(raw_data_r()))
                fields_to_show <- dwc_all()

                all_categories <- vapply(fields_to_show, function(x) x$category, FUN.VALUE = character(1))
                categories <- unique(all_categories)

                # When the upload already carries occurrenceID values (e.g. a
                # camera-trap observationID), resolve_occurrence_ids() preserves
                # them -- only blank rows get a fresh UUID. The card message
                # reflects that instead of claiming every id is auto-generated.
                occ_id_col <- raw_data_r()[["occurrenceID"]]
                occurrence_id_preserved <- !is.null(occ_id_col) &&
                    any(!is.na(occ_id_col) & nzchar(trimws(as.character(occ_id_col))))

                shiny::tagList(
                    lapply(categories, function(cat) {
                        cat_fields <- Filter(function(x) x$category == cat, fields_to_show)
                        cat_class <- paste0("cat-", tolower(gsub("-", "", cat)))

                        shiny::tagList(
                            shiny::div(
                                id = ns(paste0("cat_anchor_", slug(cat))),
                                class = "category-header",
                                category_label(cat)
                            ),
                            shiny::div(
                                class = "mapping-card-grid",
                                lapply(cat_fields, function(item) {
                                    term <- item$term
                                    current_val <- rv$map_values[[term]]
                                    if (is.null(current_val)) {
                                        current_val <- input[[paste0("map_", term)]]
                                    }
                                    current_val <- sanitize_map_selection(term, current_val)
                                    is_mapped <- is_field_mapped(term, current_val, input)
                                    # taxonRank/specificEpithet lock (and read as
                                    # mapped) once scientificName is set; they are
                                    # derived from it at export.
                                    locked_taxon <- isTRUE(scientificname_mapped) &&
                                        term %in% c("taxonRank", "specificEpithet")
                                    if (locked_taxon) {
                                        is_mapped <- TRUE
                                    }
                                    field_meta <- rv$map_meta[[term]]
                                    if (is.null(field_meta)) {
                                        field_meta <- default_meta()
                                    }
                                    card_state <- apply_establishment_card_state(
                                        term, current_val, is_mapped, field_meta
                                    )
                                    is_mapped <- card_state$is_mapped
                                    field_meta <- card_state$meta
                                    badge_info <- build_badge_info(field_meta)

                                    # Apply "show only mapped" filter
                                    if (show_only_mapped && !is_mapped) {
                                        return(NULL)
                                    }

                                    build_field_card(
                                        item = item, cols = cols,
                                        current_val = current_val,
                                        is_mapped = is_mapped,
                                        badge_info = badge_info,
                                        ns = ns, lang_r = lang,
                                        input = input, cat_class = cat_class,
                                        scientificname_mapped = scientificname_mapped,
                                        occurrence_id_preserved = occurrence_id_preserved,
                                        state_class = field_state_class(
                                            term, is_mapped, field_meta,
                                            required_fields_strip
                                        )
                                    )
                                })
                            )
                        )
                    })
                )
            })
        })

        # Per-term dynamic card content (source sample, basisOfRecord assistant
        # button, dynamicProperties key inputs) rendered into the carddyn_<term>
        # slots. Each output depends only on its own term's selection, so picking
        # a column updates just that card instead of rebuilding the grid. Created
        # once per term (extra terms included as they appear); the five special
        # terms without selection-dependent content have no slot.
        carddyn_no_slot <- c(
            "occurrenceID", "datasetName", "modified", "license", "language"
        )
        carddyn_created <- new.env(parent = emptyenv())
        make_carddyn_output <- function(term) {
            force(term)
            output[[paste0("carddyn_", term)]] <- shiny::renderUI({
                lang <- lang_r()
                # Same fallback the grid uses (see the card loop above): the
                # sync observer fills rv$map_values one flush after the client
                # echoes a selection, so reading rv alone leaves a freshly
                # mapped card with no sample line.
                current_val <- rv$map_values[[term]]
                if (is.null(current_val)) {
                    current_val <- input[[paste0("map_", term)]]
                }
                current_val <- sanitize_map_selection(term, current_val)
                if (identical(term, "basisOfRecord")) {
                    build_basis_assistant_button(current_val, ns, lang)
                } else if (term %in% establishment_terms) {
                    # One modal fills both terms, so the button lives on the
                    # lead term only -- rendering it on both cards would put two
                    # inputs with the same id on the page. The degree card gets
                    # a pointer instead.
                    field <- if (identical(term, "establishmentMeans")) "means" else "degree"
                    answered <- establishment_answer_count(rv$establishment_map, field)
                    pending <- if (identical(field, "degree")) {
                        length(establishment_pairs_missing_degree(rv$establishment_map))
                    } else {
                        0L
                    }
                    sample_vals <- processed_preview_for_term(term, current_val, 1L)
                    shiny::tagList(
                        if (identical(term, "establishmentMeans")) {
                            build_establishment_assistant_button(ns, lang)
                        } else {
                            build_establishment_degree_hint(ns, lang)
                        },
                        build_establishment_status_note(answered, pending, lang),
                        # Only when there is a value to show. The generic empty
                        # hint says "column mapped, no values", which would be
                        # false here: these terms can be filled with no column.
                        if (length(sample_vals) > 0) {
                            build_field_sample(sample_vals, lang)
                        }
                    )
                } else if (identical(term, "dynamicProperties")) {
                    # Keys block plus the assembled JSON, so the user can see
                    # the {"key":"value"} the export will emit while editing.
                    shiny::tagList(
                        build_dynprops_keys_block(current_val, ns, lang, input),
                        if (has_selected_value(current_val)) {
                            build_field_sample(
                                processed_preview_for_term(term, current_val, 1L), lang
                            )
                        }
                    )
                } else if (has_selected_value(current_val)) {
                    build_field_sample(
                        processed_preview_for_term(term, current_val, 1L), lang
                    )
                } else {
                    NULL
                }
            })
        }
        shiny::observe({
            for (term in all_term_names()) {
                if (term %in% carddyn_no_slot) next
                if (isTRUE(carddyn_created[[term]])) next
                make_carddyn_output(term)
                carddyn_created[[term]] <- TRUE
            }
        })


        # Camtrap DP columns are already canonical Darwin Core terms
        # (camtrapdp::write_dwc() emits them by name), so the mapping is a
        # deterministic identity: column X -> term X. We map them directly as
        # AUTO instead of running the fuzzy Rostrum engine, which would both
        # downgrade these exact matches to "suggested" (the extra-term rule
        # below) and invent spurious cross-matches (e.g. the decimalLatitude
        # column suggested for the verbatimLongitude term). Blank columns were
        # already dropped at conversion, so nothing empty maps here.
        perform_camtrap_automap <- function() {
            shiny::req(raw_data_r())
            cols <- names(raw_data_r())
            term_names <- all_term_names()
            # Same fields the engine path skips: their value comes from a custom
            # input (UUID/date/checkbox), not a source-column dropdown.
            special_fields <- c("occurrenceID", "modified", "license", "language")

            rv$is_programmatic_update <- TRUE
            on.exit(
                {
                    rv$is_programmatic_update <- FALSE
                    rv$programmatic_terms <- character(0)
                },
                add = TRUE
            )

            next_meta <- empty_map_meta(term_names)
            mapped_n <- 0L
            for (term in term_names) {
                if (term %in% special_fields || !(term %in% cols)) {
                    next
                }
                next_meta[[term]] <- list(
                    status = "AUTO",
                    score = 1,
                    reason = "exact_match",
                    source = "auto",
                    alternatives_json = "[]"
                )
                set_map_value(term, term, update_input = TRUE)
                mapped_n <- mapped_n + 1L
            }
            rv$map_meta <- next_meta
            rv$rostrum_decisions <- NULL
            rv$ambiguity_queue <- list()

            shiny::showNotification(
                sprintf(tr("notif_auto_mapping_v1", lang_r()), mapped_n, 0L),
                type = "message",
                duration = 6
            )
        }

        # Auto-mapping logic, shared by the "Auto-map" button and the automatic
        # run on camtrap-origin uploads. Camtrap uploads take the deterministic
        # identity path above; everything else runs the fuzzy Rostrum engine.
        perform_auto_map <- function() {
            shiny::req(raw_data_r())
            if (!is.null(attr(raw_data_r(), "saira_camtrap_source"))) {
                perform_camtrap_automap()
                return(invisible(NULL))
            }
            term_names <- all_term_names()
            special_fields <- c("occurrenceID", "modified", "license", "language")
            show_automap_loading_modal(rv, ns, lang_r)
            on.exit(hide_automap_loading_modal(), add = TRUE)

            auto_count <- 0L
            suggested_count <- 0L

            tryCatch(
                {
                    dwc_terms_df <- get_active_dwc_terms(extra = rv$extra_terms)
                    engine_result <- run_rostrum_engine(
                        df = raw_data_r(),
                        dwc_terms_df = dwc_terms_df,
                        options = rostrum_options(),
                        context = list(),
                        conn = conn
                    )

                    if (!isTRUE(engine_result$success)) {
                        err_msg <- if (length(engine_result$errors) > 0L) {
                            engine_result$errors[[1L]]
                        } else {
                            "unknown engine error"
                        }
                        shiny::showNotification(
                            sprintf(tr("notif_auto_mapping_v1_error", lang_r()), err_msg),
                            type = "error",
                            duration = 7
                        )
                        return(NULL)
                    }

                    auto_results <- engine_result$data
                    rv$rostrum_decisions <- engine_result$data
                    rv$rostrum_run_stats <- engine_result$run_stats

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
                    ambiguity_queue <- list()

                    for (i in seq_len(nrow(auto_results))) {
                        term <- as.character(auto_results$term[[i]])
                        status <- as.character(auto_results$status[[i]])
                        reason <- as.character(auto_results$reason[[i]])
                        score_value <- suppressWarnings(as.numeric(auto_results$final_score[[i]]))
                        selected_col <- as.character(auto_results$selected_col[[i]])
                        is_applied <- isTRUE(auto_results$applied[[i]])
                        alternatives_json <- if ("alternatives_json" %in% names(auto_results)) {
                            as.character(auto_results$alternatives_json[[i]])
                        } else {
                            "[]"
                        }

                        # Extra terms can't earn AUTO — engine wasn't calibrated on them
                        effective_status <- if (
                            identical(status, "AUTO") && term %in% rv$extra_terms
                        ) "SUGERIDO" else status

                        next_meta[[term]] <- list(
                            status = effective_status,
                            score = score_value,
                            reason = reason,
                            source = if (identical(effective_status, "TEMPLATE")) "template" else if (identical(effective_status, "ALIAS")) "alias" else "auto",
                            alternatives_json = alternatives_json
                        )

                        if (identical(status, "AMBIGUO")) {
                            candidates <- parse_ambiguity_candidates(alternatives_json)
                            if (length(candidates) > 0) {
                                ambiguity_queue[[length(ambiguity_queue) + 1L]] <- list(
                                    term = term,
                                    candidates = candidates
                                )
                            }
                        }

                        if (!(term %in% special_fields) && is_applied && !is.na(selected_col) && nzchar(selected_col)) {
                            set_map_value(term, selected_col, update_input = TRUE)
                            if (identical(effective_status, "AUTO")) {
                                auto_count <- auto_count + 1L
                            } else if (identical(effective_status, "SUGERIDO")) {
                                suggested_count <- suggested_count + 1L
                            }
                        }

                        update_automap_loading(rv, i, total_rows)
                    }

                    if (nrow(auto_results) == 0) {
                        update_automap_loading(rv, 1L, 1L)
                    }

                    rv$map_meta <- next_meta
                    rv$ambiguity_queue <- ambiguity_queue

                    if (!isTRUE(engine_result$stage2$success)) {
                        shiny::showNotification(
                            tr("rostrum_warning_stage2_fallback", lang_r()),
                            type = "warning",
                            duration = 6
                        )
                    }
                    if (!isTRUE(engine_result$stage3$success)) {
                        shiny::showNotification(
                            tr("rostrum_warning_stage3_fallback", lang_r()),
                            type = "warning",
                            duration = 6
                        )
                    }

                    shiny::showNotification(
                        sprintf(tr("notif_auto_mapping_v1", lang_r()), auto_count, suggested_count),
                        type = "message",
                        duration = 6
                    )

                    if (length(rv$ambiguity_queue) > 0) {
                        show_next_ambiguity_modal()
                    }
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
        }

        shiny::observeEvent(input$auto_map, {
            perform_auto_map()
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
            rv$extra_terms <- character(0)
            rv$map_meta <- empty_map_meta(all_term_names())
            rv$ambiguity_queue <- list()
            rv$rostrum_decisions <- NULL
            rv$rostrum_run_stats <- list()
            # Reset custom inputs
            shiny::updateTextInput(session, "custom_datasetName", value = "")
            shiny::updateCheckboxInput(session, "modified_use_today", value = FALSE)
            shiny::updateDateInput(session, "custom_modified_date", value = Sys.Date())
            shiny::updateCheckboxGroupInput(session, "custom_license", selected = character(0))
            shiny::updateCheckboxGroupInput(session, "custom_language", selected = character(0))
            reset_basis_of_record_state(rv)
            reset_establishment_state()
            rv$is_programmatic_update <- FALSE
            rv$programmatic_terms <- character(0)
            # Clear the downstream tabs too (the existing notification covers it).
            rv$downstream_reset <- rv$downstream_reset + 1L
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
                push_card_state("license")
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
                push_card_state("language")
            },
            ignoreInit = TRUE
        )

        # Track fixed-value edits for the constant-value allowlist (mirrors the
        # datasetName meta observer). Marks the term EDITADO so its badge and
        # mapped border update; ignoreInit avoids firing on card creation.
        lapply(constant_value_terms(), function(term) {
            use_id <- paste0("usecustom_", term)
            val_id <- paste0("custom_", term)
            has_fixed_value <- function() {
                isTRUE(input[[use_id]]) &&
                    !is.null(input[[val_id]]) &&
                    nzchar(trimws(input[[val_id]]))
            }
            # The free-text read is isolated in the renderUI (ADR-098), so typing
            # a fixed value does not re-render the card. push_card_state() flips
            # the card's border/badge client-side to match the next full render --
            # no re-render, no blur.
            shiny::observeEvent(input[[val_id]], {
                set_custom_term_meta(term, has_fixed_value())
                push_card_state(term)
            }, ignoreInit = TRUE)
            shiny::observeEvent(input[[use_id]], {
                set_custom_term_meta(term, has_fixed_value())
                push_card_state(term)
            }, ignoreInit = TRUE)
        })

        # Collect enabled fixed values (usecustom_<term> on + non-empty) for the
        # constant-value allowlist. Reused by build_mapped_result (export/preview)
        # and custom_values_r (mapping-guide serialization).
        collect_constant_values <- function() {
            vals <- list()
            for (term in constant_value_terms()) {
                if (!isTRUE(input[[paste0("usecustom_", term)]])) next
                value <- input[[paste0("custom_", term)]]
                if (!is.null(value) && nzchar(trimws(value))) {
                    vals[[term]] <- trimws(value)
                }
            }
            vals
        }

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
                constant_values = collect_constant_values(),
                basis_of_record_map = rv$basis_of_record_map,
                now_utc = Sys.time(),
                out_sep = " | ",
                dyn_props_keys = rv$dyn_props_keys,
                establishment_map = rv$establishment_map
            )
        }

        # Full mapped data (used by export and validation modules)
        processed_data <- shiny::reactive({
            shiny::req(raw_data_r())

            df <- raw_data_r()
            if (is.null(rv$occurrence_ids) || length(rv$occurrence_ids) != nrow(df)) {
                rv$occurrence_ids <- resolve_occurrence_ids(df)
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

        # Gates must survive upstream `req()` (e.g., upload without file) and
        # report a stable "no_data" state instead of aborting UI render.
        safe_raw_data_for_gate <- function() {
            tryCatch(
                raw_data_r(),
                error = function(e) {
                    if (inherits(e, "shiny.silent.error")) {
                        return(NULL)
                    }
                    stop(e)
                }
            )
        }

        # Lightweight gate for validation modules: avoid materializing processed_data
        # just to know if scientificName mapping is ready.
        validation_gate_r <- shiny::reactive({
            raw_df <- safe_raw_data_for_gate()
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
            raw_df <- safe_raw_data_for_gate()
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

        # Lightweight projection (scientificName + coords) for the Preview
        # masking overview. Avoids materialising processed_data just to count
        # how many sensitive records exist — keeps the Preview tab off the
        # heavy `build_mapped_result` pipeline (ADR-020, LESSONS.md:31).
        sensitive_overview_input_r <- shiny::reactive({
            raw <- safe_raw_data_for_gate()
            if (is.null(raw) || !is.data.frame(raw) || nrow(raw) == 0L) {
                return(NULL)
            }
            pick <- function(term) {
                sel <- sanitize_map_selection(term, rv$map_values[[term]])
                if (!has_selected_value(sel)) return(NULL)
                col <- as.character(sel[[1]])
                if (!col %in% names(raw)) return(NULL)
                raw[[col]]
            }
            sci <- pick("scientificName")
            if (is.null(sci)) return(NULL)
            lat <- pick("decimalLatitude")
            lon <- pick("decimalLongitude")
            data.frame(
                scientificName   = as.character(sci),
                decimalLatitude  = if (is.null(lat)) NA_character_ else as.character(lat),
                decimalLongitude = if (is.null(lon)) NA_character_ else as.character(lon),
                stringsAsFactors = FALSE
            )
        })

        # Lightweight mapped preview (first 100 raw rows only)
        preview_processed_data <- shiny::reactive({
            shiny::req(raw_data_r())

            preview_raw <- utils::head(raw_data_r(), 100L)
            # Show real identifiers in the preview when the upload ships them
            # (e.g. camera-trap occurrenceID); otherwise keep lightweight
            # placeholders for the sampled rows.
            preview_occurrence_ids <- if (nrow(preview_raw) == 0L) {
                character(0)
            } else if ("occurrenceID" %in% names(preview_raw)) {
                resolve_occurrence_ids(preview_raw)
            } else {
                sprintf("preview-%06d", seq_len(nrow(preview_raw)))
            }

            preview_result <- build_mapped_result(
                df_input = preview_raw,
                occurrence_ids_input = preview_occurrence_ids
            )

            preview_result$data
        })

        # Return named list of reactives (ADR-054: replaces attr()-based contract)
        # Slots kept for 1-release transition: processed_data_r, preview_data_r,
        #   validation_gate_r, validation_gate_coords_r.
        # Typed/selected constant values (datasetName, license, language plus the
        # constant_value_terms() allowlist) applied to every row. Exposed so the
        # export can serialize them in the mapping guide and restore on re-import.
        custom_values_r <- shiny::reactive({
            vals <- list()
            dn <- input$custom_datasetName
            if (!is.null(dn) && nzchar(trimws(dn))) vals$datasetName <- trimws(dn)
            lic <- input$custom_license
            if (!is.null(lic) && length(lic) > 0 && nzchar(lic[[1]])) {
                vals$license <- as.character(lic[[1]])
            }
            lng <- input$custom_language
            if (!is.null(lng) && length(lng) > 0 && nzchar(lng[[1]])) {
                vals$language <- as.character(lng[[1]])
            }
            c(vals, collect_constant_values())
        })

        # New Rostrum slots (Onda 2): rostrum_decisions_r, rostrum_explain_r,
        #   rostrum_run_stats_r.
        return(list(
            processed_data_r            = processed_data,
            preview_data_r              = preview_processed_data,
            validation_gate_r           = validation_gate_r,
            validation_gate_coords_r    = coord_validation_gate_r,
            sensitive_overview_input_r  = sensitive_overview_input_r,
            rostrum_decisions_r         = shiny::reactive(rv$rostrum_decisions),
            rostrum_explain_r           = shiny::reactive(rv$map_meta),
            rostrum_run_stats_r         = shiny::reactive(rv$rostrum_run_stats),
            map_values_r                = shiny::reactive(rv$map_values),
            custom_values_r             = custom_values_r,
            reset_signal_r              = shiny::reactive(rv$downstream_reset)
        ))
    })
}
