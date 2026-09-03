# Title: UTM Coordinate Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-09-03
# Version: 1.0

#' @include utils_coords.R
NULL

# Datums a Brazilian dataset realistically carries, with the EPSG base for each
# hemisphere. The code for a zone is base + zone, which the PROJ database
# confirms for every zone listed here; coords_utm_epsg() still validates before
# handing the code to sf, so a gap in the database surfaces as an error rather
# than as a silently wrong projection.
#
# SIRGAS 2000 is the Brazilian legal datum since 2015 and the default. WGS 84
# sits within a metre of it here, so the two are interchangeable in practice.
# SAD69 and Corrego Alegre are older and shift a point by tens of metres, which
# is why they are offered rather than assumed.
coords_utm_datums <- function() {
    list(
        SIRGAS2000 = list(label = "SIRGAS 2000", north = 31954L, south = 31960L, zones = 17:25),
        WGS84 = list(label = "WGS 84", north = 32600L, south = 32700L, zones = 1:60),
        SAD69 = list(label = "SAD69", north = NA_integer_, south = 29170L, zones = 18:25),
        CORREGO = list(label = "Corrego Alegre", north = NA_integer_, south = 22500L, zones = 21:25)
    )
}

coords_utm_default_datum <- function() "SIRGAS2000"

# Easting is bounded by the 6-degree zone width; northing counts metres from the
# equator, southwards from a 10,000 km false origin below it. The ranges are
# deliberately generous: the point here is to tell a projected pair from degrees,
# not to validate the survey.
coords_utm_easting_range <- function() c(100000, 900000)

coords_utm_northing_range <- function() c(0, 10000000)

#' Flag coordinate pairs that carry projected (UTM) values instead of degrees
#'
#' A pair qualifies when neither value can be read as degrees and both sit in
#' the magnitude bands a UTM easting/northing occupy. Order is not assumed: a
#' spreadsheet often files the easting under `decimalLatitude`.
#'
#' @param a,b Numeric vectors of the same length (the two coordinate columns).
#' @return Logical vector, `TRUE` where the pair looks projected.
#' @noRd
coords_is_projected_pair <- function(a, b) {
    a <- suppressWarnings(as.numeric(a))
    b <- suppressWarnings(as.numeric(b))
    n <- max(length(a), length(b))
    if (n == 0L) {
        return(logical(0))
    }

    east_rng <- coords_utm_easting_range()
    north_rng <- coords_utm_northing_range()

    in_east <- function(x) !is.na(x) & x >= east_rng[[1]] & x <= east_rng[[2]]
    in_north <- function(x) !is.na(x) & x >= north_rng[[1]] & x <= north_rng[[2]]

    # Degrees are never this large, so a pair that still reads as a plausible
    # lat/lon is left alone -- swapped or out-of-range degrees are somebody
    # else's diagnosis (see coord_issue_levels).
    as_degrees <- !is.na(a) & !is.na(b) &
        abs(a) <= 90 & abs(b) <= 180

    !as_degrees &
        ((in_east(a) & in_north(b)) | (in_north(a) & in_east(b)))
}

#' Decide which of the two values is the easting and which is the northing
#'
#' Told apart by magnitude: a northing carries the distance from the equator and
#' runs to seven or eight digits, while an easting is bounded by the zone width
#' and stays under six. Values that do not resolve come back as `NA`.
#'
#' @param a,b Numeric vectors of the same length.
#' @return List with `easting` and `northing` numeric vectors.
#' @noRd
coords_utm_assign_axes <- function(a, b) {
    a <- suppressWarnings(as.numeric(a))
    b <- suppressWarnings(as.numeric(b))
    n <- max(length(a), length(b))

    easting <- rep(NA_real_, n)
    northing <- rep(NA_real_, n)
    if (n == 0L) {
        return(list(easting = easting, northing = northing))
    }

    east_rng <- coords_utm_easting_range()
    north_rng <- coords_utm_northing_range()
    in_east <- function(x) !is.na(x) & x >= east_rng[[1]] & x <= east_rng[[2]]
    in_north <- function(x) !is.na(x) & x >= north_rng[[1]] & x <= north_rng[[2]]

    # A northing above the easting ceiling is unambiguous. Below it both values
    # are in range for either axis, and the larger one is the northing.
    a_is_east <- in_east(a) & in_north(b) & (b > a | b > east_rng[[2]])
    b_is_east <- in_east(b) & in_north(a) & (a > b | a > east_rng[[2]])

    easting[a_is_east] <- a[a_is_east]
    northing[a_is_east] <- b[a_is_east]
    easting[b_is_east] <- b[b_is_east]
    northing[b_is_east] <- a[b_is_east]

    list(easting = easting, northing = northing)
}

