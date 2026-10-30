# Title: Sensitive Coordinates (Generalization) Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-06-10
# Version: 1.0

#' Sensitive Coordinates (Generalization) Module UI
#'
#' Dedicated stage for assessing species sensitivity (Chapman 2020, Table 5,
#' grouped by MMA threat category) and previewing coordinate generalization on a
#' purpose-built map. The map is the guardrail: it shows where each sensitive
#' point lands at the chosen category and flags points that leave their country.
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_sensitive_coords_ui <- function(id) {
    ns <- shiny::NS(id)

    shiny::tagList(
        shiny::div(
            class = "container-fluid sensitive-coords-page",
            shiny::uiOutput(ns("precision_lock_alert")),
            shiny::uiOutput(ns("border_alert")),
            # One screen, two jobs: DECIDE on the left, SEE the consequence on
            # the map on the right (ADR-132).
            shiny::div(
                class = "sc-layout",
                shiny::div(
                    class = "sc-decide-col",
                    shiny::uiOutput(ns("assessment_panel"))
                ),
                shiny::div(
                    class = "sc-consequence-col sc-card",
                    shiny::div(
                        class = "sc-map-container",
                        leaflet::leafletOutput(ns("gen_map"), height = "100%")
                    ),
                    shiny::uiOutput(ns("map_legend"))
                )
            )
        ),
        # The remove links live in a re-rendered list, so one delegated
        # handler serves every row (same pattern as the coordinates undo).
        shiny::tags$script(module_behavior_html("sensitiveOverrideRemove", list(removeId = ns("exc_remove"))))
    )
}

# mod_sensitive_coords presentation. Views expose reactive reads; controllers own mutations.

