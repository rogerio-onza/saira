# Title: Export review summary (pure)
# Author: Rogerio Nunes Oliveira

#' Build a pre-export "review before you publish" summary
#'
#' Pure aggregator for the Export tab: given the mapped Darwin Core data and the
#' payloads produced by the validation/generalization stages, it returns a
#' structured summary of what was corrected, which species are generalized, the
#' export readiness of the required terms, and the files the bundle will contain.
#' No Shiny, no I/O — every input is a plain value so it is unit-testable.
#'
#' @param mapped_data Processed Darwin Core data frame (`processed_data_r`).
#' @param name_review_payload List with `entries` (the manual name reviews), or NULL.
#' @param coords_correction_payload List with `corrections` (occurrenceID + new
#'   coordinates) and `stale` (the fixes dropped because the point changed),
#'   or NULL.
#' @param country_fill_payload List with `country` (occurrenceID + filled country),
#'   or NULL.
#' @param sensitivity_payload Per-species sensitivity marks (for the threat
#'   category), or NULL.
#' @param generalization_payload List `{ levels, enabled, ... }` from the
#'   Generalization stage, or NULL.
#' @param dataset_name Dataset name (the `datasetName` constant), used to name
#'   the auxiliary bundle files. NULL falls back to a generic slug.
#' @param raw_data,map_values,overridden_terms The upload, the mapping and the
#'   terms whose fixed value won (`overridden_mapping_terms()`). They give the
#'   unmapped columns the download adds to the file.
#' @return Named list: `record_count`, `term_count`, `corrections`
#'   (`names_corrected`/`names_confirmed`/`coord_fixes`/`coord_fixes_stale`/`country_fills`),
#'   `generalization` (data.frame `scientificName`/`category`/`tier`),
#'   `readiness` (data.frame `term`/`present`), `readiness_pct`,
#'   `missing_required`, `occurrence_id_present`, `bor_blank_count`,
#'   `bor_blank_rows`, `sci_blank_rows` (records with no scientificName),
#'   `justification_pending`,
#'   `date_issues` (from `date_year_issues()`), `date_unparsed` (from
#'   `unparsed_date_cells()`), `formula_cells` (from `formula_like_cells()`),
#'   `formula_cells_unmapped` (the same check on the unmapped raw columns),
#'   `zero_count_rows` (count 0 with a blank occurrenceStatus),
#'   `coord_invalid_rows` (a coordinate the export cannot read, after the
#'   accepted corrections), `coord_flags` (Coordinates-tab flags with no
#'   correction, NULL when the tab did not run), `preview_problems_n`,
#'   `all_required_present`, `export_blocked`, and `files`
#'   (list `dwca` + `auxiliary`).
#' @noRd
build_export_summary <- function(mapped_data,
                                 name_review_payload = NULL,
                                 coords_correction_payload = NULL,
                                 country_fill_payload = NULL,
                                 sensitivity_payload = NULL,
                                 generalization_payload = NULL,
                                 dataset_name = NULL,
                                 coord_validation = NULL,
                                 preview_problems_n = NULL,
                                 raw_data = NULL,
                                 map_values = NULL,
                                 overridden_terms = character(0)) {
    df <- if (is.data.frame(mapped_data)) mapped_data else data.frame()
    n_records <- nrow(df)
    term_count <- ncol(df)

    nrows_of <- function(x) if (is.data.frame(x)) nrow(x) else 0L
    slot <- function(payload, name) {
        if (is.list(payload) && !is.null(payload[[name]])) payload[[name]] else NULL
    }

    # --- Corrections -------------------------------------------------------
    name_entries <- slot(name_review_payload, "entries")
    review_type <- if (is.data.frame(name_entries) && "review_type" %in% names(name_entries)) {
        as.character(name_entries$review_type)
    } else {
        character(0)
    }
    corrections <- list(
        names_corrected = sum(review_type == "correct"),
        names_confirmed = sum(review_type == "confirm"),
        coord_fixes = nrows_of(slot(coords_correction_payload, "corrections")),
        # Fixes the Coordinates tab dropped: the point changed after the fix.
        coord_fixes_stale = as.integer(slot(coords_correction_payload, "stale") %||% 0L),
        country_fills = nrows_of(slot(country_fill_payload, "country"))
    )

    # --- Generalization (only species actually generalized) ----------------
    masking_tiers <- c("extreme", "high", "medium", "low")
    gen <- data.frame(
        scientificName = character(0), category = character(0),
        tier = character(0), stringsAsFactors = FALSE
    )
    gp <- generalization_payload
    if (is.list(gp) && isTRUE(gp$enabled) && length(gp$levels) > 0L) {
        lv <- gp$levels
        keep <- !is.na(lv) & lv %in% masking_tiers
        sp <- names(lv)[keep]
        if (length(sp) > 0L) {
            # The levels carry the corrected names (AUD-01).
            cats <- tryCatch(
                sensitive_resolve(
                    sp, rekey_sensitivity_decisions(sensitivity_payload, name_review_payload)
                )$category,
                error = function(e) rep(NA_character_, length(sp))
            )
            cats[is.na(cats) | !nzchar(cats)] <- "\u2014"
            gen <- data.frame(
                scientificName = sp, category = cats,
                tier = unname(lv[keep]), stringsAsFactors = FALSE
            )
            gen <- gen[order(gen$scientificName), , drop = FALSE]
            rownames(gen) <- NULL
        }
    }

    # --- Readiness (required DwC terms present and non-empty) ---------------
    required <- c(
        "scientificName", "eventDate", "decimalLatitude",
        "decimalLongitude", "basisOfRecord", "license"
    )
    term_present <- function(term) {
        term %in% names(df) &&
            any(!is.na(df[[term]]) & nzchar(trimws(as.character(df[[term]]))))
    }
    present <- vapply(required, term_present, logical(1))
    readiness <- data.frame(
        term = required, present = unname(present), stringsAsFactors = FALSE
    )
    all_required_present <- all(present)
    readiness_pct <- if (length(present) == 0L) {
        0L
    } else {
        as.integer(round(100 * sum(present) / length(present)))
    }
    missing_required <- required[!present]
    occurrence_id_present <- term_present("occurrenceID")

    # GBIF needs basisOfRecord on every record. A mapped column can still hold
    # values with no DwC term (e.g. "Coleta"), which the conversion leaves empty.
    bor_blank_rows <- if ("basisOfRecord" %in% missing_required) {
        integer(0)
    } else {
        bor <- as.character(df[["basisOfRecord"]])
        which(is.na(bor) | !nzchar(trimws(bor)))
    }
    bor_blank_count <- length(bor_blank_rows)
    # One record with no name is enough for GBIF to reject it (AUD-12).
    sci_blank_rows <- if ("scientificName" %in% missing_required) {
        integer(0)
    } else {
        which(is_blank_cell(df[["scientificName"]]))
    }

    # A year outside the plausible range is a typo the format conversion cannot
    # catch, so it is reported here rather than blocking: a historical record
    # can legitimately predate 1600, and only the publisher knows which is which.
    date_issues <- date_year_issues(df)
    # A date the parser could not read goes to GBIF as text, and GBIF then
    # has no event date for the record. The Preview lists these rows.
    date_unparsed <- unparsed_date_cells(df)
    formula_cells <- formula_like_cells(df)
    # The unmapped columns join the file after this check, so they are
    # checked here too (AUD-04). Same call as process_for_export_with_unmapped().
    unmapped <- unmapped_raw_columns(raw_data, map_values, overridden_terms = overridden_terms)
    formula_cells_unmapped <- formula_like_cells(
        if (length(unmapped)) raw_data[, unmapped, drop = FALSE] else NULL
    )
    coords <- coord_export_issues(df, coords_correction_payload, coord_validation)
    # GBIF reads a count of 0 with no occurrenceStatus as an absence (D07).
    # Some field sheets use 0 for "not counted", so the user sees the rows.
    zero_count_rows <- if ("individualCount" %in% names(df)) {
        cnt <- trimws(as.character(df[["individualCount"]]))
        status <- if ("occurrenceStatus" %in% names(df)) {
            as.character(df[["occurrenceStatus"]])
        } else {
            rep(NA_character_, n_records)
        }
        which(!is.na(cnt) & grepl("^0+$", cnt) & (is.na(status) | !nzchar(trimws(status))))
    } else {
        integer(0)
    }

    # Generalization to Category 1/2/3 needs a written justification; export is
    # blocked until it is provided (mirrors the download handler's hard gate).
    justification_pending <- is.list(gp) && isTRUE(gp$enabled) &&
        isTRUE(gp$needs_justification) &&
        !nzchar(trimws(gp$justification %||% ""))
    # A formula cell runs when a person opens occurrence.txt in a spreadsheet,
    # and a coordinate out of range is not a point: both block (B50, B55).
    export_blocked <- !all_required_present || bor_blank_count > 0L ||
        length(sci_blank_rows) > 0L || justification_pending ||
        isTRUE(formula_cells$count > 0L) || isTRUE(formula_cells_unmapped$count > 0L) ||
        length(coords$invalid_rows) > 0L

    # --- Files the bundle will contain -------------------------------------
    # Single source of truth shared with the download handler. The private
    # real-coordinates file exists only when a species is generalized.
    files <- export_bundle_filenames(
        dataset_name = dataset_name,
        has_sensitive = nrow(gen) > 0L,
        n_records = n_records
    )

    list(
        record_count = n_records,
        term_count = term_count,
        corrections = corrections,
        generalization = gen,
        readiness = readiness,
        readiness_pct = readiness_pct,
        missing_required = missing_required,
        occurrence_id_present = occurrence_id_present,
        bor_blank_count = bor_blank_count,
        bor_blank_rows = bor_blank_rows,
        sci_blank_rows = sci_blank_rows,
        justification_pending = justification_pending,
        date_issues = date_issues,
        date_unparsed = date_unparsed,
        formula_cells = formula_cells,
        formula_cells_unmapped = formula_cells_unmapped,
        zero_count_rows = zero_count_rows,
        coord_invalid_rows = coords$invalid_rows,
        coord_flags = coords$flags,
        preview_problems_n = as.integer(preview_problems_n %||% 0L),
        all_required_present = all_required_present,
        export_blocked = export_blocked,
        files = files
    )
}

