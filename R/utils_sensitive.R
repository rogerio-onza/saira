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

# Conservative coordinate uncertainty for a grid cell, in metres
# (~ one cell side along latitude; 0.1 deg -> 11132 m).
sensitive_grid_uncertainty_m <- function(grid) {
    ceiling(grid * 111320)
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

# Per-row sensitivity decision. The Validation > Names payload (researcher's
# marks) wins; rows it does not cover fall back to the MMA auto-match so an
# unseen species is still protected by default. `$category` is carried for
# display (the pill in Validation > Names) but is no longer consumed by
# `mask_sensitive_coordinates` -- the grid is global (Chapman 2020 method).
sensitive_resolve <- function(names, decisions = NULL) {
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
# Global single-tier generalization (Chapman 2020 method, Table 7): the user
# picks one tier ("extreme"/"high"/"medium"/"low") that applies to every
# sensitive row uniformly. "not_sensitive" or `enabled = FALSE` makes the
# whole call a no-op (byte-identical to input).
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
                                        enabled = TRUE, lang = "en") {
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

    grid <- sensitive_generalization_grid(generalization)
    if (!isTRUE(enabled) || is.na(grid) || grid <= 0) {
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
    lat_num <- suppressWarnings(as.numeric(df$decimalLatitude))
    lon_num <- suppressWarnings(as.numeric(df$decimalLongitude))
    target <- decided$sensitive & !is.na(lat_num) & !is.na(lon_num)

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
                     "coordinateUncertaintyInMeters", "coordinatePrecision")
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

    # Single uniform grid across all sensitive rows.
    masked$decimalLatitude[idx]  <- generalize_coord(lat_num[idx], grid)
    masked$decimalLongitude[idx] <- generalize_coord(lon_num[idx], grid)
    masked$coordinatePrecision[idx] <- format(grid, trim = TRUE, scientific = FALSE)
    existing <- suppressWarnings(
        as.numeric(masked$coordinateUncertaintyInMeters[idx])
    )
    masked$coordinateUncertaintyInMeters[idx] <- as.character(
        pmax(existing, sensitive_grid_uncertainty_m(grid), na.rm = TRUE)
    )
    masked$dataGeneralizations[idx] <- sprintf(
        tr("sensitive_data_generalizations", lang),
        row_cat_display,
        format(grid, trim = TRUE, scientific = FALSE),
        format(round(grid * 111.32, 1), trim = TRUE)
    )
    masked$informationWithheld[idx] <- iw_text

    # Replace text that could reverse the generalization (Chapman sec. 3:
    # restricted fields carry replacement wording, not a blank/null).
    leak_cols <- c("verbatimLatitude", "verbatimLongitude",
                   "verbatimCoordinates", "footprintWKT", "locality",
                   "verbatimLocality", "georeferenceRemarks",
                   "locationRemarks")
    for (col in intersect(leak_cols, names(masked))) {
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
