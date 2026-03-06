# Title: CSS Bundle Builder
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.0
# Onda 5, Item 5.1 — Concatenates modular CSS files into custom.css
#
# When to run:
#   Run this script after editing ANY file in inst/app/www/css/*.css.
#   The app loads inst/app/www/custom.css (the bundle), not the individual files.
#   Forgetting to rebuild will cause the app to run with stale styles.
#
# Usage:
#   setwd(here::here()); source("data-raw/build_css.R")

css_dir <- file.path("inst", "app", "www", "css")
output  <- file.path("inst", "app", "www", "custom.css")

if (!dir.exists(css_dir)) {
    stop("[Saira] CSS source directory not found: ", css_dir)
}

css_files <- sort(list.files(css_dir, pattern = "\\.css$", full.names = TRUE))
if (length(css_files) == 0L) {
    stop("[Saira] No .css files found in: ", css_dir)
}

header <- "/* GENERATED FILE \u2014 do not edit. Run data-raw/build_css.R */"
lines  <- c(header, unlist(lapply(css_files, readLines, encoding = "UTF-8")))

writeLines(lines, output, useBytes = TRUE)
message(
    "[Saira] CSS bundle generated: ",
    length(css_files), " modules, ",
    length(lines), " lines -> ", output
)
