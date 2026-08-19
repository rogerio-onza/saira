# Title: Tests for Mapping Utilities
# Author: RogÃ©rio Nunes Oliveira
# Date: 2026-02-11
# Version: 1.0

reset_synonyms_cache <- function() saira:::reset_dwc_synonyms_cache()
synonyms_cache_state <- function() saira:::dwc_synonyms_cache_state()

testthat::test_that("normalize_semicolon_tokens converts semicolon lists to pipe", {
    x <- c(
        "Alexandra Cravino; Alejandro Brazeiro",
        "Native Forest, Grassland, Afforestation",
        " ; ",
        "",
        NA_character_
    )

    out <- normalize_semicolon_tokens(x)

    testthat::expect_identical(out[[1]], "Alexandra Cravino | Alejandro Brazeiro")
    testthat::expect_identical(out[[2]], "Native Forest, Grassland, Afforestation")
    testthat::expect_true(is.na(out[[3]]))
    testthat::expect_true(is.na(out[[4]]))
    testthat::expect_true(is.na(out[[5]]))

    # Vectorized fast/multi-path boundary: single values are trimmed, a literal
    # pipe is NOT a separator (only ";" is), and empty ";" tokens are dropped.
    out2 <- normalize_semicolon_tokens(c("  solo  ", "p|q", "a;;b"))
    testthat::expect_identical(out2, c("solo", "p|q", "a | b"))
})

testthat::test_that("collapse_mapped_values preserves token order and ignores comma as delimiter", {
    df <- data.frame(
        col_a = c(
            "B; A",
            "Native Forest, Grassland, Afforestation",
            NA_character_
        ),
        col_b = c(
            "C",
            "Silviculture",
            "X; Y"
        ),
        stringsAsFactors = FALSE
    )

    out <- collapse_mapped_values(df, cols = c("col_a", "col_b"))

    testthat::expect_identical(out[[1]], "B | A | C")
    testthat::expect_identical(out[[2]], "Native Forest, Grassland, Afforestation | Silviculture")
    testthat::expect_identical(out[[3]], "X | Y")
})

testthat::test_that("derive_dynprops_key normalizes accents and special chars", {
    testthat::expect_identical(saira:::derive_dynprops_key("Localidade"), "localidade")
    testthat::expect_identical(saira:::derive_dynprops_key("ÁreaProtegida"), "areaprotegida")
    testthat::expect_identical(saira:::derive_dynprops_key("tipo da área"), "tipo_da_area")
    testthat::expect_identical(saira:::derive_dynprops_key("a__b___c"), "a_b_c")
    testthat::expect_identical(saira:::derive_dynprops_key("--  --"), "field")
    testthat::expect_identical(saira:::derive_dynprops_key(""), "field")
    # Vectorized
    testthat::expect_identical(
        saira:::derive_dynprops_key(c("Foo", "Bar Baz")),
        c("foo", "bar_baz")
    )
})

testthat::test_that("json_escape_string handles all JSON escape categories", {
    testthat::expect_identical(saira:::json_escape_string("hello"), "hello")
    testthat::expect_identical(saira:::json_escape_string("a\"b"), "a\\\"b")
    testthat::expect_identical(saira:::json_escape_string("a\\b"), "a\\\\b")
    testthat::expect_identical(saira:::json_escape_string("a\nb"), "a\\nb")
    testthat::expect_identical(saira:::json_escape_string("a\rb"), "a\\rb")
    testthat::expect_identical(saira:::json_escape_string("a\tb"), "a\\tb")
    testthat::expect_identical(saira:::json_escape_string("a\bb"), "a\\bb")
    testthat::expect_identical(saira:::json_escape_string("a\fb"), "a\\fb")
    # Other control char (BEL = 0x07) -> 
    testthat::expect_identical(saira:::json_escape_string("a\007b"), "a\\u0007b")
    testthat::expect_true(is.na(saira:::json_escape_string(NA_character_)))
    # UTF-8 multi-byte preserved
    testthat::expect_identical(saira:::json_escape_string("área"), "área")
})

testthat::test_that("build_dynamic_properties_json builds strict TDWG JSON", {
    df <- data.frame(
        protectarea = c("yes", "yes", "", NA),
        protect_area_type = c("IV", "", NA, NA),
        stringsAsFactors = FALSE
    )

    out <- build_dynamic_properties_json(df, c("protectarea", "protect_area_type"))

    testthat::expect_identical(
        out[[1]], "{\"protectarea\":\"yes\",\"protect_area_type\":\"IV\"}"
    )
    testthat::expect_identical(out[[2]], "{\"protectarea\":\"yes\"}")
    # Both blank in row 3 and 4 -> empty string, NOT "{}"
    testthat::expect_identical(out[[3]], "")
    testthat::expect_identical(out[[4]], "")
})

testthat::test_that("build_dynamic_properties_json applies custom keys via override", {
    df <- data.frame(
        col_a = c("yes", "no"),
        col_b = c("IV", "II"),
        stringsAsFactors = FALSE
    )
    out <- build_dynamic_properties_json(
        df, c("col_a", "col_b"),
        keys = list(col_a = "protect_area", col_b = "protect_area_type")
    )
    testthat::expect_identical(
        out[[1]],
        "{\"protect_area\":\"yes\",\"protect_area_type\":\"IV\"}"
    )
})

testthat::test_that("build_dynamic_properties_json single column also emits JSON, not raw", {
    df <- data.frame(x = c("foo", "", NA), stringsAsFactors = FALSE)
    out <- build_dynamic_properties_json(df, "x")
    testthat::expect_identical(out[[1]], "{\"x\":\"foo\"}")
    testthat::expect_identical(out[[2]], "")
    testthat::expect_identical(out[[3]], "")
})

testthat::test_that("build_dynamic_properties_json escapes special characters in values", {
    df <- data.frame(
        note = c("she said \"hi\"", "line1\nline2", "back\\slash"),
        stringsAsFactors = FALSE
    )
    out <- build_dynamic_properties_json(df, "note")
    testthat::expect_identical(out[[1]], "{\"note\":\"she said \\\"hi\\\"\"}")
    testthat::expect_identical(out[[2]], "{\"note\":\"line1\\nline2\"}")
    testthat::expect_identical(out[[3]], "{\"note\":\"back\\\\slash\"}")
})

testthat::test_that("build_dynamic_properties_json warns on key collision and first wins", {
    df <- data.frame(
        `area-protegida` = "yes",
        `area_protegida` = "no",
        check.names = FALSE,
        stringsAsFactors = FALSE
    )
    out <- testthat::expect_warning(
        build_dynamic_properties_json(df, c("area-protegida", "area_protegida")),
        regexp = "key collision"
    )
    # First column wins; second is dropped from row's JSON
    testthat::expect_identical(out[[1]], "{\"area_protegida\":\"yes\"}")
})

testthat::test_that("build_dynamic_properties_json key override falls back to auto when invalid", {
    df <- data.frame(x = "v", stringsAsFactors = FALSE)
    # Override with double quote -> auto fallback
    out <- build_dynamic_properties_json(
        df, "x", keys = list(x = "bad\"key")
    )
    testthat::expect_identical(out[[1]], "{\"x\":\"v\"}")
    # Override blank -> auto fallback
    out2 <- build_dynamic_properties_json(df, "x", keys = list(x = "  "))
    testthat::expect_identical(out2[[1]], "{\"x\":\"v\"}")
})

testthat::test_that("build_dynamic_properties_json errors on missing column", {
    df <- data.frame(a = "x", stringsAsFactors = FALSE)
    testthat::expect_error(
        build_dynamic_properties_json(df, c("a", "missing")),
        regexp = "Columns not found"
    )
})

testthat::test_that("build_processed_mapping_df dispatches dynamicProperties before single-column branch", {
    df <- data.frame(
        a = c("yes", "yes", ""),
        b = c("IV", "", NA),
        stringsAsFactors = FALSE
    )
    dwc <- list(
        list(term = "dynamicProperties", category = "Record-level",
             desc = "", sep = "", required = FALSE)
    )
    # Single column should still emit JSON, not the raw value
    res <- build_processed_mapping_df(
        df = df, dwc_terms = dwc,
        map_values = list(dynamicProperties = "a"),
        occurrence_ids = c("u1", "u2", "u3")
    )
    testthat::expect_identical(res$data$dynamicProperties[[1]], "{\"a\":\"yes\"}")
    # Multi-column with override propagates through dispatch
    res2 <- build_processed_mapping_df(
        df = df, dwc_terms = dwc,
        map_values = list(dynamicProperties = c("a", "b")),
        occurrence_ids = c("u1", "u2", "u3"),
        dyn_props_keys = list(a = "protect", b = "type")
    )
    testthat::expect_identical(
        res2$data$dynamicProperties[[1]],
        "{\"protect\":\"yes\",\"type\":\"IV\"}"
    )
    testthat::expect_identical(res2$data$dynamicProperties[[3]], "")
})

