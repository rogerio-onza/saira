# Title: Generate embedded Natural Earth land 10m reference for the Americas
# Purpose: Create inst/extdata/ne_land_10m_americas.rds for offline scale=10 sea validation

ne_land_10m_url <- "https://naciscdn.org/naturalearth/10m/physical/ne_10m_land.zip"
output_path <- file.path("inst", "extdata", "ne_land_10m_americas.rds")

required_pkgs <- c("sf")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, FUN.VALUE = logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0L) {
    stop(
        sprintf("Missing packages for asset generation: %s", paste(missing_pkgs, collapse = ", ")),
        call. = FALSE
    )
}

old_s2 <- sf::sf_use_s2()
on.exit(sf::sf_use_s2(old_s2), add = TRUE)
sf::sf_use_s2(FALSE)

dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

tmp_dir <- tempfile("ne_land_10m_americas_")
dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(tmp_dir, recursive = TRUE, force = TRUE), add = TRUE)

zip_override <- Sys.getenv("NE_LAND_10M_ZIP", "")
zip_path <- if (nzchar(zip_override) && file.exists(zip_override)) {
    normalizePath(zip_override, mustWork = TRUE)
} else {
    dest <- file.path(tmp_dir, basename(ne_land_10m_url))
    message("Downloading Natural Earth land 10m source...")
    utils::download.file(ne_land_10m_url, dest, mode = "wb", quiet = FALSE)
    dest
}
utils::unzip(zip_path, exdir = tmp_dir)

land_path <- list.files(tmp_dir, pattern = "^ne_10m_land\\.shp$", recursive = TRUE, full.names = TRUE)
if (length(land_path) != 1L) {
    stop("Could not locate ne_10m_land.shp after download.", call. = FALSE)
}

message("Reading land 10m physical geometry...")
land <- sf::st_read(land_path, quiet = TRUE)
land <- sf::st_make_valid(land)

mask_boxes <- data.frame(
    xmin = c(-179.5, 167),
    xmax = c(-20, 180),
    ymin = c(-60, 45),
    ymax = c(85, 75)
)

make_box <- function(xmin, xmax, ymin, ymax) {
    sf::st_polygon(list(matrix(
        c(
            xmin, ymin,
            xmax, ymin,
            xmax, ymax,
            xmin, ymax,
            xmin, ymin
        ),
        ncol = 2,
        byrow = TRUE
    )))
}

americas_mask_sf <- sf::st_sf(
    id = seq_len(nrow(mask_boxes)),
    geometry = sf::st_sfc(
        lapply(
            seq_len(nrow(mask_boxes)),
            function(i) make_box(
                mask_boxes$xmin[[i]],
                mask_boxes$xmax[[i]],
                mask_boxes$ymin[[i]],
                mask_boxes$ymax[[i]]
            )
        ),
        crs = 4326
    )
)
americas_mask <- suppressWarnings(sf::st_union(sf::st_geometry(americas_mask_sf)))
americas_mask_sf <- sf::st_sf(id = 1L, geometry = sf::st_sfc(americas_mask, crs = 4326))

message("Cropping land geometry to the Americas mask...")
land_crop <- suppressWarnings(sf::st_crop(land, sf::st_bbox(americas_mask_sf)))
land_americas <- suppressWarnings(sf::st_intersection(land_crop, americas_mask_sf))
land_americas <- sf::st_make_valid(land_americas)

message("Dissolving the Americas land mask...")
dissolved <- suppressWarnings(sf::st_union(sf::st_geometry(land_americas)))
if (inherits(dissolved, "sfc_GEOMETRY") || inherits(dissolved, "sfc_GEOMETRYCOLLECTION")) {
    dissolved <- sf::st_collection_extract(dissolved, "POLYGON")
    dissolved <- sf::st_union(dissolved)
}

ref <- sf::st_sf(id = 1L, geometry = sf::st_sfc(dissolved, crs = sf::st_crs(land_americas)))

message("Building buffered Americas coverage geometry...")
coverage_ref <- suppressWarnings(sf::st_buffer(ref, dist = 10))

coords <- sf::st_coordinates(coverage_ref)
boxes <- list()

coords_west <- coords[coords[, "X"] <= 0, , drop = FALSE]
if (nrow(coords_west) > 0L) {
    boxes[[length(boxes) + 1L]] <- data.frame(
        xmin = min(coords_west[, "X"], na.rm = TRUE),
        xmax = max(coords_west[, "X"], na.rm = TRUE),
        ymin = min(coords_west[, "Y"], na.rm = TRUE),
        ymax = max(coords_west[, "Y"], na.rm = TRUE)
    )
}

coords_east <- coords[coords[, "X"] > 0, , drop = FALSE]
if (nrow(coords_east) > 0L) {
    boxes[[length(boxes) + 1L]] <- data.frame(
        xmin = min(coords_east[, "X"], na.rm = TRUE),
        xmax = max(coords_east[, "X"], na.rm = TRUE),
        ymin = min(coords_east[, "Y"], na.rm = TRUE),
        ymax = max(coords_east[, "Y"], na.rm = TRUE)
    )
}

coverage_boxes <- if (length(boxes) == 0L) {
    data.frame(xmin = numeric(0), xmax = numeric(0), ymin = numeric(0), ymax = numeric(0))
} else {
    do.call(rbind, boxes)
}

asset <- list(
    ref = ref,
    coverage_ref = coverage_ref,
    coverage_boxes = coverage_boxes,
    meta = list(
        source_url = ne_land_10m_url,
        source_layer = "Natural Earth land 10m physical",
        generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
    )
)

saveRDS(asset, output_path, compress = "xz")
message(sprintf("Saved embedded reference to %s", output_path))
