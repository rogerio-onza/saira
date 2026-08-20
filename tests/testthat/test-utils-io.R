# Title: Tests for I/O date parsing utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-14
# Version: 1.0

expected_year_from_two_digits <- function(two_digits) {
    current_yy <- as.integer(format(Sys.Date(), "%y"))
    ifelse(
        two_digits <= current_yy,
        2000L + two_digits,
        1900L + two_digits
    )
}

write_temp_text_file <- function(lines, fileext = ".csv") {
    path <- tempfile(fileext = fileext)
    writeLines(lines, path, useBytes = TRUE)
    path
}

testthat::test_that("detect_delimiter detects comma semicolon tab and tab tie rule", {
    comma_file <- write_temp_text_file(c("a,b", "1,2"))
    semicolon_file <- write_temp_text_file(c("a;b", "1;2"))
    tab_file <- write_temp_text_file(c("a\tb", "1\t2"))
    tie_file <- write_temp_text_file(c("a,b;c\td", "1,2;3\t4"))
    on.exit(unlink(c(comma_file, semicolon_file, tab_file, tie_file)), add = TRUE)

    testthat::expect_identical(detect_delimiter(comma_file), ",")
    testthat::expect_identical(detect_delimiter(semicolon_file), ";")
    testthat::expect_identical(detect_delimiter(tab_file), "\t")
    testthat::expect_identical(detect_delimiter(tie_file), "\t")
})

testthat::test_that("detect_encoding returns UTF-8 when BOM is present", {
    bom_file <- tempfile(fileext = ".csv")
    on.exit(unlink(bom_file), add = TRUE)

    bom <- as.raw(c(0xEF, 0xBB, 0xBF))
    payload <- charToRaw("col1,col2\nA,B\n")
    writeBin(c(bom, payload), bom_file)

    testthat::expect_identical(detect_encoding(bom_file), "UTF-8")
})

testthat::test_that("strip_bom removes UTF-8 BOM prefix", {
    strip_bom <- saira:::strip_bom
    with_bom <- paste0("\ufeff", "scientificName;eventDate")
    without_bom <- "scientificName;eventDate"

    testthat::expect_identical(strip_bom(with_bom), without_bom)
    testthat::expect_identical(strip_bom(without_bom), without_bom)
})

testthat::test_that("detect_delimiter handles UTF-8 BOM and empty first line", {
    bom_file <- tempfile(fileext = ".csv")
    empty_file <- tempfile(fileext = ".csv")
    on.exit(unlink(c(bom_file, empty_file)), add = TRUE)

    bom <- as.raw(c(0xEF, 0xBB, 0xBF))
    payload <- charToRaw("col1;col2\nA;B\n")
    writeBin(c(bom, payload), bom_file)
    writeLines(character(0), empty_file, useBytes = TRUE)

    testthat::expect_identical(detect_delimiter(bom_file), ";")
    testthat::expect_identical(detect_delimiter(empty_file), ",")
})

testthat::test_that("read_biodiversity_csv reads file and repairs duplicate names", {
    input_file <- write_temp_text_file(
        c(
            "name;name;count",
            "A;B;1",
            "C;D;2"
        )
    )
    on.exit(unlink(input_file), add = TRUE)

    out <- read_biodiversity_csv(input_file)

    testthat::expect_s3_class(out, "data.frame")
    testthat::expect_identical(detect_delimiter(input_file), ";")
    testthat::expect_equal(nrow(out), 2L)
    testthat::expect_identical(anyDuplicated(names(out)), 0L)
    testthat::expect_equal(out[[1]], c("A", "C"))
    testthat::expect_equal(out[[2]], c("B", "D"))
    testthat::expect_equal(as.integer(out[[3]]), c(1L, 2L))
})

testthat::test_that("parse_dates_to_iso parses supported formats and keeps invalid as NA", {
    input <- c(
        "2023-12-25",
        "25/12/2023",
        "25-12-2023",
        "25.12.2023",
        "25/12/23",
        "31/02/2023",
        "foo",
        NA_character_,
        ""
    )

    yy_year <- expected_year_from_two_digits(23L)
    expected <- c(
        "2023-12-25",
        "2023-12-25",
        "2023-12-25",
        "2023-12-25",
        sprintf("%04d-12-25", yy_year),
        NA_character_,
        NA_character_,
        NA_character_,
        NA_character_
    )

    out <- parse_dates_to_iso(input)
    testthat::expect_identical(out, expected)
})

testthat::test_that("read_biodiversity_csv retries Latin-1 when UTF-8 detection misses late encoding", {
    header <- "MUNICIPALITY,COUNT"
    ascii_rows <- paste0("CityASCII_", seq_len(100), ",", seq_len(100))
    ascii_payload <- charToRaw(paste(c(header, ascii_rows), collapse = "\n"))
    # "Pacaj\xe1,1\n" — 0xe1 is the Latin-1 byte for á (a-acute)
    latin1_row <- c(charToRaw("Pacaj"), as.raw(0xe1L), charToRaw(",1\n"))

    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp), add = TRUE)
    writeBin(c(ascii_payload, charToRaw("\n"), latin1_row), tmp)

    testthat::expect_warning(
        out <- read_biodiversity_csv(tmp),
        "retrying with alternative encoding"
    )

    testthat::expect_s3_class(out, "data.frame")
    testthat::expect_equal(nrow(out), 101L)
    converted <- iconv(out$MUNICIPALITY, from = "UTF-8", to = "UTF-8")
    testthat::expect_false(any(is.na(converted) & !is.na(out$MUNICIPALITY)))
    testthat::expect_equal(out$MUNICIPALITY[101L], "Pacajá")
})

