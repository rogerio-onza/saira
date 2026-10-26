# Helpers for local desktop builds; not part of the saira R package.
desktop_root <- function() {
    arg <- grep("^--file=", commandArgs(), value = TRUE)
    if (length(arg) != 1L) stop("Run this script with Rscript --vanilla.")
    dirname(dirname(normalizePath(sub("^--file=", "", arg), winslash = "/", mustWork = TRUE)))
}

desktop_toolchain <- function(root) {
    as.list(read.dcf(file.path(root, "desktop", "toolchain.dcf"))[1L, ])
}

desktop_library <- function(root) file.path(root, "desktop", "_tools", "library")

desktop_use_library <- function(root) {
    lib <- desktop_library(root)
    if (dir.exists(lib)) .libPaths(c(lib, .libPaths()))
    invisible(lib)
}

desktop_arg <- function(name, default = NULL) {
    prefix <- paste0("--", name, "=")
    found <- commandArgs(trailingOnly = TRUE)
    found <- found[startsWith(found, prefix)]
    if (length(found) > 1L) stop("Repeated argument: --", name)
    if (length(found)) substring(found, nchar(prefix) + 1L) else default
}

desktop_config <- function(root) {
    if (!requireNamespace("yaml", quietly = TRUE)) {
        stop("Missing yaml. On Windows run desktop/build.ps1 to prepare the build tools.")
    }
    config <- yaml::read_yaml(file.path(root, "desktop", "app", "_shinyelectron.yml"))
    if (!identical(config$build$runtime_strategy, "bundled") ||
        !identical(unlist(config$build$platforms), "win") ||
        !identical(unlist(config$build$architectures), "x64")) {
        stop("This pilot requires bundled R for Windows x64.")
    }
    if (!identical(config$updates$enabled, FALSE) ||
        !identical(config$updates$check_on_startup, FALSE)) {
        stop("Automatic updates must stay disabled for this local pilot.")
    }
    config
}

desktop_source_archive <- function(root, target) {
    version <- read.dcf(file.path(root, "DESCRIPTION"))[1L, "Version"]
    filename <- paste0("saira_", version, ".tar.gz")
    dir.create(target, recursive = TRUE, showWarnings = FALSE)
    prepared <- file.path(root, "desktop", "package", filename)
    if (file.exists(prepared)) {
        expected <- trimws(readLines(paste0(prepared, ".sha256"), warn = FALSE))
        if (!identical(unname(tools::sha256sum(prepared)), expected)) {
            stop("The prepared saira source archive failed its SHA-256 check.")
        }
        if (!file.copy(prepared, target)) stop("Could not copy the source archive.")
    } else {
        if (!dir.exists(file.path(root, "R"))) stop("Missing R sources and prepared archive.")
        old <- setwd(target)
        on.exit(setwd(old), add = TRUE)
        status <- system2(file.path(R.home("bin"), "R"),
            c("CMD", "build", "--no-build-vignettes", "--no-manual", shQuote(root)),
            env = "RENV_CONFIG_AUTOLOADER_ENABLED=FALSE")
        if (status != 0L) stop("R CMD build failed.")
    }
    archive <- file.path(target, filename)
    if (!file.exists(archive)) stop("R source archive was not produced: ", archive)
    entries <- utils::untar(archive, list = TRUE)
    if (any(grepl("^saira/(desktop|renv|website|\\.git)(/|$)", entries))) {
        stop("Development or desktop files leaked into the R source package.")
    }
    archive
}

desktop_write_provenance <- function(root, output, archive, config) {
    metadata <- list(
        preview_version = config$app$version,
        saira_package_version = read.dcf(file.path(root, "DESCRIPTION"))[1L, "Version"],
        base = desktop_toolchain(root),
        source_sha256 = unname(tools::sha256sum(archive)),
        built_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        build_R = R.version.string,
        target = "win-x64",
        configured_runtime_R = config$dependencies$r$version,
        configured_electron = config$dependencies$electron$version,
        updates_enabled = FALSE,
        published = FALSE
    )
    jsonlite::write_json(metadata, file.path(output, "build-info.json"),
        auto_unbox = TRUE, pretty = TRUE)
    file.copy(file.path(root, "renv.lock"), file.path(output, "source-renv.lock"))
}

# Files of desktop/shell/assets, named by their path in that folder. The start
# page uses the app fonts and the site photo. The Windows
# kit has no inst/ or website/, so prepare-windows.R puts copies in the kit.
desktop_shell_assets <- function(root) {
    shell <- file.path(root, "desktop", "shell", "assets")
    font_dir <- file.path(root, "inst", "app", "www", "vendor", "fonts")
    if (!dir.exists(font_dir)) font_dir <- file.path(shell, "fonts")
    photo <- file.path(root, "website", "assets", "img", "landing", "tangara-fastuosa.jpg")
    if (!file.exists(photo)) photo <- file.path(shell, "tangara-fastuosa.jpg")
    fonts <- list.files(font_dir, pattern = "\\.(css|woff2)$", full.names = TRUE)
    own <- file.path(shell, c("shell.css", "icon.ico"))
    files <- c(own, photo, fonts)
    names(files) <- c(basename(own), basename(photo), file.path("fonts", basename(fonts)))
    if (!length(fonts) || !all(file.exists(files))) {
        stop("Missing desktop shell assets: ", toString(c(files[!file.exists(files)],
            if (!length(fonts)) file.path(font_dir, "*.woff2"))))
    }
    files
}

