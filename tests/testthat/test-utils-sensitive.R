# Title: Tests for Sensitive-species Coordinate Masking (ADR-090, ADR-092)
# Author: Rogerio Nunes Oliveira

# Helper: install a synthetic sensitive list into the cache for the duration
# of the calling test, then restore the real one. `category` is recycled to
# the length of `species` (default CR -> 0.1 deg under the conservative
# scheme, so the legacy assertions still hold).
local_sensitive_fixture <- function(species, category = "CR",
                                     env = parent.frame()) {
    fixture <- data.frame(
        scientificName = species,
        match_key = saira:::build_sensitive_match_keys(species),
        category = rep_len(category, length(species)),
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

# sensitive_generalization_levels / _grid --------------------------------

testthat::test_that("generalization levels follow Chapman 2020 Table 7", {
    testthat::expect_equal(
        saira:::sensitive_generalization_levels(),
        c("extreme", "high", "medium", "low", "not_sensitive")
    )
})

testthat::test_that("generalization grid maps each tier to the right degree", {
    testthat::expect_equal(saira:::sensitive_generalization_grid("extreme"), 1.0)
    testthat::expect_equal(saira:::sensitive_generalization_grid("high"), 0.1)
    testthat::expect_equal(saira:::sensitive_generalization_grid("medium"), 0.01)
    testthat::expect_equal(saira:::sensitive_generalization_grid("low"), 0.001)
    testthat::expect_true(is.na(saira:::sensitive_generalization_grid("not_sensitive")))
    # Unknown / malformed level -> NA (treated as no-op upstream).
    testthat::expect_true(is.na(saira:::sensitive_generalization_grid("bogus")))
    testthat::expect_true(is.na(saira:::sensitive_generalization_grid(NA_character_)))
})

# precision lock ---------------------------------------------------------

testthat::test_that("coordinate_decimal_grid reads precision from the literal string", {
    testthat::expect_equal(
        saira:::coordinate_decimal_grid(c("-81.41", "-81.40", "-81", "12.34567")),
        c(0.01, 0.01, 1, 1e-5)
    )
    # Trailing zeros count (as.numeric would drop them); blank/NA -> NA.
    testthat::expect_equal(
        saira:::coordinate_decimal_grid(c("-23.500", "", NA)),
        c(0.001, NA, NA)
    )
})

testthat::test_that("existing_precision_grid takes the coarsest signal per row", {
    df <- data.frame(
        decimalLatitude = c("-81.41", "-10.12345", "-5.1"),
        decimalLongitude = c("-46.666", "-40.54321", "-39.0"),
        stringsAsFactors = FALSE
    )
    # Coarsest of the two axes: row1 lat 0.01 vs lon 0.001 -> 0.01.
    testthat::expect_equal(saira:::existing_precision_grid(df), c(0.01, 1e-5, 0.1))
    # An explicit coordinatePrecision column widens the lock when coarser.
    df$coordinatePrecision <- c("0.1", NA, NA)
    testthat::expect_equal(saira:::existing_precision_grid(df)[1], 0.1)
})

testthat::test_that("mask clamps the grid to existing precision, never finer (Chapman)", {
    local_sensitive_fixture("Panthera onca")
    # 2-decimal coordinate -> existing precision 0.01 deg.
    df <- data.frame(
        occurrenceID = "o1", scientificName = "Panthera onca",
        decimalLatitude = "-81.41", decimalLongitude = "-46.66",
        stringsAsFactors = FALSE
    )

    # low (0.001) is finer than the data -> clamped to 0.01 (never invent
    # precision), but STILL masked + documented (Chapman sec. 5.1).
    res_low <- saira:::mask_sensitive_coordinates(df, generalization = "low", lang = "en")
    testthat::expect_equal(res_low$n_masked, 1L)
    testthat::expect_equal(res_low$n_clamped_to_precision, 1L)
    testthat::expect_equal(res_low$masked$decimalLatitude[1], "-81.41")
    testthat::expect_equal(res_low$masked$coordinatePrecision[1], "0.01")
    testthat::expect_true("o1" %in% res_low$real$occurrenceID)
    # The record is still protected: informationWithheld + a precision-stored note.
    testthat::expect_true(nzchar(res_low$masked$informationWithheld[1]))
    testthat::expect_match(res_low$masked$dataGeneralizations[1], "0.01", fixed = TRUE)

    # medium (0.01) == existing precision -> applied, no clamp, coords unchanged.
    res_med <- saira:::mask_sensitive_coordinates(df, generalization = "medium", lang = "en")
    testthat::expect_equal(res_med$n_masked, 1L)
    testthat::expect_equal(res_med$n_clamped_to_precision, 0L)
    testthat::expect_equal(res_med$masked$decimalLatitude[1], "-81.41")

    # high (0.1) is coarser -> genuinely generalized, no clamp.
    res_high <- saira:::mask_sensitive_coordinates(df, generalization = "high", lang = "en")
    testthat::expect_equal(res_high$n_masked, 1L)
    testthat::expect_equal(res_high$n_clamped_to_precision, 0L)
    testthat::expect_equal(res_high$masked$decimalLatitude[1], "-81.4")
})

testthat::test_that("map preview clamps (never drops) and reports the clamped count", {
    local_sensitive_fixture("Panthera onca")
    df <- data.frame(
        scientificName = "Panthera onca",
        decimalLatitude = "-81.41", decimalLongitude = "-46.66",
        stringsAsFactors = FALSE
    )
    # low (0.001) finer than 0.01 -> still shown, but generalized at 0.01.
    clamped <- saira:::generalization_map_preview(df, generalization = "low")
    testthat::expect_equal(nrow(clamped), 1L)
    testthat::expect_equal(attr(clamped, "n_clamped_to_precision"), 1L)
    testthat::expect_equal(clamped$gen_lat, -81.41)
    # high (0.1) coarser -> one row, nothing clamped.
    shown <- saira:::generalization_map_preview(df, generalization = "high")
    testthat::expect_equal(nrow(shown), 1L)
    testthat::expect_equal(attr(shown, "n_clamped_to_precision"), 0L)
    testthat::expect_equal(shown$gen_lat, -81.4)
})

# sensitive_category_for / flag ------------------------------------------

testthat::test_that("sensitive_category_for returns the MMA category or NA", {
    local_sensitive_fixture(
        c("Panthera onca", "Araucaria angustifolia"),
        category = c("CR", "CR (PEX)")
    )
    testthat::expect_equal(
        saira:::sensitive_category_for(c(
            "Panthera onca", "Araucaria angustifolia", "Felis catus"
        )),
        c("CR", "CR (PEX)", NA_character_)
    )
    testthat::expect_equal(
        saira:::sensitive_category_for(character(0)), character(0)
    )
})

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

# sensitive_resolve ------------------------------------------------------

testthat::test_that("sensitive_resolve: payload overrides the MMA default", {
    local_sensitive_fixture("Panthera onca", category = "CR")
    dec <- data.frame(
        scientificName = c("Panthera onca", "Felis catus"),
        sensitive = c(FALSE, TRUE),
        stringsAsFactors = FALSE
    )
    res <- saira:::sensitive_resolve(
        c("Panthera onca", "Felis catus", "Canis lupus"), dec
    )
    # MMA species explicitly unmarked; non-MMA species manually marked;
    # untouched species falls back to the MMA default (not listed -> FALSE).
    testthat::expect_equal(res$sensitive, c(FALSE, TRUE, FALSE))
    # The MMA category survives for display on the pill in Validation > Names;
    # non-MMA overrides have no category (NA — pill falls back to "—").
    testthat::expect_equal(res$category[1], "CR")
    testthat::expect_true(is.na(res$category[2]))
})

testthat::test_that("sensitive_resolve tolerates a legacy payload carrying category", {
    saira:::sensitive_species_cache$set(
        saira:::sensitive_species_empty(), path = "test-empty"
    )
    withr::defer(saira:::sensitive_species_cache$reset())
    dec <- data.frame(
        scientificName = "Mystery sp", sensitive = TRUE, category = "VU",
        stringsAsFactors = FALSE
    )
    res <- saira:::sensitive_resolve("Mystery sp", dec)
    testthat::expect_true(res$sensitive)
    # Legacy `category` is honoured for display only.
    testthat::expect_equal(res$category, "VU")
})

# load_sensitive_species -------------------------------------------------

testthat::test_that("load_sensitive_species reads the bundled MMA list", {
    saira:::sensitive_species_cache$reset()
    withr::defer(saira:::sensitive_species_cache$reset())
    df <- saira:::load_sensitive_species(force = TRUE)
    testthat::expect_true(is.data.frame(df))
    testthat::expect_setequal(
        names(df), c("scientificName", "match_key", "category", "source")
    )
    testthat::expect_gt(nrow(df), 0L)
    testthat::expect_equal(anyDuplicated(df$match_key), 0L)
    testthat::expect_true(all(
        df$category %in% c("VU", "EN", "CR", "CR (PEX)")
    ))
})

testthat::test_that("sensitive_species_empty has the contract shape", {
    e <- saira:::sensitive_species_empty()
    testthat::expect_equal(nrow(e), 0L)
    testthat::expect_setequal(
        names(e), c("scientificName", "match_key", "category", "source")
    )
})

# mask_sensitive_coordinates --------------------------------------------

make_df <- function() {
    data.frame(
        occurrenceID = c("a1", "a2", "a3", "a4"),
        scientificName = c(
            "Panthera onca", "Felis catus", "Panthera onca", "Hippocampus reidi"
        ),
        decimalLatitude = c("-23.5612", "10.0", "", "-5.1234"),
        decimalLongitude = c("-46.6543", "20.0", "-40.0", "-39.9876"),
        # Row 1 uncertainty kept below SENSITIVE_ALREADY_MASKED_THRESHOLD_M
        # (1000 m, ADR-095) so masking still applies and pmax(100, grid) raises.
        coordinateUncertaintyInMeters = c("100", "", "", NA),
        stringsAsFactors = FALSE
    )
}

testthat::test_that("mask generalizes only sensitive rows that have coords", {
    local_sensitive_fixture(c("Panthera onca", "Hippocampus reidi"))
    # Default generalization is "low" (0.001 deg).
    res <- saira:::mask_sensitive_coordinates(
        make_df(), generalization = "low", lang = "en"
    )

    testthat::expect_equal(res$n_masked, 2L)
    # Row 1 sensitive + coords -> generalized to 0.001 deg.
    testthat::expect_equal(res$masked$decimalLatitude[1], "-23.561")
    testthat::expect_equal(res$masked$decimalLongitude[1], "-46.654")
    # Row 2 not sensitive -> byte-identical.
    testthat::expect_equal(res$masked$decimalLatitude[2], "10.0")
    testthat::expect_equal(res$masked$decimalLongitude[2], "20.0")
    # Row 3 sensitive but no latitude -> untouched, not in companion.
    testthat::expect_equal(res$masked$decimalLatitude[3], "")
    testthat::expect_false("a3" %in% res$real$occurrenceID)
    # Row 4 sensitive + coords -> generalized.
    testthat::expect_equal(res$masked$decimalLatitude[4], "-5.123")
})

testthat::test_that("mask grid follows the chosen Chapman tier uniformly", {
    local_sensitive_fixture("Xxxia exampla")
    df <- data.frame(
        occurrenceID = "x1", scientificName = "Xxxia exampla",
        decimalLatitude = "-23.456789", decimalLongitude = "-46.123456",
        stringsAsFactors = FALSE
    )
    expectations <- list(
        list(level = "low",     lat = "-23.457"),
        list(level = "medium",  lat = "-23.46"),
        list(level = "high",    lat = "-23.5"),
        list(level = "extreme", lat = "-23")
    )
    for (e in expectations) {
        r <- saira:::mask_sensitive_coordinates(
            df, generalization = e$level, lang = "en"
        )
        testthat::expect_equal(
            r$masked$decimalLatitude[1], e$lat,
            info = e$level
        )
    }
})

testthat::test_that("mask sets DwC fields incl. coordinatePrecision", {
    local_sensitive_fixture(c("Panthera onca", "Hippocampus reidi"))
    res <- saira:::mask_sensitive_coordinates(
        make_df(), generalization = "high", lang = "en"
    )

    testthat::expect_true(nzchar(res$masked$dataGeneralizations[1]))
    testthat::expect_true(nzchar(res$masked$informationWithheld[1]))
    testthat::expect_equal(res$masked$dataGeneralizations[2], "")
    testthat::expect_equal(res$masked$coordinatePrecision[1], "0.1")
    # Uncertainty = geographic radial (cell centre -> furthest corner) combined
    # additively with the original record uncertainty (100 m on row 1).
    g1lon <- as.numeric(res$masked$decimalLongitude[1])
    g1lat <- as.numeric(res$masked$decimalLatitude[1])
    testthat::expect_equal(
        res$masked$coordinateUncertaintyInMeters[1],
        as.character(ceiling(saira:::sensitive_grid_uncertainty_m(0.1, g1lon, g1lat) + 100))
    )
    # Missing original uncertainty -> just the cell radial.
    g4lon <- as.numeric(res$masked$decimalLongitude[4])
    g4lat <- as.numeric(res$masked$decimalLatitude[4])
    testthat::expect_equal(
        res$masked$coordinateUncertaintyInMeters[4],
        as.character(ceiling(saira:::sensitive_grid_uncertainty_m(0.1, g4lon, g4lat)))
    )
    # The cell is also captured as a footprint polygon (Best Practices 2.3.4).
    testthat::expect_match(res$masked$footprintWKT[1], "^POLYGON \\(\\(")
    testthat::expect_equal(res$masked$footprintSRS[1], "EPSG:4326")
})

testthat::test_that("mask never lowers a larger pre-existing uncertainty", {
    local_sensitive_fixture("Panthera onca")
    df <- data.frame(
        occurrenceID = "a1",
        scientificName = "Panthera onca",
        decimalLatitude = "-23.5",
        decimalLongitude = "-46.6",
        coordinateUncertaintyInMeters = "50000",
        coordinatePrecision = "",
        dataGeneralizations = "",
        informationWithheld = "",
        stringsAsFactors = FALSE
    )
    res <- saira:::mask_sensitive_coordinates(
        df, generalization = "high", lang = "en"
    )
    testthat::expect_equal(res$masked$coordinateUncertaintyInMeters[1], "50000")
    # All four DwC columns pre-existed -> no reordering.
    testthat::expect_equal(names(res$masked), names(df))
})

testthat::test_that("mask scrubs coordinate-leaking text on sensitive rows", {
    local_sensitive_fixture(c("Panthera onca", "Hippocampus reidi"))
    df <- make_df()
    df$locality <- c("exact spot", "town", "here", "river bend")
    df$verbatimLatitude <- c("23 33 S", "10 00 N", "", "5 07 S")
    df$verbatimLongitude <- c("46 39 W", "20 00 E", "", "39 59 W")
    df$verbatimCoordinates <- c("23 33 S 46 39 W", "", "", "5 07 S 39 59 W")
    res <- saira:::mask_sensitive_coordinates(df, lang = "en")
    iw <- res$masked$informationWithheld[1]

    # Locality-type leak fields carry the replacement wording.
    testthat::expect_equal(res$masked$locality[1], iw)
    # Verbatim coordinate fields are blanked, never prose (Darwin Core).
    testthat::expect_equal(res$masked$verbatimLatitude[4], "")
    testthat::expect_equal(res$masked$verbatimLongitude[4], "")
    testthat::expect_equal(res$masked$verbatimCoordinates[4], "")
    # Non-sensitive row keeps its text untouched.
    testthat::expect_equal(res$masked$locality[2], "town")
    testthat::expect_equal(res$masked$verbatimLatitude[2], "10 00 N")
    # footprintWKT now carries the generalized cell polygon on masked rows
    # (Best Practices 2.3.4), and stays empty on the non-sensitive row.
    testthat::expect_match(res$masked$footprintWKT[1], "^POLYGON \\(\\(")
    testthat::expect_equal(res$masked$footprintWKT[2], "")
    testthat::expect_equal(res$masked$footprintSRS[1], "EPSG:4326")
})

testthat::test_that("informationWithheld uses the pipe multi-value separator", {
    local_sensitive_fixture("Panthera onca")
    res <- saira:::mask_sensitive_coordinates(
        make_df(), generalization = "high", lang = "en"
    )
    iw <- res$masked$informationWithheld[1]

    testthat::expect_true(grepl(" | ", iw, fixed = TRUE))
    testthat::expect_false(grepl(";", iw, fixed = TRUE))
})

testthat::test_that("decisions override: unmark MMA, mark non-MMA", {
    local_sensitive_fixture("Panthera onca", category = "CR")
    df <- data.frame(
        occurrenceID = c("m", "n"),
        scientificName = c("Panthera onca", "Felis catus"),
        decimalLatitude = c("-23.5612", "-10.5612"),
        decimalLongitude = c("-46.6543", "-40.6543"),
        stringsAsFactors = FALSE
    )
    dec <- data.frame(
        scientificName = c("Panthera onca", "Felis catus"),
        sensitive = c(FALSE, TRUE),
        stringsAsFactors = FALSE
    )
    res <- saira:::mask_sensitive_coordinates(
        df, decisions = dec, generalization = "low", lang = "en"
    )
    testthat::expect_equal(res$n_masked, 1L)
    # Panthera onca unmarked -> untouched.
    testthat::expect_equal(res$masked$decimalLatitude[1], "-23.5612")
    # Felis catus marked sensitive -> "low" tier (0.001 deg).
    testthat::expect_equal(res$masked$decimalLatitude[2], "-10.561")
    testthat::expect_equal(res$real$scientificName, "Felis catus")
    # Non-MMA override has no MMA category -> em-dash placeholder.
    testthat::expect_equal(res$real$category, "—")
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
    testthat::expect_true(grepl("CR", en$masked$dataGeneralizations[1]))
})

testthat::test_that("enabled = FALSE is a byte-identical no-op", {
    local_sensitive_fixture("Panthera onca")
    res <- saira:::mask_sensitive_coordinates(make_df(), enabled = FALSE)
    testthat::expect_equal(res$n_masked, 0L)
    testthat::expect_identical(res$masked, make_df())
    testthat::expect_equal(nrow(res$real), 0L)
})

testthat::test_that("generalization = 'not_sensitive' is a byte-identical no-op", {
    local_sensitive_fixture("Panthera onca")
    res <- saira:::mask_sensitive_coordinates(
        make_df(), generalization = "not_sensitive"
    )
    testthat::expect_equal(res$n_masked, 0L)
    testthat::expect_identical(res$masked, make_df())
    testthat::expect_equal(nrow(res$real), 0L)
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

testthat::test_that("mask skips rows already generalized upstream (ADR-095)", {
    local_sensitive_fixture("Panthera onca")
    df <- data.frame(
        occurrenceID = c("u1", "u2"),
        scientificName = c("Panthera onca", "Panthera onca"),
        decimalLatitude = c("-23.5612", "-10.1234"),
        decimalLongitude = c("-46.6543", "-40.5678"),
        coordinateUncertaintyInMeters = c(NA, "1500"),
        dataGeneralizations = c("", "rounded to 0.1 deg upstream"),
        informationWithheld = c("", "publisher generalization"),
        stringsAsFactors = FALSE
    )
    res <- saira:::mask_sensitive_coordinates(
        df, generalization = "high", lang = "en"
    )
    # Row 1: untouched upstream -> Saira masks it.
    testthat::expect_equal(res$masked$decimalLatitude[1], "-23.6")
    # Row 2: upstream uncertainty >= 1000 m -> Saira leaves it intact.
    testthat::expect_equal(res$masked$decimalLatitude[2], "-10.1234")
    testthat::expect_equal(res$masked$decimalLongitude[2], "-40.5678")
    testthat::expect_equal(res$masked$coordinateUncertaintyInMeters[2], "1500")
    testthat::expect_equal(
        res$masked$dataGeneralizations[2], "rounded to 0.1 deg upstream"
    )
    testthat::expect_equal(
        res$masked$informationWithheld[2], "publisher generalization"
    )
    testthat::expect_equal(res$n_masked, 1L)
    testthat::expect_equal(res$n_skipped_already_masked, 1L)
    # Upstream-masked row must NOT leak into the researcher's private file
    # (we don't have the originals).
    testthat::expect_false("u2" %in% res$real$occurrenceID)
})

testthat::test_that("mask skips rows with dataGeneralizations even when uncertainty is small (ADR-095)", {
    # Camtrap DP scenario (PDF p.26): publisher ran round_coordinates(x, 3)
    # -> coordinatePrecision = 0.001, uncertainty ~150 m (below the 1000 m
    # numeric threshold), but `dataGeneralizations` populated by write_dwc().
    # The OR-gate must catch this case.
    local_sensitive_fixture("Panthera onca")
    df <- data.frame(
        occurrenceID = c("c1", "c2"),
        scientificName = c("Panthera onca", "Panthera onca"),
        decimalLatitude = c("-23.561", "-10.123"),
        decimalLongitude = c("-46.654", "-40.568"),
        # c1: 150 m uncertainty (below threshold) but dataGeneralizations set
        #     -> skip; c2: 50 m, no upstream signals -> mask normally.
        coordinateUncertaintyInMeters = c("150", "50"),
        dataGeneralizations = c("coordinates rounded to 0.001 deg", ""),
        stringsAsFactors = FALSE
    )
    res <- saira:::mask_sensitive_coordinates(
        df, generalization = "high", lang = "en"
    )
    # c1 untouched (preserves upstream metadata).
    testthat::expect_equal(res$masked$decimalLatitude[1], "-23.561")
    testthat::expect_equal(res$masked$coordinateUncertaintyInMeters[1], "150")
    testthat::expect_equal(
        res$masked$dataGeneralizations[1], "coordinates rounded to 0.001 deg"
    )
    # c2 masked (Saira applies the chosen tier).
    testthat::expect_equal(res$masked$decimalLatitude[2], "-10.1")
    testthat::expect_equal(res$n_masked, 1L)
    testthat::expect_equal(res$n_skipped_already_masked, 1L)
    testthat::expect_false("c1" %in% res$real$occurrenceID)
    testthat::expect_true("c2" %in% res$real$occurrenceID)
})

testthat::test_that("mask companion holds original coords + MMA category", {
    local_sensitive_fixture(c("Panthera onca", "Hippocampus reidi"))
    res <- saira:::mask_sensitive_coordinates(make_df(), lang = "en")

    testthat::expect_equal(res$real$occurrenceID, c("a1", "a4"))
    testthat::expect_equal(res$real$decimalLatitude, c("-23.5612", "-5.1234"))
    testthat::expect_equal(res$real$decimalLongitude, c("-46.6543", "-39.9876"))
    testthat::expect_equal(res$real$category, c("CR", "CR"))
    testthat::expect_setequal(
        names(res$real),
        c("occurrenceID", "scientificName", "category",
          "decimalLatitude", "decimalLongitude")
    )
})

# Per-species assessment (ADR-100) ---------------------------------------

testthat::test_that("resolve_row_tiers: string, map, and unassessed default", {
    sp <- c("A", "B", "C")
    # Single string applies to all (back-compat).
    testthat::expect_equal(
        saira:::resolve_row_tiers(sp, "high"),
        c("high", "high", "high")
    )
    # Named map: species absent from the map -> not_sensitive.
    testthat::expect_equal(
        saira:::resolve_row_tiers(sp, c(A = "extreme", C = "low")),
        c("extreme", "not_sensitive", "low")
    )
    # Empty / NULL -> all not_sensitive.
    testthat::expect_equal(
        saira:::resolve_row_tiers(sp, NULL),
        rep("not_sensitive", 3)
    )
    testthat::expect_equal(
        saira:::resolve_row_tiers(sp, list()),
        rep("not_sensitive", 3)
    )
})

testthat::test_that("sensitive_reason_statement maps each tier to its statement", {
    testthat::expect_match(
        saira:::sensitive_reason_statement("extreme", "en"), "Category 1"
    )
    testthat::expect_match(
        saira:::sensitive_reason_statement("high", "en"), "Category 2"
    )
    testthat::expect_match(
        saira:::sensitive_reason_statement("medium", "en"), "Category 3"
    )
    testthat::expect_match(
        saira:::sensitive_reason_statement("low", "en"), "Category 4"
    )
    # Tiers without a statement (and unknown) yield "".
    testthat::expect_equal(
        saira:::sensitive_reason_statement(c("not_sensitive", "bogus"), "en"),
        c("", "")
    )
    # Vectorized and language-aware.
    testthat::expect_match(
        saira:::sensitive_reason_statement("extreme", "pt"), "Categoria 1"
    )
})

testthat::test_that("mask applies a per-species grid map", {
    local_sensitive_fixture(c("Panthera onca", "Hippocampus reidi"))
    # Panthera -> high (0.1 deg), Hippocampus -> low (0.001 deg).
    res <- saira:::mask_sensitive_coordinates(
        make_df(),
        generalization = c("Panthera onca" = "high",
                           "Hippocampus reidi" = "low"),
        lang = "en"
    )
    testthat::expect_equal(res$n_masked, 2L)
    # Row 1 (Panthera) at the high grid.
    testthat::expect_equal(res$masked$decimalLatitude[1], "-23.6")
    testthat::expect_equal(res$masked$coordinatePrecision[1], "0.1")
    # Row 4 (Hippocampus) at the low grid.
    testthat::expect_equal(res$masked$decimalLatitude[4], "-5.123")
    testthat::expect_equal(res$masked$coordinatePrecision[4], "0.001")
    # Each row's dataGeneralizations carries its Chapman reason statement.
    testthat::expect_match(res$masked$dataGeneralizations[1], "Category 2")
    testthat::expect_match(res$masked$dataGeneralizations[4], "Category 4")
})

testthat::test_that("mask leaves a species mapped to not_sensitive as-held", {
    local_sensitive_fixture(c("Panthera onca", "Hippocampus reidi"))
    res <- saira:::mask_sensitive_coordinates(
        make_df(),
        generalization = c("Panthera onca" = "high",
                           "Hippocampus reidi" = "not_sensitive"),
        lang = "en"
    )
    # Only Panthera (row 1) is masked; Hippocampus (row 4) untouched.
    testthat::expect_equal(res$n_masked, 1L)
    testthat::expect_equal(res$masked$decimalLatitude[4], "-5.1234")
    testthat::expect_false("a4" %in% res$real$occurrenceID)
})

# generalization_map_preview + justification ----------------------------

testthat::test_that("mask appends the custodian justification to dataGeneralizations", {
    local_sensitive_fixture("Panthera onca")
    df <- data.frame(
        occurrenceID = "j1", scientificName = "Panthera onca",
        decimalLatitude = "-23.5612", decimalLongitude = "-46.6543",
        stringsAsFactors = FALSE
    )
    res <- saira:::mask_sensitive_coordinates(
        df, generalization = c("Panthera onca" = "high"), lang = "en",
        justification = "Documented poaching risk."
    )
    testthat::expect_match(res$masked$dataGeneralizations[1], "Documented poaching risk\\.$")
})

testthat::test_that("generalization_map_preview returns generalized points (+ border flag)", {
    local_sensitive_fixture("Panthera onca")
    df <- data.frame(
        scientificName = c("Panthera onca", "Felis catus"),
        decimalLatitude = c("-27.1700", "10.0"),
        decimalLongitude = c("-53.9000", "20.0"),
        stringsAsFactors = FALSE
    )
    prev <- saira:::generalization_map_preview(df, c("Panthera onca" = "extreme"))
    # Only the sensitive jaguar row is previewed.
    testthat::expect_equal(nrow(prev), 1L)
    testthat::expect_equal(prev$gen_lat, -27)
    testthat::expect_equal(prev$gen_lon, -54)
    # The Turvo jaguar crosses into Argentina at the extreme tier; the flag
    # needs the Natural Earth reference, so only assert it when available.
    if (!is.na(prev$crosses[1])) {
        testthat::expect_true(prev$crosses[1])
        testthat::expect_identical(prev$country_orig[1], "Brazil")
    }
})

testthat::test_that("generalization_map_preview is empty when nothing is masked", {
    local_sensitive_fixture("Panthera onca")
    df <- data.frame(
        scientificName = "Felis catus",
        decimalLatitude = "-27.17", decimalLongitude = "-53.9",
        stringsAsFactors = FALSE
    )
    prev <- saira:::generalization_map_preview(df, c("Panthera onca" = "extreme"))
    testthat::expect_equal(nrow(prev), 0L)
})

# shipped data integrity (Portarias 148/2022, 1.667/2026, 1.704/2026) ------

testthat::test_that("bundled sensitive_species.rds carries only canonical categories", {
    lk <- saira:::load_sensitive_species(force = TRUE)
    testthat::expect_gt(nrow(lk), 4000L)
    # The build canonicalizes the 2026 fauna label CR (PE) -> CR (PEX) and
    # excludes extinct tags; nothing else should reach the lookup.
    testthat::expect_setequal(
        unique(lk$category), c("VU", "EN", "CR", "CR (PEX)")
    )
    testthat::expect_false(any(c("CR (PE)", "EX", "RE", "EW") %in% lk$category))
    testthat::expect_equal(sum(duplicated(lk$match_key)), 0L)
})

testthat::test_that("2026 fauna refresh: terrestrial, aquatic and flora resolve", {
    # 1.704/2026 terrestrial, 1.667/2026 aquatic, 148/2022 flora; extinct -> NA.
    got <- saira:::sensitive_category_for(c(
        "Anomaloglossus apiau", "Crossodactylodes itambe",
        "Odontesthes bicudo", "Hippocampus reidi",
        "Aphelandra espirito-santensis", "Boana cymbalum"
    ))
    testthat::expect_equal(got[1], "EN")          # terrestrial amphibian
    testthat::expect_equal(got[2], "CR")          # wrap-recovered row (Nº 47)
    testthat::expect_equal(got[3], "EN")          # aquatic fish
    testthat::expect_equal(got[4], "VU")          # seahorse
    testthat::expect_equal(got[5], "EN")          # flora (unchanged)
    testthat::expect_true(is.na(got[6]))          # extinct (EX) excluded
})

# sensitive_source_for + load_sensitive_species source provenance ---------

testthat::test_that("sensitive_source_for returns the portaria, NA for non-listed", {
    species <- c("Panthera onca", "Harpia harpyja")
    fixture <- data.frame(
        scientificName = species,
        match_key = saira:::build_sensitive_match_keys(species),
        category = c("VU", "EN"),
        source = c("Portaria 1.704/2026", "Portaria 1.667/2026"),
        stringsAsFactors = FALSE
    )
    saira:::sensitive_species_cache$set(fixture, path = "test-fixture")
    withr::defer(saira:::sensitive_species_cache$reset())
    out <- saira:::sensitive_source_for(
        c("Panthera onca", "Harpia harpyja", "Canis familiaris")
    )
    testthat::expect_identical(
        out, c("Portaria 1.704/2026", "Portaria 1.667/2026", NA_character_)
    )
})

testthat::test_that("load_sensitive_species injects NA source for a pre-source RDS", {
    tmp <- withr::local_tempfile(fileext = ".rds")
    legacy <- data.frame(
        scientificName = "Panthera onca",
        match_key = saira:::build_sensitive_match_keys("Panthera onca"),
        category = "VU",
        stringsAsFactors = FALSE
    )
    saveRDS(legacy, tmp)
    testthat::local_mocked_bindings(
        resolve_sensitive_species_path = function() tmp, .package = "saira"
    )
    saira:::sensitive_species_cache$reset()
    withr::defer(saira:::sensitive_species_cache$reset())
    loaded <- saira:::load_sensitive_species(force = TRUE)
    testthat::expect_true("source" %in% names(loaded))
    testthat::expect_true(all(is.na(loaded$source)))
})

testthat::test_that("bundled sensitive_species.rds carries the source column", {
    saira:::sensitive_species_cache$reset()
    withr::defer(saira:::sensitive_species_cache$reset())
    loaded <- saira:::load_sensitive_species(force = TRUE)
    testthat::expect_true("source" %in% names(loaded))
    testthat::expect_false(anyNA(loaded$source))
    testthat::expect_true(all(
        loaded$source %in%
            c("Portaria 148/2022", "Portaria 1.704/2026", "Portaria 1.667/2026")
    ))
})
