run_rostrum_stage1 <- saira:::run_rostrum_stage1
rostrum_stage2_compositions <- saira:::rostrum_stage2_compositions
rostrum_stage3_resolve <- saira:::rostrum_stage3_resolve

if (!identical(Sys.getenv("RUN_PERF"), "true")) {
    testthat::skip("Performance suite disabled by default. Use RUN_PERF=true to execute.")
}

build_perf_dataset <- function(rows_n = 20000L, cols_n = 50L) {
    set.seed(20260302L)
    out <- data.frame(
        scientificName = sample(
            c("Panthera onca", "Leopardus pardalis", "Tapirus terrestris"),
            rows_n,
            replace = TRUE
        ),
        decimalLatitude = as.character(runif(rows_n, -33, 5)),
        decimalLongitude = as.character(runif(rows_n, -74, -34)),
        year = sample(2000:2025, rows_n, replace = TRUE),
        month = sample(1:12, rows_n, replace = TRUE),
        day = sample(1:28, rows_n, replace = TRUE),
        stringsAsFactors = FALSE
    )

    extra_n <- max(0L, as.integer(cols_n) - ncol(out))
    if (extra_n > 0L) {
        for (i in seq_len(extra_n)) {
            out[[sprintf("noise_%02d", i)]] <- sample(LETTERS, rows_n, replace = TRUE)
        }
    }

    out
}

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

testthat::test_that("Performance regression: Stage 1 remains under 7.5s for 50x20k", {
    df <- build_perf_dataset(rows_n = 20000L, cols_n = 50L)
    dwc_terms <- load_dwc_terms_rds()

    elapsed <- unname(system.time({
        run_rostrum_stage1(
            df = df,
            dwc_terms_df = dwc_terms,
            synonyms_tbl = empty_synonyms(),
            options = rostrum_options(stage1_parallel = FALSE)
        )
    })[["elapsed"]])

    testthat::expect_lt(elapsed, 7.5)
})

testthat::test_that("Performance regression: Stage 2 stays under 2s for scientificName + eventDate", {
    df <- build_perf_dataset(rows_n = 20000L, cols_n = 50L)
    stage1_seed <- data.frame(
        term = c("scientificName", "genus", "specificEpithet", "eventDate", "year", "month", "day"),
        selected_col = c(NA_character_, "scientificName", "scientificName", NA_character_, "year", "month", "day"),
        name_score = c(0, 1, 1, 0, 1, 1, 1),
        value_score = c(0, 0.9, 0.9, 0, 0.9, 0.9, 0.9),
        penalty_score = c(0, 0, 0, 0, 0, 0, 0),
        veto_code = c("", "", "", "", "", "", ""),
        final_score = c(0, 1, 1, 0, 1, 1, 1),
        status = c("MANUAL", "AUTO", "AUTO", "MANUAL", "AUTO", "AUTO", "AUTO"),
        reason = c("no_confident_match", "exact_match", "exact_match", "no_confident_match", "exact_match", "exact_match", "exact_match"),
        applied = c(FALSE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE),
        alternatives_json = rep("[]", 7),
        explain_json = rep("{}", 7),
        stringsAsFactors = FALSE
    )

    elapsed <- unname(system.time({
        rostrum_stage2_compositions(
            stage1_data = stage1_seed,
            df = df,
            options = rostrum_options()
        )
    })[["elapsed"]])

    testthat::expect_lt(elapsed, 2)
})

testthat::test_that("Performance regression: Stage 3 stays under 0.5s for 50 terms", {
    terms <- sprintf("term_%02d", seq_len(50))
    stage2_data <- data.frame(
        term = terms,
        selected_col = rep("scientificName", 50),
        name_score = runif(50, 0.7, 1),
        value_score = runif(50, 0.7, 1),
        penalty_score = rep(0, 50),
        veto_code = rep("", 50),
        final_score = runif(50, 0.75, 1),
        status = rep("SUGERIDO", 50),
        reason = rep("token_overlap", 50),
        applied = rep(TRUE, 50),
        alternatives_json = rep(
            "[{\"column_name\":\"scientificName\",\"final_score\":0.9,\"name_score\":0.9,\"value_score\":0.9}]",
            50
        ),
        explain_json = rep("{}", 50),
        stringsAsFactors = FALSE
    )
    df <- build_perf_dataset(rows_n = 20000L, cols_n = 50L)

    elapsed <- unname(system.time({
        rostrum_stage3_resolve(
            stage2_data = stage2_data,
            df = df,
            options = rostrum_options()
        )
    })[["elapsed"]])

    testthat::expect_lt(elapsed, 0.5)
})

testthat::test_that("Performance regression: full pipeline stays under 8s", {
    df <- build_perf_dataset(rows_n = 20000L, cols_n = 50L)
    dwc_terms <- load_dwc_terms_rds()

    elapsed <- unname(system.time({
        run_rostrum_engine(
            df = df,
            dwc_terms_df = dwc_terms,
            options = rostrum_options(stage1_parallel = FALSE),
            synonyms_tbl = empty_synonyms()
        )
    })[["elapsed"]])

    testthat::expect_lt(elapsed, 8)
})

testthat::test_that("Performance regression: dynamicProperties JSON over 100k x 4 cols < 0.5s", {
    set.seed(20260508L)
    n <- 100000L
    df <- data.frame(
        protectarea = sample(c("yes", "no", "", NA), n, replace = TRUE),
        protect_area_type = sample(c("I", "II", "III", "IV", "V", "", NA), n, replace = TRUE),
        managing_authority = sample(c("Federal", "State", "Municipal", "", NA), n, replace = TRUE),
        habitat = sample(c("forest", "grassland", "wetland", "", NA), n, replace = TRUE),
        stringsAsFactors = FALSE
    )

    elapsed <- unname(system.time({
        out <- saira:::build_dynamic_properties_json(
            df,
            cols = c("protectarea", "protect_area_type", "managing_authority", "habitat")
        )
    })[["elapsed"]])

    testthat::expect_length(out, n)
    testthat::expect_lt(elapsed, 0.5)
})

