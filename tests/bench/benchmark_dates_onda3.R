# Title: Onda 3 benchmark for date parsing performance
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-14
# Version: 1.0

if (requireNamespace("saira", quietly = TRUE)) {
    parse_dates_to_iso <- saira:::parse_dates_to_iso
    fix_dates_to_iso <- saira:::fix_dates_to_iso
} else {
    source("R/utils_io.R")
    source("R/utils_export.R")
}

set.seed(20260214L)

n_rows <- 100000L
iterations <- 3L

base_dates <- seq.Date(as.Date("1990-01-01"), by = "day", length.out = 20000L)
date_pool <- c(
    format(base_dates, "%Y-%m-%d"),
    format(base_dates, "%d/%m/%Y"),
    format(base_dates, "%d-%m-%Y"),
    format(base_dates, "%d.%m.%Y"),
    format(base_dates, "%d/%m/%y"),
    rep("not-a-date", 20000L),
    rep("", 20000L),
    rep(NA_character_, 20000L)
)

date_vector <- sample(date_pool, size = n_rows, replace = TRUE)
date_df <- data.frame(
    eventDate = date_vector,
    dateIdentified = date_vector,
    modified = date_vector,
    stringsAsFactors = FALSE
)

measure_elapsed <- function(fn, iterations_n) {
    times <- numeric(iterations_n)
    for (i in seq_len(iterations_n)) {
        gc(verbose = FALSE)
        times[[i]] <- unname(system.time(fn())["elapsed"])
    }
    return(times)
}

summarize_times <- function(times) {
    c(
        min = min(times),
        median = stats::median(times),
        mean = mean(times),
        max = max(times)
    )
}

parse_times <- measure_elapsed(function() parse_dates_to_iso(date_vector), iterations)
fix_times <- measure_elapsed(function() fix_dates_to_iso(date_df), iterations)
parse_stats <- summarize_times(parse_times)
fix_stats <- summarize_times(fix_times)

baseline_parse_median <- 14.980
baseline_fix_median <- 38.050

cat(sprintf("Benchmark date: %s\n", format(Sys.Date(), "%Y-%m-%d")))
cat(sprintf("Rows: %d\n", n_rows))
cat(sprintf("Iterations: %d\n\n", iterations))

cat("parse_dates_to_iso() times (s): ", paste(sprintf("%.3f", parse_times), collapse = ", "), "\n", sep = "")
cat(
    sprintf(
        "parse_dates_to_iso() stats: min=%.3f, median=%.3f, mean=%.3f, max=%.3f\n",
        parse_stats[["min"]],
        parse_stats[["median"]],
        parse_stats[["mean"]],
        parse_stats[["max"]]
    )
)
cat(sprintf("parse_dates_to_iso() speedup vs baseline median (14.980s): %.2fx\n\n", baseline_parse_median / parse_stats[["median"]]))

cat("fix_dates_to_iso() times (s): ", paste(sprintf("%.3f", fix_times), collapse = ", "), "\n", sep = "")
cat(
    sprintf(
        "fix_dates_to_iso() stats: min=%.3f, median=%.3f, mean=%.3f, max=%.3f\n",
        fix_stats[["min"]],
        fix_stats[["median"]],
        fix_stats[["mean"]],
        fix_stats[["max"]]
    )
)
cat(sprintf("fix_dates_to_iso() speedup vs baseline median (38.050s): %.2fx\n", baseline_fix_median / fix_stats[["median"]]))
