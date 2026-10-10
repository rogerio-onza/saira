# Title: Preview Fix Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-10-08
# Version: 1.0

#' @include utils_common.R
NULL

# The cell problems the Preview can fix, in the order it lists them. `family`
# names the filter pill. `bulk` says whether one fix may serve every problem
# with the same key (`preview_fix_key()`): where the value itself is the
# problem, the same value takes the same fix. An empty name or a duplicate
# identifier is not like that.
preview_problem_types <- data.frame(
    type = c("vocab_unknown", "date_unparsed", "year_range", "interval_inverted",
             "date_mismatch", "count_invalid", "required_empty", "id_duplicate"),
    family = c("vocab", "date", "year", "interval", "date_mismatch", "count",
               "empty", "id"),
    bulk = c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE),
    stringsAsFactors = FALSE
)

preview_date_terms <- c("eventDate", "dateIdentified", "modified")

# Terms a correction may not leave empty. The other terms the Preview fixes
# are optional in Darwin Core, so an empty cell is a valid fix for them.
preview_required_terms <- c("scientificName", "eventDate", "occurrenceID")

# ISO 8601 as Darwin Core takes it: a year, a month or a day, an optional time,
# and an interval of two of those. The end of an interval may drop the parts it
# shares with the start ("2007-11-13/15").
is_dwc_date_value <- function(x) {
    x <- trimws(as.character(x))
    x[is.na(x)] <- ""
    part_ok <- function(p) {
        ok <- grepl(
            "^\\d{4}(-\\d{2}(-\\d{2})?)?(T\\d{2}(:\\d{2}(:\\d{2}(\\.\\d+)?)?)?(Z|[+-]\\d{2}(:?\\d{2})?)?)?$",
            p
        )
        ym <- ok & grepl("^\\d{4}-\\d{2}", p)
        month <- suppressWarnings(as.integer(substr(p[ym], 6L, 7L)))
        ok[ym] <- month >= 1L & month <= 12L
        full <- ok & grepl("^\\d{4}-\\d{2}-\\d{2}", p)
        ok[full] <- !is.na(as.Date(substr(p[full], 1L, 10L), format = "%Y-%m-%d"))
        ok
    }
    has_slash <- grepl("/", x, fixed = TRUE)
    start <- sub("/.*$", "", x)
    end <- ifelse(has_slash, sub("^[^/]*/", "", x), "")
    end_ok <- part_ok(end) | grepl("^\\d{2}(-\\d{2})?$", end)
    part_ok(start) & (!has_slash | (end_ok & !grepl("/", end, fixed = TRUE)))
}

is_blank_cell <- function(x) {
    x <- as.character(x)
    is.na(x) | !nzchar(trimws(x))
}

problem_rows <- function(rows, term, type, value, suggestion = NA_character_) {
    n <- length(rows)
    data.frame(
        row = as.integer(rows),
        term = rep(term, n),
        type = rep(type, n),
        value = as.character(value),
        suggestion = if (length(suggestion) == n) as.character(suggestion) else rep(NA_character_, n),
        stringsAsFactors = FALSE
    )
}

# The single number in a count written as text ("cerca de 10", "10 ind.",
# "3,0"), or NA when there is none or more than one.
suggest_individual_count <- function(values) {
    num <- suppressWarnings(as.numeric(gsub(",", ".", values, fixed = TRUE)))
    out <- ifelse(!is.na(num) & num >= 0 & abs(num - round(num)) < 1e-9,
                  as.character(as.integer(round(num))), NA_character_)
    rest <- is.na(out)
    found <- regmatches(values[rest], gregexpr("\\d+", values[rest]))
    out[rest] <- vapply(found, function(d) if (length(d) == 1L) d else NA_character_, character(1))
    out
}

