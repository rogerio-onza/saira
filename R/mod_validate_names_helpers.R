# mod_validate_names_helpers.R
# Pure helper functions and package-level constants for mod_validate_names.
# No reactive dependencies — all inputs are explicit parameters.
# Extracted from mod_validate_names.R for testability and DRY.

# ---------------------------------------------------------------------------
# Package-level constants
# ---------------------------------------------------------------------------

.vn_provider_labels <- c(florabr = "Flora BR", faunabr = "Fauna BR", gbif = "GBIF")
.vn_stream_window_limit <- 100L
# "invasive" filters on a different axis than the rest: the others read
# validation_status, this one reads the species name against the bundled
# invasive list. Kept in the same bar because the user reasons about both as
# "narrow the processed names down to the ones I care about".
.vn_stream_filter_values <- c("all", "problems", "not_found", "ambiguous", "synonym", "ignored", "accepted", "invasive")
.vn_problem_status_values <- c("not_found", "ambiguous", "synonym")
.vn_review_exit_ms <- 320L

# ---------------------------------------------------------------------------
# Provider utilities
# ---------------------------------------------------------------------------

#' Format provider IDs into display labels
#' @param provider_values Character vector of provider IDs
#' @return Character vector of display labels
#' @noRd
format_provider_labels <- function(provider_values) {
    values_chr <- as.character(provider_values)
    values_chr <- values_chr[!is.na(values_chr) & nzchar(values_chr)]
    if (length(values_chr) == 0L) {
        return(character(0))
    }
    labels <- unname(.vn_provider_labels[values_chr])
    missing_idx <- is.na(labels) | !nzchar(labels)
    labels[missing_idx] <- toupper(values_chr[missing_idx])
    unique(labels)
}

#' Normalize provider failures data frame
#' @param raw_failures Data frame (or NULL) with provider and error columns
#' @return Data frame with columns provider, error (0 or more rows)
#' @noRd
normalize_provider_failures <- function(raw_failures) {
    if (!is.data.frame(raw_failures) || nrow(raw_failures) == 0L) {
        return(data.frame(provider = character(0), error = character(0), stringsAsFactors = FALSE))
    }

    out <- raw_failures
    if (!"provider" %in% names(out)) out$provider <- NA_character_
    if (!"error" %in% names(out)) out$error <- NA_character_
    out$provider <- as.character(out$provider)
    out$error <- as.character(out$error)
    out <- out[!is.na(out$provider) & nzchar(out$provider), c("provider", "error"), drop = FALSE]
    rownames(out) <- NULL
    out
}

#' Format provider failure lines with i18n
#' @param failure_df Data frame with provider and error columns
#' @param resolved_unique Integer count of resolved unique queries
#' @param lang Language code ("pt" or "en")
#' @return Character vector of formatted failure messages
#' @noRd
provider_failure_lines <- function(failure_df, resolved_unique = 0L, lang = "pt") {
    if (!is.data.frame(failure_df) || nrow(failure_df) == 0L) {
        return(character(0))
    }

    resolved_int <- suppressWarnings(as.integer(resolved_unique))
    if (is.na(resolved_int) || resolved_int < 0L) resolved_int <- 0L

    vapply(seq_len(nrow(failure_df)), function(i) {
        provider_label <- format_provider_labels(failure_df$provider[[i]])
        if (length(provider_label) == 0L) {
            provider_label <- toupper(as.character(failure_df$provider[[i]]))
        } else {
            provider_label <- provider_label[[1]]
        }
        error_text <- as.character(failure_df$error[[i]])
        if (is.na(error_text) || !nzchar(error_text)) error_text <- tr("validate_names_error_unknown", lang)
        sprintf(tr("validate_names_provider_failed_stream_item", lang), provider_label, resolved_int, error_text)
    }, FUN.VALUE = character(1))
}

# ---------------------------------------------------------------------------
# Stream utilities
# ---------------------------------------------------------------------------

