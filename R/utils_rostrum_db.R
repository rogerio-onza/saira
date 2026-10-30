# Title: Rostrum SQLite Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-03-01
# Version: 1.0

rostrum_schema_target_version <- function() {
    3L
}

rostrum_scope_levels <- function() {
    c("personal", "institution", "public")
}

rostrum_scope_rank <- function(scope) {
    scope_chr <- trimws(tolower(as.character(scope)))
    match(scope_chr, rostrum_scope_levels())
}

rostrum_validate_scope <- function(scope) {
    scope_chr <- trimws(tolower(as.character(scope)))
    if (length(scope_chr) != 1L || is.na(scope_chr) || !nzchar(scope_chr)) {
        stop("scope must be one of: personal, institution, public.")
    }
    if (!scope_chr %in% rostrum_scope_levels()) {
        stop("scope must be one of: personal, institution, public.")
    }
    scope_chr
}

rostrum_normalize_identity <- function(value) {
    if (is.null(value)) {
        return(NA_character_)
    }

    value_chr <- trimws(as.character(value))
    if (length(value_chr) == 0L || is.na(value_chr[[1]]) || !nzchar(value_chr[[1]])) {
        return(NA_character_)
    }

    value_chr[[1]]
}

rostrum_normalize_col_name <- function(col_name) {
    col_norm <- normalize_for_matching(col_name)
    if (length(col_norm) != 1L || is.na(col_norm) || !nzchar(col_norm)) {
        stop("col_name must normalize to a non-empty value.")
    }
    col_norm
}

rostrum_validate_alias_confidence <- function(confidence) {
    confidence_num <- suppressWarnings(as.numeric(confidence))
    if (length(confidence_num) != 1L || is.na(confidence_num) || confidence_num < 0 || confidence_num > 1) {
        stop("confidence must be a numeric scalar in [0, 1].")
    }
    confidence_num
}

rostrum_validate_run_id <- function(run_id) {
    run_id_chr <- trimws(as.character(run_id))
    if (length(run_id_chr) != 1L || is.na(run_id_chr) || !nzchar(run_id_chr)) {
        stop("run_id must be a non-empty character scalar.")
    }
    run_id_chr
}

