# Title: Tests for DwC term cache utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-14
# Version: 1.0

reset_terms_cache <- function() saira:::reset_dwc_terms_cache()
terms_cache_state <- function() saira:::dwc_terms_cache_state()

testthat::test_that("validate_coords handles decimal comma bounds and returns issue types", {
    out <- validate_coords(
        lat = c("-23,55", "91", NA_character_, "10"),
        lon = c("-46,63", "-46,63", "-46,63", "181")
    )

    testthat::expect_s3_class(out, "data.frame")
    testthat::expect_equal(out$decimalLatitude[1], -23.55)
    testthat::expect_equal(out$decimalLongitude[1], -46.63)
    testthat::expect_identical(out$issue_type, c("ok", "swapped", "missing", "lon_range"))
    testthat::expect_identical(out$valid, c(TRUE, TRUE, FALSE, FALSE))
    testthat::expect_identical(out$error_key[2], "validate_coords_badge_swapped")
    testthat::expect_identical(out$error_key[3], "validate_coords_badge_missing")
    testthat::expect_identical(out$error_key[4], "validate_coords_badge_lon_range")
})

testthat::test_that("validate_occurrence_id enforces uniqueness and non-empty values", {
    ids <- c("id-1", "id-1", "id-2", NA_character_, "", "id-2", "id-3")
    out <- validate_occurrence_id(ids)

    testthat::expect_identical(out, c(TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, TRUE))
})

testthat::test_that("get_dwc_terms_list supports pt and falls back to english for unknown language", {
    reset_terms_cache()
    on.exit(reset_terms_cache(), add = TRUE)

    terms <- get_dwc_terms()
    en_list <- get_dwc_terms_list("en")
    pt_list <- get_dwc_terms_list("pt")
    unknown_lang_list <- get_dwc_terms_list("es")

    testthat::expect_identical(sort(names(en_list)), sort(as.character(terms$term)))
    testthat::expect_identical(sort(names(pt_list)), sort(as.character(terms$term)))
    testthat::expect_identical(sort(names(unknown_lang_list)), sort(as.character(terms$term)))

    sample_term <- names(en_list)[1]
    sample_entry <- en_list[[sample_term]]
    testthat::expect_true(all(c("term", "category", "desc", "sep", "required") %in% names(sample_entry)))
    testthat::expect_identical(sample_entry$sep, "")
    testthat::expect_type(sample_entry$required, "logical")

    if ("definition_en" %in% names(terms)) {
        idx <- which(!is.na(terms$definition_en) & nzchar(as.character(terms$definition_en)))[1]
        if (!is.na(idx)) {
            key <- as.character(terms$term[idx])
            testthat::expect_identical(unknown_lang_list[[key]]$desc, en_list[[key]]$desc)
        }
    }

    if ("definition_pt" %in% names(terms)) {
        idx <- which(!is.na(terms$definition_pt) & nzchar(as.character(terms$definition_pt)))[1]
        if (!is.na(idx)) {
            key <- as.character(terms$term[idx])
            testthat::expect_identical(
                pt_list[[key]]$desc,
                as.character(terms$definition_pt[idx])
            )
        }
    }
})

testthat::test_that("load_dwc_terms_rds caches first read and reuses on second call", {
    reset_terms_cache()
    on.exit(reset_terms_cache(), add = TRUE)

    first <- load_dwc_terms_rds()
    state_after_first <- terms_cache_state()
    second <- load_dwc_terms_rds()
    state_after_second <- terms_cache_state()

    testthat::expect_true(is.data.frame(first))
    testthat::expect_true(state_after_first$has_value)
    testthat::expect_identical(state_after_first$load_count, 1L)
    testthat::expect_identical(state_after_second$load_count, 1L)
    testthat::expect_identical(first, second)
})

testthat::test_that("load_dwc_terms_rds force reload invalidates cache explicitly", {
    reset_terms_cache()
    on.exit(reset_terms_cache(), add = TRUE)

    first <- load_dwc_terms_rds()
    state_after_first <- terms_cache_state()
    forced <- load_dwc_terms_rds(force = TRUE)
    state_after_force <- terms_cache_state()

    testthat::expect_identical(state_after_first$load_count, 1L)
    testthat::expect_identical(state_after_force$load_count, 2L)
    testthat::expect_identical(first, forced)
})

