# Stage 1 benchmark for Rostrum baseline tracking (Onda 0)

if (!requireNamespace("devtools", quietly = TRUE)) {
    stop("Package 'devtools' is required to run this benchmark script.")
}

devtools::load_all(".", quiet = TRUE)

build_benchmark_dataset <- function(rows_n = 20000L, cols_n = 50L) {
    set.seed(123)

    base_df <- data.frame(
        decimalLatitude = runif(rows_n, min = -33, max = 5),
        decimalLongitude = runif(rows_n, min = -74, max = -34),
        eventDate = format(
            as.Date("2010-01-01") + sample.int(3650L, rows_n, replace = TRUE) - 1L,
            "%Y-%m-%d"
        ),
        scientificName = sample(
            c("Panthera onca", "Leopardus pardalis", "Tapirus terrestris"),
            rows_n,
            replace = TRUE
        ),
        individualCount = sample(0:12, rows_n, replace = TRUE),
        stringsAsFactors = FALSE
    )

    if (cols_n <= ncol(base_df)) {
        return(base_df[, seq_len(cols_n), drop = FALSE])
    }

    extra_n <- cols_n - ncol(base_df)
    for (i in seq_len(extra_n)) {
        base_df[[sprintf("noise_%02d", i)]] <- sample(LETTERS, rows_n, replace = TRUE)
    }

    base_df
}

run_stage1_benchmark <- function(rows_n = 20000L, cols_n = 50L) {
    df <- build_benchmark_dataset(rows_n = rows_n, cols_n = cols_n)
    dwc_terms_df <- load_dwc_terms_rds()
    synonyms_tbl <- load_dwc_synonyms_v1()
    opts <- rostrum_options(
        stage1_parallel = FALSE,
        stage1_name_prune_threshold = 0.45
    )

    elapsed <- system.time({
        run_rostrum_stage1(
            df = df,
            dwc_terms_df = dwc_terms_df,
            synonyms_tbl = synonyms_tbl,
            options = opts
        )
    })[["elapsed"]]

    list(
        benchmark = "rostrum_stage1_baseline",
        rows_n = rows_n,
        cols_n = cols_n,
        elapsed_seconds = as.numeric(elapsed),
        measured_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    )
}

result <- run_stage1_benchmark()
print(result)

if (identical(Sys.getenv("SAIRA_WRITE_BENCH_BASELINE"), "true")) {
    writeRDS(result, file.path("tests", "bench", "baseline_rostrum_stage1.rds"))
    message("Baseline saved to tests/bench/baseline_rostrum_stage1.rds")
}