rostrum_now_utc <- function() {
    format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

# One id per export, so undo_session_aliases() can reverse exactly that export.
rostrum_new_run_id <- function() {
    paste0("export-", format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"), "-", substr(uuid::UUIDgenerate(), 1L, 8L))
}

rostrum_resolve_data_dir <- function() {
    explicit_dir <- trimws(Sys.getenv("SAIRA_DATA_DIR", unset = ""))
    if (nzchar(explicit_dir)) {
        return(normalizePath(explicit_dir, winslash = "/", mustWork = FALSE))
    }

    user_dir <- tools::R_user_dir("saira", "data")
    if (!is.character(user_dir) || length(user_dir) != 1L || !nzchar(user_dir)) {
        user_dir <- file.path(path.expand("~"), ".saira")
    }

    normalizePath(user_dir, winslash = "/", mustWork = FALSE)
}

# A server that more than one person uses sets SAIRA_PUBLIC=true. Its sessions
# read the alias store but do not write to it (ADR-182).
rostrum_learning_enabled <- function() {
    !tolower(trimws(Sys.getenv("SAIRA_PUBLIC", unset = ""))) %in% c("true", "1", "yes")
}

rostrum_default_db_path <- function() {
    file.path(rostrum_resolve_data_dir(), "rostrum.sqlite")
}

rostrum_normalize_db_path <- function(path = NULL, create_dir = TRUE) {
    db_path <- if (is.null(path)) rostrum_default_db_path() else path

    if (!is.character(db_path) || length(db_path) != 1L || is.na(db_path) || !nzchar(trimws(db_path))) {
        stop("path must be a non-empty character scalar.")
    }

    resolved_path <- normalizePath(db_path, winslash = "/", mustWork = FALSE)
    db_dir <- dirname(resolved_path)

    if (isTRUE(create_dir) && !dir.exists(db_dir)) {
        dir.create(db_dir, recursive = TRUE, showWarnings = FALSE)
    }
    if (isTRUE(create_dir) && !dir.exists(db_dir)) {
        stop("Could not create directory for Rostrum SQLite database: ", db_dir)
    }

    resolved_path
}

#' Open a Rostrum SQLite Connection
#'
#' Opens (or creates) the Rostrum learning database and optionally runs
#' any pending schema migrations.
#'
#' @param path Character. Path to the SQLite file. Defaults to a
#'   platform-appropriate user data directory.
#' @param create_dir Logical. Create parent directories if missing (default TRUE).
#' @param migrate Logical. Run pending migrations on connect (default TRUE).
#' @param target_version Integer. Target schema version (default current).
#' @return A \code{DBIConnection} object. Caller must disconnect with
#'   \code{DBI::dbDisconnect()}.
#' @export
rostrum_connect <- function(path = NULL, create_dir = TRUE, migrate = TRUE, target_version = rostrum_schema_target_version()) {
    db_path <- rostrum_normalize_db_path(path = path, create_dir = create_dir)
    conn <- DBI::dbConnect(RSQLite::SQLite(), dbname = db_path)

    DBI::dbExecute(conn, "PRAGMA foreign_keys = ON")
    DBI::dbGetQuery(conn, "PRAGMA journal_mode = WAL")
    DBI::dbExecute(conn, "PRAGMA busy_timeout = 5000")
    # Safe companion to WAL: commits stop fsync-ing, which on WSL2 was the bulk
    # of an alias write's latency. Durability is only at risk if the OS itself
    # crashes mid-commit, never if the app does.
    DBI::dbExecute(conn, "PRAGMA synchronous = NORMAL")

    if (isTRUE(migrate)) {
        migration_ok <- FALSE
        on.exit(
            {
                if (!migration_ok && DBI::dbIsValid(conn)) {
                    DBI::dbDisconnect(conn)
                }
            },
            add = TRUE
        )

        rostrum_migrate(conn, target_version = target_version)
        migration_ok <- TRUE
    }

    conn
}

# Synchronise bundled synonyms (source = "v1_rds") with the SQLite DB.
#
# Reconciles the V1 RDS bundle against the existing DB rows with
# source = "v1_rds". The sync is hash-gated per DB path to avoid redundant
# reads when called repeatedly within the same R process.
#
# Actions taken within a single BEGIN IMMEDIATE transaction:
#   - INSERT new pairs absent from the DB
#   - UPDATE rows whose confidence changed in the bundle
#   - SET active = 0 for bundled rows that were removed from the RDS
#
# Rows with source != "v1_rds" and all rows in rostrum_aliases are never
# touched.
#
# @param conn Valid DBI connection (WAL + FK enabled via rostrum_connect()).
# @param path Optional explicit path to dwc_synonyms_v1.rds.
# @return Invisible integer: total number of rows changed (0 if nothing changed).
rostrum_sync_synonyms <- function(conn, path = NULL) {
    if (!DBI::dbIsValid(conn)) {
        stop("conn must be a valid DBI connection.", call. = FALSE)
    }

    # Resolve and load RDS bundle
    raw <- tryCatch(
        {
            if (!is.null(path)) {
                if (!file.exists(path)) stop("path does not exist: ", path)
                readRDS(path)
            } else {
                candidates <- c(
                    system.file("extdata", "dwc_synonyms_v1.rds", package = "saira"),
                    file.path("inst", "extdata", "dwc_synonyms_v1.rds"),
                    file.path("..", "..", "inst", "extdata", "dwc_synonyms_v1.rds")
                )
                candidates <- unique(candidates[nzchar(candidates)])
                rds_path <- candidates[file.exists(candidates)][1L]
                if (length(rds_path) == 0L || is.na(rds_path)) {
                    stop("dwc_synonyms_v1.rds not found in expected locations.")
                }
                readRDS(rds_path)
            }
        },
        error = function(e) {
            warning("[rostrum] Synonym sync skipped (V1 file unavailable): ", e$message)
            NULL
        }
    )

    if (is.null(raw)) {
        return(invisible(0L))
    }

    # Hash gate: skip if same bundle was already synced for this DB in this process
    rds_hash <- tryCatch(
        digest::digest(raw),
        error = function(e) NA_character_
    )
    if (is.na(rds_hash)) {
        return(invisible(0L))
    }

    conn_key <- tryCatch(
        {
            info <- DBI::dbGetInfo(conn)
            k <- info$dbname
            if (is.null(k) || !nzchar(k)) "unknown" else k
        },
        error = function(e) "unknown"
    )

    if (identical(.rostrum_bundle_sync_cache[[conn_key]], rds_hash)) {
        return(invisible(0L))
    }

    v2 <- adapt_synonyms_v1_to_v2(raw)

    # Fetch existing bundled rows from DB (active and inactive)
    existing <- DBI::dbGetQuery(
        conn,
        "SELECT term, synonym, language, context, confidence, active
         FROM rostrum_synonyms WHERE source = 'v1_rds'"
    )

    pk_cols <- c("term", "synonym", "language", "context")
    make_pk <- function(df) do.call(paste, c(df[pk_cols], list(sep = "\x01")))

    v2_pks   <- make_pk(v2)
    ex_pks   <- if (nrow(existing) > 0L) make_pk(existing) else character(0L)
    now_utc  <- rostrum_now_utc()
    n_changes <- 0L

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
            # INSERT new rows (in v2 but not in existing DB)
            new_mask <- !v2_pks %in% ex_pks
            if (any(new_mask)) {
                DBI::dbAppendTable(conn, "rostrum_synonyms", v2[new_mask, , drop = FALSE])
                n_changes <- n_changes + sum(new_mask)
            }

            # UPDATE rows with changed confidence
            if (nrow(existing) > 0L) {
                both_mask <- v2_pks %in% ex_pks
                if (any(both_mask)) {
                    v2_both  <- v2[both_mask, , drop = FALSE]
                    ex_idx   <- match(v2_pks[both_mask], ex_pks)
                    ex_both  <- existing[ex_idx, , drop = FALSE]

                    conf_changed <- abs(v2_both$confidence - ex_both$confidence) > 1e-9
                    for (i in which(conf_changed)) {
                        DBI::dbExecute(
                            conn,
                            paste(
                                "UPDATE rostrum_synonyms",
                                "SET confidence = ?, updated_at = ?",
                                "WHERE term = ? AND synonym = ? AND language = ?",
                                "  AND context = ? AND source = 'v1_rds'"
                            ),
                            params = list(
                                v2_both$confidence[[i]], now_utc,
                                v2_both$term[[i]], v2_both$synonym[[i]],
                                v2_both$language[[i]], v2_both$context[[i]]
                            )
                        )
                        n_changes <- n_changes + 1L
                    }
                }

                # DEACTIVATE rows removed from the bundle (were active, no longer in v2)
                active_mask     <- as.integer(existing$active) == 1L
                active_ex       <- existing[active_mask, , drop = FALSE]
                active_ex_pks   <- ex_pks[active_mask]
                removed_pks     <- active_ex_pks[!active_ex_pks %in% v2_pks]

                if (length(removed_pks) > 0L) {
                    removed_ex <- active_ex[make_pk(active_ex) %in% removed_pks, , drop = FALSE]
                    for (i in seq_len(nrow(removed_ex))) {
                        DBI::dbExecute(
                            conn,
                            paste(
                                "UPDATE rostrum_synonyms",
                                "SET active = 0, updated_at = ?",
                                "WHERE term = ? AND synonym = ? AND language = ?",
                                "  AND context = ? AND source = 'v1_rds'"
                            ),
                            params = list(
                                now_utc,
                                removed_ex$term[[i]], removed_ex$synonym[[i]],
                                removed_ex$language[[i]], removed_ex$context[[i]]
                            )
                        )
                        n_changes <- n_changes + 1L
                    }
                }
            }

            DBI::dbExecute(conn, "COMMIT")
            committed <- TRUE
        },
        error = function(e) {
            stop("Failed to sync synonyms from V1 RDS: ", e$message, call. = FALSE)
        }
    )

    # Update process-level cache: this bundle is now in sync for this DB path
    .rostrum_bundle_sync_cache[[conn_key]] <- rds_hash

    invisible(n_changes)
}

#' Load active synonyms from SQLite in V1-compatible format.
#'
#' Returns a data.frame with columns term, synonym, name_score, lang, active —
#' the same schema expected by sanitize_synonyms_table() and
#' prepare_synonyms_for_scoring(). Converts V2 fields back:
#'   confidence -> name_score, language -> lang (mul -> any).
#'
#' @param conn Valid DBI connection.
#' @return data.frame with V1-compatible columns, or NULL if table is empty.
#' @export
rostrum_load_synonyms_from_db <- function(conn) {
    if (!DBI::dbIsValid(conn)) {
        stop("conn must be a valid DBI connection.", call. = FALSE)
    }

    rows <- DBI::dbGetQuery(
        conn,
        paste(
            "SELECT term, synonym,",
            "  confidence AS name_score,",
            "  language   AS lang,",
            "  active",
            "FROM rostrum_synonyms",
            "WHERE active = 1"
        )
    )

    if (nrow(rows) == 0L) {
        return(NULL)
    }

    # Reverse V2 language encoding: mul → any
    rows$lang[rows$lang == "mul"] <- "any"

    rows
}
