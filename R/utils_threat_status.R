# Title: Conservation status lookups (GBIF IUCN Red List category)
# Author: Rogerio Nunes Oliveira
#
# HTTP helpers for the keyless GBIF API, and the global IUCN Red List category
# that the export writes to dynamicProperties. Every path degrades to NA: a
# machine offline, an HTTP error or an unexpected payload must never break or
# stall the export bundle. The COL XR match memo (utils_colxr.R) keeps each
# name to one request per session.

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
