# Cache scope: public provider data shared by sessions in this R process.
# Successful matches and confirmed not-found answers are memoized until reset.
# Unanswered requests are excluded from the memo and can be retried.
# Title: Name matching against COL XR through the GBIF API
# Author: Rogerio Nunes Oliveira
# Date: 2026-10-22
# Version: 1.0
#
# GBIF uses the Catalogue of Life eXtended Release (COL XR) as its default
# taxonomy. Saira matches names against it with the keyless v2 match API, so no
# taxonomic database is downloaded (ADR-167). The memo lives only for the R
# session: a stale status on disk would export wrong.

COLXR_CHECKLIST_KEY <- "7ddf754f-d193-4cc9-b351-99906754a03b"

# Session memo: one parsed row per query name, the names COL XR did not find
# included, so a name is queried at most once.
colxr_match_cache <- create_rds_cache("colxr_match")

colxr_match_request <- function(name) {
    list(
        segments = c("species", "match"),
        # strict = true keeps the exact-name contract of the old taxadb lookup:
        # a misspelling gives no match, not a fuzzy guess.
        query = list(scientificName = name, checklistKey = COLXR_CHECKLIST_KEY, strict = "true")
    )
}

colxr_text <- function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(as.character(value))) {
        return(NA_character_)
    }
    as.character(value)
}

colxr_rank_name <- function(body, rank) {
    for (entry in body$classification) {
        if (identical(entry$rank, rank)) {
            return(colxr_text(entry$name))
        }
    }
    NA_character_
}

colxr_iucn_code <- function(body) {
    for (entry in body$additionalStatus) {
        if (identical(entry$datasetAlias, "IUCN")) {
            return(colxr_text(entry$statusCode))
        }
    }
    NA_character_
}

colxr_validation_status <- function(body) {
    diagnostics <- body$diagnostics
    match_type <- colxr_text(diagnostics$matchType)
    if (match_type %in% c("EXACT", "VARIANT") && is.list(body$usage)) {
        status <- colxr_text(body$usage$status)
        if (status %in% c("ACCEPTED", "PROVISIONALLY_ACCEPTED")) {
            return("accepted")
        }
        if (status %in% c("SYNONYM", "MISAPPLIED")) {
            return("synonym")
        }
        # AMBIGUOUS_SYNONYM, DOUBTFUL and other states have no single answer.
        return("ambiguous")
    }
    # A homonym ("Oenanthe" is a bird and a plant) gives no usage.
    if ("MULTIPLE_MATCHES_SAME_CONFIDENCE" %in% unlist(diagnostics$processingFlags)) {
        return("ambiguous")
    }
    "not_found"
}

#' Parse COL XR match responses into the names report schema
#'
#' @param bodies List of parsed v2 match bodies.
#' @param query_names Query name of each body.
#' @return Data frame with one row per body.
#' @noRd
parse_colxr_matches <- function(bodies, query_names) {
    field <- function(fn) vapply(bodies, fn, character(1))
    usage <- function(name) field(function(b) colxr_text(b$usage[[name]]))
    accepted <- function(name) field(function(b) colxr_text(b$acceptedUsage[[name]]))
    rank_name <- function(rank) field(function(b) colxr_rank_name(b, rank))

    status <- field(colxr_validation_status)
    found <- status %in% c("accepted", "synonym")
    out <- data.frame(
        query_name = as.character(query_names),
        taxonID = usage("key"),
        scientificName = as.character(ifelse(found, usage("canonicalName"), query_names)),
        taxonRank = tolower(usage("rank")),
        acceptedNameUsageID = accepted("key"),
        acceptedNameUsage = accepted("canonicalName"),
        taxonomicStatus = tolower(gsub("_", " ", usage("status"), fixed = TRUE)),
        kingdom = rank_name("KINGDOM"),
        phylum = rank_name("PHYLUM"),
        class = rank_name("CLASS"),
        order = rank_name("ORDER"),
        family = rank_name("FAMILY"),
        genus = rank_name("GENUS"),
        specificEpithet = usage("specificEpithet"),
        infraspecificEpithet = usage("infraspecificEpithet"),
        iucnRedListCategory = field(colxr_iucn_code),
        provider = rep("gbif", length(query_names)),
        validation_status = status,
        match_count = as.integer(ifelse(found, 1L, NA_integer_)),
        stringsAsFactors = FALSE
    )
    # As with the old taxadb rows, an ambiguous or missing name keeps only the
    # query name: a doubtful usage must not fill the classification.
    kept <- c("query_name", "scientificName", "provider", "validation_status", "match_count")
    out[!found, setdiff(names(out), kept)] <- NA_character_
    rownames(out) <- NULL
    out
}

#' Match scientific names against COL XR
#'
#' Sends one GBIF v2 match request per new name, in parallel, and memoizes
#' every answer for the session.
#'
#' @param names Character vector of scientific names.
#' @return Data frame from `parse_colxr_matches()`, one row per answered
#'   name, `validation_status = "not_found"` included. The attribute
#'   `unanswered` lists the names GBIF did not answer (network or HTTP error).
#' @noRd
colxr_match_names <- function(names) {
    names <- unique(as.character(names))
    names <- names[!is.na(names) & nzchar(trimws(names))]
    memo <- colxr_match_cache$get()
    if (is.null(memo)) {
        memo <- parse_colxr_matches(list(), character(0))
    }

    misses <- setdiff(names, memo$query_name)
    unanswered <- character(0)
    if (length(misses) > 0L) {
        bodies <- gbif_api_get_many(lapply(misses, colxr_match_request))
        answered <- !vapply(bodies, is.null, logical(1))
        unanswered <- misses[!answered]
        if (any(answered)) {
            memo <- rbind(memo, parse_colxr_matches(bodies[answered], misses[answered]))
            colxr_match_cache$set(memo)
        }
    }

    out <- memo[memo$query_name %in% names, , drop = FALSE]
    out <- out[order(match(out$query_name, names)), , drop = FALSE]
    rownames(out) <- NULL
    attr(out, "unanswered") <- unanswered
    out
}
