# Title: i18n tests for homepage welcome keys
# Author: Codex
# Date: 2026-02-23

testthat::test_that("homepage welcome keys exist in pt/en", {
    dict <- get("i18n_dict", envir = asNamespace("finch"))

    required_keys <- c(
        "welcome_eyebrow",
        "welcome_title_prefix"
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

testthat::test_that("homepage welcome keys resolve with tr in pt/en", {
    tr_fn <- getFromNamespace("tr", "finch")
    keys <- c("welcome_eyebrow", "welcome_title_prefix")

    for (key in keys) {
        pt_value <- tr_fn(key, "pt")
        en_value <- tr_fn(key, "en")

        testthat::expect_type(pt_value, "character")
        testthat::expect_true(nzchar(pt_value), info = paste("Empty pt translation for", key))
        testthat::expect_type(en_value, "character")
        testthat::expect_true(nzchar(en_value), info = paste("Empty en translation for", key))
    }
})
