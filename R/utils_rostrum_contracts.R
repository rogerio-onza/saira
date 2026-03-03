# Title: Rostrum Contracts and Options
# Author: Rogerio Nunes Oliveira
# Date: 2026-03-01
# Version: 1.0

#' Configure Rostrum Engine Options
#'
#' Returns a validated options list controlling the Rostrum auto-mapping engine's
#' scoring thresholds, parallelization, and debug behaviour.
#'
#' @param ... Named option overrides. See Details.
#' @details
#' Available options:
#' \describe{
#'   \item{auto_apply_threshold}{Numeric [0,1]. Score above which a mapping is applied automatically (default 0.90).}
#'   \item{suggest_threshold}{Numeric [0,1]. Score above which a mapping is suggested but not auto-applied (default 0.75).}
#'   \item{hard_veto_threshold}{Numeric [0,1]. Score below which a mapping is vetoed (default 0.30).}
#'   \item{max_sample_n}{Positive integer. Maximum rows sampled for value scoring (default 1000L).}
#'   \item{stage1_parallel}{Logical. Enable parallel Stage 1 evaluation (default FALSE).}
#'   \item{debug}{Logical. Enable verbose debug logging (default FALSE).}
#' }
#' @return A named list of class \code{rostrum_options}.
#' @export
rostrum_options <- function(...) {
    defaults <- list(
        auto_apply_threshold = 0.90,
        suggest_threshold = 0.75,
        hard_veto_threshold = 0.30,
        token_overlap_min_value_score = 0.80,
        ambiguity_gap = 0.10,
        risk_policy = "conservative",
        max_sample_n = 1000L,
        stage1_name_prune_threshold = 0.45,
        stage1_parallel = FALSE,
        stage1_parallel_workers = 2L,
        stage1_parallel_strategy = "multisession",
        debug = FALSE
    )

    overrides <- list(...)
    if (length(overrides) > 0L) {
        unknown <- setdiff(names(overrides), names(defaults))
        if (length(unknown) > 0L) {
            stop("Unknown rostrum option(s): ", paste(unknown, collapse = ", "))
        }
        defaults[names(overrides)] <- overrides
    }

    numeric01 <- c(
        "auto_apply_threshold",
        "suggest_threshold",
        "hard_veto_threshold",
        "token_overlap_min_value_score",
        "ambiguity_gap",
        "stage1_name_prune_threshold"
    )
    for (name in numeric01) {
        value <- suppressWarnings(as.numeric(defaults[[name]]))
        if (length(value) != 1L || is.na(value) || value < 0 || value > 1) {
            stop(name, " must be a numeric scalar in [0, 1].")
        }
        defaults[[name]] <- value
    }

    if (defaults$auto_apply_threshold < defaults$suggest_threshold) {
        stop("auto_apply_threshold must be >= suggest_threshold.")
    }
    if (!is.character(defaults$risk_policy) || length(defaults$risk_policy) != 1L || is.na(defaults$risk_policy)) {
        stop("risk_policy must be a non-empty character scalar.")
    }
    defaults$risk_policy <- trimws(tolower(defaults$risk_policy))
    if (!defaults$risk_policy %in% c("conservative")) {
        stop("risk_policy must be one of: conservative.")
    }

    sample_n <- suppressWarnings(as.integer(defaults$max_sample_n))
    if (length(sample_n) != 1L || is.na(sample_n) || sample_n <= 0L) {
        stop("max_sample_n must be a positive integer scalar.")
    }
    defaults$max_sample_n <- sample_n

    if (!is.logical(defaults$stage1_parallel) || length(defaults$stage1_parallel) != 1L || is.na(defaults$stage1_parallel)) {
        stop("stage1_parallel must be a single TRUE or FALSE value.")
    }
    defaults$stage1_parallel <- isTRUE(defaults$stage1_parallel)

    workers <- suppressWarnings(as.integer(defaults$stage1_parallel_workers))
    if (length(workers) != 1L || is.na(workers) || workers <= 0L) {
        stop("stage1_parallel_workers must be a positive integer scalar.")
    }
    defaults$stage1_parallel_workers <- workers

    if (!is.character(defaults$stage1_parallel_strategy) ||
        length(defaults$stage1_parallel_strategy) != 1L ||
        is.na(defaults$stage1_parallel_strategy)) {
        stop("stage1_parallel_strategy must be a non-empty character scalar.")
    }
    defaults$stage1_parallel_strategy <- trimws(tolower(defaults$stage1_parallel_strategy))
    if (!defaults$stage1_parallel_strategy %in% c("multisession", "sequential")) {
        stop("stage1_parallel_strategy must be one of: multisession, sequential.")
    }

    if (!is.logical(defaults$debug) || length(defaults$debug) != 1L || is.na(defaults$debug)) {
        stop("debug must be a single TRUE or FALSE value.")
    }
    defaults$debug <- isTRUE(defaults$debug)

    class(defaults) <- c("rostrum_options", class(defaults))
    defaults
}

