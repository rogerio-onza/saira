rostrum_validate_template_payload <- saira:::rostrum_validate_template_payload
rostrum_export_template_payload <- saira:::rostrum_export_template_payload

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

testthat::test_that("Template JSON valid payload passes validation", {
    payload <- list(
        template_id = "tpl-valid-1",
        name = "Template Valid",
        scope = "personal",
        schema_version = "1.0.0",
        app_min_version = "0.1.0",
        items = list(
            list(
                dwc_term = "scientificName",
                source_columns = c("sci_name"),
                priority = 100L,
                required = TRUE
            )
        )
    )

    out <- rostrum_validate_template_payload(payload)
    testthat::expect_identical(out$template_id, "tpl-valid-1")
    testthat::expect_identical(out$scope, "personal")
    testthat::expect_identical(length(out$items), 1L)
    testthat::expect_identical(out$items[[1]]$dwc_term, "scientificName")
})

testthat::test_that("Template missing required fields fails with descriptive error", {
    payload <- list(
        template_id = "tpl-invalid-1",
        name = "Template Invalid",
        scope = "personal",
        schema_version = "1.0.0"
    )

    testthat::expect_error(
        rostrum_validate_template_payload(payload),
        "missing required fields"
    )
})

testthat::test_that("Template with future app_min_version is rejected", {
    payload <- list(
        template_id = "tpl-future-min",
        name = "Template Future",
        scope = "personal",
        schema_version = "1.0.0",
        app_min_version = "99.0.0",
        items = list(
            list(dwc_term = "eventDate", source_columns = c("event_date"))
        )
    )

    testthat::expect_error(
        rostrum_validate_template_payload(payload),
        "requires app_min_version"
    )
})

testthat::test_that("Template with past app_max_version warns but still validates", {
    payload <- list(
        template_id = "tpl-old-max",
        name = "Template Old",
        scope = "personal",
        schema_version = "1.0.0",
        app_max_version = "0.0.1",
        items = list(
            list(dwc_term = "eventDate", source_columns = c("event_date"))
        )
    )

    testthat::expect_warning(
        out <- rostrum_validate_template_payload(payload),
        "older than current app version"
    )
    testthat::expect_identical(out$template_id, "tpl-old-max")
})

testthat::test_that("Template export captures full mapping state", {
    map_values <- list(
        scientificName = "sci_col",
        eventDate = c("year_col", "month_col"),
        decimalLatitude = ""
    )
    map_meta <- list(
        scientificName = list(score = 0.99),
        eventDate = list(score = 0.82)
    )

    payload <- rostrum_export_template_payload(
        map_values = map_values,
        map_meta = map_meta,
        template_id = "tpl-export",
        name = "Template Export",
        scope = "personal",
        use_case = "occurrence"
    )

    testthat::expect_identical(payload$template_id, "tpl-export")
    testthat::expect_identical(length(payload$items), 2L)
    event_item <- payload$items[[which(vapply(payload$items, function(x) x$dwc_term, FUN.VALUE = character(1)) == "eventDate")]]
    testthat::expect_identical(event_item$source_columns, c("year_col", "month_col"))
})

testthat::test_that("Template import applies mappings with TEMPLATE badge status", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
    }, add = TRUE)

    tpl_json <- rostrum_export_template_json(
        map_values = list(scientificName = "sci_col"),
        map_meta = list(scientificName = list(score = 1)),
        template_id = "tpl-import-1",
        name = "Template Import",
        scope = "personal",
        app_min_version = "0.1.0"
    )
    rostrum_import_template_json(conn = conn, json_payload = tpl_json, replace = TRUE)

    df <- data.frame(
        sci_col = c("Panthera onca", "Leopardus pardalis"),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(term = "scientificName", stringsAsFactors = FALSE)

    res <- run_rostrum_engine(
        df = df,
        dwc_terms_df = dwc_terms,
        options = rostrum_options(),
        context = list(template_id = "tpl-import-1"),
        conn = conn,
        synonyms_tbl = empty_synonyms()
    )

    testthat::expect_identical(as.character(res$data$status[[1]]), "TEMPLATE")
    testthat::expect_identical(as.character(res$data$selected_col[[1]]), "sci_col")
    testthat::expect_identical(as.character(res$data$reason[[1]]), "template_priority_override")
})

