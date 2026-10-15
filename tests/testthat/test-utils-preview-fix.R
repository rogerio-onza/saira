# Title: Tests for Preview Fix Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-10-08
# Version: 1.0

fix_frame <- function() {
    data.frame(
        occurrenceID = c("a1", "a2", "a2", "a4", "a5"),
        scientificName = c("Puma concolor", "", "Tapirus terrestris", NA, "Nasua nasua"),
        eventDate = c("2020-05-01", "31/02/2020", "2021-03-10/2021-01-02", "2019-07-04", "3020-01-01"),
        year = c("2020", "2020", "2021", "2018", "3020"),
        individualCount = c("2", "cerca de 10", "dois", "1", "4"),
        sex = c("male", "M/F", "male", "male", "female"),
        lifeStage = c("adult", "filhote", "filhote", "talvez", "adult"),
        stringsAsFactors = FALSE
    )
}

testthat::test_that("detect_preview_problems tells an ambiguous date from an unreadable one", {
    df <- data.frame(eventDate = c("03/04/2021", "sem data", "2020-01-01"), stringsAsFactors = FALSE)
    p <- detect_preview_problems(df, max_year = 2026)
    testthat::expect_setequal(paste(p$row, p$type), c("1 date_ambiguous", "2 date_unparsed"))
    testthat::expect_identical(unique(preview_problem_types$family[preview_problem_types$type %in% p$type]), "date")
})

testthat::test_that("detect_preview_problems finds each problem type once per cell", {
    p <- detect_preview_problems(fix_frame(), max_year = 2026)
    key <- paste(p$row, p$term, p$type)

    testthat::expect_true("2 sex vocab_unknown" %in% key)
    testthat::expect_true("2 lifeStage vocab_unknown" %in% key)
    testthat::expect_true("4 lifeStage vocab_unknown" %in% key)
    testthat::expect_true("2 eventDate date_unparsed" %in% key)
    testthat::expect_true("5 eventDate year_range" %in% key)
    testthat::expect_true("3 eventDate interval_inverted" %in% key)
    testthat::expect_true("4 year date_mismatch" %in% key)
    testthat::expect_true("2 individualCount count_invalid" %in% key)
    testthat::expect_true("2 scientificName required_empty" %in% key)
    testthat::expect_true("4 scientificName required_empty" %in% key)
    testthat::expect_true(all(c("2 occurrenceID id_duplicate", "3 occurrenceID id_duplicate") %in% key))
    testthat::expect_false(anyDuplicated(p[c("row", "term")]) > 0)

    sugg <- function(r, t) p$suggestion[p$row == r & p$term == t]
    testthat::expect_equal(sugg(2, "lifeStage"), "juvenile|nestling")
    testthat::expect_equal(sugg(2, "sex"), "mixed")
    testthat::expect_true(is.na(sugg(4, "lifeStage")))
    testthat::expect_equal(sugg(3, "eventDate"), "2021-01-02/2021-03-10")
    testthat::expect_equal(sugg(4, "year"), "2019")
    testthat::expect_equal(sugg(2, "individualCount"), "10")
    testthat::expect_true(is.na(sugg(3, "individualCount")))
})

testthat::test_that("detect_preview_problems returns an empty frame for clean or empty data", {
    clean <- data.frame(scientificName = "Puma concolor", eventDate = "2020-05-01",
                        stringsAsFactors = FALSE)
    testthat::expect_equal(nrow(detect_preview_problems(clean, max_year = 2026)), 0L)
    testthat::expect_equal(nrow(detect_preview_problems(data.frame())), 0L)
})

testthat::test_that("is_dwc_date_value accepts Darwin Core dates and rejects the rest", {
    ok <- c("2020", "2020-05", "2020-05-01", "2020-05-01T10:30Z", "2007-11-13/15",
            "2007-11-13/2007-12-01")
    bad <- c("31/02/2020", "2020-13", "2020-02-30", "maio 2020", "2020/2021/2022")
    testthat::expect_true(all(is_dwc_date_value(ok)))
    testthat::expect_false(any(is_dwc_date_value(bad)))
})

testthat::test_that("apply_preview_edits writes only over the value it replaces", {
    df <- fix_frame()
    edits <- data.frame(row = c(2L, 3L), term = c("individualCount", "individualCount"),
                        from = c("cerca de 10", "tres"), to = c("10", "3"),
                        stringsAsFactors = FALSE)
    out <- apply_preview_edits(df, edits)
    testthat::expect_equal(out$individualCount[2], "10")
    # The cell holds "dois", not "tres": a stale edit stays inert.
    testthat::expect_equal(out$individualCount[3], "dois")
})