mount_mod_sensitive_coords_presentation <- function(
    actual_preview_r, exc_species_rv, exc_tier_r, group_answers_rv,
    input, justification_missing_r, justification_rv, lang_r,
    mode_rv, ns, output, preview_tier_rv,
    review_date_rv, sensitive_overview, sensitive_species_overview, session,
    species_levels_r, species_overrides_rv, on_navigate
) {
    badge_for_tier <- function(tier, lang) {
        if (identical(tier, "not_sensitive")) {
            return(tr("sensitive_gen_not_sensitive", lang))
        }
        g <- sensitive_generalization_grid(tier)
        scale_txt <- if (is.na(g)) {
            ""
        } else if (g * 111.32 < 1) {
            sprintf("~%s m", format(round(g * 111.32 * 1000, -2L), trim = TRUE))
        } else {
            sprintf("~%s km", format(round(g * 111.32), trim = TRUE))
        }
        paste0(
            tr(paste0("sensitive_card_num_", tier), lang), " \u00b7 ",
            tr(paste0("sensitive_card_impact_", tier), lang), " ", scale_txt
        )
    }

    level_compact <- function(tier, lang) {
        if (identical(tier, "not_sensitive")) {
            return(tr("sensitive_gen_not_sensitive", lang))
        }
        g <- sensitive_generalization_grid(tier)
        scale_txt <- if (is.na(g)) {
            ""
        } else if (g * 111.32 < 1) {
            sprintf("~%s m", format(round(g * 111.32 * 1000, -2L), trim = TRUE))
        } else {
            sprintf("~%s km", format(round(g * 111.32), trim = TRUE))
        }
        paste0(tr(paste0("sensitive_card_num_", tier), lang), " \u00b7 ", scale_txt)
    }

    threat_pill <- function(code, label) {
        shiny::span(class = paste0("sp-cat-pill sp-cat-pill--", code), label)
    }

    level_chip <- function(tier, lang, extra_class = NULL) {
        shiny::span(
            class = paste("sc-level-chip", paste0("sc-level-chip--", tier), extra_class),
            level_compact(tier, lang)
        )
    }

    gen_popup <- function(row, lang, crosses, col) {
        country_line <- if (!is.na(row$country_orig) || !is.na(row$country_gen)) {
            paste0("<br>", htmltools::htmlEscape(row$country_orig %||% "?"),
                   " &rarr; ", htmltools::htmlEscape(row$country_gen %||% "?"))
        } else {
            ""
        }
        cross_line <- if (crosses) {
            paste0("<br><span style='color:", col, "'>&#9888; ",
                   tr("sensitive_map_crosses", lang), "</span>")
        } else {
            ""
        }
        paste0(
            "<strong>", htmltools::htmlEscape(row$scientificName), "</strong><br>",
            htmltools::htmlEscape(badge_for_tier(row$tier, lang)), "<br>",
            tr("sc_popup_original", lang), ": ", sprintf("%.5f, %.5f", row$lat, row$lon), "<br>",
            tr("sc_popup_generalized", lang), ": ", sprintf("%.5f, %.5f", row$gen_lat, row$gen_lon),
            country_line, cross_line
        )
    }

    output$sensitive_overrides_list <- shiny::renderUI({
        ovr <- species_overrides_rv()
        lang <- lang_r()
        if (length(ovr) == 0L) return(NULL)
        ov <- sensitive_species_overview()
        items <- lapply(names(ovr), function(s) {
            code <- if (is.null(ov)) NA_character_ else ov$code[match(s, ov$scientificName)]
            cat_label <- if (is.null(ov)) NA_character_ else ov$category[match(s, ov$scientificName)]
            shiny::tags$li(
                if (!is.na(code)) threat_pill(code, cat_label),
                shiny::tags$em(s),
                shiny::span(class = "sp-override-spacer"),
                level_chip(ovr[[s]], lang),
                shiny::tags$a(href = "#", class = "sp-override-remove", `data-species` = s,
                              tr("sensitive_exc_remove", lang))
            )
        })
        shiny::tags$ul(class = "sp-override-list", items)
    })

    output$exc_result <- shiny::renderUI({
        t <- exc_tier_r()
        if (is.na(t)) {
            return(shiny::span(class = "sp-group-badge sp-group-badge--none",
                               tr("sensitive_not_assessed", lang_r())))
        }
        level_chip(t, lang_r())
    })

    output$assessment_panel <- shiny::renderUI({
        lang <- lang_r()
        ov <- sensitive_species_overview()
        if (is.null(ov)) {
            return(shiny::div(
                class = "sensitive-panel sc-empty",
                shiny::div(class = "sc-empty-icon", ph_icon("shield-halved")),
                shiny::h5(class = "sc-empty-title", tr("sc_empty_title", lang)),
                shiny::p(class = "sc-empty-desc", tr("sc_empty_desc", lang))
            ))
        }
        n <- sensitive_overview()

        yn_radio <- function(id, qkey) {
            # Restore the prior answer (isolated read: a reactive dependency
            # here would re-render the panel on every click, recreating the
            # very inputs we are reading -- the ADR-098 loop).
            prev_ans <- shiny::isolate(group_answers_rv())[[id]]
            shiny::radioButtons(
                ns(id),
                label = shiny::tags$span(class = "visually-hidden", tr(qkey, lang)),
                choiceNames = list(tr("sensitive_q_yes", lang), tr("sensitive_q_no", lang)),
                choiceValues = c("yes", "no"),
                selected = if (is.null(prev_ans)) character(0) else prev_ans,
                inline = TRUE
            )
        }
        # A question is asked only while every earlier one is "no"; the
        # first "yes" sets the grid, so later cells show a dash.
        cascade_cell <- function(cc, q) {
            id <- paste0("q4", q, "_", cc)
            if (q == 3L) return(shiny::tags$td(class = "sc-matrix-cell", yn_radio(id, "sensitive_q_4_3")))
            open_cond <- paste(sprintf("input.q4%d_%s == 'no'", seq(3L, q - 1L), cc), collapse = " && ")
            shiny::tags$td(
                class = "sc-matrix-cell",
                shiny::conditionalPanel(open_cond, ns = ns, yn_radio(id, paste0("sensitive_q_4_", q))),
                shiny::conditionalPanel(paste0("!(", open_cond, ")"), ns = ns,
                                        shiny::span(class = "sc-matrix-skip", "\u2014"))
            )
        }
        code_order <- c("crpex", "cr", "en", "vu", "other")
        present <- code_order[code_order %in% ov$code]
        matrix_rows <- lapply(present, function(cc) {
            sub <- ov[ov$code == cc, , drop = FALSE]
            label <- if (identical(cc, "other")) tr("sensitive_group_other", lang) else sub$category[1]
            shiny::tags$tr(
                shiny::tags$td(class = "sc-matrix-group", threat_pill(cc, label)),
                shiny::tags$td(
                    class = "sc-matrix-count",
                    # The species of the row, on hover.
                    title = paste(sub$scientificName, collapse = ", "),
                    sprintf(tr("sensitive_group_species_count", lang), nrow(sub))
                ),
                cascade_cell(cc, 3L), cascade_cell(cc, 4L), cascade_cell(cc, 5L),
                shiny::tags$td(class = "sc-matrix-result",
                               shiny::uiOutput(ns(paste0("group_badge_", cc)), inline = TRUE))
            )
        })
        q_head <- function(q) {
            shiny::tags$th(
                title = tr(paste0("sensitive_q_4_", q), lang),
                shiny::span(class = "sc-matrix-q", tr(paste0("sc_matrix_q4", q, "_head"), lang)),
                shiny::span(class = "sc-matrix-q-short", tr(paste0("sc_matrix_q4", q, "_short"), lang))
            )
        }
        decision_table <- shiny::tags$table(
            class = "sc-matrix",
            shiny::tags$thead(shiny::tags$tr(
                shiny::tags$th(tr("sc_matrix_col_group", lang)),
                shiny::tags$th(tr("sc_matrix_col_species", lang)),
                q_head(3L), q_head(4L), q_head(5L),
                shiny::tags$th(tr("sc_matrix_col_result", lang))
            )),
            shiny::tags$tbody(matrix_rows)
        )

        # An exception is one more row of the decision table, for one
        # species, under the same question headers (round 5, option A).
        exceptions_block <- shiny::div(
            class = "sp-exceptions sc-card",
            shiny::div(
                class = "sc-matrix-head",
                shiny::h3(class = "sp-exceptions-title", tr("sensitive_group_exceptions", lang)),
                shiny::span(class = "sc-matrix-hint", tr("sensitive_exc_hint", lang))
            ),
            shiny::tags$table(
                class = "sc-matrix sp-exc-matrix",
                shiny::tags$thead(shiny::tags$tr(
                    shiny::tags$th(tr("sensitive_exc_col_species", lang)),
                    q_head(3L), q_head(4L), q_head(5L),
                    shiny::tags$th(tr("sc_matrix_col_result", lang))
                )),
                shiny::tags$tbody(shiny::tags$tr(
                    shiny::tags$td(
                        class = "sp-exc-species",
                        shiny::selectizeInput(
                            ns("exc_species"), label = NULL,
                            choices = c("", ov$scientificName),
                            selected = restore_choice(shiny::isolate(exc_species_rv()), ov$scientificName),
                            options = list(placeholder = tr("sensitive_exc_prompt", lang))
                        )
                    ),
                    cascade_cell("exc", 3L), cascade_cell("exc", 4L), cascade_cell("exc", 5L),
                    shiny::tags$td(class = "sc-matrix-result",
                                   shiny::uiOutput(ns("exc_result"), inline = TRUE))
                ))
            ),
            shiny::div(
                class = "sp-exc-actions",
                shiny::actionButton(ns("exc_apply"), tr("sensitive_exc_apply", lang),
                                    icon = ph_icon("check"), class = "btn btn-sm sp-exc-apply"),
                shiny::checkboxInput(ns("exc_cat1"), tr("sensitive_exc_cat1_check", lang), value = FALSE),
                shiny::span(class = "sc-exc-cat1-note", tr("sensitive_exc_cat1_note", lang))
            ),
            shiny::uiOutput(ns("sensitive_overrides_list"))
        )

        confirm_block <- shiny::div(
            class = "sc-confirm sc-card",
            shiny::div(
                class = "sc-confirm-row",
                shiny::div(
                    class = "sp-justification",
                    shiny::tags$label(`for` = ns("sensitive_justification"),
                                      class = "sp-justification-label",
                                      tr("sensitive_justification_label", lang)),
                    shiny::textAreaInput(
                        ns("sensitive_justification"), label = NULL,
                        value = shiny::isolate(justification_rv()),
                        placeholder = tr("sensitive_justification_placeholder", lang),
                        rows = 1, width = "100%"
                    )
                ),
                shiny::div(
                    class = "sp-review-date",
                    shiny::dateInput(ns("sensitive_review_date"),
                                     label = tr("sensitive_review_date_label", lang),
                                     value = shiny::isolate(review_date_rv()))
                )
            ),
            shiny::uiOutput(ns("justification_prompt")),
            shiny::uiOutput(ns("justification_warn"))
        )

        # How the table works (Chapman 2020): a "?" beside the title opens
        # it over the table, so it takes no room when closed.
        about_row <- function(code, q_key, grid_key) {
            shiny::tagList(
                shiny::span(class = "sc-about-code", code),
                shiny::span(tr(q_key, lang)),
                shiny::span(class = "sc-about-grid-value", tr(grid_key, lang))
            )
        }
        about_tip <- shiny::tags$details(
            class = "sc-about",
            shiny::tags$summary(
                class = "sc-about-toggle",
                title = tr("sc_about_toggle", lang),
                `aria-label` = tr("sc_about_toggle", lang),
                "?"
            ),
            shiny::div(
                class = "sc-about-pop",
                shiny::p(class = "sc-about-text", tr("sc_about_text", lang)),
                shiny::div(
                    class = "sc-about-grid",
                    about_row("4.3", "sc_matrix_q43_short", "sc_about_g43"),
                    about_row("4.4", "sc_matrix_q44_short", "sc_about_g44"),
                    about_row("4.5", "sc_matrix_q45_short", "sc_about_g45"),
                    about_row("\u2014", "sc_about_none", "sc_about_as_is")
                ),
                shiny::tags$a(
                    class = "sc-about-ref",
                    href = "https://doi.org/10.15468/doc-5jp4-5g10",
                    target = "_blank", rel = "noopener",
                    tr("sc_about_ref", lang)
                )
            )
        )

        # Each mode is a card: title, badge and one line on what it does.
        mode_label <- function(title_key, desc_key, recommended) {
            shiny::tagList(
                shiny::span(
                    class = "sp-mode-head",
                    shiny::span(class = "sp-mode-title", tr(title_key, lang)),
                    if (recommended) shiny::span(class = "sp-mode-badge", tr("sensitive_mode_recommended_badge", lang))
                ),
                shiny::span(class = "sp-mode-desc", tr(desc_key, lang))
            )
        }

        shiny::div(
            class = "sensitive-panel sc-assess",
            shiny::div(
                class = "sc-mode-card sc-card",
                shiny::span(class = "sc-mode-summary",
                            sprintf(tr("sc_mode_summary", lang), n, count_distinct_species(ov$scientificName))),
                shiny::div(
                    class = "sp-mode-radio",
                    shiny::radioButtons(
                        ns("sensitive_mode"),
                        label = shiny::tags$span(class = "visually-hidden", tr("sensitive_step_question", lang)),
                        choiceNames = list(
                            mode_label("sensitive_mode_publish_title", "sensitive_mode_publish_desc", TRUE),
                            mode_label("sensitive_assess_mode_title", "sensitive_assess_mode_desc", FALSE)
                        ),
                        choiceValues = c("publish", "generalize"),
                        selected = shiny::isolate(mode_rv()),
                        inline = TRUE
                    )
                )
            ),
            shiny::conditionalPanel(
                condition = "input.sensitive_mode == 'generalize'", ns = ns,
                shiny::div(
                    class = "sc-matrix-card sc-card",
                    shiny::div(
                        class = "sc-matrix-head",
                        shiny::h2(class = "sc-matrix-title", tr("sc_matrix_title", lang)),
                        about_tip,
                        shiny::span(class = "sc-matrix-hint", tr("sc_matrix_hint", lang))
                    ),
                    decision_table,
                    shiny::uiOutput(ns("scale_strip"))
                ),
                shiny::uiOutput(ns("cat1_alert")),
                exceptions_block,
                confirm_block
            )
        )
    })

    output$justification_warn <- shiny::renderUI({
        if (!justification_missing_r()) return(NULL)
        shiny::div(
            class = "sc-just-warn",
            ph_icon("triangle-exclamation"), " ",
            tr("sc_result_needs_justification", lang_r())
        )
    })

    output$justification_prompt <- shiny::renderUI({
        lv <- species_levels_r()
        tiers <- intersect(c("extreme", "high", "medium"), unique(unname(lv)))
        if (length(tiers) == 0L) return(NULL)
        lang <- lang_r()
        shiny::tags$ul(
            class = "sc-just-prompt",
            lapply(tiers, function(t) {
                shiny::tags$li(tr(paste0("sensitive_just_prompt_", t), lang))
            })
        )
    })

    output$cat1_alert <- shiny::renderUI({
        if (!identical(input$sensitive_mode %||% "publish", "generalize")) return(NULL)
        levels <- species_levels_r()
        if (!any(levels == "extreme")) return(NULL)
        lang <- lang_r()
        shiny::div(
            class = "sp-level-warning sp-level-warning--extreme sc-cat1-alert",
            ph_icon("triangle-exclamation"), " ",
            shiny::span(class = "sc-cat1-title", tr("sensitive_cat1_alert", lang)),
            shiny::div(class = "sp-cat1-note", tr("sensitive_cat1_alert_note", lang))
        )
    })

    output$precision_lock_alert <- shiny::renderUI({
        if (!identical(input$sensitive_mode %||% "publish", "generalize")) return(NULL)
        prev <- actual_preview_r()
        if (is.null(prev)) return(NULL)
        n_locked <- (attr(prev, "n_clamped_to_precision") %||% 0L) +
            (attr(prev, "n_upstream_preserved") %||% 0L)
        n_withheld <- attr(prev, "n_withheld") %||% 0L
        if (n_locked == 0L && n_withheld == 0L) return(NULL)
        lang <- lang_r()
        shiny::div(
            class = "sc-precision-lock-alert",
            if (n_locked > 0L) {
                shiny::div(
                    class = "sc-precision-lock-row",
                    ph_icon("lock"),
                    shiny::span(shiny::tags$b(n_locked), " ", tr("sc_precision_lock_desc", lang)),
                    shiny::span(
                        class = "sc-precision-lock-tip", tabindex = "0",
                        title = tr("sc_precision_lock_tip", lang),
                        `aria-label` = tr("sc_precision_lock_tip", lang),
                        ph_icon("info-circle")
                    )
                )
            },
            # B09/B23: a sensitive point the grid cannot move.
            if (n_withheld > 0L) {
                shiny::div(
                    class = "sc-precision-lock-row is-invalid",
                    ph_icon("triangle-exclamation"),
                    shiny::span(shiny::tags$b(n_withheld), " ", tr("sc_withheld_invalid_desc", lang)),
                    if (is.function(on_navigate)) {
                        shiny::tagList(
                            shiny::span(class = "sc-precision-lock-sep", `aria-hidden` = "true", "\u00B7"),
                            shiny::actionLink(ns("go_fix_coords"), tr("sc_withheld_fix", lang))
                        )
                    }
                )
            }
        )
    })

    output$border_alert <- shiny::renderUI({
        if (!identical(input$sensitive_mode %||% "publish", "generalize")) return(NULL)
        prev <- actual_preview_r()
        if (!is.data.frame(prev) || nrow(prev) == 0L) return(NULL)
        cr <- prev$crosses
        n_cross <- sum(!is.na(cr) & cr)
        if (n_cross == 0L) return(NULL)
        lang <- lang_r()
        crossing <- prev[!is.na(cr) & cr, , drop = FALSE]
        crossing <- crossing[!duplicated(crossing$scientificName), , drop = FALSE]
        # Country names in the UI language, and "sea" for no country (B42).
        none <- tr("sc_border_no_country", lang)
        orig <- country_display_name(crossing$country_orig, lang, none)
        gen <- country_display_name(crossing$country_gen, lang, none)
        items <- lapply(seq_len(nrow(crossing)), function(i) {
            shiny::tags$li(
                shiny::tags$em(crossing$scientificName[i]), ": ",
                sprintf("%s \u2192 %s", orig[i], gen[i])
            )
        })
        # Backing off means a HIGHER category number (a finer grid), and the
        # suggestion has to clear the least aggressive tier among the
        # crossing species so it resolves all of them at once.
        suggestions <- sensitive_tier_category_number(
            sensitive_less_aggressive_tiers(crossing$tier)
        )
        recommendation <- if (length(suggestions) == 0L) {
            tr("sc_border_alert_recommend_floor", lang)
        } else {
            # "2, 3 ou 4" / "2, 3 or 4": the comma is punctuation, only the
            # last conjunction is language-dependent.
            listed <- if (length(suggestions) == 1L) {
                as.character(suggestions)
            } else {
                paste0(
                    paste(suggestions[-length(suggestions)], collapse = ", "),
                    tr("sc_border_alert_cat_join", lang),
                    suggestions[[length(suggestions)]]
                )
            }
            sprintf(tr("sc_border_alert_recommend", lang), listed)
        }
        shiny::div(
            class = "sc-border-alert",
            shiny::div(
                class = "sc-border-alert-head",
                ph_icon("triangle-exclamation"), " ",
                shiny::span(class = "sc-border-alert-title", tr("sc_border_alert_title", lang))
            ),
            shiny::div(class = "sc-border-alert-desc", sprintf(tr("sc_border_alert_desc", lang), n_cross)),
            shiny::tags$ul(class = "sc-border-alert-list", items),
            shiny::div(class = "sc-border-alert-rec", ph_icon("lightbulb"), " ", recommendation)
        )
    })

    output$scale_strip <- shiny::renderUI({
        ov <- sensitive_species_overview()
        if (is.null(ov)) return(NULL)
        lang <- lang_r()
        is_gen <- identical(input$sensitive_mode %||% "publish", "generalize")
        active <- preview_tier_rv()

        tiers <- c("low", "medium", "high", "extreme")
        # "Current decision" is the first option of the same control, so
        # the way back from a what-if preview is always visible.
        actual_chip <- if (is_gen) {
            shiny::actionButton(
                ns("ladder_actual"), tr("sc_ladder_actual", lang),
                class = paste("sc-scale-chip sc-scale-chip--actual", if (is.null(active)) "sc-scale-chip--active")
            )
        }
        chips <- lapply(tiers, function(t) {
            chip <- level_chip(t, lang)
            cls <- "sc-scale-chip"
            if (identical(active, t)) cls <- paste(cls, "sc-scale-chip--active")
            if (is_gen) {
                shiny::actionButton(ns(paste0("ladder_", t)), chip, class = cls)
            } else {
                shiny::span(class = cls, chip)
            }
        })

        shiny::div(
            class = "sc-scale",
            shiny::div(
                class = "sc-scale-row",
                shiny::span(class = "sc-scale-label",
                            if (is_gen) tr("sc_ladder_title", lang) else tr("sc_scale_title", lang)),
                shiny::div(class = "sc-scale-chips", actual_chip, chips)
            )
        )
    })

    output$map_legend <- shiny::renderUI({
        ov <- sensitive_species_overview()
        if (is.null(ov)) return(NULL)
        lang <- lang_r()
        is_gen <- identical(input$sensitive_mode %||% "publish", "generalize")
        code_order <- c("crpex", "cr", "en", "vu", "other")
        present <- code_order[code_order %in% ov$code]
        threat_items <- lapply(present, function(cc) {
            label <- if (identical(cc, "other")) tr("sensitive_group_other", lang) else ov$category[match(cc, ov$code)]
            shiny::span(
                class = "sc-legend-item",
                shiny::span(class = paste0("sc-legend-mark sc-legend-mark--threat-", cc)),
                label
            )
        })
        item <- function(mark, key) {
            shiny::span(class = "sc-legend-item",
                        shiny::span(class = paste0("sc-legend-mark sc-legend-mark--", mark)),
                        tr(key, lang))
        }
        shiny::div(
            class = "sc-scale-legend",
            threat_items,
            if (is_gen) shiny::tagList(
                item("pending", "sc_legend_pending"),
                item("generalized", "sc_legend_generalized"),
                item("area", "sc_legend_area"),
                item("uncertainty", "sc_legend_uncertainty"),
                item("cross", "sc_legend_crosses")
            )
        )
    })

    output$gen_map <- leaflet::renderLeaflet({
        map_obj <- leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE))
        map_obj <- leaflet::addProviderTiles(
            map_obj, leaflet::providers$OpenStreetMap, group = "OpenStreetMap",
            options = leaflet::providerTileOptions(noWrap = TRUE)
        )
        map_obj <- leaflet::addProviderTiles(
            map_obj, leaflet::providers$Esri.WorldImagery, group = "Esri.WorldImagery",
            options = leaflet::providerTileOptions(noWrap = TRUE)
        )
        map_obj <- leaflet::addLayersControl(
            map_obj, baseGroups = c("OpenStreetMap", "Esri.WorldImagery"),
            options = leaflet::layersControlOptions(collapsed = FALSE)
        )
        map_obj <- leaflet::hideGroup(map_obj, "Esri.WorldImagery")
        map_obj <- leaflet::setView(map_obj, lng = -52, lat = -15, zoom = 3)
        map_obj <- leaflet_fill_world(map_obj)
        # On the satellite tiles a dark stroke disappears, so the points
        # switch to a white one there, new points included (ADR-132).
        module_behavior_on_render(map_obj, "sensitiveMapStroke")
    })

    shiny::outputOptions(output, "gen_map", suspendWhenHidden = FALSE)
    list(
        badge_for_tier = badge_for_tier, level_compact = level_compact, threat_pill = threat_pill,
        level_chip = level_chip, gen_popup = gen_popup
    )
}
