# Title: Tests for the COL XR name matching
# Author: Rogerio Nunes Oliveira
#
# The fixtures are real GBIF v2 match responses (checklistKey of COL XR,
# strict = true), recorded on 2026-10-22. The tests do not use the network.

read_colxr_fixture <- function(name) {
    jsonlite::read_json(testthat::test_path("fixtures", "colxr", paste0(gsub(" ", "_", name), ".json")))
}

testthat::test_that("parse_colxr_matches maps accepted, synonym, homonym and missing names", {
    names <- c("Panthera onca", "Cebus apella", "Oenanthe", "Pantera onca", "Rhea americana americana")
    out <- saira:::parse_colxr_matches(lapply(names, read_colxr_fixture), names)

    testthat::expect_identical(out$query_name, names)
    testthat::expect_identical(
        out$validation_status,
        c("accepted", "synonym", "ambiguous", "not_found", "accepted")
    )
    testthat::expect_identical(out$provider, rep("gbif", 5L))

    onca <- out[1L, ]
    testthat::expect_identical(onca$taxonID, "4CGXQ")
    testthat::expect_identical(onca$taxonRank, "species")
    testthat::expect_identical(onca$family, "Felidae")
    testthat::expect_identical(onca$iucnRedListCategory, "NT")

    cebus <- out[2L, ]
    testthat::expect_identical(cebus$scientificName, "Cebus apella")
    testthat::expect_identical(cebus$acceptedNameUsage, "Sapajus apella")
    testthat::expect_identical(cebus$acceptedNameUsageID, "6XJVY")

    # An ambiguous or missing name keeps only the query name.
    testthat::expect_identical(out$scientificName[3:4], c("Oenanthe", "Pantera onca"))
    testthat::expect_true(all(is.na(out$taxonID[3:4])))
    testthat::expect_true(all(is.na(out$family[3:4])))

    testthat::expect_identical(out$taxonRank[[5L]], "subspecies")
    testthat::expect_identical(out$infraspecificEpithet[[5L]], "americana")
})

testthat::test_that("colxr_match_names queries each name once per session", {
    saira:::colxr_match_cache$reset()
    withr::defer(saira:::colxr_match_cache$reset())
    sent <- character(0)
    testthat::local_mocked_bindings(
        gbif_api_get_many = function(requests) {
            names <- vapply(requests, function(r) r$query$scientificName, character(1))
            sent <<- c(sent, names)
            lapply(names, read_colxr_fixture)
        },
        .package = "saira"
    )

    first <- saira:::colxr_match_names(c("Panthera onca", "Pantera onca", NA, ""))
    second <- saira:::colxr_match_names(c("Pantera onca", "Panthera onca"))

    testthat::expect_identical(sent, c("Panthera onca", "Pantera onca"))
    testthat::expect_identical(first$query_name, c("Panthera onca", "Pantera onca"))
    testthat::expect_identical(second$query_name, c("Pantera onca", "Panthera onca"))
    testthat::expect_length(attr(second, "unanswered"), 0L)
})

testthat::test_that("colxr_match_names reports the names GBIF did not answer and retries them", {
    saira:::colxr_match_cache$reset()
    withr::defer(saira:::colxr_match_cache$reset())
    online <- FALSE
    testthat::local_mocked_bindings(
        gbif_api_get_many = function(requests) {
            names <- vapply(requests, function(r) r$query$scientificName, character(1))
            lapply(names, function(n) {
                if (online || identical(n, "Panthera onca")) read_colxr_fixture(n) else NULL
            })
        },
        .package = "saira"
    )

    out <- saira:::colxr_match_names(c("Panthera onca", "Cebus apella"))
    testthat::expect_identical(out$query_name, "Panthera onca")
    testthat::expect_identical(attr(out, "unanswered"), "Cebus apella")

    online <- TRUE
    out <- saira:::colxr_match_names(c("Panthera onca", "Cebus apella"))
    testthat::expect_identical(out$validation_status, c("accepted", "synonym"))
    testthat::expect_length(attr(out, "unanswered"), 0L)
})

testthat::test_that("colxr_match_request asks COL XR for strict matches", {
    req <- saira:::colxr_match_request("Panthera onca")
    testthat::expect_identical(req$segments, c("species", "match"))
    testthat::expect_identical(req$query$checklistKey, "7ddf754f-d193-4cc9-b351-99906754a03b")
    testthat::expect_identical(req$query$strict, "true")
})