testthat::test_that("find_first_invalid_utf8_cell locates first invalid cell and returns NULL for clean df", {
    find_cell <- saira:::find_first_invalid_utf8_cell

    bad_string <- rawToChar(c(charToRaw("Pacaj"), as.raw(0xe1L)))
    df_bad <- data.frame(A = c("valid", bad_string), B = c("x", "y"), stringsAsFactors = FALSE)

    result <- find_cell(df_bad)
    testthat::expect_identical(result$column, "A")
    testthat::expect_identical(result$row, 2L)

    df_clean <- data.frame(A = c("Pacajá", "normal"), stringsAsFactors = FALSE)
    testthat::expect_null(find_cell(df_clean))

    df_numeric <- data.frame(x = 1:3)
    testthat::expect_null(find_cell(df_numeric))
})

testthat::test_that("parse_dates_to_iso applies dynamic cutoff for DD/MM/YY", {
    current_yy <- as.integer(format(Sys.Date(), "%y"))
    next_yy <- as.integer((current_yy + 1L) %% 100L)

    input <- c(
        sprintf("18/05/%02d", current_yy),
        sprintf("18/05/%02d", next_yy),
        "18/05/99",
        "18/05/09"
    )

    expected_years <- c(
        expected_year_from_two_digits(current_yy),
        expected_year_from_two_digits(next_yy),
        expected_year_from_two_digits(99L),
        expected_year_from_two_digits(9L)
    )
    expected <- sprintf("%04d-05-18", expected_years)

    out <- parse_dates_to_iso(input)
    testthat::expect_identical(out, expected)
})

testthat::test_that("parse_dates_to_iso handles factors and empty inputs", {
    input <- factor(c("25/12/2023", "foo", ""))
    out <- parse_dates_to_iso(input)
    testthat::expect_identical(out, c("2023-12-25", NA_character_, NA_character_))

    out_empty <- parse_dates_to_iso(character())
    testthat::expect_identical(out_empty, character())
})

testthat::test_that("parse_dates_to_iso normalises year-first, month-year and dates carrying a time", {
    input <- c(
        "2023/12/25",
        "2023.12.25",
        "25/12/2023 14:30",
        "25/12/2023 9:05:30",
        "2023-12-25T10:00:00Z",
        "12/2023",
        "2023/12",
        "13/2023"
    )

    expected <- c(
        "2023-12-25",
        "2023-12-25",
        "2023-12-25T14:30",
        "2023-12-25T09:05:30",
        "2023-12-25T10:00:00Z",
        "2023-12",
        "2023-12",
        NA_character_
    )

    testthat::expect_identical(parse_dates_to_iso(input), expected)
})

testthat::test_that("parse_dates_to_iso keeps the day-first vote when the column carries times", {
    # 25 > 12 proves day-first, and the vote has to survive the time suffix.
    input <- c("25/12/2023 08:00", "05/06/2023 08:00")
    testthat::expect_identical(
        parse_dates_to_iso(input),
        c("2023-12-25T08:00", "2023-06-05T08:00")
    )
})

testthat::test_that("date_year_issues flags future and ancient years without touching valid ones", {
    df <- data.frame(
        eventDate = c("2023-12-25", "2098-05-01", "1450-01-01", "20231225"),
        modified = rep("2024-01-01", 4),
        year = c("2023", "2098", "1450", "2023"),
        stringsAsFactors = FALSE
    )

    issues <- saira:::date_year_issues(df, max_year = 2026L)

    testthat::expect_identical(issues$count, 4L)
    testthat::expect_identical(issues$future_count, 2L)
    testthat::expect_identical(issues$ancient_count, 2L)
    testthat::expect_setequal(issues$columns, c("eventDate", "year"))
    testthat::expect_identical(issues$sample$row, c(2L, 2L, 3L, 3L))
    testthat::expect_true(all(issues$sample$value %in% c("2098-05-01", "2098", "1450-01-01", "1450")))
})

testthat::test_that("date_year_issues reads both halves of an interval and ignores clean frames", {
    df <- data.frame(
        eventDate = c("2010-01/2098-03", "2010-01/2012-03"),
        stringsAsFactors = FALSE
    )
    issues <- saira:::date_year_issues(df, max_year = 2026L)
    testthat::expect_identical(issues$count, 1L)
    testthat::expect_identical(issues$sample$row, 1L)

    clean <- saira:::date_year_issues(
        data.frame(eventDate = c("2024-01-01", ""), stringsAsFactors = FALSE),
        max_year = 2026L
    )
    testthat::expect_identical(clean$count, 0L)
    testthat::expect_identical(nrow(clean$sample), 0L)

    no_cols <- saira:::date_year_issues(data.frame(x = 1:3))
    testthat::expect_identical(no_cols$count, 0L)
})
