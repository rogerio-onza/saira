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

# The feature is opt-in through Suggests: absent httr2 disables every call.
has_httr2 <- function() requireNamespace("httr2", quietly = TRUE)

# GET against the GBIF API; returns parsed JSON (a list) or NULL on any failure.
# Centralizes the httr2 guard, timeout and full error trapping so callers only
# deal with "got a body or did not".
gbif_api_get <- function(segments, query = NULL) {
    if (!has_httr2()) {
        return(NULL)
    }
    tryCatch(
        {
            req <- httr2::request(GBIF_API_BASE)
            req <- do.call(
                httr2::req_url_path_append, c(list(req), as.list(segments))
            )
            if (length(query) > 0L) {
                req <- do.call(httr2::req_url_query, c(list(req), query))
            }
            req <- httr2::req_timeout(req, GBIF_API_TIMEOUT_S)
            req <- httr2::req_user_agent(req, "saira R package")
            # Treat any non-2xx as "no data" rather than an error to catch.
            req <- httr2::req_error(req, is_error = function(resp) FALSE)
            resp <- httr2::req_perform(req)
            if (httr2::resp_status(resp) != 200L) {
                return(NULL)
            }
            httr2::resp_body_json(resp)
        },
        error = function(e) NULL
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
    for (k in misses) {
        body <- gbif_api_get(c("species", k, "iucnRedListCategory"))
        memo[[k]] <- gbif_body_field(body, "code")
    }
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
    for (q in misses) {
        body <- gbif_api_get(c("species", "match"), query = list(name = q))
        memo[[q]] <- gbif_body_field(body, "usageKey")
    }
    if (length(misses) > 0L) {
        gbif_match_cache$set(memo)
    }
    out[valid] <- unname(memo[nm[valid]])
    out
}
