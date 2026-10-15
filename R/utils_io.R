# Title: I/O Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

#' Read biodiversity CSV file with encoding detection
#'
#' Every column is read as character. Type guessing reads only the first rows,
#' so a column that starts empty or numeric and turns to prose further down
#' loses those values to NA without an error (ADR-124). Saira standardizes text
#' into Darwin Core, which has no numeric type, and the callers that need a
#' number convert on their own.
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
read_biodiversity_csv <- function(file_path, encoding = NULL, header = TRUE) {
    decoded <- decode_text_file(file_path, encoding)
    lines <- decoded$lines
    report <- decoded$report

    # Excel writes "sep=;" as line 1 of a CSV it saves for another locale.
    delimiter <- NULL
    if (length(lines) > 0L && grepl("^sep=.$", lines[[1L]])) {
        delimiter <- substr(lines[[1L]], 5L, 5L)
        lines <- lines[-1L]
        report$sep_line <- TRUE
    }
    if (is.null(delimiter)) delimiter <- delimiter_from_line(lines[1L])

    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(lines, tmp, useBytes = TRUE)

    parsed <- withCallingHandlers(
        tryCatch(
            readr::read_delim(
                tmp,
                delim = delimiter,
                locale = readr::locale(encoding = "UTF-8"),
                col_names = header,
                col_types = readr::cols(.default = readr::col_character()),
                show_col_types = FALSE,
                name_repair = "minimal",
                progress = FALSE
            ),
            error = function(e) {
                utils::read.csv(
                    tmp,
                    fileEncoding = "UTF-8",
                    sep = delimiter,
                    header = header,
                    colClasses = "character",
                    stringsAsFactors = FALSE,
                    check.names = FALSE
                )
            }
        ),
        # The ragged lines go to the read report. The readr warning only
        # reached the console, and under warn = 2 it became an error.
        warning = function(w) {
            if (grepl("parsing issues", conditionMessage(w), fixed = TRUE)) {
                invokeRestart("muffleWarning")
            }
        }
    )
    probs <- if (inherits(parsed, "tbl_df")) readr::problems(parsed) else NULL
    if (is.data.frame(probs) && nrow(probs) > 0L) {
        bad <- sort(unique(probs$row[grepl("columns", probs$expected, fixed = TRUE)]))
        report$ragged_count <- length(bad)
        report$ragged_lines <- utils::head(bad, 5L)
    }
    df <- as.data.frame(parsed, stringsAsFactors = FALSE)
    if (!header) names(df) <- paste0("col_", seq_len(ncol(df)))
    finish_upload_frame(df, report)
}

# Reads a text file into UTF-8 lines. The file can mix encodings (rows pasted
# from two exports), so each line is decoded on its own: UTF-8 when it is
# valid, else Windows-1252, else Latin-1. Windows-1252 goes first because
# Latin-1 decodes every byte, and its curly quote 0x92 becomes the invisible
# C1 control U+0092. CR, CRLF and LF all end a line: readr does not split on a
# lone CR and merged the next record into the last cell.
decode_text_file <- function(file_path, encoding = NULL) {
    report <- list(encoding_lines = c(), utf16 = FALSE)
    size <- file.info(file_path)$size
    bytes <- if (is.na(size) || size == 0L) raw(0) else readBin(file_path, "raw", n = size)
    n <- length(bytes)
    utf16 <- NULL
    if (n >= 2L && bytes[1L] == as.raw(0xff) && bytes[2L] == as.raw(0xfe)) {
        utf16 <- "UTF-16LE"
    } else if (n >= 2L && bytes[1L] == as.raw(0xfe) && bytes[2L] == as.raw(0xff)) {
        utf16 <- "UTF-16BE"
    }
    if (!is.null(utf16)) {
        text <- iconv(list(bytes[-(1:2)]), from = utf16, to = "UTF-8")
        if (is.na(text)) stop("The file has a UTF-16 mark, but its bytes are not valid UTF-16.")
        report$utf16 <- TRUE
        encoding <- "UTF-8"
    } else {
        if (n >= 3L && all(bytes[1:3] == as.raw(c(0xef, 0xbb, 0xbf)))) bytes <- bytes[-(1:3)]
        if (any(bytes == as.raw(0L))) {
            stop("The file has NUL bytes. Save it as UTF-8 text (CSV UTF-8 in Excel).")
        }
        text <- rawToChar(bytes)
    }
    lines <- strsplit(text, "\r\n|\r|\n", useBytes = TRUE)[[1L]]
    if (length(lines) == 0L) lines <- character(0)

    if (!is.null(encoding)) {
        lines <- iconv(lines, from = encoding, to = "UTF-8", sub = "?")
        Encoding(lines) <- "UTF-8"
        return(list(lines = lines, report = report))
    }
    ok <- validUTF8(lines)
    enc <- ifelse(ok, "UTF-8", "Windows-1252")
    if (any(!ok)) {
        cp <- iconv(lines[!ok], from = "CP1252", to = "UTF-8")
        # Bytes 0x81, 0x8D, 0x8F, 0x90 and 0x9D have no CP1252 character.
        miss <- is.na(cp)
        if (any(miss)) {
            cp[miss] <- iconv(lines[!ok][miss], from = "latin1", to = "UTF-8")
            enc[which(!ok)[miss]] <- "Latin-1"
        }
        lines[!ok] <- cp
    }
    Encoding(lines) <- "UTF-8"
    counts <- table(enc)
    report$encoding_lines <- stats::setNames(as.integer(counts), names(counts))
    list(lines = lines, report = report)
}

