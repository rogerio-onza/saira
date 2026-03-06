# Title: Tests for Common Utility Functions
# Author: Rogerio Nunes Oliveira
# Date: 2026-03-06
# Version: 1.0

# create_rds_cache --------------------------------------------------------

testthat::test_that("create_rds_cache returns NULL before first set", {
    cache <- saira:::create_rds_cache("test")
    testthat::expect_null(cache$get())
})

testthat::test_that("create_rds_cache stores and retrieves a value", {
    cache <- saira:::create_rds_cache("test")
    cache$set(list(a = 1, b = 2))
    testthat::expect_equal(cache$get(), list(a = 1, b = 2))
})

testthat::test_that("create_rds_cache reset clears value and path", {
    cache <- saira:::create_rds_cache("test")
    cache$set(42L, path = "/some/path.rds")
    cache$reset()
    testthat::expect_null(cache$get())
    testthat::expect_null(cache$state()$path)
    testthat::expect_equal(cache$state()$load_count, 0L)
})

testthat::test_that("create_rds_cache state tracks load_count and has_value", {
    cache <- saira:::create_rds_cache("test")
    testthat::expect_false(cache$state()$has_value)
    testthat::expect_equal(cache$state()$load_count, 0L)

    cache$set("first")
    testthat::expect_true(cache$state()$has_value)
    testthat::expect_equal(cache$state()$load_count, 1L)

    cache$set("second")
    testthat::expect_equal(cache$state()$load_count, 2L)
})

testthat::test_that("create_rds_cache stores path when provided", {
    cache <- saira:::create_rds_cache("test")
    cache$set("value", path = "/mock/path.rds")
    testthat::expect_equal(cache$state()$path, "/mock/path.rds")
})

testthat::test_that("create_rds_cache instances are independent", {
    cache_a <- saira:::create_rds_cache("a")
    cache_b <- saira:::create_rds_cache("b")
    cache_a$set("alpha")
    testthat::expect_null(cache_b$get())
    testthat::expect_equal(cache_a$get(), "alpha")
})

# is_blank_value ----------------------------------------------------------

testthat::test_that("is_blank_value returns TRUE for NULL", {
    testthat::expect_true(saira:::is_blank_value(NULL))
})

testthat::test_that("is_blank_value returns TRUE for NA", {
    testthat::expect_true(saira:::is_blank_value(NA))
    testthat::expect_true(saira:::is_blank_value(NA_character_))
    testthat::expect_true(saira:::is_blank_value(NA_real_))
})

testthat::test_that("is_blank_value returns TRUE for empty string", {
    testthat::expect_true(saira:::is_blank_value(""))
})

testthat::test_that("is_blank_value returns TRUE for whitespace-only string", {
    testthat::expect_true(saira:::is_blank_value("   "))
    testthat::expect_true(saira:::is_blank_value("\t"))
    testthat::expect_true(saira:::is_blank_value("\n"))
})

testthat::test_that("is_blank_value returns TRUE for length-0 vector", {
    testthat::expect_true(saira:::is_blank_value(character(0)))
    testthat::expect_true(saira:::is_blank_value(integer(0)))
})

testthat::test_that("is_blank_value returns FALSE for non-blank values", {
    testthat::expect_false(saira:::is_blank_value("a"))
    testthat::expect_false(saira:::is_blank_value("  x  "))
    testthat::expect_false(saira:::is_blank_value(0))
    testthat::expect_false(saira:::is_blank_value(FALSE))
})

# normalize_for_matching --------------------------------------------------

testthat::test_that("normalize_for_matching lowercases input", {
    testthat::expect_equal(saira:::normalize_for_matching("LATITUDE"), "latitude")
})

testthat::test_that("normalize_for_matching trims whitespace", {
    testthat::expect_equal(saira:::normalize_for_matching("  lat  "), "lat")
})

testthat::test_that("normalize_for_matching converts accented chars to ASCII", {
    result <- saira:::normalize_for_matching("La\u00E7\u00E3o")
    testthat::expect_false(grepl("[^\x01-\x7F]", result))
})

testthat::test_that("normalize_for_matching replaces non-alphanumeric with space", {
    result <- saira:::normalize_for_matching("data-raw_file.csv")
    testthat::expect_false(grepl("[-_.]", result))
})

testthat::test_that("normalize_for_matching propagates NA input as NA", {
    result <- saira:::normalize_for_matching(NA_character_)
    testthat::expect_true(is.na(result))
})

# tokenize_for_matching ---------------------------------------------------

testthat::test_that("tokenize_for_matching splits on non-alphanumeric separators", {
    tokens <- saira:::tokenize_for_matching("scientific Name")
    testthat::expect_equal(tokens, c("scientific", "name"))
})

testthat::test_that("tokenize_for_matching returns character(0) for blank input", {
    testthat::expect_equal(saira:::tokenize_for_matching(""), character(0))
    testthat::expect_equal(saira:::tokenize_for_matching("   "), character(0))
    testthat::expect_equal(saira:::tokenize_for_matching(NA_character_), character(0))
})

testthat::test_that("tokenize_for_matching drops empty tokens from splitting", {
    tokens <- saira:::tokenize_for_matching("a  b   c")
    testthat::expect_equal(tokens, c("a", "b", "c"))
})

testthat::test_that("tokenize_for_matching handles multi-separator strings", {
    tokens <- saira:::tokenize_for_matching("decimal_Latitude-2")
    testthat::expect_equal(tokens, c("decimal", "latitude", "2"))
})
