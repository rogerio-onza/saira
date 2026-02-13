# Title: Tests for i18n dictionary and translations
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-13
# Version: 1.0

testthat::test_that("onda 2 i18n keys exist with pt/en translations", {
    dict <- get("i18n_dict", envir = asNamespace("finch"))

    required_keys <- c(
        "nav_home",
        "nav_validate",
        "lang_es",
        "mapping_dataset_placeholder",
        "mapping_separator_placeholder",
        "preview_datatable_search",
        "preview_datatable_length_menu",
        "preview_datatable_info",
        "validate_names_missing_scientific_name",
        "validate_names_all_valid",
        "validate_coords_missing_columns",
        "validate_coords_all_valid",
        "wiki_search_placeholder",
        "wiki_datatable_search",
        "wiki_class_all",
        "wiki_term"
    )

    missing_keys <- setdiff(required_keys, names(dict))
    testthat::expect_equal(
        length(missing_keys),
        0L,
        info = paste("Missing keys:", paste(missing_keys, collapse = ", "))
    )

    for (key in required_keys) {
        testthat::expect_true(
            !is.null(dict[[key]][["pt"]]) && nzchar(dict[[key]][["pt"]]),
            info = paste("Missing pt value for key:", key)
        )
        testthat::expect_true(
            !is.null(dict[[key]][["en"]]) && nzchar(dict[[key]][["en"]]),
            info = paste("Missing en value for key:", key)
        )
    }
})

testthat::test_that("tr resolves onda 2 keys in pt and en", {
    tr_fn <- getFromNamespace("tr", "finch")

    keys <- c(
        "nav_home",
        "nav_validate",
        "mapping_dataset_placeholder",
        "preview_datatable_length_menu",
        "validate_names_all_valid",
        "validate_coords_all_valid",
        "wiki_class_all",
        "wiki_term"
    )

    for (key in keys) {
        pt_value <- tr_fn(key, "pt")
        en_value <- tr_fn(key, "en")

        testthat::expect_type(pt_value, "character")
        testthat::expect_true(nzchar(pt_value), info = paste("Empty pt translation for", key))
        testthat::expect_type(en_value, "character")
        testthat::expect_true(nzchar(en_value), info = paste("Empty en translation for", key))
    }
})

testthat::test_that("pt-en alternation yields distinct navigation labels", {
    tr_fn <- getFromNamespace("tr", "finch")

    testthat::expect_false(identical(tr_fn("nav_home", "pt"), tr_fn("nav_home", "en")))
    testthat::expect_false(identical(tr_fn("nav_validate", "pt"), tr_fn("nav_validate", "en")))
    testthat::expect_false(identical(tr_fn("validate_names_all_valid", "pt"), tr_fn("validate_names_all_valid", "en")))
    testthat::expect_false(identical(tr_fn("validate_coords_all_valid", "pt"), tr_fn("validate_coords_all_valid", "en")))
})
