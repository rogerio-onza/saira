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
    coords_correction_payload <- drop_stale_coord_corrections(coords_correction_payload, df)
    country_fill_payload <- reconcile_country_fill(country_fill_payload, df)
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

    effective <- prepare_effective_records(df, name_review_payload,
                                            coords_correction_payload, country_fill_payload)
    assessment <- assess_publication(effective, gp, raw_data, map_values,
                                     overridden_terms, coord_validation,
                                     drop_stale_coord_corrections(coords_correction_payload, df))
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
        readiness = assessment$readiness,
        readiness_pct = assessment$readiness_pct,
        missing_required = assessment$missing_required,
        occurrence_id_present = assessment$occurrence_id_present,
        bor_blank_count = assessment$bor_blank_count,
        bor_blank_rows = assessment$bor_blank_rows,
        sci_blank_rows = assessment$sci_blank_rows,
        justification_pending = assessment$justification_pending,
        date_issues = assessment$date_issues,
        date_unparsed = assessment$date_unparsed,
        formula_cells = assessment$formula_cells,
        formula_cells_unmapped = assessment$formula_cells_unmapped,
        zero_count_rows = assessment$zero_count_rows,
        coord_invalid_rows = assessment$coord_invalid_rows,
        coord_flags = assessment$coord_flags,
        preview_problems_n = as.integer(preview_problems_n %||% 0L),
        all_required_present = assessment$all_required_present,
        export_blocked = assessment$export_blocked,
        files = files
    )
}


# Row numbers for a pending item: the first ones, then how many more.
format_row_list <- function(rows, max_n = 10L) {
    shown <- paste(utils::head(rows, max_n), collapse = ", ")
    extra <- length(rows) - max_n
    if (extra > 0L) paste0(shown, " (+", extra, ")") else shown
}
