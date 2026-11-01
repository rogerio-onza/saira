# Utils rostrum migrations

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
