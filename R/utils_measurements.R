# Utils measurements
#
# The MeasurementOrFact extension of the archive. GBIF reads no measurement
# term in the Occurrence core, so a measurement that stays there is not
# published. The extension holds one row per measurement, linked to its
# record by occurrenceID, and a record can have many measurements: area,
# rainfall and camera effort of one site are three rows.

MOF_FILENAME <- "measurementorfact.txt"

# The MeasurementOrFact terms of the DwC catalog, in catalog order.
measurement_terms <- function() {
    catalog <- get_dwc_full_catalog()
    as.character(catalog$term[catalog$class == "MeasurementOrFact"])
}

# With two or more columns mapped to measurementValue, the mapped frame keeps
# one column per source column, as "measurementValue [AREA_HA]". The Preview
# can then show and fix each measurement, and the export reads each one apart.
measurement_value_column <- function(col) {
    paste0("measurementValue [", col, "]")
}

# The source column in each name, NA for a name that is not one of these.
measurement_value_source <- function(names) {
    names <- as.character(names)
    hit <- grepl("^measurementValue \\[.*\\]$", names)
    out <- rep(NA_character_, length(names))
    out[hit] <- sub("^measurementValue \\[(.*)\\]$", "\\1", names[hit])
    out
}

# TRUE for measurementValue and for its per-column names.
is_measurement_value_term <- function(names) {
    names == "measurementValue" | !is.na(measurement_value_source(names))
}

# Unit tokens at the end of a column name, and the measurementUnit of each.
measurement_name_units <- c(
    ha = "ha", m = "m", m2 = "m2", km = "km", km2 = "km2", cm = "cm", mm = "mm",
    kg = "kg", g = "g", mg = "mg", l = "L", ml = "mL", c = "\u00b0C", pct = "%"
)

#' Columns that auto-map suggests for measurementValue
#'
#' Rostrum compares names, and no name like "AREA_HA" resembles
#' measurementValue. A column whose name ends in a unit ("AREA_HA",
#' "peso (kg)") and whose values are numbers is a measurement. A name without
#' a unit ("dia_inicio") is not, so the date parts stay out.
#'
#' @param df Uploaded data frame.
#' @param exclude Columns that already have a term.
#' @return Named character vector: column -> measurementUnit.
#' @noRd
suggest_measurement_columns <- function(df, exclude = character(0)) {
    cols <- setdiff(names(df), exclude)
    pattern <- paste0("[ _.(\\[-](", paste(names(measurement_name_units), collapse = "|"),
                      ")[])]?$")
    token <- tolower(regmatches(cols, regexpr(pattern, cols, ignore.case = TRUE, perl = TRUE)))
    named <- grepl(pattern, cols, ignore.case = TRUE, perl = TRUE)
    cols <- cols[named]
    units <- measurement_name_units[gsub("[^a-z0-9]", "", token)]
    numeric <- vapply(cols, function(col) {
        v <- trimws(as.character(df[[col]]))
        v[is.na(v)] <- ""
        is_measure_column(v)
    }, logical(1))
    stats::setNames(unname(units[numeric]), cols[numeric])
}

#' Move the measurements of an export into the MeasurementOrFact extension
#'
#' Each column mapped to `measurementValue` gives one measurement per record
#' with a value in that column. `measurementType` comes from `specs`, then
#' from the mapped `measurementType` (one column only), then from the column
#' name. The other measurement terms of `df` (unit, method, remarks...) apply
#' to every measurement of the record. `measurementID` is
#' `<occurrenceID>:<column>`, so each one is unique.
#'
#' The values come from `df`, so the corrections of the Preview stay. With two
#' or more columns, `df` holds one `measurement_value_column()` per column.
#'
#' @param df Export data frame (`process_for_export_with_unmapped()` output).
#' @param column Source column of a single `measurementValue` column. NULL for
#'   a fixed value.
#' @param specs Optional named list keyed by column. Each entry is a named list
#'   of measurement terms (`measurementType`, `measurementUnit`,
#'   `measurementMethod`) that win over the values of `df` for that column.
#' @return List with `core` (`df` without the measurement terms) and
#'   `measurements` (the extension rows, `occurrenceID` first). With no
#'   measurement, `core` is `df` unchanged and `measurements` is NULL.
#' @noRd
split_measurements <- function(df, column = NULL, specs = NULL) {
    unchanged <- list(core = df, measurements = NULL)
    sources <- measurement_value_source(names(df))
    wide <- any(!is.na(sources))
    if (!"occurrenceID" %in% names(df) || nrow(df) == 0L ||
        !(wide || "measurementValue" %in% names(df))) {
        return(unchanged)
    }
    value_cols <- if (wide) names(df)[!is.na(sources)] else "measurementValue"
    columns <- if (wide) sources[!is.na(sources)] else as.character(column %||% NA_character_)[1L]
    if (!is.na(columns[1L]) && !nzchar(columns[1L])) columns[1L] <- NA_character_

    terms <- intersect(measurement_terms(), names(df))
    # Every block gets the same columns, so rbind() can join them.
    filled_terms <- intersect(c(terms, unlist(lapply(specs, names))), measurement_terms())
    shared <- setdiff(union("measurementType", filled_terms), c("measurementID", "measurementValue"))
    text <- function(x) {
        x <- trimws(as.character(x))
        x[is.na(x)] <- ""
        x
    }
    ids <- text(df$occurrenceID)

    blocks <- Map(function(value_col, col) {
        value <- text(df[[value_col]])
        rows <- which(nzchar(value))
        spec <- if (!is.na(col)) specs[[col]] else NULL
        out <- data.frame(occurrenceID = ids[rows], stringsAsFactors = FALSE)
        out$measurementID <- if (!wide && "measurementID" %in% terms) {
            text(df$measurementID[rows])
        } else if (!is.na(col)) {
            sprintf("%s:%s", ids[rows], col)
        } else {
            rep("", length(rows))
        }
        for (term in shared) {
            given <- text(spec[[term]] %||% "")
            # A unit or a method can hold for every column, a type cannot.
            from_df <- term %in% names(df) && !(wide && term == "measurementType")
            out[[term]] <- if (nzchar(given)) {
                rep(given, length(rows))
            } else if (from_df) {
                text(df[[term]][rows])
            } else {
                rep("", length(rows))
            }
        }
        if (!is.na(col)) out$measurementType[!nzchar(out$measurementType)] <- col
        out$measurementValue <- value[rows]
        out
    }, value_cols, columns)
    measurements <- do.call(rbind, unname(blocks))
    if (nrow(measurements) == 0L) {
        return(unchanged)
    }

    # Records first, then the measurements of each record in column order.
    measurements <- measurements[order(match(measurements$occurrenceID, ids)), , drop = FALSE]
    lead <- c("occurrenceID", "measurementID", "measurementType", "measurementValue",
              "measurementUnit")
    measurements <- measurements[, c(intersect(lead, names(measurements)),
                                     setdiff(names(measurements), lead)), drop = FALSE]
    rownames(measurements) <- NULL

    core <- df[, setdiff(names(df), c(measurement_terms(), value_cols)), drop = FALSE]
    attr(core, "id_strategy") <- attr(df, "id_strategy")
    list(core = core, measurements = measurements)
}
