# Title: Tests for the species photos
# Author: Rogerio Nunes Oliveira
# Date: 2026-10-10

testthat::test_that("every species photo has a file, a credit and a common name", {
    photos <- species_photos()
    www <- system.file("app", "www", "images", "species", package = "saira")
    dict <- saira:::load_i18n_dict()
    for (slug in photos$slug) {
        testthat::expect_true(file.exists(file.path(www, paste0(slug, ".webp"))), info = slug)
        for (lang in get_languages()) {
            key <- paste0("species_common_", gsub("-", "_", slug, fixed = TRUE))
            testthat::expect_true(nzchar(dict[[key]][[lang]] %||% ""), info = paste(key, lang))
        }
    }
    testthat::expect_true(all(grepl(" \u00b7 CC BY", photos$credit, fixed = TRUE)))
})

testthat::test_that("species_photo_tag puts the credit on the photo", {
    html <- as.character(species_photo_tag(species_photo("leopardus-munoai"), "en", class = "x-photo"))
    testthat::expect_true(grepl("class=\"species-photo x-photo\"", html, fixed = TRUE))
    testthat::expect_true(grepl("www/images/species/leopardus-munoai.webp", html, fixed = TRUE))
    testthat::expect_true(grepl("<em>Leopardus munoai</em>", html, fixed = TRUE))
    testthat::expect_true(grepl(" \u00b7 Pampas cat \u00b7 Felipe Peters \u00b7 CC BY-NC 4.0", html, fixed = TRUE))
    testthat::expect_error(species_photo("no-such-species"), "Unknown species photo")
})
