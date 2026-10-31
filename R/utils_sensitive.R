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
        source = character(0),
        stringsAsFactors = FALSE
    )
}

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
    # Backward compatible: an RDS built before the source column simply has no
    # provenance. mmaSource is then omitted from the export (NA -> no key).
    if (!"source" %in% names(df)) {
        df$source <- NA_character_
    }
    df$source <- as.character(df$source)
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
    # A dataset repeats few species over many rows: normalize each name once.
    names <- as.character(names)
    uniq <- unique(names)
    canonical <- vapply(
        uniq,
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
    normalize_for_matching(canonical)[match(names, uniq)]
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

# Portaria that listed each name (e.g. "Portaria 1.704/2026"), or NA when the
# name is not on the MMA list or the bundled list predates the source column.
# Feeds the mmaSource conservation-status field on export; mirrors the matching
# in sensitive_category_for() so the two line up row for row.
sensitive_source_for <- function(names) {
    n <- length(names)
    if (n == 0L) {
        return(character(0))
    }
    out <- rep(NA_character_, n)
    lookup <- load_sensitive_species()
    if (!is.data.frame(lookup) || nrow(lookup) == 0L ||
        is.null(lookup$source)) {
        return(out)
    }
    keys <- build_sensitive_match_keys(names)
    m <- match(keys, lookup$match_key)
    ok <- !is.na(keys) & nzchar(keys) & !is.na(m)
    out[ok] <- as.character(lookup$source)[m[ok]]
    out
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

# Category number the UI shows for a tier: 1 is the most aggressive grid, 4 the
# least. NA for anything outside the four masking tiers.
sensitive_tier_category_number <- function(tier) {
    match(tier, c("extreme", "high", "medium", "low"))
}

# Tiers that generalize LESS than every tier in `tiers` -- what to suggest when a
# generalized point lands outside its country of origin. Taken from the least
# aggressive tier present, not the most, so a single suggestion resolves every
# species crossing the border at once. Empty when any of them already sits on
# `low`: there is nothing coarser to back off to, and the border crossing is then
# real rather than an artefact of the grid.
sensitive_less_aggressive_tiers <- function(tiers) {
    masking <- c("extreme", "high", "medium", "low")
    ranks <- sensitive_tier_category_number(tiers)
    ranks <- ranks[!is.na(ranks)]
    if (length(ranks) == 0L || max(ranks) >= length(masking)) {
        return(character(0))
    }
    masking[seq.int(max(ranks) + 1L, length(masking))]
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

# Precision grid implied by a coordinate's decimal places, read from the LITERAL
# string so trailing zeros count ("-81.40" -> 2 decimals -> 0.01, which
# as.numeric() would collapse to 1). No decimal point -> 0 places -> grid 1.0.
# Blank/NA -> NA (no precision signal). Vectorized.
coordinate_decimal_grid <- function(x) {
    s <- trimws(as.character(x))
    grid <- rep(NA_real_, length(s))
    ok <- !is.na(s) & nzchar(s)
    if (!any(ok)) return(grid)
    # Drop the integer part (everything up to the first "." or decimal ","),
    # then the separator, then keep only the leading run of digits (defends
    # against stray suffixes).
    dec <- sub("^[^.,]*", "", s[ok])
    dec <- sub("^[.,]", "", dec)
    dec <- regmatches(dec, regexpr("^[0-9]*", dec))
    grid[ok] <- 10^(-nchar(dec))
    grid
}

# Per-row coarsest existing precision (the LARGEST grid the data already sits on),
# used to block generalizing to a finer grid than the coordinates carry -- which
# would fabricate precision. Coarsest of: decimal places of decimalLatitude and
# decimalLongitude, plus an explicit `coordinatePrecision` column when present.
# NA where no signal exists (then no lock applies). Vectorized over rows.
existing_precision_grid <- function(df) {
    n <- if (is.data.frame(df)) nrow(df) else 0L
    get_col <- function(nm) {
        if (is.data.frame(df) && nm %in% names(df)) df[[nm]] else rep(NA_character_, n)
    }
    lat_g <- coordinate_decimal_grid(get_col("decimalLatitude"))
    lon_g <- coordinate_decimal_grid(get_col("decimalLongitude"))
    g <- pmax(lat_g, lon_g, na.rm = TRUE)
    if (is.data.frame(df) && "coordinatePrecision" %in% names(df)) {
        cp <- suppressWarnings(as.numeric(df[["coordinatePrecision"]]))
        g <- pmax(g, cp, na.rm = TRUE)
    }
    # pmax(na.rm = TRUE) returns -Inf when every input is NA; normalize to NA so
    # "no precision signal" stays distinct from "infinitely coarse".
    g[!is.finite(g)] <- NA_real_
    g
}

# The declared uncertainty in meters, or NA when the value is not a valid one.
# "30 m" reads as 30, while "-5" and "999999999" (larger than the Earth) read
# as NA, so they neither add to the cell radius nor count as a generalization.
uncertainty_meters <- function(x) {
    suppressWarnings(as.numeric(suggest_uncertainty(x)))
}

# A point the generalization can move: both axes numeric and in range, not at
# (0, 0) and not a copy of one axis into the other. Any other point of a
# sensitive species is withheld, because a swapped or a UTM pair still shows
# where the animal is.
sensitive_point_ok <- function(lat, lon) {
    is.finite(lat) & is.finite(lon) & abs(lat) <= 90 & abs(lon) <= 180 &
        !(abs(lat) < 0.5 & abs(lon) < 0.5) & lat != lon
}

# The openings of every coordinate note that a Saira version wrote, and of the
# camtrapdp `write_dwc()` note. Frozen text, not tr(): a new wording of
# `sensitive_data_generalizations` adds its opening here and keeps the old
# ones, so a file from an older version stays recognized.
# test-utils-sensitive.R fails when the current note has no opening here.
COORDINATE_NOTE_OPENINGS <- c(
    "Coordenadas generalizadas para ",     # pt, v0.2.5
    "Coordinates generalized to ",         # en, v0.2.5
    "Coordenadas de esp\u00e9cie ",        # pt, v0.3.0 and later
    "Coordinates of a ",                   # en, v0.3.0 and later
    "Coordenadas de una especie ",         # es, v1.0.0 and later
    "coordinates rounded to"               # camtrapdp write_dwc()
)

# A `dataGeneralizations` note that says the coordinates were generalized
# (COORDINATE_NOTE_OPENINGS). A note about other data, such as "Dates
# normalized", says nothing about the point (AUD-03). Vectorized.
coordinate_generalization_note <- function(x) {
    escaped <- gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", COORDINATE_NOTE_OPENINGS)
    pattern <- paste0("(^|\\| )(", paste(escaped, collapse = "|"), ")")
    x <- trimws(as.character(x))
    !is.na(x) & grepl(pattern, x, ignore.case = TRUE)
}

# Rows the publisher already generalized (ADR-095): `coordinateUncertaintyInMeters`
# at/above the threshold, OR a coordinate generalization note in
# `dataGeneralizations`. The export leaves these intact and the generalization
# preview drops them. Vectorized over rows.
sensitive_already_masked_rows <- function(df) {
    n <- if (is.data.frame(df)) nrow(df) else 0L
    unc <- if (is.data.frame(df) && "coordinateUncertaintyInMeters" %in% names(df)) {
        uncertainty_meters(df$coordinateUncertaintyInMeters)
    } else {
        rep(NA_real_, n)
    }
    dg <- if (is.data.frame(df) && "dataGeneralizations" %in% names(df)) {
        df$dataGeneralizations
    } else {
        rep("", n)
    }
    (!is.na(unc) & unc >= SENSITIVE_ALREADY_MASKED_THRESHOLD_M) |
        coordinate_generalization_note(dg)
}

# Grid for a row that only the declared uncertainty marks as already masked, but
# whose coordinate has more decimals than that uncertainty justifies (D04):
# -24.4873 with 2500 m shows a ~11 m point. The grid is the coarsest tier grid
# whose cell radius fits inside the declared uncertainty, so a point already on
# that grid (-24.5 with 10 km) gets NA and stays as typed. NA for every other
# row. A coordinate generalization note keeps the full skip of ADR-095.
sensitive_uncertainty_snap_grid <- function(df, lat, lon) {
    n <- length(lat)
    out <- rep(NA_real_, n)
    if (!is.data.frame(df) || !"coordinateUncertaintyInMeters" %in% names(df)) {
        return(out)
    }
    unc <- uncertainty_meters(df$coordinateUncertaintyInMeters)
    dg <- if ("dataGeneralizations" %in% names(df)) df$dataGeneralizations else rep("", n)
    cand <- !is.na(unc) & unc >= SENSITIVE_ALREADY_MASKED_THRESHOLD_M &
        !coordinate_generalization_note(dg) & is.finite(lat) & is.finite(lon)
    if (!any(cand)) {
        return(out)
    }
    grid <- rep(NA_real_, n)
    # Finest grid first, so each coarser grid that still fits replaces it.
    for (g in c(0.001, 0.01, 0.1, 1.0)) {
        fits <- cand
        fits[cand] <- sensitive_grid_uncertainty_m(g, lon[cand], lat[cand]) <= unc[cand]
        grid[fits] <- g
    }
    # The finer axis decides: one axis with extra decimals still shows the point.
    finest <- pmin(coordinate_decimal_grid(df$decimalLatitude),
                   coordinate_decimal_grid(df$decimalLongitude), na.rm = TRUE)
    snap <- cand & !is.na(grid) & !is.na(finest) & finest < grid
    out[snap] <- grid[snap]
    out
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
    values <- as.character(tier)
    if (length(values) == 0L) {
        return(character(0))
    }
    # There are at most 5 distinct tiers whatever the row count, so resolve the
    # statement once each and expand by index instead of calling tr() per row.
    uniq <- unique(values)
    resolved <- vapply(uniq, function(t) {
        k <- unname(keys[t])
        if (is.na(k)) "" else tr(k, lang)
    }, FUN.VALUE = character(1), USE.NAMES = FALSE)
    resolved[match(values, uniq)]
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

# Sensitivity decisions keyed by the name each record leaves with. The Names
# tab marks the name as typed, and a name correction renames the record before
# the Generalization tab and the export read it. So each decision on a corrected
# name is copied to the new name. A name with two decisions is sensitive when
# either one says so (AUD-01).
rekey_sensitivity_decisions <- function(decisions, name_payload = NULL) {
    entries <- if (is.list(name_payload)) name_payload$entries else NULL
    if (!is.data.frame(decisions) || nrow(decisions) == 0L ||
            !all(c("scientificName", "sensitive") %in% names(decisions)) ||
            !is.data.frame(entries) || nrow(entries) == 0L ||
            !all(c("query_name", "review_type", "corrected_name") %in% names(entries))) {
        return(decisions)
    }
    entries <- entries[tolower(entries$review_type) %in% c("confirm", "correct"), , drop = FALSE]
    # The last review of a name wins, as in apply_name_review_payload().
    when <- if ("reviewed_at" %in% names(entries)) entries$reviewed_at else rep(NA, nrow(entries))
    entries <- entries[order(entries$query_name, when, seq_len(nrow(entries)), na.last = TRUE), ,
                       drop = FALSE]
    entries <- entries[!duplicated(entries$query_name, fromLast = TRUE), , drop = FALSE]
    fix <- entries[tolower(entries$review_type) == "correct" &
                       !is_blank_cell(entries$corrected_name), , drop = FALSE]
    if (nrow(fix) == 0L) {
        return(decisions)
    }
    dkey <- build_sensitive_match_keys(decisions$scientificName)
    m <- match(dkey, build_sensitive_match_keys(fix$query_name))
    if ("original_name" %in% names(fix)) {
        m_orig <- match(dkey, build_sensitive_match_keys(fix$original_name))
        m[is.na(m)] <- m_orig[is.na(m)]
    }
    hit <- which(!is.na(m))
    if (!length(hit)) {
        return(decisions)
    }
    as_bool <- function(x) tolower(trimws(as.character(x))) %in% c("true", "1", "yes", "t")
    category <- if ("category" %in% names(decisions)) {
        as.character(decisions$category)
    } else {
        rep(NA_character_, nrow(decisions))
    }
    rows <- data.frame(
        scientificName = c(as.character(decisions$scientificName),
                           trimws(as.character(fix$corrected_name[m[hit]]))),
        sensitive = c(as_bool(decisions$sensitive), as_bool(decisions$sensitive[hit])),
        category = c(category, category[hit]),
        stringsAsFactors = FALSE
    )
    key <- build_sensitive_match_keys(rows$scientificName)
    no_key <- is.na(key) | !nzchar(key)
    key[no_key] <- rows$scientificName[no_key]
    groups <- unique(key)
    # The category of a sensitive decision goes into the published note.
    with_cat <- rows$sensitive & !is_blank_cell(rows$category)
    data.frame(
        scientificName = rows$scientificName[match(groups, key)],
        sensitive = vapply(groups, function(g) any(rows$sensitive[key == g]), logical(1),
                           USE.NAMES = FALSE),
        category = rows$category[with_cat][match(groups, key[with_cat])],
        stringsAsFactors = FALSE
    )
}

# The generalization plan of every row: the decision, the grid, the published
# point and its uncertainty. The export and the map preview read the same plan,
# so the map never shows a point the export does not write (SP-10). `df` has
# scientificName, decimalLatitude and decimalLongitude.
#
# Returns per-row vectors (NA or FALSE where the field does not apply):
#   target   : the row is generalized
#   withheld : a sensitive point the grid cannot move, so it is removed
#   kept     : a sensitive row the publisher already generalized (ADR-095)
#   snap     : the grid comes from the row uncertainty (D04)
#   eff_grid : the grid after the precision clamp
#   pub_lat, pub_lon, unc_m : the published point and its uncertainty
# plus the counts the banners show.
sensitive_generalization_plan <- function(df, generalization, decisions = NULL) {
    n <- nrow(df)
    decided <- sensitive_resolve(df$scientificName, decisions)
    # Per-row Chapman tier and its grid. Rows whose species resolve to
    # "not_sensitive"/unassessed get NA grid and are left untouched.
    row_tier <- resolve_row_tiers(df$scientificName, generalization)
    # Grid per row, resolved over the few unique tiers (<= 5) and mapped back --
    # calling sensitive_generalization_grid per record is O(n) for no reason.
    row_tier_u <- unique(row_tier)
    row_grid <- vapply(row_tier_u, sensitive_generalization_grid,
                       FUN.VALUE = numeric(1), USE.NAMES = FALSE)[match(row_tier, row_tier_u)]
    # Decimal comma accepted, as in the Coordinates tab: the mapped frame keeps
    # the value as typed, and a plain as.numeric() dropped "-19,91" rows.
    lat <- as_coord_numeric(df$decimalLatitude)$num
    lon <- as_coord_numeric(df$decimalLongitude)$num
    point_ok <- sensitive_point_ok(lat, lon)
    has_coord <- !is_blank_cell(df$decimalLatitude) | !is_blank_cell(df$decimalLongitude)
    sensitive <- decided$sensitive & !is.na(row_grid) & row_grid > 0
    target <- sensitive & point_ok

    # Honour upstream generalization (ADR-095). Two signals:
    #   1. `coordinateUncertaintyInMeters` >= 1000 m -- publisher who fuzzed
    #      via grid >= 0.01 deg, or who explicitly set a wide uncertainty.
    #   2. A coordinate note in `dataGeneralizations`: the Saira note, or the
    #      one `camtrapdp::write_dwc()` writes when the publisher set
    #      `coordinatePrecision` (PDF p.26), covering Chapman category 4
    #      generalization (3 digits -> ~150 m uncertainty, below 1000 m).
    # Skip those rows so we neither overwrite their values nor leak them
    # into the `real` companion file (we do not have the originals).
    # A row that only the uncertainty marks, with more decimals than that
    # uncertainty justifies, is rounded to the uncertainty grid (D04).
    snap_grid <- sensitive_uncertainty_snap_grid(df, lat, lon)
    snap <- target & !is.na(snap_grid)
    already_masked <- sensitive_already_masked_rows(df) & !snap
    n_skipped <- sum(target & already_masked)
    target <- target & !already_masked
    base_grid <- row_grid
    base_grid[snap] <- snap_grid[snap]

    # Precision clamp (Chapman 2020 sec. 4.1-4.3 + glossary). Generalization
    # REDUCES precision and must never increase it: rounding a 2-decimal value
    # (~0.01 deg) to the 0.001 grid would invent false precision the data never
    # had ("precision"/"randomization" glossary). So each row's grid is widened
    # to never be finer than the precision the coordinates already carry. The
    # records are NOT skipped -- sec. 5.1 requires the sensitivity record-level
    # metadata (informationWithheld, dataGeneralizations, precision provided +
    # stored, locality scrub) regardless of whether the coordinate moves; only
    # the grid is clamped to the data's real precision.
    exist_prec <- existing_precision_grid(df)
    eff_grid <- base_grid
    has_prec <- !is.na(exist_prec) & !is.na(base_grid)
    eff_grid[has_prec] <- pmax(base_grid[has_prec], exist_prec[has_prec])

    # One rounding rule for every grid (generalize_coord). The uncertainty is
    # the geographic radial of the cell (centre -> furthest corner) COMBINED
    # with any original record uncertainty (Best Practices sec. 3.4.7: combine
    # sources, not take the max). The original point lies within its own radius
    # of the published cell centre, so the guaranteed maximum distance is additive.
    pub_lat <- pub_lon <- unc_m <- rep(NA_real_, n)
    for (g in unique(eff_grid[target])) {
        rows <- which(target & eff_grid == g)
        pub_lat[rows] <- generalize_coord(lat[rows], g)
        pub_lon[rows] <- generalize_coord(lon[rows], g)
    }
    unc_prior <- if ("coordinateUncertaintyInMeters" %in% names(df)) {
        uncertainty_meters(as.character(df$coordinateUncertaintyInMeters))
    } else {
        rep(NA_real_, n)
    }
    unc_prior[is.na(unc_prior)] <- 0
    unc_m[target] <- ceiling(
        sensitive_grid_uncertainty_m(eff_grid[target], pub_lon[target], pub_lat[target]) +
            unc_prior[target]
    )

    list(
        category = decided$category,
        tier = row_tier,
        row_grid = row_grid,
        lat = lat,
        lon = lon,
        target = target,
        # A sensitive point the grid cannot move (out of range, one axis only, a
        # UTM pair) is removed and kept in the private file (B09, B23).
        withheld = sensitive & has_coord & !point_ok & !already_masked,
        kept = sensitive & already_masked,
        snap = snap,
        exist_prec = exist_prec,
        eff_grid = eff_grid,
        pub_lat = pub_lat,
        pub_lon = pub_lon,
        unc_prior = unc_prior,
        unc_m = unc_m,
        n_skipped_already_masked = n_skipped,
        n_snapped_to_uncertainty = sum(snap),
        n_clamped_to_precision = sum(target & has_prec & base_grid < exist_prec)
    )
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
        n_withheld = 0L,
        rows = integer(0),
        grid = numeric(0),
        n_skipped_already_masked = 0L,
        n_snapped_to_uncertainty = 0L,
        n_clamped_to_precision = 0L,
        scrub_rows = integer(0),
        scrub_points = NULL
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

    plan <- sensitive_generalization_plan(df, generalization, decisions)
    row_tier <- plan$tier
    row_grid <- plan$row_grid
    lat_num <- plan$lat
    lon_num <- plan$lon
    target <- plan$target
    withheld <- plan$withheld
    snap <- plan$snap
    exist_prec <- plan$exist_prec
    eff_grid <- plan$eff_grid
    result$n_skipped_already_masked <- plan$n_skipped_already_masked
    result$n_snapped_to_uncertainty <- plan$n_snapped_to_uncertainty
    result$n_clamped_to_precision <- plan$n_clamped_to_precision
    # A skipped row keeps its point, but its verbatim and unmapped copies of
    # the original point still go (AUD-03).
    kept <- which(plan$kept)

    # Verbatim coordinate fields must be blank (Darwin Core forbids prose
    # there), the other locality/remarks fields carry replacement wording
    # (Chapman sec. 3).
    blank_cols <- c("verbatimLatitude", "verbatimLongitude",
                    "verbatimCoordinates")
    scrub_cols <- c("locality", "verbatimLocality",
                    "georeferenceRemarks", "locationRemarks")
    blank_verbatim <- function(d, rows) {
        for (col in intersect(blank_cols, names(d))) {
            d[[col]] <- as.character(d[[col]])
            d[[col]][rows] <- ""
        }
        d
    }
    # Copies of the point in the other mapped fields, such as a GPS pair in
    # dynamicProperties or occurrenceRemarks, get the published value (AUD-02).
    # A cell that is one number is the value of its own term and stays.
    redact_copies <- function(d, rows, lat, lon, grid, pub_lat, pub_lon, skip) {
        for (col in setdiff(names(d), skip)) {
            cell <- as.character(d[[col]][rows])
            text <- which(is.na(suppressWarnings(as.numeric(sub(",", ".", trimws(cell), fixed = TRUE)))))
            if (!length(text)) next
            new <- cell
            new[text] <- redact_point_numbers(cell[text], lat[text], lon[text], grid[text],
                                              pub_lat[text], pub_lon[text])
            if (!identical(new, cell)) {
                d[[col]] <- as.character(d[[col]])
                d[[col]][rows] <- new
            }
        }
        d
    }
    # A row the publisher already generalized has no real point here. A number
    # finer than its published point and less than one step away, such as a GPS
    # value in the remarks, is still a copy of the real point.
    keep_lat <- coord_text_with_dot(df$decimalLatitude)[kept]
    keep_lon <- coord_text_with_dot(df$decimalLongitude)[kept]
    redact_kept <- function(d) {
        redact_copies(d, kept, lat_num[kept], lon_num[kept], exist_prec[kept], keep_lat, keep_lon,
                      c("occurrenceID", "scientificName", "decimalLatitude", "decimalLongitude",
                        "footprintWKT", "footprintSRS", blank_cols))
    }
    # The unmapped columns of these rows are scrubbed at export, against the
    # real point or, on a kept row, the published one.
    set_scrub <- function(res, idx, real_lat, real_lon, grid) {
        res$scrub_rows <- c(idx, kept)
        if (length(res$scrub_rows)) {
            res$scrub_points <- data.frame(
                decimalLatitude = c(real_lat, keep_lat),
                decimalLongitude = c(real_lon, keep_lon),
                grid = c(grid, exist_prec[kept]),
                stringsAsFactors = FALSE
            )
        }
        res
    }

    if (!any(target | withheld)) {
        if (length(kept)) {
            result$masked <- redact_kept(blank_verbatim(df, kept))
            result <- set_scrub(result, integer(0), character(0), character(0), numeric(0))
        }
        return(result)
    }
    idx <- which(target | withheld)
    row_cat <- plan$category[idx]
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
        decimalLatitude = coord_text_with_dot(df$decimalLatitude)[idx],
        decimalLongitude = coord_text_with_dot(df$decimalLongitude)[idx],
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

    # Write the plan, one grid at a time (one of four distinct values, bijective
    # with the Chapman tier). `dataGeneralizations` carries the MMA category,
    # the grid, and the Chapman Table 5 reason for the record.
    gen_idx <- which(target)
    for (g in unique(eff_grid[gen_idx])) {
        in_group <- eff_grid[idx] == g & target[idx]
        rows <- idx[in_group]
        cat_disp <- row_cat_display[in_group]
        gen_lat <- plan$pub_lat[rows]
        gen_lon <- plan$pub_lon[rows]
        masked$decimalLatitude[rows]  <- gen_lat
        masked$decimalLongitude[rows] <- gen_lon
        masked$coordinatePrecision[rows] <- format(g, trim = TRUE, scientific = FALSE)
        existing <- plan$unc_prior[rows]
        masked$coordinateUncertaintyInMeters[rows] <- as.character(plan$unc_m[rows])
        # Capture the cell as a polygon (Best Practices sec. 2.3.4: "the ideal
        # way to record [a grid cell] ... is the polygon consisting of the
        # corners"). Safe to publish -- it is the coarse cell, not the point.
        # A cell at a pole or at the antimeridian stops at the world bounds,
        # because EPSG:4326 has no latitude past 90 (AUD-17).
        half <- g / 2
        west <- wkt_num(pmax(gen_lon - half, -180))
        east <- wkt_num(pmin(gen_lon + half, 180))
        south <- wkt_num(pmax(gen_lat - half, -90))
        north <- wkt_num(pmin(gen_lat + half, 90))
        masked$footprintWKT[rows] <- sprintf(
            "POLYGON ((%s %s, %s %s, %s %s, %s %s, %s %s))",
            west, south, east, south, east, north, west, north, west, south
        )
        masked$footprintSRS[rows] <- "EPSG:4326"
        # Chapman sec. 4.3 / 5.1: record BOTH the precision provided (the grid,
        # = coordinatePrecision above) AND the precision originally stored. The
        # latter has no adopted Darwin Core term, so it rides in
        # dataGeneralizations text where the data's real resolution is known.
        stored <- exist_prec[rows]
        # One format() call per value: on the whole vector, one row with 12
        # decimals gave every row 12 decimals (B10).
        stored_text <- vapply(stored, function(v) format(v, trim = TRUE, scientific = FALSE),
                              character(1))
        stored_note <- ifelse(
            is.na(stored), "",
            sprintf(tr("sensitive_precision_stored", lang), stored_text)
        )
        # Say why the grid differs from the Chapman category grid, so "1 degree"
        # never reads as the grid of "Category 4" (D01, D04).
        g_text <- format(g, trim = TRUE, scientific = FALSE)
        fmt_each <- function(v) {
            vapply(v, function(x) format(x, trim = TRUE, scientific = FALSE), character(1))
        }
        grid_note <- ifelse(
            snap[rows],
            sprintf(tr("sensitive_grid_from_uncertainty", lang), g_text, fmt_each(existing)),
            ifelse(
                g > row_grid[rows],
                sprintf(tr("sensitive_grid_clamped", lang),
                        sensitive_tier_category_number(row_tier[rows]),
                        fmt_each(row_grid[rows]), g_text),
                ""
            )
        )
        masked$dataGeneralizations[rows] <- after_prior_note(
            redact_point_numbers(masked$dataGeneralizations[rows], lat_num[rows], lon_num[rows],
                                 rep(g, length(rows)), as.character(masked$decimalLatitude[rows]),
                                 as.character(masked$decimalLongitude[rows])),
            trimws(paste(
                sprintf(
                    tr("sensitive_data_generalizations", lang),
                    cat_disp,
                    g_text
                ),
                sensitive_reason_statement(row_tier[rows], lang),
                grid_note,
                stored_note,
                just_text
            ))
        )
    }
    wh <- which(withheld)
    if (length(wh)) {
        masked$decimalLatitude[wh] <- ""
        masked$decimalLongitude[wh] <- ""
        masked$coordinateUncertaintyInMeters[wh] <- ""
        masked$coordinatePrecision[wh] <- ""
        masked$footprintWKT[wh] <- ""
        masked$footprintSRS[wh] <- ""
        masked$dataGeneralizations[wh] <- after_prior_note(
            redact_point_numbers(masked$dataGeneralizations[wh], lat_num[wh], lon_num[wh],
                                 eff_grid[wh], rep("", length(wh)), rep("", length(wh))),
            trimws(paste(
                sprintf(tr("sensitive_withheld_invalid", lang),
                        row_cat_display[match(wh, idx)]),
                just_text
            ))
        )
    }
    masked$informationWithheld[idx] <- iw_text

    # Scrub fields that could reverse the generalization. footprintWKT is NOT
    # scrubbed here: the loop above already replaced it with the generalized
    # cell polygon (safe, coarse) on every masked row.
    masked <- blank_verbatim(masked, c(idx, kept))
    for (col in intersect(scrub_cols, names(masked))) {
        masked[[col]] <- as.character(masked[[col]])
        masked[[col]][idx] <- iw_text
    }
    managed <- c("occurrenceID", "scientificName", "decimalLatitude", "decimalLongitude",
                 ensure_cols, blank_cols, scrub_cols)
    masked <- redact_copies(masked, idx, lat_num[idx], lon_num[idx], eff_grid[idx],
                            as.character(masked$decimalLatitude[idx]),
                            as.character(masked$decimalLongitude[idx]), managed)
    if (length(kept)) masked <- redact_kept(masked)

    # Newly created columns land at the right side; re-sort into their DwC
    # blocks. Skipped when the columns already existed (positions unchanged).
    if (!had_cols) {
        masked <- order_columns_dwc_canonical(masked)
    }

    result$masked <- masked
    result$n_masked <- length(gen_idx)
    result$n_withheld <- length(wh)
    result$rows <- idx
    # The grid of each row in `rows`, so the export knows how close a raw copy
    # of the point may be before it gives the point away (B52).
    result$grid <- eff_grid[idx]
    set_scrub(result, idx, result$real$decimalLatitude, result$real$decimalLongitude,
              result$grid)
}

# A publisher note in `dataGeneralizations` stays in front of the Saira note,
# joined with the Darwin Core list separator (AUD-03).
after_prior_note <- function(prior, note) {
    prior <- trimws(as.character(prior))
    prior[is.na(prior)] <- ""
    ifelse(nzchar(prior), paste(prior, note, sep = " | "), note)
}

# Replace each copy of the real point inside a text cell, such as
# '{"gps":"-23.55052,-46.63331"}' or "23.55052 S", with the published value.
# A copy is a number with more decimals than the grid, less than one grid step
# from either axis. The test ignores the sign, because a hemisphere letter can
# replace it. A blank published value removes the copy. Vectorized over cells,
# and every argument has one value per cell (AUD-02).
redact_point_numbers <- function(x, lat, lon, grid, pub_lat, pub_lon) {
    x <- as.character(x)
    cand <- which(!is.na(x) & grepl("[0-9][.,][0-9]|[0-9]\\s*['\u2032\u2019\u00b4`]", x))
    if (!length(cand)) {
        return(x)
    }
    pub_lat[is.na(pub_lat)] <- ""
    pub_lon[is.na(pub_lon)] <- ""
    places <- pmax(0, round(-log10(grid)))
    cells <- redact_dms_copies(x[cand], lat[cand], lon[cand], grid[cand],
                               pub_lat[cand], pub_lon[cand])
    found <- gregexpr("[-+]?[0-9]+[.,][0-9]+", cells)
    tokens <- regmatches(cells, found)
    regmatches(cells, found) <- lapply(seq_along(cand), function(k) {
        i <- cand[k]
        tok <- tokens[[k]]
        num <- abs(as.numeric(sub(",", ".", tok, fixed = TRUE)))
        decimals <- nchar(sub("^[^.,]*[.,]", "", tok))
        near_lat <- !is.na(lat[i]) & abs(num - abs(lat[i])) < grid[i]
        near_lon <- !is.na(lon[i]) & abs(num - abs(lon[i])) < grid[i]
        hit <- decimals > places[i] & (near_lat | near_lon)
        hit[is.na(hit)] <- FALSE
        if (!any(hit)) {
            return(tok)
        }
        pub <- ifelse(near_lat, pub_lat[i], pub_lon[i])[hit]
        value <- sub("^-", "", pub)
        comma <- grepl(",", tok[hit], fixed = TRUE)
        value[comma] <- sub(".", ",", value[comma], fixed = TRUE)
        sign <- ifelse(startsWith(tok[hit], "-") & nzchar(value), "-", "")
        tok[hit] <- paste0(sign, value)
        tok
    })
    x[cand] <- cells
    x
}

# Degrees and minutes, with optional seconds and hemisphere, in the forms that
# parse_coordinate_text() reads: 23°33'1.872"S, 46°37.999' W. The optional
# backslash reads an escaped second mark inside a JSON string.
POINT_DMS_PATTERN <- paste0(
    "([-+\u2212]?)(\\d{1,3})\\s*[\u00b0\u00ba]?\\s*(\\d{1,2}(?:[.,]\\d+)?)\\s*['\u2032\u2019\u00b4`]",
    "(?:\\s*(\\d{1,2}(?:[.,]\\d+)?)\\s*\\\\?(?:[\"\u2033\u201d]|''))?",
    "(?:\\s*([NSEWOLnsewol])\\b)?"
)

# The degrees-minutes step of redact_point_numbers(): a copy finer than the
# grid and less than one grid step from either axis gets the published value,
# with the hemisphere letter or the sign of the copy. Arguments as there.
redact_dms_copies <- function(cells, lat, lon, grid, pub_lat, pub_lon) {
    found <- gregexpr(POINT_DMS_PATTERN, cells, perl = TRUE)
    tokens <- regmatches(cells, found)
    num <- function(v) suppressWarnings(as.numeric(sub(",", ".", v, fixed = TRUE)))
    regmatches(cells, found) <- lapply(seq_along(cells), function(i) {
        tok <- tokens[[i]]
        if (!length(tok)) {
            return(tok)
        }
        p <- do.call(rbind, regmatches(tok, regexec(POINT_DMS_PATTERN, tok, perl = TRUE)))
        has_sec <- nzchar(p[, 5])
        value <- num(p[, 3]) + num(p[, 4]) / 60 + ifelse(has_sec, num(p[, 5]), 0) / 3600
        # The finest step the copy carries: a minute or a second, with its decimals.
        last <- ifelse(has_sec, p[, 5], p[, 4])
        step <- ifelse(has_sec, 1 / 3600, 1 / 60) * 10^-nchar(sub("^[^.,]*[.,]?", "", last))
        near_lat <- !is.na(lat[i]) & abs(value - abs(lat[i])) < grid[i]
        near_lon <- !is.na(lon[i]) & abs(value - abs(lon[i])) < grid[i]
        hit <- step < grid[i] & (near_lat | near_lon)
        hit[is.na(hit)] <- FALSE
        if (!any(hit)) {
            return(tok)
        }
        value <- sub("^-", "", ifelse(near_lat, pub_lat[i], pub_lon[i]))
        hemi <- toupper(p[, 6])
        sign <- ifelse(nzchar(p[, 2]) & p[, 2] != "+", "-", "")
        tok[hit] <- ifelse(!nzchar(value), "",
                           ifelse(nzchar(hemi), paste(value, hemi), paste0(sign, value)))[hit]
        tok
    })
    cells
}

# A coordinate as typed, with a decimal comma turned into a dot when the value
# is a number. Text the parser cannot read stays as typed for the custodian.
coord_text_with_dot <- function(x) {
    x <- trimws(as.character(x))
    parsed <- as_coord_numeric(x)
    num_ok <- !is.na(parsed$num)
    x[num_ok] <- sub(",", ".", x[num_ok], fixed = TRUE)
    x[is.na(x)] <- ""
    x
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
    # The map shows only what Saira changes: publisher-generalized rows
    # (ADR-095) and withheld points (B16) ride to the banner as counts.
    plan <- sensitive_generalization_plan(df, generalization, decisions)
    set_lock_attrs <- function(d) {
        attr(d, "n_clamped_to_precision") <- plan$n_clamped_to_precision
        attr(d, "n_upstream_preserved") <- plan$n_skipped_already_masked
        attr(d, "n_withheld") <- sum(plan$withheld)
        d
    }

    if (!any(plan$target)) {
        return(set_lock_attrs(empty))
    }
    idx <- which(plan$target)
    out <- data.frame(
        scientificName = as.character(df$scientificName)[idx],
        tier = plan$tier[idx],
        lat = plan$lat[idx], lon = plan$lon[idx],
        gen_lat = plan$pub_lat[idx], gen_lon = plan$pub_lon[idx],
        unc_m = plan$unc_m[idx],
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
    set_lock_attrs(out)
}

# Sensitivity decisions for synonyms of MMA-listed species (B18). The MMA list
# uses the accepted name, so "Caesalpinia echinata" (a synonym of the EN
# "Paubrasilia echinata") missed the generalization. Returns the same columns
# as the manual overrides: scientificName, sensitive, category. The accepted
# name comes from the COL XR match of the names run.
synonym_sensitivity_entries <- function(report) {
    empty <- data.frame(scientificName = character(0), sensitive = logical(0),
                        category = character(0), stringsAsFactors = FALSE)
    needed <- c("validation_status", "acceptedNameUsage")
    if (!is.data.frame(report) || nrow(report) == 0L || !all(needed %in% names(report))) {
        return(empty)
    }
    typed_col <- intersect(c("input_name", "query_name", "scientificName"), names(report))[1]
    if (is.na(typed_col)) {
        return(empty)
    }
    syn <- report$validation_status %in% "synonym" & !is_blank_cell(report$acceptedNameUsage)
    typed <- as.character(report[[typed_col]])[syn]
    accepted <- as.character(report$acceptedNameUsage)[syn]
    keep <- !duplicated(typed) & !is_blank_cell(typed)
    typed <- typed[keep]
    accepted <- accepted[keep]
    # A synonym on the list keeps its own category.
    unlisted <- is.na(sensitive_category_for(typed))
    typed <- typed[unlisted]
    accepted <- accepted[unlisted]
    if (!length(typed)) {
        return(empty)
    }
    category <- sensitive_category_for(accepted)
    hit <- !is.na(category)
    if (!any(hit)) {
        return(empty)
    }
    data.frame(scientificName = typed[hit], sensitive = TRUE, category = category[hit],
               stringsAsFactors = FALSE)
}

# Count species by canonical name, so "Panthera cf. onca", "panthera onca"
# and "Panthera onca" are one species in every tab (B11). A name with no
# canonical form (a hybrid formula) counts as typed.
count_distinct_species <- function(names) {
    names <- as.character(names)
    names <- names[!is_blank_cell(names)]
    if (!length(names)) {
        return(0L)
    }
    keys <- build_sensitive_match_keys(names)
    blank <- is.na(keys) | !nzchar(keys)
    keys[blank] <- names[blank]
    length(unique(keys))
}
