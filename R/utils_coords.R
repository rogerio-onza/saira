# Title: Coordinate Validation Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-21
# Version: 2.0

#' @include utils_common.R
NULL
coord_issue_levels <- c("ok", "missing", "lat_range", "lon_range", "zero_zero", "swapped", "identical_all")
coord_diag_levels <- c(
    "ok",
    "validity_missing",
    "validity_bounds",
    "swapped",
    "sea",
    "zero_equal",
    "identical_all",
    "reference"
)
coord_family_levels <- c("ok", "validity", "sea", "zero_equal", "reference", "corrected")

as_coord_numeric <- function(x) {
    raw_chr <- as.character(x)
    raw_chr[is.na(x)] <- NA_character_
    normalized <- gsub(",", ".", raw_chr, fixed = TRUE)
    num <- suppressWarnings(as.numeric(normalized))
    parse_failed <- !is.na(raw_chr) & nzchar(trimws(raw_chr)) & is.na(num)
    list(num = num, parse_failed = parse_failed)
}

empty_coords_result <- function() {
    data.frame(
        .row_index = integer(0),
        lat_num = numeric(0),
        lon_num = numeric(0),
        decimalLatitude = numeric(0),
        decimalLongitude = numeric(0),
        valid = logical(0),
        issue_type = character(0),
        error_key = character(0),
        stringsAsFactors = FALSE
    )
}

coords_aliases_cache <- create_rds_cache("coords_aliases")

coords_fuzzy_cache <- create_rds_cache("coords_fuzzy")

ne_land_env <- new.env(parent = emptyenv())

coords_embedded_land_10m_asset <- "ne_land_10m_americas.rds"

coords_embedded_land_margin_deg <- 2

coords_resolve_embedded_ne_land_path <- function() {
    candidates <- c(
        system.file("extdata", coords_embedded_land_10m_asset, package = "saira"),
        file.path("inst", "extdata", coords_embedded_land_10m_asset),
        file.path("..", "..", "inst", "extdata", coords_embedded_land_10m_asset)
    )
    candidates <- unique(candidates[nzchar(candidates)])
    path <- candidates[file.exists(candidates)][1]
    if (is.null(path) || is.na(path) || !file.exists(path)) {
        return("")
    }
    path
}

coords_read_embedded_ne_land <- function(path = coords_resolve_embedded_ne_land_path()) {
    if (!nzchar(path) || !file.exists(path)) {
        return(NULL)
    }

    raw <- tryCatch(readRDS(path), error = function(e) e)
    if (inherits(raw, "error")) {
        warning(
            sprintf("[Saira] Failed to read embedded Natural Earth land reference: %s", conditionMessage(raw)),
            call. = FALSE
        )
        return(NULL)
    }

    ref_obj <- if (is.list(raw) && !is.null(raw$ref)) raw$ref else raw
    ref <- tryCatch(
        {
            if (inherits(ref_obj, "SpatVector")) {
                ref_obj
            } else {
                terra::vect(ref_obj)
            }
        },
        error = function(e) e
    )
    if (inherits(ref, "error") ||
        !inherits(ref, "SpatVector") ||
        !identical(terra::geomtype(ref), "polygons")) {
        warning(
            "[Saira] Embedded Natural Earth land reference is invalid; expected polygon data.",
            call. = FALSE
        )
        return(NULL)
    }

    coverage_ref_obj <- if (is.list(raw)) raw$coverage_ref else NULL
    coverage_ref <- NULL
    if (!is.null(coverage_ref_obj)) {
        coverage_ref <- tryCatch(
            {
                if (inherits(coverage_ref_obj, "SpatVector")) {
                    coverage_ref_obj
                } else {
                    terra::vect(coverage_ref_obj)
                }
            },
            error = function(e) e
        )
        if (inherits(coverage_ref, "error") ||
            !inherits(coverage_ref, "SpatVector") ||
            !identical(terra::geomtype(coverage_ref), "polygons")) {
            warning(
                "[Saira] Embedded Natural Earth land coverage geometry is invalid; ignoring it.",
                call. = FALSE
            )
            coverage_ref <- NULL
        }
    }

    coverage_boxes <- if (is.list(raw)) raw$coverage_boxes else NULL
    if (!is.null(coverage_boxes)) {
        required_cols <- c("xmin", "xmax", "ymin", "ymax")
        if (!is.data.frame(coverage_boxes) || !all(required_cols %in% names(coverage_boxes))) {
            warning(
                "[Saira] Embedded Natural Earth land coverage boxes are invalid; ignoring embedded scale=10 reference.",
                call. = FALSE
            )
            return(NULL)
        }
        coverage_boxes <- coverage_boxes[, required_cols, drop = FALSE]
        coverage_boxes[] <- lapply(coverage_boxes, function(col) suppressWarnings(as.numeric(col)))
        coverage_boxes <- coverage_boxes[stats::complete.cases(coverage_boxes), , drop = FALSE]
        if (nrow(coverage_boxes) == 0L) {
            warning(
                "[Saira] Embedded Natural Earth land coverage boxes are empty; ignoring embedded scale=10 reference.",
                call. = FALSE
            )
            return(NULL)
        }
    }

    list(
        ref = ref,
        coverage_ref = coverage_ref,
        coverage_boxes = coverage_boxes,
        source = "embedded_americas_10m",
        path = path
    )
}

coords_get_ne_land_entry <- function(scale = 50L, download = TRUE) {
    scale <- as.integer(scale)
    key <- paste0("land_", scale)

    cached <- ne_land_env[[key]]
    if (!is.null(cached)) return(cached)

    entry <- NULL
    if (identical(scale, 10L)) {
        path <- coords_resolve_embedded_ne_land_path()
        if (!nzchar(path)) {
            if (isTRUE(download)) {
                warning(
                    "[Saira] Embedded Natural Earth land reference for scale=10 (Americas) not found; falling back to scale=50 where needed.",
                    call. = FALSE
                )
            }
            return(NULL)
        }
        entry <- coords_read_embedded_ne_land(path = path)
    } else if (scale %in% c(50L, 110L)) {
        land_sf <- tryCatch(
            rnaturalearth::ne_countries(
                scale = scale,
                type = "map_units",
                returnclass = "sf"
            ),
            error = function(e) e
        )
        if (inherits(land_sf, "error")) {
            if (isTRUE(download)) {
                warning(
                    sprintf("[Saira] Failed to load Natural Earth land reference (scale=%s): %s", scale, conditionMessage(land_sf)),
                    call. = FALSE
                )
            }
            return(NULL)
        }
        entry <- list(
            ref = terra::vect(land_sf),
            coverage_boxes = NULL,
            source = sprintf("map_units_%s", scale),
            path = NA_character_
        )
    }

    if (is.null(entry)) {
        return(NULL)
    }

    ne_land_env[[key]] <- entry
    entry
}

coords_load_ne_land <- function(scale = 50L, download = TRUE) {
    entry <- coords_get_ne_land_entry(scale = scale, download = download)
    if (is.null(entry)) {
        return(NULL)
    }
    entry$ref
}

coords_ne_land_coverage_boxes <- function(scale = 10L, download = TRUE) {
    entry <- coords_get_ne_land_entry(scale = scale, download = download)
    if (is.null(entry)) {
        return(NULL)
    }
    entry$coverage_boxes
}

coords_ne_land_coverage_ref <- function(scale = 10L, download = TRUE) {
    entry <- coords_get_ne_land_entry(scale = scale, download = download)
    if (is.null(entry)) {
        return(NULL)
    }
    entry$coverage_ref
}

coords_points_in_boxes <- function(x, boxes, margin = 0) {
    n <- nrow(x)
    if (n == 0L || is.null(boxes) || nrow(boxes) == 0L) {
        return(rep(FALSE, n))
    }

    lon <- suppressWarnings(as.numeric(x$decimalLongitude))
    lat <- suppressWarnings(as.numeric(x$decimalLatitude))
    inside <- rep(FALSE, n)

    for (idx in seq_len(nrow(boxes))) {
        box <- boxes[idx, , drop = FALSE]
        inside <- inside |
            (lon >= (box$xmin - margin) &
            lon <= (box$xmax + margin) &
            lat >= (box$ymin - margin) &
            lat <= (box$ymax + margin))
    }

    inside[is.na(lon) | is.na(lat)] <- FALSE
    inside
}

coords_points_in_coverage <- function(x, coverage_ref = NULL, coverage_boxes = NULL, margin = 0) {
    n <- nrow(x)
    if (n == 0L) {
        return(logical(0))
    }

    if (!is.null(coverage_ref) && inherits(coverage_ref, "SpatVector")) {
        pts <- terra::vect(
            x[, c("decimalLongitude", "decimalLatitude"), drop = FALSE],
            geom = c("decimalLongitude", "decimalLatitude"),
            crs = "+proj=longlat +datum=WGS84 +no_defs"
        )
        extracted <- tryCatch(terra::extract(coverage_ref, pts), error = function(e) NULL)
        if (!is.null(extracted) && ncol(extracted) >= 2L) {
            return(!is.na(extracted[!duplicated(extracted[, 1]), 2]))
        }
    }

    coords_points_in_boxes(x, coverage_boxes, margin = margin)
}

