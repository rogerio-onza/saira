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
.vn_stream_filter_values <- c("all", "problems", "not_found", "ambiguous", "synonym", "ignored", "accepted", "invasive", "translocated")
.vn_problem_status_values <- c("not_found", "ambiguous", "synonym")
.vn_review_exit_ms <- 320L

# ---------------------------------------------------------------------------
# Provider utilities
# ---------------------------------------------------------------------------

#' Warning text for a names run with a failed provider
#'
#' The text names the providers that failed (DEP-02).
#' @param meta The \code{meta} list of \code{finalize_taxadb_run()}.
#' @param lang Language code.
#' @return Character string, or NULL when every provider answered.
#' @noRd
vn_provider_failure_message <- function(meta, lang = "pt") {
    failures <- meta$provider_failures
    if (!is.data.frame(failures) || nrow(failures) == 0L) {
        return(NULL)
    }
    providers <- paste(
        format_provider_labels(failures$provider),
        collapse = tr("validate_names_run_and", lang)
    )
    sprintf(tr("validate_names_provider_failed", lang), providers)
}

#' Answer list without the names a run left unchecked
#'
#' A name that no provider could check has only a "not_found" answer, and the
#' block of unchecked names shows it. The list and its counts leave it out. A
#' name with an answer from another provider keeps its row (ADR-169).
#' @param stream_df Stream data frame.
#' @param unchecked Character vector of unchecked query names.
#' @return Stream data frame.
#' @noRd
vn_drop_unchecked <- function(stream_df, unchecked) {
    if (!is.data.frame(stream_df) || nrow(stream_df) == 0L || length(unchecked) == 0L) {
        return(stream_df)
    }
    status <- vapply(stream_df$validation_status, normalize_status_for_filter, FUN.VALUE = character(1))
    drop <- stream_df$query_name %in% unchecked & status == "not_found"
    out <- stream_df[!drop, , drop = FALSE]
    rownames(out) <- NULL
    out
}

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

    # Order to an INDEX, truncate the index, then subset once. The previous shape
    # materialized the whole reordered frame -- every column of the entire
    # accumulated stream -- and only then kept the first `limit` rows. This runs
    # on every 60ms tick of a run, when the stream is at its largest.
    # ADR-093 is untouched: limit = NULL still returns every row (the post-run
    # contract), and the cap still applies only while the run is in flight.
    idx <- order(out$display_order, decreasing = TRUE)
    if (!is.null(limit) && !is.infinite(limit)) {
        limit_int <- suppressWarnings(as.integer(limit))
        if (!is.na(limit_int) && limit_int > 0L && length(idx) > limit_int) {
            idx <- idx[seq_len(limit_int)]
        }
    }

    out <- out[idx, , drop = FALSE]
    rownames(out) <- NULL
    out
}

#' Status of each name during a run, for the run grid
#'
#' One character per name, in sheet order: "a" accepted, "s" synonym, "m"
#' ambiguous, "n" not found, "q" in the next batch and "." waiting. A name
#' that a Brazilian provider finds but does not accept waits for GBIF, so it
#' stays "." until it has its last answer.
#' @param state Run state object.
#' @return Character scalar.
#' @noRd
vn_run_cells <- function(state) {
    queries <- as.character(state$query_order %||% character(0))
    if (length(queries) == 0L) {
        return("")
    }
    stream <- state$stream_df
    status <- if (is.data.frame(stream) && nrow(stream) > 0L) {
        stream$validation_status[match(queries, stream$query_name)]
    } else {
        rep(NA_character_, length(queries))
    }
    code <- rep("n", length(queries))
    code[status %in% "accepted"] <- "a"
    code[status %in% "synonym"] <- "s"
    code[status %in% c("ambiguous", "unresolved")] <- "m"

    pending <- queries %in% as.character(state$pending_queries %||% character(0))
    code[pending] <- "."
    next_idx <- as.integer(state$provider_batch_idx %||% 0L) + 1L
    batches <- state$current_batches
    if (identical(state$phase, "provider_query_batch") && next_idx <= length(batches)) {
        code[pending & queries %in% batches[[next_idx]]] <- "q"
    }
    paste(code, collapse = "")
}

#' Answer list rows of the names that have their last answer
#'
#' A name that a Brazilian provider finds but does not accept waits for the
#' next provider, so its first answer can change. The list shows a name when
#' it leaves the queue, as the run grid does (DEP-07).
#' @param state Run state object.
#' @return Stream data frame.
#' @noRd
vn_settled_stream <- function(state) {
    stream <- state$stream_df
    if (!is.data.frame(stream) || nrow(stream) == 0L) {
        return(stream)
    }
    pending <- as.character(state$pending_queries %||% character(0))
    stream[!(stream$query_name %in% pending), , drop = FALSE]
}

