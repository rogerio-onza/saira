# utils names reviews

# Title: Accepted name reviews and rank helpers
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

#' Apply manual name-review payload to export data
#'
#' @param df Data frame to export
#' @param payload Optional list with `entries` and `normalize_opts`
#' @return Data frame with review columns and optional scientificName replacements
#' @export
apply_name_review_payload <- function(df, payload = NULL) {
    if (!is.data.frame(df)) {
        warning("apply_name_review_payload: 'df' must be a data.frame, got ", class(df)[1L])
        return(df)
    }

    out <- df
    n_rows <- nrow(out)

    # ADR-088 (reverte ADR-051): audit columns `validacao_manual` e
    # `motivo_revisao` NAO sao mais emitidas no export. Correcoes feitas via
    # revisao manual de nomes ainda sao aplicadas silenciosamente ao
    # `scientificName` (replacement abaixo); a rastreabilidade vai pelo
    # `mapping_guide.txt` do bundle.
    if (n_rows == 0L) {
        return(out)
    }
    if (!("scientificName" %in% names(out))) {
        return(out)
    }
    if (is.null(payload) || !is.list(payload) || is.null(payload$entries) || !is.data.frame(payload$entries)) {
        return(out)
    }

    entries <- payload$entries
    required_cols <- c("query_name", "review_type", "original_name", "corrected_name", "reason", "reviewed_at")
    for (col_name in required_cols) {
        if (!(col_name %in% names(entries))) {
            if (identical(col_name, "reviewed_at")) {
                entries[[col_name]] <- as.POSIXct(rep(NA_character_, nrow(entries)), tz = "UTC")
            } else {
                entries[[col_name]] <- rep("", nrow(entries))
            }
        }
    }

    entries <- entries[, required_cols, drop = FALSE]
    entries$query_name <- as.character(entries$query_name)
    entries$review_type <- tolower(as.character(entries$review_type))
    entries$original_name <- as.character(entries$original_name)
    entries$corrected_name <- as.character(entries$corrected_name)
    entries$reason <- as.character(entries$reason)
    entries$reviewed_at <- as.POSIXct(entries$reviewed_at, tz = "UTC")

    keep <- !is.na(entries$query_name) &
        nzchar(entries$query_name) &
        entries$review_type %in% c("confirm", "correct")
    entries <- entries[keep, , drop = FALSE]
    if (nrow(entries) == 0L) {
        return(out)
    }

    ord <- order(entries$query_name, entries$reviewed_at, seq_len(nrow(entries)), na.last = TRUE)
    entries <- entries[ord, , drop = FALSE]
    entries <- entries[!duplicated(entries$query_name, fromLast = TRUE), , drop = FALSE]

    normalize_opts <- payload$normalize_opts
    remove_authors_opt <- TRUE
    ignore_qualifiers_opt <- TRUE
    if (is.list(normalize_opts)) {
        if (is.logical(normalize_opts$remove_authors) && length(normalize_opts$remove_authors) == 1L && !is.na(normalize_opts$remove_authors)) {
            remove_authors_opt <- isTRUE(normalize_opts$remove_authors)
        }
        if (is.logical(normalize_opts$ignore_qualifiers) && length(normalize_opts$ignore_qualifiers) == 1L && !is.na(normalize_opts$ignore_qualifiers)) {
            ignore_qualifiers_opt <- isTRUE(normalize_opts$ignore_qualifiers)
        }
    }

    scientific_name <- as.character(out$scientificName)
    scientific_name[is.na(scientific_name)] <- ""

    # Optimize: normalize only unique names to avoid redundant work on repeated values
    unique_names <- unique(scientific_name)
    unique_normalized <- vapply(unique_names, function(value) {
        normalized <- normalize_scientific_name(
            value,
            remove_authors = remove_authors_opt,
            ignore_qualifiers = ignore_qualifiers_opt
        )
        if (is.na(normalized) || !nzchar(normalized)) {
            trimws(as.character(value))
        } else {
            normalized
        }
    }, FUN.VALUE = character(1))
    query_name <- unique_normalized[match(scientific_name, unique_names)]

    match_idx <- match(query_name, entries$query_name)
    has_review <- !is.na(match_idx)
    if (!any(has_review)) {
        return(out)
    }

    review_type_vec <- rep("", n_rows)
    review_type_vec[has_review] <- entries$review_type[match_idx[has_review]]

    correct_mask <- has_review & review_type_vec == "correct"
    if (any(correct_mask)) {
        correct_idx <- match_idx[correct_mask]
        corrected_name <- trimws(as.character(entries$corrected_name[correct_idx]))
        original_name <- trimws(as.character(entries$original_name[correct_idx]))
        current_name <- as.character(out$scientificName[correct_mask])
        replacement <- corrected_name
        replacement[is.na(replacement) | !nzchar(replacement)] <- original_name[is.na(replacement) | !nzchar(replacement)]
        replacement[is.na(replacement) | !nzchar(replacement)] <- current_name[is.na(replacement) | !nzchar(replacement)]
        old_names <- out$scientificName
        out$scientificName[correct_mask] <- replacement
        # genus and the epithets came from the old name. Without this, a
        # synonym fix exports "Puma concolor" with genus "Felis".
        out <- refresh_taxon_terms(out, old_names)
    }

    out
}

#' Rank of each name the Names tab validated
#'
#' @param report Validation report (`validation_result()` of the Names tab).
#' @return Data frame `query_name`, `taxonRank` (lowercase), or NULL.
#' @noRd
name_rank_table <- function(report) {
    cols <- c("query_name", "taxonRank", "validation_status")
    if (!is.data.frame(report) || !all(cols %in% names(report))) {
        return(NULL)
    }
    rank <- tolower(trimws(as.character(report$taxonRank)))
    keep <- report$validation_status %in% c("accepted", "synonym") &
        !is.na(report$query_name) & !is.na(rank) & nzchar(rank)
    out <- data.frame(query_name = as.character(report$query_name[keep]),
                      taxonRank = rank[keep], stringsAsFactors = FALSE)
    out[!duplicated(out$query_name), , drop = FALSE]
}

#' Put the validated rank on one-word names (ADR-151)
#'
#' The mapping reads every one-word name as a genus, so "Felidae" leaves with
#' `taxonRank = genus` and `genus = Felidae`, and the GBIF match then fails. The
#' name provider knows the real rank. Only a blank or "genus" rank changes, so a
#' rank the user mapped from a column stays.
#'
#' @param df Data frame to export.
#' @param ranks Output of `name_rank_table()`.
#' @return `df` with the rank of higher taxa corrected.
#' @noRd
apply_name_rank_payload <- function(df, ranks) {
    if (!is.data.frame(df) || !is.data.frame(ranks) || nrow(ranks) == 0L ||
            !"scientificName" %in% names(df)) {
        return(df)
    }
    name <- trimws(as.character(df$scientificName))
    name[is.na(name)] <- ""
    rank <- ranks$taxonRank[match(name, ranks$query_name)]
    current <- if ("taxonRank" %in% names(df)) as.character(df$taxonRank) else rep(NA_character_, nrow(df))
    fix <- nzchar(name) & !grepl(" ", name, fixed = TRUE) & !is.na(rank) & rank != "genus" &
        (is.na(current) | !nzchar(trimws(current)) | current == "genus")
    if (!any(fix)) {
        return(df)
    }
    current[fix] <- rank[fix]
    df$taxonRank <- current
    if ("genus" %in% names(df)) {
        genus <- as.character(df$genus)
        genus[fix & !is.na(genus) & genus == name] <- ""
        df$genus <- genus
    }
    df
}