testthat::test_that("detect_eventdate_roles uses heuristics and falls back to selected order", {
    by_name <- detect_eventdate_roles(c("COL_START_MO", "COL_START_YR", "COL_END_MO", "COL_END_YR"))
    testthat::expect_identical(by_name$start_month, 1L)
    testthat::expect_identical(by_name$start_year, 2L)
    testthat::expect_identical(by_name$end_month, 3L)
    testthat::expect_identical(by_name$end_year, 4L)
    testthat::expect_false(by_name$used_fallback)

    fallback <- detect_eventdate_roles(c("A", "B", "C", "D"))
    testthat::expect_identical(fallback$start_month, 1L)
    testthat::expect_identical(fallback$start_year, 2L)
    testthat::expect_identical(fallback$end_month, 3L)
    testthat::expect_identical(fallback$end_year, 4L)
    testthat::expect_true(fallback$used_fallback)
})

testthat::test_that("parse_month_to_number supports numeric, Portuguese and English values", {
    testthat::expect_identical(parse_month_to_number("8"), "08")
    testthat::expect_identical(parse_month_to_number("Aug"), "08")
    testthat::expect_identical(parse_month_to_number("August"), "08")
    testthat::expect_identical(parse_month_to_number("Ago"), "08")
    testthat::expect_identical(parse_month_to_number("Agosto"), "08")
    testthat::expect_identical(parse_month_to_number("Jun"), "06")
    testthat::expect_identical(parse_month_to_number("June"), "06")
    testthat::expect_identical(parse_month_to_number("Junho"), "06")
    testthat::expect_true(is.na(parse_month_to_number("foo")))
})

# Vectorized parser companions ------------------------------------------
# Each one is asserted against its scalar original element by element, so the
# scalar stays the specification and the companion can only be accepted when it
# agrees on every case -- including the awkward ones.

testthat::test_that("parse_month_to_number_vec matches the scalar helper element by element", {
    # "0" and "13" are the important cases: they match ^\\d{1,2}$ but fall
    # outside 1..12, and the scalar does NOT short-circuit them to NA -- it lets
    # them reach the name lookup, where they miss. A naive vectorization that
    # returns NA at the numeric step would silently agree on the result here but
    # diverge for any future name that looks numeric.
    # "Março" guards the iconv transliteration inside normalize_for_matching().
    values <- c(
        "8", "08", "0", "13", "Aug", "August", "Ago", "Agosto",
        "Mar\u00E7o", "  jun  ", "foo", "", NA, "12", "SET", "sept"
    )

    expected <- vapply(
        values, parse_month_to_number,
        FUN.VALUE = character(1), USE.NAMES = FALSE
    )

    testthat::expect_identical(parse_month_to_number_vec(values), expected)
})

testthat::test_that("parse_month_to_number_vec handles empty, NA and factor input", {
    testthat::expect_identical(parse_month_to_number_vec(character(0)), character(0))
    testthat::expect_identical(parse_month_to_number_vec(NA_character_), NA_character_)
    testthat::expect_identical(
        parse_month_to_number_vec(factor(c("jan", "dez"))),
        c("01", "12")
    )
})

testthat::test_that("parse_year_to_number_vec matches the scalar helper element by element", {
    # "20201" and "19-07-2011" exercise the "first 4-digit run" branch, where a
    # regmatches()-based rewrite would drop the non-matching elements and
    # misalign everything after the first miss.
    values <- c(
        "1998", "98", "2020-01-01", "coletado em 1975", "abc",
        "", NA, "20201", "0000", "19-07-2011"
    )

    expected <- vapply(
        values, parse_year_to_number,
        FUN.VALUE = integer(1), USE.NAMES = FALSE
    )

    testthat::expect_identical(parse_year_to_number_vec(values), expected)
    testthat::expect_identical(parse_year_to_number_vec(character(0)), integer(0))
})

testthat::test_that("format_genus_token_vec and format_epithet_token_vec match their scalars", {
    values <- c(
        "panthera", "PANTHERA", "  onca ", "x-ray", "3panthera",
        "cf.", "", NA, "Leopardus-", "aff. onca"
    )

    testthat::expect_identical(
        format_genus_token_vec(values),
        vapply(values, format_genus_token, FUN.VALUE = character(1), USE.NAMES = FALSE)
    )
    testthat::expect_identical(
        format_epithet_token_vec(values),
        vapply(values, format_epithet_token, FUN.VALUE = character(1), USE.NAMES = FALSE)
    )
    testthat::expect_identical(format_genus_token_vec(character(0)), character(0))
    testthat::expect_identical(format_epithet_token_vec(character(0)), character(0))
})

testthat::test_that("build_eventdate_interval is unchanged when month/year values repeat across rows", {
    # The vectorized parsers resolve over unique() and expand with match(), so a
    # frame with heavy repetition and an interleaved failure is what proves the
    # expansion preserves row order rather than grouping equal values together.
    df <- data.frame(
        COL_START_MO = c("Aug", "Agosto", "foo", "Aug", "jun", "Aug", "foo", "jun", "Agosto", "Aug", "13", "jun"),
        COL_START_YR = c("2017", "2017", "2017", "1998", "2017", "2017", "1998", "2017", "1998", "2017", "2017", "1998"),
        COL_END_MO   = c("Jun", "June", "Jun", "Jun", "dez", "June", "Jun", "dez", "Jun", "Jun", "Jun", "dez"),
        COL_END_YR   = c("2018", "2018", "2018", "2018", "2019", "2018", "2018", "2019", "2018", "2018", "2018", "2019"),
        stringsAsFactors = FALSE
    )

    out <- build_eventdate_interval(
        df = df,
        cols = c("COL_START_MO", "COL_START_YR", "COL_END_MO", "COL_END_YR"),
        fallback_raw = TRUE
    )

    testthat::expect_identical(out$values[[1]], "2017-08/2018-06")
    testthat::expect_identical(out$values[[4]], "1998-08/2018-06")
    testthat::expect_identical(out$values[[5]], "2017-06/2019-12")
    testthat::expect_identical(out$values[[9]], "1998-08/2018-06")
    # Row 3 and 7 fail on "foo"; row 11 fails on the out-of-range month "13".
    testthat::expect_identical(out$values[[3]], "foo | 2017 | Jun | 2018")
    testthat::expect_identical(out$values[[7]], "foo | 1998 | Jun | 2018")
    testthat::expect_identical(out$values[[11]], "13 | 2017 | Jun | 2018")
    testthat::expect_identical(out$failure_count, 3L)
    testthat::expect_identical(which(out$failed_rows), c(3L, 7L, 11L))
})

testthat::test_that("build_eventdate_interval produces YYYY-MM/YYYY-MM and keeps raw fallback on failures", {
    df <- data.frame(
        COL_START_MO = c("Aug", "Agosto", "foo"),
        COL_START_YR = c("2017", "2017", "2017"),
        COL_END_MO = c("Jun", "June", "Jun"),
        COL_END_YR = c("2018", "2018", "2018"),
        stringsAsFactors = FALSE
    )

    out <- build_eventdate_interval(
        df = df,
        cols = c("COL_START_MO", "COL_START_YR", "COL_END_MO", "COL_END_YR"),
        fallback_raw = TRUE
    )

    testthat::expect_identical(out$values[[1]], "2017-08/2018-06")
    testthat::expect_identical(out$values[[2]], "2017-08/2018-06")
    testthat::expect_identical(out$values[[3]], "foo | 2017 | Jun | 2018")
    testthat::expect_identical(out$failure_count, 1L)
    testthat::expect_true(out$failed_rows[[3]])
})

testthat::test_that("build_eventdate_interval uses order fallback when column names are generic", {
    df <- data.frame(
        A = "Aug",
        B = "2017",
        C = "Jun",
        D = "2018",
        stringsAsFactors = FALSE
    )

    out <- build_eventdate_interval(
        df = df,
        cols = c("A", "B", "C", "D"),
        fallback_raw = TRUE
    )

    testthat::expect_identical(out$values[[1]], "2017-08/2018-06")
    testthat::expect_true(out$role_map$used_fallback)
})

testthat::test_that("extract_scientific_name_components parses binomial and genus-only patterns", {
    parsed <- extract_scientific_name_components(c(
        "Lycalopex gymnocercus",
        "Leopardus sp",
        "Leopardus sp.",
        "Leopardus",
        "Leopardus cf. pardalis",
        "",
        NA_character_
    ))

    testthat::expect_identical(parsed$genus[[1]], "Lycalopex")
    testthat::expect_identical(parsed$specificEpithet[[1]], "gymnocercus")
    testthat::expect_identical(parsed$taxonRank[[1]], "species")

    testthat::expect_identical(parsed$genus[[2]], "Leopardus")
    testthat::expect_true(is.na(parsed$specificEpithet[[2]]))
    testthat::expect_identical(parsed$taxonRank[[2]], "genus")

    testthat::expect_identical(parsed$genus[[3]], "Leopardus")
    testthat::expect_true(is.na(parsed$specificEpithet[[3]]))
    testthat::expect_identical(parsed$taxonRank[[3]], "genus")

    testthat::expect_identical(parsed$genus[[4]], "Leopardus")
    testthat::expect_true(is.na(parsed$specificEpithet[[4]]))
    testthat::expect_identical(parsed$taxonRank[[4]], "genus")

    testthat::expect_identical(parsed$genus[[5]], "Leopardus")
    testthat::expect_identical(parsed$specificEpithet[[5]], "pardalis")
    testthat::expect_identical(parsed$taxonRank[[5]], "species")

    testthat::expect_true(is.na(parsed$genus[[6]]))
    testthat::expect_true(is.na(parsed$specificEpithet[[6]]))
    testthat::expect_true(is.na(parsed$taxonRank[[6]]))

    testthat::expect_true(is.na(parsed$genus[[7]]))
    testthat::expect_true(is.na(parsed$specificEpithet[[7]]))
    testthat::expect_true(is.na(parsed$taxonRank[[7]]))
})

