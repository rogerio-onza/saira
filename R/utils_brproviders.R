# Title: Brazilian Biodiversity Providers Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-03-05
# Version: 1.0
# Desc: Pure functions for florabr/faunabr data management, querying, and
#       result normalisation to the taxadb common schema. No Shiny deps.

# Private in-session cache so large data.frames are not re-read from disk on
# every validation run.
.brprovider_cache <- new.env(parent = emptyenv())

# Private in-session registry for background update jobs.
.brprovider_jobs <- new.env(parent = emptyenv())

.brprovider_check_ttl_secs_default <- 24L * 60L * 60L
.brprovider_retry_backoff_secs_default <- 15L * 60L
.brprovider_lock_stale_secs_default <- 60L * 60L

# ---------------------------------------------------------------------------
# Data directory helpers
# ---------------------------------------------------------------------------

#' Return the local data directory for a BR provider
#' @param provider_id Character. "florabr" or "faunabr".
#' @return Absolute path string.
#' @noRd
brprovider_data_dir <- function(provider_id) {
    base <- tools::R_user_dir("saira", which = "data")
    path <- file.path(base, "brproviders", as.character(provider_id))
    normalizePath(path, winslash = "/", mustWork = FALSE)
}

#' @noRd
.brprovider_rds_path <- function(provider_id) {
    file.path(brprovider_data_dir(provider_id), paste0(as.character(provider_id), ".rds"))
}

#' @noRd
.brprovider_meta_path <- function(provider_id) {
    file.path(brprovider_data_dir(provider_id), paste0(as.character(provider_id), ".meta.json"))
}

#' @noRd
.brprovider_backup_path <- function(provider_id) {
    file.path(brprovider_data_dir(provider_id), paste0(as.character(provider_id), ".rds.bak"))
}

#' @noRd
.brprovider_lock_path <- function(provider_id) {
    file.path(brprovider_data_dir(provider_id), paste0(as.character(provider_id), ".update.lock"))
}

#' @noRd
.brprovider_pkg_version_safe <- function(provider_id) {
    tryCatch(as.character(utils::packageVersion(provider_id)), error = function(e) NA_character_)
}

#' @noRd
.brprovider_now_utc <- function() {
    Sys.time()
}

