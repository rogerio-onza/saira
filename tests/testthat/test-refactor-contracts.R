# Composition and compatibility checks for the B-H boundaries.
publication_fixture <- function() data.frame(
    occurrenceID = c("a", "b"), scientificName = c("Felis onca", "Felis catus"),
    eventDate = c("2024-01-01", "2024-02-02"),
    decimalLatitude = c("-23.55052", "-23.5"),
    decimalLongitude = c("-46.63331", "-46.6"), country = c("", "Brazil"),
    basisOfRecord = "HumanObservation", license = "CC-BY 4.0", datasetName = "Field data",
    stringsAsFactors = FALSE
)

testthat::test_that("publication composes accepted name, point and protection without publishing real points", {
    df <- publication_fixture()
    reviews <- list(entries = data.frame(
        query_name = "Felis onca", review_type = "correct", original_name = "Felis onca",
        corrected_name = "Panthera onca", reason = "synonym", stringsAsFactors = FALSE
    ))
    point <- list(corrections = data.frame(
        occurrenceID = "a", decimalLatitude = "-23.65052", decimalLongitude = "-46.73331",
        from_decimalLatitude = df$decimalLatitude[1], from_decimalLongitude = df$decimalLongitude[1]
    ))
    marks <- data.frame(scientificName = "Felis onca", sensitive = TRUE, category = "VU")
    gen <- list(enabled = TRUE, levels = c("Panthera onca" = "high"),
                needs_justification = TRUE, justification = "Poaching risk", review_date = "2030-01-01")
    prep <- saira:::prepare_publication_records(df, reviews, point, sensitivity = marks,
                                               generalization = gen, lang = "en")
    testthat::expect_equal(prep$masked$scientificName[1], "Panthera onca")
    testthat::expect_equal(as.numeric(prep$real$decimalLatitude), -23.65052)
    testthat::expect_false(identical(prep$masked$decimalLatitude[1], prep$real$decimalLatitude[1]))
    testthat::expect_equal(prep$masked$decimalLatitude[2], df$decimalLatitude[2])
    public <- saira:::process_for_export(prep$masked)
    metadata <- saira:::publication_metadata(public, prep$real, gen, "en")
    testthat::expect_equal(metadata$title, "Field data")
    testthat::expect_equal(metadata$license, "CC-BY 4.0")
    testthat::expect_equal(metadata$sensitivity$n_masked, 1L)
    path <- tempfile(fileext = ".zip")
    withr::defer(unlink(path))
    saira::build_dwca_bundle(public, path, metadata)
    testthat::expect_setequal(zip::zip_list(path)$filename, c("occurrence.txt", "meta.xml", "eml.xml"))
    directory <- tempfile(); dir.create(directory)
    withr::defer(unlink(directory, recursive = TRUE))
    utils::unzip(path, exdir = directory)
    core <- readr::read_csv(file.path(directory, "occurrence.txt"), show_col_types = FALSE)
    testthat::expect_false(any(as.character(core$decimalLatitude) == prep$real$decimalLatitude))
    testthat::expect_match(paste(readLines(file.path(directory, "eml.xml")), collapse = ""), "Field data")
    summary <- saira:::build_export_summary(df, reviews, point, sensitivity_payload = marks,
                                           generalization_payload = gen)
    testthat::expect_false(summary$export_blocked)
    testthat::expect_equal(summary$generalization$scientificName, "Panthera onca")
})

