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
        )
    )
}

# Point fill per MMA threat group: the border colour of the group's pill, so
# the map and the table read the same (ADR-132). A dark stroke keeps the light
# fills (VU) visible on the land and the sea.
sensitive_threat_colors <- c(
    crpex = "#a33b57", cr = "#c0392b", en = "#e6873c", vu = "#e6c84d", other = "#9aa0a6"
)

# Default "review by" date offered for a generalization decision: Chapman
# recommends revisiting it within 2-5 years, and this is the midpoint.
default_review_date <- function() Sys.Date() + 1460

# Keep a saved dropdown value only while it is still on offer: a new dataset
# retires the species the user had open in the exception editor.
restore_choice <- function(saved, choices) {
    if (length(saved) == 1L && !is.na(saved) && saved %in% choices) saved else ""
}

#' Sensitive Coordinates (Generalization) Module Server
#'
#' @param id Module ID
#' @param data_r Reactive data frame with mapped (Darwin Core) data
#' @param lang_r Reactive language value
#' @param sensitivity_payload_r Optional reactive data frame of per-species
#'   sensitivity decisions from Validation > Names (researcher mark/unmark).
#' @param coords_correction_payload_r Optional reactive transposed-coordinate
#'   correction payload, applied so the preview matches the published point.
#' @param country_fill_payload_r Optional reactive country-fill payload.
#' @param reset_signal_r Optional reactive reset signal from the mapping module.
#'   When it fires, module-local state and inputs are cleared.
#' @param active_r Optional reactive flagging whether this tab is the one on
#'   screen. The map path is the only consumer of the full mapped frame that is
#'   driven by observers, and observers are never suspended by tab visibility,
#'   so without this every mapping edit pays a whole-dataset rebuild here.
#'   Defaults to always-active when not supplied.
#' @return Reactive list `{ levels, justification, review_date, enabled }`
#'   consumed by the export (Preview tab).
#' @export
mod_sensitive_coords_server <- function(id, data_r, lang_r,
                                        sensitivity_payload_r = NULL,
                                        coords_correction_payload_r = NULL,
                                        country_fill_payload_r = NULL,
                                        reset_signal_r = NULL,
                                        active_r = NULL) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        is_active <- function() {
            if (is.null(active_r) || !shiny::is.reactive(active_r)) return(TRUE)
            isTRUE(tryCatch(active_r(), error = function(e) TRUE))
        }

        # Effective data: apply the same corrections the export applies, so the
        # generalization preview shows the *published* coordinate, not the raw one.
        effective_data_r <- shiny::reactive({
            df <- tryCatch(data_r(), error = function(e) NULL)
            if (!is.data.frame(df)) return(NULL)
            cp <- if (!is.null(coords_correction_payload_r) &&
                      shiny::is.reactive(coords_correction_payload_r)) {
                tryCatch(coords_correction_payload_r(), error = function(e) NULL)
            } else {
                NULL
            }
            df <- apply_coords_correction_payload(df, cp)
            fp <- if (!is.null(country_fill_payload_r) &&
                      shiny::is.reactive(country_fill_payload_r)) {
                tryCatch(country_fill_payload_r(), error = function(e) NULL)
            } else {
                NULL
            }
            apply_country_fill_payload(df, fp)
        })

        export_sensitivity_payload <- shiny::reactive({
            if (is.null(sensitivity_payload_r) ||
                !shiny::is.reactive(sensitivity_payload_r)) {
                return(NULL)
            }
            sensitivity_payload_r()
        })

        sensitive_codes <- c("crpex", "cr", "en", "vu", "other")
        cat_code <- function(category) {
            code <- gsub("[^a-z0-9]", "", tolower(as.character(category)))
            ifelse(nzchar(code), code, "other")
        }
        # Chapman Table 5 cascade -> tier, CAPPED at Category 2 (4.3->high ...
        # 4.5->low; all-no -> not_sensitive). Category 1 (extreme) is never
        # produced here -- it is reachable only via an explicit, justified
        # per-species exception. NA while the cascade is still unanswered.
        determine_tier <- function(a3, a4, a5) {
            done <- function(x) !is.null(x) && nzchar(x)
            if (!done(a3)) return(NA_character_)
            if (identical(a3, "yes")) return("high")
            if (!done(a4)) return(NA_character_)
            if (identical(a4, "yes")) return("medium")
            if (!done(a5)) return(NA_character_)
            if (identical(a5, "yes")) return("low")
            "not_sensitive"
        }

        group_levels_rv <- shiny::reactiveVal(list())
        species_overrides_rv <- shiny::reactiveVal(list())
        preview_tier_rv <- shiny::reactiveVal(NULL)
        # Raw cascade answers (q43/q44/q45 per group code) kept so the assessment
        # panel can restore the radios after a re-render: the panel is a renderUI
        # that recreates these inputs, and without restoration a tab switch wipes
        # the user's marks (the recreated radios read back as NULL). Same input-
        # recreation hazard as ADR-098.
        group_answers_rv <- shiny::reactiveVal(list())
        # Decision inputs mirrored server-side. The assessment panel is a
        # renderUI that recreates them, and every Mapping edit invalidates the
        # mapped frame this panel reads, so a tab switch was enough to re-render
        # it. The recreated inputs echoed their hardcoded defaults back and the
        # mode silently fell to "publish" -- the export then published exact
        # coordinates for sensitive species with no warning. Restoring from
        # these (not from `input`, which the reset handler clears one flush
        # later) is what keeps the decision. Same hazard as ADR-098.
        mode_rv <- shiny::reactiveVal("publish")
        justification_rv <- shiny::reactiveVal("")
        review_date_rv <- shiny::reactiveVal(default_review_date())
        exc_species_rv <- shiny::reactiveVal("")

        shiny::observeEvent(input$sensitive_mode, {
            m <- as.character(input$sensitive_mode)
            if (length(m) == 1L && nzchar(m)) mode_rv(m)
        })
        shiny::observeEvent(input$sensitive_justification, {
            justification_rv(input$sensitive_justification %||% "")
        }, ignoreNULL = FALSE)
        shiny::observeEvent(input$sensitive_review_date, {
            d <- input$sensitive_review_date
            review_date_rv(if (length(d) == 1L && !is.na(d)) d else default_review_date())
        })
        shiny::observeEvent(input$exc_species, {
            sp <- as.character(input$exc_species %||% "")
            exc_species_rv(if (length(sp) == 1L) sp else "")
        }, ignoreNULL = FALSE)

        # Detected sensitive species (>= 1 record with coordinates), grouped by
        # MMA threat status. Sourced from the corrected data already in hand.
        sensitive_species_overview <- shiny::reactive({
            df <- effective_data_r()
            need <- c("scientificName", "decimalLatitude", "decimalLongitude")
            if (!is.data.frame(df) || nrow(df) == 0L || !all(need %in% names(df))) {
                return(NULL)
            }
            sci <- as.character(df$scientificName)
            lat <- suppressWarnings(as.numeric(df$decimalLatitude))
            lon <- suppressWarnings(as.numeric(df$decimalLongitude))
            keep <- !is.na(sci) & nzchar(sci)
            u <- unique(sci[keep])
            if (length(u) == 0L) return(NULL)
            dec <- sensitive_resolve(u, export_sensitivity_payload())
            sens <- u[dec$sensitive]
            cats <- dec$category[dec$sensitive]
            if (length(sens) == 0L) return(NULL)
            has_coord <- !is.na(lat) & !is.na(lon)
            # One table() pass over the georeferenced rows instead of rescanning
            # the whole column once per sensitive species. It also skips the
            # NA/blank names `keep` already excludes, so a nameless row with
            # coordinates can no longer turn a count into NA.
            coord_counts <- table(sci[keep & has_coord])
            n_rec <- as.integer(coord_counts[sens])
            n_rec[is.na(n_rec)] <- 0L
            ok <- n_rec > 0L
            if (!any(ok)) return(NULL)
            cats_ok <- cats[ok]
            cats_ok[is.na(cats_ok) | !nzchar(cats_ok)] <- "\u2014"
            out <- data.frame(
                scientificName = sens[ok], category = cats_ok,
                code = cat_code(cats_ok), n = n_rec[ok],
                stringsAsFactors = FALSE
            )
            out[order(out$category, out$scientificName), , drop = FALSE]
        })

        sensitive_overview <- shiny::reactive({
            ov <- sensitive_species_overview()
            if (is.null(ov)) 0L else sum(ov$n)
        })

        # Per-species tier map (override > group > unassessed/not_sensitive).
        species_levels_r <- shiny::reactive({
            ov <- sensitive_species_overview()
            if (is.null(ov) || nrow(ov) == 0L) {
                return(stats::setNames(character(0), character(0)))
            }
            gl <- group_levels_rv()
            ovr <- species_overrides_rv()
            tiers <- vapply(ov$code, function(cc) {
                t <- gl[[cc]]
                if (is.null(t)) "not_sensitive" else t
            }, character(1))
            for (i in seq_len(nrow(ov))) {
                o <- ovr[[ov$scientificName[i]]]
                if (!is.null(o)) tiers[i] <- o
            }
            stats::setNames(tiers, ov$scientificName)
        })

        # Decision-driven preview rows (one per masked record): the actual
        # outcome of the current assessment. Drives the result card + border
        # alert + the map overlay (unless a what-if preview is active).
        actual_preview_r <- shiny::reactive({
            df <- effective_data_r()
            tryCatch(
                generalization_map_preview(df, species_levels_r(), export_sensitivity_payload()),
                error = function(e) NULL
            )
        })

        # Justification is mandatory once any record lands at Cat 1/2/3
        # (extreme/high/medium); Cat 4 (~100 m) and publish stay optional.
        justification_missing_r <- shiny::reactive({
            lv <- species_levels_r()
            any(lv %in% c("extreme", "high", "medium")) &&
                !nzchar(trimws(input$sensitive_justification %||% ""))
        })

        # ---- Cascade -> tier wiring ---------------------------------------
        # "exc" is the per-species exception cascade. Its answers ride the same
        # persistence so the exception editor survives a re-render, but it never
        # defines a group tier.
        lapply(c(sensitive_codes, "exc"), function(cc) {
            shiny::observe({
                a3 <- input[[paste0("q43_", cc)]]
                a4 <- input[[paste0("q44_", cc)]]
                a5 <- input[[paste0("q45_", cc)]]
                # A re-render recreates the radios with no selection; ignore that
                # transient all-empty state so a tab switch never wipes a mark.
                # The user has no way to clear a radio back to NULL, so NULL here
                # only ever means "freshly (re)rendered, not yet answered".
                if (is.null(a3) && is.null(a4) && is.null(a5)) {
                    return(invisible(NULL))
                }
                # Persist the raw answers so the panel can restore them on the
                # next re-render (see group_answers_rv / yn_radio).
                ans <- group_answers_rv()
                ans[[paste0("q43_", cc)]] <- a3
                ans[[paste0("q44_", cc)]] <- a4
                ans[[paste0("q45_", cc)]] <- a5
                group_answers_rv(ans)

                if (identical(cc, "exc")) return(invisible(NULL))

                t <- determine_tier(a3, a4, a5)
                gl <- group_levels_rv()
                cur <- gl[[cc]]
                if (is.na(t)) {
                    if (!is.null(cur)) { gl[[cc]] <- NULL; group_levels_rv(gl) }
                } else if (!identical(cur, t)) {
                    gl[[cc]] <- t; group_levels_rv(gl)
                }
            })
        })

        # Per-species exception via the (capped) cascade.
        shiny::observeEvent(input$exc_apply, {
            sp <- input$exc_species
            if (is.null(sp) || !nzchar(sp)) return()
            t <- determine_tier(input$q43_exc, input$q44_exc, input$q45_exc)
            if (is.na(t)) return()
            ovr <- species_overrides_rv()
            ovr[[sp]] <- t
            species_overrides_rv(ovr)
            shiny::showNotification(tr("sensitive_saved_toast", lang_r()))
        })
        # Explicit Category-1 (extreme) escape hatch -- only path to extreme,
        # reserved for low-mobility / endemic taxa and gated by the mandatory
        # justification at export.
        shiny::observeEvent(input$exc_apply_cat1, {
            sp <- input$exc_species
            if (is.null(sp) || !nzchar(sp)) return()
            ovr <- species_overrides_rv()
            ovr[[sp]] <- "extreme"
            species_overrides_rv(ovr)
            shiny::showNotification(tr("sensitive_saved_toast", lang_r()))
        })
        shiny::observeEvent(input$exc_clear, {
            species_overrides_rv(list())
        })

        # ---- Click-preview ladder (what-if) -------------------------------
        # Stable observers, dynamic buttons: the ladder renderUI does not depend
        # on preview_tier_rv, so its buttons are not re-created on a preview click.
        lapply(c("extreme", "high", "medium", "low"), function(tier) {
            shiny::observeEvent(input[[paste0("ladder_", tier)]], {
                preview_tier_rv(tier)
            })
        })
        shiny::observeEvent(input$ladder_actual, {
            preview_tier_rv(NULL)
        })
        shiny::observeEvent(input$sensitive_mode, {
            if (!identical(input$sensitive_mode, "generalize")) preview_tier_rv(NULL)
        }, ignoreInit = TRUE)

        # ---- Shared label helpers -----------------------------------------
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

        # Compact level label for tight rows: "Categoria N · ~X km".
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

        # MMA threat-category pill (colour differs per category via CSS).
        threat_pill <- function(code, label) {
            shiny::span(class = paste0("sp-cat-pill sp-cat-pill--", code), label)
        }

        # Chapman category chip: neutral, with a square that grows with the
        # grid. Colour stays reserved for the official threat status (ADR-132).
        level_chip <- function(tier, lang, extra_class = NULL) {
            shiny::span(
                class = paste("sc-level-chip", paste0("sc-level-chip--", tier), extra_class),
                shiny::span(class = "sc-level-glyph", `aria-hidden` = "true"),
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

        # Per-group determination chip, shown live in the accordion summary.
        lapply(sensitive_codes, function(cc) {
            output[[paste0("group_badge_", cc)]] <- shiny::renderUI({
                gl <- group_levels_rv()
                lang <- lang_r()
                t <- gl[[cc]]
                if (is.null(t)) {
                    return(shiny::span(
                        class = "sp-group-badge sp-group-badge--none",
                        tr("sensitive_not_assessed", lang)
                    ))
                }
                level_chip(t, lang)
            })
        })

        output$sensitive_overrides_list <- shiny::renderUI({
            ovr <- species_overrides_rv()
            lang <- lang_r()
            if (length(ovr) == 0L) return(NULL)
            items <- lapply(names(ovr), function(s) {
                shiny::tags$li(shiny::tags$em(s), " \u2014 ", badge_for_tier(ovr[[s]], lang))
            })
            shiny::tagList(
                shiny::tags$ul(class = "sp-override-list", items),
                shiny::actionLink(ns("exc_clear"), tr("sensitive_clear_overrides", lang))
            )
        })

        # ---- Assessment panel (static structure; nested outputs stay live) -
        # Chapman's Table 5 as one decision table: a row per threat group, a
        # column per question, the resulting grid on the right (ADR-132).
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
            # The exception editor keeps the stacked cascade: it answers for
            # one species, not a row of the table.
            cascade_stack <- function(cc) {
                cond <- function(q) sprintf("input.q4%d_%s == 'no'", q, cc)
                shiny::div(
                    class = "sp-cascade",
                    yn_radio(paste0("q43_", cc), "sensitive_q_4_3"),
                    shiny::conditionalPanel(cond(3), ns = ns,
                        yn_radio(paste0("q44_", cc), "sensitive_q_4_4"),
                        shiny::conditionalPanel(cond(4), ns = ns,
                            yn_radio(paste0("q45_", cc), "sensitive_q_4_5")
                        )
                    )
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

            exceptions_block <- shiny::tags$details(
                class = "sp-exceptions sc-card",
                shiny::tags$summary(tr("sensitive_group_exceptions", lang)),
                shiny::div(
                    class = "sp-exc-body",
                    shiny::selectizeInput(
                        ns("exc_species"), label = NULL,
                        choices = c("", ov$scientificName),
                        selected = restore_choice(shiny::isolate(exc_species_rv()), ov$scientificName),
                        options = list(placeholder = tr("sensitive_exc_prompt", lang))
                    ),
                    shiny::conditionalPanel(
                        "input.exc_species != ''", ns = ns,
                        cascade_stack("exc"),
                        shiny::actionButton(ns("exc_apply"), tr("sensitive_exc_apply", lang),
                                            class = "btn btn-sm btn-secondary"),
                        shiny::div(
                            class = "sc-exc-cat1",
                            shiny::actionButton(ns("exc_apply_cat1"),
                                                tr("sensitive_exc_cat1_btn", lang),
                                                class = "btn btn-sm sc-exc-cat1-btn"),
                            shiny::span(class = "sc-exc-cat1-note", tr("sensitive_exc_cat1_note", lang))
                        )
                    ),
                    shiny::uiOutput(ns("sensitive_overrides_list"))
                )
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

            mode_label <- function(title_key, recommended) {
                shiny::tagList(
                    tr(title_key, lang),
                    if (recommended) shiny::span(class = "sp-mode-badge", tr("sensitive_mode_recommended_badge", lang))
                )
            }

            shiny::div(
                class = "sensitive-panel sc-assess",
                shiny::div(
                    class = "sc-mode-card sc-card",
                    shiny::span(class = "sc-mode-summary",
                                sprintf(tr("sc_mode_summary", lang), n, nrow(ov))),
                    shiny::div(
                        class = "sp-mode-radio",
                        shiny::radioButtons(
                            ns("sensitive_mode"),
                            label = shiny::tags$span(class = "visually-hidden", tr("sensitive_step_question", lang)),
                            choiceNames = list(
                                mode_label("sensitive_mode_publish_title", TRUE),
                                mode_label("sensitive_assess_mode_title", FALSE)
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
                            shiny::span(class = "sc-matrix-hint", tr("sc_matrix_hint", lang))
                        ),
                        decision_table,
                        shiny::uiOutput(ns("scale_strip"))
                    ),
                    shiny::uiOutput(ns("cat1_alert")),
                    exceptions_block,
                    confirm_block,
                    shiny::div(
                        class = "sc-about",
                        ph_icon("book-open"),
                        shiny::div(
                            shiny::p(class = "sc-about-text", tr("sc_about_text", lang)),
                            shiny::tags$a(
                                class = "sc-about-ref",
                                href = "https://doi.org/10.15468/doc-5jp4-5g10",
                                target = "_blank", rel = "noopener",
                                tr("sc_about_ref", lang)
                            )
                        )
                    )
                )
            )
        })

        # Live "justification required" hint under the field.
        output$justification_warn <- shiny::renderUI({
            if (!justification_missing_r()) return(NULL)
            shiny::div(
                class = "sc-just-warn",
                ph_icon("triangle-exclamation"), " ",
                tr("sc_result_needs_justification", lang_r())
            )
        })

        # Per-category justification guidance: one tailored line per generalized
        # category actually in play (Cat 1/2/3), not a single generic prompt.
        output$justification_prompt <- shiny::renderUI({
            lv <- species_levels_r()
            tiers <- intersect(c("extreme", "high", "medium"), unique(unname(lv)))
            if (length(tiers) == 0L) return(NULL)
            lang <- lang_r()
            shiny::tags$ul(
                class = "sc-just-prompt",
                lapply(tiers, function(t) {
                    shiny::tags$li(
                        shiny::span(class = paste0("sc-just-dot sc-level-chip--", t),
                                    shiny::span(class = "sc-level-glyph", `aria-hidden` = "true")),
                        tr(paste0("sensitive_just_prompt_", t), lang)
                    )
                })
            )
        })

        # Category-1 alert (verbatim Chapman Table 6 + low-mobility/endemic note).
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

        # Loud border-crossing alert: the single most important event on screen.
        # Surfaces records published at the data's real precision rather than the
        # finer chosen grid: clamped because the chosen level was finer than the
        # data (Chapman: generalization never increases precision) or preserved
        # because already generalized upstream (ADR-095). Without this the
        # behaviour was silent.
        output$precision_lock_alert <- shiny::renderUI({
            if (!identical(input$sensitive_mode %||% "publish", "generalize")) return(NULL)
            prev <- actual_preview_r()
            if (is.null(prev)) return(NULL)
            n_locked <- (attr(prev, "n_clamped_to_precision") %||% 0L) +
                (attr(prev, "n_upstream_preserved") %||% 0L)
            if (n_locked == 0L) return(NULL)
            lang <- lang_r()
            shiny::div(
                class = "sc-precision-lock-alert",
                ph_icon("lock"), " ",
                shiny::span(
                    class = "sc-precision-lock-text",
                    sprintf(tr("sc_precision_lock_desc", lang), n_locked)
                )
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
            items <- lapply(seq_len(nrow(crossing)), function(i) {
                shiny::tags$li(
                    shiny::tags$em(crossing$scientificName[i]), " \u2014 ",
                    sprintf("%s \u2192 %s", crossing$country_orig[i] %||% "?", crossing$country_gen[i] %||% "?")
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

        # ---- Grid chips under the decision table ----------------------------
        # The what-if preview: a click draws every sensitive point at that
        # category until "Show actual decision".
        output$scale_strip <- shiny::renderUI({
            ov <- sensitive_species_overview()
            if (is.null(ov)) return(NULL)
            lang <- lang_r()
            is_gen <- identical(input$sensitive_mode %||% "publish", "generalize")
            active <- preview_tier_rv()

            tiers <- c("low", "medium", "high", "extreme")
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
                    shiny::div(class = "sc-scale-chips", chips),
                    if (is_gen) {
                        shiny::actionLink(ns("ladder_actual"), tr("sc_ladder_actual", lang),
                                          class = "sc-ladder-actual")
                    }
                )
            )
        })

        # ---- Legend under the map ------------------------------------------
        # Point fill = the MMA threat group, once the group has a decision;
        # white while it waits. Cells are neutral, a dashed red one leaves the
        # country (ADR-132).
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

        # ---- Hero map -----------------------------------------------------
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
            htmlwidgets::onRender(map_obj, "
                function(el, x) {
                    var map = this;
                    var stroke = function() { return map._sairaSat ? '#ffffff' : '#1C1C26'; };
                    var origin = function() { return map.layerManager && map.layerManager.getLayerGroup('orig_points'); };
                    map.on('baselayerchange', function(e) {
                        map._sairaSat = e.name === 'Esri.WorldImagery';
                        var g = origin();
                        if (g) g.eachLayer(function(l) { if (l.setStyle) l.setStyle({color: stroke()}); });
                    });
                    map.on('layeradd', function(e) {
                        var g = origin();
                        if (map._sairaSat && g && g.hasLayer(e.layer) && e.layer.setStyle) {
                            e.layer.setStyle({color: stroke()});
                        }
                    });
                }
            ")
        })
        # Keep the map live while its tab is hidden so leafletProxy repaints
        # (e.g. an origin marker corrected on the Coords tab) are applied instead
        # of dropped, otherwise the stale point lingers until a full re-render.
        shiny::outputOptions(output, "gen_map", suspendWhenHidden = FALSE)

        # Single map painter so layer order is deterministic: published cells +
        # connectors are drawn FIRST, then the high-contrast "origin" markers
        # LAST so they always sit on top of the translucent cells (under
        # preferCanvas everything shares one canvas, so draw order = z-order --
        # this is the fix for the markers vanishing under the cell rectangles).
        # It deliberately does NOT move the map: tier/what-if redraws keep the
        # user's current zoom so cell sizes are comparable at a glance.
        # Debounced so each cascade answer paints the result card + category
        # badges immediately, while the heavier map overlay (border lookup +
        # shape draw) redraws ~300 ms after the user stops answering. Computing
        # prev here (not in the observe) keeps the whole map path off the
        # answer's flush, so the pills feel instant.
        # The gate sits HERE, ahead of sensitive_species_overview(), because that
        # is the call that pulls the full mapped frame -- gating the observers
        # below would leave the rebuild running while the user is on Mapping.
        # It is a reactive dependency, so opening the tab recomputes and repaints.
        gen_overlay_data_r <- shiny::debounce(shiny::reactive({
            if (!is_active()) return(NULL)
            ov <- sensitive_species_overview()
            if (is.null(ov)) return(NULL)
            df <- effective_data_r()
            if (!is.data.frame(df)) return(NULL)
            is_gen <- identical(input$sensitive_mode %||% "publish", "generalize")
            prev <- NULL
            if (is_gen) {
                pt <- preview_tier_rv()
                levels <- if (!is.null(pt)) {
                    stats::setNames(rep(pt, nrow(ov)), ov$scientificName)
                } else {
                    species_levels_r()
                }
                prev <- tryCatch(
                    generalization_map_preview(df, levels, export_sensitivity_payload()),
                    error = function(e) NULL
                )
            }
            # A point takes its threat colour once its species has a decision:
            # a group answer, an exception, or "publish" for everything.
            gl <- group_levels_rv()
            ovr <- species_overrides_rv()
            decided <- if (!is_gen) {
                rep(TRUE, nrow(ov))
            } else {
                vapply(ov$code, function(cc) !is.null(gl[[cc]]), logical(1)) |
                    ov$scientificName %in% names(ovr)
            }
            list(ov = ov, df = df, is_gen = is_gen, prev = prev, lang = lang_r(),
                 decided = stats::setNames(unname(decided), ov$scientificName))
        }), 300)

        shiny::observe({
            d <- gen_overlay_data_r()
            proxy <- leaflet::leafletProxy(ns("gen_map"))
            leaflet::clearGroup(proxy, "gen_overlay")
            leaflet::clearGroup(proxy, "orig_points")
            if (is.null(d)) return(invisible(NULL))
            ov <- d$ov
            df <- d$df
            lang <- d$lang
            prev <- d$prev

            # 1) Published overlay (generalize mode only).
            if (isTRUE(d$is_gen)) {
                if (is.data.frame(prev) && nrow(prev) > 0L) {
                    tier_u <- unique(prev$tier)
                    g_all <- vapply(tier_u, sensitive_generalization_grid, numeric(1), USE.NAMES = FALSE)[match(prev$tier, tier_u)]
                    crosses_all <- !is.na(prev$crosses) & prev$crosses
                    has_cell <- !is.na(g_all) & g_all > 0 & coords_plottable(prev$lat, prev$lon)
                    # Camera-trap data stacks thousands of records on a handful of
                    # camera coordinates, so the same cell/connector/circle is
                    # drawn over and over. Collapse to unique (origin, cell, tier,
                    # crossing) shapes and issue ONE batched, vectorized leaflet
                    # call per shape type instead of three calls per record -- the
                    # per-record loop was the source of the freeze on large
                    # datasets (and the compounding-opacity stacking artefact).
                    if (any(has_cell)) {
                        idx <- which(has_cell)
                        sig <- paste(
                            prev$scientificName[idx], prev$lon[idx], prev$lat[idx],
                            prev$gen_lon[idx], prev$gen_lat[idx], prev$tier[idx],
                            crosses_all[idx],
                            sep = "|"
                        )
                        idx <- idx[!duplicated(sig)]

                        gu <- g_all[idx]
                        cu <- crosses_all[idx]
                        # Neutral cells: colour belongs to the threat groups on
                        # the points. A cell that leaves the country is red and
                        # dashed (ADR-132).
                        col_u <- ifelse(cu, "#C0392B", "#1C1C26")
                        pop_u <- vapply(
                            idx,
                            function(i) gen_popup(
                                prev[i, , drop = FALSE], lang, crosses_all[i],
                                if (crosses_all[i]) "#C0392B" else "#FFA204"
                            ),
                            character(1)
                        )

                        # Connectors: Origin -> published cell centre. One call,
                        # NA-separated coordinates so each pair is a distinct
                        # dashed teal segment. Drawn first (under the cells).
                        leaflet::addPolylines(
                            proxy,
                            lng = as.vector(rbind(prev$lon[idx], prev$gen_lon[idx], NA_real_)),
                            lat = as.vector(rbind(prev$lat[idx], prev$gen_lat[idx], NA_real_)),
                            weight = 1.5, color = "#0e7c86", opacity = 0.85,
                            dashArray = "5,5", group = "gen_overlay"
                        )
                        # Published cells: one vectorized call (per-cell colour
                        # red when the cell crosses a border, else orange).
                        leaflet::addRectangles(
                            proxy,
                            lng1 = prev$gen_lon[idx] - gu / 2, lat1 = prev$gen_lat[idx] - gu / 2,
                            lng2 = prev$gen_lon[idx] + gu / 2, lat2 = prev$gen_lat[idx] + gu / 2,
                            weight = ifelse(cu, 2, 1), color = col_u, fillColor = col_u,
                            fillOpacity = 0.06, opacity = ifelse(cu, 0.95, 0.55),
                            dashArray = ifelse(cu, "5,3", ""),
                            popup = pop_u, group = "gen_overlay"
                        )
                        # Point-radius uncertainty circles (centre -> furthest
                        # corner = coordinateUncertaintyInMeters), the honest GBIF
                        # view that circumscribes each cell (Chapman Fig. 2). One
                        # vectorized call over the rows with a positive radius.
                        unc_u <- prev$unc_m[idx]
                        uc <- !is.na(unc_u) & unc_u > 0
                        if (any(uc)) {
                            leaflet::addCircles(
                                proxy,
                                lng = prev$gen_lon[idx][uc], lat = prev$gen_lat[idx][uc],
                                radius = unc_u[uc], weight = 1.5, color = "#6d28d9",
                                opacity = 0.9, fill = FALSE, dashArray = "6,5",
                                group = "gen_overlay"
                            )
                        }
                    }
                }
            }

            # 2) Origin markers ON TOP (always shown; the raw published point).
            # Deduped by (species, coordinate): camera-trap datasets repeat the
            # same camera location across thousands of records, so one marker per
            # distinct point keeps the canvas light without changing the view.
            sci <- as.character(df$scientificName)
            lat <- suppressWarnings(as.numeric(df$decimalLatitude))
            lon <- suppressWarnings(as.numeric(df$decimalLongitude))
            # A point outside the valid range has no place on the map; the
            # Coordinates tab lists it.
            sel <- sci %in% ov$scientificName & coords_plottable(lat, lon)
            if (any(sel)) {
                s_sci <- sci[sel]; s_lat <- lat[sel]; s_lon <- lon[sel]
                keep <- !duplicated(paste(s_sci, s_lon, s_lat, sep = "|"))
                k_sci <- s_sci[keep]
                fill <- sensitive_threat_colors[ov$code[match(k_sci, ov$scientificName)]]
                fill[is.na(fill) | !d$decided[k_sci]] <- "#ffffff"
                leaflet::addCircleMarkers(
                    proxy, lng = s_lon[keep], lat = s_lat[keep],
                    radius = 6, stroke = TRUE, weight = 2, color = "#1C1C26",
                    fillColor = unname(fill), fillOpacity = 1, opacity = 1,
                    group = "orig_points",
                    popup = sprintf("<strong>%s</strong><br>%s",
                                    htmltools::htmlEscape(s_sci[keep]), tr("sc_popup_original", lang))
                )
            }
            invisible(NULL)
        })

        # Frame the map ONCE per dataset (the set of origin points). Assessment
        # and what-if redraws must not re-zoom -- otherwise clicking a category
        # pill reframes the view and the same-tier cell looks a different size
        # at the new zoom. Re-fits only when the origin points actually change.
        # Reads the overlay payload instead of recomputing ov/df: both need the
        # same two values, and pulling them twice meant every edit rebuilt the
        # whole mapped frame twice. Inheriting the 300 ms debounce is fine -- the
        # fit is a one-shot per dataset anyway.
        map_fitted_sig_rv <- shiny::reactiveVal(NULL)
        shiny::observe({
            d <- gen_overlay_data_r()
            if (is.null(d)) return(invisible(NULL))
            ov <- d$ov
            df <- d$df
            if (is.null(ov) || !is.data.frame(df)) return(invisible(NULL))
            sci <- as.character(df$scientificName)
            lat <- suppressWarnings(as.numeric(df$decimalLatitude))
            lon <- suppressWarnings(as.numeric(df$decimalLongitude))
            sel <- sci %in% ov$scientificName & coords_plottable(lat, lon)
            if (!any(sel)) return(invisible(NULL))
            sig <- paste0(sprintf("%.6f,%.6f", lon[sel], lat[sel]), collapse = ";")
            if (identical(sig, map_fitted_sig_rv())) return(invisible(NULL))
            map_fitted_sig_rv(sig)
            proxy <- leaflet::leafletProxy(ns("gen_map"))
            view <- coords_map_view(lat[sel], lon[sel])
            if (identical(view$type, "point")) {
                leaflet::setView(proxy, lng = view$lng, lat = view$lat, zoom = 8)
            } else {
                leaflet::fitBounds(proxy, view$lng1, view$lat1, view$lng2, view$lat2)
            }
            invisible(NULL)
        })

        # A re-upload or a confirmed Mapping reset invalidates the dataset
        # baseline: drop the generalization determination, the per-species
        # exceptions, and the decision inputs (mode/justification/review date) so
        # nothing from the previous dataset carries into the new one.
        if (!is.null(reset_signal_r)) {
            shiny::observeEvent(reset_signal_r(), {
                group_levels_rv(list())
                species_overrides_rv(list())
                preview_tier_rv(NULL)
                group_answers_rv(list())
                map_fitted_sig_rv(NULL)
                mode_rv("publish")
                justification_rv("")
                review_date_rv(default_review_date())
                exc_species_rv("")
                shiny::updateRadioButtons(session, "sensitive_mode", selected = "publish")
                shiny::updateTextAreaInput(session, "sensitive_justification", value = "")
                shiny::updateDateInput(session, "sensitive_review_date", value = default_review_date())
            }, ignoreInit = TRUE)
        }

        # ---- Decision consumed by the export (Preview tab) ----------------
        sensitive_generalization_payload_r <- shiny::reactive({
            if (!identical(input$sensitive_mode %||% "publish", "generalize")) {
                return(list(levels = stats::setNames(character(0), character(0)),
                            review_date = NULL, justification = NULL,
                            enabled = FALSE, needs_justification = FALSE))
            }
            lv <- species_levels_r()
            list(
                levels = lv,
                review_date = input$sensitive_review_date,
                justification = input$sensitive_justification,
                enabled = TRUE,
                # Justification is mandatory once any record is Cat 1/2/3.
                needs_justification = any(lv %in% c("extreme", "high", "medium"))
            )
        })

        sensitive_generalization_payload_r
    })
}