#' Find the cells the Preview can fix
#'
#' Scans the whole mapped frame, not the 100 rows the Preview table shows. A
#' cell is reported once, under the first problem type that matches it.
#'
#' @param df Mapped Darwin Core data frame.
#' @param max_year Newest plausible year. Default: the current year.
#' @return Data frame with `row`, `term`, `type`, `family`, `bulk`, `value`
#'   (the mapped value, "" when empty) and `suggestion` (NA when none; several
#'   concepts are joined with "|").
#' @noRd
detect_preview_problems <- function(df, max_year = NULL) {
    out <- list()
    cols <- if (is.data.frame(df) && nrow(df) > 0L) names(df) else character(0)
    text <- function(term) {
        v <- trimws(as.character(df[[term]]))
        v[is.na(v)] <- ""
        v
    }

    for (term in intersect(vocabulary_terms, cols)) {
        v <- text(term)
        bad <- which(nzchar(v) & !v %in% vocabulary_concepts(term))
        if (length(bad)) {
            uniq <- unique(v[bad])
            sugg <- vapply(uniq, function(x) paste(vocabulary_suggestions(term, x), collapse = "|"),
                           character(1))
            sugg[!nzchar(sugg)] <- NA_character_
            out[[length(out) + 1L]] <- problem_rows(bad, term, "vocab_unknown", v[bad],
                                                    unname(sugg[match(v[bad], uniq)]))
        }
    }

    for (term in intersect(preview_date_terms, cols)) {
        v <- text(term)
        bad <- which(nzchar(v) & !is_dwc_date_value(v))
        if (length(bad)) {
            out[[length(out) + 1L]] <- problem_rows(bad, term, "date_unparsed", v[bad])
        }
    }

    year_cols <- intersect(c(preview_date_terms, "year"), cols)
    if (length(year_cols)) {
        issues <- date_year_issues(df[, year_cols, drop = FALSE], max_year = max_year,
                                   sample_n = length(year_cols) * nrow(df))
        hits <- issues$sample
        for (term in unique(hits$column)) {
            h <- hits[hits$column == term, , drop = FALSE]
            out[[length(out) + 1L]] <- problem_rows(h$row, term, "year_range", h$value)
        }
    }

    if ("eventDate" %in% cols) {
        v <- text("eventDate")
        interval <- which(grepl("/", v, fixed = TRUE) & is_dwc_date_value(v))
        start <- sub("/.*$", "", v[interval])
        end <- sub("^[^/]*/", "", v[interval])
        width <- pmin(nchar(start), nchar(end))
        inverted <- grepl("^\\d{4}", end) & substr(start, 1L, width) > substr(end, 1L, width)
        if (any(inverted)) {
            rows <- interval[inverted]
            out[[length(out) + 1L]] <- problem_rows(rows, "eventDate", "interval_inverted", v[rows],
                                                    paste0(end[inverted], "/", start[inverted]))
        }

        single <- !grepl("/", v, fixed = TRUE) & is_dwc_date_value(v) & nzchar(v)
        parts <- list(year = c(1L, 4L), month = c(6L, 7L), day = c(9L, 10L))
        for (term in intersect(names(parts), cols)) {
            pos <- parts[[term]]
            p <- text(term)
            ref <- ifelse(single & nchar(v) >= pos[2],
                          suppressWarnings(as.integer(substr(v, pos[1], pos[2]))), NA_integer_)
            given <- suppressWarnings(as.integer(p))
            bad <- which(!is.na(ref) & nzchar(p) & (is.na(given) | given != ref))
            if (length(bad)) {
                out[[length(out) + 1L]] <- problem_rows(bad, term, "date_mismatch", p[bad],
                                                        as.character(ref[bad]))
            }
        }
    }

    if ("individualCount" %in% cols) {
        v <- text("individualCount")
        bad <- which(nzchar(v) & !grepl("^\\d+$", v))
        if (length(bad)) {
            out[[length(out) + 1L]] <- problem_rows(bad, "individualCount", "count_invalid", v[bad],
                                                    suggest_individual_count(v[bad]))
        }
    }

    for (term in intersect(c("scientificName", "eventDate"), cols)) {
        bad <- which(is_blank_cell(df[[term]]))
        if (length(bad)) {
            out[[length(out) + 1L]] <- problem_rows(bad, term, "required_empty", rep("", length(bad)))
        }
    }

    if ("occurrenceID" %in% cols) {
        v <- text("occurrenceID")
        dup <- which(nzchar(v) & (duplicated(v) | duplicated(v, fromLast = TRUE)))
        if (length(dup)) {
            out[[length(out) + 1L]] <- problem_rows(dup, "occurrenceID", "id_duplicate", v[dup])
        }
    }

    res <- do.call(rbind, out)
    if (is.null(res)) {
        res <- problem_rows(integer(0), character(0), character(0), character(0))
    }
    res <- res[!duplicated(res[c("row", "term")]), , drop = FALSE]
    meta <- match(res$type, preview_problem_types$type)
    res$family <- preview_problem_types$family[meta]
    res$bulk <- preview_problem_types$bulk[meta]
    res <- res[order(meta, res$row), c("row", "term", "type", "family", "bulk", "value", "suggestion"),
               drop = FALSE]
    rownames(res) <- NULL
    res
}