testthat::test_that("source snapshots invalidate only affected coordinate and country decisions", {
    df <- publication_fixture()
    fills <- list(country = data.frame(occurrenceID = "a", country = "Brazil",
        from_decimalLatitude = df$decimalLatitude[1], from_decimalLongitude = df$decimalLongitude[1]))
    testthat::expect_equal(saira:::prepare_effective_records(df, country_payload = fills)$country[1], "Brazil")
    moved <- df[2:1, ]; moved$decimalLatitude[2] <- "10"
    out <- saira:::prepare_effective_records(moved, country_payload = fills)
    testthat::expect_equal(out$country[2], "")
    stale <- saira:::reconcile_country_fill(fills, moved)
    testthat::expect_equal(stale$stale, 1L)
    testthat::expect_equal(nrow(stale$country), 0L)
    legacy <- fills; legacy$country <- legacy$country[, c("occurrenceID", "country")]
    testthat::expect_equal(saira:::prepare_effective_records(moved, country_payload = legacy)$country[2], "Brazil")
    fixes <- list(corrections = data.frame(occurrenceID = "a", decimalLatitude = "5", decimalLongitude = "6",
        from_decimalLatitude = df$decimalLatitude[1], from_decimalLongitude = df$decimalLongitude[1]))
    stale <- saira:::drop_stale_coord_corrections(fixes, moved)
    testthat::expect_identical(saira:::drop_stale_coord_corrections(stale, moved)$stale, 1L)
})

testthat::test_that("publication policy evaluates accepted values and all unmapped columns", {
    df <- publication_fixture()
    raw <- data.frame(extra = c("=1+1", "ordinary text"))
    summary <- saira:::build_export_summary(df, raw_data = raw, map_values = list())
    assessment <- saira:::assess_publication(df, raw_data = raw, map_values = list())
    testthat::expect_true(summary$export_blocked)
    testthat::expect_identical(summary$export_blocked, assessment$export_blocked)
    testthat::expect_identical(summary$formula_cells_unmapped$count, 1L)
    testthat::expect_false(saira:::assess_publication(df)$export_blocked)
    testthat::expect_false("occurrenceID" %in% saira:::publication_required_terms())
})

testthat::test_that("named module results retain the legacy reactive adapter", {
    report <- shiny::reactive(1L); reviews <- shiny::reactive(list(entries = NULL))
    result <- saira:::new_module_result(report, reviews_r = reviews)
    named <- saira:::module_result_return(result, c(review_export_payload = "reviews_r"), "list")
    legacy <- saira:::module_result_return(result, c(review_export_payload = "reviews_r"), "legacy")
    testthat::expect_identical(named$reviews_r, reviews)
    testthat::expect_identical(attr(legacy, "review_export_payload"), reviews)
    testthat::expect_identical(shiny::isolate(legacy()), shiny::isolate(named$report_r()))
    testthat::expect_error(saira:::new_module_result(report, reviews_r = list()), "must be reactive")
})

testthat::test_that("mapping import commands apply selections and always release programmatic state", {
    writes <- list(); metas <- list(); active <- FALSE
    commands <- saira:::new_mapping_commands(
        write_selection = function(term, value) writes[[term]] <<- value,
        write_meta = function(term, value) metas[[term]] <<- value,
        add_terms = function(terms) NULL,
        begin_restore = function() active <<- TRUE,
        end_restore = function() active <<- FALSE,
        sync_selection = function(term, value, update_input) NULL
    )
    plan <- list(map_values = list(scientificName = "Taxon", eventDate = "Date"))
    commands$restore(plan)
    testthat::expect_identical(writes$scientificName, "Taxon")
    testthat::expect_identical(writes$eventDate, "Date")
    testthat::expect_false(active)
    commands <- saira:::new_mapping_commands(
        write_selection = function(...) stop("write failed"), write_meta = function(...) NULL,
        add_terms = function(...) NULL, begin_restore = function() active <<- TRUE,
        end_restore = function() active <<- FALSE, sync_selection = function(...) NULL)
    testthat::expect_error(commands$restore(plan), "write failed")
    testthat::expect_false(active)
})

