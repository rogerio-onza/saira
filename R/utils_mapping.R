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
        cols <- trimws(strsplit(src, "\\s*\\+\\s*", perl = TRUE)[[1]])
        cols <- cols[nzchar(cols)]
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

normalize_basis_of_record_keys <- function(values) {
    chr <- as.character(values)
    chr[is.na(values)] <- ""
    tolower(trimws(chr))
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

auto_suggest_basis_of_record_term <- function(raw_value) {
    if (is_blank_value(raw_value)) {
        return("")
    }

    allowed_terms <- get_basis_of_record_terms()
    term_match <- match(
        tolower(trimws(as.character(raw_value)[[1]])),
        tolower(allowed_terms)
    )

    if (is.na(term_match)) {
        return("")
    }

    allowed_terms[[term_match]]
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
    if (length(keep_idx) == 0) {
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
    keys <- normalize_basis_of_record_keys(raw_chr)

    if (is.null(basis_of_record_map) || length(basis_of_record_map) == 0) {
        return(rep("", length(keys)))
    }

    clean_map <- sanitize_basis_of_record_map(basis_of_record_map)
    mapped <- unname(clean_map[keys])
    mapped[is.na(mapped)] <- ""
    mapped <- sanitize_basis_of_record_terms(mapped)
    mapped
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

normalize_species_keys <- function(values) {
    chr <- as.character(values)
    chr[is.na(values)] <- ""
    tolower(trimws(chr))
}

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

# The assistant's committed state: list(means = <named chr>, degree = <named chr>).
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
        )
    )
}

