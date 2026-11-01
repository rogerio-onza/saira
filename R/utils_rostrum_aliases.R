# Utils rostrum aliases

rostrum_insert_alias_event_locked <- function(
    conn,
    alias_id,
    action,
    run_id = NULL,
    payload = NULL,
    created_by = NULL,
    created_at = rostrum_now_utc()
) {
    if (!DBI::dbIsValid(conn)) {
        stop("conn must be a valid DBI connection.")
    }

    action_chr <- trimws(as.character(action))
    if (length(action_chr) != 1L || is.na(action_chr) || !nzchar(action_chr)) {
        stop("action must be a non-empty character scalar.")
    }

    payload_json <- if (is.null(payload)) {
        NA_character_
    } else if (is.character(payload) && length(payload) == 1L && !is.na(payload) && nzchar(trimws(payload))) {
        as.character(payload)
    } else {
        as.character(jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null"))
    }

    run_id_norm <- rostrum_normalize_identity(run_id)
    created_by_norm <- rostrum_normalize_identity(created_by)
    alias_id_num <- suppressWarnings(as.integer(alias_id))
    if (length(alias_id_num) != 1L || is.na(alias_id_num) || alias_id_num <= 0L) {
        stop("alias_id must be a positive integer.")
    }

    DBI::dbExecute(
        conn,
        paste(
            "INSERT INTO rostrum_alias_events",
            "(alias_id, action, run_id, payload_json, created_at, created_by)",
            "VALUES (?, ?, ?, ?, ?, ?)"
        ),
        params = list(
            alias_id_num,
            action_chr,
            run_id_norm,
            payload_json,
            as.character(created_at),
            created_by_norm
        )
    )

    invisible(TRUE)
}

rostrum_upsert_alias <- function(
    conn,
    col_name,
    dwc_term,
    confidence,
    scope = "personal",
    reviewed = TRUE,
    run_id = NULL,
    action = "alias_upserted",
    created_by = NULL,
    user_id = Sys.getenv("SAIRA_USER", unset = ""),
    institution_id = Sys.getenv("SAIRA_INSTITUTION", unset = ""),
    payload = NULL
) {
    if (!DBI::dbIsValid(conn)) {
        stop("conn must be a valid DBI connection.")
    }

    DBI::dbExecute(conn, "BEGIN IMMEDIATE")
    committed <- FALSE
    on.exit(
        {
            if (!committed) {
                try(DBI::dbExecute(conn, "ROLLBACK"), silent = TRUE)
            }
        },
        add = TRUE
    )

    result <- rostrum_upsert_alias_locked(
        conn = conn,
        col_name = col_name,
        dwc_term = dwc_term,
        confidence = confidence,
        scope = scope,
        reviewed = reviewed,
        run_id = run_id,
        action = action,
        created_by = created_by,
        user_id = user_id,
        institution_id = institution_id,
        payload = payload
    )

    DBI::dbExecute(conn, "COMMIT")
    committed <- TRUE
    result
}

# The upsert body without the transaction, so a batch commit can run many of
# these inside ONE BEGIN IMMEDIATE. Same convention as
# rostrum_insert_alias_event_locked: the caller owns the transaction.
rostrum_upsert_alias_locked <- function(
    conn,
    col_name,
    dwc_term,
    confidence,
    scope = "personal",
    reviewed = TRUE,
    run_id = NULL,
    action = "alias_upserted",
    created_by = NULL,
    user_id = Sys.getenv("SAIRA_USER", unset = ""),
    institution_id = Sys.getenv("SAIRA_INSTITUTION", unset = ""),
    payload = NULL,
    now_utc = rostrum_now_utc()
) {
    scope_norm <- rostrum_validate_scope(scope)
    term_chr <- trimws(as.character(dwc_term))
    if (length(term_chr) != 1L || is.na(term_chr) || !nzchar(term_chr)) {
        stop("dwc_term must be a non-empty character scalar.")
    }

    col_name_norm <- rostrum_normalize_col_name(col_name)
    confidence_num <- rostrum_validate_alias_confidence(confidence)
    reviewed_int <- as.integer(isTRUE(reviewed))
    created_by_norm <- rostrum_normalize_identity(created_by)
    user_id_norm <- rostrum_normalize_identity(user_id)
    institution_id_norm <- rostrum_normalize_identity(institution_id)
    run_id_norm <- rostrum_normalize_identity(run_id)

    if (identical(scope_norm, "personal") && is.na(user_id_norm)) {
        user_id_norm <- "anonymous"
    }

    tryCatch(
        {
            existing <- DBI::dbGetQuery(
                conn,
                paste(
                    "SELECT alias_id, deprecated FROM rostrum_aliases",
                    "WHERE scope = ?",
                    "  AND COALESCE(user_id, '') = COALESCE(?, '')",
                    "  AND COALESCE(institution_id, '') = COALESCE(?, '')",
                    "  AND col_name_norm = ?",
                    "  AND dwc_term = ?",
                    "ORDER BY alias_id ASC",
                    "LIMIT 1"
                ),
                params = list(
                    scope_norm,
                    user_id_norm,
                    institution_id_norm,
                    col_name_norm,
                    term_chr
                )
            )

            action_effective <- "alias_created"
            if (nrow(existing) > 0L) {
                alias_id <- as.integer(existing$alias_id[[1]])
                DBI::dbExecute(
                    conn,
                    paste(
                        "UPDATE rostrum_aliases",
                        "SET confidence = ?,",
                        "    reviewed = ?,",
                        "    deprecated = 0,",
                        "    updated_at = ?",
                        "WHERE alias_id = ?"
                    ),
                    params = list(confidence_num, reviewed_int, now_utc, alias_id)
                )
                # Undo has to tell a revived alias from one that was live before.
                action_effective <- if (isTRUE(as.integer(existing$deprecated[[1]]) == 1L)) {
                    "alias_reactivated"
                } else {
                    "alias_updated"
                }
            } else {
                DBI::dbExecute(
                    conn,
                    paste(
                        "INSERT INTO rostrum_aliases",
                        "(scope, user_id, institution_id, col_name_norm, dwc_term, confidence,",
                        " reviewed, deprecated, created_at, created_by, updated_at)",
                        "VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)"
                    ),
                    params = list(
                        scope_norm,
                        user_id_norm,
                        institution_id_norm,
                        col_name_norm,
                        term_chr,
                        confidence_num,
                        reviewed_int,
                        now_utc,
                        created_by_norm,
                        now_utc
                    )
                )
                alias_id <- as.integer(DBI::dbGetQuery(conn, "SELECT last_insert_rowid() AS id")$id[[1]])
            }

            event_payload <- list(
                scope = scope_norm,
                col_name_norm = col_name_norm,
                dwc_term = term_chr,
                confidence = confidence_num,
                reviewed = reviewed_int,
                action = action,
                payload = payload
            )
            rostrum_insert_alias_event_locked(
                conn = conn,
                alias_id = alias_id,
                action = action_effective,
                run_id = run_id_norm,
                payload = event_payload,
                created_by = created_by_norm,
                created_at = now_utc
            )
            if (!is.null(action) && nzchar(trimws(as.character(action)))) {
                rostrum_insert_alias_event_locked(
                    conn = conn,
                    alias_id = alias_id,
                    action = trimws(as.character(action)),
                    run_id = run_id_norm,
                    payload = event_payload,
                    created_by = created_by_norm,
                    created_at = now_utc
                )
            }

            list(
                alias_id = alias_id,
                action = action_effective,
                scope = scope_norm,
                user_id = user_id_norm,
                institution_id = institution_id_norm,
                col_name_norm = col_name_norm,
                dwc_term = term_chr,
                confidence = confidence_num
            )
        },
        error = function(e) {
            stop("Failed to upsert alias: ", e$message, call. = FALSE)
        }
    )
}

#' Record a User Alias Confirmation
#'
#' Persists a confirmed auto-mapping suggestion to the Rostrum alias store.
#'
#' @param conn A DBI connection from \code{rostrum_connect()}.
#' @param col_name Character. Source column name.
#' @param dwc_term Character. Darwin Core term confirmed by the user.
#' @param score_original Numeric [0,1]. Engine confidence score.
#' @param scope Character. One of \code{"personal"}, \code{"institution"}, \code{"public"}.
#' @param run_id Optional run identifier string.
#' @param created_by Character. User identifier.
#' @param user_id Character. User identifier for scope resolution.
#' @param institution_id Character. Institution identifier.
#' @return Invisibly, the alias ID.
#' @export
rostrum_record_alias_confirmation <- function(
    conn,
    col_name,
    dwc_term,
    score_original,
    scope = "personal",
    run_id = NULL,
    created_by = Sys.getenv("SAIRA_USER", unset = ""),
    user_id = Sys.getenv("SAIRA_USER", unset = ""),
    institution_id = Sys.getenv("SAIRA_INSTITUTION", unset = "")
) {
    rostrum_upsert_alias(
        conn = conn,
        col_name = col_name,
        dwc_term = dwc_term,
        confidence = score_original,
        scope = scope,
        reviewed = TRUE,
        run_id = run_id,
        action = "suggestion_confirmed",
        created_by = created_by,
        user_id = user_id,
        institution_id = institution_id
    )
}

#' Record a Manual Alias Override
#'
#' Persists a manual column-to-term mapping to the Rostrum alias store with
#' confidence 1.0 and \code{reviewed = TRUE}.
#'
#' @param conn A DBI connection from \code{rostrum_connect()}.
#' @param col_name Character. Source column name.
#' @param dwc_term Character. Darwin Core term chosen by the user.
#' @param scope Character. One of \code{"personal"}, \code{"institution"}, \code{"public"}.
#' @param run_id Optional run identifier string.
#' @param created_by Character. User identifier.
#' @param user_id Character. User identifier for scope resolution.
#' @param institution_id Character. Institution identifier.
#' @return Invisibly, the alias ID.
#' @export
rostrum_record_alias_override <- function(
    conn,
    col_name,
    dwc_term,
    scope = "personal",
    run_id = NULL,
    created_by = Sys.getenv("SAIRA_USER", unset = ""),
    user_id = Sys.getenv("SAIRA_USER", unset = ""),
    institution_id = Sys.getenv("SAIRA_INSTITUTION", unset = "")
) {
    rostrum_upsert_alias(
        conn = conn,
        col_name = col_name,
        dwc_term = dwc_term,
        confidence = 1.0,
        scope = scope,
        reviewed = TRUE,
        run_id = run_id,
        action = "manual_override",
        created_by = created_by,
        user_id = user_id,
        institution_id = institution_id
    )
}

#' Commit a Confirmed Mapping to the Alias Store
#'
#' Learns column-to-term aliases from a mapping the user has confirmed by
#' exporting. Saira deliberately does not learn from selections made while
#' mapping: an intermediate pick is a hypothesis, and recording hypotheses is
#' what filled the store with entries like \code{id -> basisOfRecord} left
#' behind by cycling through options on a card.
#'
#' The whole set is written in a single transaction under one \code{run_id}, so
#' \code{undo_session_aliases()} can reverse exactly one export.
#'
#' @param conn A DBI connection from \code{rostrum_connect()}.
#' @param map_values Named list of the final mapping: names are Darwin Core
#'   terms, values are the source column(s). Terms with no column, or resolved
#'   from a fixed value rather than a column, are skipped.
#' @param run_id Optional run identifier string shared by the whole batch.
#' @param scope Character. One of \code{"personal"}, \code{"institution"}, \code{"public"}.
#' @param created_by Character. User identifier.
#' @param user_id Character. User identifier for scope resolution.
#' @param institution_id Character. Institution identifier.
#' @return Invisibly, a data frame of the committed pairs (zero rows when there
#'   was nothing to learn), with the upsert \code{action} of each pair.
#' @export
rostrum_commit_session_aliases <- function(
    conn,
    map_values,
    run_id = NULL,
    scope = "personal",
    created_by = Sys.getenv("SAIRA_USER", unset = ""),
    user_id = Sys.getenv("SAIRA_USER", unset = ""),
    institution_id = Sys.getenv("SAIRA_INSTITUTION", unset = "")
) {
    empty <- data.frame(
        dwc_term = character(0), col_name = character(0),
        stringsAsFactors = FALSE
    )
    if (!inherits(conn, "DBIConnection") || !DBI::dbIsValid(conn)) {
        return(invisible(empty))
    }
    if (!rostrum_learning_enabled() || !is.list(map_values) || length(map_values) == 0L) {
        return(invisible(empty))
    }

    terms <- names(map_values)
    if (is.null(terms)) {
        return(invisible(empty))
    }

    pairs <- empty
    for (term in terms) {
        if (!nzchar(trimws(term))) next
        value <- map_values[[term]]
        # A multi-column term (e.g. eventDate assembled from year/month/day) is
        # not a one-to-one alias, so it teaches nothing and is skipped.
        if (is.null(value) || length(value) != 1L) next
        col_name <- trimws(as.character(value)[[1]])
        if (is.na(col_name) || !nzchar(col_name)) next
        pairs <- rbind(
            pairs,
            data.frame(dwc_term = term, col_name = col_name,
                       stringsAsFactors = FALSE)
        )
    }

    if (nrow(pairs) == 0L) {
        return(invisible(empty))
    }

    now_utc <- rostrum_now_utc()
    DBI::dbExecute(conn, "BEGIN IMMEDIATE")
    committed <- FALSE
    on.exit(
        {
            if (!committed) {
                try(DBI::dbExecute(conn, "ROLLBACK"), silent = TRUE)
            }
        },
        add = TRUE
    )

    upserted <- vector("list", nrow(pairs))
    for (i in seq_len(nrow(pairs))) {
        upserted[[i]] <- rostrum_upsert_alias_locked(
            conn = conn,
            col_name = pairs$col_name[[i]],
            dwc_term = pairs$dwc_term[[i]],
            confidence = 1.0,
            scope = scope,
            reviewed = TRUE,
            run_id = run_id,
            # NULL keeps this to one event row per alias. The origin rides in
            # the payload instead of doubling the audit trail.
            action = NULL,
            created_by = created_by,
            user_id = user_id,
            institution_id = institution_id,
            payload = list(origin = "export_confirmed"),
            now_utc = now_utc
        )
    }
    rostrum_supersede_aliases_locked(
        conn = conn,
        upserted = upserted,
        run_id = run_id,
        created_by = created_by,
        now_utc = now_utc
    )

    DBI::dbExecute(conn, "COMMIT")
    committed <- TRUE
    pairs$action <- vapply(upserted, function(u) u$action, character(1))
    invisible(pairs)
}

# What an export taught the alias store: the pairs it created or reactivated.
# A pair that was live before is not news, and undo leaves it live (ADR-141).
alias_export_receipt <- function(committed, run_id) {
    if (!is.data.frame(committed) || !"action" %in% names(committed)) {
        return(NULL)
    }
    learned <- committed[committed$action %in% c("alias_created", "alias_reactivated"), , drop = FALSE]
    if (nrow(learned) == 0L) {
        return(NULL)
    }
    list(
        run_id = run_id,
        pairs = data.frame(col_name = learned$col_name, dwc_term = learned$dwc_term, stringsAsFactors = FALSE)
    )
}

# The export is the newest decision for each column it maps. Older live
# aliases of the same scope, owner and column that point to another term are
# deprecated, so the lookup cannot return a stale term. Two terms mapped to one
# column in the same export (altitude -> minimum and maximum elevation) both
# stay (ADR-140). The caller owns the transaction.
rostrum_supersede_aliases_locked <- function(conn, upserted, run_id, created_by, now_utc) {
    run_id_norm <- rostrum_normalize_identity(run_id)
    created_by_norm <- rostrum_normalize_identity(created_by)
    col_keys <- vapply(upserted, function(u) {
        paste(u$scope, u$user_id, u$institution_id, u$col_name_norm, sep = "\r")
    }, character(1))

    for (key in unique(col_keys)) {
        group <- upserted[col_keys == key]
        first <- group[[1]]
        keep_ids <- vapply(group, function(u) as.integer(u$alias_id), integer(1))
        old <- DBI::dbGetQuery(
            conn,
            paste(
                "SELECT alias_id FROM rostrum_aliases",
                "WHERE scope = ?",
                "  AND COALESCE(user_id, '') = COALESCE(?, '')",
                "  AND COALESCE(institution_id, '') = COALESCE(?, '')",
                "  AND col_name_norm = ?",
                "  AND deprecated = 0",
                "  AND alias_id NOT IN (", paste(rep("?", length(keep_ids)), collapse = ","), ")"
            ),
            params = c(
                list(first$scope, first$user_id, first$institution_id, first$col_name_norm),
                as.list(keep_ids)
            )
        )
        for (alias_id in as.integer(old$alias_id)) {
            DBI::dbExecute(
                conn,
                "UPDATE rostrum_aliases SET deprecated = 1, updated_at = ? WHERE alias_id = ?",
                params = list(now_utc, alias_id)
            )
            rostrum_insert_alias_event_locked(
                conn = conn,
                alias_id = alias_id,
                action = "alias_superseded",
                run_id = run_id_norm,
                payload = list(superseded_by = vapply(group, function(u) u$dwc_term, character(1))),
                created_by = created_by_norm,
                created_at = now_utc
            )
        }
    }
    invisible(NULL)
}

rostrum_deprecate_alias <- function(
    conn,
    alias_id,
    run_id = NULL,
    created_by = Sys.getenv("SAIRA_USER", unset = ""),
    action = "alias_deprecated",
    payload = NULL
) {
    if (!DBI::dbIsValid(conn)) {
        stop("conn must be a valid DBI connection.")
    }

    alias_id_num <- suppressWarnings(as.integer(alias_id))
    if (length(alias_id_num) != 1L || is.na(alias_id_num) || alias_id_num <= 0L) {
        stop("alias_id must be a positive integer.")
    }

    now_utc <- rostrum_now_utc()

    DBI::dbExecute(conn, "BEGIN IMMEDIATE")
    committed <- FALSE
    on.exit(
        {
            if (!committed) {
                try(DBI::dbExecute(conn, "ROLLBACK"), silent = TRUE)
            }
        },
        add = TRUE
    )

    tryCatch(
        {
            DBI::dbExecute(
                conn,
                paste(
                    "UPDATE rostrum_aliases",
                    "SET deprecated = 1,",
                    "    updated_at = ?",
                    "WHERE alias_id = ?"
                ),
                params = list(now_utc, alias_id_num)
            )

            rostrum_insert_alias_event_locked(
                conn = conn,
                alias_id = alias_id_num,
                action = action,
                run_id = run_id,
                payload = payload,
                created_by = created_by,
                created_at = now_utc
            )

            DBI::dbExecute(conn, "COMMIT")
            committed <- TRUE
            invisible(TRUE)
        },
        error = function(e) {
            stop("Failed to deprecate alias: ", e$message, call. = FALSE)
        }
    )
}

rostrum_list_aliases_for_column <- function(
    conn,
    col_name,
    dwc_term = NULL,
    user_id = Sys.getenv("SAIRA_USER", unset = ""),
    institution_id = Sys.getenv("SAIRA_INSTITUTION", unset = "")
) {
    if (!DBI::dbIsValid(conn)) {
        stop("conn must be a valid DBI connection.")
    }

    col_name_norm <- rostrum_normalize_col_name(col_name)
    user_id_norm <- rostrum_normalize_identity(user_id)
    institution_id_norm <- rostrum_normalize_identity(institution_id)

    query <- paste(
        "SELECT alias_id, scope, user_id, institution_id, col_name_norm,",
        "       dwc_term, confidence, reviewed, deprecated, created_at, updated_at",
        "FROM rostrum_aliases",
        "WHERE col_name_norm = ?",
        "  AND deprecated = 0"
    )
    params <- list(col_name_norm)

    if (!is.null(dwc_term)) {
        term_chr <- trimws(as.character(dwc_term))
        if (length(term_chr) != 1L || is.na(term_chr) || !nzchar(term_chr)) {
            stop("dwc_term must be NULL or a non-empty character scalar.")
        }
        query <- paste(query, "  AND dwc_term = ?")
        params <- c(params, list(term_chr))
    }

    alias_df <- DBI::dbGetQuery(conn, query, params = params)
    if (nrow(alias_df) == 0L) {
        return(alias_df)
    }

    scope_chr <- trimws(tolower(as.character(alias_df$scope)))
    user_hit <- !is.na(user_id_norm) & scope_chr == "personal" & as.character(alias_df$user_id) == user_id_norm
    institution_hit <- !is.na(institution_id_norm) &
        scope_chr == "institution" &
        as.character(alias_df$institution_id) == institution_id_norm
    public_hit <- scope_chr == "public"

    visible <- user_hit | institution_hit | public_hit
    alias_df <- alias_df[visible, , drop = FALSE]
    if (nrow(alias_df) == 0L) {
        return(alias_df)
    }

    alias_df$scope <- trimws(tolower(as.character(alias_df$scope)))
    alias_df$scope_rank <- rostrum_scope_rank(alias_df$scope)
    alias_df$confidence <- suppressWarnings(as.numeric(alias_df$confidence))
    alias_df$reviewed <- as.integer(alias_df$reviewed)
    alias_df$reviewed_rank <- ifelse(alias_df$reviewed > 0L, 1L, 0L)
    # rostrum_now_utc() writes "...T...Z". The default as.POSIXct() formats
    # do not read the "T" and keep only the date, so a same-day tie went to
    # the oldest alias (ADR-140).
    updated_at <- as.character(alias_df$updated_at)
    updated_rank <- suppressWarnings(as.numeric(as.POSIXct(updated_at, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")))
    legacy <- is.na(updated_rank) & !is.na(updated_at)
    updated_rank[legacy] <- suppressWarnings(as.numeric(as.POSIXct(updated_at[legacy], tz = "UTC")))
    updated_rank[is.na(updated_rank)] <- -Inf

    ordering <- order(
        alias_df$scope_rank,
        -alias_df$confidence,
        -alias_df$reviewed_rank,
        -updated_rank,
        alias_df$alias_id
    )
    alias_df[ordering, , drop = FALSE]
}

rostrum_lookup_alias <- function(
    conn,
    col_name,
    user_id = Sys.getenv("SAIRA_USER", unset = ""),
    institution_id = Sys.getenv("SAIRA_INSTITUTION", unset = "")
) {
    alias_df <- rostrum_list_aliases_for_column(
        conn = conn,
        col_name = col_name,
        dwc_term = NULL,
        user_id = user_id,
        institution_id = institution_id
    )

    if (nrow(alias_df) == 0L) {
        return(alias_df)
    }

    alias_df[1, , drop = FALSE]
}

#' Undo All Alias Decisions From a Session
#'
#' Deprecates the alias records that \code{run_id} created or reactivated, and
#' restores the aliases that \code{run_id} superseded. An alias that was live
#' before the run stays live.
#'
#' @param conn A DBI connection from \code{rostrum_connect()}.
#' @param run_id Character. Run identifier whose aliases should be undone.
#' @param created_by Character. User identifier (default \code{SAIRA_USER} env var).
#' @return Invisibly, the integer count of aliases deprecated.
#' @export
undo_session_aliases <- function(
    conn,
    run_id,
    created_by = Sys.getenv("SAIRA_USER", unset = "")
) {
    if (!DBI::dbIsValid(conn)) {
        stop("conn must be a valid DBI connection.")
    }

    run_id_chr <- rostrum_validate_run_id(run_id)
    now_utc <- rostrum_now_utc()

    DBI::dbExecute(conn, "BEGIN IMMEDIATE")
    committed <- FALSE
    on.exit(
        {
            if (!committed) {
                try(DBI::dbExecute(conn, "ROLLBACK"), silent = TRUE)
            }
        },
        add = TRUE
    )

    tryCatch(
        {
            alias_df <- DBI::dbGetQuery(
                conn,
                paste(
                    "SELECT DISTINCT alias_id",
                    "FROM rostrum_alias_events",
                    "WHERE run_id = ?",
                    "  AND alias_id IS NOT NULL",
                    "  AND action IN ('alias_created', 'alias_reactivated', 'alias_superseded')"
                ),
                params = list(run_id_chr)
            )
            if (nrow(alias_df) == 0L) {
                DBI::dbExecute(conn, "COMMIT")
                committed <- TRUE
                return(0L)
            }

            alias_ids <- sort(unique(suppressWarnings(as.integer(alias_df$alias_id))))
            alias_ids <- alias_ids[!is.na(alias_ids) & alias_ids > 0L]

            # An alias this run superseded comes back (ADR-140).
            superseded <- DBI::dbGetQuery(
                conn,
                paste(
                    "SELECT DISTINCT alias_id FROM rostrum_alias_events",
                    "WHERE run_id = ? AND action = 'alias_superseded'"
                ),
                params = list(run_id_chr)
            )
            restore_ids <- intersect(alias_ids, as.integer(superseded$alias_id))
            alias_ids <- setdiff(alias_ids, restore_ids)
            for (alias_id in restore_ids) {
                DBI::dbExecute(
                    conn,
                    "UPDATE rostrum_aliases SET deprecated = 0, updated_at = ? WHERE alias_id = ?",
                    params = list(now_utc, alias_id)
                )
                rostrum_insert_alias_event_locked(
                    conn = conn,
                    alias_id = alias_id,
                    action = "alias_undo_session",
                    run_id = run_id_chr,
                    payload = list(reason = "restore_superseded", run_id = run_id_chr),
                    created_by = created_by,
                    created_at = now_utc
                )
            }

            if (length(alias_ids) == 0L) {
                DBI::dbExecute(conn, "COMMIT")
                committed <- TRUE
                return(0L)
            }

            placeholders <- paste(rep("?", length(alias_ids)), collapse = ",")
            update_sql <- paste(
                "UPDATE rostrum_aliases",
                "SET deprecated = 1, reviewed = 0, updated_at = ?",
                "WHERE alias_id IN (", placeholders, ")",
                "  AND deprecated = 0"
            )
            updated_n <- DBI::dbExecute(
                conn,
                update_sql,
                params = c(list(now_utc), as.list(alias_ids))
            )

            for (alias_id in alias_ids) {
                rostrum_insert_alias_event_locked(
                    conn = conn,
                    alias_id = alias_id,
                    action = "alias_undo_session",
                    run_id = run_id_chr,
                    payload = list(reason = "batch_undo", run_id = run_id_chr),
                    created_by = created_by,
                    created_at = now_utc
                )
            }

            DBI::dbExecute(conn, "COMMIT")
            committed <- TRUE
            as.integer(updated_n)
        },
        error = function(e) {
            stop("Failed to undo aliases for run_id ", run_id_chr, ": ", e$message, call. = FALSE)
        }
    )
}

# ---------------------------------------------------------------------------
# Synonym persistence (PR-1.2 completion)
# ---------------------------------------------------------------------------

#' Seed rostrum_synonyms from V1 RDS if the table is empty.
#'
#' Idempotent: does nothing if any rows already exist. Uses BEGIN IMMEDIATE
#' to prevent concurrent seeds. Converts V1 format via
#' \code{adapt_synonyms_v1_to_v2()}.
#'
#' @param conn Valid DBI connection (WAL + FK enabled via \code{rostrum_connect()}).
#' @param v1_path Optional explicit path to \code{dwc_synonyms_v1.rds}. Resolved
#'   automatically when NULL.
#' @return Invisible integer: number of rows inserted (0 if already seeded).
#' @export
rostrum_seed_synonyms_if_empty <- function(conn, v1_path = NULL) {
    if (!DBI::dbIsValid(conn)) {
        stop("conn must be a valid DBI connection.", call. = FALSE)
    }

    n_existing <- DBI::dbGetQuery(conn, "SELECT COUNT(*) AS n FROM rostrum_synonyms")$n
    if (!is.na(n_existing) && n_existing > 0L) {
        return(invisible(0L))
    }

    raw <- tryCatch(
        {
            if (!is.null(v1_path)) {
                if (!file.exists(v1_path)) stop("v1_path does not exist: ", v1_path)
                readRDS(v1_path)
            } else {
                candidates <- c(
                    system.file("extdata", "dwc_synonyms_v1.rds", package = "saira"),
                    file.path("inst", "extdata", "dwc_synonyms_v1.rds"),
                    file.path("..", "..", "inst", "extdata", "dwc_synonyms_v1.rds")
                )
                candidates <- unique(candidates[nzchar(candidates)])
                path <- candidates[file.exists(candidates)][1L]
                if (length(path) == 0L || is.na(path)) {
                    stop("dwc_synonyms_v1.rds not found in expected locations.")
                }
                readRDS(path)
            }
        },
        error = function(e) {
            warning("[rostrum] Synonym seed skipped (V1 file unavailable): ", e$message)
            NULL
        }
    )

    if (is.null(raw)) {
        return(invisible(0L))
    }

    v2 <- adapt_synonyms_v1_to_v2(raw)

    DBI::dbExecute(conn, "BEGIN IMMEDIATE")
    committed <- FALSE
    on.exit(
        {
            if (!committed) try(DBI::dbExecute(conn, "ROLLBACK"), silent = TRUE)
        },
        add = TRUE
    )

    tryCatch(
        {
            DBI::dbAppendTable(conn, "rostrum_synonyms", v2)
            DBI::dbExecute(conn, "COMMIT")
            committed <- TRUE
            invisible(nrow(v2))
        },
        error = function(e) {
            stop("Failed to seed synonyms from V1 RDS: ", e$message, call. = FALSE)
        }
    )
}

# Process-level cache for sync: key = db path, value = last synced bundle hash.
# Cleared on R session restart. Prevents redundant diff + write on repeated calls.
.rostrum_bundle_sync_cache <- new.env(parent = emptyenv())

# Internal helper: reset the sync cache (used in tests).
rostrum_reset_sync_cache <- function() {
    rm(list = ls(envir = .rostrum_bundle_sync_cache), envir = .rostrum_bundle_sync_cache)
}
