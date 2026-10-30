# Publication transformations. Network enrichment is supplied by the caller.
# Order: name review -> rank -> coordinates -> country -> sensitivity -> mask.
# Final normalization/unmapped columns follow enrichment in the download handler.

prepare_effective_records <- function(data, name_payload = NULL, coords_payload = NULL,
                                      country_payload = NULL) {
    apply_validation_payloads(data, name_payload, coords_payload, country_payload)
}

prepare_publication_records <- function(data, name_payload = NULL, coords_payload = NULL,
                                        country_payload = NULL, sensitivity = NULL,
                                        generalization = NULL, lang = "pt") {
    effective <- prepare_effective_records(data, name_payload, coords_payload, country_payload)
    levels <- generalization$levels %||% stats::setNames(character(0), character(0))
    mask_sensitive_coordinates(
        effective, decisions = rekey_sensitivity_decisions(sensitivity, name_payload),
        generalization = levels, enabled = isTRUE(generalization$enabled), lang = lang,
        justification = generalization$justification
    )
}

publication_metadata <- function(data, private_records, generalization = NULL, lang = "pt",
                                 today = Sys.Date()) {
    metadata <- list()
    # The EML license and title are what the user chose in the mapping
    # (constant card or mapped column), not the CC0 default or "Saira export".
    # A mapped column with more than one value gives its most frequent one.
    for (entry in c(license = "license", title = "datasetName")) {
        if (!entry %in% names(data)) next
        values <- trimws(as.character(data[[entry]]))
        values <- values[!is.na(values) & nzchar(values)]
        if (length(values)) {
            key <- if (entry == "license") "license" else "title"
            metadata[[key]] <- names(sort(table(values), decreasing = TRUE))[[1L]]
        }
    }
    # Record the dataset-level access constraint (Chapman sec. 5.1) in the EML
    # when any record was generalized.
    if (is.data.frame(private_records) && nrow(private_records) > 0L) {
        review_date <- generalization$review_date
        if (is.null(review_date) || !length(review_date)) review_date <- today + 730
        metadata$sensitivity <- list(
            n_masked = nrow(private_records),
            review_date = format(as.Date(review_date), "%Y-%m-%d"), lang = lang
        )
    }
    metadata
}

# Column presence, per-record values and generated IDs are distinct policies.
publication_required_terms <- function() c(
    "scientificName", "eventDate", "decimalLatitude", "decimalLongitude", "basisOfRecord", "license"
)

assess_publication <- function(data, generalization = NULL, raw_data = NULL,
                               map_values = NULL, overridden_terms = character(0),
                               coord_validation = NULL, coords_correction_payload = NULL) {
    df <- if (is.data.frame(data)) data else data.frame()
    n_records <- nrow(df)
    gp <- generalization
    # --- Readiness (required DwC terms present and non-empty) ---------------
    required <- publication_required_terms()
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

    list(
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
        all_required_present = all_required_present,
        export_blocked = export_blocked,
        coord_invalid_rows = coords$invalid_rows, coord_flags = coords$flags
    )
}

# Reconcile only records with a source snapshot; legacy payloads keep their contract.
reconcile_country_fill <- function(payload, data) {
    rows <- if (is.list(payload)) payload$country else NULL
    if (!is.data.frame(rows)) return(payload)
    stale <- stale_coord_rows(rows, data)
    payload$country <- rows[!stale, , drop = FALSE]
    payload$stale <- as.integer(payload$stale %||% 0L) + sum(stale)
    payload
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

#' Apply the validation payloads in export order
#'
#' The Generalization tab and the download both read the data through this
#' function, so the tab assesses the names and points the export writes
#' (AUD-01).
#'
#' @param df Data frame to export.
#' @param name_payload Names-tab payload (`entries`, `ranks`, `normalize_opts`).
#' @param coords_payload Coordinates-tab correction payload.
#' @param country_payload Coordinates-tab country-fill payload.
#' @return `df` with the name reviews, ranks, coordinate corrections and
#'   country fills applied.
#' @noRd
apply_validation_payloads <- function(df, name_payload = NULL, coords_payload = NULL,
                                      country_payload = NULL) {
    coords_payload <- drop_stale_coord_corrections(coords_payload, df)
    country_payload <- reconcile_country_fill(country_payload, df)
    df <- apply_name_review_payload(df, payload = name_payload)
    df <- apply_name_rank_payload(df, name_payload$ranks)
    df <- apply_coords_correction_payload(df, coords_payload)
    apply_country_fill_payload(df, country_payload)
}