testthat::test_that("apply_preview_edits lets a row edit win over a value-wide edit", {
    df <- fix_frame()
    edits <- data.frame(row = c(NA, 3L), term = "lifeStage", from = "filhote",
                        to = c("juvenile", "nestling"), stringsAsFactors = FALSE)
    out <- apply_preview_edits(df, edits)
    testthat::expect_equal(out$lifeStage[2:3], c("juvenile", "nestling"))

    cleared <- apply_preview_edits(df, data.frame(row = 4L, term = "lifeStage", from = "talvez",
                                                  to = "", stringsAsFactors = FALSE))
    testthat::expect_true(is.na(cleared$lifeStage[4]))
    testthat::expect_identical(apply_preview_edits(df, NULL), df)
})

testthat::test_that("apply_preview_edits fills an empty cell", {
    df <- fix_frame()
    edits <- data.frame(row = 4L, term = "scientificName", from = "", to = "Cerdocyon thous",
                        stringsAsFactors = FALSE)
    testthat::expect_equal(apply_preview_edits(df, edits)$scientificName[4], "Cerdocyon thous")
})

testthat::test_that("preview_problem_edit matches row edits first, then value-wide edits", {
    p <- detect_preview_problems(fix_frame(), max_year = 2026)
    edits <- data.frame(row = c(NA, 3L), term = "lifeStage", from = "filhote",
                        to = c("juvenile", "nestling"), stringsAsFactors = FALSE)
    hit <- preview_problem_edit(p, edits)
    at <- function(r) hit[p$row == r & p$term == "lifeStage"]
    testthat::expect_equal(at(2), 1L)
    testthat::expect_equal(at(3), 2L)
    testthat::expect_true(is.na(at(4)))
    testthat::expect_true(all(is.na(preview_problem_edit(p, edits[0, ]))))
})

testthat::test_that("next_open_problem skips the edited copies in table order", {
    # Table order 4, 9, 2, 7, 5. A bulk fix of 9 also fixed 2.
    shown <- c(4L, 9L, 2L, 7L, 5L)
    open <- c(TRUE, FALSE, FALSE, TRUE, TRUE)
    testthat::expect_equal(next_open_problem(9L, shown, open), 4L)
    # Nothing open below: the table stays where it is.
    testthat::expect_true(is.na(next_open_problem(5L, shown, open)))
    testthat::expect_true(is.na(next_open_problem(1L, shown, open)))
})

testthat::test_that("preview_fix_key groups a differing year by its suggestion too", {
    p <- data.frame(term = "year", type = "date_mismatch", value = "2019",
                    suggestion = c("2022", "2022", "2021"), stringsAsFactors = FALSE)
    key <- preview_fix_key(p)
    testthat::expect_identical(key[1], key[2])
    testthat::expect_false(identical(key[1], key[3]))
    # Other types group by value only.
    p$type <- "count_invalid"
    testthat::expect_length(unique(preview_fix_key(p)), 1L)
})

testthat::test_that("parse_preview_edit leaves an optional term empty", {
    for (term in c("individualCount", "year", "dateIdentified")) {
        out <- parse_preview_edit(term, "  ")
        testthat::expect_identical(out$value, "")
        testthat::expect_null(out$error)
    }
    for (term in c("basisOfRecord", "occurrenceID")) {
        testthat::expect_equal(parse_preview_edit(term, "")$error, "preview_fix_err_blank")
    }
    # eventDate is recommended, and the Export does not block a blank one.
    testthat::expect_identical(parse_preview_edit("eventDate", "")$value, "")
})

testthat::test_that("parse_preview_edit takes a basisOfRecord term in any case", {
    testthat::expect_identical(parse_preview_edit("basisOfRecord", "humanobservation")$value, "HumanObservation")
    testthat::expect_identical(parse_preview_edit("basisOfRecord", "Coleta")$error, "preview_fix_err_bor")
})

