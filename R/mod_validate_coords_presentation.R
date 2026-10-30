# Title: Validate Coordinates Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-21
# Version: 3.0

#' Validate Coordinates Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_validate_coords_ui <- function(id) {
    ns <- shiny::NS(id)

    shiny::tagList(
        shiny::div(
            class = "container-fluid validate-coords-page",
            # One toolbar on top holds the column check, the run button and the
            # fixes, so the map and the table get the full width (ADR-132).
            shiny::div(
                class = "validate-coords-toolbar",
                shiny::uiOutput(ns("action_card")),
                shiny::uiOutput(ns("transposed_panel")),
                shiny::uiOutput(ns("outside_panel")),
                shiny::uiOutput(ns("swap_fill_panel")),
                shiny::uiOutput(ns("country_panel"))
            ),
            shiny::uiOutput(ns("utm_panel")),
            shiny::div(
                class = "validate-coords-layout",
                # Run stage (ADR-160): run-progress.js shows it during a run
                # and draws the radar. It covers the results until it fades.
                shiny::div(
                    id = ns("run_stage"),
                    class = "coords-run-stage",
                    hidden = NA,
                    shiny::div(
                        class = "coords-run-map",
                        shiny::tags$canvas(role = "img")
                    ),
                    shiny::div(
                        class = "vn-run-body coords-run-body",
                        `aria-live` = "polite",
                        shiny::div(class = "vn-run-eyebrow"),
                        shiny::p(class = "vn-run-count"),
                        shiny::div(class = "vn-run-bar", shiny::div(class = "vn-run-bar-fill")),
                        shiny::div(class = "vn-run-steps")
                    )
                ),
                shiny::div(
                    class = "validate-coords-right",
                    shiny::uiOutput(ns("pre_right_hint")),
                    shiny::uiOutput(ns("filter_pills")),
                    shiny::div(
                        class = "row g-3 validate-coords-results-row",
                        shiny::div(
                            class = "col-12 col-lg-6 validate-coords-map-col",
                            shiny::uiOutput(ns("map_panel"))
                        ),
                        shiny::div(
                            class = "col-12 col-lg-6 validate-coords-table-col",
                            shiny::uiOutput(ns("table_panel"))
                        )
                    )
                )
            )
        ),
        # The undo link lives inside re-rendered table cells, so one delegated
        # handler serves every row (same pattern as the names review links).
        shiny::tags$script(module_behavior_html("coordsEditUndo", list(undoId = ns("undo_edit")))),
        # "Show in table" in a map popup sends the row to the server, which
        # pages the table to it (the table is server-side, so the browser only
        # holds the current page). A capture listener: Leaflet stops click
        # propagation out of popups.
        shiny::tags$script(module_behavior_html(
            "coordsShowRow", list(tableId = ns("issues_table"), locateId = ns("locate_row"))
        ))
    )
}

# mod_validate_coords presentation. Views expose reactive reads; controllers own mutations.

