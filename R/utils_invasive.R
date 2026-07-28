# Title: Invasive alien species lookup
# Author: Rogerio Nunes Oliveira
#
# Pure helpers for the invasive-species flag shown in name validation. No
# Shiny, no reactives. A bundled list of alien invasive species recorded for
# Brazil (inst/extdata/invasive_species.rds, built from
# data-raw/generate_invasive_species.R over the Instituto Horus 2023 list) is
# matched against the validator's resolved scientificName.
#
# Being on this list says the taxon is alien and invasive in Brazil, which
# supports dwc:establishmentMeans = "introduced". It says nothing about
# dwc:degreeOfEstablishment: whether an individual is captive, released or
# invasive is a property of the record, not of the species.
#
# Mirrors R/utils_sensitive.R (the MMA threatened list): same cache factory
# (ADR-014), same three-candidate path resolution, same graceful degradation,
# and the same two-step match key.

invasive_species_cache <- create_rds_cache("invasive_species")

# Resolve the bundled RDS path. Returns NA_character_ (not an error) when
# absent so the flag degrades to "nothing is invasive" instead of breaking
# validation.
resolve_invasive_species_path <- function() {
    candidates <- c(
        system.file("extdata", "invasive_species.rds", package = "saira"),
        file.path("inst", "extdata", "invasive_species.rds"),
        file.path("..", "..", "inst", "extdata", "invasive_species.rds")
    )
    candidates <- unique(candidates[nzchar(candidates)])
    path <- candidates[file.exists(candidates)][1]
    if (is.null(path) || is.na(path) || !file.exists(path)) {
        return(NA_character_)
    }
    path
}

invasive_species_empty <- function() {
    data.frame(
        scientificName = character(0),
        match_key = character(0),
        kingdom = character(0),
        vernacularName = character(0),
        introduction_reason = character(0),
        source = character(0),
        stringsAsFactors = FALSE
    )
}

# Cached read of the invasive-species lookup. Missing/invalid file -> a warning
# plus a zero-row frame (nothing is flagged). The not-found case is not cached,
# so a later regenerate is picked up without force.
load_invasive_species <- function(force = FALSE) {
    if (!isTRUE(force) && !is.null(invasive_species_cache$get())) {
        return(invasive_species_cache$get())
    }
    path <- resolve_invasive_species_path()
    if (is.na(path)) {
        warning("invasive_species.rds not found; invasive flag disabled.")
        return(invasive_species_empty())
    }
    df <- tryCatch(readRDS(path), error = function(e) NULL)
    if (!is.data.frame(df) ||
        !all(c("scientificName", "match_key") %in% names(df))) {
        warning("invasive_species.rds is invalid; invasive flag disabled.")
        return(invasive_species_empty())
    }
    df$scientificName <- as.character(df$scientificName)
    df$match_key <- as.character(df$match_key)
    for (col in c("kingdom", "vernacularName", "introduction_reason", "source")) {
        if (!col %in% names(df)) {
            df[[col]] <- NA_character_
        }
        df[[col]] <- as.character(df[[col]])
    }
    df <- df[!is.na(df$match_key) & nzchar(df$match_key), , drop = FALSE]
    rownames(df) <- NULL
    invasive_species_cache$set(df, path = path)
    df
}

# Normalize names exactly as data-raw/generate_invasive_species.R does, so the
# list and the validator's resolved names compare on identical keys. The two
# must stay in lockstep.
build_invasive_match_keys <- function(names) {
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

# Lookup row for each name, aligned to the input (NA columns where not listed).
# Resolves over unique names and expands with match(): occurrence data repeats
# a handful of species across thousands of rows, so this is the difference
# between a per-row scan and a single pass (same idiom as sensitive_resolve).
invasive_info_for <- function(names) {
    n <- length(names)
    empty <- data.frame(
        invasive = logical(n),
        vernacularName = rep(NA_character_, n),
        introduction_reason = rep(NA_character_, n),
        source = rep(NA_character_, n),
        stringsAsFactors = FALSE
    )
    if (n == 0L) {
        return(empty[0L, , drop = FALSE])
    }
    lookup <- load_invasive_species()
    if (!is.data.frame(lookup) || nrow(lookup) == 0L) {
        return(empty)
    }

    unique_names <- unique(as.character(names))
    keys <- build_invasive_match_keys(unique_names)
    m <- match(keys, lookup$match_key)
    ok <- !is.na(keys) & nzchar(keys) & !is.na(m)

    idx <- match(as.character(names), unique_names)
    hit <- ok[idx]
    row <- m[idx]

    out <- empty
    out$invasive <- hit
    out$vernacularName[hit] <- lookup$vernacularName[row[hit]]
    out$introduction_reason[hit] <- lookup$introduction_reason[row[hit]]
    out$source[hit] <- lookup$source[row[hit]]
    out
}

# TRUE for each name recorded as an alien invasive species in Brazil.
flag_invasive_species <- function(names) {
    if (length(names) == 0L) {
        return(logical(0))
    }
    invasive_info_for(names)$invasive
}
