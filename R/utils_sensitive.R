# Title: Sensitive-species coordinate masking
# Author: Rogerio Nunes Oliveira
#
# Pure helpers shared by the name-validation pill (display) and the export
# pipeline. No Shiny, no reactives. A bundled list of threatened species
# (inst/extdata/sensitive_species.rds, built from data-raw/redlist_brasil_mma.md)
# is matched against the validator's resolved scientificName; matched records
# have their coordinates generalized to a coarser grid on export.

sensitive_species_cache <- create_rds_cache("sensitive_species")

# Rows whose upstream `coordinateUncertaintyInMeters` already reaches this
# threshold are treated as pre-generalized by the publisher (e.g. a Camtrap
# DP package downloaded from GBIF/Wildlife Insights/Agouti where coords were
# fuzzed before export). We skip masking those rows so the publisher's
# generalization is not overwritten or stacked on top of ours.
#
# 1000 m alone misses Chapman category 4 (round_coordinates(x, 3) -> ~150 m
# uncertainty per Chapman & Wieczorek 2020 Table 3). The Camtrap DP package
# closes that gap by populating `dwc:dataGeneralizations` whenever the
# publisher set `coordinatePrecision` (PDF p.26), so we OR a non-empty
# `dataGeneralizations` into the skip condition.
SENSITIVE_ALREADY_MASKED_THRESHOLD_M <- 1000

# Resolve the bundled RDS path. Returns NA_character_ (not an error) when
# absent so the feature degrades gracefully instead of breaking export.
resolve_sensitive_species_path <- function() {
    candidates <- c(
        system.file("extdata", "sensitive_species.rds", package = "saira"),
        file.path("inst", "extdata", "sensitive_species.rds"),
        file.path("..", "..", "inst", "extdata", "sensitive_species.rds")
    )
    candidates <- unique(candidates[nzchar(candidates)])
    path <- candidates[file.exists(candidates)][1]
    if (is.null(path) || is.na(path) || !file.exists(path)) {
        return(NA_character_)
    }
    path
}

sensitive_species_empty <- function() {
    data.frame(
        scientificName = character(0),
        match_key = character(0),
        category = character(0),
        stringsAsFactors = FALSE
    )
}

# Threat categories ordered by restrictiveness (drives the export grid).
sensitive_category_levels <- function() c("VU", "EN", "CR", "CR (PEX)")

# Cached read of the sensitive-species lookup. Missing/invalid file -> a
# warning plus a zero-row frame (masking simply does nothing). The not-found
# case is not cached, so a later regenerate is picked up without force.
load_sensitive_species <- function(force = FALSE) {
    if (!isTRUE(force) && !is.null(sensitive_species_cache$get())) {
        return(sensitive_species_cache$get())
    }
    path <- resolve_sensitive_species_path()
    if (is.na(path)) {
        warning("sensitive_species.rds not found; coordinate masking disabled.")
        return(sensitive_species_empty())
    }
    df <- tryCatch(readRDS(path), error = function(e) NULL)
    if (!is.data.frame(df) ||
        !all(c("scientificName", "match_key") %in% names(df))) {
        warning("sensitive_species.rds is invalid; coordinate masking disabled.")
        return(sensitive_species_empty())
    }
    df$scientificName <- as.character(df$scientificName)
    df$match_key <- as.character(df$match_key)
    # Backward compatible: a pre-ADR-092 RDS has no category column. Treat
    # every taxon as CR (0.1 deg under the conservative scheme) so an old
    # artifact still masks, just without graduated precision.
    if (!"category" %in% names(df)) {
        warning("sensitive_species.rds has no 'category'; defaulting to CR.")
        df$category <- "CR"
    }
    df$category <- as.character(df$category)
    df$category[is.na(df$category) | !nzchar(df$category)] <- "CR"
    df <- df[!is.na(df$match_key) & nzchar(df$match_key), , drop = FALSE]
    rownames(df) <- NULL
    sensitive_species_cache$set(df, path = path)
    df
}

