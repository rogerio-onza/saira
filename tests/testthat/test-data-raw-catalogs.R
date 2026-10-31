# Title: Tests for the DwC catalog build pipeline (SP-05)

catalog_build_env <- function() {
    path <- testthat::test_path("..", "..", "data-raw", "build_dwc_catalogs.R")
    testthat::skip_if_not(file.exists(path), "data-raw is not in the installed package")
    env <- new.env()
    sys.source(path, envir = env)
    env
}

# A frozen TDWG input made from the shipped catalog, so the test needs no
# download. Each class goes back to one of its organized_in URIs.
frozen_tdwg_csv <- function(env, full) {
    uri_of <- vapply(split(names(env$class_map), unlist(env$class_map)), `[[`, "", 1L)
    uri_of[["Record-level"]] <- ""
    path <- tempfile(fileext = ".csv")
    utils::write.csv(data.frame(
        term_localName = full$term,
        status = "recommended",
        rdf_type = "http://www.w3.org/1999/02/22-rdf-syntax-ns#Property",
        organized_in = unname(uri_of[full$class]),
        definition = full$definition_en,
        examples = full$examples,
        stringsAsFactors = FALSE
    ), path, row.names = FALSE, fileEncoding = "UTF-8")
    path
}

testthat::test_that("the catalogs rebuild from the sources alone, the same each time", {
    env <- catalog_build_env()
    shipped_base <- readRDS(system.file("extdata", "dwc_terms.rds", package = "saira"))
    shipped_full <- readRDS(system.file("extdata", "dwc_full_catalog.rds", package = "saira"))
    tdwg <- env$read_tdwg_terms(frozen_tdwg_csv(env, shipped_full))
    sources <- testthat::test_path("..", "..", "data-raw")

    out_dir <- withr::local_tempdir()
    env$publish_dwc_catalogs(env$build_dwc_catalogs(tdwg, sources), out_dir)
    first <- tools::md5sum(file.path(out_dir, c("dwc_terms.rds", "dwc_full_catalog.rds")))
    testthat::expect_identical(readRDS(file.path(out_dir, "dwc_terms.rds")), shipped_base)
    testthat::expect_identical(readRDS(file.path(out_dir, "dwc_full_catalog.rds")), shipped_full)
    testthat::expect_length(names(shipped_full), 11L)

    env$publish_dwc_catalogs(env$build_dwc_catalogs(tdwg, sources), out_dir)
    testthat::expect_identical(
        unname(tools::md5sum(file.path(out_dir, c("dwc_terms.rds", "dwc_full_catalog.rds")))),
        unname(first)
    )
    testthat::expect_identical(list.files(out_dir), c("dwc_full_catalog.rds", "dwc_terms.rds"))
})

testthat::test_that("a failed build step leaves the previous catalogs as they were", {
    env <- catalog_build_env()
    shipped_full <- readRDS(system.file("extdata", "dwc_full_catalog.rds", package = "saira"))
    sources <- testthat::test_path("..", "..", "data-raw")
    out_dir <- withr::local_tempdir()
    files <- file.path(out_dir, c("dwc_terms.rds", "dwc_full_catalog.rds"))
    for (f in files) writeLines("previous", f)

    no_base_term <- shipped_full[shipped_full$term != "eventDate", , drop = FALSE]
    tdwg <- env$read_tdwg_terms(frozen_tdwg_csv(env, no_base_term))
    testthat::expect_error(env$build_dwc_catalogs(tdwg, sources), "eventDate")

    cats <- env$build_dwc_catalogs(env$read_tdwg_terms(frozen_tdwg_csv(env, shipped_full)), sources)
    cats$full$definition_es[cats$full$term == "habitat"] <- ""
    testthat::expect_error(env$publish_dwc_catalogs(cats, out_dir))
    testthat::expect_identical(readLines(files[[1]]), "previous")
    testthat::expect_identical(readLines(files[[2]]), "previous")
    testthat::expect_identical(sort(list.files(out_dir)), sort(basename(files)))
})

testthat::test_that("a replacement that fails halfway puts both previous catalogs back", {
    env <- catalog_build_env()
    shipped_full <- readRDS(system.file("extdata", "dwc_full_catalog.rds", package = "saira"))
    sources <- testthat::test_path("..", "..", "data-raw")
    cats <- env$build_dwc_catalogs(env$read_tdwg_terms(frozen_tdwg_csv(env, shipped_full)), sources)
    out_dir <- withr::local_tempdir()
    files <- file.path(out_dir, c("dwc_terms.rds", "dwc_full_catalog.rds"))
    for (f in files) writeLines("previous", f)

    # The first catalog goes in, the second one fails.
    fail_second <- function(from, to) {
        if (identical(basename(to), "dwc_full_catalog.rds") && !grepl("previous", from, fixed = TRUE) &&
            !grepl("previous", to, fixed = TRUE)) {
            return(FALSE)
        }
        file.rename(from, to)
    }
    testthat::expect_error(env$publish_dwc_catalogs(cats, out_dir, rename = fail_second), "previous ones are back")
    testthat::expect_identical(readLines(files[[1]]), "previous")
    testthat::expect_identical(readLines(files[[2]]), "previous")
    testthat::expect_identical(sort(list.files(out_dir)), sort(basename(files)))
})
