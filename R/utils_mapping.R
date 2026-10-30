# Title: Mapping Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-11
# Version: 1.0

# is_blank_value(), normalize_for_matching(), tokenize_for_matching() moved to
# utils_common.R (Onda 0, PR-0.1 / M8).

#' @include utils_common.R
NULL

split_semicolon_tokens <- function(value) {
    if (is_blank_value(value)) {
        return(character(0))
    }

    parts <- strsplit(as.character(value), ";", fixed = TRUE)[[1]]
    parts <- trimws(parts)
    parts[nzchar(parts)]
}

split_output_tokens <- function(value, out_sep = " | ") {
    if (is_blank_value(value)) {
        return(character(0))
    }

    parts <- strsplit(as.character(value), out_sep, fixed = TRUE)[[1]]
    parts <- trimws(parts)
    parts[nzchar(parts)]
}

has_selected_value <- function(value) {
    !is.null(value) && length(value) > 0 && any(value != "")
}

# Match a mapped selection to the columns the upload actually carries. An exact
# name wins. A name that differs only by surrounding whitespace is accepted
# next, in either direction: a spreadsheet header may carry a trailing space
# ("family "), and a mapping guide may have picked up a stray one. A name that
# matches nothing is dropped -- reading a missing column yields NULL, and the
# zero-length vector that follows aborts the whole mapping build.
resolve_selected_columns <- function(selection, available) {
    if (!has_selected_value(selection)) {
        return(character(0))
    }

    resolved <- as.character(selection)
    unmatched <- !resolved %in% available
    if (any(unmatched)) {
        idx <- match(trimws(resolved[unmatched]), trimws(available))
        resolved[unmatched] <- available[idx]
    }

    resolved[!is.na(resolved)]
}

sanitize_map_selection <- function(term, value) {
    if (is.null(value) || length(value) == 0) {
        return("")
    }

    value_chr <- as.character(value)
    value_chr <- value_chr[!is.na(value_chr)]
    # Trim decides what counts as blank, but the value is kept verbatim: a
    # column name is a literal key into names(df), and a spreadsheet header may
    # carry surrounding whitespace ("family "). resolve_selected_columns()
    # forgives a whitespace difference later, against the real column names.
    value_chr <- value_chr[nzchar(trimws(value_chr))]

    if (length(value_chr) == 0) {
        return("")
    }

    if (term %in% c("scientificName", "basisOfRecord")) {
        return(value_chr[[1]])
    }

    value_chr
}

# The columns of a guide source. The guide joins a concatenation with " + ",
# so a column named "lat + gps" looks like two. The whole name wins when the
# data has that column (AUD-15).
guide_source_columns <- function(src, available_columns = NULL) {
    src <- trimws(src)
    if (src %in% available_columns) return(src)
    # A header can contain ' + '. Match the longest literal header first,
    # also inside a concatenation of columns (ADR-171).
    columns <- unique(trimws(available_columns))
    columns <- columns[!is.na(columns) & nzchar(columns)]
    columns <- columns[order(nchar(columns), decreasing = TRUE)]
    for (column in columns) {
        prefix <- paste0(column, " + ")
        if (startsWith(src, prefix)) {
            rest <- substring(src, nchar(prefix) + 1L)
            return(c(column, guide_source_columns(rest, available_columns)))
        }
    }
    cols <- trimws(strsplit(src, "\\s*\\+\\s*", perl = TRUE)[[1]])
    cols[nzchar(cols)]
}

#' Plan a faithful mapping restore from a parsed mapping guide
#'
#' Given a parsed guide payload (\code{parse_mapping_guide_txt()}) and the
#' columns available in the currently loaded dataset, returns the exact mapping
#' to apply: per-term column selections with concatenations preserved (and
#' restricted to columns that exist), constant values, and the matched/missing
#' source columns for user reporting.
#'
#' @param payload Output of \code{parse_mapping_guide_txt()}.
#' @param available_columns Character vector of column names in the loaded data.
#' @return Named list: \code{map_values} (term -> column vector),
#'   \code{constants} (term -> value), \code{matched_columns},
#'   \code{missing_columns}, \code{applied_terms}, \code{skipped_terms}.
#' @noRd
plan_mapping_guide_restore <- function(payload, available_columns) {
    available_columns <- as.character(available_columns)
    map_values <- list()
    constants <- list()
    matched <- character(0)
    missing <- character(0)
    applied_terms <- character(0)
    skipped_terms <- character(0)

    pairs <- if (is.list(payload)) payload$pairs else NULL
    if (!is.data.frame(pairs) || nrow(pairs) == 0L) {
        return(list(
            map_values = map_values, constants = constants,
            matched_columns = matched, missing_columns = missing,
            applied_terms = applied_terms, skipped_terms = skipped_terms
        ))
    }

    has_kind <- "kind" %in% names(pairs)
    for (i in seq_len(nrow(pairs))) {
        term <- trimws(as.character(pairs$dwc_term[[i]]))
        if (!nzchar(term)) next
        kind <- if (has_kind) as.character(pairs$kind[[i]]) else "column"

        if (identical(kind, "constant")) {
            val <- as.character(pairs$constant_value[[i]])
            if (!is.na(val) && nzchar(val)) {
                constants[[term]] <- val
                applied_terms <- c(applied_terms, term)
            }
            next
        }

        src <- as.character(pairs$source_column[[i]])
        if (is.na(src) || !nzchar(trimws(src))) next
        cols <- guide_source_columns(src, available_columns)
        present <- cols[cols %in% available_columns]
        absent <- cols[!cols %in% available_columns]
        matched <- c(matched, present)
        missing <- c(missing, absent)
        if (length(present) > 0L) {
            map_values[[term]] <- present
            applied_terms <- c(applied_terms, term)
        } else {
            skipped_terms <- c(skipped_terms, term)
        }
    }

    list(
        map_values = map_values,
        constants = constants,
        matched_columns = unique(matched),
        missing_columns = unique(missing),
        applied_terms = unique(applied_terms),
        skipped_terms = unique(skipped_terms)
    )
}

normalize_basis_of_record_key <- function(value) {
    if (is_blank_value(value)) {
        return("")
    }

    normalized <- trimws(as.character(value))
    normalized <- tolower(normalized)
    normalized
}

normalize_basis_of_record_keys <- function(values) normalize_domain_keys(values)

# The key of a blank cell. A blank basisOfRecord blocks the export, so the
# assistant lists blank cells as one more value the user can convert.
bor_blank_key <- "\u2205"

bor_value_keys <- function(values) {
    keys <- normalize_basis_of_record_keys(values)
    keys[!nzchar(keys)] <- bor_blank_key
    keys
}

sanitize_basis_of_record_term <- function(value) {
    if (is_blank_value(value)) {
        return("")
    }

    candidate <- trimws(as.character(value)[[1]])
    allowed_terms <- get_basis_of_record_terms()

    if (!candidate %in% allowed_terms) {
        return("")
    }

    candidate
}

sanitize_basis_of_record_terms <- function(values) {
    allowed <- get_basis_of_record_terms()
    chr <- trimws(as.character(values))
    chr[is.na(values)] <- ""
    ifelse(chr %in% allowed, chr, "")
}

# Common spreadsheet values that name one basisOfRecord term without doubt.
# Keys are normalize_for_matching() output. Values that can mean more than one
# term ("coleta": a specimen or a tissue sample) stay out: the assistant asks
# for them.
basis_of_record_synonyms <- c(
    "observacao" = "HumanObservation",
    "observacao em campo" = "HumanObservation",
    "observacao de campo" = "HumanObservation",
    "observacao direta" = "HumanObservation",
    "avistamento" = "HumanObservation",
    "observation" = "HumanObservation",
    "field observation" = "HumanObservation",
    "armadilha fotografica" = "MachineObservation",
    "camera trap" = "MachineObservation",
    "especime preservado" = "PreservedSpecimen",
    "material preservado" = "PreservedSpecimen",
    "material preservado herbario" = "PreservedSpecimen",
    "especime de herbario" = "PreservedSpecimen",
    "especime de museu" = "PreservedSpecimen",
    "exsicata" = "PreservedSpecimen",
    "herbarium specimen" = "PreservedSpecimen",
    "museum specimen" = "PreservedSpecimen",
    "amostra de tecido" = "MaterialSample",
    "tissue sample" = "MaterialSample",
    "especime vivo" = "LivingSpecimen",
    "fossil" = "FossilSpecimen",
    "observacion" = "HumanObservation",
    "observacion de campo" = "HumanObservation",
    "observacion directa" = "HumanObservation",
    "avistamiento" = "HumanObservation",
    "fototrampeo" = "MachineObservation",
    "camara trampa" = "MachineObservation",
    "trampa camara" = "MachineObservation",
    "especimen de herbario" = "PreservedSpecimen",
    "especimen de museo" = "PreservedSpecimen",
    "muestra de tejido" = "MaterialSample",
    "fosil" = "FossilSpecimen",
    # GBIF: a person who takes a photo or a recording observed the organism,
    # so the record is a HumanObservation. A device that records with no
    # person present (camera trap, autonomous recorder) is a MachineObservation
    # (B30).
    "foto" = "HumanObservation",
    "fotografia" = "HumanObservation",
    "registro fotografico" = "HumanObservation",
    "photo" = "HumanObservation",
    "photograph" = "HumanObservation",
    "audio" = "HumanObservation",
    "gravacao de audio" = "HumanObservation",
    "audio recording" = "HumanObservation",
    "sound recording" = "HumanObservation",
    "grabacion de audio" = "HumanObservation",
    "gravador autonomo" = "MachineObservation",
    "autonomous recorder" = "MachineObservation",
    "grabadora autonoma" = "MachineObservation",
    "specimen" = "PreservedSpecimen",
    "especime" = "PreservedSpecimen",
    "especimen" = "PreservedSpecimen"
)

#' Suggest a basisOfRecord term for each raw value
#'
#' Matches, in order: the DwC term itself (case, space and underscore
#' insensitive), its English, Portuguese or Spanish label, then
#' `basis_of_record_synonyms`. Accents do not matter. Vectorized.
#'
#' @param raw_values Character vector of raw spreadsheet values
#' @return Character vector of the same length: a DwC term, or "" when no
#'   match is certain
#' @noRd
auto_suggest_basis_of_record_terms <- function(raw_values) {
    norm <- normalize_for_matching(raw_values)
    norm[is.na(norm)] <- ""
    out <- rep("", length(norm))

    terms <- get_basis_of_record_terms()
    labels_en <- vapply(basis_of_record_vocab_catalog, function(item) item$label_en, character(1))
    labels_pt <- vapply(basis_of_record_vocab_catalog, function(item) item$label_pt, character(1))
    labels_es <- vapply(basis_of_record_vocab_catalog, function(item) item$label_es, character(1))
    lookup <- c(
        stats::setNames(terms, gsub(" ", "", normalize_for_matching(terms), fixed = TRUE)),
        stats::setNames(terms, normalize_for_matching(labels_en)),
        stats::setNames(terms, normalize_for_matching(labels_pt)),
        stats::setNames(terms, normalize_for_matching(labels_es)),
        basis_of_record_synonyms
    )

    compact <- gsub(" ", "", norm, fixed = TRUE)
    hit <- lookup[compact]
    by_label <- is.na(hit)
    hit[by_label] <- lookup[norm[by_label]]
    found <- !is.na(hit) & nzchar(norm)
    out[found] <- unname(hit[found])
    out
}

