# Draw desktop/shell/assets/icon.ico (board Icon-B): the italic S of the
# wordmark on the cool gray of the app. Run in a checkout with chromote and
# Chrome. The build only copies the result.
arg <- grep("^--file=", commandArgs(), value = TRUE)
source(file.path(dirname(normalizePath(sub("^--file=", "", arg))), "common.R"))
root <- desktop_root()
if (!requireNamespace("chromote", quietly = TRUE)) stop("The chromote R package is required.")

# Windows asks for these sizes at 100 % to 200 % scale. The board fixes 16, 32, 48 and 256.
sizes <- c(16L, 20L, 24L, 32L, 40L, 48L, 64L, 256L)
board <- list(`16` = c(13, 3), `32` = c(25, 6), `48` = c(38, 9), `256` = c(200, 46))
font <- file.path(root, "inst", "app", "www", "vendor", "fonts", "vEFK2_tTDB4M7-auWDN0ahZJW1gewtW_Wg.woff2")
if (!file.exists(font)) stop("Missing the Source Serif 4 italic font: ", font)

page <- tempfile("saira-icon-", fileext = ".html")
writeLines(c(
    "<!doctype html><meta charset='utf-8'><style>",
    sprintf("@font-face { font-family: 'S4'; font-style: italic; font-weight: 600; src: url('file://%s'); }", font),
    "html, body { margin: 0; background: transparent; }",
    ".icon { box-sizing: border-box; display: flex; align-items: center; justify-content: center;",
    "  background: #f5f6f8; border: 1px solid #d3d8e0; color: #2833ac;",
    "  font: italic 600 10px/1 'S4'; }",
    "</style><div class='icon' id='icon'><span>S</span></div>"
), page)

b <- chromote::ChromoteSession$new(width = 300, height = 300)
on.exit(b$close(), add = TRUE)
invisible(b$Emulation$setDeviceMetricsOverride(width = 300, height = 300, deviceScaleFactor = 1, mobile = FALSE))
invisible(b$Emulation$setDefaultBackgroundColorOverride(color = list(r = 0, g = 0, b = 0, a = 0)))
invisible(b$Page$navigate(paste0("file://", page)))
Sys.sleep(1)
loaded <- b$Runtime$evaluate("document.fonts.load(\"italic 600 10px 'S4'\").then((f) => f.length > 0)",
    awaitPromise = TRUE)
if (!isTRUE(loaded$result$value)) stop("Chrome did not load the Source Serif 4 italic font.")

pngs <- vapply(sizes, function(s) {
    spec <- board[[as.character(s)]] %||% c(round(s * 0.78), round(s * 0.18))
    invisible(b$Runtime$evaluate(sprintf(
        "var i = document.getElementById('icon'); i.style.width = i.style.height = '%dpx';
         i.style.fontSize = '%gpx'; i.style.borderRadius = '%gpx'; i.querySelector('span').style.transform =
         'translateY(%gpx)';", s, spec[1], spec[2], -0.023 * s)))
    shot <- b$Page$captureScreenshot(format = "png",
        clip = list(x = 0, y = 0, width = s, height = s, scale = 1))
    file <- tempfile(sprintf("icon-%d-", s), fileext = ".png")
    writeBin(jsonlite::base64_dec(shot$data), file)
    file
}, "")

# ICO with one PNG per size (Windows Vista and later read PNG entries).
output <- file.path(root, "desktop", "shell", "assets", "icon.ico")
blobs <- lapply(pngs, function(f) readBin(f, "raw", file.size(f)))
con <- file(output, "wb")
writeBin(c(0L, 1L, length(blobs)), con, size = 2L, endian = "little")
offset <- 6L + 16L * length(blobs)
for (i in seq_along(blobs)) {
    side <- sizes[[i]] %% 256L
    writeBin(as.raw(c(side, side, 0L, 0L)), con)
    writeBin(c(1L, 32L), con, size = 2L, endian = "little")
    writeBin(c(length(blobs[[i]]), offset), con, size = 4L, endian = "little")
    offset <- offset + length(blobs[[i]])
}
for (blob in blobs) writeBin(blob, con)
close(con)
# Linux reads PNG, not ICO.
stopifnot(file.copy(pngs[[match(256L, sizes)]], file.path(dirname(output), "icon.png"), overwrite = TRUE))
message("Icon: ", output, " (", paste(sizes, collapse = ", "), " px) and icon.png (256 px)")
preview <- desktop_arg("preview")
if (!is.null(preview)) {
    dir.create(preview, recursive = TRUE, showWarnings = FALSE)
    stopifnot(all(file.copy(pngs, file.path(preview, sprintf("icon-%d.png", sizes)), overwrite = TRUE)))
    message("PNG files: ", normalizePath(preview))
}