#' Apply the Preview corrections to the mapped frame
#'
#' An edit holds the value it replaces (`from`), so it acts only while the cell
#' still shows that value. A changed mapping makes an old edit inert instead of
#' writing it over a different value. An edit with `row = NA` serves every cell
#' of the term that holds `from`. An edit for one row wins over it.
#'
#' @param df Mapped Darwin Core data frame.
#' @param edits Data frame with `row` (integer or NA), `term`, `from`, `to`.
#'   An empty `to` clears the cell.
#' @return `df` with the corrections in place. A corrected scientificName
#'   also updates the taxon terms the mapping derived from the old name.
#' @noRd
apply_preview_edits <- function(df, edits) {
    if (!is.data.frame(df) || !is.data.frame(edits) || nrow(edits) == 0L) {
        return(df)
    }
    edits <- edits[edits$term %in% names(df), , drop = FALSE]
    old_names <- df$scientificName
    for (term in unique(edits$term)) {
        cur <- as.character(df[[term]])
        key <- trimws(cur)
        key[is.na(key)] <- ""
        out <- cur
        e <- edits[edits$term == term, , drop = FALSE]
        e <- e[order(!is.na(e$row)), , drop = FALSE]
        for (i in seq_len(nrow(e))) {
            from <- if (is.na(e$from[i])) "" else e$from[i]
            r <- e$row[i]
            if (is.na(r)) {
                out[key == from] <- e$to[i]
            } else if (r >= 1L && r <= length(key) && key[r] == from) {
                out[r] <- e$to[i]
            }
        }
        out[!is.na(out) & !nzchar(trimws(out))] <- NA_character_
        df[[term]] <- out
    }
    if ("scientificName" %in% edits$term) {
        df <- refresh_taxon_terms(df, old_names)
    }
    df
}

# The mapping derives genus, the epithets, taxonRank and the authorship from
# scientificName (build_processed_mapping_df). After a name correction, a
# derived value that came from the old name (or a blank) follows the new name.
# A value that came from a column of the user stays, as in the mapping.
refresh_taxon_terms <- function(df, old_names) {
    old <- as.character(old_names)
    new <- as.character(df$scientificName)
    old[is.na(old)] <- ""
    new[is.na(new)] <- ""
    rows <- which(old != new)
    if (!length(rows)) {
        return(df)
    }
    old_parts <- extract_scientific_name_components(old[rows])
    new_parts <- extract_scientific_name_components(new[rows])
    for (term in c(derived_taxon_terms(), "scientificNameAuthorship")) {
        cur <- if (term %in% names(df)) as.character(df[[term]]) else rep(NA_character_, nrow(df))
        here <- cur[rows]
        follow <- is.na(here) | !nzchar(trimws(here)) |
            (!is.na(old_parts[[term]]) & here == old_parts[[term]])
        here[follow] <- new_parts[[term]][follow]
        # No empty column for a term the new names do not use.
        if (!term %in% names(df) && all(is.na(here))) next
        cur[rows] <- here
        df[[term]] <- cur
    }
    # The name keeps only the taxon, as in the mapping (ADR-123).
    stripped <- scientific_name_without_authorship(new_parts)
    author <- new_parts$scientificNameAuthorship
    cut <- !is.na(stripped) & !is.na(author) & nzchar(author)
    df$scientificName[rows[cut]] <- stripped[cut]
    df
}

#' Match each problem to the edit that corrects it
#'
#' @param problems Output of `detect_preview_problems()`.
#' @param edits Edits as in `apply_preview_edits()`.
#' @return Integer index into `edits` for each problem, NA when not corrected.
#' @noRd
preview_problem_edit <- function(problems, edits) {
    n <- nrow(problems)
    if (!is.data.frame(edits) || nrow(edits) == 0L || n == 0L) {
        return(rep(NA_integer_, n))
    }
    from <- ifelse(is.na(edits$from), "", edits$from)
    row_key <- paste(edits$row, edits$term, from, sep = "\r")
    all_key <- paste(NA, edits$term, from, sep = "\r")
    all_key[!is.na(edits$row)] <- ""
    hit <- match(paste(problems$row, problems$term, problems$value, sep = "\r"), row_key)
    rest <- is.na(hit)
    hit[rest] <- match(paste(NA, problems$term[rest], problems$value[rest], sep = "\r"),
                       all_key)
    hit
}