# Normalize names exactly as data-raw/generate_sensitive_species.R does, so
# the list and the validator's resolved names compare on identical keys.
build_sensitive_match_keys <- function(names) {
    if (length(names) == 0L) {
        return(character(0))
    }
    canonical <- vapply(
        as.character(names),
        function(nm) {
            normalize_scientific_name(
                nm,
                remove_authors = TRUE,
                ignore_qualifiers = TRUE
            )
        },
        FUN.VALUE = character(1),
        USE.NAMES = FALSE
    )
    normalize_for_matching(canonical)
}

# MMA threat category for each resolved name, or NA when not on the list.
# Single source of truth for the pill default and the export grid.
sensitive_category_for <- function(names) {
    n <- length(names)
    if (n == 0L) {
        return(character(0))
    }
    out <- rep(NA_character_, n)
    lookup <- load_sensitive_species()
    if (!is.data.frame(lookup) || nrow(lookup) == 0L ||
        is.null(lookup$category)) {
        return(out)
    }
    keys <- build_sensitive_match_keys(names)
    m <- match(keys, lookup$match_key)
    ok <- !is.na(keys) & nzchar(keys) & !is.na(m)
    out[ok] <- as.character(lookup$category)[m[ok]]
    out
}

# Logical vector: which of `names` are on the MMA list (pill display).
flag_sensitive_species <- function(names) {
    !is.na(sensitive_category_for(names))
}

# Round coordinates to a coarser grid (default 0.1 deg ~ 11 km). NA -> NA.
# The final round() removes binary float noise (e.g. -23.6 not -23.60000001).
generalize_coord <- function(x, grid = 0.1) {
    if (!is.numeric(grid) || length(grid) != 1L || is.na(grid) || grid <= 0) {
        stop("generalize_coord: 'grid' must be a single positive number.")
    }
    x <- suppressWarnings(as.numeric(x))
    round(round(x / grid) * grid, 6L)
}

# Format a coordinate for WKT (fixed notation, no scientific). Vectorized.
wkt_num <- function(x) formatC(x, format = "f", digits = 6)

# Great-circle distance in metres between lon/lat points (haversine, WGS84
# mean radius). Vectorized over either pair of coordinates.
geo_distance_m <- function(lon1, lat1, lon2, lat2) {
    R <- 6371008.8
    rad <- pi / 180
    dlat <- (lat2 - lat1) * rad
    dlon <- (lon2 - lon1) * rad
    a <- sin(dlat / 2)^2 +
        cos(lat1 * rad) * cos(lat2 * rad) * sin(dlon / 2)^2
    2 * R * asin(pmin(1, sqrt(a)))
}

# coordinateUncertaintyInMeters for a grid cell published at its CENTER: the
# "geographic radial" = the distance from the centre to the FURTHEST corner
# (Chapman & Wieczorek 2020, Georeferencing Best Practices sec. 2.3.4; Quick
# Reference Guide sec. 2.3.3 -- "use the corrected centre of the grid cell ...
# determine the geographic radial"). `grid` is the cell size in decimal
# degrees; `gen_lon`/`gen_lat` are the published cell centre(s). Geodesic, so
# the longitude convergence with latitude is handled exactly (the furthest
# corner is the one nearest the equator). Vectorized over the centres.
sensitive_grid_uncertainty_m <- function(grid, gen_lon, gen_lat) {
    d <- grid / 2
    d1 <- geo_distance_m(gen_lon, gen_lat, gen_lon - d, gen_lat - d)
    d2 <- geo_distance_m(gen_lon, gen_lat, gen_lon + d, gen_lat - d)
    d3 <- geo_distance_m(gen_lon, gen_lat, gen_lon + d, gen_lat + d)
    d4 <- geo_distance_m(gen_lon, gen_lat, gen_lon - d, gen_lat + d)
    pmax(d1, d2, d3, d4)
}

