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
        c("invasive", "vernacularName", "introduction_reason", "origin_class",
          "native_range", "source") %in%
            names(info)
    ))
})

test_that("invasive_detail_lines carries the range, then the reason", {
    # The coati and the tegu have no motivo, which is exactly why the range
    # matters: it is the only thing that tells the publisher where the taxon
    # actually belongs.
    for (name in c("Nasua nasua", "Salvator merianae")) {
        lines <- invasive_detail_lines(name, "pt")
        expect_length(lines, 1L)
        expect_true(startsWith(lines[[1]], "Distribui"))
    }

    both <- invasive_detail_lines("Cichla kelberi", "pt")
    expect_length(both, 2L)
    expect_true(startsWith(both[[1]], "Distribui"))
    expect_true(startsWith(both[[2]], "Introduzida para:"))

    # Only the label is translated; the range itself is source prose.
    expect_true(startsWith(
        invasive_detail_lines("Cichla kelberi", "en")[[1]], "Natural range:"
    ))

    expect_length(invasive_detail_lines("Panthera onca", "pt"), 0L)
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
          "introduction_reason", "origin_class", "native_range", "source")
    )
})

test_that("origin_class separates alien taxa from translocated natives", {
    # The Horus list is not uniformly alien: Nasua nasua is native to most of
    # Brazil and invasive on Fernando de Noronha, so calling it "exotica
    # invasora" states something false about a mainland record.
    expect_equal(invasive_origin_class_for("Nasua nasua"), "translocated_native")
    expect_equal(invasive_origin_class_for("Sus scrofa"), "alien")
    expect_true(is.na(invasive_origin_class_for("Panthera onca")))

    # Membership itself is unchanged: both groups still flag, so the filter
    # pill and the aggregate count keep covering them.
    expect_equal(
        flag_invasive_species(c("Nasua nasua", "Sus scrofa", "Panthera onca")),
        c(TRUE, TRUE, FALSE)
    )
    expect_equal(invasive_origin_class_for(character(0)), character(0))
})

test_that("translate_invasive_reason localizes the closed Horus vocabulary", {
    expect_equal(
        translate_invasive_reason("Peixes de aquário; Pesca desportiva", "en"),
        "aquarium fish, sport fishing"
    )
    expect_equal(
        translate_invasive_reason("Peixes de aquário; Pesca desportiva", "pt"),
        "peixes de aquário, pesca desportiva"
    )
    # A value outside the known 8 passes through instead of becoming a
    # [missing_key] placeholder.
    expect_equal(translate_invasive_reason("Motivo novo", "en"), "Motivo novo")
    expect_true(is.na(translate_invasive_reason(NA_character_, "pt")))
    expect_true(is.na(translate_invasive_reason("   ", "pt")))
})

test_that("a list without origin_class keeps the pre-existing alien treatment", {
    invasive_species_cache$reset()
    withr::defer(invasive_species_cache$reset())

    legacy <- readRDS(resolve_invasive_species_path())
    legacy$origin_class <- NULL
    path <- withr::local_tempfile(fileext = ".rds")
    saveRDS(legacy, path)

    testthat::local_mocked_bindings(
        resolve_invasive_species_path = function() path,
        .package = "saira"
    )

    loaded <- load_invasive_species(force = TRUE)
    expect_true(all(loaded$origin_class == "alien"))
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
    # Every row is classified, and both groups are non-empty -- an all-alien
    # artifact would mean the generator ran without the provider caches.
    expect_setequal(unique(lookup$origin_class), c("alien", "translocated_native"))
    expect_gt(sum(lookup$origin_class == "translocated_native"), 50L)
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
