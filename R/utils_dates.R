# Utils dates

parse_year_to_number <- function(x) {
    if (is_blank_value(x)) {
        return(NA_integer_)
    }

    value <- trimws(as.character(x))
    if (grepl("^\\d{4}$", value)) {
        return(as.integer(value))
    }

    year_match <- regmatches(value, regexpr("\\d{4}", value, perl = TRUE))
    if (length(year_match) == 0 || identical(year_match, "")) {
        return(NA_integer_)
    }

    as.integer(year_match)
}

#' Vectorized companion to parse_year_to_number()
#'
#' Same extraction, resolved once per distinct value instead of once per row.
#' Years repeat by construction, so the distinct count stays small even on a
#' free-text date column.
#'
#' @param x Character vector of raw year values
#' @return Integer vector of years, NA where no 4-digit run is present, same
#'   length as the input
#' @noRd
parse_year_to_number_vec <- function(x) {
    values <- as.character(x)
    n <- length(values)
    out <- rep(NA_integer_, n)
    if (n == 0L) {
        return(out)
    }

    trimmed <- trimws(values)
    candidates <- !(is.na(values) | !nzchar(trimmed))
    if (!any(candidates)) {
        return(out)
    }

    uniq <- unique(trimmed[candidates])
    resolved <- rep(NA_integer_, length(uniq))

    exact <- grepl("^\\d{4}$", uniq)
    resolved[exact] <- as.integer(uniq[exact])

    rest <- which(!exact)
    if (length(rest) > 0L) {
        # Deliberately NOT regmatches(): it DROPS non-matching elements and so
        # silently shortens the vector, which would misalign every value after
        # the first miss. The match position is used directly instead.
        m <- regexpr("\\d{4}", uniq[rest], perl = TRUE)
        hit <- m > 0L
        if (any(hit)) {
            starts <- m[hit]
            resolved[rest[hit]] <- as.integer(
                substring(uniq[rest][hit], starts, starts + 3L)
            )
        }
    }

    out[candidates] <- resolved[match(trimmed[candidates], uniq)]
    out
}

detect_eventdate_roles <- function(col_names) {
    normalized_names <- normalize_for_matching(col_names)
    used_env <- new.env(parent = emptyenv())
    used_env$used <- rep(FALSE, length(normalized_names))

    start_mask <- grepl("\\b(start|begin|initial|inicio|from)\\b", normalized_names)
    end_mask <- grepl("\\b(end|final|fim|to)\\b", normalized_names)
    month_mask <- grepl("\\b(month|mo|mes)\\b", normalized_names)
    year_mask <- grepl("\\b(year|yr|ano)\\b", normalized_names)

    pick_first <- function(mask) {
        idx <- which(mask & !used_env$used)
        if (length(idx) == 0) {
            return(NA_integer_)
        }
        used_env$used[[idx[1]]] <- TRUE
        idx[1]
    }

    start_month <- pick_first(start_mask & month_mask)
    start_year <- pick_first(start_mask & year_mask)
    end_month <- pick_first(end_mask & month_mask)
    end_year <- pick_first(end_mask & year_mask)

    if (is.na(start_month)) start_month <- pick_first(month_mask)
    if (is.na(start_year)) start_year <- pick_first(year_mask)
    if (is.na(end_month)) end_month <- pick_first(month_mask)
    if (is.na(end_year)) end_year <- pick_first(year_mask)

    used_fallback <- FALSE
    if (anyNA(c(start_month, start_year, end_month, end_year)) && length(col_names) >= 4) {
        start_month <- 1L
        start_year <- 2L
        end_month <- 3L
        end_year <- 4L
        used_fallback <- TRUE
    }

    list(
        start_month = start_month,
        start_year = start_year,
        end_month = end_month,
        end_year = end_year,
        used_fallback = used_fallback
    )
}