testthat::test_that("parse_preview_edit checks the value for each term", {
    testthat::expect_equal(parse_preview_edit("sex", " Male ")$value, "male")
    testthat::expect_equal(parse_preview_edit("lifeStage", "")$value, "")
    testthat::expect_equal(parse_preview_edit("sex", "macho")$error, "preview_fix_err_vocab")
    testthat::expect_equal(parse_preview_edit("scientificName", "  ")$error, "preview_fix_err_blank")
    testthat::expect_equal(parse_preview_edit("eventDate", "2020-05-01")$value, "2020-05-01")
    testthat::expect_equal(parse_preview_edit("eventDate", "nunca")$error, "preview_fix_err_date")
    testthat::expect_equal(parse_preview_edit("individualCount", "10")$value, "10")
    testthat::expect_equal(parse_preview_edit("individualCount", "10.5")$error, "preview_fix_err_count")
    testthat::expect_equal(parse_preview_edit("month", "07")$value, "7")
    testthat::expect_equal(parse_preview_edit("month", "13")$error, "preview_fix_err_number")
    testthat::expect_equal(parse_preview_edit("occurrenceID", "a1", taken = "a1")$error,
                           "preview_fix_err_id_taken")
    testthat::expect_equal(parse_preview_edit("occurrenceID", "a9", taken = "a1")$value, "a9")
})

testthat::test_that("preview_problem_banner flags only a large share of one problem", {
    p <- data.frame(row = 1:30, term = "eventDate", type = "date_unparsed",
                    value = rep(c("05/2020", "06/2020"), c(20, 10)), stringsAsFactors = FALSE)
    b <- preview_problem_banner(p, n_rows = 100)
    testthat::expect_equal(b$count, 30L)
    testthat::expect_equal(b$example, "05/2020")
    testthat::expect_null(preview_problem_banner(p, n_rows = 1000))
    testthat::expect_null(preview_problem_banner(p[1:10, ], n_rows = 20))
})

testthat::test_that("the banner for blank cells has no example", {
    p <- data.frame(row = 1:30, term = "scientificName", type = "required_empty",
                    value = "", stringsAsFactors = FALSE)
    b <- preview_problem_banner(p, n_rows = 50)
    testthat::expect_identical(b$type, "required_empty")
    testthat::expect_identical(b$example, "")
})

testthat::test_that("a scientificName correction updates the derived taxon terms", {
    df <- data.frame(
        scientificName = c("", "Puma concolor", ""),
        genus = c("", "Puma", "Leopardus"),
        specificEpithet = c("", "concolor", ""),
        taxonRank = c("", "species", ""),
        stringsAsFactors = FALSE
    )
    edits <- data.frame(
        row = c(1L, 2L, 3L), term = "scientificName",
        from = c("", "Puma concolor", ""),
        to = c("Nasua nasua (Linnaeus, 1766)", "Nasua", "Leopardus pardalis"),
        stringsAsFactors = FALSE
    )
    out <- apply_preview_edits(df, edits)
    testthat::expect_equal(out$scientificName, c("Nasua nasua", "Nasua", "Leopardus pardalis"))
    testthat::expect_equal(out$genus, c("Nasua", "Nasua", "Leopardus"))
    testthat::expect_equal(out$specificEpithet, c("nasua", NA, "pardalis"))
    testthat::expect_equal(out$taxonRank, c("species", "genus", "species"))
    testthat::expect_equal(out$scientificNameAuthorship, c("(Linnaeus, 1766)", NA, NA))
    # No empty column for a term that no new name uses.
    testthat::expect_false("infraspecificEpithet" %in% names(out))
})

testthat::test_that("parse_preview_edit refuses a date whose day and month can swap", {
    testthat::expect_identical(parse_preview_edit("eventDate", "05/07/2016")$error, "preview_fix_err_date_ambiguous")
    testthat::expect_identical(parse_preview_edit("eventDate", "25/07/2016")$value, "2016-07-25")
    testthat::expect_identical(parse_preview_edit("eventDate", "05/05/2016")$value, "2016-05-05")
})

