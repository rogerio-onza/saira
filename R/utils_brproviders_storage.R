# Cache scope: public provider data shared by sessions in this R process.
# Loaded frames persist until brprovider_clear_cache(); on-disk update checks
# retain their 24-hour TTL, 15-minute retry backoff and existing lock ownership.
# Utils brproviders storage

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
    .brprovider_seed_from_bundle(provider_id)
    file.exists(.brprovider_rds_path(provider_id))
}

#' Path of a file in the BR provider snapshot shipped with the package
#' @param file Character. File name inside inst/extdata/brproviders.
#' @return Absolute path, or "" when the file is not bundled.
#' @noRd
.brprovider_bundle_path <- function(file) {
    system.file("extdata", "brproviders", file, package = "saira")
}

#' Copy the bundled snapshot into an empty user cache
#'
#' The IPT download fails often (ADR-070, ADR-153), and without a cache a new
#' user has no Flora or Fauna BR data at all. The copy goes into the normal
#' cache, so a later download replaces it as usual.
#' @param provider_id Character. "florabr" or "faunabr".
#' @return TRUE when it copied the snapshot, FALSE otherwise.
#' @noRd
.brprovider_seed_from_bundle <- function(provider_id) {
    target <- .brprovider_rds_path(provider_id)
    bundle <- .brprovider_bundle_path(paste0(provider_id, ".rds"))
    if (file.exists(target) || !nzchar(bundle)) {
        return(FALSE)
    }
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    # Copy, then rename: a parallel session must never read a half-copied file.
    tmp <- paste0(target, ".seed")
    if (!isTRUE(file.copy(bundle, tmp, overwrite = TRUE)) ||
        !isTRUE(file.rename(tmp, target))) {
        unlink(tmp, force = TRUE)
        return(FALSE)
    }
    info <- tryCatch(
        jsonlite::fromJSON(.brprovider_bundle_path("snapshot.json"))[[provider_id]],
        error = function(e) NULL
    )
    version <- .brprovider_scalar_chr(info$version)
    .brprovider_patch_meta(provider_id, list(
        local_version = version,
        remote_version_last_seen = version,
        last_updated_at = .brprovider_scalar_chr(info$downloaded_at),
        status = "up_to_date",
        last_error = NA_character_,
        retry_after_at = NA_character_
    ))
    TRUE
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

    # Check data first: it can copy the bundled snapshot and write its meta.
    has_data <- brprovider_data_available(provider_id)
    meta <- .brprovider_read_meta(provider_id)

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

    # The old cache still answers after a failed update (ADR-073). A known
    # newer remote version means the data is stale, so the failure stays
    # visible (ADR-167).
    if (has_data && identical(as.character(meta$status), "update_failed") &&
        brprovider_compare_versions(meta$remote_version_last_seen, meta$local_version) <= 0L) {
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
# Load (with in-process cache)
# ---------------------------------------------------------------------------

#' Load BR provider data, using an in-process cache to avoid repeated I/O
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

#' Clear the in-process BR data cache
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