coords_crop_land_ref <- function(ref, x, margin = coords_embedded_land_margin_deg) {
    if (is.null(ref) || !inherits(ref, "SpatVector") || nrow(x) == 0L) {
        return(ref)
    }

    lon <- suppressWarnings(as.numeric(x$decimalLongitude))
    lat <- suppressWarnings(as.numeric(x$decimalLatitude))
    valid <- is.finite(lon) & is.finite(lat)
    if (!any(valid)) {
        return(ref)
    }

    ref_ext <- terra::ext(ref)
    crop_ext <- terra::ext(
        max(min(lon[valid]) - margin, ref_ext$xmin),
        min(max(lon[valid]) + margin, ref_ext$xmax),
        max(min(lat[valid]) - margin, ref_ext$ymin),
        min(max(lat[valid]) + margin, ref_ext$ymax)
    )
    cropped <- tryCatch(terra::crop(ref, crop_ext), error = function(e) NULL)
    if (is.null(cropped) || nrow(cropped) == 0L) {
        return(ref)
    }
    cropped
}

coords_normalize_cc_sea_timeout <- function(timeout = NULL) {
    raw_timeout <- timeout
    if (is.null(raw_timeout)) {
        env_timeout <- Sys.getenv("SAIRA_CC_SEA_TIMEOUT", "")
        if (!nzchar(env_timeout)) {
            return(NULL)
        }
        raw_timeout <- env_timeout
    }

    timeout_num <- suppressWarnings(as.numeric(raw_timeout))
    if (!is.finite(timeout_num) || timeout_num <= 0) {
        return(NULL)
    }
    timeout_num
}

coords_with_optional_time_limit <- function(fn, timeout = NULL) {
    if (is.null(timeout)) {
        return(fn())
    }

    base::setTimeLimit(cpu = Inf, elapsed = timeout, transient = TRUE)
    on.exit(base::setTimeLimit(cpu = Inf, elapsed = Inf, transient = TRUE), add = TRUE)
    fn()
}

coords_cc_sea_run <- function(x, ref = NULL, scale = NULL, timeout = NULL, crop_ref = FALSE) {
    if (nrow(x) == 0L) {
        return(logical(0))
    }

    run <- function() {
        ref_to_use <- ref
        if (!is.null(ref_to_use) && isTRUE(crop_ref)) {
            ref_to_use <- coords_crop_land_ref(ref_to_use, x)
        }

        dots <- list(
            "cc_sea",
            x,
            lon = "decimalLongitude",
            lat = "decimalLatitude"
        )
        if (is.null(ref_to_use)) {
            dots$scale <- scale
        } else {
            dots$ref <- ref_to_use
        }
        do.call(coords_cc_flagged, dots)
    }

    tryCatch(
        coords_with_optional_time_limit(run, timeout = timeout),
        error = function(e) e
    )
}



resolve_country_aliases_path <- function() {
    candidates <- c(
        system.file("extdata", "country_aliases.rds", package = "saira"),
        file.path("inst", "extdata", "country_aliases.rds"),
        file.path("..", "..", "inst", "extdata", "country_aliases.rds")
    )
    candidates <- unique(candidates[nzchar(candidates)])
    path <- candidates[file.exists(candidates)][1]
    if (is.null(path) || is.na(path) || !file.exists(path)) {
        stop("country_aliases.rds not found in expected locations.", call. = FALSE)
    }
    path
}

normalize_country_token <- function(x) {
    out <- as.character(x)
    out[is.na(out)] <- ""
    out <- trimws(out)
    out <- iconv(out, from = "UTF-8", to = "ASCII//TRANSLIT")
    out[is.na(out)] <- ""
    out <- tolower(out)
    out <- gsub("[^a-z0-9]+", " ", out)
    trimws(out)
}

coords_sanitize_aliases_table <- function(alias_df) {
    if (!is.data.frame(alias_df) || !all(c("alias", "iso3c") %in% names(alias_df))) {
        stop("country_aliases.rds must be a data.frame with columns alias and iso3c.", call. = FALSE)
    }

    clean <- data.frame(
        alias = normalize_country_token(alias_df$alias),
        iso3c = toupper(trimws(as.character(alias_df$iso3c))),
        stringsAsFactors = FALSE
    )
    clean <- clean[nzchar(clean$alias) & grepl("^[A-Z]{3}$", clean$iso3c), , drop = FALSE]
    if (nrow(clean) == 0L) {
        stop("country_aliases.rds has no valid alias entries.", call. = FALSE)
    }

    alias_groups <- split(clean$iso3c, clean$alias)
    ambiguous <- names(alias_groups)[vapply(alias_groups, function(x) length(unique(x)) > 1L, FUN.VALUE = logical(1))]
    if (length(ambiguous) > 0L) {
        stop(
            sprintf(
                "country_aliases.rds has conflicting iso3c values for aliases: %s",
                paste(utils::head(ambiguous, 10L), collapse = ", ")
            ),
            call. = FALSE
        )
    }

    clean <- clean[!duplicated(clean$alias), , drop = FALSE]
    rownames(clean) <- NULL
    clean
}

coords_load_aliases <- function(force = FALSE) {
    validate_force_flag(force)

    if (!isTRUE(force) && !is.null(coords_aliases_cache$get())) {
        return(coords_aliases_cache$get())
    }

    path <- resolve_country_aliases_path()
    alias_df <- readRDS(path)
    alias_df <- coords_sanitize_aliases_table(alias_df)

    coords_aliases_cache$set(alias_df, path = path)
    alias_df
}

coords_alias_map <- function() {
    alias_df <- coords_load_aliases()
    stats::setNames(alias_df$iso3c, alias_df$alias)
}

coords_build_fuzzy_reference <- function(force = FALSE) {
    validate_force_flag(force)

    if (!isTRUE(force) && !is.null(coords_fuzzy_cache$get())) {
        return(coords_fuzzy_cache$get())
    }
    if (!requireNamespace("countrycode", quietly = TRUE)) {
        stop("Package 'countrycode' is required for country conversion.", call. = FALSE)
    }

    alias_df <- coords_load_aliases(force = force)
    codelist <- countrycode::codelist
    origin_cols <- intersect(
        c(
            "country.name.en",
            "country.name.de",
            "country.name.fr",
            "country.name.it",
            "cldr.name.pt",
            "cldr.name.es",
            "cldr.name.de",
            "cldr.name.fr",
            "cldr.name.it",
            "cldr.name.en"
        ),
        names(codelist)
    )

    ref_parts <- lapply(origin_cols, function(col_name) {
        data.frame(
            alias = normalize_country_token(codelist[[col_name]]),
            iso3c = toupper(as.character(codelist$iso3c)),
            stringsAsFactors = FALSE
        )
    })
    ref <- do.call(rbind, c(ref_parts, list(alias_df[, c("alias", "iso3c"), drop = FALSE])))
    ref <- ref[nzchar(ref$alias) & grepl("^[A-Z]{3}$", ref$iso3c), , drop = FALSE]

    alias_groups <- split(ref$iso3c, ref$alias)
    resolved <- vapply(alias_groups, function(x) {
        ux <- unique(x)
        if (length(ux) == 1L) ux[[1]] else NA_character_
    }, FUN.VALUE = character(1))
    resolved <- resolved[!is.na(resolved) & nzchar(names(resolved))]

    out <- data.frame(
        alias = names(resolved),
        iso3c = unname(resolved),
        stringsAsFactors = FALSE
    )
    out <- out[order(out$alias), , drop = FALSE]
    rownames(out) <- NULL

    coords_fuzzy_cache$set(out)
    out
}

coords_assert_cc_dependencies <- function() {
    required_pkgs <- c("CoordinateCleaner", "countrycode", "sf", "rnaturalearth", "rnaturalearthdata")
    missing <- required_pkgs[!vapply(required_pkgs, requireNamespace, FUN.VALUE = logical(1), quietly = TRUE)]
    if (length(missing) > 0L) {
        stop(
            sprintf(
                "Missing required packages for coordinate validation: %s",
                paste(missing, collapse = ", ")
            ),
            call. = FALSE
        )
    }
}

