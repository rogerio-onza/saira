# Release gate of the desktop candidates.
#
# On the build machine, after build.R (Linux) or build.ps1 (Windows):
#   Rscript --vanilla desktop/gate.R --build=<build folder>
# This checks the provenance of the build and runs shell-check.mjs, the smoke
# test and e2e.mjs on the built app. It writes gate.json into the build folder.
# A preview build (source.dirty) needs --preview, and its record is not a
# release record. --skip-e2e does not open a window, and its record is
# INCOMPLETE.
#
# In the git checkout of the release, with the two builds:
#   Rscript --vanilla desktop/gate.R --verify --linux=<build> --windows=<build>
# This accepts only two PASS records of the same clean commit. The two source
# archives must hold the files of HEAD, HEAD must hold the tip of the release
# branch, and the installers must have the hashes of the records.
arg <- grep("^--file=", commandArgs(), value = TRUE)
source(file.path(dirname(normalizePath(sub("^--file=", "", arg))), "common.R"))
root <- desktop_root()

gate_sha <- function(path) unname(tools::sha256sum(path))

gate_paths <- function(build, platform) {
    project <- file.path(build, "bundle", "electron-app")
    unpacked <- file.path(project, "dist", if (platform == "win") "win-unpacked" else "linux-unpacked")
    list(
        project = project,
        dist = file.path(project, "dist"),
        unpacked = unpacked,
        exe = file.path(unpacked, if (platform == "win") "saira-desktop.exe" else "saira-desktop"),
        runtime = file.path(unpacked, "resources", "app.asar.unpacked", "runtime", "R"),
        archive = list.files(file.path(build, "input", "package"), "^saira_.*[.]tar[.]gz$", full.names = TRUE)
    )
}

# The installers and their hashes, from SHA256SUMS.txt of the build.
gate_installers <- function(dist) {
    sums <- read.table(file.path(dist, "SHA256SUMS.txt"), col.names = c("sha256", "file"),
        colClasses = "character")
    if (!nrow(sums)) stop("SHA256SUMS.txt lists no installer.")
    actual <- vapply(file.path(dist, sums$file), gate_sha, character(1))
    if (!identical(unname(actual), sums$sha256)) {
        stop("An installer does not match SHA256SUMS.txt: ", paste(sums$file[actual != sums$sha256], collapse = ", "))
    }
    as.list(stats::setNames(sums$sha256, sums$file))
}

gate_archive_description <- function(archive) {
    folder <- tempfile("saira-gate-description-")
    on.exit(unlink(folder, recursive = TRUE), add = TRUE)
    utils::untar(archive, files = "saira/DESCRIPTION", exdir = folder)
    read.dcf(file.path(folder, "saira", "DESCRIPTION"))[1L, ]
}

# A source archive from an old commit is the failure that this gate prevents
# (PR-D1 of the pre-v1 audit), so the build must ship the archive it records.
gate_provenance <- function(build, paths, platform, preview) {
    info <- jsonlite::read_json(file.path(build, "build-info.json"))
    if (!identical(info$target, paste0(platform, "-x64"))) {
        stop("The build is for ", info$target, ", and this machine runs ", platform, ".")
    }
    if (isTRUE(info$source$dirty) && !preview) {
        stop("The build has uncommitted source files. A release candidate needs a clean build, or use --preview.")
    }
    if (!identical(info$resolved_electron_version, info$configured_electron)) {
        stop("Electron ", info$resolved_electron_version, " differs from the configured ", info$configured_electron, ".")
    }
    if (length(paths$archive) != 1L) stop("Expected one saira source archive in input/package.")
    if (!identical(gate_sha(paths$archive), info$source_sha256)) {
        stop("The source archive does not match source_sha256 of build-info.json.")
    }
    shipped <- read.dcf(file.path(paths$runtime, "library", "saira", "DESCRIPTION"))[1L, ]
    packed <- gate_archive_description(paths$archive)
    fields <- c("Version", "Packaged")
    if (!identical(shipped[fields], packed[fields])) {
        stop("The bundled saira (", paste(shipped[fields], collapse = ", "),
             ") does not come from the source archive (", paste(packed[fields], collapse = ", "), ").")
    }
    list(info = info, installers = gate_installers(paths$dist))
}