testthat::test_that("dwc term consumers share cache and keep semantic consistency", {
    reset_terms_cache()
    on.exit(reset_terms_cache(), add = TRUE)

    all_terms <- get_dwc_terms()
    required_terms <- get_required_dwc_terms()
    terms_list <- get_dwc_terms_list("en")
    state <- terms_cache_state()

    testthat::expect_identical(state$load_count, 1L)
    testthat::expect_true(all(required_terms$required))
    testthat::expect_true(all(required_terms$term %in% all_terms$term))
    testthat::expect_identical(sort(names(terms_list)), sort(as.character(all_terms$term)))
})

testthat::test_that("load_dwc_terms_rds validates force flag", {
    reset_terms_cache()
    on.exit(reset_terms_cache(), add = TRUE)

    testthat::expect_error(load_dwc_terms_rds(force = NA), "force must be a single TRUE or FALSE value")
    testthat::expect_error(load_dwc_terms_rds(force = c(TRUE, FALSE)), "force must be a single TRUE or FALSE value")
    testthat::expect_error(load_dwc_terms_rds(force = "TRUE"), "force must be a single TRUE or FALSE value")
})

testthat::test_that("basisOfRecord vocabulary is complete and ordered", {
    get_vocab <- saira:::get_basis_of_record_vocab
    get_terms <- saira:::get_basis_of_record_terms
    is_valid <- saira:::is_valid_basis_of_record_term

    expected_terms <- c(
        "PreservedSpecimen",
        "FossilSpecimen",
        "LivingSpecimen",
        "HumanObservation",
        "MachineObservation",
        "MaterialSample",
        "MaterialCitation",
        "Occurrence"
    )

    vocab_en <- get_vocab("en")
    vocab_pt <- get_vocab("pt")
    terms <- get_terms()

    testthat::expect_identical(terms, expected_terms)
    testthat::expect_identical(
        vapply(vocab_en, function(x) x$term, FUN.VALUE = character(1)),
        expected_terms
    )
    testthat::expect_identical(
        vapply(vocab_pt, function(x) x$term, FUN.VALUE = character(1)),
        expected_terms
    )

    for (term in expected_terms) {
        testthat::expect_true(is_valid(term))
    }

    testthat::expect_false(is_valid("UnknownValue"))
    testthat::expect_false(is_valid(""))
})

testthat::test_that("default base term set matches the Rede Felinos template + kept extras", {
    base <- get_dwc_terms()
    terms <- base$term

    # 64 template + kept extras, plus the two establishment terms promoted in
    # ADR-110 so their per-species assistant is reachable without "Add term".
    testthat::expect_identical(nrow(base), 66L)
    establishment_added <- c("establishmentMeans", "degreeOfEstablishment")
    testthat::expect_true(all(establishment_added %in% terms))
    testthat::expect_true(all(
        base$class[match(establishment_added, terms)] == "Occurrence"
    ))
    # Optional: the assistant must never make them a gate for export.
    testthat::expect_false(any(base$required[match(establishment_added, terms)]))

    # Template terms newly added to the default.
    template_added <- c(
        "locationID", "coordinateUncertaintyInMeters", "eventID", "parentEventID",
        "eventTime", "sampleSizeValue", "sampleSizeUnit", "taxonRemarks", "sex",
        "lifeStage", "reproductiveCondition", "behavior", "identifiedByID",
        "identificationRemarks", "informationWithheld", "associatedMedia",
        "associatedReferences"
    )
    testthat::expect_true(all(template_added %in% terms))

    # Curated extras kept in the default beyond the 51 template terms.
    kept_extras <- c("year", "month", "day", "catalogNumber", "collectionCode",
                     "taxonRank", "kingdom", "phylum", "scientificNameAuthorship",
                     "rightsHolder", "verbatimLatitude", "verbatimLongitude",
                     "fieldNotes")
    testthat::expect_true(all(kept_extras %in% terms))

    # Dropped from the default (still reachable via the full catalog).
    dropped <- c("disposition", "preparations", "infraspecificEpithet",
                 "verbatimIdentification")
    testthat::expect_false(any(dropped %in% terms))
    testthat::expect_true(all(dropped %in% get_dwc_full_catalog()$term))

    # First card is the occurrence identifier; required gate terms preserved.
    testthat::expect_identical(terms[[1]], "occurrenceID")
    required_terms <- c("occurrenceID", "license", "institutionCode",
                        "basisOfRecord", "recordedBy", "eventDate",
                        "scientificName", "country", "stateProvince", "locality",
                        "decimalLatitude", "decimalLongitude")
    testthat::expect_true(all(base$required[match(required_terms, terms)]))

    # Coherent class grouping: temporal/sampling terms live under Event.
    testthat::expect_identical(base$class[base$term == "eventDate"], "Event")
    testthat::expect_identical(base$class[base$term == "year"], "Event")

    # TDWG resync: catalogNumber is organised under MaterialEntity upstream.
    testthat::expect_identical(base$class[base$term == "catalogNumber"], "MaterialEntity")
})

