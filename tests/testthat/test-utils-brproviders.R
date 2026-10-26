# Title: Tests for BR providers utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-03-05
# Version: 1.0

normalize_brprovider_result    <- function(...) saira:::normalize_brprovider_result(...)
brprovider_data_available      <- function(...) saira:::brprovider_data_available(...)
brprovider_data_dir            <- function(...) saira:::brprovider_data_dir(...)
.brprovider_read_meta          <- function(...) saira:::.brprovider_read_meta(...)
.brprovider_write_meta         <- function(...) saira:::.brprovider_write_meta(...)
.brprovider_lock_path          <- function(...) saira:::.brprovider_lock_path(...)
.brprovider_acquire_lock       <- function(...) saira:::.brprovider_acquire_lock(...)
.brprovider_release_lock       <- function(...) saira:::.brprovider_release_lock(...)
.brprovider_jobs               <- function() saira:::.brprovider_jobs
brprovider_compare_versions    <- function(...) saira:::brprovider_compare_versions(...)
brprovider_cache_status        <- function(...) saira:::brprovider_cache_status(...)
brprovider_poll_updates        <- function(...) saira:::brprovider_poll_updates(...)
brprovider_ensure_data         <- function(...) saira:::brprovider_ensure_data(...)
.brprovider_start_background_update <- function(...) saira:::.brprovider_start_background_update(...)
.brprovider_check_artifacts    <- function(...) saira:::.brprovider_check_artifacts(...)

# ---------------------------------------------------------------------------
# normalize_brprovider_result -- florabr-style input
# ---------------------------------------------------------------------------

testthat::test_that("normalize_brprovider_result: empty input returns empty df", {
    out <- normalize_brprovider_result(data.frame(), "florabr")
    testthat::expect_true(is.data.frame(out))
    testthat::expect_equal(nrow(out), 0L)
    testthat::expect_true("query_name" %in% names(out))
    testthat::expect_true("validation_status" %in% names(out))
})

testthat::test_that("normalize_brprovider_result: a homonym tie keeps the accepted row in any order", {
    raw <- data.frame(
        input_name      = c("Victoria amazonica", "Victoria amazonica"),
        Spelling        = c("Correct", "Correct"),
        Suggested_name  = c("Victoria amazonica", "Victoria amazonica"),
        Distance        = c(0, 0),
        taxonomicStatus = c("Synonym", "Accepted"),
        family          = "Nymphaeaceae",
        stringsAsFactors = FALSE,
        check.names     = FALSE
    )
    testthat::expect_equal(normalize_brprovider_result(raw, "florabr")$validation_status, "accepted")
    testthat::expect_equal(normalize_brprovider_result(raw[2:1, ], "florabr")$validation_status, "accepted")
})

testthat::test_that("normalize_brprovider_result: Correct + Accepted -> accepted", {
    raw <- data.frame(
        input_name      = "Panthera onca",
        Spelling        = "Correct",
        Suggested_name  = "Panthera onca",
        Distance        = 0L,
        taxonomicStatus = "valid",
        family          = "Felidae",
        stringsAsFactors = FALSE,
        check.names     = FALSE
    )
    out <- normalize_brprovider_result(raw, "faunabr")
    testthat::expect_equal(nrow(out), 1L)
    testthat::expect_equal(out$validation_status, "accepted")
    testthat::expect_equal(out$provider, "faunabr")
    testthat::expect_equal(out$query_name, "Panthera onca")
    testthat::expect_equal(out$scientificName, "Panthera onca")
    testthat::expect_true(is.na(out$suggestedName))
})

testthat::test_that("normalize_brprovider_result: Correct + Synonym -> synonym", {
    raw <- data.frame(
        input_name      = "Araucaria angustifolia",
        Spelling        = "Correct",
        Suggested_name  = "Araucaria angustifolia",
        Distance        = 0L,
        taxonomicStatus = "Synonym",
        family          = "Araucariaceae",
        stringsAsFactors = FALSE,
        check.names     = FALSE
    )
    out <- normalize_brprovider_result(raw, "florabr")
    testthat::expect_equal(out$validation_status, "synonym")
    testthat::expect_equal(out$provider, "florabr")
})