gate_node <- function(platform) {
    node <- desktop_arg("node")
    if (is.null(node) && platform == "linux") node <- file.path(root, "desktop", "_tools", "node-linux", "bin", "node")
    if (is.null(node)) node <- Sys.which("node")
    if (!nzchar(node) && platform == "win") node <- file.path(Sys.getenv("ProgramFiles"), "nodejs", "node.exe")
    if (!file.exists(node)) stop("Node was not found. Pass --node=<node executable>.")
    normalizePath(node, winslash = "/")
}

# The kit holds the E2E sheet. A checkout makes it from the example of the site.
gate_e2e_csv <- function(work) {
    kit <- file.path(root, "desktop", "examples", "ocorrencias-e2e.csv")
    if (file.exists(kit)) return(normalizePath(kit, winslash = "/"))
    csv <- file.path(work, "ocorrencias-e2e.csv")
    desktop_write_e2e_csv(file.path(root, "website", "assets", "exemplo", "ocorrencias-demo.csv"), csv)
    csv
}

gate_command <- function(command, args, log, env = character()) {
    status <- system2(command, args, stdout = log, stderr = log, env = env)
    if (status != 0L) stop("Exit status ", status, ". See ", log)
    "exit status 0"
}

gate_run <- function(build, preview, skip_e2e) {
    platform <- if (.Platform$OS.type == "windows") "win" else "linux"
    build <- normalizePath(build, winslash = "/")
    started <- Sys.time()
    work <- file.path(build, paste0("gate-", format(started, "%Y%m%d-%H%M%S")))
    dir.create(work)
    paths <- gate_paths(build, platform)
    node <- gate_node(platform)
    found <- gate_provenance(build, paths, platform, preview)
    script <- function(name) normalizePath(file.path(root, "desktop", name), winslash = "/")
    log <- function(name) file.path(work, paste0(name, ".log"))
    e2e <- NULL

    steps <- list(
        `shell-check` = function() gate_command(node, c(shQuote(script("shell-check.mjs")),
            shQuote(file.path(paths$project, c("backends/process-tree.js", "log-retention.js", "log-writer.js")))),
            log("shell-check")),
        smoke = function() {
            if (platform == "win") {
                return(gate_command("powershell", c("-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                    shQuote(script("smoke.ps1")), "-BuildDirectory", shQuote(build)), log("smoke")))
            }
            rscript <- Sys.glob(file.path(paths$runtime, "portable-r-*", "bin", "Rscript"))
            if (length(rscript) != 1L) stop("Expected one bundled Rscript.")
            gate_command(rscript, c("--vanilla", shQuote(script("smoke.R")),
                shQuote(paste0("--library=", file.path(paths$runtime, "library")))), log("smoke"),
                env = "RENV_CONFIG_AUTOLOADER_ENABLED=FALSE")
        },
        e2e = function() {
            folder <- file.path(work, "e2e")
            status <- system2(node, shQuote(c(script("e2e.mjs"), paths$exe, gate_e2e_csv(work), folder)),
                stdout = log("e2e"), stderr = log("e2e"))
            # e2e.mjs runs a copy of the unpacked app, about 1 GB.
            unlink(file.path(folder, basename(paths$unpacked)), recursive = TRUE)
            results <- jsonlite::read_json(file.path(folder, "results.json"))
            ok <- vapply(results$results, function(r) isTRUE(r$ok), logical(1))
            e2e <<- list(passed = sum(ok), total = length(ok))
            if (status != 0L || !length(ok) || !all(ok)) {
                stop(sprintf("%d of %d checks passed, exit status %d. See %s", sum(ok), length(ok), status, log("e2e")))
            }
            sprintf("%d of %d checks passed", sum(ok), length(ok))
        }
    )
    if (skip_e2e) steps$e2e <- NULL

    outcome <- lapply(names(steps), function(name) {
        message("[gate] ", name)
        begin <- Sys.time()
        result <- tryCatch(list(ok = TRUE, detail = steps[[name]]()),
            error = function(e) list(ok = FALSE, detail = conditionMessage(e)))
        message("[gate] ", name, ": ", if (result$ok) "PASS" else "FAIL", ", ", result$detail)
        list(name = name, ok = result$ok, detail = result$detail,
            seconds = round(as.numeric(difftime(Sys.time(), begin, units = "secs")), 1))
    })
    passed <- all(vapply(outcome, function(s) s$ok, logical(1)))
    result <- if (!passed) "FAIL" else if (skip_e2e) "INCOMPLETE" else "PASS"
    info <- found$info
    record <- list(
        result = result,
        platform = platform,
        build = basename(build),
        preview = preview,
        source = info$source,
        desktop_version = info$desktop_version,
        saira_package_version = info$saira_package_version,
        source_sha256 = info$source_sha256,
        electron = info$resolved_electron_version,
        installers = found$installers,
        e2e = e2e,
        steps = outcome,
        node = system2(node, "--version", stdout = TRUE),
        gate_R = R.version.string,
        logs = basename(work),
        started_at_utc = format(started, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        finished_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    )
    jsonlite::write_json(record, file.path(build, "gate.json"), auto_unbox = TRUE, pretty = TRUE, null = "null")
    message("[gate] ", result, ": ", file.path(build, "gate.json"))
    if (result != "PASS") quit(status = 1L)
}

# Paths of a package tree that R CMD build keeps, after .Rbuildignore. A
# pattern can match the path or one of its folders.
gate_build_files <- function(paths, ignore) {
    keep <- vapply(paths, function(path) {
        parts <- strsplit(path, "/", fixed = TRUE)[[1L]]
        prefixes <- vapply(seq_along(parts), function(i) paste(parts[seq_len(i)], collapse = "/"), character(1))
        !any(vapply(ignore, function(p) any(grepl(p, prefixes, perl = TRUE, ignore.case = TRUE)), logical(1)))
    }, logical(1))
    paths[keep]
}

# Each file of the archive must equal the file of HEAD, and no file of HEAD
# can be absent. R CMD build adds build/ and fields to DESCRIPTION.
gate_compare_source <- function(archive) {
    folder <- tempfile("saira-gate-source-")
    dir.create(folder)
    on.exit(unlink(folder, recursive = TRUE), add = TRUE)
    head_tar <- file.path(folder, "head.tar")
    desktop_git(root, "archive", "--format=tar", "-o", shQuote(head_tar), "HEAD")
    utils::untar(head_tar, exdir = file.path(folder, "head"))
    utils::untar(archive, exdir = file.path(folder, "archive"))
    head <- file.path(folder, "head")
    packed <- file.path(folder, "archive", "saira")
    ignore <- readLines(file.path(head, ".Rbuildignore"), warn = FALSE)
    # R CMD build also leaves out .Rbuildignore itself.
    ignore <- c(ignore[nzchar(trimws(ignore))], "^\\.Rbuildignore$")
    expected <- setdiff(gate_build_files(list.files(head, recursive = TRUE, all.files = TRUE), ignore), "DESCRIPTION")
    actual <- list.files(packed, recursive = TRUE, all.files = TRUE)
    actual <- setdiff(actual[!startsWith(actual, "build/")], "DESCRIPTION")
    problems <- c(
        sprintf("absent from the archive: %s", setdiff(expected, actual)),
        sprintf("not in HEAD: %s", setdiff(actual, expected))
    )
    both <- intersect(expected, actual)
    changed <- both[tools::md5sum(file.path(head, both)) != tools::md5sum(file.path(packed, both))]
    problems <- c(problems, sprintf("differs from HEAD: %s", changed))
    # R CMD build wraps the long fields again, so the spaces are not compared.
    fields <- function(path) gsub("\\s+", " ", read.dcf(path)[1L, ])
    head_fields <- fields(file.path(head, "DESCRIPTION"))
    packed_fields <- fields(file.path(packed, "DESCRIPTION"))
    same <- names(head_fields) %in% names(packed_fields) &
        head_fields == packed_fields[names(head_fields)]
    problems <- c(problems, sprintf("DESCRIPTION field differs from HEAD: %s", names(head_fields)[!same %in% TRUE]))
    problems
}

gate_verify <- function(builds) {
    if (!file.exists(file.path(root, ".git"))) stop("--verify needs the git checkout of the release.")
    desktop_git(root, "fetch", "--quiet", "origin")
    head <- desktop_git(root, "rev-parse", "HEAD")
    problems <- character()
    fail <- function(...) problems <<- c(problems, paste0(...))
    records <- lapply(names(builds), function(platform) {
        file <- file.path(builds[[platform]], "gate.json")
        if (!file.exists(file)) {
            fail(platform, ": no gate.json. Run desktop/gate.R --build on that machine.")
            return(NULL)
        }
        record <- jsonlite::read_json(file)
        if (!identical(record$platform, platform)) fail(platform, ": the record is for ", record$platform, ".")
        if (!identical(record$result, "PASS")) fail(platform, ": the gate result is ", record$result, ".")
        if (!isFALSE(record$source$dirty) || isTRUE(record$preview)) fail(platform, ": a preview build is not a release candidate.")
        paths <- gate_paths(builds[[platform]], platform)
        installers <- tryCatch(gate_installers(paths$dist), error = function(e) {
            fail(platform, ": ", conditionMessage(e))
            NULL
        })
        if (!is.null(installers) && !identical(installers[order(names(installers))],
                record$installers[order(names(record$installers))])) {
            fail(platform, ": the installers changed after the gate ran.")
        }
        if (length(paths$archive) != 1L || !identical(gate_sha(paths$archive), record$source_sha256)) {
            fail(platform, ": the source archive is absent or differs from the record.")
        } else {
            for (p in gate_compare_source(paths$archive)) fail(platform, ": ", p)
        }
        record
    })
    names(records) <- names(builds)
    present <- Filter(Negate(is.null), records)
    commits <- unique(vapply(present, function(r) r$source$commit, character(1)))
    if (length(commits) > 1L) fail("The builds come from different commits: ", paste(commits, collapse = ", "))
    for (commit in commits) {
        if (!gate_is_ancestor(commit, head)) fail("The build commit ", commit, " is not in HEAD.")
    }
    versions <- unique(vapply(present, function(r) r$desktop_version, character(1)))
    if (length(versions) > 1L) fail("The builds have different versions: ", paste(versions, collapse = ", "))
    release <- desktop_arg("release")
    if (is.null(release) && length(versions) == 1L) {
        branch <- paste0("origin/release/v", sub("-.*$", "", versions))
        release <- if (gate_ref_exists(branch)) branch else "origin/main"
    }
    if (!is.null(release) && !gate_is_ancestor(release, head)) fail("HEAD does not hold the tip of ", release, ".")

    message("HEAD ", head, ", release ref ", release)
    for (platform in names(present)) {
        r <- present[[platform]]
        e2e <- if (is.null(r$e2e)) "none" else paste0(r$e2e$passed, "/", r$e2e$total)
        message(sprintf("%s: %s, commit %s, archive %s, E2E %s", platform, r$build,
            substr(r$source$commit, 1L, 7L), substr(r$source_sha256, 1L, 12L), e2e))
        for (file in names(r$installers)) message("  ", r$installers[[file]], "  ", file)
    }
    if (length(problems)) {
        message("\nDesktop gate FAILED:\n", paste0("- ", problems, collapse = "\n"))
        quit(status = 1L)
    }
    message("\nDesktop gate PASSED.")
}

gate_git_status <- function(...) {
    suppressWarnings(system2("git", c("-C", shQuote(root), ...), stdout = FALSE, stderr = FALSE))
}
gate_ref_exists <- function(ref) identical(gate_git_status("rev-parse", "--verify", "--quiet", shQuote(ref)), 0L)
# TRUE when `commit` holds `ancestor`. An unknown ref gives FALSE.
gate_is_ancestor <- function(ancestor, commit) {
    identical(gate_git_status("merge-base", "--is-ancestor", shQuote(ancestor), shQuote(commit)), 0L)
}

if ("--verify" %in% commandArgs(trailingOnly = TRUE)) {
    builds <- list(linux = desktop_arg("linux"), win = desktop_arg("windows"))
    if (any(vapply(builds, is.null, logical(1)))) stop("Pass --linux=<build> and --windows=<build>.")
    gate_verify(lapply(builds, normalizePath, winslash = "/"))
} else {
    build <- desktop_arg("build")
    if (is.null(build) || !dir.exists(build)) stop("Pass --build=<build folder>.")
    gate_run(build, preview = "--preview" %in% commandArgs(trailingOnly = TRUE),
        skip_e2e = "--skip-e2e" %in% commandArgs(trailingOnly = TRUE))
}
