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
#' @param rows_left_out Rows of exact copies the Preview left out of the
#'   package. They do not count as records.
#' @param preview_changes `cell_changes()` of the Preview edits, or NULL.
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
#'   `all_required_present`, `export_blocked`, `changes`
#'   (`build_change_log()`), and `files` (list `dwca` + `auxiliary`).
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
                                 overridden_terms = character(0),
                                 rows_left_out = integer(0),
                                 preview_changes = NULL) {
    df <- if (is.data.frame(mapped_data)) mapped_data else data.frame()
    coords_correction_payload <- drop_stale_coord_corrections(coords_correction_payload, df)
    country_fill_payload <- reconcile_country_fill(country_fill_payload, df)
    rows_left_out <- intersect(as.integer(rows_left_out), seq_len(nrow(df)))
    n_records <- nrow(df) - length(rows_left_out)
    # The per-column measurement columns are one term, measurementValue.
    value_cols <- names(df)[is_measurement_value_term(names(df))]
    term_count <- length(unique(replace(names(df), names(df) %in% value_cols, "measurementValue")))

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
    changes <- build_change_log(df, effective, preview_changes,
                                generalized_record_rows(effective, gp), rows_left_out)
    # --- Files the bundle will contain -------------------------------------
    # Single source of truth shared with the download handler. The private
    # real-coordinates file exists only when a species is generalized.
    values <- trimws(unlist(lapply(df[value_cols], as.character), use.names = FALSE))
    files <- export_bundle_filenames(
        dataset_name = dataset_name,
        has_sensitive = nrow(gen) > 0L,
        n_records = n_records,
        has_changes = nrow(changes) > 0L,
        has_measurements = "occurrenceID" %in% names(df) && any(!is.na(values) & nzchar(values))
    )

    list(
        record_count = n_records,
        rows_left_out = rows_left_out,
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
        changes = changes,
        files = files
    )
}


# Row numbers for a pending item: the first ones, then how many more.
format_row_list <- function(rows, max_n = 10L) {
    shown <- paste(utils::head(rows, max_n), collapse = ", ")
    extra <- length(rows) - max_n
    if (extra > 0L) paste0(shown, " (+", extra, ")") else shown
}

# The cells that differ between two frames with the same rows, for `terms`.
# A blank cell and NA are the same value. Returns `row`, `term`, `from`, `to`.
cell_changes <- function(before, after, terms) {
    none <- data.frame(row = integer(0), term = character(0), from = character(0),
                       to = character(0), stringsAsFactors = FALSE)
    if (!is.data.frame(before) || !is.data.frame(after) || nrow(before) != nrow(after)) {
        return(none)
    }
    text <- function(v) {
        v <- trimws(as.character(v))
        v[is.na(v)] <- ""
        v
    }
    out <- lapply(intersect(intersect(terms, names(before)), names(after)), function(term) {
        from <- text(before[[term]])
        to <- text(after[[term]])
        hit <- which(from != to)
        data.frame(row = hit, term = rep(term, length(hit)), from = from[hit], to = to[hit],
                   stringsAsFactors = FALSE)
    })
    if (!length(out)) return(none)
    do.call(rbind, c(list(none), out))
}

# Rows of the species the Generalization tab masks. The change list hides
# their values, so it never shows a real point.
generalized_record_rows <- function(df, generalization_payload) {
    gp <- generalization_payload
    if (!is.data.frame(df) || !"scientificName" %in% names(df) ||
        !is.list(gp) || !isTRUE(gp$enabled) || !length(gp$levels)) {
        return(integer(0))
    }
    lv <- gp$levels
    species <- names(lv)[!is.na(lv) & lv %in% c("extreme", "high", "medium", "low")]
    which(trimws(as.character(df$scientificName)) %in% species)
}

change_kinds <- c("names", "coordinates", "country", "preview")

#' List the corrections an export applies, one row per changed cell
#'
#' @param data Darwin Core frame after the Preview edits, before the
#'   validation corrections.
#' @param effective `data` with the name, coordinate and country corrections
#'   (`prepare_effective_records()`).
#' @param preview_changes `cell_changes()` of the Preview edits, or NULL.
#' @param hidden_rows Rows of generalized records. Their values are blank,
#'   except scientificName and country.
#' @param rows_left_out Exact copies left out of the package.
#' @return Data frame `row`, `occurrenceID`, `kind` (one of `change_kinds`),
#'   `term`, `from`, `to`, `generalized`.
#' @noRd
build_change_log <- function(data, effective, preview_changes = NULL,
                             hidden_rows = integer(0), rows_left_out = integer(0)) {
    parts <- list(
        names = cell_changes(data, effective, "scientificName"),
        coordinates = cell_changes(data, effective, c("decimalLatitude", "decimalLongitude")),
        country = cell_changes(data, effective, "country"),
        preview = if (is.data.frame(preview_changes)) preview_changes else cell_changes(NULL, NULL, character(0))
    )
    log <- do.call(rbind, lapply(names(parts), function(kind) {
        p <- parts[[kind]][, c("row", "term", "from", "to"), drop = FALSE]
        p$kind <- rep(kind, nrow(p))
        p
    }))
    log <- log[!log$row %in% rows_left_out, , drop = FALSE]
    ids <- if (is.data.frame(effective) && "occurrenceID" %in% names(effective)) {
        as.character(effective$occurrenceID)
    } else {
        character(0)
    }
    log$occurrenceID <- ids[log$row]
    log$generalized <- log$row %in% hidden_rows
    hide <- log$generalized & !log$term %in% c("scientificName", "country")
    log$from[hide] <- ""
    log$to[hide] <- ""
    log <- log[order(log$row, match(log$kind, change_kinds)),
               c("row", "occurrenceID", "kind", "term", "from", "to", "generalized"), drop = FALSE]
    rownames(log) <- NULL
    log
}

# The records each kind changed, and one example of each kind: the first
# record whose values the list shows.
change_examples <- function(log) {
    kinds <- intersect(change_kinds, log$kind)
    lapply(stats::setNames(kinds, kinds), function(kind) {
        k <- log[log$kind == kind, , drop = FALSE]
        open <- k[!k$generalized | k$term %in% c("scientificName", "country"), , drop = FALSE]
        example <- if (nrow(open)) open[open$row == open$row[1L], , drop = FALSE]
        list(records = length(unique(k$row)), example = example)
    })
}

# A corrected formula cell keeps its old value in `from`. The leading quote
# stops a spreadsheet from running it.
write_change_log_csv <- function(log, path) {
    for (col in c("from", "to")) {
        hit <- is_formula_like(log[[col]])
        log[[col]][hit] <- paste0("'", log[[col]][hit])
    }
    readr::write_csv(log, path, na = "")
}
