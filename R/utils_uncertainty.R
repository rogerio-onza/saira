# Utils uncertainty

# Half the length of the equator: no point is farther from another one.
max_uncertainty_m <- 20037509

# "1.000" is 1000 in a Brazilian sheet and 1 to the export, so it is not valid.
is_valid_uncertainty <- function(x) {
    x <- trimws(as.character(x))
    num <- suppressWarnings(as.numeric(x))
    grepl("^[0-9]+(\\.[0-9]+)?$", x) & !grepl("^[0-9]{1,3}\\.[0-9]{3}$", x) &
        !is.na(num) & num > 0 & num <= max_uncertainty_m
}

# A number of meters from "30 m", "aprox. 100 m", "1.000" (a thousands dot),
# "1,5" or "2 km", or NA when no valid number comes out.
suggest_uncertainty <- function(values) {
    v <- tolower(trimws(as.character(values)))
    v[is.na(v)] <- ""
    km <- grepl("[0-9 ]km$", v)
    v <- sub("^(aprox\\.?|approx\\.?|ca\\.?|cerca de|~|\\+/-|\u00b1)\\s*", "", v)
    v <- trimws(sub("\\s*(km|m|metros|meters|metres)$", "", v))
    thousands <- grepl("^[0-9]{1,3}(\\.[0-9]{3})+$", v)
    v[thousands] <- gsub(".", "", v[thousands], fixed = TRUE)
    v <- sub(",", ".", v, fixed = TRUE)
    num <- suppressWarnings(as.numeric(v))
    num[km] <- num[km] * 1000
    out <- format(num, scientific = FALSE, trim = TRUE, drop0trailing = TRUE)
    out[!is_valid_uncertainty(out)] <- NA_character_
    out
}