#' @noRd
.brprovider_time_to_string <- function(value) {
    if (length(value) == 0L || all(is.na(value))) {
        return(NA_character_)
    }
    format(as.POSIXct(value, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

#' @noRd
.brprovider_time_from_string <- function(value) {
    if (is.null(value) || length(value) == 0L || is.na(value[[1L]]) || !nzchar(as.character(value[[1L]]))) {
        return(as.POSIXct(NA_character_, tz = "UTC"))
    }
    as.POSIXct(as.character(value[[1L]]), format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

#' @noRd
.brprovider_meta_defaults <- function(provider_id) {
    has_data <- file.exists(.brprovider_rds_path(provider_id))
    list(
        provider_id = as.character(provider_id),
        local_version = NA_character_,
        remote_version_last_seen = NA_character_,
        last_checked_at = NA_character_,
        last_updated_at = NA_character_,
        status = if (has_data) "up_to_date" else "never_downloaded",
        last_error = NA_character_,
        source_package_version = .brprovider_pkg_version_safe(provider_id),
        retry_after_at = NA_character_
    )
}

#' @noRd
.brprovider_scalar_chr <- function(value) {
    if (is.null(value) || length(value) == 0L) {
        return(NA_character_)
    }
    out <- as.character(value[[1L]])
    if (length(out) == 0L) {
        return(NA_character_)
    }
    out
}

#' @noRd
.brprovider_read_meta <- function(provider_id) {
    defaults <- .brprovider_meta_defaults(provider_id)
    path <- .brprovider_meta_path(provider_id)
    if (!file.exists(path)) {
        return(defaults)
    }

    meta <- tryCatch(
        jsonlite::fromJSON(path, simplifyVector = TRUE),
        error = function(e) NULL
    )
    if (!is.list(meta)) {
        return(defaults)
    }

    for (nm in names(defaults)) {
        if (!nm %in% names(meta)) {
            meta[[nm]] <- defaults[[nm]]
        }
    }

    meta$provider_id <- .brprovider_scalar_chr(meta$provider_id)
    meta$local_version <- .brprovider_scalar_chr(meta$local_version)
    meta$remote_version_last_seen <- .brprovider_scalar_chr(meta$remote_version_last_seen)
    meta$last_checked_at <- .brprovider_scalar_chr(meta$last_checked_at)
    meta$last_updated_at <- .brprovider_scalar_chr(meta$last_updated_at)
    meta$status <- .brprovider_scalar_chr(meta$status)
    meta$last_error <- .brprovider_scalar_chr(meta$last_error)
    meta$source_package_version <- .brprovider_scalar_chr(meta$source_package_version)
    meta$retry_after_at <- .brprovider_scalar_chr(meta$retry_after_at)

    if (!nzchar(meta$provider_id)) {
        meta$provider_id <- as.character(provider_id)
    }

    meta
}

#' @noRd
.brprovider_write_meta <- function(provider_id, meta) {
    dir.create(brprovider_data_dir(provider_id), recursive = TRUE, showWarnings = FALSE)
    meta_path <- .brprovider_meta_path(provider_id)
    jsonlite::write_json(meta, path = meta_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
    invisible(meta)
}

#' @noRd
.brprovider_patch_meta <- function(provider_id, fields) {
    meta <- .brprovider_read_meta(provider_id)
    for (nm in names(fields)) {
        meta[[nm]] <- fields[[nm]]
    }
    .brprovider_write_meta(provider_id, meta)
}

#' Check whether a BR provider's data is available on disk
#' @param provider_id Character. "florabr" or "faunabr".
#' @return Single logical.
#' @noRd
brprovider_data_available <- function(provider_id) {
    file.exists(.brprovider_rds_path(provider_id))
}

#' Return metadata status for one BR provider cache
#' @param provider_id Character.
#' @param poll Logical. If TRUE, collect completed background jobs first.
#' @return Named list with cache metadata.
#' @noRd
brprovider_cache_status <- function(provider_id, poll = TRUE) {
    provider_id <- as.character(provider_id)
    if (isTRUE(poll)) {
        brprovider_poll_updates(provider_id = provider_id)
    }

    meta <- .brprovider_read_meta(provider_id)
    has_data <- brprovider_data_available(provider_id)

    meta_changed <- FALSE

    # Crash recovery: stale "in progress" without a job or lock.
    if (identical(as.character(meta$status), "update_in_progress") &&
        !exists(provider_id, envir = .brprovider_jobs, inherits = FALSE) &&
        !file.exists(.brprovider_lock_path(provider_id))) {
        meta$status <- if (has_data) "up_to_date" else "update_failed"
        if (!has_data && (is.na(meta$last_error) || !nzchar(meta$last_error))) {
            meta$last_error <- "Background update interrupted."
        }
        meta_changed <- TRUE
    }

    if (!has_data && !identical(as.character(meta$status), "update_in_progress") &&
        !identical(as.character(meta$status), "update_failed") &&
        !identical(as.character(meta$status), "never_downloaded")) {
        meta$status <- "never_downloaded"
        meta_changed <- TRUE
    }

    if (has_data && identical(as.character(meta$status), "never_downloaded")) {
        meta$status <- "up_to_date"
        meta_changed <- TRUE
    }

    if (has_data && identical(as.character(meta$status), "update_failed")) {
        meta$status <- "up_to_date"
        meta_changed <- TRUE
    }

    if (isTRUE(meta_changed)) {
        .brprovider_write_meta(provider_id, meta)
    }

    meta$has_data <- has_data
    meta
}

#' Return metadata status for multiple BR providers
#' @param provider_ids Character vector.
#' @param poll Logical. Poll updates before reading statuses.
#' @return Named list.
#' @noRd
brprovider_cache_statuses <- function(provider_ids = c("florabr", "faunabr"), poll = TRUE) {
    ids <- unique(as.character(provider_ids))
    ids <- ids[!is.na(ids) & nzchar(ids)]
    out <- stats::setNames(vector("list", length(ids)), ids)
    for (id in ids) {
        out[[id]] <- brprovider_cache_status(id, poll = poll)
    }
    out
}

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
# Locking and background coordination
# ---------------------------------------------------------------------------

#' @noRd
.brprovider_acquire_lock <- function(provider_id, stale_secs = .brprovider_lock_stale_secs_default) {
    path <- .brprovider_lock_path(provider_id)
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

    if (file.exists(path)) {
        info <- file.info(path)
        age <- as.numeric(difftime(Sys.time(), info$mtime, units = "secs"))
        if (!is.na(age) && age > as.numeric(stale_secs)) {
            unlink(path, force = TRUE)
        }
    }

    if (file.exists(path)) {
        return(FALSE)
    }

    handle <- tryCatch(file(path, open = "wx"), error = function(e) NULL)
    if (is.null(handle)) {
        return(FALSE)
    }

    on.exit(close(handle), add = TRUE)
    writeLines(c(
        paste0("pid=", Sys.getpid()),
        paste0("started_at=", .brprovider_time_to_string(Sys.time()))
    ), con = handle)
    TRUE
}

#' @noRd
.brprovider_release_lock <- function(provider_id) {
    unlink(.brprovider_lock_path(provider_id), force = TRUE)
    invisible(NULL)
}

#' @noRd
.brprovider_retry_blocked <- function(meta, now = Sys.time()) {
    retry_at <- .brprovider_time_from_string(meta$retry_after_at)
    !is.na(retry_at) && retry_at > now
}

#' @noRd
.brprovider_check_due <- function(meta, ttl_secs = .brprovider_check_ttl_secs_default, now = Sys.time()) {
    ttl <- suppressWarnings(as.numeric(ttl_secs))
    if (is.na(ttl) || ttl <= 0) {
        return(TRUE)
    }

    checked_at <- .brprovider_time_from_string(meta$last_checked_at)
    if (is.na(checked_at)) {
        return(TRUE)
    }

    age <- as.numeric(difftime(now, checked_at, units = "secs"))
    is.na(age) || age >= ttl
}

#' @noRd
.brprovider_write_rds_atomic <- function(data, target_path, backup_path) {
    dir.create(dirname(target_path), recursive = TRUE, showWarnings = FALSE)
    tmp_path <- paste0(target_path, ".tmp")

    saveRDS(data, tmp_path)
    verify <- readRDS(tmp_path)
    if (!is.data.frame(verify)) {
        unlink(tmp_path, force = TRUE)
        stop("Atomic write validation failed: object is not a data.frame.")
    }

    if (file.exists(target_path)) {
        file.copy(target_path, backup_path, overwrite = TRUE)
    }

    renamed <- file.rename(tmp_path, target_path)
    if (!isTRUE(renamed)) {
        copied <- file.copy(tmp_path, target_path, overwrite = TRUE)
        unlink(tmp_path, force = TRUE)
        if (!isTRUE(copied)) {
            stop("Atomic write failed: unable to move temporary file into place.")
        }
    }

    invisible(TRUE)
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
    expected <- switch(provider_id,
        florabr = "Flora_e_Funga_do_Brasil.rds",
        faunabr = "CompleteBrazilianFauna.gz",
        NULL
    )
    if (is.null(expected)) return(invisible(NULL))
    hits <- list.files(tmp_dir, pattern = expected, recursive = TRUE,
                       full.names = TRUE)
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
            expected, provider_id, tmp_dir, tree
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
            data <- florabr::load_florabr(
                data_dir = tmp_dir,
                data_version = data_version,
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
            data <- faunabr::load_faunabr(
                data_dir = tmp_dir,
                data_version = data_version,
                type = "short",
                verbose = FALSE
            )
        } else {
            stop(sprintf("Unknown BR provider: %s", provider_id))
        }

        persist_path <- .brprovider_rds_path(provider_id)
        backup_path <- .brprovider_backup_path(provider_id)
        .brprovider_write_rds_atomic(data, persist_path, backup_path)

        local_version <- .brprovider_detect_downloaded_version(tmp_dir, data_version)
        if (is.na(local_version) || !nzchar(local_version)) {
            local_version <- as.character(data_version)
            if (identical(local_version, "latest")) {
                local_version <- NA_character_
            }
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
        brprovider_clear_cache(provider_id)
        .brprovider_patch_meta(provider_id, list(
            provider_id = provider_id,
            local_version = as.character(result$local_version),
            remote_version_last_seen = as.character(result$local_version),
            last_checked_at = .brprovider_time_to_string(now),
            last_updated_at = .brprovider_time_to_string(now),
            status = "up_to_date",
            last_error = NA_character_,
            source_package_version = .brprovider_pkg_version_safe(provider_id),
            retry_after_at = NA_character_
        ))
        return(TRUE)
    }

    .brprovider_patch_meta(provider_id, list(
        provider_id = provider_id,
        status = "update_failed",
        last_checked_at = .brprovider_time_to_string(now),
        last_error = as.character(result$error),
        source_package_version = .brprovider_pkg_version_safe(provider_id),
        retry_after_at = .brprovider_time_to_string(now + .brprovider_retry_backoff_secs_default)
    ))

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
.brprovider_start_background_update <- function(provider_id,
                                                local_version = NA_character_,
                                                retry_backoff_secs = .brprovider_retry_backoff_secs_default) {
    provider_id <- as.character(provider_id)

    if (exists(provider_id, envir = .brprovider_jobs, inherits = FALSE)) {
        return(FALSE)
    }

    if (!requireNamespace("future", quietly = TRUE)) {
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

    future_obj <- tryCatch({
        old_plan <- tryCatch(future::plan("list"), error = function(e) NULL)
        changed_plan <- FALSE
        if (is.list(old_plan) && length(old_plan) > 0L && inherits(old_plan[[1L]], "sequential")) {
            future::plan(future::multisession, workers = 1L)
            changed_plan <- TRUE
        }

        on.exit({
            if (isTRUE(changed_plan) && !is.null(old_plan)) {
                try(future::plan(old_plan), silent = TRUE)
            }
        }, add = TRUE)

        future::future(
            {
                .brprovider_background_update_worker(
                    provider_id = provider_id,
                    local_version = local_version
                )
            },
            lazy = FALSE,
            seed = TRUE
        )
    }, error = function(e) e)

    if (inherits(future_obj, "error")) {
        .brprovider_release_lock(provider_id)
        now <- .brprovider_now_utc()
        .brprovider_patch_meta(provider_id, list(
            status = "update_failed",
            last_checked_at = .brprovider_time_to_string(now),
            last_error = as.character(future_obj$message),
            retry_after_at = .brprovider_time_to_string(now + as.numeric(retry_backoff_secs)),
            source_package_version = .brprovider_pkg_version_safe(provider_id)
        ))
        return(FALSE)
    }

    assign(provider_id, list(
        future = future_obj,
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
    if (!requireNamespace("future", quietly = TRUE)) {
        return(list())
    }

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
        future_obj <- job$future

        resolved <- tryCatch(
            future::resolved(future_obj),
            error = function(e) TRUE
        )
        if (!isTRUE(resolved)) {
            next
        }

        result <- tryCatch(
            future::value(future_obj),
            error = function(e) {
                list(
                    ok = FALSE,
                    updated = FALSE,
                    provider_id = id,
                    remote_version = NA_character_,
                    local_version = NA_character_,
                    error = as.character(e$message)
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
            fields <- list(
                status = "up_to_date",
                local_version = as.character(result$local_version),
                remote_version_last_seen = as.character(result$remote_version),
                last_checked_at = .brprovider_time_to_string(now),
                last_error = NA_character_,
                source_package_version = .brprovider_pkg_version_safe(id),
                retry_after_at = NA_character_
            )
            if (isTRUE(result$updated)) {
                fields$last_updated_at <- .brprovider_time_to_string(now)
                brprovider_clear_cache(id)
            }
            .brprovider_patch_meta(id, fields)

            events[[length(events) + 1L]] <- list(
                provider_id = as.character(id),
                status = "up_to_date",
                updated = isTRUE(result$updated),
                local_version = as.character(result$local_version),
                remote_version = as.character(result$remote_version),
                error = NA_character_
            )
        } else {
            .brprovider_patch_meta(id, list(
                status = "update_failed",
                remote_version_last_seen = as.character(result$remote_version),
                last_checked_at = .brprovider_time_to_string(now),
                last_error = as.character(result$error),
                source_package_version = .brprovider_pkg_version_safe(id),
                retry_after_at = .brprovider_time_to_string(now + retry_backoff)
            ))

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
#' @param check_ttl_secs Numeric. Remote check TTL in seconds. Default 24h.
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
            .brprovider_patch_meta(provider_id, list(
                status = "update_failed",
                last_checked_at = .brprovider_time_to_string(now),
                last_error = as.character(bootstrap$error),
                source_package_version = .brprovider_pkg_version_safe(provider_id),
                retry_after_at = .brprovider_time_to_string(now + as.numeric(retry_backoff_secs))
            ))
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

        brprovider_clear_cache(provider_id)
        local_version <- as.character(bootstrap$local_version)
        .brprovider_patch_meta(provider_id, list(
            status = "up_to_date",
            local_version = local_version,
            remote_version_last_seen = local_version,
            last_checked_at = .brprovider_time_to_string(now),
            last_updated_at = .brprovider_time_to_string(now),
            last_error = NA_character_,
            source_package_version = .brprovider_pkg_version_safe(provider_id),
            retry_after_at = NA_character_
        ))

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

    due <- .brprovider_check_due(meta, ttl_secs = check_ttl_secs, now = now)
    in_progress <- identical(as.character(meta$status), "update_in_progress") ||
        exists(provider_id, envir = .brprovider_jobs, inherits = FALSE)
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
# Load (with in-session cache)
# ---------------------------------------------------------------------------

#' Load BR provider data, using an in-session cache to avoid repeated I/O
#'
#' Reads the pre-processed .rds file saved by brprovider_download_data().
#' No florabr/faunabr package calls needed - the data frame is loaded directly.
#'
#' @param provider_id Character. "florabr" or "faunabr".
#' @param force_reload Logical. Bypass cache and reload from disk. Default FALSE.
#' @return Data frame of species records, or NULL on failure.
#' @noRd
brprovider_load_data <- function(provider_id, force_reload = FALSE) {
    cache_key <- paste0("data_", provider_id)

    if (!isTRUE(force_reload) &&
        exists(cache_key, envir = .brprovider_cache, inherits = FALSE)) {
        cached <- get(cache_key, envir = .brprovider_cache, inherits = FALSE)
        if (is.data.frame(cached) && nrow(cached) > 0L) {
            return(cached)
        }
    }

    rds_path <- .brprovider_rds_path(provider_id)
    result <- tryCatch({
        if (!file.exists(rds_path)) {
            stop(sprintf("Data not found. Download required for '%s'.", provider_id))
        }
        readRDS(rds_path)
    }, error = function(e) {
        warning(sprintf("brprovider_load_data failed for '%s': %s", provider_id, e$message))
        NULL
    })

    if (!is.null(result) && is.data.frame(result) && nrow(result) > 0L) {
        assign(cache_key, result, envir = .brprovider_cache)
    }
    result
}

#' Clear the in-session BR data cache
#' @param provider_id Character or NULL. NULL clears all entries.
#' @noRd
brprovider_clear_cache <- function(provider_id = NULL) {
    if (is.null(provider_id)) {
        rm(list = ls(envir = .brprovider_cache, all.names = TRUE),
           envir = .brprovider_cache)
    } else {
        cache_key <- paste0("data_", as.character(provider_id))
        if (exists(cache_key, envir = .brprovider_cache, inherits = FALSE)) {
            rm(list = cache_key, envir = .brprovider_cache)
        }
    }
    invisible(NULL)
}

# ---------------------------------------------------------------------------
# Result normalisation
# ---------------------------------------------------------------------------

#' Normalise a raw florabr/faunabr check_names result to the taxadb schema
#'
#' Key mappings:
#'   input_name       -> query_name
#'   Spelling         -> validation_status  (Correct -> accepted/synonym,
#'                                           Probably_incorrect -> ambiguous,
#'                                           Not_found -> not_found)
#'   "Suggested name" -> scientificName
#'   taxonomicStatus  -> taxonomicStatus    (lowercased)
#'   family           -> family
#'
#' When multiple rows share the same input_name (multiple fuzzy suggestions)
#' only the row with the smallest Distance is kept.
#'
#' @param raw_df Data frame from florabr::check_names or
#'   faunabr::check_fauna_names.
#' @param provider_id Character. "florabr" or "faunabr".
#' @return Data frame compatible with the taxadb common schema.
#' @noRd
normalize_brprovider_result <- function(raw_df, provider_id) {
    empty_out <- data.frame(
        query_name        = character(0),
        scientificName    = character(0),
        taxonomicStatus   = character(0),
        family            = character(0),
        provider          = character(0),
        validation_status = character(0),
        match_count       = integer(0),
        stringsAsFactors  = FALSE
    )

    if (!is.data.frame(raw_df) || nrow(raw_df) == 0L) {
        return(empty_out)
    }

    names(raw_df) <- trimws(names(raw_df))

    # Deduplicate: florabr/faunabr can return multiple suggestion rows per
    # input_name when Spelling == "Probably_incorrect". Keep closest match.
    if ("Distance" %in% names(raw_df) && "input_name" %in% names(raw_df)) {
        dist_num <- suppressWarnings(as.numeric(raw_df[["Distance"]]))
        dist_num[is.na(dist_num)] <- Inf
        raw_df[["Distance"]] <- dist_num
        split_list <- split(seq_len(nrow(raw_df)), raw_df[["input_name"]])
        keep_rows <- vapply(split_list, function(idxs) {
            if (length(idxs) == 1L) return(idxs[[1L]])
            idxs[[which.min(raw_df[["Distance"]][idxs])]]
        }, FUN.VALUE = integer(1))
        raw_df <- raw_df[keep_rows, , drop = FALSE]
        rownames(raw_df) <- NULL
    }

    n <- nrow(raw_df)

    query_name <- if ("input_name" %in% names(raw_df)) {
        as.character(raw_df[["input_name"]])
    } else {
        rep(NA_character_, n)
    }

    spelling <- if ("Spelling" %in% names(raw_df)) {
        as.character(raw_df[["Spelling"]])
    } else {
        rep(NA_character_, n)
    }

    taxa_status_raw <- if ("taxonomicStatus" %in% names(raw_df)) {
        tolower(as.character(raw_df[["taxonomicStatus"]]))
    } else {
        rep(NA_character_, n)
    }

    # Map Spelling + taxonomicStatus -> validation_status
    validation_status <- vapply(seq_len(n), function(i) {
        sp <- spelling[[i]]
        ts <- taxa_status_raw[[i]]
        if (is.na(sp)) return("not_found")
        if (identical(sp, "Correct")) {
            if (!is.na(ts) && grepl("synonym", ts, fixed = TRUE)) {
                return("synonym")
            }
            return("accepted")
        }
        if (identical(sp, "Probably_incorrect")) return("ambiguous")
        "not_found"
    }, FUN.VALUE = character(1))

    # scientificName: prefer "Suggested name" column, fall back to input
    suggested_col <- if ("Suggested name" %in% names(raw_df)) {
        "Suggested name"
    } else {
        NA_character_
    }
    scientific_name <- if (!is.na(suggested_col)) {
        sugg <- as.character(raw_df[[suggested_col]])
        ifelse(is.na(sugg) | !nzchar(sugg), query_name, sugg)
    } else {
        query_name
    }

    family <- if ("family" %in% names(raw_df)) {
        as.character(raw_df[["family"]])
    } else {
        rep(NA_character_, n)
    }

    match_count <- as.integer(validation_status != "not_found")

    out <- data.frame(
        query_name        = query_name,
        scientificName    = scientific_name,
        taxonomicStatus   = taxa_status_raw,
        family            = family,
        provider          = as.character(provider_id),
        validation_status = validation_status,
        match_count       = match_count,
        stringsAsFactors  = FALSE
    )

    # Fill taxadb expected columns absent from the BR schema
    for (col_name in c("taxonID", "taxonRank", "acceptedNameUsageID",
                       "update_date", "kingdom", "phylum", "class",
                       "order", "genus", "specificEpithet",
                       "vernacularName", "infraspecificEpithet")) {
        if (!col_name %in% names(out)) {
            out[[col_name]] <- NA_character_
        }
    }

    rownames(out) <- NULL
    out
}

# ---------------------------------------------------------------------------
# Query
# ---------------------------------------------------------------------------

#' Query a BR provider with a vector of normalised scientific names
#'
#' @param query_names Character vector of normalised names.
#' @param provider_id Character. "florabr" or "faunabr".
#' @param data Pre-loaded provider data frame, or NULL to use cache.
#' @param max_distance Numeric. Levenshtein fraction for fuzzy matching.
#'   Default 0.1.
#' @return Data frame in the taxadb common schema.
#' @noRd
query_brprovider <- function(query_names, provider_id,
                             data = NULL, max_distance = 0.1) {
    names_chr <- unique(as.character(query_names))
    names_chr <- names_chr[!is.na(names_chr) & nzchar(names_chr)]
    if (length(names_chr) == 0L) {
        return(normalize_brprovider_result(data.frame(), provider_id))
    }

    if (is.null(data)) {
        data <- brprovider_load_data(provider_id)
    }
    if (is.null(data) || !is.data.frame(data) || nrow(data) == 0L) {
        stop(sprintf(
            "No data available for provider '%s'. Download required.",
            provider_id
        ))
    }

    raw <- tryCatch({
        if (identical(provider_id, "florabr")) {
            if (!requireNamespace("florabr", quietly = TRUE)) {
                stop("Package 'florabr' is not installed.")
            }
            florabr::check_names(
                data             = data,
                species          = names_chr,
                max_distance     = max_distance,
                include_subspecies = TRUE,
                include_variety  = FALSE,
                parallel         = FALSE,
                progress_bar     = FALSE
            )
        } else if (identical(provider_id, "faunabr")) {
            if (!requireNamespace("faunabr", quietly = TRUE)) {
                stop("Package 'faunabr' is not installed.")
            }
            faunabr::check_fauna_names(
                data               = data,
                species            = names_chr,
                max_distance       = max_distance,
                include_subspecies = TRUE
            )
        } else {
            stop(sprintf("Unknown BR provider: %s", provider_id))
        }
    }, error = function(e) e)

    if (inherits(raw, "error")) {
        stop(sprintf("BR provider '%s' query failed: %s", provider_id, raw$message))
    }

    normalize_brprovider_result(
        as.data.frame(raw, stringsAsFactors = FALSE),
        provider_id
    )
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

#' Inspect download parameters without performing any network calls
#'
#' Returns a named list of all relevant paths and metadata that
#' brprovider_download_data() would use. Intended for local audit and debugging.
#'
#' @param provider_id Character. "florabr" or "faunabr".
#' @param data_version Character. Version string. Default "latest".
#' @return Named list with key paths and metadata.
#' @noRd
brprovider_download_params <- function(provider_id, data_version = "latest") {
    list(
        provider_id  = as.character(provider_id),
        data_version = as.character(data_version),
        tmp_dir      = file.path(tempdir(), as.character(provider_id)),
        persist_dir  = brprovider_data_dir(provider_id),
        rds_path     = .brprovider_rds_path(provider_id),
        meta_path    = .brprovider_meta_path(provider_id),
        lock_path    = .brprovider_lock_path(provider_id),
        pkg_version  = .brprovider_pkg_version_safe(provider_id)
    )
}

#' Return query names NOT resolved by a BR provider (validation_status == "not_found")
#' @param result_df Data frame produced by query_brprovider / normalize_brprovider_result.
#' @return Character vector of query_name values.
#' @noRd
brprovider_unresolved_names <- function(result_df) {
    if (!is.data.frame(result_df) || nrow(result_df) == 0L) {
        return(character(0))
    }
    if (!all(c("query_name", "validation_status") %in% names(result_df))) {
        return(character(0))
    }
    idx <- result_df$validation_status == "not_found"
    idx[is.na(idx)] <- FALSE
    unique(as.character(result_df$query_name[idx]))
}
