# Title: Tests for Mapping Utilities
# Author: RogÃ©rio Nunes Oliveira
# Date: 2026-02-11
# Version: 1.0

reset_synonyms_cache <- function() {
    getFromNamespace("reset_dwc_synonyms_cache", "saira")()
}

synonyms_cache_state <- function() {
    getFromNamespace("dwc_synonyms_cache_state", "saira")()
}

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

testthat::test_that("run_automap_v1 excludes temporal inference except exact match", {
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
    out_synonym <- run_automap_v1(df_synonym_only, dwc_terms, syn)
    testthat::expect_identical(out_synonym$status[[1]], "MANUAL")
    testthat::expect_true(is.na(out_synonym$selected_col[[1]]))

    df_exact <- data.frame(
        eventDate = c("2024-01-01", "2024-01-02"),
        stringsAsFactors = FALSE
    )
    out_exact <- run_automap_v1(df_exact, dwc_terms, syn)
    testthat::expect_true(out_exact$status[[1]] %in% c("AUTO", "SUGERIDO"))
    testthat::expect_identical(out_exact$selected_col[[1]], "eventDate")
})

testthat::test_that("run_automap_v1 resolves conflicts by strongest score", {
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

    out <- run_automap_v1(df, dwc_terms, syn)
    count_rows <- out[out$term %in% c("individualCount", "samplingEffort"), , drop = FALSE]

    testthat::expect_identical(sum(count_rows$applied), 1L)
    testthat::expect_true(any(count_rows$status == "MANUAL"))
    testthat::expect_true(any(count_rows$reason == "conflict_lost"))
})

testthat::test_that("run_automap_v1 returns expected columns and status thresholds", {
    syn <- load_dwc_synonyms_v1(path = test_data_path("dwc_synonyms_v1.rds"))
    dwc_terms <- data.frame(term = c("scientificName", "recordedBy", "decimalLatitude"), stringsAsFactors = FALSE)
    df <- data.frame(
        scientificName = c("Panthera onca", "Leopardus pardalis"),
        collector = c("A", "B"),
        decimalLatitude = c("texto", "invalido"),
        stringsAsFactors = FALSE
    )

    out <- run_automap_v1(df, dwc_terms, syn)

    testthat::expect_true(all(c("term", "selected_col", "name_score", "value_score", "final_score", "status", "reason", "applied") %in% names(out)))
    testthat::expect_true(out$status[out$term == "scientificName"] %in% c("AUTO", "SUGERIDO"))
    testthat::expect_true(out$status[out$term == "recordedBy"] %in% c("SUGERIDO", "MANUAL"))
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
    testthat::expect_identical(out$modified, c("2026-02-14T10:11:12Z", "2026-02-14T10:11:12Z"))
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