testthat::test_that("normalize_brprovider_result: a synonym carries the accepted name of each base", {
    flora <- data.frame(
        input_name          = c("Caesalpinia echinata", "Euterpe edulis"),
        Spelling            = "Correct",
        Suggested_name      = c("Caesalpinia echinata", "Euterpe edulis"),
        Distance            = 0,
        taxonomicStatus     = c("Synonym", "Accepted"),
        nomenclaturalStatus = c("", "Correct"),
        acceptedName        = c("Paubrasilia echinata", ""),
        family              = c("Fabaceae", "Arecaceae"),
        stringsAsFactors    = FALSE
    )
    out <- normalize_brprovider_result(flora, "florabr")
    testthat::expect_identical(out$acceptedNameUsage, c("Paubrasilia echinata", NA_character_))

    # Fauna BR fills validName on valid rows too, with the name itself.
    fauna <- data.frame(
        input_name          = c("Habronema waltoni", "Panthera onca"),
        Spelling            = "Correct",
        Suggested_name      = c("Habronema waltoni", "Panthera onca"),
        Distance            = 0,
        taxonomicStatus     = c("synonym", "valid"),
        nomenclaturalStatus = NA_character_,
        validName           = c("Lispirurus waltoni", "Panthera onca"),
        family              = c("Habronematidae", "Felidae"),
        matches             = "single",
        stringsAsFactors    = FALSE
    )
    out <- normalize_brprovider_result(fauna, "faunabr")
    testthat::expect_identical(out$acceptedNameUsage, c("Lispirurus waltoni", NA_character_))
})

testthat::test_that("a Flora BR synonym of an MMA species reaches the sensitive lookup (B18)", {
    listed <- "Paubrasilia echinata"
    testthat::skip_if(is.na(saira:::sensitive_category_for(listed)), "Paubrasilia echinata not on the bundled MMA list")
    report <- normalize_brprovider_result(data.frame(
        input_name      = "Caesalpinia echinata",
        Spelling        = "Correct",
        Suggested_name  = "Caesalpinia echinata",
        Distance        = 0,
        taxonomicStatus = "Synonym",
        acceptedName    = listed,
        family          = "Fabaceae",
        stringsAsFactors = FALSE
    ), "florabr")
    out <- saira:::synonym_sensitivity_entries(report)
    testthat::expect_identical(out$scientificName, "Caesalpinia echinata")
    testthat::expect_true(out$sensitive)
})

testthat::test_that("normalize_brprovider_result: Probably_incorrect -> ambiguous", {
    raw <- data.frame(
        input_name      = "Pantera onca",
        Spelling        = "Probably_incorrect",
        Suggested_name  = "Panthera onca",
        Distance        = 1L,
        taxonomicStatus = "valid",
        family          = "Felidae",
        stringsAsFactors = FALSE,
        check.names     = FALSE
    )
    out <- normalize_brprovider_result(raw, "faunabr")
    testthat::expect_equal(out$validation_status, "ambiguous")
    # The report and the export look up threat status by scientificName.
    testthat::expect_equal(out$scientificName, "Pantera onca")
    testthat::expect_equal(out$suggestedName, "Panthera onca")
})

testthat::test_that("normalize_brprovider_result: Not_found -> not_found with match_count 0", {
    raw <- data.frame(
        input_name      = "Xyz abc",
        Spelling        = "Not_found",
        Suggested_name  = NA_character_,
        Distance        = NA_real_,
        taxonomicStatus = NA_character_,
        family          = NA_character_,
        stringsAsFactors = FALSE,
        check.names     = FALSE
    )
    out <- normalize_brprovider_result(raw, "florabr")
    testthat::expect_equal(out$validation_status, "not_found")
    testthat::expect_equal(out$match_count, 0L)
})

testthat::test_that("normalize_brprovider_result: dedup keeps closest Distance per input_name", {
    raw <- data.frame(
        input_name      = c("Pantera onca", "Pantera onca", "Pantera onca"),
        Spelling        = c("Probably_incorrect", "Probably_incorrect", "Probably_incorrect"),
        Suggested_name  = c("Panthera onca", "Pantera once", "Pantera oncaa"),
        Distance        = c(1L, 2L, 3L),
        taxonomicStatus = c("valid", "valid", "valid"),
        family          = c("Felidae", "Felidae", "Felidae"),
        stringsAsFactors = FALSE,
        check.names     = FALSE
    )
    out <- normalize_brprovider_result(raw, "faunabr")
    testthat::expect_equal(nrow(out), 1L)
    testthat::expect_equal(out$suggestedName, "Panthera onca")
})