#' The key of the problems that one fix serves
#'
#' A year that differs from eventDate takes its fix from the date of its own
#' row, so the key also holds the suggestion. The same year can be right in a
#' row with another date, so this fix is stored per row (`preview_fix_by_row()`).
#'
#' @param problems Output of `detect_preview_problems()`.
#' @return Character key for each problem.
#' @noRd
preview_fix_key <- function(problems) {
    by_row <- preview_fix_by_row(problems$type)
    paste(problems$term, problems$type, problems$value,
          ifelse(by_row, problems$suggestion, ""), sep = "\r")
}

preview_fix_by_row <- function(type) {
    type == "date_mismatch"
}

#' Find the next open problem below a saved one
#'
#' @param id Problem index that was just corrected.
#' @param shown Problem indices in the order the table shows them.
#' @param open Logical, TRUE for each problem of `shown` that has no edit.
#' @return Position in `shown` of the first open problem after `id`, NA when
#'   none is left below it.
#' @noRd
next_open_problem <- function(id, shown, open) {
    here <- match(id, shown)
    if (is.na(here)) return(NA_integer_)
    as.integer(which(open & seq_along(shown) > here)[1])
}

#' Check and normalize a value typed in the Preview
#'
#' @param term Darwin Core term of the cell.
#' @param value Typed text.
#' @param taken Identifiers other rows already use (occurrenceID only).
#' @return List with `value` (the text to store) and `error` (an i18n key or
#'   NULL).
#' @noRd
parse_preview_edit <- function(term, value, taken = character(0)) {
    v <- trimws(as.character(value %||% ""))
    if (length(v) != 1L || is.na(v)) v <- ""
    fail <- function(key) list(value = NULL, error = key)

    if (term %in% vocabulary_terms) {
        v <- tolower(v)
        if (nzchar(v) && !v %in% vocabulary_concepts(term)) return(fail("preview_fix_err_vocab"))
        return(list(value = v, error = NULL))
    }
    if (!nzchar(v)) {
        if (term %in% preview_required_terms) return(fail("preview_fix_err_blank"))
        return(list(value = "", error = NULL))
    }
    if (term %in% preview_date_terms) {
        if (!is_dwc_date_value(v)) {
            iso <- parse_dates_to_iso(v)
            if (is.na(iso)) return(fail("preview_fix_err_date"))
            v <- iso
        }
    } else if (term == "individualCount") {
        if (!grepl("^\\d+$", v)) return(fail("preview_fix_err_count"))
    } else if (term %in% c("year", "month", "day")) {
        n <- suppressWarnings(as.integer(v))
        top <- c(year = 9999L, month = 12L, day = 31L)[[term]]
        if (!grepl("^\\d{1,4}$", v) || is.na(n) || n < 1L || n > top) {
            return(fail("preview_fix_err_number"))
        }
        v <- as.character(n)
    } else if (term == "occurrenceID" && v %in% taken) {
        return(fail("preview_fix_err_id_taken"))
    }
    list(value = v, error = NULL)
}

#' The problem type that covers too many rows to fix one by one
#'
#' A share this large is usually a mapping or format issue (the wrong column, a
#' date format the parser does not know), not a typo per row.
#'
#' @param problems Output of `detect_preview_problems()`.
#' @param n_rows Rows in the dataset.
#' @param min_share,min_count Thresholds for the banner.
#' @return NULL, or a list with `type`, `term`, `count`, `share` and `example`.
#' @noRd
preview_problem_banner <- function(problems, n_rows, min_share = 0.2, min_count = 20L) {
    if (!is.data.frame(problems) || nrow(problems) == 0L || n_rows < 1L) {
        return(NULL)
    }
    groups <- paste(problems$type, problems$term, sep = "\r")
    counts <- table(groups)
    top <- names(counts)[which.max(counts)]
    count <- as.integer(counts[[top]])
    if (count < min_count || count / n_rows < min_share) {
        return(NULL)
    }
    sel <- problems[groups == top, , drop = FALSE]
    values <- sel$value[nzchar(sel$value)]
    list(
        type = sel$type[[1]],
        term = sel$term[[1]],
        count = count,
        share = count / n_rows,
        example = if (length(values)) names(sort(table(values), decreasing = TRUE))[[1]] else ""
    )
}