testthat::test_that("Template has priority over heuristic scoring and logs conflicts", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
    }, add = TRUE)

    tpl_json <- rostrum_export_template_json(
        map_values = list(eventDate = "event_date_text"),
        map_meta = list(eventDate = list(score = 1)),
        template_id = "tpl-priority-1",
        name = "Template Priority",
        scope = "personal",
        use_case = "event"
    )
    rostrum_import_template_json(conn = conn, json_payload = tpl_json, replace = TRUE)

    df <- data.frame(
        eventDate = c("2024-01-01", "2024-01-02"),
        event_date_text = c("2023-05-01", "2023-05-02"),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(term = "eventDate", stringsAsFactors = FALSE)

    res <- run_rostrum_engine(
        df = df,
        dwc_terms_df = dwc_terms,
        options = rostrum_options(),
        context = list(template_id = "tpl-priority-1"),
        conn = conn,
        synonyms_tbl = empty_synonyms()
    )

    testthat::expect_identical(as.character(res$data$status[[1]]), "TEMPLATE")
    testthat::expect_identical(as.character(res$data$selected_col[[1]]), "event_date_text")
    testthat::expect_true(any(grepl("conflict override", res$warnings, fixed = TRUE)))
})

testthat::test_that("Local template catalog filters by institution and use_case", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
    }, add = TRUE)

    tpl_a <- rostrum_export_template_json(
        map_values = list(scientificName = "sci"),
        map_meta = list(scientificName = list(score = 1)),
        template_id = "tpl-cat-a",
        name = "Cat A",
        scope = "institution",
        institution_id = "inst_a",
        use_case = "taxon"
    )
    tpl_b <- rostrum_export_template_json(
        map_values = list(eventDate = "evt"),
        map_meta = list(eventDate = list(score = 1)),
        template_id = "tpl-cat-b",
        name = "Cat B",
        scope = "institution",
        institution_id = "inst_b",
        use_case = "event"
    )
    rostrum_import_template_json(conn = conn, json_payload = tpl_a, replace = TRUE)
    rostrum_import_template_json(conn = conn, json_payload = tpl_b, replace = TRUE)

    out <- rostrum_list_template_catalog(
        conn = conn,
        scope = "institution",
        institution_id = "inst_a",
        use_case = "taxon"
    )

    testthat::expect_identical(nrow(out), 1L)
    testthat::expect_identical(as.character(out$template_id[[1]]), "tpl-cat-a")
})

testthat::test_that("rostrum_extra_terms_from_template returns empty for all-base templates", {
    base_terms <- get_dwc_terms()$term
    payload <- list(
        items = list(
            list(dwc_term = base_terms[[1]], source_columns = list("col_a")),
            list(dwc_term = base_terms[[2]], source_columns = list("col_b"))
        )
    )
    result <- saira:::rostrum_extra_terms_from_template(payload, active_terms = base_terms)

    testthat::expect_length(result$to_activate, 0L)
    testthat::expect_length(result$unknown, 0L)
})

testthat::test_that("rostrum_extra_terms_from_template identifies catalog extra terms", {
    base_terms   <- get_dwc_terms()$term
    full_catalog <- get_dwc_full_catalog()
    extra_term   <- setdiff(full_catalog$term, base_terms)[[1]]

    payload <- list(
        items = list(
            list(dwc_term = base_terms[[1]], source_columns = list("col_a")),
            list(dwc_term = extra_term,      source_columns = list("col_b"))
        )
    )
    result <- saira:::rostrum_extra_terms_from_template(payload, active_terms = base_terms)

    testthat::expect_identical(result$to_activate, extra_term)
    testthat::expect_length(result$unknown, 0L)
})

testthat::test_that("rostrum_extra_terms_from_template identifies unknown terms", {
    base_terms <- get_dwc_terms()$term
    payload <- list(
        items = list(
            list(dwc_term = "notARealDwCTerm_xyz", source_columns = list("col_a"))
        )
    )
    result <- saira:::rostrum_extra_terms_from_template(payload, active_terms = base_terms)

    testthat::expect_length(result$to_activate, 0L)
    testthat::expect_identical(result$unknown, "notARealDwCTerm_xyz")
})

testthat::test_that("rostrum_extra_terms_from_template already-active extras are excluded", {
    base_terms   <- get_dwc_terms()$term
    full_catalog <- get_dwc_full_catalog()
    extra_term   <- setdiff(full_catalog$term, base_terms)[[1]]
    active       <- c(base_terms, extra_term)

    payload <- list(
        items = list(list(dwc_term = extra_term, source_columns = list("col_a")))
    )
    result <- saira:::rostrum_extra_terms_from_template(payload, active_terms = active)

    testthat::expect_length(result$to_activate, 0L)
})

# ADR-087: mapping_guide.txt round-trip via rostrum_aliases ------------------

testthat::test_that("is_saira_mapping_guide returns TRUE only for files with magic header", {
    tmp_guide <- tempfile(fileext = ".txt")
    on.exit(unlink(tmp_guide), add = TRUE)
    writeLines(c("# saira:mapping:v1", "Lat -> decimalLatitude"), tmp_guide)

    tmp_data <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp_data), add = TRUE)
    writeLines(c("col_a,col_b", "1,2"), tmp_data)

    testthat::expect_true(is_saira_mapping_guide(tmp_guide))
    testthat::expect_false(is_saira_mapping_guide(tmp_data))
    testthat::expect_false(is_saira_mapping_guide(tempfile(fileext = ".missing")))
})