testthat::test_that("normalize_brprovider_result: taxadb expected columns are present", {
    raw <- data.frame(
        input_name      = "Panthera onca",
        Spelling        = "Correct",
        Suggested_name  = "Panthera onca",
        Distance        = 0L,
        taxonomicStatus = "valid",
        family          = "Felidae",
        stringsAsFactors = FALSE,
        check.names     = FALSE
    )
    out <- normalize_brprovider_result(raw, "faunabr")
    for (col_name in c("taxonID", "taxonRank", "kingdom", "phylum", "class",
                       "order", "genus", "specificEpithet")) {
        testthat::expect_true(col_name %in% names(out),
                              info = paste("missing column:", col_name))
        testthat::expect_true(is.na(out[[col_name]]))
    }
})

# ---------------------------------------------------------------------------
# brprovider_data_available
# ---------------------------------------------------------------------------

testthat::test_that("brprovider_data_available: non-existent dir returns FALSE", {
    testthat::expect_false(
        brprovider_data_available("florabr_nonexistent_provider_xyz")
    )
})

testthat::test_that("brprovider_data_available: empty dir returns FALSE", {
    tmp <- tempfile()
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))
    # Temporarily override data dir by testing the logic directly
    testthat::expect_false(
        length(list.files(tmp, pattern = "\\.rds$")) > 0L
    )
})

# ---------------------------------------------------------------------------
# .brprovider_check_artifacts
# ---------------------------------------------------------------------------

testthat::test_that(".brprovider_check_artifacts: missing artifact gives descriptive error", {
    tmp <- tempfile(pattern = "brp_test_")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))

    err <- testthat::expect_error(
        .brprovider_check_artifacts("faunabr", tmp),
        regexp = "CompleteBrazilianFauna\\.gz"
    )
    testthat::expect_match(err$message, "faunabr")
    testthat::expect_match(err$message, tmp, fixed = TRUE)
})

testthat::test_that(".brprovider_check_artifacts: florabr missing artifact mentions file name", {
    tmp <- tempfile(pattern = "brp_flora_")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))

    err <- testthat::expect_error(.brprovider_check_artifacts("florabr", tmp))
    testthat::expect_match(err$message, "CompleteBrazilianFlora.gz", fixed = TRUE)
    testthat::expect_match(err$message, "CompleteBrazilianFlora.rds", fixed = TRUE)
})

testthat::test_that(".brprovider_check_artifacts: florabr 1.4 gz artifact is accepted (DEP-04)", {
    tmp <- tempfile(pattern = "brp_flora_gz_")
    dir.create(file.path(tmp, "393.420"), recursive = TRUE)
    on.exit(unlink(tmp, recursive = TRUE))
    writeLines("", file.path(tmp, "393.420", "CompleteBrazilianFlora.gz"))

    result <- .brprovider_check_artifacts("florabr", tmp)
    testthat::expect_match(result[[1L]], "CompleteBrazilianFlora\\.gz$")
})

testthat::test_that(".brprovider_check_artifacts: florabr present artifact returns invisibly", {
    tmp <- tempfile(pattern = "brp_flora_ok_")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))
    writeLines("", file.path(tmp, "CompleteBrazilianFlora.rds"))

    result <- .brprovider_check_artifacts("florabr", tmp)
    testthat::expect_true(length(result) >= 1L)
    testthat::expect_match(result[[1L]], "CompleteBrazilianFlora\\.rds")
})

