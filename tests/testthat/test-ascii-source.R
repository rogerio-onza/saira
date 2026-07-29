# Title: Portable-package guardrail: no non-ASCII in R code
# Date: 2026-07-29
#
# `R CMD check` warns when R/*.R carries raw non-ASCII characters in *code*
# (string literals). Comments are explicitly tolerated ("except perhaps in
# comments"), so a plain tools::showNonASCIIfile() sweep would fail on the many
# legitimate accented pt-BR comments in the package. This checks what the
# check actually inspects: parsed tokens, minus comments.

non_ascii_code_lines <- function(path) {
    parsed <- parse(path, keep.source = TRUE)
    parse_data <- utils::getParseData(parsed)
    code <- parse_data[parse_data$terminal & parse_data$token != "COMMENT", ]
    hits <- grepl("[^\x01-\x7f]", code$text, perl = TRUE)
    if (!any(hits)) {
        return(character(0))
    }
    sprintf("%s:%d: %s", basename(path), code$line1[hits], code$text[hits])
}

testthat::test_that("R sources use \\uxxxx escapes instead of raw non-ASCII in code", {
    r_dir <- file.path(pkg_root, "R")
    testthat::skip_if_not(
        dir.exists(r_dir),
        "R/ sources unavailable (running against an installed package)"
    )

    r_files <- list.files(r_dir, pattern = "\\.R$", full.names = TRUE)
    testthat::expect_gt(length(r_files), 0L)

    offenders <- unlist(lapply(r_files, non_ascii_code_lines), use.names = FALSE)

    testthat::expect_length(offenders, 0L)
    if (length(offenders) > 0L) {
        testthat::fail(paste0(
            "Non-ASCII in R code (use \\uxxxx escapes):\n  ",
            paste(offenders, collapse = "\n  ")
        ))
    }
})