coords_country_to_iso3 <- function(country_values) {
    if (!requireNamespace("countrycode", quietly = TRUE)) {
        stop("Package 'countrycode' is required for country conversion.", call. = FALSE)
    }

    raw <- as.character(country_values)
    raw[is.na(raw) | !nzchar(trimws(raw))] <- NA_character_
    if (length(raw) == 0L) {
        return(character(0))
    }

    uniq_vals <- unique(raw)
    out_uniq <- rep(NA_character_, length(uniq_vals))
    pending <- !is.na(uniq_vals)

    apply_layer <- function(out_uniq, pending, origin, custom_dict = NULL) {
        if (!any(pending)) {
            return(list(out_uniq = out_uniq, pending = pending))
        }
        idx_pending <- which(pending)
        source_vals <- uniq_vals[idx_pending]
        resolved <- tryCatch(
            {
                if (is.null(custom_dict)) {
                    countrycode::countrycode(
                        sourcevar = source_vals,
                        origin = origin,
                        destination = "iso3c",
                        warn = FALSE
                    )
                } else {
                    countrycode::countrycode(
                        sourcevar = source_vals,
                        origin = origin,
                        destination = "iso3c",
                        warn = FALSE,
                        custom_dict = custom_dict
                    )
                }
            },
            error = function(e) rep(NA_character_, length(source_vals))
        )
        resolved <- toupper(as.character(resolved))
        hit <- !is.na(resolved) & nzchar(resolved)
        if (any(hit)) {
            out_uniq[idx_pending[hit]] <- resolved[hit]
            pending[idx_pending[hit]] <- FALSE
        }
        list(out_uniq = out_uniq, pending = pending)
    }

    apply_result <- apply_layer(out_uniq, pending, "iso3c")
    out_uniq <- apply_result$out_uniq
    pending <- apply_result$pending
    apply_result <- apply_layer(out_uniq, pending, "iso2c")
    out_uniq <- apply_result$out_uniq
    pending <- apply_result$pending

    # Layer 2: multilingual CLDR names via custom_dict.
    codelist <- countrycode::codelist
    cldr_origins <- c(
        "cldr.name.pt",
        "cldr.name.es",
        "cldr.name.fr",
        "cldr.name.de",
        "cldr.name.it",
        "cldr.name.en"
    )
    for (origin in cldr_origins) {
        if (!origin %in% names(codelist)) {
            next
        }
        custom_dict <- codelist[, c("iso3c", origin), drop = FALSE]
        apply_result <- apply_layer(out_uniq, pending, origin, custom_dict = custom_dict)
        out_uniq <- apply_result$out_uniq
        pending <- apply_result$pending
    }

    # Layer 3: country.name plus regex origins.
    name_origins <- c(
        "country.name",
        "country.name.en.regex",
        "country.name.de.regex",
        "country.name.fr.regex",
        "country.name.it.regex"
    )
    for (origin in name_origins) {
        apply_result <- apply_layer(out_uniq, pending, origin)
        out_uniq <- apply_result$out_uniq
        pending <- apply_result$pending
    }

    # Layer 4: custom aliases from country_aliases.rds.
    if (any(pending)) {
        idx_pending <- which(pending)
        tokens <- normalize_country_token(uniq_vals[idx_pending])
        alias_df <- coords_load_aliases()
        hit <- match(tokens, alias_df$alias)
        has_hit <- !is.na(hit)
        if (any(has_hit)) {
            out_uniq[idx_pending[has_hit]] <- alias_df$iso3c[hit[has_hit]]
            pending[idx_pending[has_hit]] <- FALSE
        }
    }

    # Layer 5: conservative fuzzy matching (Levenshtein) — batch matrix.
    if (any(pending)) {
        idx_pending <- which(pending)
        ref <- coords_build_fuzzy_reference()
        if (nrow(ref) > 0L) {
            # Batch: pre-normalize all pending tokens once
            pending_tokens <- normalize_country_token(uniq_vals[idx_pending])
            valid_mask <- nzchar(pending_tokens) & nchar(pending_tokens) >= 4L

            if (any(valid_mask)) {
                valid_indices <- idx_pending[valid_mask]
                valid_tokens <- pending_tokens[valid_mask]

                tryCatch(
                    {
                        dist_matrix <- utils::adist(
                            valid_tokens, ref$alias,
                            ignore.case = TRUE
                        )
                        storage.mode(dist_matrix) <- "integer"

                        for (i in seq_along(valid_tokens)) {
                            dist_row <- dist_matrix[i, ]
                            if (all(is.na(dist_row))) next

                            best_dist <- min(dist_row, na.rm = TRUE)
                            if (!is.finite(best_dist)) next

                            token_len <- nchar(valid_tokens[[i]])
                            max_dist <- max(1L, floor(token_len / 4L))
                            if (best_dist > max_dist) next

                            best_idx <- which(dist_row == best_dist)
                            if (length(best_idx) != 1L) next

                            higher <- dist_row[dist_row > best_dist]
                            second_best <- if (length(higher) == 0L) {
                                Inf
                            } else {
                                min(higher, na.rm = TRUE)
                            }
                            if (is.finite(second_best) &&
                                (second_best - best_dist) < 1L) {
                                next
                            }

                            idx <- valid_indices[[i]]
                            out_uniq[[idx]] <- ref$iso3c[[best_idx]]
                            pending[[idx]] <- FALSE
                        }
                    },
                    error = function(e) {
                        warning(
                            "[Saira] Fuzzy batch failed, skipping: ",
                            e$message
                        )
                    }
                )
            }
        }
    }

    out <- out_uniq[match(raw, uniq_vals)]
    out <- toupper(trimws(as.character(out)))
    out[!nzchar(out)] <- NA_character_
    out
}

coords_cc_flagged <- function(fun_name, x, ...) {
    fun_name <- match.arg(fun_name, c("cc_val", "cc_sea", "cc_zero", "cc_equ", "cc_cap", "cc_cen", "cc_gbif", "cc_inst"))
    fn <- switch(fun_name,
        cc_val  = CoordinateCleaner::cc_val,
        cc_sea  = CoordinateCleaner::cc_sea,
        cc_zero = CoordinateCleaner::cc_zero,
        cc_equ  = CoordinateCleaner::cc_equ,
        cc_cap  = CoordinateCleaner::cc_cap,
        cc_cen  = CoordinateCleaner::cc_cen,
        cc_gbif = CoordinateCleaner::cc_gbif,
        cc_inst = CoordinateCleaner::cc_inst
    )
    flagged <- fn(x = x, value = "flagged", verbose = FALSE, ...)
    flagged <- as.logical(flagged)
    if (length(flagged) != nrow(x)) {
        stop(
            sprintf("CoordinateCleaner::%s returned unexpected output length.", fun_name),
            call. = FALSE
        )
    }
    flagged
}

coords_cc_sea_flagged <- function(x, scale, timeout = NULL) {
    scale <- as.integer(scale)
    timeout <- coords_normalize_cc_sea_timeout(timeout)

    run_scale <- function(x_subset, scale_value, ref = NULL, crop_ref = FALSE) {
        coords_cc_sea_run(
            x = x_subset,
            ref = ref,
            scale = scale_value,
            timeout = timeout,
            crop_ref = crop_ref
        )
    }

    if (identical(scale, 10L)) {
        land_ref_10 <- coords_load_ne_land(10L)
        coverage_ref_10 <- coords_ne_land_coverage_ref(10L, download = FALSE)
        coverage_boxes <- coords_ne_land_coverage_boxes(10L, download = FALSE)

        if (is.null(land_ref_10) ||
            (is.null(coverage_ref_10) &&
            (is.null(coverage_boxes) || nrow(coverage_boxes) == 0L))) {
            land_ref_50 <- coords_load_ne_land(50L)
            flagged_50 <- run_scale(x, 50L, ref = land_ref_50, crop_ref = FALSE)
            if (!inherits(flagged_50, "error")) {
                return(flagged_50)
            }

            warning(
                sprintf(
                    "[Saira] cc_sea(scale=10) could not use the embedded Americas reference and scale=50 fallback failed: %s; skipping sea check for this run.",
                    conditionMessage(flagged_50)
                ),
                call. = FALSE
            )
            return(rep(TRUE, nrow(x)))
        }

        inside_americas <- coords_points_in_coverage(
            x,
            coverage_ref = coverage_ref_10,
            coverage_boxes = coverage_boxes,
            margin = coords_embedded_land_margin_deg
        )

        # Short-circuit: dataset 100% nas Americas -> um unico cc_sea(10m)
        if (all(inside_americas)) {
            flagged_10 <- run_scale(x, 10L, ref = land_ref_10, crop_ref = TRUE)
            if (inherits(flagged_10, "error")) {
                warning(
                    sprintf(
                        "[Saira] cc_sea(scale=10, embedded Americas) failed: %s; skipping sea check for all rows.",
                        conditionMessage(flagged_10)
                    ),
                    call. = FALSE
                )
                return(rep(TRUE, nrow(x)))
            }
            return(flagged_10)
        }

        # Short-circuit: dataset 100% fora das Americas -> um unico cc_sea(50m)
        if (!any(inside_americas)) {
            land_ref_50 <- coords_load_ne_land(50L)
            flagged_50 <- run_scale(x, 50L, ref = land_ref_50, crop_ref = FALSE)
            if (inherits(flagged_50, "error")) {
                warning(
                    sprintf(
                        "[Saira] cc_sea(scale=50 fallback outside embedded Americas coverage) failed: %s; skipping sea check for all rows.",
                        conditionMessage(flagged_50)
                    ),
                    call. = FALSE
                )
                return(rep(TRUE, nrow(x)))
            }
            return(flagged_50)
        }

        # Caso misto: dois cc_sea para grupos distintos
        flagged <- rep(TRUE, nrow(x))

        flagged_10 <- run_scale(
            x[inside_americas, , drop = FALSE],
            10L,
            ref = land_ref_10,
            crop_ref = TRUE
        )
        if (inherits(flagged_10, "error")) {
            warning(
                sprintf(
                    "[Saira] cc_sea(scale=10, embedded Americas) failed: %s; skipping sea check for affected rows.",
                    conditionMessage(flagged_10)
                ),
                call. = FALSE
            )
        } else {
            flagged[inside_americas] <- flagged_10
        }

        land_ref_50 <- coords_load_ne_land(50L)
        flagged_50 <- run_scale(
            x[!inside_americas, , drop = FALSE],
            50L,
            ref = land_ref_50,
            crop_ref = FALSE
        )
        if (inherits(flagged_50, "error")) {
            warning(
                sprintf(
                    "[Saira] cc_sea(scale=50 fallback outside embedded Americas coverage) failed: %s; skipping sea check for affected rows.",
                    conditionMessage(flagged_50)
                ),
                call. = FALSE
            )
        } else {
            flagged[!inside_americas] <- flagged_50
        }

        return(flagged)
    }

    land_ref <- coords_load_ne_land(scale)
    flagged <- run_scale(x, scale, ref = land_ref, crop_ref = FALSE)
    if (!inherits(flagged, "error")) {
        return(flagged)
    }

    warning(
        sprintf(
            "[Saira] cc_sea(scale=%s) failed: %s; skipping sea check for this run.",
            scale,
            conditionMessage(flagged)
        ),
        call. = FALSE
    )
    rep(TRUE, nrow(x))
}

coords_family_from_diag <- function(diagnostic) {
    family_map <- c(
        ok = "ok",
        validity_missing = "validity",
        validity_bounds = "validity",
        swapped = "validity",
        sea = "sea",
        zero_equal = "zero_equal",
        identical_all = "zero_equal",
        reference = "reference"
    )
    out <- unname(family_map[diagnostic])
    out[is.na(out)] <- "validity"
    out
}