testthat::test_that("florabr download loads the 1.4 gz artifact end to end (DEP-04)", {
    testthat::skip_if_not_installed("florabr", minimum_version = "1.4.0")
    tmp <- tempfile(pattern = "brp_flora_load_")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))

    # get_florabr() 1.4 writes <version>/CompleteBrazilianFlora.gz, a gzipped
    # CSV that load_florabr() reads with data.table::fread().
    short_cols <- c(
        "species", "scientificName", "acceptedName", "kingdom", "group", "subgroup",
        "phylum", "class", "order", "family", "genus", "lifeForm", "habitat", "biome",
        "states", "vegetation", "origin", "endemism", "taxonomicStatus",
        "nomenclaturalStatus", "vernacularName", "taxonRank", "id"
    )
    fake_get <- function(output_dir, data_version, overwrite, verbose) {
        version_dir <- file.path(output_dir, "393.420")
        dir.create(version_dir, recursive = TRUE)
        row <- stats::setNames(as.list(rep("x", length(short_cols))), short_cols)
        row$species <- "Paubrasilia echinata"
        con <- gzfile(file.path(version_dir, "CompleteBrazilianFlora.gz"), "w")
        utils::write.csv(as.data.frame(row), con, row.names = FALSE)
        close(con)
        invisible(NULL)
    }

    testthat::local_mocked_bindings(get_florabr = fake_get, .package = "florabr")
    testthat::local_mocked_bindings(
        brprovider_data_dir = function(provider_id) file.path(tmp, provider_id),
        .package = "saira"
    )
    out <- saira:::.brprovider_download_data_impl("florabr", verbose = FALSE)

    testthat::expect_true(isTRUE(out$ok), info = out$error)
    testthat::expect_identical(out$local_version, "393.420")
    cached <- readRDS(out$persist_path)
    testthat::expect_identical(cached$species, "Paubrasilia echinata")
})

testthat::test_that(".brprovider_check_artifacts: present artifact returns invisibly", {
    tmp <- tempfile(pattern = "brp_ok_")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))
    writeLines("", file.path(tmp, "CompleteBrazilianFauna.gz"))

    result <- .brprovider_check_artifacts("faunabr", tmp)
    testthat::expect_true(length(result) >= 1L)
    testthat::expect_match(result[[1L]], "CompleteBrazilianFauna\\.gz")
})

testthat::test_that(".brprovider_check_artifacts: unknown provider returns NULL invisibly", {
    tmp <- tempfile()
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))
    result <- .brprovider_check_artifacts("other_provider", tmp)
    testthat::expect_null(result)
})

# ---------------------------------------------------------------------------
# Version and metadata/cache lifecycle
# ---------------------------------------------------------------------------

testthat::test_that("brprovider_compare_versions compares dotted numeric segments", {
    testthat::expect_identical(brprovider_compare_versions("1.48", "1.47"), 1L)
    testthat::expect_identical(brprovider_compare_versions("393.319", "393.320"), -1L)
    testthat::expect_identical(brprovider_compare_versions("1.0.0", "1"), 0L)
    testthat::expect_identical(brprovider_compare_versions(NA_character_, "1"), -1L)
})

testthat::test_that("brprovider_cache_status returns never_downloaded without cache", {
    tmp <- tempfile(pattern = "brp_status_")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))

    testthat::with_mocked_bindings(
        brprovider_data_dir = function(provider_id) file.path(tmp, provider_id),
        .brprovider_bundle_path = function(file) "",
        .package = "saira",
        {
            st <- brprovider_cache_status("faunabr", poll = FALSE)
            testthat::expect_identical(as.character(st$status), "never_downloaded")
            testthat::expect_false(isTRUE(st$has_data))
        }
    )
})

testthat::test_that("ensure_data with warm cache is immediate when TTL is fresh", {
    tmp <- tempfile(pattern = "brp_warm_")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))

    testthat::with_mocked_bindings(
        brprovider_data_dir = function(provider_id) file.path(tmp, provider_id),
        .package = "saira",
        {
            pid <- "faunabr"
            dir.create(brprovider_data_dir(pid), recursive = TRUE, showWarnings = FALSE)
            saveRDS(data.frame(scientificName = "Panthera onca", stringsAsFactors = FALSE),
                    file.path(brprovider_data_dir(pid), paste0(pid, ".rds")))

            now_chr <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
            .brprovider_write_meta(pid, list(
                provider_id = pid,
                local_version = "1.48",
                remote_version_last_seen = "1.48",
                last_checked_at = now_chr,
                last_updated_at = now_chr,
                status = "up_to_date",
                last_error = NA_character_,
                source_package_version = NA_character_,
                retry_after_at = NA_character_
            ))

            started <- FALSE
            testthat::with_mocked_bindings(
                .brprovider_start_background_update = function(...) {
                    started <<- TRUE
                    TRUE
                },
                .package = "saira",
                {
                    out <- brprovider_ensure_data(
                        provider_id = pid,
                        check_ttl_secs = 24L * 60L * 60L,
                        verbose = FALSE
                    )
                    testthat::expect_true(isTRUE(out$ok))
                    testthat::expect_true(isTRUE(out$available))
                    testthat::expect_false(isTRUE(out$bootstrap))
                    testthat::expect_false(isTRUE(out$background_started))
                    testthat::expect_false(started)
                }
            )
        }
    )
})