# Role detection for a SINGLE eventDate spread across separate day/month/year
# columns -- the sibling of detect_eventdate_roles(), which resolves the 4-column
# start/end interval instead. Name-based only, with no positional fallback: a
# selection whose column names do not carry the roles as whole words stays
# unresolved so the caller keeps the generic collapse rather than guessing a
# date. Prefix matching is deliberately not attempted, since in Portuguese it
# misfires on ordinary column names ("anotacoes" -> ano, "mesorregiao" -> mes).
detect_eventdate_dmy_roles <- function(col_names) {
    normalized_names <- normalize_for_matching(col_names)
    used <- rep(FALSE, length(normalized_names))

    pick_first <- function(pattern) {
        idx <- which(grepl(pattern, normalized_names) & !used)
        if (length(idx) == 0) {
            return(NA_integer_)
        }
        used[[idx[[1]]]] <<- TRUE
        idx[[1]]
    }

    list(
        day = pick_first("\\b(day|dia|dd)\\b"),
        month = pick_first("\\b(month|mo|mes)\\b"),
        year = pick_first("\\b(year|yr|ano)\\b")
    )
}

# Compose one ISO 8601 eventDate from the day/month/year columns the user mapped
# to the term. Returns NULL -- meaning "not a date split into parts, treat it as
# any other multi-column term" -- unless every selected column resolves to a
# role, a year is among them, and a day never arrives without its month. That
# strictness is what keeps an unrelated pair of columns from being read as a
# date. Composition itself is delegated to the Rostrum composer, which already
# emits YYYY, YYYY-MM and YYYY-MM-DD and validates the day against the month's
# length in the given year.
build_eventdate_from_parts <- function(df, cols, fallback_raw = TRUE) {
    roles <- detect_eventdate_dmy_roles(cols)
    resolved <- c(roles$day, roles$month, roles$year)

    if (is.na(roles$year) || sum(!is.na(resolved)) != length(cols)) {
        return(NULL)
    }
    if (!is.na(roles$day) && is.na(roles$month)) {
        return(NULL)
    }

    pick_col <- function(idx) if (is.na(idx)) NA_character_ else cols[[idx]]
    composed <- rostrum_compose_eventdate_values(
        df = df,
        source_columns = list(
            year = pick_col(roles$year),
            month = pick_col(roles$month),
            day = pick_col(roles$day)
        )
    )

    # A row with no date parts at all is blank, not a failure -- same convention
    # as build_eventdate_interval().
    failed_rows <- composed$has_any_input & !composed$valid_mask

    result <- composed$values
    if (isTRUE(fallback_raw) && any(failed_rows)) {
        raw_values <- collapse_mapped_values(df, cols, out_sep = " | ")
        result[failed_rows] <- raw_values[failed_rows]
    }

    list(
        values = result,
        failed_rows = failed_rows,
        failure_count = sum(failed_rows),
        role_map = roles
    )
}

# Role detection for an interval whose two ends each carry a day, month and year
# ("dia_inicio, mes_inicio, ano_inicio, dia_fim, mes_fim, ano_fim"). It reads the
# same start/end vocabulary as detect_eventdate_roles(), which resolves the
# 4-column month/year interval, and is as strict as detect_eventdate_dmy_roles():
# names only, no positional fallback, so an unrelated six-column pick keeps the
# generic collapse instead of being read as a date range.
detect_eventdate_interval_dmy_roles <- function(col_names) {
    normalized_names <- normalize_for_matching(col_names)
    used_env <- new.env(parent = emptyenv())
    used_env$used <- rep(FALSE, length(normalized_names))

    start_mask <- grepl("\\b(start|begin|initial|inicio|from)\\b", normalized_names)
    end_mask <- grepl("\\b(end|final|fim|to)\\b", normalized_names)
    day_mask <- grepl("\\b(day|dia|dd)\\b", normalized_names)
    month_mask <- grepl("\\b(month|mo|mes)\\b", normalized_names)
    year_mask <- grepl("\\b(year|yr|ano)\\b", normalized_names)

    pick_first <- function(mask) {
        idx <- which(mask & !used_env$used)
        if (length(idx) == 0) {
            return(NA_integer_)
        }
        used_env$used[[idx[1]]] <- TRUE
        idx[1]
    }

    list(
        start = list(
            day = pick_first(start_mask & day_mask),
            month = pick_first(start_mask & month_mask),
            year = pick_first(start_mask & year_mask)
        ),
        end = list(
            day = pick_first(end_mask & day_mask),
            month = pick_first(end_mask & month_mask),
            year = pick_first(end_mask & year_mask)
        )
    )
}

