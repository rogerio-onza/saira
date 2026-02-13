# Title: I/O Utilities
# Author: Rogério Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

#' Read biodiversity CSV file with encoding detection
#'
#' @param file_path Path to CSV file
#' @param encoding Optional encoding override
#' @return Data frame
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

#' Detect CSV delimiter
#'
#' @param file_path Path to CSV file
#' @return Delimiter character
#' @export
detect_delimiter <- function(file_path) {
    # Read first line
    first_line <- readLines(file_path, n = 1, warn = FALSE)

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
    # Common Brazilian formats
    formats <- c(
        "%d/%m/%Y", # 25/12/2023
        "%d-%m-%Y", # 25-12-2023
        "%Y-%m-%d", # 2023-12-25 (ISO)
        "%d/%m/%y", # 25/12/23
        "%d.%m.%Y" # 25.12.2023
    )

    result <- rep(NA_character_, length(date_vector))

    for (i in seq_along(date_vector)) {
        if (is.na(date_vector[i]) || date_vector[i] == "") {
            next
        }

        for (fmt in formats) {
            parsed <- tryCatch(
                {
                    as.Date(date_vector[i], format = fmt)
                },
                error = function(e) NA
            )

            if (!is.na(parsed)) {
                result[i] <- format(parsed, "%Y-%m-%d")
                break
            }
        }
    }

    return(result)
}