# Delimiter from the header line: the most frequent of tab, ";" and ",",
# with quoted text removed ("nome, autor" is one column name).
delimiter_from_line <- function(first_line) {
    if (length(first_line) == 0L || is.na(first_line) || !nzchar(first_line)) return(",")
    first_line <- gsub("\"[^\"]*\"", "", first_line, useBytes = TRUE)
    count_byte <- function(ch) {
        sum(gregexpr(ch, first_line, fixed = TRUE, useBytes = TRUE)[[1]] > 0L)
    }
    comma_count <- count_byte(",")
    semicolon_count <- count_byte(";")
    tab_count <- count_byte("\t")
    if (tab_count >= comma_count && tab_count >= semicolon_count) {
        "\t"
    } else if (semicolon_count > comma_count) {
        ";"
    } else {
        ","
    }
}

# Characters a user cannot see but that break a match: NBSP between genus and
# epithet, a zero-width space inside a word, bidi controls before a locality,
# a C1 control from a mis-decoded byte (U+0092 for a curly quote).
# NBSP and the line/paragraph separators become a plain space. The others go.
invisible_char_pattern <- "(*UTF)[\\x{0080}-\\x{009F}\\x{200B}-\\x{200F}\\x{202A}-\\x{202E}\\x{2060}\\x{FEFF}\\x{00AD}]"
space_char_pattern <- "(*UTF)[\\x{00A0}\\x{2028}\\x{2029}\\x{2007}\\x{202F}]"

clean_invisible_chars <- function(x) {
    if (!is.character(x)) return(x)
    out <- gsub(space_char_pattern, " ", x, perl = TRUE)
    out <- gsub(invisible_char_pattern, "", out, perl = TRUE)
    out
}

# Column names as the user sees them: trimmed, a blank header named after its
# position, a repeated header given a suffix. readr's "...18" suffix reached
# the UI and the occurrence.txt header.
repair_column_names <- function(x) {
    x <- clean_invisible_chars(trimws(as.character(x)))
    x[is.na(x)] <- ""
    blank <- !nzchar(x)
    x[blank] <- paste0("col_", which(blank))
    make.unique(x, sep = "_")
}

# A header line that is a data row: its cells are numbers, coordinates or
# dates. Two such cells, or one in four, is enough to ask the user.
probable_data_header <- function(header) {
    h <- trimws(as.character(header))
    h <- h[!is.na(h) & nzchar(h)]
    if (length(h) == 0L) return(FALSE)
    data_like <- grepl(
        paste0(
            "^[-+\u2212]?[0-9]+([.,][0-9]+)?\\s*(\u00b0|m|km)?$",
            "|^[0-9]{1,4}[/.-][0-9]{1,2}[/.-][0-9]{1,4}$",
            "|^[0-9]+\u00b0"
        ),
        h, perl = TRUE
    )
    sum(data_like) >= 2L || mean(data_like) >= 0.25
}

# One line per adjustment the reader made, for the upload notice. The parse
# warnings used to reach only the R console.
upload_read_notes <- function(report, lang = "en") {
    if (!is.list(report)) return(character(0))
    notes <- character(0)
    if (isTRUE(report$utf16)) notes <- c(notes, tr("upload_report_utf16", lang))
    enc <- report$encoding_lines
    other <- enc[names(enc) != "UTF-8"]
    if (length(other) > 0L && sum(other) > 0L) {
        notes <- c(notes, sprintf(
            tr("upload_report_encoding", lang),
            sum(other), paste(names(other), collapse = " / ")
        ))
    }
    if (isTRUE(report$sep_line)) notes <- c(notes, tr("upload_report_sep_line", lang))
    if (isTRUE(report$ragged_count > 0L)) {
        notes <- c(notes, sprintf(
            tr("upload_report_ragged", lang),
            report$ragged_count, paste(report$ragged_lines, collapse = ", ")
        ))
    }
    if (isTRUE(report$empty_rows > 0L)) {
        notes <- c(notes, sprintf(tr("upload_report_empty_rows", lang), report$empty_rows))
    }
    if (length(report$footer_rows) > 0L) {
        notes <- c(notes, sprintf(
            tr("upload_report_footer", lang),
            length(report$footer_rows),
            paste(utils::head(report$footer_rows, 5L), collapse = ", ")
        ))
    }
    if (isTRUE(report$invisible_cells > 0L)) {
        notes <- c(notes, sprintf(tr("upload_report_invisible", lang), report$invisible_cells))
    }
    if (length(report$duplicated_names) > 0L) {
        notes <- c(notes, sprintf(
            tr("upload_report_dup_names", lang),
            paste(report$duplicated_names, collapse = ", ")
        ))
    }
    if (isTRUE(report$blank_names > 0L)) {
        notes <- c(notes, sprintf(tr("upload_report_blank_names", lang), report$blank_names))
    }
    notes
}

