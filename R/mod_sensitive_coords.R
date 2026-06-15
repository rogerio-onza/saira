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
            shiny::uiOutput(ns("title")),
            shiny::uiOutput(ns("subtitle")),
            shiny::uiOutput(ns("border_alert")),
            # One screen, two jobs: DECIDE on the left, SEE the consequence
            # (per-species result stacked directly over the hero map) on the right.
            shiny::div(
                class = "row g-3 sc-layout",
                shiny::div(
                    class = "col-12 col-lg-5 sc-decide-col",
                    shiny::uiOutput(ns("assessment_panel"))
                ),
                shiny::div(
                    class = "col-12 col-lg-7 sc-consequence-col",
                    shiny::uiOutput(ns("result_card")),
                    shiny::div(
                        class = "sc-map-container",
                        leaflet::leafletOutput(ns("gen_map"), height = "380px")
                    ),
                    shiny::uiOutput(ns("scale_strip")),
                    shiny::uiOutput(ns("chapman_table"))
                )
            )
        )
    )
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
#' @return Reactive list `{ levels, justification, review_date, enabled }`
#'   consumed by the export (Preview tab).
#' @export
mod_sensitive_coords_server <- function(id, data_r, lang_r,
                                        sensitivity_payload_r = NULL,
                                        coords_correction_payload_r = NULL,
                                        country_fill_payload_r = NULL) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        output$title <- shiny::renderUI({
            shiny::h3(class = "sensitive-coords-title", tr("sensitive_coords_title", lang_r()))
        })
        output$subtitle <- shiny::renderUI({
            shiny::p(class = "sensitive-coords-subtitle", tr("sensitive_coords_subtitle", lang_r()))
        })

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
        # Threat-level filter for the result list ("all" or a threat code:
        # crpex/cr/en/vu/other). Lets the user narrow a long result list to a
        # single MMA group. Reset to "all" whenever the detected set changes.
        result_filter_rv <- shiny::reactiveVal("all")

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
            n_rec <- vapply(sens, function(s) sum(sci == s & has_coord), integer(1))
            ok <- n_rec > 0L
            if (!any(ok)) return(NULL)
            cats_ok <- cats[ok]
            cats_ok[is.na(cats_ok) | !nzchar(cats_ok)] <- "—"
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
        lapply(sensitive_codes, function(cc) {
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
                tr(paste0("sensitive_card_num_", tier), lang), " · ",
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
            paste0(tr(paste0("sensitive_card_num_", tier), lang), " · ", scale_txt)
        }

        # MMA threat-category pill (colour differs per category via CSS).
        threat_pill <- function(code, label) {
            shiny::span(class = paste0("sp-cat-pill sp-cat-pill--", code), label)
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
                shiny::span(
                    class = paste0("sp-group-badge sp-group-badge--", t),
                    badge_for_tier(t, lang)
                )
            })
        })

        output$sensitive_overrides_list <- shiny::renderUI({
            ovr <- species_overrides_rv()
            lang <- lang_r()
            if (length(ovr) == 0L) return(NULL)
            items <- lapply(names(ovr), function(s) {
                shiny::tags$li(shiny::tags$em(s), " — ", badge_for_tier(ovr[[s]], lang))
            })
            shiny::tagList(
                shiny::tags$ul(class = "sp-override-list", items),
                shiny::actionLink(ns("exc_clear"), tr("sensitive_clear_overrides", lang))
            )
        })

        # ---- Assessment panel (static structure; nested outputs stay live) -
        output$assessment_panel <- shiny::renderUI({
            lang <- lang_r()
            ov <- sensitive_species_overview()
            if (is.null(ov)) {
                return(shiny::div(
                    class = "sensitive-panel sc-empty",
                    shiny::div(class = "sc-empty-icon", shiny::icon("shield-halved")),
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
                    ns(id), label = tr(qkey, lang),
                    choiceNames = list(tr("sensitive_q_yes", lang), tr("sensitive_q_no", lang)),
                    choiceValues = c("yes", "no"),
                    selected = if (is.null(prev_ans)) character(0) else prev_ans,
                    inline = TRUE
                )
            }
            cascade_ui <- function(cc) {
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

            # The two publication strategies, each a rich card (the colored
            # publish/generalize cards the user wants back). Reuses .sp-mode-radio.
            mode_card <- function(title_key, desc_key, recommended) {
                shiny::tagList(
                    shiny::div(
                        class = "sp-mode-head",
                        shiny::span(class = "sp-mode-title", tr(title_key, lang)),
                        if (recommended) {
                            shiny::span(class = "sp-mode-badge",
                                        tr("sensitive_mode_recommended_badge", lang))
                        }
                    ),
                    shiny::div(class = "sp-mode-desc", tr(desc_key, lang))
                )
            }

            code_order <- c("crpex", "cr", "en", "vu", "other")
            present <- code_order[code_order %in% ov$code]
            group_blocks <- lapply(seq_along(present), function(i) {
                cc <- present[i]
                sub <- ov[ov$code == cc, , drop = FALSE]
                label <- if (identical(cc, "other")) tr("sensitive_group_other", lang) else sub$category[1]
                shiny::tags$details(
                    class = "sp-group", name = "sc-groups",
                    open = if (i == 1L) NA else NULL,
                    shiny::tags$summary(
                        class = "sp-group-head",
                        shiny::span(class = paste0("sp-cat-pill sp-cat-pill--", cc), label),
                        shiny::span(class = "sp-group-count",
                                    sprintf(tr("sensitive_group_species_count", lang), nrow(sub))),
                        shiny::uiOutput(ns(paste0("group_badge_", cc)), inline = TRUE)
                    ),
                    cascade_ui(cc),
                    shiny::tags$details(
                        class = "sp-group-species",
                        shiny::tags$summary(tr("sensitive_group_species_list", lang)),
                        shiny::tags$ul(class = "sp-species-list",
                            lapply(sub$scientificName, function(s) shiny::tags$li(shiny::tags$em(s))))
                    )
                )
            })

            exceptions_block <- shiny::tags$details(
                class = "sp-exceptions",
                shiny::tags$summary(tr("sensitive_group_exceptions", lang)),
                shiny::div(
                    class = "sp-exc-body",
                    shiny::selectizeInput(
                        ns("exc_species"), label = NULL,
                        choices = c("", ov$scientificName), selected = "",
                        options = list(placeholder = tr("sensitive_exc_prompt", lang))
                    ),
                    shiny::conditionalPanel(
                        "input.exc_species != ''", ns = ns,
                        cascade_ui("exc"),
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
                class = "sc-confirm",
                shiny::h6(class = "sc-confirm-title", shiny::icon("circle-check"), " ",
                          tr("sc_confirm_title", lang)),
                shiny::div(
                    class = "sp-justification",
                    shiny::tags$label(`for` = ns("sensitive_justification"),
                                      class = "sp-justification-label",
                                      tr("sensitive_justification_label", lang)),
                    shiny::uiOutput(ns("justification_prompt")),
                    shiny::textAreaInput(
                        ns("sensitive_justification"), label = NULL,
                        placeholder = tr("sensitive_justification_placeholder", lang),
                        rows = 2, width = "100%"
                    ),
                    shiny::uiOutput(ns("justification_warn"))
                ),
                shiny::div(
                    class = "sp-review-date",
                    shiny::dateInput(ns("sensitive_review_date"),
                                     label = tr("sensitive_review_date_label", lang),
                                     value = Sys.Date() + 1460)
                )
            )

            shiny::div(
                class = "sensitive-panel sc-assess",
                shiny::div(
                    class = "sp-header",
                    shiny::h5(
                        class = "sp-title",
                        shiny::icon("shield-halved", class = "sp-title-icon"),
                        tr("sensitive_panel_title", lang)
                    ),
                    shiny::span(class = "sp-count-chip",
                                sprintf(tr("sensitive_panel_records_chip", lang), n))
                ),
                shiny::p(class = "sp-lead", shiny::HTML(sprintf(tr("sensitive_panel_intro", lang), n))),
                shiny::div(class = "sp-step-question", tr("sensitive_step_question", lang)),
                shiny::div(
                    class = "sp-mode-radio",
                    shiny::radioButtons(
                        ns("sensitive_mode"), label = NULL,
                        choiceNames = list(
                            mode_card("sensitive_mode_publish_title",
                                      "sensitive_mode_publish_desc", TRUE),
                            mode_card("sensitive_assess_mode_title",
                                      "sensitive_assess_mode_desc", FALSE)
                        ),
                        choiceValues = c("publish", "generalize"), selected = "publish"
                    )
                ),
                shiny::conditionalPanel(
                    condition = "input.sensitive_mode == 'generalize'", ns = ns,
                    shiny::div(
                        class = "sp-level-block",
                        shiny::div(class = "sp-level-prompt", tr("sensitive_assess_prompt", lang)),
                        shiny::div(
                            class = "sc-assess-meta",
                            shiny::uiOutput(ns("groups_progress")),
                            bslib::popover(
                                shiny::tags$button(
                                    type = "button",
                                    class = "btn btn-link btn-sm sc-cascade-help",
                                    shiny::icon("circle-question"), " ",
                                    tr("sc_cascade_help_link", lang)
                                ),
                                title = tr("sc_cascade_help_title", lang),
                                shiny::HTML(tr("sc_cascade_help_body", lang)),
                                placement = "right"
                            )
                        ),
                        shiny::div(class = "sp-groups sc-groups", group_blocks),
                        shiny::uiOutput(ns("cat1_alert")),
                        exceptions_block,
                        confirm_block
                    )
                )
            )
        })

        # ---- Result card (live) -------------------------------------------
        output$result_card <- shiny::renderUI({
            ov <- sensitive_species_overview()
            if (is.null(ov)) return(NULL)
            lang <- lang_r()
            n <- sensitive_overview()
            mode <- input$sensitive_mode %||% "publish"
            if (!identical(mode, "generalize")) {
                return(shiny::div(
                    class = "sc-result sc-result--publish",
                    shiny::div(class = "sc-result-head", tr("sc_result_title", lang)),
                    shiny::div(
                        class = "sc-result-state sc-result-state--publish",
                        shiny::icon("circle-check"), " ", tr("sc_result_publish_state", lang)
                    ),
                    shiny::div(class = "sc-result-line", sprintf(tr("sc_result_records", lang), n))
                ))
            }
            levels <- species_levels_r()
            gl <- group_levels_rv()
            ovr <- species_overrides_rv()

            # Threat-level filter: when more than one MMA group is present, offer
            # chips so a long list can be narrowed to a single group. A filter for
            # a no-longer-present group falls back to "all".
            code_order <- c("crpex", "cr", "en", "vu", "other")
            present_codes <- code_order[code_order %in% ov$code]
            active_filter <- result_filter_rv()
            if (!identical(active_filter, "all") && !active_filter %in% present_codes) {
                active_filter <- "all"
            }
            ov_view <- if (identical(active_filter, "all")) {
                ov
            } else {
                ov[ov$code == active_filter, , drop = FALSE]
            }

            code_label <- function(cc) {
                if (identical(cc, "other")) {
                    tr("sensitive_group_other", lang)
                } else {
                    ov$category[match(cc, ov$code)]
                }
            }
            filter_chips <- if (length(present_codes) > 1L) {
                all_cls <- "sc-rfilter-chip"
                if (identical(active_filter, "all")) {
                    all_cls <- paste(all_cls, "sc-rfilter-chip--active")
                }
                chips <- c(
                    list(shiny::actionButton(
                        ns("rfilter_all"), tr("sc_result_filter_all", lang), class = all_cls
                    )),
                    lapply(present_codes, function(cc) {
                        cls <- paste0("sc-rfilter-chip sc-rfilter-chip--", cc)
                        if (identical(active_filter, cc)) {
                            cls <- paste(cls, "sc-rfilter-chip--active")
                        }
                        shiny::actionButton(
                            ns(paste0("rfilter_", cc)), code_label(cc), class = cls
                        )
                    })
                )
                shiny::div(
                    class = "sc-result-filter", role = "group",
                    `aria-label` = tr("sc_result_filter_label", lang),
                    chips
                )
            }

            # One row per detected sensitive species: threat pill + name -> outcome.
            rows <- lapply(seq_len(nrow(ov_view)), function(i) {
                sp <- ov_view$scientificName[i]
                assessed <- !is.null(ovr[[sp]]) || !is.null(gl[[ov_view$code[i]]])
                tier <- unname(levels[[sp]])
                outcome <- if (!assessed) {
                    shiny::span(class = "sc-sp-outcome sc-sp-outcome--pending",
                                tr("sc_result_unassessed_row", lang))
                } else if (identical(tier, "not_sensitive")) {
                    shiny::span(class = "sc-sp-outcome sc-sp-outcome--publish",
                                tr("sc_result_publish_row", lang))
                } else {
                    shiny::span(class = paste0("sc-sp-outcome sc-sp-outcome--", tier),
                                level_compact(tier, lang))
                }
                shiny::div(
                    class = "sc-sp-row",
                    threat_pill(ov_view$code[i], ov_view$category[i]),
                    shiny::span(class = "sc-sp-name", shiny::tags$em(sp)),
                    shiny::span(class = "sc-sp-arrow", "→"),
                    outcome
                )
            })
            prev <- actual_preview_r()
            cr <- if (is.data.frame(prev)) prev$crosses else logical(0)
            n_cross <- sum(!is.na(cr) & cr)
            assessed_vec <- vapply(seq_len(nrow(ov)), function(i) {
                !is.null(ovr[[ov$scientificName[i]]]) || !is.null(gl[[ov$code[i]]])
            }, logical(1))
            n_assessed <- sum(assessed_vec)
            n_total <- nrow(ov)
            shiny::div(
                class = "sc-result sc-result--generalize",
                shiny::div(class = "sc-result-head", tr("sc_result_title", lang)),
                filter_chips,
                shiny::div(class = "sc-sp-list", rows),
                shiny::div(
                    class = "sc-result-foot",
                    shiny::div(
                        class = if (n_cross > 0L) "sc-result-cross sc-result-cross--danger" else "sc-result-cross",
                        shiny::icon(if (n_cross > 0L) "triangle-exclamation" else "circle-check"), " ",
                        if (n_cross > 0L) sprintf(tr("sc_result_crossing", lang), n_cross) else tr("sc_result_no_crossing", lang)
                    ),
                    shiny::div(class = "sc-result-assessed",
                               sprintf(tr("sensitive_species_assessed_count", lang), n_assessed, n_total)),
                    if (justification_missing_r()) {
                        shiny::div(class = "sc-just-warn",
                                   shiny::icon("triangle-exclamation"), " ",
                                   tr("sc_result_needs_justification", lang))
                    }
                )
            )
        })

        # Threat-level filter chips drive result_filter_rv. The codes are a
        # fixed known set, so observers are registered up front.
        for (code in c("all", "vu", "en", "cr", "crpex", "other")) {
            local({
                cc <- code
                shiny::observeEvent(input[[paste0("rfilter_", cc)]], {
                    result_filter_rv(cc)
                }, ignoreInit = TRUE)
            })
        }

        # Reset the filter whenever the detected set of sensitive species changes
        # (a new upload), so a stale group filter never hides the new list.
        shiny::observeEvent(sensitive_species_overview(), {
            result_filter_rv("all")
        }, ignoreInit = TRUE)

        # Live "justification required" hint under the field.
        output$justification_warn <- shiny::renderUI({
            if (!justification_missing_r()) return(NULL)
            shiny::div(
                class = "sc-just-warn",
                shiny::icon("triangle-exclamation"), " ",
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
                        shiny::span(class = paste0("sc-just-dot sp-grid-swatch sp-grid-swatch--", t)),
                        tr(paste0("sensitive_just_prompt_", t), lang)
                    )
                })
            )
        })

        # Group-assessment progress ("X de Y grupos avaliados"), shown above the
        # accordion. A separate output so answering a cascade does not re-render
        # (and collapse) the whole assessment panel.
        output$groups_progress <- shiny::renderUI({
            if (!identical(input$sensitive_mode %||% "publish", "generalize")) return(NULL)
            ov <- sensitive_species_overview()
            if (is.null(ov)) return(NULL)
            gl <- group_levels_rv()
            present <- unique(ov$code)
            n_assessed <- sum(vapply(present, function(cc) !is.null(gl[[cc]]), logical(1)))
            shiny::span(
                class = "sc-groups-progress",
                sprintf(tr("sc_groups_progress", lang_r()), n_assessed, length(present))
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
                shiny::icon("triangle-exclamation"), " ",
                shiny::span(class = "sc-cat1-title", tr("sensitive_cat1_alert", lang)),
                shiny::div(class = "sp-cat1-note", tr("sensitive_cat1_alert_note", lang))
            )
        })

        # Loud border-crossing alert: the single most important event on screen.
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
                    shiny::tags$em(crossing$scientificName[i]), " — ",
                    sprintf("%s → %s", crossing$country_orig[i] %||% "?", crossing$country_gen[i] %||% "?")
                )
            })
            shiny::div(
                class = "sc-border-alert",
                shiny::div(
                    class = "sc-border-alert-head",
                    shiny::icon("triangle-exclamation"), " ",
                    shiny::span(class = "sc-border-alert-title", tr("sc_border_alert_title", lang))
                ),
                shiny::div(class = "sc-border-alert-desc", sprintf(tr("sc_border_alert_desc", lang), n_cross)),
                shiny::tags$ul(class = "sc-border-alert-list", items),
                shiny::div(class = "sc-border-alert-rec", shiny::icon("lightbulb"), " ",
                           tr("sc_border_alert_recommend", lang))
            )
        })

        # ---- Scale strip under the map ------------------------------------
        # Ascending category chips (the what-if preview) + the map legend. Each
        # chip carries its category colour (dot), and the active what-if chip
        # fills with that colour so "answer -> category -> map" stays coupled.
        output$scale_strip <- shiny::renderUI({
            ov <- sensitive_species_overview()
            if (is.null(ov)) return(NULL)
            lang <- lang_r()
            is_gen <- identical(input$sensitive_mode %||% "publish", "generalize")
            active <- preview_tier_rv()

            tiers <- c("low", "medium", "high", "extreme")
            chips <- lapply(tiers, function(t) {
                is_cat1 <- identical(t, "extreme")
                label <- shiny::tagList(
                    shiny::span(class = paste0("sc-scale-dot sp-grid-swatch sp-grid-swatch--", t)),
                    if (is_cat1) shiny::tagList(shiny::icon("triangle-exclamation"), " "),
                    level_compact(t, lang)
                )
                cls <- paste0("sc-scale-chip sc-scale-chip--", t)
                if (identical(active, t)) cls <- paste0(cls, " sc-scale-chip--active")
                if (is_gen) {
                    shiny::actionButton(ns(paste0("ladder_", t)), label, class = cls)
                } else {
                    shiny::span(class = cls, label)
                }
            })

            legend_items <- if (is_gen) {
                list(c("real", "sc_legend_real"),
                     c("generalized", "sc_legend_generalized"),
                     c("area", "sc_legend_area"),
                     c("uncertainty", "sc_legend_uncertainty"),
                     c("cross", "sc_legend_crosses"))
            } else {
                list(c("real", "sc_legend_real"))
            }
            legend <- shiny::div(
                class = "sc-scale-legend",
                lapply(legend_items, function(it) {
                    shiny::span(
                        class = "sc-legend-item",
                        shiny::span(class = paste0("sc-legend-mark sc-legend-mark--", it[[1]])),
                        tr(it[[2]], lang)
                    )
                })
            )

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
                ),
                legend
            )
        })

        # ---- Chapman reference table (fixed below the map) ----------------
        # Kept in evidence as a fixed, elegant panel (not a popover); documents
        # all four categories, with the Cat-1 row flagged "extreme cases only".
        output$chapman_table <- shiny::renderUI({
            if (is.null(sensitive_species_overview())) return(NULL)
            lang <- lang_r()
            fmt_grid_cell <- function(level) {
                g <- sensitive_generalization_grid(level)
                if (is.na(g)) return(tr("sensitive_grid_unmasked", lang))
                km <- round(g * 111.32, 1)
                sprintf("%s° (~%s km)", format(g, trim = TRUE, scientific = FALSE), format(km, trim = TRUE))
            }
            spatial_for <- function(level) {
                if (identical(level, "not_sensitive")) return("—")
                tr(paste0("sensitive_card_impact_", level), lang)
            }
            table_rows <- lapply(sensitive_generalization_levels(), function(level) {
                baseline <- identical(level, "not_sensitive")
                is_cat1 <- identical(level, "extreme")
                cls <- if (baseline) "sp-grid-row-baseline" else if (is_cat1) "sp-grid-row-cat1" else NULL
                shiny::tags$tr(
                    class = cls,
                    shiny::tags$td(
                        shiny::span(class = paste0("sp-grid-swatch sp-grid-swatch--", level)),
                        tr(paste0("sensitive_gen_", level), lang),
                        if (is_cat1) shiny::div(class = "sp-grid-cat1-note", tr("sensitive_table_cat1_note", lang))
                    ),
                    shiny::tags$td(class = "sp-grid-result", spatial_for(level)),
                    shiny::tags$td(class = "sp-grid-value", fmt_grid_cell(level))
                )
            })
            shiny::div(
                class = "sc-reference",
                shiny::h6(class = "sc-reference-title", shiny::icon("table-list"), " ",
                          tr("sensitive_reference_title", lang)),
                shiny::tags$table(
                    class = "table table-sm sensitive-grid-table",
                    shiny::tags$thead(shiny::tags$tr(
                        shiny::tags$th(tr("sensitive_table_col_category", lang)),
                        shiny::tags$th(tr("sensitive_table_col_result", lang)),
                        shiny::tags$th(class = "sp-grid-value", tr("sensitive_table_col_grid", lang))
                    )),
                    shiny::tags$tbody(table_rows)
                ),
                shiny::p(class = "sc-reference-caption", tr("sensitive_table_caption", lang))
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
            leaflet::setView(map_obj, lng = -52, lat = -15, zoom = 3)
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
        gen_overlay_data_r <- shiny::debounce(shiny::reactive({
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
            list(ov = ov, df = df, is_gen = is_gen, prev = prev, lang = lang_r())
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
                    has_cell <- !is.na(g_all) & g_all > 0
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
                        col_u <- ifelse(cu, "#C0392B", "#FFA204")
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
                            weight = 1.5, color = col_u, fillColor = col_u,
                            fillOpacity = 0.18, opacity = 0.85,
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
            sel <- sci %in% ov$scientificName & !is.na(lat) & !is.na(lon)
            if (any(sel)) {
                s_sci <- sci[sel]; s_lat <- lat[sel]; s_lon <- lon[sel]
                keep <- !duplicated(paste(s_sci, s_lon, s_lat, sep = "|"))
                leaflet::addCircleMarkers(
                    proxy, lng = s_lon[keep], lat = s_lat[keep],
                    radius = 6, stroke = TRUE, weight = 3, color = "#1C1C26",
                    fillColor = "#ffffff", fillOpacity = 0.95, opacity = 1,
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
        map_fitted_sig_rv <- shiny::reactiveVal(NULL)
        shiny::observe({
            ov <- sensitive_species_overview()
            df <- effective_data_r()
            if (is.null(ov) || !is.data.frame(df)) return(invisible(NULL))
            sci <- as.character(df$scientificName)
            lat <- suppressWarnings(as.numeric(df$decimalLatitude))
            lon <- suppressWarnings(as.numeric(df$decimalLongitude))
            sel <- sci %in% ov$scientificName & !is.na(lat) & !is.na(lon)
            if (!any(sel)) return(invisible(NULL))
            sig <- paste0(sprintf("%.6f,%.6f", lon[sel], lat[sel]), collapse = ";")
            if (identical(sig, map_fitted_sig_rv())) return(invisible(NULL))
            map_fitted_sig_rv(sig)
            proxy <- leaflet::leafletProxy(ns("gen_map"))
            rng_lon <- range(lon[sel])
            rng_lat <- range(lat[sel])
            if (diff(rng_lon) < 1e-6 && diff(rng_lat) < 1e-6) {
                leaflet::setView(proxy, lng = rng_lon[1], lat = rng_lat[1], zoom = 8)
            } else {
                leaflet::fitBounds(proxy, rng_lon[1], rng_lat[1], rng_lon[2], rng_lat[2])
            }
            invisible(NULL)
        })

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