#' Validate a Rostrum Candidate Data Frame
#'
#' Checks that \code{candidate_df} conforms to the Stage 1 output contract.
#' Stops with an informative error if any required column is missing or has an
#' unexpected type or out-of-range value.
#'
#' @param candidate_df A data frame produced by \code{run_rostrum_stage1}.
#' @return Invisibly \code{TRUE} on success; stops on failure.
#' @export
validate_candidate_df <- function(candidate_df) {
    if (!is.data.frame(candidate_df)) {
        stop("candidate_df must be a data.frame.")
    }

    required_cols <- c(
        "term",
        "column_name",
        "name_score",
        "value_score",
        "penalty_score",
        "veto_code",
        "final_score",
        "decision_band",
        "reason_code",
        "explain_json"
    )
    missing_cols <- setdiff(required_cols, names(candidate_df))
    if (length(missing_cols) > 0L) {
        stop("candidate_df is missing required columns: ", paste(missing_cols, collapse = ", "))
    }

    if (!is.character(candidate_df$term)) {
        stop("candidate_df$term must be character.")
    }
    if (!is.character(candidate_df$column_name)) {
        stop("candidate_df$column_name must be character.")
    }

    score_cols <- c("name_score", "value_score", "final_score")
    for (name in score_cols) {
        if (!is.numeric(candidate_df[[name]])) {
            stop("candidate_df$", name, " must be numeric.")
        }
        invalid <- !is.na(candidate_df[[name]]) & (candidate_df[[name]] < 0 | candidate_df[[name]] > 1)
        if (any(invalid)) {
            stop("candidate_df$", name, " values must be in [0, 1].")
        }
    }

    if (!is.numeric(candidate_df$penalty_score)) {
        stop("candidate_df$penalty_score must be numeric.")
    }
    penalty_invalid <- !is.na(candidate_df$penalty_score) &
        (candidate_df$penalty_score < -1 | candidate_df$penalty_score > 1)
    if (any(penalty_invalid)) {
        stop("candidate_df$penalty_score values must be in [-1, 1].")
    }

    if (!is.character(candidate_df$veto_code)) {
        stop("candidate_df$veto_code must be character.")
    }
    if (!is.character(candidate_df$decision_band)) {
        stop("candidate_df$decision_band must be character.")
    }
    if (!is.character(candidate_df$reason_code)) {
        stop("candidate_df$reason_code must be character.")
    }
    if (!is.character(candidate_df$explain_json)) {
        stop("candidate_df$explain_json must be character.")
    }

    allowed_bands <- c("AUTO", "SUGERIDO", "AMBIGUO", "MANUAL")
    band_invalid <- !is.na(candidate_df$decision_band) & !(candidate_df$decision_band %in% allowed_bands)
    if (any(band_invalid)) {
        stop("candidate_df$decision_band contains unsupported values.")
    }

    invisible(TRUE)
}

#' Validate a Rostrum Decision Data Frame
#'
#' Checks that \code{decision_df} conforms to the Stage 3 output contract.
#' Stops with an informative error if any required column is missing or has an
#' unexpected type or out-of-range value.
#'
#' @param decision_df A data frame produced by \code{rostrum_stage3_resolve}.
#' @return Invisibly \code{TRUE} on success; stops on failure.
#' @export
validate_decision_df <- function(decision_df) {
    if (!is.data.frame(decision_df)) {
        stop("decision_df must be a data.frame.")
    }

    required_cols <- c(
        "term",
        "selected_col",
        "status",
        "score",
        "score_gap",
        "ambiguity_flag",
        "source",
        "provenance_id"
    )
    missing_cols <- setdiff(required_cols, names(decision_df))
    if (length(missing_cols) > 0L) {
        stop("decision_df is missing required columns: ", paste(missing_cols, collapse = ", "))
    }

    char_cols <- c("term", "selected_col", "status", "source", "provenance_id")
    for (name in char_cols) {
        if (!is.character(decision_df[[name]])) {
            stop("decision_df$", name, " must be character.")
        }
    }

    if (!is.numeric(decision_df$score)) {
        stop("decision_df$score must be numeric.")
    }
    score_invalid <- !is.na(decision_df$score) & (decision_df$score < 0 | decision_df$score > 1)
    if (any(score_invalid)) {
        stop("decision_df$score values must be in [0, 1].")
    }

    if (!is.numeric(decision_df$score_gap)) {
        stop("decision_df$score_gap must be numeric.")
    }
    gap_invalid <- !is.na(decision_df$score_gap) & (decision_df$score_gap < 0 | decision_df$score_gap > 1)
    if (any(gap_invalid)) {
        stop("decision_df$score_gap values must be in [0, 1].")
    }

    if (!is.logical(decision_df$ambiguity_flag)) {
        stop("decision_df$ambiguity_flag must be logical.")
    }

    allowed_status <- c("AUTO", "SUGERIDO", "AMBIGUO", "MANUAL", "EDITADO")
    status_invalid <- !is.na(decision_df$status) & !(decision_df$status %in% allowed_status)
    if (any(status_invalid)) {
        stop("decision_df$status contains unsupported values.")
    }

    allowed_source <- c("auto", "alias", "template", "manual")
    source_invalid <- !is.na(decision_df$source) & !(decision_df$source %in% allowed_source)
    if (any(source_invalid)) {
        stop("decision_df$source contains unsupported values.")
    }

    invisible(TRUE)
}