testthat::test_that("get_dwc_full_catalog returns superset of base terms with correct schema", {
    base    <- get_dwc_terms()
    catalog <- get_dwc_full_catalog()

    testthat::expect_s3_class(catalog, "data.frame")
    testthat::expect_gte(nrow(catalog), nrow(base))
    testthat::expect_true(all(base$term %in% catalog$term))
    testthat::expect_identical(
        sort(names(catalog)),
        sort(c("term", "class", "definition_en", "definition_pt",
               "examples", "required", "data_type"))
    )
    testthat::expect_identical(
        sum(catalog$required),
        sum(base$required)
    )
    base_idx <- match(base$term, catalog$term)
    testthat::expect_false(anyNA(base_idx))
    # Base terms appear before extra terms (first nrow(base) rows)
    testthat::expect_identical(catalog$term[seq_len(nrow(base))], base$term)
})

testthat::test_that("get_dwc_full_catalog PT translations preserved from base", {
    base    <- get_dwc_terms()
    catalog <- get_dwc_full_catalog()

    for (trm in base$term) {
        pt_base    <- base$definition_pt[base$term == trm]
        pt_catalog <- catalog$definition_pt[catalog$term == trm]
        testthat::expect_identical(pt_catalog, pt_base,
            info = paste("definition_pt mismatch for term:", trm))
    }
})

testthat::test_that("every full-catalog term has a non-empty PT definition", {
    catalog <- get_dwc_full_catalog()
    empty   <- catalog$term[!nzchar(trimws(catalog$definition_pt))]
    testthat::expect_identical(
        empty, character(0),
        info = paste("terms missing definition_pt:",
                      paste(empty, collapse = ", "))
    )
})

testthat::test_that("extra (non-base) term renders PT, not the EN fallback", {
    base_terms <- get_dwc_terms()$term
    catalog    <- get_dwc_full_catalog()
    extra_term <- catalog$term[!catalog$term %in% base_terms][[1]]

    pt <- get_active_dwc_terms_list(extra = extra_term, lang = "pt")
    en <- get_active_dwc_terms_list(extra = extra_term, lang = "en")

    pt_desc <- pt[[extra_term]]$desc
    en_desc <- en[[extra_term]]$desc

    testthat::expect_true(nzchar(pt_desc))
    testthat::expect_false(identical(pt_desc, en_desc))
    testthat::expect_identical(
        pt_desc,
        catalog$definition_pt[catalog$term == extra_term]
    )
})

testthat::test_that("get_active_dwc_terms returns base set when no extras supplied", {
    base   <- get_dwc_terms()
    active <- get_active_dwc_terms()

    testthat::expect_identical(active, base)
})

testthat::test_that("get_active_dwc_terms appends valid extra terms from catalog", {
    base    <- get_dwc_terms()
    catalog <- get_dwc_full_catalog()
    extras  <- setdiff(catalog$term, base$term)

    testthat::expect_gte(length(extras), 1L)
    extra_term <- extras[[1]]
    active     <- get_active_dwc_terms(extra = extra_term)

    testthat::expect_equal(nrow(active), nrow(base) + 1L)
    testthat::expect_true(extra_term %in% active$term)
    testthat::expect_identical(active$term[seq_len(nrow(base))], base$term)
})

