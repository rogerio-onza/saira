# Title: Tests for Controlled Vocabulary Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-10-08
# Version: 1.0

testthat::test_that("map_vocabulary_values converts known spreadsheet words", {
    testthat::expect_equal(
        map_vocabulary_values("sex", c("M", " fêmea ", "Male", "I", "♂")),
        c("male", "female", "male", "indeterminate", "male")
    )
    testthat::expect_equal(
        map_vocabulary_values("lifeStage", c("Adulto", "juv.", "ninhego", "girino")),
        c("adult", "juvenile", "nestling", "tadpole")
    )
    testthat::expect_equal(
        map_vocabulary_values("occurrenceStatus", c("visto", "não visto", "present")),
        c("present", "absent", "present")
    )
})

testthat::test_that("map_vocabulary_values keeps unknown and ambiguous values for the user", {
    testthat::expect_equal(
        map_vocabulary_values("lifeStage", c("filhote", "talvez")),
        c("filhote", "talvez")
    )
    testthat::expect_equal(map_vocabulary_values("sex", c(" M/F ")), "M/F")
    testthat::expect_equal(
        map_vocabulary_values("sex", c(NA, "", "  ")),
        rep(NA_character_, 3)
    )
    testthat::expect_identical(map_vocabulary_values("sex", NULL), character(0))
})

testthat::test_that("vocabulary_suggestions offers every reading of an ambiguous value", {
    testthat::expect_setequal(vocabulary_suggestions("lifeStage", "Filhote"),
                              c("juvenile", "nestling"))
    testthat::expect_equal(vocabulary_suggestions("sex", "m/f"), "mixed")
    testthat::expect_length(vocabulary_suggestions("sex", "talvez"), 0L)
})

testthat::test_that("vocabulary_concepts lists the GBIF concepts", {
    testthat::expect_setequal(vocabulary_concepts("occurrenceStatus"), c("present", "absent"))
    testthat::expect_length(vocabulary_concepts("sex"), 5L)
    testthat::expect_true(all(c("adult", "juvenile", "nestling") %in% vocabulary_concepts("lifeStage")))
})
