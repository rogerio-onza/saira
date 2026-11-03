# Local-only Windows or Linux bundle. No GitHub Actions, releases or upload commands.
arg <- grep("^--file=", commandArgs(), value = TRUE)
source(file.path(dirname(normalizePath(sub("^--file=", "", arg))), "common.R"))
root <- desktop_root()
desktop_use_library(root)
platform <- desktop_arg("platform", desktop_host_platform())
config <- desktop_config(root, platform)
pin <- desktop_toolchain(root)
message("Preview: ", config$app$version, " for ", platform)
origin <- desktop_source_identity(root)
message("Source: ", origin$branch, " @ ", origin$commit, if (origin$dirty) " (uncommitted files)")
invisible(desktop_npm_lock(root))
message("Package DESCRIPTION version: ", read.dcf(file.path(root, "DESCRIPTION"))[1L, "Version"])
if ("--check" %in% commandArgs(trailingOnly = TRUE)) {
    invisible(parse(file.path(root, "desktop", "app", "app.R")))
    message("Configuration and launcher parsed. The bundle build runs on the target system.")
    quit(status = 0L)
}
desktop_check_source(origin, config$app$version, "--allow-dirty" %in% commandArgs(trailingOnly = TRUE))
if (platform != desktop_host_platform()) stop("Build the ", platform, " bundle on ", platform, ".")
stamp <- file.path(dirname(desktop_library(root)), "shinyelectron-ref.txt")
if (!file.exists(stamp) || !identical(readLines(stamp), pin[["Shinyelectron-Ref"]])) {
    stop("Run desktop/bootstrap.R first.")
}
if (!requireNamespace("shinyelectron", quietly = TRUE)) stop("Missing shinyelectron.")
options(timeout = max(600, getOption("timeout")))
builds <- if (platform == "win") Sys.getenv("LOCALAPPDATA") else
    Sys.getenv("XDG_DATA_HOME", path.expand("~/.local/share"))
default <- file.path(builds, "saira-desktop-builds",
    paste0(config$app$version, "-", platform, "-", format(Sys.time(), "%Y%m%d-%H%M%S")))
output <- normalizePath(desktop_arg("output", default), winslash = "/", mustWork = FALSE)
if (dir.exists(output) || file.exists(output)) stop("Use a new output directory: ", output)
dir.create(output, recursive = TRUE)
archive <- desktop_source_archive(root, file.path(output, "input", "package"))
app <- file.path(output, "input", "app")
dir.create(app)
file.copy(file.path(root, "desktop", "app", "app.R"), app)
config$dependencies$r$local_packages <- list(paste0("../package/", basename(archive)))
yaml::write_yaml(config, file.path(app, "_shinyelectron.yml"))
desktop_write_provenance(root, output, archive, config, origin)
Sys.setenv(CSC_IDENTITY_AUTO_DISCOVERY = "false", RENV_CONFIG_AUTOLOADER_ENABLED = "FALSE")
# electron-builder signs with the certificate in WIN_CSC_LINK or CSC_LINK and its
# password in WIN_CSC_KEY_PASSWORD or CSC_KEY_PASSWORD. Without one, the build is unsigned.
sign <- nzchar(Sys.getenv("WIN_CSC_LINK")) || nzchar(Sys.getenv("CSC_LINK"))
message("Code signing: ", if (sign) "on" else "off")
if (platform == "linux") {
    Sys.setenv(PATH = paste(file.path(root, "desktop", "_tools", "node-linux", "bin"), Sys.getenv("PATH"), sep = ":"))
    linux_r <- desktop_linux_r(root, config$dependencies$r$version)
    # install-r.R stops for Linux. The relocated r-builds R takes the place of the portable R.
    utils::assignInNamespace("install_r_portable", function(...) linux_r, "shinyelectron")
    utils::assignInNamespace("r_executable", function(...) {
        Sys.glob(file.path(linux_r, "portable-r-*", "bin", "Rscript"))
    }, "shinyelectron")
}
# export() has no hook between the runtime install and electron-builder. npm
# install is the last step before electron-builder reads package.json, so the
# shell, the prune, the version gate and the BR snapshot run there. On exit, npm
# has installed the packages and electron-builder has not started.
trace("install_npm_dependencies", where = asNamespace("shinyelectron"), print = FALSE,
    tracer = bquote({
        desktop_apply_shell(.(root), output_dir, .(config), .(origin))
        desktop_prune_library(file.path(output_dir, "runtime", "R", "library"))
        desktop_prune_runtime(Sys.glob(file.path(output_dir, "runtime", "R", "portable-r-*")),
            file.path(output_dir, "runtime", "R", "library"))
        if (.(platform) == "linux") {
            desktop_bundle_system_libs(Sys.glob(file.path(output_dir, "runtime", "R", "portable-r-*")),
                file.path(output_dir, "runtime", "R", "library"))
        }
        desktop_check_versions(.(root), file.path(output_dir, "runtime", "R", "library"), .(output))
        desktop_refresh_br_snapshot(file.path(output_dir, "runtime", "R"))
        desktop_use_npm_lock(.(root), output_dir)
    }),
    exit = bquote({
        desktop_check_npm_lock(.(root), output_dir)
        if (.(platform) == "linux") desktop_patch_apprun(.(root), output_dir)
    }))
result <- shinyelectron::export(
    appdir = app,
    destdir = file.path(output, "bundle"),
    app_type = "r-shiny", runtime_strategy = "bundled",
    platform = platform, arch = "x64", sign = sign,
    overwrite = FALSE, run_after = FALSE, open_after = FALSE
)
library <- file.path(output, "bundle", "electron-app", "runtime", "R", "library")
packages <- installed.packages(lib.loc = library, noCache = TRUE)
write.csv(packages[, c("Package", "Version", "Built"), drop = FALSE],
    file.path(output, "bundled-packages.csv"), row.names = FALSE)
project <- file.path(output, "bundle", "electron-app")
metadata <- jsonlite::read_json(file.path(output, "build-info.json"))
metadata$resolved_electron_version <- jsonlite::read_json(
    file.path(project, "node_modules", "electron", "package.json"))$version
metadata$br_snapshot <- jsonlite::read_json(
    file.path(library, "saira", "extdata", "brproviders", "snapshot.json"))
jsonlite::write_json(metadata, file.path(output, "build-info.json"), auto_unbox = TRUE, pretty = TRUE)
file.copy(file.path(project, "package-lock.json"), file.path(output, "node-package-lock.json"))
dist <- file.path(project, "dist")
installers <- list.files(dist, pattern = "[.](exe|AppImage|deb)$", full.names = TRUE)
writeLines(paste0(tools::sha256sum(installers), "  ", basename(installers)), file.path(dist, "SHA256SUMS.txt"))
message("Local installer: ", dist)