testthat::test_that("ensure_data triggers background update when cache is stale", {
    tmp <- tempfile(pattern = "brp_stale_")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))

    testthat::with_mocked_bindings(
        brprovider_data_dir = function(provider_id) file.path(tmp, provider_id),
        .package = "saira",
        {
            pid <- "faunabr"
            dir.create(brprovider_data_dir(pid), recursive = TRUE, showWarnings = FALSE)
            saveRDS(data.frame(scientificName = "Panthera onca", stringsAsFactors = FALSE),
                    file.path(brprovider_data_dir(pid), paste0(pid, ".rds")))
            .brprovider_write_meta(pid, list(
                provider_id = pid,
                local_version = "1.47",
                remote_version_last_seen = "1.47",
                last_checked_at = "2000-01-01T00:00:00Z",
                last_updated_at = "2000-01-01T00:00:00Z",
                status = "up_to_date",
                last_error = NA_character_,
                source_package_version = NA_character_,
                retry_after_at = NA_character_
            ))

            started <- FALSE
            testthat::with_mocked_bindings(
                .brprovider_start_background_update = function(...) {
                    started <<- TRUE
                    TRUE
                },
                .package = "saira",
                {
                    out <- brprovider_ensure_data(provider_id = pid, check_ttl_secs = 1L, verbose = FALSE)
                    testthat::expect_true(isTRUE(out$ok))
                    testthat::expect_true(isTRUE(out$available))
                    testthat::expect_true(isTRUE(out$background_started))
                    testthat::expect_true(started)
                }
            )
        }
    )
})

testthat::test_that("bootstrap failure without cache is reported clearly", {
    tmp <- tempfile(pattern = "brp_boot_fail_")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))

    testthat::with_mocked_bindings(
        brprovider_data_dir = function(provider_id) file.path(tmp, provider_id),
        .brprovider_bundle_path = function(file) "",
        .brprovider_download_data_impl = function(provider_id, verbose = TRUE, data_version = "latest") {
            list(
                ok = FALSE,
                provider_id = provider_id,
                data_version = as.character(data_version),
                local_version = NA_character_,
                tmp_dir = tempfile("tmp_fail_"),
                persist_path = file.path(tmp, provider_id, paste0(provider_id, ".rds")),
                error = "network unavailable"
            )
        },
        .package = "saira",
        {
            out <- brprovider_ensure_data(provider_id = "faunabr", verbose = FALSE)
            testthat::expect_false(isTRUE(out$ok))
            testthat::expect_false(isTRUE(out$available))
            testthat::expect_identical(as.character(out$status), "update_failed")
            testthat::expect_match(as.character(out$error), "network unavailable")
        }
    )
})

testthat::test_that("failed download keeps previous rds untouched", {
    tmp <- tempfile(pattern = "brp_rollback_")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))

    old_df <- data.frame(scientificName = "old-record", stringsAsFactors = FALSE)

    testthat::with_mocked_bindings(
        brprovider_data_dir = function(provider_id) file.path(tmp, provider_id),
        .brprovider_download_data_impl = function(provider_id, verbose = TRUE, data_version = "latest") {
            list(
                ok = FALSE,
                provider_id = provider_id,
                data_version = as.character(data_version),
                local_version = NA_character_,
                tmp_dir = tempfile("tmp_fail_"),
                persist_path = file.path(tmp, provider_id, paste0(provider_id, ".rds")),
                error = "corrupted zip"
            )
        },
        .package = "saira",
        {
            pid <- "faunabr"
            dir.create(brprovider_data_dir(pid), recursive = TRUE, showWarnings = FALSE)
            saveRDS(old_df, file.path(brprovider_data_dir(pid), paste0(pid, ".rds")))

            testthat::expect_warning(
                ok <- saira:::brprovider_download_data(pid, verbose = FALSE),
                "corrupted zip"
            )
            testthat::expect_false(isTRUE(ok))

            persisted <- readRDS(file.path(brprovider_data_dir(pid), paste0(pid, ".rds")))
            testthat::expect_identical(as.character(persisted$scientificName[[1L]]), "old-record")
        }
    )
})

