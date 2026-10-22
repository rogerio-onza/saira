# Title: Oceanic islands for the establishmentMeans assistant
# Author: Rogerio Nunes Oliveira
#
# The Horus list is per species, but establishmentMeans is per record. For a
# native that is invasive outside its natural range (the coati on Fernando de
# Noronha), only some records are introduced. No bundled source gives the
# natural range per state: the Fauna do Brasil marks every state where the
# species occurs as native, including the states it was introduced to.
#
# Brazil's oceanic islands are the one case the app can decide with no range
# data: none of the list's non-marine translocated natives is native to them
# (ADR-143). Each archipelago is far from the coast, so a bounding box is
# exact enough and no polygon file is needed.

.oceanic_island_boxes <- data.frame(
    name = c(
        "Fernando de Noronha",
        "Atol das Rocas",
        "Trindade e Martim Vaz",
        "S\u00e3o Pedro e S\u00e3o Paulo"
    ),
    lat_min = c(-3.98, -3.92, -20.60, 0.85),
    lat_max = c(-3.78, -3.82, -20.40, 0.96),
    lon_min = c(-32.55, -33.86, -29.40, -29.40),
    lon_max = c(-32.33, -33.76, -28.80, -29.30),
    stringsAsFactors = FALSE
)

# Island name for each point, or NA. Coordinates arrive as the raw column
# values, so decimal commas are accepted and anything else that does not parse
# is NA.
oceanic_island_for <- function(lat, lon) {
    n <- length(lat)
    out <- rep(NA_character_, n)
    if (n == 0L || length(lon) != n) {
        return(out)
    }
    lat_num <- as_coord_numeric(lat)$num
    lon_num <- as_coord_numeric(lon)$num
    boxes <- .oceanic_island_boxes
    for (i in seq_len(nrow(boxes))) {
        inside <- !is.na(lat_num) & !is.na(lon_num) &
            lat_num >= boxes$lat_min[[i]] & lat_num <= boxes$lat_max[[i]] &
            lon_num >= boxes$lon_min[[i]] & lon_num <= boxes$lon_max[[i]]
        out[inside] <- boxes$name[[i]]
    }
    out
}

# TRUE for taxa whose island records are outside the natural range: the list's
# translocated natives, less the marine ones, which can live in the waters
# around the islands.
island_rule_applies <- function(species_names) {
    if (length(species_names) == 0L) {
        return(logical(0))
    }
    info <- invasive_info_for(species_names)
    reason <- normalize_for_matching(info$introduction_reason)
    marine <- !is.na(reason) & grepl("especies marinhas", reason, fixed = TRUE)
    !is.na(info$origin_class) & info$origin_class == "translocated_native" & !marine
}

# Island name for each record the island rule covers, NA for all others.
establishment_island_rows <- function(species_values, lat, lon) {
    n <- length(species_values)
    out <- rep(NA_character_, n)
    if (n == 0L || length(lat) != n || length(lon) != n) {
        return(out)
    }
    island <- oceanic_island_for(lat, lon)
    on_island <- !is.na(island)
    if (!any(on_island)) {
        return(out)
    }
    species <- as.character(species_values)
    applies <- island_rule_applies(unique(species[on_island]))
    covered <- on_island & species %in% unique(species[on_island])[applies]
    out[covered] <- island[covered]
    out
}

# Same, read from the raw data through the coordinate mapping. NULL when the
# coordinates are not mapped, which means "no record is on an island".
establishment_island_rows_for_df <- function(df, map_values, species_values) {
    if (!is.data.frame(df) || length(species_values) != nrow(df)) {
        return(NULL)
    }
    lat_col <- sanitize_map_selection("decimalLatitude", map_values[["decimalLatitude"]])
    lon_col <- sanitize_map_selection("decimalLongitude", map_values[["decimalLongitude"]])
    if (!has_selected_value(lat_col) || !has_selected_value(lon_col)) {
        return(NULL)
    }
    lat_col <- lat_col[[1]]
    lon_col <- lon_col[[1]]
    if (!(lat_col %in% names(df)) || !(lon_col %in% names(df))) {
        return(NULL)
    }
    establishment_island_rows(species_values, df[[lat_col]], df[[lon_col]])
}

# Add n_island (records on an island) and island_names (comma-separated) to the
# assistant's species entries. `island_rows` is NULL when no record can be
# placed, and then every species gets 0.
add_island_counts <- function(entries, species_values, island_rows) {
    entries$n_island <- rep(0L, nrow(entries))
    entries$island_names <- rep("", nrow(entries))
    if (nrow(entries) == 0L || length(island_rows) != length(species_values)) {
        return(entries)
    }
    on_island <- !is.na(island_rows)
    if (!any(on_island)) {
        return(entries)
    }
    keys <- normalize_species_keys(species_values)[on_island]
    islands <- island_rows[on_island]
    for (i in seq_len(nrow(entries))) {
        hit <- keys == entries$key[[i]]
        entries$n_island[[i]] <- sum(hit)
        entries$island_names[[i]] <- paste(sort(unique(islands[hit])), collapse = ", ")
    }
    entries
}
