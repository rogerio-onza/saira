# Title: Conservation status lookups (GBIF IUCN Red List category)
# Author: Rogerio Nunes Oliveira
#
# HTTP helpers for the keyless GBIF API, and the global IUCN Red List category
# that the export writes to dynamicProperties. Every path degrades to NA: a
# machine offline, an HTTP error or an unexpected payload must never break or
# stall the export bundle. The COL XR match memo (utils_colxr.R) keeps each
# name to one request per R process.
#
# Cache scope: public provider data shared by sessions in this R process.
# Category lookups retain the existing memo/reset policy; network failures
# remain non-blocking.

GBIF_API_BASE <- "https://api.gbif.org/v2"
GBIF_API_TIMEOUT_S <- 10
# One request at a time made the export wait ~0.3 s per taxon, several minutes
# for a few hundred species (ADR-126).
GBIF_API_MAX_ACTIVE <- 10L

# One GET request against the GBIF API. A 429 or 503 is retried, so a rate
# limit under parallel load does not turn a real category into NA. Keep the
# default req_error(): req_perform_parallel() retries only a response it
# classifies as an error.
gbif_request <- function(segments, query = NULL) {
    req <- httr2::request(GBIF_API_BASE)
    req <- do.call(httr2::req_url_path_append, c(list(req), as.list(segments)))
    if (length(query) > 0L) {
        req <- do.call(httr2::req_url_query, c(list(req), query))
    }
    req |>
        httr2::req_timeout(GBIF_API_TIMEOUT_S) |>
        httr2::req_user_agent("saira R package") |>
        httr2::req_retry(max_tries = 3L)
}

# Parsed JSON of a 200 response, or NULL for anything else (an HTTP error
# arrives here as a condition object, because on_error = "continue").
gbif_response_body <- function(resp) {
    if (!inherits(resp, "httr2_response") || httr2::resp_status(resp) != 200L) {
        return(NULL)
    }
    tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)
}

# Parallel GETs against the GBIF API. `requests` is a list of
# list(segments, query). Returns one parsed body per request, NULL on any
# failure, so callers only deal with "got a body or did not".
gbif_api_get_many <- function(requests) {
    empty <- vector("list", length(requests))
    if (length(requests) == 0L) {
        return(empty)
    }
    tryCatch(
        {
            reqs <- lapply(requests, function(r) gbif_request(r$segments, r$query))
            resps <- httr2::req_perform_parallel(
                reqs,
                on_error = "continue",
                progress = FALSE,
                max_active = GBIF_API_MAX_ACTIVE
            )
            lapply(resps, gbif_response_body)
        },
        error = function(e) empty
    )
}

#' IUCN Red List category of scientific names, from COL XR
#'
#' The COL XR match carries the global IUCN category of the name. A synonym
#' has no category of its own, so it takes the category of its accepted name.
#' Names GBIF did not answer, and names without an assessment, give NA.
#'
#' @param names Character vector of scientific names (NA allowed).
#' @return Character vector of IUCN codes ("NT", "EN", ...), same length.
#' @keywords internal
#' @noRd
colxr_iucn_category <- function(names) {
    nm <- as.character(names)
    out <- rep(NA_character_, length(nm))
    valid <- !is.na(nm) & nzchar(trimws(nm))
    if (!any(valid)) {
        return(out)
    }
    matches <- colxr_match_names(nm[valid])
    code <- stats::setNames(matches$iucnRedListCategory, matches$query_name)
    syn <- matches$validation_status %in% "synonym" & is.na(code) &
        !is.na(matches$acceptedNameUsage)
    if (any(syn)) {
        accepted <- matches$acceptedNameUsage[syn]
        found <- colxr_match_names(accepted)
        code[syn] <- found$iucnRedListCategory[match(accepted, found$query_name)]
    }
    out[valid] <- unname(code[nm[valid]])
    out
}

