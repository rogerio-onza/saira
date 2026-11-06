# Refresh the Flora e Funga do Brasil and Fauna do Brasil snapshot in
# inst/extdata/brproviders/ (ADR-153). Run it before each release.
#
# Usage, from the repository root:
#   Rscript data-raw/update_brproviders.R          download the latest IPT versions
#   Rscript data-raw/update_brproviders.R --cache  use this machine's Saira cache
#   Rscript data-raw/update_brproviders.R --check  compare the snapshot with the IPT

pkgload::load_all(".", quiet = TRUE)

args <- commandArgs(trailingOnly = TRUE)
providers <- c("florabr", "faunabr")
out_dir <- file.path("inst", "extdata", "brproviders")
snapshot_path <- file.path(out_dir, "snapshot.json")
snapshot <- if (file.exists(snapshot_path)) jsonlite::fromJSON(snapshot_path) else list()

if ("--check" %in% args) {
    for (pid in providers) {
        local <- snapshot[[pid]]$version %||% NA_character_
        age <- floor(as.numeric(difftime(
            Sys.time(),
            as.POSIXct(snapshot[[pid]]$downloaded_at %||% NA_character_,
                       format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
            units = "days"
        )))
        remote <- tryCatch(
            suppressWarnings(brprovider_latest_remote_version(pid)),
            error = function(e) NA_character_
        )
        message(if (is.na(remote)) {
            sprintf("%s: snapshot %s, %s days old. The IPT did not answer: check the version by hand.",
                    pid, local, age)
        } else if (is.na(local) || brprovider_compare_versions(remote, local) > 0L) {
            sprintf("%s: snapshot %s is older than IPT %s. Run data-raw/update_brproviders.R.",
                    pid, local, remote)
        } else {
            sprintf("%s: snapshot %s is the IPT version.", pid, local)
        })
    }
    quit(save = "no")
}

if (!"--cache" %in% args) {
    # A temporary data dir keeps the developer cache out of the download.
    Sys.setenv(R_USER_DATA_DIR = tempfile("brp_snapshot_"))
    for (pid in providers) {
        if (!isTRUE(brprovider_download_data(pid))) {
            stop("Download failed for ", pid, ". Try again later or use --cache.")
        }
    }
}

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
for (pid in providers) {
    data <- readRDS(.brprovider_rds_path(pid))
    stopifnot(is.data.frame(data), nrow(data) > 0L)
    meta <- .brprovider_read_meta(pid)
    # xz makes the file about 35% smaller than the default gzip.
    saveRDS(data, file.path(out_dir, paste0(pid, ".rds")), compress = "xz")
    snapshot[[pid]] <- list(
        version = meta$local_version,
        downloaded_at = meta$last_updated_at,
        package_version = meta$source_package_version
    )
    message(sprintf("%s: snapshot %s, %d rows.", pid, meta$local_version, nrow(data)))
}
jsonlite::write_json(snapshot, snapshot_path, auto_unbox = TRUE, pretty = TRUE)
