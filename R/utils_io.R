# Title: I/O Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

#' Read biodiversity CSV file with encoding detection
#'
#' @param file_path Path to CSV file
#' @param encoding Optional encoding override
#' @return Data frame
#' @examples
#' \dontrun{
#'   # Reads CSV with automatic encoding and delimiter detection
#'   df <- read_biodiversity_csv("data/biodiversity.csv")
#'   # Or with explicit encoding:
#'   df <- read_biodiversity_csv("data/biodiversity.csv", encoding = "UTF-8")
#' }
#' @export
read_biodiversity_csv <- function(file_path, encoding = NULL) {
    forced_encoding <- !is.null(encoding)
    if (!forced_encoding) encoding <- detect_encoding(file_path)

    delimiter <- detect_delimiter(file_path)

    read_with_enc <- function(enc) {
        as.data.frame(tryCatch(
            readr::read_delim(
                file_path,
                delim = delimiter,
                locale = readr::locale(encoding = enc),
                show_col_types = FALSE,
                name_repair = "unique"
            ),
            error = function(e) {
                utils::read.csv(
                    file_path,
                    fileEncoding = enc,
                    sep = delimiter,
                    stringsAsFactors = FALSE
                )
            }
        ))
    }

    df <- read_with_enc(encoding)

    if (!forced_encoding) {
        candidates <- c("Latin1", "Windows-1252")
        candidates <- candidates[candidates != encoding]

        invalid <- find_first_invalid_utf8_cell(df)
        if (!is.null(invalid)) {
            warning(sprintf(
                "Invalid UTF-8 in column %s row %d; retrying with alternative encoding",
                invalid$column, invalid$row
            ))
            for (retry_enc in candidates) {
                df <- read_with_enc(retry_enc)
                encoding <- retry_enc
                if (is.null(find_first_invalid_utf8_cell(df))) break
            }
        }

        remaining <- find_first_invalid_utf8_cell(df)
        if (!is.null(remaining)) {
            warning(sprintf(
                "Invalid UTF-8 bytes remain in column %s row %d after encoding retry",
                remaining$column, remaining$row
            ))
        }
    }

    df
}

#' Detect file encoding
#'
#' @param file_path Path to file
#' @return Detected encoding string
#' @export
detect_encoding <- function(file_path) {
    # Read first few bytes
    raw_bytes <- readBin(file_path, "raw", n = 10000)

    # Try to detect UTF-8 BOM
    if (length(raw_bytes) >= 3) {
        if (raw_bytes[1] == 0xef && raw_bytes[2] == 0xbb && raw_bytes[3] == 0xbf) {
            return("UTF-8")
        }
    }

    # Try UTF-8 first (most common)
    test_utf8 <- tryCatch(
        {
            readr::read_lines(file_path, n_max = 100, locale = readr::locale(encoding = "UTF-8"))
            TRUE
        },
        error = function(e) FALSE
    )

    if (test_utf8) {
        return("UTF-8")
    }

    # Try Latin1 (Portuguese/Brazilian data)
    test_latin1 <- tryCatch(
        {
            readr::read_lines(file_path, n_max = 100, locale = readr::locale(encoding = "Latin1"))
            TRUE
        },
        error = function(e) FALSE
    )

    if (test_latin1) {
        return("Latin1")
    }

    # Default to Windows-1252 (common in Brazilian Excel exports)
    return("Windows-1252")
}

#' Strip UTF-8 BOM from text
#'
#' @param text Character vector
#' @return Character vector without BOM prefix
strip_bom <- function(text) {
    sub("^\ufeff", "", text)
}

# Returns list(column, row) for the first character cell with invalid UTF-8 bytes,
# or NULL if all columns are clean.
find_first_invalid_utf8_cell <- function(df) {
    for (col in names(df)) {
        if (!is.character(df[[col]])) next
        converted <- iconv(df[[col]], from = "UTF-8", to = "UTF-8")
        bad <- which(is.na(converted) & !is.na(df[[col]]))
        if (length(bad) > 0L) return(list(column = col, row = bad[[1L]]))
    }
    NULL
}