sanitize_basis_of_record_map <- function(basis_of_record_map) {
    if (is.null(basis_of_record_map) || length(basis_of_record_map) == 0) {
        return(stats::setNames(character(0), character(0)))
    }

    raw_values <- unlist(basis_of_record_map, use.names = FALSE)
    raw_keys <- names(basis_of_record_map)

    if (is.null(raw_keys)) {
        raw_keys <- rep("", length(raw_values))
    }

    clean_keys <- normalize_basis_of_record_keys(raw_keys)
    clean_values <- sanitize_basis_of_record_terms(raw_values)
    keep <- nzchar(clean_keys)

    if (!any(keep)) {
        return(stats::setNames(character(0), character(0)))
    }

    stats::setNames(clean_values[keep], clean_keys[keep])
}

extract_basis_of_record_unique_entries <- function(raw_values) {
    raw_chr <- as.character(raw_values)
    raw_chr[is.na(raw_values)] <- ""
    raw_chr <- trimws(raw_chr)

    keys <- normalize_basis_of_record_keys(raw_chr)
    keep_idx <- which(nzchar(keys))
    if (length(keys) == 0) {
        return(data.frame(
            idx = integer(0),
            key = character(0),
            raw = character(0),
            stringsAsFactors = FALSE
        ))
    }

    keys_non_blank <- keys[keep_idx]
    raw_non_blank <- raw_chr[keep_idx]
    first_occurrence <- !duplicated(keys_non_blank)
    unique_keys <- keys_non_blank[first_occurrence]
    raw_display <- raw_non_blank[first_occurrence]
    # Blank cells come last as one entry, so the user can give them a term.
    if (length(keep_idx) < length(keys)) {
        unique_keys <- c(unique_keys, bor_blank_key)
        raw_display <- c(raw_display, "")
    }

    data.frame(
        idx = seq_along(unique_keys),
        key = unique_keys,
        raw = raw_display,
        stringsAsFactors = FALSE
    )
}

map_basis_of_record_values <- function(raw_values, basis_of_record_map = NULL) {
    raw_chr <- as.character(raw_values)
    raw_chr[is.na(raw_values)] <- ""
    keys <- bor_value_keys(raw_chr)

    # A value the assistant has a decision for keeps it, a skip ("") included.
    # Any other value gets the automatic suggestion, so a mapped column converts
    # without opening the assistant.
    clean_map <- sanitize_basis_of_record_map(basis_of_record_map)
    mapped <- unname(clean_map[keys])
    undecided <- is.na(mapped)
    if (any(undecided)) {
        # Suggest once per distinct value: a column has few, over many rows.
        pending <- raw_chr[undecided]
        distinct <- unique(pending)
        mapped[undecided] <- auto_suggest_basis_of_record_terms(distinct)[match(pending, distinct)]
    }
    sanitize_basis_of_record_terms(mapped)
}

# ---------------------------------------------------------------------------
# establishmentMeans / degreeOfEstablishment (per-species assistant)
#
# Unlike the basisOfRecord assistant, which translates the unique values of a
# mapped column, this one is keyed on the SPECIES: the user answers once per
# taxon and the answer is expanded to every record of that taxon. That is what
# makes a spreadsheet with thousands of rows and a few dozen species tractable.
# All helpers are vectorized (ADR-018).
# ---------------------------------------------------------------------------

normalize_species_keys <- function(values) normalize_domain_keys(values)

sanitize_establishment_terms <- function(values, field = "means") {
    allowed <- if (identical(field, "degree")) {
        get_degree_of_establishment_terms()
    } else {
        get_establishment_means_terms()
    }
    chr <- trimws(as.character(values))
    chr[is.na(values)] <- ""
    ifelse(chr %in% allowed, chr, "")
}

# Normalize one field's species -> term map: blank keys dropped, values not in
# the controlled vocabulary reduced to "".
sanitize_establishment_field_map <- function(field_map, field = "means") {
    if (is.null(field_map) || length(field_map) == 0) {
        return(stats::setNames(character(0), character(0)))
    }
    raw_values <- unlist(field_map, use.names = FALSE)
    raw_keys <- names(field_map)
    if (is.null(raw_keys)) {
        raw_keys <- rep("", length(raw_values))
    }
    clean_keys <- normalize_species_keys(raw_keys)
    clean_values <- sanitize_establishment_terms(raw_values, field = field)
    keep <- nzchar(clean_keys)
    if (!any(keep)) {
        return(stats::setNames(character(0), character(0)))
    }
    stats::setNames(clean_values[keep], clean_keys[keep])
}

# The assistant's committed state: list(means, degree, island_means,
# island_degree), each a named chr keyed by species. The island pair holds the
# answer for the species' records on an oceanic island (ADR-143).
sanitize_establishment_map <- function(establishment_map) {
    if (!is.list(establishment_map)) {
        establishment_map <- list()
    }
    list(
        means = sanitize_establishment_field_map(
            establishment_map$means, field = "means"
        ),
        degree = sanitize_establishment_field_map(
            establishment_map$degree, field = "degree"
        ),
        island_means = sanitize_establishment_field_map(
            establishment_map$island_means, field = "means"
        ),
        island_degree = sanitize_establishment_field_map(
            establishment_map$island_degree, field = "degree"
        )
    )
}

establishment_map_is_empty <- function(establishment_map) {
    clean <- sanitize_establishment_map(establishment_map)
    !any(vapply(clean, function(x) any(nzchar(x)), logical(1)))
}

# Unique species in the mapped scientificName column, with the record count so
# the assistant can show how much data each answer covers. Ordered by count
# (descending) then name: the taxa that matter most come first.
extract_species_entries <- function(raw_values) {
    raw_chr <- as.character(raw_values)
    raw_chr[is.na(raw_values)] <- ""
    raw_chr <- trimws(raw_chr)

    keys <- normalize_species_keys(raw_chr)
    keep_idx <- which(nzchar(keys))
    if (length(keep_idx) == 0) {
        return(data.frame(
            idx = integer(0), key = character(0), raw = character(0),
            n_records = integer(0), stringsAsFactors = FALSE
        ))
    }

    keys_non_blank <- keys[keep_idx]
    raw_non_blank <- raw_chr[keep_idx]
    first_occurrence <- !duplicated(keys_non_blank)
    unique_keys <- keys_non_blank[first_occurrence]
    raw_display <- raw_non_blank[first_occurrence]
    counts <- as.integer(table(keys_non_blank)[unique_keys])

    ord <- order(-counts, raw_display)
    data.frame(
        idx = seq_along(unique_keys),
        key = unique_keys[ord],
        raw = raw_display[ord],
        n_records = counts[ord],
        stringsAsFactors = FALSE
    )
}

# Pre-fill establishmentMeans only for taxa the bundled list records as alien
# to Brazil: that is what supports "introduced". Nothing is suggested for the
# rest -- guessing "native" for an unlisted taxon would assert something the
# app cannot know, and the list's translocated natives are alien to part of
# Brazil only, so a record could sit on either side of the taxon's natural
# range. Nothing is ever suggested for degreeOfEstablishment: that depends on
# the record (a captive animal and a feral one are the same species), so it
# stays with the user.
auto_suggest_establishment_means <- function(species_names) {
    n <- length(species_names)
    if (n == 0L) {
        return(stats::setNames(character(0), character(0)))
    }
    origin_class <- invasive_origin_class_for(species_names)
    alien <- !is.na(origin_class) & origin_class == "alien"
    out <- ifelse(alien, "introduced", "")
    stats::setNames(out, normalize_species_keys(species_names))
}

# Expand a per-species answer to one value per row. `island_rows` (from
# establishment_island_rows()) marks the records that take the island answer
# instead. They never fall back to the species answer: "native" given for the
# mainland records is false on the island.
map_establishment_values <- function(species_values, establishment_map = NULL,
                                     field = "means", island_rows = NULL) {
    keys <- normalize_species_keys(species_values)
    if (is.null(establishment_map) || length(establishment_map) == 0) {
        return(rep("", length(keys)))
    }
    clean <- sanitize_establishment_map(establishment_map)
    degree <- identical(field, "degree")
    field_map <- if (degree) clean$degree else clean$means
    mapped <- unname(field_map[keys])
    mapped[is.na(mapped)] <- ""
    if (length(island_rows) == length(keys)) {
        on_island <- !is.na(island_rows)
        island_map <- if (degree) clean$island_degree else clean$island_means
        island_values <- unname(island_map[keys[on_island]])
        island_values[is.na(island_values)] <- ""
        mapped[on_island] <- island_values
    }
    mapped
}

# Value of one establishment term for a data slice: the user's mapped column
# (if any) with the blanks filled from the per-species answers. Shared by the
# export pipeline and the mapping card's sample line so both show the same
# thing. `species_values` NULL (scientificName not mapped) means the assistant
# contributes nothing.
# Key used to recognize a controlled term written in another shape. Case and
# punctuation are ignored, so "native endemic" and "Native-Endemic" both reach
# `nativeEndemic`. Nothing is translated: "Nativo" is not the vocabulary and
# gets no key that matches.
establishment_vocab_key <- function(values) {
    chr <- tolower(as.character(values))
    chr[is.na(values)] <- ""
    translit <- iconv(chr, to = "ASCII//TRANSLIT")
    chr[!is.na(translit)] <- translit[!is.na(translit)]
    gsub("[^a-z0-9]", "", chr)
}

# The controlled term each value already is, or "" for a value outside the
# vocabulary. `field` is "means" or "degree".
canonical_establishment_values <- function(values, field = "means") {
    allowed <- if (identical(field, "degree")) {
        get_degree_of_establishment_terms()
    } else {
        get_establishment_means_terms()
    }
    idx <- match(establishment_vocab_key(values), establishment_vocab_key(allowed))
    out <- allowed[idx]
    out[is.na(out)] <- ""
    out
}

build_establishment_term_value <- function(term, df, user_cols = NULL,
                                           species_values = NULL,
                                           establishment_map = NULL,
                                           out_sep = " | ",
                                           island_rows = NULL) {
    field <- if (identical(term, "degreeOfEstablishment")) "degree" else "means"
    n <- nrow(df)
    assistant_values <- if (is.null(species_values)) {
        rep("", n)
    } else {
        map_establishment_values(
            species_values, establishment_map, field = field,
            island_rows = island_rows
        )
    }
    column_values <- if (has_selected_value(user_cols)) {
        build_term_value(term = term, df = df, user_cols = user_cols, out_sep = out_sep)$values
    } else {
        rep("", n)
    }

    # Precedence, per row: a column value that already IS the controlled term
    # wins, then the assistant's answer, then blank. What must never happen is
    # the third case the old code allowed -- a column value outside the
    # vocabulary published verbatim, which put free text like "Domestico" into
    # a term GBIF reads against a fixed list. Those rows come back from
    # establishment_dropped_values() so the export screen can name them.
    out <- canonical_establishment_values(column_values, field = field)
    blank <- !nzchar(out)
    out[blank] <- assistant_values[blank]
    out[is.na(out)] <- ""
    out
}

# Column values that reach neither the vocabulary nor an assistant answer, so
# the export leaves their rows blank. One row per distinct value, ordered by
# how much data it covers, for the export screen to report.
establishment_dropped_values <- function(term, df, user_cols = NULL,
                                         species_values = NULL,
                                         establishment_map = NULL,
                                         out_sep = " | ",
                                         island_rows = NULL) {
    empty <- data.frame(
        raw = character(0), n_records = integer(0), stringsAsFactors = FALSE
    )
    if (!is.data.frame(df) || nrow(df) == 0L || !has_selected_value(user_cols)) {
        return(empty)
    }

    column_values <- build_term_value(
        term = term, df = df, user_cols = user_cols, out_sep = out_sep
    )$values
    published <- build_establishment_term_value(
        term = term, df = df, user_cols = user_cols,
        species_values = species_values, establishment_map = establishment_map,
        out_sep = out_sep, island_rows = island_rows
    )

    raw_chr <- trimws(as.character(column_values))
    raw_chr[is.na(column_values)] <- ""
    lost <- nzchar(raw_chr) & !nzchar(published)
    if (!any(lost)) {
        return(empty)
    }

    tab <- table(raw_chr[lost])
    out <- data.frame(
        raw = names(tab),
        n_records = as.integer(tab),
        stringsAsFactors = FALSE
    )
    out[order(-out$n_records, out$raw), , drop = FALSE]
}

