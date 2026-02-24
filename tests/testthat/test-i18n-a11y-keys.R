# Title: i18n tests for new a11y/ui keys
# Author: Codex
# Date: 2026-02-20

testthat::test_that("a11y/ui keys for this cycle exist in pt/en", {
    dict <- get("i18n_dict", envir = asNamespace("finch"))

    required_keys <- c(
        "a11y_lang_switch_label",
        "a11y_upload_file_label",
        "upload_dropzone_cta",
        "a11y_help_search_label",
        "a11y_help_bug_link",
        "a11y_help_external_link",
        "a11y_wiki_search_label",
        "a11y_wiki_class_filter_label",
        "a11y_wiki_page_length_label",
        "a11y_bor_target_label",
        "mapping_sidebar_actions",
        "mapping_sidebar_filters"
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
            info = paste("Missing pt translation for key:", key)
        )
        testthat::expect_true(
            !is.null(dict[[key]][["en"]]) && nzchar(dict[[key]][["en"]]),
            info = paste("Missing en translation for key:", key)
        )
    }
})

testthat::test_that("a11y/ui keys resolve with tr in pt/en", {
    tr_fn <- getFromNamespace("tr", "finch")

    keys <- c(
        "a11y_lang_switch_label",
        "a11y_upload_file_label",
        "upload_dropzone_cta",
        "a11y_help_search_label",
        "a11y_help_bug_link",
        "a11y_help_external_link",
        "a11y_wiki_search_label",
        "a11y_wiki_class_filter_label",
        "a11y_wiki_page_length_label",
        "a11y_bor_target_label",
        "mapping_sidebar_actions",
        "mapping_sidebar_filters"
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