testthat::test_that("names rounds can run with injected providers and no external effects", {
    input <- saira:::prepare_taxadb_inputs(c("Panthera onca", "Felis catus"))
    state <- saira:::init_taxadb_run_state(input, "gbif", batch_size = 1L)
    queries <- character(0)
    adapters <- list(poll = function() NULL, load = function(...) list(data = NULL, error = NULL),
        query = function(names, provider, type, data) {
            queries <<- c(queries, names)
            rows <- saira:::build_taxadb_placeholder(names, "accepted")
            list(results = rows, resolved = names, answered = names,
                 unanswered = character(0), error = NULL)
        })
    for (i in seq_len(20L)) {
        state <- saira:::next_taxadb_run_step(state, adapters)
        if (saira:::is_taxadb_run_done(state)) break
    }
    testthat::expect_identical(state$phase, "done")
    testthat::expect_setequal(queries, c("Panthera onca", "Felis catus"))
    testthat::expect_length(state$pending_queries, 0L)
    testthat::expect_equal(nrow(state$cascade_results), 2L)
})

testthat::test_that("script configuration preserves translated text and cannot close its script", {
    text <- "a quote '\" and </script><script>alert(1)</script>"
    script <- saira:::module_behavior_call("previewFixValueCell", list(auto = text))
    testthat::expect_false(grepl("</script>", script, fixed = TRUE))
    json <- sub("^window[.]sairaModuleBehavior[.]previewFixValueCell[(]", "", script)
    json <- substr(json, 1L, nchar(json) - 1L)
    testthat::expect_identical(jsonlite::fromJSON(json)$auto, text)
    deps <- htmltools::renderTags(saira::app_ui())$dependencies
    testthat::expect_equal(sum(vapply(deps, function(x) x$name == "saira-module-behavior", TRUE)), 1L)
})

testthat::test_that("the common fallback preserves scalar and vector semantics", {
    fallback <- get("%||%", envir = asNamespace("saira"))
    for (value in list(NULL, NA, NA_character_, "")) testthat::expect_identical(fallback(value, "fallback"), "fallback")
    for (value in list(character(0), c(NA_character_, ""), FALSE, 0, " ")) testthat::expect_identical(fallback(value, "fallback"), value)
})

testthat::test_that("standalone map exports carry their behavior assets", {
    directory <- tempfile(); dir.create(directory)
    withr::defer(unlink(directory, recursive = TRUE))
    widget <- saira:::leaflet_fill_world(leaflet::leaflet())
    htmlwidgets::saveWidget(widget, file.path(directory, "map.html"), selfcontained = FALSE)
    testthat::expect_true(any(basename(list.files(directory, recursive = TRUE)) == "module-utils-coords.js"))
})

testthat::test_that("table callbacks receive the widget and retain search, paging and resize behavior", {
    code <- saira:::module_behavior_call(
        "wikiTableFilters", list(searchId = "search", classId = "class", pageId = "page"), table_context = TRUE
    )
    testthat::expect_match(code, ", table)", fixed = TRUE)
    node <- Sys.which("node")
    testthat::skip_if(!nzchar(node), "node is needed for the JavaScript behavior check")
    result <- system2(node, c(shQuote(testthat::test_path("js", "module-behavior.cjs")),
                             shQuote(system.file("app", "www", package = "saira"))),
                      stdout = TRUE, stderr = TRUE)
    testthat::expect_null(attr(result, "status"), info = paste(result, collapse = "\n"))
})

for (case in list(
    c("a card patch keeps the Mapping filter on screen", "mapping-filter.cjs"),
    c("the upload observes only its own progress bars", "upload-dropzone.cjs")
)) {
    testthat::test_that(case[[1]], {
        node <- Sys.which("node")
        testthat::skip_if(!nzchar(node), "node is needed for the JavaScript behavior check")
        result <- system2(node, c(shQuote(testthat::test_path("js", case[[2]])),
                                 shQuote(system.file("app", "www", package = "saira"))),
                          stdout = TRUE, stderr = TRUE)
        testthat::expect_null(attr(result, "status"), info = paste(result, collapse = "\n"))
    })
}
