score_token_overlap <- saira:::score_token_overlap
apply_semantic_penalties <- saira:::apply_semantic_penalties
run_rostrum_stage1 <- saira:::run_rostrum_stage1

empty_synonyms <- function() {
    data.frame(
        term = character(0),
        synonym = character(0),
        name_score = numeric(0),
        lang = character(0),
        active = logical(0),
        stringsAsFactors = FALSE
    )
}

testthat::test_that("record favors recordNumber over recordedBy in token overlap scoring", {
    exact_like <- score_token_overlap("record", "recordNumber")
    substring_like <- score_token_overlap("record", "recordedBy")

    testthat::expect_gt(exact_like, substring_like)
})

testthat::test_that("token overlap candidate is rejected when value_score is below 0.8", {
    df <- data.frame(
        decimal_lat = c("-10", "220", "350", "x"),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(term = "decimalLatitude", stringsAsFactors = FALSE)

    out <- run_rostrum_stage1(df, dwc_terms, empty_synonyms(), options = rostrum_options())

    testthat::expect_identical(out$status[[1]], "MANUAL")
    testthat::expect_true(is.na(out$selected_col[[1]]))
})

testthat::test_that("token overlap candidate is accepted when value_score is at least 0.8", {
    df <- data.frame(
        decimal_lat = c("-10", "-20", "15", "0"),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(term = "decimalLatitude", stringsAsFactors = FALSE)

    out <- run_rostrum_stage1(df, dwc_terms, empty_synonyms(), options = rostrum_options())

    testthat::expect_true(out$status[[1]] %in% c("AUTO", "SUGERIDO", "AMBIGUO"))
    testthat::expect_identical(out$selected_col[[1]], "decimal_lat")
})

testthat::test_that("semantic penalties are capped at -0.5", {
    penalty <- apply_semantic_penalties("temp_depth_count_campo1", "decimalLatitude")

    testthat::expect_identical(penalty$score, -0.5)
})

testthat::test_that("final_score stays in [0,1] for random inputs", {
    set.seed(42)
    df <- data.frame(
        decimal_lat = as.character(runif(100, -120, 120)),
        sci_name = sample(c("Panthera onca", "Leopardus pardalis", "foo"), 100, replace = TRUE),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(
        term = c("decimalLatitude", "scientificName"),
        stringsAsFactors = FALSE
    )

    out <- run_rostrum_stage1(df, dwc_terms, empty_synonyms(), options = rostrum_options())
    finite_scores <- out$final_score[!is.na(out$final_score)]

    testthat::expect_true(all(finite_scores >= 0 & finite_scores <= 1))
})

testthat::test_that("error boundary preserves stage 1 when stage 2 fails", {
    df <- data.frame(
        scientificName = c("Panthera onca", "Leopardus pardalis"),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(term = "scientificName", stringsAsFactors = FALSE)

    res <- run_rostrum_engine(
        df = df,
        dwc_terms_df = dwc_terms,
        options = rostrum_options(),
        context = list(force_stage2_error = TRUE),
        synonyms_tbl = empty_synonyms()
    )

    testthat::expect_false(res$stage2$success)
    testthat::expect_true(is.data.frame(res$stage1$data))
    testthat::expect_identical(res$data, res$stage1$data)
})

testthat::test_that("type incompatible column triggers veto for numeric-only terms", {
    # Column named exactly "decimalLatitude" (exact name match, score=1.0)
    # with mostly non-numeric values: numeric_ratio < 0.60 -> compatible_type=FALSE
    # and valid_ratio = 1/3 >= 0.30 so veto_low_validation does NOT fire.
    # resolve_candidate_veto_code must return "type_incompatible".
    df <- data.frame(
        decimalLatitude = c("-45", "north", "south"),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(term = "decimalLatitude", stringsAsFactors = FALSE)

    out <- run_rostrum_stage1(df, dwc_terms, empty_synonyms(), options = rostrum_options())

    testthat::expect_identical(out$veto_code[[1]], "type_incompatible")
    testthat::expect_identical(out$status[[1]], "MANUAL")
    testthat::expect_identical(out$final_score[[1]], 0)
})

testthat::test_that("temperature context penalty reduces latitude mapping score below AUTO", {
    # "lat_temperatura": token "lat" is a substring of "latitude" (token overlap
    # score ~0.51, which is >= 0.45 so value scoring IS triggered).
    # With all valid lat values, value_score = 1.0 and H1 gate does not fire
    # (1.0 >= 0.80). "temperatura" as a whole word triggers the -0.30 semantic
    # penalty. Combined: ~0.76 - 0.30 = ~0.46 -> final_score below AUTO (0.90).
    set.seed(1L)
    df <- data.frame(
        lat_temperatura = as.character(runif(50, -89, 89)),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(term = "decimalLatitude", stringsAsFactors = FALSE)

    out <- run_rostrum_stage1(df, dwc_terms, empty_synonyms(), options = rostrum_options())

    testthat::expect_true(
        is.na(out$final_score[[1]]) || out$final_score[[1]] < 0.90,
        info = paste("final_score was", out$final_score[[1]])
    )
    testthat::expect_false(isTRUE(out$status[[1]] == "AUTO"))
})

local({
    set.seed(99)
    parity_df <- data.frame(
        scientificName = sample(c("Panthera onca", "Leopardus pardalis", "foo"), 200, replace = TRUE),
        scientific_name = sample(c("Panthera onca", "Leopardus pardalis", "foo"), 200, replace = TRUE),
        decimalLatitude = as.character(runif(200, -89, 89)),
        decimal_lat = as.character(runif(200, -89, 89)),
        recorded_by = sample(c("Ana", "Bruno", "Carlos"), 200, replace = TRUE),
        stringsAsFactors = FALSE
    )
    parity_terms <- data.frame(
        term = c("scientificName", "decimalLatitude", "recordedBy"),
        stringsAsFactors = FALSE
    )
    parity_seq_out <- run_rostrum_stage1(
        df = parity_df,
        dwc_terms_df = parity_terms,
        synonyms_tbl = empty_synonyms(),
        options = rostrum_options(stage1_parallel = FALSE)
    )

    assert_parity <- function(par_out) {
        seq_cmp <- parity_seq_out[order(parity_seq_out$term), , drop = FALSE]
        par_cmp <- par_out[order(par_out$term), , drop = FALSE]
        testthat::expect_identical(seq_cmp$term, par_cmp$term)
        testthat::expect_identical(seq_cmp$selected_col, par_cmp$selected_col)
        testthat::expect_equal(seq_cmp$final_score, par_cmp$final_score, tolerance = 1e-12)
        testthat::expect_identical(seq_cmp$status, par_cmp$status)
        testthat::expect_identical(seq_cmp$reason, par_cmp$reason)
    }

    # Multisession: fresh R processes cannot loadNamespace() a pkgload::load_all()'d package.
    # Skips under devtools::test(); runs and must pass under R CMD check (installed pkg).
    testthat::test_that("stage1 parallel multisession matches sequential decisions", {
        testthat::skip_if_not_installed("future")
        testthat::skip_if_not_installed("furrr")
        testthat::skip_if(
            requireNamespace("pkgload", quietly = TRUE) && pkgload::is_dev_package("saira"),
            "future::multisession workers cannot load a pkgload::load_all()'d package; parity verified under R CMD check"
        )
        par_out <- run_rostrum_stage1(
            df = parity_df,
            dwc_terms_df = parity_terms,
            synonyms_tbl = empty_synonyms(),
            options = rostrum_options(
                stage1_parallel = TRUE,
                stage1_parallel_workers = 2L,
                stage1_parallel_strategy = "multisession"
            )
        )
        assert_parity(par_out)
    })

    # Multicore: fork inherits the parent namespace, so this runs correctly under load_all.
    # Skipped on Windows (fork unavailable) and when parallelly::supportsMulticore() is FALSE.
    testthat::test_that("stage1 parallel multicore matches sequential decisions", {
        testthat::skip_if_not_installed("future")
        testthat::skip_if_not_installed("furrr")
        testthat::skip_on_os("windows")
        testthat::skip_if_not(
            requireNamespace("parallelly", quietly = TRUE) && parallelly::supportsMulticore(),
            "multicore not supported on this platform"
        )
        par_out <- run_rostrum_stage1(
            df = parity_df,
            dwc_terms_df = parity_terms,
            synonyms_tbl = empty_synonyms(),
            options = rostrum_options(
                stage1_parallel = TRUE,
                stage1_parallel_workers = 2L,
                stage1_parallel_strategy = "multicore"
            )
        )
        assert_parity(par_out)
    })
})

testthat::test_that("identifier qualifier decides which identifier term a column can fill", {
    entities <- saira:::rostrum_identifier_entities

    testthat::expect_null(entities(c("species", "name")))
    testthat::expect_true(entities("id")$bare)
    testthat::expect_identical(entities(c("location", "id"))$entities, "location")
    testthat::expect_identical(entities(c("xyz", "id"))$entities, character(0))
    testthat::expect_false(entities(c("xyz", "id"))$bare)
})

testthat::test_that("identifier columns are penalized on foreign identifier terms", {
    has_id_penalty <- function(col, term) {
        "identifier_context" %in% apply_semantic_penalties(col, term)$reasons
    }

    testthat::expect_true(has_id_penalty("ID", "locationID"))
    testthat::expect_true(has_id_penalty("species_id", "locationID"))
    testthat::expect_true(has_id_penalty("location_id", "locationRemarks"))
    testthat::expect_true(has_id_penalty("Event_ID", "eventTime"))
    testthat::expect_false(has_id_penalty("ID", "occurrenceID"))
    testthat::expect_false(has_id_penalty("location_id", "locationID"))
    testthat::expect_false(has_id_penalty("xyz_id", "locationID"))
    testthat::expect_false(has_id_penalty("specimen_id", "catalogNumber"))
})

testthat::test_that("a qualifier that names the term entity adds name evidence", {
    bonus <- saira:::rostrum_identifier_name_bonus
    tokens <- saira:::tokenize_for_overlap

    testthat::expect_equal(bonus(tokens("location_id"), "locationID"), 0.10)
    testthat::expect_equal(bonus(tokens("Road_ID"), "locationID"), 0.10)
    testthat::expect_equal(bonus(tokens("study_id"), "locationID"), 0)
    testthat::expect_equal(bonus(tokens("location_id"), "locationRemarks"), 0)
})

testthat::test_that("location_id wins locationID over species_id and study_id", {
    df <- data.frame(
        location_id = c("L1", "L2", "L3", "L1"),
        species_id = c("S1", "S2", "S1", "S3"),
        study_id = c("T1", "T1", "T2", "T2"),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(term = "locationID", stringsAsFactors = FALSE)

    out <- run_rostrum_stage1(df, dwc_terms, empty_synonyms(), options = rostrum_options())

    testthat::expect_identical(out$selected_col[[1]], "location_id")
})

testthat::test_that("off-list values veto a weak name on vocabulary terms", {
    profile_iucn <- saira:::rostrum_build_column_value_profile(c("LC", "VU", "EN", "NT", "LC"))
    profile_pa <- saira:::rostrum_build_column_value_profile(c("presente", "ausente", "present", "absent"))
    value_score <- saira:::compute_value_score_from_profile

    weak <- value_score(profile_iucn, "occurrenceStatus", name_score = 0.60)
    exact <- value_score(profile_iucn, "occurrenceStatus", name_score = 1)
    valid <- value_score(profile_pa, "occurrenceStatus", name_score = 0.60)

    testthat::expect_lt(weak$valid_ratio, 0.30)
    testthat::expect_equal(exact$score, 0.80)
    testthat::expect_equal(valid$valid_ratio, 1)
})

testthat::test_that("basisOfRecord values are checked against its vocabulary", {
    profile <- saira:::rostrum_build_column_value_profile(c("camera trap", "specimen", "observation"))
    profile_bad <- saira:::rostrum_build_column_value_profile(c("Panthera onca", "Puma concolor"))
    value_score <- saira:::compute_value_score_from_profile

    testthat::expect_gt(value_score(profile, "basisOfRecord", name_score = 0.60)$valid_ratio, 0.60)
    testthat::expect_lt(value_score(profile_bad, "basisOfRecord", name_score = 0.60)$valid_ratio, 0.30)
})

one_synonym <- function(term, synonym, name_score = 0.92) {
    data.frame(
        term = term,
        synonym = synonym,
        name_score = name_score,
        lang = "en",
        active = TRUE,
        stringsAsFactors = FALSE
    )
}

testthat::test_that("header abbreviations expand for synonym lookup", {
    expand <- saira:::rostrum_expand_column_name
    profile <- saira:::build_column_matching_profile

    testthat::expect_identical(expand("# of inds."), "number of individuals")
    testthat::expect_identical(expand("VEG_TYPE"), "vegetation type")
    testthat::expect_identical(expand("CAM_EFF"), "cam effort")
    testthat::expect_identical(profile("n_points")$norm_expanded, "number points")
    testthat::expect_false("number" %in% profile("n_points")$tokens)
    testthat::expect_null(profile("site")$norm_expanded)
})

testthat::test_that("a synonym reached through an abbreviation stays SUGERIDO", {
    counts <- c("1", "2", "3", "1", "4")
    synonyms <- one_synonym("individualCount", "number of individuals", 0.94)
    dwc_terms <- data.frame(term = "individualCount", stringsAsFactors = FALSE)
    abbreviated <- data.frame(`# of inds.` = counts, check.names = FALSE)
    spelled <- data.frame(`number of individuals` = counts, check.names = FALSE)

    out_abbreviated <- run_rostrum_stage1(abbreviated, dwc_terms, synonyms, options = rostrum_options())
    out_spelled <- run_rostrum_stage1(spelled, dwc_terms, synonyms, options = rostrum_options())

    testthat::expect_identical(out_abbreviated$status[[1]], "SUGERIDO")
    testthat::expect_identical(out_abbreviated$selected_col[[1]], "# of inds.")
    testthat::expect_identical(out_spelled$status[[1]], "AUTO")
})

testthat::test_that("a one-letter header stays SUGERIDO", {
    longitudes <- c("-45.1", "-46.2", "-44.9")
    dwc_terms <- data.frame(term = "decimalLongitude", stringsAsFactors = FALSE)
    out <- run_rostrum_stage1(
        data.frame(X = longitudes), dwc_terms,
        one_synonym("decimalLongitude", "x", 0.90), options = rostrum_options()
    )

    testthat::expect_identical(out$status[[1]], "SUGERIDO")
    testthat::expect_identical(out$selected_col[[1]], "X")
})

testthat::test_that("eventDate takes a non-exact name only when the values are dates", {
    dwc_terms <- data.frame(term = "eventDate", stringsAsFactors = FALSE)
    synonyms <- one_synonym("eventDate", "date")
    dates <- data.frame(date = c("2020-01-05", "2020-02-11", "2021-03-09"))
    words <- data.frame(date = c("a", "b", "c"))

    out_dates <- run_rostrum_stage1(dates, dwc_terms, synonyms, options = rostrum_options())
    out_words <- run_rostrum_stage1(words, dwc_terms, synonyms, options = rostrum_options())

    testthat::expect_identical(out_dates$status[[1]], "SUGERIDO")
    testthat::expect_identical(out_dates$selected_col[[1]], "date")
    testthat::expect_identical(out_words$status[[1]], "MANUAL")
})

testthat::test_that("other temporal terms still need an exact name", {
    df <- data.frame(det_date = c("2020-01-05", "2020-02-11", "2021-03-09"))
    dwc_terms <- data.frame(term = "dateIdentified", stringsAsFactors = FALSE)

    out <- run_rostrum_stage1(df, dwc_terms, one_synonym("dateIdentified", "det date"),
                              options = rostrum_options())

    testthat::expect_identical(out$reason[[1]], "temporal_manual_only")
})

testthat::test_that("a column named like another term does not compete for this term", {
    df <- data.frame(
        OBS = c("seen at dawn", "tracks only", "near road"),
        locationRemarks = c("near river", "forest edge", "pasture"),
        stringsAsFactors = FALSE
    )
    dwc_terms <- data.frame(term = c("occurrenceRemarks", "locationRemarks"), stringsAsFactors = FALSE)

    out <- run_rostrum_stage1(df, dwc_terms, one_synonym("occurrenceRemarks", "obs"),
                              options = rostrum_options())
    remarks <- out[out$term == "occurrenceRemarks", ]

    testthat::expect_identical(remarks$status[[1]], "SUGERIDO")
    testthat::expect_identical(remarks$selected_col[[1]], "OBS")
    testthat::expect_false(grepl("locationRemarks", remarks$alternatives_json[[1]], fixed = TRUE))
})

testthat::test_that("the synonym bundle carries survey field names", {
    bundle <- saira:::load_dwc_synonyms_v1()
    pairs <- paste(bundle$term, bundle$synonym)

    testthat::expect_true(all(c(
        "locality site", "habitat vegetation type", "individualCount number of individuals",
        "occurrenceStatus presence absence", "eventDate date"
    ) %in% pairs))
})
