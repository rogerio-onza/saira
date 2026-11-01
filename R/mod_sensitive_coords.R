
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
#' @param name_review_payload_r Optional reactive Names-tab review payload,
#'   applied so the tab assesses the corrected names that the export writes.
#' @param reset_signal_r Optional reactive reset signal from the mapping module.
#'   When it fires, module-local state and inputs are cleared.
#' @param active_r Optional reactive flagging whether this tab is the one on
#'   screen. The map path is the only consumer of the full mapped frame that is
#'   driven by observers, and observers are never suspended by tab visibility,
#'   so without this every mapping edit pays a whole-dataset rebuild here.
#'   Defaults to always-active when not supplied.
#' @param on_navigate Optional callback `function(tab)` that switches the
#'   top-level tab. The invalid-coordinate alert uses it to open Coordinates.
#' @return Reactive list `list(levels, justification, review_date, enabled)`
#'   consumed by the export (Preview tab).
#' @export
mod_sensitive_coords_server <- function(id, data_r, lang_r,
                                        sensitivity_payload_r = NULL,
                                        coords_correction_payload_r = NULL,
                                        country_fill_payload_r = NULL,
                                        name_review_payload_r = NULL,
                                        reset_signal_r = NULL,
                                        active_r = NULL,
                                        on_navigate = NULL) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        is_active <- function() {
            if (is.null(active_r) || !shiny::is.reactive(active_r)) return(TRUE)
            isTRUE(tryCatch(active_r(), error = function(e) TRUE))
        }

        optional_payload <- function(payload_r) {
            if (is.null(payload_r) || !shiny::is.reactive(payload_r)) return(NULL)
            tryCatch(payload_r(), error = function(e) NULL)
        }

        # Effective data: apply the same corrections the export applies, so the
        # generalization preview shows the *published* name and coordinate.
        effective_data_r <- shiny::reactive({
            df <- tryCatch(data_r(), error = function(e) NULL)
            if (!is.data.frame(df)) return(NULL)
            apply_validation_payloads(
                df,
                name_payload = optional_payload(name_review_payload_r),
                coords_payload = optional_payload(coords_correction_payload_r),
                country_payload = optional_payload(country_fill_payload_r)
            )
        })

        # The Names-tab marks, keyed by the corrected names (AUD-01).
        export_sensitivity_payload <- shiny::reactive({
            if (is.null(sensitivity_payload_r) ||
                !shiny::is.reactive(sensitivity_payload_r)) {
                return(NULL)
            }
            rekey_sensitivity_decisions(sensitivity_payload_r(),
                                        optional_payload(name_review_payload_r))
        })

        sensitive_codes <- c("crpex", "cr", "en", "vu", "other")

        # Chapman Table 5 cascade -> tier, CAPPED at Category 2 (4.3->high ...
        # 4.5->low; all-no -> not_sensitive). Category 1 (extreme) is never
        # produced here -- it is reachable only via an explicit, justified
        # per-species exception. NA while the cascade is still unanswered.

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
            lat <- as_coord_numeric(df$decimalLatitude)$num
            lon <- as_coord_numeric(df$decimalLongitude)$num
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
                code = sensitive_category_code(cats_ok), n = n_rec[ok],
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
            resolve_generalization_levels(sensitive_species_overview(), group_levels_rv(), species_overrides_rv())
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

                t <- chapman_tier(a3, a4, a5)
                gl <- group_levels_rv()
                cur <- gl[[cc]]
                if (is.na(t)) {
                    if (!is.null(cur)) { gl[[cc]] <- NULL; group_levels_rv(gl) }
                } else if (!identical(cur, t)) {
                    gl[[cc]] <- t; group_levels_rv(gl)
                }
            })
        })

        # The tier the exception row gives, NA while it is unanswered. The
        # Category 1 box is the only path to extreme, reserved for low-mobility
        # or endemic taxa and gated by the mandatory justification at export.
        exc_tier_r <- shiny::reactive({
            if (isTRUE(input$exc_cat1)) return("extreme")
            chapman_tier(input$q43_exc, input$q44_exc, input$q45_exc)
        })

        # Per-species exception: one row of the decision table.
        shiny::observeEvent(input$exc_apply, {
            sp <- input$exc_species
            if (is.null(sp) || !nzchar(sp)) return()
            t <- exc_tier_r()
            if (is.na(t)) return()
            ovr <- species_overrides_rv()
            ovr[[sp]] <- t
            species_overrides_rv(ovr)
            shiny::showNotification(tr("sensitive_saved_toast", lang_r()))
        })
        shiny::observeEvent(input$exc_remove, {
            ovr <- species_overrides_rv()
            ovr[[as.character(input$exc_remove)]] <- NULL
            species_overrides_rv(ovr)
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

        # Compact level label for tight rows: "Categoria N · ~X km".

        # MMA threat-category pill (colour differs per category via CSS).

        # Chapman category chip: neutral text. Colour stays reserved for the
        # official threat status (ADR-132).

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

        # ---- Assessment panel (static structure; nested outputs stay live) -
        # Chapman's Table 5 as one decision table: a row per threat group, a
        # column per question, the resulting grid on the right (ADR-132).

        # Live "justification required" hint under the field.

        # Per-category justification guidance: one tailored line per generalized
        # category actually in play (Cat 1/2/3), not a single generic prompt.

        # Category-1 alert (verbatim Chapman Table 6 + low-mobility/endemic note).

        # Loud border-crossing alert: the single most important event on screen.
        # Surfaces records published at the data's real precision rather than the
        # finer chosen grid: clamped because the chosen level was finer than the
        # data (Chapman: generalization never increases precision) or preserved
        # because already generalized upstream (ADR-095). Without this the
        # behaviour was silent.
        shiny::observeEvent(input$go_fix_coords, {
            if (is.function(on_navigate)) on_navigate("validate_coords")
        }, ignoreInit = TRUE)

        # ---- Grid chips under the decision table ----------------------------
        # The what-if preview: a click draws every sensitive point at that
        # category until "Show actual decision".

        # ---- Legend under the map ------------------------------------------
        # Point fill = the MMA threat group, once the group has a decision;
        # white while it waits. Cells are neutral, a dashed red one leaves the
        # country (ADR-132).

        # ---- Hero map -----------------------------------------------------
        # Keep the map live while its tab is hidden so leafletProxy repaints
        # (e.g. an origin marker corrected on the Coords tab) are applied instead
        # of dropped, otherwise the stale point lingers until a full re-render.


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
            lat <- as_coord_numeric(df$decimalLatitude)$num
            lon <- as_coord_numeric(df$decimalLongitude)$num
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
                    # leaflet-hex.js draws the point as a hexagon (ADR-160).
                    # The uncertainty circle above stays round: its radius is
                    # a distance on the ground.
                    options = leaflet::pathOptions(hex = TRUE),
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
            lat <- as_coord_numeric(df$decimalLatitude)$num
            lon <- as_coord_numeric(df$decimalLongitude)$num
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
        presentation <- mount_mod_sensitive_coords_presentation(
            actual_preview_r = actual_preview_r,
            exc_species_rv = exc_species_rv,
            exc_tier_r = exc_tier_r,
            group_answers_rv = group_answers_rv,
            input = input,
            justification_missing_r = justification_missing_r,
            justification_rv = justification_rv,
            lang_r = lang_r,
            mode_rv = mode_rv,
            ns = ns,
            output = output,
            preview_tier_rv = preview_tier_rv,
            review_date_rv = review_date_rv,
            sensitive_overview = sensitive_overview,
            sensitive_species_overview = sensitive_species_overview,
            session = session,
            species_levels_r = species_levels_r,
            species_overrides_rv = species_overrides_rv,
            on_navigate = on_navigate
        )
        badge_for_tier <- presentation$badge_for_tier
        level_compact <- presentation$level_compact
        threat_pill <- presentation$threat_pill
        level_chip <- presentation$level_chip
        gen_popup <- presentation$gen_popup

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