coords_empty_cc_result <- function() {
    data.frame(
        .row_index = integer(0),
        lat_num = numeric(0),
        lon_num = numeric(0),
        decimalLatitude = numeric(0),
        decimalLongitude = numeric(0),
        country = character(0),
        country_iso3 = character(0),
        profile = character(0),
        diagnostic = character(0),
        diagnostic_family = character(0),
        valid = logical(0),
        issue_type = character(0),
        error_key = character(0),
        stringsAsFactors = FALSE
    )
}

#' Validate coordinates using CoordinateCleaner with deterministic diagnostics
#'
#' @param df Data frame with mapped columns
#' @param lat_col Latitude column name
#' @param lon_col Longitude column name
#' @param country_col Country column name
#' @param profile Validation profile (`"complete"` or `"fast"`)
#' @param seas_scale Landmass resolution for sea test (10 = embedded Americas detail, 50 = medium global fallback, 110 = coarse global). Default `10` uses the embedded Americas reference and falls back to `50` only for points outside that coverage.
#' @return Data frame preserving input cardinality with flags and final diagnosis
#' @export
validate_coords_cc_df <- function(
  df,
  lat_col,
  lon_col,
  country_col,
  profile = c("complete", "fast"),
  seas_scale = 10L
) {
    if (!is.data.frame(df)) {
        stop("df must be a data.frame.", call. = FALSE)
    }
    profile <- match.arg(profile)
    seas_scale <- as.integer(seas_scale)
    if (!seas_scale %in% c(10L, 50L, 110L)) seas_scale <- 10L
    for (col_name in c(lat_col, lon_col, country_col)) {
        if (!is.character(col_name) || length(col_name) != 1L || !nzchar(col_name)) {
            stop("lat_col, lon_col and country_col must be non-empty strings.", call. = FALSE)
        }
        if (!col_name %in% names(df)) {
            stop(sprintf("Column not found: %s", col_name), call. = FALSE)
        }
    }

    coords_assert_cc_dependencies()

    # Performance logging controlado por SAIRA_COORDS_PROFILE=true
    # Zero custo quando env var nao definida: .plog() no-op imediato
    .perf <- if (identical(Sys.getenv("SAIRA_COORDS_PROFILE"), "true")) {
        e <- new.env(parent = emptyenv())
        e$t_phase <- proc.time()
        e$t_total <- proc.time()
        e$log <- function(phase) {
            elapsed_phase <- (proc.time() - e$t_phase)[["elapsed"]]
            elapsed_total <- (proc.time() - e$t_total)[["elapsed"]]
            message(sprintf(
                "[saira/coords] %-32s %5.2fs  (total acum: %5.2fs)",
                phase, elapsed_phase, elapsed_total
            ))
            e$t_phase <- proc.time()
        }
        e
    } else {
        NULL
    }
    .plog <- function(phase) if (!is.null(.perf)) .perf$log(phase)

    n <- nrow(df)
    if (n == 0L) {
        out <- coords_empty_cc_result()
        attr(out, "conversion_failures") <- list(lat = 0L, lon = 0L, total = 0L)
        attr(out, "engine") <- "CoordinateCleaner"
        attr(out, "profile") <- profile
        attr(out, "seas_scale") <- seas_scale
        return(out)
    }

    lat_parsed <- as_coord_numeric(df[[lat_col]])
    lon_parsed <- as_coord_numeric(df[[lon_col]])
    lat_num <- lat_parsed$num
    lon_num <- lon_parsed$num
    .plog("parse lat/lon")

    country_raw <- as.character(df[[country_col]])
    country_raw[is.na(country_raw)] <- ""
    country_raw <- trimws(country_raw)
    country_iso3 <- coords_country_to_iso3(country_raw)
    .plog("country_to_iso3")

    validity_missing <- is.na(lat_num) | is.na(lon_num)
    swapped <- !validity_missing &
        lat_num >= -180 & lat_num <= 180 &
        (lat_num < -90 | lat_num > 90) &
        lon_num >= -90 & lon_num <= 90
    validity_bounds <- !validity_missing & !swapped &
        (lat_num < -90 | lat_num > 90 | lon_num < -180 | lon_num > 180)

    sea_flag <- rep(FALSE, n)
    zero_equal <- rep(FALSE, n)
    reference_flag <- rep(FALSE, n)

    candidate_idx <- !validity_missing & !validity_bounds & !swapped
    if (any(candidate_idx)) {
        rows_candidate <- which(candidate_idx)
        cc_candidate <- data.frame(
            decimalLongitude = lon_num[rows_candidate],
            decimalLatitude = lat_num[rows_candidate],
            stringsAsFactors = FALSE
        )

        flag_val <- coords_cc_flagged(
            "cc_val",
            cc_candidate,
            lon = "decimalLongitude",
            lat = "decimalLatitude"
        )
        .plog("cc_val")
        rows_val_fail <- rows_candidate[!flag_val]
        if (length(rows_val_fail) > 0L) {
            validity_bounds[rows_val_fail] <- TRUE
        }

        rows_clean <- rows_candidate[flag_val]
        if (length(rows_clean) > 0L) {
            cc_clean <- data.frame(
                decimalLongitude = lon_num[rows_clean],
                decimalLatitude = lat_num[rows_clean],
                stringsAsFactors = FALSE
            )

            flag_sea <- coords_cc_sea_flagged(
                cc_clean,
                scale = seas_scale
            )
            sea_flag[rows_clean] <- !flag_sea
            .plog("cc_sea")

            flag_zero <- coords_cc_flagged(
                "cc_zero",
                cc_clean,
                lon = "decimalLongitude",
                lat = "decimalLatitude",
                buffer = 0.5
            )
            flag_equal <- coords_cc_flagged(
                "cc_equ",
                cc_clean,
                lon = "decimalLongitude",
                lat = "decimalLatitude",
                test = "absolute"
            )
            zero_equal[rows_clean] <- (!flag_zero | !flag_equal)
            .plog("cc_zero + cc_equ")

            if (identical(profile, "complete")) {
                flag_cap <- coords_cc_flagged(
                    "cc_cap",
                    cc_clean,
                    lon = "decimalLongitude",
                    lat = "decimalLatitude"
                )
                flag_cen <- coords_cc_flagged(
                    "cc_cen",
                    cc_clean,
                    lon = "decimalLongitude",
                    lat = "decimalLatitude",
                    test = "both"
                )
                flag_gbif <- coords_cc_flagged(
                    "cc_gbif",
                    cc_clean,
                    lon = "decimalLongitude",
                    lat = "decimalLatitude"
                )
                flag_inst <- coords_cc_flagged(
                    "cc_inst",
                    cc_clean,
                    lon = "decimalLongitude",
                    lat = "decimalLatitude",
                    geod = FALSE
                )
                reference_flag[rows_clean] <- !(
                    flag_cap & flag_cen & flag_gbif & flag_inst
                )
                .plog("cc_cap + cc_cen + cc_gbif + cc_inst")
            }
        }
    }

    diagnostic <- rep("ok", n)
    diagnostic[reference_flag] <- "reference"
    diagnostic[zero_equal] <- "zero_equal"
    diagnostic[sea_flag] <- "sea"
    diagnostic[validity_bounds] <- "validity_bounds"
    diagnostic[swapped] <- "swapped"
    diagnostic[validity_missing] <- "validity_missing"

    complete_idx <- !validity_missing & !validity_bounds & !swapped
    has_identical_all <- FALSE
    if (sum(complete_idx, na.rm = TRUE) >= 2L) {
        coord_key <- paste(lat_num[complete_idx], lon_num[complete_idx], sep = "||")
        has_identical_all <- length(unique(coord_key)) == 1L
        if (has_identical_all) {
            idx_identical <- complete_idx & diagnostic == "ok"
            diagnostic[idx_identical] <- "identical_all"
        }
    }

    diagnostic[is.na(diagnostic) | !nzchar(diagnostic)] <- "validity_bounds"
    diagnostic_family <- coords_family_from_diag(diagnostic)
    valid <- diagnostic == "ok"

    error_key_map <- c(
        ok = "",
        validity_missing = "validate_coords_diag_validity_missing",
        validity_bounds = "validate_coords_diag_validity_bounds",
        swapped = "validate_coords_diag_swapped",
        sea = "validate_coords_diag_sea",
        zero_equal = "validate_coords_diag_zero_equal",
        identical_all = "validate_coords_diag_identical_all",
        reference = "validate_coords_diag_reference"
    )
    error_key <- unname(error_key_map[diagnostic])
    error_key[is.na(error_key)] <- ""

    out <- data.frame(
        .row_index = seq_len(n),
        lat_num = lat_num,
        lon_num = lon_num,
        decimalLatitude = lat_num,
        decimalLongitude = lon_num,
        country = country_raw,
        country_iso3 = country_iso3,
        profile = rep(profile, n),
        diagnostic = diagnostic,
        diagnostic_family = diagnostic_family,
        valid = valid,
        issue_type = diagnostic,
        error_key = error_key,
        stringsAsFactors = FALSE
    )

    out$flag_validity_missing <- validity_missing
    out$flag_validity_bounds <- validity_bounds
    out$flag_swapped <- swapped
    out$flag_sea <- sea_flag
    out$flag_zero_equal <- zero_equal
    out$flag_reference <- reference_flag

    attr(out, "conversion_failures") <- list(
        lat = as.integer(sum(lat_parsed$parse_failed, na.rm = TRUE)),
        lon = as.integer(sum(lon_parsed$parse_failed, na.rm = TRUE)),
        total = as.integer(sum(lat_parsed$parse_failed, na.rm = TRUE) + sum(lon_parsed$parse_failed, na.rm = TRUE))
    )
    attr(out, "has_identical_all") <- isTRUE(has_identical_all)
    attr(out, "engine") <- "CoordinateCleaner"
    attr(out, "profile") <- profile
    attr(out, "seas_scale") <- seas_scale
    .plog("TOTAL")
    out
}