#' Detect CSV delimiter
#'
#' @param file_path Path to CSV file
#' @return Delimiter character
#' @export
detect_delimiter <- function(file_path) {
    # Read first line
    first_line <- readLines(file_path, n = 1, warn = FALSE, encoding = "UTF-8")
    if (length(first_line) == 0L || !nzchar(first_line)) {
        return(",")
    }
    first_line <- strip_bom(first_line)

    # Count potential delimiters
    comma_count <- stringr::str_count(first_line, ",")
    semicolon_count <- stringr::str_count(first_line, ";")
    tab_count <- stringr::str_count(first_line, "\t")

    # Return most common delimiter
    if (tab_count >= comma_count && tab_count >= semicolon_count) {
        return("\t")
    } else if (semicolon_count > comma_count) {
        return(";")
    } else {
        return(",")
    }
}

# Decide whether a column of slash/dash/dot dates is day-first (DD/MM) or
# month-first (MM/DD). Any value with a first component > 12 proves day-first;
# otherwise any value with a second component > 12 proves month-first. When no
# value disambiguates (every component <= 12), default to month-first (MM/DD):
# most published datasets use the English convention, so this is the safer
# long-term guess. Year-first ISO dates are ignored here.
detect_day_first <- function(date_chr) {
    orderable <- "^(\\d{1,2})[/.-](\\d{1,2})[/.-]\\d{2,4}$"
    parts <- regmatches(date_chr, regexec(orderable, date_chr))
    parts <- parts[lengths(parts) == 3L]
    if (!length(parts)) {
        return(FALSE)
    }
    first_comp <- as.integer(vapply(parts, `[`, character(1), 2L))
    second_comp <- as.integer(vapply(parts, `[`, character(1), 3L))
    if (any(first_comp > 12, na.rm = TRUE)) {
        return(TRUE)
    }
    if (any(second_comp > 12, na.rm = TRUE)) {
        return(FALSE)
    }
    FALSE
}

# A spreadsheet or a GPS logger writes the collection time next to the date
# ("25/12/2023 14:30"), and only the date half needs normalising. Splitting the
# time off here is what lets the day-first vote and every format spec below see
# a bare date; the time half is re-attached with the ISO "T" separator, so an
# hour the collector recorded is never dropped on the way to the export.
.datetime_split_re <- paste0(
    "^(.+?)[ T]([0-9]{1,2}:[0-9]{2}(:[0-9]{2})?)",
    "[[:space:]]*(Z|[+-][0-9]{2}:?[0-9]{2})?$"
)

split_time_suffix <- function(x) {
    has_time <- grepl(.datetime_split_re, x, perl = TRUE)
    time_part <- rep("", length(x))

    if (!any(has_time)) {
        return(list(date = x, time = time_part))
    }

    with_time <- x[has_time]
    date_part <- x
    date_part[has_time] <- trimws(sub(.datetime_split_re, "\\1", with_time, perl = TRUE))
    time_part[has_time] <- paste0(
        sub("^([0-9]):", "0\\1:", sub(.datetime_split_re, "\\2", with_time, perl = TRUE)),
        sub(.datetime_split_re, "\\4", with_time, perl = TRUE)
    )

    list(date = date_part, time = time_part)
}