# How many species have an answer for one of the two fields. Drives the card's
# "filled by the assistant" state, so the card stops reading as unmapped once
# the assistant has done its job.
establishment_answer_count <- function(establishment_map, field = "means") {
    clean <- sanitize_establishment_map(establishment_map)
    degree <- identical(field, "degree")
    values <- if (degree) clean$degree else clean$means
    island <- if (degree) clean$island_degree else clean$island_means
    answered <- union(names(values)[nzchar(values)], names(island)[nzchar(island)])
    length(answered)
}

# Species that got an establishmentMeans but no degreeOfEstablishment. The
# pair is strongly recommended, so the assistant and the export surface this --
# but it never blocks: Darwin Core does not require degreeOfEstablishment, and
# a taxon whose degree is genuinely unknown must still be publishable.
establishment_pairs_missing_degree <- function(establishment_map) {
    clean <- sanitize_establishment_map(establishment_map)
    missing_in <- function(means, degree) {
        with_means <- names(means)[nzchar(means)]
        degree_for <- degree[with_means]
        degree_for[is.na(degree_for)] <- ""
        with_means[!nzchar(degree_for)]
    }
    union(
        missing_in(clean$means, clean$degree),
        missing_in(clean$island_means, clean$island_degree)
    )
}

default_meta <- function() {
    list(
        status = NA_character_,
        score = NA_real_,
        reason = NA_character_,
        source = NA_character_
    )
}

empty_map_values <- function(terms) {
    stats::setNames(lapply(seq_along(terms), function(i) ""), terms)
}

empty_map_meta <- function(terms) {
    stats::setNames(lapply(seq_along(terms), function(i) default_meta()), terms)
}

build_manual_meta <- function(previous_meta, has_value) {
    previous_score <- if (is.null(previous_meta) || is.null(previous_meta$score)) {
        NA_real_
    } else {
        suppressWarnings(as.numeric(previous_meta$score))
    }

    if (isTRUE(has_value)) {
        return(list(
            status = "EDITADO",
            score = previous_score,
            reason = "manual_adjust",
            source = "manual"
        ))
    }

    list(
        status = "MANUAL",
        score = NA_real_,
        reason = "manual_cleared",
        source = "manual"
    )
}

sanitize_synonyms_table <- function(synonyms_tbl) {
    required_cols <- c("term", "synonym", "name_score", "lang", "active")

    if (!all(required_cols %in% names(synonyms_tbl))) {
        stop("Synonyms table must contain columns: ", paste(required_cols, collapse = ", "))
    }

    clean_tbl <- synonyms_tbl[, required_cols, drop = FALSE]
    clean_tbl$term <- trimws(as.character(clean_tbl$term))
    clean_tbl$synonym <- trimws(as.character(clean_tbl$synonym))
    clean_tbl$name_score <- suppressWarnings(as.numeric(clean_tbl$name_score))
    clean_tbl$lang <- trimws(tolower(as.character(clean_tbl$lang)))
    clean_tbl$active <- as.logical(clean_tbl$active)

    if (any(is.na(clean_tbl$term) | clean_tbl$term == "")) {
        stop("Synonyms table contains invalid term values.")
    }
    if (any(is.na(clean_tbl$synonym) | clean_tbl$synonym == "")) {
        stop("Synonyms table contains invalid synonym values.")
    }
    if (any(is.na(clean_tbl$name_score) | clean_tbl$name_score < 0.90 | clean_tbl$name_score > 0.98)) {
        stop("Synonyms table name_score must be numeric in range [0.90, 0.98].")
    }
    if (any(is.na(clean_tbl$lang) | !clean_tbl$lang %in% c("pt", "en", "es", "any"))) {
        stop("Synonyms table lang must be one of: pt, en, es, any.")
    }
    if (any(is.na(clean_tbl$active))) {
        stop("Synonyms table active column must be TRUE/FALSE.")
    }

    active_tbl <- clean_tbl[clean_tbl$active, , drop = FALSE]
    if (nrow(active_tbl) > 0) {
        key <- paste(
            normalize_for_matching(active_tbl$term),
            normalize_for_matching(active_tbl$synonym),
            active_tbl$lang,
            sep = "||"
        )
        if (any(duplicated(key))) {
            stop("Synonyms table contains duplicated active term/synonym/lang combinations.")
        }
    }

    clean_tbl
}

dwc_synonyms_cache <- create_rds_cache("dwc_synonyms")

resolve_dwc_synonyms_path <- function() {
    candidates <- c(
        system.file("extdata", "dwc_synonyms_v1.rds", package = "saira"),
        file.path("inst", "extdata", "dwc_synonyms_v1.rds"),
        file.path("..", "..", "inst", "extdata", "dwc_synonyms_v1.rds")
    )
    candidates <- unique(candidates[nzchar(candidates)])
    path <- candidates[file.exists(candidates)][1]

    if (is.null(path) || !file.exists(path)) {
        stop("dwc_synonyms_v1.rds not found in expected locations.")
    }

    path
}

resolve_explicit_synonyms_path <- function(path) {
    if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
        stop("path must be a non-empty character scalar when provided.")
    }
    if (!file.exists(path)) {
        stop("dwc_synonyms_v1.rds not found at explicit path.")
    }
    path
}

reset_dwc_synonyms_cache <- function() {
    dwc_synonyms_cache$reset()
}

dwc_synonyms_cache_state <- function() {
    dwc_synonyms_cache$state()
}

load_dwc_synonyms_v1 <- function(path = NULL, force = FALSE) {
    validate_force_flag(force)

    if (!is.null(path)) {
        explicit_path <- resolve_explicit_synonyms_path(path)
        return(sanitize_synonyms_table(readRDS(explicit_path)))
    }

    if (!isTRUE(force) && !is.null(dwc_synonyms_cache$get())) {
        return(dwc_synonyms_cache$get())
    }

    resolved_path <- resolve_dwc_synonyms_path()
    synonyms_tbl <- sanitize_synonyms_table(readRDS(resolved_path))

    dwc_synonyms_cache$set(synonyms_tbl, path = resolved_path)

    synonyms_tbl
}

tokenize_for_overlap <- function(x) {
    if (is_blank_value(x)) {
        return(character(0))
    }

    expanded <- as.character(x)
    expanded <- gsub("([a-z])([A-Z])", "\\1 \\2", expanded, perl = TRUE)
    expanded <- gsub("([A-Z]+)([A-Z][a-z])", "\\1 \\2", expanded, perl = TRUE)
    unique(tokenize_for_matching(expanded))
}

prepare_synonyms_for_scoring <- function(synonyms_tbl) {
    if (is.null(synonyms_tbl)) {
        return(list(
            by_term = list(),
            table = data.frame(stringsAsFactors = FALSE),
            prepared = TRUE
        ))
    }

    clean_tbl <- sanitize_synonyms_table(synonyms_tbl)
    active_tbl <- clean_tbl[clean_tbl$active, , drop = FALSE]
    if (nrow(active_tbl) == 0) {
        return(list(
            by_term = list(),
            table = active_tbl,
            prepared = TRUE
        ))
    }

    active_tbl$term_norm <- normalize_for_matching(active_tbl$term)
    active_tbl$synonym_norm <- normalize_for_matching(active_tbl$synonym)
    by_term <- split(active_tbl, active_tbl$term_norm, drop = TRUE)

    list(
        by_term = by_term,
        table = active_tbl,
        prepared = TRUE
    )
}

is_substring_token_match <- function(lhs, rhs, min_substring_n = 3L) {
    if (is_blank_value(lhs) || is_blank_value(rhs)) {
        return(FALSE)
    }

    lhs_chr <- as.character(lhs)
    rhs_chr <- as.character(rhs)
    if (identical(lhs_chr, rhs_chr)) {
        return(FALSE)
    }

    if (nchar(lhs_chr) < min_substring_n || nchar(rhs_chr) < min_substring_n) {
        return(FALSE)
    }

    grepl(lhs_chr, rhs_chr, fixed = TRUE) || grepl(rhs_chr, lhs_chr, fixed = TRUE)
}

score_token_overlap <- function(
  col_name,
  term,
  col_tokens = NULL,
  term_tokens = NULL,
  min_substring_n = 3L,
  with_details = FALSE
) {
    if (is.null(col_tokens)) {
        col_tokens <- tokenize_for_overlap(col_name)
    }
    if (is.null(term_tokens)) {
        term_tokens <- tokenize_for_overlap(term)
    }

    col_tokens <- unique(col_tokens)
    term_tokens <- unique(term_tokens)

    if (length(col_tokens) == 0 || length(term_tokens) == 0) {
        out <- list(
            score = 0,
            exact_hits = 0L,
            substring_hits = 0L,
            overlap_ratio = 0
        )
        if (isTRUE(with_details)) {
            return(out)
        }
        return(out$score)
    }

    exact_hits <- 0L
    substring_hits <- 0L

    for (token in col_tokens) {
        if (any(term_tokens == token)) {
            exact_hits <- exact_hits + 1L
            next
        }

        has_substring <- any(vapply(
            term_tokens,
            FUN = function(term_token) {
                is_substring_token_match(token, term_token, min_substring_n = min_substring_n)
            },
            FUN.VALUE = logical(1)
        ))

        if (has_substring) {
            substring_hits <- substring_hits + 1L
        }
    }

    matched_hits <- exact_hits + substring_hits
    if (matched_hits == 0L) {
        out <- list(
            score = 0,
            exact_hits = 0L,
            substring_hits = 0L,
            overlap_ratio = 0
        )
        if (isTRUE(with_details)) {
            return(out)
        }
        return(out$score)
    }

    union_size <- length(unique(c(col_tokens, term_tokens)))
    overlap_ratio <- matched_hits / union_size
    base_score <- 0.55 + (0.25 * overlap_ratio)
    adjusted <- base_score + (0.10 * exact_hits) - (0.10 * substring_hits)
    final_score <- pmin(0.80, pmax(0, adjusted))

    out <- list(
        score = final_score,
        exact_hits = exact_hits,
        substring_hits = substring_hits,
        overlap_ratio = overlap_ratio
    )

    if (isTRUE(with_details)) {
        return(out)
    }

    out$score
}

score_text_similarity <- function(col_name, term) {
    col_norm <- normalize_for_matching(col_name)
    term_norm <- normalize_for_matching(term)

    if (is_blank_value(col_norm) || is_blank_value(term_norm)) {
        return(0.30)
    }

    distance <- utils::adist(col_norm, term_norm)[1]
    max_len <- max(nchar(col_norm), nchar(term_norm))

    similarity <- if (max_len == 0) 0 else (1 - (distance / max_len))
    similarity <- pmin(1, pmax(0, similarity))

    pmin(0.60, pmax(0.30, 0.30 + 0.30 * similarity))
}

