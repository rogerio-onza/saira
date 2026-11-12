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
        httr2::req_retry(max_tries = GBIF_API_MAX_TRIES, is_transient = gbif_transient_counter())
}

GBIF_API_MAX_TRIES <- 3L

# req_perform_parallel() of httr2 1.3.0 does not read max_tries: it retries a
# 429 or 503 until the API answers otherwise. So each request counts its own
# tries, and its last answer counts as final.
gbif_transient_counter <- function(max_tries = GBIF_API_MAX_TRIES) {
    count <- new.env(parent = emptyenv())
    count$tries <- 0L
    function(resp) {
        count$tries <- count$tries + 1L
        count$tries < max_tries && httr2::resp_status(resp) %in% c(429L, 503L)
    }
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

# A fetch that sends nothing: every request stays unanswered. The names run
# uses it after the worker stored its answers, so a name GBIF did not answer
# gets no second, blocking request.
gbif_offline_fetch <- function(requests) vector("list", length(requests))

#' IUCN Red List category of scientific names, from COL XR
#'
#' The COL XR match carries the global IUCN category of the name. A synonym
#' has no category of its own, so it takes the category of its accepted name.
#' Names GBIF did not answer, and names without an assessment, give NA.
#'
#' @param names Character vector of scientific names (NA allowed).
#' @param fetch Fetch for the names the memo does not have, as in
#'   `colxr_match_names()`. The export passes `gbif_offline_fetch`.
#' @return Character vector of IUCN codes ("NT", "EN", ...), same length.
#' @keywords internal
#' @noRd
colxr_iucn_category <- function(names, fetch = gbif_api_get_many) {
    nm <- as.character(names)
    out <- rep(NA_character_, length(nm))
    valid <- !is.na(nm) & nzchar(trimws(nm))
    if (!any(valid)) {
        return(out)
    }
    matches <- colxr_match_names(nm[valid], fetch = fetch)
    code <- stats::setNames(matches$iucnRedListCategory, matches$query_name)
    syn <- matches$validation_status %in% "synonym" & is.na(code) &
        !is.na(matches$acceptedNameUsage)
    if (any(syn)) {
        accepted <- matches$acceptedNameUsage[syn]
        found <- colxr_match_names(accepted, fetch = fetch)
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
#' global and is applied regardless of locality. The IUCN codes come from
#' `payload$iucn_by_name`, which the Export tab looks up before the download,
#' so this step sends no request. Runs after [apply_name_review_payload()] so it sees the corrected
#' `scientificName`, and after the country fill so coordinate-derived countries
#' are already in place.
#'
#' @param df Data frame to export (post name review).
#' @param payload Optional list with `include_mma` and `include_iucn` (logical),
#'   and `iucn_by_name`: IUCN code by scientific name, NA without a code. A
#'   NULL `iucn_by_name` adds no IUCN key.
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

    # The download sends no GBIF request: a slow GBIF held the session for
    # the whole file. A name outside the snapshot gets no IUCN key.
    iucn_by_name <- payload$iucn_by_name
    if (include_iucn && length(iucn_by_name) > 0L) {
        dynprops <- merge_dynamic_property(
            dynprops, "iucnRedListCategory", unname(iucn_by_name[names_vec])
        )
    }

    # Keep an already-mapped column even if nothing merged; but do not create a
    # spurious all-empty column when no taxon matched and none was mapped.
    if (had_column || any(nzchar(dynprops))) {
        df[["dynamicProperties"]] <- dynprops
    }
    df
}

# The IUCN lookup of the Export tab (ADR-213). It runs before the download and
# sends its requests through the names worker, so the download sends none and
# a slow GBIF never holds the session. The memo of a Names run answers first.
IUCN_LOOKUP_BATCH <- 20L

iucn_lookup_new <- function(names, run_id) {
    names <- colxr_clean_names(names)
    list(run_id = run_id, names = names, phase = "match", targets = names,
         tried = character(0), batches = 0L, snapshot = NULL, unanswered = character(0))
}

# One tick of the lookup. `fetch_for(misses)` gives NULL while a batch is in
# flight, else the fetch for the misses, as names_worker_fetch() does. A name
# without an answer goes out once per run, so the run always ends. Phases:
# "match" for the names, "accepted" for the accepted names of the synonyms
# without a category, then "done" with the snapshot.
iucn_lookup_step <- function(state, fetch_for, batch_size = IUCN_LOOKUP_BATCH) {
    if (identical(state$phase, "done")) {
        return(state)
    }
    todo <- setdiff(colxr_unmemoized(state$targets), state$tried)
    if (length(todo) > 0L) {
        batch <- utils::head(todo, batch_size)
        fetch <- fetch_for(batch)
        if (is.null(fetch)) {
            return(state)
        }
        # An answer the parser cannot read leaves the batch unanswered.
        unanswered <- tryCatch(attr(colxr_match_names(batch, fetch = fetch), "unanswered"),
                               error = function(e) batch)
        state$tried <- c(state$tried, unanswered)
        # The count in the download bar moves with each batch.
        state$batches <- state$batches + 1L
        return(state)
    }
    if (identical(state$phase, "match")) {
        state$phase <- "accepted"
        state$targets <- iucn_lookup_accepted(state$names)
        return(state)
    }
    iucn_lookup_finish(state)
}

# The accepted names of the synonyms that have no category of their own.
iucn_lookup_accepted <- function(names) {
    matches <- colxr_match_names(names, fetch = gbif_offline_fetch)
    syn <- matches$validation_status %in% "synonym" &
        is.na(matches$iucnRedListCategory) & !is.na(matches$acceptedNameUsage)
    colxr_clean_names(matches$acceptedNameUsage[syn])
}

# The snapshot from the answers in the memo. The lookup calls this at its end,
# and a skip calls it at any phase, so the answers that came stay in the file.
iucn_lookup_finish <- function(state) {
    matches <- colxr_match_names(state$names, fetch = gbif_offline_fetch)
    syn <- matches$validation_status %in% "synonym" &
        is.na(matches$iucnRedListCategory) & !is.na(matches$acceptedNameUsage)
    accepted <- matches$acceptedNameUsage[syn]
    state$snapshot <- stats::setNames(
        colxr_iucn_category(state$names, fetch = gbif_offline_fetch), state$names
    )
    # A synonym whose accepted name GBIF did not answer has no category yet.
    state$unanswered <- union(colxr_unmemoized(state$names),
                              matches$query_name[syn][accepted %in% colxr_unmemoized(accepted)])
    state$phase <- "done"
    state
}

# Names with an answer, for the count in the download bar.
iucn_lookup_progress <- function(state) {
    total <- length(state$names)
    if (!identical(state$phase, "match")) {
        return(list(done = total, total = total))
    }
    left <- setdiff(colxr_unmemoized(state$names), state$tried)
    list(done = total - length(left), total = total)
}

# Names of the lookup that have a GBIF answer in the memo. A count that does
# not move tells that GBIF does not answer, also while the batch waits.
iucn_lookup_answered <- function(state) {
    asked <- union(state$names, state$targets)
    length(asked) - length(colxr_unmemoized(asked))
}
