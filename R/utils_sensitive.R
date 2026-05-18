# Title: Sensitive-species coordinate masking
# Author: Rogerio Nunes Oliveira
#
# Pure helpers shared by the name-validation pill (display) and the export
# pipeline. No Shiny, no reactives. A bundled list of threatened species
# (inst/extdata/sensitive_species.rds, built from data-raw/redlist_brasil_mma.md)
# is matched against the validator's resolved scientificName; matched records
# have their coordinates generalized to a coarser grid on export.

sensitive_species_cache <- create_rds_cache("sensitive_species")

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

# Logical vector: which of `names` (resolved scientific names) are on the
# sensitive list. Single source of truth for both display and export.
flag_sensitive_species <- function(names) {
    n <- length(names)
    if (n == 0L) {
        return(logical(0))
    }
    lookup <- load_sensitive_species()
    if (!is.data.frame(lookup) || nrow(lookup) == 0L) {
        return(rep(FALSE, n))
    }
    keys <- build_sensitive_match_keys(names)
    !is.na(keys) & nzchar(keys) & keys %in% lookup$match_key
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

# Mask sensitive records on the post-process_for_export frame (which already
# carries occurrenceID, scientificName and the coordinate columns).
#
# Returns:
#   masked   : the frame with generalized coords + dataGeneralizations,
#              informationWithheld and coordinateUncertaintyInMeters set on
#              sensitive rows that have coordinates; every other row byte-
#              identical to the input.
#   real     : occurrenceID + scientificName + the ORIGINAL coordinates for
#              the masked rows only (the researcher's private control file).
#   n_masked : count of rows whose coordinates were generalized.
mask_sensitive_coordinates <- function(df, grid = 0.1, lang = "en") {
    result <- list(
        masked = df,
        real = data.frame(
            occurrenceID = character(0),
            scientificName = character(0),
            decimalLatitude = character(0),
            decimalLongitude = character(0),
            stringsAsFactors = FALSE
        ),
        n_masked = 0L
    )

    if (!is.data.frame(df) || nrow(df) == 0L) {
        return(result)
    }
    needed <- c("scientificName", "decimalLatitude", "decimalLongitude")
    if (!all(needed %in% names(df))) {
        return(result)
    }

    is_sensitive <- flag_sensitive_species(df$scientificName)
    lat_num <- suppressWarnings(as.numeric(df$decimalLatitude))
    lon_num <- suppressWarnings(as.numeric(df$decimalLongitude))
    target <- is_sensitive & !is.na(lat_num) & !is.na(lon_num)
    if (!any(target)) {
        return(result)
    }
    idx <- which(target)

    occ <- if ("occurrenceID" %in% names(df)) {
        as.character(df$occurrenceID)
    } else {
        as.character(seq_len(nrow(df)))
    }

    result$real <- data.frame(
        occurrenceID = occ[idx],
        scientificName = as.character(df$scientificName)[idx],
        decimalLatitude = as.character(df$decimalLatitude)[idx],
        decimalLongitude = as.character(df$decimalLongitude)[idx],
        stringsAsFactors = FALSE
    )

    had_cols <- all(
        c(
            "dataGeneralizations",
            "informationWithheld",
            "coordinateUncertaintyInMeters"
        ) %in% names(df)
    )

    masked <- df
    masked$decimalLatitude[idx] <- generalize_coord(lat_num[idx], grid)
    masked$decimalLongitude[idx] <- generalize_coord(lon_num[idx], grid)

    ensure_col <- function(d, name) {
        if (!name %in% names(d)) {
            d[[name]] <- rep("", nrow(d))
        }
        d[[name]] <- as.character(d[[name]])
        d[[name]][is.na(d[[name]])] <- ""
        d
    }
    masked <- ensure_col(masked, "dataGeneralizations")
    masked <- ensure_col(masked, "informationWithheld")
    masked <- ensure_col(masked, "coordinateUncertaintyInMeters")

    grid_km <- round(grid * 111.32, 1)
    unc_m <- sensitive_grid_uncertainty_m(grid)
    dg_text <- sprintf(
        tr("sensitive_data_generalizations", lang),
        format(grid, trim = TRUE),
        format(grid_km, trim = TRUE)
    )
    iw_text <- tr("sensitive_information_withheld", lang)

    masked$dataGeneralizations[idx] <- dg_text
    masked$informationWithheld[idx] <- iw_text
    existing_unc <- suppressWarnings(
        as.numeric(masked$coordinateUncertaintyInMeters[idx])
    )
    new_unc <- pmax(existing_unc, unc_m, na.rm = TRUE)
    masked$coordinateUncertaintyInMeters[idx] <- as.character(new_unc)

    # Newly created columns land at the right side; re-sort into their DwC
    # blocks. Skipped when the columns already existed (positions unchanged).
    if (!had_cols) {
        masked <- order_columns_dwc_canonical(masked)
    }

    result$masked <- masked
    result$n_masked <- length(idx)
    result
}
