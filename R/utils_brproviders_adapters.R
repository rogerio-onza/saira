# Utils brproviders adapters

# ---------------------------------------------------------------------------
# Result normalisation
# ---------------------------------------------------------------------------

#' Normalise a raw florabr/faunabr check_names result to the taxadb schema
#'
#' Key mappings:
#'   input_name       -> query_name
#'   Spelling         -> validation_status  (Correct -> accepted/synonym,
#'                                           Probably_incorrect -> ambiguous,
#'                                           Not_found -> not_found)
#'   "Suggested name" -> scientificName
#'   taxonomicStatus  -> taxonomicStatus    (lowercased)
#'   family           -> family
#'
#' When multiple rows share the same input_name (multiple fuzzy suggestions)
#' only the row with the smallest Distance is kept.
#'
#' @param raw_df Data frame from florabr::check_names or
#'   faunabr::check_fauna_names.
#' @param provider_id Character. "florabr" or "faunabr".
#' @return Data frame compatible with the taxadb common schema.
#' @noRd
normalize_brprovider_result <- function(raw_df, provider_id) {
    empty_out <- data.frame(
        query_name        = character(0),
        scientificName    = character(0),
        taxonomicStatus   = character(0),
        family            = character(0),
        provider          = character(0),
        validation_status = character(0),
        match_count       = integer(0),
        stringsAsFactors  = FALSE
    )

    if (!is.data.frame(raw_df) || nrow(raw_df) == 0L) {
        return(empty_out)
    }

    names(raw_df) <- trimws(names(raw_df))

    # Deduplicate: florabr/faunabr can return multiple suggestion rows per
    # input_name when Spelling == "Probably_incorrect". Keep closest match.
    if ("Distance" %in% names(raw_df) && "input_name" %in% names(raw_df)) {
        dist_num <- suppressWarnings(as.numeric(raw_df[["Distance"]]))
        dist_num[is.na(dist_num)] <- Inf
        raw_df[["Distance"]] <- dist_num
        # A homonym ties at the same distance: Flora BR lists "Victoria
        # amazonica" as accepted and as an illegitimate synonym. The row order
        # changes with the other names of the query, so the tie goes to the
        # row that is not a synonym, not to the first row.
        not_synonym <- !grepl("synonym", tolower(as.character(raw_df[["taxonomicStatus"]] %||% "")), fixed = TRUE)
        split_list <- split(seq_len(nrow(raw_df)), raw_df[["input_name"]])
        keep_rows <- vapply(split_list, function(idxs) {
            if (length(idxs) == 1L) return(idxs[[1L]])
            dist <- raw_df[["Distance"]][idxs]
            closest <- idxs[dist == min(dist)]
            preferred <- closest[not_synonym[closest]]
            if (length(preferred) > 0L) preferred[[1L]] else closest[[1L]]
        }, FUN.VALUE = integer(1))
        raw_df <- raw_df[keep_rows, , drop = FALSE]
        rownames(raw_df) <- NULL
    }

    n <- nrow(raw_df)

    query_name <- if ("input_name" %in% names(raw_df)) {
        as.character(raw_df[["input_name"]])
    } else {
        rep(NA_character_, n)
    }

    spelling <- if ("Spelling" %in% names(raw_df)) {
        as.character(raw_df[["Spelling"]])
    } else {
        rep(NA_character_, n)
    }

    taxa_status_raw <- if ("taxonomicStatus" %in% names(raw_df)) {
        tolower(as.character(raw_df[["taxonomicStatus"]]))
    } else {
        rep(NA_character_, n)
    }

    # Map Spelling + taxonomicStatus -> validation_status
    validation_status <- vapply(seq_len(n), function(i) {
        sp <- spelling[[i]]
        ts <- taxa_status_raw[[i]]
        if (is.na(sp)) return("not_found")
        if (identical(sp, "Correct")) {
            if (!is.na(ts) && grepl("synonym", ts, fixed = TRUE)) {
                return("synonym")
            }
            return("accepted")
        }
        if (identical(sp, "Probably_incorrect")) return("ambiguous")
        "not_found"
    }, FUN.VALUE = character(1))

    # scientificName: prefer "Suggested name" column, fall back to input
    suggested_col <- if ("Suggested name" %in% names(raw_df)) {
        "Suggested name"
    } else {
        NA_character_
    }
    scientific_name <- if (!is.na(suggested_col)) {
        sugg <- as.character(raw_df[[suggested_col]])
        ifelse(is.na(sugg) | !nzchar(sugg), query_name, sugg)
    } else {
        query_name
    }

    family <- if ("family" %in% names(raw_df)) {
        as.character(raw_df[["family"]])
    } else {
        rep(NA_character_, n)
    }

    match_count <- as.integer(validation_status != "not_found")

    out <- data.frame(
        query_name        = query_name,
        scientificName    = scientific_name,
        taxonomicStatus   = taxa_status_raw,
        family            = family,
        provider          = as.character(provider_id),
        validation_status = validation_status,
        match_count       = match_count,
        stringsAsFactors  = FALSE
    )

    # Fill taxadb expected columns absent from the BR schema
    for (col_name in c("taxonID", "taxonRank", "acceptedNameUsageID",
                       "update_date", "kingdom", "phylum", "class",
                       "order", "genus", "specificEpithet",
                       "vernacularName", "infraspecificEpithet")) {
        if (!col_name %in% names(out)) {
            out[[col_name]] <- NA_character_
        }
    }

    rownames(out) <- NULL
    out
}