# Shared end of the CSV and xlsx readers: repaired names, invisible
# characters, blank rows and probable footer rows. The findings go to the
# "read_report" attribute, which the upload tab shows to the user.
finish_upload_frame <- function(df, report = list()) {
    raw_names <- names(df)
    report$headerless_suspect <- probable_data_header(raw_names)
    trimmed <- trimws(raw_names)
    dup <- unique(trimmed[nzchar(trimmed) & duplicated(trimmed)])
    report$duplicated_names <- dup
    report$blank_names <- sum(!nzchar(trimmed))
    names(df) <- repair_column_names(raw_names)

    changed <- 0L
    for (col in names(df)) {
        v <- df[[col]]
        if (!is.character(v)) next
        cleaned <- clean_invisible_chars(v)
        diff <- !is.na(v) & cleaned != v
        if (any(diff)) {
            changed <- changed + sum(diff)
            df[[col]] <- cleaned
        }
    }
    report$invisible_cells <- changed

    if (nrow(df) > 0L && ncol(df) > 0L) {
        filled <- vapply(df, function(v) !is.na(v) & nzchar(trimws(v)), logical(nrow(df)))
        if (!is.matrix(filled)) filled <- matrix(filled, nrow = nrow(df))
        n_filled <- rowSums(filled)
        empty <- n_filled == 0L
        report$empty_rows <- sum(empty)
        # One filled cell in a wide row reads like "Total de registros: 138".
        footer <- which(n_filled[!empty] == 1L & ncol(df) >= 4L)
        df <- df[!empty, , drop = FALSE]
        rownames(df) <- NULL
        report$footer_rows <- footer
    }
    attr(df, "read_report") <- report
    df
}

#' Read the first sheet of an Excel .xlsx file as text
#'
#' Every column comes back as character, like \code{read_biodiversity_csv()}.
#' A plain \code{col_types = "text"} read turns a date cell into its Excel
#' serial number ("45372"), so the sheet is read cell by cell and each cell is
#' converted from its own type: dates to ISO 8601, numbers without scientific
#' notation.
#'
#' @param file_path Path to the .xlsx file
#' @return Data frame of character columns
#' @export
read_biodiversity_xlsx <- function(file_path, header = TRUE) {
    # readxl prints a message for each renamed blank header.
    sheet <- suppressMessages(readxl::read_xlsx(
        file_path,
        sheet = 1L,
        col_names = header,
        col_types = "list",
        .name_repair = "minimal"
    ))
    df <- as.data.frame(lapply(sheet, function(col) {
        vapply(col, xlsx_cell_to_text, character(1))
    }), stringsAsFactors = FALSE, check.names = FALSE)
    names(df) <- if (header) names(sheet) else paste0("col_", seq_len(ncol(sheet)))
    finish_upload_frame(df)
}

xlsx_cell_to_text <- function(x) {
    if (length(x) == 0L || is.na(x)) return(NA_character_)
    if (inherits(x, "POSIXt")) {
        fmt <- if (format(x, "%H:%M:%S", tz = "UTC") == "00:00:00") "%Y-%m-%d" else "%Y-%m-%dT%H:%M:%S"
        return(format(x, fmt, tz = "UTC"))
    }
    if (is.numeric(x)) return(format(x, scientific = FALSE, digits = 15L, trim = TRUE))
    as.character(x)
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
    # useBytes: a Latin-1 header is not valid UTF-8, and a character match on it
    # fails with "input string is invalid".
    sub("^\ufeff", "", text, useBytes = TRUE)
}

# Returns list(column, row) for the first character cell with invalid UTF-8 bytes,
# or NULL if all columns are clean.
find_first_invalid_utf8_cell <- function(df) {
    # Row 0 is the header: a Latin-1 file with ASCII data rows has its only
    # accents in the column names.
    bad_names <- which(is.na(iconv(names(df), from = "UTF-8", to = "UTF-8")))
    if (length(bad_names) > 0L) return(list(column = names(df)[[bad_names[[1L]]]], row = 0L))
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
    # Bytes, not characters: the header can still be Latin-1 here.
    delimiter_from_line(strip_bom(first_line))
}

