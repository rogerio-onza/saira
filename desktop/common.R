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

desktop_host_platform <- function() {
    if (.Platform$OS.type == "windows") "win" else if (Sys.info()[["sysname"]] == "Linux") "linux" else "other"
}

# The config lists every target. A build makes one of them.
desktop_config <- function(root, platform = "win") {
    if (!requireNamespace("yaml", quietly = TRUE)) {
        stop("Missing yaml. Run desktop/bootstrap.R (desktop/build.ps1 on Windows) first.")
    }
    config <- yaml::read_yaml(file.path(root, "desktop", "app", "_shinyelectron.yml"))
    if (!identical(config$build$runtime_strategy, "bundled") ||
        !platform %in% unlist(config$build$platforms) ||
        !identical(unlist(config$build$architectures), "x64")) {
        stop("This pilot requires bundled R for x64 and a target in build.platforms: ", platform)
    }
    if (!identical(config$updates$enabled, FALSE) ||
        !identical(config$updates$check_on_startup, FALSE)) {
        stop("Automatic updates must stay disabled for this local pilot.")
    }
    config$build$platforms <- list(platform)
    if (platform == "linux") {
        # On Linux the snapshot URL serves only sources. The __linux__ path has
        # the Ubuntu 24.04 binaries of the same date.
        config$dependencies$r$repos <- as.list(sub("/cran/", "/cran/__linux__/noble/",
            unlist(config$dependencies$r$repos), fixed = TRUE))
    }
    config
}

desktop_rscript_name <- function() if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"

# shinyelectron has no portable R for Linux. The Posit r-builds .deb has a full R
# in /opt/R/<version>/lib/R. The build extracts it without dpkg -i and makes it
# relocatable: bin/R finds R_HOME from its own path, and bin/Rscript gives RHOME
# to the real binary, which has the /opt path compiled in. Returns the folder
# that holds portable-r-<version>-linux-x64, as install_r_portable() does.
desktop_linux_r <- function(root, version) {
    pin <- desktop_toolchain(root)
    if (!identical(pin[["Linux-R-Version"]], version)) {
        stop("toolchain.dcf pins Linux R ", pin[["Linux-R-Version"]], ", the config asks for ", version)
    }
    cache <- file.path(root, "desktop", "_tools", paste0("linux-r-", version))
    home <- file.path(cache, paste0("portable-r-", version, "-linux-x64"))
    if (file.exists(file.path(home, "bin", "Rscript.bin"))) return(cache)
    unlink(cache, recursive = TRUE)
    dir.create(cache, recursive = TRUE)
    deb <- file.path(cache, "r.deb")
    download.file(sprintf("https://cdn.posit.co/r/ubuntu-2404/pkgs/r-%s_1_amd64.deb", version),
        deb, mode = "wb", quiet = TRUE)
    if (!identical(unname(tools::sha256sum(deb)), pin[["Linux-R-SHA256"]])) {
        stop("The R .deb failed its SHA-256 check.")
    }
    if (system2("dpkg-deb", c("-x", shQuote(deb), shQuote(file.path(cache, "deb")))) != 0L) {
        stop("dpkg-deb could not extract the R .deb.")
    }
    prefix <- sprintf("/opt/R/%s/lib/R", version)
    if (!file.rename(file.path(cache, "deb", prefix), home)) stop("Could not move ", prefix)
    unlink(c(deb, file.path(cache, "deb")), recursive = TRUE)

    relative_home <- 'R_HOME_DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd -P)"'
    script <- file.path(home, "bin", "R")
    lines <- readLines(script)
    first <- grep("^R_HOME_DIR=", lines)
    last <- first + match("fi", lines[-seq_len(first)])
    if (length(first) != 1L || is.na(last)) stop("Unexpected layout of bin/R in the R .deb.")
    lines <- c(lines[seq_len(first - 1L)], relative_home, lines[-seq_len(last)])
    writeLines(gsub(prefix, "${R_HOME_DIR}", lines, fixed = TRUE), script)
    makeconf <- file.path(home, "etc", "Makeconf")
    writeLines(gsub(prefix, "$(R_HOME)", readLines(makeconf), fixed = TRUE), makeconf)
    # R_HOME/syslib holds the shared libraries of the bundle (desktop_bundle_system_libs).
    ldpaths <- file.path(home, "etc", "ldpaths")
    writeLines(sub("${R_HOME}/lib:/usr/local/lib:/usr/lib/x86_64-linux-gnu", "${R_HOME}/lib:${R_HOME}/syslib",
        readLines(ldpaths), fixed = TRUE), ldpaths)
    rscript <- file.path(home, "bin", "Rscript")
    # Not in bin/exec: R CMD INSTALL reads each file there as a sub-architecture.
    if (!file.rename(rscript, file.path(home, "bin", "Rscript.bin"))) stop("Could not move Rscript.")
    writeLines(c("#!/bin/sh", "# The real Rscript reads RHOME before its compiled-in /opt path.",
        sub("R_HOME_DIR", "RHOME", relative_home, fixed = TRUE), "export RHOME",
        'exec "$RHOME/bin/Rscript.bin" "$@"'), rscript)
    Sys.chmod(c(script, rscript), "0755")
    cache
}

