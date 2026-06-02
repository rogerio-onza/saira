# Tests for build_field_card() locked-field behavior.

test_that("taxonRank/specificEpithet lock when scientificName is mapped", {
    ns <- shiny::NS("map")
    cols <- c("-- " = "", colA = "colA")

    for (term in c("taxonRank", "specificEpithet")) {
        item <- list(term = term, desc = "x", category = "Taxon", sep = "")

        locked_html <- as.character(build_field_card(
            item = item, cols = cols, current_val = "", is_mapped = TRUE,
            badge_info = NULL, ns = ns, lang_r = "en", input = list(),
            cat_class = "cat-taxon", scientificname_mapped = TRUE
        ))

        # Locked: shows the derived notice, not a column selector.
        expect_match(locked_html, tr("taxon_auto_derived", "en"), fixed = TRUE)
        expect_false(grepl(ns(paste0("map_", term)), locked_html, fixed = TRUE))
    }
})

test_that("taxonRank renders a column selector when scientificName is not mapped", {
    ns <- shiny::NS("map")
    cols <- c("-- " = "", colA = "colA")
    item <- list(term = "taxonRank", desc = "x", category = "Taxon", sep = "")

    unlocked_html <- as.character(build_field_card(
        item = item, cols = cols, current_val = "", is_mapped = FALSE,
        badge_info = NULL, ns = ns, lang_r = "en", input = list(),
        cat_class = "cat-taxon", scientificname_mapped = FALSE
    ))

    expect_match(unlocked_html, ns("map_taxonRank"), fixed = TRUE)
    expect_false(grepl(tr("taxon_auto_derived", "en"), unlocked_html, fixed = TRUE))
})
