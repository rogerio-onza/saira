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

rostrum_current_schema_version <- function(conn) {
    if (!DBI::dbExistsTable(conn, "schema_version")) {
        return(0L)
    }

    query <- DBI::dbGetQuery(conn, "SELECT MAX(version) AS version FROM schema_version")
    if (nrow(query) == 0L) {
        return(0L)
    }
    version <- query$version[[1]]

    if (is.na(version)) {
        return(0L)
    }

    as.integer(version)
}

rostrum_migration_registry <- function() {
    list(
        `1` = rostrum_migrate_v1,
        `2` = rostrum_migrate_v2,
        `3` = rostrum_migrate_v3
    )
}

rostrum_migrate <- function(conn, target_version = rostrum_schema_target_version(), migration_fns = NULL) {
    if (!DBI::dbIsValid(conn)) {
        stop("conn must be a valid DBI connection.")
    }

    target_version <- as.integer(target_version)
    if (length(target_version) != 1L || is.na(target_version) || target_version < 0L) {
        stop("target_version must be a single non-negative integer.")
    }

    if (is.null(migration_fns)) {
        migration_fns <- rostrum_migration_registry()
    }
    if (!is.list(migration_fns) || length(migration_fns) == 0L) {
        stop("migration_fns must be a non-empty named list of functions.")
    }

    current <- rostrum_current_schema_version(conn)
    if (current >= target_version) {
        return(invisible(TRUE))
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

    tryCatch(
        {
            DBI::dbExecute(
                conn,
                "CREATE TABLE IF NOT EXISTS schema_version (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL)"
            )

            current_tx <- rostrum_current_schema_version(conn)
            if (current_tx < target_version) {
                for (version in seq.int(current_tx + 1L, target_version)) {
                    migration_fn <- migration_fns[[as.character(version)]]
                    if (!is.function(migration_fn)) {
                        stop("Missing migration function for schema version ", version)
                    }

                    migration_fn(conn)

                    DBI::dbExecute(
                        conn,
                        "INSERT INTO schema_version(version, applied_at) VALUES(?, ?)",
                        params = list(as.integer(version), rostrum_now_utc())
                    )
                }
            }

            DBI::dbExecute(conn, "COMMIT")
            committed <- TRUE
            invisible(TRUE)
        },
        error = function(e) {
            stop("Migration to v", target_version, " failed: ", e$message, call. = FALSE)
        }
    )
}

rostrum_migrate_v1 <- function(conn) {
    ddl <- c(
        "CREATE TABLE IF NOT EXISTS rostrum_synonyms (
            term TEXT NOT NULL,
            synonym TEXT NOT NULL,
            language TEXT NOT NULL,
            context TEXT NOT NULL,
            confidence REAL NOT NULL,
            validation_regex TEXT,
            notes TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            source TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY(term, synonym, language, context, source)
        )",
        "CREATE TABLE IF NOT EXISTS rostrum_aliases (
            alias_id INTEGER PRIMARY KEY,
            scope TEXT NOT NULL,
            user_id TEXT,
            institution_id TEXT,
            col_name_norm TEXT NOT NULL,
            dwc_term TEXT NOT NULL,
            confidence REAL NOT NULL,
            reviewed INTEGER NOT NULL DEFAULT 0,
            deprecated INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            created_by TEXT,
            updated_at TEXT NOT NULL
        )",
        "CREATE TABLE IF NOT EXISTS rostrum_alias_events (
            event_id INTEGER PRIMARY KEY,
            alias_id INTEGER,
            action TEXT NOT NULL,
            run_id TEXT,
            payload_json TEXT,
            created_at TEXT NOT NULL,
            created_by TEXT,
            FOREIGN KEY(alias_id) REFERENCES rostrum_aliases(alias_id)
        )",
        "CREATE TABLE IF NOT EXISTS rostrum_templates (
            template_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            scope TEXT NOT NULL,
            owner_id TEXT,
            institution_id TEXT,
            schema_version TEXT NOT NULL,
            app_min_version TEXT,
            app_max_version TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            description TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )",
        "CREATE TABLE IF NOT EXISTS rostrum_template_items (
            template_id TEXT NOT NULL,
            dwc_term TEXT NOT NULL,
            source_columns_json TEXT NOT NULL,
            transform_kind TEXT,
            transform_params_json TEXT,
            priority INTEGER NOT NULL DEFAULT 0,
            required INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY(template_id, dwc_term),
            FOREIGN KEY(template_id) REFERENCES rostrum_templates(template_id)
        )",
        "CREATE TABLE IF NOT EXISTS rostrum_runs (
            run_id TEXT PRIMARY KEY,
            session_id TEXT,
            app_version TEXT,
            engine_version TEXT,
            rows_n INTEGER NOT NULL,
            cols_n INTEGER NOT NULL,
            elapsed_ms INTEGER NOT NULL,
            stage1_ms INTEGER,
            stage2_ms INTEGER,
            stage3_ms INTEGER,
            auto_n INTEGER NOT NULL DEFAULT 0,
            suggested_n INTEGER NOT NULL DEFAULT 0,
            ambiguous_n INTEGER NOT NULL DEFAULT 0,
            manual_n INTEGER NOT NULL DEFAULT 0,
            options_json TEXT,
            metrics_json TEXT,
            created_at TEXT NOT NULL
        )",
        "CREATE TABLE IF NOT EXISTS rostrum_run_details (
            run_id TEXT NOT NULL,
            term TEXT NOT NULL,
            column_name TEXT NOT NULL,
            name_score REAL,
            value_score REAL,
            penalty_score REAL,
            final_score REAL,
            veto_code TEXT,
            decision_band TEXT,
            explain_json TEXT,
            PRIMARY KEY(run_id, term, column_name),
            FOREIGN KEY(run_id) REFERENCES rostrum_runs(run_id)
        )",
        "CREATE INDEX IF NOT EXISTS idx_alias_lookup
            ON rostrum_aliases (scope, user_id, institution_id, col_name_norm, dwc_term, deprecated)",
        "CREATE INDEX IF NOT EXISTS idx_synonyms_term_lang
            ON rostrum_synonyms (term, language, active)",
        "CREATE INDEX IF NOT EXISTS idx_runs_created_at
            ON rostrum_runs (created_at)",
        "CREATE INDEX IF NOT EXISTS idx_alias_events_run_id
            ON rostrum_alias_events (run_id)"
    )

    for (statement in ddl) {
        DBI::dbExecute(conn, statement)
    }

    invisible(TRUE)
}

