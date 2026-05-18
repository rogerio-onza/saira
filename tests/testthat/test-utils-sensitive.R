# Title: Tests for Sensitive-species Coordinate Masking
# Author: Rogerio Nunes Oliveira

# Helper: install a synthetic sensitive list into the cache for the duration
# of the calling test, then restore the real one.
local_sensitive_fixture <- function(species, env = parent.frame()) {
    fixture <- data.frame(
        scientificName = species,
        match_key = saira:::build_sensitive_match_keys(species),
        stringsAsFactors = FALSE
    )
    saira:::sensitive_species_cache$set(fixture, path = "test-fixture")
    withr::defer(saira:::sensitive_species_cache$reset(), envir = env)
    fixture
}

# generalize_coord --------------------------------------------------------

testthat::test_that("generalize_coord rounds to grid incl. negatives and NA", {
    testthat::expect_equal(
        saira:::generalize_coord(c(-23.5612, 46.6543, NA), 0.1),
        c(-23.6, 46.7, NA)
    )
    testthat::expect_equal(
        saira:::generalize_coord(c(-23.5612, 46.6543), 0.01),
        c(-23.56, 46.65)
    )
    testthat::expect_equal(
        saira:::generalize_coord(c(-23.9, 46.1), 1),
        c(-24, 46)
    )
})

testthat::test_that("generalize_coord coerces character input", {
    testthat::expect_equal(
        saira:::generalize_coord(c("-23.5612", "46.6543"), 0.1),
        c(-23.6, 46.7)
    )
})

testthat::test_that("generalize_coord rejects an invalid grid", {
    testthat::expect_error(saira:::generalize_coord(1, 0))
    testthat::expect_error(saira:::generalize_coord(1, -0.1))
    testthat::expect_error(saira:::generalize_coord(1, NA))
    testthat::expect_error(saira:::generalize_coord(1, c(0.1, 0.2)))
})

# flag_sensitive_species --------------------------------------------------

testthat::test_that("flag_sensitive_species matches exact and author forms", {
    local_sensitive_fixture(c("Panthera onca", "Hippocampus reidi"))
    res <- saira:::flag_sensitive_species(c(
        "Panthera onca",
        "Panthera onca (Linnaeus, 1758)",
        "Felis catus"
    ))
    testthat::expect_equal(res, c(TRUE, TRUE, FALSE))
})

testthat::test_that("flag_sensitive_species matching is rank-exact", {
    local_sensitive_fixture("Arthrocereus melanurus subsp. magnus")
    res <- saira:::flag_sensitive_species(c(
        "Arthrocereus melanurus subsp. magnus",
        "Arthrocereus melanurus"
    ))
    testthat::expect_equal(res, c(TRUE, FALSE))
})

testthat::test_that("flag_sensitive_species handles empty, NA and blank input", {
    local_sensitive_fixture("Panthera onca")
    testthat::expect_equal(saira:::flag_sensitive_species(character(0)), logical(0))
    testthat::expect_equal(
        saira:::flag_sensitive_species(c(NA_character_, "", "  ")),
        c(FALSE, FALSE, FALSE)
    )
})

testthat::test_that("flag_sensitive_species is all-FALSE on an empty list", {
    saira:::sensitive_species_cache$set(
        saira:::sensitive_species_empty(),
        path = "test-empty"
    )
    withr::defer(saira:::sensitive_species_cache$reset())
    testthat::expect_equal(
        saira:::flag_sensitive_species(c("Panthera onca", "Felis catus")),
        c(FALSE, FALSE)
    )
})

# load_sensitive_species --------------------------------------------------

testthat::test_that("load_sensitive_species reads the bundled MMA list", {
    saira:::sensitive_species_cache$reset()
    withr::defer(saira:::sensitive_species_cache$reset())
    df <- saira:::load_sensitive_species(force = TRUE)
    testthat::expect_true(is.data.frame(df))
    testthat::expect_setequal(names(df), c("scientificName", "match_key"))
    testthat::expect_gt(nrow(df), 0L)
    testthat::expect_equal(anyDuplicated(df$match_key), 0L)
})

testthat::test_that("sensitive_species_empty has the contract shape", {
    e <- saira:::sensitive_species_empty()
    testthat::expect_equal(nrow(e), 0L)
    testthat::expect_setequal(names(e), c("scientificName", "match_key"))
})

# mask_sensitive_coordinates ----------------------------------------------

make_df <- function() {
    data.frame(
        occurrenceID = c("a1", "a2", "a3", "a4"),
        scientificName = c(
            "Panthera onca", "Felis catus", "Panthera onca", "Hippocampus reidi"
        ),
        decimalLatitude = c("-23.5612", "10.0", "", "-5.1234"),
        decimalLongitude = c("-46.6543", "20.0", "-40.0", "-39.9876"),
        coordinateUncertaintyInMeters = c("3000", "", "", NA),
        stringsAsFactors = FALSE
    )
}