#' Return top N rows from stream df, ordered by display_order descending
#' @param stream_df Stream data frame
#' @param limit Maximum number of rows to return
#' @return Filtered data frame
#' @noRd
stream_window <- function(stream_df, limit = .vn_stream_window_limit) {
    if (!is.data.frame(stream_df) || nrow(stream_df) == 0L) {
        return(stream_df)
    }
    out <- stream_df
    if (!"display_order" %in% names(out)) out$display_order <- seq_len(nrow(out))
    out <- out[order(out$display_order, decreasing = TRUE), , drop = FALSE]
    if (!is.null(limit) && !is.infinite(limit)) {
        limit_int <- suppressWarnings(as.integer(limit))
        if (!is.na(limit_int) && limit_int > 0L && nrow(out) > limit_int) {
            out <- out[seq_len(limit_int), , drop = FALSE]
        }
    }
    rownames(out) <- NULL
    out
}

#' Get phase label string for a run state
#' @param state Run state object with $phase field
#' @param lang Language code ("pt" or "en")
#' @return Character string
#' @noRd
phase_label <- function(state, lang = "pt") {
    phase_value <- as.character(state$phase %||% "")
    switch(phase_value,
        prepare = tr("validate_names_progress_phase_prepare", lang),
        provider_init = tr("validate_names_progress_phase_provider_init", lang),
        provider_query_batch = tr("validate_names_progress_phase_provider_query_batch", lang),
        provider_finalize = tr("validate_names_progress_phase_provider_finalize", lang),
        consolidate = tr("validate_names_progress_phase_consolidate", lang),
        done = tr("validate_names_progress_phase_done", lang),
        failed = tr("validate_names_progress_phase_failed", lang),
        tr("validate_names_progress_phase_prepare", lang)
    )
}

#' Get FA icon name for current validation phase
#' @param state Run state object with $phase and $current_provider fields
#' @return Character string with FA icon name
#' @noRd
vn_phase_icon <- function(state) {
    phase <- as.character(state$phase %||% "")
    provider <- as.character(state$current_provider %||% "")
    is_br <- provider %in% c("florabr", "faunabr")

    if (identical(phase, "provider_init") && is_br && !brprovider_data_available(provider)) {
        return("download")
    }
    switch(phase,
        prepare              = "gears",
        provider_init        = "plug",
        provider_query_batch = "microscope",
        provider_finalize    = "circle-notch",
        consolidate          = "layer-group",
        done                 = "flag-checkered",
        failed               = "triangle-exclamation",
        "spinner"
    )
}

#' Get phase text with BR download detection
#' @param state Run state object
#' @param lang Language code ("pt" or "en")
#' @return Character string with phase description
#' @noRd
vn_phase_text <- function(state, lang = "pt") {
    phase <- as.character(state$phase %||% "")
    provider <- as.character(state$current_provider %||% "")
    is_br <- provider %in% c("florabr", "faunabr")

    if (identical(phase, "provider_init") && is_br && !brprovider_data_available(provider)) {
        return(sprintf(tr("validate_names_loading_phase_provider_download", lang), provider))
    }
    phase_label(state, lang)
}

#' Recommend stream filter after validation completes
#' @param report_df Finalized validation report data frame
#' @return Character: "all" or "problems"
#' @noRd
stream_filter_after_completion <- function(report_df) {
    if (!is.data.frame(report_df) || nrow(report_df) == 0L) {
        return("all")
    }
    "problems"
}

# ---------------------------------------------------------------------------
# Status classification
# ---------------------------------------------------------------------------

