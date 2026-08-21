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
#'   coordinates), or NULL.
#' @param country_fill_payload List with `country` (occurrenceID + filled country),
#'   or NULL.
#' @param sensitivity_payload Per-species sensitivity marks (for the threat
#'   category), or NULL.
#' @param generalization_payload List `{ levels, enabled, ... }` from the
#'   Generalization stage, or NULL.
#' @param dataset_name Dataset name (the `datasetName` constant), used to name
#'   the auxiliary bundle files. NULL falls back to a generic slug.
#' @return Named list: `record_count`, `term_count`, `corrections`
#'   (`names_corrected`/`names_confirmed`/`coord_fixes`/`country_fills`),
#'   `generalization` (data.frame `scientificName`/`category`/`tier`),
#'   `readiness` (data.frame `term`/`present`), `readiness_pct`,
#'   `missing_required`, `occurrence_id_present`, `justification_pending`,
#'   `date_issues` (from `date_year_issues()`),
#'   `all_required_present`, `export_blocked`, and `files`
#'   (list `dwca` + `auxiliary`).
#' @noRd
build_export_summary <- function(mapped_data,
                                 name_review_payload = NULL,
                                 coords_correction_payload = NULL,
                                 country_fill_payload = NULL,
                                 sensitivity_payload = NULL,
                                 generalization_payload = NULL,
                                 dataset_name = NULL) {
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
            cats <- tryCatch(
                sensitive_resolve(sp, sensitivity_payload)$category,
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
        "decimalLongitude", "basisOfRecord"
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

    # A year outside the plausible range is a typo the format conversion cannot
    # catch, so it is reported here rather than blocking: a historical record
    # can legitimately predate 1600, and only the publisher knows which is which.
    date_issues <- date_year_issues(df)

    # Generalization to Category 1/2/3 needs a written justification; export is
    # blocked until it is provided (mirrors the download handler's hard gate).
    justification_pending <- is.list(gp) && isTRUE(gp$enabled) &&
        isTRUE(gp$needs_justification) &&
        !nzchar(trimws(gp$justification %||% ""))
    export_blocked <- !all_required_present || justification_pending

    # --- Files the bundle will contain -------------------------------------
    # Single source of truth shared with the download handler. The real-coords
    # CSV only ships when a species is actually generalized.
    files <- export_bundle_filenames(
        dataset_name = dataset_name,
        has_sensitive = nrow(gen) > 0L
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
        justification_pending = justification_pending,
        date_issues = date_issues,
        all_required_present = all_required_present,
        export_blocked = export_blocked,
        files = files
    )
}
