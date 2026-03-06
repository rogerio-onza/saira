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
coord_family_levels <- c("ok", "validity", "sea", "zero_equal", "reference")

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
                        message(
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
#' @param seas_scale Landmass resolution for sea test (10 = highest detail, 50 = medium, 110 = coarse). Default `10` requires `rnaturalearthhires`; falls back to `50` if not installed.
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
    if (seas_scale == 10L && !requireNamespace("rnaturalearthhires", quietly = TRUE)) {
        warning("rnaturalearthhires not installed; falling back to seas_scale = 50.", call. = FALSE)
        seas_scale <- 50L
    }
    for (col_name in c(lat_col, lon_col, country_col)) {
        if (!is.character(col_name) || length(col_name) != 1L || !nzchar(col_name)) {
            stop("lat_col, lon_col and country_col must be non-empty strings.", call. = FALSE)
        }
        if (!col_name %in% names(df)) {
            stop(sprintf("Column not found: %s", col_name), call. = FALSE)
        }
    }

    coords_assert_cc_dependencies()

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

    country_raw <- as.character(df[[country_col]])
    country_raw[is.na(country_raw)] <- ""
    country_raw <- trimws(country_raw)
    country_iso3 <- coords_country_to_iso3(country_raw)

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

            flag_sea <- coords_cc_flagged(
                "cc_sea",
                cc_clean,
                lon = "decimalLongitude",
                lat = "decimalLatitude",
                scale = seas_scale
            )
            sea_flag[rows_clean] <- !flag_sea

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
                reference_flag[rows_clean] <- !(flag_cap & flag_cen & flag_gbif & flag_inst)
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
    out
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
        problems = as.integer(sum(fam_counts[names(fam_counts) != "ok"])),
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
            reference = "#8b5cf6"
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
            reference = "Reference hotspot"
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
                out$diagnostic_family == "validity",
                "coord-issue-badge-error",
                "coord-issue-badge-warning"
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
