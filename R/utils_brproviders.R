# Title: Brazilian Biodiversity Providers Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-03-05
# Version: 1.0
# Download/update and background jobs for florabr/faunabr. No Shiny dependencies.
# Storage and pure response adapters live in their respective domain files.
#
# Cache scope: public provider data shared by sessions in this R process.
# Loaded frames persist until brprovider_clear_cache(); on-disk update checks
# retain their 24-hour TTL, 15-minute retry backoff and existing lock ownership.

# Private in-process cache so large data.frames are not re-read from disk on
# every validation run.
.brprovider_cache <- new.env(parent = emptyenv())

# Private in-process registry for background update jobs.
.brprovider_jobs <- new.env(parent = emptyenv())

# A new catalog version is a full download of about 2 min, and the names change
# little in a month (ADR-174).
.brprovider_check_ttl_secs_default <- 30L * 24L * 60L * 60L
.brprovider_retry_backoff_secs_default <- 15L * 60L
.brprovider_lock_stale_secs_default <- 60L * 60L
.brprovider_lock_max_secs_default <- 24L * 60L * 60L

# ---------------------------------------------------------------------------
# Version helpers
# ---------------------------------------------------------------------------

#' @noRd
.brprovider_version_tokens <- function(version) {
    ver <- as.character(version)
    if (is.na(ver) || !nzchar(ver)) {
        return(numeric(0))
    }

    parts <- strsplit(ver, "\\.", fixed = FALSE)[[1]]
    parts <- gsub("[^0-9]", "", parts)
    parts[!nzchar(parts)] <- "0"
    out <- suppressWarnings(as.numeric(parts))
    out[is.na(out)] <- 0
    out
}

#' Compare two dotted numeric versions by segments
#' @param left Character version.
#' @param right Character version.
#' @return -1, 0, or 1.
#' @noRd
brprovider_compare_versions <- function(left, right) {
    left_chr <- as.character(left)
    right_chr <- as.character(right)

    if ((is.na(left_chr) || !nzchar(left_chr)) && (is.na(right_chr) || !nzchar(right_chr))) {
        return(0L)
    }
    if (is.na(left_chr) || !nzchar(left_chr)) {
        return(-1L)
    }
    if (is.na(right_chr) || !nzchar(right_chr)) {
        return(1L)
    }

    a <- .brprovider_version_tokens(left_chr)
    b <- .brprovider_version_tokens(right_chr)
    n <- max(length(a), length(b))
    if (length(a) < n) a <- c(a, rep(0, n - length(a)))
    if (length(b) < n) b <- c(b, rep(0, n - length(b)))

    for (i in seq_len(n)) {
        if (a[[i]] > b[[i]]) return(1L)
        if (a[[i]] < b[[i]]) return(-1L)
    }
    0L
}

#' @noRd
.brprovider_pick_max_version <- function(versions) {
    versions <- unique(as.character(versions))
    versions <- versions[!is.na(versions) & nzchar(versions)]
    if (length(versions) == 0L) {
        return(NA_character_)
    }
    if (length(versions) == 1L) {
        return(versions[[1L]])
    }

    best <- versions[[1L]]
    for (idx in 2:length(versions)) {
        cand <- versions[[idx]]
        if (brprovider_compare_versions(cand, best) > 0L) {
            best <- cand
        }
    }
    best
}

#' @noRd
.brprovider_resource_url <- function(provider_id) {
    switch(as.character(provider_id),
        florabr = "https://ipt.jbrj.gov.br/jbrj/resource?r=lista_especies_flora_brasil",
        faunabr = "https://ipt.jbrj.gov.br/jbrj/resource?r=catalogo_taxonomico_da_fauna_do_brasil",
        NA_character_
    )
}

#' @noRd
.brprovider_version_link_pattern <- function(provider_id) {
    switch(as.character(provider_id),
        florabr = "archive\\.do\\?r=lista_especies_flora_brasil&v=([0-9.]+)",
        faunabr = "archive\\.do\\?r=catalogo_taxonomico_da_fauna_do_brasil&v=([0-9.]+)",
        NA_character_
    )
}