#' Map validation status to style attributes
#' @param status_value Status value string
#' @return Named list with key, icon_symbol, label_key, item_class, badge_class, row_class
#' @noRd
status_style_map <- function(status_value) {
    status_key <- as.character(status_value)
    status_key <- ifelse(is.na(status_key) | !nzchar(status_key), "not_found", tolower(status_key))

    if (identical(status_key, "accepted")) {
        return(list(
            key = "accepted",
            icon_symbol = "\u2713",
            label_key = "validate_names_stream_status_accepted",
            item_class = "vn-stream-item-accepted",
            badge_class = "badge-success",
            row_class = "vn-row-accepted"
        ))
    }
    if (identical(status_key, "synonym")) {
        return(list(
            key = "synonym",
            icon_symbol = "\u21C4",
            label_key = "validate_names_stream_status_synonym",
            item_class = "vn-stream-item-synonym",
            badge_class = "badge-info",
            row_class = "vn-row-synonym"
        ))
    }
    if (status_key %in% c("ambiguous", "unresolved")) {
        return(list(
            key = "ambiguous",
            icon_symbol = "?",
            label_key = "validate_names_stream_status_ambiguous",
            item_class = "vn-stream-item-ambiguous",
            badge_class = "badge-warning",
            row_class = "vn-row-ambiguous"
        ))
    }
    if (status_key %in% c("invalid", "ignored")) {
        return(list(
            key = "ignored",
            icon_symbol = "\u2014",
            label_key = "validate_names_stream_status_ignored",
            item_class = "vn-stream-item-ignored",
            badge_class = "badge-muted",
            row_class = "vn-row-ignored"
        ))
    }
    list(
        key = "not_found",
        icon_symbol = "\u2715",
        label_key = "validate_names_stream_status_not_found",
        item_class = "vn-stream-item-not-found",
        badge_class = "badge-error",
        row_class = "vn-row-not-found"
    )
}

#' Normalize status value to canonical filter key
#' @param status_value Raw status value
#' @return Canonical key: one of "accepted", "synonym", "not_found", "ambiguous", "ignored"
#' @noRd
normalize_status_for_filter <- function(status_value) {
    status_key <- tolower(as.character(status_value %||% ""))
    if (!nzchar(status_key) || is.na(status_key)) {
        return("not_found")
    }
    if (identical(status_key, "unresolved")) {
        return("ambiguous")
    }
    if (identical(status_key, "invalid")) {
        return("ignored")
    }
    if (status_key %in% c("accepted", "synonym", "not_found", "ambiguous", "ignored")) {
        return(status_key)
    }
    "not_found"
}

#' Vectorized companion to normalize_status_for_filter()
#'
#' Same mapping, resolved once per distinct status instead of once per row. A
#' status vector has at most a handful of distinct values whatever the dataset
#' size, so this turns an O(rows) loop into O(distinct statuses).
#'
#' @param status_values Character vector of raw status values
#' @return Character vector of canonical keys, same length as the input
#' @noRd
normalize_status_vec <- function(status_values) {
    values <- as.character(status_values)
    if (length(values) == 0L) {
        return(character(0))
    }
    uniq <- unique(values)
    resolved <- vapply(
        uniq, normalize_status_for_filter,
        FUN.VALUE = character(1), USE.NAMES = FALSE
    )
    resolved[match(values, uniq)]
}

#' Test if status represents an unresolved problem
#' @param status_key Status value (raw or canonical)
#' @return Logical
#' @noRd
is_problem_status_key <- function(status_key) {
    key <- normalize_status_for_filter(status_key)
    key %in% .vn_problem_status_values
}