# Chapman 2020 (GBIF "Best Practices for Generalizing Sensitive Species
# Occurrence Data", Table 7) defines four global generalization tiers; the
# Saira UI exposes those four plus an explicit "not_sensitive" no-op. The
# user picks ONE tier that applies uniformly to every sensitive record. The
# MMA list still triggers detection, but it no longer governs the grid.
sensitive_generalization_levels <- function() {
    c("extreme", "high", "medium", "low", "not_sensitive")
}

# Grid (in decimal degrees) for a Chapman tier. NA means "no masking".
sensitive_generalization_grid <- function(level) {
    if (length(level) != 1L) level <- level[1]
    m <- c(extreme       = 1.0,
           high          = 0.1,
           medium        = 0.01,
           low           = 0.001,
           not_sensitive = NA_real_)
    if (!is.character(level) || is.na(level) || !(level %in% names(m))) {
        return(NA_real_)
    }
    unname(m[level])
}

# Condensed Chapman Table 5 "Decision on release" statement for a tier,
# documented at the record level so a data user knows WHY the coordinates were
# generalized (Chapman 2020 sec. 5, statements 4c-4f). Vectorized over `tier`;
# tiers without a statement (e.g. "not_sensitive") yield "".
sensitive_reason_statement <- function(tier, lang = "en") {
    keys <- c(extreme = "sensitive_reason_cat1",
              high    = "sensitive_reason_cat2",
              medium  = "sensitive_reason_cat3",
              low     = "sensitive_reason_cat4")
    vapply(as.character(tier), function(t) {
        k <- unname(keys[t])
        if (is.na(k)) "" else tr(k, lang)
    }, FUN.VALUE = character(1), USE.NAMES = FALSE)
}

# Resolve a per-row Chapman tier from the `generalization` argument of
# `mask_sensitive_coordinates`. Accepts either a single tier string (applies
# uniformly -- back-compat) or a named `scientificName -> tier` map (per-species
# assessment). Species absent from the map fall back to "not_sensitive".
resolve_row_tiers <- function(species, generalization) {
    n <- length(species)
    if (is.null(generalization) || length(generalization) == 0L) {
        return(rep("not_sensitive", n))
    }
    if (length(generalization) == 1L && is.null(names(generalization))) {
        return(rep(as.character(generalization), n))
    }
    map <- unlist(generalization)
    tiers <- unname(map[as.character(species)])
    tiers[is.na(tiers)] <- "not_sensitive"
    tiers
}

# Per-row sensitivity decision. The Validation > Names payload (researcher's
# marks) wins; rows it does not cover fall back to the MMA auto-match so an
# unseen species is still protected by default. `$category` is carried for
# display (the pill in Validation > Names) but is no longer consumed by
# `mask_sensitive_coordinates` -- the grid is global (Chapman 2020 method).
sensitive_resolve <- function(names, decisions = NULL) {
    # Resolve over UNIQUE names and expand back: callers (e.g.
    # generalization_map_preview) pass per-record vectors, and camera-trap data
    # repeats a handful of species across thousands of rows. The per-name key
    # building + MMA match is the dominant cost, so collapsing to unique names
    # is the difference between ~2.4 s and a few ms on large datasets.
    # (LESSONS: unique -> resolve -> match back.)
    names <- as.character(names)
    if (length(names) > 1L) {
        u <- unique(names)
        if (length(u) < length(names)) {
            res_u <- sensitive_resolve(u, decisions)
            m <- match(names, u)
            return(list(
                sensitive = res_u$sensitive[m],
                category = res_u$category[m]
            ))
        }
    }
    category <- sensitive_category_for(names)
    sensitive <- !is.na(category)
    if (is.data.frame(decisions) && nrow(decisions) > 0L &&
        all(c("scientificName", "sensitive") %in% names(decisions))) {
        dkey <- build_sensitive_match_keys(decisions$scientificName)
        nkey <- build_sensitive_match_keys(names)
        m <- match(nkey, dkey)
        has <- !is.na(m)
        as_bool <- function(x) {
            tolower(trimws(as.character(x))) %in% c("true", "1", "yes", "t")
        }
        sensitive[has] <- as_bool(decisions$sensitive[m[has]])
        # Backward-compat: a pre-Chapman payload may still carry `category`.
        # Honour it for display, but the masking grid is global so this is
        # purely cosmetic on the pill.
        if ("category" %in% names(decisions)) {
            ovr <- as.character(decisions$category[m[has]])
            keep <- !is.na(ovr) & nzchar(ovr)
            if (any(keep)) {
                pos <- which(has)[keep]
                category[pos] <- ovr[keep]
            }
        }
    }
    sensitive[is.na(sensitive)] <- FALSE
    list(sensitive = sensitive, category = category)
}