#' Progress of a names run, for the run card of the report panel
#'
#' The count is the names that have an answer. Names that no provider finds
#' get one at the end, so the count always reaches the total.
#' @param state Run state object.
#' @param lang Language code.
#' @return List with \code{run_id}, \code{done}, \code{total}, \code{pct},
#'   \code{waiting} (a first Flora BR or Fauna BR download, with no count to
#'   show), \code{eyebrow}, \code{count}, \code{cells} (from
#'   \code{vn_run_cells()}), \code{tally} (formatted count per cell status)
#'   and \code{steps}: one list per step with \code{key}, \code{label},
#'   \code{state} ("done", "active" or "next") and \code{state_label}.
#' @noRd
vn_run_progress <- function(state, lang = "pt") {
    phase <- as.character(state$phase %||% "")
    provider <- as.character(state$current_provider %||% "")
    types <- state$provider_types
    br_ids <- names(types)[types == "br"]
    total <- as.integer(state$total_unique %||% 0L)
    in_report <- phase %in% c("consolidate", "done")
    done <- if (in_report) total else as.integer(state$resolved_unique %||% 0L)

    current <- if (in_report) {
        "report"
    } else if (identical(state$cascade_phase, "br")) {
        "br"
    } else {
        "gbif"
    }
    keys <- c(if (length(br_ids) > 0L) "br", "gbif", "report")
    labels <- c(
        br = paste(format_provider_labels(br_ids), collapse = tr("validate_names_run_and", lang)),
        gbif = tr(if (length(br_ids) > 0L) "validate_names_run_step_gbif_rest" else "validate_names_run_step_gbif", lang),
        report = tr("validate_names_run_step_report", lang)
    )
    current_idx <- match(current, keys)
    steps <- lapply(seq_along(keys), function(i) {
        step_state <- if (i < current_idx) "done" else if (i == current_idx) "active" else "next"
        list(
            key = keys[i],
            label = unname(labels[keys[i]]),
            state = step_state,
            state_label = tr(paste0("validate_names_run_state_", step_state), lang)
        )
    })

    cells <- vn_run_cells(state)
    codes <- strsplit(cells, "", fixed = TRUE)[[1]]
    tally <- lapply(c(a = "a", s = "s", m = "m", n = "n"), function(code) {
        format_count(sum(codes == code), lang)
    })

    list(
        run_id = as.character(state$run_id %||% ""),
        done = done,
        total = total,
        pct = if (total > 0L) round(100 * done / total) else 0,
        waiting = identical(phase, "provider_init") && provider %in% br_ids &&
            !brprovider_data_available(provider),
        eyebrow = tr(if (in_report) "validate_names_run_eyebrow_report" else "validate_names_run_eyebrow", lang),
        count = sprintf(tr("validate_names_run_count", lang), format_count(done, lang), format_count(total, lang)),
        cells = cells,
        tally = tally,
        steps = steps
    )
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

#' Cascade step at which a provider is queried
#'
#' Mirrors the reorder in `init_taxadb_run_state()`: the Brazilian providers
#' answer first, and GBIF receives only the names they did not find.
#' @param provider_id Provider id.
#' @param selected Character vector of selected provider ids.
#' @param br_ids Character vector of Brazilian provider ids.
#' @return Integer step (1 or 2), or NA when the provider is not selected.
#' @noRd
provider_query_step <- function(provider_id, selected, br_ids) {
    if (!(provider_id %in% selected)) {
        return(NA_integer_)
    }
    if (provider_id %in% br_ids || !any(br_ids %in% selected)) 1L else 2L
}

# ---------------------------------------------------------------------------
# Status classification
# ---------------------------------------------------------------------------

#' Map validation status to style attributes
#' @param status_value Status value string
#' @return Named list with key, icon_symbol, icon (Phosphor name), label_key, item_class, badge_class, row_class
#' @noRd
status_style_map <- function(status_value) {
    status_key <- as.character(status_value)
    status_key <- ifelse(is.na(status_key) | !nzchar(status_key), "not_found", tolower(status_key))

    if (identical(status_key, "accepted")) {
        return(list(
            key = "accepted",
            icon_symbol = "\u2713",
            icon = "check",
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
            icon = "arrows-left-right",
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
            icon = "question",
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
            icon = "minus",
            label_key = "validate_names_stream_status_ignored",
            item_class = "vn-stream-item-ignored",
            badge_class = "badge-muted",
            row_class = "vn-row-ignored"
        ))
    }
    list(
        key = "not_found",
        icon_symbol = "\u2715",
        icon = "x",
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
        invasive = 0L,
        translocated = 0L
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
    # One pill per claim: "invasive" counts only taxa the list calls alien to
    # Brazil, so a native on the list is never counted as an exotic invader.
    origin_class <- invasive_origin_class_for(query_vec)
    out[["invasive"]] <- as.integer(sum(origin_class == "alien", na.rm = TRUE))
    out[["translocated"]] <- as.integer(sum(origin_class == "translocated_native", na.rm = TRUE))
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
    origin_class <- if (key %in% c("invasive", "translocated")) {
        invasive_origin_class_for(query_vec)
    } else {
        rep(NA_character_, length(query_vec))
    }
    keep_idx <- switch(key,
        problems = (status_vec %in% .vn_problem_status_values & !reviewed_vec) | exiting_vec,
        not_found = ((status_vec == "not_found") & !reviewed_vec) | exiting_vec,
        ambiguous = ((status_vec == "ambiguous") & !reviewed_vec) | exiting_vec,
        synonym = ((status_vec == "synonym") & !reviewed_vec) | exiting_vec,
        ignored = status_vec == "ignored",
        accepted = status_vec == "accepted",
        # Species-list axis, so no reviewed/exiting interplay: a name is on the
        # invasive list or it is not, regardless of its validation status. The
        # two groups filter apart, matching what their badges claim.
        invasive = !is.na(origin_class) & origin_class == "alien",
        translocated = !is.na(origin_class) & origin_class == "translocated_native",
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
