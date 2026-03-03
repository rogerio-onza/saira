rostrum_connect <- getFromNamespace("rostrum_connect", "saira")
rostrum_upsert_alias <- getFromNamespace("rostrum_upsert_alias", "saira")
rostrum_lookup_alias <- getFromNamespace("rostrum_lookup_alias", "saira")
rostrum_record_alias_confirmation <- getFromNamespace("rostrum_record_alias_confirmation", "saira")
rostrum_record_alias_override <- getFromNamespace("rostrum_record_alias_override", "saira")
rostrum_deprecate_alias <- getFromNamespace("rostrum_deprecate_alias", "saira")
undo_session_aliases <- getFromNamespace("undo_session_aliases", "saira")
run_rostrum_engine <- getFromNamespace("run_rostrum_engine", "saira")
rostrum_options <- getFromNamespace("rostrum_options", "saira")

empty_synonyms <- function() {
    data.frame(
        term = character(0),
        synonym = character(0),
        name_score = numeric(0),
        lang = character(0),
        active = logical(0),
        stringsAsFactors = FALSE
    )
}

testthat::test_that("alias created from confirmation persists across sessions", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
    }, add = TRUE)

    rostrum_record_alias_confirmation(
        conn = conn,
        col_name = "collector_name",
        dwc_term = "recordedBy",
        score_original = 0.83,
        scope = "personal",
        run_id = "run-confirm-1",
        user_id = "user_a",
        institution_id = "inst_a",
        created_by = "user_a"
    )
    DBI::dbDisconnect(conn)

    conn2 <- rostrum_connect(path = db_path)
    on.exit({
        if (DBI::dbIsValid(conn2)) DBI::dbDisconnect(conn2)
    }, add = TRUE)

    hit <- rostrum_lookup_alias(
        conn = conn2,
        col_name = "collector_name",
        user_id = "user_a",
        institution_id = "inst_a"
    )

    testthat::expect_identical(nrow(hit), 1L)
    testthat::expect_identical(as.character(hit$dwc_term[[1]]), "recordedBy")
    testthat::expect_equal(as.numeric(hit$confidence[[1]]), 0.83, tolerance = 1e-09)
})

testthat::test_that("deprecated alias does not influence engine mapping", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
    }, add = TRUE)

    created <- rostrum_record_alias_confirmation(
        conn = conn,
        col_name = "foo_col",
        dwc_term = "eventDate",
        score_original = 0.88,
        scope = "personal",
        run_id = "run-deprecate-1",
        user_id = "user_a",
        institution_id = "inst_a",
        created_by = "user_a"
    )
    rostrum_deprecate_alias(
        conn = conn,
        alias_id = created$alias_id,
        run_id = "run-deprecate-1",
        created_by = "user_a"
    )

    hit <- rostrum_lookup_alias(
        conn = conn,
        col_name = "foo_col",
        user_id = "user_a",
        institution_id = "inst_a"
    )
    testthat::expect_identical(nrow(hit), 0L)

    df <- data.frame(foo_col = c("2024-01-01", "2024-01-02"), stringsAsFactors = FALSE)
    dwc_terms <- data.frame(term = "eventDate", stringsAsFactors = FALSE)
    res <- run_rostrum_engine(
        df = df,
        dwc_terms_df = dwc_terms,
        options = rostrum_options(),
        context = list(user_id = "user_a", institution_id = "inst_a"),
        conn = conn,
        synonyms_tbl = empty_synonyms()
    )

    testthat::expect_false(identical(as.character(res$data$status[[1]]), "ALIAS"))
})