# Compose one ISO 8601 interval ("2007-03-01/2008-05-11") from the six columns a
# collection uses to record a date range. Returns NULL -- meaning "not an
# interval, treat it as any other multi-column term" -- unless all six columns
# resolve to a distinct role. Each end is composed by the same Rostrum composer
# the single-date path uses, so a day is validated against its month either way.
build_eventdate_interval_dmy <- function(df, cols, fallback_raw = TRUE) {
    roles <- detect_eventdate_interval_dmy_roles(cols)
    resolved <- unlist(c(roles$start, roles$end), use.names = FALSE)

    if (anyNA(resolved) || length(unique(resolved)) != length(cols)) {
        return(NULL)
    }

    compose_end <- function(side) {
        rostrum_compose_eventdate_values(
            df = df,
            source_columns = list(
                year = cols[[side$year]],
                month = cols[[side$month]],
                day = cols[[side$day]]
            )
        )
    }
    start <- compose_end(roles$start)
    end <- compose_end(roles$end)

    # A range whose two ends are the same date is one date, not an interval --
    # writing "2024-03-22/2024-03-22" would state a span the record never had.
    # An end left blank is the same case: the collection recorded a single day.
    both_valid <- start$valid_mask & end$valid_mask
    is_range <- both_valid & start$values != end$values
    start_only <- start$valid_mask & !end$has_any_input
    end_only <- end$valid_mask & !start$has_any_input

    result <- rep(NA_character_, nrow(df))
    result[both_valid] <- start$values[both_valid]
    result[is_range] <- paste0(start$values[is_range], "/", end$values[is_range])
    result[start_only] <- start$values[start_only]
    result[end_only] <- end$values[end_only]

    has_any_input <- start$has_any_input | end$has_any_input
    failed_rows <- has_any_input & is.na(result)

    if (isTRUE(fallback_raw) && any(failed_rows)) {
        raw_values <- collapse_mapped_values(df, cols, out_sep = " | ")
        result[failed_rows] <- raw_values[failed_rows]
    }

    list(
        values = result,
        failed_rows = failed_rows,
        failure_count = sum(failed_rows),
        role_map = roles
    )
}

# Month name lookup, hoisted to a file-level constant so it is allocated once per
# session instead of once per call. It used to live inside parse_month_to_number(),
# which meant a 40-element named vector was built for every row of the dataset.
# Both the scalar helper and its vectorized companion read this same object, so
# the two spellings of the month table cannot drift apart.
.month_name_map <- c(
    jan = "01", janeiro = "01", january = "01",
    fev = "02", fevereiro = "02", feb = "02", february = "02",
    mar = "03", marco = "03", march = "03",
    abr = "04", abril = "04", apr = "04", april = "04",
    mai = "05", maio = "05", may = "05",
    jun = "06", junho = "06", june = "06",
    jul = "07", julho = "07", july = "07",
    ago = "08", agosto = "08", aug = "08", august = "08",
    set = "09", setembro = "09", sep = "09", sept = "09", september = "09",
    out = "10", outubro = "10", oct = "10", october = "10",
    nov = "11", novembro = "11", november = "11",
    dez = "12", dezembro = "12", dec = "12", december = "12",
    # Spanish names that the Portuguese and English entries do not cover
    ene = "01", enero = "01", febrero = "02", marzo = "03", mayo = "05",
    junio = "06", julio = "07", septiembre = "09", setiembre = "09",
    octubre = "10", noviembre = "11", dic = "12", diciembre = "12"
)

parse_month_to_number <- function(x) {
    if (is_blank_value(x)) {
        return(NA_character_)
    }

    value <- trimws(as.character(x))
    if (grepl("^\\d{1,2}$", value)) {
        month_num <- suppressWarnings(as.integer(value))
        if (!is.na(month_num) && month_num >= 1 && month_num <= 12) {
            return(sprintf("%02d", month_num))
        }
    }

    normalized <- normalize_for_matching(value)
    normalized <- gsub("\\s+", "", normalized)

    if (!normalized %in% names(.month_name_map)) {
        return(NA_character_)
    }

    unname(.month_name_map[[normalized]])
}