#' Parse dates from various formats to ISO
#'
#' @param date_vector Character vector of dates
#' @return Character vector of ISO-formatted dates
#' @export
parse_dates_to_iso <- function(date_vector) {
    date_chr <- as.character(date_vector)
    result <- rep(NA_character_, length(date_chr))
    remaining <- !is.na(date_chr) & nzchar(date_chr)

    if (!any(remaining)) {
        return(result)
    }

    split <- split_time_suffix(trimws(date_chr))
    date_chr <- split$date
    time_suffix <- split$time

    # Disambiguate day-first (DD/MM) vs month-first (MM/DD) for slash/dash/dot
    # dates by voting over the whole column: a value whose first component is
    # > 12 proves day-first; one whose second component is > 12 proves
    # month-first. A fully ambiguous column (every component <= 12) falls back
    # to month-first (MM/DD), the safer guess for English-published datasets.
    day_first <- detect_day_first(date_chr)

    # Parse in batches by format to avoid element-wise loops.
    # Day/month accept 1-2 digits so unpadded inputs (e.g. 2/9/2021, exported by
    # spreadsheets) parse the same as zero-padded ones (02/09/2021).
    # Year-first values are never ambiguous, so they carry no day-first vote.
    dm <- if (day_first) c("%d", "%m") else c("%m", "%d")
    format_specs <- list(
        list(regex = "^\\d{4}-\\d{1,2}-\\d{1,2}$", fmt = "%Y-%m-%d"), # 2023-12-25 (ISO)
        list(regex = "^\\d{4}/\\d{1,2}/\\d{1,2}$", fmt = "%Y/%m/%d"),
        list(regex = "^\\d{4}\\.\\d{1,2}\\.\\d{1,2}$", fmt = "%Y.%m.%d"),
        list(regex = "^\\d{1,2}/\\d{1,2}/\\d{4}$", fmt = sprintf("%s/%s/%%Y", dm[1], dm[2])),
        list(regex = "^\\d{1,2}-\\d{1,2}-\\d{4}$", fmt = sprintf("%s-%s-%%Y", dm[1], dm[2])),
        list(regex = "^\\d{1,2}\\.\\d{1,2}\\.\\d{4}$", fmt = sprintf("%s.%s.%%Y", dm[1], dm[2]))
    )

    for (spec in format_specs) {
        idx <- which(remaining)
        if (!length(idx)) {
            break
        }

        candidates <- date_chr[idx]
        matches <- grepl(spec$regex, candidates)
        if (!any(matches)) {
            next
        }

        parsed <- as.Date(candidates[matches], format = spec$fmt)
        success <- !is.na(parsed)

        if (any(success)) {
            resolved_idx <- idx[matches][success]
            result[resolved_idx] <- format(parsed[success], "%Y-%m-%d")
            remaining[resolved_idx] <- FALSE
        }
    }

    # Handle DD/MM/YY with dynamic century cutoff.
    idx <- which(remaining)
    if (length(idx)) {
        yy_candidates <- date_chr[idx]
        yy_re <- "^(\\d{1,2})/(\\d{1,2})/(\\d{2})$"
        yy_mask <- grepl(yy_re, yy_candidates)

        if (any(yy_mask)) {
            yy_values <- yy_candidates[yy_mask]
            comp1 <- as.integer(sub(yy_re, "\\1", yy_values))
            comp2 <- as.integer(sub(yy_re, "\\2", yy_values))
            day <- if (day_first) comp1 else comp2
            month <- if (day_first) comp2 else comp1
            year_two_digits <- as.integer(sub(yy_re, "\\3", yy_values))
            current_yy <- as.integer(format(Sys.Date(), "%y"))
            full_year <- ifelse(
                year_two_digits <= current_yy,
                2000L + year_two_digits,
                1900L + year_two_digits
            )

            iso_candidates <- sprintf("%04d-%02d-%02d", full_year, month, day)
            parsed <- as.Date(iso_candidates, format = "%Y-%m-%d")
            success <- !is.na(parsed)

            if (any(success)) {
                resolved_idx <- idx[yy_mask][success]
                result[resolved_idx] <- format(parsed[success], "%Y-%m-%d")
                remaining[resolved_idx] <- FALSE
            }
        }
    }

    # Month and year with no day. Darwin Core accepts the reduced ISO form, so
    # "12/2023" and "2023/12" become "2023-12" instead of reaching the export
    # with the separator the spreadsheet happened to use.
    idx <- which(remaining)
    if (length(idx)) {
        ym_candidates <- date_chr[idx]
        my_re <- "^(\\d{1,2})[/.-](\\d{4})$"
        ym_re <- "^(\\d{4})[/.-](\\d{1,2})$"
        my_mask <- grepl(my_re, ym_candidates)
        ym_mask <- !my_mask & grepl(ym_re, ym_candidates)

        month <- rep(NA_integer_, length(ym_candidates))
        year <- month
        month[my_mask] <- as.integer(sub(my_re, "\\1", ym_candidates[my_mask]))
        year[my_mask] <- as.integer(sub(my_re, "\\2", ym_candidates[my_mask]))
        year[ym_mask] <- as.integer(sub(ym_re, "\\1", ym_candidates[ym_mask]))
        month[ym_mask] <- as.integer(sub(ym_re, "\\2", ym_candidates[ym_mask]))

        success <- !is.na(month) & !is.na(year) & month >= 1L & month <= 12L
        if (any(success)) {
            resolved_idx <- idx[success]
            result[resolved_idx] <- sprintf("%04d-%02d", year[success], month[success])
            remaining[resolved_idx] <- FALSE
        }
    }

    with_time <- nzchar(time_suffix) & !is.na(result)
    if (any(with_time)) {
        result[with_time] <- paste0(result[with_time], "T", time_suffix[with_time])
    }

    return(result)
}

