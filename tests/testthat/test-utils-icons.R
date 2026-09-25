# Title: Tests for the Phosphor icon helpers

phosphor_classes <- function(weight = "regular") {
    # system.file() also resolves under R CMD check, where the tests run
    # against the installed package and inst/ is not next to them.
    css_path <- system.file("app", "www", "vendor", "phosphor", weight, "style.css", package = "saira")
    prefix <- if (identical(weight, "light")) "ph-light" else "ph"
    css <- readLines(css_path, warn = FALSE)
    m <- regmatches(css, regexpr(sprintf("^\\.%s\\.ph-[a-z0-9-]+(?=:before)", prefix), css, perl = TRUE))
    sub(sprintf("^\\.%s\\.ph-", prefix), "", m)
}

testthat::test_that("every translated icon name exists in the vendored Phosphor font", {
    available <- phosphor_classes("regular")
    missing <- setdiff(unname(saira:::ph_icon_names), available)
    testthat::expect_length(missing, 0L)
})

testthat::test_that("every literal icon name in the R sources resolves to a Phosphor icon", {
    r_dir <- testthat::test_path("..", "..", "R")
    testthat::skip_if_not(
        dir.exists(r_dir),
        "R/ sources unavailable (running against an installed package)"
    )
    src <- unlist(lapply(list.files(r_dir, pattern = "\\.R$", full.names = TRUE), readLines, warn = FALSE))
    literal <- unlist(regmatches(src, gregexpr("ph_icon(_name)?\\(\"[a-z0-9-]+\"", src)))
    literal <- sub("^ph_icon(_name)?\\(\"", "", sub("\"$", "", literal))
    data_names <- unlist(regmatches(src, gregexpr("\\bicon = \"[a-z0-9-]+\"", src)))
    data_names <- sub("^icon = \"", "", sub("\"$", "", data_names))
    used <- unique(saira:::ph_icon_name(c(literal, data_names)))
    missing <- setdiff(used, phosphor_classes("regular"))
    testthat::expect_length(missing, 0L)
})

testthat::test_that("ph_icon builds a hidden Phosphor tag with the weight class", {
    tag <- saira:::ph_icon("triangle-exclamation", class = "me-2")
    testthat::expect_identical(tag$attribs$class, "ph ph-warning me-2")
    testthat::expect_identical(tag$attribs$`aria-hidden`, "true")
    light <- saira:::ph_icon("upload", weight = "light")
    testthat::expect_identical(light$attribs$class, "ph-light ph-upload-simple")
    testthat::expect_true("upload-simple" %in% phosphor_classes("light"))
})
