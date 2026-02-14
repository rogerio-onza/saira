# Title: Mapping Utilities
# Author: Rogério Nunes Oliveira
# Date: 2026-02-11
# Version: 1.0

is_blank_value <- function(x) {
    if (is.null(x) || length(x) == 0) {
        return(TRUE)
    }
    if (is.na(x)) {
        return(TRUE)
    }
    nchar(trimws(as.character(x))) == 0
}

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

    if (identical(term, "scientificName")) {
        return(value_chr[[1]])
    }

    value_chr
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

normalize_for_matching <- function(x) {
    x_chr <- as.character(x)
    normalized <- tolower(x_chr)
    translit <- iconv(normalized, to = "ASCII//TRANSLIT")
    normalized[!is.na(translit)] <- translit[!is.na(translit)]
    normalized <- gsub("[^a-z0-9]+", " ", normalized)
    trimws(normalized)
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

load_dwc_synonyms_v1 <- function(path = NULL) {
    resolved_path <- NULL

    if (!is.null(path)) {
        resolved_path <- path
    } else {
        candidates <- c(
            system.file("extdata", "dwc_synonyms_v1.rds", package = "finch"),
            here::here("inst", "extdata", "dwc_synonyms_v1.rds"),
            file.path("inst", "extdata", "dwc_synonyms_v1.rds"),
            file.path("..", "..", "inst", "extdata", "dwc_synonyms_v1.rds"),
            # Backward-compatible fallbacks for dev environments not yet migrated
            system.file("data", "dwc_synonyms_v1.rds", package = "finch"),
            here::here("data", "dwc_synonyms_v1.rds"),
            file.path("data", "dwc_synonyms_v1.rds"),
            file.path("..", "..", "data", "dwc_synonyms_v1.rds")
        )
        candidates <- unique(candidates[nzchar(candidates)])
        resolved_path <- candidates[file.exists(candidates)][1]
    }

    if (is.null(resolved_path) || !file.exists(resolved_path)) {
        stop("dwc_synonyms_v1.rds not found in expected locations.")
    }

    synonyms_tbl <- readRDS(resolved_path)
    sanitize_synonyms_table(synonyms_tbl)
}

tokenize_for_matching <- function(x) {
    normalized <- normalize_for_matching(x)
    if (is_blank_value(normalized) || !nzchar(normalized)) {
        return(character(0))
    }

    parts <- strsplit(normalized, " ", fixed = TRUE)[[1]]
    parts <- trimws(parts)
    parts[nzchar(parts)]
}

score_token_overlap <- function(col_name, term) {
    col_tokens <- unique(tokenize_for_matching(col_name))
    term_tokens <- unique(tokenize_for_matching(term))

    if (length(col_tokens) == 0 || length(term_tokens) == 0) {
        return(0)
    }

    overlap <- length(intersect(col_tokens, term_tokens))
    if (overlap == 0) {
        return(0)
    }

    union_size <- length(unique(c(col_tokens, term_tokens)))
    overlap_ratio <- overlap / union_size
    pmin(0.80, pmax(0.55, 0.55 + 0.25 * overlap_ratio))
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

compute_name_score <- function(col_name, term, synonyms_tbl = NULL) {
    col_norm <- normalize_for_matching(col_name)
    term_norm <- normalize_for_matching(term)

    if (is_blank_value(col_norm) || is_blank_value(term_norm)) {
        return(list(score = 0, reason = "no_match", is_exact = FALSE))
    }

    if (identical(col_norm, term_norm)) {
        return(list(score = 1.00, reason = "exact_match", is_exact = TRUE))
    }

    if (!is.null(synonyms_tbl) && nrow(synonyms_tbl) > 0) {
        clean_synonyms <- sanitize_synonyms_table(synonyms_tbl)
        term_mask <- normalize_for_matching(clean_synonyms$term) == term_norm & clean_synonyms$active
        term_syn <- clean_synonyms[term_mask, , drop = FALSE]

        if (nrow(term_syn) > 0) {
            synonym_norm <- normalize_for_matching(term_syn$synonym)
            hit_idx <- which(synonym_norm == col_norm)
            if (length(hit_idx) > 0) {
                score <- max(term_syn$name_score[hit_idx], na.rm = TRUE)
                score <- pmin(0.98, pmax(0.90, score))
                return(list(score = score, reason = "known_synonym", is_exact = FALSE))
            }
        }
    }

    overlap_score <- score_token_overlap(col_name, term)
    if (overlap_score >= 0.55) {
        return(list(score = overlap_score, reason = "token_overlap", is_exact = FALSE))
    }

    similarity_score <- score_text_similarity(col_name, term)
    list(score = similarity_score, reason = "text_similarity", is_exact = FALSE)
}

sample_values_for_scoring <- function(values, name_score) {
    values_chr <- as.character(values)
    values_chr[is.na(values)] <- NA_character_
    values_chr <- trimws(values_chr)
    non_blank_values <- values_chr[!is.na(values_chr) & nzchar(values_chr)]

    if (length(non_blank_values) == 0) {
        return(character(0))
    }

    if (name_score >= 0.98) {
        target_n <- 30L
        head_n <- 30L
        random_n <- 0L
    } else if (name_score >= 0.85) {
        target_n <- 100L
        head_n <- 50L
        random_n <- 50L
    } else if (name_score >= 0.70) {
        target_n <- 200L
        head_n <- 100L
        random_n <- 100L
    } else {
        return(character(0))
    }

    total_n <- length(non_blank_values)
    if (total_n <= target_n) {
        return(non_blank_values)
    }

    head_idx <- seq_len(min(head_n, total_n))
    remaining_idx <- setdiff(seq_len(total_n), head_idx)
    random_take <- min(random_n, length(remaining_idx))
    random_idx <- if (random_take > 0) sample(remaining_idx, size = random_take, replace = FALSE) else integer(0)

    selected_idx <- sort(unique(c(head_idx, random_idx)))
    non_blank_values[selected_idx]
}

score_ratio_to_confidence <- function(valid_ratio) {
    valid_ratio <- pmin(1, pmax(0, valid_ratio))
    pmin(1, pmax(0.5, 0.5 + 0.5 * valid_ratio))
}

validate_numeric_range <- function(values, min_value, max_value) {
    numeric_values <- suppressWarnings(as.numeric(gsub(",", ".", values)))
    numeric_ratio <- mean(!is.na(numeric_values))
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

    numeric_ratio <- mean(!is.na(numeric_values))
    valid_ratio <- if (length(is_integer_non_negative) == 0) 0 else mean(is_integer_non_negative)

    list(
        score = score_ratio_to_confidence(valid_ratio),
        compatible_type = numeric_ratio >= 0.60,
        valid_ratio = valid_ratio,
        numeric_ratio = numeric_ratio
    )
}

compute_value_score <- function(values, term, name_score) {
    values_chr <- as.character(values)
    values_chr[is.na(values)] <- NA_character_
    non_blank <- values_chr[!is.na(values_chr) & nzchar(trimws(values_chr))]

    if (length(non_blank) == 0) {
        return(list(
            score = 0,
            reason = "empty_column",
            compatible_type = FALSE,
            sampled_n = 0L
        ))
    }

    if (name_score < 0.70) {
        return(list(
            score = 0,
            reason = "low_name_confidence",
            compatible_type = TRUE,
            sampled_n = 0L
        ))
    }

    sampled_values <- sample_values_for_scoring(values_chr, name_score)
    if (length(sampled_values) == 0) {
        return(list(
            score = 0,
            reason = "empty_column",
            compatible_type = FALSE,
            sampled_n = 0L
        ))
    }

    term_name <- as.character(term)

    if (identical(term_name, "decimalLatitude")) {
        lat_result <- validate_numeric_range(sampled_values, -90, 90)
        return(list(
            score = lat_result$score,
            reason = if (lat_result$valid_ratio >= 0.80) "content_validated" else "weak_content_validation",
            compatible_type = lat_result$compatible_type,
            sampled_n = length(sampled_values)
        ))
    }

    if (identical(term_name, "decimalLongitude")) {
        lon_result <- validate_numeric_range(sampled_values, -180, 180)
        return(list(
            score = lon_result$score,
            reason = if (lon_result$valid_ratio >= 0.80) "content_validated" else "weak_content_validation",
            compatible_type = lon_result$compatible_type,
            sampled_n = length(sampled_values)
        ))
    }

    if (identical(term_name, "scientificName")) {
        sn_result <- validate_scientific_name_pattern(sampled_values)
        return(list(
            score = sn_result$score,
            reason = if (sn_result$valid_ratio >= 0.80) "content_validated" else "weak_content_validation",
            compatible_type = sn_result$compatible_type,
            sampled_n = length(sampled_values)
        ))
    }

    if (identical(term_name, "individualCount")) {
        count_result <- validate_individual_count(sampled_values)
        return(list(
            score = count_result$score,
            reason = if (count_result$valid_ratio >= 0.80) "content_validated" else "weak_content_validation",
            compatible_type = count_result$compatible_type,
            sampled_n = length(sampled_values)
        ))
    }

    list(
        score = 0.80,
        reason = "neutral_no_validator",
        compatible_type = TRUE,
        sampled_n = length(sampled_values)
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
    length(tokenize_for_matching(x))
}

resolve_reason_code <- function(name_reason, value_reason, status, compatible_type, is_temporal_limited = FALSE) {
    if (identical(status, "EDITADO")) {
        return("manual_adjust")
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

run_automap_v1 <- function(df, dwc_terms_df, synonyms_tbl) {
    if (!is.data.frame(df)) {
        stop("df must be a data.frame.")
    }
    if (!is.data.frame(dwc_terms_df) || !"term" %in% names(dwc_terms_df)) {
        stop("dwc_terms_df must be a data.frame with a 'term' column.")
    }

    clean_synonyms <- sanitize_synonyms_table(synonyms_tbl)
    terms <- unique(as.character(dwc_terms_df$term))
    columns <- names(df)
    temporal_terms <- c("eventDate", "year", "month", "day", "modified", "dateIdentified")
    manual_only_terms <- c("occurrenceID", "modified", "license", "language")

    term_results <- lapply(terms, function(term) {
        if (term %in% manual_only_terms) {
            return(data.frame(
                term = term,
                selected_col = NA_character_,
                name_score = NA_real_,
                value_score = NA_real_,
                final_score = NA_real_,
                status = "MANUAL",
                reason = "manual_only_term",
                applied = FALSE,
                compatible_type = TRUE,
                specificity = 0,
                stringsAsFactors = FALSE
            ))
        }

        if (length(columns) == 0) {
            return(data.frame(
                term = term,
                selected_col = NA_character_,
                name_score = 0,
                value_score = 0,
                final_score = 0,
                status = "MANUAL",
                reason = "no_columns_available",
                applied = FALSE,
                compatible_type = TRUE,
                specificity = 0,
                stringsAsFactors = FALSE
            ))
        }

        is_temporal_limited <- term %in% temporal_terms
        candidate_rows <- lapply(columns, function(col_name) {
            name_res <- compute_name_score(col_name, term, clean_synonyms)

            if (is_temporal_limited && !isTRUE(name_res$is_exact)) {
                return(NULL)
            }

            value_res <- compute_value_score(df[[col_name]], term, name_res$score)
            final_score <- 0.5 * name_res$score + 0.5 * value_res$score
            status <- classify_automap_status(final_score, compatible_type = value_res$compatible_type)
            applied <- status %in% c("AUTO", "SUGERIDO")
            reason <- resolve_reason_code(
                name_reason = name_res$reason,
                value_reason = value_res$reason,
                status = status,
                compatible_type = value_res$compatible_type,
                is_temporal_limited = is_temporal_limited
            )

            data.frame(
                term = term,
                selected_col = as.character(col_name),
                name_score = as.numeric(name_res$score),
                value_score = as.numeric(value_res$score),
                final_score = as.numeric(final_score),
                status = status,
                reason = reason,
                applied = applied,
                compatible_type = isTRUE(value_res$compatible_type),
                specificity = count_relevant_tokens(col_name),
                stringsAsFactors = FALSE
            )
        })

        candidate_rows <- Filter(Negate(is.null), candidate_rows)

        if (length(candidate_rows) == 0) {
            return(data.frame(
                term = term,
                selected_col = NA_character_,
                name_score = 0,
                value_score = 0,
                final_score = 0,
                status = "MANUAL",
                reason = if (is_temporal_limited) "temporal_manual_only" else "no_confident_match",
                applied = FALSE,
                compatible_type = TRUE,
                specificity = 0,
                stringsAsFactors = FALSE
            ))
        }

        candidates_df <- do.call(rbind, candidate_rows)
        ordering <- order(
            -candidates_df$final_score,
            -candidates_df$value_score,
            -candidates_df$specificity
        )
        best <- candidates_df[ordering[1], , drop = FALSE]

        if (!isTRUE(best$compatible_type) && identical(best$status, "AUTO")) {
            best$status <- "SUGERIDO"
            best$applied <- TRUE
            best$reason <- "type_incompatible"
        }

        if (best$final_score < 0.75) {
            best$status <- "MANUAL"
            best$applied <- FALSE
            best$selected_col <- NA_character_
            if (!is_temporal_limited) {
                best$reason <- "no_confident_match"
            }
        }

        best
    })

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

    keep_cols <- c("term", "selected_col", "name_score", "value_score", "final_score", "status", "reason", "applied")
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
    x_chr[is.na(x)] <- NA_character_

    vapply(
        x_chr,
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

detect_eventdate_roles <- function(col_names) {
    normalized_names <- normalize_for_matching(col_names)
    used <- rep(FALSE, length(normalized_names))

    start_mask <- grepl("\\b(start|begin|initial|inicio|from)\\b", normalized_names)
    end_mask <- grepl("\\b(end|final|fim|to)\\b", normalized_names)
    month_mask <- grepl("\\b(month|mo|mes)\\b", normalized_names)
    year_mask <- grepl("\\b(year|yr|ano)\\b", normalized_names)

    pick_first <- function(mask) {
        idx <- which(mask & !used)
        if (length(idx) == 0) {
            return(NA_integer_)
        }
        used[idx[1]] <<- TRUE
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
    result <- rep(NA_character_, nrow(df))
    failed_rows <- rep(FALSE, nrow(df))

    for (i in seq_len(nrow(df))) {
        row_values <- vapply(
            cols,
            FUN = function(col_name) as.character(df[[col_name]][[i]]),
            FUN.VALUE = character(1)
        )

        if (all(vapply(row_values, is_blank_value, FUN.VALUE = logical(1)))) {
            result[[i]] <- NA_character_
            next
        }

        start_month <- parse_month_to_number(row_values[[role_indices[[1]]]])
        start_year <- parse_year_to_number(row_values[[role_indices[[2]]]])
        end_month <- parse_month_to_number(row_values[[role_indices[[3]]]])
        end_year <- parse_year_to_number(row_values[[role_indices[[4]]]])

        if (all(!is.na(c(start_month, start_year, end_month, end_year)))) {
            result[[i]] <- sprintf("%04d-%s/%04d-%s", start_year, start_month, end_year, end_month)
        } else {
            failed_rows[[i]] <- TRUE
            result[[i]] <- if (isTRUE(fallback_raw)) raw_values[[i]] else NA_character_
        }
    }

    list(
        values = result,
        failed_rows = failed_rows,
        failure_count = sum(failed_rows),
        role_map = role_map
    )
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
    now_utc = Sys.time(),
    out_sep = " | "
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
                date_str <- format(now_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
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

        user_cols <- sanitize_map_selection(term, map_values[[term]])
        if (!has_selected_value(user_cols)) {
            next
        }

        if (term == "scientificName" && length(user_cols) > 1) {
            user_cols <- user_cols[[1]]
        }

        selected_terms <- c(selected_terms, term)

        if (term == "eventDate" && length(user_cols) == 4) {
            event_result <- build_eventdate_interval(
                df = df,
                cols = user_cols,
                fallback_raw = TRUE
            )
            df_final[[term]] <- event_result$values
            eventdate_failure_count <- eventdate_failure_count + event_result$failure_count
        } else if (length(user_cols) == 1) {
            df_final[[term]] <- normalize_semicolon_tokens(
                df[[user_cols[[1]]]],
                out_sep = out_sep
            )
        } else {
            df_final[[term]] <- collapse_mapped_values(
                df = df,
                cols = user_cols,
                out_sep = out_sep
            )
        }
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
