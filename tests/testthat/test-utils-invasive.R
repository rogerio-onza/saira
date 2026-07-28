test_that("flag_invasive_species matches listed taxa and ignores the rest", {
    expect_true(flag_invasive_species("Sus scrofa"))
    expect_false(flag_invasive_species("Panthera onca"))

    mixed <- flag_invasive_species(c("Sus scrofa", "Panthera onca", "Felis catus"))
    expect_equal(mixed, c(TRUE, FALSE, TRUE))
})

test_that("flag_invasive_species strips authorship and qualifiers", {
    expect_true(flag_invasive_species("Felis catus (Linnaeus, 1758)"))
    expect_true(flag_invasive_species("Sus scrofa Linnaeus, 1758"))
    expect_true(flag_invasive_species("sus scrofa"))
    # Deliberately shared with the validator: a capitalized second word is read
    # as authorship ("Sus Scrofa" -> "Sus"), so the list behaves exactly like
    # name validation rather than matching more loosely than it does.
    expect_false(flag_invasive_species("Sus Scrofa"))
})

test_that("flag_invasive_species handles blank, NA and empty input", {
    expect_equal(flag_invasive_species(c(NA, "", "   ")), c(FALSE, FALSE, FALSE))
    expect_equal(flag_invasive_species(character(0)), logical(0))
})

test_that("invasive_info_for returns list metadata aligned to the input", {
    info <- invasive_info_for(c("Sus scrofa", "Panthera onca", "Sus scrofa"))

    expect_s3_class(info, "data.frame")
    expect_equal(nrow(info), 3L)
    expect_equal(info$invasive, c(TRUE, FALSE, TRUE))
    expect_equal(info$source[[1]], "Instituto Horus, 2023")
    expect_true(is.na(info$source[[2]]))
    # Repeated names resolve identically (unique + match round trip).
    expect_equal(info$vernacularName[[1]], info$vernacularName[[3]])
})

test_that("invasive_info_for returns a zero-row frame for empty input", {
    info <- invasive_info_for(character(0))
    expect_s3_class(info, "data.frame")
    expect_equal(nrow(info), 0L)
    expect_true(all(
        c("invasive", "vernacularName", "introduction_reason", "source") %in%
            names(info)
    ))
})

test_that("a missing list degrades to nothing flagged instead of erroring", {
    invasive_species_cache$reset()
    withr::defer(invasive_species_cache$reset())

    testthat::local_mocked_bindings(
        resolve_invasive_species_path = function() NA_character_,
        .package = "saira"
    )

    expect_warning(loaded <- load_invasive_species(force = TRUE))
    expect_equal(nrow(loaded), 0L)
    expect_equal(
        suppressWarnings(flag_invasive_species(c("Sus scrofa", "Panthera onca"))),
        c(FALSE, FALSE)
    )
})

test_that("invasive_species_empty has the schema load_invasive_species promises", {
    empty <- invasive_species_empty()
    expect_equal(nrow(empty), 0L)
    expect_equal(
        names(empty),
        c("scientificName", "match_key", "kingdom", "vernacularName",
          "introduction_reason", "source")
    )
})

# Artifact assertions on the list that actually ships.
test_that("the bundled invasive list is loadable and well formed", {
    invasive_species_cache$reset()
    withr::defer(invasive_species_cache$reset())

    lookup <- load_invasive_species(force = TRUE)
    expect_gt(nrow(lookup), 400L)
    expect_true(all(nzchar(lookup$match_key)))
    expect_false(any(duplicated(lookup$match_key)))
    expect_true(all(lookup$source == "Instituto Horus, 2023"))
    # Both kingdoms are represented: the list is not animals-only.
    expect_true(all(c("Animalia", "Plantae") %in% unique(lookup$kingdom)))
})

test_that("match keys are built exactly like the generator builds them", {
    # The generator and the consumer must apply the same two steps, or the
    # bundled keys stop matching validated names.
    expected <- normalize_for_matching(
        normalize_scientific_name(
            "Sus scrofa Linnaeus, 1758",
            remove_authors = TRUE,
            ignore_qualifiers = TRUE
        )
    )
    expect_equal(build_invasive_match_keys("Sus scrofa Linnaeus, 1758"), expected)
    expect_equal(build_invasive_match_keys(character(0)), character(0))
})
