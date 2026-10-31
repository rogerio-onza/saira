# Export product: every step between the captured export inputs and the files
# of the bundle. The download handler keeps only the file writes, the progress
# modal and the alias commit (SP-08).
#
# `inputs` is a named list, read once by the module (`capture_sources()`):
# download_data, name_review, coords_correction, country_fill, sensitivity,
# generalization, raw_data, map_values, custom_values, rows_left_out,
# preview_changes, conservation, measurement_specs, occurrence_id_info.
# A missing slot is an absent source.

# The steps both downloads share. The private file must hold the same real
# points that the bundle generalizes.
prepare_masked_export <- function(inputs, lang = "en") {
    data <- inputs$download_data
    gen <- inputs$generalization
    # Generalization to Category 1/2/3 needs a written reason. The summary
    # blocks the same case, this is the last gate before a file exists.
    if (is.list(gen) && isTRUE(gen$enabled) &&
        isTRUE(gen$needs_justification) &&
        !nzchar(trimws(gen$justification %||% ""))) {
        stop(tr("preview_export_needs_justification", lang), call. = FALSE)
    }
    effective <- prepare_effective_records(
        data, inputs$name_review, inputs$coords_correction, inputs$country_fill
    )
    # Masks before process_for_export_with_unmapped(): that step turns the
    # coordinates into numbers, "-19.900" loses its trailing zeros, and the
    # precision clamp then picks a coarser grid than the Generalization tab shows.
    masked <- prepare_publication_records(
        effective,
        sensitivity = rekey_sensitivity_decisions(inputs$sensitivity, inputs$name_review),
        generalization = gen, lang = lang
    )
    # Exact copies the Preview left out. The rows go after the unmapped
    # columns join, which match the upload by row.
    drop <- intersect(as.integer(inputs$rows_left_out %||% integer(0)), seq_len(nrow(effective)))
    if (length(drop) && nrow(masked$real)) {
        ids <- if ("occurrenceID" %in% names(effective)) {
            as.character(effective$occurrenceID)
        } else {
            as.character(seq_len(nrow(effective)))
        }
        masked$real <- masked$real[!masked$real$occurrenceID %in% ids[drop], , drop = FALSE]
    }
    changes <- build_change_log(
        data, effective, inputs$preview_changes,
        union(masked$rows, generalized_record_rows(effective, gen)), drop
    )
    list(masked = masked, gen = gen, drop = drop, changes = changes)
}

# The full product: core, measurements, real points, change log, EML metadata
# and the mapping guide text. Stops when a formula cell remains after the
# enrichment, because the file would run it in a spreadsheet.
prepare_export_product <- function(inputs, lang = "en") {
    prep <- prepare_masked_export(inputs, lang)
    masked <- prep$masked
    raw_df <- inputs$raw_data %||% data.frame()
    mv <- inputs$map_values %||% list()
    cv <- inputs$custom_values %||% list()

    # Conservation status (MMA and/or IUCN) in dynamicProperties, on the
    # corrected names and after the country fill. After the mask, so a
    # generalized row outside Brazil still gets the MMA category its
    # dataGeneralizations cites. The GBIF IUCN call degrades to NA on failure.
    masked$masked <- apply_conservation_status(
        masked$masked, inputs$conservation,
        generalized = seq_len(nrow(masked$masked)) %in% masked$rows
    )
    core <- process_for_export_with_unmapped(
        masked$masked,
        raw_data = raw_df,
        map_values = mv,
        overridden_terms = overridden_mapping_terms(cv),
        sensitive_rows = masked$scrub_rows,
        sensitive_points = masked$scrub_points
    )
    if (length(prep$drop)) {
        id_attr <- attr(core, "id_strategy")
        core <- core[-prep$drop, , drop = FALSE]
        rownames(core) <- NULL
        attr(core, "id_strategy") <- id_attr
    }

    # GBIF reads no measurement term in the core, so the measurements go to
    # their own extension file.
    value_column <- if ("measurementValue" %in% overridden_mapping_terms(cv)) {
        NULL
    } else {
        map_value_sources(mv["measurementValue"])[1L]
    }
    mof <- split_measurements(core, value_column, inputs$measurement_specs)
    core <- mof$core
    if (formula_like_cells(core)$count > 0L ||
        formula_like_cells(mof$measurements)$count > 0L) {
        stop(tr("export_download_blocked", lang), call. = FALSE)
    }

    # The mapping stage resolves the identifiers, so only it knows how many
    # came from the user's data. The attribute of the core only ever reported
    # "user_supplied", because by then the column is always full.
    id_info <- inputs$occurrence_id_info
    id_strategy <- id_info$strategy %||% attr(core, "id_strategy")
    if (is.null(id_strategy)) id_strategy <- NA_character_
    # The Preview replaces the ids that still repeat after its corrections (ADR-152).
    id_counts <- occurrence_id_counts_after_repeats(
        id_info$counts, attr(inputs$download_data, "ids_replaced")
    )
    if (!identical(id_counts, id_info$counts)) {
        id_strategy <- occurrence_id_strategy_label(id_counts$preserved, id_counts$total)
    }

    list(
        core = core,
        measurements = mof$measurements,
        real = masked$real,
        changes = prep$changes,
        metadata = publication_metadata(core, masked$real, prep$gen, lang),
        mapping_guide = build_mapping_guide_txt(
            mv, raw_df,
            lang = lang,
            id_strategy = id_strategy,
            constants = cv,
            id_counts = id_counts,
            source_file = attr(raw_df, "source_file") %||% NA_character_
        ),
        dataset_name = cv$datasetName
    )
}
