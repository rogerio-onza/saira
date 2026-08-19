# Title: Export Module (review-before-publish summary + download)
# Author: Rogerio Nunes Oliveira

#' Export Module UI
#'
#' Dedicated "review then publish" stage. A prominent download control sits
#' top-right; below it a consolidated summary of what the validation /
#' generalization stages produced — export readiness (health score), applied
#' corrections, generalized species (threat category + tier) and the files the
#' DwC-A bundle will contain — so the user can sanity-check before downloading.
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_export_ui <- function(id) {
    ns <- shiny::NS(id)
    shiny::tagList(
        # One-time handler: when the blocked banner's "fix" CTA navigates to
        # Mapping, scroll the targeted field card into view and flash it.
        shiny::tags$script(shiny::HTML(paste(
            "(function(){",
            "if (window.__sairaFocusFieldHandler || !window.Shiny) { return; }",
            "window.__sairaFocusFieldHandler = true;",
            "Shiny.addCustomMessageHandler('saira_focus_field', function(msg){",
            "  if (!msg || !msg.id) { return; }",
            "  setTimeout(function(){",
            "    var el = document.getElementById(msg.id);",
            "    if (!el) { return; }",
            "    el.scrollIntoView({behavior: 'smooth', block: 'center'});",
            "    el.classList.add('field-card-flash');",
            "    setTimeout(function(){ el.classList.remove('field-card-flash'); }, 2200);",
            "  }, 300);",
            "});",
            "})();",
            sep = "\n"
        ))),
        shiny::div(
            class = "container-fluid export-page",
            shiny::div(
                class = "export-header",
                shiny::div(
                    class = "export-header-top",
                    shiny::uiOutput(ns("title")),
                    shiny::div(
                        class = "export-header-actions",
                        shiny::uiOutput(ns("download_btn_container"))
                    )
                ),
                shiny::uiOutput(ns("subtitle"))
            ),
            shiny::uiOutput(ns("summary"))
        )
    )
}