mount_mod_validate_coords_presentation <- function(
    active_filter, can_run_validation, coord_validation_r, effective_validation_r,
    family_counts, input, lang_r, map_data_r,
    ns, output, quick_gate, session,
    table_base_r, table_proxy, utm_converted_r, view,
    filtered_result_r
) {
    map_labels <- function() {
        label_keys <- c(
            ok = "validate_coords_diag_ok",
            validity_missing = "validate_coords_diag_validity_missing",
            validity_bounds = "validate_coords_diag_validity_bounds",
            swapped = "validate_coords_diag_swapped",
            sea = "validate_coords_diag_sea",
            zero_equal = "validate_coords_diag_zero_equal",
            identical_all = "validate_coords_diag_identical_all",
            reference = "validate_coords_diag_reference",
            corrected = "validate_coords_diag_corrected"
        )
        issue_labels <- vapply(label_keys, function(k) tr(k, lang_r()), FUN.VALUE = character(1))
        popup_labels <- list(
            row = tr("validate_coords_popup_row", lang_r()),
            issue = tr("validate_coords_popup_issue", lang_r()),
            lat = tr("validate_coords_col_lat", lang_r()),
            lon = tr("validate_coords_col_lon", lang_r()),
            show_row = tr("validate_coords_popup_show_row", lang_r())
        )
        list(issue = issue_labels, popup = popup_labels)
    }

    output$action_card <- shiny::renderUI({
        gate <- quick_gate()
        is_busy <- isTRUE(view$running()) || isTRUE(view$starting())
        run_label <- if (is_busy) tr("validate_coords_run_running", lang_r()) else tr("validate_coords_run", lang_r())

        lat_ok <- isTRUE(gate$has_lat)
        lon_ok <- isTRUE(gate$has_lon)
        country_ok <- isTRUE(gate$has_country)

        lat_desc <- if (lat_ok) as.character(gate$lat_col) else tr("validate_coords_status_not_mapped", lang_r())
        lon_desc <- if (lon_ok) as.character(gate$lon_col) else tr("validate_coords_status_not_mapped", lang_r())
        # A fixed value is not a column, so name it as what it is instead of
        # printing "Brasil" where the other two rows print a column name.
        country_desc <- if (!country_ok) {
            tr("validate_coords_status_not_mapped", lang_r())
        } else if (isTRUE(gate$country_is_constant)) {
            sprintf(
                tr("validate_coords_status_fixed_value", lang_r()),
                as.character(gate$country_col)
            )
        } else {
            as.character(gate$country_col)
        }

        helper_text <- switch(gate$status,
            no_data = tr("validate_coords_no_data", lang_r()),
            missing_lat = tr("validate_coords_lat_missing", lang_r()),
            missing_lon = tr("validate_coords_lon_missing", lang_r()),
            missing_country = tr("validate_coords_country_missing", lang_r()),
            missing_multiple = tr("validate_coords_missing_multiple", lang_r()),
            ""
        )

        shiny::div(
            class = "coords-toolbar-config",
            shiny::div(
                class = "coords-toolbar-config-row",
                shiny::div(
                    class = "coords-gate-list",
                    shiny::div(
                        class = "coords-gate-item",
                        shiny::span(class = "coords-gate-label", tr("validate_coords_status_lat", lang_r())),
                        shiny::span(class = paste("coords-gate-value", if (lat_ok) "coords-gate-ok" else "coords-gate-missing"), lat_desc)
                    ),
                    shiny::div(
                        class = "coords-gate-item",
                        shiny::span(class = "coords-gate-label", tr("validate_coords_status_lon", lang_r())),
                        shiny::span(class = paste("coords-gate-value", if (lon_ok) "coords-gate-ok" else "coords-gate-missing"), lon_desc)
                    ),
                    shiny::div(
                        class = "coords-gate-item",
                        shiny::span(class = "coords-gate-label", tr("validate_coords_status_country", lang_r())),
                        shiny::span(class = paste("coords-gate-value", if (country_ok) "coords-gate-ok" else "coords-gate-missing"), country_desc)
                    )
                ),
                shiny::actionButton(
                    inputId = ns("validate"),
                    label = run_label,
                    icon = ph_icon(if (is_busy) "spinner" else "play", class = if (is_busy) "ph-spin" else ""),
                    class = "btn-primary",
                    disabled = !isTRUE(can_run_validation())
                )
            ),
            if (nzchar(helper_text)) {
                shiny::div(class = "validate-action-help", helper_text)
            }
        )
    })

    output$pre_right_hint <- shiny::renderUI({
        if (isTRUE(view$running()) || isTRUE(view$starting()) || !is.null(coord_validation_r())) {
            return(NULL)
        }
        shiny::div(
            class = "validate-pre-right",
            shiny::div(
                class = "validate-ready-hint",
                ph_icon("circle-info"),
                shiny::div(
                    shiny::p(
                        class = "mb-0",
                        tr("validate_coords_pre_hint_prefix", lang_r()),
                        shiny::strong("decimalLatitude"),
                        ", ",
                        shiny::strong("decimalLongitude"),
                        " e ",
                        shiny::strong("country"),
                        tr("validate_coords_pre_hint_suffix", lang_r())
                    )
                )
            )
        )
    })

    output$filter_pills <- shiny::renderUI({
        res <- coord_validation_r()
        if (is.null(res) || !is.data.frame(res) || nrow(res) == 0L) {
            return(NULL)
        }

        counts <- family_counts()
        active_key <- active_filter()
        # Active-state colours mirror the map legend dots so each pill reads
        # as its category: validity = error, sea = info, zero_equal =
        # warning, reference = swapped/purple. "all" is the neutral reset
        # (muted) and "problems" the primary accent, so the six are distinct.
        pill_defs <- list(
            list(key = "all", class = "pill-muted", label_key = "validate_coords_filter_all"),
            list(key = "problems", class = "pill-problems", label_key = "validate_coords_filter_problems"),
            list(key = "validity", class = "pill-error", label_key = "validate_coords_filter_validity"),
            list(key = "sea", class = "pill-info", label_key = "validate_coords_filter_sea"),
            list(key = "zero_equal", class = "pill-warning", label_key = "validate_coords_filter_zero_equal"),
            list(key = "reference", class = "pill-reference", label_key = "validate_coords_filter_reference")
        )
        if (isTRUE(counts[["edited"]] > 0L)) {
            pill_defs <- c(pill_defs, list(
                list(key = "edited", class = "pill-edited", label_key = "validate_coords_filter_edited")
            ))
        }

        shiny::div(
            class = "coords-filter-pills",
            lapply(pill_defs, function(item) {
                count_value <- suppressWarnings(as.integer(counts[[item$key]]))
                if (is.na(count_value) || count_value < 0L) count_value <- 0L
                is_active <- identical(active_key, item$key)
                shiny::actionButton(
                    inputId = ns(paste0("coords_filter_", item$key)),
                    label = shiny::tagList(
                        shiny::tags$span(class = "pill-label", tr(item$label_key, lang_r())),
                        shiny::tags$span(class = "pill-count", count_value)
                    ),
                    class = trimws(paste("stream-pill has-count", item$class, if (is_active) "active" else ""))
                )
            })
        )
    })

    output$map_note <- shiny::renderUI({
        map_df <- map_data_r()
        has_rows <- is.data.frame(map_df) && nrow(map_df) > 0L
        hidden_n <- if (has_rows) sum(!coords_plottable(map_df$lat_num, map_df$lon_num)) else 0L
        if (!has_rows) {
            return(shiny::div(
                class = "alert alert-warning mb-0",
                ph_icon("triangle-exclamation"),
                " ",
                tr("validate_coords_map_empty", lang_r())
            ))
        }
        if (hidden_n == 0L) {
            return(NULL)
        }
        shiny::div(
            class = "coords-map-hidden-note",
            ph_icon("triangle-exclamation"),
            shiny::span(sprintf(tr("validate_coords_map_hidden", lang_r()), hidden_n)),
            if (!identical(active_filter(), "validity")) {
                shiny::actionLink(ns("map_show_hidden"), tr("validate_coords_map_hidden_link", lang_r()))
            }
        )
    })

    output$map_panel <- shiny::renderUI({
        res <- coord_validation_r()
        if (is.null(res) || !is.data.frame(res) || nrow(res) == 0L) {
            return(NULL)
        }

        bslib::card(
            class = "validate-coords-card validate-coords-map-card",
            `aria-labelledby` = ns("map_title"),
            bslib::card_body(
                shiny::div(
                    class = "coords-map-container",
                    leaflet::leafletOutput(ns("coords_map"), height = "100%"),
                    shiny::uiOutput(ns("map_legend"))
                ),
                shiny::uiOutput(ns("map_note"))
            )
        )
    })

    output$map_legend <- shiny::renderUI({
        info_icon <- function(text) {
            shiny::tags$span(
                class = "coords-map-legend-info", title = text, tabindex = "0",
                `aria-label` = text, ph_icon("circle-info")
            )
        }
        shiny::tagList(
            shiny::span(id = ns("map_title"), class = "visually-hidden", tr("validate_coords_map_title", lang_r())),
            shiny::div(
                    class = "coords-map-legend",
                    shiny::div(class = "coords-map-legend-item", shiny::span(class = "coords-map-legend-dot coords-map-legend-dot-ok"), shiny::span(tr("validate_coords_map_legend_ok", lang_r()))),
                    shiny::div(class = "coords-map-legend-item", shiny::span(class = "coords-map-legend-dot coords-map-legend-dot-validity"), shiny::span(tr("validate_coords_map_legend_validity", lang_r()))),
                    shiny::div(class = "coords-map-legend-item", shiny::span(class = "coords-map-legend-dot coords-map-legend-dot-sea"), shiny::span(tr("validate_coords_map_legend_sea", lang_r()))),
                    shiny::div(class = "coords-map-legend-item", shiny::span(class = "coords-map-legend-dot coords-map-legend-dot-zero-equal"), shiny::span(tr("validate_coords_map_legend_zero_equal", lang_r()))),
                    shiny::div(class = "coords-map-legend-item", shiny::span(class = "coords-map-legend-dot coords-map-legend-dot-reference"), shiny::span(tr("validate_coords_map_legend_reference", lang_r())), info_icon(tr("validate_coords_map_legend_reference_note", lang_r()))),
                    shiny::div(class = "coords-map-legend-item", shiny::span(class = "coords-map-legend-dot coords-map-legend-dot-corrected"), shiny::span(tr("validate_coords_map_legend_corrected", lang_r()))),
                    info_icon(tr("validate_coords_sea_precision_note", lang_r()))
            )
        )
    })

    output$table_panel <- shiny::renderUI({
        res <- coord_validation_r()
        if (is.null(res) || !is.data.frame(res) || nrow(res) == 0L) {
            return(NULL)
        }

        # table_base_r(), not filtered_result_r(): an edit must not rebuild
        # this container, or the table would lose its page (ADR-129).
        filtered <- table_base_r()
        table_body <- if (!is.data.frame(filtered) || nrow(filtered) == 0L) {
            shiny::div(
                class = "alert alert-info mb-0",
                ph_icon("filter"),
                " ",
                tr("validate_coords_datatable_zero_records", lang_r())
            )
        } else {
            shiny::tagList(
                shiny::p(class = "coords-edit-hint", tr("validate_coords_table_edit_hint", lang_r())),
                shiny::div(class = "saira-table-shell", DT::dataTableOutput(ns("issues_table")))
            )
        }

        bslib::card(
            class = "validate-coords-card validate-coords-table-card",
            `aria-label` = tr("validate_coords_table_title", lang_r()),
            bslib::card_body(table_body)
        )
    })

    output$coords_map <- leaflet::renderLeaflet({
        res <- coord_validation_r()
        shiny::req(res)

        map_obj <- leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE))
        map_obj <- leaflet::addProviderTiles(
            map = map_obj,
            provider = leaflet::providers$OpenStreetMap,
            group = "OpenStreetMap",
            options = leaflet::providerTileOptions(noWrap = TRUE)
        )
        map_obj <- leaflet::addProviderTiles(
            map = map_obj,
            provider = leaflet::providers$Esri.WorldImagery,
            group = "Esri.WorldImagery",
            options = leaflet::providerTileOptions(noWrap = TRUE)
        )
        map_obj <- leaflet::addLayersControl(
            map = map_obj,
            baseGroups = c("OpenStreetMap", "Esri.WorldImagery"),
            options = leaflet::layersControlOptions(collapsed = FALSE)
        )
        map_obj <- leaflet::hideGroup(map_obj, "Esri.WorldImagery")
        map_obj <- leaflet::setView(map = map_obj, lng = 0, lat = 0, zoom = 2)
        leaflet_fill_world(map_obj)
    })

    draw_markers <- function(map_df, fit_view = TRUE) {
        proxy <- leaflet::leafletProxy(ns("coords_map"))
        proxy <- leaflet::clearMarkers(proxy)
        proxy <- leaflet::clearMarkerClusters(proxy)
        proxy <- leaflet::clearPopups(proxy)
        if (!is.data.frame(map_df) || nrow(map_df) == 0L) {
            return(invisible(NULL))
        }

        # A point outside the valid range has no place on the map. The
        # map note counts these rows, and the table lists them.
        map_df <- map_df[coords_plottable(map_df$lat_num, map_df$lon_num), , drop = FALSE]
        if (nrow(map_df) == 0L) {
            return(invisible(NULL))
        }

        marker_radius <- if (nrow(map_df) > 2000L) 4 else 6
        leaflet::addCircleMarkers(
            map = proxy,
            data = map_df,
            lat = ~lat_num,
            lng = ~lon_num,
            radius = marker_radius,
            stroke = TRUE,
            weight = 1,
            color = ~color,
            fillColor = ~color,
            fillOpacity = 0.85,
            layerId = ~paste0("r", .row_index),
            # leaflet-hex.js draws the point as a hexagon (ADR-160).
            options = leaflet::pathOptions(hex = TRUE)
        )

        if (!fit_view) {
            return(invisible(NULL))
        }
        view <- coords_map_view(map_df$lat_num, map_df$lon_num)
        if (identical(view$type, "point")) {
            leaflet::setView(map = proxy, lng = view$lng, lat = view$lat, zoom = 8)
        } else if (identical(view$type, "bounds")) {
            leaflet::fitBounds(
                map = proxy,
                lng1 = view$lng1,
                lat1 = view$lat1,
                lng2 = view$lng2,
                lat2 = view$lat2
            )
        }
    }

    refresh_marker <- function(row_index) {
        eff <- shiny::isolate(effective_validation_r())
        if (!is.data.frame(eff)) return(invisible(NULL))
        proxy <- leaflet::leafletProxy(ns("coords_map"))
        leaflet::removeMarker(proxy, layerId = paste0("r", row_index))
        leaflet::clearPopups(proxy)
        md <- build_leaflet_data(
            eff[eff$.row_index %in% row_index, , drop = FALSE], filter = "all", popups = FALSE
        )
        if (nrow(md) == 0L) return(invisible(NULL))
        leaflet::addCircleMarkers(
            map = proxy, data = md, lat = ~lat_num, lng = ~lon_num,
            radius = 6, stroke = TRUE, weight = 1, color = ~color,
            fillColor = ~color, fillOpacity = 0.85,
            layerId = ~paste0("r", .row_index),
            options = leaflet::pathOptions(hex = TRUE)
        )
    }

    diag_label_key <- function(diag) {
        switch(as.character(diag),
            ok = "validate_coords_diag_ok",
            validity_missing = "validate_coords_diag_validity_missing",
            validity_bounds = "validate_coords_diag_validity_bounds",
            swapped = "validate_coords_diag_swapped",
            sea = "validate_coords_diag_sea",
            zero_equal = "validate_coords_diag_zero_equal",
            identical_all = "validate_coords_diag_identical_all",
            reference = "validate_coords_diag_reference",
            corrected = "validate_coords_diag_corrected",
            "validate_coords_diag_validity_bounds"
        )
    }

    diag_badge_class <- function(fam) {
        fam <- as.character(fam)
        if (identical(fam, "ok")) {
            return("coord-issue-badge-ok")
        }
        if (identical(fam, "corrected")) {
            return("coord-issue-badge-corrected")
        }
        if (identical(fam, "validity")) {
            return("coord-issue-badge-error")
        }
        "coord-issue-badge-warning"
    }

    build_issues_table_df <- function(res) {
        diag <- as.character(res$diagnostic)
        diag[is.na(diag) | !nzchar(diag)] <- "validity_bounds"
        fam <- as.character(res$diagnostic_family)
        fam[is.na(fam) | !nzchar(fam)] <- "validity"

        # Resolve one label per distinct diagnostic (~9) and one class per
        # distinct family (~4), then expand by name. Called per row this
        # ran tr() and the reactive read once per record.
        label_map <- vapply(
            unique(diag),
            function(x) tr(diag_label_key(x), lang_r()),
            FUN.VALUE = character(1)
        )
        class_map <- vapply(unique(fam), diag_badge_class, FUN.VALUE = character(1))
        labels <- unname(label_map[diag])
        classes <- unname(class_map[fam])
        badges <- paste0("<span class=\"coord-issue-badge ", classes, "\">", labels, "</span>")
        edited <- if ("edited" %in% names(res)) res$edited %in% TRUE else rep(FALSE, nrow(res))
        if (any(edited)) {
            badges[edited] <- paste0(
                "<span class=\"coord-issue-badge coord-issue-badge-edited\">",
                tr("validate_coords_edit_badge", lang_r()), "</span> ", badges[edited],
                " <a href=\"#\" class=\"coords-edit-undo\" data-row=\"", res$.row_index[edited], "\">",
                tr("validate_coords_edit_undo", lang_r()), "</a>"
            )
        }

        lat_display <- ifelse(is.na(res$lat_num), "", format(round(res$lat_num, 6), trim = TRUE))
        lon_display <- ifelse(is.na(res$lon_num), "", format(round(res$lon_num, 6), trim = TRUE))

        # The table renders HTML for the badges, so the country typed in the
        # spreadsheet goes in as text (SEG-01).
        as_text <- function(col) {
            if (!col %in% names(res)) return("")
            x <- as.character(res[[col]])
            ifelse(is.na(x), NA_character_, htmltools::htmlEscape(x))
        }
        table_df <- data.frame(
            row_col = res$.row_index,
            diag_col = badges,
            lat_col = lat_display,
            lon_col = lon_display,
            country_col = as_text("country"),
            iso3_col = as_text("country_iso3"),
            stringsAsFactors = FALSE
        )
        table_df
    }

    refresh_table_rows <- function() {
        base <- shiny::isolate(table_base_r())
        eff <- shiny::isolate(effective_validation_r())
        if (!is.data.frame(base) || nrow(base) == 0L || !is.data.frame(eff)) {
            return(invisible(NULL))
        }
        rows <- eff[match(base$.row_index, eff$.row_index), , drop = FALSE]
        DT::replaceData(table_proxy, build_issues_table_df(rows),
                        resetPaging = FALSE, rownames = FALSE)
    }

    output$issues_table <- DT::renderDataTable({
        res <- table_base_r()
        shiny::req(res, nrow(res) > 0L)
        table_df <- build_issues_table_df(res)

        DT::datatable(
            table_df,
            # Translated headers only: the data keeps its column names, so a
            # server-side request sent before a language change still finds
            # its columns (DT alerts "column name not found" otherwise).
            colnames = c(
                tr("validate_coords_col_row", lang_r()),
                tr("validate_coords_col_issue", lang_r()),
                tr("validate_coords_col_lat", lang_r()),
                tr("validate_coords_col_lon", lang_r()),
                tr("validate_coords_col_country", lang_r()),
                tr("validate_coords_col_iso3", lang_r())
            ),
            options = list(
                pageLength = 10,
                lengthMenu = c(10, 25, 50, 100),
                scrollX = TRUE,
                autoWidth = FALSE,
                language = list(
                    search = tr("validate_coords_datatable_search", lang_r()),
                    lengthMenu = tr("validate_coords_datatable_length_menu", lang_r()),
                    info = tr("validate_coords_datatable_info", lang_r()),
                    emptyTable = tr("validate_coords_datatable_empty", lang_r()),
                    zeroRecords = tr("validate_coords_datatable_zero_records", lang_r()),
                    paginate = list(
                        first = tr("validate_coords_datatable_first", lang_r()),
                        last = tr("validate_coords_datatable_last", lang_r()),
                        `next` = tr("validate_coords_datatable_next", lang_r()),
                        previous = tr("validate_coords_datatable_prev", lang_r())
                    )
                )
            ),
            class = "display compact validate-results-table",
            rownames = FALSE,
            escape = FALSE,
            # One selected row: the one a map popup pointed at.
            selection = "single",
            # Only latitude (column 2) and longitude (column 3) take an edit.
            editable = list(target = "cell", disable = list(columns = c(0L, 1L, 4L, 5L)))
        )
    })

    output$transposed_panel <- shiny::renderUI({
        tbl <- view$transposed_table()
        if (is.null(tbl) || nrow(tbl) == 0L) return(NULL)
        n <- nrow(tbl)
        applied <- isTRUE(view$transposed_applied())
        ex <- tbl[1, ]

        lang <- lang_r()
        detail <- paste0(
            sprintf(tr(if (applied) "validate_coords_transposed_applied" else "validate_coords_transposed_found", lang), n),
            " \u00b7 ", sprintf("%s (%.2f, %.2f) \u2192 (%.2f, %.2f)", ex$country, ex$lat_old, ex$lon_old, ex$decimalLatitude, ex$decimalLongitude),
            if (n > 1L) paste0(" \u00b7 ", sprintf(tr("validate_coords_transposed_more", lang), n - 1L)) else ""
        )
        coords_fix_chip(
            applied = applied, icon = "right-left", detail = detail,
            label = sprintf(tr(if (applied) "validate_coords_transposed_short_applied" else "validate_coords_transposed_short", lang), n),
            button = shiny::actionButton(
                ns("apply_transposed"), tr("validate_coords_fix_btn_transposed", lang),
                icon = ph_icon("wand-magic-sparkles"),
                class = "btn btn-primary btn-sm"
            )
        )
    })

    output$outside_panel <- shiny::renderUI({
        tbl <- view$outside_table()
        if (is.null(tbl) || nrow(tbl) == 0L) return(NULL)
        lang <- lang_r()
        n <- nrow(tbl)
        ex <- utils::head(tbl, 5L)
        detail <- paste(sprintf(tr("validate_coords_outside_row", lang), ex$row, ex$country, ex$lat, ex$lon),
                        collapse = " \u00b7 ")
        if (n > 5L) {
            detail <- paste0(detail, " \u00b7 ", sprintf(tr("validate_coords_transposed_more", lang), n - 5L))
        }
        coords_fix_chip(
            applied = FALSE, icon = "triangle-exclamation", detail = detail,
            label = sprintf(tr("validate_coords_outside_short", lang), n),
            button = NULL
        )
    })

    output$utm_panel <- shiny::renderUI({
        rows <- view$utm_rows()
        if (is.null(rows) || !length(rows)) return(NULL)
        lang <- lang_r()
        n <- length(rows)
        applied <- isTRUE(view$utm_applied())
        cand <- view$utm_candidates()
        zones <- if (is.data.frame(cand) && nrow(cand) > 0L) {
            as.integer(cand$zone)
        } else {
            # No country to score against: offer the zones the datum covers.
            as.integer(coords_utm_datums()[[coords_utm_default_datum()]]$zones)
        }

        datum_choices <- stats::setNames(
            names(coords_utm_datums()),
            vapply(coords_utm_datums(), function(x) x$label, character(1))
        )

        # A band of its own under the toolbar (round 5): the zone and datum
        # pickers do not fit a toolbar chip. It shows only when some rows
        # carry projected (UTM) pairs; everything exported is WGS84.
        if (applied) {
            return(shiny::div(
                class = "coords-utm-band is-applied",
                ph_icon("circle-check"),
                shiny::span(class = "coords-utm-title", sprintf(tr("validate_coords_utm_applied", lang), n))
            ))
        }
        # Keep the pick across a language switch, not across a new upload.
        zone_sel <- shiny::isolate(input$utm_zone)
        if (!isTRUE(as.integer(zone_sel) %in% zones)) zone_sel <- zones[[1]]
        datum_sel <- shiny::isolate(input$utm_datum)
        if (!isTRUE(datum_sel %in% datum_choices)) datum_sel <- coords_utm_default_datum()
        help <- tr("validate_coords_utm_help", lang)
        if (is.data.frame(cand) && nrow(cand) > 1L) {
            help <- paste(help, sprintf(tr("validate_coords_utm_ambiguous", lang), nrow(cand)))
        }
        shiny::div(
            class = "coords-utm-band",
            ph_icon("compass"),
            shiny::span(class = "coords-utm-title", sprintf(tr("validate_coords_utm_found", lang), n)),
            shiny::span(class = "coords-utm-help", title = help, `aria-label` = help, ph_icon("circle-info")),
            shiny::span(class = "coords-utm-spacer"),
            # isolate(): this output must not depend on the pickers it
            # creates, or each pick would rebuild them.
            shiny::selectInput(
                ns("utm_zone"), tr("validate_coords_utm_zone", lang),
                choices = zones,
                selected = zone_sel,
                selectize = FALSE
            ),
            shiny::selectInput(
                ns("utm_datum"), tr("validate_coords_utm_datum", lang),
                choices = datum_choices,
                selected = datum_sel,
                selectize = FALSE
            ),
            shiny::uiOutput(ns("utm_preview"), inline = TRUE),
            shiny::actionButton(
                ns("apply_utm"),
                tr("validate_coords_utm_apply", lang),
                icon = ph_icon("wand-magic-sparkles"),
                class = "btn btn-primary btn-sm"
            )
        )
    })

    output$utm_preview <- shiny::renderUI({
        preview <- utm_converted_r()
        if (is.data.frame(preview) && nrow(preview) > 0L) {
            shiny::span(class = "coords-utm-preview", sprintf(
                "\u2192 (%.4f, %.4f)",
                preview$decimalLatitude[[1]], preview$decimalLongitude[[1]]
            ))
        } else {
            # An older datum covers fewer zones than SIRGAS 2000, so a valid
            # zone can become unreachable when the datum changes. Say so
            # instead of leaving the button inert.
            shiny::span(class = "coords-utm-preview is-unavailable",
                        tr("validate_coords_utm_unavailable", lang_r()))
        }
    })

    output$swap_fill_panel <- shiny::renderUI({
        tbl <- view$swap_fill_table()
        if (is.null(tbl) || nrow(tbl) == 0L) return(NULL)
        n <- nrow(tbl)
        applied <- isTRUE(view$swap_fill_applied())
        ex <- tbl[1, ]

        lang <- lang_r()
        detail <- paste0(
            sprintf(tr(if (applied) "validate_coords_swapfill_applied" else "validate_coords_swapfill_found", lang), n),
            " \u00b7 ", sprintf("(%.2f, %.2f) \u2192 (%.2f, %.2f) %s", ex$lat_old, ex$lon_old, ex$decimalLatitude, ex$decimalLongitude, ex$country),
            if (n > 1L) paste0(" \u00b7 ", sprintf(tr("validate_coords_transposed_more", lang), n - 1L)) else ""
        )
        coords_fix_chip(
            applied = applied, icon = "right-left", detail = detail,
            label = sprintf(tr(if (applied) "validate_coords_swapfill_short_applied" else "validate_coords_swapfill_short", lang), n),
            button = shiny::actionButton(
                ns("apply_swap_fill"), tr("validate_coords_fix_btn_swapfill", lang),
                icon = ph_icon("wand-magic-sparkles"),
                class = "btn btn-primary btn-sm"
            )
        )
    })

    output$country_panel <- shiny::renderUI({
        tbl <- view$country_fill_table()
        if (is.null(tbl) || nrow(tbl) == 0L) return(NULL)
        n <- nrow(tbl)
        applied <- isTRUE(view$country_fill_applied())
        ex <- tbl[1, ]

        lang <- lang_r()
        detail <- paste0(
            sprintf(tr(if (applied) "validate_coords_country_filled" else "validate_coords_country_found", lang), n),
            " \u00b7 ", sprintf("(%.2f, %.2f) \u2192 %s", ex$lat, ex$lon, ex$country),
            if (n > 1L) paste0(" \u00b7 ", sprintf(tr("validate_coords_transposed_more", lang), n - 1L)) else ""
        )
        coords_fix_chip(
            applied = applied, icon = "earth-americas", detail = detail,
            label = sprintf(tr(if (applied) "validate_coords_country_short_applied" else "validate_coords_country_short", lang), n),
            button = shiny::actionButton(
                ns("apply_country_fill"), tr("validate_coords_fix_btn_country", lang),
                icon = ph_icon("wand-magic-sparkles"),
                class = "btn btn-primary btn-sm"
            )
        )
    })

    list(
        map_labels = map_labels, draw_markers = draw_markers, refresh_marker = refresh_marker,
        diag_label_key = diag_label_key, diag_badge_class = diag_badge_class,
        build_issues_table_df = build_issues_table_df, refresh_table_rows = refresh_table_rows
    )
}
