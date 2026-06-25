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

sanitize_map_selection <- function(term, value) {
    if (is.null(value) || length(value) == 0) {
        return("")
    }

    value_chr <- as.character(value)
    value_chr <- value_chr[!is.na(value_chr)]
    value_chr <- trimws(value_chr)
    value_chr <- value_chr[nzchar(value_chr)]

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
    manual_only_terms <- c("occurrenceID", "modified", "license", "language")
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

    parsed <- lapply(scientific_names, function(value) {
        if (is_blank_value(value)) {
            return(list(
                genus = NA_character_,
                specificEpithet = NA_character_,
                taxonRank = NA_character_
            ))
        }

        cleaned <- gsub("\\|", " ", as.character(value))
        cleaned <- gsub("\\s+", " ", trimws(cleaned))
        tokens <- strsplit(cleaned, " ", fixed = TRUE)[[1]]
        tokens <- tokens[nzchar(tokens)]

        if (length(tokens) == 0) {
            return(list(
                genus = NA_character_,
                specificEpithet = NA_character_,
                taxonRank = NA_character_
            ))
        }

        genus <- format_genus_token(tokens[[1]])
        first_lower <- tolower(tokens[[1]])
        if (first_lower %in% unknown_markers) {
            genus <- NA_character_
        }

        if (is.na(genus)) {
            return(list(
                genus = NA_character_,
                specificEpithet = NA_character_,
                taxonRank = NA_character_
            ))
        }

        if (length(tokens) == 1) {
            return(list(
                genus = genus,
                specificEpithet = NA_character_,
                taxonRank = "genus"
            ))
        }

        second_lower <- tolower(tokens[[2]])
        if (second_lower %in% unknown_markers) {
            return(list(
                genus = genus,
                specificEpithet = NA_character_,
                taxonRank = "genus"
            ))
        }

        if (second_lower %in% qualifier_markers && length(tokens) >= 3) {
            specific <- format_epithet_token(tokens[[3]])
            return(list(
                genus = genus,
                specificEpithet = specific,
                taxonRank = if (!is.na(specific)) "species" else "genus"
            ))
        }

        specific <- format_epithet_token(tokens[[2]])
        if (is.na(specific)) {
            return(list(
                genus = genus,
                specificEpithet = NA_character_,
                taxonRank = "genus"
            ))
        }

        list(
            genus = genus,
            specificEpithet = specific,
            taxonRank = "species"
        )
    })

    data.frame(
        genus = vapply(parsed, function(x) x$genus, FUN.VALUE = character(1)),
        specificEpithet = vapply(parsed, function(x) x$specificEpithet, FUN.VALUE = character(1)),
        taxonRank = vapply(parsed, function(x) x$taxonRank, FUN.VALUE = character(1)),
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

    vapply(
        seq_len(nrow(df)),
        FUN = function(i) {
            row_tokens <- character(0)
            for (col_values in normalized_cols) {
                row_tokens <- c(row_tokens, split_output_tokens(col_values[[i]], out_sep = out_sep))
            }

            if (length(row_tokens) == 0) {
                return(NA_character_)
            }

            paste(row_tokens, collapse = out_sep)
        },
        FUN.VALUE = character(1)
    )
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

    month_map <- c(
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

    if (!normalized %in% names(month_map)) {
        return(NA_character_)
    }

    unname(month_map[[normalized]])
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

    raw_values <- collapse_mapped_values(df, cols, out_sep = " | ")
    row_values <- lapply(cols, function(col_name) {
        values <- as.character(df[[col_name]])
        values[is.na(df[[col_name]])] <- NA_character_
        values
    })

    blank_matrix <- do.call(cbind, lapply(row_values, function(values) {
        is.na(values) | !nzchar(trimws(values))
    }))
    all_blank <- rowSums(blank_matrix) == ncol(blank_matrix)

    start_month <- vapply(
        row_values[[role_indices[[1]]]],
        FUN = parse_month_to_number,
        FUN.VALUE = character(1)
    )
    start_year <- vapply(
        row_values[[role_indices[[2]]]],
        FUN = parse_year_to_number,
        FUN.VALUE = integer(1)
    )
    end_month <- vapply(
        row_values[[role_indices[[3]]]],
        FUN = parse_month_to_number,
        FUN.VALUE = character(1)
    )
    end_year <- vapply(
        row_values[[role_indices[[4]]]],
        FUN = parse_year_to_number,
        FUN.VALUE = integer(1)
    )

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
    } else if (term == "eventDate" && length(user_cols) == 4) {
        event_result <- build_eventdate_interval(df = df, cols = user_cols, fallback_raw = TRUE)
        values <- event_result$values
        failure_count <- event_result$failure_count
    } else if (length(user_cols) == 1) {
        values <- normalize_semicolon_tokens(df[[user_cols[[1]]]], out_sep = out_sep)
    } else {
        values <- collapse_mapped_values(df = df, cols = user_cols, out_sep = out_sep)
    }

    # Normalise to ISO 8601 (YYYY-MM-DD) for date-typed DWC terms so the card
    # preview matches what the export pipeline emits via fix_dates_to_iso().
    # Unparseable values (already-correct intervals "YYYY-MM/YYYY-MM", partial
    # dates like "2026", or invalid text) keep their raw value.
    if (term %in% c("eventDate", "dateIdentified")) {
        parsed <- parse_dates_to_iso(values)
        keep_raw <- is.na(parsed) & !is.na(values) & nzchar(values)
        parsed[keep_raw] <- values[keep_raw]
        values <- parsed
    }

    list(values = values, eventdate_failure_count = failure_count)
}

# Resolve the occurrenceID vector for a dataset. When the uploaded data already
# carries a non-blank `occurrenceID` column (e.g. a camera-trap observationID, or
# a CSV that ships stable identifiers), preserve those values for provenance;
# fill any missing/blank entries with fresh UUIDs. Datasets without the column
# keep the previous behaviour (all random UUIDs).
resolve_occurrence_ids <- function(df, n = NULL) {
    n <- n %||% (if (is.data.frame(df)) nrow(df) else length(df))
    out <- ids::uuid(n = n)
    if (is.data.frame(df) && "occurrenceID" %in% names(df)) {
        src <- trimws(as.character(df[["occurrenceID"]]))
        keep <- !is.na(src) & nzchar(src)
        out[keep] <- src[keep]
    }
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
  dyn_props_keys = list()
) {
    if (length(occurrence_ids) != nrow(df)) {
        stop("occurrence_ids must have the same length as nrow(df).")
    }

    df_final <- data.frame(matrix(ncol = 0, nrow = nrow(df)))
    eventdate_failure_count <- 0L
    selected_terms <- character(0)

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

        if (term == "modified") {
            if (isTRUE(modified_use_today)) {
                # Date only (no time/zone), matching the manual date-picker path
                # below -- the user wants a plain calendar date for `modified`.
                date_str <- format(now_utc, "%Y-%m-%d", tz = "UTC")
                df_final[[term]] <- rep(date_str, nrow(df))
                selected_terms <- c(selected_terms, term)
            } else if (!is.null(custom_modified_date)) {
                date_str <- format(as.Date(custom_modified_date), "%Y-%m-%d")
                df_final[[term]] <- rep(date_str, nrow(df))
                selected_terms <- c(selected_terms, term)
            }
            next
        }

        if (term == "license") {
            if (!is.null(custom_license) && length(custom_license) > 0) {
                df_final[[term]] <- rep(custom_license[[1]], nrow(df))
                selected_terms <- c(selected_terms, term)
            }
            next
        }

        if (term == "language") {
            if (!is.null(custom_language) && length(custom_language) > 0) {
                df_final[[term]] <- rep(custom_language[[1]], nrow(df))
                selected_terms <- c(selected_terms, term)
            }
            next
        }

        # Generalized fixed values (constant_value_terms allowlist): a single
        # enabled value is replicated across every row, taking precedence over
        # any column mapping for the term.
        if (term %in% names(constant_values)) {
            value <- constant_values[[term]]
            if (!is.null(value) && nzchar(trimws(value))) {
                df_final[[term]] <- rep(trimws(value), nrow(df))
                selected_terms <- c(selected_terms, term)
            }
            next
        }

        user_cols <- sanitize_map_selection(term, map_values[[term]])
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
        selected_terms <- c(selected_terms, "genus", "specificEpithet", "taxonRank")

        if (!"genus" %in% names(df_final)) {
            df_final$genus <- scientific_parts$genus
        } else {
            df_final$genus <- fill_missing_character_values(
                df_final$genus,
                scientific_parts$genus
            )
        }

        if (!"specificEpithet" %in% names(df_final)) {
            df_final$specificEpithet <- scientific_parts$specificEpithet
        } else {
            df_final$specificEpithet <- fill_missing_character_values(
                df_final$specificEpithet,
                scientific_parts$specificEpithet
            )
        }

        if (!"taxonRank" %in% names(df_final)) {
            df_final$taxonRank <- scientific_parts$taxonRank
        } else {
            df_final$taxonRank <- fill_missing_character_values(
                df_final$taxonRank,
                scientific_parts$taxonRank
            )
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