validate_composition_df <- function(composition_df) {
    if (!is.data.frame(composition_df)) {
        stop("composition_df must be a data.frame.")
    }

    required_cols <- c(
        "term",
        "selected_col",
        "status",
        "reason",
        "applied",
        "composed_from_json"
    )
    missing_cols <- setdiff(required_cols, names(composition_df))
    if (length(missing_cols) > 0L) {
        stop("composition_df is missing required columns: ", paste(missing_cols, collapse = ", "))
    }

    if (!is.character(composition_df$term)) {
        stop("composition_df$term must be character.")
    }
    if (!is.character(composition_df$selected_col)) {
        stop("composition_df$selected_col must be character.")
    }
    if (!is.character(composition_df$status)) {
        stop("composition_df$status must be character.")
    }
    if (!is.character(composition_df$reason)) {
        stop("composition_df$reason must be character.")
    }
    if (!is.logical(composition_df$applied)) {
        stop("composition_df$applied must be logical.")
    }
    if (!is.character(composition_df$composed_from_json)) {
        stop("composition_df$composed_from_json must be character.")
    }

    allowed_status <- c("AUTO", "SUGERIDO", "AMBIGUO", "MANUAL", "EDITADO")
    status_invalid <- !is.na(composition_df$status) & !(composition_df$status %in% allowed_status)
    if (any(status_invalid)) {
        stop("composition_df$status contains unsupported values.")
    }

    invisible(TRUE)
}

#' Adapt V1 Synonym Table to V2 Schema
#'
#' Converts a synonym data frame in the legacy V1 format (columns
#' \code{term}, \code{synonym}, \code{name_score}, \code{lang}, \code{active})
#' to the V2 schema expected by \code{rostrum_seed_synonyms_if_empty}.
#'
#' @param synonyms_v1_df A data frame with V1 synonym columns.
#' @param updated_at ISO-8601 timestamp string used for \code{updated_at} (defaults to current UTC time).
#' @return A data frame conforming to the V2 synonym schema.
#' @export
adapt_synonyms_v1_to_v2 <- function(synonyms_v1_df, updated_at = rostrum_now_utc()) {
    if (!is.data.frame(synonyms_v1_df)) {
        stop("synonyms_v1_df must be a data.frame.")
    }

    required_cols <- c("term", "synonym", "name_score", "lang", "active")
    missing_cols <- setdiff(required_cols, names(synonyms_v1_df))
    if (length(missing_cols) > 0L) {
        stop("synonyms_v1_df is missing required columns: ", paste(missing_cols, collapse = ", "))
    }

    out <- data.frame(
        term = trimws(as.character(synonyms_v1_df$term)),
        synonym = trimws(as.character(synonyms_v1_df$synonym)),
        language = trimws(tolower(as.character(synonyms_v1_df$lang))),
        context = rep("unknown", nrow(synonyms_v1_df)),
        confidence = suppressWarnings(as.numeric(synonyms_v1_df$name_score)),
        validation_regex = rep(NA_character_, nrow(synonyms_v1_df)),
        notes = rep("Migrated from v1 RDS", nrow(synonyms_v1_df)),
        active = as.integer(as.logical(synonyms_v1_df$active)),
        source = rep("v1_rds", nrow(synonyms_v1_df)),
        updated_at = rep(updated_at, nrow(synonyms_v1_df)),
        stringsAsFactors = FALSE
    )

    out$language[out$language == "any"] <- "mul"

    if (any(is.na(out$term) | !nzchar(out$term))) {
        stop("adapt_synonyms_v1_to_v2 produced invalid term values.")
    }
    if (any(is.na(out$synonym) | !nzchar(out$synonym))) {
        stop("adapt_synonyms_v1_to_v2 produced invalid synonym values.")
    }
    if (any(is.na(out$language) | !nzchar(out$language))) {
        stop("adapt_synonyms_v1_to_v2 produced invalid language values.")
    }
    if (any(is.na(out$confidence) | out$confidence < 0 | out$confidence > 1)) {
        stop("adapt_synonyms_v1_to_v2 produced invalid confidence values.")
    }

    out
}