compute_name_score <- function(
  col_name,
  term,
  synonyms_tbl = NULL,
  col_profile = NULL,
  term_profile = NULL,
  synonyms_index = NULL
) {
    col_norm <- if (!is.null(col_profile) && !is.null(col_profile$norm)) {
        as.character(col_profile$norm)
    } else {
        normalize_for_matching(col_name)
    }
    term_norm <- if (!is.null(term_profile) && !is.null(term_profile$norm)) {
        as.character(term_profile$norm)
    } else {
        normalize_for_matching(term)
    }
    col_tokens <- if (!is.null(col_profile) && !is.null(col_profile$tokens)) {
        unique(as.character(col_profile$tokens))
    } else {
        tokenize_for_overlap(col_name)
    }
    term_tokens <- if (!is.null(term_profile) && !is.null(term_profile$tokens)) {
        unique(as.character(term_profile$tokens))
    } else {
        tokenize_for_overlap(term)
    }

    if (is_blank_value(col_norm) || is_blank_value(term_norm)) {
        return(list(
            score = 0,
            reason = "no_match",
            is_exact = FALSE,
            exact_hits = 0L,
            substring_hits = 0L
        ))
    }

    if (identical(col_norm, term_norm)) {
        return(list(
            score = 1.00,
            reason = "exact_match",
            is_exact = TRUE,
            exact_hits = length(col_tokens),
            substring_hits = 0L
        ))
    }

    synonym_lookup <- synonyms_index
    if (is.null(synonym_lookup) && !is.null(synonyms_tbl)) {
        synonym_lookup <- prepare_synonyms_for_scoring(synonyms_tbl)
    }

    if (!is.null(synonym_lookup$by_term) && length(synonym_lookup$by_term) > 0) {
        term_syn <- synonym_lookup$by_term[[term_norm]]
        if (!is.null(term_syn) && nrow(term_syn) > 0) {
            hit_idx <- which(term_syn$synonym_norm == col_norm)
            via_expansion <- FALSE
            if (length(hit_idx) == 0 && !is.null(col_profile$norm_expanded)) {
                hit_idx <- which(term_syn$synonym_norm == col_profile$norm_expanded)
                via_expansion <- length(hit_idx) > 0
            }
            if (length(hit_idx) > 0) {
                score <- max(term_syn$name_score[hit_idx], na.rm = TRUE)
                score <- pmin(0.98, pmax(0.90, score))
                return(list(
                    score = score,
                    reason = "known_synonym",
                    is_exact = FALSE,
                    exact_hits = 0L,
                    substring_hits = 0L,
                    via_expansion = via_expansion
                ))
            }
        }
    }

    overlap_details <- score_token_overlap(
        col_name = col_name,
        term = term,
        col_tokens = col_tokens,
        term_tokens = term_tokens,
        with_details = TRUE
    )
    if (overlap_details$score >= 0.40) {
        return(list(
            score = overlap_details$score + rostrum_identifier_name_bonus(col_tokens, term),
            reason = "token_overlap",
            is_exact = FALSE,
            exact_hits = overlap_details$exact_hits,
            substring_hits = overlap_details$substring_hits
        ))
    }

    similarity_score <- score_text_similarity(col_name, term)
    list(
        score = similarity_score,
        reason = "text_similarity",
        is_exact = FALSE,
        exact_hits = 0L,
        substring_hits = 0L
    )
}

sample_values_for_scoring <- function(values, name_score, max_sample_n = 1000L) {
    values_chr <- as.character(values)
    values_chr[is.na(values)] <- NA_character_
    values_chr <- trimws(values_chr)
    non_blank_values <- values_chr[!is.na(values_chr) & nzchar(values_chr)]

    if (length(non_blank_values) == 0) {
        return(character(0))
    }

    if (name_score >= 0.90) {
        target_n <- 1000L
    } else if (name_score >= 0.75) {
        target_n <- 500L
    } else {
        target_n <- 200L
    }

    target_n <- as.integer(max(1L, min(as.integer(max_sample_n), target_n)))
    total_n <- length(non_blank_values)
    if (total_n <= target_n) {
        return(non_blank_values)
    }

    # Uniform stratified sampling across the full column to avoid head bias.
    base_idx <- as.integer(round(seq(1, total_n, length.out = target_n)))
    base_idx <- sort(unique(base_idx))

    if (length(base_idx) >= target_n) {
        return(non_blank_values[base_idx[seq_len(target_n)]])
    }

    remaining_idx <- setdiff(seq_len(total_n), base_idx)
    random_take <- min(target_n - length(base_idx), length(remaining_idx))
    seed_probe <- non_blank_values[seq_len(min(10L, total_n))]
    seed <- digest::digest2int(paste0(seed_probe, collapse = "|"))

    extra_idx <- if (random_take > 0L) {
        withr::with_seed(
            seed,
            sample(remaining_idx, size = random_take, replace = FALSE)
        )
    } else {
        integer(0)
    }

    selected_idx <- sort(unique(c(base_idx, extra_idx)))
    selected_idx <- selected_idx[seq_len(min(length(selected_idx), target_n))]
    non_blank_values[selected_idx]
}

score_ratio_to_confidence <- function(valid_ratio) {
    valid_ratio <- suppressWarnings(as.numeric(valid_ratio))
    if (length(valid_ratio) != 1L || is.na(valid_ratio) || is.nan(valid_ratio)) {
        return(0)
    }

    pmin(1, pmax(0, valid_ratio))
}

validate_numeric_range <- function(values, min_value, max_value) {
    numeric_values <- suppressWarnings(as.numeric(gsub(",", ".", values)))
    numeric_ratio <- if (length(numeric_values) == 0) 0 else mean(!is.na(numeric_values))
    in_range <- !is.na(numeric_values) & numeric_values >= min_value & numeric_values <= max_value
    valid_ratio <- if (length(in_range) == 0) 0 else mean(in_range)

    list(
        score = score_ratio_to_confidence(valid_ratio),
        compatible_type = numeric_ratio >= 0.60,
        valid_ratio = valid_ratio,
        numeric_ratio = numeric_ratio
    )
}

validate_scientific_name_pattern <- function(values) {
    cleaned <- trimws(as.character(values))
    cleaned <- cleaned[nzchar(cleaned)]

    if (length(cleaned) == 0) {
        return(list(score = 0, compatible_type = FALSE, valid_ratio = 0))
    }

    is_valid <- grepl(
        "^[A-Z][A-Za-z-]+(\\s+([a-z][A-Za-z-]+|sp\\.?|cf\\.?\\s+[a-z][A-Za-z-]+))?$",
        cleaned
    )
    valid_ratio <- mean(is_valid)

    list(
        score = score_ratio_to_confidence(valid_ratio),
        compatible_type = valid_ratio >= 0.50,
        valid_ratio = valid_ratio
    )
}

validate_individual_count <- function(values) {
    numeric_values <- suppressWarnings(as.numeric(gsub(",", ".", values)))
    is_integer_non_negative <- !is.na(numeric_values) &
        numeric_values >= 0 &
        abs(numeric_values - round(numeric_values)) < 1e-09

    numeric_ratio <- if (length(numeric_values) == 0) 0 else mean(!is.na(numeric_values))
    valid_ratio <- if (length(is_integer_non_negative) == 0) 0 else mean(is_integer_non_negative)

    list(
        score = score_ratio_to_confidence(valid_ratio),
        compatible_type = numeric_ratio >= 0.60,
        valid_ratio = valid_ratio,
        numeric_ratio = numeric_ratio
    )
}

validate_vocabulary <- function(is_valid) {
    valid_ratio <- if (length(is_valid) == 0) 0 else mean(is_valid)
    list(
        score = score_ratio_to_confidence(valid_ratio),
        compatible_type = TRUE,
        valid_ratio = valid_ratio
    )
}

finalize_value_result <- function(result, sampled_n) {
    valid_ratio <- suppressWarnings(as.numeric(result$valid_ratio))
    if (length(valid_ratio) != 1L || is.na(valid_ratio)) {
        valid_ratio <- 0
    }

    if (valid_ratio < 0.30) {
        return(list(
            score = 0,
            reason = "veto_low_validation",
            compatible_type = isTRUE(result$compatible_type),
            sampled_n = as.integer(sampled_n),
            valid_ratio = valid_ratio
        ))
    }

    list(
        score = result$score,
        reason = if (valid_ratio >= 0.80) "content_validated" else "weak_content_validation",
        compatible_type = isTRUE(result$compatible_type),
        sampled_n = as.integer(sampled_n),
        valid_ratio = valid_ratio
    )
}

classify_automap_status <- function(final_score, compatible_type = TRUE) {
    if (is.na(final_score)) {
        return("MANUAL")
    }

    if (final_score >= 0.90 && isTRUE(compatible_type)) {
        return("AUTO")
    }

    if (final_score >= 0.75) {
        return("SUGERIDO")
    }

    "MANUAL"
}

count_relevant_tokens <- function(x) {
    length(tokenize_for_overlap(x))
}

# Identifier columns: the shared "id" token alone made location_id,
# species_id and study_id tie for locationID. The qualifier before "id" names
# the entity, so it decides which identifier term the column can fill.
rostrum_id_tokens <- c("id", "identifier", "identificador", "codigo", "cod")
rostrum_id_entities <- list(
    occurrence = c("occurrence", "ocorrencia"),
    location = c("location", "localidade", "local", "site", "sitio", "station", "estacao",
                 "plot", "parcela", "point", "ponto", "trap", "armadilha", "road", "rodovia",
                 "transect", "transecto", "trail", "trilha"),
    event = c("event", "evento", "survey", "campanha", "sampling", "amostragem", "visit", "visita"),
    person = c("identified", "determiner", "determinador", "collector", "coletor",
               "observer", "observador", "person", "pessoa"),
    other = c("taxon", "species", "especie", "study", "estudo", "reference", "referencia", "ref",
              "project", "projeto", "dataset", "individual", "organism", "animal", "tag",
              "record", "registro", "photo", "foto")
)
rostrum_id_term_entity <- c(
    occurrenceID = "occurrence", locationID = "location",
    eventID = "event", parentEventID = "event", identifiedByID = "person"
)
# Terms that can hold a code. Any other term on an identifier column is a
# name coincidence (location_id -> locationRemarks, Event_ID -> eventTime).
rostrum_id_accepting_terms <- c(
    names(rostrum_id_term_entity), "catalogNumber", "recordNumber",
    "associatedMedia", "associatedReferences"
)

# Returns NULL when the column name is not an identifier name, else whether
# the "id" stands alone and which entities the qualifier tokens name.
rostrum_identifier_entities <- function(col_tokens) {
    if (!any(col_tokens %in% rostrum_id_tokens)) {
        return(NULL)
    }
    qualifier <- setdiff(col_tokens, rostrum_id_tokens)
    hits <- vapply(rostrum_id_entities, function(words) any(qualifier %in% words), logical(1))
    list(bare = length(qualifier) == 0L, entities = names(rostrum_id_entities)[hits])
}

# +0.10 name evidence when the qualifier names only the term's own entity
# (location_id, Road_ID -> locationID).
rostrum_identifier_name_bonus <- function(col_tokens, term) {
    own <- rostrum_id_term_entity[as.character(term)]
    if (is.na(own)) {
        return(0)
    }
    id_parts <- rostrum_identifier_entities(col_tokens)
    if (!is.null(id_parts) && identical(id_parts$entities, own[[1]])) 0.10 else 0
}