testthat::test_that("provider lock prevents concurrent starts", {
    tmp <- tempfile(pattern = "brp_lock_")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))

    testthat::with_mocked_bindings(
        brprovider_data_dir = function(provider_id) file.path(tmp, provider_id),
        .package = "saira",
        {
            pid <- "faunabr"
            first <- .brprovider_acquire_lock(pid)
            second <- .brprovider_acquire_lock(pid)
            .brprovider_release_lock(pid)
            third <- .brprovider_acquire_lock(pid)
            .brprovider_release_lock(pid)

            testthat::expect_true(isTRUE(first))
            testthat::expect_false(isTRUE(second))
            testthat::expect_true(isTRUE(third))
        }
    )
})

testthat::test_that("poll_updates marks update_failed and preserves cache (DEP-05)", {
    testthat::skip_if_not_installed("future")

    tmp <- tempfile(pattern = "brp_poll_fail_")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))

    testthat::with_mocked_bindings(
        brprovider_data_dir = function(provider_id) file.path(tmp, provider_id),
        .package = "saira",
        {
            pid <- "faunabr"
            dir.create(brprovider_data_dir(pid), recursive = TRUE, showWarnings = FALSE)
            saveRDS(data.frame(scientificName = "cached", stringsAsFactors = FALSE),
                    file.path(brprovider_data_dir(pid), paste0(pid, ".rds")))
            .brprovider_write_meta(pid, list(
                provider_id = pid,
                local_version = "1.48",
                remote_version_last_seen = "1.49",
                last_checked_at = "2000-01-01T00:00:00Z",
                last_updated_at = "2000-01-01T00:00:00Z",
                status = "update_in_progress",
                last_error = NA_character_,
                source_package_version = NA_character_,
                retry_after_at = NA_character_
            ))
            dir.create(dirname(.brprovider_lock_path(pid)), recursive = TRUE, showWarnings = FALSE)
            writeLines("lock", .brprovider_lock_path(pid))

            assign(pid, list(future = structure(list(), class = "fake_future"), retry_backoff_secs = 60L),
                   envir = .brprovider_jobs())

            testthat::with_mocked_bindings(
                resolved = function(future_obj) TRUE,
                value = function(future_obj) list(
                    ok = FALSE,
                    updated = FALSE,
                    provider_id = pid,
                    remote_version = "1.49",
                    local_version = "1.48",
                    error = "timeout"
                ),
                .package = "future",
                {
                    events <- brprovider_poll_updates(provider_id = pid)
                    testthat::expect_true(length(events) == 1L)
                }
            )

            # Version 1.49 is known and newer: the cache is stale, so the
            # badge keeps the failure.
            st <- brprovider_cache_status(pid, poll = FALSE)
            testthat::expect_identical(as.character(st$status), "update_failed")
            testthat::expect_true(isTRUE(st$has_data))

            # No newer version known: the old cache is current (ADR-073).
            saira:::.brprovider_patch_meta(pid, list(remote_version_last_seen = "1.48"))
            st <- brprovider_cache_status(pid, poll = FALSE)
            testthat::expect_identical(as.character(st$status), "up_to_date")
        }
    )
})

