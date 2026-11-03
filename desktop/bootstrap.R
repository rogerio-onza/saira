# Install build tools into desktop/_tools, without changing the regular R library.
arg <- grep("^--file=", commandArgs(), value = TRUE)
source(file.path(dirname(normalizePath(sub("^--file=", "", arg))), "common.R"))
root <- desktop_root()
platform <- desktop_host_platform()
if (platform == "other") stop("Prepare the build tools on Windows or Linux.")
if (getRversion() < "4.5.0") stop("The build tools require R >= 4.5.0.")
# The __linux__ path serves Ubuntu 24.04 binaries. Other Linux hosts compile from source.
options(timeout = max(600, getOption("timeout")), repos = c(CRAN = if (platform == "win")
    "https://cloud.r-project.org" else "https://packagemanager.posit.co/cran/__linux__/noble/latest"))
lib <- desktop_library(root)
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
desktop_use_library(root)
pin <- desktop_toolchain(root)
# On Windows the build uses the installed Node. On Linux it uses the pinned one.
node <- file.path(dirname(lib), "node-linux")
if (platform == "linux" && !file.exists(file.path(node, "bin", "node"))) {
    tarball <- tempfile(fileext = ".tar.xz")
    download.file(sprintf("https://nodejs.org/dist/v%1$s/node-v%1$s-linux-x64.tar.xz",
        pin[["Node-Linux-Version"]]), tarball, mode = "wb")
    if (!identical(unname(tools::sha256sum(tarball)), pin[["Node-Linux-SHA256"]])) {
        stop("Downloaded Node.js failed its SHA-256 check.")
    }
    utils::untar(tarball, exdir = dirname(lib))
    file.rename(file.path(dirname(lib), sprintf("node-v%s-linux-x64", pin[["Node-Linux-Version"]])), node)
}
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
install.packages(deps, lib = lib, type = if (platform == "win") "binary" else "source", dependencies = NA)
install.packages(package, repos = NULL, type = "source", lib = lib)
if (!requireNamespace("shinyelectron", quietly = TRUE, lib.loc = lib)) {
    stop("Pinned shinyelectron did not install successfully.")
}
writeLines(pin[["Shinyelectron-Ref"]], stamp)
message("Local build tools prepared.")
