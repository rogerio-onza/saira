# Local-only Windows bundle. No GitHub Actions, releases or upload commands.
arg <- grep("^--file=", commandArgs(), value = TRUE)
source(file.path(dirname(normalizePath(sub("^--file=", "", arg))), "common.R"))
root <- desktop_root()
desktop_use_library(root)
config <- desktop_config(root)
pin <- desktop_toolchain(root)
message("Preview: ", config$app$version)
# prepare-windows.R writes the source fields into the kit copy of toolchain.dcf.
message("Source base: ", pin[["Source-Branch"]] %||% "checkout", " @ ", pin[["Source-Commit"]] %||% "HEAD")
message("Package DESCRIPTION version: ", read.dcf(file.path(root, "DESCRIPTION"))[1L, "Version"])
if ("--check" %in% commandArgs(trailingOnly = TRUE)) {
    invisible(parse(file.path(root, "desktop", "app", "app.R")))
    message("Configuration and launcher parsed. Bundle build requires native Windows R.")
    quit(status = 0L)
}
if (.Platform$OS.type != "windows") stop("Build this bundle with Windows R, not WSL R.")
stamp <- file.path(dirname(desktop_library(root)), "shinyelectron-ref.txt")
if (!file.exists(stamp) || !identical(readLines(stamp), pin[["Shinyelectron-Ref"]])) {
    stop("Run desktop/bootstrap.R with Windows R first.")
}
if (!requireNamespace("shinyelectron", quietly = TRUE)) stop("Missing shinyelectron.")
options(timeout = max(600, getOption("timeout")))
default <- file.path(Sys.getenv("LOCALAPPDATA"), "saira-desktop-builds",
    paste0(config$app$version, "-", format(Sys.time(), "%Y%m%d-%H%M%S")))
output <- normalizePath(desktop_arg("output", default), winslash = "/", mustWork = FALSE)
if (dir.exists(output) || file.exists(output)) stop("Use a new output directory: ", output)
dir.create(output, recursive = TRUE)
archive <- desktop_source_archive(root, file.path(output, "input", "package"))
app <- file.path(output, "input", "app")
dir.create(app)
file.copy(file.path(root, "desktop", "app", "app.R"), app)
config$dependencies$r$local_packages <- list(paste0("../package/", basename(archive)))
yaml::write_yaml(config, file.path(app, "_shinyelectron.yml"))
desktop_write_provenance(root, output, archive, config)
Sys.setenv(CSC_IDENTITY_AUTO_DISCOVERY = "false", RENV_CONFIG_AUTOLOADER_ENABLED = "FALSE")
# export() has no hook between the runtime install and electron-builder. npm
# install is the last step before electron-builder reads package.json, so the
# shell, the prune and the version gate run there.
trace("install_npm_dependencies", where = asNamespace("shinyelectron"), print = FALSE,
    tracer = bquote({
        desktop_apply_shell(.(root), output_dir, .(config))
        desktop_prune_library(file.path(output_dir, "runtime", "R", "library"))
        desktop_check_versions(.(root), file.path(output_dir, "runtime", "R", "library"), .(output))
    }))
result <- shinyelectron::export(
    appdir = app,
    destdir = file.path(output, "bundle"),
    app_type = "r-shiny", runtime_strategy = "bundled",
    platform = "win", arch = "x64", sign = FALSE,
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
jsonlite::write_json(metadata, file.path(output, "build-info.json"), auto_unbox = TRUE, pretty = TRUE)
file.copy(file.path(project, "package-lock.json"), file.path(output, "node-package-lock.json"))
message("Local installer: ", file.path(output, "bundle", "electron-app", "dist"))