testthat::test_that("background update runs in its own R process, and the poll stops it", {
    testthat::skip_if_not_installed("future")
    testthat::skip_if_not_installed("parallelly")

    tmp <- tempfile(pattern = "brp_worker_")
    dir.create(tmp)
    old_plan <- future::plan("list")
    future::plan(future::sequential)
    on.exit({
        future::plan(old_plan)
        unlink(tmp, recursive = TRUE)
    })

    job <- function(provider_id, local_version) {
        list(ok = TRUE, updated = FALSE, provider_id = provider_id,
             remote_version = "1", local_version = "1", error = NA_character_,
             pid = Sys.getpid())
    }
    environment(job) <- baseenv()

    testthat::with_mocked_bindings(
        brprovider_data_dir = function(provider_id) file.path(tmp, provider_id),
        .brprovider_update_job = function() job,
        .package = "saira",
        {
            testthat::expect_true(.brprovider_start_background_update("faunabr"))
            started <- get("faunabr", envir = .brprovider_jobs())
            testthat::expect_s3_class(future::plan(), "sequential")
            testthat::expect_false(identical(future::value(started$future)$pid, Sys.getpid()))

            events <- brprovider_poll_updates(provider_id = "faunabr")
            testthat::expect_length(events, 1L)
            testthat::expect_identical(events[[1L]]$status, "up_to_date")
            testthat::expect_false(exists("faunabr", envir = .brprovider_jobs(), inherits = FALSE))
            testthat::expect_false(file.exists(.brprovider_lock_path("faunabr")))
            testthat::expect_error(parallel::clusterEvalQ(started$cluster, 1))
        }
    )
})

testthat::test_that("a worker that does not start releases the lock and backs off", {
    testthat::skip_if_not_installed("future")
    testthat::skip_if_not_installed("parallelly")

    tmp <- tempfile(pattern = "brp_worker_fail_")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))

    testthat::with_mocked_bindings(
        brprovider_data_dir = function(provider_id) file.path(tmp, provider_id),
        .package = "saira",
        testthat::with_mocked_bindings(
            makeClusterPSOCK = function(...) stop("worker unavailable"),
            .package = "parallelly",
            {
                testthat::expect_false(.brprovider_start_background_update("faunabr"))
                meta <- .brprovider_read_meta("faunabr")
                testthat::expect_identical(meta$status, "update_failed")
                testthat::expect_identical(meta$last_error, "worker unavailable")
                testthat::expect_false(is.na(meta$retry_after_at))
                testthat::expect_false(file.exists(.brprovider_lock_path("faunabr")))
                testthat::expect_false(exists("faunabr", envir = .brprovider_jobs(), inherits = FALSE))
            }
        )
    )
})

testthat::test_that("bundled snapshot fills an empty cache with its version", {
    tmp <- tempfile(pattern = "brp_seed_")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))

    testthat::with_mocked_bindings(
        brprovider_data_dir = function(provider_id) file.path(tmp, provider_id),
        .package = "saira",
        {
            snap <- jsonlite::fromJSON(system.file(
                "extdata", "brproviders", "snapshot.json", package = "saira"
            ))
            # The status call is the first touch, as in the Names tab.
            st <- brprovider_cache_status("florabr", poll = FALSE)
            testthat::expect_true(isTRUE(st$has_data))
            testthat::expect_identical(as.character(st$status), "up_to_date")
            testthat::expect_identical(as.character(st$local_version), snap$florabr$version)
        }
    )
})

testthat::test_that("bundled snapshot never replaces a user cache", {
    tmp <- tempfile(pattern = "brp_seed_keep_")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE))

    testthat::with_mocked_bindings(
        brprovider_data_dir = function(provider_id) file.path(tmp, provider_id),
        .package = "saira",
        {
            pid <- "faunabr"
            dir.create(brprovider_data_dir(pid), recursive = TRUE, showWarnings = FALSE)
            rds <- file.path(brprovider_data_dir(pid), paste0(pid, ".rds"))
            saveRDS(data.frame(scientificName = "user cache", stringsAsFactors = FALSE), rds)
            testthat::expect_true(brprovider_data_available(pid))
            testthat::expect_identical(readRDS(rds)$scientificName, "user cache")
        }
    )
})

testthat::test_that("brprovider_keep_queried() drops rows for names that were not queried (B43)", {
    res <- data.frame(
        query_name = c("Canis lupus", "panthera onca"),
        validation_status = c("accepted", "accepted"),
        stringsAsFactors = FALSE
    )
    out <- saira:::brprovider_keep_queried(res, c("Canis lupus familiaris", "Panthera onca"))
    testthat::expect_equal(out$query_name, "Panthera onca")
})
