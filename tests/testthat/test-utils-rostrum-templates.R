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