establishment_map_is_empty <- function(establishment_map) {
    clean <- sanitize_establishment_map(establishment_map)
    !any(nzchar(clean$means)) && !any(nzchar(clean$degree))
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

# Pre-fill establishmentMeans for taxa on the bundled invasive list: being
# recorded as an alien invasive species in Brazil is what supports
# "introduced". Nothing is suggested for the rest -- guessing "native" for an
# unlisted taxon would assert something the app cannot know. Nothing is ever
# suggested for degreeOfEstablishment: that depends on the record (a captive
# animal and a feral one are the same species), so it stays with the user.
auto_suggest_establishment_means <- function(species_names) {
    n <- length(species_names)
    if (n == 0L) {
        return(stats::setNames(character(0), character(0)))
    }
    listed <- flag_invasive_species(species_names)
    out <- ifelse(listed, "introduced", "")
    stats::setNames(out, normalize_species_keys(species_names))
}

# Expand a per-species answer to one value per row.
map_establishment_values <- function(species_values, establishment_map = NULL,
                                     field = "means") {
    keys <- normalize_species_keys(species_values)
    if (is.null(establishment_map) || length(establishment_map) == 0) {
        return(rep("", length(keys)))
    }
    clean <- sanitize_establishment_map(establishment_map)
    field_map <- if (identical(field, "degree")) clean$degree else clean$means
    if (length(field_map) == 0) {
        return(rep("", length(keys)))
    }
    mapped <- unname(field_map[keys])
    mapped[is.na(mapped)] <- ""
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
                                           out_sep = " | ") {
    field <- if (identical(term, "degreeOfEstablishment")) "degree" else "means"
    n <- nrow(df)
    assistant_values <- if (is.null(species_values)) {
        rep("", n)
    } else {
        map_establishment_values(species_values, establishment_map, field = field)
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
                                         out_sep = " | ") {
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
        out_sep = out_sep
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
    values <- if (identical(field, "degree")) clean$degree else clean$means
    if (length(values) == 0L) {
        return(0L)
    }
    sum(nzchar(values))
}

# Species that got an establishmentMeans but no degreeOfEstablishment. The
# pair is strongly recommended, so the assistant and the export surface this --
# but it never blocks: Darwin Core does not require degreeOfEstablishment, and
# a taxon whose degree is genuinely unknown must still be publishable.
establishment_pairs_missing_degree <- function(establishment_map) {
    clean <- sanitize_establishment_map(establishment_map)
    if (length(clean$means) == 0) {
        return(character(0))
    }
    with_means <- names(clean$means)[nzchar(clean$means)]
    if (length(with_means) == 0) {
        return(character(0))
    }
    degree_for <- clean$degree[with_means]
    degree_for[is.na(degree_for)] <- ""
    with_means[!nzchar(degree_for)]
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
    if (any(is.na(clean_tbl$lang) | !clean_tbl$lang %in% c("pt", "en", "any"))) {
        stop("Synonyms table lang must be one of: pt, en, any.")
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
            if (length(hit_idx) > 0) {
                score <- max(term_syn$name_score[hit_idx], na.rm = TRUE)
                score <- pmin(0.98, pmax(0.90, score))
                return(list(
                    score = score,
                    reason = "known_synonym",
                    is_exact = FALSE,
                    exact_hits = 0L,
                    substring_hits = 0L
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
            score = overlap_details$score,
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

compute_value_score <- function(values, term, name_score, max_sample_n = 1000L) {
    values_chr <- as.character(values)
    values_chr[is.na(values)] <- NA_character_
    non_blank <- values_chr[!is.na(values_chr) & nzchar(trimws(values_chr))]

    if (length(non_blank) == 0) {
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

    sampled_values <- sample_values_for_scoring(
        values = values_chr,
        name_score = name_score,
        max_sample_n = max_sample_n
    )
    if (length(sampled_values) == 0) {
        return(list(
            score = 0,
            reason = "empty_column",
            compatible_type = FALSE,
            sampled_n = 0L,
            valid_ratio = 0
        ))
    }

    term_name <- as.character(term)

    if (identical(term_name, "decimalLatitude")) {
        lat_result <- validate_numeric_range(sampled_values, -90, 90)
        return(finalize_value_result(lat_result, sampled_n = length(sampled_values)))
    }

    if (identical(term_name, "decimalLongitude")) {
        lon_result <- validate_numeric_range(sampled_values, -180, 180)
        return(finalize_value_result(lon_result, sampled_n = length(sampled_values)))
    }

    if (identical(term_name, "scientificName")) {
        sn_result <- validate_scientific_name_pattern(sampled_values)
        return(finalize_value_result(sn_result, sampled_n = length(sampled_values)))
    }

    if (identical(term_name, "individualCount")) {
        count_result <- validate_individual_count(sampled_values)
        return(finalize_value_result(count_result, sampled_n = length(sampled_values)))
    }

    list(
        score = 0.80,
        reason = "neutral_no_validator",
        compatible_type = TRUE,
        sampled_n = length(sampled_values),
        valid_ratio = 0.80
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

apply_semantic_penalties <- function(col_name, term) {
    col_norm <- normalize_for_matching(col_name)
    term_name <- as.character(term)

    penalties <- numeric(0)
    reason_codes <- character(0)

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
        lapply(columns, build_matching_profile),
        columns
    )
    term_profiles <- stats::setNames(
        lapply(terms, build_matching_profile),
        terms
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
            col_profile <- column_profiles[[col_name]]
            name_res <- compute_name_score(
                col_name = col_name,
                term = term,
                synonyms_tbl = NULL,
                col_profile = col_profile,
                term_profile = term_profile,
                synonyms_index = synonyms_index
            )

            if (is_temporal_limited && !isTRUE(name_res$is_exact)) {
                return(NULL)
            }

            if (!isTRUE(name_res$is_exact) &&
                !identical(name_res$reason, "known_synonym") &&
                name_res$score < prune_threshold) {
                return(NULL)
            }

            value_res <- compute_value_score_from_profile(
                value_profile = value_profiles[[col_name]],
                term = term,
                name_score = name_res$score
            )
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

format_genus_token <- function(token) {
    if (is_blank_value(token)) {
        return(NA_character_)
    }

    cleaned <- gsub("^[^A-Za-z]+|[^A-Za-z-]+$", "", as.character(token))
    if (!nzchar(cleaned)) {
        return(NA_character_)
    }

    paste0(
        toupper(substr(cleaned, 1, 1)),
        tolower(substr(cleaned, 2, nchar(cleaned)))
    )
}

format_epithet_token <- function(token) {
    if (is_blank_value(token)) {
        return(NA_character_)
    }

    cleaned <- gsub("^[^A-Za-z]+|[^A-Za-z-]+$", "", as.character(token))
    cleaned <- tolower(cleaned)

    if (!grepl("^[a-z][a-z-]*$", cleaned)) {
        return(NA_character_)
    }

    cleaned
}

#' Vectorized companions to format_genus_token() / format_epithet_token()
#'
#' Straight transliterations: every operation the scalars use (gsub, toupper,
#' tolower, substr, nchar, grepl) is already vectorized in base R, so no
#' unique/expand step is needed. Called per row the closure and dispatch overhead
#' dominated; over a column it is a handful of vectorized passes. Names are
#' dropped, matching what the paste() at the call site expects.
#'
#' @param token Character vector of raw name tokens
#' @return Character vector the same length as the input, NA where the token has
#'   no usable letters
#' @noRd
format_genus_token_vec <- function(token) {
    values <- as.character(token)
    n <- length(values)
    out <- rep(NA_character_, n)
    if (n == 0L) {
        return(out)
    }

    keep <- !(is.na(values) | !nzchar(trimws(values)))
    if (!any(keep)) {
        return(out)
    }

    cleaned <- gsub("^[^A-Za-z]+|[^A-Za-z-]+$", "", values[keep])
    ok <- nzchar(cleaned)
    resolved <- rep(NA_character_, length(cleaned))
    resolved[ok] <- paste0(
        toupper(substr(cleaned[ok], 1, 1)),
        tolower(substr(cleaned[ok], 2, nchar(cleaned[ok])))
    )

    out[keep] <- resolved
    out
}

#' @rdname format_genus_token_vec
#' @noRd
format_epithet_token_vec <- function(token) {
    values <- as.character(token)
    n <- length(values)
    out <- rep(NA_character_, n)
    if (n == 0L) {
        return(out)
    }

    keep <- !(is.na(values) | !nzchar(trimws(values)))
    if (!any(keep)) {
        return(out)
    }

    cleaned <- tolower(gsub("^[^A-Za-z]+|[^A-Za-z-]+$", "", values[keep]))
    ok <- grepl("^[a-z][a-z-]*$", cleaned)
    resolved <- rep(NA_character_, length(cleaned))
    resolved[ok] <- cleaned[ok]

    out[keep] <- resolved
    out
}

# Taxon terms derived from scientificName by extract_scientific_name_components().
# The mapping cards lock these once scientificName is mapped, so the single list
# lives here rather than being spelled out at each card call site.
derived_taxon_terms <- function() {
    c("genus", "specificEpithet", "infraspecificEpithet", "taxonRank")
}

# Terms whose card is locked when scientificName is mapped. genus is excluded:
# it stays user-mappable because a dataset may carry a genus column that
# disagrees with the parsed name, and fill_missing_character_values() lets the
# mapped value win.
locked_taxon_terms <- function() {
    c("specificEpithet", "infraspecificEpithet", "taxonRank")
}

# Rank markers that may introduce an infraspecific epithet, mapped to the DwC
# taxonRank each one implies.
infraspecific_rank_markers <- function() {
    c(
        "subsp" = "subspecies", "subsp." = "subspecies",
        "ssp" = "subspecies", "ssp." = "subspecies",
        "var" = "variety", "var." = "variety",
        "f" = "form", "f." = "form", "forma" = "form"
    )
}

# Resolve the infraspecific part of a name from the tokens sitting after the
# specific epithet. Two shapes are accepted: an explicit marker plus an epithet
# ("Puma concolor subsp. concolor") and the bare trinomial the zoological code
# uses ("Dasypus septemcinctus hybridus").
#
# The bare form has to be told apart from authorship, which occupies the same
# position: "Dasypus novemcinctus Linnaeus, 1758". Only a token starting with a
# lowercase letter and made of letters/hyphen counts as an epithet.
# format_epithet_token() cannot make that call because it lowercases before
# validating, so "Linnaeus" would sail through it.
extract_infraspecific_part <- function(tokens, start) {
    if (length(tokens) < start) {
        return(NULL)
    }

    markers <- infraspecific_rank_markers()
    marker_idx <- match(tolower(tokens[[start]]), names(markers))
    if (!is.na(marker_idx)) {
        if (length(tokens) < start + 1L) {
            return(NULL)
        }
        epithet <- format_epithet_token(tokens[[start + 1L]])
        if (is.na(epithet)) {
            return(NULL)
        }
        return(list(
            infraspecificEpithet = epithet,
            taxonRank = unname(markers[[marker_idx]])
        ))
    }

    if (!grepl("^[a-z][a-z-]*$", tokens[[start]])) {
        return(NULL)
    }
    epithet <- format_epithet_token(tokens[[start]])
    if (is.na(epithet)) {
        return(NULL)
    }
    list(infraspecificEpithet = epithet, taxonRank = "subspecies")
}

extract_scientific_name_components <- function(scientific_names) {
    # Parse over UNIQUE names and expand back: the genus/epithet/rank of a row
    # depends only on its scientificName, and a dataset repeats a handful of
    # species across thousands of rows (camera traps especially). The per-name
    # regex (gsub/sub/trimws via format_*_token) is otherwise the dominant cost
    # of build_processed_mapping_df. (LESSONS: unique -> resolve -> match back.)
    sn <- as.character(scientific_names)
    if (length(sn) > 1L) {
        u <- unique(sn)
        if (length(u) < length(sn)) {
            res_u <- extract_scientific_name_components(u)
            out <- res_u[match(sn, u), , drop = FALSE]
            rownames(out) <- NULL
            return(out)
        }
    }

    unknown_markers <- c("sp", "sp.", "spp", "spp.")
    qualifier_markers <- c("cf", "cf.", "aff", "aff.", "nr", "nr.")

    blank_result <- list(
        genus = NA_character_,
        specificEpithet = NA_character_,
        infraspecificEpithet = NA_character_,
        taxonRank = NA_character_
    )

    # Attach the infraspecific epithet when the tokens after the specific one
    # carry it, promoting the rank from species to subspecies/variety/form.
    with_infraspecific <- function(genus, specific, tokens, start) {
        infra <- extract_infraspecific_part(tokens, start)
        list(
            genus = genus,
            specificEpithet = specific,
            infraspecificEpithet = if (is.null(infra)) {
                NA_character_
            } else {
                infra$infraspecificEpithet
            },
            taxonRank = if (is.null(infra)) "species" else infra$taxonRank
        )
    }

    parsed <- lapply(scientific_names, function(value) {
        if (is_blank_value(value)) {
            return(blank_result)
        }

        cleaned <- gsub("\\|", " ", as.character(value))
        cleaned <- gsub("\\s+", " ", trimws(cleaned))
        tokens <- strsplit(cleaned, " ", fixed = TRUE)[[1]]
        tokens <- tokens[nzchar(tokens)]

        if (length(tokens) == 0) {
            return(blank_result)
        }

        genus <- format_genus_token(tokens[[1]])
        first_lower <- tolower(tokens[[1]])
        if (first_lower %in% unknown_markers) {
            genus <- NA_character_
        }

        if (is.na(genus)) {
            return(blank_result)
        }

        genus_only <- list(
            genus = genus,
            specificEpithet = NA_character_,
            infraspecificEpithet = NA_character_,
            taxonRank = "genus"
        )

        if (length(tokens) == 1) {
            return(genus_only)
        }

        second_lower <- tolower(tokens[[2]])
        if (second_lower %in% unknown_markers) {
            return(genus_only)
        }

        if (second_lower %in% qualifier_markers && length(tokens) >= 3) {
            specific <- format_epithet_token(tokens[[3]])
            if (is.na(specific)) {
                return(genus_only)
            }
            return(with_infraspecific(genus, specific, tokens, 4L))
        }

        specific <- format_epithet_token(tokens[[2]])
        if (is.na(specific)) {
            return(genus_only)
        }

        with_infraspecific(genus, specific, tokens, 3L)
    })

    pluck <- function(field) {
        vapply(parsed, function(x) x[[field]], FUN.VALUE = character(1))
    }

    data.frame(
        genus = pluck("genus"),
        specificEpithet = pluck("specificEpithet"),
        infraspecificEpithet = pluck("infraspecificEpithet"),
        taxonRank = pluck("taxonRank"),
        stringsAsFactors = FALSE
    )
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

parse_year_to_number <- function(x) {
    if (is_blank_value(x)) {
        return(NA_integer_)
    }

    value <- trimws(as.character(x))
    if (grepl("^\\d{4}$", value)) {
        return(as.integer(value))
    }

    year_match <- regmatches(value, regexpr("\\d{4}", value, perl = TRUE))
    if (length(year_match) == 0 || identical(year_match, "")) {
        return(NA_integer_)
    }

    as.integer(year_match)
}

#' Vectorized companion to parse_year_to_number()
#'
#' Same extraction, resolved once per distinct value instead of once per row.
#' Years repeat by construction, so the distinct count stays small even on a
#' free-text date column.
#'
#' @param x Character vector of raw year values
#' @return Integer vector of years, NA where no 4-digit run is present, same
#'   length as the input
#' @noRd
parse_year_to_number_vec <- function(x) {
    values <- as.character(x)
    n <- length(values)
    out <- rep(NA_integer_, n)
    if (n == 0L) {
        return(out)
    }

    trimmed <- trimws(values)
    candidates <- !(is.na(values) | !nzchar(trimmed))
    if (!any(candidates)) {
        return(out)
    }

    uniq <- unique(trimmed[candidates])
    resolved <- rep(NA_integer_, length(uniq))

    exact <- grepl("^\\d{4}$", uniq)
    resolved[exact] <- as.integer(uniq[exact])

    rest <- which(!exact)
    if (length(rest) > 0L) {
        # Deliberately NOT regmatches(): it DROPS non-matching elements and so
        # silently shortens the vector, which would misalign every value after
        # the first miss. The match position is used directly instead.
        m <- regexpr("\\d{4}", uniq[rest], perl = TRUE)
        hit <- m > 0L
        if (any(hit)) {
            starts <- m[hit]
            resolved[rest[hit]] <- as.integer(
                substring(uniq[rest][hit], starts, starts + 3L)
            )
        }
    }

    out[candidates] <- resolved[match(trimmed[candidates], uniq)]
    out
}

normalize_semicolon_tokens <- function(x, out_sep = " | ") {
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

    multi <- !is.na(out) & grepl(";", out, fixed = TRUE)
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

#' Escape a character vector for embedding inside JSON double-quoted strings
#'
#' Implements the strict JSON string escape table (RFC 8259). UTF-8 multi-byte
#' sequences are preserved as-is (legal in JSON). NA values are passed through.
#'
#' @param x Character vector.
#' @return Character vector of the same length with JSON-safe contents.
#' @keywords internal
#' @noRd
json_escape_string <- function(x) {
    x <- as.character(x)
    out <- x
    # Fast path: skip per-class gsub when no character in any element needs
    # escaping. Cheap single grepl is faster than running every gsub blindly.
    if (any(grepl("[\\\\\"\x01-\x1f]", out, perl = TRUE), na.rm = TRUE)) {
        out <- gsub("\\\\", "\\\\\\\\", out, perl = TRUE)
        out <- gsub("\"", "\\\\\"", out, perl = TRUE)
        out <- gsub("\b", "\\b", out, fixed = TRUE)
        out <- gsub("\f", "\\f", out, fixed = TRUE)
        out <- gsub("\n", "\\n", out, fixed = TRUE)
        out <- gsub("\r", "\\r", out, fixed = TRUE)
        out <- gsub("\t", "\\t", out, fixed = TRUE)
        has_other_ctrl <- grepl("[\x01-\x07\x0b\x0e-\x1f]", out, perl = TRUE)
        if (any(has_other_ctrl, na.rm = TRUE)) {
            idx <- which(has_other_ctrl)
            out[idx] <- vapply(out[idx], function(s) {
                chars <- strsplit(s, "", fixed = TRUE)[[1]]
                codes <- utf8ToInt(s)
                ctrl <- which(codes < 32 & !(codes %in% c(8, 9, 10, 12, 13)))
                chars[ctrl] <- sprintf("\\u%04x", codes[ctrl])
                paste(chars, collapse = "")
            }, character(1), USE.NAMES = FALSE)
        }
    }
    out[is.na(x)] <- NA_character_
    out
}

#' Derive a JSON-safe key from a source column name
#'
#' Lowercases, transliterates accents to ASCII via iconv, replaces any run of
#' non-alphanumeric characters with a single underscore, trims leading/trailing
#' underscores, and falls back to "field" if the result is empty.
#'
#' @param column_name Character vector of column names.
#' @return Character vector of normalized JSON keys, same length as input.
#' @keywords internal
#' @noRd
derive_dynprops_key <- function(column_name) {
    x <- tolower(as.character(column_name))
    translit <- iconv(x, to = "ASCII//TRANSLIT")
    has_translit <- !is.na(translit)
    x[has_translit] <- translit[has_translit]
    x <- gsub("[^a-z0-9]+", "_", x, perl = TRUE)
    x <- gsub("_+", "_", x, perl = TRUE)
    x <- gsub("^_|_$", "", x, perl = TRUE)
    x[!nzchar(x)] <- "field"
    x
}

#' Compose dynamicProperties JSON from one or more source columns
#'
#' Builds a strict TDWG-compatible JSON object per row of the form
#' `{"key1":"value1","key2":"value2"}` (no whitespace). Blank cells are
#' omitted from that row's JSON. A row in which every selected column is
#' blank produces an empty string `""` (not `"{}"`).
#'
#' @param df Data frame containing the source columns.
#' @param cols Character vector of source column names (length >= 1).
#' @param keys Optional named character vector (or list) mapping
#'   `cols[i]` to a user-overridden JSON key. Entries that are NULL,
#'   NA, blank, or contain a literal double-quote are ignored and the
#'   key is auto-derived via [derive_dynprops_key()].
#' @return Character vector of length `nrow(df)`.
#' @keywords internal
#' @noRd
build_dynamic_properties_json <- function(df, cols, keys = NULL) {
    if (length(cols) == 0) {
        return(rep("", nrow(df)))
    }

    missing_cols <- setdiff(cols, names(df))
    if (length(missing_cols) > 0) {
        stop("Columns not found in data frame: ", paste(missing_cols, collapse = ", "))
    }

    key_overrides <- if (is.null(keys)) list() else as.list(keys)

    resolved_keys <- vapply(cols, function(col_name) {
        override <- key_overrides[[col_name]]
        if (!is.null(override) && length(override) == 1L) {
            override_str <- as.character(override)
            if (!is.na(override_str) && nzchar(trimws(override_str)) &&
                !grepl("\"", override_str, fixed = TRUE)) {
                return(trimws(override_str))
            }
        }
        derive_dynprops_key(col_name)
    }, character(1), USE.NAMES = FALSE)

    dup_mask <- duplicated(resolved_keys)
    if (any(dup_mask)) {
        collisions <- unique(resolved_keys[dup_mask])
        details <- vapply(collisions, function(k) {
            paste0("'", k, "' <- ", paste(cols[resolved_keys == k], collapse = ", "))
        }, character(1), USE.NAMES = FALSE)
        warning(
            "build_dynamic_properties_json: key collision after normalization. ",
            "First column wins; later duplicates dropped. Conflicts: ",
            paste(details, collapse = "; ")
        )
        keep_idx <- which(!dup_mask)
        cols <- cols[keep_idx]
        resolved_keys <- resolved_keys[keep_idx]
    }

    n <- nrow(df)
    if (n == 0L) {
        return(character(0))
    }

    n_cols <- length(cols)

    # Vectorized row build: per column, pre-format `"key":"value"` strings,
    # mark blank cells with "" (sentinel). Join columns with a control-char
    # sentinel \x01, then strip empty pieces and surrounding sentinels via
    # regex, swap the sentinel for ',', and wrap non-empty rows in {...}.
    sentinel <- "\x01"
    parts_per_col <- vector("list", n_cols)
    for (j in seq_len(n_cols)) {
        v <- df[[cols[[j]]]]
        blank <- is.na(v) | !nzchar(trimws(as.character(v)))
        escaped <- json_escape_string(v)
        piece <- paste0("\"", resolved_keys[[j]], "\":\"", escaped, "\"")
        piece[blank] <- ""
        parts_per_col[[j]] <- piece
    }

    joined <- do.call(paste, c(parts_per_col, list(sep = sentinel)))
    joined <- gsub(paste0(sentinel, "+"), sentinel, joined, perl = TRUE)
    joined <- gsub(
        paste0("^", sentinel, "|", sentinel, "$"), "", joined, perl = TRUE
    )
    joined <- gsub(sentinel, ",", joined, fixed = TRUE)

    out <- character(n)
    keep <- nzchar(joined)
    out[keep] <- paste0("{", joined[keep], "}")
    out
}

#' Merge one key/value pair into existing dynamicProperties JSON
#'
#' Folds `"key":"value"` into each element of `existing` — a vector of flat
#' dynamicProperties JSON strings produced by [build_dynamic_properties_json()]
#' (`{"k":"v"}`) or `""`/NA. Used on export to add conservation-status entries
#' without hand-concatenating strings: the value is JSON-escaped and the object
#' reserialized (same no-whitespace convention). Rows whose `value` is NA or
#' blank are returned unchanged, so empty keys are never emitted.
#'
#' @param existing Character vector of dynamicProperties JSON strings.
#' @param key Single JSON key, assumed ASCII-safe (e.g. a DwC-style term).
#' @param value Character vector of length 1 or `length(existing)`.
#' @return Character vector the same length as `existing`.
#' @keywords internal
#' @noRd
merge_dynamic_property <- function(existing, key, value) {
    n <- length(existing)
    if (n == 0L) {
        return(character(0))
    }
    existing <- as.character(existing)
    existing[is.na(existing)] <- ""
    value <- as.character(value)
    if (length(value) == 1L) {
        value <- rep(value, n)
    }
    out <- existing
    add <- !is.na(value) & nzchar(trimws(value))
    if (!any(add)) {
        return(out)
    }
    pair <- paste0("\"", key, "\":\"", json_escape_string(value), "\"")
    # Empty target -> wrap the pair as a fresh object.
    fresh <- add & !nzchar(existing)
    out[fresh] <- paste0("{", pair[fresh], "}")
    # Existing object -> splice the pair in before the closing brace.
    obj <- add & nzchar(existing)
    inner <- sub("\\}$", "", sub("^\\{", "", existing[obj]))
    joined <- ifelse(nzchar(inner), paste0(inner, ",", pair[obj]), pair[obj])
    out[obj] <- paste0("{", joined, "}")
    out
}

detect_eventdate_roles <- function(col_names) {
    normalized_names <- normalize_for_matching(col_names)
    used_env <- new.env(parent = emptyenv())
    used_env$used <- rep(FALSE, length(normalized_names))

    start_mask <- grepl("\\b(start|begin|initial|inicio|from)\\b", normalized_names)
    end_mask <- grepl("\\b(end|final|fim|to)\\b", normalized_names)
    month_mask <- grepl("\\b(month|mo|mes)\\b", normalized_names)
    year_mask <- grepl("\\b(year|yr|ano)\\b", normalized_names)

    pick_first <- function(mask) {
        idx <- which(mask & !used_env$used)
        if (length(idx) == 0) {
            return(NA_integer_)
        }
        used_env$used[[idx[1]]] <- TRUE
        idx[1]
    }

    start_month <- pick_first(start_mask & month_mask)
    start_year <- pick_first(start_mask & year_mask)
    end_month <- pick_first(end_mask & month_mask)
    end_year <- pick_first(end_mask & year_mask)

    if (is.na(start_month)) start_month <- pick_first(month_mask)
    if (is.na(start_year)) start_year <- pick_first(year_mask)
    if (is.na(end_month)) end_month <- pick_first(month_mask)
    if (is.na(end_year)) end_year <- pick_first(year_mask)

    used_fallback <- FALSE
    if (anyNA(c(start_month, start_year, end_month, end_year)) && length(col_names) >= 4) {
        start_month <- 1L
        start_year <- 2L
        end_month <- 3L
        end_year <- 4L
        used_fallback <- TRUE
    }

    list(
        start_month = start_month,
        start_year = start_year,
        end_month = end_month,
        end_year = end_year,
        used_fallback = used_fallback
    )
}

# Role detection for a SINGLE eventDate spread across separate day/month/year
# columns -- the sibling of detect_eventdate_roles(), which resolves the 4-column
# start/end interval instead. Name-based only, with no positional fallback: a
# selection whose column names do not carry the roles as whole words stays
# unresolved so the caller keeps the generic collapse rather than guessing a
# date. Prefix matching is deliberately not attempted, since in Portuguese it
# misfires on ordinary column names ("anotacoes" -> ano, "mesorregiao" -> mes).
detect_eventdate_dmy_roles <- function(col_names) {
    normalized_names <- normalize_for_matching(col_names)
    used <- rep(FALSE, length(normalized_names))

    pick_first <- function(pattern) {
        idx <- which(grepl(pattern, normalized_names) & !used)
        if (length(idx) == 0) {
            return(NA_integer_)
        }
        used[[idx[[1]]]] <<- TRUE
        idx[[1]]
    }

    list(
        day = pick_first("\\b(day|dia|dd)\\b"),
        month = pick_first("\\b(month|mo|mes)\\b"),
        year = pick_first("\\b(year|yr|ano)\\b")
    )
}

# Compose one ISO 8601 eventDate from the day/month/year columns the user mapped
# to the term. Returns NULL -- meaning "not a date split into parts, treat it as
# any other multi-column term" -- unless every selected column resolves to a
# role, a year is among them, and a day never arrives without its month. That
# strictness is what keeps an unrelated pair of columns from being read as a
# date. Composition itself is delegated to the Rostrum composer, which already
# emits YYYY, YYYY-MM and YYYY-MM-DD and validates the day against the month's
# length in the given year.
build_eventdate_from_parts <- function(df, cols, fallback_raw = TRUE) {
    roles <- detect_eventdate_dmy_roles(cols)
    resolved <- c(roles$day, roles$month, roles$year)

    if (is.na(roles$year) || sum(!is.na(resolved)) != length(cols)) {
        return(NULL)
    }
    if (!is.na(roles$day) && is.na(roles$month)) {
        return(NULL)
    }

    pick_col <- function(idx) if (is.na(idx)) NA_character_ else cols[[idx]]
    composed <- rostrum_compose_eventdate_values(
        df = df,
        source_columns = list(
            year = pick_col(roles$year),
            month = pick_col(roles$month),
            day = pick_col(roles$day)
        )
    )

    # A row with no date parts at all is blank, not a failure -- same convention
    # as build_eventdate_interval().
    failed_rows <- composed$has_any_input & !composed$valid_mask

    result <- composed$values
    if (isTRUE(fallback_raw) && any(failed_rows)) {
        raw_values <- collapse_mapped_values(df, cols, out_sep = " | ")
        result[failed_rows] <- raw_values[failed_rows]
    }

    list(
        values = result,
        failed_rows = failed_rows,
        failure_count = sum(failed_rows),
        role_map = roles
    )
}

# Role detection for an interval whose two ends each carry a day, month and year
# ("dia_inicio, mes_inicio, ano_inicio, dia_fim, mes_fim, ano_fim"). It reads the
# same start/end vocabulary as detect_eventdate_roles(), which resolves the
# 4-column month/year interval, and is as strict as detect_eventdate_dmy_roles():
# names only, no positional fallback, so an unrelated six-column pick keeps the
# generic collapse instead of being read as a date range.
detect_eventdate_interval_dmy_roles <- function(col_names) {
    normalized_names <- normalize_for_matching(col_names)
    used_env <- new.env(parent = emptyenv())
    used_env$used <- rep(FALSE, length(normalized_names))

    start_mask <- grepl("\\b(start|begin|initial|inicio|from)\\b", normalized_names)
    end_mask <- grepl("\\b(end|final|fim|to)\\b", normalized_names)
    day_mask <- grepl("\\b(day|dia|dd)\\b", normalized_names)
    month_mask <- grepl("\\b(month|mo|mes)\\b", normalized_names)
    year_mask <- grepl("\\b(year|yr|ano)\\b", normalized_names)

    pick_first <- function(mask) {
        idx <- which(mask & !used_env$used)
        if (length(idx) == 0) {
            return(NA_integer_)
        }
        used_env$used[[idx[1]]] <- TRUE
        idx[1]
    }

    list(
        start = list(
            day = pick_first(start_mask & day_mask),
            month = pick_first(start_mask & month_mask),
            year = pick_first(start_mask & year_mask)
        ),
        end = list(
            day = pick_first(end_mask & day_mask),
            month = pick_first(end_mask & month_mask),
            year = pick_first(end_mask & year_mask)
        )
    )
}

# Compose one ISO 8601 interval ("2007-03-01/2008-05-11") from the six columns a
# collection uses to record a date range. Returns NULL -- meaning "not an
# interval, treat it as any other multi-column term" -- unless all six columns
# resolve to a distinct role. Each end is composed by the same Rostrum composer
# the single-date path uses, so a day is validated against its month either way.
build_eventdate_interval_dmy <- function(df, cols, fallback_raw = TRUE) {
    roles <- detect_eventdate_interval_dmy_roles(cols)
    resolved <- unlist(c(roles$start, roles$end), use.names = FALSE)

    if (anyNA(resolved) || length(unique(resolved)) != length(cols)) {
        return(NULL)
    }

    compose_end <- function(side) {
        rostrum_compose_eventdate_values(
            df = df,
            source_columns = list(
                year = cols[[side$year]],
                month = cols[[side$month]],
                day = cols[[side$day]]
            )
        )
    }
    start <- compose_end(roles$start)
    end <- compose_end(roles$end)

    # A range whose two ends are the same date is one date, not an interval --
    # writing "2024-03-22/2024-03-22" would state a span the record never had.
    # An end left blank is the same case: the collection recorded a single day.
    both_valid <- start$valid_mask & end$valid_mask
    is_range <- both_valid & start$values != end$values
    start_only <- start$valid_mask & !end$has_any_input
    end_only <- end$valid_mask & !start$has_any_input

    result <- rep(NA_character_, nrow(df))
    result[both_valid] <- start$values[both_valid]
    result[is_range] <- paste0(start$values[is_range], "/", end$values[is_range])
    result[start_only] <- start$values[start_only]
    result[end_only] <- end$values[end_only]

    has_any_input <- start$has_any_input | end$has_any_input
    failed_rows <- has_any_input & is.na(result)

    if (isTRUE(fallback_raw) && any(failed_rows)) {
        raw_values <- collapse_mapped_values(df, cols, out_sep = " | ")
        result[failed_rows] <- raw_values[failed_rows]
    }

    list(
        values = result,
        failed_rows = failed_rows,
        failure_count = sum(failed_rows),
        role_map = roles
    )
}

# Month name lookup, hoisted to a file-level constant so it is allocated once per
# session instead of once per call. It used to live inside parse_month_to_number(),
# which meant a 40-element named vector was built for every row of the dataset.
# Both the scalar helper and its vectorized companion read this same object, so
# the two spellings of the month table cannot drift apart.
.month_name_map <- c(
    jan = "01", janeiro = "01", january = "01",
    fev = "02", fevereiro = "02", feb = "02", february = "02",
    mar = "03", marco = "03", march = "03",
    abr = "04", abril = "04", apr = "04", april = "04",
    mai = "05", maio = "05", may = "05",
    jun = "06", junho = "06", june = "06",
    jul = "07", julho = "07", july = "07",
    ago = "08", agosto = "08", aug = "08", august = "08",
    set = "09", setembro = "09", sep = "09", sept = "09", september = "09",
    out = "10", outubro = "10", oct = "10", october = "10",
    nov = "11", novembro = "11", november = "11",
    dez = "12", dezembro = "12", dec = "12", december = "12"
)

parse_month_to_number <- function(x) {
    if (is_blank_value(x)) {
        return(NA_character_)
    }

    value <- trimws(as.character(x))
    if (grepl("^\\d{1,2}$", value)) {
        month_num <- suppressWarnings(as.integer(value))
        if (!is.na(month_num) && month_num >= 1 && month_num <= 12) {
            return(sprintf("%02d", month_num))
        }
    }

    normalized <- normalize_for_matching(value)
    normalized <- gsub("\\s+", "", normalized)

    if (!normalized %in% names(.month_name_map)) {
        return(NA_character_)
    }

    unname(.month_name_map[[normalized]])
}

#' Vectorized companion to parse_month_to_number()
#'
#' Same mapping, resolved once per distinct month value instead of once per row.
#' A month column has at most a few dozen distinct spellings whatever the dataset
#' size, while the scalar version paid a grepl, an iconv (via
#' normalize_for_matching) and two gsub per record.
#'
#' @param x Character vector of raw month values
#' @return Character vector of "01".."12", NA where unparseable, same length as
#'   the input
#' @noRd
parse_month_to_number_vec <- function(x) {
    values <- as.character(x)
    n <- length(values)
    out <- rep(NA_character_, n)
    if (n == 0L) {
        return(out)
    }

    trimmed <- trimws(values)
    blank <- is.na(values) | !nzchar(trimmed)

    numeric_like <- !blank & grepl("^\\d{1,2}$", trimmed)
    month_num <- rep(NA_integer_, n)
    month_num[numeric_like] <- suppressWarnings(as.integer(trimmed[numeric_like]))
    in_range <- numeric_like & !is.na(month_num) & month_num >= 1L & month_num <= 12L
    out[in_range] <- sprintf("%02d", month_num[in_range])

    # Anything that is neither blank nor an in-range number falls through to the
    # name path. That includes out-of-range digits such as "0" and "13": the
    # scalar version does not short-circuit them to NA either, it lets them reach
    # the lookup (where they miss and yield NA). Keeping the fall-through is what
    # makes this a behaviour-preserving rewrite.
    named <- !blank & !in_range
    if (any(named)) {
        uniq <- unique(trimmed[named])
        norm <- gsub("\\s+", "", normalize_for_matching(uniq))
        # Single bracket, not [[: on a NAMED VECTOR (unlike a list) [[key]] errors
        # on a missing key, while [ ] with an NA index returns NA (ADR-110).
        resolved <- unname(.month_name_map[match(norm, names(.month_name_map))])
        out[named] <- resolved[match(trimmed[named], uniq)]
    }

    out
}

build_eventdate_interval <- function(df, cols, fallback_raw = TRUE) {
    if (length(cols) != 4) {
        stop("eventDate interval requires exactly 4 columns.")
    }

    role_map <- detect_eventdate_roles(cols)
    role_indices <- c(
        role_map$start_month,
        role_map$start_year,
        role_map$end_month,
        role_map$end_year
    )

    if (anyNA(role_indices)) {
        stop("Could not detect eventDate roles for all 4 mapped columns.")
    }

    row_values <- lapply(cols, function(col_name) {
        values <- as.character(df[[col_name]])
        values[is.na(df[[col_name]])] <- NA_character_
        values
    })

    blank_matrix <- do.call(cbind, lapply(row_values, function(values) {
        is.na(values) | !nzchar(trimws(values))
    }))
    all_blank <- rowSums(blank_matrix) == ncol(blank_matrix)

    # Four column-wide passes instead of four per-row vapply loops. The vapply
    # calls also carried USE.NAMES = TRUE (the default), so each one built and
    # threw away a names attribute as long as the dataset.
    start_month <- parse_month_to_number_vec(row_values[[role_indices[[1]]]])
    start_year <- parse_year_to_number_vec(row_values[[role_indices[[2]]]])
    end_month <- parse_month_to_number_vec(row_values[[role_indices[[3]]]])
    end_year <- parse_year_to_number_vec(row_values[[role_indices[[4]]]])

    has_all_parts <- !is.na(start_month) & !is.na(start_year) & !is.na(end_month) & !is.na(end_year)
    failed_rows <- !all_blank & !has_all_parts

    result <- rep(NA_character_, nrow(df))
    if (any(has_all_parts)) {
        result[has_all_parts] <- sprintf(
            "%04d-%s/%04d-%s",
            start_year[has_all_parts],
            start_month[has_all_parts],
            end_year[has_all_parts],
            end_month[has_all_parts]
        )
    }
    if (isTRUE(fallback_raw) && any(failed_rows)) {
        # Built here rather than up front: it is only ever read on this branch,
        # and on a clean dataset (no parse failures, the common case) nothing
        # reads it at all. With 4 columns collapse_mapped_values() takes its
        # multi-column path, an O(nrow) loop that was costing ~14s per call at
        # 50k rows purely to be discarded. Nothing is lost by deferring: the
        # function is pure, and its only other effect -- stop() on a missing
        # column -- is already reached by df[[col_name]] above.
        raw_values <- collapse_mapped_values(df, cols, out_sep = " | ")
        result[failed_rows] <- raw_values[failed_rows]
    }

    list(
        values = result,
        failed_rows = failed_rows,
        failure_count = sum(failed_rows),
        role_map = role_map
    )
}

#' Map raw values to DwC occurrenceStatus literals
#'
#' Coerces common presence/absence representations (0/1, sim/nao, yes/no,
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

    present_set <- c("1", "present", "presente", "yes", "y", "sim", "s", "true", "t")
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
        values <- normalize_semicolon_tokens(df[[user_cols[[1]]]], out_sep = out_sep)
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

    list(values = values, eventdate_failure_count = failure_count)
}

# Position of each element within its group of equal values, without splitting
# the vector. ave(FUN = seq_along) is the readable form but builds one group per
# distinct value, which on a 40k-row upload of mostly unique content is the
# dominant cost. One sort does the same work.
seq_within_groups <- function(x) {
    n <- length(x)
    if (n == 0L) {
        return(integer(0))
    }
    o <- order(x)
    sorted <- x[o]
    starts <- c(TRUE, sorted[-1L] != sorted[-n])
    out <- integer(n)
    out[o] <- sequence(diff(c(which(starts), n + 1L)))
    out
}

# Build the identifier for rows that carry none.
#
# Deterministic by construction: the identifier is derived from the row's own
# content, so re-uploading the same spreadsheet reproduces the same identifiers
# instead of minting new ones. That is the requirement -- an identifier that
# stays the same across exports, so republishing updates a record rather than
# creating a duplicate.
#
# Rows whose content is identical are routine in aggregated datasets (the same
# taxon, at the same point, on the same date, arriving from different source
# studies), and Darwin Core requires occurrenceID to be unique within the
# dataset. Each is therefore disambiguated by its occurrence number within its
# content group. The cost is stated plainly rather than hidden: correcting a
# value changes that row's identifier, and reordering rows that are identical in
# every column can swap their identifiers between them.
#
# The encoding is confined to this function on purpose: swapping UUID v5 for a
# ULID or another digest must not reach any caller, or the vocabulary the user
# reads.
generate_persistent_ids <- function(df, rows = NULL, exclude = NULL) {
    n <- if (is.data.frame(df)) nrow(df) else 0L
    if (n == 0L) {
        return(character(0))
    }
    if (is.null(rows)) rows <- rep(TRUE, n)
    if (!any(rows)) {
        return(character(0))
    }

    # The identifier column itself never feeds the hash: a row that has no
    # identifier must hash the same whether the column is absent or blank.
    cols <- setdiff(names(df), c(exclude, "occurrenceID"))
    # ASCII unit/record separators join the parts. A plain concatenation would
    # let ("ab", "c") and ("a", "bc") hash to the same key; these bytes cannot
    # occur in spreadsheet cells, so the join is unambiguous.
    content <- if (length(cols) == 0L) {
        rep("", sum(rows))
    } else {
        do.call(paste, c(
            lapply(cols, function(col) as.character(df[[col]])[rows]),
            list(sep = "\u001f")
        ))
    }

    keys <- paste0(content, "\u001e", seq_within_groups(content))

    # UUID v5 is itself SHA-1 over (namespace + name), so the key goes in as the
    # name and no separate digest step is needed. Feed the distinct keys only,
    # in one vectorized call: UUIDfromName over a 40k vector is ~80x the loop.
    uniq <- unique(keys)
    hashed <- paste0("urn:uuid:", uuid::UUIDfromName(saira_id_namespace(), uniq))
    hashed[match(keys, uniq)]
}

# RFC 4122 URL namespace. Fixed forever: changing it would re-mint every
# identifier Saira has ever generated.
saira_id_namespace <- function() {
    "6ba7b811-9dad-11d1-80b4-00c04fd430c8"
}

# Resolve which column the occurrenceID should be taken from. The user's mapping
# wins, because the identifier column is rarely called "occurrenceID" in a
# publisher's own spreadsheet. The literal column is the fallback, which is what
# a re-imported Saira export and any already-standardized DwC file ship.
occurrence_id_source_column <- function(df, map_values = NULL) {
    if (!is.data.frame(df)) {
        return(NULL)
    }

    if (is.list(map_values)) {
        selected <- sanitize_map_selection(
            "occurrenceID", map_values[["occurrenceID"]]
        )
        if (has_selected_value(selected) && selected[[1]] %in% names(df)) {
            return(selected[[1]])
        }
    }
    if ("occurrenceID" %in% names(df)) {
        return("occurrenceID")
    }
    NULL
}

occurrence_id_source_values <- function(df, map_values = NULL) {
    col <- occurrence_id_source_column(df, map_values)
    if (is.null(col)) {
        return(NULL)
    }
    trimws(as.character(df[[col]]))
}

# Resolve the occurrenceID vector for a dataset.
#
# The whole rule, in one place: an identifier the row already carries wins, and
# Saira fills only the gaps. That is the TDWG guidance for the term ("in the
# absence of a persistent global unique identifier, construct one") and it is
# what makes the round trip work -- export, add rows, re-import, and everything
# already published keeps its identifier while only the new rows get one.
#
# Any stable string qualifies: Darwin Core requires occurrenceID to be unique
# within the dataset, not globally, so a publisher's own "ABBA_00001" is a
# perfectly good identifier and is preserved verbatim rather than rewritten.
#
# `map_values` is what makes the mapping authoritative; before it was threaded
# through, a source column named anything other than "occurrenceID" was silently
# replaced while the mapping guide still reported the ids as user-supplied.
#
# Returns the character vector with `id_strategy` and `id_counts` attributes
# describing what actually happened, which the mapping guide reports verbatim.
resolve_occurrence_ids <- function(df, n = NULL, map_values = NULL) {
    n <- n %||% (if (is.data.frame(df)) nrow(df) else length(df))

    # Generate only the identifiers actually needed. Building n and then
    # overwriting the supplied ones made a file that ships a complete column pay
    # for a full set and discard every one.
    out <- character(n)
    keep <- rep(FALSE, n)

    src_col <- occurrence_id_source_column(df, map_values)
    if (!is.null(src_col)) {
        src <- trimws(as.character(df[[src_col]]))
        if (length(src) == n) {
            keep <- !is.na(src) & nzchar(src)
            out[keep] <- src[keep]
        }
    }

    n_preserved <- sum(keep)
    if (n_preserved < n) {
        out[!keep] <- generate_persistent_ids(df, rows = !keep, exclude = src_col)
    }

    attr(out, "id_strategy") <- occurrence_id_strategy_label(n_preserved, n)
    attr(out, "id_counts") <- list(
        total = n,
        preserved = n_preserved,
        generated = n - n_preserved
    )
    out
}

# Name what produced a dataset's identifiers. The mapping guide keys its
# explanation off this label.
occurrence_id_strategy_label <- function(n_preserved, n_total) {
    if (n_preserved == n_total) {
        # Covers the empty frame too: nothing was generated.
        return("user_supplied")
    }
    if (n_preserved == 0L) {
        return("generated")
    }
    "user_supplied_with_generated"
}

# Darwin Core requires occurrenceID to be unique within a dataset, so the card
# reports collisions: pointing at a column that repeats is a GBIF blocker, and
# it is not obvious from looking at the data. Blank rows are counted apart from
# collisions -- a blank is not a duplicate, it just gets a generated id.
check_occurrence_id_uniqueness <- function(values) {
    v <- trimws(as.character(values))
    v[is.na(values)] <- ""
    filled <- nzchar(v)
    n_filled <- sum(filled)

    list(
        total = length(v),
        filled = n_filled,
        blank = sum(!filled),
        duplicates = n_filled - length(unique(v[filled])),
        ok = n_filled == length(unique(v[filled]))
    )
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
    if (!is.null(establishment_map) && !establishment_map_is_empty(establishment_map)) {
        sci_cols <- sanitize_map_selection("scientificName", map_values[["scientificName"]])
        if (has_selected_value(sci_cols) && sci_cols[[1]] %in% names(df)) {
            establishment_species <- as.character(df[[sci_cols[[1]]]])
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
                establishment_map = establishment_map, out_sep = out_sep
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
