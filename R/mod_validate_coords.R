
#' One fix in the coordinates toolbar: icon, short label and action
#'
#' The full sentence and an example ride in the tooltip, so the fixes fit the
#' toolbar row (ADR-132).
#' @noRd
coords_fix_chip <- function(applied, icon, label, detail, button) {
    shiny::div(
        class = paste("coords-transposed-card coords-fix-chip", if (applied) "is-applied" else ""),
        title = detail,
        ph_icon(if (applied) "circle-check" else icon),
        shiny::span(class = "coords-transposed-title", label),
        if (!applied) button
    )
}

#' Validate Coordinates Module Server
#'
#' @param id Module ID
#' @param mapped_data_r Reactive data frame with mapped data
#' @param lang_r Reactive language value
#' @param validation_gate_r Optional lightweight coordinate gate reactive
#' @param reset_signal_r Optional reactive reset signal from the mapping module.
#'   When it fires, module-local state and inputs are cleared.
#' @return A reactive with legacy attributes by default, or a named list of
#'   reactives when return_contract is \code{"list"}.
#' @param return_contract Return a legacy reactive (default) or a named list of reactives.
#' @export
mod_validate_coords_server <- function(id, mapped_data_r, lang_r, validation_gate_r = NULL, reset_signal_r = NULL, return_contract = c("legacy", "list")) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        notify_saira <- function(message, type = "message", duration = NULL, key = NULL) {
            if (is.null(duration)) {
                duration <- switch(type,
                    error = 7,
                    warning = 5,
                    message = 4,
                    4
                )
            }
            notification_id <- if (!is.null(key) && nzchar(key)) ns(paste0("notif_", key)) else NULL
            shiny::showNotification(ui = message, type = type, duration = duration, id = notification_id)
        }

        coord_filter_values <- c("all", "problems", "validity", "sea", "zero_equal", "reference", "edited")
        coord_validation_r <- shiny::reactiveVal(NULL)
        # Coordinates fixed by hand in the table, one row per record (ADR-129):
        # occurrenceID, row_index, the new decimalLatitude/decimalLongitude and
        # the diagnosis of the revalidated point. Kept apart from
        # rv$coords_corrections so validating again does not erase them.
        manual_edits_rv <- shiny::reactiveVal(NULL)

        rv <- shiny::reactiveValues(
            starting = FALSE,
            running = FALSE,
            start_requested = FALSE,
            run_requested = FALSE,
            stream_filter = "all",
            last_run_status = "idle",
            transposed_table = NULL,     # data.frame of correctable rows (preview)
            outside_table = NULL,        # rows outside the informed country, no fix
            transposed_applied = FALSE,
            coords_corrections = NULL,    # transposed payload applied at export
            validated_coords = NULL,      # the lat/lon text the last validation read
            country_fill_table = NULL,    # data.frame of fillable rows (preview)
            country_fill_applied = FALSE,
            country_fills = NULL,         # country-fill payload applied at export
            swap_fill_table = NULL,       # blank-country sea points fixable by swap
            swap_fill_applied = FALSE,
            utm_rows = NULL,              # row indices carrying projected (UTM) pairs
            utm_axes = NULL,              # resolved easting/northing for those rows
            utm_candidates = NULL,        # ranked zone candidates, best first
            utm_applied = FALSE
        )

        normalize_gate <- function(gate) {
            if (!is.list(gate)) {
                return(NULL)
            }
            has_coords_contract <- !is.null(gate$coords_status) ||
                !is.null(gate$lat_col) ||
                !is.null(gate$lon_col) ||
                !is.null(gate$country_col)
            if (!isTRUE(has_coords_contract)) {
                return(NULL)
            }

            status <- tolower(as.character(gate$coords_status %||% "missing_multiple"))
            status <- if (length(status) > 0L) status[[1]] else "missing_multiple"
            if (!(status %in% c("ok", "no_data", "missing_lat", "missing_lon", "missing_country", "missing_multiple"))) {
                status <- "missing_multiple"
            }

            pick_scalar <- function(x) {
                out <- as.character(x)
                out <- out[!is.na(out) & nzchar(out)]
                if (length(out) == 0L) "" else out[[1]]
            }

            list(
                status = status,
                has_data = isTRUE(gate$has_data),
                lat_col = pick_scalar(gate$lat_col),
                lon_col = pick_scalar(gate$lon_col),
                country_col = pick_scalar(gate$country_col),
                country_is_constant = isTRUE(gate$country_is_constant),
                has_lat = isTRUE(gate$has_lat),
                has_lon = isTRUE(gate$has_lon),
                has_country = isTRUE(gate$has_country)
            )
        }

        quick_gate <- shiny::reactive({
            if (!is.null(validation_gate_r) && shiny::is.reactive(validation_gate_r)) {
                gate_from_attr <- normalize_gate(validation_gate_r())
                if (!is.null(gate_from_attr)) {
                    return(gate_from_attr)
                }
            }

            df <- mapped_data_r()
            if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
                return(list(
                    status = "no_data",
                    has_data = FALSE,
                    lat_col = "",
                    lon_col = "",
                    country_col = "",
                    country_is_constant = FALSE,
                    has_lat = FALSE,
                    has_lon = FALSE,
                    has_country = FALSE
                ))
            }

            has_lat <- "decimalLatitude" %in% names(df)
            has_lon <- "decimalLongitude" %in% names(df)
            has_country <- "country" %in% names(df)
            missing_count <- sum(!c(has_lat, has_lon, has_country))

            status <- if (missing_count == 0L) {
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
                status = status,
                has_data = TRUE,
                lat_col = if (has_lat) "decimalLatitude" else "",
                lon_col = if (has_lon) "decimalLongitude" else "",
                country_col = if (has_country) "country" else "",
                country_is_constant = FALSE,
                has_lat = has_lat,
                has_lon = has_lon,
                has_country = has_country
            )
        })

        active_filter <- shiny::reactive({
            key <- as.character(rv$stream_filter)
            key <- key[!is.na(key) & nzchar(key)]
            if (length(key) == 0L) {
                return("all")
            }
            key <- key[[1]]
            if (!(key %in% coord_filter_values)) {
                return("all")
            }
            key
        })

        # Overlay accepted corrections onto the raw validation result so the
        # map, table and pill counts all show the published point (mirrors what
        # Generalization and export apply). Single source feeding all three.
        effective_validation_r <- shiny::reactive({
            res <- coord_validation_r()
            if (is.null(res)) {
                return(res)
            }
            res <- apply_coord_corrections_to_result(
                res,
                coords_corrections = rv$coords_corrections,
                country_fills = rv$country_fills,
                occ_ids = rv$validation_occ_ids
            )
            apply_manual_coord_edits_to_result(res, manual_edits_rv())
        })

        filtered_result_r <- shiny::reactive({
            res <- effective_validation_r()
            shiny::req(res)
            key <- active_filter()

            if (!is.data.frame(res) || !"diagnostic_family" %in% names(res)) {
                return(res)
            }

            fam <- as.character(res$diagnostic_family)
            fam[is.na(fam) | !nzchar(fam)] <- "validity"
            keep <- switch(key,
                all = rep(TRUE, nrow(res)),
                problems = fam != "ok",
                validity = fam == "validity",
                sea = fam == "sea",
                zero_equal = fam == "zero_equal",
                reference = fam == "reference",
                edited = res$edited %in% TRUE,
                rep(TRUE, nrow(res))
            )

            out <- res[keep, , drop = FALSE]
            rownames(out) <- NULL
            out
        }) |> shiny::bindCache(effective_validation_r(), active_filter())

        family_counts <- shiny::reactive({
            res <- effective_validation_r()
            if (is.null(res) || !is.data.frame(res) || nrow(res) == 0L) {
                return(c(
                    all = 0L,
                    problems = 0L,
                    validity = 0L,
                    sea = 0L,
                    zero_equal = 0L,
                    reference = 0L,
                    edited = 0L
                ))
            }

            counts <- count_coords_diagnostics(res)
            c(
                all = as.integer(counts$total %||% 0L),
                problems = as.integer(counts$problems %||% 0L),
                validity = as.integer(counts$validity %||% 0L),
                sea = as.integer(counts$sea %||% 0L),
                zero_equal = as.integer(counts$zero_equal %||% 0L),
                reference = as.integer(counts$reference %||% 0L),
                edited = sum(res$edited %in% TRUE)
            )
        })

        map_data_r <- shiny::reactive({
            res <- effective_validation_r()
            shiny::req(res)
            labels <- map_labels()
            build_leaflet_data(
                coords_result_df = res,
                filter = active_filter(),
                issue_labels = labels$issue,
                popup_labels = labels$popup
            )
        })

        for (filter_key in coord_filter_values) {
            local({
                key_local <- filter_key
                shiny::observeEvent(input[[paste0("coords_filter_", key_local)]],
                    {
                        rv$stream_filter <- key_local
                    },
                    ignoreInit = TRUE
                )
            })
        }

        can_run_validation <- shiny::reactive({
            gate <- quick_gate()
            identical(gate$status, "ok") && !isTRUE(rv$running) && !isTRUE(rv$starting)
        })

        # stats_panel removed: the four count boxes duplicated the filter pill
        # counts above the map. The left column now hosts the transposed-coords
        # correction card instead.

        shiny::observeEvent(input$map_show_hidden, {
            rv$stream_filter <- "validity"
        })

        # NOTE: depend only on coord_validation_r() here. This renderUI hosts the
        # leafletOutput, so any extra reactive dependency (e.g. on corrections
        # or the language) would recreate the map widget mid-session and break
        # proxy repaints. Translated text lives in map_legend for this reason.

        # Markers travel through a proxy, and Leaflet drops a proxy call made
        # before the widget exists, which left the map empty after each run
        # until a filter was clicked. The map reports its bounds once drawn,
        # so that first report marks it ready and triggers the first draw.
        map_ready <- shiny::reactiveVal(FALSE)
        shiny::observeEvent(input$coords_map_bounds, map_ready(TRUE), ignoreInit = TRUE)
        shiny::observeEvent(coord_validation_r(), {
            if (is.null(coord_validation_r())) map_ready(FALSE)
        }, ignoreNULL = FALSE)

        shiny::bindEvent(
            shiny::observe({
                res <- coord_validation_r()
                shiny::req(res, map_ready())
                draw_markers(map_data_r())
            }),
            # Not effective_validation_r(): a manual edit moves its own marker
            # (refresh_marker below) and must not redraw or re-zoom the map.
            coord_validation_r(),
            rv$coords_corrections,
            rv$country_fills,
            active_filter(),
            map_ready()
        )

        # The popups carry translated labels. Keep the view the user chose.
        shiny::observeEvent(lang_r(), {
            shiny::req(coord_validation_r(), map_ready())
            draw_markers(map_data_r(), fit_view = FALSE)
        }, ignoreInit = TRUE)

        # One row per record: badge, point, country. Built for the first render
        # and again for each proxy update after a manual edit.

        # The rows the table shows. It changes with a new validation, a filter
        # or a bulk correction, never with a manual edit: an edit patches the
        # rendered rows through the proxy, so the page, the sort order and the
        # search stay where the person left them (ADR-129).
        table_base_r <- shiny::reactive({
            coord_validation_r()
            active_filter()
            rv$coords_corrections
            rv$country_fills
            shiny::isolate(filtered_result_r())
        })
        table_proxy <- DT::dataTableProxy("issues_table")

        # "Show in table": select the row and open its page. The page comes
        # from the order and search the table shows now; a search that hides
        # the row is cleared first.
        shiny::observeEvent(input$locate_row, {
            base <- table_base_r()
            i <- match(as.integer(input$locate_row$row), base$.row_index)
            if (is.na(i)) return(invisible(NULL))
            shown <- input$issues_table_rows_all
            if (!i %in% shown) {
                DT::updateSearch(table_proxy, keywords = list(global = ""))
                shown <- seq_len(nrow(base))
            }
            per_page <- suppressWarnings(as.integer(input$locate_row$len))
            if (length(per_page) != 1L || is.na(per_page) || per_page < 1L) per_page <- 10L
            DT::selectRows(table_proxy, i)
            DT::selectPage(table_proxy, ceiling(match(i, shown) / per_page))
        }, ignoreInit = TRUE)

        # A double-clicked latitude or longitude, typed and confirmed with
        # Enter. The value is checked, the point revalidated, and the edit
        # stored by occurrenceID.
        shiny::observeEvent(input$issues_table_cell_edit, {
            info <- input$issues_table_cell_edit
            base <- table_base_r()
            row_pos <- suppressWarnings(as.integer(info$row))
            if (!is.data.frame(base) || length(row_pos) != 1L || is.na(row_pos) ||
                    row_pos < 1L || row_pos > nrow(base)) {
                return(invisible(NULL))
            }
            axis <- if (identical(as.integer(info$col), 2L)) "lat" else if (identical(as.integer(info$col), 3L)) "lon" else NA
            if (is.na(axis)) return(invisible(NULL))

            row_index <- base$.row_index[[row_pos]]
            occ_ids <- rv$validation_occ_ids
            occ <- if (length(occ_ids) >= row_index) occ_ids[[row_index]] else NA_character_
            if (!isTRUE(coords_edit_allowed(occ_ids)[row_index])) {
                notify_saira(tr("validate_coords_edit_blocked_id", lang_r()), type = "warning", key = "coords_edit")
                refresh_table_rows()
                return(invisible(NULL))
            }

            parsed <- parse_coord_edit(info$value, axis)
            if (!is.null(parsed$error)) {
                notify_saira(tr(parsed$error, lang_r()), type = "error", key = "coords_edit")
                refresh_table_rows()
                return(invisible(NULL))
            }

            eff <- effective_validation_r()
            current <- eff[match(row_index, eff$.row_index), , drop = FALSE]
            lat_new <- if (axis == "lat") parsed$value else current$lat_num[[1]]
            lon_new <- if (axis == "lon") parsed$value else current$lon_num[[1]]

            df <- mapped_data_r()
            row_df <- df[row_index, c("decimalLatitude", "decimalLongitude", "country"), drop = FALSE]
            row_df$decimalLatitude <- as.character(lat_new)
            row_df$decimalLongitude <- as.character(lon_new)
            reval <- tryCatch(
                revalidate_coord_rows(row_df, row_index = row_index, profile = "complete"),
                error = function(e) NULL
            )
            if (!is.data.frame(reval) || nrow(reval) != 1L) {
                notify_saira(tr("validate_coords_edit_failed", lang_r()), type = "error", key = "coords_edit")
                refresh_table_rows()
                return(invisible(NULL))
            }

            new_row <- data.frame(
                occurrenceID = as.character(occ),
                row_index = as.integer(row_index),
                decimalLatitude = as.character(lat_new),
                decimalLongitude = as.character(lon_new),
                diagnostic = as.character(reval$diagnostic[[1]]),
                diagnostic_family = as.character(reval$diagnostic_family[[1]]),
                valid = isTRUE(reval$valid[[1]]),
                stringsAsFactors = FALSE
            )
            new_row <- with_coord_source(new_row)
            edits <- manual_edits_rv()
            edits <- if (is.data.frame(edits)) {
                rbind(edits[edits$row_index != row_index, , drop = FALSE], new_row)
            } else {
                new_row
            }
            manual_edits_rv(edits)
            refresh_table_rows()
            refresh_marker(row_index)

            if (identical(new_row$diagnostic_family, "ok")) {
                notify_saira(tr("validate_coords_edit_saved_ok", lang_r()), type = "message", key = "coords_edit")
            } else {
                notify_saira(
                    sprintf(tr("validate_coords_edit_saved_issue", lang_r()),
                            tr(diag_label_key(new_row$diagnostic), lang_r())),
                    type = "warning", key = "coords_edit"
                )
            }
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$undo_edit, {
            row_index <- suppressWarnings(as.integer(input$undo_edit))
            edits <- manual_edits_rv()
            if (!is.data.frame(edits) || is.na(row_index) || !row_index %in% edits$row_index) {
                return(invisible(NULL))
            }
            edits <- edits[edits$row_index != row_index, , drop = FALSE]
            manual_edits_rv(if (nrow(edits) == 0L) NULL else edits)
            refresh_table_rows()
            refresh_marker(row_index)
            notify_saira(tr("validate_coords_edit_undone", lang_r()), type = "message", key = "coords_edit")
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$validate,
            {
                if (isTRUE(rv$running) || isTRUE(rv$starting)) {
                    return(invisible(NULL))
                }

                gate <- quick_gate()
                if (!identical(gate$status, "ok")) {
                    msg <- switch(gate$status,
                        no_data = tr("validate_coords_no_data", lang_r()),
                        missing_lat = tr("validate_coords_lat_missing", lang_r()),
                        missing_lon = tr("validate_coords_lon_missing", lang_r()),
                        missing_country = tr("validate_coords_country_missing", lang_r()),
                        tr("validate_coords_missing_multiple", lang_r())
                    )
                    notify_saira(message = msg, type = "warning", key = "coords_gate")
                    return(invisible(NULL))
                }

                rv$starting <- TRUE
                rv$last_run_status <- "starting"
                coord_validation_r(NULL)
                rv$stream_filter <- "all"

                rv$start_requested <- TRUE
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(rv$start_requested,
            {
                if (!isTRUE(rv$start_requested)) {
                    return(invisible(NULL))
                }
                rv$start_requested <- FALSE
                rv$running <- TRUE
                rv$starting <- FALSE
                rv$last_run_status <- "running"
                df <- mapped_data_r()
                session$sendCustomMessage("coordsRun", list(
                    stage = "start",
                    id = ns("run_stage"),
                    progress = coords_run_progress(1L, integer(0), if (is.data.frame(df)) nrow(df) else 0L, lang_r())
                ))

                session$onFlushed(function() {
                    rv$run_requested <- TRUE
                }, once = TRUE)
            },
            ignoreInit = FALSE
        )

        shiny::observeEvent(rv$run_requested,
            {
                if (!isTRUE(rv$run_requested)) {
                    return(invisible(NULL))
                }
                rv$run_requested <- FALSE
                # Registered before the early return, so the run stage never
                # stays on the page.
                on.exit(
                    {
                        session$sendCustomMessage("coordsRun", list(
                            stage = "end",
                            failed = !identical(rv$last_run_status, "success")
                        ))
                        rv$running <- FALSE
                    },
                    add = TRUE
                )
                if (!isTRUE(rv$running)) {
                    return(invisible(NULL))
                }

                result <- tryCatch(
                    {
                        df <- mapped_data_r()
                        if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
                            stop(tr("validate_coords_no_data", lang_r()))
                        }
                        if (!all(c("decimalLatitude", "decimalLongitude", "country") %in% names(df))) {
                            stop(tr("validate_coords_missing_multiple", lang_r()))
                        }

                        profile_value <- "complete"

                        validate_coords_cc_df(
                            df = df,
                            lat_col = "decimalLatitude",
                            lon_col = "decimalLongitude",
                            country_col = "country",
                            profile = profile_value,
                            seas_scale = 10L,
                            # Custom messages leave at once, even while this
                            # observer holds the session.
                            on_step = coords_run_reporter(
                                function(msg) session$sendCustomMessage("coordsRun", msg),
                                n_records = nrow(df),
                                lang = lang_r()
                            )
                        )
                    },
                    error = function(e) {
                        notify_saira(
                            message = sprintf(tr("validate_coords_failed", lang_r()), as.character(e$message)),
                            type = "error",
                            key = "coords_failed"
                        )
                        NULL
                    }
                )

                if (is.null(result)) {
                    rv$last_run_status <- "failed"
                    return(invisible(NULL))
                }

                coord_validation_r(result)
                rv$stream_filter <- "problems"
                rv$last_run_status <- "success"
                # occurrenceID per row (aligned to .row_index) so accepted
                # corrections can be overlaid back onto this result for display.
                rv$validation_occ_ids <- if ("occurrenceID" %in% names(df)) {
                    as.character(df$occurrenceID)
                } else {
                    character(0)
                }
                rv$validated_coords <- data.frame(
                    decimalLatitude = coord_source_text(df$decimalLatitude),
                    decimalLongitude = coord_source_text(df$decimalLongitude),
                    stringsAsFactors = FALSE
                )

                # Manual edits survive a new validation. The row of each is
                # looked up again by occurrenceID, and an edit whose record
                # left the data is dropped with a notice.
                kept <- drop_orphan_coord_edits(manual_edits_rv(), rv$validation_occ_ids)
                if (is.data.frame(kept$edits)) {
                    kept$edits$row_index <- match(kept$edits$occurrenceID, rv$validation_occ_ids)
                }
                # So is an edit whose point changed after it (AUD-05).
                stale <- stale_coord_rows(kept$edits, df)
                if (any(stale)) {
                    kept$edits <- if (all(stale)) NULL else kept$edits[!stale, , drop = FALSE]
                }
                manual_edits_rv(kept$edits)
                if (kept$dropped > 0L) {
                    notify_saira(
                        sprintf(tr("validate_coords_edit_orphans", lang_r()), kept$dropped),
                        type = "warning", key = "coords_edit_orphans"
                    )
                }
                if (any(stale)) {
                    notify_saira(
                        sprintf(tr("validate_coords_edit_stale", lang_r()), sum(stale)),
                        type = "warning", key = "coords_edit_stale"
                    )
                }

                # Detect transposed / sign-flipped coordinates correctable
                # against the informed country (reuses the same data frame).
                rv$transposed_applied <- FALSE
                rv$coords_corrections <- NULL
                rv$transposed_table <- NULL
                rv$outside_table <- NULL
                tr_res <- tryCatch(
                    coords_transposed_corrections(
                        df,
                        lat_col = "decimalLatitude",
                        lon_col = "decimalLongitude",
                        country_col = "country",
                        # `result` already carries the resolved ISO3, aligned to
                        # .row_index = seq_len(nrow(df)) and never subset or
                        # reordered. Without this argument the function re-runs
                        # the whole country -> ISO3 cascade (iso3c, iso2c, CLDR,
                        # aliases, then a utils::adist matrix against ~3k
                        # aliases) over the same column, seconds after
                        # validate_coords_cc_df() computed exactly that vector.
                        # The parameter exists for this.
                        country_iso3 = result$country_iso3
                    ),
                    error = function(e) NULL
                )
                if (!is.null(tr_res) && isTRUE(tr_res$available) &&
                        tr_res$n_corrected > 0L && "occurrenceID" %in% names(df)) {
                    ci <- which(tr_res$corrected)
                    rv$transposed_table <- data.frame(
                        occurrenceID = as.character(df$occurrenceID)[ci],
                        country = as.character(df$country)[ci],
                        lat_old = as_coord_numeric(df$decimalLatitude)$num[ci],
                        lon_old = as_coord_numeric(df$decimalLongitude)$num[ci],
                        decimalLatitude = tr_res$lat_new[ci],
                        decimalLongitude = tr_res$lon_new[ci],
                        transform = tr_res$transform[ci],
                        stringsAsFactors = FALSE
                    )
                }

                if (!is.null(tr_res) && isTRUE(tr_res$available) && any(tr_res$outside)) {
                    oi <- which(tr_res$outside)
                    rv$outside_table <- data.frame(
                        row = oi,
                        country = as.character(df$country)[oi],
                        lat = as_coord_numeric(df$decimalLatitude)$num[oi],
                        lon = as_coord_numeric(df$decimalLongitude)$num[oi],
                        stringsAsFactors = FALSE
                    )
                }

                # Detect coordinates published in a projected system (UTM)
                # rather than in degrees. They land in validity_bounds above,
                # which is accurate but not actionable: the fix is a conversion,
                # not an edit. The zone cannot be read off the numbers, so this
                # only ranks candidates -- the user confirms one on the map.
                rv$utm_applied <- FALSE
                rv$utm_rows <- NULL
                rv$utm_axes <- NULL
                rv$utm_candidates <- NULL
                utm_mask <- tryCatch(
                    coords_is_projected_pair(df$decimalLatitude, df$decimalLongitude),
                    error = function(e) logical(0)
                )
                if (any(utm_mask) && "occurrenceID" %in% names(df)) {
                    ui <- which(utm_mask)
                    axes <- coords_utm_assign_axes(
                        df$decimalLatitude[ui], df$decimalLongitude[ui]
                    )
                    rv$utm_rows <- ui
                    rv$utm_axes <- axes
                    rv$utm_candidates <- tryCatch(
                        coords_utm_zone_candidates(
                            easting = axes$easting,
                            northing = axes$northing,
                            country_iso3 = result$country_iso3[ui],
                            hemisphere = if (any(axes$northing > 0, na.rm = TRUE)) "S" else "N"
                        ),
                        error = function(e) NULL
                    )
                }

                # Derive country for records missing it from valid coordinates.
                rv$country_fill_applied <- FALSE
                rv$country_fills <- NULL
                rv$country_fill_table <- NULL
                cf_res <- tryCatch(
                    coords_country_from_coordinates(
                        df,
                        lat_col = "decimalLatitude",
                        lon_col = "decimalLongitude",
                        country_col = "country"
                    ),
                    error = function(e) NULL
                )
                if (!is.null(cf_res) && isTRUE(cf_res$available) &&
                        cf_res$n_filled > 0L && "occurrenceID" %in% names(df)) {
                    fi <- which(cf_res$filled)
                    rv$country_fill_table <- data.frame(
                        occurrenceID = as.character(df$occurrenceID)[fi],
                        lat = as_coord_numeric(df$decimalLatitude)$num[fi],
                        lon = as_coord_numeric(df$decimalLongitude)$num[fi],
                        country = cf_res$country_new[fi],
                        stringsAsFactors = FALSE
                    )
                }

                # Combined case: blank country + sea point fixable by a lat/lon
                # swap that lands unambiguously in one country.
                rv$swap_fill_applied <- FALSE
                rv$swap_fill_table <- NULL
                sf_res <- tryCatch(
                    coords_swap_and_fill(
                        df,
                        lat_col = "decimalLatitude",
                        lon_col = "decimalLongitude",
                        country_col = "country"
                    ),
                    error = function(e) NULL
                )
                if (!is.null(sf_res) && isTRUE(sf_res$available) &&
                        sf_res$n > 0L && "occurrenceID" %in% names(df)) {
                    si <- which(sf_res$applies)
                    rv$swap_fill_table <- data.frame(
                        occurrenceID = as.character(df$occurrenceID)[si],
                        lat_old = as_coord_numeric(df$decimalLatitude)$num[si],
                        lon_old = as_coord_numeric(df$decimalLongitude)$num[si],
                        decimalLatitude = sf_res$lat_new[si],
                        decimalLongitude = sf_res$lon_new[si],
                        country = sf_res$country_new[si],
                        stringsAsFactors = FALSE
                    )
                }

                conversion <- attr(result, "conversion_failures")
                total_conversion_failures <- suppressWarnings(as.integer(conversion$total))
                if (length(total_conversion_failures) == 1L &&
                        !is.na(total_conversion_failures) &&
                        total_conversion_failures > 0L) {
                    notify_saira(
                        message = sprintf(tr("validate_coords_conversion_warning", lang_r()), total_conversion_failures),
                        type = "warning",
                        key = "coords_conversion"
                    )
                }
            },
            ignoreInit = FALSE
        )

        # Transposed-coordinate correction panel (shown after validation when
        # one or more records can be corrected against the informed country).

        # Points outside the informed country that no swap or sign fix brings
        # back. Only the person can say which value is wrong, so no button.

        # Projected-coordinate (UTM) conversion panel. Unlike the other cards
        # this one cannot propose a single answer: the same easting/northing is
        # valid in every zone, six degrees of longitude apart, so the user picks
        # the zone and sees the result on the map before applying.
        utm_selected_zone <- shiny::reactive({
            z <- suppressWarnings(as.integer(input$utm_zone))
            if (length(z) != 1L || is.na(z)) {
                cand <- rv$utm_candidates
                if (is.data.frame(cand) && nrow(cand) > 0L) {
                    return(as.integer(cand$zone[[1]]))
                }
                return(NA_integer_)
            }
            z
        })

        utm_selected_datum <- shiny::reactive({
            d <- input$utm_datum
            if (is.null(d) || !nzchar(d)) coords_utm_default_datum() else as.character(d)
        })

        # Rows converted under the current zone/datum pick, ready to apply.
        utm_converted_r <- shiny::reactive({
            rows <- rv$utm_rows
            axes <- rv$utm_axes
            zone <- utm_selected_zone()
            if (is.null(rows) || is.null(axes) || is.na(zone)) {
                return(NULL)
            }
            occ <- rv$validation_occ_ids
            if (is.null(occ) || length(occ) < max(rows)) {
                return(NULL)
            }
            converted <- tryCatch(
                coords_utm_to_wgs84(
                    easting = axes$easting, northing = axes$northing,
                    zone = zone,
                    hemisphere = if (any(axes$northing > 0, na.rm = TRUE)) "S" else "N",
                    datum = utm_selected_datum()
                ),
                error = function(e) NULL
            )
            if (is.null(converted)) {
                return(NULL)
            }
            # The projected pair is the only record of what was published, and
            # the conversion overwrites it. Preserve it under the verbatim terms
            # along with the zone and datum the user confirmed, so the original
            # reading stays reproducible. Axes go to the term they correspond to
            # -- northing to latitude -- rather than to the column they happened
            # to sit in, which in the reported upload was the wrong one.
            label <- coords_utm_srs_label(
                zone = zone,
                hemisphere = if (any(axes$northing > 0, na.rm = TRUE)) "S" else "N",
                datum = utm_selected_datum()
            )

            out <- data.frame(
                occurrenceID = as.character(occ)[rows],
                decimalLatitude = converted$decimalLatitude,
                decimalLongitude = converted$decimalLongitude,
                verbatimLatitude = as.character(axes$northing),
                verbatimLongitude = as.character(axes$easting),
                verbatimCoordinateSystem = if (is.null(label)) NA_character_ else label$system,
                verbatimSRS = if (is.null(label)) NA_character_ else label$srs,
                stringsAsFactors = FALSE
            )
            out[!is.na(out$decimalLatitude) & !is.na(out$decimalLongitude), , drop = FALSE]
        })

        # Each fix keeps the values it replaces, so a later change of the same
        # point drops it from the export (AUD-05, ADR-166).
        with_coord_source <- function(tbl) {
            src <- rv$validated_coords
            i <- match(as.character(tbl$occurrenceID), rv$validation_occ_ids)
            tbl$from_decimalLatitude <- if (is.data.frame(src)) src$decimalLatitude[i] else NA_character_
            tbl$from_decimalLongitude <- if (is.data.frame(src)) src$decimalLongitude[i] else NA_character_
            tbl
        }

        # Payload merge helpers: the transposed, swap-fill and country cards act
        # on disjoint rows but two of them write coordinate/country payloads, so
        # we accumulate (dedupe by occurrenceID) instead of overwriting.
        merge_coords_corrections <- function(new_df) {
            new_df <- with_coord_source(new_df)
            cur <- rv$coords_corrections$corrections
            # The UTM card carries verbatim columns the other cards do not, so
            # the two payloads no longer share a column set. Align on the union
            # before stacking; a card that never writes a column leaves it NA.
            merged <- if (is.null(cur)) {
                new_df
            } else {
                all_cols <- union(names(cur), names(new_df))
                fill <- function(d) {
                    for (cl in setdiff(all_cols, names(d))) d[[cl]] <- NA_character_
                    d[, all_cols, drop = FALSE]
                }
                rbind(fill(cur), fill(new_df))
            }
            merged <- merged[!duplicated(merged$occurrenceID, fromLast = TRUE), , drop = FALSE]
            rv$coords_corrections <- list(corrections = merged)
        }
        merge_country_fills <- function(new_df) {
            new_df <- with_coord_source(new_df)
            cur <- rv$country_fills$country
            merged <- if (is.null(cur)) new_df else rbind(cur, new_df)
            merged <- merged[!duplicated(merged$occurrenceID, fromLast = TRUE), , drop = FALSE]
            rv$country_fills <- list(country = merged)
        }

        shiny::observeEvent(input$apply_utm, {
            tbl <- utm_converted_r()
            if (is.null(tbl) || nrow(tbl) == 0L) return(invisible(NULL))
            merge_coords_corrections(tbl)
            rv$utm_applied <- TRUE
            notify_saira(
                message = sprintf(tr("validate_coords_utm_applied", lang_r()), nrow(tbl)),
                type = "message",
                key = "coords_utm_applied"
            )
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$apply_transposed, {
            tbl <- rv$transposed_table
            if (is.null(tbl) || nrow(tbl) == 0L) return(invisible(NULL))
            merge_coords_corrections(
                tbl[, c("occurrenceID", "decimalLatitude", "decimalLongitude"), drop = FALSE]
            )
            rv$transposed_applied <- TRUE
            notify_saira(
                message = sprintf(tr("validate_coords_transposed_applied", lang_r()), nrow(tbl)),
                type = "message",
                key = "coords_transposed_applied"
            )
        }, ignoreInit = TRUE)

        # Combined swap + country-fill panel (blank country, sea point).

        shiny::observeEvent(input$apply_swap_fill, {
            tbl <- rv$swap_fill_table
            if (is.null(tbl) || nrow(tbl) == 0L) return(invisible(NULL))
            merge_coords_corrections(
                tbl[, c("occurrenceID", "decimalLatitude", "decimalLongitude"), drop = FALSE]
            )
            merge_country_fills(tbl[, c("occurrenceID", "country"), drop = FALSE])
            rv$swap_fill_applied <- TRUE
            notify_saira(
                message = sprintf(tr("validate_coords_swapfill_applied", lang_r()), nrow(tbl)),
                type = "message",
                key = "coords_swapfill_applied"
            )
        }, ignoreInit = TRUE)

        # Country-from-coordinates fill panel.

        shiny::observeEvent(input$apply_country_fill, {
            tbl <- rv$country_fill_table
            if (is.null(tbl) || nrow(tbl) == 0L) return(invisible(NULL))
            merge_country_fills(tbl[, c("occurrenceID", "country"), drop = FALSE])
            rv$country_fill_applied <- TRUE
            notify_saira(
                message = sprintf(tr("validate_coords_country_filled", lang_r()), nrow(tbl)),
                type = "message",
                key = "coords_country_filled"
            )
        }, ignoreInit = TRUE)

        # A re-upload or a confirmed Mapping reset invalidates the dataset
        # baseline: drop the validation result and every pending/applied
        # correction so nothing from the previous dataset carries over.
        if (!is.null(reset_signal_r)) {
            shiny::observeEvent(reset_signal_r(), {
                coord_validation_r(NULL)
                rv$stream_filter <- "all"
                rv$last_run_status <- "idle"
                rv$transposed_table <- NULL
                rv$outside_table <- NULL
                rv$transposed_applied <- FALSE
                rv$coords_corrections <- NULL
                rv$validated_coords <- NULL
                rv$country_fill_table <- NULL
                rv$country_fill_applied <- FALSE
                rv$country_fills <- NULL
                rv$swap_fill_table <- NULL
                rv$swap_fill_applied <- FALSE
                rv$utm_rows <- NULL
                rv$utm_axes <- NULL
                rv$utm_candidates <- NULL
                rv$utm_applied <- FALSE
                manual_edits_rv(NULL)
                rv$starting <- FALSE
                rv$running <- FALSE
                rv$start_requested <- FALSE
                rv$run_requested <- FALSE
            }, ignoreInit = TRUE)
        }

        presentation <- mount_mod_validate_coords_presentation(
            active_filter = active_filter,
            can_run_validation = can_run_validation,
            coord_validation_r = coord_validation_r,
            effective_validation_r = effective_validation_r,
            family_counts = family_counts,
            input = input,
            lang_r = lang_r,
            map_data_r = map_data_r,
            ns = ns,
            output = output,
            quick_gate = quick_gate,
            session = session,
            table_base_r = table_base_r,
            table_proxy = table_proxy,
            utm_converted_r = utm_converted_r,
            view = list(
                country_fill_applied = shiny::reactive(rv$country_fill_applied),
                country_fill_table = shiny::reactive(rv$country_fill_table),
                outside_table = shiny::reactive(rv$outside_table),
                running = shiny::reactive(rv$running),
                starting = shiny::reactive(rv$starting),
                swap_fill_applied = shiny::reactive(rv$swap_fill_applied),
                swap_fill_table = shiny::reactive(rv$swap_fill_table),
                transposed_applied = shiny::reactive(rv$transposed_applied),
                transposed_table = shiny::reactive(rv$transposed_table),
                utm_applied = shiny::reactive(rv$utm_applied),
                utm_candidates = shiny::reactive(rv$utm_candidates),
                utm_rows = shiny::reactive(rv$utm_rows)
            ),
            filtered_result_r = filtered_result_r
        )
        map_labels <- presentation$map_labels
        draw_markers <- presentation$draw_markers
        refresh_marker <- presentation$refresh_marker
        diag_label_key <- presentation$diag_label_key
        diag_badge_class <- presentation$diag_badge_class
        build_issues_table_df <- presentation$build_issues_table_df
        refresh_table_rows <- presentation$refresh_table_rows

        result_r <- shiny::reactive(coord_validation_r())
        # Generalization, Export and the summary read this one payload, so the
        # manual edits reach them with no change in app_server.R (ADR-129).
        corrections_r <- shiny::reactive({
            edits <- manual_edits_rv()
            manual <- if (is.data.frame(edits)) {
                keep <- c("occurrenceID", "decimalLatitude", "decimalLongitude", coord_source_cols)
                edits[, intersect(keep, names(edits)), drop = FALSE]
            } else {
                NULL
            }
            payload <- merge_manual_coord_edits(rv$coords_corrections, manual)
            if (!is.list(payload) || !is.data.frame(payload$corrections) ||
                    nrow(payload$corrections) == 0L) {
                return(payload)
            }
            drop_stale_coord_corrections(payload, mapped_data_r())
        })
        country_r <- shiny::reactive(reconcile_country_fill(rv$country_fills, mapped_data_r()))
        module_result_return(
            new_module_result(result_r, filtered_data_r = filtered_result_r, active_filter_r = active_filter, corrections_r = corrections_r, country_r = country_r),
            c("filtered_data" = "filtered_data_r", "active_filter" = "active_filter_r", "coords_correction_payload" = "corrections_r", "country_fill_payload" = "country_r"), return_contract
        )
    })
}