# DwC-A bundle assembly. Targets:
# - 20k rows: under 3 seconds (interactive feel for the median dataset).
# - 100k rows: under 12 seconds (publishable cap for the largest dataset
#   class Saira is intended to handle).

build_dwca_perf_dataset <- function(rows_n) {
    set.seed(20260525L)
    data.frame(
        occurrenceID = paste0("urn:uuid:", ids::uuid(n = rows_n)),
        scientificName = sample(
            c("Panthera onca", "Leopardus pardalis", "Tapirus terrestris"),
            rows_n,
            replace = TRUE
        ),
        eventDate = format(
            as.Date("2000-01-01") + sample.int(9000, rows_n, replace = TRUE),
            "%Y-%m-%d"
        ),
        decimalLatitude  = runif(rows_n, -33, 5),
        decimalLongitude = runif(rows_n, -74, -34),
        basisOfRecord = "HumanObservation",
        countryCode = "BR",
        geodeticDatum = "EPSG:4326",
        institutionCode = "MZUSP",
        catalogNumber = sprintf("%07d", seq_len(rows_n)),
        stringsAsFactors = FALSE
    )
}

testthat::test_that("Performance regression: DwC-A bundle for 20k rows under 3s", {
    df <- build_dwca_perf_dataset(20000L)
    zip_path <- tempfile(fileext = ".zip")
    on.exit(unlink(zip_path), add = TRUE)

    elapsed <- unname(system.time({
        build_dwca_bundle(df, zip_path, metadata = list(title = "Perf 20k"))
    })[["elapsed"]])

    testthat::expect_lt(elapsed, 3)
    testthat::expect_true(file.exists(zip_path))
    files <- zip::zip_list(zip_path)$filename
    testthat::expect_true(all(c("occurrence.txt", "meta.xml", "eml.xml") %in% files))
})

testthat::test_that("Performance regression: DwC-A bundle for 100k rows under 12s", {
    df <- build_dwca_perf_dataset(100000L)
    zip_path <- tempfile(fileext = ".zip")
    on.exit(unlink(zip_path), add = TRUE)

    elapsed <- unname(system.time({
        build_dwca_bundle(df, zip_path, metadata = list(title = "Perf 100k"))
    })[["elapsed"]])

    testthat::expect_lt(elapsed, 12)
    testthat::expect_true(file.exists(zip_path))
})

# ADR-111: render hot paths. Each budget is set far above the vectorized cost
# and far below the per-row cost it replaced, so it fails if a per-row loop
# comes back but tolerates a slow CI runner.

testthat::test_that("Performance regression: tr() stays under 1.2s for 50k lookups", {
    elapsed <- unname(system.time({
        for (i in seq_len(50000L)) tr("nav_home", "pt")
    })[["elapsed"]])

    # Pre-ADR-111 (exists() scans + names(dict) per call): ~1.59s.
    testthat::expect_lt(elapsed, 1.2)
})

testthat::test_that("Performance regression: per-row label expansion stays vectorized", {
    set.seed(20260728L)
    rows_n <- 50000L

    tiers <- sample(
        c("extreme", "high", "medium", "low", "not_sensitive"), rows_n,
        replace = TRUE
    )
    elapsed_tiers <- unname(system.time({
        saira:::sensitive_reason_statement(tiers, "pt")
    })[["elapsed"]])
    # Pre-ADR-111 (tr() per masked row): ~1.44s.
    testthat::expect_lt(elapsed_tiers, 0.5)

    statuses <- sample(
        c("accepted", "synonym", "not_found", "ambiguous", "invalid"), rows_n,
        replace = TRUE
    )
    elapsed_status <- unname(system.time({
        saira:::normalize_status_vec(statuses)
    })[["elapsed"]])
    # Pre-ADR-111 (scalar vapply per row): ~0.65s.
    testthat::expect_lt(elapsed_status, 0.3)
})

# ADR-113: the validation run tick. stream_window() runs on every 60ms step of a
# taxonomic run, on the same single R thread doing the taxadb work, and the
# stream is largest exactly when the run is busiest.

testthat::test_that("Performance regression: stream_window truncates the index, not the frame", {
    set.seed(20260730L)
    rows_n <- 20000L
    df <- data.frame(
        query_name = paste0("name-", seq_len(rows_n)),
        display_order = sample(rows_n),
        status = sample(c("accepted", "synonym", "not_found"), rows_n, replace = TRUE),
        provider = sample(c("gbif", "florabr"), rows_n, replace = TRUE),
        rank = sample(c("species", "genus"), rows_n, replace = TRUE),
        matched = paste0("matched-", seq_len(rows_n)),
        authorship = paste0("auth-", seq_len(rows_n)),
        note = paste0("note-", seq_len(rows_n)),
        stringsAsFactors = FALSE
    )

    # A real for-loop over the call, NOT `force(expr)`: the latter evaluates the
    # promise once and then measures nothing, which once nearly caused a genuine
    # 3x win here to be dismissed as noise.
    elapsed <- unname(system.time({
        for (i in seq_len(200L)) saira:::stream_window(df, limit = 100L)
    })[["elapsed"]])

    # Pre-ADR-113 (order() then subset the WHOLE frame, then keep 100 rows):
    # ~1.02s. After truncating the index first: ~0.06s.
    testthat::expect_lt(elapsed, 0.35)
})
