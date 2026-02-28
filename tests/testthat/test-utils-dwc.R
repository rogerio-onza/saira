# Title: Tests for DwC term cache utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-14
# Version: 1.0

reset_terms_cache <- function() {
    getFromNamespace("reset_dwc_terms_cache", "saira")()
}

terms_cache_state <- function() {
    getFromNamespace("dwc_terms_cache_state", "saira")()
}

testthat::test_that("validate_coords handles decimal comma bounds and returns issue types", {
    out <- validate_coords(
        lat = c("-23,55", "91", NA_character_, "10"),
        lon = c("-46,63", "-46,63", "-46,63", "181")
    )

    testthat::expect_s3_class(out, "data.frame")
    testthat::expect_equal(out$decimalLatitude[1], -23.55)
    testthat::expect_equal(out$decimalLongitude[1], -46.63)
    testthat::expect_identical(out$issue_type, c("ok", "swapped", "missing", "lon_range"))
    testthat::expect_identical(out$valid, c(TRUE, TRUE, FALSE, FALSE))
    testthat::expect_identical(out$error_key[2], "validate_coords_badge_swapped")
    testthat::expect_identical(out$error_key[3], "validate_coords_badge_missing")
    testthat::expect_identical(out$error_key[4], "validate_coords_badge_lon_range")
})

testthat::test_that("validate_occurrence_id enforces uniqueness and non-empty values", {
    ids <- c("id-1", "id-1", "id-2", NA_character_, "", "id-2", "id-3")
    out <- validate_occurrence_id(ids)

    testthat::expect_identical(out, c(TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, TRUE))
})

testthat::test_that("get_dwc_terms_list supports pt and falls back to english for unknown language", {
    reset_terms_cache()
    on.exit(reset_terms_cache(), add = TRUE)

    terms <- get_dwc_terms()
    en_list <- get_dwc_terms_list("en")
    pt_list <- get_dwc_terms_list("pt")
    unknown_lang_list <- get_dwc_terms_list("es")

    testthat::expect_identical(sort(names(en_list)), sort(as.character(terms$term)))
    testthat::expect_identical(sort(names(pt_list)), sort(as.character(terms$term)))
    testthat::expect_identical(sort(names(unknown_lang_list)), sort(as.character(terms$term)))

    sample_term <- names(en_list)[1]
    sample_entry <- en_list[[sample_term]]
    testthat::expect_true(all(c("term", "category", "desc", "sep", "required") %in% names(sample_entry)))
    testthat::expect_identical(sample_entry$sep, "")
    testthat::expect_type(sample_entry$required, "logical")

    if ("definition_en" %in% names(terms)) {
        idx <- which(!is.na(terms$definition_en) & nzchar(as.character(terms$definition_en)))[1]
        if (!is.na(idx)) {
            key <- as.character(terms$term[idx])
            testthat::expect_identical(unknown_lang_list[[key]]$desc, en_list[[key]]$desc)
        }
    }

    if ("definition_pt" %in% names(terms)) {
        idx <- which(!is.na(terms$definition_pt) & nzchar(as.character(terms$definition_pt)))[1]
        if (!is.na(idx)) {
            key <- as.character(terms$term[idx])
            testthat::expect_identical(
                pt_list[[key]]$desc,
                as.character(terms$definition_pt[idx])
            )
        }
    }
})

testthat::test_that("load_dwc_terms_rds caches first read and reuses on second call", {
    reset_terms_cache()
    on.exit(reset_terms_cache(), add = TRUE)

    first <- load_dwc_terms_rds()
    state_after_first <- terms_cache_state()
    second <- load_dwc_terms_rds()
    state_after_second <- terms_cache_state()

    testthat::expect_true(is.data.frame(first))
    testthat::expect_true(state_after_first$has_value)
    testthat::expect_identical(state_after_first$load_count, 1L)
    testthat::expect_identical(state_after_second$load_count, 1L)
    testthat::expect_identical(first, second)
})