# Day/month/year with a separator, the only shape whose field order a
# spreadsheet hides. A two-digit year counts only after "/".
.dmy_re <- "^(\\d{1,2})([/.-])(\\d{1,2})\\2(\\d{4}|\\d{2})$"

dmy_fields <- function(date_chr) {
    m <- regmatches(date_chr, regexec(.dmy_re, date_chr))
    hit <- lengths(m) == 5L
    na <- rep(NA_integer_, length(hit))
    out <- data.frame(hit = hit, a = na, b = na, year = na)
    if (!any(hit)) {
        return(out)
    }
    parts <- do.call(rbind, m[hit])
    year <- parts[, 5]
    short <- nchar(year) == 2L
    out$hit[hit] <- !short | parts[, 3] == "/"
    out$a[hit] <- as.integer(parts[, 2])
    out$b[hit] <- as.integer(parts[, 4])
    yy <- as.integer(year)
    current_yy <- as.integer(format(Sys.Date(), "%y"))
    yy[short] <- ifelse(yy[short] <= current_yy, 2000L + yy[short], 1900L + yy[short])
    out$year[hit] <- yy
    out
}

dmy_iso <- function(year, month, day) {
    iso <- sprintf("%04d-%02d-%02d", year, month, day)
    ok <- !is.na(as.Date(iso, format = "%Y-%m-%d"))
    ifelse(ok, iso, NA_character_)
}

# Decide whether a column of slash/dash/dot dates is day-first (DD/MM) or
# month-first (MM/DD). A value with one field > 12 is a vote, but only when it
# is a real date: "31/04/2020" proves nothing. The majority wins. A tie, or a
# column with no vote, returns NA: the order is unknown, and parse_dates_to_iso()
# then leaves the ambiguous values raw for the Preview instead of a guess.
detect_day_first <- function(date_chr) {
    f <- dmy_fields(as.character(date_chr))
    f <- f[f$hit, , drop = FALSE]
    if (!nrow(f)) {
        return(NA)
    }
    day_votes <- sum(f$a > 12L & !is.na(dmy_iso(f$year, f$b, f$a)))
    month_votes <- sum(f$b > 12L & !is.na(dmy_iso(f$year, f$a, f$b)))
    if (day_votes == month_votes) {
        return(NA)
    }
    day_votes > month_votes
}

# A value with a field > 12, or with the same day and month, has one reading
# and parses by itself. The column vote orders the rest. Because only valid
# dates vote, a second pass over the values the first pass left raw finds no
# vote and leaves them raw again, so the Preview and the export agree.
parse_dmy_dates <- function(date_chr) {
    f <- dmy_fields(date_chr)
    result <- rep(NA_character_, length(date_chr))
    if (!any(f$hit)) {
        return(result)
    }
    day_first <- detect_day_first(date_chr[f$hit])
    a <- f$a
    b <- f$b
    order <- rep(NA, length(a))
    order[which(a > 12L & b <= 12L)] <- TRUE
    order[which(b > 12L & a <= 12L)] <- FALSE
    order[which(a == b)] <- TRUE
    order[which(f$hit & is.na(order) & a <= 12L & b <= 12L)] <- day_first
    use <- f$hit & !is.na(order)
    day <- ifelse(order, a, b)
    month <- ifelse(order, b, a)
    result[use] <- dmy_iso(f$year[use], month[use], day[use])
    result
}

# Values the column vote cannot order: both fields <= 12 and different.
is_ambiguous_dmy <- function(date_chr) {
    f <- dmy_fields(as.character(date_chr))
    (f$hit & f$a <= 12L & f$b <= 12L & f$a != f$b) %in% TRUE
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

    # Day/month/year values follow the column vote (see parse_dmy_dates()).
    dmy <- parse_dmy_dates(ifelse(remaining, date_chr, ""))
    result[!is.na(dmy)] <- dmy[!is.na(dmy)]
    remaining[!is.na(dmy)] <- FALSE

    # Parse in batches by format to avoid element-wise loops.
    format_specs <- list(
        list(regex = "^\\d{4}-\\d{1,2}-\\d{1,2}$", fmt = "%Y-%m-%d"), # 2023-12-25 (ISO)
        list(regex = "^\\d{4}/\\d{1,2}/\\d{1,2}$", fmt = "%Y/%m/%d"),
        list(regex = "^\\d{4}\\.\\d{1,2}\\.\\d{1,2}$", fmt = "%Y.%m.%d")
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
