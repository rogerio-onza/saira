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

test_that("occurrenceID card message reflects preservation vs auto-generation", {
    ns <- shiny::NS("map")
    cols <- c("-- " = "", colA = "colA")
    item <- list(term = "occurrenceID", desc = "x", category = "Record", sep = "")

    # Default (no source occurrenceID): says it will be auto-generated.
    gen_html <- as.character(build_field_card(
        item = item, cols = cols, current_val = "", is_mapped = TRUE,
        badge_info = NULL, ns = ns, lang_r = "en", input = list(),
        cat_class = "cat-record"
    ))
    expect_match(gen_html, tr("uuid_auto_generated", "en"), fixed = TRUE)
    expect_false(grepl(tr("occurrence_id_preserved", "en"), gen_html, fixed = TRUE))

    # Camera-trap upload that already carries occurrenceID: says preserved.
    keep_html <- as.character(build_field_card(
        item = item, cols = cols, current_val = "", is_mapped = TRUE,
        badge_info = NULL, ns = ns, lang_r = "en", input = list(),
        cat_class = "cat-record", occurrence_id_preserved = TRUE
    ))
    expect_match(keep_html, tr("occurrence_id_preserved", "en"), fixed = TRUE)
    expect_false(grepl(tr("uuid_auto_generated", "en"), keep_html, fixed = TRUE))
})

# Selection-dependent content now lives in per-term carddyn_<term> slots so a
# single selection updates only its card instead of rebuilding the whole grid.

test_that("standard select card embeds a carddyn slot instead of an inline sample", {
    ns <- shiny::NS("map")
    cols <- c("-- " = "", colA = "colA")
    item <- list(term = "eventDate", desc = "x", category = "Event", sep = "")

    html <- as.character(build_field_card(
        item = item, cols = cols, current_val = "colA", is_mapped = TRUE,
        badge_info = NULL, ns = ns, lang_r = "en", input = list(),
        cat_class = "cat-event"
    ))

    expect_match(html, ns("carddyn_eventDate"), fixed = TRUE)
    # The sample text itself is no longer baked into the card markup.
    expect_false(grepl("field-card-sample", html, fixed = TRUE))
})

test_that("basisOfRecord and dynamicProperties cards embed their carddyn slots", {
    ns <- shiny::NS("map")
    cols <- c("-- " = "", colA = "colA")

    basis_html <- as.character(build_field_card(
        item = list(term = "basisOfRecord", desc = "x", category = "Record", sep = ""),
        cols = cols, current_val = "colA", is_mapped = TRUE, badge_info = NULL,
        ns = ns, lang_r = "en", input = list(), cat_class = "cat-record"
    ))
    expect_match(basis_html, ns("carddyn_basisOfRecord"), fixed = TRUE)

    dyn_html <- as.character(build_field_card(
        item = list(term = "dynamicProperties", desc = "x", category = "Record", sep = ""),
        cols = cols, current_val = "colA", is_mapped = TRUE, badge_info = NULL,
        ns = ns, lang_r = "en", input = list(), cat_class = "cat-record"
    ))
    expect_match(dyn_html, ns("carddyn_dynamicProperties"), fixed = TRUE)
})

test_that("build_field_sample renders the sample only when values are present", {
    expect_null(build_field_sample(character(0), "en"))

    html <- as.character(build_field_sample(c("2020-01", "2020-02"), "en"))
    expect_match(html, "field-card-sample", fixed = TRUE)
    expect_match(html, "2020-01", fixed = TRUE)
    expect_match(html, tr("mapping_card_sample_prefix", "en"), fixed = TRUE)
})

test_that("build_basis_assistant_button appears only when a column is selected", {
    ns <- shiny::NS("map")
    expect_null(build_basis_assistant_button("", ns, "en"))

    html <- as.character(build_basis_assistant_button("colA", ns, "en"))
    expect_match(html, ns("open_basis_of_record_assistant"), fixed = TRUE)
})

test_that("build_dynprops_keys_block renders a key input per selected column", {
    ns <- shiny::NS("map")
    expect_null(build_dynprops_keys_block(character(0), ns, "en", list()))

    html <- as.character(build_dynprops_keys_block(c("colA", "colB"), ns, "en", list()))
    expect_match(html, ns(paste0("dynprops_key_", make.names("colA"))), fixed = TRUE)
    expect_match(html, ns(paste0("dynprops_key_", make.names("colB"))), fixed = TRUE)
})