testthat::test_that("load_dwc_terms_rds force reload invalidates cache explicitly", {
    reset_terms_cache()
    on.exit(reset_terms_cache(), add = TRUE)

    first <- load_dwc_terms_rds()
    state_after_first <- terms_cache_state()
    forced <- load_dwc_terms_rds(force = TRUE)
    state_after_force <- terms_cache_state()

    testthat::expect_identical(state_after_first$load_count, 1L)
    testthat::expect_identical(state_after_force$load_count, 2L)
    testthat::expect_identical(first, forced)
})

testthat::test_that("dwc term consumers share cache and keep semantic consistency", {
    reset_terms_cache()
    on.exit(reset_terms_cache(), add = TRUE)

    all_terms <- get_dwc_terms()
    required_terms <- get_required_dwc_terms()
    terms_list <- get_dwc_terms_list("en")
    state <- terms_cache_state()

    testthat::expect_identical(state$load_count, 1L)
    testthat::expect_true(all(required_terms$required))
    testthat::expect_true(all(required_terms$term %in% all_terms$term))
    testthat::expect_identical(sort(names(terms_list)), sort(as.character(all_terms$term)))
})

testthat::test_that("load_dwc_terms_rds validates force flag", {
    reset_terms_cache()
    on.exit(reset_terms_cache(), add = TRUE)

    testthat::expect_error(load_dwc_terms_rds(force = NA), "force must be a single TRUE or FALSE value")
    testthat::expect_error(load_dwc_terms_rds(force = c(TRUE, FALSE)), "force must be a single TRUE or FALSE value")
    testthat::expect_error(load_dwc_terms_rds(force = "TRUE"), "force must be a single TRUE or FALSE value")
})

testthat::test_that("basisOfRecord vocabulary is complete and ordered", {
    get_vocab <- getFromNamespace("get_basis_of_record_vocab", "saira")
    get_terms <- getFromNamespace("get_basis_of_record_terms", "saira")
    is_valid <- getFromNamespace("is_valid_basis_of_record_term", "saira")

    expected_terms <- c(
        "PreservedSpecimen",
        "FossilSpecimen",
        "LivingSpecimen",
        "HumanObservation",
        "MachineObservation",
        "MaterialSample",
        "MaterialCitation",
        "Occurrence"
    )

    vocab_en <- get_vocab("en")
    vocab_pt <- get_vocab("pt")
    terms <- get_terms()

    testthat::expect_identical(terms, expected_terms)
    testthat::expect_identical(
        vapply(vocab_en, function(x) x$term, FUN.VALUE = character(1)),
        expected_terms
    )
    testthat::expect_identical(
        vapply(vocab_pt, function(x) x$term, FUN.VALUE = character(1)),
        expected_terms
    )

    for (term in expected_terms) {
        testthat::expect_true(is_valid(term))
    }

    testthat::expect_false(is_valid("UnknownValue"))
    testthat::expect_false(is_valid(""))
})

testthat::test_that("basisOfRecord choices include skip option and descriptions", {
    get_choices <- getFromNamespace("get_basis_of_record_term_choices", "saira")

    pt_choices <- get_choices(lang = "pt", include_skip = TRUE, with_description = TRUE, skip_label = "-- Não mapear --")
    en_choices <- get_choices(lang = "en", include_skip = TRUE, with_description = TRUE, skip_label = "-- Skip --")

    testthat::expect_true("-- Não mapear --" %in% names(pt_choices))
    testthat::expect_true("-- Skip --" %in% names(en_choices))
    testthat::expect_identical(unname(pt_choices[["-- Não mapear --"]]), "")
    testthat::expect_identical(unname(en_choices[["-- Skip --"]]), "")

    testthat::expect_true(any(grepl("HumanObservation", names(en_choices), fixed = TRUE)))
    pt_choice_names_ascii <- iconv(names(pt_choices), from = "", to = "ASCII//TRANSLIT")
    testthat::expect_true(any(grepl("Observacao", pt_choice_names_ascii, fixed = TRUE)))
})