testthat::test_that("fill_missing_character_values only fills blank positions", {
    existing <- c("species", NA_character_, "", "  ", "genus")
    fallback <- c("ignored", "species", "species", "species", "ignored")

    out <- fill_missing_character_values(existing, fallback)

    testthat::expect_identical(
        out,
        c("species", "species", "species", "species", "genus")
    )
})

testthat::test_that("replace_na_with_blank converts missing values to empty strings", {
    df <- data.frame(
        char_col = c("a", NA_character_, "c"),
        num_col = c(1, NA_real_, 3),
        stringsAsFactors = FALSE
    )

    out <- replace_na_with_blank(df)

    testthat::expect_identical(out$char_col, c("a", "", "c"))
    testthat::expect_identical(out$num_col, c("1", "", "3"))
})

testthat::test_that("load_dwc_synonyms_v1 loads and validates schema", {
    syn <- load_dwc_synonyms_v1(path = test_data_path("dwc_synonyms_v1.rds"))

    required_cols <- c("term", "synonym", "name_score", "lang", "active")
    testthat::expect_true(all(required_cols %in% names(syn)))
    testthat::expect_true(all(syn$name_score >= 0.90 & syn$name_score <= 0.98))
})

testthat::test_that("load_dwc_synonyms_v1 reuses cache and reloads with force", {
    reset_synonyms_cache()
    on.exit(reset_synonyms_cache(), add = TRUE)

    first <- load_dwc_synonyms_v1()
    state_after_first <- synonyms_cache_state()
    second <- load_dwc_synonyms_v1()
    state_after_second <- synonyms_cache_state()
    forced <- load_dwc_synonyms_v1(force = TRUE)
    state_after_force <- synonyms_cache_state()

    testthat::expect_true(state_after_first$has_value)
    testthat::expect_identical(state_after_first$load_count, 1L)
    testthat::expect_identical(state_after_second$load_count, 1L)
    testthat::expect_identical(state_after_force$load_count, 2L)
    testthat::expect_identical(first, second)
    testthat::expect_identical(first, forced)
})

testthat::test_that("load_dwc_synonyms_v1 validates force flag", {
    reset_synonyms_cache()
    on.exit(reset_synonyms_cache(), add = TRUE)

    testthat::expect_error(load_dwc_synonyms_v1(force = NA), "force must be a single TRUE or FALSE value")
    testthat::expect_error(load_dwc_synonyms_v1(force = c(TRUE, FALSE)), "force must be a single TRUE or FALSE value")
    testthat::expect_error(load_dwc_synonyms_v1(force = "TRUE"), "force must be a single TRUE or FALSE value")
})

testthat::test_that("load_dwc_synonyms_v1 explicit path bypasses cache state", {
    reset_synonyms_cache()
    on.exit(reset_synonyms_cache(), add = TRUE)

    syn_path <- test_data_path("dwc_synonyms_v1.rds")
    from_path <- load_dwc_synonyms_v1(path = syn_path)
    state_after_path <- synonyms_cache_state()

    cached <- load_dwc_synonyms_v1()
    state_after_cache <- synonyms_cache_state()

    from_path_again <- load_dwc_synonyms_v1(path = syn_path, force = TRUE)
    state_after_path_again <- synonyms_cache_state()

    testthat::expect_false(state_after_path$has_value)
    testthat::expect_identical(state_after_path$load_count, 0L)
    testthat::expect_true(state_after_cache$has_value)
    testthat::expect_identical(state_after_cache$load_count, 1L)
    testthat::expect_identical(state_after_path_again$load_count, 1L)
    testthat::expect_identical(from_path, cached)
    testthat::expect_identical(from_path, from_path_again)
})

testthat::test_that("compute_name_score prioritizes exact match and synonyms", {
    syn <- data.frame(
        term = c("scientificName"),
        synonym = c("nome cientifico"),
        name_score = c(0.98),
        lang = c("pt"),
        active = c(TRUE),
        stringsAsFactors = FALSE
    )

    exact_res <- compute_name_score("scientificName", "scientificName", syn)
    syn_res <- compute_name_score("nome cientifico", "scientificName", syn)
    low_res <- compute_name_score("unrelated_column", "scientificName", syn)

    testthat::expect_identical(exact_res$reason, "exact_match")
    testthat::expect_identical(exact_res$score, 1)
    testthat::expect_identical(syn_res$reason, "known_synonym")
    testthat::expect_true(syn_res$score >= 0.90)
    testthat::expect_true(low_res$score <= 0.60)
})

testthat::test_that("compute_value_score validates coordinates and blocks incompatible type", {
    lat_ok <- c("-12.1", "-23.5", "0.0", "45.9")
    lat_bad <- c("abc", "texto", "sem numero", "x")

    ok_res <- compute_value_score(lat_ok, term = "decimalLatitude", name_score = 1.0)
    bad_res <- compute_value_score(lat_bad, term = "decimalLatitude", name_score = 1.0)

    testthat::expect_true(ok_res$score >= 0.90)
    testthat::expect_true(ok_res$compatible_type)

    testthat::expect_true(bad_res$score <= 0.60)
    testthat::expect_false(bad_res$compatible_type)
})

testthat::test_that("compute_value_score validates scientificName and individualCount", {
    sn_ok <- c("Panthera onca", "Leopardus sp.", "Leopardus cf. pardalis")
    sn_bad <- c("foo", "123", "???")

    count_ok <- c("1", "2", "0", "9")
    count_bad <- c("one", "-1", "3.7", "abc")

    sn_ok_res <- compute_value_score(sn_ok, term = "scientificName", name_score = 1.0)
    sn_bad_res <- compute_value_score(sn_bad, term = "scientificName", name_score = 1.0)
    count_ok_res <- compute_value_score(count_ok, term = "individualCount", name_score = 1.0)
    count_bad_res <- compute_value_score(count_bad, term = "individualCount", name_score = 1.0)

    testthat::expect_true(sn_ok_res$score > sn_bad_res$score)
    testthat::expect_true(count_ok_res$score > count_bad_res$score)
})