#' Vectorized companion to parse_month_to_number()
#'
#' Same mapping, resolved once per distinct month value instead of once per row.
#' A month column has at most a few dozen distinct spellings whatever the dataset
#' size, while the scalar version paid a grepl, an iconv (via
#' normalize_for_matching) and two gsub per record.
#'
#' @param x Character vector of raw month values
#' @return Character vector of "01".."12", NA where unparseable, same length as
#'   the input
#' @noRd
parse_month_to_number_vec <- function(x) {
    values <- as.character(x)
    n <- length(values)
    out <- rep(NA_character_, n)
    if (n == 0L) {
        return(out)
    }

    trimmed <- trimws(values)
    blank <- is.na(values) | !nzchar(trimmed)

    numeric_like <- !blank & grepl("^\\d{1,2}$", trimmed)
    month_num <- rep(NA_integer_, n)
    month_num[numeric_like] <- suppressWarnings(as.integer(trimmed[numeric_like]))
    in_range <- numeric_like & !is.na(month_num) & month_num >= 1L & month_num <= 12L
    out[in_range] <- sprintf("%02d", month_num[in_range])

    # Anything that is neither blank nor an in-range number falls through to the
    # name path. That includes out-of-range digits such as "0" and "13": the
    # scalar version does not short-circuit them to NA either, it lets them reach
    # the lookup (where they miss and yield NA). Keeping the fall-through is what
    # makes this a behaviour-preserving rewrite.
    named <- !blank & !in_range
    if (any(named)) {
        uniq <- unique(trimmed[named])
        norm <- gsub("\\s+", "", normalize_for_matching(uniq))
        # Single bracket, not [[: on a NAMED VECTOR (unlike a list) [[key]] errors
        # on a missing key, while [ ] with an NA index returns NA (ADR-110).
        resolved <- unname(.month_name_map[match(norm, names(.month_name_map))])
        out[named] <- resolved[match(trimmed[named], uniq)]
    }

    out
}

build_eventdate_interval <- function(df, cols, fallback_raw = TRUE) {
    if (length(cols) != 4) {
        stop("eventDate interval requires exactly 4 columns.")
    }

    role_map <- detect_eventdate_roles(cols)
    role_indices <- c(
        role_map$start_month,
        role_map$start_year,
        role_map$end_month,
        role_map$end_year
    )

    if (anyNA(role_indices)) {
        stop("Could not detect eventDate roles for all 4 mapped columns.")
    }

    row_values <- lapply(cols, function(col_name) {
        values <- as.character(df[[col_name]])
        values[is.na(df[[col_name]])] <- NA_character_
        values
    })

    blank_matrix <- do.call(cbind, lapply(row_values, function(values) {
        is.na(values) | !nzchar(trimws(values))
    }))
    all_blank <- rowSums(blank_matrix) == ncol(blank_matrix)

    # Four column-wide passes instead of four per-row vapply loops. The vapply
    # calls also carried USE.NAMES = TRUE (the default), so each one built and
    # threw away a names attribute as long as the dataset.
    start_month <- parse_month_to_number_vec(row_values[[role_indices[[1]]]])
    start_year <- parse_year_to_number_vec(row_values[[role_indices[[2]]]])
    end_month <- parse_month_to_number_vec(row_values[[role_indices[[3]]]])
    end_year <- parse_year_to_number_vec(row_values[[role_indices[[4]]]])

    has_all_parts <- !is.na(start_month) & !is.na(start_year) & !is.na(end_month) & !is.na(end_year)
    failed_rows <- !all_blank & !has_all_parts

    result <- rep(NA_character_, nrow(df))
    if (any(has_all_parts)) {
        result[has_all_parts] <- sprintf(
            "%04d-%s/%04d-%s",
            start_year[has_all_parts],
            start_month[has_all_parts],
            end_year[has_all_parts],
            end_month[has_all_parts]
        )
    }
    if (isTRUE(fallback_raw) && any(failed_rows)) {
        # Built here rather than up front: it is only ever read on this branch,
        # and on a clean dataset (no parse failures, the common case) nothing
        # reads it at all. With 4 columns collapse_mapped_values() takes its
        # multi-column path, an O(nrow) loop that was costing ~14s per call at
        # 50k rows purely to be discarded. Nothing is lost by deferring: the
        # function is pure, and its only other effect -- stop() on a missing
        # column -- is already reached by df[[col_name]] above.
        raw_values <- collapse_mapped_values(df, cols, out_sep = " | ")
        result[failed_rows] <- raw_values[failed_rows]
    }

    list(
        values = result,
        failed_rows = failed_rows,
        failure_count = sum(failed_rows),
        role_map = role_map
    )
}

