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
    type = c("vocab_unknown", "date_unparsed", "date_ambiguous", "year_range", "interval_inverted",
             "date_mismatch", "time_invalid", "count_invalid", "count_present_zero",
             "uncertainty_invalid",
             "coord_invalid", "coord_zero", "name_hybrid", "name_multiple", "name_abbreviated",
             "name_placeholder", "name_extra_text", "name_authorship", "country_threat_code",
             "country_conflict", "cell_formula", "required_empty", "id_duplicate"),
    family = c("vocab", "date", "date", "year", "interval", "date_mismatch", "time", "count",
               "count", "uncertainty", "coord", "coord", "name", "name", "name", "name", "name", "name",
               "country", "country", "formula", "empty", "id"),
    bulk = c(rep(TRUE, 8L), FALSE, rep(TRUE, 10L), FALSE, TRUE, FALSE, FALSE),
    stringsAsFactors = FALSE
)

# Problems where the other cell may be the wrong one. The row also offers this
# fix for that cell: a count of 0 with "present" can have the wrong status,
# not the wrong count (D07).
preview_other_fix <- data.frame(
    type = "count_present_zero", term = "occurrenceStatus", to = "absent",
    label = "preview_fix_mark_absent", stringsAsFactors = FALSE
)

preview_date_terms <-c("eventDate", "dateIdentified", "modified")

# Terms a correction may not leave empty. The other terms the Preview fixes
# are optional in Darwin Core, so an empty cell is a valid fix for them.
# eventDate is not here: a blank eventDate cell does not block the Export,
# so the Preview does not call it required (B24). A fully blank eventDate
# column still blocks, as one of the six required terms of the mapping.
preview_required_terms <- c("scientificName", "basisOfRecord", "occurrenceID")

# "2007-11-13/15": the end of an interval may drop the parts it shares with the
# start. A full end ("2024-03") has its own year and stays as it is (AUD-11).
expand_interval_end <- function(start, end) {
    short <- grepl("^\\d{2}(-\\d{2})?$", end)
    day <- substr(start[short], 1L, 10L)
    end[short] <- paste0(substr(day, 1L, nchar(day) - nchar(end[short])), end[short])
    end
}