#' Flag dates whose year is outside the plausible range
#'
#' A typo in a spreadsheet ("2098" for "2008") survives every format conversion:
#' the value is a perfectly well-formed ISO date, so nothing downstream objects
#' to it. This reports those cells so the publisher can fix them before the
#' dataset reaches GBIF, which rejects a record dated in the future.
#'
#' Every standalone 4-digit run in the value counts as a year, so an interval
#' ("2010-01/2098-03") is flagged on its second half too.
#'
#' @param df Data frame carrying Darwin Core columns.
#' @param min_year Oldest plausible year. Default 1600, the GBIF convention for
#'   an occurrence record.
#' @param max_year Newest plausible year. Default: the current year.
#' @param sample_n How many offending cells to report back.
#' @return Named list: `count` (offending cells), `future_count`,
#'   `ancient_count`, `columns`, `sample` (data frame `row`/`column`/`value`),
#'   `min_year`, `max_year`.
#' @noRd
date_year_issues <- function(df, min_year = 1600L, max_year = NULL, sample_n = 5L) {
    if (is.null(max_year)) {
        max_year <- as.integer(format(Sys.Date(), "%Y"))
    }

    empty <- list(
        count = 0L, future_count = 0L, ancient_count = 0L,
        columns = character(0),
        sample = data.frame(
            row = integer(0), column = character(0), value = character(0),
            stringsAsFactors = FALSE
        ),
        min_year = as.integer(min_year), max_year = as.integer(max_year)
    )

    if (!is.data.frame(df) || nrow(df) == 0L) {
        return(empty)
    }

    cols <- intersect(c("eventDate", "dateIdentified", "modified", "year"), names(df))
    if (!length(cols)) {
        return(empty)
    }

    hits <- empty$sample
    future_count <- 0L
    ancient_count <- 0L

    for (col in cols) {
        values <- trimws(as.character(df[[col]]))
        uniq <- unique(values)
        # The lookarounds keep a compact "20231225" from being read as the year
        # 2023 plus a bogus year 1225.
        matches <- regmatches(uniq, gregexpr("(?<!\\d)\\d{4}(?!\\d)", uniq, perl = TRUE))
        uniq_future <- vapply(matches, function(y) any(as.integer(y) > max_year), logical(1))
        uniq_ancient <- vapply(matches, function(y) any(as.integer(y) < min_year), logical(1))

        pos <- match(values, uniq)
        is_future <- uniq_future[pos]
        is_ancient <- uniq_ancient[pos]
        bad <- is_future | is_ancient

        if (any(bad)) {
            future_count <- future_count + sum(is_future)
            ancient_count <- ancient_count + sum(is_ancient)
            rows <- which(bad)
            hits <- rbind(hits, data.frame(
                row = rows, column = col, value = values[rows],
                stringsAsFactors = FALSE
            ))
        }
    }

    if (nrow(hits) == 0L) {
        return(empty)
    }

    hits <- hits[order(hits$row, hits$column), , drop = FALSE]
    rownames(hits) <- NULL

    list(
        count = nrow(hits),
        future_count = as.integer(future_count),
        ancient_count = as.integer(ancient_count),
        columns = unique(hits$column),
        sample = utils::head(hits, sample_n),
        min_year = as.integer(min_year),
        max_year = as.integer(max_year)
    )
}