# Coordinate transformations tried when correcting transposed / sign-flipped
# coordinates, in priority order. Each maps original (lat, lon) to a candidate.
coords_transpose_transforms <- function() {
    list(
        list(key = "swap",          fn = function(la, lo) list(lat = lo,  lon = la)),
        list(key = "neg_lon",       fn = function(la, lo) list(lat = la,  lon = -lo)),
        list(key = "neg_lat",       fn = function(la, lo) list(lat = -la, lon = lo)),
        list(key = "neg_both",      fn = function(la, lo) list(lat = -la, lon = -lo)),
        list(key = "swap_neg_lon",  fn = function(la, lo) list(lat = lo,  lon = -la)),
        list(key = "swap_neg_lat",  fn = function(la, lo) list(lat = -lo, lon = la)),
        list(key = "swap_neg_both", fn = function(la, lo) list(lat = -lo, lon = -la))
    )
}

# Point-in-polygon test for a single (already-subset) country SpatVector.
# Returns a logical vector aligned with lon/lat; FALSE for out-of-range/NA.
coords_points_in_poly <- function(lon, lat, poly) {
    n <- length(lon)
    out <- rep(FALSE, n)
    if (is.null(poly) || nrow(poly) == 0L) return(out)
    ok <- is.finite(lon) & is.finite(lat) & abs(lat) <= 90 & abs(lon) <= 180
    if (!any(ok)) return(out)
    pts <- terra::vect(
        data.frame(.lon = lon[ok], .lat = lat[ok]),
        geom = c(".lon", ".lat"),
        crs = "+proj=longlat +datum=WGS84 +no_defs"
    )
    ex <- tryCatch(terra::extract(poly[, 1], pts), error = function(e) NULL)
    if (is.null(ex) || ncol(ex) < 2L) return(out)
    ex <- ex[!duplicated(ex[[1]]), , drop = FALSE]
    out[ok] <- !is.na(ex[[2]])
    out
}

#' Detect and correct transposed / sign-flipped geographic coordinates
#'
#' For records whose verbatim coordinates fall outside the informed country (plus
#' an optional border buffer), tries latitude/longitude swap and sign-flip
#' transformations on Saira's bundled Natural Earth country layer and accepts the
#' first that lands inside the country. Verbatim coordinates are never mutated
#' here — corrections are returned alongside the originals so the caller (UI) can
#' preview and apply them explicitly.
#'
#' @param df data.frame with coordinate and country columns.
#' @param lat_col,lon_col,country_col Column names.
#' @param country_iso3 Optional precomputed ISO3 vector (else resolved from
#'   \code{country_col} via \code{coords_country_to_iso3()}).
#' @param border_buffer Numeric degrees. Records within this distance of the
#'   informed country border are left untouched. Default 0.2 (~22 km).
#' @param ref Optional country SpatVector (else \code{coords_load_ne_land(50)}).
#' @param iso_col ISO3 attribute column name in \code{ref}.
#' @return Named list: \code{corrected} (logical), \code{lat_new}/\code{lon_new}
#'   (numeric, equal to originals where not corrected), \code{transform}
#'   (character key or NA), \code{informed_country} (ISO3), \code{n_corrected},
#'   \code{n_candidates}, \code{available} (FALSE when no country layer could be
#'   loaded, e.g. offline).
#' @export
coords_transposed_corrections <- function(df,
                                          lat_col = "decimalLatitude",
                                          lon_col = "decimalLongitude",
                                          country_col = "country",
                                          country_iso3 = NULL,
                                          border_buffer = 0.2,
                                          ref = NULL,
                                          iso_col = "iso_a3_eh") {
    n <- if (is.data.frame(df)) nrow(df) else 0L
    lat0 <- if (n > 0L) as_coord_numeric(df[[lat_col]])$num else numeric(0)
    lon0 <- if (n > 0L) as_coord_numeric(df[[lon_col]])$num else numeric(0)

    base_out <- list(
        corrected = rep(FALSE, n),
        lat_new = lat0, lon_new = lon0,
        transform = rep(NA_character_, n),
        informed_country = rep(NA_character_, n),
        n_corrected = 0L, n_candidates = 0L, available = TRUE
    )
    if (n == 0L) return(base_out)

    if (is.null(country_iso3)) {
        country_iso3 <- coords_country_to_iso3(df[[country_col]])
    }
    country_iso3 <- toupper(as.character(country_iso3))
    base_out$informed_country <- country_iso3

    if (is.null(ref)) ref <- coords_load_ne_land(scale = 50L)
    if (is.null(ref) || !inherits(ref, "SpatVector") || !iso_col %in% names(ref)) {
        base_out$available <- FALSE
        return(base_out)
    }

    border_buffer <- suppressWarnings(as.numeric(border_buffer)[1L])
    if (!is.finite(border_buffer) || border_buffer < 0) border_buffer <- 0
    buf_m <- border_buffer * 111319.5  # ~ degrees -> metres at the equator

    has_iso <- !is.na(country_iso3) & nzchar(country_iso3)
    in_range <- is.finite(lat0) & is.finite(lon0) & abs(lat0) <= 180 & abs(lon0) <= 180

    lat_new <- lat0
    lon_new <- lon0
    transform <- rep(NA_character_, n)
    corrected <- rep(FALSE, n)
    candidate <- rep(FALSE, n)
    transforms <- coords_transpose_transforms()

    iso_values <- toupper(as.character(ref[[iso_col]][[1]]))
    for (iso in unique(country_iso3[has_iso & in_range])) {
        rows <- which(has_iso & in_range & country_iso3 == iso)
        if (length(rows) == 0L) next
        poly <- ref[which(iso_values == iso), ]
        if (nrow(poly) == 0L) next  # informed country not in the reference layer
        poly_acc <- if (buf_m > 0) {
            tryCatch(terra::buffer(poly, width = buf_m), error = function(e) poly)
        } else {
            poly
        }

        # Records already inside (buffered) country are not candidates.
        orig_in <- coords_points_in_poly(lon0[rows], lat0[rows], poly_acc)
        cand_rows <- rows[!orig_in]
        candidate[cand_rows] <- TRUE
        if (length(cand_rows) == 0L) next

        remaining <- cand_rows
        for (tf in transforms) {
            if (length(remaining) == 0L) break
            cand <- tf$fn(lat0[remaining], lon0[remaining])
            inside <- coords_points_in_poly(cand$lon, cand$lat, poly_acc)
            acc <- remaining[inside]
            if (length(acc) > 0L) {
                hit <- which(inside)
                lat_new[acc] <- cand$lat[hit]
                lon_new[acc] <- cand$lon[hit]
                transform[acc] <- tf$key
                corrected[acc] <- TRUE
                remaining <- remaining[!inside]
            }
        }
    }

    list(
        corrected = corrected,
        lat_new = lat_new, lon_new = lon_new,
        transform = transform,
        informed_country = country_iso3,
        n_corrected = sum(corrected),
        n_candidates = sum(candidate),
        available = TRUE
    )
}

#' Apply a transposed-coordinate correction payload at export time
#'
#' Companion to \code{coords_transposed_corrections()} consumed by the preview /
#' export module. Replaces \code{decimalLatitude}/\code{decimalLongitude} for the
#' rows named in the payload (matched by \code{occurrenceID}), preserving the
#' originals in \code{verbatimLatitude}/\code{verbatimLongitude} when those
#' columns exist and are still empty.
#'
#' @param df Export data frame (must contain occurrenceID + coordinate columns).
#' @param payload List with \code{corrections}: a data.frame of
#'   \code{occurrenceID}, \code{decimalLatitude}, \code{decimalLongitude}.
#' @return \code{df} with corrected coordinates applied.
#' @export
apply_coords_correction_payload <- function(df, payload = NULL) {
    if (!is.data.frame(df) || nrow(df) == 0L) return(df)
    if (is.null(payload) || !is.list(payload) ||
        is.null(payload$corrections) || !is.data.frame(payload$corrections)) {
        return(df)
    }
    corr <- payload$corrections
    needed <- c("occurrenceID", "decimalLatitude", "decimalLongitude")
    if (!all(needed %in% names(corr)) || nrow(corr) == 0L) return(df)
    if (!all(c("occurrenceID", "decimalLatitude", "decimalLongitude") %in% names(df))) {
        return(df)
    }

    corr <- corr[!is.na(corr$occurrenceID) & nzchar(as.character(corr$occurrenceID)), , drop = FALSE]
    corr <- corr[!duplicated(corr$occurrenceID, fromLast = TRUE), , drop = FALSE]
    if (nrow(corr) == 0L) return(df)

    idx <- match(as.character(corr$occurrenceID), as.character(df$occurrenceID))
    keep <- !is.na(idx)
    idx <- idx[keep]
    corr <- corr[keep, , drop = FALSE]
    if (length(idx) == 0L) return(df)

    # Preserve verbatim originals where the template provides the columns and
    # they are not already populated.
    for (vcol in c("verbatimLatitude", "verbatimLongitude")) {
        if (vcol %in% names(df)) {
            src <- if (vcol == "verbatimLatitude") "decimalLatitude" else "decimalLongitude"
            blank <- is.na(df[[vcol]][idx]) | !nzchar(trimws(as.character(df[[vcol]][idx])))
            df[[vcol]][idx[blank]] <- as.character(df[[src]][idx[blank]])
        }
    }

    df$decimalLatitude[idx]  <- as.character(corr$decimalLatitude)
    df$decimalLongitude[idx] <- as.character(corr$decimalLongitude)
    df
}

