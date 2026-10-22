# Title: Invasive alien species lookup
# Author: Rogerio Nunes Oliveira
#
# Pure helpers for the invasive-species flag shown in name validation. No
# Shiny, no reactives. A bundled list of alien invasive species recorded for
# Brazil (inst/extdata/invasive_species.rds, built from
# data-raw/generate_invasive_species.R over the Instituto Horus 2023 list) is
# matched against the validator's resolved scientificName.
#
# The list is not uniform: alongside taxa alien to Brazil it carries Brazilian
# natives that are invasive outside their natural range within the country.
# origin_class, derived at build time from the CTFB / Flora e Funga do Brasil
# origin field, separates the two.
#
# "alien" says the taxon is alien and invasive in Brazil, which supports
# dwc:establishmentMeans = "introduced". "translocated_native" supports
# neither term: whether a record sits inside or outside the taxon's natural
# range is not knowable from the name. Neither says anything about
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
        origin_class = character(0),
        native_range = character(0),
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
    for (col in c("kingdom", "vernacularName", "introduction_reason",
                  "origin_class", "native_range", "source")) {
        if (!col %in% names(df)) {
            df[[col]] <- NA_character_
        }
        df[[col]] <- as.character(df[[col]])
    }
    # An RDS predating origin_class keeps the old behaviour: everything alien.
    unclassed <- is.na(df$origin_class) | !nzchar(df$origin_class)
    df$origin_class[unclassed] <- "alien"
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
        origin_class = rep(NA_character_, n),
        native_range = rep(NA_character_, n),
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
    out$origin_class[hit] <- lookup$origin_class[row[hit]]
    out$native_range[hit] <- lookup$native_range[row[hit]]
    out$source[hit] <- lookup$source[row[hit]]
    out
}

# TRUE for each name on the invasive list, whichever origin_class it carries.
# The filter pill and the aggregate count cover both groups: a translocated
# native is still a record whose establishment terms deserve attention.
flag_invasive_species <- function(names) {
    if (length(names) == 0L) {
        return(logical(0))
    }
    invasive_info_for(names)$invasive
}

# Translate the Horus "Motivo da introducao no Brasil" for display. The source
# writes Portuguese values from a closed set of 8, sometimes several separated
# by "; ", so each token is looked up on its own and anything unrecognised
# falls through verbatim rather than turning into a missing-key placeholder.
# Keyed on normalize_for_matching() output, so accents and case in the source
# spreadsheet do not have to be reproduced here.
.invasive_reason_keys <- c(
    "especies marinhas" = "invasive_reason_marine",
    "peixes de aquario" = "invasive_reason_aquarium_fish",
    "peixes de aquicultura" = "invasive_reason_aquaculture_fish",
    "pesca desportiva" = "invasive_reason_sport_fishing",
    "pets" = "invasive_reason_pets",
    "plantas forrageiras" = "invasive_reason_forage_plants",
    "plantas ornamentais" = "invasive_reason_ornamental_plants",
    "uso florestal" = "invasive_reason_forestry"
)

translate_invasive_reason <- function(reason, lang) {
    if (length(reason) != 1L || is.na(reason) || !nzchar(trimws(reason))) {
        return(NA_character_)
    }
    tokens <- trimws(strsplit(as.character(reason), ";", fixed = TRUE)[[1]])
    tokens <- tokens[nzchar(tokens)]
    if (length(tokens) == 0L) {
        return(NA_character_)
    }
    labels <- vapply(tokens, function(token) {
        # Single bracket: [[ ]] on an absent name errors (LESSONS.md).
        key <- unname(.invasive_reason_keys[normalize_for_matching(token)])
        if (is.na(key)) token else tr(key, lang)
    }, FUN.VALUE = character(1), USE.NAMES = FALSE)
    paste(labels, collapse = ", ")
}

# The detail lines shown under the badge, in order, for one name. Both are
# optional in the source, so the result is a zero-length vector when neither
# is recorded -- which is the case for the coati and the tegu's reason.
#
# native_range is free Portuguese prose copied from Horus, so only the label
# is translated. It is informational: nothing in the app tests a record's
# country or coordinates against it.
invasive_detail_lines <- function(name, lang) {
    info <- invasive_info_for(name)
    if (nrow(info) == 0L || !isTRUE(info$invasive[[1]])) {
        return(character(0))
    }
    lines <- character(0)
    range_text <- info$native_range[[1]]
    if (!is.na(range_text) && nzchar(trimws(range_text))) {
        lines <- c(lines, sprintf(
            tr("invasive_native_range_line", lang), trimws(range_text)
        ))
    }
    reason <- translate_invasive_reason(info$introduction_reason[[1]], lang)
    if (!is.na(reason)) {
        lines <- c(lines, sprintf(tr("invasive_reason_line", lang), reason))
    }
    lines
}

# "alien", "translocated_native", or NA for names that are not on the list.
# Callers that assert something about the taxon (badge wording, the
# establishmentMeans suggestion) must branch on this, not on membership alone.
invasive_origin_class_for <- function(names) {
    if (length(names) == 0L) {
        return(character(0))
    }
    invasive_info_for(names)$origin_class
}