apply_semantic_penalties <- function(col_name, term) {
    col_norm <- normalize_for_matching(col_name)
    term_name <- as.character(term)

    penalties <- numeric(0)
    reason_codes <- character(0)

    id_parts <- rostrum_identifier_entities(tokenize_for_overlap(col_name))
    if (!is.null(id_parts)) {
        # A bare "id" identifies the row, so it is only an occurrenceID.
        own <- unname(rostrum_id_term_entity[term_name])
        foreign_id <- !is.na(own) && (
            (id_parts$bare && own != "occurrence") ||
                (length(id_parts$entities) > 0L && !(own %in% id_parts$entities))
        )
        if (foreign_id || !(term_name %in% rostrum_id_accepting_terms)) {
            penalties <- c(penalties, -0.30)
            reason_codes <- c(reason_codes, "identifier_context")
        }
    }

    is_coordinate_term <- term_name %in% c("decimalLatitude", "decimalLongitude")
    is_temporal_term <- term_name %in% c("eventDate", "year", "month", "day", "modified", "dateIdentified")

    if (is_coordinate_term && grepl("\\b(temp|temperatura)\\b", col_norm, perl = TRUE)) {
        penalties <- c(penalties, -0.30)
        reason_codes <- c(reason_codes, "temp_context")
    }

    if (is_coordinate_term && grepl("\\b(depth|profund|altura)\\b", col_norm, perl = TRUE)) {
        penalties <- c(penalties, -0.30)
        reason_codes <- c(reason_codes, "depth_context")
    }

    if (is_temporal_term && grepl("\\b(count|numero|qtd|quantidade)\\b", col_norm, perl = TRUE)) {
        penalties <- c(penalties, -0.20)
        reason_codes <- c(reason_codes, "count_context")
    }

    if (grepl("^((campo|col|column|field|var)[ _-]*[0-9]+|col_[a-z0-9]+)$", col_norm, perl = TRUE)) {
        penalties <- c(penalties, -0.10)
        reason_codes <- c(reason_codes, "generic_name")
    }

    total_penalty <- if (length(penalties) > 0L) sum(penalties) else 0
    total_penalty <- pmax(-0.50, pmin(0, total_penalty))

    list(
        score = as.numeric(total_penalty),
        reasons = unique(reason_codes)
    )
}

resolve_candidate_veto_code <- function(term, value_res) {
    if (identical(value_res$reason, "empty_column")) {
        return("empty_column")
    }

    if (identical(value_res$reason, "veto_low_validation")) {
        return("low_validation")
    }

    if (!isTRUE(value_res$compatible_type) &&
        term %in% c("decimalLatitude", "decimalLongitude", "individualCount", "year", "month", "day")) {
        return("type_incompatible")
    }

    if (!is.null(value_res$valid_ratio) &&
        !is.na(value_res$valid_ratio) &&
        value_res$valid_ratio < 0.30) {
        return("low_validation")
    }

    ""
}

resolve_reason_code <- function(
  name_reason,
  value_reason,
  status,
  compatible_type,
  is_temporal_limited = FALSE,
  penalty_score = 0,
  veto_code = ""
) {
    if (!is_blank_value(veto_code)) {
        return("veto_hard")
    }

    if (identical(status, "EDITADO")) {
        return("manual_adjust")
    }

    if (identical(status, "AMBIGUO")) {
        return("ambiguity_detected")
    }

    if (!isTRUE(compatible_type) && identical(status, "SUGERIDO")) {
        return("type_incompatible")
    }

    if (isTRUE(is_temporal_limited) && identical(status, "MANUAL")) {
        return("temporal_manual_only")
    }

    if (identical(name_reason, "exact_match")) {
        return("exact_match")
    }

    if (identical(name_reason, "known_synonym")) {
        return("known_synonym")
    }

    if (identical(name_reason, "token_overlap")) {
        return("token_overlap")
    }

    if (identical(name_reason, "text_similarity")) {
        return("text_similarity")
    }

    if (penalty_score < 0) {
        return("semantic_penalty")
    }

    if (identical(value_reason, "content_validated")) {
        return("content_validated")
    }

    if (identical(value_reason, "empty_column")) {
        return("empty_column")
    }

    if (identical(value_reason, "low_name_confidence")) {
        return("low_name_confidence")
    }

    "low_confidence"
}

build_matching_profile <- function(x) {
    list(
        norm = normalize_for_matching(x),
        tokens = tokenize_for_overlap(x)
    )
}

# Abbreviations in survey headers (ADR-139).
rostrum_column_abbreviations <- c(
    inds = "individuals", indiv = "individuals",
    eff = "effort", veg = "vegetation", sp = "species", spp = "species"
)
# "#", "n" and "num" read as "number" only for synonym lookup ("# of inds." ->
# "number of individuals"). As a token, "number" would match catalogNumber.
rostrum_number_abbreviations <- c("n", "num", "nr", "nro")

rostrum_expand_column_name <- function(col_name, numbers = TRUE) {
    x <- as.character(col_name)
    if (numbers) {
        x <- gsub("#", " number ", x, fixed = TRUE)
    }
    words <- strsplit(normalize_for_matching(x), " ", fixed = TRUE)[[1]]
    hit <- words %in% names(rostrum_column_abbreviations)
    words[hit] <- rostrum_column_abbreviations[words[hit]]
    if (numbers) {
        words[words %in% rostrum_number_abbreviations] <- "number"
    }
    paste(words, collapse = " ")
}

# Column profile with the expanded name. norm_expanded is set only when an
# abbreviation changed the name, so a synonym hit through it is known.
build_column_matching_profile <- function(col_name) {
    profile <- build_matching_profile(col_name)
    expanded <- rostrum_expand_column_name(col_name)
    if (nzchar(expanded) && !identical(expanded, profile$norm)) {
        profile$norm_expanded <- expanded
        profile$tokens <- tokenize_for_overlap(rostrum_expand_column_name(col_name, numbers = FALSE))
    }
    profile
}

rostrum_debug_enabled <- function(options = NULL) {
    opt_debug <- isTRUE(getOption("saira.rostrum.debug", FALSE))
    if (is.list(options) && !is.null(options$debug)) {
        opt_debug <- opt_debug || isTRUE(options$debug)
    }
    opt_debug
}

rostrum_debug_log <- function(..., options = NULL) {
    if (!rostrum_debug_enabled(options)) {
        return(invisible(NULL))
    }
    message("[rostrum] ", paste0(..., collapse = ""))
    invisible(NULL)
}

rostrum_stage1_sample_tier <- function(name_score) {
    score <- suppressWarnings(as.numeric(name_score))
    if (!is.finite(score)) {
        return("low")
    }
    if (score >= 0.90) {
        return("high")
    }
    if (score >= 0.75) {
        return("mid")
    }
    "low"
}

rostrum_build_tier_value_cache <- function(sampled_values) {
    sampled_n <- length(sampled_values)
    if (sampled_n == 0L) {
        empty <- list(
            score = 0,
            reason = "empty_column",
            compatible_type = FALSE,
            sampled_n = 0L,
            valid_ratio = 0
        )
        return(list(
            decimalLatitude = empty,
            decimalLongitude = empty,
            scientificName = empty,
            individualCount = empty,
            occurrenceStatus = empty,
            basisOfRecord = empty,
            neutral = empty
        ))
    }

    list(
        decimalLatitude = finalize_value_result(
            validate_numeric_range(sampled_values, -90, 90),
            sampled_n = sampled_n
        ),
        decimalLongitude = finalize_value_result(
            validate_numeric_range(sampled_values, -180, 180),
            sampled_n = sampled_n
        ),
        scientificName = finalize_value_result(
            validate_scientific_name_pattern(sampled_values),
            sampled_n = sampled_n
        ),
        individualCount = finalize_value_result(
            validate_individual_count(sampled_values),
            sampled_n = sampled_n
        ),
        occurrenceStatus = finalize_value_result(
            validate_vocabulary(map_occurrence_status_values(sampled_values) %in% c("present", "absent")),
            sampled_n = sampled_n
        ),
        basisOfRecord = finalize_value_result(
            validate_vocabulary(nzchar(auto_suggest_basis_of_record_terms(sampled_values))),
            sampled_n = sampled_n
        ),
        neutral = list(
            score = 0.80,
            reason = "neutral_no_validator",
            compatible_type = TRUE,
            sampled_n = sampled_n,
            valid_ratio = 0.80
        )
    )
}

rostrum_build_column_value_profile <- function(values, max_sample_n = 1000L) {
    values_chr <- as.character(values)
    values_chr[is.na(values)] <- NA_character_
    values_chr <- trimws(values_chr)
    non_blank <- values_chr[!is.na(values_chr) & nzchar(values_chr)]

    if (length(non_blank) == 0L) {
        empty <- rostrum_build_tier_value_cache(character(0))
        return(list(
            has_non_blank = FALSE,
            tier_cache = list(high = empty, mid = empty, low = empty)
        ))
    }

    high_values <- sample_values_for_scoring(values_chr, name_score = 0.95, max_sample_n = max_sample_n)
    mid_values <- sample_values_for_scoring(values_chr, name_score = 0.80, max_sample_n = max_sample_n)
    low_values <- sample_values_for_scoring(values_chr, name_score = 0.50, max_sample_n = max_sample_n)

    list(
        has_non_blank = TRUE,
        tier_cache = list(
            high = rostrum_build_tier_value_cache(high_values),
            mid = rostrum_build_tier_value_cache(mid_values),
            low = rostrum_build_tier_value_cache(low_values)
        )
    )
}

compute_value_score_from_profile <- function(value_profile, term, name_score) {
    if (!isTRUE(value_profile$has_non_blank)) {
        return(list(
            score = 0,
            reason = "empty_column",
            compatible_type = FALSE,
            sampled_n = 0L,
            valid_ratio = 0
        ))
    }

    if (name_score < 0.45) {
        return(list(
            score = 0,
            reason = "low_name_confidence",
            compatible_type = TRUE,
            sampled_n = 0L,
            valid_ratio = 0
        ))
    }

    tier <- rostrum_stage1_sample_tier(name_score)
    tier_cache <- value_profile$tier_cache[[tier]]
    term_name <- as.character(term)

    if (term_name %in% c("decimalLatitude", "decimalLongitude", "scientificName", "individualCount")) {
        return(tier_cache[[term_name]])
    }

    # Vocabulary terms: values off the list veto a weak name (IUCN_status is
    # not an occurrenceStatus). An exact or synonym name keeps the neutral
    # score instead, because the value step translates unknown values later.
    if (term_name %in% c("occurrenceStatus", "basisOfRecord")) {
        vocab_res <- tier_cache[[term_name]]
        if (identical(tier, "high") && vocab_res$valid_ratio < 0.80) {
            return(tier_cache$neutral)
        }
        return(vocab_res)
    }

    tier_cache$neutral
}

rostrum_stage1_apply_future_plan <- function(strategy, workers, options) {
    if (identical(strategy, "multicore")) {
        can_multicore <- requireNamespace("parallelly", quietly = TRUE) &&
            parallelly::supportsMulticore()
        if (can_multicore) {
            future::plan(future::multicore, workers = workers)
        } else {
            rostrum_debug_log("multicore unavailable on this platform; falling back to multisession.", options = options)
            future::plan(future::multisession, workers = workers)
        }
    } else {
        future::plan(future::multisession, workers = workers)
    }
    invisible(NULL)
}

rostrum_stage1_run_term_map <- function(terms, worker_fn, options) {
    can_parallel <- isTRUE(options$stage1_parallel) &&
        length(terms) > 1L &&
        !identical(options$stage1_parallel_strategy, "sequential")

    if (!can_parallel) {
        return(lapply(terms, worker_fn))
    }

    if (!requireNamespace("future", quietly = TRUE) || !requireNamespace("furrr", quietly = TRUE)) {
        warning(
            "stage1_parallel=TRUE, but future/furrr are unavailable. Falling back to sequential mode.",
            call. = FALSE
        )
        return(lapply(terms, worker_fn))
    }

    workers <- max(1L, min(as.integer(options$stage1_parallel_workers), length(terms)))
    rostrum_debug_log(
        "Stage 1 parallel mode enabled (strategy=",
        options$stage1_parallel_strategy,
        ", workers=",
        workers,
        ").",
        options = options
    )

    old_plan <- future::plan()
    on.exit(
        {
            future::plan(old_plan)
        },
        add = TRUE
    )

    rostrum_stage1_apply_future_plan(
        options$stage1_parallel_strategy, workers, options
    )
    furrr::future_map(
        terms,
        worker_fn,
        .options = furrr::furrr_options(seed = TRUE, scheduling = 1)
    )
}