rostrum_migrate_v2 <- function(conn) {
    columns <- DBI::dbGetQuery(conn, "PRAGMA table_info(rostrum_templates)")
    has_use_case <- "name" %in% names(columns) && "use_case" %in% as.character(columns$name)

    if (!isTRUE(has_use_case)) {
        DBI::dbExecute(conn, "ALTER TABLE rostrum_templates ADD COLUMN use_case TEXT")
    }

    DBI::dbExecute(
        conn,
        "CREATE INDEX IF NOT EXISTS idx_templates_catalog ON rostrum_templates (institution_id, use_case, is_active, updated_at)"
    )

    invisible(TRUE)
}

rostrum_migrate_v3 <- function(conn) {
    ddl <- c(
        "CREATE INDEX IF NOT EXISTS idx_synonyms_value ON rostrum_synonyms (synonym)",
        "CREATE INDEX IF NOT EXISTS idx_alias_active ON rostrum_aliases (deprecated, reviewed)",
        "CREATE INDEX IF NOT EXISTS idx_alias_events_created_at ON rostrum_alias_events (created_at)"
    )
    for (statement in ddl) {
        DBI::dbExecute(conn, statement)
    }
    invisible(TRUE)
}

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
    now_utc <- rostrum_now_utc()

    if (identical(scope_norm, "personal") && is.na(user_id_norm)) {
        user_id_norm <- "anonymous"
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

    tryCatch(
        {
            existing <- DBI::dbGetQuery(
                conn,
                paste(
                    "SELECT alias_id FROM rostrum_aliases",
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
                action_effective <- "alias_updated"
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

            DBI::dbExecute(conn, "COMMIT")
            committed <- TRUE

            list(
                alias_id = alias_id,
                action = action_effective,
                scope = scope_norm,
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
    updated_rank <- suppressWarnings(as.numeric(as.POSIXct(alias_df$updated_at, tz = "UTC")))
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

rostrum_lookup_alias_for_term <- function(
    conn,
    col_name,
    dwc_term,
    user_id = Sys.getenv("SAIRA_USER", unset = ""),
    institution_id = Sys.getenv("SAIRA_INSTITUTION", unset = "")
) {
    alias_df <- rostrum_list_aliases_for_column(
        conn = conn,
        col_name = col_name,
        dwc_term = dwc_term,
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
#' Deprecates all non-public alias records created during \code{run_id}.
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
                    "  AND alias_id IS NOT NULL"
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