testthat::test_that("mask generalizes only sensitive rows that have coords", {
    local_sensitive_fixture(c("Panthera onca", "Hippocampus reidi"))
    res <- saira:::mask_sensitive_coordinates(make_df(), grid = 0.1, lang = "en")

    testthat::expect_equal(res$n_masked, 2L)
    # Row 1 sensitive + coords -> generalized.
    testthat::expect_equal(res$masked$decimalLatitude[1], "-23.6")
    testthat::expect_equal(res$masked$decimalLongitude[1], "-46.7")
    # Row 2 not sensitive -> byte-identical.
    testthat::expect_equal(res$masked$decimalLatitude[2], "10.0")
    testthat::expect_equal(res$masked$decimalLongitude[2], "20.0")
    # Row 3 sensitive but no latitude -> untouched, not in companion.
    testthat::expect_equal(res$masked$decimalLatitude[3], "")
    testthat::expect_false("a3" %in% res$real$occurrenceID)
    # Row 4 sensitive + coords -> generalized.
    testthat::expect_equal(res$masked$decimalLatitude[4], "-5.1")
})

testthat::test_that("mask sets DwC fields and raises uncertainty conservatively", {
    local_sensitive_fixture(c("Panthera onca", "Hippocampus reidi"))
    res <- saira:::mask_sensitive_coordinates(make_df(), grid = 0.1, lang = "en")

    testthat::expect_true(nzchar(res$masked$dataGeneralizations[1]))
    testthat::expect_true(nzchar(res$masked$informationWithheld[1]))
    testthat::expect_equal(res$masked$dataGeneralizations[2], "")
    # Existing 3000 m < grid cell -> raised to the grid uncertainty.
    testthat::expect_equal(
        res$masked$coordinateUncertaintyInMeters[1],
        as.character(saira:::sensitive_grid_uncertainty_m(0.1))
    )
    # Missing uncertainty -> set to the grid uncertainty.
    testthat::expect_equal(
        res$masked$coordinateUncertaintyInMeters[4],
        as.character(saira:::sensitive_grid_uncertainty_m(0.1))
    )
})

testthat::test_that("mask never lowers a larger pre-existing uncertainty", {
    local_sensitive_fixture("Panthera onca")
    df <- data.frame(
        occurrenceID = "a1",
        scientificName = "Panthera onca",
        decimalLatitude = "-23.5",
        decimalLongitude = "-46.6",
        coordinateUncertaintyInMeters = "50000",
        dataGeneralizations = "",
        informationWithheld = "",
        stringsAsFactors = FALSE
    )
    res <- saira:::mask_sensitive_coordinates(df, grid = 0.1, lang = "en")
    testthat::expect_equal(res$masked$coordinateUncertaintyInMeters[1], "50000")
    # Columns pre-existed -> no reordering.
    testthat::expect_equal(names(res$masked), names(df))
})

testthat::test_that("mask companion holds original coords keyed on occurrenceID", {
    local_sensitive_fixture(c("Panthera onca", "Hippocampus reidi"))
    res <- saira:::mask_sensitive_coordinates(make_df(), grid = 0.1, lang = "en")

    testthat::expect_equal(res$real$occurrenceID, c("a1", "a4"))
    testthat::expect_equal(res$real$decimalLatitude, c("-23.5612", "-5.1234"))
    testthat::expect_equal(res$real$decimalLongitude, c("-46.6543", "-39.9876"))
    testthat::expect_setequal(
        names(res$real),
        c("occurrenceID", "scientificName", "decimalLatitude", "decimalLongitude")
    )
})

testthat::test_that("mask DwC text follows the requested language", {
    local_sensitive_fixture("Panthera onca")
    en <- saira:::mask_sensitive_coordinates(make_df(), lang = "en")
    pt <- saira:::mask_sensitive_coordinates(make_df(), lang = "pt")
    testthat::expect_false(
        identical(
            en$masked$dataGeneralizations[1],
            pt$masked$dataGeneralizations[1]
        )
    )
    testthat::expect_true(grepl("generalized", en$masked$dataGeneralizations[1]))
    testthat::expect_true(grepl("generalizadas", pt$masked$dataGeneralizations[1]))
})

testthat::test_that("mask is a no-op without the required columns or rows", {
    local_sensitive_fixture("Panthera onca")
    no_cols <- data.frame(scientificName = "Panthera onca", stringsAsFactors = FALSE)
    r1 <- saira:::mask_sensitive_coordinates(no_cols)
    testthat::expect_equal(r1$n_masked, 0L)
    testthat::expect_identical(r1$masked, no_cols)

    r2 <- saira:::mask_sensitive_coordinates(make_df()[0, ])
    testthat::expect_equal(r2$n_masked, 0L)

    none <- data.frame(
        scientificName = "Felis catus",
        decimalLatitude = "1.0",
        decimalLongitude = "2.0",
        stringsAsFactors = FALSE
    )
    r3 <- saira:::mask_sensitive_coordinates(none)
    testthat::expect_equal(r3$n_masked, 0L)
    testthat::expect_identical(r3$masked, none)
})