testthat::test_that("get_active_dwc_terms ignores duplicates of base terms", {
    base       <- get_dwc_terms()
    base_term  <- base$term[[1]]
    active     <- get_active_dwc_terms(extra = base_term)

    testthat::expect_equal(nrow(active), nrow(base))
})

testthat::test_that("get_active_dwc_terms ignores extra terms not in catalog", {
    base   <- get_dwc_terms()
    active <- get_active_dwc_terms(extra = "notARealDwCTerm_xyz")

    testthat::expect_equal(nrow(active), nrow(base))
})

testthat::test_that("get_active_dwc_terms_list returns base list when no extras", {
    base_list <- get_dwc_terms_list(lang = "en")
    active    <- get_active_dwc_terms_list(extra = character(0), lang = "en")

    testthat::expect_equal(length(active), length(base_list))
    testthat::expect_setequal(
        unname(vapply(active, function(x) x$term, FUN.VALUE = character(1))),
        unname(vapply(base_list, function(x) x$term, FUN.VALUE = character(1)))
    )
})

testthat::test_that("get_active_dwc_terms_list appends a valid extra and keeps schema", {
    catalog    <- get_dwc_full_catalog()
    base_terms <- get_dwc_terms()$term
    extra_term <- catalog$term[!catalog$term %in% base_terms][[1]]

    active <- get_active_dwc_terms_list(extra = extra_term, lang = "en")
    terms  <- vapply(active, function(x) x$term, FUN.VALUE = character(1))

    testthat::expect_true(extra_term %in% terms)
    testthat::expect_equal(length(active), length(base_terms) + 1L)

    appended <- active[[which(terms == extra_term)]]
    testthat::expect_named(appended, c("term", "category", "desc", "sep", "required"))
    testthat::expect_type(appended$desc, "character")
    testthat::expect_type(appended$required, "logical")
})

testthat::test_that("get_active_dwc_terms_list deduplicates extras already in base", {
    base_terms <- get_dwc_terms()$term
    base_term  <- base_terms[[1]]

    active <- get_active_dwc_terms_list(extra = base_term, lang = "en")

    testthat::expect_equal(length(active), length(base_terms))
})

testthat::test_that("basisOfRecord choices include skip option and descriptions", {
    get_choices <- saira:::get_basis_of_record_term_choices

    pt_choices <- get_choices(lang = "pt", include_skip = TRUE, with_description = TRUE, skip_label = "-- Não mapear --")
    en_choices <- get_choices(lang = "en", include_skip = TRUE, with_description = TRUE, skip_label = "-- Skip --")

    testthat::expect_true("-- Não mapear --" %in% names(pt_choices))
    testthat::expect_true("-- Skip --" %in% names(en_choices))
    testthat::expect_identical(unname(pt_choices[["-- Não mapear --"]]), "")
    testthat::expect_identical(unname(en_choices[["-- Skip --"]]), "")

    testthat::expect_true(any(grepl("HumanObservation", names(en_choices), fixed = TRUE)))
    pt_choice_names_ascii <- iconv(names(pt_choices), from = "", to = "ASCII//TRANSLIT")
    testthat::expect_true(any(grepl("Observacao", pt_choice_names_ascii, fixed = TRUE)))
})

testthat::test_that("detect_extra_dwc_terms returns catalog-valid, non-base columns only", {
    cols <- c("scientificName", "geodeticDatum", "taxonID", "my_random_col", "")
    extra <- detect_extra_dwc_terms(cols)
    # geodeticDatum / taxonID are DwC terms outside the base set.
    testthat::expect_true(all(c("geodeticDatum", "taxonID") %in% extra))
    # Base terms and non-DwC columns are excluded.
    testthat::expect_false("scientificName" %in% extra)
    testthat::expect_false("my_random_col" %in% extra)
    testthat::expect_false("" %in% extra)
    # None of the returned terms belong to the curated base set.
    testthat::expect_length(intersect(extra, get_dwc_terms()$term), 0L)
})

testthat::test_that("detect_extra_dwc_terms handles empty input", {
    testthat::expect_identical(detect_extra_dwc_terms(character(0)), character(0))
    testthat::expect_identical(detect_extra_dwc_terms(c(NA, "")), character(0))
})
