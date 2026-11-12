# Draw the desktop art (ADR-214): desktop/shell/assets/icon.ico and icon.png
# (the italic S of the wordmark, white on the indigo of the wordmark) and
# installer-sidebar.bmp (the photo of the start screen). Run in a checkout with
# chromote, png and Chrome. The build only copies the result.
arg <- grep("^--file=", commandArgs(), value = TRUE)
source(file.path(dirname(normalizePath(sub("^--file=", "", arg))), "common.R"))
root <- desktop_root()
for (pkg in c("chromote", "png")) {
    if (!requireNamespace(pkg, quietly = TRUE)) stop("The ", pkg, " R package is required.")
}

# Windows asks for these sizes at 100 % to 200 % scale. The board fixes 16, 32, 48 and 256.
# An ICO entry stops at 256 px. Linux reads the 512 px PNG.
sizes <- c(16L, 20L, 24L, 32L, 40L, 48L, 64L, 256L)
linux_size <- 512L
board <- list(`16` = c(13, 3), `32` = c(25, 6), `48` = c(38, 9), `256` = c(200, 46), `512` = c(400, 92))
font_dir <- file.path(root, "inst", "app", "www", "vendor", "fonts")
font <- file.path(font_dir, "vEFK2_tTDB4M7-auWDN0ahZJW1gewtW_Wg.woff2")
if (!file.exists(font)) stop("Missing the Source Serif 4 italic font: ", font)
photo <- file.path(root, "website", "assets", "img", "landing", "tangara-fastuosa.jpg")
if (!file.exists(photo)) stop("Missing the start screen photo: ", photo)

page <- tempfile("saira-icon-", fileext = ".html")
writeLines(c(
    "<!doctype html><meta charset='utf-8'><style>",
    sprintf("@font-face { font-family: 'S4'; font-style: italic; font-weight: 600; src: url('file://%s'); }", font),
    "html, body { margin: 0; background: transparent; }",
    ".icon { box-sizing: border-box; display: flex; align-items: center; justify-content: center;",
    "  background: #2833ac; color: #ffffff; font: italic 600 10px/1 'S4'; }",
    "</style><div class='icon' id='icon'><span>S</span></div>"
), page)

b <- chromote::ChromoteSession$new(width = 600, height = 600)
on.exit(b$close(), add = TRUE)
invisible(b$Emulation$setDeviceMetricsOverride(width = 600, height = 600, deviceScaleFactor = 1, mobile = FALSE))
invisible(b$Emulation$setDefaultBackgroundColorOverride(color = list(r = 0, g = 0, b = 0, a = 0)))

open_page <- function(file, fonts) {
    invisible(b$Page$navigate(paste0("file://", file)))
    Sys.sleep(1)
    loaded <- b$Runtime$evaluate(sprintf(
        "Promise.all(%s.map((f) => document.fonts.load(f))).then((r) => r.every((f) => f.length > 0))",
        jsonlite::toJSON(fonts)), awaitPromise = TRUE)
    if (!isTRUE(loaded$result$value)) stop("Chrome did not load the fonts of ", basename(file), ".")
}

shot <- function(width, height, file) {
    data <- b$Page$captureScreenshot(format = "png",
        clip = list(x = 0, y = 0, width = width, height = height, scale = 1))$data
    writeBin(jsonlite::base64_dec(data), file)
    file
}

open_page(page, "italic 600 10px 'S4'")
pngs <- vapply(c(sizes, linux_size), function(s) {
    spec <- board[[as.character(s)]] %||% c(round(s * 0.78), round(s * 0.18))
    invisible(b$Runtime$evaluate(sprintf(
        "var i = document.getElementById('icon'); i.style.width = i.style.height = '%dpx';
         i.style.fontSize = '%gpx'; i.style.borderRadius = '%gpx'; i.querySelector('span').style.transform =
         'translateY(%gpx)';", s, spec[1], spec[2], -0.023 * s)))
    shot(s, s, tempfile(sprintf("icon-%d-", s), fileext = ".png"))
}, "")
names(pngs) <- c(sizes, linux_size)

# ICO with one PNG per size (Windows Vista and later read PNG entries).
assets <- file.path(root, "desktop", "shell", "assets")
output <- file.path(assets, "icon.ico")
blobs <- lapply(pngs[as.character(sizes)], function(f) readBin(f, "raw", file.size(f)))
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
stopifnot(file.copy(pngs[[as.character(linux_size)]], file.path(assets, "icon.png"), overwrite = TRUE))
message("Icon: ", output, " (", paste(sizes, collapse = ", "), " px) and icon.png (", linux_size, " px)")

# The NSIS installer and uninstaller show a 164 x 314 BMP on the first and last page.
sidebar <- tempfile("saira-sidebar-", fileext = ".html")
writeLines(c(
    "<!doctype html><meta charset='utf-8'>",
    sprintf("<link rel='stylesheet' href='file://%s'>", file.path(font_dir, "source-fonts.css")),
    "<style>",
    "html, body { margin: 0; background: #1c1c26; }",
    ".side { position: relative; width: 164px; height: 314px; overflow: hidden; }",
    "img { display: block; width: 100%; height: 100%; object-fit: cover; object-position: 50% 28%; }",
    ".cap { position: absolute; left: 0; right: 0; bottom: 0; padding: 12px 12px 10px;",
    "  background: rgba(18, 20, 27, 0.78); color: #ffffff; }",
    ".mark { font: italic 600 32px/1 'Source Serif 4'; }",
    ".credit { margin-top: 6px; font: 400 10px/1.35 'IBM Plex Sans'; opacity: 0.85; }",
    "</style>",
    sprintf("<div class='side'><img src='file://%s' alt=''>", photo),
    "<div class='cap'><div class='mark'>Saíra</div>",
    "<div class='credit'>Renato Bandeira<br>CC BY 4.0</div></div></div>"
), sidebar, useBytes = TRUE)
open_page(sidebar, c("italic 600 32px 'Source Serif 4'", "400 10px 'IBM Plex Sans'"))
pixels <- png::readPNG(shot(164L, 314L, tempfile("sidebar-", fileext = ".png")))

# 24-bit BMP, rows bottom up in BGR order. 164 * 3 bytes is a multiple of 4, so no row padding.
write_bmp <- function(img, file) {
    h <- dim(img)[1L]
    w <- dim(img)[2L]
    rgb <- round(img[, , 1:3] * 255)
    rows <- lapply(rev(seq_len(h)), function(y) as.raw(t(rgb[y, , 3:1])))
    body <- do.call(c, rows)
    con <- file(file, "wb")
    on.exit(close(con))
    writeBin(charToRaw("BM"), con)
    writeBin(c(54L + length(body), 0L, 54L, 40L, w, h), con, size = 4L, endian = "little")
    writeBin(c(1L, 24L), con, size = 2L, endian = "little")
    writeBin(c(0L, length(body), 2835L, 2835L, 0L, 0L), con, size = 4L, endian = "little")
    writeBin(body, con)
}
bmp <- file.path(assets, "installer-sidebar.bmp")
write_bmp(pixels, bmp)
message("Installer sidebar: ", bmp)

preview <- desktop_arg("preview")
if (!is.null(preview)) {
    dir.create(preview, recursive = TRUE, showWarnings = FALSE)
    stopifnot(all(file.copy(pngs, file.path(preview, sprintf("icon-%s.png", names(pngs))), overwrite = TRUE)))
    message("PNG files: ", normalizePath(preview))
}