# Rows whose country resolves to Brazil. The MMA portaria is a *national* legal
# instrument, so its status must never be asserted for a record collected
# elsewhere -- picking a BR name provider is a taxonomic-source preference, not
# a statement about locality. `countryCode` wins when present (Saira keeps it in
# alpha-3 until convert_country_code_to_alpha2() runs at the export boundary,
# but a publisher may supply alpha-2); otherwise the free-text `country` goes
# through the same 5-layer cascade the coordinate tab uses (ADR-036), which
# resolves multilingual spellings and dedupes internally. A row with no
# resolvable country is NOT Brazilian: an unknown locality is not evidence of
# Brazilian occurrence.
is_brazilian_record <- function(df) {
    n <- if (is.data.frame(df)) nrow(df) else 0L
    if (n == 0L) {
        return(logical(0))
    }
    iso <- rep(NA_character_, n)
    for (col in c("countryCode", "country")) {
        pending <- is.na(iso)
        if (!any(pending) || !(col %in% names(df))) {
            next
        }
        values <- as.character(df[[col]])[pending]
        iso[pending] <- tryCatch(
            coords_country_to_iso3(values),
            error = function(e) rep(NA_character_, length(values))
        )
    }
    !is.na(iso) & iso == "BRA"
}

#' Append conservation-status entries to dynamicProperties on export
#'
#' Additively folds each selected provider's conservation status into the
#' `dynamicProperties` column (creating it when absent): the Brazilian MMA
#' category plus its portaria source when a BR provider was selected, and/or the
#' global IUCN Red List code from GBIF when GBIF was selected. The two sources
#' are independent — a taxon can receive both, or only the MMA keys when GBIF
#' does not assess it. The MMA list is national, so its keys go only to records
#' that resolve to Brazil (see [is_brazilian_record()]); the IUCN assessment is
#' global and is applied regardless of locality. The GBIF lookup is optional and
#' non-blocking: any failure simply omits the IUCN key and never breaks the
#' export. Runs after [apply_name_review_payload()] so it sees the corrected
#' `scientificName`, and after the country fill so coordinate-derived countries
#' are already in place.
#'
#' @param df Data frame to export (post name review).
#' @param payload Optional list with `include_mma` and `include_iucn` (logical).
#' @param generalized Optional logical vector, one per row: TRUE where
#'   `mask_sensitive_coordinates()` protected the row.
#' @return `df` with an updated `dynamicProperties` column.
#' @keywords internal
#' @noRd
apply_conservation_status <- function(df, payload = NULL, generalized = NULL) {
    if (!is.data.frame(df) || nrow(df) == 0L ||
        !("scientificName" %in% names(df)) ||
        is.null(payload) || !is.list(payload)) {
        return(df)
    }
    include_mma <- isTRUE(payload$include_mma)
    include_iucn <- isTRUE(payload$include_iucn)
    if (!include_mma && !include_iucn) {
        return(df)
    }

    names_vec <- as.character(df$scientificName)
    had_column <- "dynamicProperties" %in% names(df)
    dynprops <- df[["dynamicProperties"]]
    if (is.null(dynprops)) {
        dynprops <- rep("", nrow(df))
    }

    # Each source is wrapped independently so a failure in one (e.g. the GBIF
    # network) never blocks the export nor drops the other source's keys.
    if (include_mma) {
        dynprops <- tryCatch(
            {
                # National list: blank the keys outside Brazil so
                # merge_dynamic_property() leaves those rows untouched.
                br <- is_brazilian_record(df)
                # A row Saira generalized cites its MMA category in
                # dataGeneralizations, so dynamicProperties carries it too (B12).
                if (length(generalized) == length(br)) br <- br | generalized
                mma_category <- sensitive_category_for(names_vec)
                mma_category[!br] <- NA_character_
                mma_source <- sensitive_source_for(names_vec)
                mma_source[!br] <- NA_character_
                dp <- merge_dynamic_property(
                    dynprops, "mmaThreatStatus", mma_category
                )
                merge_dynamic_property(dp, "mmaSource", mma_source)
            },
            error = function(e) {
                warning("apply_conservation_status: MMA skipped (", conditionMessage(e), ")")
                dynprops
            }
        )
    }

    if (include_iucn) {
        dynprops <- tryCatch(
            {
                merge_dynamic_property(
                    dynprops, "iucnRedListCategory",
                    colxr_iucn_category(names_vec)
                )
            },
            error = function(e) {
                warning("apply_conservation_status: IUCN skipped (", conditionMessage(e), ")")
                dynprops
            }
        )
    }

    # Keep an already-mapped column even if nothing merged; but do not create a
    # spurious all-empty column when no taxon matched and none was mapped.
    if (had_column || any(nzchar(dynprops))) {
        df[["dynamicProperties"]] <- dynprops
    }
    df
}