#' Resolve the EPSG code for a UTM zone, hemisphere and datum
#'
#' @param zone Integer UTM zone.
#' @param hemisphere `"S"` or `"N"`.
#' @param datum Key of `coords_utm_datums()`.
#' @return Integer EPSG code.
#' @noRd
coords_utm_epsg <- function(zone, hemisphere = "S", datum = coords_utm_default_datum()) {
    zone <- suppressWarnings(as.integer(zone))
    hemisphere <- toupper(as.character(hemisphere))
    datums <- coords_utm_datums()

    if (is.na(zone) || !datum %in% names(datums) || !hemisphere %in% c("N", "S")) {
        stop("Invalid UTM zone, hemisphere or datum.", call. = FALSE)
    }

    spec <- datums[[datum]]
    if (!zone %in% spec$zones) {
        stop(sprintf("%s does not cover UTM zone %d.", spec$label, zone), call. = FALSE)
    }

    base <- if (identical(hemisphere, "S")) spec$south else spec$north
    if (is.na(base)) {
        stop(sprintf("%s has no northern-hemisphere zones.", spec$label), call. = FALSE)
    }

    epsg <- base + zone
    # The formula is only a shortcut into the PROJ database. Confirm the code
    # resolves before it reaches sf, so a missing definition fails loudly here
    # instead of projecting points to the wrong place.
    valid <- tryCatch(!is.na(sf::st_crs(epsg)$Name), error = function(e) FALSE)
    if (!isTRUE(valid)) {
        stop(sprintf("EPSG:%d is not available for %s zone %d%s.",
                     epsg, spec$label, zone, hemisphere), call. = FALSE)
    }

    epsg
}

#' Convert projected UTM values to WGS 84 degrees
#'
#' @param easting,northing Numeric vectors of the same length.
#' @param zone Integer UTM zone.
#' @param hemisphere `"S"` or `"N"`.
#' @param datum Key of `coords_utm_datums()`.
#' @return Data frame with `decimalLatitude` and `decimalLongitude`, `NA` where
#'   the input pair was incomplete.
#' @noRd
coords_utm_to_wgs84 <- function(easting, northing, zone, hemisphere = "S",
                                datum = coords_utm_default_datum()) {
    easting <- suppressWarnings(as.numeric(easting))
    northing <- suppressWarnings(as.numeric(northing))
    n <- max(length(easting), length(northing))

    out <- data.frame(
        decimalLatitude = rep(NA_real_, n),
        decimalLongitude = rep(NA_real_, n),
        stringsAsFactors = FALSE
    )
    if (n == 0L) {
        return(out)
    }

    epsg <- coords_utm_epsg(zone = zone, hemisphere = hemisphere, datum = datum)
    ok <- !is.na(easting) & !is.na(northing)
    if (!any(ok)) {
        return(out)
    }

    # Projected over unique pairs: a camera-trap upload repeats the same station
    # across thousands of rows, and st_transform costs the same per point
    # whether or not it has seen the coordinate before.
    pairs <- paste(easting[ok], northing[ok], sep = "|")
    uniq <- !duplicated(pairs)
    src <- sf::st_as_sf(
        data.frame(x = easting[ok][uniq], y = northing[ok][uniq]),
        coords = c("x", "y"), crs = epsg
    )
    lonlat <- sf::st_coordinates(sf::st_transform(src, 4326))

    idx <- match(pairs, pairs[uniq])
    out$decimalLatitude[ok] <- lonlat[idx, 2L]
    out$decimalLongitude[ok] <- lonlat[idx, 1L]
    out
}

#' UTM zone covering a longitude
#'
#' @param lon Numeric longitude in degrees.
#' @return Integer zone, `NA` for an unusable longitude.
#' @noRd
coords_utm_zone_from_lon <- function(lon) {
    lon <- suppressWarnings(as.numeric(lon))
    zone <- floor((lon + 180) / 6) + 1
    zone[is.na(lon) | lon < -180 | lon > 180] <- NA_real_
    as.integer(pmin(pmax(zone, 1), 60))
}

# Point-in-country reference used to rank zone candidates. Natural Earth ships
# rings that the s2 spherical engine rejects, so the lookup runs in planar mode
# and restores the previous setting on exit -- the setting is global, and the
# generalization module shares this sf session.
coords_utm_country_ref <- function(scale = 110L) {
    if (!requireNamespace("rnaturalearth", quietly = TRUE)) {
        return(NULL)
    }
    tryCatch(
        rnaturalearth::ne_countries(scale = scale, returnclass = "sf")[, "iso_a3"],
        error = function(e) NULL
    )
}