run_rostrum_stage1 <- function(df, dwc_terms_df, synonyms_tbl, options = rostrum_options()) {
    if (!is.data.frame(df)) {
        stop("df must be a data.frame.")
    }
    if (!is.data.frame(dwc_terms_df) || !"term" %in% names(dwc_terms_df)) {
        stop("dwc_terms_df must be a data.frame with a 'term' column.")
    }
    if (!is.list(options) || is.null(options$max_sample_n)) {
        stop("options must be produced by rostrum_options().")
    }

    synonyms_index <- prepare_synonyms_for_scoring(synonyms_tbl)
    terms <- unique(as.character(dwc_terms_df$term))
    columns <- names(df)
    temporal_terms <- c("eventDate", "year", "month", "day", "modified", "dateIdentified")
    # Terms whose value comes from a dedicated input (date picker, checkbox),
    # never from a source column, so scoring them would offer a mapping the card
    # cannot accept. occurrenceID is not one of them: it takes a real column,
    # and an upload that ships identifiers -- a re-imported Saira export, an
    # already-standardized DwC file -- must have them found rather than left for
    # the user to notice and wire up by hand.
    manual_only_terms <- c("modified", "license", "language")
    prune_threshold <- suppressWarnings(as.numeric(options$stage1_name_prune_threshold))
    if (!is.finite(prune_threshold)) {
        prune_threshold <- 0.45
    }

    column_profiles <- stats::setNames(
        lapply(columns, build_column_matching_profile),
        columns
    )
    term_profiles <- stats::setNames(
        lapply(terms, build_matching_profile),
        terms
    )
    # Term whose name equals the column name, NA when there is none.
    column_exact_owner <- stats::setNames(
        terms[match(
            vapply(column_profiles, function(p) p$norm, character(1)),
            vapply(term_profiles, function(p) p$norm, character(1))
        )],
        columns
    )
    value_profiles <- stats::setNames(
        lapply(columns, function(col_name) {
            rostrum_build_column_value_profile(
                values = df[[col_name]],
                max_sample_n = options$max_sample_n
            )
        }),
        columns
    )

    rostrum_debug_log(
        "Stage 1 prepared ",
        length(terms),
        " terms and ",
        length(columns),
        " columns (prune threshold=",
        format(prune_threshold, digits = 3),
        ").",
        options = options
    )

    # Share of values that parse as dates, computed only for the columns that
    # reach the eventDate rescue.
    date_results <- new.env(parent = emptyenv())
    column_date_result <- function(col_name) {
        if (is.null(date_results[[col_name]])) {
            sampled <- sample_values_for_scoring(df[[col_name]], name_score = 0.80,
                                                 max_sample_n = options$max_sample_n)
            # An ambiguous "03/04/2021" stays raw in the conversion but is a date.
            is_date <- !is.na(parse_dates_to_iso(sampled)) | is_ambiguous_dmy(sampled)
            date_results[[col_name]] <- finalize_value_result(validate_vocabulary(is_date),
                                                              sampled_n = length(sampled))
        }
        date_results[[col_name]]
    }

    empty_row <- function(term, reason = "no_confident_match", is_temporal_limited = FALSE) {
        data.frame(
            term = term,
            selected_col = NA_character_,
            name_score = 0,
            value_score = 0,
            penalty_score = 0,
            veto_code = "",
            final_score = 0,
            status = "MANUAL",
            reason = if (is_temporal_limited) "temporal_manual_only" else reason,
            applied = FALSE,
            compatible_type = TRUE,
            specificity = 0,
            alternatives_json = "[]",
            explain_json = "{}",
            stringsAsFactors = FALSE
        )
    }

    term_worker <- function(term) {
        if (term %in% manual_only_terms) {
            return(data.frame(
                term = term,
                selected_col = NA_character_,
                name_score = NA_real_,
                value_score = NA_real_,
                penalty_score = 0,
                veto_code = "",
                final_score = NA_real_,
                status = "MANUAL",
                reason = "manual_only_term",
                applied = FALSE,
                compatible_type = TRUE,
                specificity = 0,
                alternatives_json = "[]",
                explain_json = "{}",
                stringsAsFactors = FALSE
            ))
        }

        if (length(columns) == 0) {
            return(empty_row(term, reason = "no_columns_available", is_temporal_limited = FALSE))
        }

        is_temporal_limited <- term %in% temporal_terms
        term_profile <- term_profiles[[term]]

        candidate_rows <- lapply(columns, function(col_name) {
            # A column named exactly like another term belongs to that term, so
            # "locationRemarks" does not tie with "OBS" for occurrenceRemarks.
            owner <- column_exact_owner[[col_name]]
            if (!is.na(owner) && !identical(owner, term)) {
                return(NULL)
            }
            col_profile <- column_profiles[[col_name]]
            name_res <- compute_name_score(
                col_name = col_name,
                term = term,
                synonyms_tbl = NULL,
                col_profile = col_profile,
                term_profile = term_profile,
                synonyms_index = synonyms_index
            )

            # Temporal terms need an exact name. eventDate also takes a synonym
            # or token-overlap name when most values parse as dates (ADR-139).
            date_rescue <- FALSE
            if (is_temporal_limited && !isTRUE(name_res$is_exact)) {
                if (!identical(term, "eventDate") || name_res$score < prune_threshold ||
                    column_date_result(col_name)$valid_ratio < 0.90) {
                    return(NULL)
                }
                date_rescue <- TRUE
            }

            if (!isTRUE(name_res$is_exact) &&
                !identical(name_res$reason, "known_synonym") &&
                name_res$score < prune_threshold) {
                return(NULL)
            }

            value_res <- if (date_rescue) {
                column_date_result(col_name)
            } else {
                compute_value_score_from_profile(
                    value_profile = value_profiles[[col_name]],
                    term = term,
                    name_score = name_res$score
                )
            }
            if (identical(name_res$reason, "token_overlap") &&
                name_res$score <= 0.70 &&
                value_res$score < options$token_overlap_min_value_score) {
                return(NULL)
            }

            penalty_res <- apply_semantic_penalties(col_name, term)
            veto_code <- resolve_candidate_veto_code(term = term, value_res = value_res)

            base_score <- (0.5 * name_res$score) + (0.5 * value_res$score)
            final_score <- base_score + penalty_res$score
            final_score <- pmin(1, pmax(0, final_score))
            # Offered for review, never AUTO: a one-letter header, a header
            # read through an abbreviation, a date column found by its values.
            if (date_rescue || isTRUE(name_res$via_expansion) || nchar(col_profile$norm) == 1L) {
                final_score <- min(final_score, options$auto_apply_threshold - 0.01)
            }

            if (!is_blank_value(veto_code)) {
                final_score <- 0
            }

            status <- classify_automap_status(final_score, compatible_type = value_res$compatible_type)
            applied <- status %in% c("AUTO", "SUGERIDO")

            if (!is_blank_value(veto_code)) {
                status <- "MANUAL"
                applied <- FALSE
            }

            reason <- resolve_reason_code(
                name_reason = name_res$reason,
                value_reason = value_res$reason,
                status = status,
                compatible_type = value_res$compatible_type,
                is_temporal_limited = is_temporal_limited,
                penalty_score = penalty_res$score,
                veto_code = veto_code
            )

            explain_json <- jsonlite::toJSON(
                list(
                    name_reason = name_res$reason,
                    value_reason = value_res$reason,
                    exact_hits = as.integer(name_res$exact_hits),
                    substring_hits = as.integer(name_res$substring_hits),
                    valid_ratio = suppressWarnings(as.numeric(value_res$valid_ratio)),
                    penalty_reasons = penalty_res$reasons,
                    veto_code = veto_code
                ),
                auto_unbox = TRUE,
                null = "null"
            )

            data.frame(
                term = term,
                selected_col = as.character(col_name),
                name_score = as.numeric(name_res$score),
                value_score = as.numeric(value_res$score),
                penalty_score = as.numeric(penalty_res$score),
                veto_code = as.character(veto_code),
                final_score = as.numeric(final_score),
                status = status,
                reason = reason,
                applied = applied,
                compatible_type = isTRUE(value_res$compatible_type),
                specificity = count_relevant_tokens(col_name),
                alternatives_json = "[]",
                explain_json = explain_json,
                stringsAsFactors = FALSE
            )
        })

        pruned_pairs <- sum(vapply(candidate_rows, is.null, FUN.VALUE = logical(1)))
        candidate_rows <- Filter(Negate(is.null), candidate_rows)
        rostrum_debug_log(
            "Stage 1 term '", term,
            "': candidates=", length(candidate_rows),
            ", pruned=", pruned_pairs,
            ".",
            options = options
        )

        if (length(candidate_rows) == 0) {
            return(empty_row(term, is_temporal_limited = is_temporal_limited))
        }

        candidates_df <- do.call(rbind, candidate_rows)
        ordering <- order(
            -candidates_df$final_score,
            -candidates_df$value_score,
            -candidates_df$specificity
        )
        ordered_df <- candidates_df[ordering, , drop = FALSE]
        best <- ordered_df[1, , drop = FALSE]

        top_n <- min(3L, nrow(ordered_df))
        alternatives_payload <- lapply(seq_len(top_n), function(i) {
            list(
                column_name = as.character(ordered_df$selected_col[[i]]),
                final_score = as.numeric(ordered_df$final_score[[i]]),
                name_score = as.numeric(ordered_df$name_score[[i]]),
                value_score = as.numeric(ordered_df$value_score[[i]])
            )
        })
        best$alternatives_json <- jsonlite::toJSON(alternatives_payload, auto_unbox = TRUE)

        if (nrow(ordered_df) >= 2L) {
            score_gap <- abs(ordered_df$final_score[[1]] - ordered_df$final_score[[2]])
            if (is.finite(score_gap) && score_gap < 0.10 && ordered_df$final_score[[1]] >= 0.75) {
                best$status <- "AMBIGUO"
                best$applied <- FALSE
                best$selected_col <- NA_character_
                best$reason <- "ambiguity_detected"
            }
        }

        if (!isTRUE(best$compatible_type) && identical(best$status, "AUTO")) {
            best$status <- "SUGERIDO"
            best$applied <- TRUE
            best$reason <- "type_incompatible"
        }

        if (best$final_score < 0.75 && !identical(best$status, "AMBIGUO")) {
            best$status <- "MANUAL"
            best$applied <- FALSE
            best$selected_col <- NA_character_
            if (!is_temporal_limited) {
                best$reason <- "no_confident_match"
            }
        }

        best
    }

    term_results <- rostrum_stage1_run_term_map(
        terms = terms,
        worker_fn = term_worker,
        options = options
    )

    results_df <- do.call(rbind, term_results)

    applied_idx <- which(results_df$applied & !is.na(results_df$selected_col) & nzchar(results_df$selected_col))
    if (length(applied_idx) > 1) {
        applied_cols <- unique(results_df$selected_col[applied_idx])
        for (col_name in applied_cols) {
            idx <- which(results_df$selected_col == col_name & results_df$applied)
            if (length(idx) <= 1) {
                next
            }

            tie_order <- order(
                -results_df$final_score[idx],
                -results_df$value_score[idx],
                -results_df$specificity[idx]
            )
            keep_idx <- idx[tie_order[1]]
            lose_idx <- setdiff(idx, keep_idx)

            results_df$status[lose_idx] <- "MANUAL"
            results_df$applied[lose_idx] <- FALSE
            results_df$reason[lose_idx] <- "conflict_lost"
            results_df$selected_col[lose_idx] <- NA_character_
        }
    }

    keep_cols <- c(
        "term",
        "selected_col",
        "name_score",
        "value_score",
        "penalty_score",
        "veto_code",
        "final_score",
        "status",
        "reason",
        "applied",
        "alternatives_json",
        "explain_json"
    )
    results_df[, keep_cols, drop = FALSE]
}