# ISO 8601 as Darwin Core takes it: a year, a month or a day, an optional time,
# and an interval of two of those. The time keeps its real ranges: hour 00-23,
# minute and second 00-59, offset up to 14 hours (AUD-10).
is_dwc_date_value <- function(x) {
    x <- trimws(as.character(x))
    x[is.na(x)] <- ""
    part_ok <- function(p) {
        ok <- grepl(
            paste0("^\\d{4}(-\\d{2}(-\\d{2})?)?(T([01]\\d|2[0-3])(:[0-5]\\d(:[0-5]\\d(\\.\\d+)?)?)?",
                   "(Z|[+-](0\\d|1[0-4])(:?[0-5]\\d)?)?)?$"),
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
    # "2024-01-01/99" becomes "2024-01-99", so the day it names must exist.
    end_ok <- part_ok(expand_interval_end(start, end))
    part_ok(start) & (!has_slash | (end_ok & !grepl("/", end, fixed = TRUE)))
}

# Date cells that are not ISO 8601 after the conversion, for the Export
# pending list. `count` counts cells, `sample` shows the first ones.
unparsed_date_cells <- function(df, sample_n = 5L) {
    empty <- data.frame(row = integer(), column = character(), value = character(),
                        stringsAsFactors = FALSE)
    found <- lapply(intersect(preview_date_terms, names(df)), function(term) {
        v <- trimws(as.character(df[[term]]))
        v[is.na(v)] <- ""
        rows <- which(nzchar(v) & !is_dwc_date_value(v))
        data.frame(row = rows, column = rep(term, length(rows)), value = v[rows],
                   stringsAsFactors = FALSE)
    })
    bad <- do.call(rbind, c(list(empty), found))
    list(count = nrow(bad), sample = utils::head(bad, sample_n))
}

# A cell that a spreadsheet runs as a formula when a person opens
# occurrence.txt (B48). "=1+1" and "@SUM(A1)" always are. A sign starts a
# formula only with an operator after it, so "-23.5" and "-23\u00b033'S" pass.
is_formula_like <- function(x) {
    x <- trimws(as.character(x))
    x[is.na(x)] <- ""
    grepl("^[=@]", x) |
        (grepl("^[+-]", x) & grepl("[=*/^(!|&]|^[+-][0-9.]+[+-][0-9]", x) &
            is.na(suppressWarnings(as.numeric(x))))
}

# The value with no leading formula marker, or NA when nothing is left.
suggest_formula_fix <- function(x) {
    out <- trimws(sub("^[=@+]+", "", trimws(as.character(x))))
    out[!nzchar(out) | out == trimws(as.character(x))] <- NA_character_
    out
}

# Formula-like cells in every column, for the Export pending list. Same
# shape as unparsed_date_cells().
formula_like_cells <- function(df, sample_n = 5L) {
    empty <- data.frame(row = integer(), column = character(), value = character(),
                        stringsAsFactors = FALSE)
    cols <- if (is.data.frame(df)) names(df) else character(0)
    found <- lapply(cols, function(term) {
        v <- as.character(df[[term]])
        rows <- which(is_formula_like(v))
        data.frame(row = rows, column = rep(term, length(rows)), value = trimws(v[rows]),
                   stringsAsFactors = FALSE)
    })
    bad <- do.call(rbind, c(list(empty), found))
    list(count = nrow(bad), sample = utils::head(bad, sample_n))
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
        type = if (length(type) == n) type else rep(type, n),
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

# ISO 8601 time as Darwin Core takes it for eventTime, with an optional zone
# and an interval of two times.
is_dwc_time_value <- function(x) {
    x <- trimws(as.character(x))
    x[is.na(x)] <- ""
    one <- "([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9](\\.[0-9]+)?)?(Z|[+-][0-9]{2}(:?[0-9]{2})?)?"
    grepl(paste0("^", one, "(/", one, ")?$"), x)
}

# The 24-hour form of a time typed as "8:30", "12h30", "14h" or "08:30 PM",
# or NA when the hour or the minute is out of range.
suggest_event_time <- function(values) {
    v <- tolower(gsub("\\s+", "", trimws(as.character(values))))
    v[is.na(v)] <- ""
    re <- "^([0-9]{1,2})(?:[:h]([0-9]{2}))?(?::([0-9]{2}))?h?(am|pm|a\\.m\\.|p\\.m\\.)?$"
    m <- regmatches(v, regexec(re, v, perl = TRUE))
    vapply(m, function(p) {
        if (length(p) != 5L) return(NA_character_)
        hour <- as.integer(p[2])
        minute <- if (nzchar(p[3])) as.integer(p[3]) else 0L
        ampm <- substr(p[5], 1L, 1L)
        has_sep <- nzchar(p[3]) || nzchar(ampm) || grepl("h", p[1], fixed = TRUE)
        if (!has_sep) return(NA_character_)
        if (nzchar(ampm)) {
            if (hour < 1L || hour > 12L) return(NA_character_)
            hour <- hour %% 12L + if (ampm == "p") 12L else 0L
        }
        if (hour > 23L || minute > 59L) return(NA_character_)
        out <- sprintf("%02d:%02d", hour, minute)
        if (nzchar(p[4])) {
            if (as.integer(p[4]) > 59L) return(NA_character_)
            out <- paste0(out, ":", p[4])
        }
        out
    }, character(1))
}

# A coordinate the export can read: a number, with a comma or a dot, in range.
coord_value_ok <- function(x, limit) {
    parsed <- as_coord_numeric(trimws(as.character(x)))
    !parsed$parse_failed & !is.na(parsed$num) & abs(parsed$num) <= limit
}

# The number in a coordinate typed with a degree sign or a comma, or NA.
suggest_coordinate <- function(values, limit) {
    v <- trimws(sub("\\s*\u00b0$", "", trimws(as.character(values))))
    v <- sub(",", ".", sub("^\u2212", "-", v), fixed = TRUE)
    num <- suppressWarnings(as.numeric(v))
    ifelse(!is.na(num) & abs(num) <= limit, v, NA_character_)
}

# The name issues extract_scientific_name_components() finds, as Preview
# types. An issue keeps the typed name, so the record is not matched to a
# taxon and is not generalized.
name_issue_types <- c(
    hybrid = "name_hybrid", multiple = "name_multiple",
    abbreviated = "name_abbreviated", placeholder = "name_placeholder",
    extra_text = "name_extra_text"
)

has_unbalanced_brackets <- function(x) {
    count <- function(ch) lengths(regmatches(x, gregexpr(ch, x, fixed = TRUE)))
    count("(") != count(")") | count("[") != count("]")
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

    # First, so a formula in a name or a date shows as a formula.
    for (term in cols) {
        v <- text(term)
        bad <- which(is_formula_like(v))
        if (length(bad)) {
            out[[length(out) + 1L]] <- problem_rows(bad, term, "cell_formula", v[bad],
                                                    suggest_formula_fix(v[bad]))
        }
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
        # The column vote left these raw: "03/04/2021" reads two ways.
        ambiguous <- bad[is_ambiguous_dmy(v[bad])]
        bad <- setdiff(bad, ambiguous)
        if (length(ambiguous)) {
            out[[length(out) + 1L]] <- problem_rows(ambiguous, term, "date_ambiguous", v[ambiguous])
        }
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
        # A count of 0 says absence, so "present" contradicts it (D07). The row
        # needs a person to say which one is right.
        if ("occurrenceStatus" %in% cols) {
            status <- tolower(text("occurrenceStatus"))
            bad <- which(grepl("^0+$", v) & status %in% c("present", "presente"))
            if (length(bad)) {
                out[[length(out) + 1L]] <- problem_rows(bad, "individualCount", "count_present_zero",
                                                        v[bad])
            }
        }
    }

    if ("eventTime" %in% cols) {
        v <- text("eventTime")
        bad <- which(nzchar(v) & !is_dwc_time_value(v))
        if (length(bad)) {
            out[[length(out) + 1L]] <- problem_rows(bad, "eventTime", "time_invalid", v[bad],
                                                    suggest_event_time(v[bad]))
        }
    }

    if ("coordinateUncertaintyInMeters" %in% cols) {
        v <- text("coordinateUncertaintyInMeters")
        bad <- which(nzchar(v) & !is_valid_uncertainty(v))
        if (length(bad)) {
            out[[length(out) + 1L]] <- problem_rows(bad, "coordinateUncertaintyInMeters",
                                                    "uncertainty_invalid", v[bad],
                                                    suggest_uncertainty(v[bad]))
        }
    }

    for (term in intersect(c("decimalLatitude", "decimalLongitude"), cols)) {
        limit <- if (term == "decimalLatitude") 90 else 180
        v <- text(term)
        bad <- which(nzchar(v) & !coord_value_ok(v, limit))
        if (length(bad)) {
            out[[length(out) + 1L]] <- problem_rows(bad, term, "coord_invalid", v[bad],
                                                    suggest_coordinate(v[bad], limit))
        }
    }

    # (0, 0) is a filler, not a point in the Gulf of Guinea. A 0 next to a
    # blank axis stays flagged, so blanking one axis does not hide the other.
    if (all(c("decimalLatitude", "decimalLongitude") %in% cols)) {
        lat <- text("decimalLatitude")
        lon <- text("decimalLongitude")
        zero <- function(v) {
            num <- as_coord_numeric(v)$num
            !is.na(num) & num == 0
        }
        filler <- (zero(lat) | !nzchar(lat)) & (zero(lon) | !nzchar(lon))
        for (term in c("decimalLatitude", "decimalLongitude")) {
            v <- text(term)
            bad <- which(filler & zero(v))
            if (length(bad)) {
                out[[length(out) + 1L]] <- problem_rows(bad, term, "coord_zero", v[bad])
            }
        }
    }

    if ("scientificName" %in% cols) {
        v <- text("scientificName")
        uniq <- unique(v[nzchar(v)])
        if (length(uniq)) {
            issue <- extract_scientific_name_components(uniq)$nameIssue
            type <- unname(name_issue_types[issue])
            bad <- which(v %in% uniq[!is.na(type)])
            if (length(bad)) {
                out[[length(out) + 1L]] <- problem_rows(bad, "scientificName",
                                                        type[match(v[bad], uniq)], v[bad])
            }
        }
    }

    if ("scientificNameAuthorship" %in% cols) {
        v <- text("scientificNameAuthorship")
        bad <- which(nzchar(v) & has_unbalanced_brackets(v))
        if (length(bad)) {
            out[[length(out) + 1L]] <- problem_rows(bad, "scientificNameAuthorship",
                                                    "name_authorship", v[bad])
        }
    }

    for (term in intersect(c("scientificName", "basisOfRecord"), cols)) {
        bad <- which(is_blank_cell(df[[term]]))
        if (length(bad)) {
            out[[length(out) + 1L]] <- problem_rows(bad, term, "required_empty", rep("", length(bad)))
        }
    }

    # A threat category in the country column is a shifted column, not a
    # country: "VU" reads as Vanuatu (B33). "CR" stays out, it is Costa Rica.
    if ("country" %in% cols) {
        v <- text("country")
        bad <- which(toupper(v) %in% c("EX", "EW", "EN", "VU", "NT", "LC", "DD"))
        if (length(bad)) {
            out[[length(out) + 1L]] <- problem_rows(bad, "country", "country_threat_code", v[bad])
        }
    }

    # MIX-065: country "Argentina", countryCode "BR" (B04). The row needs a
    # person to say which one is right, so one fix does not serve all rows.
    if (all(c("country", "countryCode") %in% cols)) {
        both <- which(nzchar(text("country")) & nzchar(text("countryCode")))
        if (length(both)) {
            iso <- tryCatch(
                list(coords_country_to_iso3(text("country")[both]),
                     coords_country_to_iso3(text("countryCode")[both])),
                error = function(e) NULL
            )
            if (!is.null(iso)) {
                bad <- both[!is.na(iso[[1]]) & !is.na(iso[[2]]) & iso[[1]] != iso[[2]]]
                if (length(bad)) {
                    out[[length(out) + 1L]] <- problem_rows(bad, "countryCode", "country_conflict",
                                                            text("countryCode")[bad])
                }
            }
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
    other <- match(problems$type, preview_other_fix$type)
    rest <- is.na(hit) & !is.na(other)
    if (any(rest)) {
        other_key <- paste(edits$row, edits$term, edits$to, sep = "\r")
        hit[rest] <- match(paste(problems$row[rest], preview_other_fix$term[other[rest]],
                                 preview_other_fix$to[other[rest]], sep = "\r"), other_key)
    }
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
    if (term == "basisOfRecord") {
        # A label ("Observação humana") or any case of the term is accepted.
        v <- auto_suggest_basis_of_record_terms(v)
        if (!nzchar(v)) return(fail("preview_fix_err_bor"))
    } else if (term %in% preview_date_terms) {
        if (!is_dwc_date_value(v)) {
            # One value carries no column vote, so "05/07/2016" would be read
            # month-first. Ask for ISO instead of guessing the order.
            dm <- regmatches(v, regexec("^(\\d{1,2})[/.-](\\d{1,2})[/.-]\\d{2,4}$", v))[[1]]
            if (length(dm) == 3L && max(as.integer(dm[2:3])) <= 12L && dm[2] != dm[3]) {
                return(fail("preview_fix_err_date_ambiguous"))
            }
            iso <- parse_dates_to_iso(v)
            if (is.na(iso)) return(fail("preview_fix_err_date"))
            v <- iso
        }
    } else if (term == "eventTime") {
        if (!is_dwc_time_value(v)) {
            v <- suggest_event_time(v)
            if (is.na(v)) return(fail("preview_fix_err_time"))
        }
    } else if (term == "coordinateUncertaintyInMeters") {
        if (!is_valid_uncertainty(v)) {
            v <- suggest_uncertainty(v)
            if (is.na(v)) return(fail("preview_fix_err_uncertainty"))
        }
    } else if (term %in% c("decimalLatitude", "decimalLongitude")) {
        limit <- if (term == "decimalLatitude") 90 else 180
        if (!coord_value_ok(v, limit)) {
            v <- suggest_coordinate(v, limit)
            if (is.na(v)) return(fail("preview_fix_err_coord"))
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
