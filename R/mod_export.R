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
            shiny::uiOutput(ns("summary")),
            # The download sits in a bar fixed to the bottom of the page, with
            # the bundle name and what still blocks it (ADR-132).
            shiny::div(
                class = "export-download-bar",
                shiny::uiOutput(ns("download_status"), class = "export-download-status"),
                shiny::uiOutput(ns("download_btn_container"))
            )
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
#' @param establishment_dropped_r Optional reactive, named by DwC term, with the
#'   `establishment_dropped_values()` frame for each mapped establishment term
#'   whose column carried values outside the controlled vocabulary.
#' @param occurrence_id_info_r Optional reactive with the identifier strategy and
#'   counts from `resolve_occurrence_ids()`.
#' @param on_navigate Optional callback `function(tab)` to switch the top-level
#'   navbar (used by the "fix missing terms" banner action).
#' @param on_export_success Optional callback fired after a successful export,
#'   used to signal the mapping module to learn its aliases (ADR-115).
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
                              establishment_dropped_r = NULL,
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
            } else if (isTRUE(s$bor_blank_count > 0L)) {
                on_navigate("mapping", term = "basisOfRecord")
            } else {
                on_navigate("sensitive_coords")
            }
        }, ignoreInit = TRUE)

        # One button per pending item, each opening the step that fixes it.
        navigate_on <- function(input_id, tab, term = NULL) {
            shiny::observeEvent(input[[input_id]], {
                if (is.function(on_navigate)) on_navigate(tab, term = term)
            }, ignoreInit = TRUE)
        }
        navigate_on("go_fix_justification", "sensitive_coords")
        navigate_on("go_preview", "preview")
        navigate_on("go_map_unmapped", "mapping")
        navigate_on("go_map_establishment", "mapping", term = "establishmentMeans")
        navigate_on("go_map_occid", "mapping", term = "occurrenceID")

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
                ph_icon("circle-info")
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
                    ph_icon("circle-info"), " ", tr("export_empty", lang)
                ))
            }

            # --- Numbers ------------------------------------------------------
            cc <- s$corrections
            gen <- s$generalization
            kpi <- function(value, label, sub) {
                shiny::div(
                    class = "export-kpi",
                    shiny::div(class = "export-kpi-value",
                               if (identical(lang, "pt")) {
                                   format(value, big.mark = ".", decimal.mark = ",")
                               } else {
                                   format(value, big.mark = ",", decimal.mark = ".")
                               }),
                    shiny::div(class = "export-kpi-label", label),
                    shiny::div(class = "export-kpi-sub", sub)
                )
            }
            n_aux <- length(s$files$auxiliary)
            kpis <- shiny::div(
                class = "export-kpis",
                kpi(s$record_count, tr("export_kpi_records", lang),
                    sprintf(tr("export_kpi_records_sub", lang), s$term_count)),
                kpi(cc$names_corrected + cc$names_confirmed + cc$coord_fixes + cc$country_fills,
                    tr("export_kpi_corrections", lang),
                    sprintf(tr("export_kpi_corrections_sub", lang),
                            cc$names_corrected + cc$names_confirmed, cc$coord_fixes, cc$country_fills)),
                kpi(nrow(gen), tr("export_kpi_generalized", lang),
                    if (nrow(gen) == 0L) tr("export_gen_none_short", lang) else tr("export_kpi_generalized_sub", lang)),
                kpi(length(s$files$dwca) + n_aux, tr("export_kpi_files", lang),
                    sprintf(tr("export_kpi_files_sub", lang), length(s$files$dwca), n_aux))
            )

            # --- Pending items: one row each, with the step that fixes it ------
            pending_row <- function(severity, body, action_id = NULL, action_label = NULL) {
                shiny::div(
                    class = paste0("export-pending-row is-", severity),
                    shiny::span(class = paste0("export-sev export-sev--", severity),
                                tr(paste0("export_sev_", severity), lang)),
                    shiny::div(class = "export-pending-body", body),
                    if (!is.null(action_id)) {
                        shiny::actionButton(ns(action_id), action_label,
                                            class = "btn btn-outline-secondary btn-sm export-pending-action")
                    }
                )
            }
            rows <- list()
            add <- function(x) rows[[length(rows) + 1L]] <<- x
            if (length(s$missing_required) > 0L) {
                add(pending_row("block", shiny::tagList(
                    tr("export_blocked_missing", lang), " ",
                    shiny::tags$code(paste(s$missing_required, collapse = ", "))
                ), "go_fix_terms", tr("export_fix_terms_cta", lang)))
            }
            if (isTRUE(s$bor_blank_count > 0L)) {
                add(pending_row("block", sprintf(tr("export_blocked_bor_blank", lang), s$bor_blank_count),
                                if (length(s$missing_required) == 0L) "go_fix_terms",
                                tr("export_action_mapping", lang)))
            }
            if (isTRUE(s$justification_pending)) {
                add(pending_row("block", tr("export_blocked_justification", lang),
                                "go_fix_justification", tr("export_fix_justification_cta", lang)))
            }
            # A well-formed date can still be wrong: "2098" passes every format
            # check and only a human knows it was meant to be "2008". The fix is
            # at the source, so the button only shows the rows.
            di <- s$date_issues
            if (is.list(di) && di$count > 0L) {
                add(pending_row("warn", shiny::tagList(
                    shiny::strong(tr("export_date_range_title", lang)), " ",
                    sprintf(tr("export_date_range_body", lang), di$count, di$min_year, di$max_year),
                    shiny::tags$code(paste(
                        sprintf(tr("export_date_range_row", lang),
                                di$sample$row, di$sample$column, di$sample$value),
                        collapse = ", "
                    ))
                ), "go_preview", tr("export_action_preview", lang)))
            }
            # A value outside the TDWG vocabulary leaves its row blank rather
            # than travelling to GBIF as free text.
            dropped <- call_r(establishment_dropped_r)
            if (is.list(dropped) && length(dropped) > 0L) {
                add(pending_row("warn", lapply(names(dropped), function(term) {
                    entries <- dropped[[term]]
                    shiny::tagList(
                        sprintf(tr("export_establishment_dropped", lang),
                                nrow(entries), term, sum(entries$n_records)), " ",
                        shiny::tags$code(paste(sprintf("%s (%d)", entries$raw, entries$n_records),
                                               collapse = ", "))
                    )
                }), "go_map_establishment", tr("export_action_mapping", lang)))
            }
            if (!isTRUE(s$occurrence_id_present)) {
                add(pending_row("warn", tr("export_warn_occid", lang),
                                "go_map_occid", tr("export_action_mapping", lang)))
            }
            # Preserving unmapped columns in the CSV does not publish them:
            # meta.xml declares only recognized DwC terms, so GBIF drops the
            # rest. `exclude` must stay in step with
            # process_for_export_with_unmapped(): a raw column whose name is
            # already an export column is published under that name.
            unmapped_cols <- unmapped_raw_columns(
                call_r(raw_data_r), call_r(map_values_r),
                exclude = names(call_r(mapped_data_r)),
                overridden_terms = overridden_mapping_terms(call_r(custom_values_r))
            )
            if (length(unmapped_cols) > 0L) {
                add(pending_row("info", shiny::tagList(
                    sprintf(tr("export_unmapped_not_published", lang), length(unmapped_cols)), " ",
                    shiny::tags$code(paste(unmapped_cols, collapse = ", "))
                ), "go_map_unmapped", tr("export_action_mapping", lang)))
            }
            pending_card <- shiny::div(
                class = "export-card export-pending",
                shiny::h2(class = "export-card-title", tr("export_pending_title", lang)),
                if (length(rows) == 0L) {
                    shiny::div(class = "export-pending-none", ph_icon("circle-check"), " ",
                               tr("export_nothing_pending", lang))
                } else {
                    rows
                }
            )

            # --- Generalized species (only when there are any) ----------------
            gen_card <- if (nrow(gen) > 0L) {
                gen_rows <- lapply(seq_len(nrow(gen)), function(i) {
                    shiny::tags$tr(
                        shiny::tags$td(shiny::tags$em(gen$scientificName[i])),
                        shiny::tags$td(cat_pill(gen$category[i])),
                        shiny::tags$td(tier_label(gen$tier[i], lang))
                    )
                })
                shiny::div(
                    class = "export-card",
                    shiny::h2(class = "export-card-title", tr("export_section_generalization", lang)),
                    shiny::tags$table(
                        class = "export-gen-table",
                        shiny::tags$thead(shiny::tags$tr(
                            shiny::tags$th(tr("export_gen_species", lang)),
                            shiny::tags$th(tr("export_gen_category", lang), " ",
                                           info_tip(tr("export_cat_tooltip", lang))),
                            shiny::tags$th(tr("export_gen_tier", lang), " ",
                                           info_tip(tr("export_gen_tooltip", lang)))
                        )),
                        shiny::tags$tbody(gen_rows)
                    )
                )
            }

            # --- Files, and what to do with them next -------------------------
            files_card <- shiny::div(
                class = "export-card export-files",
                shiny::h2(class = "export-card-title", tr("export_section_files", lang)),
                file_group(tr("export_section_files_dwca", lang), s$files$dwca),
                file_group(tr("export_section_files_aux", lang), unname(s$files$auxiliary)),
                shiny::div(
                    class = "export-ipt-note",
                    ph_icon("upload"),
                    shiny::span(shiny::strong(tr("export_ipt_title", lang)), " ",
                                tr("export_ipt_body", lang))
                )
            )

            shiny::tagList(
                kpis,
                shiny::div(
                    class = "export-summary",
                    shiny::div(class = "export-summary-main", pending_card, gen_card),
                    files_card
                ),
                shiny::tags$script(shiny::HTML(
                    "(function(){if(window.bootstrap&&bootstrap.Tooltip){document.querySelectorAll('.export-info-tip[data-bs-toggle=\"tooltip\"]').forEach(function(el){if(!el.__tipInit){el.__tipInit=true;new bootstrap.Tooltip(el);}});}})();"
                ))
            )
        })

        # The bar under the page: bundle name and whether it can go out yet.
        output$download_status <- shiny::renderUI({
            s <- summary_r()
            if (is.null(s) || !is.list(s) || s$record_count == 0L) return(NULL)
            lang <- lang_r()
            n_block <- length(s$missing_required) + isTRUE(s$bor_blank_count > 0L) +
                isTRUE(s$justification_pending)
            shiny::tagList(
                ph_icon("file-zipper"),
                shiny::span(class = "export-zip-name", s$files$zip),
                if (n_block > 0L) {
                    shiny::span(class = "export-bar-state is-blocked",
                                sprintf(tr("export_bar_blocked", lang), n_block))
                } else {
                    shiny::span(class = "export-bar-state is-ready", tr("export_bar_ready", lang))
                }
            )
        })

        invisible(NULL)
    })
}