testthat::test_that("undo_session_aliases deprecates all aliases from a run_id", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
    }, add = TRUE)

    rostrum_record_alias_confirmation(
        conn = conn,
        col_name = "lat_col",
        dwc_term = "decimalLatitude",
        score_original = 0.91,
        scope = "personal",
        run_id = "run-batch-undo",
        user_id = "user_a",
        institution_id = "inst_a",
        created_by = "user_a"
    )
    rostrum_record_alias_override(
        conn = conn,
        col_name = "lon_col",
        dwc_term = "decimalLongitude",
        scope = "personal",
        run_id = "run-batch-undo",
        user_id = "user_a",
        institution_id = "inst_a",
        created_by = "user_a"
    )

    updated_n <- undo_session_aliases(conn = conn, run_id = "run-batch-undo", created_by = "user_a")
    deprecated_n <- DBI::dbGetQuery(
        conn,
        "SELECT COUNT(*) AS n FROM rostrum_aliases WHERE deprecated = 1"
    )$n[[1]]

    testthat::expect_identical(as.integer(updated_n), 2L)
    testthat::expect_identical(as.integer(deprecated_n), 2L)
})

testthat::test_that("scope precedence is personal over institution over public", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
    }, add = TRUE)

    rostrum_upsert_alias(
        conn = conn,
        col_name = "shared_col",
        dwc_term = "eventDate",
        confidence = 0.99,
        scope = "public",
        reviewed = TRUE,
        run_id = "run-precedence",
        action = "seed_public",
        created_by = "seed"
    )
    rostrum_upsert_alias(
        conn = conn,
        col_name = "shared_col",
        dwc_term = "recordedBy",
        confidence = 0.95,
        scope = "institution",
        reviewed = TRUE,
        run_id = "run-precedence",
        action = "seed_institution",
        created_by = "seed",
        institution_id = "inst_a"
    )
    rostrum_upsert_alias(
        conn = conn,
        col_name = "shared_col",
        dwc_term = "scientificName",
        confidence = 0.60,
        scope = "personal",
        reviewed = TRUE,
        run_id = "run-precedence",
        action = "seed_personal",
        created_by = "seed",
        user_id = "user_a",
        institution_id = "inst_a"
    )

    hit_personal <- rostrum_lookup_alias(
        conn = conn,
        col_name = "shared_col",
        user_id = "user_a",
        institution_id = "inst_a"
    )
    hit_institution <- rostrum_lookup_alias(
        conn = conn,
        col_name = "shared_col",
        user_id = "user_b",
        institution_id = "inst_a"
    )
    hit_public <- rostrum_lookup_alias(
        conn = conn,
        col_name = "shared_col",
        user_id = "user_b",
        institution_id = "inst_b"
    )

    testthat::expect_identical(as.character(hit_personal$dwc_term[[1]]), "scientificName")
    testthat::expect_identical(as.character(hit_institution$dwc_term[[1]]), "recordedBy")
    testthat::expect_identical(as.character(hit_public$dwc_term[[1]]), "eventDate")
})

testthat::test_that("duplicate alias upsert updates existing row instead of inserting", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
    }, add = TRUE)

    rostrum_upsert_alias(
        conn = conn,
        col_name = "collector_name",
        dwc_term = "recordedBy",
        confidence = 0.75,
        scope = "personal",
        reviewed = TRUE,
        run_id = "run-dup",
        action = "first_insert",
        created_by = "user_a",
        user_id = "user_a",
        institution_id = "inst_a"
    )
    rostrum_upsert_alias(
        conn = conn,
        col_name = "collector_name",
        dwc_term = "recordedBy",
        confidence = 0.89,
        scope = "personal",
        reviewed = TRUE,
        run_id = "run-dup",
        action = "second_update",
        created_by = "user_a",
        user_id = "user_a",
        institution_id = "inst_a"
    )

    agg <- DBI::dbGetQuery(
        conn,
        paste(
            "SELECT COUNT(*) AS n, MAX(confidence) AS max_conf",
            "FROM rostrum_aliases",
            "WHERE scope = 'personal'",
            "  AND user_id = 'user_a'",
            "  AND institution_id = 'inst_a'",
            "  AND col_name_norm = ?",
            "  AND dwc_term = 'recordedBy'"
        ),
        params = list("collector name")
    )

    testthat::expect_identical(as.integer(agg$n[[1]]), 1L)
    testthat::expect_equal(as.numeric(agg$max_conf[[1]]), 0.89, tolerance = 1e-09)
})