rostrum_eventdate_parse_day <- function(values) {
    values_chr <- as.character(values)
    values_chr[is.na(values)] <- ""
    values_chr <- trimws(values_chr)

    # as.integer("29.9") gives 29. A day with a fraction is not a day.
    num <- suppressWarnings(as.numeric(values_chr))
    invalid <- !nzchar(values_chr) | is.na(num) | num != round(num) | num < 1 | num > 31
    out <- rep(NA_integer_, length(num))
    out[!invalid] <- as.integer(num[!invalid])
    out
}

rostrum_is_leap_year <- function(year_values) {
    year_num <- suppressWarnings(as.integer(year_values))
    valid <- !is.na(year_num)
    out <- rep(FALSE, length(year_num))
    out[valid] <- ((year_num[valid] %% 4L == 0L) & (year_num[valid] %% 100L != 0L)) |
        (year_num[valid] %% 400L == 0L)
    out
}

rostrum_days_in_month <- function(year_values, month_values) {
    month_num <- suppressWarnings(as.integer(month_values))
    year_num <- suppressWarnings(as.integer(year_values))

    out <- rep(NA_integer_, length(month_num))
    valid_month <- !is.na(month_num) & month_num >= 1L & month_num <= 12L

    out[valid_month & month_num %in% c(1L, 3L, 5L, 7L, 8L, 10L, 12L)] <- 31L
    out[valid_month & month_num %in% c(4L, 6L, 9L, 11L)] <- 30L

    feb_mask <- valid_month & month_num == 2L
    if (any(feb_mask)) {
        leap_mask <- rostrum_is_leap_year(year_num[feb_mask])
        out[feb_mask] <- ifelse(leap_mask, 29L, 28L)
    }

    out
}

rostrum_compose_eventdate_values <- function(df, source_columns) {
    n_rows <- nrow(df)
    if (n_rows == 0) {
        return(list(
            values = character(0),
            valid_mask = logical(0),
            partial_mask = logical(0),
            has_any_input = logical(0)
        ))
    }

    year_values <- rostrum_extract_column(df, source_columns[["year"]])
    month_values <- rostrum_extract_column(df, source_columns[["month"]])
    day_values <- rostrum_extract_column(df, source_columns[["day"]])

    year_blank <- is.na(year_values) | !nzchar(trimws(year_values))
    month_blank <- is.na(month_values) | !nzchar(trimws(month_values))
    day_blank <- is.na(day_values) | !nzchar(trimws(day_values))
    has_any_input <- !(year_blank & month_blank & day_blank)

    parsed_year <- parse_year_to_number_vec(year_values)
    parsed_month <- parse_month_to_number_vec(month_values)
    parsed_month_num <- suppressWarnings(as.integer(parsed_month))
    parsed_day <- rostrum_eventdate_parse_day(day_values)

    max_days <- rostrum_days_in_month(parsed_year, parsed_month_num)

    valid_year_only <- !year_blank & month_blank & day_blank & !is.na(parsed_year)
    valid_year_month <- !year_blank & !month_blank & day_blank &
        !is.na(parsed_year) & !is.na(parsed_month_num)
    valid_full <- !year_blank & !month_blank & !day_blank &
        !is.na(parsed_year) & !is.na(parsed_month_num) & !is.na(parsed_day) &
        !is.na(max_days) & parsed_day <= max_days

    valid_mask <- valid_year_only | valid_year_month | valid_full
    partial_mask <- valid_year_only | valid_year_month

    composed <- rep(NA_character_, n_rows)
    if (any(valid_year_only)) {
        composed[valid_year_only] <- sprintf("%04d", parsed_year[valid_year_only])
    }
    if (any(valid_year_month)) {
        composed[valid_year_month] <- sprintf("%04d-%02d", parsed_year[valid_year_month], parsed_month_num[valid_year_month])
    }
    if (any(valid_full)) {
        composed[valid_full] <- sprintf("%04d-%02d-%02d", parsed_year[valid_full], parsed_month_num[valid_full], parsed_day[valid_full])
    }

    list(
        values = composed,
        valid_mask = valid_mask,
        partial_mask = partial_mask,
        has_any_input = has_any_input
    )
}