#' Derive country names from valid coordinates for records missing them
#'
#' For records whose \code{country} is blank but whose coordinates are valid,
#' looks up the country the point falls in on Saira's bundled Natural Earth
#' country layer (no name for points in the sea). Existing country values are
#' never overwritten.
#'
#' @param df data.frame with coordinate + country columns.
#' @param lat_col,lon_col,country_col Column names.
#' @param ref Optional country SpatVector (else \code{coords_load_ne_land(50)}).
#' @param name_col Country-name attribute column in \code{ref} (default "admin").
#' @return Named list: \code{filled} (logical), \code{country_new} (character,
#'   equal to the original where not filled), \code{n_filled}, \code{n_candidates},
#'   \code{available} (FALSE when no country layer could be loaded).
#' @export
coords_country_from_coordinates <- function(df,
                                            lat_col = "decimalLatitude",
                                            lon_col = "decimalLongitude",
                                            country_col = "country",
                                            ref = NULL,
                                            name_col = "admin") {
    n <- if (is.data.frame(df)) nrow(df) else 0L
    lat0 <- if (n > 0L) as_coord_numeric(df[[lat_col]])$num else numeric(0)
    lon0 <- if (n > 0L) as_coord_numeric(df[[lon_col]])$num else numeric(0)
    country0 <- if (n > 0L && country_col %in% names(df)) {
        as.character(df[[country_col]])
    } else {
        rep(NA_character_, n)
    }

    base_out <- list(
        filled = rep(FALSE, n), country_new = country0,
        n_filled = 0L, n_candidates = 0L, available = TRUE
    )
    if (n == 0L) return(base_out)

    if (is.null(ref)) ref <- coords_load_ne_land(scale = 50L)
    if (is.null(ref) || !inherits(ref, "SpatVector") || !name_col %in% names(ref)) {
        base_out$available <- FALSE
        return(base_out)
    }

    ctry_trim <- trimws(country0)
    ctry_trim[is.na(country0)] <- ""
    blank_country <- !nzchar(ctry_trim)
    valid_xy <- is.finite(lat0) & is.finite(lon0) & abs(lat0) <= 90 & abs(lon0) <= 180
    candidate <- blank_country & valid_xy

    country_new <- country0
    filled <- rep(FALSE, n)
    if (any(candidate)) {
        rows <- which(candidate)
        pts <- terra::vect(
            data.frame(.lon = lon0[rows], .lat = lat0[rows]),
            geom = c(".lon", ".lat"),
            crs = "+proj=longlat +datum=WGS84 +no_defs"
        )
        ex <- tryCatch(terra::extract(ref[, name_col], pts), error = function(e) NULL)
        if (!is.null(ex) && ncol(ex) >= 2L) {
            ex <- ex[!duplicated(ex[[1]]), , drop = FALSE]
            names_extracted <- as.character(ex[[2]])
            got <- !is.na(names_extracted) & nzchar(names_extracted)
            country_new[rows[got]] <- names_extracted[got]
            filled[rows[got]] <- TRUE
        }
    }

    list(
        filled = filled,
        country_new = country_new,
        n_filled = sum(filled),
        n_candidates = sum(candidate),
        available = TRUE
    )
}

#' Apply a country-from-coordinates fill payload at export time
#'
#' Companion to \code{coords_country_from_coordinates()}. Fills the \code{country}
#' column for the rows named in the payload (matched by \code{occurrenceID}),
#' only where the current value is still blank (never overwrites user input).
#'
#' @param df Export data frame (must contain occurrenceID + country columns).
#' @param payload List with \code{country}: a data.frame of \code{occurrenceID}
#'   and \code{country}.
#' @return \code{df} with missing country values filled.
#' @export
apply_country_fill_payload <- function(df, payload = NULL) {
    if (!is.data.frame(df) || nrow(df) == 0L) return(df)
    if (is.null(payload) || !is.list(payload) ||
        is.null(payload$country) || !is.data.frame(payload$country)) {
        return(df)
    }
    cf <- payload$country
    if (!all(c("occurrenceID", "country") %in% names(cf)) || nrow(cf) == 0L) return(df)
    if (!all(c("occurrenceID", "country") %in% names(df))) return(df)

    cf <- cf[!is.na(cf$occurrenceID) & nzchar(as.character(cf$occurrenceID)), , drop = FALSE]
    cf <- cf[!duplicated(cf$occurrenceID, fromLast = TRUE), , drop = FALSE]
    if (nrow(cf) == 0L) return(df)

    idx <- match(as.character(cf$occurrenceID), as.character(df$occurrenceID))
    keep <- !is.na(idx)
    idx <- idx[keep]
    cf <- cf[keep, , drop = FALSE]
    if (length(idx) == 0L) return(df)

    cur <- trimws(as.character(df$country[idx]))
    cur[is.na(df$country[idx])] <- ""
    blank <- !nzchar(cur)
    df$country[idx[blank]] <- as.character(cf$country)[blank]
    df
}

#' Reflect accepted coordinate corrections in a validation result
#'
#' Overlays the accepted transposed/swap coordinate corrections and country
#' fills onto a \code{validate_coords_cc_df()} result so the Coords tab map,
#' table and counts show the published point instead of the flagged original
#' (matching what Generalization and export publish). Rows whose coordinate
#' moved are re-tagged \code{diagnostic = diagnostic_family = "corrected"} (a
#' resolved overlay, not an outstanding problem); country fills update only the
#' \code{country} value. Rows are matched by \code{occurrenceID} via
#' \code{occ_ids}, the per-row occurrenceID vector captured at validation time
#' and aligned to \code{.row_index}.
#'
#' @param res \code{validate_coords_cc_df()} result data.frame.
#' @param coords_corrections List with \code{corrections} (occurrenceID +
#'   decimalLatitude/Longitude), or NULL.
#' @param country_fills List with \code{country} (occurrenceID + country), or NULL.
#' @param occ_ids Character vector of occurrenceIDs indexed by \code{.row_index}.
#' @return \code{res} with the corrections applied.
#' @noRd
apply_coord_corrections_to_result <- function(res, coords_corrections = NULL,
                                              country_fills = NULL, occ_ids = NULL) {
    if (!is.data.frame(res) || nrow(res) == 0L || !".row_index" %in% names(res)) {
        return(res)
    }
    if (!is.character(occ_ids) || length(occ_ids) == 0L) {
        return(res)
    }

    # occurrenceID -> .row_index value -> row position in res.
    res_pos_for <- function(occ) {
        match(match(as.character(occ), occ_ids), res$.row_index)
    }

    cc <- if (is.list(coords_corrections)) coords_corrections$corrections else NULL
    if (is.data.frame(cc) && nrow(cc) > 0L &&
        all(c("occurrenceID", "decimalLatitude", "decimalLongitude") %in% names(cc))) {
        pos <- res_pos_for(cc$occurrenceID)
        ok <- !is.na(pos)
        if (any(ok)) {
            p <- pos[ok]
            res$lat_num[p] <- suppressWarnings(as.numeric(cc$decimalLatitude[ok]))
            res$lon_num[p] <- suppressWarnings(as.numeric(cc$decimalLongitude[ok]))
            if ("diagnostic" %in% names(res)) res$diagnostic[p] <- "corrected"
            if ("diagnostic_family" %in% names(res)) res$diagnostic_family[p] <- "corrected"
            if ("valid" %in% names(res)) res$valid[p] <- TRUE
        }
    }

    cf <- if (is.list(country_fills)) country_fills$country else NULL
    if (is.data.frame(cf) && nrow(cf) > 0L &&
        all(c("occurrenceID", "country") %in% names(cf)) && "country" %in% names(res)) {
        pos <- res_pos_for(cf$occurrenceID)
        ok <- !is.na(pos)
        if (any(ok)) res$country[pos[ok]] <- as.character(cf$country[ok])
    }

    res
}

