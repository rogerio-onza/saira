# Tests for the shared mapping loading modal (auto-map and template import).

testthat::test_that("both phrase sets resolve in PT and EN", {
    all_specs <- c(mapping_loading_phrase_specs(), mapping_import_phrase_specs())

    for (spec in all_specs) {
        for (lang in c("pt", "en")) {
            # tr() warns and returns "[key]" for a key that is not in i18n.json,
            # which is the whole failure mode of adding phrases by hand.
            text <- testthat::expect_no_warning(tr(spec$key, lang))
            testthat::expect_false(startsWith(text, "["))
            testthat::expect_true(nzchar(text))
        }
        testthat::expect_true(nzchar(spec$icon))
    }
})

testthat::test_that("the import modal has its own wording, not the automap's", {
    import_keys <- vapply(
        mapping_import_phrase_specs(), function(x) x$key, character(1)
    )
    automap_keys <- vapply(
        mapping_loading_phrase_specs(), function(x) x$key, character(1)
    )
    testthat::expect_length(intersect(import_keys, automap_keys), 0L)

    for (lang in c("pt", "en")) {
        for (key in c("loading_import_title", "loading_import_status")) {
            testthat::expect_false(startsWith(tr(key, lang), "["))
        }
        # The status line is fed through sprintf() with the progress number.
        testthat::expect_match(tr("loading_import_status", lang), "%s", fixed = TRUE)
    }
})

testthat::test_that("show_mapping_loading_modal still defaults to the automap wording", {
    # The function grew parameters so the import could reuse it; the auto-map
    # call site passes none of them and must keep the modal it had.
    defaults <- formals(show_mapping_loading_modal)
    testthat::expect_identical(defaults$title_key, "loading_automap_title")
    testthat::expect_identical(defaults$status_key, "loading_automap_status")
    testthat::expect_identical(
        eval(defaults$specs), mapping_loading_phrase_specs()
    )
})
