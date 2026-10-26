# Install build tools into desktop/_tools, without changing the regular R library.
arg <- grep("^--file=", commandArgs(), value = TRUE)
source(file.path(dirname(normalizePath(sub("^--file=", "", arg))), "common.R"))
root <- desktop_root()
if (.Platform$OS.type != "windows") stop("Prepare Windows build tools using Windows R.")
if (getRversion() < "4.5.0") stop("The build tools require R >= 4.5.0.")
options(timeout = max(600, getOption("timeout")), repos = c(CRAN = "https://cloud.r-project.org"))
lib <- desktop_library(root)
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
desktop_use_library(root)
pin <- desktop_toolchain(root)
stamp <- file.path(dirname(lib), "shinyelectron-ref.txt")
installed <- file.path(lib, "shinyelectron", "DESCRIPTION")
if (file.exists(stamp) && file.exists(installed) &&
    identical(readLines(stamp, warn = FALSE), pin[["Shinyelectron-Ref"]])) {
    message("Pinned shinyelectron already prepared: ", pin[["Shinyelectron-Ref"]])
    quit(status = 0L)
}
archive <- tempfile(fileext = ".tar.gz")
unpacked <- tempfile("shinyelectron-source-")
dir.create(unpacked)
url <- paste0("https://codeload.github.com/coatless-rpkg/shinyelectron/tar.gz/",
              pin[["Shinyelectron-Ref"]])
download.file(url, archive, mode = "wb")
if (!identical(unname(tools::sha256sum(archive)), pin[["Shinyelectron-SHA256"]])) {
    stop("Downloaded shinyelectron source failed its SHA-256 check.")
}
utils::untar(archive, exdir = unpacked)
package <- list.dirs(unpacked, full.names = TRUE, recursive = FALSE)
description <- read.dcf(file.path(package, "DESCRIPTION"))
# Only renv is needed from Suggests for native dependency detection.
imports <- trimws(strsplit(description[1L, "Imports"], ",")[[1L]])
imports <- sub(" *\\(.*$", "", imports)
base_packages <- rownames(installed.packages(priority = c("base", "recommended")))
deps <- setdiff(unique(c(imports, "renv")), base_packages)
install.packages(deps, lib = lib, type = "binary", dependencies = NA)
install.packages(package, repos = NULL, type = "source", lib = lib)
if (!requireNamespace("shinyelectron", quietly = TRUE, lib.loc = lib)) {
    stop("Pinned shinyelectron did not install successfully.")
}
writeLines(pin[["Shinyelectron-Ref"]], stamp)
message("Local Windows build tools prepared.")