#' Count stream items by filter category
#' @param stream_df Stream data frame with validation_status and query_name columns
#' @param reviewed_keys Character vector of already-reviewed query names
#' @return Named integer vector with counts per category
#' @noRd
stream_filter_counts <- function(stream_df, reviewed_keys = character(0)) {
    out <- c(
        all = 0L,
        problems = 0L,
        not_found = 0L,
        ambiguous = 0L,
        synonym = 0L,
        ignored = 0L,
        accepted = 0L,
        invasive = 0L
    )
    if (!is.data.frame(stream_df) || nrow(stream_df) == 0L) {
        return(out)
    }
    status_vec <- vapply(stream_df$validation_status, normalize_status_for_filter, FUN.VALUE = character(1))
    query_vec <- if ("query_name" %in% names(stream_df)) as.character(stream_df$query_name) else rep("", nrow(stream_df))
    reviewed_vec <- query_vec %in% reviewed_keys
    reviewed_vec[is.na(reviewed_vec)] <- FALSE
    unresolved_problem <- status_vec %in% .vn_problem_status_values & !reviewed_vec
    out[["all"]] <- as.integer(length(status_vec))
    out[["not_found"]] <- as.integer(sum(status_vec == "not_found" & !reviewed_vec, na.rm = TRUE))
    out[["ambiguous"]] <- as.integer(sum(status_vec == "ambiguous" & !reviewed_vec, na.rm = TRUE))
    out[["synonym"]] <- as.integer(sum(status_vec == "synonym" & !reviewed_vec, na.rm = TRUE))
    out[["ignored"]] <- as.integer(sum(status_vec == "ignored", na.rm = TRUE))
    out[["problems"]] <- as.integer(sum(unresolved_problem, na.rm = TRUE))
    out[["accepted"]] <- as.integer(sum(status_vec == "accepted", na.rm = TRUE))
    out[["invasive"]] <- as.integer(sum(flag_invasive_species(query_vec), na.rm = TRUE))
    out
}

#' Filter stream data frame by category
#' @param stream_df Stream data frame
#' @param filter_key Category key: one of .vn_stream_filter_values
#' @param reviewed_keys Character vector of reviewed query names
#' @param exiting_keys Character vector of names in exit animation (always included)
#' @return Filtered data frame
#' @noRd
filter_stream_df <- function(stream_df, filter_key = "all", reviewed_keys = character(0), exiting_keys = character(0)) {
    if (!is.data.frame(stream_df) || nrow(stream_df) == 0L) {
        return(stream_df)
    }
    key <- as.character(filter_key %||% "all")
    if (!(key %in% .vn_stream_filter_values)) key <- "all"
    if (identical(key, "all")) {
        return(stream_df)
    }

    status_vec <- vapply(stream_df$validation_status, normalize_status_for_filter, FUN.VALUE = character(1))
    query_vec <- if ("query_name" %in% names(stream_df)) as.character(stream_df$query_name) else rep("", nrow(stream_df))
    reviewed_vec <- query_vec %in% reviewed_keys
    reviewed_vec[is.na(reviewed_vec)] <- FALSE
    exiting_vec <- query_vec %in% exiting_keys
    exiting_vec[is.na(exiting_vec)] <- FALSE
    keep_idx <- switch(key,
        problems = (status_vec %in% .vn_problem_status_values & !reviewed_vec) | exiting_vec,
        not_found = ((status_vec == "not_found") & !reviewed_vec) | exiting_vec,
        ambiguous = ((status_vec == "ambiguous") & !reviewed_vec) | exiting_vec,
        synonym = ((status_vec == "synonym") & !reviewed_vec) | exiting_vec,
        ignored = status_vec == "ignored",
        accepted = status_vec == "accepted",
        # Species-list axis, so no reviewed/exiting interplay: a name is on the
        # invasive list or it is not, regardless of its validation status.
        invasive = flag_invasive_species(query_vec),
        rep(TRUE, length(status_vec))
    )
    out <- stream_df[keep_idx, , drop = FALSE]
    rownames(out) <- NULL
    out
}

# ---------------------------------------------------------------------------
# Review modal utilities
# ---------------------------------------------------------------------------