testthat::test_that("detect_preview_problems checks eventTime, uncertainty, coordinates and names", {
    df <- data.frame(
        scientificName = c("Panthera onca", "P. onca", "Panthera onca x Panthera pardus", "indet."),
        scientificNameAuthorship = c("(Linnaeus 1758", "", "", ""),
        eventTime = c("08:30 PM", "14:70", "12:00", "12h30"),
        coordinateUncertaintyInMeters = c("30 m", "0", "100", "1.000"),
        decimalLatitude = c("-23.6°", "vinte e dois", "-46,6559", "95"),
        stringsAsFactors = FALSE
    )
    p <- detect_preview_problems(df, max_year = 2026)
    got <- function(term) { g <- p[p$term == term, c("row", "type", "suggestion")]; g[order(g$row), ] }

    testthat::expect_identical(got("eventTime")$suggestion, c("20:30", NA, "12:30"))
    testthat::expect_identical(got("coordinateUncertaintyInMeters")$suggestion, c("30", NA, "1000"))
    testthat::expect_identical(got("decimalLatitude")$row, c(1L, 2L, 4L))
    testthat::expect_identical(got("decimalLatitude")$suggestion[[1]], "-23.6")
    testthat::expect_identical(got("scientificName")$type,
                               c("name_abbreviated", "name_hybrid", "name_placeholder"))
    testthat::expect_identical(got("scientificNameAuthorship")$type, "name_authorship")
    testthat::expect_true(all(p$family[startsWith(p$type, "name_")] == "name"))
})

testthat::test_that("parse_preview_edit converts eventTime, uncertainty and coordinates", {
    testthat::expect_identical(parse_preview_edit("eventTime", "8:30 pm")$value, "20:30")
    testthat::expect_identical(parse_preview_edit("eventTime", "25:00")$error, "preview_fix_err_time")
    testthat::expect_identical(parse_preview_edit("coordinateUncertaintyInMeters", "30 m")$value, "30")
    testthat::expect_identical(parse_preview_edit("coordinateUncertaintyInMeters", "-5")$error,
                               "preview_fix_err_uncertainty")
    testthat::expect_identical(parse_preview_edit("decimalLatitude", "-23,5")$value, "-23,5")
    testthat::expect_identical(parse_preview_edit("decimalLatitude", "91")$error, "preview_fix_err_coord")
})

test_that("a threat category in country is flagged (B33)", {
  df <- data.frame(country = c("VU", "Brasil", "CR", "en"), stringsAsFactors = FALSE)
  p <- detect_preview_problems(df)
  expect_equal(p$row[p$type == "country_threat_code"], c(1L, 4L))
})

test_that("a count of 0 with occurrenceStatus present is flagged (D07)", {
  df <- data.frame(individualCount = c("0", "0", "3", "0"),
                   occurrenceStatus = c("present", "absent", "present", ""),
                   stringsAsFactors = FALSE)
  p <- detect_preview_problems(df)
  expect_equal(p$row[p$type == "count_present_zero"], 1L)
  expect_false(p$bulk[p$type == "count_present_zero"])
})

test_that("absent in occurrenceStatus corrects a count of 0 with present (D07)", {
  df <- data.frame(individualCount = c("0", "0", "3"),
                   occurrenceStatus = c("present", "present", "present"),
                   stringsAsFactors = FALSE)
  p <- detect_preview_problems(df)
  edits <- data.frame(row = 1L, term = "occurrenceStatus", from = "present", to = "absent",
                      stringsAsFactors = FALSE)
  hit <- preview_problem_edit(p, edits)
  expect_equal(hit, c(1L, NA_integer_))
  # The edit reaches its row only, not row 3, which is right as present.
  expect_equal(apply_preview_edits(df, edits)$occurrenceStatus, c("absent", "present", "present"))
  # Another status value does not close the problem.
  edits$to <- "present"
  expect_true(all(is.na(preview_problem_edit(p, edits))))
})

test_that("country and countryCode that disagree are flagged (B04)", {
  df <- data.frame(country = c("Argentina", "Brasil", "Brasil"),
                   countryCode = c("BR", "BR", ""), stringsAsFactors = FALSE)
  p <- detect_preview_problems(df)
  expect_equal(p$row[p$type == "country_conflict"], 1L)
  expect_false(p$bulk[p$type == "country_conflict"])
})

testthat::test_that("detect_preview_problems flags a (0, 0) filler on both axes (B50)", {
    df <- data.frame(decimalLatitude = c("0", "0", "", "-23.5"),
                     decimalLongitude = c("0,0", "-46.6", "0", "0"),
                     stringsAsFactors = FALSE)
    p <- detect_preview_problems(df)
    z <- p[p$type == "coord_zero", ]
    testthat::expect_equal(z$row[z$term == "decimalLatitude"], 1L)
    testthat::expect_equal(sort(z$row[z$term == "decimalLongitude"]), c(1L, 3L))
})