testthat::test_that("parse_mapping_guide_txt extracts metadata and pairs", {
    tmp <- tempfile(fileext = ".txt")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(c(
        "# saira:mapping:v1",
        "# created_at: 2026-05-10T12:00:00Z",
        "# source_file: AMZ_CAMTRAP.csv",
        "# n_cols_total: 5  n_cols_mapped: 3  n_cols_unmapped: 2  n_rows: 100",
        "#",
        "# Mapeamentos:",
        "Lat              -> decimalLatitude",
        "Lon              -> decimalLongitude",
        "coletor          -> recordedBy",
        "#",
        "# Colunas brutas nao usadas:",
        "notas_campo",
        "codigo_interno"
    ), tmp)

    out <- parse_mapping_guide_txt(tmp)

    testthat::expect_identical(out$meta$created_at, "2026-05-10T12:00:00Z")
    testthat::expect_identical(out$meta$source_file, "AMZ_CAMTRAP.csv")
    testthat::expect_identical(nrow(out$pairs), 3L)
    testthat::expect_identical(out$pairs$source_column, c("Lat", "Lon", "coletor"))
    testthat::expect_identical(out$pairs$dwc_term, c("decimalLatitude", "decimalLongitude", "recordedBy"))
})

testthat::test_that("parse_mapping_guide_txt rejects file without magic header", {
    tmp <- tempfile(fileext = ".txt")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(c("not a guide", "Lat -> decimalLatitude"), tmp)

    testthat::expect_error(parse_mapping_guide_txt(tmp), "magic header")
})

testthat::test_that("parse_mapping_guide_txt silently skips bare lines without '->' (e.g. unmapped columns)", {
    tmp <- tempfile(fileext = ".txt")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(c(
        "# saira:mapping:v1",
        "Lat -> decimalLatitude",
        "notas_campo",
        "codigo_interno",
        "Lon -> decimalLongitude"
    ), tmp)

    out <- parse_mapping_guide_txt(tmp)
    testthat::expect_identical(nrow(out$pairs), 2L)
    testthat::expect_identical(out$pairs$source_column, c("Lat", "Lon"))
})

testthat::test_that("parse_mapping_guide_txt warns on malformed mapping lines (contain '->' but bad shape)", {
    tmp <- tempfile(fileext = ".txt")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(c(
        "# saira:mapping:v1",
        "Lat -> decimalLatitude",
        "-> just_term_no_source",
        "source_no_term -> ",
        "Lon -> decimalLongitude"
    ), tmp)

    out <- testthat::expect_warning(parse_mapping_guide_txt(tmp), "malformed")
    testthat::expect_identical(nrow(out$pairs), 2L)
    testthat::expect_identical(out$pairs$source_column, c("Lat", "Lon"))
})

testthat::test_that("import_mapping_guide_to_aliases upserts and is idempotent", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
        unlink(db_path)
    }, add = TRUE)

    payload <- list(
        meta = list(),
        pairs = data.frame(
            source_column = c("Lat", "Lon", "coletor"),
            dwc_term      = c("decimalLatitude", "decimalLongitude", "recordedBy"),
            stringsAsFactors = FALSE
        )
    )

    n1 <- import_mapping_guide_to_aliases(payload, conn = conn, user_id = "test_user")
    testthat::expect_identical(as.integer(n1), 3L)

    rows1 <- DBI::dbGetQuery(
        conn,
        "SELECT col_name_norm, dwc_term, confidence, reviewed FROM rostrum_aliases WHERE scope = 'personal' AND user_id = 'test_user'"
    )
    testthat::expect_identical(nrow(rows1), 3L)
    testthat::expect_true(all(rows1$confidence == 1.0))
    testthat::expect_true(all(as.logical(rows1$reviewed)))

    # Idempotent: re-importing the same payload UPDATES rather than duplicates.
    n2 <- import_mapping_guide_to_aliases(payload, conn = conn, user_id = "test_user")
    testthat::expect_identical(as.integer(n2), 3L)

    rows2 <- DBI::dbGetQuery(
        conn,
        "SELECT col_name_norm, dwc_term FROM rostrum_aliases WHERE scope = 'personal' AND user_id = 'test_user'"
    )
    testthat::expect_identical(nrow(rows2), 3L)  # still 3, not 6
})