fill_missing_character_values <- function(existing_values, fallback_values) {
    if (length(existing_values) != length(fallback_values)) {
        stop("existing_values and fallback_values must have same length.")
    }

    existing_chr <- as.character(existing_values)
    fallback_chr <- as.character(fallback_values)
    fallback_chr[is.na(fallback_values)] <- NA_character_

    missing_idx <- is.na(existing_values) | nchar(trimws(existing_chr)) == 0
    existing_chr[missing_idx] <- fallback_chr[missing_idx]
    existing_chr
}

replace_na_with_blank <- function(df) {
    for (col_name in names(df)) {
        values <- df[[col_name]]

        if (is.factor(values)) {
            values <- as.character(values)
        }

        if (!is.character(values)) {
            values <- as.character(values)
        }

        values[is.na(values)] <- ""
        df[[col_name]] <- values
    }

    df
}

# Darwin Core terms that hold a list, where " | " is the recommended
# separator. In any other term a ";" is prose ("linha 2 com; separador") and
# stays as typed (B40).
dwc_list_terms <- c(
    "recordedBy", "recordedByID", "identifiedBy", "identifiedByID", "associatedMedia",
    "associatedReferences", "associatedSequences", "associatedTaxa", "associatedOccurrences",
    "associatedOrganisms", "otherCatalogNumbers", "preparations", "typeStatus",
    "georeferencedBy", "georeferenceSources", "previousIdentifications", "higherClassification",
    "sex", "lifeStage", "vernacularName"
)

normalize_semicolon_tokens <- function(x, out_sep = " | ", split = TRUE) {
    x_chr <- as.character(x)
    # Vectorized fast path: the overwhelming majority of cells hold a single
    # value with no ";" separator, so resolve those with one vectorized trim
    # (blank -> NA, matching is_blank_value/split_semicolon_tokens). Only the
    # cells that actually contain ";" need the per-cell split/rejoin. This is the
    # difference between ~15 s and < 1 s for a large multi-column dataset, since
    # base trimws() runs match.arg + a regex sub on every call.
    trimmed <- trimws(x_chr)
    out <- trimmed
    out[is.na(x_chr) | !nzchar(trimmed)] <- NA_character_

    multi <- split & !is.na(out) & grepl(";", out, fixed = TRUE)
    if (any(multi)) {
        out[multi] <- vapply(
            x_chr[multi],
            FUN = function(value) {
                tokens <- split_semicolon_tokens(value)
                if (length(tokens) == 0) {
                    return(NA_character_)
                }
                paste(tokens, collapse = out_sep)
            },
            FUN.VALUE = character(1)
        )
    }
    unname(out)
}

collapse_mapped_values <- function(df, cols, out_sep = " | ") {
    if (length(cols) == 0) {
        return(rep(NA_character_, nrow(df)))
    }

    missing_cols <- setdiff(cols, names(df))
    if (length(missing_cols) > 0) {
        stop("Columns not found in data frame: ", paste(missing_cols, collapse = ", "))
    }

    normalized_cols <- lapply(cols, function(col_name) {
        normalize_semicolon_tokens(df[[col_name]], out_sep = out_sep)
    })

    # Single source column (the common case) is already normalized -- skip the
    # per-row re-split/re-join entirely.
    if (length(normalized_cols) == 1L) {
        return(normalized_cols[[1]])
    }

    # One vectorized pass per COLUMN instead of a scalar pass per ROW. The old
    # loop called split_output_tokens once per cell, and each of those runs
    # strsplit + trimws (which is match.arg + a perl sub) -- on a 21.5k-row
    # dataset with four multi-column terms that was ~37 s of the ~52 s spent
    # rebuilding the mapped frame, and it is why the mapping screen stalled.
    # Equivalence rests on normalize_semicolon_tokens() having already trimmed
    # each cell and turned blanks into NA, so the only cells that still need
    # token surgery are the ones that literally contain out_sep.
    normalized_cols <- lapply(
        normalized_cols, clean_out_sep_tokens, out_sep = out_sep
    )

    out <- rep(NA_character_, nrow(df))
    for (col_values in normalized_cols) {
        has_value <- !is.na(col_values)
        if (!any(has_value)) next
        append_to <- has_value & !is.na(out)
        out[append_to] <- paste(out[append_to], col_values[append_to], sep = out_sep)
        seed <- has_value & is.na(out)
        out[seed] <- col_values[seed]
    }
    out
}

# Drop empty tokens from cells that already carry out_sep, keeping the per-cell
# split for exactly those cells (same shape as normalize_semicolon_tokens): a
# value like "a |  | b" collapses to "a | b", and one that is all separators
# becomes NA. Everything else is untouched, because it was trimmed upstream.
clean_out_sep_tokens <- function(x, out_sep = " | ") {
    idx <- which(!is.na(x) & grepl(out_sep, x, fixed = TRUE))
    if (length(idx) == 0L) {
        return(x)
    }
    x[idx] <- vapply(
        x[idx],
        FUN = function(value) {
            parts <- trimws(strsplit(value, out_sep, fixed = TRUE)[[1]])
            parts <- parts[nzchar(parts)]
            if (length(parts) == 0L) {
                return(NA_character_)
            }
            paste(parts, collapse = out_sep)
        },
        FUN.VALUE = character(1),
        USE.NAMES = FALSE
    )
    x
}

#' Map raw values to DwC occurrenceStatus literals
#'
#' Coerces common presence/absence representations (0/1, sim/nao, si/no, yes/no,
#' presente/ausente, present/absent, TRUE/FALSE) to canonical DwC values
#' "present" or "absent" for export. Convention: 0 = absent, 1 = present.
#' Unrecognized non-empty values pass through after trim. NA / empty stay NA.
#'
#' @param raw_values Character/numeric/logical vector from the source column.
#' @return Character vector of the same length.
#' @export
map_occurrence_status_values <- function(raw_values) {
    if (is.null(raw_values)) return(character(0))
    x <- trimws(as.character(raw_values))
    out <- x
    norm <- tolower(x)

    present_set <- c("1", "present", "presente", "yes", "y", "sim", "s", "si", "s\u00ed", "true", "t")
    absent_set  <- c("0", "absent", "ausente", "no", "n", "nao", "n\u00e3o", "false", "f")

    out[norm %in% present_set] <- "present"
    out[norm %in% absent_set]  <- "absent"

    na_mask <- is.na(raw_values) | !nzchar(x)
    out[na_mask] <- NA_character_
    out
}

# Pure per-term column builder. Called by build_processed_mapping_df and by the
# card inline preview helper (processed_preview_for_term in mod_mapping).
# Returns list(values = <character vector>, eventdate_failure_count = <int>).
build_term_value <- function(
    term,
    df,
    user_cols,
    basis_of_record_map = NULL,
    dyn_props_keys = list(),
    out_sep = " | "
) {
    failure_count <- 0L

    if (term == "basisOfRecord") {
        values <- map_basis_of_record_values(
            raw_values = df[[user_cols[[1]]]],
            basis_of_record_map = basis_of_record_map
        )
    } else if (term == "occurrenceStatus") {
        values <- map_occurrence_status_values(df[[user_cols[[1]]]])
        values <- map_vocabulary_values(term, values)
    } else if (term %in% c("sex", "lifeStage") && length(user_cols) == 1) {
        # Known spreadsheet words become GBIF vocabulary concepts ("M" -> male).
        # Unknown ones keep their text and reach the user in the Preview.
        values <- map_vocabulary_values(
            term, normalize_semicolon_tokens(df[[user_cols[[1]]]], out_sep = out_sep)
        )
    } else if (term == "dynamicProperties") {
        values <- build_dynamic_properties_json(df = df, cols = user_cols, keys = dyn_props_keys)
    } else if (term == "eventDate" && length(user_cols) == 6) {
        # Day, month and year for each end of a range. Falls through to the
        # generic collapse when the six columns are not a date interval.
        interval <- build_eventdate_interval_dmy(df = df, cols = user_cols, fallback_raw = TRUE)
        if (is.null(interval)) {
            values <- collapse_mapped_values(df = df, cols = user_cols, out_sep = out_sep)
        } else {
            values <- interval$values
            failure_count <- interval$failure_count
        }
    } else if (term == "eventDate" && length(user_cols) == 4) {
        event_result <- build_eventdate_interval(df = df, cols = user_cols, fallback_raw = TRUE)
        values <- event_result$values
        failure_count <- event_result$failure_count
    } else if (term == "eventDate" && length(user_cols) %in% c(2L, 3L)) {
        # Day/month/year in separate columns describe ONE date, so they compose
        # into ISO 8601 instead of being pipe-joined like any other multi-column
        # term. A selection the composer does not recognise keeps that generic
        # collapse.
        parts <- build_eventdate_from_parts(df = df, cols = user_cols, fallback_raw = TRUE)
        if (is.null(parts)) {
            values <- collapse_mapped_values(df = df, cols = user_cols, out_sep = out_sep)
        } else {
            values <- parts$values
            failure_count <- parts$failure_count
        }
    } else if (length(user_cols) == 1) {
        values <- normalize_semicolon_tokens(df[[user_cols[[1]]]], out_sep = out_sep,
                                             split = term %in% dwc_list_terms)
    } else {
        values <- collapse_mapped_values(df = df, cols = user_cols, out_sep = out_sep)
    }

    # Normalise to ISO 8601 (YYYY-MM-DD) for date-typed DWC terms so the card
    # preview matches what the export pipeline emits via fix_dates_to_iso().
    # Unparseable values (already-correct intervals "YYYY-MM/YYYY-MM", partial
    # dates like "2026", or invalid text) keep their raw value.
    if (term %in% c("eventDate", "dateIdentified", "modified")) {
        parsed <- parse_dates_to_iso(values)
        keep_raw <- is.na(parsed) & !is.na(values) & nzchar(values)
        parsed[keep_raw] <- values[keep_raw]
        values <- parsed
    }

    # DMS, a hemisphere letter or a Unicode minus become decimal degrees, so
    # the Coordinates tab, the mask and the export read a number (B08).
    if (term %in% c("decimalLatitude", "decimalLongitude")) {
        values <- convert_coordinate_text(values, if (term == "decimalLatitude") "lat" else "lon")
    }

    list(values = values, eventdate_failure_count = failure_count)
}

# The license and language cards take a fixed value, not a column, so the
# Rostrum engine does not score them (manual_only_terms). A spreadsheet can
# have both as columns ("Licenca", "dcterms:license", "Idioma"). When every
# filled cell of the column holds the same value, and the card offers that
# value, it fills the card, and the card is no longer a pending required
# term. Returns a list with `license` and `language` when found.
card_values_from_columns <- function(df) {
    out <- list()
    if (!is.data.frame(df)) return(out)
    headers <- sub("^(dcterms|dc) ", "", normalize_for_matching(names(df)))
    single_value <- function(names_in) {
        col <- which(headers %in% names_in)
        if (length(col) != 1L) return(NA_character_)
        v <- unique(trimws(as.character(df[[col]])))
        v <- v[!is.na(v) & nzchar(v)]
        if (length(v) == 1L) v else NA_character_
    }
    # "CC-BY-NC 4.0" and "CC BY NC" are spellings people type.
    lic <- single_value(c("license", "licence", "licenca", "licencia"))
    key <- normalize_license_key(gsub("[ _-]+", "-", tolower(lic)))
    if (!is.na(key)) out$license <- unname(cc_license_names()[[key]])
    # The language card offers pt, en and es. "pt-BR" is pt.
    lang_codes <- c(
        pt = "pt", por = "pt", portugues = "pt", portuguese = "pt",
        en = "en", eng = "en", english = "en", ingles = "en",
        es = "es", spa = "es", espanol = "es", spanish = "es"
    )
    lang <- sub(" .*$", "", normalize_for_matching(single_value(c("language", "idioma", "lingua"))))
    lang <- unname(lang_codes[lang])
    if (!is.na(lang)) out$language <- lang
    out
}

