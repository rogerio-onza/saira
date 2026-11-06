# Title: Every R file is in the Collate field
# Author: Rogerio Nunes Oliveira
# Date: 2026-10-05
#
# R CMD INSTALL stops when a file in R/ is not in Collate. load_all() only
# gives a message, so the gap shows only at install time.

testthat::test_that("Collate lists every file in R/", {
    r_dir <- testthat::test_path("..", "..", "R")
    desc_file <- testthat::test_path("..", "..", "DESCRIPTION")
    testthat::skip_if_not(dir.exists(r_dir) && file.exists(desc_file), "needs a source checkout")

    collate <- strsplit(read.dcf(desc_file, fields = "Collate")[1, 1], "\\s+")[[1]]
    collate <- gsub("'", "", collate[nzchar(collate)], fixed = TRUE)

    testthat::expect_setequal(collate, list.files(r_dir, pattern = "\\.R$"))
})