#' Rank the UTM zones that could have produced a set of projected coordinates
#'
#' A zone cannot be read off the numbers: the same easting/northing pair is
#' valid in every zone, and each one places the point exactly six degrees of
#' longitude from the next, at the same latitude. Only an outside reference
#' decides, so the declared country is used to score candidates.
#'
#' Even then the answer is often not unique -- a country as wide as Brazil spans
#' several zones -- which is why this ranks candidates instead of picking one.
#' The caller is expected to confirm the choice with the user.
#'
#' @param easting,northing Numeric vectors of the same length.
#' @param country_iso3 Character vector of ISO3 codes, or `NULL` when the
#'   dataset declares no country.
#' @param hemisphere `"S"` or `"N"`.
#' @param datum Key of `coords_utm_datums()`.
#' @param sample_n How many distinct coordinate pairs to test per zone.
#' @return Data frame ordered by descending `share`: `zone`, `matched`,
#'   `tested`, `share`. Empty when nothing could be tested.
#' @noRd
coords_utm_zone_candidates <- function(easting, northing, country_iso3 = NULL,
                                       hemisphere = "S",
                                       datum = coords_utm_default_datum(),
                                       sample_n = 200L) {
    empty <- data.frame(
        zone = integer(0), matched = integer(0),
        tested = integer(0), share = numeric(0),
        stringsAsFactors = FALSE
    )

    easting <- suppressWarnings(as.numeric(easting))
    northing <- suppressWarnings(as.numeric(northing))
    ok <- !is.na(easting) & !is.na(northing)
    if (!any(ok)) {
        return(empty)
    }

    pairs <- !duplicated(paste(easting[ok], northing[ok], sep = "|"))
    east_s <- utils::head(easting[ok][pairs], sample_n)
    north_s <- utils::head(northing[ok][pairs], sample_n)

    target <- if (is.null(country_iso3)) {
        NA_character_
    } else {
        iso <- as.character(country_iso3)
        iso <- iso[!is.na(iso) & nzchar(iso)]
        if (!length(iso)) NA_character_ else names(sort(table(iso), decreasing = TRUE))[[1]]
    }

    ref <- if (is.na(target)) NULL else coords_utm_country_ref()
    if (is.null(ref)) {
        return(empty)
    }

    old_s2 <- suppressMessages(sf::sf_use_s2(FALSE))
    on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)

    zones <- coords_utm_datums()[[datum]]$zones
    rows <- lapply(zones, function(z) {
        converted <- tryCatch(
            coords_utm_to_wgs84(east_s, north_s, zone = z, hemisphere = hemisphere, datum = datum),
            error = function(e) NULL
        )
        if (is.null(converted)) {
            return(NULL)
        }

        pts <- sf::st_as_sf(
            converted, coords = c("decimalLongitude", "decimalLatitude"), crs = 4326
        )
        hit <- tryCatch(
            suppressMessages(sf::st_join(pts, ref, join = sf::st_within)),
            error = function(e) NULL
        )
        if (is.null(hit)) {
            return(NULL)
        }

        matched <- sum(!is.na(hit$iso_a3) & hit$iso_a3 == target)
        data.frame(
            zone = as.integer(z), matched = as.integer(matched),
            tested = length(east_s), share = matched / length(east_s),
            stringsAsFactors = FALSE
        )
    })

    out <- do.call(rbind, Filter(Negate(is.null), rows))
    if (is.null(out) || !nrow(out)) {
        return(empty)
    }

    out <- out[out$matched > 0L, , drop = FALSE]
    if (!nrow(out)) {
        return(empty)
    }

    out <- out[order(-out$share, out$zone), , drop = FALSE]
    rownames(out) <- NULL
    out
}

#' Describe the source projection for the verbatim Darwin Core terms
#'
#' The zone and datum the user confirmed are the only record of how the original
#' numbers should be read. Written alongside the preserved pair, they let a
#' reader reproduce the conversion instead of guessing at seven-digit values.
#'
#' @param zone Integer UTM zone.
#' @param hemisphere `"S"` or `"N"`.
#' @param datum Key of `coords_utm_datums()`.
#' @return List with `system` (`verbatimCoordinateSystem`) and `srs`
#'   (`verbatimSRS`), or `NULL` when the combination has no EPSG code.
#' @noRd
coords_utm_srs_label <- function(zone, hemisphere = "S", datum = coords_utm_default_datum()) {
    epsg <- tryCatch(
        coords_utm_epsg(zone = zone, hemisphere = hemisphere, datum = datum),
        error = function(e) NULL
    )
    if (is.null(epsg)) {
        return(NULL)
    }

    list(
        system = sprintf("UTM zone %d%s", as.integer(zone), toupper(hemisphere)),
        srs = sprintf("EPSG:%d", epsg)
    )
}