#' Combined latitude/longitude swap + country fill for country-less sea points
#'
#' Handles the case where \code{country} is blank AND the verbatim point falls in
#' the sea (no country) — a strong signal of a lat/lon swap that cannot be fixed
#' by the country-aware transposed check (no country to aim at) nor by the
#' country-from-coordinates fill (the point is at sea). Only the lat/lon swap is
#' tried (never sign flips), so the result is unambiguous: the swapped point is
#' inside at most one country. When it lands in a country, both the coordinates
#' (swapped) and the derived country are proposed together.
#'
#' @param df data.frame with coordinate + country columns.
#' @param lat_col,lon_col,country_col Column names.
#' @param ref Optional country SpatVector (else \code{coords_load_ne_land(50)}).
#' @param name_col Country-name attribute column in \code{ref} (default "admin").
#' @return Named list: \code{applies} (logical), \code{lat_new}/\code{lon_new}
#'   (swapped where applied, else original), \code{country_new} (derived where
#'   applied, else original), \code{n}, \code{available}.
#' @export
coords_swap_and_fill <- function(df,
                                 lat_col = "decimalLatitude",
                                 lon_col = "decimalLongitude",
                                 country_col = "country",
                                 ref = NULL,
                                 name_col = "admin") {
    n <- if (is.data.frame(df)) nrow(df) else 0L
    lat0 <- if (n > 0L) as_coord_numeric(df[[lat_col]])$num else numeric(0)
    lon0 <- if (n > 0L) as_coord_numeric(df[[lon_col]])$num else numeric(0)
    country0 <- if (n > 0L && country_col %in% names(df)) {
        as.character(df[[country_col]])
    } else {
        rep(NA_character_, n)
    }

    base_out <- list(
        applies = rep(FALSE, n), lat_new = lat0, lon_new = lon0,
        country_new = country0, n = 0L, available = TRUE
    )
    if (n == 0L) return(base_out)

    if (is.null(ref)) ref <- coords_load_ne_land(scale = 50L)
    if (is.null(ref) || !inherits(ref, "SpatVector") || !name_col %in% names(ref)) {
        base_out$available <- FALSE
        return(base_out)
    }

    country_at <- function(lon, lat) {
        out <- rep(NA_character_, length(lon))
        ok <- is.finite(lon) & is.finite(lat) & abs(lat) <= 90 & abs(lon) <= 180
        if (!any(ok)) return(out)
        pts <- terra::vect(
            data.frame(.lon = lon[ok], .lat = lat[ok]),
            geom = c(".lon", ".lat"), crs = "+proj=longlat +datum=WGS84 +no_defs"
        )
        ex <- tryCatch(terra::extract(ref[, name_col], pts), error = function(e) NULL)
        if (is.null(ex) || ncol(ex) < 2L) return(out)
        ex <- ex[!duplicated(ex[[1]]), , drop = FALSE]
        out[ok] <- as.character(ex[[2]])
        out
    }

    ctry <- trimws(country0)
    ctry[is.na(country0)] <- ""
    blank_country <- !nzchar(ctry)
    valid_xy <- is.finite(lat0) & is.finite(lon0) & abs(lat0) <= 90 & abs(lon0) <= 180

    # Only consider blank-country rows whose VERBATIM point is in the sea.
    orig_country <- rep(NA_character_, n)
    pre <- blank_country & valid_xy
    if (any(pre)) orig_country[pre] <- country_at(lon0[pre], lat0[pre])
    candidate <- pre & is.na(orig_country)

    applies <- rep(FALSE, n)
    lat_new <- lat0
    lon_new <- lon0
    country_new <- country0
    if (any(candidate)) {
        rows <- which(candidate)
        sw_lat <- lon0[rows]  # swap: new lat = old lon
        sw_lon <- lat0[rows]  # new lon = old lat
        sw_name <- country_at(sw_lon, sw_lat)
        got <- !is.na(sw_name) & nzchar(sw_name)
        acc <- rows[got]
        lat_new[acc] <- sw_lat[got]
        lon_new[acc] <- sw_lon[got]
        country_new[acc] <- sw_name[got]
        applies[acc] <- TRUE
    }

    list(
        applies = applies, lat_new = lat_new, lon_new = lon_new,
        country_new = country_new, n = sum(applies), available = TRUE
    )
}

#' Validate latitude/longitude columns with legacy issue typing
#'
#' @param df Data frame containing coordinate columns
#' @param lat_col Name of latitude column in `df`
#' @param lon_col Name of longitude column in `df`
#' @return Data frame with `.row_index`, numeric coordinates, `valid`,
#'   `issue_type`, and `error_key`
#' @export
validate_coords_df <- function(df, lat_col = "decimalLatitude", lon_col = "decimalLongitude") {
    if (!is.data.frame(df)) {
        stop("df must be a data.frame.")
    }
    if (!is.character(lat_col) || length(lat_col) != 1L || !nzchar(lat_col)) {
        stop("lat_col must be a non-empty string.")
    }
    if (!is.character(lon_col) || length(lon_col) != 1L || !nzchar(lon_col)) {
        stop("lon_col must be a non-empty string.")
    }
    if (!lat_col %in% names(df)) {
        stop(sprintf("Column not found: %s", lat_col))
    }
    if (!lon_col %in% names(df)) {
        stop(sprintf("Column not found: %s", lon_col))
    }

    n <- nrow(df)
    if (n == 0L) {
        out <- empty_coords_result()
        attr(out, "conversion_failures") <- list(lat = 0L, lon = 0L, total = 0L)
        attr(out, "has_identical_all") <- FALSE
        return(out)
    }

    lat_parsed <- as_coord_numeric(df[[lat_col]])
    lon_parsed <- as_coord_numeric(df[[lon_col]])

    lat_num <- lat_parsed$num
    lon_num <- lon_parsed$num

    issue_type <- rep("ok", n)
    missing_idx <- is.na(lat_num) | is.na(lon_num)
    issue_type[missing_idx] <- "missing"

    complete_idx <- !missing_idx
    zero_zero_idx <- complete_idx & lat_num == 0 & lon_num == 0
    issue_type[zero_zero_idx] <- "zero_zero"

    swapped_idx <- complete_idx &
        lat_num >= -180 & lat_num <= 180 &
        (lat_num < -90 | lat_num > 90) &
        lon_num >= -90 & lon_num <= 90
    issue_type[swapped_idx] <- "swapped"

    lat_range_idx <- complete_idx &
        (lat_num < -90 | lat_num > 90) &
        !swapped_idx
    issue_type[lat_range_idx] <- "lat_range"

    lon_range_idx <- complete_idx &
        (lon_num < -180 | lon_num > 180) &
        !lat_range_idx
    issue_type[lon_range_idx] <- "lon_range"

    complete_ok_idx <- complete_idx & issue_type == "ok"
    has_identical_all <- FALSE
    if (sum(complete_ok_idx, na.rm = TRUE) >= 2L) {
        coord_key <- paste(lat_num[complete_ok_idx], lon_num[complete_ok_idx], sep = "||")
        has_identical_all <- length(unique(coord_key)) == 1L
        if (has_identical_all) {
            issue_type[complete_ok_idx] <- "identical_all"
        }
    }

    valid <- issue_type %in% c("ok", "zero_zero", "swapped", "identical_all")

    error_key_map <- c(
        ok = "",
        missing = "validate_coords_badge_missing",
        lat_range = "validate_coords_badge_lat_range",
        lon_range = "validate_coords_badge_lon_range",
        zero_zero = "validate_coords_badge_zero_zero",
        swapped = "validate_coords_badge_swapped",
        identical_all = "validate_coords_badge_identical_all"
    )
    error_key <- unname(error_key_map[issue_type])
    error_key[is.na(error_key)] <- ""

    out <- data.frame(
        .row_index = seq_len(n),
        lat_num = lat_num,
        lon_num = lon_num,
        decimalLatitude = lat_num,
        decimalLongitude = lon_num,
        valid = valid,
        issue_type = issue_type,
        error_key = error_key,
        stringsAsFactors = FALSE
    )

    attr(out, "conversion_failures") <- list(
        lat = as.integer(sum(lat_parsed$parse_failed, na.rm = TRUE)),
        lon = as.integer(sum(lon_parsed$parse_failed, na.rm = TRUE)),
        total = as.integer(sum(lat_parsed$parse_failed, na.rm = TRUE) + sum(lon_parsed$parse_failed, na.rm = TRUE))
    )
    attr(out, "has_identical_all") <- isTRUE(has_identical_all)
    out
}

has_coord_columns <- function(df) {
    !is.null(detect_coord_columns(df))
}

detect_coord_columns <- function(df) {
    if (!is.data.frame(df) || length(names(df)) == 0L) {
        return(NULL)
    }

    col_names <- names(df)
    normalized <- tolower(trimws(col_names))

    pick_col <- function(candidates) {
        idx <- match(candidates, normalized)
        idx <- idx[!is.na(idx)]
        if (length(idx) == 0L) {
            return("")
        }
        col_names[[idx[[1]]]]
    }

    lat_col <- pick_col(c("decimallatitude", "latitude", "lat", "decimal_latitude", "verbatimlatitude"))
    lon_col <- pick_col(c("decimallongitude", "longitude", "lon", "lng", "decimal_longitude", "verbatimlongitude"))

    if (!nzchar(lat_col) || !nzchar(lon_col) || identical(lat_col, lon_col)) {
        return(NULL)
    }

    list(lat_col = lat_col, lon_col = lon_col)
}

count_coords_diagnostics <- function(result_df) {
    base_counts <- stats::setNames(as.integer(rep(0L, length(coord_family_levels))), coord_family_levels)
    if (!is.data.frame(result_df) || !"diagnostic_family" %in% names(result_df)) {
        return(as.list(c(
            total = 0L,
            ok = 0L,
            problems = 0L,
            missing = 0L,
            base_counts
        )))
    }

    fam <- as.character(result_df$diagnostic_family)
    fam[is.na(fam) | !nzchar(fam)] <- "validity"
    tab <- table(factor(fam, levels = coord_family_levels))
    fam_counts <- as.integer(tab)
    names(fam_counts) <- coord_family_levels

    diag_vec <- as.character(result_df$diagnostic)
    diag_vec[is.na(diag_vec) | !nzchar(diag_vec)] <- "validity_bounds"

    as.list(c(
        total = as.integer(nrow(result_df)),
        ok = as.integer(fam_counts[["ok"]]),
        # "corrected" rows are resolved overlays, not outstanding problems.
        problems = as.integer(sum(fam_counts[!(names(fam_counts) %in% c("ok", "corrected"))])),
        missing = as.integer(sum(diag_vec == "validity_missing", na.rm = TRUE)),
        fam_counts
    ))
}

