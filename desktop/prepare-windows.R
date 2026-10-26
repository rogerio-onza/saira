# Produce a Windows source kit locally, including all uncommitted desktop files.
arg <- grep("^--file=", commandArgs(), value = TRUE)
source(file.path(dirname(normalizePath(sub("^--file=", "", arg))), "common.R"))
root <- desktop_root()
if (!requireNamespace("zip", quietly = TRUE)) stop("The zip R package is required.")
# The first pilot shipped an old base because toolchain.dcf named it by hand.
# The kit gets the branch and the commit from git.
git <- function(...) system2("git", c("-C", shQuote(root), ...), stdout = TRUE)
source_fields <- c(`Source-Branch` = git("rev-parse", "--abbrev-ref", "HEAD"),
    `Source-Commit` = git("rev-parse", "HEAD"))
output <- normalizePath(desktop_arg("output",
    file.path(root, "desktop", "_build", "saira-desktop-windows-kit.zip")),
    winslash = "/", mustWork = FALSE)
if (file.exists(output)) stop("Use a new kit filename: ", output)
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
stage <- tempfile("saira-windows-kit-")
kit <- file.path(stage, "saira-desktop")
dir.create(file.path(kit, "desktop"), recursive = TRUE)
files <- c("app", "shell", "common.R", "bootstrap.R", "build.R", "build.ps1",
    "smoke.R", "smoke.ps1", "e2e.mjs", "toolchain.dcf", "README.md")
if (!all(file.copy(file.path(root, "desktop", files), file.path(kit, "desktop"), recursive = TRUE))) {
    stop("Could not prepare desktop source files.")
}
desktop_copy_assets(desktop_shell_assets(root), file.path(kit, "desktop", "shell", "assets"))
write.dcf(as.data.frame(as.list(c(desktop_toolchain(root), source_fields)), check.names = FALSE),
    file.path(kit, "desktop", "toolchain.dcf"), width = 200L)
file.copy(file.path(root, c("DESCRIPTION", "renv.lock")), kit)
# R CMD build reads the working tree, so uncommitted package files go into the kit.
dirty <- git("status", "--porcelain", "--", ".", "':!desktop'")
if (length(dirty)) {
    warning("The kit includes uncommitted package files:\n", paste(dirty, collapse = "\n"), call. = FALSE)
}
archive <- desktop_source_archive(root, file.path(kit, "desktop", "package"))
writeLines(unname(tools::sha256sum(archive)), paste0(archive, ".sha256"))
examples <- file.path(kit, "desktop", "examples")
dir.create(examples)
file.copy(file.path(root, "website", "assets", "exemplo", "ocorrencias-demo.csv"), examples)
desktop_write_e2e_csv(file.path(examples, "ocorrencias-demo.csv"), file.path(examples, "ocorrencias-e2e.csv"))
zip::zipr(output, files = "saira-desktop", root = stage)
message("Windows source kit: ", output)
message("Extract it on a Windows drive, then run desktop/build.ps1.")
