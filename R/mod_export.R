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
        shiny::tags$script(module_behavior_html("exportFocusField")),

        shiny::div(
            class = "container-fluid export-page",
            shiny::uiOutput(ns("summary")),
            # The download sits in a card fixed to the bottom of the page
            # (ADR-132). The dock is a solid band, so the cards that scroll
            # under it never show around the bar. What blocks the download is
            # in the Pending card, not here.
            shiny::div(
                class = "export-download-dock",
                shiny::div(
                    class = "export-download-bar",
                    shiny::uiOutput(ns("download_status"), class = "export-download-status"),
                    shiny::uiOutput(ns("download_btn_container"))
                )
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
#'   selection (`include_mma`, `include_iucn`).
#' @param raw_data_r Optional reactive with the original uploaded data.frame.
#' @param map_values_r Optional reactive with the current mapping list.
#' @param custom_values_r Optional reactive with typed constants (`datasetName`,
#'   `license`, `language`); the dataset name names the auxiliary bundle files.
#' @param establishment_dropped_r Optional reactive, named by DwC term, with the
#'   `establishment_dropped_values()` frame for each mapped establishment term
#'   whose column carried values outside the controlled vocabulary.
#' @param occurrence_id_info_r Optional reactive with the identifier strategy and
#'   counts from `resolve_occurrence_ids()`.
#' @param alias_receipt_r Optional reactive with what the last export taught the
#'   alias store (`alias_export_receipt()`), shown with an undo (ADR-141).
#' @param coord_validation_r Optional reactive with the Coordinates-tab result
#'   (`validate_coords_cc_df()`), NULL before the tab runs.
#' @param preview_problems_n_r Optional reactive with the count of open Preview
#'   problems.
#' @param rows_left_out_r Optional reactive with the rows of exact copies the
#'   Preview left out of the package.
#' @param preview_changes_r Optional reactive with the cells the Preview edits
#'   change (`cell_changes()`).
#' @param measurement_specs_r Optional reactive with the type, unit and method
#'   of each column mapped to `measurementValue`, keyed by column.
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
                              alias_receipt_r = NULL,
                              coord_validation_r = NULL,
                              preview_problems_n_r = NULL,
                              rows_left_out_r = NULL,
                              preview_changes_r = NULL,
                              measurement_specs_r = NULL,
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
                dataset_name = dataset_name_r(),
                coord_validation = call_r(coord_validation_r),
                preview_problems_n = call_r(preview_problems_n_r),
                raw_data = call_r(raw_data_r),
                map_values = call_r(map_values_r),
                overridden_terms = overridden_mapping_terms(call_r(custom_values_r)),
                rows_left_out = call_r(rows_left_out_r),
                preview_changes = call_r(preview_changes_r)
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
            rows_left_out_r = rows_left_out_r,
            preview_changes_r = preview_changes_r,
            measurement_specs_r = measurement_specs_r,
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
            force(input_id)
            shiny::observeEvent(input[[input_id]], {
                if (is.function(on_navigate)) on_navigate(tab, term = term)
            }, ignoreInit = TRUE)
        }
        navigate_on("go_fix_justification", "sensitive_coords")
        for (id in c("go_preview_sci_blank", "go_preview_coord_invalid", "go_preview_date_range",
                     "go_preview_date_unparsed", "go_preview_formula", "go_preview_problems",
                     "go_preview_copies")) {
            navigate_on(id, "preview")
        }
        navigate_on("go_changes_names", "validate_names")
        navigate_on("go_changes_coordinates", "validate_coords")
        navigate_on("go_changes_country", "validate_coords")
        navigate_on("go_changes_preview", "preview")
        navigate_on("go_coords_stale", "validate_coords")
        navigate_on("go_coords_flags", "validate_coords")
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

        # One example of each kind of correction, under the Corrections
        # number. The full list goes in the changes file of the package.
        changes_panel <- function(s, ex, n_fix, has_gen, lang) {
            shown <- function(v) {
                if (all(!nzchar(v))) tr("export_changes_blank", lang) else paste(v, collapse = ", ")
            }
            rows <- lapply(names(ex), function(kind) {
                e <- ex[[kind]]$example
                body <- if (is.null(e)) {
                    shiny::div(class = "export-change-why", tr("export_changes_hidden", lang))
                } else {
                    term <- if (kind == "preview" || (kind == "coordinates" && nrow(e) == 1L)) {
                        shiny::span(class = "export-change-term", paste(e$term, collapse = ", "))
                    }
                    shiny::tagList(
                        shiny::div(
                            class = "export-change-ex", term,
                            shiny::span(class = "export-change-old", shown(e$from)),
                            ph_icon("arrow-right"),
                            shiny::span(class = "export-change-new", shown(e$to))
                        ),
                        shiny::div(class = "export-change-why",
                                   sprintf(tr("export_changes_row", lang), e$row[1L]), " \u00b7 ",
                                   tr(paste0("export_changes_why_", kind), lang))
                    )
                }
                shiny::div(
                    class = "export-change-row",
                    shiny::div(class = "export-change-kind",
                               tr(paste0("export_changes_kind_", kind), lang),
                               shiny::span(sprintf(tr("export_changes_records", lang),
                                                   ex[[kind]]$records))),
                    shiny::div(class = "export-change-body", body),
                    shiny::actionLink(ns(paste0("go_changes_", kind)),
                                      tr(paste0("export_changes_go_", kind), lang),
                                      class = "export-change-go")
                )
            })
            shiny::div(
                id = ns("changes_panel"), class = "collapse",
                shiny::div(
                    class = "export-changes",
                    shiny::div(class = "export-changes-head",
                               shiny::strong(sprintf(tr("export_changes_head", lang), n_fix,
                                                     length(unique(s$changes$row)))),
                               shiny::span(tr("export_changes_one_each", lang))),
                    rows,
                    shiny::div(
                        class = "export-changes-foot", ph_icon("lock"),
                        shiny::p(
                            sprintf(tr("export_changes_foot", lang), s$files$auxiliary$changes),
                            if (has_gen) paste0(" ", tr("export_changes_foot_gen", lang))
                        )
                    )
                )
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
            gen <- s$generalization
            fmt_n <- function(value) format_count(value, lang)
            # The numbers sit in a strip inside the package card (round 5,
            # option C). Each detail line rides in the cell tooltip; records
            # and corrections also get a line under the strip.
            kpi <- function(value, label, sub) {
                shiny::div(
                    class = "export-kpi",
                    title = sub,
                    shiny::div(class = "export-kpi-value", fmt_n(value)),
                    shiny::div(class = "export-kpi-label", label)
                )
            }
            n_aux <- length(s$files$auxiliary)
            # Corrections count records, one per kind of change (ADR-176).
            ex <- change_examples(s$changes)
            n_of <- function(kind) ex[[kind]]$records %||% 0L
            n_fix <- sum(vapply(change_kinds, n_of, integer(1)))
            records_sub <- sprintf(tr("export_kpi_records_sub", lang), s$term_count)
            fixes_sub <- sprintf(tr("export_kpi_corrections_sub", lang), n_of("names"),
                                 n_of("coordinates"), n_of("country"), n_of("preview"))
            fixes_kpi <- kpi(n_fix, tr("export_kpi_corrections", lang), fixes_sub)
            if (n_fix > 0L) {
                fixes_kpi <- shiny::tags$button(
                    type = "button", class = "export-kpi export-kpi-toggle collapsed",
                    title = fixes_sub, `data-bs-toggle` = "collapse",
                    `data-bs-target` = paste0("#", ns("changes_panel")),
                    `aria-expanded` = "false", `aria-controls` = ns("changes_panel"),
                    shiny::div(class = "export-kpi-value", fmt_n(n_fix)),
                    shiny::div(class = "export-kpi-label", tr("export_kpi_corrections", lang),
                               ph_icon("caret-down"))
                )
            }
            kpis <- shiny::tagList(
                shiny::div(
                    class = "export-kpis",
                    kpi(s$record_count, tr("export_kpi_records", lang), records_sub),
                    fixes_kpi,
                    kpi(count_distinct_species(gen$scientificName), tr("export_kpi_generalized", lang),
                        if (nrow(gen) == 0L) tr("export_gen_none_short", lang) else tr("export_kpi_generalized_sub", lang)),
                    kpi(length(s$files$dwca) + n_aux, tr("export_kpi_files", lang),
                        sprintf(tr("export_kpi_files_sub", lang), length(s$files$dwca), n_aux))
                ),
                shiny::div(
                    class = "export-kpi-sub",
                    shiny::span(records_sub),
                    shiny::span(sprintf(tr("export_kpi_corrections_line", lang), fixes_sub))
                ),
                if (n_fix > 0L) changes_panel(s, ex, n_fix, nrow(gen) > 0L, lang)
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
                add(pending_row("block", shiny::tagList(
                    sprintf(tr("export_blocked_bor_blank", lang), s$bor_blank_count), " ",
                    shiny::tags$code(format_row_list(s$bor_blank_rows))
                ),
                                if (length(s$missing_required) == 0L) "go_fix_terms",
                                tr("export_action_mapping", lang)))
            }
            if (length(s$sci_blank_rows) > 0L) {
                add(pending_row("block", shiny::tagList(
                    sprintf(tr("export_blocked_sci_blank", lang), length(s$sci_blank_rows)), " ",
                    shiny::tags$code(format_row_list(s$sci_blank_rows))
                ), "go_preview_sci_blank", tr("export_action_preview", lang)))
            }
            if (length(s$coord_invalid_rows) > 0L) {
                add(pending_row("block", shiny::tagList(
                    sprintf(tr("export_blocked_coord_invalid", lang), length(s$coord_invalid_rows)), " ",
                    shiny::tags$code(format_row_list(s$coord_invalid_rows))
                ), "go_preview_coord_invalid", tr("export_action_preview", lang)))
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
                ), "go_preview_date_range", tr("export_action_preview", lang)))
            }
            du <- s$date_unparsed
            if (is.list(du) && isTRUE(du$count > 0L)) {
                add(pending_row("warn", shiny::tagList(
                    shiny::strong(tr("export_date_invalid_title", lang)), " ",
                    sprintf(tr("export_date_invalid_body", lang), du$count), " ",
                    shiny::tags$code(paste(
                        sprintf(tr("export_date_range_row", lang),
                                du$sample$row, du$sample$column, du$sample$value),
                        collapse = ", "
                    ))
                ), "go_preview_date_unparsed", tr("export_action_preview", lang)))
            }
            fc <- s$formula_cells
            if (is.list(fc) && isTRUE(fc$count > 0L)) {
                add(pending_row("block", shiny::tagList(
                    shiny::strong(tr("export_formula_title", lang)), " ",
                    sprintf(tr("export_formula_body", lang), fc$count), " ",
                    shiny::tags$code(paste(
                        sprintf(tr("export_date_range_row", lang),
                                fc$sample$row, fc$sample$column, fc$sample$value),
                        collapse = ", "
                    ))
                ), "go_preview_formula", tr("export_action_preview", lang)))
            }
            # The Preview shows only mapped terms, so these go back to Mapping.
            fu <- s$formula_cells_unmapped
            if (is.list(fu) && isTRUE(fu$count > 0L)) {
                add(pending_row("block", shiny::tagList(
                    shiny::strong(tr("export_formula_title", lang)), " ",
                    sprintf(tr("export_formula_unmapped_body", lang), fu$count), " ",
                    shiny::tags$code(paste(
                        sprintf(tr("export_date_range_row", lang),
                                fu$sample$row, fu$sample$column, fu$sample$value),
                        collapse = ", "
                    ))
                ), "go_map_unmapped", tr("export_action_mapping", lang)))
            }
            if (isTRUE(s$corrections$coord_fixes_stale > 0L)) {
                add(pending_row("warn", sprintf(tr("export_coord_fixes_stale", lang), s$corrections$coord_fixes_stale),
                                "go_coords_stale", tr("export_action_coords", lang)))
            }
            cf <- s$coord_flags
            if (is.list(cf) && isTRUE(cf$count > 0L)) {
                add(pending_row("warn", shiny::tagList(
                    shiny::strong(tr("export_coord_flags_title", lang)), " ",
                    sprintf(tr("export_coord_flags_body", lang), cf$count), " ",
                    shiny::tags$code(format_row_list(cf$rows))
                ), "go_coords_flags", tr("export_action_coords", lang)))
            }
            if (isTRUE(s$preview_problems_n > 0L)) {
                add(pending_row("warn", shiny::tagList(
                    shiny::strong(tr("export_preview_open_title", lang)), " ",
                    sprintf(tr("export_preview_open_body", lang), s$preview_problems_n)
                ), "go_preview_problems", tr("export_action_preview", lang)))
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
            # rest. The call stays in step with process_for_export_with_unmapped().
            unmapped_cols <- unmapped_raw_columns(
                call_r(raw_data_r), call_r(map_values_r),
                overridden_terms = overridden_mapping_terms(call_r(custom_values_r))
            )
            if (length(s$rows_left_out) > 0L) {
                add(pending_row("info", shiny::tagList(
                    sprintf(tr("export_copies_left_out", lang), length(s$rows_left_out)), " ",
                    shiny::tags$code(format_row_list(s$rows_left_out))
                ), "go_preview_copies", tr("export_action_preview", lang)))
            }
            if (length(s$zero_count_rows) > 0L) {
                add(pending_row("info", shiny::tagList(
                    sprintf(tr("export_zero_count_absent", lang), length(s$zero_count_rows)), " ",
                    shiny::tags$code(format_row_list(s$zero_count_rows))
                )))
            }
            if (is.null(s$files$auxiliary$xlsx)) {
                add(pending_row("info", sprintf(tr("export_xlsx_mirror_skipped", lang), s$record_count)))
            }
            if (length(unmapped_cols) > 0L) {
                add(pending_row("info", shiny::tagList(
                    sprintf(tr("export_unmapped_not_published", lang), length(unmapped_cols)), " ",
                    shiny::tags$code(paste(unmapped_cols, collapse = ", "))
                ), "go_map_unmapped", tr("export_action_mapping", lang)))
            }
            # With nothing to review, the card shows the saira-pintor and says
            # the package is ready.
            pending_card <- if (length(rows) == 0L) {
                shiny::div(
                    class = "export-card export-ready",
                    species_photo_tag(species_photo("tangara-fastuosa"), lang, class = "export-ready-photo"),
                    shiny::div(
                        class = "export-ready-body",
                        shiny::div(class = "export-ready-eyebrow", ph_icon("check"), tr("export_ready_eyebrow", lang)),
                        shiny::p(class = "export-ready-title", tr("export_ready_title", lang))
                    )
                )
            } else {
                shiny::div(
                    class = "export-card export-pending",
                    shiny::h2(class = "export-card-title", tr("export_pending_title", lang)),
                    rows
                )
            }

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
                shiny::h2(class = "export-card-title", tr("export_section_package", lang)),
                kpis,
                file_group(tr("export_section_files_dwca", lang), s$files$dwca),
                file_group(tr("export_section_files_aux", lang), unname(s$files$auxiliary)),
                if (!is.null(s$files$private)) {
                    shiny::div(
                        class = "export-private",
                        shiny::div(class = "export-private-title",
                                   ph_icon("lock"), tr("export_private_title", lang)),
                        shiny::p(class = "export-private-body", tr("export_private_body", lang)),
                        shiny::downloadButton(
                            ns("download_private"),
                            sprintf(tr("export_private_download", lang), s$files$private),
                            icon = ph_icon("download"),
                            class = "btn export-private-btn"
                        )
                    )
                },
                shiny::uiOutput(ns("alias_memory")),
                shiny::div(
                    class = "export-ipt-note",
                    ph_icon("upload"),
                    shiny::span(shiny::strong(tr("export_ipt_title", lang)), " ",
                                tr("export_ipt_body", lang))
                )
            )

            # Pending items and the package share the first grid row, so both
            # cards end at the same line whatever their content.
            shiny::tagList(
                shiny::div(
                    class = "export-summary",
                    pending_card,
                    files_card,
                    if (!is.null(gen_card)) shiny::div(class = "export-summary-gen", gen_card)
                ),
                shiny::tags$script(module_behavior_html("exportTooltips"))
            )
        })

        # What the last export taught Rostrum, with an undo (ADR-141). The undo
        # reverses only that export, so the receipt names its run_id.
        undone_run <- shiny::reactiveVal(NULL)

        output$alias_memory <- shiny::renderUI({
            receipt <- call_r(alias_receipt_r)
            if (is.null(receipt)) return(NULL)
            lang <- lang_r()
            body <- if (identical(undone_run(), receipt$run_id)) {
                shiny::p(class = "export-memory-text", tr("export_memory_undone", lang))
            } else {
                pairs <- receipt$pairs
                shiny::tagList(
                    shiny::p(
                        class = "export-memory-text",
                        ph_icon("check"),
                        shiny::span(sprintf(tr("export_memory_learned", lang), nrow(pairs)))
                    ),
                    shiny::div(
                        class = "export-memory-actions",
                        shiny::tags$details(
                            class = "export-memory-details",
                            shiny::tags$summary(tr("export_memory_show", lang)),
                            shiny::div(
                                class = "export-memory-pairs",
                                lapply(seq_len(nrow(pairs)), function(i) {
                                    shiny::tagList(
                                        shiny::span(pairs$col_name[[i]]),
                                        shiny::span(class = "export-memory-arrow", "\u2192"),
                                        shiny::span(class = "export-memory-term", pairs$dwc_term[[i]])
                                    )
                                })
                            )
                        ),
                        shiny::actionButton(
                            ns("undo_alias_export"),
                            shiny::tagList(ph_icon("rotate-left"), tr("export_memory_undo", lang)),
                            class = "btn btn-outline-secondary btn-sm export-memory-undo"
                        )
                    )
                )
            }
            shiny::div(
                class = "export-memory",
                shiny::div(class = "export-file-group-title", tr("export_memory_title", lang)),
                body
            )
        })

        shiny::observeEvent(input$undo_alias_export, {
            receipt <- call_r(alias_receipt_r)
            if (is.null(receipt) || identical(undone_run(), receipt$run_id)) return(invisible(NULL))
            undo <- function() {
                conn <- rostrum_connect()
                on.exit(DBI::dbDisconnect(conn), add = TRUE)
                undo_session_aliases(conn, run_id = receipt$run_id)
            }
            ok <- tryCatch({
                undo()
                TRUE
            }, error = function(e) {
                warning("[rostrum] Could not undo the export aliases: ", e$message)
                FALSE
            })
            if (ok) {
                undone_run(receipt$run_id)
            } else {
                shiny::showNotification(tr("export_memory_undo_failed", lang_r()), type = "error", duration = 5)
            }
        })

        # The bar under the page: the bundle name. The button says if it can go out.
        output$download_status <- shiny::renderUI({
            s <- summary_r()
            if (is.null(s) || !is.list(s) || s$record_count == 0L) return(NULL)
            shiny::tagList(
                ph_icon("file-zipper"),
                shiny::span(class = "export-zip-name", s$files$zip)
            )
        })

        invisible(NULL)
    })
}