# Detect raw/source columns selected for more than one Darwin Core term. Mapping
# one column to several terms is allowed (the same value is published under each),
# but it is usually a mistake worth flagging -- e.g. a camera-trap `type` column
# left on both `basisOfRecord` and `type`. Returns a named list keyed by the
# shared source column, each holding the character vector of terms that use it
# (only columns used by >= 2 terms); an empty list when there are no collisions.
# `exclude` drops terms that do not draw from a source column (constants such as
# license/language, the generated occurrenceID).
detect_duplicate_source_mappings <- function(map_values, exclude = character(0)) {
    if (!is.list(map_values) || length(map_values) == 0L) {
        return(list())
    }
    terms <- setdiff(names(map_values), exclude)
    # `verbatim*` terms intentionally mirror a source column (the raw value kept
    # alongside its parsed term, e.g. verbatimEventDate next to eventDate), so a
    # column shared with one of them is expected, not a mistake -- never flag it.
    terms <- terms[!grepl("verbatim", terms, ignore.case = TRUE)]
    cols <- character(0)
    tms <- character(0)
    for (term in terms) {
        v <- map_values[[term]]
        if (is.null(v)) next
        v <- as.character(v)
        v <- v[!is.na(v)]
        if (length(v) == 0L) next
        v <- trimws(v[[1]])
        if (!nzchar(v)) next
        cols <- c(cols, v)
        tms <- c(tms, term)
    }
    if (length(cols) == 0L) {
        return(list())
    }
    dup_cols <- unique(cols[duplicated(cols)])
    if (length(dup_cols) == 0L) {
        return(list())
    }
    stats::setNames(lapply(dup_cols, function(col) tms[cols == col]), dup_cols)
}

#' Terms whose fixed value overrode a mapped source column
#'
#' `build_processed_mapping_df()` lets an enabled fixed value win over a column
#' mapping and then never reads the column. Naming those terms in one place is
#' what lets the export hand the orphaned column back at the end of the CSV,
#' and the mapping guide report it as unused instead of published.
#'
#' @param constant_values Named list of fixed values keyed by DwC term, as
#'   `custom_values_r` returns it (`constant_value_terms()` plus `datasetName`,
#'   `license`, `language` and `modified`).
#' @return Character vector of DwC term names, possibly empty.
#' @noRd
overridden_mapping_terms <- function(constant_values = list()) {
    if (!is.list(constant_values) || length(constant_values) == 0L) {
        return(character(0))
    }
    filled <- vapply(constant_values, function(v) {
        if (is.null(v) || length(v) == 0L) {
            return(FALSE)
        }
        v <- trimws(as.character(v)[[1]])
        !is.na(v) && nzchar(v)
    }, logical(1))
    unique(names(constant_values)[filled])
}

build_processed_mapping_df <- function(
  df,
  dwc_terms,
  map_values,
  occurrence_ids,
  custom_dataset_name = NULL,
  modified_use_today = FALSE,
  custom_modified_date = NULL,
  custom_license = NULL,
  custom_language = NULL,
  constant_values = list(),
  basis_of_record_map = NULL,
  now_utc = Sys.time(),
  out_sep = " | ",
  dyn_props_keys = list(),
  establishment_map = NULL
) {
    if (length(occurrence_ids) != nrow(df)) {
        stop("occurrence_ids must have the same length as nrow(df).")
    }

    df_final <- data.frame(matrix(ncol = 0, nrow = nrow(df)))
    eventdate_failure_count <- 0L
    selected_terms <- character(0)

    # Species vector backing the per-species establishment answers (ADR-110).
    # Resolved from the raw data via the scientificName mapping rather than from
    # df_final, so it does not depend on where scientificName falls in the term
    # loop. NULL means "no assistant answers to apply".
    establishment_species <- NULL
    establishment_islands <- NULL
    if (!is.null(establishment_map) && !establishment_map_is_empty(establishment_map)) {
        sci_cols <- sanitize_map_selection("scientificName", map_values[["scientificName"]])
        if (has_selected_value(sci_cols) && sci_cols[[1]] %in% names(df)) {
            establishment_species <- as.character(df[[sci_cols[[1]]]])
            establishment_islands <- establishment_island_rows_for_df(
                df, map_values, establishment_species
            )
        }
    }

    for (item in dwc_terms) {
        term <- item$term

        if (term == "occurrenceID") {
            df_final[[term]] <- occurrence_ids
            selected_terms <- c(selected_terms, term)
            next
        }

        if (term == "datasetName") {
            if (!is.null(custom_dataset_name) && nchar(trimws(custom_dataset_name)) > 0) {
                df_final[[term]] <- rep(trimws(custom_dataset_name), nrow(df))
                selected_terms <- c(selected_terms, term)
                next
            }
        }

        # modified/license/language, like datasetName above: the fixed value
        # wins, and `next` belongs INSIDE the branch that consumed it. Outside,
        # a column mapped to one of these was read by nobody and dropped by the
        # unmapped-column tail as well -- it left the export entirely.
        if (term == "modified") {
            if (isTRUE(modified_use_today)) {
                # Date only (no time/zone), matching the manual date-picker path
                # below -- the user wants a plain calendar date for `modified`.
                date_str <- format(now_utc, "%Y-%m-%d", tz = "UTC")
                df_final[[term]] <- rep(date_str, nrow(df))
                selected_terms <- c(selected_terms, term)
                next
            } else if (!is.null(custom_modified_date)) {
                date_str <- format(as.Date(custom_modified_date), "%Y-%m-%d")
                df_final[[term]] <- rep(date_str, nrow(df))
                selected_terms <- c(selected_terms, term)
                next
            }
        }

        if (term == "license") {
            if (!is.null(custom_license) && length(custom_license) > 0) {
                df_final[[term]] <- rep(custom_license[[1]], nrow(df))
                selected_terms <- c(selected_terms, term)
                next
            }
        }

        if (term == "language") {
            if (!is.null(custom_language) && length(custom_language) > 0) {
                df_final[[term]] <- rep(custom_language[[1]], nrow(df))
                selected_terms <- c(selected_terms, term)
                next
            }
        }

        # Generalized fixed values (constant_value_terms allowlist): a single
        # enabled value is replicated across every row, taking precedence over
        # any column mapping for the term.
        if (term %in% names(constant_values)) {
            value <- constant_values[[term]]
            if (!is.null(value) && nzchar(trimws(value))) {
                df_final[[term]] <- rep(trimws(value), nrow(df))
                selected_terms <- c(selected_terms, term)
                next
            }
        }

        # The two establishment terms can be filled by the per-species
        # assistant, by a mapped column, or by both. The user's own column
        # always wins; the assistant only fills the rows it left blank.
        if (term %in% c("establishmentMeans", "degreeOfEstablishment") &&
            !is.null(establishment_species)) {
            user_cols <- sanitize_map_selection(term, map_values[[term]])
            has_column <- has_selected_value(user_cols)
            merged <- build_establishment_term_value(
                term = term, df = df, user_cols = user_cols,
                species_values = establishment_species,
                establishment_map = establishment_map, out_sep = out_sep,
                island_rows = establishment_islands
            )
            if (has_column || any(nzchar(merged[!is.na(merged)]))) {
                df_final[[term]] <- merged
                selected_terms <- c(selected_terms, term)
            }
            next
        }

        user_cols <- sanitize_map_selection(term, map_values[[term]])
        if (!has_selected_value(user_cols)) {
            next
        }

        # Resolve the selection against the real column names before reading
        # anything. A term left unresolved is treated as unmapped, exactly like
        # one the user never picked.
        user_cols <- resolve_selected_columns(user_cols, names(df))
        if (!has_selected_value(user_cols)) {
            next
        }

        if (term == "scientificName" && length(user_cols) > 1) {
            user_cols <- user_cols[[1]]
        }

        # Each column of a wide sheet is its own measurement (ADR-179). One
        # frame column per source keeps the values apart for the Preview.
        if (term == "measurementValue" && length(user_cols) > 1) {
            for (col in user_cols) {
                name <- measurement_value_column(col)
                df_final[[name]] <- collapse_mapped_values(df, col, out_sep = out_sep)
                selected_terms <- c(selected_terms, name)
            }
            next
        }

        selected_terms <- c(selected_terms, term)

        term_result <- build_term_value(
            term = term,
            df = df,
            user_cols = user_cols,
            basis_of_record_map = basis_of_record_map,
            dyn_props_keys = dyn_props_keys,
            out_sep = out_sep
        )
        df_final[[term]] <- term_result$values
        eventdate_failure_count <- eventdate_failure_count + term_result$eventdate_failure_count
    }

    if ("scientificName" %in% names(df_final)) {
        scientific_parts <- extract_scientific_name_components(df_final$scientificName)
        # infraspecificEpithet is deliberately absent from selected_terms: it
        # rides on the non-missing filter below, so a dataset without a single
        # trinomial does not ship (and meta.xml does not declare) an empty
        # column. The other three are always populated, so they are pinned.
        selected_terms <- c(
            selected_terms, "genus", "specificEpithet", "taxonRank"
        )

        for (derived in derived_taxon_terms()) {
            if (!derived %in% names(df_final)) {
                df_final[[derived]] <- scientific_parts[[derived]]
            } else {
                df_final[[derived]] <- fill_missing_character_values(
                    df_final[[derived]],
                    scientific_parts[[derived]]
                )
            }
        }

        # Authorship travels in its own term, and the name keeps only the taxon
        # (ADR-123). A column the user mapped to the term wins, as with the
        # other derived taxon terms. Only rows the parser actually resolved are
        # rewritten: anything it could not read keeps its original value rather
        # than being trimmed on a guess.
        authorship <- scientific_parts$scientificNameAuthorship
        if ("scientificNameAuthorship" %in% names(df_final)) {
            df_final$scientificNameAuthorship <- fill_missing_character_values(
                df_final$scientificNameAuthorship, authorship
            )
        } else {
            df_final$scientificNameAuthorship <- authorship
        }

        # The parsed name replaces the typed one: case, double spaces, a
        # qualifier and a stray period go (B06). A name with text the parser
        # cannot read keeps its typed value.
        stripped <- scientific_name_without_authorship(scientific_parts)
        rewrite <- !is.na(stripped)
        if (any(rewrite)) {
            df_final$scientificName[rewrite] <- stripped[rewrite]
        }

        # "cf.", "aff.", "sp." and "?" go to identificationQualifier, as GBIF
        # asks. A mapped column wins, as with the other derived terms.
        qualifier <- scientific_parts$identificationQualifier
        if (any(!is.na(qualifier))) {
            df_final$identificationQualifier <- if ("identificationQualifier" %in% names(df_final)) {
                fill_missing_character_values(df_final$identificationQualifier, qualifier)
            } else {
                qualifier
            }
        }
    }

    selected_terms <- unique(selected_terms)
    non_missing_cols <- colSums(!is.na(df_final)) > 0
    keep_selected_cols <- names(df_final) %in% selected_terms
    df_final <- df_final[, non_missing_cols | keep_selected_cols, drop = FALSE]
    df_final <- replace_na_with_blank(df_final)

    list(
        data = df_final,
        eventdate_failure_count = as.integer(eventdate_failure_count)
    )
}