# The coordinate rows Export reports (B50). `invalid_rows`: a coordinate that
# is not a number in range once the corrections of the Coordinates tab are
# applied, as the Preview flags it. `flags`: the rows the Coordinates tab
# flagged (sea, (0, 0), reference point) and nobody corrected. A blank
# coordinate is not a flag, and out-of-range rows are already in `invalid_rows`.
coord_export_issues <- function(df, coords_correction_payload = NULL, coord_validation = NULL) {
    out <- list(invalid_rows = integer(0), flags = NULL)
    axes <- c(decimalLatitude = 90, decimalLongitude = 180)
    if (!is.data.frame(df) || nrow(df) == 0L || !all(names(axes) %in% names(df))) {
        return(out)
    }
    fixed <- tryCatch(apply_coords_correction_payload(df, coords_correction_payload),
                      error = function(e) df)
    bad <- rep(FALSE, nrow(df))
    for (term in names(axes)) {
        v <- trimws(as.character(fixed[[term]]))
        v[is.na(v)] <- ""
        bad <- bad | (nzchar(v) & !coord_value_ok(v, axes[[term]]))
    }
    out$invalid_rows <- which(bad)

    cv <- coord_validation
    if (is.data.frame(cv) && all(c(".row_index", "diagnostic_family") %in% names(cv))) {
        idx <- as.integer(cv$.row_index)
        fam <- as.character(cv$diagnostic_family)
        keep <- !is.na(idx) & idx >= 1L & idx <= nrow(df) &
            !is.na(fam) & fam %in% c("sea", "zero_equal", "reference")
        rows <- sort(unique(idx[keep]))
        corrected <- as.character(slot_df(coords_correction_payload, "corrections")$occurrenceID)
        if (length(corrected) && "occurrenceID" %in% names(df)) {
            rows <- rows[!as.character(df$occurrenceID[rows]) %in% corrected]
        }
        rows <- setdiff(rows, out$invalid_rows)
        out$flags <- list(count = length(rows), rows = rows)
    }
    out
}

slot_df <- function(payload, name) {
    x <- if (is.list(payload)) payload[[name]] else NULL
    if (is.data.frame(x)) x else data.frame(occurrenceID = character(0))
}

# Row numbers for a pending item: the first ones, then how many more.
format_row_list <- function(rows, max_n = 10L) {
    shown <- paste(utils::head(rows, max_n), collapse = ", ")
    extra <- length(rows) - max_n
    if (extra > 0L) paste0(shown, " (+", extra, ")") else shown
}
