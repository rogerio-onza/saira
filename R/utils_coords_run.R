# Title: Coordinates run progress
# Pure helpers for the run stage of the Coordinates page (ADR-160): the
# step list, the points and the land outline that the radar draws.

#' Steps of a coordinates run, in the order of validate_coords_cc_df()
#' @noRd
coords_run_step_keys <- function() {
    c("parse", "iso3", "validity", "sea", "zero_equal", "reference")
}

#' Points that the run map can draw
#' @param lat,lon Numeric vectors.
#' @return Logical vector.
#' @noRd
coords_run_drawable <- function(lat, lon) {
    is.finite(lat) & is.finite(lon) & abs(lat) <= 90 & abs(lon) <= 180
}

#' Keep at most \code{max} drawable points, one per rounded position
#'
#' Many sheets repeat a position, and the canvas draws each point on every
#' frame. A stride keeps the sample spread over the sheet, with no random
#' state.
#' @param lat,lon Numeric vectors.
#' @param max Maximum count of points.
#' @return List with numeric \code{lon} and \code{lat}.
#' @noRd
coords_run_points <- function(lat, lon, max = 20000L) {
    ok <- coords_run_drawable(lat, lon)
    lon <- round(lon[ok], 4)
    lat <- round(lat[ok], 4)
    keep <- !duplicated(paste(lon, lat))
    lon <- lon[keep]
    lat <- lat[keep]
    if (length(lon) > max) {
        idx <- unique(round(seq(1, length(lon), length.out = max)))
        lon <- lon[idx]
        lat <- lat[idx]
    }
    list(lon = lon, lat = lat)
}

#' Box of land to send with the run map
#'
#' The browser fits the view to the points and widens one axis to the shape
#' of the canvas. A margin of one full span on each side covers that.
#' @param lon,lat Numeric vectors of drawable points.
#' @return List with \code{xmin}, \code{xmax}, \code{ymin} and \code{ymax},
#'   or NULL when there is no point.
#' @noRd
coords_run_extent <- function(lon, lat) {
    if (length(lon) == 0L) {
        return(NULL)
    }
    xr <- range(lon)
    yr <- range(lat)
    pad <- max(diff(xr), diff(yr), 4)
    list(
        xmin = max(-180, xr[1] - pad),
        xmax = min(180, xr[2] + pad),
        ymin = max(-90, yr[1] - pad),
        ymax = min(90, yr[2] + pad)
    )
}

#' Land outline inside a box, as flat rings
#'
#' Uses the embedded Natural Earth 10m land of the Americas. Outside that
#' coverage the map shows the points only.
#' @param extent List from \code{coords_run_extent()}.
#' @param ref Land SpatVector, or NULL.
#' @return List of numeric vectors \code{c(lon1, lat1, lon2, lat2, ...)}.
#' @noRd
coords_run_land <- function(extent, ref = coords_load_ne_land(10L, download = FALSE)) {
    if (is.null(extent) || is.null(ref) || !inherits(ref, "SpatVector")) {
        return(list())
    }
    box <- terra::ext(extent$xmin, extent$xmax, extent$ymin, extent$ymax)
    cropped <- tryCatch(terra::crop(ref, box), error = function(e) NULL)
    if (is.null(cropped) || nrow(cropped) == 0L) {
        return(list())
    }
    # About one canvas pixel: more detail costs bytes and draw time only.
    tolerance <- max(extent$xmax - extent$xmin, extent$ymax - extent$ymin) / 600
    simple <- tryCatch(
        terra::simplifyGeom(cropped, tolerance = tolerance, preserveTopology = TRUE),
        error = function(e) cropped
    )
    g <- terra::geom(simple)
    if (nrow(g) == 0L) {
        return(list())
    }
    ring_id <- paste(g[, "geom"], g[, "part"], g[, "hole"])
    rings <- split(seq_len(nrow(g)), factor(ring_id, levels = unique(ring_id)))
    rings <- rings[lengths(rings) >= 3L]
    unname(lapply(rings, function(i) {
        as.vector(rbind(round(g[i, "x"], 3), round(g[i, "y"], 3)))
    }))
}