count_coords_issues <- function(result_df) {
    if (is.data.frame(result_df) && "diagnostic_family" %in% names(result_df)) {
        return(count_coords_diagnostics(result_df))
    }

    zero_counts <- stats::setNames(as.integer(rep(0L, length(coord_issue_levels))), coord_issue_levels)
    if (!is.data.frame(result_df) || !"issue_type" %in% names(result_df)) {
        out <- as.list(c(
            total = 0L,
            zero_counts,
            invalid = 0L,
            warnings = 0L
        ))
        return(out)
    }

    issue_chr <- as.character(result_df$issue_type)
    issue_chr[is.na(issue_chr) | !nzchar(issue_chr)] <- "missing"
    tab <- table(factor(issue_chr, levels = coord_issue_levels))
    counts <- as.integer(tab)
    names(counts) <- coord_issue_levels

    invalid_count <- counts[["lat_range"]] + counts[["lon_range"]]
    warnings_count <- counts[["zero_zero"]] + counts[["swapped"]] + counts[["identical_all"]]

    as.list(c(
        total = as.integer(nrow(result_df)),
        counts,
        invalid = as.integer(invalid_count),
        warnings = as.integer(warnings_count)
    ))
}

build_leaflet_data <- function(coords_result_df, filter = "all", issue_labels = NULL, popup_labels = NULL) {
    empty <- data.frame(
        .row_index = integer(0),
        lat_num = numeric(0),
        lon_num = numeric(0),
        issue_type = character(0),
        diagnostic = character(0),
        diagnostic_family = character(0),
        color = character(0),
        popup_html = character(0),
        stringsAsFactors = FALSE
    )

    if (!is.data.frame(coords_result_df) || nrow(coords_result_df) == 0L) {
        return(empty)
    }

    popup_defaults <- list(row = "Row", issue = "Issue", lat = "Lat", lon = "Lon")
    if (is.list(popup_labels) && length(popup_labels) > 0L) {
        for (nm in names(popup_labels)) {
            if (is.character(nm) && nzchar(nm) && nm %in% names(popup_defaults)) {
                popup_defaults[[nm]] <- as.character(popup_labels[[nm]])
            }
        }
    }

    if (all(c(".row_index", "lat_num", "lon_num", "diagnostic", "diagnostic_family") %in% names(coords_result_df))) {
        filter_key <- as.character(if (is.null(filter)) "all" else filter)
        allowed_filters <- c("all", "problems", "validity", "sea", "zero_equal", "reference")
        if (!(filter_key %in% allowed_filters)) {
            filter_key <- "all"
        }

        diag <- as.character(coords_result_df$diagnostic)
        diag[is.na(diag) | !nzchar(diag)] <- "validity_bounds"
        fam <- as.character(coords_result_df$diagnostic_family)
        fam[is.na(fam) | !nzchar(fam)] <- "validity"

        keep_idx <- switch(filter_key,
            all = rep(TRUE, nrow(coords_result_df)),
            problems = fam != "ok",
            validity = fam == "validity",
            sea = fam == "sea",
            zero_equal = fam == "zero_equal",
            reference = fam == "reference",
            rep(TRUE, nrow(coords_result_df))
        )

        out <- coords_result_df[keep_idx, c(".row_index", "lat_num", "lon_num", "diagnostic", "diagnostic_family"), drop = FALSE]
        if (nrow(out) == 0L) {
            return(empty)
        }

        has_point <- !is.na(out$lat_num) & !is.na(out$lon_num)
        out <- out[has_point, , drop = FALSE]
        if (nrow(out) == 0L) {
            return(empty)
        }

        color_map <- c(
            ok = "#00A86B",
            validity = "#C0392B",
            sea = "#252659",
            zero_equal = "#FFA204",
            reference = "#8b5cf6",
            corrected = "#0e7c86"
        )
        color_vec <- unname(color_map[out$diagnostic_family])
        color_vec[is.na(color_vec)] <- "#C0392B"

        label_map <- c(
            ok = "OK",
            validity_missing = "Missing coordinates",
            validity_bounds = "Out of bounds",
            swapped = "Possible swap",
            sea = "Sea",
            zero_equal = "Zero/Equal",
            identical_all = "Identical coordinates",
            reference = "Reference hotspot",
            corrected = "Corrected"
        )
        if (!is.null(issue_labels) && length(issue_labels) > 0L) {
            label_names <- names(issue_labels)
            if (!is.null(label_names) && any(nzchar(label_names))) {
                match_idx <- label_names %in% names(label_map)
                label_map[label_names[match_idx]] <- as.character(issue_labels[match_idx])
            }
        }
        diag_label <- unname(label_map[out$diagnostic])
        diag_label[is.na(diag_label)] <- out$diagnostic

        badge_class <- ifelse(
            out$diagnostic_family == "ok",
            "coord-issue-badge-ok",
            ifelse(
                out$diagnostic_family == "corrected",
                "coord-issue-badge-corrected",
                ifelse(
                    out$diagnostic_family == "validity",
                    "coord-issue-badge-error",
                    "coord-issue-badge-warning"
                )
            )
        )

        lat_text <- format(round(out$lat_num, 6), nsmall = 0L, trim = TRUE)
        lon_text <- format(round(out$lon_num, 6), nsmall = 0L, trim = TRUE)
        popup_html <- paste0(
            "<b>", popup_defaults$row, ":</b> ", out$.row_index,
            "<br><b>", popup_defaults$lat, ":</b> ", lat_text,
            " <b>", popup_defaults$lon, ":</b> ", lon_text,
            "<br><b>", popup_defaults$issue, ":</b> ",
            "<span class=\"coord-issue-badge ", badge_class, "\">", diag_label, "</span>"
        )

        return(data.frame(
            .row_index = out$.row_index,
            lat_num = out$lat_num,
            lon_num = out$lon_num,
            issue_type = out$diagnostic,
            diagnostic = out$diagnostic,
            diagnostic_family = out$diagnostic_family,
            color = color_vec,
            popup_html = popup_html,
            stringsAsFactors = FALSE
        ))
    }

    required_cols <- c(".row_index", "lat_num", "lon_num", "issue_type")
    if (!all(required_cols %in% names(coords_result_df))) {
        return(empty)
    }

    filter_key <- as.character(if (is.null(filter)) "all" else filter)
    allowed_filters <- c("all", "problems", "missing", "lat_range", "lon_range", "zero_zero", "swapped")
    if (!(filter_key %in% allowed_filters)) {
        filter_key <- "all"
    }

    issue_type <- as.character(coords_result_df$issue_type)
    issue_type[is.na(issue_type) | !nzchar(issue_type)] <- "missing"

    keep_idx <- switch(filter_key,
        all = rep(TRUE, nrow(coords_result_df)),
        problems = issue_type != "ok",
        missing = issue_type == "missing",
        lat_range = issue_type == "lat_range",
        lon_range = issue_type == "lon_range",
        zero_zero = issue_type == "zero_zero",
        swapped = issue_type == "swapped",
        rep(TRUE, nrow(coords_result_df))
    )

    out <- coords_result_df[keep_idx, c(".row_index", "lat_num", "lon_num", "issue_type"), drop = FALSE]
    if (nrow(out) == 0L) {
        return(empty)
    }

    has_point <- !is.na(out$lat_num) & !is.na(out$lon_num)
    out <- out[has_point, , drop = FALSE]
    if (nrow(out) == 0L) {
        return(empty)
    }

    color_map <- c(
        ok = "#00A86B",
        missing = "rgba(28,28,38,0.35)",
        lat_range = "#C0392B",
        lon_range = "#C0392B",
        zero_zero = "#FFA204",
        swapped = "#8b5cf6",
        identical_all = "#FFE005"
    )
    label_map <- c(
        ok = "ok",
        missing = "missing",
        lat_range = "lat out of range",
        lon_range = "lon out of range",
        zero_zero = "zero-zero",
        swapped = "possible swap",
        identical_all = "identical coordinates"
    )
    if (!is.null(issue_labels) && length(issue_labels) > 0L) {
        label_names <- names(issue_labels)
        if (!is.null(label_names) && any(nzchar(label_names))) {
            match_idx <- label_names %in% names(label_map)
            label_map[label_names[match_idx]] <- as.character(issue_labels[match_idx])
        }
    }

    issue_chr <- as.character(out$issue_type)
    issue_chr[is.na(issue_chr) | !nzchar(issue_chr)] <- "missing"
    color_vec <- unname(color_map[issue_chr])
    color_vec[is.na(color_vec)] <- color_map[["missing"]]
    issue_label <- unname(label_map[issue_chr])
    issue_label[is.na(issue_label)] <- label_map[["missing"]]

    lat_text <- format(round(out$lat_num, 6), nsmall = 0L, trim = TRUE)
    lon_text <- format(round(out$lon_num, 6), nsmall = 0L, trim = TRUE)
    badge_class <- ifelse(
        issue_chr %in% c("lat_range", "lon_range"),
        "coord-issue-badge-error",
        ifelse(
            issue_chr %in% c("zero_zero", "swapped", "identical_all"),
            "coord-issue-badge-warning",
            ifelse(issue_chr == "ok", "coord-issue-badge-ok", "coord-issue-badge-missing")
        )
    )

    popup_html <- paste0(
        "<b>", popup_defaults$row, ":</b> ", out$.row_index,
        "<br><b>", popup_defaults$lat, ":</b> ", lat_text,
        " <b>", popup_defaults$lon, ":</b> ", lon_text,
        "<br><b>", popup_defaults$issue, ":</b> ",
        "<span class=\"coord-issue-badge ", badge_class, "\">", issue_label, "</span>"
    )

    data.frame(
        .row_index = out$.row_index,
        lat_num = out$lat_num,
        lon_num = out$lon_num,
        issue_type = issue_chr,
        diagnostic = issue_chr,
        diagnostic_family = ifelse(issue_chr == "ok", "ok", "validity"),
        color = color_vec,
        popup_html = popup_html,
        stringsAsFactors = FALSE
    )
}