testthat::test_that("import_mapping_guide_to_aliases splits 'colA + colB' composites into separate aliases", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
        unlink(db_path)
    }, add = TRUE)

    payload <- list(
        meta = list(),
        pairs = data.frame(
            source_column = c("year + month + day"),
            dwc_term      = c("eventDate"),
            stringsAsFactors = FALSE
        )
    )

    n <- import_mapping_guide_to_aliases(payload, conn = conn, user_id = "test_user")
    testthat::expect_identical(as.integer(n), 3L)

    rows <- DBI::dbGetQuery(
        conn,
        "SELECT col_name_norm FROM rostrum_aliases WHERE scope = 'personal' AND user_id = 'test_user' AND dwc_term = 'eventDate' ORDER BY col_name_norm"
    )
    testthat::expect_identical(nrow(rows), 3L)
})

testthat::test_that("build_mapping_guide_txt + parse_mapping_guide_txt round-trip preserves pairs", {
    tmp <- tempfile(fileext = ".txt")
    on.exit(unlink(tmp), add = TRUE)

    raw <- data.frame(
        Lat = -15.5, Lon = -47.5, especie = "x", notas = "y",
        stringsAsFactors = FALSE
    )
    map_values <- list(
        decimalLatitude  = "Lat",
        decimalLongitude = "Lon",
        scientificName   = "especie"
    )

    writeLines(build_mapping_guide_txt(map_values, raw, lang = "pt"), tmp)

    parsed <- parse_mapping_guide_txt(tmp)
    testthat::expect_identical(nrow(parsed$pairs), 3L)
    # Sort both sides by term to make order-insensitive:
    parsed_sorted <- parsed$pairs[order(parsed$pairs$dwc_term), ]
    testthat::expect_identical(
        parsed_sorted$source_column,
        c("Lat", "Lon", "especie")
    )
    testthat::expect_identical(
        parsed_sorted$dwc_term,
        c("decimalLatitude", "decimalLongitude", "scientificName")
    )
})

testthat::test_that("end-to-end: guide import populates aliases that rostrum_lookup_alias finds", {
    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
        unlink(db_path)
    }, add = TRUE)

    # Build guide from a fake mapping
    raw <- data.frame(my_lat = 0.0, my_lon = 0.0, stringsAsFactors = FALSE)
    map_values <- list(
        decimalLatitude  = "my_lat",
        decimalLongitude = "my_lon"
    )
    guide_path <- tempfile(fileext = ".txt")
    on.exit(unlink(guide_path), add = TRUE)
    writeLines(build_mapping_guide_txt(map_values, raw, lang = "pt"), guide_path)

    # Parse + import
    payload <- parse_mapping_guide_txt(guide_path)
    n <- import_mapping_guide_to_aliases(payload, conn = conn, user_id = "test_user")
    testthat::expect_identical(as.integer(n), 2L)

    # Confirm the aliases exist (lookup with same column name, normalized)
    hit <- saira:::rostrum_lookup_alias(
        conn = conn,
        col_name = "my_lat",
        user_id = "test_user"
    )
    testthat::expect_true(is.data.frame(hit))
    testthat::expect_true(nrow(hit) >= 1L)
    testthat::expect_identical(as.character(hit$dwc_term[[1]]), "decimalLatitude")
})

# Regression for the bug found 2026-05-10: aliases imported with default
# user_id ("anonymous") were invisible to run_rostrum_engine() because
# the engine looked them up with user_id = "" (Sys.getenv("SAIRA_USER")
# unset). Fix: rostrum_apply_alias_overrides now promotes "" -> "anonymous",
# matching what rostrum_upsert_alias does at insert time.
testthat::test_that("imported aliases (no SAIRA_USER) are picked up by run_rostrum_engine with ALIAS badge", {
    skip_if_env_set <- nzchar(Sys.getenv("SAIRA_USER", unset = ""))
    if (skip_if_env_set) testthat::skip("SAIRA_USER is set; this test specifically covers the unset case")

    db_path <- tempfile(fileext = ".sqlite")
    conn <- rostrum_connect(path = db_path)
    on.exit({
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
        unlink(db_path)
    }, add = TRUE)

    payload <- list(
        meta = list(),
        pairs = data.frame(
            source_column = c("my_special_lat"),
            dwc_term      = c("decimalLatitude"),
            stringsAsFactors = FALSE
        )
    )
    # Default user_id (NULL -> "anonymous") — same as the UI flow.
    n <- import_mapping_guide_to_aliases(payload, conn = conn)
    testthat::expect_identical(as.integer(n), 1L)

    # Engine call mirrors mod_mapping line 1092 (context = list()).
    df <- data.frame(my_special_lat = c(-15.5, -16.2), stringsAsFactors = FALSE)
    res <- run_rostrum_engine(
        df = df,
        dwc_terms_df = data.frame(term = "decimalLatitude", stringsAsFactors = FALSE),
        options = rostrum_options(),
        context = list(),
        conn = conn,
        synonyms_tbl = empty_synonyms()
    )

    testthat::expect_identical(as.character(res$data$status[[1]]), "ALIAS")
    testthat::expect_identical(as.character(res$data$selected_col[[1]]), "my_special_lat")
})