# Mask sensitive records on the post-process_for_export frame (which already
# carries occurrenceID, scientificName and the coordinate columns).
#
# Per-species generalization (Chapman 2020 Table 5/7). `generalization` is
# either a single tier string ("extreme"/"high"/"medium"/"low") applied to every
# sensitive row (back-compat) OR a named `scientificName -> tier` map produced by
# the Preview questionnaire, so each species is generalized to the grid its
# Chapman assessment derived. Species mapped to "not_sensitive" (or unassessed)
# and `enabled = FALSE` are left as-held; an all-no-op call returns the input
# byte-identical.
#
# Returns:
#   masked   : generalized coords + dataGeneralizations / informationWithheld
#              / coordinateUncertaintyInMeters / coordinatePrecision set, and
#              the leak fields scrubbed on sensitive rows; every other row
#              byte-identical to the input.
#   real     : occurrenceID + scientificName + category + the ORIGINAL
#              coordinates for the masked rows (researcher's private file).
#              `category` here is the MMA tag (CR/EN/VU/CR PEX) when known,
#              "\u2014" when the row was flagged by a researcher override outside
#              the MMA list.
#   n_masked : count of rows whose coordinates were generalized.
mask_sensitive_coordinates <- function(df, decisions = NULL,
                                        generalization = "low",
                                        enabled = TRUE, lang = "en",
                                        justification = NULL) {
    result <- list(
        masked = df,
        real = data.frame(
            occurrenceID = character(0),
            scientificName = character(0),
            category = character(0),
            decimalLatitude = character(0),
            decimalLongitude = character(0),
            stringsAsFactors = FALSE
        ),
        n_masked = 0L,
        n_skipped_already_masked = 0L
    )

    if (!isTRUE(enabled)) {
        return(result)
    }
    if (!is.data.frame(df) || nrow(df) == 0L) {
        return(result)
    }
    needed <- c("scientificName", "decimalLatitude", "decimalLongitude")
    if (!all(needed %in% names(df))) {
        return(result)
    }

    decided <- sensitive_resolve(df$scientificName, decisions)
    # Per-row Chapman tier and its grid. Rows whose species resolve to
    # "not_sensitive"/unassessed get NA grid and are left untouched below.
    row_tier <- resolve_row_tiers(df$scientificName, generalization)
    # Grid per row, resolved over the few unique tiers (<= 5) and mapped back --
    # calling sensitive_generalization_grid per record is O(n) for no reason.
    row_tier_u <- unique(row_tier)
    row_grid <- vapply(row_tier_u, sensitive_generalization_grid,
                       FUN.VALUE = numeric(1), USE.NAMES = FALSE)[match(row_tier, row_tier_u)]
    lat_num <- suppressWarnings(as.numeric(df$decimalLatitude))
    lon_num <- suppressWarnings(as.numeric(df$decimalLongitude))
    target <- decided$sensitive & !is.na(lat_num) & !is.na(lon_num) &
        !is.na(row_grid) & row_grid > 0

    # Honour upstream generalization (ADR-095). Two signals:
    #   1. `coordinateUncertaintyInMeters` >= 1000 m -- publisher who fuzzed
    #      via grid >= 0.01 deg, or who explicitly set a wide uncertainty.
    #   2. `dataGeneralizations` non-empty -- guaranteed by
    #      `camtrapdp::write_dwc()` when the publisher set
    #      `coordinatePrecision` (PDF p.26), covering Chapman category 4
    #      generalization (3 digits -> ~150 m uncertainty, below 1000 m).
    # Skip those rows so we neither overwrite their values nor leak them
    # into the `real` companion file (we do not have the originals).
    existing_unc <- if ("coordinateUncertaintyInMeters" %in% names(df)) {
        suppressWarnings(as.numeric(df$coordinateUncertaintyInMeters))
    } else {
        rep(NA_real_, nrow(df))
    }
    existing_dg <- if ("dataGeneralizations" %in% names(df)) {
        trimws(as.character(df$dataGeneralizations))
    } else {
        rep("", nrow(df))
    }
    existing_dg[is.na(existing_dg)] <- ""
    already_masked <- (!is.na(existing_unc) &
        existing_unc >= SENSITIVE_ALREADY_MASKED_THRESHOLD_M) |
        nzchar(existing_dg)
    result$n_skipped_already_masked <- sum(target & already_masked)
    target <- target & !already_masked
    if (!any(target)) {
        return(result)
    }
    idx <- which(target)
    row_cat <- decided$category[idx]
    row_cat_display <- ifelse(is.na(row_cat) | !nzchar(row_cat), "\u2014", row_cat)

    occ <- if ("occurrenceID" %in% names(df)) {
        as.character(df$occurrenceID)
    } else {
        as.character(seq_len(nrow(df)))
    }

    result$real <- data.frame(
        occurrenceID = occ[idx],
        scientificName = as.character(df$scientificName)[idx],
        category = row_cat_display,
        decimalLatitude = as.character(df$decimalLatitude)[idx],
        decimalLongitude = as.character(df$decimalLongitude)[idx],
        stringsAsFactors = FALSE
    )

    ensure_cols <- c("dataGeneralizations", "informationWithheld",
                     "coordinateUncertaintyInMeters", "coordinatePrecision",
                     "footprintWKT", "footprintSRS")
    had_cols <- all(ensure_cols %in% names(df))

    masked <- df
    ensure_col <- function(d, name) {
        if (!name %in% names(d)) {
            d[[name]] <- rep("", nrow(d))
        }
        d[[name]] <- as.character(d[[name]])
        d[[name]][is.na(d[[name]])] <- ""
        d
    }
    for (nm in ensure_cols) masked <- ensure_col(masked, nm)
    iw_text <- tr("sensitive_information_withheld", lang)
    # Optional custodian justification, appended to dataGeneralizations after
    # the auto Chapman reason on every masked row.
    just_text <- if (is.null(justification)) "" else trimws(as.character(justification)[1])
    if (is.na(just_text)) just_text <- ""

    # Apply each species' own grid. Grouping by grid (one of four distinct
    # values, bijective with the Chapman tier) keeps `generalize_coord` the
    # single source of the rounding rule. `dataGeneralizations` carries the MMA
    # category, the grid, and the Chapman Table 5 reason for the record.
    for (g in unique(row_grid[idx])) {
        rows <- idx[row_grid[idx] == g]
        cat_disp <- row_cat_display[row_grid[idx] == g]
        masked$decimalLatitude[rows]  <- generalize_coord(lat_num[rows], g)
        masked$decimalLongitude[rows] <- generalize_coord(lon_num[rows], g)
        masked$coordinatePrecision[rows] <- format(g, trim = TRUE, scientific = FALSE)
        gen_lon <- suppressWarnings(as.numeric(masked$decimalLongitude[rows]))
        gen_lat <- suppressWarnings(as.numeric(masked$decimalLatitude[rows]))
        # coordinateUncertaintyInMeters = geographic radial of the cell (centre
        # -> furthest corner) COMBINED with any original record uncertainty
        # (Best Practices sec. 3.4.7: combine sources, not take the max). The
        # original point lies within its own radius of the published cell
        # centre, so the guaranteed maximum distance is additive.
        existing <- suppressWarnings(
            as.numeric(masked$coordinateUncertaintyInMeters[rows])
        )
        existing[is.na(existing)] <- 0
        masked$coordinateUncertaintyInMeters[rows] <- as.character(ceiling(
            sensitive_grid_uncertainty_m(g, gen_lon, gen_lat) + existing
        ))
        # Capture the cell as a polygon (Best Practices sec. 2.3.4: "the ideal
        # way to record [a grid cell] ... is the polygon consisting of the
        # corners"). Safe to publish -- it is the coarse cell, not the point.
        half <- g / 2
        masked$footprintWKT[rows] <- sprintf(
            "POLYGON ((%s %s, %s %s, %s %s, %s %s, %s %s))",
            wkt_num(gen_lon - half), wkt_num(gen_lat - half),
            wkt_num(gen_lon + half), wkt_num(gen_lat - half),
            wkt_num(gen_lon + half), wkt_num(gen_lat + half),
            wkt_num(gen_lon - half), wkt_num(gen_lat + half),
            wkt_num(gen_lon - half), wkt_num(gen_lat - half)
        )
        masked$footprintSRS[rows] <- "EPSG:4326"
        masked$dataGeneralizations[rows] <- trimws(paste(
            sprintf(
                tr("sensitive_data_generalizations", lang),
                cat_disp,
                format(g, trim = TRUE, scientific = FALSE)
            ),
            sensitive_reason_statement(row_tier[rows], lang),
            just_text
        ))
    }
    masked$informationWithheld[idx] <- iw_text

    # Scrub fields that could reverse the generalization. Verbatim coordinate
    # fields must be blank (Darwin Core forbids prose there); the remaining
    # locality/remarks fields carry replacement wording (Chapman sec. 3).
    # footprintWKT is NOT scrubbed here: the loop above already replaced it with
    # the generalized cell polygon (safe, coarse) on every masked row.
    blank_cols <- c("verbatimLatitude", "verbatimLongitude",
                    "verbatimCoordinates")
    scrub_cols <- c("locality", "verbatimLocality",
                    "georeferenceRemarks", "locationRemarks")
    for (col in intersect(blank_cols, names(masked))) {
        masked[[col]] <- as.character(masked[[col]])
        masked[[col]][idx] <- ""
    }
    for (col in intersect(scrub_cols, names(masked))) {
        masked[[col]] <- as.character(masked[[col]])
        masked[[col]][idx] <- iw_text
    }

    # Newly created columns land at the right side; re-sort into their DwC
    # blocks. Skipped when the columns already existed (positions unchanged).
    if (!had_cols) {
        masked <- order_columns_dwc_canonical(masked)
    }

    result$masked <- masked
    result$n_masked <- length(idx)
    result
}

