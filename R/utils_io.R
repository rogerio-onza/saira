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
    # Try to detect encoding if not specified
    if (is.null(encoding)) {
        encoding <- detect_encoding(file_path)
    }

    # Try to detect delimiter
    delimiter <- detect_delimiter(file_path)

    # Read file
    df <- tryCatch(
        {
            readr::read_delim(
                file_path,
                delim = delimiter,
                locale = readr::locale(encoding = encoding),
                show_col_types = FALSE,
                name_repair = "unique"
            )
        },
        error = function(e) {
            # Fallback to base R
            utils::read.csv(
                file_path,
                fileEncoding = encoding,
                sep = delimiter,
                stringsAsFactors = FALSE
            )
        }
    )

    return(as.data.frame(df))
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

    # Parse in batches by format to avoid element-wise loops.
    format_specs <- list(
        list(regex = "^\\d{4}-\\d{2}-\\d{2}$", fmt = "%Y-%m-%d"), # 2023-12-25 (ISO)
        list(regex = "^\\d{2}/\\d{2}/\\d{4}$", fmt = "%d/%m/%Y"), # 25/12/2023
        list(regex = "^\\d{2}-\\d{2}-\\d{4}$", fmt = "%d-%m-%Y"), # 25-12-2023
        list(regex = "^\\d{2}\\.\\d{2}\\.\\d{4}$", fmt = "%d.%m.%Y") # 25.12.2023
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
        yy_mask <- grepl("^\\d{2}/\\d{2}/\\d{2}$", yy_candidates)

        if (any(yy_mask)) {
            yy_values <- yy_candidates[yy_mask]
            day <- as.integer(substr(yy_values, 1, 2))
            month <- as.integer(substr(yy_values, 4, 5))
            year_two_digits <- as.integer(substr(yy_values, 7, 8))
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

    return(result)
}
