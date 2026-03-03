rostrum_migrate <- saira:::rostrum_migrate
rostrum_migrate_v1 <- saira:::rostrum_migrate_v1

# Minimal V1-format synonyms fixture
.make_v1_synonyms_rds <- function() {
    path <- tempfile(fileext = ".rds")
    df <- data.frame(
        term      = c("decimalLatitude", "decimalLongitude"),
        synonym   = c("latitude decimal", "longitude decimal"),
        name_score = c(0.92, 0.91),
        lang      = c("any", "pt"),
        active    = c(TRUE, TRUE),
        stringsAsFactors = FALSE
    )
    saveRDS(df, path)
    path
}

testthat::test_that("rostrum_migrate creates v1 schema idempotently", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path, migrate = FALSE)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
    }, add = TRUE)

    rostrum_migrate(conn, target_version = 1L)
    rostrum_migrate(conn, target_version = 1L)

    tables <- DBI::dbGetQuery(conn, "SELECT name FROM sqlite_master WHERE type = 'table'")$name
    required_tables <- c(
        "schema_version",
        "rostrum_synonyms",
        "rostrum_aliases",
        "rostrum_alias_events",
        "rostrum_templates",
        "rostrum_template_items",
        "rostrum_runs",
        "rostrum_run_details"
    )
    testthat::expect_true(all(required_tables %in% tables))

    version <- DBI::dbGetQuery(conn, "SELECT MAX(version) AS v FROM schema_version")$v[[1]]
    version_rows <- DBI::dbGetQuery(conn, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 1")$n[[1]]
    testthat::expect_identical(as.integer(version), 1L)
    testthat::expect_identical(as.integer(version_rows), 1L)
})

testthat::test_that("rostrum_migrate rolls back cleanly on mid-failure", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- DBI::dbConnect(RSQLite::SQLite(), dbname = db_path)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
    }, add = TRUE)

    failing_migrations <- list(
        `1` = rostrum_migrate_v1,
        `2` = function(conn) {
            DBI::dbExecute(conn, "CREATE TABLE rollback_probe (id INTEGER PRIMARY KEY)")
            stop("forced migration failure")
        }
    )

    testthat::expect_error(
        rostrum_migrate(conn, target_version = 2L, migration_fns = failing_migrations),
        "Migration to v2 failed"
    )

    testthat::expect_false(DBI::dbExistsTable(conn, "rollback_probe"))
    testthat::expect_false(DBI::dbExistsTable(conn, "rostrum_synonyms"))
    testthat::expect_false(DBI::dbExistsTable(conn, "schema_version"))
})

testthat::test_that("rostrum_connect sets WAL mode, foreign_keys and busy_timeout", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path, migrate = FALSE)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
    }, add = TRUE)

    fk <- DBI::dbGetQuery(conn, "PRAGMA foreign_keys")[[1]]
    journal <- tolower(as.character(DBI::dbGetQuery(conn, "PRAGMA journal_mode")[[1]]))
    busy <- as.integer(DBI::dbGetQuery(conn, "PRAGMA busy_timeout")[[1]])

    testthat::expect_identical(as.integer(fk), 1L)
    testthat::expect_identical(journal, "wal")
    testthat::expect_identical(busy, 5000L)
})

testthat::test_that("schema_version increments correctly across migration steps", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- DBI::dbConnect(RSQLite::SQLite(), dbname = db_path)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
    }, add = TRUE)

    DBI::dbExecute(conn, "PRAGMA foreign_keys = ON")

    migrations <- list(
        `1` = rostrum_migrate_v1,
        `2` = function(conn) {
            DBI::dbExecute(conn, "CREATE TABLE IF NOT EXISTS rostrum_meta (key TEXT PRIMARY KEY, value TEXT)")
        }
    )

    rostrum_migrate(conn, target_version = 2L, migration_fns = migrations)

    version <- DBI::dbGetQuery(conn, "SELECT MAX(version) AS v FROM schema_version")$v[[1]]
    n_versions <- DBI::dbGetQuery(conn, "SELECT COUNT(*) AS n FROM schema_version")$n[[1]]

    testthat::expect_identical(as.integer(version), 2L)
    testthat::expect_identical(as.integer(n_versions), 2L)
    testthat::expect_true(DBI::dbExistsTable(conn, "rostrum_meta"))
})

testthat::test_that("rostrum_seed_synonyms_if_empty inserts all rows from V1 RDS", {
    v1_path <- .make_v1_synonyms_rds()
    on.exit(unlink(v1_path), add = TRUE)

    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit(if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn), add = TRUE)

    n <- rostrum_seed_synonyms_if_empty(conn, v1_path = v1_path)

    rows <- DBI::dbGetQuery(conn, "SELECT * FROM rostrum_synonyms")

    testthat::expect_identical(as.integer(n), 2L)
    testthat::expect_identical(nrow(rows), 2L)
    testthat::expect_true("decimalLatitude" %in% rows$term)
    # lang "any" converted to "mul" in V2 storage
    testthat::expect_true("mul" %in% rows$language)
    testthat::expect_true("pt" %in% rows$language)
})

testthat::test_that("rostrum_seed_synonyms_if_empty is idempotent (no duplicate rows)", {
    v1_path <- .make_v1_synonyms_rds()
    on.exit(unlink(v1_path), add = TRUE)

    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit(if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn), add = TRUE)

    rostrum_seed_synonyms_if_empty(conn, v1_path = v1_path)
    n2 <- rostrum_seed_synonyms_if_empty(conn, v1_path = v1_path)
    rows <- DBI::dbGetQuery(conn, "SELECT COUNT(*) AS n FROM rostrum_synonyms")$n

    testthat::expect_identical(as.integer(n2), 0L)
    testthat::expect_identical(as.integer(rows), 2L)
})

testthat::test_that("rostrum_load_synonyms_from_db returns V1-compatible format", {
    v1_path <- .make_v1_synonyms_rds()
    on.exit(unlink(v1_path), add = TRUE)

    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit(if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn), add = TRUE)

    rostrum_seed_synonyms_if_empty(conn, v1_path = v1_path)
    result <- rostrum_load_synonyms_from_db(conn)

    testthat::expect_true(is.data.frame(result))
    testthat::expect_true(all(c("term", "synonym", "name_score", "lang", "active") %in% names(result)))
    # "mul" must be converted back to "any" for scorer compatibility
    testthat::expect_false("mul" %in% result$lang)
    testthat::expect_true("any" %in% result$lang)
    testthat::expect_true(all(result$name_score >= 0.90 & result$name_score <= 0.98))
})

testthat::test_that("rostrum_load_synonyms_from_db returns NULL when table is empty", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit(if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn), add = TRUE)

    result <- rostrum_load_synonyms_from_db(conn)

    testthat::expect_null(result)
})

testthat::test_that("default migrations include template catalog use_case support", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
    }, add = TRUE)

    version <- DBI::dbGetQuery(conn, "SELECT MAX(version) AS v FROM schema_version")$v[[1]]
    cols <- DBI::dbGetQuery(conn, "PRAGMA table_info(rostrum_templates)")
    idx <- DBI::dbGetQuery(conn, "SELECT name FROM sqlite_master WHERE type='index'")$name

    testthat::expect_identical(as.integer(version), 3L)
    testthat::expect_true("use_case" %in% as.character(cols$name))
    testthat::expect_true("idx_templates_catalog" %in% idx)
})