# Map-preview rows for the generalization guardrail (ADR-100). For every point
# that WOULD be masked at the current assessment, returns where it moves and a
# `crosses` flag set when the generalized point lands in a different country than
# the original -- the border-crossing red signal (e.g. a Turvo jaguar generalized
# to `extreme` defecting into Argentina). Pure; the country lookup reuses the
# Natural Earth reference behind `coords_country_from_coordinates()` and degrades
# to `crosses = NA` when sf/terra/reference are unavailable.
generalization_map_preview <- function(df, generalization, decisions = NULL) {
    empty <- data.frame(
        scientificName = character(0), tier = character(0),
        lat = numeric(0), lon = numeric(0),
        gen_lat = numeric(0), gen_lon = numeric(0), unc_m = numeric(0),
        country_orig = character(0), country_gen = character(0),
        crosses = logical(0), stringsAsFactors = FALSE
    )
    needed <- c("scientificName", "decimalLatitude", "decimalLongitude")
    if (!is.data.frame(df) || nrow(df) == 0L || !all(needed %in% names(df))) {
        return(empty)
    }
    decided <- sensitive_resolve(df$scientificName, decisions)
    row_tier <- resolve_row_tiers(df$scientificName, generalization)
    # Grid per row, resolved over the few unique tiers (<= 5) and mapped back --
    # calling sensitive_generalization_grid per record is O(n) for no reason.
    row_tier_u <- unique(row_tier)
    row_grid <- vapply(row_tier_u, sensitive_generalization_grid,
                       FUN.VALUE = numeric(1), USE.NAMES = FALSE)[match(row_tier, row_tier_u)]
    lat <- suppressWarnings(as.numeric(df$decimalLatitude))
    lon <- suppressWarnings(as.numeric(df$decimalLongitude))
    target <- decided$sensitive & !is.na(lat) & !is.na(lon) &
        !is.na(row_grid) & row_grid > 0
    if (!any(target)) return(empty)
    idx <- which(target)
    g <- row_grid[idx]
    gen_lat <- round(round(lat[idx] / g) * g, 6L)
    gen_lon <- round(round(lon[idx] / g) * g, 6L)
    # Same point-radius uncertainty the export writes (centre -> furthest
    # corner, combined additively with any original record uncertainty).
    unc0 <- if ("coordinateUncertaintyInMeters" %in% names(df)) {
        suppressWarnings(as.numeric(df$coordinateUncertaintyInMeters))[idx]
    } else {
        rep(0, length(idx))
    }
    unc0[is.na(unc0)] <- 0

    out <- data.frame(
        scientificName = as.character(df$scientificName)[idx],
        tier = row_tier[idx],
        lat = lat[idx], lon = lon[idx],
        gen_lat = gen_lat, gen_lon = gen_lon,
        unc_m = ceiling(sensitive_grid_uncertainty_m(g, gen_lon, gen_lat) + unc0),
        country_orig = NA_character_, country_gen = NA_character_,
        crosses = NA, stringsAsFactors = FALSE
    )

    # Best-effort country (admin) lookup for original vs generalized points.
    ref <- tryCatch(coords_load_ne_land(scale = 50L), error = function(e) NULL)
    if (!is.null(ref) && inherits(ref, "SpatVector") && "admin" %in% names(ref)) {
        admin_at <- function(lo, la) {
            # Camera-trap data repeats the same coordinates across thousands of
            # records, so resolve the admin (country) over UNIQUE points only and
            # map back -- terra::extract over every row is the dominant cost here
            # (and it runs for both the original and the generalized point sets).
            key <- paste(lo, la, sep = "|")
            uk <- unique(key)
            ui <- match(uk, key)
            pts <- terra::vect(
                data.frame(.lon = lo[ui], .lat = la[ui]),
                geom = c(".lon", ".lat"),
                crs = "+proj=longlat +datum=WGS84 +no_defs"
            )
            ex <- tryCatch(terra::extract(ref[, "admin"], pts), error = function(e) NULL)
            if (is.null(ex) || ncol(ex) < 2L) return(rep(NA_character_, length(lo)))
            ex <- ex[!duplicated(ex[[1]]), , drop = FALSE]
            # ex ID column is 1..length(uk) in order, so this is the per-unique
            # admin; expand it back to the per-record order.
            u_admin <- as.character(ex[[2]])
            u_admin[match(key, uk)]
        }
        out$country_orig <- admin_at(out$lon, out$lat)
        out$country_gen  <- admin_at(out$gen_lon, out$gen_lat)
        out$crosses <- !is.na(out$country_orig) &
            (is.na(out$country_gen) | out$country_orig != out$country_gen)
    }
    out
}
