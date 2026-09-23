# Title: Conservation status lookups (GBIF IUCN Red List category)
# Author: Rogerio Nunes Oliveira
#
# Optional, non-blocking helpers that read a taxon's global IUCN Red List
# category from GBIF's keyless species API, used on export to populate the
# iucnRedListCategory entry of dynamicProperties. Every path degrades to NA:
# httr2 absent (it is a Suggests-only dependency), machine offline, an HTTP
# error or an unexpected payload must never break or stall the export bundle.
# Results are memoized per session so the same taxon is queried at most once.

# Session memo: usageKey -> IUCN code (e.g. "NT"). An NA answer is stored too so
# a taxon GBIF does not assess is not re-queried.
gbif_iucn_cache <- create_rds_cache("gbif_iucn")
# Session memo: scientific name -> GBIF usageKey, for the match fallback.
gbif_match_cache <- create_rds_cache("gbif_match")

GBIF_API_BASE <- "https://api.gbif.org/v1"
GBIF_API_TIMEOUT_S <- 10
# One request at a time made the export wait ~0.3 s per taxon, several minutes
# for a few hundred species (ADR-126).
GBIF_API_MAX_ACTIVE <- 10L

# The feature is opt-in through Suggests: absent httr2 disables every call.
has_httr2 <- function() requireNamespace("httr2", quietly = TRUE)

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
    if (length(requests) == 0L || !has_httr2()) {
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

# Read a single scalar string field from a parsed GBIF body, or NA.
gbif_body_field <- function(body, field) {
    if (!is.list(body)) {
        return(NA_character_)
    }
    value <- body[[field]]
    if (length(value) != 1L) {
        return(NA_character_)
    }
    value <- as.character(value)
    if (is.na(value) || !nzchar(value)) NA_character_ else value
}

#' IUCN Red List category code for GBIF usage keys
#'
#' For each GBIF usageKey, reads the global IUCN Red List category from
#' `GET /species/{key}/iucnRedListCategory` and returns its short `code`
#' (e.g. "NT", "VU", "EN"). Missing keys, taxa GBIF does not assess, an absent
#' httr2, an offline machine or any API error all yield NA. Memoized per session.
#'
#' @param usage_keys Character/numeric vector of GBIF usage keys (NA allowed).
#' @return Character vector of IUCN codes (NA where unavailable), same length.
#' @keywords internal
#' @noRd
fetch_gbif_iucn_category <- function(usage_keys) {
    n <- length(usage_keys)
    if (n == 0L) {
        return(character(0))
    }
    keys <- as.character(usage_keys)
    out <- rep(NA_character_, n)
    valid <- !is.na(keys) & nzchar(keys)
    if (!any(valid) || !has_httr2()) {
        return(out)
    }
    memo <- gbif_iucn_cache$get()
    if (is.null(memo)) {
        memo <- character(0)
    }
    misses <- setdiff(unique(keys[valid]), names(memo))
    bodies <- gbif_api_get_many(lapply(misses, function(k) {
        list(segments = c("species", k, "iucnRedListCategory"))
    }))
    memo[misses] <- vapply(bodies, gbif_body_field, character(1), field = "code")
    if (length(misses) > 0L) {
        gbif_iucn_cache$set(memo)
    }
    out[valid] <- unname(memo[keys[valid]])
    out
}

#' Resolve scientific names to GBIF usage keys (match fallback)
#'
#' Used only for names that lack a GBIF-resolved `taxonID` (e.g. rows a Brazilian
#' provider matched, or manual renames). Calls the keyless
#' `GET /species/match?name=` endpoint and returns the `usageKey`. Same graceful
#' degradation and per-session memoization as [fetch_gbif_iucn_category()].
#'
#' @param names Character vector of scientific names (NA allowed).
#' @return Character vector of GBIF usage keys (NA where unmatched), same length.
#' @keywords internal
#' @noRd
gbif_match_usage_keys <- function(names) {
    n <- length(names)
    if (n == 0L) {
        return(character(0))
    }
    nm <- as.character(names)
    out <- rep(NA_character_, n)
    valid <- !is.na(nm) & nzchar(trimws(nm))
    if (!any(valid) || !has_httr2()) {
        return(out)
    }
    memo <- gbif_match_cache$get()
    if (is.null(memo)) {
        memo <- character(0)
    }
    misses <- setdiff(unique(nm[valid]), names(memo))
    bodies <- gbif_api_get_many(lapply(misses, function(q) {
        list(segments = c("species", "match"), query = list(name = q))
    }))
    memo[misses] <- vapply(bodies, gbif_body_field, character(1), field = "usageKey")
    if (length(misses) > 0L) {
        gbif_match_cache$set(memo)
    }
    out[valid] <- unname(memo[nm[valid]])
    out
}