#' Export Module Server
#'
#' @param id Module ID
#' @param mapped_data_r Reactive processed Darwin Core data frame.
#' @param lang_r Reactive language value.
#' @param download_data_r Reactive data frame with the full mapped data for
#'   download (defaults to `mapped_data_r`).
#' @param name_review_payload_r,coords_correction_payload_r,country_fill_payload_r
#'   Optional reactives with the validation correction payloads.
#' @param sensitivity_payload_r Optional reactive with per-species sensitivity marks.
#' @param sensitive_generalization_payload_r Optional reactive with the
#'   generalization decision (`levels`, `enabled`, ...).
#' @param conservation_payload_r Optional reactive with the conservation-status
#'   selection (`include_mma`, `include_iucn`, `taxon_keys`).
#' @param raw_data_r Optional reactive with the original uploaded data.frame.
#' @param map_values_r Optional reactive with the current mapping list.
#' @param custom_values_r Optional reactive with typed constants (`datasetName`,
#'   `license`, `language`); the dataset name names the auxiliary bundle files.
#' @param on_navigate Optional callback `function(tab)` to switch the top-level
#'   navbar (used by the "fix missing terms" banner action).
#' @return invisible NULL.
#' @export
mod_export_server <- function(id, mapped_data_r, lang_r,
                              download_data_r = mapped_data_r,
                              name_review_payload_r = NULL,
                              coords_correction_payload_r = NULL,
                              country_fill_payload_r = NULL,
                              sensitivity_payload_r = NULL,
                              sensitive_generalization_payload_r = NULL,
                              conservation_payload_r = NULL,
                              raw_data_r = NULL,
                              map_values_r = NULL,
                              custom_values_r = NULL,
                              occurrence_id_info_r = NULL,
                              on_navigate = NULL,
                              on_export_success = NULL) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        call_r <- function(r) {
            if (!is.null(r) && shiny::is.reactive(r)) {
                tryCatch(r(), error = function(e) NULL)
            } else {
                NULL
            }
        }

        dataset_name_r <- shiny::reactive({
            cv <- call_r(custom_values_r)
            if (is.list(cv)) cv$datasetName else NULL
        })

        summary_r <- shiny::reactive({
            build_export_summary(
                mapped_data = call_r(mapped_data_r),
                name_review_payload = call_r(name_review_payload_r),
                coords_correction_payload = call_r(coords_correction_payload_r),
                country_fill_payload = call_r(country_fill_payload_r),
                sensitivity_payload = call_r(sensitivity_payload_r),
                generalization_payload = call_r(sensitive_generalization_payload_r),
                dataset_name = dataset_name_r()
            )
        })

        # Readiness shared by the banner and the download button so they never
        # contradict each other (green button next to a red "blocked" banner).
        blocked_r <- shiny::reactive({
            s <- summary_r()
            isTRUE(s$export_blocked)
        })

        # The download flow (validation -> confirmation -> animated modal ->
        # DwC-A bundle) is mounted from the relocated subsystem (ADR-103); it
        # renders output$download_btn_container into the header above.
        mount_export_download(
            input, output, session, lang_r,
            mapped_data_r = mapped_data_r,
            download_data_r = download_data_r,
            name_review_payload_r = name_review_payload_r,
            sensitivity_payload_r = sensitivity_payload_r,
            sensitive_generalization_payload_r = sensitive_generalization_payload_r,
            conservation_payload_r = conservation_payload_r,
            raw_data_r = raw_data_r,
            map_values_r = map_values_r,
            custom_values_r = custom_values_r,
            occurrence_id_info_r = occurrence_id_info_r,
            coords_correction_payload_r = coords_correction_payload_r,
            country_fill_payload_r = country_fill_payload_r,
            blocked_r = blocked_r,
            on_export_success = on_export_success
        )

        # Banner CTA: jump to the tab where the blocker is fixed. For a missing
        # required term, go to Mapping and focus the first missing term's card;
        # for a pending justification, go to Generalization.
        shiny::observeEvent(input$go_fix_terms, {
            if (is.null(on_navigate) || !is.function(on_navigate)) {
                return(invisible(NULL))
            }
            s <- summary_r()
            if (length(s$missing_required) > 0L) {
                on_navigate("mapping", term = s$missing_required[1L])
            } else {
                on_navigate("sensitive_coords")
            }
        }, ignoreInit = TRUE)

        output$title <- shiny::renderUI({
            shiny::h3(class = "export-title", tr("export_title", lang_r()))
        })
        output$subtitle <- shiny::renderUI({
            shiny::p(class = "export-subtitle", tr("export_subtitle", lang_r()))
        })

        tier_label <- function(tier, lang) tr(paste0("export_tier_", tier), lang)

        # MMA/IUCN threat category -> shared pill class (same colours as the
        # Generalization and Names tabs: VU gold, EN orange, CR red, CR(PEX)
        # maroon, everything else neutral).
        cat_pill <- function(category) {
            code <- gsub("[^a-z0-9]", "", tolower(as.character(category)))
            if (!code %in% c("crpex", "cr", "en", "vu")) code <- "other"
            shiny::span(class = paste0("sp-cat-pill sp-cat-pill--", code), category)
        }

        info_tip <- function(text) {
            shiny::span(
                class = "export-info-tip",
                `data-bs-toggle` = "tooltip",
                title = text,
                shiny::icon("circle-info")
            )
        }

        metric <- function(value, label) {
            shiny::div(
                class = paste("export-metric", if (identical(value, 0L) || identical(value, 0)) "is-zero" else NULL),
                shiny::span(class = "export-metric-value", value),
                shiny::span(class = "export-metric-label", label)
            )
        }

        section_card <- function(icon, title, body) {
            bslib::card(
                class = "export-card",
                bslib::card_header(
                    shiny::div(
                        class = "export-card-title",
                        shiny::icon(icon, class = "me-2"), title
                    )
                ),
                bslib::card_body(body)
            )
        }

        file_group <- function(title, files) {
            shiny::tagList(
                shiny::div(class = "export-file-group-title", title),
                shiny::tags$ul(
                    class = "export-file-list",
                    lapply(files, function(f) shiny::tags$li(shiny::tags$code(f)))
                )
            )
        }

        output$summary <- shiny::renderUI({
            lang <- lang_r()
            s <- summary_r()

            if (is.null(s) || !is.list(s) || s$record_count == 0L) {
                return(shiny::div(
                    class = "alert alert-info export-empty",
                    shiny::icon("circle-info"), " ", tr("export_empty", lang)
                ))
            }

            # --- Severity banner -------------------------------------------
            banner <- if (isTRUE(s$export_blocked)) {
                reasons <- list()
                if (length(s$missing_required) > 0L) {
                    reasons[[length(reasons) + 1L]] <- shiny::tags$li(
                        tr("export_blocked_missing", lang), " ",
                        shiny::tags$code(paste(s$missing_required, collapse = ", "))
                    )
                }
                if (isTRUE(s$justification_pending)) {
                    reasons[[length(reasons) + 1L]] <- shiny::tags$li(
                        tr("export_blocked_justification", lang)
                    )
                }
                cta_label <- if (length(s$missing_required) > 0L) {
                    tr("export_fix_terms_cta", lang)
                } else {
                    tr("export_fix_justification_cta", lang)
                }
                shiny::div(
                    class = "export-banner export-banner--danger",
                    shiny::icon("triangle-exclamation"),
                    shiny::div(
                        class = "export-banner-body",
                        shiny::strong(tr("export_blocked_title", lang)),
                        shiny::tags$ul(class = "export-banner-list", reasons)
                    ),
                    shiny::actionButton(
                        ns("go_fix_terms"),
                        label = shiny::tagList(cta_label, " ", shiny::icon("arrow-right")),
                        class = "btn btn-success export-banner-action"
                    )
                )
            } else if (!isTRUE(s$occurrence_id_present)) {
                shiny::div(
                    class = "export-banner export-banner--warning",
                    shiny::icon("circle-info"),
                    shiny::div(
                        class = "export-banner-body",
                        shiny::strong(tr("export_warn_title", lang)),
                        shiny::p(class = "mb-0", tr("export_warn_occid", lang))
                    )
                )
            } else {
                shiny::div(
                    class = "export-banner export-banner--ok",
                    shiny::icon("circle-check"),
                    shiny::div(
                        class = "export-banner-body",
                        shiny::strong(tr("export_ready_title", lang))
                    )
                )
            }

            # Preserving unmapped columns in the CSV does not publish them:
            # meta.xml declares only recognized DwC terms, so GBIF drops the
            # rest. Say it here, where the user can still go map them.
            #
            # `exclude` is what keeps this honest, and must stay in step with
            # process_for_export_with_unmapped(): a raw column whose name is
            # already a column of the export is published under that name, not
            # dropped. An upload carrying `occurrenceID` is the everyday case --
            # it feeds the export whether or not the user picked it in the
            # dropdown, so warning that GBIF would ignore it was simply false.
            unmapped_cols <- unmapped_raw_columns(
                call_r(raw_data_r), call_r(map_values_r),
                exclude = names(call_r(mapped_data_r)),
                overridden_terms = overridden_mapping_terms(call_r(custom_values_r))
            )
            unmapped_notice <- if (length(unmapped_cols) > 0L) {
                shiny::div(
                    class = "export-banner export-banner--warning",
                    shiny::icon("circle-info"),
                    shiny::div(
                        class = "export-banner-body",
                        shiny::p(
                            class = "mb-0",
                            sprintf(
                                tr("export_unmapped_not_published", lang),
                                length(unmapped_cols)
                            )
                        ),
                        shiny::tags$code(paste(unmapped_cols, collapse = ", "))
                    )
                )
            }

            # --- Readiness: counts + per-term presence chips ----------------
            term_chips <- lapply(seq_len(nrow(s$readiness)), function(i) {
                term <- s$readiness$term[i]
                ok <- isTRUE(s$readiness$present[i])
                shiny::span(
                    class = paste("export-term-chip", if (ok) "is-present" else "is-missing"),
                    shiny::icon(if (ok) "circle-check" else "circle-xmark"),
                    " ", term
                )
            })
            readiness_card <- section_card(
                if (s$all_required_present) "circle-check" else "triangle-exclamation",
                tr("export_section_readiness", lang),
                shiny::tagList(
                    shiny::p(
                        class = "export-readiness-counts",
                        sprintf(tr("export_counts", lang), s$record_count, s$term_count)
                    ),
                    shiny::div(class = "export-terms", term_chips)
                )
            )

            # --- Corrections (dim metrics that are zero) --------------------
            cc <- s$corrections
            corrections_card <- section_card(
                "wand-magic-sparkles", tr("export_section_corrections", lang),
                shiny::div(
                    class = "export-metrics",
                    metric(cc$names_corrected, tr("export_names_corrected", lang)),
                    metric(cc$names_confirmed, tr("export_names_confirmed", lang)),
                    metric(cc$coord_fixes, tr("export_coord_fixes", lang)),
                    metric(cc$country_fills, tr("export_country_fills", lang))
                )
            )

            # --- Generalization (threat badges + rule tooltips) -------------
            gen <- s$generalization
            gen_body <- if (nrow(gen) == 0L) {
                shiny::p(class = "export-muted", tr("export_gen_none", lang))
            } else {
                rows <- lapply(seq_len(nrow(gen)), function(i) {
                    shiny::tags$tr(
                        shiny::tags$td(shiny::tags$em(gen$scientificName[i])),
                        shiny::tags$td(cat_pill(gen$category[i])),
                        shiny::tags$td(tier_label(gen$tier[i], lang))
                    )
                })
                shiny::tags$table(
                    class = "export-gen-table",
                    shiny::tags$thead(shiny::tags$tr(
                        shiny::tags$th(tr("export_gen_species", lang)),
                        shiny::tags$th(
                            tr("export_gen_category", lang), " ",
                            info_tip(tr("export_cat_tooltip", lang))
                        ),
                        shiny::tags$th(
                            tr("export_gen_tier", lang), " ",
                            info_tip(tr("export_gen_tooltip", lang))
                        )
                    )),
                    shiny::tags$tbody(rows)
                )
            }
            generalization_card <- section_card(
                "shield-halved", tr("export_section_generalization", lang), gen_body
            )

            # --- Files (DwC-A core trio vs renamed auxiliary siblings) ------
            files_card <- section_card(
                "file-zipper", tr("export_section_files", lang),
                shiny::tagList(
                    shiny::p(class = "export-muted", tr("export_files_hint", lang)),
                    file_group(tr("export_section_files_dwca", lang), s$files$dwca),
                    file_group(tr("export_section_files_aux", lang), unname(s$files$auxiliary))
                )
            )

            shiny::tagList(
                banner,
                unmapped_notice,
                shiny::div(
                    class = "export-summary",
                    readiness_card,
                    corrections_card,
                    generalization_card,
                    files_card
                ),
                shiny::tags$script(shiny::HTML(
                    "(function(){if(window.bootstrap&&bootstrap.Tooltip){document.querySelectorAll('.export-info-tip[data-bs-toggle=\"tooltip\"]').forEach(function(el){if(!el.__tipInit){el.__tipInit=true;new bootstrap.Tooltip(el);}});}})();"
                ))
            )
        })

        invisible(NULL)
    })
}