#' Map payload of a run: the points and the land around them
#' @param lat,lon Numeric vectors of all records.
#' @return List with \code{lon}, \code{lat} and \code{land}.
#' @noRd
coords_run_view <- function(lat, lon) {
    pts <- coords_run_points(lat, lon)
    land <- tryCatch(
        coords_run_land(coords_run_extent(pts$lon, pts$lat)),
        error = function(e) list()
    )
    list(lon = I(pts$lon), lat = I(pts$lat), land = lapply(land, I))
}

#' Positions of newly flagged records, for the radar
#' @param rows Integer row indices.
#' @param lat,lon Numeric vectors of all records.
#' @param max Maximum count of points.
#' @return Numeric vector \code{c(lon1, lat1, lon2, lat2, ...)}.
#' @noRd
coords_run_flags <- function(rows, lat, lon, max = 5000L) {
    if (length(rows) == 0L) {
        return(numeric(0))
    }
    pts <- coords_run_points(lat[rows], lon[rows], max = max)
    as.vector(rbind(pts$lon, pts$lat))
}

#' Progress of a coordinates run, for the run stage
#'
#' @param active Index of the step in progress, from 1 to 6. A value of 7
#'   means that every step is done.
#' @param hits Named integer vector: records that each test flags first, for
#'   "validity", "sea", "zero_equal" and "reference".
#' @param n_records Count of records.
#' @param lang Language code.
#' @return List with \code{pct}, \code{done}, \code{eyebrow}, \code{count},
#'   \code{map_label} and \code{steps}: one list per step with \code{key},
#'   \code{label}, \code{state}, \code{state_label} and \code{hit}.
#' @noRd
coords_run_progress <- function(active, hits, n_records, lang = "pt") {
    keys <- coords_run_step_keys()
    active <- as.integer(active)
    done <- active > length(keys)
    records <- format_count(as.integer(n_records), lang)
    count <- if (done) {
        sprintf(tr("validate_coords_run_count_done", lang), format_count(as.integer(sum(hits)), lang), records)
    } else if (active <= 2L) {
        sprintf(tr("validate_coords_run_count_prep", lang), records)
    } else {
        sprintf(tr("validate_coords_run_count", lang), active - 2L, records)
    }
    steps <- lapply(seq_along(keys), function(i) {
        key <- keys[i]
        step_state <- if (i < active) "done" else if (i == active) "active" else "next"
        n_hits <- if (key %in% names(hits)) as.integer(hits[[key]]) else NA_integer_
        state_label <- if (identical(step_state, "done") && !is.na(n_hits)) {
            sprintf(tr(paste0("validate_coords_run_hits_", key), lang), format_count(n_hits, lang))
        } else {
            tr(paste0("validate_names_run_state_", step_state), lang)
        }
        list(
            key = key,
            label = tr(paste0("validate_coords_run_step_", key), lang),
            state = step_state,
            state_label = state_label,
            hit = identical(step_state, "done") && isTRUE(n_hits > 0L)
        )
    })
    list(
        pct = round(100 * (min(active, 7L) - 1L) / length(keys)),
        done = done,
        eyebrow = tr(if (done) "validate_coords_run_eyebrow_done" else "validate_coords_run_eyebrow", lang),
        count = count,
        map_label = tr("validate_coords_run_map_label", lang),
        steps = steps
    )
}

#' Step callback for validate_coords_cc_df() that reports to the run stage
#'
#' A record keeps the family of the first test that flags it, as in the
#' final diagnosis, so the counts match the filter pills.
#' @param send Function that takes one message list.
#' @param n_records Count of records.
#' @param lang Language code.
#' @return Function \code{(key, rows, lat, lon)}.
#' @noRd
coords_run_reporter <- function(send, n_records, lang = "pt") {
    keys <- coords_run_step_keys()
    seen <- logical(n_records)
    hits <- c(validity = 0L, sea = 0L, zero_equal = 0L, reference = 0L)
    function(key, rows = integer(0), lat = NULL, lon = NULL) {
        msg <- list(stage = "step")
        if (identical(key, "parse")) {
            msg$stage <- "map"
            msg$view <- coords_run_view(lat, lon)
        } else if (key %in% names(hits)) {
            rows <- rows[!seen[rows]]
            seen[rows] <<- TRUE
            hits[[key]] <<- length(rows)
            msg$family <- key
            msg$flags <- I(coords_run_flags(rows, lat, lon))
        }
        msg$progress <- coords_run_progress(match(key, keys) + 1L, hits, n_records, lang)
        send(msg)
        invisible(NULL)
    }
}