#' Build UI context for the review modal based on name status
#' @param status_key Canonical status key (ambiguous/synonym/not_found)
#' @param lang Language code ("pt" or "en")
#' @return Named list with header_class, icon, problem_label, status_label, question, helper
#' @noRd
review_status_context <- function(status_key, lang = "pt") {
    key <- normalize_status_for_filter(status_key)
    if (identical(key, "ambiguous")) {
        return(list(
            header_class = "vn-review-header-warning",
            icon = "circle-question",
            problem_label = tr("validate_names_review_problem_ambiguous", lang),
            status_label = tr("validate_names_stream_status_ambiguous", lang),
            question = tr("validate_names_review_question_ambiguous", lang),
            helper = tr("validate_names_review_helper_ambiguous", lang)
        ))
    }
    if (identical(key, "synonym")) {
        return(list(
            header_class = "vn-review-header-info",
            icon = "code-compare",
            problem_label = tr("validate_names_review_problem_synonym", lang),
            status_label = tr("validate_names_stream_status_synonym", lang),
            question = tr("validate_names_review_question_synonym", lang),
            helper = tr("validate_names_review_helper_synonym", lang)
        ))
    }
    list(
        header_class = "vn-review-header-error",
        icon = "circle-xmark",
        problem_label = tr("validate_names_review_problem_not_found", lang),
        status_label = tr("validate_names_stream_status_not_found", lang),
        question = tr("validate_names_review_question_not_found", lang),
        helper = tr("validate_names_review_helper_not_found", lang)
    )
}

#' Render scientific name with italic emphasis
#' @param value Scientific name string
#' @return Shiny HTML object
#' @noRd
render_review_name_em <- function(value) {
    shiny::HTML(sprintf("<em>%s</em>", htmltools::htmlEscape(as.character(value %||% ""))))
}

#' Summary of conservation status that export will add to dynamicProperties
#'
#' Shown above the validation report. MMA is an exact local count of records on
#' the national threatened list; IUCN is the number of resolved records GBIF
#' will be queried for on export (some may have no assessment). Returns NULL when
#' no source applies or there is nothing to count, so it drops out of the layout.
#'
#' @param report Validation report data frame (needs `scientificName`).
#' @param selected Character vector of selected provider IDs.
#' @param br_provider_ids Character vector of Brazilian provider IDs.
#' @param lang Active language code.
#' @return A Shiny tag or NULL.
#' @noRd
conservation_status_summary_ui <- function(report, selected, br_provider_ids, lang) {
    include_mma <- length(intersect(selected, br_provider_ids)) > 0L
    include_iucn <- "gbif" %in% selected
    name_col <- if (is.data.frame(report) && "scientificName" %in% names(report)) {
        as.character(report$scientificName)
    } else {
        character(0)
    }
    # The invasive count comes from a bundled list and is provider-independent,
    # so it is reported even when neither conservation provider is selected.
    if (length(name_col) == 0L) {
        return(NULL)
    }

    lines <- list()
    if (include_mma) {
        mma_n <- sum(!is.na(sensitive_category_for(name_col)))
        if (mma_n > 0L) {
            lines[[length(lines) + 1L]] <- shiny::tags$span(
                class = "vn-conservation-line",
                sprintf(tr("validate_names_conservation_summary_mma", lang), mma_n)
            )
        }
    }
    if (include_iucn) {
        iucn_n <- sum(!is.na(name_col) & nzchar(trimws(name_col)))
        if (iucn_n > 0L) {
            lines[[length(lines) + 1L]] <- shiny::tags$span(
                class = "vn-conservation-line",
                sprintf(tr("validate_names_conservation_summary_iucn", lang), iucn_n)
            )
        }
    }
    invasive_n <- sum(flag_invasive_species(name_col))
    if (invasive_n > 0L) {
        lines[[length(lines) + 1L]] <- shiny::tags$span(
            class = "vn-conservation-line",
            sprintf(tr("validate_names_conservation_summary_invasive", lang), invasive_n)
        )
    }
    if (length(lines) == 0L) {
        return(NULL)
    }
    shiny::div(class = "vn-conservation-summary", lines)
}
