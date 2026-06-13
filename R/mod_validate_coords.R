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
            shiny::uiOutput(ns("title")),
            shiny::uiOutput(ns("subtitle")),
            shiny::div(
                class = "row g-4 validate-coords-layout",
                shiny::div(
                    class = "col-12 col-lg-2 validate-coords-left",
                    shiny::uiOutput(ns("action_card")),
                    shiny::uiOutput(ns("transposed_panel")),
                    shiny::uiOutput(ns("swap_fill_panel")),
                    shiny::uiOutput(ns("country_panel"))
                ),
                shiny::div(
                    class = "col-12 col-lg-10 validate-coords-right",
                    shiny::uiOutput(ns("pre_right_hint")),
                    shiny::uiOutput(ns("progress_panel")),
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
        )
    )
}

#' Validate Coordinates Module Server
#'
#' @param id Module ID
#' @param mapped_data_r Reactive data frame with mapped data
#' @param lang_r Reactive language value
#' @param validation_gate_r Optional lightweight coordinate gate reactive
#' @return Reactive coordinate validation data frame
#' @export
mod_validate_coords_server <- function(id, mapped_data_r, lang_r, validation_gate_r = NULL) {
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

        coord_filter_values <- c("all", "problems", "validity", "sea", "zero_equal", "reference")
        coord_validation_r <- shiny::reactiveVal(NULL)

        rv <- shiny::reactiveValues(
            starting = FALSE,
            running = FALSE,
            start_requested = FALSE,
            run_requested = FALSE,
            stream_filter = "all",
            last_run_status = "idle",
            transposed_table = NULL,     # data.frame of correctable rows (preview)
            transposed_applied = FALSE,
            coords_corrections = NULL,    # transposed payload applied at export
            country_fill_table = NULL,    # data.frame of fillable rows (preview)
            country_fill_applied = FALSE,
            country_fills = NULL,         # country-fill payload applied at export
            swap_fill_table = NULL,       # blank-country sea points fixable by swap
            swap_fill_applied = FALSE
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
            apply_coord_corrections_to_result(
                res,
                coords_corrections = rv$coords_corrections,
                country_fills = rv$country_fills,
                occ_ids = rv$validation_occ_ids
            )
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
                    reference = 0L
                ))
            }

            counts <- count_coords_diagnostics(res)
            c(
                all = as.integer(counts$total %||% 0L),
                problems = as.integer(counts$problems %||% 0L),
                validity = as.integer(counts$validity %||% 0L),
                sea = as.integer(counts$sea %||% 0L),
                zero_equal = as.integer(counts$zero_equal %||% 0L),
                reference = as.integer(counts$reference %||% 0L)
            )
        })

        map_data_r <- shiny::reactive({
            res <- effective_validation_r()
            shiny::req(res)

            label_keys <- c(
                ok = "validate_coords_diag_ok",
                validity_missing = "validate_coords_diag_validity_missing",
                validity_bounds = "validate_coords_diag_validity_bounds",
                swapped = "validate_coords_diag_swapped",
                sea = "validate_coords_diag_sea",
                zero_equal = "validate_coords_diag_zero_equal",
                identical_all = "validate_coords_diag_identical_all",
                reference = "validate_coords_diag_reference"
            )
            issue_labels <- vapply(label_keys, function(k) tr(k, lang_r()), FUN.VALUE = character(1))
            popup_labels <- list(
                row = tr("validate_coords_popup_row", lang_r()),
                issue = tr("validate_coords_popup_issue", lang_r()),
                lat = tr("validate_coords_col_lat", lang_r()),
                lon = tr("validate_coords_col_lon", lang_r())
            )

            build_leaflet_data(
                coords_result_df = res,
                filter = active_filter(),
                issue_labels = issue_labels,
                popup_labels = popup_labels
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

        output$title <- shiny::renderUI({
            shiny::h3(
                shiny::icon("map-marker-alt", class = "me-2"),
                tr("validate_coords_title", lang_r()),
                class = "text-mono mb-2"
            )
        })

        output$subtitle <- shiny::renderUI({
            shiny::p(tr("validate_coords_subtitle", lang_r()), class = "text-accent mb-4")
        })

        output$action_card <- shiny::renderUI({
            gate <- quick_gate()
            is_busy <- isTRUE(rv$running) || isTRUE(rv$starting)
            run_label <- if (is_busy) tr("validate_coords_run_running", lang_r()) else tr("validate_coords_run", lang_r())

            lat_ok <- isTRUE(gate$has_lat)
            lon_ok <- isTRUE(gate$has_lon)
            country_ok <- isTRUE(gate$has_country)

            lat_desc <- if (lat_ok) as.character(gate$lat_col) else tr("validate_coords_status_not_mapped", lang_r())
            lon_desc <- if (lon_ok) as.character(gate$lon_col) else tr("validate_coords_status_not_mapped", lang_r())
            country_desc <- if (country_ok) as.character(gate$country_col) else tr("validate_coords_status_not_mapped", lang_r())

            helper_text <- switch(gate$status,
                no_data = tr("validate_coords_no_data", lang_r()),
                missing_lat = tr("validate_coords_lat_missing", lang_r()),
                missing_lon = tr("validate_coords_lon_missing", lang_r()),
                missing_country = tr("validate_coords_country_missing", lang_r()),
                missing_multiple = tr("validate_coords_missing_multiple", lang_r()),
                ""
            )

            bslib::card(
                class = "validate-coords-card mb-3",
                bslib::card_header(
                    shiny::div(
                        class = "validate-card-title",
                        shiny::icon("gear", class = "me-2"),
                        tr("validate_coords_action_card_title", lang_r())
                    )
                ),
                bslib::card_body(
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
                        icon = shiny::icon(if (is_busy) "spinner" else "play", class = if (is_busy) "fa-spin" else ""),
                        class = "btn-primary w-100",
                        disabled = !isTRUE(can_run_validation())
                    ),
                    if (nzchar(helper_text)) {
                        shiny::div(class = "validate-action-help mt-3", helper_text)
                    }
                )
            )
        })

        output$pre_right_hint <- shiny::renderUI({
            if (isTRUE(rv$running) || isTRUE(rv$starting) || !is.null(coord_validation_r())) {
                return(NULL)
            }
            shiny::div(
                class = "validate-pre-right",
                shiny::div(
                    class = "validate-ready-hint",
                    shiny::icon("circle-info"),
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

        output$progress_panel <- shiny::renderUI({
            if (!isTRUE(rv$starting) && !isTRUE(rv$running)) {
                return(NULL)
            }
            bslib::card(
                class = "validate-coords-card mb-3 validation-progress-panel",
                bslib::card_body(
                    shiny::div(
                        class = "validation-progress-empty",
                        shiny::icon("spinner", class = "me-2 fa-spin"),
                        tr("validate_coords_run_running", lang_r())
                    )
                )
            )
        })

        # stats_panel removed: the four count boxes duplicated the filter pill
        # counts above the map. The left column now hosts the transposed-coords
        # correction card instead.

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
                list(key = "problems", class = "", label_key = "validate_coords_filter_problems"),
                list(key = "validity", class = "pill-error", label_key = "validate_coords_filter_validity"),
                list(key = "sea", class = "pill-info", label_key = "validate_coords_filter_sea"),
                list(key = "zero_equal", class = "pill-warning", label_key = "validate_coords_filter_zero_equal"),
                list(key = "reference", class = "pill-reference", label_key = "validate_coords_filter_reference")
            )

            shiny::div(
                class = "coords-filter-pills",
                lapply(pill_defs, function(item) {
                    count_value <- suppressWarnings(as.integer(counts[[item$key]]))
                    if (is.na(count_value) || count_value < 0L) count_value <- 0L
                    is_active <- identical(active_key, item$key)
                    shiny::actionButton(
                        inputId = ns(paste0("coords_filter_", item$key)),
                        label = shiny::tagList(
                            tr(item$label_key, lang_r()),
                            shiny::tags$span(class = "pill-count", count_value)
                        ),
                        class = trimws(paste("stream-pill", item$class, if (is_active) "active" else ""))
                    )
                })
            )
        })

        output$map_note <- shiny::renderUI({
            map_df <- map_data_r()
            if (is.data.frame(map_df) && nrow(map_df) > 0L) {
                return(NULL)
            }
            shiny::div(
                class = "alert alert-warning mb-0",
                shiny::icon("triangle-exclamation"),
                " ",
                tr("validate_coords_map_empty", lang_r())
            )
        })

        # NOTE: depend only on coord_validation_r() here. This renderUI hosts the
        # leafletOutput, so any extra reactive dependency (e.g. on corrections)
        # would recreate the map widget mid-session and break proxy repaints.
        output$map_panel <- shiny::renderUI({
            res <- coord_validation_r()
            if (is.null(res) || !is.data.frame(res) || nrow(res) == 0L) {
                return(NULL)
            }

            bslib::card(
                class = "validate-coords-card mb-3 validate-coords-map-card",
                bslib::card_header(
                    shiny::div(class = "validate-card-title", shiny::icon("earth-americas", class = "me-2"), tr("validate_coords_map_title", lang_r()))
                ),
                bslib::card_body(
                    shiny::p(class = "coords-map-subtitle", tr("validate_coords_map_subtitle", lang_r())),
                    shiny::div(class = "coords-map-container", leaflet::leafletOutput(ns("coords_map"), height = "560px")),
                    shiny::uiOutput(ns("map_note")),
                    shiny::div(
                        class = "coords-map-legend",
                        shiny::div(class = "coords-map-legend-item", shiny::span(class = "coords-map-legend-dot coords-map-legend-dot-ok"), shiny::span(tr("validate_coords_map_legend_ok", lang_r()))),
                        shiny::div(class = "coords-map-legend-item", shiny::span(class = "coords-map-legend-dot coords-map-legend-dot-validity"), shiny::span(tr("validate_coords_map_legend_validity", lang_r()))),
                        shiny::div(class = "coords-map-legend-item", shiny::span(class = "coords-map-legend-dot coords-map-legend-dot-sea"), shiny::span(tr("validate_coords_map_legend_sea", lang_r()))),
                        shiny::div(class = "coords-map-legend-item", shiny::span(class = "coords-map-legend-dot coords-map-legend-dot-zero-equal"), shiny::span(tr("validate_coords_map_legend_zero_equal", lang_r()))),
                        shiny::div(class = "coords-map-legend-item", shiny::span(class = "coords-map-legend-dot coords-map-legend-dot-reference"), shiny::span(tr("validate_coords_map_legend_reference", lang_r()))),
                        shiny::div(class = "coords-map-legend-item", shiny::span(class = "coords-map-legend-dot coords-map-legend-dot-corrected"), shiny::span(tr("validate_coords_map_legend_corrected", lang_r())))
                    ),
                    shiny::div(
                        class = "coords-reference-note",
                        shiny::span(class = "coords-map-legend-dot coords-map-legend-dot-reference coords-reference-note-dot"),
                        tr("validate_coords_map_legend_reference_note", lang_r())
                    ),
                    shiny::div(
                        class = "alert alert-warning coords-sea-precision-note mb-0 mt-2",
                        shiny::icon("triangle-exclamation", class = "me-1"),
                        tr("validate_coords_sea_precision_note", lang_r())
                    )
                )
            )
        })

        output$table_panel <- shiny::renderUI({
            res <- coord_validation_r()
            if (is.null(res) || !is.data.frame(res) || nrow(res) == 0L) {
                return(NULL)
            }

            filtered <- filtered_result_r()
            table_body <- if (!is.data.frame(filtered) || nrow(filtered) == 0L) {
                shiny::div(
                    class = "alert alert-info mb-0",
                    shiny::icon("filter"),
                    " ",
                    tr("validate_coords_datatable_zero_records", lang_r())
                )
            } else {
                shiny::div(class = "saira-table-shell", DT::dataTableOutput(ns("issues_table")))
            }

            bslib::card(
                class = "validate-coords-card mb-3 validate-coords-table-card",
                bslib::card_header(
                    shiny::div(class = "validate-card-title", shiny::icon("table", class = "me-2"), tr("validate_coords_table_title", lang_r()))
                ),
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
            leaflet::setView(map = map_obj, lng = 0, lat = 0, zoom = 2)
        })

        shiny::bindEvent(
            shiny::observe({
                res <- coord_validation_r()
                shiny::req(res)
                map_df <- map_data_r()

                proxy <- leaflet::leafletProxy(ns("coords_map"))
                proxy <- leaflet::clearMarkers(proxy)
                proxy <- leaflet::clearMarkerClusters(proxy)
                if (!is.data.frame(map_df) || nrow(map_df) == 0L) {
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
                    popup = ~popup_html
                )

                lon_values <- suppressWarnings(as.numeric(map_df$lon_num))
                lat_values <- suppressWarnings(as.numeric(map_df$lat_num))
                valid_bounds <- is.finite(lon_values) & is.finite(lat_values)
                if (!any(valid_bounds)) {
                    return(invisible(NULL))
                }

                lon_values <- lon_values[valid_bounds]
                lat_values <- lat_values[valid_bounds]
                lon_min <- min(lon_values)
                lon_max <- max(lon_values)
                lat_min <- min(lat_values)
                lat_max <- max(lat_values)

                if (isTRUE(all.equal(lon_min, lon_max)) && isTRUE(all.equal(lat_min, lat_max))) {
                    leaflet::setView(
                        map = proxy,
                        lng = lon_min,
                        lat = lat_min,
                        zoom = 8
                    )
                    return(invisible(NULL))
                }

                leaflet::fitBounds(
                    map = proxy,
                    lng1 = lon_min,
                    lat1 = lat_min,
                    lng2 = lon_max,
                    lat2 = lat_max
                )
            }),
            effective_validation_r(),
            active_filter()
        )

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

        output$issues_table <- DT::renderDataTable({
            res <- filtered_result_r()
            shiny::req(res, nrow(res) > 0L)

            diag <- as.character(res$diagnostic)
            diag[is.na(diag) | !nzchar(diag)] <- "validity_bounds"
            fam <- as.character(res$diagnostic_family)
            fam[is.na(fam) | !nzchar(fam)] <- "validity"

            labels <- vapply(diag, function(x) tr(diag_label_key(x), lang_r()), FUN.VALUE = character(1))
            classes <- vapply(fam, diag_badge_class, FUN.VALUE = character(1))
            badges <- paste0("<span class=\"coord-issue-badge ", classes, "\">", labels, "</span>")

            lat_display <- ifelse(is.na(res$lat_num), "", format(round(res$lat_num, 6), trim = TRUE))
            lon_display <- ifelse(is.na(res$lon_num), "", format(round(res$lon_num, 6), trim = TRUE))

            table_df <- data.frame(
                row_col = res$.row_index,
                diag_col = badges,
                lat_col = lat_display,
                lon_col = lon_display,
                country_col = if ("country" %in% names(res)) as.character(res$country) else "",
                iso3_col = if ("country_iso3" %in% names(res)) as.character(res$country_iso3) else "",
                stringsAsFactors = FALSE
            )

            colnames(table_df) <- c(
                tr("validate_coords_col_row", lang_r()),
                tr("validate_coords_col_issue", lang_r()),
                tr("validate_coords_col_lat", lang_r()),
                tr("validate_coords_col_lon", lang_r()),
                tr("validate_coords_col_country", lang_r()),
                tr("validate_coords_col_iso3", lang_r())
            )

            DT::datatable(
                table_df,
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
                escape = FALSE
            )
        })

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
                tryCatch(
                    show_validate_coords_loading_modal(ns, lang_r),
                    error = function(e) {
                        notify_saira(
                            message = tr("validate_coords_modal_fallback", lang_r()),
                            type = "warning",
                            key = "coords_modal_fallback"
                        )
                    }
                )

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
                if (!isTRUE(rv$running)) {
                    return(invisible(NULL))
                }

                on.exit(
                    {
                        hide_validate_coords_loading_modal()
                        rv$running <- FALSE
                    },
                    add = TRUE
                )

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
                            seas_scale = 10L
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

                # Detect transposed / sign-flipped coordinates correctable
                # against the informed country (reuses the same data frame).
                rv$transposed_applied <- FALSE
                rv$coords_corrections <- NULL
                rv$transposed_table <- NULL
                tr_res <- tryCatch(
                    coords_transposed_corrections(
                        df,
                        lat_col = "decimalLatitude",
                        lon_col = "decimalLongitude",
                        country_col = "country"
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
        output$transposed_panel <- shiny::renderUI({
            tbl <- rv$transposed_table
            if (is.null(tbl) || nrow(tbl) == 0L) return(NULL)
            n <- nrow(tbl)
            applied <- isTRUE(rv$transposed_applied)
            ex <- tbl[1, ]

            shiny::div(
                class = paste("coords-transposed-card", if (applied) "is-applied" else ""),
                shiny::div(
                    class = "coords-transposed-head",
                    shiny::icon(if (applied) "circle-check" else "right-left"),
                    shiny::span(
                        class = "coords-transposed-title",
                        if (applied) {
                            sprintf(tr("validate_coords_transposed_applied", lang_r()), n)
                        } else {
                            sprintf(tr("validate_coords_transposed_found", lang_r()), n)
                        }
                    )
                ),
                # One compact, stacked example (fits the narrow left column).
                shiny::div(
                    class = "coords-transposed-example",
                    shiny::div(class = "coords-transposed-ex-country", ex$country),
                    shiny::div(sprintf("(%.2f, %.2f)", ex$lat_old, ex$lon_old)),
                    shiny::div(class = "coords-transposed-ex-arrow",
                               sprintf("→ (%.2f, %.2f)", ex$decimalLatitude, ex$decimalLongitude))
                ),
                if (n > 1L) {
                    shiny::p(class = "coords-transposed-more",
                             sprintf(tr("validate_coords_transposed_more", lang_r()), n - 1L))
                },
                if (!applied) {
                    shiny::actionButton(
                        ns("apply_transposed"),
                        tr("validate_coords_transposed_apply", lang_r()),
                        icon = shiny::icon("wand-magic-sparkles"),
                        class = "btn btn-primary btn-sm w-100"
                    )
                }
            )
        })

        # Payload merge helpers: the transposed, swap-fill and country cards act
        # on disjoint rows but two of them write coordinate/country payloads, so
        # we accumulate (dedupe by occurrenceID) instead of overwriting.
        merge_coords_corrections <- function(new_df) {
            cur <- rv$coords_corrections$corrections
            merged <- if (is.null(cur)) new_df else rbind(cur, new_df)
            merged <- merged[!duplicated(merged$occurrenceID, fromLast = TRUE), , drop = FALSE]
            rv$coords_corrections <- list(corrections = merged)
        }
        merge_country_fills <- function(new_df) {
            cur <- rv$country_fills$country
            merged <- if (is.null(cur)) new_df else rbind(cur, new_df)
            merged <- merged[!duplicated(merged$occurrenceID, fromLast = TRUE), , drop = FALSE]
            rv$country_fills <- list(country = merged)
        }

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
        output$swap_fill_panel <- shiny::renderUI({
            tbl <- rv$swap_fill_table
            if (is.null(tbl) || nrow(tbl) == 0L) return(NULL)
            n <- nrow(tbl)
            applied <- isTRUE(rv$swap_fill_applied)
            ex <- tbl[1, ]

            shiny::div(
                class = paste("coords-transposed-card", if (applied) "is-applied" else ""),
                shiny::div(
                    class = "coords-transposed-head",
                    shiny::icon(if (applied) "circle-check" else "right-left"),
                    shiny::span(
                        class = "coords-transposed-title",
                        if (applied) {
                            sprintf(tr("validate_coords_swapfill_applied", lang_r()), n)
                        } else {
                            sprintf(tr("validate_coords_swapfill_found", lang_r()), n)
                        }
                    )
                ),
                shiny::div(
                    class = "coords-transposed-example",
                    shiny::div(sprintf("(%.2f, %.2f)", ex$lat_old, ex$lon_old)),
                    shiny::div(class = "coords-transposed-ex-arrow",
                               sprintf("→ (%.2f, %.2f) · %s",
                                       ex$decimalLatitude, ex$decimalLongitude, ex$country))
                ),
                if (n > 1L) {
                    shiny::p(class = "coords-transposed-more",
                             sprintf(tr("validate_coords_transposed_more", lang_r()), n - 1L))
                },
                if (!applied) {
                    shiny::actionButton(
                        ns("apply_swap_fill"),
                        tr("validate_coords_swapfill_apply", lang_r()),
                        icon = shiny::icon("wand-magic-sparkles"),
                        class = "btn btn-primary btn-sm w-100"
                    )
                }
            )
        })

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
        output$country_panel <- shiny::renderUI({
            tbl <- rv$country_fill_table
            if (is.null(tbl) || nrow(tbl) == 0L) return(NULL)
            n <- nrow(tbl)
            applied <- isTRUE(rv$country_fill_applied)
            ex <- tbl[1, ]

            shiny::div(
                class = paste("coords-transposed-card", if (applied) "is-applied" else ""),
                shiny::div(
                    class = "coords-transposed-head",
                    shiny::icon(if (applied) "circle-check" else "earth-americas"),
                    shiny::span(
                        class = "coords-transposed-title",
                        if (applied) {
                            sprintf(tr("validate_coords_country_filled", lang_r()), n)
                        } else {
                            sprintf(tr("validate_coords_country_found", lang_r()), n)
                        }
                    )
                ),
                shiny::div(
                    class = "coords-transposed-example",
                    shiny::div(sprintf("(%.2f, %.2f)", ex$lat, ex$lon)),
                    shiny::div(class = "coords-transposed-ex-arrow", sprintf("→ %s", ex$country))
                ),
                if (n > 1L) {
                    shiny::p(class = "coords-transposed-more",
                             sprintf(tr("validate_coords_transposed_more", lang_r()), n - 1L))
                },
                if (!applied) {
                    shiny::actionButton(
                        ns("apply_country_fill"),
                        tr("validate_coords_country_apply", lang_r()),
                        icon = shiny::icon("wand-magic-sparkles"),
                        class = "btn btn-primary btn-sm w-100"
                    )
                }
            )
        })

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

        result_r <- shiny::reactive(coord_validation_r())
        attr(result_r, "filtered_data") <- filtered_result_r
        attr(result_r, "active_filter") <- active_filter
        attr(result_r, "coords_correction_payload") <- shiny::reactive(rv$coords_corrections)
        attr(result_r, "country_fill_payload") <- shiny::reactive(rv$country_fills)
        return(result_r)
    })
}