# Libraries that come from the host: glibc must match the loader, the graphics
# stack must match the drivers, and the font libraries must read the host font
# configuration. Every distribution with a desktop has them.
desktop_host_libraries <- paste0("^(ld-linux|linux-vdso|libc|libm|libmvec|libdl|libpthread|librt|",
    "libresolv|libutil|libanl|libnss_|libGL|libGLX|libEGL|libGLdispatch|libOpenGL|libdrm|libgbm|",
    "libX11|libxcb|libXau|libXdmcp|libXext|libXrender|libfontconfig|libfreetype|libharfbuzz|libexpat)[.-]")

# The R binaries and the package libraries link to Ubuntu 24.04 libraries
# (BLAS, ICU, GDAL, PROJ, GEOS and others). They go into R_HOME/syslib, which
# etc/ldpaths puts on LD_LIBRARY_PATH. PROJ and GDAL also read their data files.
desktop_bundle_system_libs <- function(r_home, library) {
    objects <- c(file.path(r_home, "bin", c("exec/R", "Rscript.bin")),
        list.files(c(file.path(r_home, c("lib", "modules", "library")), library),
            pattern = "[.]so([.][0-9.]+)?$", recursive = TRUE, full.names = TRUE))
    old <- Sys.getenv("LD_LIBRARY_PATH", unset = NA)
    Sys.setenv(LD_LIBRARY_PATH = file.path(r_home, "lib"))
    on.exit(if (is.na(old)) Sys.unsetenv("LD_LIBRARY_PATH") else Sys.setenv(LD_LIBRARY_PATH = old), add = TRUE)
    lines <- unlist(lapply(objects, function(f) system2("ldd", shQuote(f), stdout = TRUE)))
    missing <- unique(trimws(sub("=>.*", "", grep("not found", lines, value = TRUE))))
    if (length(missing)) stop("Shared libraries not found on the build host: ", toString(missing))
    found <- regmatches(lines, regexec("^\\s*(\\S+) => (/\\S+)", lines))
    found <- do.call(rbind, found[lengths(found) == 3L])
    found <- unique(data.frame(name = found[, 2], path = found[, 3]))
    found <- found[!startsWith(normalizePath(found$path), normalizePath(r_home)) &
        !grepl(desktop_host_libraries, found$name), , drop = FALSE]
    syslib <- file.path(r_home, "syslib")
    dir.create(file.path(syslib, "share"), recursive = TRUE, showWarnings = FALSE)
    if (!all(file.copy(normalizePath(found$path), file.path(syslib, found$name), overwrite = TRUE))) {
        stop("Could not copy the shared libraries.")
    }
    data <- c(proj = "/usr/share/proj", gdal = "/usr/share/gdal")
    if (!all(file.copy(data, file.path(syslib, "share"), recursive = TRUE))) stop("Could not copy PROJ and GDAL data.")
    # etc/Renviron is read on every start, with --vanilla too.
    cat("\n# PROJ and GDAL data of the bundle (desktop build).\n",
        "PROJ_DATA=${R_HOME}/syslib/share/proj\n", "GDAL_DATA=${R_HOME}/syslib/share/gdal\n",
        file = file.path(r_home, "etc", "Renviron"), append = TRUE, sep = "")
    bytes <- sum(file.size(list.files(syslib, recursive = TRUE, full.names = TRUE)))
    message(sprintf("Bundled %d shared libraries and the PROJ/GDAL data (%.0f MB).", nrow(found), bytes / 1024^2))
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

desktop_git <- function(root, ...) {
    out <- suppressWarnings(system2("git", c("-C", shQuote(root), ...), stdout = TRUE, stderr = FALSE))
    if (!is.null(attr(out, "status"))) stop("git failed: ", paste(c(...), collapse = " "))
    out
}

# A checkout reads the identity from git. The Windows kit has no .git, so
# prepare-windows.R writes the identity into the kit copy of toolchain.dcf.
desktop_source_identity <- function(root) {
    if (file.exists(file.path(root, ".git"))) {
        return(list(
            commit = desktop_git(root, "rev-parse", "HEAD"),
            branch = desktop_git(root, "rev-parse", "--abbrev-ref", "HEAD"),
            dirty = length(desktop_git(root, "status", "--porcelain")) > 0L
        ))
    }
    pin <- desktop_toolchain(root)
    if (is.null(pin[["Source-Commit"]])) stop("The kit has no source identity in toolchain.dcf.")
    list(commit = pin[["Source-Commit"]], branch = pin[["Source-Branch"]],
        dirty = identical(pin[["Source-Dirty"]], "TRUE"))
}

# With uncommitted files, one commit does not name what the build ships. A
# preview can accept that on request. A release version (no suffix) cannot.
desktop_check_source <- function(origin, version, allow_dirty) {
    if (!origin$dirty) return(invisible(TRUE))
    if (!grepl("-", version, fixed = TRUE)) stop("A release build needs a clean source tree: ", version)
    if (!allow_dirty) stop("The source tree has uncommitted files. Commit them, or use --allow-dirty for a preview.")
    invisible(TRUE)
}

desktop_write_provenance <- function(root, output, archive, config, origin) {
    metadata <- list(
        desktop_version = config$app$version,
        saira_package_version = read.dcf(file.path(root, "DESCRIPTION"))[1L, "Version"],
        source = origin,
        base = desktop_toolchain(root),
        source_sha256 = unname(tools::sha256sum(archive)),
        built_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        build_R = R.version.string,
        target = paste0(config$build$platforms[[1L]], "-x64"),
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
    own <- file.path(shell, c("shell.css", "icon.ico", "icon.png"))
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
# Each old text must occur once, so a new shinyelectron or electron-builder
# stops the build. The text stays bytes, so a C locale keeps the accents.
desktop_patch_text <- function(file, replacements) {
    text <- paste(readLines(file, warn = FALSE), collapse = "\n")
    for (old in names(replacements)) {
        if (sum(gregexpr(old, text, fixed = TRUE, useBytes = TRUE)[[1L]] > 0L) != 1L) {
            stop("Patch text not found once in ", basename(file), ": ", old)
        }
        text <- sub(old, replacements[[old]], text, fixed = TRUE, useBytes = TRUE)
    }
    writeLines(text, file, useBytes = TRUE)
}

# The AppImage launcher of electron-builder adds --no-sandbox when the system
# blocks user namespaces. The patched launcher stops with a message instead.
# The .deb keeps the sandbox: it installs an AppArmor profile.
desktop_patch_apprun <- function(root, project) {
    snippet <- paste(readLines(file.path(root, "desktop", "apprun-sandbox.sh"), warn = FALSE), collapse = "\n")
    desktop_patch_text(
        file.path(project, "node_modules", "app-builder-lib", "out", "targets", "appimage", "appImageUtil.js"),
        stats::setNames(snippet, paste0(
            "if [ $HAVE_NO_SANDBOX -eq 0 ] && ! unshare -Ur true 2>/dev/null ; then\n",
            "  NO_SANDBOX=(--no-sandbox)\nfi"
        ))
    )
}

desktop_apply_shell <- function(root, project, config, origin) {
    modules <- c("i18n.js", "log-retention.js", "log-writer.js")
    pages <- c("main.js", "preload.js", "lifecycle.html", modules)
    shell <- file.path(root, "desktop", "shell", pages)
    if (!all(file.copy(shell, project, overwrite = TRUE))) stop("Could not copy the desktop shell.")
    assets <- desktop_shell_assets(root)
    desktop_copy_assets(assets, file.path(project, "assets"))
    # electron-builder reads build/icon.ico (Windows) or build/icon.png (Linux).
    dir.create(file.path(project, "build"), showWarnings = FALSE)
    if (!all(file.copy(assets[c("icon.ico", "icon.png")], file.path(project, "build"), overwrite = TRUE))) {
        stop("Could not copy the app icon.")
    }
    description <- read.dcf(file.path(root, "DESCRIPTION"))[1L, ]
    info <- list(
        desktop_version = config$app$version,
        saira_version = description[["Version"]],
        source_commit = origin$commit,
        source_dirty = origin$dirty,
        r_version = config$dependencies$r$version
    )
    jsonlite::write_json(info, file.path(project, "desktop-info.json"), auto_unbox = TRUE, pretty = TRUE)
    # R gets a process group of its own. stop() waits for shell/process-tree.js,
    # which replaces the helper of shinyelectron, so the R workers stop too.
    # --vanilla: R reads no profile or environment file of the host.
    # The crash report shows the last lines of stderr, so a tail is enough.
    # A bundled app uses only its own R and library: no saved path, no R of the host.
    desktop_patch_text(file.path(project, "backends", "native-r.js"), c(
        "spawn(rscript, ['-e', rCode], {" =
            "spawn(rscript, ['--vanilla', '-e', rCode], { detached: process.platform !== 'win32',",
        "stderr += msg + '\\n';" = "stderr = (stderr + msg + '\\n').slice(-256 * 1024);",
        "if (pickerPrefs && pickerPrefs.runtime_path) {" =
            "if (config?.runtime_strategy !== 'bundled' && pickerPrefs && pickerPrefs.runtime_path) {",
        "if (userLibPath) libPaths.push(" =
            "if (config?.runtime_strategy !== 'bundled' && userLibPath) libPaths.push(",
        "    // 3. Try system PATH first\n" = paste0(
            "    if (config && config.runtime_strategy === 'bundled') {\n",
            "      const message = 'The bundled R is missing. Reinstall the app.';\n",
            "      this.emit('status', { phase: 'error', code: 'R_MISSING', message, detail: { stderr: message } });\n",
            "      throw new Error(message);\n",
            "    }\n\n",
            "    // 3. Try system PATH first\n"),
        "      exited = waitForExit(child);\n      killProcessTree(child);" =
            "      exited = Promise.all([waitForExit(child), killProcessTree(child)]);"
    ))
    if (!file.copy(file.path(root, "desktop", "shell", "process-tree.js"), file.path(project, "backends"), overwrite = TRUE)) {
        stop("Could not copy the process tree module.")
    }
    desktop_patch_text(file.path(project, "backends", "utils.js"), c(
        "  killProcessTree,\n" = "  killProcessTree: require('./process-tree').killProcessTree,\n"
    ))
    manifest <- file.path(project, "package.json")
    package <- jsonlite::read_json(manifest)
    package$build$files <- as.list(unique(c(unlist(package$build$files),
        "lifecycle.html", modules, "desktop-info.json")))
    # The main process loads the backend code, so it stays in app.asar. R and the
    # Shiny app must be real files on disk.
    package$build$asarUnpack <- as.list(setdiff(unlist(package$build$asarUnpack), "backends/**/*"))
    package$build$win$icon <- "build/icon.ico"
    if (identical(config$build$platforms[[1L]], "linux")) {
        # The .deb needs a maintainer with an email, and the AppImage runs on other distributions.
        author <- eval(parse(text = description[["Authors@R"]]))
        package$author <- list(name = format(author, include = c("given", "family")), email = author$email)
        package$homepage <- description[["URL"]]
        package$build$linux$icon <- "build/icon.png"
        package$build$linux$target <- list("AppImage", "deb")
        package$build$linux$category <- "Science"
    }
    # shinyelectron writes AGPL. The saira package is GPL-3 (DESCRIPTION).
    package$license <- "GPL-3.0-only"
    # Electron ships about 55 Chromium locale packs. The app has three languages.
    package$build$electronLanguages <- list("pt-BR", "en-US", "es", "es-419")
    # shinyelectron writes "^" ranges. The exact version matches the approved lockfile.
    package$devDependencies$electron <- config$dependencies$electron$version
    # ADR-191: electron-builder 26.18.0 asks for minimatch ^10, and the pinned
    # @electron/universal 2.0.3 asks for ^9. Both are in the advisory range. Keys by
    # range leave minimatch 3 and 5 alone: they have another API and are not affected.
    package$overrides <- list(`minimatch@^9` = "11.0.4", `minimatch@^10` = "11.0.4")
    # The app does not start Electron as Node.js. The main process loads its code
    # from app.asar. The integrity check of that file works on Windows and macOS only.
    package$build$electronFuses <- list(runAsNode = FALSE,
        enableNodeOptionsEnvironmentVariable = FALSE, enableNodeCliInspectArguments = FALSE,
        enableEmbeddedAsarIntegrityValidation = TRUE, onlyLoadAppFromAsar = TRUE)
    jsonlite::write_json(package, manifest, auto_unbox = TRUE, pretty = TRUE)
}

# desktop/node-package-lock.json is the approved npm lockfile. npm install keeps
# its versions when package.json accepts them. Without the file, npm chooses the
# versions, so the build stops.
desktop_npm_lock <- function(root) {
    approved <- file.path(root, "desktop", "node-package-lock.json")
    if (!file.exists(approved)) stop("Missing approved desktop/node-package-lock.json.")
    approved
}

desktop_use_npm_lock <- function(root, project) {
    if (!file.copy(desktop_npm_lock(root), file.path(project, "package-lock.json"), overwrite = TRUE)) {
        stop("Could not copy the approved npm lockfile.")
    }
}

# The build stops before electron-builder when npm resolved a package that is
# not in the approved lockfile, with the same version and integrity.
desktop_check_npm_lock <- function(root, project) {
    approved <- desktop_npm_lock(root)
    resolved <- file.path(project, "package-lock.json")
    if (!file.exists(resolved)) stop("npm wrote no package-lock.json.")
    entries <- function(path) {
        packages <- jsonlite::read_json(path)$packages
        packages <- packages[names(packages) != ""]
        vapply(packages, function(entry) paste(entry$version %||% "", entry$integrity %||% ""), "")
    }
    old <- entries(approved)
    new <- entries(resolved)
    keys <- union(names(old), names(new))
    changed <- keys[old[keys] != new[keys] | is.na(old[keys]) | is.na(new[keys])]
    if (length(changed)) {
        stop("npm resolved packages that differ from desktop/node-package-lock.json: ",
            paste(utils::head(changed, 10L), collapse = ", "))
    }
    invisible(TRUE)
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

# The portable R also ships Tcl/Tk, the message translations, help pages and
# recommended packages that no bundled package loads. The app uses none of them.
desktop_prune_runtime <- function(r_home, library) {
    if (length(r_home) != 1L || !dir.exists(r_home)) stop("Missing the portable R folder.")
    base_lib <- file.path(r_home, "library")
    db <- installed.packages(lib.loc = c(library, base_lib), noCache = TRUE)
    db <- db[!duplicated(db[, "Package"]), , drop = FALSE]
    needed <- tools::package_dependencies(rownames(installed.packages(library, noCache = TRUE)),
        db = db, which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE)
    needed <- unique(unlist(needed))
    shipped <- installed.packages(base_lib, noCache = TRUE)
    optional <- shipped[shipped[, "Priority"] %in% "recommended", "Package"]
    unused <- c(setdiff(optional, needed), setdiff("tcltk", needed))
    targets <- c(file.path(r_home, "Tcl"), file.path(base_lib, c("translations", unused)),
        as.vector(outer(list.dirs(base_lib, recursive = FALSE), c("doc", "help", "html"), file.path)))
    targets <- targets[dir.exists(targets)]
    bytes <- sum(file.size(list.files(targets, recursive = TRUE, full.names = TRUE, all.files = TRUE)))
    unlink(targets, recursive = TRUE)
    if (any(dir.exists(targets))) stop("Could not prune the portable R.")
    message(sprintf("Pruned the portable R (%.0f MB). Removed packages: %s.",
        bytes / 1024^2, toString(unused)))
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

# The package BR snapshot (ADR-153) ages between releases. When it is more than
# 30 days old, the first names check of a new install waits for the Flora BR and
# Fauna BR downloads. The bundled R puts the IPT versions of today into the
# bundled saira. If the IPT does not answer, the bundle keeps the package snapshot.
desktop_refresh_br_snapshot <- function(r_dir) {
    rscript <- Sys.glob(file.path(r_dir, "portable-r-*", "bin", desktop_rscript_name()))
    if (length(rscript) != 1L) stop("Expected one packaged ", desktop_rscript_name(), ".")
    script <- tempfile(fileext = ".R")
    writeLines(c(
        ".libPaths(c(commandArgs(TRUE)[1L], .Library))",
        "Sys.setenv(R_USER_DATA_DIR = tempfile('brp-'))",
        "out <- system.file('extdata', 'brproviders', package = 'saira')",
        "snapshot <- jsonlite::read_json(file.path(out, 'snapshot.json'))",
        "for (pid in c('florabr', 'faunabr')) {",
        "    if (!isTRUE(saira:::brprovider_download_data(pid, verbose = FALSE))) stop('Download failed: ', pid)",
        "    data <- readRDS(saira:::.brprovider_rds_path(pid))",
        "    stopifnot(is.data.frame(data), nrow(data) > 0L)",
        "    meta <- saira:::.brprovider_read_meta(pid)",
        "    saveRDS(data, file.path(out, paste0(pid, '.rds')), compress = 'xz')",
        "    snapshot[[pid]] <- list(version = meta$local_version, downloaded_at = meta$last_updated_at,",
        "        package_version = meta$source_package_version)",
        "    jsonlite::write_json(snapshot, file.path(out, 'snapshot.json'), auto_unbox = TRUE, pretty = TRUE)",
        "}"
    ), script)
    status <- system2(rscript, c("--vanilla", shQuote(script), shQuote(file.path(r_dir, "library"))))
    snapshot <- jsonlite::read_json(file.path(r_dir, "library", "saira", "extdata", "brproviders", "snapshot.json"))
    versions <- toString(paste(names(snapshot), vapply(snapshot, function(x) x$version, ""),
        "from", vapply(snapshot, function(x) x$downloaded_at, "")))
    if (status != 0L) {
        warning("The BR snapshot update failed. The bundle has: ", versions, call. = FALSE)
    } else {
        message("BR snapshot: ", versions)
    }
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