#' Fetch the latest remote provider version from the official IPT page
#' @param provider_id Character.
#' @return Character version.
#' @noRd
brprovider_latest_remote_version <- function(provider_id) {
    provider_id <- as.character(provider_id)
    resource_url <- .brprovider_resource_url(provider_id)
    pattern <- .brprovider_version_link_pattern(provider_id)

    if (is.na(resource_url) || is.na(pattern)) {
        stop(sprintf("Unknown BR provider: %s", provider_id))
    }

    page <- tryCatch(
        paste(readLines(resource_url, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
        error = function(e) {
            stop(sprintf("Failed to query remote version for '%s': %s", provider_id, e$message))
        }
    )

    matches <- regmatches(page, gregexpr(pattern, page, perl = TRUE))[[1]]
    if (length(matches) == 0L) {
        stop(sprintf("No version links found for provider '%s'.", provider_id))
    }

    versions <- gsub(".*&v=([0-9.]+).*", "\\1", matches, perl = TRUE)
    latest <- .brprovider_pick_max_version(versions)
    if (is.na(latest) || !nzchar(latest)) {
        stop(sprintf("Unable to parse remote version for provider '%s'.", provider_id))
    }

    latest
}

#' @noRd
.brprovider_detect_downloaded_version <- function(tmp_dir, data_version) {
    requested <- as.character(data_version)
    if (!identical(requested, "latest")) {
        return(requested)
    }

    dirs <- list.dirs(tmp_dir, recursive = FALSE, full.names = FALSE)
    dirs <- dirs[grepl("^[0-9]+(\\.[0-9]+)*$", dirs)]
    if (length(dirs) > 0L) {
        return(.brprovider_pick_max_version(dirs))
    }

    zips <- list.files(tmp_dir, pattern = "\\.zip$", full.names = FALSE)
    if (length(zips) > 0L) {
        zip_versions <- gsub("\\.zip$", "", zips)
        zip_versions <- zip_versions[grepl("^[0-9]+(\\.[0-9]+)*$", zip_versions)]
        if (length(zip_versions) > 0L) {
            return(.brprovider_pick_max_version(zip_versions))
        }
    }

    NA_character_
}

# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------

#' Validate that expected artifact files exist after get_* download
#'
#' @param provider_id Character. "florabr" or "faunabr".
#' @param tmp_dir Character. The temp directory passed to get_*.
#' @return Invisible character vector of matched paths, or stops with a
#'   descriptive error including a partial directory tree.
#' @noRd
.brprovider_check_artifacts <- function(provider_id, tmp_dir) {
    # florabr 1.4 writes a gzipped CSV. Older versions wrote an .rds, and
    # load_florabr() still reads both.
    expected <- switch(provider_id,
        florabr = c("CompleteBrazilianFlora.gz", "CompleteBrazilianFlora.rds"),
        faunabr = "CompleteBrazilianFauna.gz",
        NULL
    )
    if (is.null(expected)) return(invisible(NULL))
    hits <- list.files(tmp_dir, recursive = TRUE, full.names = TRUE)
    hits <- hits[basename(hits) %in% expected]
    if (length(hits) == 0L) {
        all_files <- list.files(tmp_dir, recursive = TRUE, full.names = FALSE)
        tree <- if (length(all_files) == 0L) {
            "(empty)"
        } else {
            paste(all_files[seq_len(min(20L, length(all_files)))],
                  collapse = "\n  ")
        }
        stop(sprintf(
            "Expected artifact '%s' not found after get_%s().\nTemp dir: %s\nContents (up to 20):\n  %s",
            paste(expected, collapse = "' or '"), provider_id, tmp_dir, tree
        ))
    }
    invisible(hits)
}

#' @noRd
.brprovider_download_data_impl <- function(provider_id, verbose = TRUE,
                                           data_version = "latest") {
    provider_id <- as.character(provider_id)

    # Download to a short temp path to avoid Windows path-length issues.
    tmp_dir <- file.path(tempdir(), provider_id)
    unlink(tmp_dir, recursive = TRUE, force = TRUE)
    dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)

    # The IPT data archives are large; on slow links the default 60s download
    # timeout truncates the zip and surfaces as "extracting from zip" failures.
    # Raise it for the duration of the download and restore it on exit.
    old_timeout <- getOption("timeout")
    options(timeout = max(old_timeout, 600L))
    on.exit(options(timeout = old_timeout), add = TRUE)

    if (isTRUE(verbose)) {
        message(sprintf(
            "[brprovider] provider=%s version=%s tempdir=%s pkg=%s",
            provider_id, data_version, tmp_dir, .brprovider_pkg_version_safe(provider_id)
        ))
    }

    out <- tryCatch({
        if (identical(provider_id, "florabr")) {
            if (!requireNamespace("florabr", quietly = TRUE)) {
                stop("Package 'florabr' is not installed.")
            }

            if (isTRUE(verbose)) {
                florabr::get_florabr(
                    output_dir = tmp_dir,
                    data_version = data_version,
                    overwrite = TRUE,
                    verbose = TRUE
                )
            } else {
                suppressMessages(invisible(utils::capture.output(
                    florabr::get_florabr(
                        output_dir = tmp_dir,
                        data_version = data_version,
                        overwrite = TRUE,
                        verbose = TRUE
                    ),
                    type = "message"
                )))
            }

            .brprovider_check_artifacts(provider_id, tmp_dir)
            load_version <- .brprovider_detect_downloaded_version(tmp_dir, data_version)
            if (is.na(load_version) || !nzchar(load_version)) load_version <- data_version
            data <- florabr::load_florabr(
                data_dir = tmp_dir,
                data_version = load_version,
                type = "short",
                verbose = FALSE
            )
        } else if (identical(provider_id, "faunabr")) {
            if (!requireNamespace("faunabr", quietly = TRUE)) {
                stop("Package 'faunabr' is not installed.")
            }

            download_expr <- quote(
                faunabr::get_faunabr(
                    output_dir = tmp_dir,
                    data_version = data_version,
                    overwrite = TRUE,
                    verbose = TRUE
                )
            )

            if (isTRUE(verbose)) {
                withCallingHandlers(
                    eval(download_expr),
                    warning = function(w) {
                        msg <- conditionMessage(w)
                        if (grepl("extracting from zip|cannot open", msg, ignore.case = TRUE)) {
                            stop(paste0(
                                "faunabr download/extraction failed: ", msg,
                                "\nThe remote server (ipt.jbrj.gov.br) may be unavailable ",
                                "or the download was corrupted. Check your internet connection and try again."
                            ))
                        }
                    }
                )
            } else {
                suppressMessages(invisible(utils::capture.output(
                    withCallingHandlers(
                        eval(download_expr),
                        warning = function(w) {
                            msg <- conditionMessage(w)
                            if (grepl("extracting from zip|cannot open", msg, ignore.case = TRUE)) {
                                stop(paste0(
                                    "faunabr download/extraction failed: ", msg,
                                    "\nThe remote server (ipt.jbrj.gov.br) may be unavailable ",
                                    "or the download was corrupted. Check your internet connection and try again."
                                ))
                            }
                            invokeRestart("muffleWarning")
                        }
                    ),
                    type = "message"
                )))
            }

            .brprovider_check_artifacts(provider_id, tmp_dir)
            load_version <- .brprovider_detect_downloaded_version(tmp_dir, data_version)
            if (is.na(load_version) || !nzchar(load_version)) load_version <- data_version
            data <- faunabr::load_faunabr(
                data_dir = tmp_dir,
                data_version = load_version,
                type = "short",
                verbose = FALSE
            )
        } else {
            stop(sprintf("Unknown BR provider: %s", provider_id))
        }

        persist_path <- .brprovider_rds_path(provider_id)
        backup_path <- .brprovider_backup_path(provider_id)
        .brprovider_write_rds_atomic(data, persist_path, backup_path)

        local_version <- load_version
        if (is.na(local_version) || !nzchar(local_version) ||
            identical(local_version, "latest")) {
            local_version <- NA_character_
        }

        list(
            ok = TRUE,
            provider_id = provider_id,
            data_version = as.character(data_version),
            local_version = local_version,
            tmp_dir = tmp_dir,
            persist_path = persist_path,
            error = NA_character_
        )
    }, error = function(e) {
        list(
            ok = FALSE,
            provider_id = provider_id,
            data_version = as.character(data_version),
            local_version = NA_character_,
            tmp_dir = tmp_dir,
            persist_path = .brprovider_rds_path(provider_id),
            error = as.character(e$message)
        )
    })

    out
}

#' Download the BR provider database to the local cache directory
#'
#' Downloads to a temporary directory (following the faunabr/florabr recommended
#' pattern), loads the resulting data frame, and saves it as a single .rds file
#' in the persistent user data directory for fast subsequent loads.
#'
#' @param provider_id Character. "florabr" or "faunabr".
#' @param verbose Logical. Show progress messages. Default TRUE.
#' @param data_version Character. Version to download. Use "latest" for the most
#'   recent version (updated weekly/frequently), or a pinned version string such
#'   as "393.319" (florabr) or "1.2" (faunabr). Default "latest".
#' @return TRUE on success, FALSE on failure (message written to console).
#' @noRd
brprovider_download_data <- function(provider_id, verbose = TRUE,
                                     data_version = "latest") {
    provider_id <- as.character(provider_id)
    now <- .brprovider_now_utc()

    result <- .brprovider_download_data_impl(
        provider_id = provider_id,
        verbose = verbose,
        data_version = data_version
    )

    if (isTRUE(result$ok)) {
        .brprovider_record_success(provider_id, result$local_version, now = now)
        return(TRUE)
    }

    .brprovider_record_failure(provider_id, result$error,
                               .brprovider_retry_backoff_secs_default, now = now)

    warning(sprintf(
        "brprovider_download_data failed [provider=%s version=%s tempdir=%s]: %s",
        provider_id,
        as.character(data_version),
        result$tmp_dir,
        as.character(result$error)
    ))
    FALSE
}

# ---------------------------------------------------------------------------
# Background update
# ---------------------------------------------------------------------------

#' @noRd
.brprovider_background_update_worker <- function(provider_id, local_version = NA_character_) {
    remote_version <- brprovider_latest_remote_version(provider_id)
    needs_download <- is.na(local_version) || !nzchar(local_version) ||
        (brprovider_compare_versions(remote_version, local_version) > 0L)

    if (!isTRUE(needs_download)) {
        return(list(
            ok = TRUE,
            updated = FALSE,
            provider_id = provider_id,
            remote_version = as.character(remote_version),
            local_version = as.character(local_version),
            error = NA_character_
        ))
    }

    downloaded <- .brprovider_download_data_impl(
        provider_id = provider_id,
        verbose = FALSE,
        data_version = remote_version
    )

    if (!isTRUE(downloaded$ok)) {
        return(list(
            ok = FALSE,
            updated = FALSE,
            provider_id = provider_id,
            remote_version = as.character(remote_version),
            local_version = as.character(local_version),
            error = as.character(downloaded$error)
        ))
    }

    new_local <- as.character(downloaded$local_version)
    if (is.na(new_local) || !nzchar(new_local)) {
        new_local <- as.character(remote_version)
    }

    list(
        ok = TRUE,
        updated = TRUE,
        provider_id = provider_id,
        remote_version = as.character(remote_version),
        local_version = new_local,
        error = NA_character_
    )
}

#' @noRd
.brprovider_update_job <- function() {
    # pkgload runs the app from the source tree, without an installed saira.
    # The new R process must then load the same tree to find the worker.
    path <- getNamespaceInfo("saira", "path")
    source_path <- if (file.exists(file.path(path, "R", "utils_brproviders.R"))) path
    job <- function(provider_id, local_version) {
        if (!is.null(source_path)) {
            pkgload::load_all(source_path, quiet = TRUE, export_all = FALSE)
        }
        worker <- get(".brprovider_background_update_worker", envir = asNamespace("saira"))
        worker(provider_id = provider_id, local_version = local_version)
    }
    environment(job) <- list2env(list(source_path = source_path), parent = baseenv())
    job
}

#' @noRd
.brprovider_start_background_update <- function(provider_id,
                                                local_version = NA_character_,
                                                retry_backoff_secs = .brprovider_retry_backoff_secs_default) {
    provider_id <- as.character(provider_id)

    if (exists(provider_id, envir = .brprovider_jobs, inherits = FALSE)) {
        return(FALSE)
    }

    if (!.brprovider_acquire_lock(provider_id)) {
        return(FALSE)
    }

    .brprovider_patch_meta(provider_id, list(
        status = "update_in_progress",
        last_error = NA_character_,
        source_package_version = .brprovider_pkg_version_safe(provider_id)
    ))

    # The IPT check and the download get their own R process, so the app does
    # not stop (LESSONS). A PSOCK worker listens on all network interfaces, and
    # Windows then asks for firewall access. callr uses pipes, not a socket.
    process <- tryCatch(
        callr::r_bg(
            .brprovider_update_job(),
            args = list(provider_id = provider_id, local_version = local_version),
            libpath = .libPaths(),
            package = TRUE,
            user_profile = FALSE,
            stdout = NULL,
            stderr = NULL,
            supervise = TRUE
        ),
        error = function(e) e
    )

    if (inherits(process, "error")) {
        .brprovider_release_lock(provider_id)
        .brprovider_record_failure(provider_id, process$message, retry_backoff_secs)
        return(FALSE)
    }

    assign(provider_id, list(
        process = process,
        retry_backoff_secs = as.integer(retry_backoff_secs),
        started_at = .brprovider_time_to_string(.brprovider_now_utc())
    ), envir = .brprovider_jobs)

    TRUE
}

#' Poll and finalize completed BR background update jobs
#' @param provider_id Character or NULL. NULL polls all providers.
#' @return List of update events completed during this poll.
#' @noRd
brprovider_poll_updates <- function(provider_id = NULL) {
    job_ids <- ls(envir = .brprovider_jobs, all.names = TRUE)
    if (!is.null(provider_id)) {
        ids <- unique(as.character(provider_id))
        job_ids <- intersect(job_ids, ids)
    }
    if (length(job_ids) == 0L) {
        return(list())
    }

    events <- list()
    for (id in job_ids) {
        job <- get(id, envir = .brprovider_jobs, inherits = FALSE)

        alive <- tryCatch(job$process$is_alive(), error = function(e) FALSE)
        if (isTRUE(alive)) {
            next
        }

        result <- tryCatch(
            job$process$get_result(),
            error = function(e) {
                # callr wraps the error of the R process. The cause is the message to keep.
                cause <- if (inherits(e$parent, "condition")) e$parent else e
                list(
                    ok = FALSE,
                    updated = FALSE,
                    provider_id = id,
                    remote_version = NA_character_,
                    local_version = NA_character_,
                    error = conditionMessage(cause)
                )
            }
        )

        .brprovider_release_lock(id)

        now <- .brprovider_now_utc()
        retry_backoff <- suppressWarnings(as.numeric(job$retry_backoff_secs))
        if (is.na(retry_backoff) || retry_backoff < 1) {
            retry_backoff <- .brprovider_retry_backoff_secs_default
        }

        if (isTRUE(result$ok)) {
            .brprovider_record_success(id, result$local_version, result$remote_version,
                                       updated = result$updated, now = now)

            events[[length(events) + 1L]] <- list(
                provider_id = as.character(id),
                status = "up_to_date",
                updated = isTRUE(result$updated),
                local_version = as.character(result$local_version),
                remote_version = as.character(result$remote_version),
                error = NA_character_
            )
        } else {
            .brprovider_record_failure(id, result$error, retry_backoff,
                                       remote_version = result$remote_version, now = now)

            events[[length(events) + 1L]] <- list(
                provider_id = as.character(id),
                status = "update_failed",
                updated = FALSE,
                local_version = as.character(result$local_version),
                remote_version = as.character(result$remote_version),
                error = as.character(result$error)
            )
        }

        rm(list = id, envir = .brprovider_jobs)
    }

    events
}

#' Ensure BR provider data is ready for querying
#'
#' If cache exists, returns immediately and may trigger a background update when
#' version checks are due. If cache is missing, performs a synchronous bootstrap
#' download (mandatory first run).
#'
#' @param provider_id Character.
#' @param check_ttl_secs Numeric. Remote check TTL in seconds. Default 30 days.
#' @param retry_backoff_secs Numeric. Retry backoff after update failure.
#' @param verbose Logical.
#' @return Named list with status flags.
#' @noRd
brprovider_ensure_data <- function(provider_id,
                                   check_ttl_secs = .brprovider_check_ttl_secs_default,
                                   retry_backoff_secs = .brprovider_retry_backoff_secs_default,
                                   verbose = FALSE) {
    provider_id <- as.character(provider_id)
    now <- .brprovider_now_utc()

    # Always collect any completed background jobs before making decisions.
    poll_events <- brprovider_poll_updates(provider_id = provider_id)

    has_cache <- brprovider_data_available(provider_id)
    meta <- .brprovider_read_meta(provider_id)

    if (!has_cache) {
        acquired <- .brprovider_acquire_lock(provider_id)
        if (!isTRUE(acquired)) {
            .brprovider_patch_meta(provider_id, list(
                status = "update_in_progress",
                last_error = NA_character_,
                source_package_version = .brprovider_pkg_version_safe(provider_id)
            ))
            return(list(
                ok = FALSE,
                available = FALSE,
                provider_id = provider_id,
                status = "update_in_progress",
                bootstrap = TRUE,
                background_started = FALSE,
                poll_events = poll_events,
                error = "Initial bootstrap is already running for this provider."
            ))
        }

        .brprovider_patch_meta(provider_id, list(
            status = "update_in_progress",
            last_error = NA_character_,
            source_package_version = .brprovider_pkg_version_safe(provider_id)
        ))

        bootstrap <- .brprovider_download_data_impl(
            provider_id = provider_id,
            verbose = isTRUE(verbose),
            data_version = "latest"
        )
        .brprovider_release_lock(provider_id)

        if (!isTRUE(bootstrap$ok)) {
            .brprovider_record_failure(provider_id, bootstrap$error, retry_backoff_secs, now = now)
            return(list(
                ok = FALSE,
                available = FALSE,
                provider_id = provider_id,
                status = "update_failed",
                bootstrap = TRUE,
                background_started = FALSE,
                poll_events = poll_events,
                error = as.character(bootstrap$error)
            ))
        }

        local_version <- as.character(bootstrap$local_version)
        .brprovider_record_success(provider_id, local_version, now = now)

        return(list(
            ok = TRUE,
            available = TRUE,
            provider_id = provider_id,
            status = "up_to_date",
            local_version = local_version,
            bootstrap = TRUE,
            background_started = FALSE,
            poll_events = poll_events,
            error = NA_character_
        ))
    }

    if (identical(as.character(meta$status), "never_downloaded")) {
        .brprovider_patch_meta(provider_id, list(
            status = "up_to_date",
            source_package_version = .brprovider_pkg_version_safe(provider_id)
        ))
        meta <- .brprovider_read_meta(provider_id)
    }

    # A stale lock or an orphan "in progress" status must not block the update.
    state <- .brprovider_reconcile_update(provider_id, meta, has_data = TRUE)
    meta <- state$meta
    in_progress <- state$in_progress
    due <- .brprovider_check_due(meta, ttl_secs = check_ttl_secs, now = now)
    retry_blocked <- .brprovider_retry_blocked(meta, now = now)

    background_started <- FALSE
    background_reason <- "not_due"
    if (isTRUE(due) && !isTRUE(in_progress) && !isTRUE(retry_blocked)) {
        local_version <- as.character(meta$local_version)
        background_started <- .brprovider_start_background_update(
            provider_id = provider_id,
            local_version = local_version,
            retry_backoff_secs = retry_backoff_secs
        )
        background_reason <- if (isTRUE(background_started)) "started" else "not_started"
    } else if (isTRUE(in_progress)) {
        background_reason <- "already_running"
    } else if (isTRUE(retry_blocked)) {
        background_reason <- "backoff"
    }

    status <- brprovider_cache_status(provider_id, poll = FALSE)
    list(
        ok = TRUE,
        available = TRUE,
        provider_id = provider_id,
        status = as.character(status$status),
        local_version = as.character(status$local_version),
        remote_version_last_seen = as.character(status$remote_version_last_seen),
        bootstrap = FALSE,
        background_started = isTRUE(background_started),
        background_reason = background_reason,
        poll_events = poll_events,
        error = NA_character_
    )
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