testthat::test_that("run_rostrum_stage1 excludes temporal inference except exact match", {
    syn <- data.frame(
        term = c("eventDate"),
        synonym = c("data coleta"),
        name_score = c(0.95),
        lang = c("pt"),
        active = c(TRUE),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(term = c("eventDate"), stringsAsFactors = FALSE)

    df_synonym_only <- data.frame(
        data_coleta = c("2024-01-01", "2024-01-02"),
        stringsAsFactors = FALSE
    )
    out_synonym <- run_rostrum_stage1(df_synonym_only, dwc_terms, syn, options = rostrum_options())
    testthat::expect_identical(out_synonym$status[[1]], "MANUAL")
    testthat::expect_true(is.na(out_synonym$selected_col[[1]]))

    df_exact <- data.frame(
        eventDate = c("2024-01-01", "2024-01-02"),
        stringsAsFactors = FALSE
    )
    out_exact <- run_rostrum_stage1(df_exact, dwc_terms, syn, options = rostrum_options())
    testthat::expect_true(out_exact$status[[1]] %in% c("AUTO", "SUGERIDO", "AMBIGUO"))
    testthat::expect_identical(out_exact$selected_col[[1]], "eventDate")
})

testthat::test_that("run_rostrum_stage1 resolves conflicts by strongest score", {
    syn <- data.frame(
        term = c("individualCount", "samplingEffort"),
        synonym = c("count", "count"),
        name_score = c(0.97, 0.93),
        lang = c("any", "any"),
        active = c(TRUE, TRUE),
        stringsAsFactors = FALSE
    )

    dwc_terms <- data.frame(term = c("individualCount", "samplingEffort"), stringsAsFactors = FALSE)
    df <- data.frame(count = c("1", "2", "3"), stringsAsFactors = FALSE)

    out <- run_rostrum_stage1(df, dwc_terms, syn, options = rostrum_options())
    count_rows <- out[out$term %in% c("individualCount", "samplingEffort"), , drop = FALSE]

    testthat::expect_identical(sum(count_rows$applied), 1L)
    testthat::expect_true(any(count_rows$status == "MANUAL"))
    testthat::expect_true(any(count_rows$reason == "conflict_lost"))
})

testthat::test_that("run_rostrum_stage1 returns expected columns and status thresholds", {
    syn <- load_dwc_synonyms_v1(path = test_data_path("dwc_synonyms_v1.rds"))
    dwc_terms <- data.frame(term = c("scientificName", "recordedBy", "decimalLatitude"), stringsAsFactors = FALSE)
    df <- data.frame(
        scientificName = c("Panthera onca", "Leopardus pardalis"),
        collector = c("A", "B"),
        decimalLatitude = c("texto", "invalido"),
        stringsAsFactors = FALSE
    )

    out <- run_rostrum_stage1(df, dwc_terms, syn, options = rostrum_options())

    testthat::expect_true(all(c("term", "selected_col", "name_score", "value_score", "final_score", "status", "reason", "applied") %in% names(out)))
    testthat::expect_true(out$status[out$term == "scientificName"] %in% c("AUTO", "SUGERIDO", "AMBIGUO"))
    testthat::expect_true(out$status[out$term == "recordedBy"] %in% c("SUGERIDO", "MANUAL", "AMBIGUO"))
    testthat::expect_false(out$status[out$term == "decimalLatitude"] == "AUTO")
})

testthat::test_that("sanitize_map_selection and has_selected_value keep mapping semantics", {
    testthat::expect_false(has_selected_value(NULL))
    testthat::expect_false(has_selected_value(character(0)))
    testthat::expect_false(has_selected_value(""))
    testthat::expect_true(has_selected_value(c("", "col_a")))

    testthat::expect_identical(
        sanitize_map_selection("scientificName", c(" scientific_col ", "other_col")),
        "scientific_col"
    )
    testthat::expect_identical(
        sanitize_map_selection("recordedBy", c(" col_a ", "", NA_character_, " col_b ")),
        c("col_a", "col_b")
    )
    testthat::expect_identical(sanitize_map_selection("recordedBy", NULL), "")
})

testthat::test_that("mapping state helpers build empty structures and manual metadata transitions", {
    terms <- c("scientificName", "eventDate")
    expected_default_meta <- list(
        status = NA_character_,
        score = NA_real_,
        reason = NA_character_,
        source = NA_character_
    )

    testthat::expect_identical(default_meta(), expected_default_meta)

    values_state <- empty_map_values(terms)
    testthat::expect_identical(values_state$scientificName, "")
    testthat::expect_identical(values_state$eventDate, "")

    meta_state <- empty_map_meta(terms)
    testthat::expect_identical(meta_state$scientificName, expected_default_meta)
    testthat::expect_identical(meta_state$eventDate, expected_default_meta)

    previous_meta <- list(
        status = "AUTO",
        score = "0.95",
        reason = "exact_match",
        source = "auto"
    )
    edited <- build_manual_meta(previous_meta = previous_meta, has_value = TRUE)
    cleared <- build_manual_meta(previous_meta = previous_meta, has_value = FALSE)

    testthat::expect_identical(
        edited,
        list(
            status = "EDITADO",
            score = 0.95,
            reason = "manual_adjust",
            source = "manual"
        )
    )
    testthat::expect_identical(
        cleared,
        list(
            status = "MANUAL",
            score = NA_real_,
            reason = "manual_cleared",
            source = "manual"
        )
    )
})

testthat::test_that("build_processed_mapping_df enforces occurrence_ids length", {
    df <- data.frame(col_a = c("x", "y"), stringsAsFactors = FALSE)
    terms <- list(list(term = "occurrenceID"))

    testthat::expect_error(
        build_processed_mapping_df(
            df = df,
            dwc_terms = terms,
            map_values = list(),
            occurrence_ids = "id-1"
        ),
        "occurrence_ids must have the same length as nrow\\(df\\)"
    )
})

testthat::test_that("build_processed_mapping_df preserves processed_data contract for special fields and eventDate", {
    df <- data.frame(
        dataset_col = c("from_column_1", "from_column_2"),
        start_mo = c("Aug", "foo"),
        start_yr = c("2017", "2017"),
        end_mo = c("Jun", "Jun"),
        end_yr = c("2018", "2018"),
        scientific_col = c("Panthera onca", "Leopardus"),
        recorded_col = c("Ana; Bruno", NA_character_),
        count_col = c("1", "2"),
        stringsAsFactors = FALSE
    )

    dwc_terms <- list(
        list(term = "occurrenceID"),
        list(term = "datasetName"),
        list(term = "modified"),
        list(term = "license"),
        list(term = "language"),
        list(term = "eventDate"),
        list(term = "scientificName"),
        list(term = "recordedBy"),
        list(term = "individualCount"),
        list(term = "genus"),
        list(term = "specificEpithet"),
        list(term = "taxonRank")
    )

    map_values <- empty_map_values(vapply(dwc_terms, function(item) item$term, FUN.VALUE = character(1)))
    map_values$datasetName <- "dataset_col"
    map_values$eventDate <- c("start_mo", "start_yr", "end_mo", "end_yr")
    map_values$scientificName <- "scientific_col"
    map_values$recordedBy <- "recorded_col"
    map_values$individualCount <- "count_col"

    fixed_now <- as.POSIXct("2026-02-14 10:11:12", tz = "UTC")
    result <- build_processed_mapping_df(
        df = df,
        dwc_terms = dwc_terms,
        map_values = map_values,
        occurrence_ids = c("id-1", "id-2"),
        custom_dataset_name = "Dataset Custom",
        modified_use_today = TRUE,
        custom_modified_date = as.Date("2025-01-01"),
        custom_license = c("CC0", "CC-BY"),
        custom_language = c("pt", "en"),
        now_utc = fixed_now
    )

    out <- result$data
    testthat::expect_identical(result$eventdate_failure_count, 1L)
    testthat::expect_identical(out$occurrenceID, c("id-1", "id-2"))
    testthat::expect_identical(out$datasetName, c("Dataset Custom", "Dataset Custom"))
    testthat::expect_identical(out$modified, c("2026-02-14", "2026-02-14"))
    testthat::expect_identical(out$license, c("CC0", "CC0"))
    testthat::expect_identical(out$language, c("pt", "pt"))
    testthat::expect_identical(out$eventDate[[1]], "2017-08/2018-06")
    testthat::expect_identical(out$eventDate[[2]], "foo | 2017 | Jun | 2018")
    testthat::expect_identical(out$recordedBy[[1]], "Ana | Bruno")
    testthat::expect_identical(out$recordedBy[[2]], "")
    testthat::expect_identical(out$genus, c("Panthera", "Leopardus"))
    testthat::expect_identical(out$specificEpithet, c("onca", ""))
    testthat::expect_identical(out$taxonRank, c("species", "genus"))
    testthat::expect_false(any(is.na(out)))
})

testthat::test_that("build_processed_mapping_df injects constant_values across all rows with precedence over columns", {
    df <- data.frame(
        rights_col = c("Org A", "Org B", "Org C"),
        sci_col = c("Panthera onca", "Leopardus pardalis", "Puma concolor"),
        stringsAsFactors = FALSE
    )

    dwc_terms <- list(
        list(term = "occurrenceID"),
        list(term = "rightsHolder"),
        list(term = "geodeticDatum"),
        list(term = "scientificName"),
        list(term = "genus"),
        list(term = "specificEpithet"),
        list(term = "taxonRank")
    )

    map_values <- empty_map_values(vapply(dwc_terms, function(item) item$term, FUN.VALUE = character(1)))
    # rightsHolder also points at a column: the fixed value must take precedence.
    map_values$rightsHolder <- "rights_col"
    map_values$scientificName <- "sci_col"

    result <- build_processed_mapping_df(
        df = df,
        dwc_terms = dwc_terms,
        map_values = map_values,
        occurrence_ids = c("id-1", "id-2", "id-3"),
        constant_values = list(
            rightsHolder = "Museu Nacional/UFRJ",
            geodeticDatum = "EPSG:4326"
        )
    )

    out <- result$data
    # Constant wins over the mapped column, applied to every row.
    testthat::expect_identical(out$rightsHolder, rep("Museu Nacional/UFRJ", 3L))
    # A term with no source column still gets the constant on every row.
    testthat::expect_identical(out$geodeticDatum, rep("EPSG:4326", 3L))
})

testthat::test_that("basisOfRecord helpers normalize and auto-suggest canonical terms", {
    testthat::expect_identical(normalize_basis_of_record_key("  HumanObservation  "), "humanobservation")
    testthat::expect_identical(normalize_basis_of_record_key(NA_character_), "")
    testthat::expect_identical(auto_suggest_basis_of_record_term("humanobservation"), "HumanObservation")
    testthat::expect_identical(auto_suggest_basis_of_record_term("HumanObservation"), "HumanObservation")
    testthat::expect_identical(auto_suggest_basis_of_record_term("camera trap"), "")
})

testthat::test_that("sanitize_basis_of_record_map filters invalid terms and keeps keys normalized", {
    raw_map <- c(
        "HumanObservation",
        "InvalidTerm",
        "",
        "Occurrence"
    )
    names(raw_map) <- c(" HumanObservation ", "camera trap", "  ", "OCCURRENCE")

    out <- sanitize_basis_of_record_map(raw_map)

    testthat::expect_identical(out[["humanobservation"]], "HumanObservation")
    testthat::expect_identical(out[["camera trap"]], "")
    testthat::expect_identical(out[["occurrence"]], "Occurrence")
    testthat::expect_false("" %in% names(out))
})

testthat::test_that("build_processed_mapping_df enforces single mapped value for basisOfRecord", {
    df <- data.frame(
        bor_raw = c(
            "Active searching, Camera trap, Opportunistic",
            "humanobservation",
            "Unknown method",
            NA_character_
        ),
        stringsAsFactors = FALSE
    )

    dwc_terms <- list(
        list(term = "occurrenceID"),
        list(term = "basisOfRecord")
    )

    map_values <- empty_map_values(vapply(dwc_terms, function(item) item$term, FUN.VALUE = character(1)))
    map_values$basisOfRecord <- "bor_raw"

    basis_map <- c(
        "HumanObservation",
        "HumanObservation"
    )
    names(basis_map) <- c(
        "active searching, camera trap, opportunistic",
        "humanobservation"
    )

    result <- build_processed_mapping_df(
        df = df,
        dwc_terms = dwc_terms,
        map_values = map_values,
        occurrence_ids = c("id-1", "id-2", "id-3", "id-4"),
        basis_of_record_map = basis_map
    )

    out <- result$data
    testthat::expect_true("basisOfRecord" %in% names(out))
    testthat::expect_identical(
        out$basisOfRecord,
        c("HumanObservation", "HumanObservation", "", "")
    )
    testthat::expect_false(any(grepl("\\|", out$basisOfRecord)))
})

testthat::test_that("map_occurrence_status_values converts 0/1 and common variants to DwC literals", {
    inputs <- c("0", "1", "Sim", "Nao", "Não", "yes", "NO", "TRUE", "false",
                "presente", "ausente", "other", "", NA_character_)

    expected <- c("absent", "present", "present", "absent", "absent",
                  "present", "absent", "present", "absent",
                  "present", "absent", "other",
                  NA_character_, NA_character_)

    testthat::expect_identical(
        map_occurrence_status_values(inputs),
        expected
    )
})

testthat::test_that("map_occurrence_status_values handles numeric and logical input types", {
    testthat::expect_identical(
        map_occurrence_status_values(c(1, 0, 1, NA_real_)),
        c("present", "absent", "present", NA_character_)
    )
    testthat::expect_identical(
        map_occurrence_status_values(c(TRUE, FALSE, NA, TRUE)),
        c("present", "absent", NA_character_, "present")
    )
    testthat::expect_identical(
        map_occurrence_status_values(NULL),
        character(0)
    )
})

testthat::test_that("build_term_value: single-column term normalizes semicolons", {
    df <- data.frame(recorded = c("Ana; Bruno", "Carlos"), stringsAsFactors = FALSE)
    result <- build_term_value("recordedBy", df, "recorded")
    testthat::expect_identical(unname(result$values), c("Ana | Bruno", "Carlos"))
    testthat::expect_identical(result$eventdate_failure_count, 0L)
})

testthat::test_that("build_term_value: multi-column term collapses with pipe", {
    df <- data.frame(a = c("X", "Y"), b = c("P", "Q"), stringsAsFactors = FALSE)
    result <- build_term_value("locality", df, c("a", "b"))
    testthat::expect_identical(result$values, c("X | P", "Y | Q"))
})

testthat::test_that("build_term_value: eventDate 4-col produces ISO interval", {
    df <- data.frame(
        smo = c("Aug", "foo"), syr = c("2017", "2017"),
        emo = c("Jun", "Jun"), eyr = c("2018", "2018"),
        stringsAsFactors = FALSE
    )
    result <- build_term_value("eventDate", df, c("smo", "syr", "emo", "eyr"))
    testthat::expect_identical(result$values[[1]], "2017-08/2018-06")
    testthat::expect_identical(result$eventdate_failure_count, 1L)
})

testthat::test_that("detect_eventdate_dmy_roles resolves Portuguese and English names", {
    pt <- detect_eventdate_dmy_roles(c("dia", "mes", "ano"))
    testthat::expect_identical(pt$day, 1L)
    testthat::expect_identical(pt$month, 2L)
    testthat::expect_identical(pt$year, 3L)

    en <- detect_eventdate_dmy_roles(c("collection_year", "day_of_month", "month"))
    testthat::expect_identical(en$day, 2L)
    testthat::expect_identical(en$month, 3L)
    testthat::expect_identical(en$year, 1L)

    partial <- detect_eventdate_dmy_roles(c("mes", "ano"))
    testthat::expect_true(is.na(partial$day))
    testthat::expect_identical(partial$month, 1L)
    testthat::expect_identical(partial$year, 2L)

    testthat::expect_true(all(vapply(
        detect_eventdate_dmy_roles(c("a", "b", "c")), is.na, logical(1)
    )))
})

testthat::test_that("build_term_value: eventDate from day/month/year columns is ISO 8601", {
    df <- data.frame(
        dia = c("12", "5", "31", ""),
        mes = c("2", "maio", "2", ""),
        ano = c("1809", "2020", "1809", ""),
        stringsAsFactors = FALSE
    )

    result <- build_term_value("eventDate", df, c("dia", "mes", "ano"))
    testthat::expect_identical(result$values[[1]], "1809-02-12")
    testthat::expect_identical(result$values[[2]], "2020-05-05")
    # 31 February is not a date: the row keeps its raw value and is reported.
    testthat::expect_identical(result$values[[3]], "31 | 2 | 1809")
    testthat::expect_true(is.na(result$values[[4]]))
    testthat::expect_identical(result$eventdate_failure_count, 1L)

    # Roles come from the column names, so the order the user picked them in
    # does not change the composed date.
    shuffled <- build_term_value("eventDate", df, c("ano", "dia", "mes"))
    testthat::expect_identical(shuffled$values[[1]], "1809-02-12")
})

testthat::test_that("build_term_value: eventDate from month/year columns keeps reduced precision", {
    df <- data.frame(
        mes = c("2", "dez"), ano = c("1809", "2020"),
        stringsAsFactors = FALSE
    )
    result <- build_term_value("eventDate", df, c("mes", "ano"))
    testthat::expect_identical(result$values, c("1809-02", "2020-12"))
    testthat::expect_identical(result$eventdate_failure_count, 0L)
})

testthat::test_that("build_term_value: eventDate keeps the generic collapse when parts are unrecognizable", {
    df <- data.frame(
        a = "12", b = "2", c = "1809",
        stringsAsFactors = FALSE
    )
    testthat::expect_identical(
        build_term_value("eventDate", df, c("a", "b", "c"))$values,
        "12 | 2 | 1809"
    )

    # A day with no month cannot become a date, and a column with no role at all
    # would be silently dropped -- both keep the collapse.
    df2 <- data.frame(dia = "12", ano = "1809", obs = "x", stringsAsFactors = FALSE)
    testthat::expect_identical(
        build_term_value("eventDate", df2, c("dia", "ano"))$values,
        "12 | 1809"
    )
    testthat::expect_identical(
        build_term_value("eventDate", df2, c("dia", "ano", "obs"))$values,
        "12 | 1809 | x"
    )
})

testthat::test_that("build_eventdate_from_parts returns NULL when the selection is not a split date", {
    df <- data.frame(a = "1", b = "2", stringsAsFactors = FALSE)
    testthat::expect_null(build_eventdate_from_parts(df, c("a", "b")))
})

testthat::test_that("build_term_value: basisOfRecord applies mapping", {
    df <- data.frame(bor = c("humanobservation", "Unknown"), stringsAsFactors = FALSE)
    bmap <- c("humanobservation" = "HumanObservation")
    result <- build_term_value("basisOfRecord", df, "bor", basis_of_record_map = bmap)
    testthat::expect_identical(result$values[[1]], "HumanObservation")
})

testthat::test_that("build_term_value and build_processed_mapping_df agree on single-col output", {
    df <- data.frame(
        sp = c("Panthera onca"), rby = c("Ana; Bruno"),
        stringsAsFactors = FALSE
    )
    dwc_terms <- list(
        list(term = "occurrenceID"),
        list(term = "scientificName"),
        list(term = "recordedBy")
    )
    map_values <- empty_map_values(c("occurrenceID", "scientificName", "recordedBy"))
    map_values$scientificName <- "sp"
    map_values$recordedBy <- "rby"
    full <- build_processed_mapping_df(
        df = df, dwc_terms = dwc_terms, map_values = map_values,
        occurrence_ids = "id-1"
    )$data
    direct <- build_term_value("recordedBy", df, "rby")
    testthat::expect_identical(full$recordedBy, unname(direct$values))
})

testthat::test_that("build_processed_mapping_df transforms occurrenceStatus values to present/absent", {
    df <- data.frame(
        flag_col = c("1", "0", "Sim", "presente", "other", NA_character_),
        stringsAsFactors = FALSE
    )

    dwc_terms <- list(
        list(term = "occurrenceID"),
        list(term = "occurrenceStatus")
    )

    map_values <- empty_map_values(vapply(dwc_terms, function(item) item$term, FUN.VALUE = character(1)))
    map_values$occurrenceStatus <- "flag_col"

    result <- build_processed_mapping_df(
        df = df,
        dwc_terms = dwc_terms,
        map_values = map_values,
        occurrence_ids = c("id-1", "id-2", "id-3", "id-4", "id-5", "id-6")
    )

    out <- result$data
    testthat::expect_true("occurrenceStatus" %in% names(out))
    testthat::expect_identical(
        out$occurrenceStatus,
        c("present", "absent", "present", "present", "other", "")
    )
})

testthat::test_that("plan_mapping_guide_restore rebuilds concatenations, constants, flags missing", {
    pairs <- data.frame(
        source_column  = c("year + month + day", "lat", "ghost", NA_character_),
        dwc_term       = c("eventDate", "decimalLatitude", "recordedBy", "datasetName"),
        kind           = c("column", "column", "column", "constant"),
        constant_value = c(NA_character_, NA_character_, NA_character_, "Rede Felinos"),
        stringsAsFactors = FALSE
    )
    plan <- plan_mapping_guide_restore(
        list(meta = list(), pairs = pairs),
        available_columns = c("year", "month", "day", "lat")
    )

    # Concatenation preserved as a multi-column selection.
    testthat::expect_identical(plan$map_values$eventDate, c("year", "month", "day"))
    testthat::expect_identical(plan$map_values$decimalLatitude, "lat")
    # A term whose only source column is absent is skipped, not silently lost.
    testthat::expect_null(plan$map_values$recordedBy)
    testthat::expect_true("recordedBy" %in% plan$skipped_terms)
    testthat::expect_true("ghost" %in% plan$missing_columns)
    # Constants restored.
    testthat::expect_identical(plan$constants$datasetName, "Rede Felinos")
})

# resolve_occurrence_ids (C2) --------------------------------------------

testthat::test_that("resolve_occurrence_ids preserves provided IDs and fills gaps", {
    df <- data.frame(
        occurrenceID = c("obs-1", NA, "  ", "obs-4"),
        x = 1:4,
        stringsAsFactors = FALSE
    )
    out <- resolve_occurrence_ids(df)
    testthat::expect_length(out, 4L)
    testthat::expect_identical(out[c(1L, 4L)], c("obs-1", "obs-4"))
    # Blank/NA entries are backfilled with non-empty UUIDs.
    testthat::expect_true(all(nchar(out[c(2L, 3L)]) > 10L))
    testthat::expect_false(anyNA(out))
})

testthat::test_that("resolve_occurrence_ids generates UUIDs when no column exists", {
    out <- resolve_occurrence_ids(data.frame(x = 1:3))
    testthat::expect_length(out, 3L)
    testthat::expect_true(all(nchar(out) > 10L))
    testthat::expect_false(anyDuplicated(out) > 0L)
})

testthat::test_that("resolve_occurrence_ids generates nothing when every row ships an ID", {
    # Asserted structurally rather than by timing: if the generator is reached at
    # all on a fully-populated column, every identifier it produces would be
    # overwritten, which is the waste being avoided. A timing assertion would rot
    # on faster hardware; this one cannot.
    df <- data.frame(
        occurrenceID = c("obs-1", "obs-2", "obs-3"),
        x = 1:3,
        stringsAsFactors = FALSE
    )

    testthat::local_mocked_bindings(
        generate_persistent_ids = function(...) {
            stop("must not generate when no ID is missing")
        }
    )

    testthat::expect_identical(
        as.character(resolve_occurrence_ids(df)),
        c("obs-1", "obs-2", "obs-3")
    )
})

testthat::test_that("resolve_occurrence_ids generates for exactly the rows that need one", {
    # The paired negative: the assertion above must not be able to pass by making
    # the function never generate anything.
    df <- data.frame(
        occurrenceID = c("obs-1", "", "obs-3"),
        x = 1:3,
        stringsAsFactors = FALSE
    )

    asked_for <- NULL
    testthat::local_mocked_bindings(
        generate_persistent_ids = function(df, rows = NULL, exclude = NULL) {
            asked_for <<- rows
            rep("generated-01", sum(rows))
        }
    )

    out <- resolve_occurrence_ids(df)
    testthat::expect_identical(asked_for, c(FALSE, TRUE, FALSE))
    testthat::expect_identical(
        as.character(out),
        c("obs-1", "generated-01", "obs-3")
    )
})

# detect_duplicate_source_mappings (item 3) ------------------------------
testthat::test_that("detect_duplicate_source_mappings flags a column used by two terms", {
    mv <- list(
        scientificName = "taxon",
        decimalLatitude = "lat",
        basisOfRecord = "type_col",
        type = "type_col"
    )
    dups <- detect_duplicate_source_mappings(mv)
    testthat::expect_named(dups, "type_col")
    testthat::expect_setequal(dups[["type_col"]], c("basisOfRecord", "type"))
})

testthat::test_that("detect_duplicate_source_mappings ignores blanks, singles, and excluded terms", {
    # No collisions: every column used once.
    mv_ok <- list(scientificName = "taxon", decimalLatitude = "lat", type = "")
    testthat::expect_length(detect_duplicate_source_mappings(mv_ok), 0L)

    # A clash only on an excluded constant term is not reported.
    mv_excl <- list(license = "x", language = "x", scientificName = "taxon")
    testthat::expect_length(
        detect_duplicate_source_mappings(
            mv_excl,
            exclude = c("license", "language")
        ),
        0L
    )

    # Empty / non-list input is safe.
    testthat::expect_length(detect_duplicate_source_mappings(list()), 0L)
})

testthat::test_that("detect_duplicate_source_mappings ignores verbatim terms", {
    # A column shared between a parsed term and its verbatim twin is expected.
    mv <- list(eventDate = "date_col", verbatimEventDate = "date_col")
    testthat::expect_length(detect_duplicate_source_mappings(mv), 0L)

    # But a clash between two non-verbatim terms is still flagged.
    mv2 <- list(eventDate = "date_col", year = "date_col",
                verbatimEventDate = "date_col")
    dups <- detect_duplicate_source_mappings(mv2)
    testthat::expect_named(dups, "date_col")
    testthat::expect_setequal(dups[["date_col"]], c("eventDate", "year"))
})

# merge_dynamic_property --------------------------------------------------

testthat::test_that("merge_dynamic_property wraps an empty or NA target", {
    testthat::expect_identical(
        saira:::merge_dynamic_property(c("", NA), "iucnRedListCategory", c("NT", "VU")),
        c("{\"iucnRedListCategory\":\"NT\"}", "{\"iucnRedListCategory\":\"VU\"}")
    )
})

testthat::test_that("merge_dynamic_property splices into an existing object", {
    testthat::expect_identical(
        saira:::merge_dynamic_property("{\"a\":\"1\"}", "mmaThreatStatus", "CR"),
        "{\"a\":\"1\",\"mmaThreatStatus\":\"CR\"}"
    )
})

testthat::test_that("merge_dynamic_property leaves NA/blank values untouched", {
    testthat::expect_identical(
        saira:::merge_dynamic_property(
            c("{\"x\":\"y\"}", "", "{\"z\":\"1\"}"),
            "mmaSource", c(NA, "  ", "Portaria 1.704/2026")
        ),
        c("{\"x\":\"y\"}", "", "{\"z\":\"1\",\"mmaSource\":\"Portaria 1.704/2026\"}")
    )
})

testthat::test_that("merge_dynamic_property JSON-escapes the value", {
    testthat::expect_identical(
        saira:::merge_dynamic_property("", "k", "a\"b\\c"),
        "{\"k\":\"a\\\"b\\\\c\"}"
    )
})

testthat::test_that("merge_dynamic_property recycles a scalar value over rows", {
    testthat::expect_identical(
        saira:::merge_dynamic_property(
            c("", "{\"a\":\"1\"}"), "mmaSource", "Portaria 148/2022"
        ),
        c("{\"mmaSource\":\"Portaria 148/2022\"}",
          "{\"a\":\"1\",\"mmaSource\":\"Portaria 148/2022\"}")
    )
})

testthat::test_that("merge_dynamic_property handles empty input", {
    testthat::expect_identical(
        saira:::merge_dynamic_property(character(0), "k", character(0)),
        character(0)
    )
})

# --- establishmentMeans / degreeOfEstablishment assistant (ADR-110) ---------

test_that("extract_species_entries dedupes, counts and orders by frequency", {
    entries <- extract_species_entries(
        c("Sus scrofa", "Panthera onca", "Sus scrofa", NA, "", "  ", "Sus scrofa")
    )
    expect_equal(entries$raw, c("Sus scrofa", "Panthera onca"))
    expect_equal(entries$n_records, c(3L, 1L))
    expect_equal(entries$key, c("sus scrofa", "panthera onca"))
    expect_equal(entries$idx, c(1L, 2L))
})

test_that("extract_species_entries returns the empty schema for no species", {
    entries <- extract_species_entries(c(NA, "", "   "))
    expect_equal(nrow(entries), 0L)
    expect_equal(names(entries), c("idx", "key", "raw", "n_records"))
})

test_that("auto_suggest_establishment_means only pre-fills listed invasives", {
    out <- auto_suggest_establishment_means(c("Sus scrofa", "Panthera onca"))
    expect_equal(unname(out), c("introduced", ""))
    expect_equal(names(out), c("sus scrofa", "panthera onca"))
    # Never guesses "native" for an unlisted taxon: the app cannot know that.
    expect_false(any(out == "native"))
})

test_that("map_establishment_values expands per-species answers to rows", {
    map <- list(
        means = c("sus scrofa" = "introduced", "panthera onca" = "native"),
        degree = c("sus scrofa" = "invasive")
    )
    species <- c("Sus scrofa", "Panthera onca", "Sus scrofa", "Bos taurus", NA)

    expect_equal(
        map_establishment_values(species, map, "means"),
        c("introduced", "native", "introduced", "", "")
    )
    expect_equal(
        map_establishment_values(species, map, "degree"),
        c("invasive", "", "invasive", "", "")
    )
    expect_equal(map_establishment_values(species, NULL, "means"), rep("", 5L))
})

test_that("map_establishment_values drops values outside the controlled vocabulary", {
    map <- list(means = c("sus scrofa" = "bogus"), degree = c("sus scrofa" = "invasive"))
    expect_equal(map_establishment_values("Sus scrofa", map, "means"), "")
    # A valid term in the other field is unaffected by the invalid one.
    expect_equal(map_establishment_values("Sus scrofa", map, "degree"), "invasive")
})

test_that("establishment_pairs_missing_degree lists means without a degree", {
    map <- list(
        means = c("sus scrofa" = "introduced", "bos taurus" = "introduced", "x" = ""),
        degree = c("sus scrofa" = "invasive")
    )
    expect_equal(establishment_pairs_missing_degree(map), "bos taurus")
    expect_equal(establishment_pairs_missing_degree(NULL), character(0))
})

test_that("build_establishment_term_value lets the user's column win", {
    df <- data.frame(
        especie = c("Sus scrofa", "Sus scrofa", "Sus scrofa"),
        origem = c("vagrant", "", NA),
        stringsAsFactors = FALSE
    )
    map <- list(means = c("sus scrofa" = "introduced"), degree = character(0))

    out <- build_establishment_term_value(
        "establishmentMeans", df, user_cols = "origem",
        species_values = df$especie, establishment_map = map
    )
    # Row 1 keeps the user's value; the blank rows are filled by the assistant.
    expect_equal(out, c("vagrant", "introduced", "introduced"))
})

test_that("build_establishment_term_value works with no column and no assistant", {
    df <- data.frame(especie = c("Sus scrofa", "Panthera onca"), stringsAsFactors = FALSE)
    map <- list(means = c("sus scrofa" = "introduced"), degree = character(0))

    expect_equal(
        build_establishment_term_value(
            "establishmentMeans", df, user_cols = NULL,
            species_values = df$especie, establishment_map = map
        ),
        c("introduced", "")
    )
    # scientificName not mapped -> no species to key the answers on, so every
    # row comes out blank (which keeps the column out of the export entirely).
    expect_equal(
        build_establishment_term_value(
            "establishmentMeans", df, user_cols = NULL,
            species_values = NULL, establishment_map = map
        ),
        c("", "")
    )
})

test_that("build_processed_mapping_df emits establishment columns from the assistant alone", {
    df <- data.frame(
        especie = c("Sus scrofa", "Panthera onca", "Sus scrofa"),
        stringsAsFactors = FALSE
    )
    terms <- get_active_dwc_terms_list()
    map <- list(
        means = c("sus scrofa" = "introduced", "panthera onca" = "native"),
        degree = c("sus scrofa" = "invasive")
    )

    out <- build_processed_mapping_df(
        df = df, dwc_terms = terms,
        map_values = list(scientificName = "especie"),
        occurrence_ids = paste0("id-", seq_len(nrow(df))),
        establishment_map = map
    )$data

    expect_true(all(c("establishmentMeans", "degreeOfEstablishment") %in% names(out)))
    expect_equal(out$establishmentMeans, c("introduced", "native", "introduced"))
    expect_equal(out$degreeOfEstablishment, c("invasive", "", "invasive"))
})

test_that("build_processed_mapping_df omits establishment columns without answers", {
    df <- data.frame(especie = c("Sus scrofa"), stringsAsFactors = FALSE)
    out <- build_processed_mapping_df(
        df = df, dwc_terms = get_active_dwc_terms_list(),
        map_values = list(scientificName = "especie"),
        occurrence_ids = "id-1",
        establishment_map = NULL
    )$data
    expect_false("establishmentMeans" %in% names(out))
    expect_false("degreeOfEstablishment" %in% names(out))
})

test_that("build_processed_mapping_df needs scientificName for the assistant to apply", {
    df <- data.frame(
        especie = c("Sus scrofa"), outra = c("x"), stringsAsFactors = FALSE
    )
    map <- list(means = c("sus scrofa" = "introduced"), degree = character(0))
    # scientificName unmapped: there is no species vector to key the answers on.
    out <- build_processed_mapping_df(
        df = df, dwc_terms = get_active_dwc_terms_list(),
        map_values = list(locality = "outra"),
        occurrence_ids = "id-1",
        establishment_map = map
    )$data
    expect_false("establishmentMeans" %in% names(out))
})

# occurrenceID resolution (mapping is authoritative) ----------------------

test_that("resolve_occurrence_ids honours the mapping, not the column name", {
    # The regression this guards: the resolver used to look for a column
    # literally named "occurrenceID" and ignored map_values, so any dataset
    # whose identifier column is named anything else had every id silently
    # replaced by a random UUID while the guide still called them user-supplied.
    df <- data.frame(
        record_key = c("K-1", "K-2", "K-3"),
        taxon = c("a", "b", "c"),
        stringsAsFactors = FALSE
    )

    out <- resolve_occurrence_ids(
        df, map_values = list(occurrenceID = "record_key", scientificName = "taxon")
    )

    expect_identical(as.character(out), c("K-1", "K-2", "K-3"))
    expect_identical(attr(out, "id_strategy"), "user_supplied")
    expect_identical(attr(out, "id_counts")$preserved, 3L)
    expect_identical(attr(out, "id_counts")$generated, 0L)
})

test_that("resolve_occurrence_ids falls back to a literal occurrenceID column", {
    # A re-imported Saira export and a camtrapdp::write_dwc() upload both ship
    # the column already named occurrenceID, with no mapping needed.
    df <- data.frame(
        occurrenceID = c("obs-a", "obs-b"),
        x = 1:2,
        stringsAsFactors = FALSE
    )

    out <- resolve_occurrence_ids(df, map_values = list())
    expect_identical(as.character(out), c("obs-a", "obs-b"))
    expect_identical(attr(out, "id_strategy"), "user_supplied")
})

test_that("resolve_occurrence_ids preserves existing ids and fills only new rows", {
    # The round trip: export, add occurrences, re-import. Everything already
    # published keeps its identifier; only the new rows get one.
    df <- data.frame(
        occurrenceID = c("keep-1", "keep-2", "", NA_character_),
        x = 1:4,
        stringsAsFactors = FALSE
    )

    out <- resolve_occurrence_ids(df, map_values = list())
    counts <- attr(out, "id_counts")

    expect_identical(as.character(out)[1:2], c("keep-1", "keep-2"))
    expect_true(all(nzchar(as.character(out))))
    expect_identical(counts$preserved, 2L)
    expect_identical(counts$generated, 2L)
    expect_identical(attr(out, "id_strategy"), "user_supplied_with_generated")
})

test_that("check_occurrence_id_uniqueness separates duplicates from blanks", {
    res <- check_occurrence_id_uniqueness(c("a", "b", "a", "", NA))

    expect_false(res$ok)
    expect_identical(res$duplicates, 1L)
    expect_identical(res$blank, 2L)
    expect_true(check_occurrence_id_uniqueness(c("a", "b"))$ok)
})

# Infraspecific names ----------------------------------------------------

test_that("bare trinomials parse as subspecies with an infraspecific epithet", {
    out <- extract_scientific_name_components(c(
        "Panthera onca palustris",
        "Canis lupus familiaris"
    ))

    expect_identical(out$taxonRank, c("subspecies", "subspecies"))
    expect_identical(out$specificEpithet, c("onca", "lupus"))
    expect_identical(out$infraspecificEpithet, c("palustris", "familiaris"))
})

test_that("explicit rank markers set the matching taxonRank", {
    out <- extract_scientific_name_components(c(
        "Puma concolor subsp. concolor",
        "Solanum lycopersicum var. cerasiforme",
        "Bradypus torquatus f. minor"
    ))

    expect_identical(out$taxonRank, c("subspecies", "variety", "form"))
    expect_identical(
        out$infraspecificEpithet,
        c("concolor", "cerasiforme", "minor")
    )
})

test_that("authorship is never mistaken for an infraspecific epithet", {
    # The third token sits where a subspecies epithet would. Capitalisation is
    # the only signal, and format_epithet_token() cannot be the judge because it
    # lowercases before validating.
    out <- extract_scientific_name_components(c(
        "Dasypus novemcinctus Linnaeus, 1758",
        "Dasypus novemcinctus (Linnaeus, 1758)",
        "Tamandua tetradactyla L.",
        "Bradypus variegatus Schinz 1825"
    ))

    expect_true(all(out$taxonRank == "species"))
    expect_true(all(is.na(out$infraspecificEpithet)))
    expect_true(all(out$specificEpithet %in% c("novemcinctus", "tetradactyla",
                                               "variegatus")))
})

test_that("binomials, genus-only and blank names are unchanged", {
    out <- extract_scientific_name_components(c(
        "Dasypus novemcinctus", "Dasypus sp.", "Dasypus", "", NA
    ))

    expect_identical(out$taxonRank, c("species", "genus", "genus", NA, NA))
    expect_true(all(is.na(out$infraspecificEpithet)))
})

test_that("infraspecificEpithet is only exported when some row carries one", {
    # Pinning it unconditionally would add an empty column (and a meta.xml
    # field) to every dataset without a trinomial.
    binomials <- build_processed_mapping_df(
        df = data.frame(taxon = c("Dasypus novemcinctus"), stringsAsFactors = FALSE),
        dwc_terms = get_active_dwc_terms_list(),
        map_values = list(scientificName = "taxon"),
        occurrence_ids = "id-1"
    )$data
    expect_false("infraspecificEpithet" %in% names(binomials))

    trinomials <- build_processed_mapping_df(
        df = data.frame(taxon = c("Canis lupus familiaris"), stringsAsFactors = FALSE),
        dwc_terms = get_active_dwc_terms_list(),
        map_values = list(scientificName = "taxon"),
        occurrence_ids = "id-1"
    )$data
    expect_identical(trinomials$infraspecificEpithet, "familiaris")
    expect_identical(trinomials$taxonRank, "subspecies")
})

test_that("generated identifiers are derived from row content, not chance", {
    # The requirement is an identifier that stays the same across exports. Being
    # derived from the row itself means re-uploading the same spreadsheet
    # reproduces them, without the user re-importing the exported file.
    df <- data.frame(
        sp = c("Dasypus", "Cabassous"),
        lat = c(-15.7, -22.1),
        stringsAsFactors = FALSE
    )

    first <- resolve_occurrence_ids(df)
    again <- resolve_occurrence_ids(df)

    expect_identical(as.character(first), as.character(again))
    expect_true(all(grepl("^urn:uuid:", as.character(first))))
    expect_identical(attr(first, "id_strategy"), "generated")
})

test_that("a row keeps its identifier when the file is reordered", {
    df <- data.frame(
        sp = c("Dasypus", "Cabassous", "Bradypus"),
        lat = c(-15.7, -22.1, -3.4),
        stringsAsFactors = FALSE
    )

    straight <- as.character(resolve_occurrence_ids(df))
    shuffled <- as.character(resolve_occurrence_ids(df[c(3, 1, 2), ]))

    expect_identical(straight[1], shuffled[2])
    expect_identical(straight[3], shuffled[1])
})

test_that("rows identical in every column get unique, stable identifiers", {
    # Aggregated datasets legitimately hold the same taxon, point and date from
    # different source studies. Content alone would collide, and Darwin Core
    # requires occurrenceID to be unique within the dataset.
    df <- data.frame(
        sp = rep("Dasypus", 4),
        lat = rep(-15.7, 4),
        stringsAsFactors = FALSE
    )

    out <- as.character(resolve_occurrence_ids(df))

    expect_identical(length(unique(out)), 4L)
    expect_identical(out, as.character(resolve_occurrence_ids(df)))
})

test_that("correcting one value changes only that row's identifier", {
    df <- data.frame(
        sp = c("Dasypus", "Cabassous"),
        lat = c(-15.7, -22.1),
        stringsAsFactors = FALSE
    )
    fixed <- df
    fixed$sp[2] <- "Cabassous unicinctus"

    before <- as.character(resolve_occurrence_ids(df))
    after <- as.character(resolve_occurrence_ids(fixed))

    expect_identical(before[1], after[1])
    expect_false(identical(before[2], after[2]))
})

test_that("the identifier column never feeds its own hash", {
    # A row without an identifier must hash the same whether the column is
    # absent or present-but-blank, or a partial upload and a full one would
    # disagree on the identifier for the very same row.
    with_col <- data.frame(
        occurrenceID = c("", ""), sp = c("A", "B"), stringsAsFactors = FALSE
    )
    without_col <- data.frame(sp = c("A", "B"), stringsAsFactors = FALSE)

    expect_identical(
        as.character(resolve_occurrence_ids(with_col)),
        as.character(resolve_occurrence_ids(without_col))
    )
})

test_that("column parts are joined unambiguously", {
    # A plain concatenation would let ("ab","c") and ("a","bc") hash alike.
    df <- data.frame(
        one = c("ab", "a"), two = c("c", "bc"), stringsAsFactors = FALSE
    )
    out <- as.character(resolve_occurrence_ids(df))
    expect_identical(length(unique(out)), 2L)
})

test_that("seq_within_groups numbers each value's repeats in order", {
    expect_identical(
        saira:::seq_within_groups(c("a", "b", "a", "a", "b")),
        c(1L, 1L, 2L, 3L, 2L)
    )
    expect_identical(saira:::seq_within_groups(character(0)), integer(0))
})

test_that("Rostrum scores occurrenceID instead of leaving it manual-only", {
    # An upload that ships identifiers must have them found, not left for the
    # user to notice and wire up by hand. Only terms fed by a dedicated input
    # (modified/license/language) stay unscored.
    raw <- data.frame(
        occurrenceID = c("A-1", "A-2"),
        decimalLatitude = c(-1, -2),
        stringsAsFactors = FALSE
    )

    res <- run_rostrum_engine(df = raw, dwc_terms_df = get_active_dwc_terms())
    row <- res$data[res$data$term == "occurrenceID", ]

    expect_identical(row$selected_col, "occurrenceID")
    expect_identical(row$status, "AUTO")
    expect_true(row$applied)

    for (term in c("modified", "license", "language")) {
        manual <- res$data[res$data$term == term, ]
        expect_identical(manual$reason, "manual_only_term")
    }
})

testthat::test_that("modified/license/language consume their mapped column when no fixed value is set", {
    raw <- data.frame(
        Especie = "Panthera onca", Licenca = "CC0", Idioma = "pt",
        Atualizado = "2024-01-01", stringsAsFactors = FALSE
    )
    dwc <- list(
        list(term = "occurrenceID"), list(term = "scientificName"),
        list(term = "license"), list(term = "language"), list(term = "modified"),
        list(term = "genus"), list(term = "specificEpithet"), list(term = "taxonRank")
    )
    map_values <- list(
        scientificName = "Especie", license = "Licenca",
        language = "Idioma", modified = "Atualizado"
    )

    # These three used to `next` unconditionally, so the mapped column was read
    # by nobody and dropped by the unmapped-column tail as well (issue #98).
    res <- build_processed_mapping_df(
        df = raw, dwc_terms = dwc, map_values = map_values,
        occurrence_ids = "id1"
    )
    testthat::expect_identical(res$data$license, "CC0")
    testthat::expect_identical(res$data$language, "pt")
    testthat::expect_identical(res$data$modified, "2024-01-01")

    # A fixed value still wins over the column.
    res2 <- build_processed_mapping_df(
        df = raw, dwc_terms = dwc, map_values = map_values,
        occurrence_ids = "id1",
        custom_license = "CC-BY", custom_language = "en",
        modified_use_today = TRUE, now_utc = as.POSIXct("2026-02-14 10:11:12", tz = "UTC")
    )
    testthat::expect_identical(res2$data$license, "CC-BY")
    testthat::expect_identical(res2$data$language, "en")
    testthat::expect_identical(res2$data$modified, "2026-02-14")
})

testthat::test_that("a blank fixed value leaves the mapped column in place", {
    raw <- data.frame(
        Especie = "Panthera onca", Municipio = "Curitiba",
        stringsAsFactors = FALSE
    )
    dwc <- list(
        list(term = "occurrenceID"), list(term = "scientificName"),
        list(term = "country"), list(term = "genus"),
        list(term = "specificEpithet"), list(term = "taxonRank")
    )
    # Same shape as the modified/license/language fix: `next` must run only in
    # the branch that consumed the fixed value.
    res <- build_processed_mapping_df(
        df = raw, dwc_terms = dwc,
        map_values = list(scientificName = "Especie", country = "Municipio"),
        occurrence_ids = "id1", constant_values = list(country = "  ")
    )
    testthat::expect_identical(res$data$country, "Curitiba")
})
