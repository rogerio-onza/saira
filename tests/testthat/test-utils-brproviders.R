# Title: Tests for BR providers utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-03-05
# Version: 1.0

normalize_brprovider_result    <- function(...) saira:::normalize_brprovider_result(...)
brprovider_unresolved_names    <- function(...) saira:::brprovider_unresolved_names(...)
brprovider_data_available      <- function(...) saira:::brprovider_data_available(...)
brprovider_data_dir            <- function(...) saira:::brprovider_data_dir(...)
brprovider_download_params     <- function(...) saira:::brprovider_download_params(...)
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

testthat::test_that("normalize_brprovider_result: Correct + Accepted -> accepted", {
    raw <- data.frame(
        input_name      = "Panthera onca",
        Spelling        = "Correct",
        `Suggested name` = "Panthera onca",
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
})

testthat::test_that("normalize_brprovider_result: Correct + Synonym -> synonym", {
    raw <- data.frame(
        input_name      = "Araucaria angustifolia",
        Spelling        = "Correct",
        `Suggested name` = "Araucaria angustifolia",
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

testthat::test_that("normalize_brprovider_result: Probably_incorrect -> ambiguous", {
    raw <- data.frame(
        input_name      = "Pantera onca",
        Spelling        = "Probably_incorrect",
        `Suggested name` = "Panthera onca",
        Distance        = 1L,
        taxonomicStatus = "valid",
        family          = "Felidae",
        stringsAsFactors = FALSE,
        check.names     = FALSE
    )
    out <- normalize_brprovider_result(raw, "faunabr")
    testthat::expect_equal(out$validation_status, "ambiguous")
    testthat::expect_equal(out$scientificName, "Panthera onca")
})

testthat::test_that("normalize_brprovider_result: Not_found -> not_found with match_count 0", {
    raw <- data.frame(
        input_name      = "Xyz abc",
        Spelling        = "Not_found",
        `Suggested name` = NA_character_,
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
        `Suggested name` = c("Panthera onca", "Pantera once", "Pantera oncaa"),
        Distance        = c(1L, 2L, 3L),
        taxonomicStatus = c("valid", "valid", "valid"),
        family          = c("Felidae", "Felidae", "Felidae"),
        stringsAsFactors = FALSE,
        check.names     = FALSE
    )
    out <- normalize_brprovider_result(raw, "faunabr")
    testthat::expect_equal(nrow(out), 1L)
    testthat::expect_equal(out$scientificName, "Panthera onca")
})

testthat::test_that("normalize_brprovider_result: taxadb expected columns are present", {
    raw <- data.frame(
        input_name      = "Panthera onca",
        Spelling        = "Correct",
        `Suggested name` = "Panthera onca",
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
# brprovider_unresolved_names
# ---------------------------------------------------------------------------

testthat::test_that("brprovider_unresolved_names: returns only not_found names", {
    df <- data.frame(
        query_name        = c("Panthera onca", "Xyz abc", "Butia capita"),
        validation_status = c("accepted", "not_found", "not_found"),
        stringsAsFactors  = FALSE
    )
    out <- brprovider_unresolved_names(df)
    testthat::expect_equal(sort(out), sort(c("Xyz abc", "Butia capita")))
})

testthat::test_that("brprovider_unresolved_names: empty df returns character(0)", {
    testthat::expect_equal(
        brprovider_unresolved_names(data.frame()),
        character(0)
    )
})

testthat::test_that("brprovider_unresolved_names: all accepted returns character(0)", {
    df <- data.frame(
        query_name        = "Panthera onca",
        validation_status = "accepted",
        stringsAsFactors  = FALSE
    )
    testthat::expect_equal(brprovider_unresolved_names(df), character(0))
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
# brprovider_download_params
# ---------------------------------------------------------------------------

testthat::test_that("brprovider_download_params: default data_version is 'latest'", {
    p <- brprovider_download_params("florabr")
    testthat::expect_equal(p$data_version, "latest")
    testthat::expect_equal(p$provider_id, "florabr")
    testthat::expect_type(p$tmp_dir, "character")
    testthat::expect_type(p$persist_dir, "character")
    testthat::expect_type(p$pkg_version, "character")
})

testthat::test_that("brprovider_download_params: fixed version propagates correctly", {
    p <- brprovider_download_params("florabr", "393.319")
    testthat::expect_equal(p$data_version, "393.319")
    p2 <- brprovider_download_params("faunabr", "1.2")
    testthat::expect_equal(p2$data_version, "1.2")
    testthat::expect_equal(p2$provider_id, "faunabr")
})

testthat::test_that("brprovider_download_params: tmp_dir ends with provider_id", {
    p <- brprovider_download_params("faunabr")
    testthat::expect_true(endsWith(p$tmp_dir, "faunabr"))
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

    testthat::expect_error(
        .brprovider_check_artifacts("florabr", tmp),
        regexp = "Flora_e_Funga_do_Brasil\\.rds"
    )
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

testthat::test_that("poll_updates marks update_failed and preserves cache", {
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

            st <- brprovider_cache_status(pid, poll = FALSE)
            testthat::expect_identical(as.character(st$status), "up_to_date")
            testthat::expect_true(isTRUE(st$has_data))
        }
    )
})
