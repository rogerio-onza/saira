# Title: Tests for the Help tab credits (ADR-146)
# Author: Rogerio Nunes Oliveira
# Date: 2026-10-05

testthat::test_that("the package groups list every import, with a text per language", {
    imports <- utils::packageDescription("saira")$Imports
    imports <- trimws(sub("\\(.*", "", strsplit(imports, ",")[[1]]))
    groups <- credits_package_groups()
    dict <- saira:::load_i18n_dict()

    testthat::expect_true(all(imports %in% unlist(groups)), info = paste(setdiff(imports, unlist(groups)), collapse = ", "))
    keys <- c(paste0("help_pkg_group_", names(groups)), paste0("help_pkg_", tolower(unlist(groups))))
    for (key in keys) {
        for (lang in get_languages()) {
            testthat::expect_true(nzchar(dict[[key]][[lang]] %||% ""), info = paste(key, lang))
        }
    }
})

testthat::test_that("credits_package_meta reads the version and drops the maintainer email", {
    meta <- credits_package_meta("shiny")
    testthat::expect_equal(meta$version, as.character(utils::packageVersion("shiny")))
    testthat::expect_false(grepl("[<>@]", meta$maintainer))
    testthat::expect_equal(meta$href, "https://cran.r-project.org/package=shiny")
    testthat::expect_equal(credits_package_meta("faunabr")$href, "https://github.com/wevertonbio/faunabr")

    missing <- credits_package_meta("notapackage.saira")
    testthat::expect_true(is.na(missing$version))
    testthat::expect_true(is.na(missing$maintainer))
})

testthat::test_that("credits_saira_meta takes the maintainer from Authors@R", {
    desc <- list(
        `Authors@R` = paste(
            'c(person("Ana", "Lima", role = "ctb"),',
            'person("Rog\\u00E9rio", "Nunes Oliveira", email = "r@example.org", role = c("aut", "cre")))'
        ),
        Title = "Biodiversity Data Standardization to Darwin Core",
        Version = "1.0.0",
        License = "GPL-3",
        URL = "https://github.com/rogerio-onza/saira, https://rogerio-onza.github.io/saira",
        BugReports = "https://github.com/rogerio-onza/saira/issues",
        Packaged = "2026-10-05 12:00:00 UTC; rogerio"
    )
    meta <- credits_saira_meta(desc)

    testthat::expect_equal(meta$name, "Rog\u00E9rio Nunes Oliveira")
    testthat::expect_equal(meta$initials, "RO")
    testthat::expect_equal(meta$email, "r@example.org")
    testthat::expect_equal(meta$repo, "https://github.com/rogerio-onza/saira")
    testthat::expect_equal(meta$year, "2026")

    cite <- credits_citation(meta)
    testthat::expect_equal(
        cite$text,
        paste(
            "Nunes Oliveira, R. (2026). Sa\u00EDra: Biodiversity Data Standardization to Darwin Core.",
            "R package version 1.0.0. https://github.com/rogerio-onza/saira"
        )
    )
    testthat::expect_match(cite$bibtex, "^@Manual\\{saira,\n")
    testthat::expect_match(cite$bibtex, "author = {Rog\u00E9rio {Nunes Oliveira}}", fixed = TRUE)
    testthat::expect_match(cite$bibtex, "note = {R package version 1.0.0}", fixed = TRUE)
})