# ---------------------------------------------------------------------------
# Query
# ---------------------------------------------------------------------------

#' Query a BR provider with a vector of normalised scientific names
#'
#' @param query_names Character vector of normalised names.
#' @param provider_id Character. "florabr" or "faunabr".
#' @param data Pre-loaded provider data frame, or NULL to use cache.
#' @param max_distance Numeric. Levenshtein fraction for fuzzy matching.
#'   Default 0.1.
#' @return Data frame in the taxadb common schema.
#' @noRd
query_brprovider <- function(query_names, provider_id,
                             data = NULL, max_distance = 0.1) {
    names_chr <- unique(as.character(query_names))
    names_chr <- names_chr[!is.na(names_chr) & nzchar(names_chr)]
    if (length(names_chr) == 0L) {
        return(normalize_brprovider_result(data.frame(), provider_id))
    }

    if (is.null(data)) {
        data <- brprovider_load_data(provider_id)
    }
    if (is.null(data) || !is.data.frame(data) || nrow(data) == 0L) {
        stop(sprintf(
            "No data available for provider '%s'. Download required.",
            provider_id
        ))
    }

    raw <- tryCatch({
        if (identical(provider_id, "florabr")) {
            if (!requireNamespace("florabr", quietly = TRUE)) {
                stop("Package 'florabr' is not installed.")
            }
            florabr::check_names(
                data             = data,
                species          = names_chr,
                max_distance     = max_distance,
                include_subspecies = TRUE,
                include_variety  = FALSE,
                parallel         = FALSE,
                progress_bar     = FALSE
            )
        } else if (identical(provider_id, "faunabr")) {
            if (!requireNamespace("faunabr", quietly = TRUE)) {
                stop("Package 'faunabr' is not installed.")
            }
            faunabr::check_fauna_names(
                data               = data,
                species            = names_chr,
                max_distance       = max_distance,
                include_subspecies = TRUE
            )
        } else {
            stop(sprintf("Unknown BR provider: %s", provider_id))
        }
    }, error = function(e) e)

    if (inherits(raw, "error")) {
        stop(sprintf("BR provider '%s' query failed: %s", provider_id, raw$message))
    }

    normalize_brprovider_result(
        as.data.frame(raw, stringsAsFactors = FALSE),
        provider_id
    ) |>
        brprovider_keep_queried(names_chr)
}

# Rows that answer one of the queried names. faunabr answers a trinomial it
# does not hold with the binomial in input_name ("Canis lupus familiaris" ->
# "Canis lupus"). That row named a taxon the user did not type, so the names
# list showed one name more than the report (B43). The trinomial stays
# pending and goes to GBIF.
brprovider_keep_queried <- function(result_df, query_names) {
    if (!is.data.frame(result_df) || nrow(result_df) == 0L) {
        return(result_df)
    }
    idx <- match(tolower(result_df$query_name), tolower(query_names))
    result_df$query_name <- query_names[idx]
    out <- result_df[!is.na(idx), , drop = FALSE]
    rownames(out) <- NULL
    out
}
