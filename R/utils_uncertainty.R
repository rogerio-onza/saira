# Utils uncertainty

# Half the length of the equator: no point is farther from another one.
max_uncertainty_m <- 20037509

# "1.000" is 1000 in a Brazilian sheet and 1 to the export, so it is not valid,
# unless the column writes decimals with a dot (uncertainty_decimal_dot).
is_valid_uncertainty <- function(x, decimal_dot = FALSE) {
    x <- trimws(as.character(x))
    num <- suppressWarnings(as.numeric(x))
    grepl("^[0-9]+(\\.[0-9]+)?$", x) & (decimal_dot | !grepl("^[0-9]{1,3}\\.[0-9]{3}$", x)) &
        !is.na(num) & num > 0 & num <= max_uncertainty_m
}

# A number of meters from "30 m", "aprox. 100 m", "1.000" (a thousands dot),
# "1,5" or "2 km", or NA when no valid number comes out. With `decimal_dot`,
# "4.551" stays 4.551.
suggest_uncertainty <- function(values, decimal_dot = FALSE) {
    v <- tolower(trimws(as.character(values)))
    v[is.na(v)] <- ""
    km <- grepl("[0-9 ]km$", v)
    v <- sub("^(aprox\\.?|approx\\.?|ca\\.?|cerca de|~|\\+/-|\u00b1)\\s*", "", v)
    v <- trimws(sub("\\s*(km|m|metros|meters|metres)$", "", v))
    thousands <- !decimal_dot & grepl("^[0-9]{1,3}(\\.[0-9]{3})+$", v)
    v[thousands] <- gsub(".", "", v[thousands], fixed = TRUE)
    v <- sub(",", ".", v, fixed = TRUE)
    num <- suppressWarnings(as.numeric(v))
    num[km] <- num[km] * 1000
    out <- format(num, scientific = FALSE, trim = TRUE, drop0trailing = TRUE)
    out[!is_valid_uncertainty(out, decimal_dot)] <- NA_character_
    out
}

# "4.551" or "4.551 m" can be 4.551 m (a GPS accuracy from ODK or KoboToolbox)
# or 4551 m. A value in km is not in this group.
ambiguous_uncertainty <- function(values) {
    v <- tolower(trimws(as.character(values)))
    v[is.na(v)] <- ""
    v <- sub("^(aprox\\.?|approx\\.?|ca\\.?|cerca de|~|\\+/-|\u00b1)\\s*", "", v)
    v <- trimws(sub("\\s*(m|metros|meters|metres)$", "", v))
    grepl("^[0-9]{1,3}\\.[0-9]{3}$", v)
}

# A column with a dot that is no thousands dot, as "12.3" or "7.25", writes
# decimals with a dot. Its "4.551" is 4.551 m, a GPS accuracy (ADR-210).
uncertainty_decimal_dot <- function(values) {
    v <- trimws(as.character(values))
    any(grepl("^[0-9]+\\.[0-9]+$", v) & !grepl("^[0-9]{1,3}\\.[0-9]{3}$", v), na.rm = TRUE)
}