desktop_copy_assets <- function(files, target) {
    dir.create(file.path(target, "fonts"), recursive = TRUE, showWarnings = FALSE)
    if (!all(file.copy(files, file.path(target, names(files)), overwrite = TRUE))) {
        stop("Could not copy the desktop shell assets to ", target)
    }
}

# Replace the generated Electron main process with the Saira shell in desktop/shell.
desktop_apply_shell <- function(root, project, config) {
    pages <- c("main.js", "preload.js", "i18n.js", "lifecycle.html")
    shell <- file.path(root, "desktop", "shell", pages)
    if (!all(file.copy(shell, project, overwrite = TRUE))) stop("Could not copy the desktop shell.")
    assets <- desktop_shell_assets(root)
    desktop_copy_assets(assets, file.path(project, "assets"))
    # electron-builder reads build/icon.ico for the installer and the exe.
    dir.create(file.path(project, "build"), showWarnings = FALSE)
    if (!file.copy(assets[["icon.ico"]], file.path(project, "build", "icon.ico"), overwrite = TRUE)) {
        stop("Could not copy the app icon.")
    }
    description <- read.dcf(file.path(root, "DESCRIPTION"))[1L, ]
    info <- list(
        preview_version = config$app$version,
        saira_version = description[["Version"]],
        source_commit = desktop_toolchain(root)[["Source-Commit"]],
        r_version = config$dependencies$r$version
    )
    jsonlite::write_json(info, file.path(project, "desktop-info.json"), auto_unbox = TRUE, pretty = TRUE)
    manifest <- file.path(project, "package.json")
    package <- jsonlite::read_json(manifest)
    package$build$files <- as.list(unique(c(unlist(package$build$files),
        "lifecycle.html", "i18n.js", "desktop-info.json")))
    package$build$win$icon <- "build/icon.ico"
    # shinyelectron writes AGPL. The saira package is GPL-3 (DESCRIPTION).
    package$license <- "GPL-3.0-only"
    # Electron ships about 55 Chromium locale packs. The app has three languages.
    package$build$electronLanguages <- list("pt-BR", "en-US", "es", "es-419")
    jsonlite::write_json(package, manifest, auto_unbox = TRUE, pretty = TRUE)
}

# shinyelectron keeps the help, manuals, examples and C headers of each package.
# The app reads none of them at runtime.
desktop_prune_library <- function(library) {
    targets <- as.vector(outer(list.dirs(library, recursive = FALSE),
        c("doc", "help", "html", "examples", "demo", "include"), file.path))
    targets <- targets[dir.exists(targets)]
    bytes <- sum(file.size(list.files(targets, recursive = TRUE, full.names = TRUE, all.files = TRUE)))
    unlink(targets, recursive = TRUE)
    if (any(dir.exists(targets))) stop("Could not prune the bundled R library.")
    message(sprintf("Pruned %d package folders (%.0f MB).", length(targets), bytes / 1024^2))
}

# The bundle must ship the versions that the tests ran with (renv.lock). The
# repository snapshot has only CRAN releases, so the r-universe development
# builds in the lock change, and so do the recommended packages of the R build.
desktop_check_versions <- function(root, library, output) {
    lock <- jsonlite::read_json(file.path(root, "renv.lock"))$Packages
    bundled <- installed.packages(lib.loc = library, noCache = TRUE)[,
        c("Package", "Version", "Priority"), drop = FALSE]
    bundled <- as.data.frame(bundled, stringsAsFactors = FALSE)
    bundled$Lock <- vapply(bundled$Package, function(p) lock[[p]]$Version %||% NA_character_, "")
    universe <- vapply(bundled$Package, function(p) any(grepl("r-universe", unlist(lock[[p]]))), NA)
    unlisted <- setdiff(bundled$Package[is.na(bundled$Lock)], "saira")
    changed <- bundled[!is.na(bundled$Lock) & bundled$Version != bundled$Lock, , drop = FALSE]
    allowed <- universe[changed$Package] | changed$Priority %in% "recommended"
    utils::write.csv(changed, file.path(output, "version-differences.csv"), row.names = FALSE)
    if (length(unlisted)) stop("Bundled packages missing from renv.lock: ", toString(unlisted))
    if (!all(allowed)) {
        bad <- changed[!allowed, , drop = FALSE]
        stop("Bundled versions differ from renv.lock: ",
            toString(paste0(bad$Package, " ", bad$Version, " (lock ", bad$Lock, ")")))
    }
    message(sprintf("Bundled versions match renv.lock (%d known differences).", nrow(changed)))
}

# The demo shows the export blockers on purpose. The E2E needs a file that
# exports: 'Coleta' has no DwC term, and two rows have latitude -95.
desktop_write_e2e_csv <- function(demo, output) {
    data <- utils::read.csv(demo, colClasses = "character", check.names = FALSE,
        na.strings = character(), fileEncoding = "UTF-8-BOM")
    in_range <- function(x, limit) {
        value <- suppressWarnings(as.numeric(x))
        !nzchar(trimws(x)) | (!is.na(value) & abs(value) <= limit)
    }
    data$tipo_de_registro[data$tipo_de_registro == "Coleta"] <- "Espécime preservado"
    data <- data[in_range(data$latitude, 90) & in_range(data$longitude, 180), , drop = FALSE]
    utils::write.csv(data, output, row.names = FALSE, fileEncoding = "UTF-8")
    invisible(output)
}
