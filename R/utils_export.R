# Title: Export Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

#' Apply manual name-review payload to export data
#'
#' @param df Data frame to export
#' @param payload Optional list with `entries` and `normalize_opts`
#' @return Data frame with review columns and optional scientificName replacements
#' @export
apply_name_review_payload <- function(df, payload = NULL) {
    if (!is.data.frame(df)) {
        warning("apply_name_review_payload: 'df' must be a data.frame, got ", class(df)[1L])
        return(df)
    }

    out <- df
    n_rows <- nrow(out)

    # ADR-088 (reverte ADR-051): audit columns `validacao_manual` e
    # `motivo_revisao` NAO sao mais emitidas no export. Correcoes feitas via
    # revisao manual de nomes ainda sao aplicadas silenciosamente ao
    # `scientificName` (replacement abaixo); a rastreabilidade vai pelo
    # `mapping_guide.txt` do bundle.
    if (n_rows == 0L) {
        return(out)
    }
    if (!("scientificName" %in% names(out))) {
        return(out)
    }
    if (is.null(payload) || !is.list(payload) || is.null(payload$entries) || !is.data.frame(payload$entries)) {
        return(out)
    }

    entries <- payload$entries
    required_cols <- c("query_name", "review_type", "original_name", "corrected_name", "reason", "reviewed_at")
    for (col_name in required_cols) {
        if (!(col_name %in% names(entries))) {
            if (identical(col_name, "reviewed_at")) {
                entries[[col_name]] <- as.POSIXct(character(nrow(entries)), tz = "UTC")
            } else {
                entries[[col_name]] <- rep("", nrow(entries))
            }
        }
    }

    entries <- entries[, required_cols, drop = FALSE]
    entries$query_name <- as.character(entries$query_name)
    entries$review_type <- tolower(as.character(entries$review_type))
    entries$original_name <- as.character(entries$original_name)
    entries$corrected_name <- as.character(entries$corrected_name)
    entries$reason <- as.character(entries$reason)
    entries$reviewed_at <- as.POSIXct(entries$reviewed_at, tz = "UTC")

    keep <- !is.na(entries$query_name) &
        nzchar(entries$query_name) &
        entries$review_type %in% c("confirm", "correct")
    entries <- entries[keep, , drop = FALSE]
    if (nrow(entries) == 0L) {
        return(out)
    }

    ord <- order(entries$query_name, entries$reviewed_at, seq_len(nrow(entries)), na.last = TRUE)
    entries <- entries[ord, , drop = FALSE]
    entries <- entries[!duplicated(entries$query_name, fromLast = TRUE), , drop = FALSE]

    normalize_opts <- payload$normalize_opts
    remove_authors_opt <- TRUE
    ignore_qualifiers_opt <- TRUE
    if (is.list(normalize_opts)) {
        if (is.logical(normalize_opts$remove_authors) && length(normalize_opts$remove_authors) == 1L && !is.na(normalize_opts$remove_authors)) {
            remove_authors_opt <- isTRUE(normalize_opts$remove_authors)
        }
        if (is.logical(normalize_opts$ignore_qualifiers) && length(normalize_opts$ignore_qualifiers) == 1L && !is.na(normalize_opts$ignore_qualifiers)) {
            ignore_qualifiers_opt <- isTRUE(normalize_opts$ignore_qualifiers)
        }
    }

    scientific_name <- as.character(out$scientificName)
    scientific_name[is.na(scientific_name)] <- ""

    # Optimize: normalize only unique names to avoid redundant work on repeated values
    unique_names <- unique(scientific_name)
    unique_normalized <- vapply(unique_names, function(value) {
        normalized <- normalize_scientific_name(
            value,
            remove_authors = remove_authors_opt,
            ignore_qualifiers = ignore_qualifiers_opt
        )
        if (is.na(normalized) || !nzchar(normalized)) {
            trimws(as.character(value))
        } else {
            normalized
        }
    }, FUN.VALUE = character(1))
    query_name <- unique_normalized[match(scientific_name, unique_names)]

    match_idx <- match(query_name, entries$query_name)
    has_review <- !is.na(match_idx)
    if (!any(has_review)) {
        return(out)
    }

    review_type_vec <- rep("", n_rows)
    review_type_vec[has_review] <- entries$review_type[match_idx[has_review]]

    correct_mask <- has_review & review_type_vec == "correct"
    if (any(correct_mask)) {
        correct_idx <- match_idx[correct_mask]
        corrected_name <- trimws(as.character(entries$corrected_name[correct_idx]))
        original_name <- trimws(as.character(entries$original_name[correct_idx]))
        current_name <- as.character(out$scientificName[correct_mask])
        replacement <- corrected_name
        replacement[is.na(replacement) | !nzchar(replacement)] <- original_name[is.na(replacement) | !nzchar(replacement)]
        replacement[is.na(replacement) | !nzchar(replacement)] <- current_name[is.na(replacement) | !nzchar(replacement)]
        out$scientificName[correct_mask] <- replacement
    }

    out
}

#' Append conservation-status entries to dynamicProperties on export
#'
#' Additively folds each selected provider's conservation status into the
#' `dynamicProperties` column (creating it when absent): the Brazilian MMA
#' category plus its portaria source when a BR provider was selected, and/or the
#' global IUCN Red List code from GBIF when GBIF was selected. The two sources
#' are independent — a taxon can receive both, or only the MMA keys when GBIF
#' does not assess it. The GBIF lookup is optional and non-blocking: any failure
#' simply omits the IUCN key and never breaks the export. Runs after
#' [apply_name_review_payload()] so it sees the corrected `scientificName`.
#'
#' @param df Data frame to export (post name review).
#' @param payload Optional list with `include_mma`, `include_iucn` (logical) and
#'   `taxon_keys` (data.frame of `scientificName`, `taxonID`, `provider`).
#' @return `df` with an updated `dynamicProperties` column.
#' @keywords internal
#' @noRd
apply_conservation_status <- function(df, payload = NULL) {
    if (!is.data.frame(df) || nrow(df) == 0L ||
        !("scientificName" %in% names(df)) ||
        is.null(payload) || !is.list(payload)) {
        return(df)
    }
    include_mma <- isTRUE(payload$include_mma)
    include_iucn <- isTRUE(payload$include_iucn)
    if (!include_mma && !include_iucn) {
        return(df)
    }

    names_vec <- as.character(df$scientificName)
    had_column <- "dynamicProperties" %in% names(df)
    dynprops <- df[["dynamicProperties"]]
    if (is.null(dynprops)) {
        dynprops <- rep("", nrow(df))
    }

    # Each source is wrapped independently so a failure in one (e.g. the GBIF
    # network) never blocks the export nor drops the other source's keys.
    if (include_mma) {
        dynprops <- tryCatch(
            {
                dp <- merge_dynamic_property(
                    dynprops, "mmaThreatStatus", sensitive_category_for(names_vec)
                )
                merge_dynamic_property(
                    dp, "mmaSource", sensitive_source_for(names_vec)
                )
            },
            error = function(e) {
                warning("apply_conservation_status: MMA skipped (", conditionMessage(e), ")")
                dynprops
            }
        )
    }

    if (include_iucn) {
        dynprops <- tryCatch(
            {
                usage_keys <- resolve_iucn_usage_keys(names_vec, payload$taxon_keys)
                merge_dynamic_property(
                    dynprops, "iucnRedListCategory",
                    fetch_gbif_iucn_category(usage_keys)
                )
            },
            error = function(e) {
                warning("apply_conservation_status: IUCN skipped (", conditionMessage(e), ")")
                dynprops
            }
        )
    }

    # Keep an already-mapped column even if nothing merged; but do not create a
    # spurious all-empty column when no taxon matched and none was mapped.
    if (had_column || any(nzchar(dynprops))) {
        df[["dynamicProperties"]] <- dynprops
    }
    df
}

# GBIF usage keys for the IUCN lookup. Prefer the taxonID taxadb already resolved
# for rows GBIF matched (stripping any "GBIF:" prefix to the bare numeric key),
# and fall back to the keyless match endpoint for the rest (BR-resolved rows or
# manual renames).
resolve_iucn_usage_keys <- function(names_vec, taxon_keys) {
    n <- length(names_vec)
    keys <- rep(NA_character_, n)
    if (is.data.frame(taxon_keys) && nrow(taxon_keys) > 0L &&
        all(c("scientificName", "taxonID", "provider") %in% names(taxon_keys))) {
        is_gbif <- tolower(as.character(taxon_keys$provider)) == "gbif"
        sci <- as.character(taxon_keys$scientificName)[is_gbif]
        bare <- sub("^[^0-9]*", "", as.character(taxon_keys$taxonID)[is_gbif])
        ok <- !is.na(bare) & nzchar(bare) & !is.na(sci) & nzchar(sci)
        sci <- sci[ok]
        bare <- bare[ok]
        if (length(sci) > 0L) {
            keys <- bare[match(names_vec, sci)]
        }
    }
    need <- is.na(keys) & !is.na(names_vec) &
        nzchar(trimws(as.character(names_vec)))
    if (any(need)) {
        keys[need] <- gbif_match_usage_keys(names_vec[need])
    }
    keys
}

#' Process data for DwC-compliant export
#'
#' @param df Data frame with mapped columns
#' @return Data frame with ISO dates, cleaned separators, UUIDs, canonical column order
#' @examples
#' \dontrun{
#'   # Processes mapped data for export (uses taxadb, spatial packages)
#'   processed <- process_for_export(my_mapped_data)
#'   # Returns data with:
#'   # - eventDate in ISO format (YYYY-MM-DD)
#'   # - Coordinate separators normalized (comma -> dot)
#'   # - occurrenceID added if missing
#'   # - License URLs abbreviated
#'   # - Columns reordered to canonical DwC sequence
#' }
#' @export
process_for_export <- function(df) {
    # Fix dates to ISO format
    df <- fix_dates_to_iso(df)

    # Clean coordinate separators (comma to dot)
    df <- clean_coordinate_separators(df)

    # Add occurrence IDs if missing (sets attr "id_strategy")
    df <- add_occurrence_ids(df)
    id_strategy <- attr(df, "id_strategy")

    # Normalize known Creative Commons license URLs to short labels
    df <- abbreviate_license_column(df)

    # Populate geodeticDatum for rows with valid lat/lon (DwC GBIF expectation).
    df <- apply_geodetic_datum(df)

    # Convert countryCode from internal ISO alpha-3 to DwC-required alpha-2.
    # Internal pipeline keeps alpha-3 for CoordinateCleaner compatibility;
    # this is the single export-time boundary that emits alpha-2.
    df <- convert_country_code_to_alpha2(df)

    # Reorder columns to canonical DwC sequence (occurrenceID first,
    # scientificName leading the Taxon block, etc.). Subsetting strips
    # custom attrs, so reattach the id_strategy after.
    df <- order_columns_dwc_canonical(df)
    attr(df, "id_strategy") <- id_strategy

    return(df)
}

#' Append non-mapped raw columns to processed export
#'
#' Wraps process_for_export(): runs the existing pipeline, then appends to
#' the right side any column from `raw_data` that the user did not select
#' as a source for any DwC mapping. Preserves original names and order so
#' the user can hand-edit dropped fields after IPT upload.
#'
#' @param df_processed Data frame already produced by build_processed_mapping_df()
#'   (the DwC-shaped intermediate, BEFORE process_for_export()).
#' @param raw_data Data frame with original uploaded columns.
#' @param map_values Named list keyed by DwC term, values are char vectors of
#'   source column names.
#' @return Data frame: process_for_export(df_processed) + tail of unused raw cols.
#' @export
process_for_export_with_unmapped <- function(df_processed, raw_data, map_values) {
    out <- process_for_export(df_processed)
    id_strategy <- attr(out, "id_strategy")

    if (!is.data.frame(raw_data) || ncol(raw_data) == 0L || !is.list(map_values)) {
        return(out)
    }

    used_sources <- unique(unlist(
        lapply(map_values, function(v) {
            chr <- as.character(unlist(v, recursive = TRUE, use.names = FALSE))
            chr <- chr[!is.na(chr)]
            chr <- trimws(chr)
            chr[nzchar(chr)]
        }),
        use.names = FALSE
    ))

    extra_cols <- setdiff(names(raw_data), used_sources)
    extra_cols <- setdiff(extra_cols, names(out))
    if (length(extra_cols) == 0L) return(out)

    extras <- raw_data[, extra_cols, drop = FALSE]
    combined <- cbind(out, extras)
    attr(combined, "id_strategy") <- id_strategy
    combined
}

#' Write a data frame to .xlsx with every cell forced to text
#'
#' Excel's auto-detection corrupts ISO dates ("2024-01-15" -> "15/01/2024" in
#' PT-BR locale), large numbers (-> scientific notation), and leading zeros
#' (stripped). To survive double-click open and a re-save, every column is
#' coerced to character before writing via writexl.
#'
#' @param df Data frame to write.
#' @param path Destination .xlsx path.
#' @return Invisibly returns `path`.
#' @export
write_xlsx_text_only <- function(df, path) {
    if (!is.data.frame(df)) {
        stop("write_xlsx_text_only: 'df' must be a data.frame.")
    }

    df_text <- as.data.frame(
        lapply(df, function(col) {
            x <- as.character(col)
            x[is.na(x)] <- ""
            x
        }),
        stringsAsFactors = FALSE,
        check.names = FALSE
    )
    names(df_text) <- names(df)

    writexl::write_xlsx(df_text, path = path, format_headers = TRUE)
    invisible(path)
}

#' Build dual-purpose mapping guide TXT (humano + maquina)
#'
#' Texto plano que serve simultaneamente como (a) relatorio legivel para o
#' usuario e (b) entrada importavel pelo upload do Saira. NAO contem dados,
#' apenas o vocabulario "Coluna -> Termo". Cada linha de mapping vira uma
#' row em rostrum_aliases ao re-importar via parse_mapping_guide_txt().
#'
#' Header magico fixo: `# saira:mapping:v1` na primeira linha.
#'
#' @param map_values Named list: nome = termo DwC, valor = char vec de colunas
#'   fonte (multi-coluna serializa como "colA + colB").
#' @param raw_data data.frame original (para listar colunas nao usadas).
#' @param lang Character scalar "pt" ou "en" (ou reactive — extraido com `()` se for).
#' @param required_terms Character vector de termos DwC obrigatorios (default = required do preview).
#' @param source_file Optional character: nome do arquivo de origem para metadados.
#' @param id_strategy Optional character: occurrenceID strategy used at export
#'   (`"user_supplied"`, `"stable_v5"`, `"stable_v5_with_random_fallback"`,
#'   `"random_v4"`). When supplied, an "Identifier Strategy" section is
#'   appended explaining the consequence for GBIF republication.
#' @param constants Optional named list: name = DwC term, value = typed constant
#'   applied to every row. Rendered as the guide's `constants` section.
#' @return character vector (uma entrada por linha), encoding UTF-8.
#' @export
build_mapping_guide_txt <- function(map_values,
                                    raw_data,
                                    lang = "pt",
                                    required_terms = c("scientificName", "eventDate",
                                                       "decimalLatitude", "decimalLongitude",
                                                       "basisOfRecord"),
                                    source_file = NA_character_,
                                    id_strategy = NA_character_,
                                    constants = NULL) {
    if (is.function(lang)) lang <- lang()
    lang <- as.character(lang)[1L]
    if (!lang %in% c("pt", "en")) lang <- "pt"

    if (!is.list(map_values)) map_values <- list()
    if (!is.data.frame(raw_data)) raw_data <- data.frame()
    if (!is.list(constants)) constants <- list()

    # Column mappings: one entry per mapped term (concatenations joined " + ").
    pairs <- list()
    used_sources <- character(0)
    for (term in names(map_values)) {
        cols <- as.character(unlist(map_values[[term]], recursive = TRUE, use.names = FALSE))
        cols <- cols[!is.na(cols)]
        cols <- trimws(cols)
        cols <- cols[nzchar(cols)]
        if (length(cols) == 0L) next
        used_sources <- c(used_sources, cols)
        source_repr <- if (length(cols) == 1L) cols[[1]] else paste(cols, collapse = " + ")
        pairs[[length(pairs) + 1L]] <- list(source = source_repr, term = term)
    }
    used_sources <- unique(used_sources)

    # Constants: typed/selected literal values applied to every row.
    const_pairs <- list()
    for (term in names(constants)) {
        val <- constants[[term]]
        if (is.null(val) || length(val) == 0L) next
        val <- trimws(as.character(val)[[1]])
        if (is.na(val) || !nzchar(val)) next
        const_pairs[[length(const_pairs) + 1L]] <- list(value = val, term = term)
    }

    raw_cols <- names(raw_data)
    unmapped_cols <- setdiff(raw_cols, used_sources)
    mapped_terms <- c(
        vapply(pairs, function(p) p$term, character(1)),
        vapply(const_pairs, function(p) p$term, character(1))
    )
    missing_required <- setdiff(required_terms, mapped_terms)

    n_total <- length(raw_cols)
    n_mapped <- length(used_sources)
    n_unmapped <- length(unmapped_cols)
    n_rows <- if (is.data.frame(raw_data)) nrow(raw_data) else 0L
    n_terms <- length(unique(mapped_terms))
    n_const <- length(const_pairs)

    # Term -> DwC class lookup for grouping (falls back to "Other").
    term_class <- tryCatch({
        dt <- get_dwc_terms()
        stats::setNames(as.character(dt$class), dt$term)
    }, error = function(e) stats::setNames(character(0), character(0)))
    class_of <- function(term) {
        cl <- if (term %in% names(term_class)) term_class[[term]] else NA_character_
        if (is.na(cl) || !nzchar(cl)) "Other" else cl
    }

    L <- if (lang == "pt") {
        list(
            title        = "#   SAIRA \u00b7 Guia de Mapeamento Darwin Core",
            url          = "#   github.com/sibbr/saira",
            tagline      = "#   Vocabulario de mapeamento compartilhavel - sem dados de registros",
            how_to_use   = "#   como usar",
            step_1       = "#     1. Suba seu CSV de dados no Saira e abra a aba Mapeamento.",
            step_2       = "#     2. Na barra lateral, clique em Importar modelo e selecione este .txt.",
            step_3       = "#     3. O mapeamento e reconstruido nos cards (concatenacoes e constantes).",
            step_4       = "#     4. Revise e exporte. (Cada coluna tambem vira um alias pessoal reutilizavel.)",
            section_map  = "#   mapeamentos por classe DwC   (coluna_origem -> termo_DwC)",
            legend       = "#   concatenacoes de colunas sao unidas pelo separador \" | \"",
            section_const= "#   constantes   (valor digitado/escolhido aplicado a todas as linhas)",
            section_miss = "#   termos DwC obrigatorios ainda nao mapeados",
            section_unmp = "#   colunas brutas nao usadas (mantidas no fim do CSV)",
            coverage     = "# cobertura: %d termo(s) DwC mapeado(s), %d constante(s), %d obrigatorio(s) faltando",
            none         = "(nenhum)"
        )
    } else {
        list(
            title        = "#   SAIRA \u00b7 Darwin Core Mapping Guide",
            url          = "#   github.com/sibbr/saira",
            tagline      = "#   Shareable mapping vocabulary - contains no record data",
            how_to_use   = "#   how to use",
            step_1       = "#     1. Upload your data CSV in Saira and open the Mapping tab.",
            step_2       = "#     2. In the sidebar, click Import template and pick this .txt.",
            step_3       = "#     3. The mapping is rebuilt in the cards (concatenations and constants).",
            step_4       = "#     4. Review and export. (Each column also becomes a reusable personal alias.)",
            section_map  = "#   mappings by DwC class   (source_column -> DwC_term)",
            legend       = "#   column concatenations are joined with the \" | \" separator",
            section_const= "#   constants   (typed/selected value applied to every row)",
            section_miss = "#   required DwC terms not yet mapped",
            section_unmp = "#   unused raw columns (kept at end of CSV)",
            coverage     = "# coverage: %d DwC term(s) mapped, %d constant(s), %d required missing",
            none         = "(none)"
        )
    }

    out <- c(
        "# saira:mapping:v2",
        "#",
        L$title,
        L$url,
        L$tagline,
        "#",
        sprintf("# created_at: %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
        sprintf("# source_file: %s", if (is.na(source_file)) "" else source_file),
        sprintf("# saira_version: %s", as.character(utils::packageVersion("saira"))),
        sprintf("# n_cols_total: %d  n_cols_mapped: %d  n_cols_unmapped: %d  n_rows: %d",
                n_total, n_mapped, n_unmapped, n_rows),
        sprintf(L$coverage, n_terms, n_const, length(missing_required)),
        "#",
        L$how_to_use,
        L$step_1,
        L$step_2,
        L$step_3,
        L$step_4,
        "#",
        L$section_map,
        L$legend,
        "#"
    )

    if (length(pairs) == 0L) {
        out <- c(out, paste0("#     ", L$none))
    } else {
        col_width <- max(nchar(vapply(pairs, function(p) p$source, character(1))))
        col_width <- max(col_width, 16L)
        # Group mapping lines by DwC class in canonical order.
        pair_classes <- vapply(pairs, function(p) class_of(p$term), character(1))
        class_order <- dwc_canonical_class_order()
        ordered_classes <- c(
            intersect(class_order, unique(pair_classes)),
            setdiff(unique(pair_classes), class_order)
        )
        for (cls in ordered_classes) {
            out <- c(out, sprintf("#   -- %s --", cls))
            for (i in which(pair_classes == cls)) {
                p <- pairs[[i]]
                out <- c(out, sprintf("%-*s -> %s", col_width, p$source, p$term))
            }
        }
    }

    # Constants section (= value -> term).
    out <- c(out, "#", L$section_const, "#")
    if (length(const_pairs) == 0L) {
        out <- c(out, paste0("#     ", L$none))
    } else {
        cw <- max(nchar(vapply(const_pairs,
                               function(p) sprintf("=\"%s\"", p$value), character(1))))
        cw <- max(cw, 16L)
        for (p in const_pairs) {
            out <- c(out, sprintf("%-*s -> %s", cw, sprintf("=\"%s\"", p$value), p$term))
        }
    }

    out <- c(out, "#", L$section_miss)
    if (length(missing_required) == 0L) {
        out <- c(out, paste0("#     ", L$none))
    } else {
        for (term in missing_required) {
            out <- c(out, paste0("#     - ", term))
        }
    }

    out <- c(out, "#", L$section_unmp)
    if (length(unmapped_cols) == 0L) {
        out <- c(out, paste0("#     ", L$none))
    } else {
        for (col in unmapped_cols) {
            out <- c(out, paste0("#     - ", col))
        }
    }

    if (!is.na(id_strategy) && nzchar(id_strategy)) {
        strategy_section <- if (lang == "pt") {
            list(
                header = "#   estrategia de occurrenceID",
                explainers = list(
                    user_supplied = "#     Estrategia: user_supplied. Todos os occurrenceID vieram dos seus dados; serao preservados literalmente no export.",
                    stable_v5     = "#     Estrategia: stable_v5. UUIDs v5 deterministicos gerados a partir de institutionCode + (catalogNumber/eventID/recordNumber). Mesma combinacao = mesmo UUID em qualquer maquina e re-export. Republicacoes no GBIF aparecerao como atualizacoes do mesmo registro.",
                    stable_v5_with_random_fallback = "#     Estrategia: stable_v5_with_random_fallback. A maioria das linhas tem UUID v5 estavel; algumas sem institutionCode/anchor cairam em UUID v4 aleatorio. Linhas v4 mudam a cada export.",
                    random_v4     = "#     Estrategia: random_v4. UUIDs aleatorios (mudam a cada export). Republicacoes no GBIF serao registradas como novos registros, nao atualizacoes. Para estabilidade entre versoes, mapeie institutionCode + catalogNumber (ou eventID/recordNumber)."
                )
            )
        } else {
            list(
                header = "#   identifier strategy (occurrenceID)",
                explainers = list(
                    user_supplied = "#     Strategy: user_supplied. All occurrenceIDs came from your data; they will be preserved verbatim in the export.",
                    stable_v5     = "#     Strategy: stable_v5. Deterministic UUID v5 generated from institutionCode + (catalogNumber/eventID/recordNumber). Same combination = same UUID across machines and re-exports. Republishing to GBIF will appear as updates to the same record.",
                    stable_v5_with_random_fallback = "#     Strategy: stable_v5_with_random_fallback. Most rows received stable v5 UUIDs; some lacking an institutionCode/anchor fell back to random v4 UUIDs. v4 rows change on every export.",
                    random_v4     = "#     Strategy: random_v4. Random UUIDs (change on every export). Republishing to GBIF will create new records, not updates. For stability across versions, map institutionCode + catalogNumber (or eventID/recordNumber)."
                )
            )
        }
        out <- c(out, "#", strategy_section$header, "#")
        explainer <- strategy_section$explainers[[id_strategy]]
        if (is.null(explainer)) explainer <- sprintf("#     Strategy: %s.", id_strategy)
        out <- c(out, explainer)
    }

    out
}

#' Canonical class (group) order for DwC export
#'
#' Sequence used to order columns in the exported spreadsheet. Identifier-bearing
#' Occurrence terms come first, then record metadata, event/temporal, location,
#' organism/taxon, identification, and auxiliary classes. Matches GBIF DwC
#' archive conventions for occurrence datasets.
#'
#' @return Character vector of DwC class names.
#' @export
dwc_canonical_class_order <- function() {
    c(
        "Occurrence",
        "Record-level",
        "Event",
        "Location",
        "GeologicalContext",
        "Organism",
        "Taxon",
        "Identification",
        "MaterialEntity",
        "MaterialSample",
        "MeasurementOrFact",
        "ResourceRelationship",
        # DwC-DP classes (rarely present in occurrence exports; ordered last).
        "Agent",
        "Assertion",
        "BibliographicResource",
        "MolecularProtocol",
        "NucleotideAnalysis",
        "NucleotideSequence",
        "OrganismInteraction",
        "Protocol",
        "Provenance"
    )
}

#' Preferred-first DwC terms within each class
#'
#' Within a class block, terms listed here lead the order. Remaining terms of
#' that class follow in dwc_full_catalog row order. Lets the export show
#' high-signal columns first (occurrenceID in Occurrence, scientificName in
#' Taxon, decimalLatitude/decimalLongitude in Location, etc.).
#'
#' @return Named list keyed by class -> character vector of term names.
#' @export
dwc_canonical_preferred_terms <- function() {
    list(
        Occurrence = c(
            "occurrenceID", "recordNumber",
            "recordedBy", "individualCount", "occurrenceStatus",
            "preparations", "disposition", "occurrenceRemarks"
        ),
        `Record-level` = c(
            "type", "basisOfRecord",
            "institutionCode", "collectionCode", "datasetName",
            "license", "rightsHolder", "modified", "language",
            "dynamicProperties"
        ),
        Event = c(
            "eventDate", "year", "month", "day",
            "samplingProtocol", "samplingEffort",
            "fieldNotes", "habitat"
        ),
        Location = c(
            "country", "countryCode", "stateProvince", "county",
            "municipality", "locality", "locationRemarks",
            "decimalLatitude", "decimalLongitude",
            "verbatimLatitude", "verbatimLongitude",
            "geodeticDatum", "coordinateUncertaintyInMeters"
        ),
        Taxon = c(
            "scientificName", "scientificNameAuthorship",
            "kingdom", "phylum", "class", "order", "family", "genus",
            "subgenus", "specificEpithet", "infraspecificEpithet", "taxonRank",
            "verbatimIdentification", "identificationQualifier", "vernacularName",
            # Relocated here from Occurrence for reading order -- see
            # dwc_canonical_class_overrides().
            "establishmentMeans", "degreeOfEstablishment"
        ),
        Identification = c(
            "identifiedBy", "dateIdentified", "identificationRemarks", "typeStatus"
        ),
        # catalogNumber/otherCatalogNumbers moved from Occurrence to
        # MaterialEntity in the TDWG resync; keep them leading the MaterialEntity
        # block so the catalog identifiers stay near the front of the export.
        MaterialEntity = c("catalogNumber", "otherCatalogNumbers")
    )
}

#' Terms placed outside their DwC class in the exported column order
#'
#' `establishmentMeans` and `degreeOfEstablishment` are Occurrence terms, which
#' would put them at the very front of the sheet, far from the species they
#' describe. They read as attributes of the taxon, so the export places them at
#' the end of the Taxon block: whoever opens the file sees the scientific name
#' and, right next to it, whether that species is native or introduced.
#'
#' Display order only. The catalog class is untouched, so the mapping grid still
#' groups both cards under Occurrence and `meta.xml` still declares the real
#' Darwin Core term URIs.
#'
#' @return Named character vector: term -> class used for ordering.
#' @noRd
dwc_canonical_class_overrides <- function() {
    c(
        establishmentMeans = "Taxon",
        degreeOfEstablishment = "Taxon"
    )
}

#' Reorder a data frame's columns into the canonical DwC sequence
#'
#' Looks up each column's class via the cached DwC full catalog
#' (\code{get_dwc_full_catalog()}), then orders by class priority
#' (\code{dwc_canonical_class_order}), preferred-term position within class
#' (\code{dwc_canonical_preferred_terms}), catalog row position, and original
#' column position as final tie-breakers. Columns whose name is not a known
#' DwC term are appended at the end, preserving their original relative order.
#'
#' @param df A data frame of mapped DwC columns.
#' @return The same data frame with columns reordered (rows untouched).
#' @export
order_columns_dwc_canonical <- function(df) {
    if (!is.data.frame(df) || ncol(df) == 0L) return(df)

    cols <- names(df)
    catalog <- tryCatch(get_dwc_full_catalog(), error = function(e) NULL)

    if (is.null(catalog) || !is.data.frame(catalog) || nrow(catalog) == 0L) {
        cls_lookup <- character(0)
        cat_pos <- integer(0)
    } else {
        cls_lookup <- stats::setNames(as.character(catalog$class), catalog$term)
        cat_pos <- stats::setNames(seq_len(nrow(catalog)), catalog$term)
    }

    class_order <- dwc_canonical_class_order()
    preferred <- dwc_canonical_preferred_terms()
    unknown_class_idx <- length(class_order) + 1L

    class_overrides <- dwc_canonical_class_overrides()

    lookup_class <- function(col) {
        # Overrides win so both the class block and the within-class preferred
        # position are resolved against the same (relocated) class.
        if (col %in% names(class_overrides)) {
            return(unname(class_overrides[[col]]))
        }
        if (length(cls_lookup) == 0L || !(col %in% names(cls_lookup))) {
            return(NA_character_)
        }
        cls_lookup[[col]]
    }
    lookup_cat_pos <- function(col) {
        if (length(cat_pos) == 0L || !(col %in% names(cat_pos))) {
            return(NA_integer_)
        }
        as.integer(cat_pos[[col]])
    }

    cls_idx <- vapply(cols, function(col) {
        cls <- lookup_class(col)
        if (is.na(cls) || !nzchar(cls)) return(unknown_class_idx)
        m <- match(cls, class_order, nomatch = unknown_class_idx)
        as.integer(m)
    }, integer(1))

    pref_idx <- vapply(seq_along(cols), function(i) {
        col <- cols[i]
        cls <- lookup_class(col)
        if (!is.na(cls) && nzchar(cls)) {
            pref <- preferred[[cls]]
            if (!is.null(pref)) {
                p <- match(col, pref)
                if (!is.na(p)) return(as.integer(p))
            }
        }
        cp <- lookup_cat_pos(col)
        if (is.na(cp)) {
            1000L + i
        } else {
            1000L + cp
        }
    }, integer(1))

    ord <- order(cls_idx, pref_idx, seq_along(cols))
    df[, cols[ord], drop = FALSE]
}

#' Abbreviate Creative Commons license values
#'
#' @param x Character vector with license values
#' @return Character vector with known license URLs abbreviated
#' @export
abbreviate_license <- function(x) {
    x_chr <- as.character(x)
    missing_idx <- is.na(x_chr)
    normalized <- tolower(trimws(x_chr))

    # Normalize common URL variants for stable matching
    normalized <- gsub("^https?://", "", normalized)
    normalized <- gsub("/legalcode/?$", "", normalized)
    normalized <- gsub("/+$", "", normalized)

    out <- x_chr

    is_cc0 <- normalized %in% c(
        "creativecommons.org/publicdomain/zero/1.0",
        "cc0"
    )
    is_cc_by_nc <- normalized %in% c(
        "creativecommons.org/licenses/by-nc/4.0",
        "cc-by-nc"
    )
    is_cc_by <- normalized %in% c(
        "creativecommons.org/licenses/by/4.0",
        "cc-by"
    )

    out[is_cc0] <- "CC0"
    out[is_cc_by_nc] <- "CC-BY-NC"
    out[is_cc_by] <- "CC-BY"
    out[missing_idx] <- NA_character_

    return(out)
}

#' Abbreviate the license column in a data frame
#'
#' @param df Data frame
#' @param col Column name to abbreviate (default: "license")
#' @return Data frame with abbreviated license values when column exists
#' @export
abbreviate_license_column <- function(df, col = "license") {
    if (!(col %in% names(df))) {
        return(df)
    }

    df[[col]] <- abbreviate_license(df[[col]])
    return(df)
}

#' Convert dates to ISO 8601 format
#'
#' @param df Data frame
#' @return Data frame with converted dates
#' @export
fix_dates_to_iso <- function(df) {
    date_cols <- c("eventDate", "dateIdentified", "modified")

    for (col in date_cols) {
        if (col %in% names(df)) {
            original_values <- as.character(df[[col]])
            parsed_values <- parse_dates_to_iso(df[[col]])
            keep_raw <- is.na(parsed_values) & !is.na(original_values) & nzchar(original_values)
            parsed_values[keep_raw] <- original_values[keep_raw]
            df[[col]] <- parsed_values
        }
    }

    return(df)
}

#' Clean coordinate separators (comma to dot)
#'
#' @param df Data frame
#' @return Data frame with cleaned coordinates
#' @export
clean_coordinate_separators <- function(df) {
    coord_cols <- c("decimalLatitude", "decimalLongitude")

    for (col in coord_cols) {
        if (col %in% names(df)) {
            # Replace comma with dot
            df[[col]] <- gsub(",", ".", df[[col]])

            # Convert to numeric
            df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
        }
    }

    return(df)
}

#' Generate occurrenceIDs with deterministic v5 or random v4 strategy
#'
#' Strategy resolution:
#' - Rows with a user-supplied `occurrenceID` are preserved verbatim.
#' - For rows missing `occurrenceID`: if the data has `institutionCode` AND one
#'   of `catalogNumber` / `eventID` / `recordNumber` (the "anchor"), a
#'   deterministic UUID v5 is generated via `uuid::UUIDfromName()` using the
#'   RFC 4122 URL namespace plus `saira-occurrence:<institutionCode>|<anchor>`
#'   as the name. The same anchor combination always produces the same UUID
#'   across machines and re-exports.
#' - Otherwise, falls back to random UUID v4 via `ids::uuid()`.
#'
#' The returned data frame carries an `id_strategy` attribute documenting which
#' path was used: `"user_supplied"`, `"stable_v5"`, `"stable_v5_with_random_fallback"`,
#' or `"random_v4"`. Downstream consumers (mapping_guide.txt, export form
#' banner) read this attribute.
#'
#' @param df Data frame.
#' @return Data frame with `occurrenceID` populated. Carries `id_strategy`
#'   attribute.
#' @export
generate_occurrence_ids <- function(df) {
    n <- nrow(df)
    if (n == 0L) {
        if (!"occurrenceID" %in% names(df)) df$occurrenceID <- character(0)
        attr(df, "id_strategy") <- "user_supplied"
        return(df)
    }

    if ("occurrenceID" %in% names(df)) {
        current <- as.character(df$occurrenceID)
    } else {
        current <- rep(NA_character_, n)
    }
    missing <- is.na(current) | !nzchar(trimws(current))

    if (!any(missing)) {
        df$occurrenceID <- current
        attr(df, "id_strategy") <- "user_supplied"
        return(df)
    }

    has_inst <- "institutionCode" %in% names(df)
    anchor_col <- if ("catalogNumber" %in% names(df)) {
        "catalogNumber"
    } else if ("eventID" %in% names(df)) {
        "eventID"
    } else if ("recordNumber" %in% names(df)) {
        "recordNumber"
    } else {
        NA_character_
    }
    has_anchor <- has_inst && !is.na(anchor_col) &&
        requireNamespace("uuid", quietly = TRUE)

    if (has_anchor) {
        ic <- as.character(df$institutionCode)
        sec <- as.character(df[[anchor_col]])
        anchor_valid <- !is.na(ic) & nzchar(trimws(ic)) &
            !is.na(sec) & nzchar(trimws(sec))
        rows_v5 <- missing & anchor_valid
        rows_v4 <- missing & !anchor_valid

        # RFC 4122 URL namespace UUID. Stable across machines and Saira versions.
        url_ns <- "6ba7b811-9dad-11d1-80b4-00c04fd430c8"

        if (any(rows_v5)) {
            names_v5 <- paste0("saira-occurrence:", ic[rows_v5], "|", sec[rows_v5])
            current[rows_v5] <- paste0(
                "urn:uuid:",
                vapply(names_v5, function(nm) uuid::UUIDfromName(url_ns, nm), character(1))
            )
        }
        if (any(rows_v4)) {
            current[rows_v4] <- ids::uuid(n = sum(rows_v4))
        }
        strategy <- if (any(rows_v5) && any(rows_v4)) {
            "stable_v5_with_random_fallback"
        } else if (any(rows_v5)) {
            "stable_v5"
        } else {
            "random_v4"
        }
    } else {
        current[missing] <- ids::uuid(n = sum(missing))
        strategy <- "random_v4"
    }

    df$occurrenceID <- current
    attr(df, "id_strategy") <- strategy
    df
}

#' Add occurrence IDs (legacy alias)
#'
#' Kept for backward compatibility. New code should call
#' `generate_occurrence_ids()` directly.
#'
#' @param df Data frame.
#' @return Data frame with `occurrenceID` populated.
#' @export
add_occurrence_ids <- function(df) {
    generate_occurrence_ids(df)
}

#' Populate geodeticDatum for rows with valid coordinates
#'
#' Darwin Core records with `decimalLatitude`/`decimalLongitude` should declare
#' the coordinate reference system in `geodeticDatum`. Saira's pipeline assumes
#' WGS84 throughout, so any row with finite, in-range coordinates and no
#' pre-existing `geodeticDatum` gets `"EPSG:4326"`. Rows without valid
#' coordinates or with a user-supplied datum are left untouched (DwC convention
#' is to omit rather than write "unknown").
#'
#' @param df Data frame.
#' @return Data frame with `geodeticDatum` populated where appropriate.
#' @export
apply_geodetic_datum <- function(df) {
    if (!"decimalLatitude" %in% names(df) || !"decimalLongitude" %in% names(df)) {
        return(df)
    }

    lat <- suppressWarnings(as.numeric(df$decimalLatitude))
    lon <- suppressWarnings(as.numeric(df$decimalLongitude))
    valid <- is.finite(lat) & is.finite(lon) &
        lat >= -90 & lat <= 90 & lon >= -180 & lon <= 180

    if (!"geodeticDatum" %in% names(df)) {
        df$geodeticDatum <- NA_character_
    }
    current <- as.character(df$geodeticDatum)
    blank <- is.na(current) | !nzchar(trimws(current))

    df$geodeticDatum[valid & blank] <- "EPSG:4326"
    df
}

#' Convert countryCode to ISO 3166-1 alpha-2 for DwC export
#'
#' Saira's internal pipeline keeps `countryCode` in ISO alpha-3 ("BRA") for
#' compatibility with `CoordinateCleaner::cc_coun()`. Darwin Core's
#' `countryCode` term requires alpha-2 ("BR"). This helper converts alpha-3
#' values to alpha-2 at the export boundary. Values that are already 2
#' characters are treated as alpha-2 and preserved unchanged. Unconvertible
#' values become `NA` (GBIF convention for unknown).
#'
#' @param df Data frame.
#' @return Data frame with `countryCode` (if present) converted to alpha-2.
#' @export
convert_country_code_to_alpha2 <- function(df) {
    if (!"countryCode" %in% names(df)) return(df)
    if (!requireNamespace("countrycode", quietly = TRUE)) return(df)

    raw <- as.character(df$countryCode)
    trimmed <- trimws(raw)
    trimmed[is.na(trimmed) | !nzchar(trimmed)] <- NA_character_

    needs_conv <- !is.na(trimmed) & nchar(trimmed) == 3L
    if (any(needs_conv)) {
        converted <- countrycode::countrycode(
            sourcevar = trimmed[needs_conv],
            origin = "iso3c",
            destination = "iso2c",
            warn = FALSE
        )
        trimmed[needs_conv] <- converted
    }

    df$countryCode <- trimmed
    df
}

# Dublin Core terms used in DwC (everything else lives under dwc:).
.dc_terms <- c(
    "type", "modified", "language", "license", "rights", "rightsHolder",
    "accessRights", "bibliographicCitation", "references"
)

# Audiovisual Core terms recommended by DwC. fundingAttribution is organised
# under the Provenance class but its authoritative IRI is ac:, not dwc:.
.ac_terms <- c("fundingAttribution")

#' Map a DwC/DC column name to its full term URI
#'
#' @param column Character vector of column names.
#' @return Character vector of term URIs, NA where the column is not a
#'   recognized DwC or DC term.
#' @export
dwc_term_uri <- function(column) {
    catalog <- tryCatch(get_dwc_full_catalog(), error = function(e) NULL)
    known <- if (is.data.frame(catalog)) as.character(catalog$term) else character(0)

    out <- ifelse(
        column %in% .dc_terms,
        paste0("http://purl.org/dc/terms/", column),
        ifelse(
            column %in% .ac_terms,
            paste0("http://rs.tdwg.org/ac/terms/", column),
            ifelse(
                column %in% known,
                paste0("http://rs.tdwg.org/dwc/terms/", column),
                NA_character_
            )
        )
    )
    out
}

#' Build a Darwin Core Archive meta.xml descriptor
#'
#' Generates the DwC-A `meta.xml` document describing the `occurrence.txt`
#' core file. Only columns recognized as DwC or Dublin Core terms get a
#' `<field>` declaration; extras stay in the CSV but are not declared (GBIF
#' will ignore them per spec).
#'
#' @param df Data frame whose columns describe the rows that will be written
#'   to `occurrence.txt`.
#' @param core_filename Name of the core CSV file referenced by `meta.xml`.
#'   Default `"occurrence.txt"`.
#' @return Character scalar containing the serialized XML document.
#' @export
build_meta_xml <- function(df, core_filename = "occurrence.txt") {
    if (!is.data.frame(df)) stop("build_meta_xml: 'df' must be a data.frame.")

    cols <- names(df)
    uris <- dwc_term_uri(cols)

    doc <- xml2::xml_new_root(
        "archive",
        xmlns = "http://rs.tdwg.org/dwc/text/",
        metadata = "eml.xml"
    )
    core <- xml2::xml_add_child(
        doc, "core",
        encoding = "UTF-8",
        fieldsTerminatedBy = ",",
        linesTerminatedBy = "\\n",
        fieldsEnclosedBy = "\"",
        ignoreHeaderLines = "1",
        rowType = "http://rs.tdwg.org/dwc/terms/Occurrence"
    )
    files <- xml2::xml_add_child(core, "files")
    xml2::xml_add_child(files, "location", core_filename)

    id_idx <- match("occurrenceID", cols)
    if (!is.na(id_idx)) {
        xml2::xml_add_child(core, "id", index = as.character(id_idx - 1L))
    }

    for (i in seq_along(cols)) {
        if (is.na(uris[i])) next
        xml2::xml_add_child(
            core, "field",
            index = as.character(i - 1L),
            term = uris[i]
        )
    }

    as.character(doc)
}

#' Compute geographic and temporal extents for EML coverage
#'
#' Reads `decimalLatitude`/`decimalLongitude` for the geographic bounding box
#' and `eventDate` for the temporal range. Returns NA for any extent that
#' cannot be derived from the data.
#'
#' @param df Data frame.
#' @return Named list with `bbox` (named numeric vector: west/east/north/south)
#'   and `dates` (named character vector: begin/end, ISO YYYY-MM-DD).
#' @export
compute_dataset_extents <- function(df) {
    bbox <- c(west = NA_real_, east = NA_real_, north = NA_real_, south = NA_real_)
    if (all(c("decimalLatitude", "decimalLongitude") %in% names(df))) {
        lat <- suppressWarnings(as.numeric(df$decimalLatitude))
        lon <- suppressWarnings(as.numeric(df$decimalLongitude))
        valid <- is.finite(lat) & is.finite(lon) &
            lat >= -90 & lat <= 90 & lon >= -180 & lon <= 180
        if (any(valid)) {
            bbox[["west"]]  <- min(lon[valid])
            bbox[["east"]]  <- max(lon[valid])
            bbox[["north"]] <- max(lat[valid])
            bbox[["south"]] <- min(lat[valid])
        }
    }

    dates <- c(begin = NA_character_, end = NA_character_)
    if ("eventDate" %in% names(df)) {
        raw <- as.character(df$eventDate)
        iso <- substr(trimws(raw), 1L, 10L)
        parsed <- suppressWarnings(as.Date(iso, format = "%Y-%m-%d"))
        if (any(!is.na(parsed))) {
            dates[["begin"]] <- format(min(parsed, na.rm = TRUE), "%Y-%m-%d")
            dates[["end"]]   <- format(max(parsed, na.rm = TRUE), "%Y-%m-%d")
        }
    }

    list(bbox = bbox, dates = dates)
}

# Escape text for safe insertion into XML content or a double-quoted attribute.
.xml_escape <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    gsub("\"", "&quot;", x, fixed = TRUE)
}

# Build the <intellectualRights> element for a chosen license, following the
# GBIF/IPT convention: a <para> with a <ulink url><citetitle> naming the
# license. Accepts either the short token ("CC-BY-4.0") or the full Creative
# Commons URL the mapping card stores. Only the three GBIF-accepted licenses
# (CC0 1.0, CC-BY 4.0, CC-BY-NC 4.0) get a canonical statement; any other value
# is cited verbatim so the EML never silently claims CC0/public domain for a
# dataset the publisher licensed differently. Returns a serialized XML string.
build_intellectual_rights_xml <- function(license_value) {
    norm <- tolower(trimws(as.character(license_value)))
    norm <- gsub("^https?://", "", norm)
    norm <- gsub("/legalcode/?$", "", norm)
    norm <- gsub("/+$", "", norm)

    para <- if (norm %in% c("cc0-1.0", "cc0",
                            "creativecommons.org/publicdomain/zero/1.0")) {
        paste0(
            "<para>To the extent possible under law, the publisher has waived ",
            "all rights to these data and has dedicated them to the ",
            "<ulink url=\"http://creativecommons.org/publicdomain/zero/1.0/legalcode\">",
            "<citetitle>Public Domain (CC0 1.0)</citetitle></ulink>. Users may ",
            "copy, modify, distribute and use the work, including for commercial ",
            "purposes, without restriction.</para>"
        )
    } else if (norm %in% c("cc-by-4.0", "cc-by",
                           "creativecommons.org/licenses/by/4.0")) {
        paste0(
            "<para>This work is licensed under a ",
            "<ulink url=\"http://creativecommons.org/licenses/by/4.0/legalcode\">",
            "<citetitle>Creative Commons Attribution (CC-BY) 4.0 License</citetitle>",
            "</ulink>.</para>"
        )
    } else if (norm %in% c("cc-by-nc-4.0", "cc-by-nc",
                           "creativecommons.org/licenses/by-nc/4.0")) {
        paste0(
            "<para>This work is licensed under a ",
            "<ulink url=\"http://creativecommons.org/licenses/by-nc/4.0/legalcode\">",
            "<citetitle>Creative Commons Attribution Non Commercial (CC-BY-NC) 4.0 License</citetitle>",
            "</ulink>.</para>"
        )
    } else {
        val <- trimws(as.character(license_value))
        esc <- .xml_escape(val)
        if (grepl("^https?://", val)) {
            paste0(
                "<para>This work is released under the license at ",
                "<ulink url=\"", esc, "\"><citetitle>", esc,
                "</citetitle></ulink>.</para>"
            )
        } else {
            paste0("<para>This work is released under the following license: ",
                   esc, ".</para>")
        }
    }

    paste0("<intellectualRights>", para, "</intellectualRights>")
}

#' Build an EML 2.1.1 dataset descriptor for a Saira export
#'
#' Produces a minimal-but-valid EML document with required GBIF/IPT fields:
#' title, creator, contact, pubDate, abstract, intellectualRights, and
#' coverage (geographic + temporal). Geographic and temporal coverage are
#' computed automatically from the data via `compute_dataset_extents()`;
#' callers supply the editable fields (title/creator/license/abstract) via
#' `metadata`.
#'
#' @param df Data frame that will become `occurrence.txt`.
#' @param metadata Named list with optional entries: `title` (string),
#'   `creator` (named list with `name`, `email`, `organization`), `license`
#'   (string, default `"CC0-1.0"`), `abstract` (string).
#' @param package_id Optional UUID for the EML packageId; defaults to a
#'   freshly generated UUID.
#' @return Character scalar containing the serialized EML document.
#' @export
build_eml_xml <- function(df, metadata = list(), package_id = NULL) {
    ext <- compute_dataset_extents(df)

    title <- metadata$title %||% paste0("Saira export ", format(Sys.Date(), "%Y-%m-%d"))
    creator <- metadata$creator %||% list(name = "", email = "", organization = "")
    creator$name         <- creator$name         %||% ""
    creator$email        <- creator$email        %||% ""
    creator$organization <- creator$organization %||% ""
    # Reflect the license the user chose in the mapping (default CC0 only when
    # no license was set). Mapped to the GBIF/IPT intellectualRights form below.
    license  <- metadata$license  %||% "CC0-1.0"
    abstract <- metadata$abstract %||% sprintf(
        "Biodiversity occurrence dataset standardized to Darwin Core via Saira v%s.",
        utils::packageVersion("saira")
    )
    pkg_id <- package_id %||% paste0("urn:uuid:", ids::uuid())

    # Split creator name into given/sur for EML structure.
    name_parts <- strsplit(trimws(creator$name), "\\s+")[[1]]
    if (length(name_parts) == 0L) {
        given <- ""
        sur   <- ""
    } else if (length(name_parts) == 1L) {
        given <- name_parts[1L]
        sur   <- ""
    } else {
        given <- paste(name_parts[-length(name_parts)], collapse = " ")
        sur   <- name_parts[length(name_parts)]
    }

    doc <- xml2::xml_new_root(
        "eml:eml",
        "xmlns:eml" = "https://eml.ecoinformatics.org/eml-2.1.1",
        "xmlns:dc"  = "http://purl.org/dc/terms/",
        "xmlns:xsi" = "http://www.w3.org/2001/XMLSchema-instance",
        "xsi:schemaLocation" = "https://eml.ecoinformatics.org/eml-2.1.1 https://eml.ecoinformatics.org/eml-2.1.1/eml.xsd",
        packageId = pkg_id,
        system = "saira",
        scope = "system",
        "xml:lang" = "eng"
    )
    ds <- xml2::xml_add_child(doc, "dataset")
    title_el <- xml2::xml_add_child(ds, "title", title)
    xml2::xml_set_attr(title_el, "xml:lang", "eng")

    cr <- xml2::xml_add_child(ds, "creator")
    ind <- xml2::xml_add_child(cr, "individualName")
    if (nzchar(given)) xml2::xml_add_child(ind, "givenName", given)
    if (nzchar(sur))   xml2::xml_add_child(ind, "surName", sur)
    if (!nzchar(given) && !nzchar(sur)) xml2::xml_add_child(ind, "surName", "Unknown")
    if (nzchar(creator$organization)) {
        xml2::xml_add_child(cr, "organizationName", creator$organization)
    }
    if (nzchar(creator$email)) {
        xml2::xml_add_child(cr, "electronicMailAddress", creator$email)
    }

    xml2::xml_add_child(ds, "pubDate", format(Sys.Date(), "%Y-%m-%d"))

    abs_el <- xml2::xml_add_child(ds, "abstract")
    xml2::xml_add_child(abs_el, "para", abstract)

    # Access constraints for generalized sensitive records (Chapman 2020 sec.
    # 5.1). Emitted only when the export actually masked rows. Placed before
    # intellectualRights to honour the EML 2.1.1 resource sequence.
    sens <- metadata$sensitivity
    if (is.list(sens) && !is.null(sens$n_masked) && sens$n_masked > 0L) {
        review <- sens$review_date %||% format(Sys.Date() + 730, "%Y-%m-%d")
        note <- sprintf(
            tr("sensitive_eml_access_note", sens$lang %||% "en"),
            sens$n_masked, review
        )
        ai_el <- xml2::xml_add_child(ds, "additionalInfo")
        xml2::xml_add_child(ai_el, "para", note)
    }

    xml2::xml_add_child(ds, xml2::read_xml(build_intellectual_rights_xml(license)))

    cov <- xml2::xml_add_child(ds, "coverage")
    if (all(is.finite(ext$bbox))) {
        geo <- xml2::xml_add_child(cov, "geographicCoverage")
        xml2::xml_add_child(geo, "geographicDescription",
            "Bounding box computed from decimalLatitude/decimalLongitude.")
        bc <- xml2::xml_add_child(geo, "boundingCoordinates")
        xml2::xml_add_child(bc, "westBoundingCoordinate",
            format(ext$bbox[["west"]], nsmall = 6))
        xml2::xml_add_child(bc, "eastBoundingCoordinate",
            format(ext$bbox[["east"]], nsmall = 6))
        xml2::xml_add_child(bc, "northBoundingCoordinate",
            format(ext$bbox[["north"]], nsmall = 6))
        xml2::xml_add_child(bc, "southBoundingCoordinate",
            format(ext$bbox[["south"]], nsmall = 6))
    }
    if (!is.na(ext$dates[["begin"]]) && !is.na(ext$dates[["end"]])) {
        tmp <- xml2::xml_add_child(cov, "temporalCoverage")
        if (ext$dates[["begin"]] == ext$dates[["end"]]) {
            sd <- xml2::xml_add_child(tmp, "singleDateTime")
            xml2::xml_add_child(sd, "calendarDate", ext$dates[["begin"]])
        } else {
            rd <- xml2::xml_add_child(tmp, "rangeOfDates")
            bd <- xml2::xml_add_child(rd, "beginDate")
            xml2::xml_add_child(bd, "calendarDate", ext$dates[["begin"]])
            ed <- xml2::xml_add_child(rd, "endDate")
            xml2::xml_add_child(ed, "calendarDate", ext$dates[["end"]])
        }
    }

    methods <- xml2::xml_add_child(ds, "methods")
    ms <- xml2::xml_add_child(methods, "methodStep")
    desc <- xml2::xml_add_child(ms, "description")
    xml2::xml_add_child(desc, "para", sprintf(
        "Dataset prepared with Saira v%s (https://github.com/rogerio-onza/saira). Fields validated and mapped to Darwin Core; coordinates checked with CoordinateCleaner; taxonomy reconciled against taxadb.",
        utils::packageVersion("saira")
    ))

    # Contact mirrors the creator block.
    ct <- xml2::xml_add_child(ds, "contact")
    ct_ind <- xml2::xml_add_child(ct, "individualName")
    if (nzchar(given)) xml2::xml_add_child(ct_ind, "givenName", given)
    xml2::xml_add_child(ct_ind, "surName", if (nzchar(sur)) sur else "Unknown")
    if (nzchar(creator$organization)) {
        xml2::xml_add_child(ct, "organizationName", creator$organization)
    }
    if (nzchar(creator$email)) {
        xml2::xml_add_child(ct, "electronicMailAddress", creator$email)
    }

    as.character(doc)
}

# Local null-coalescing operator.
`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1L && (is.na(a) || identical(a, "")))) b else a

#' Assemble a Darwin Core Archive (DwC-A) bundle as a ZIP
#'
#' Lays out the archive with `occurrence.txt`, `meta.xml`, `eml.xml` at the
#' ZIP root, plus any provided sibling files (`mapping_guide.txt`, the
#' Excel mirror, the private sensitive-coordinates CSV). The bundle is
#' GBIF/IPT-compatible.
#'
#' @param df Data frame of DwC-ready records (output of
#'   `process_for_export()` or `process_for_export_with_unmapped()`).
#' @param zip_path Destination ZIP path.
#' @param metadata Named list passed to `build_eml_xml()`.
#' @param extras Optional named list mapping in-zip filenames to local file
#'   paths to include as siblings.
#' @return Invisibly returns `zip_path`.
#' @export
build_dwca_bundle <- function(df, zip_path, metadata = list(), extras = list()) {
    if (!is.data.frame(df)) stop("build_dwca_bundle: 'df' must be a data.frame.")

    tmpdir <- tempfile("saira_dwca_")
    dir.create(tmpdir, showWarnings = FALSE, recursive = TRUE)
    on.exit(unlink(tmpdir, recursive = TRUE), add = TRUE)

    core_path <- file.path(tmpdir, "occurrence.txt")
    meta_path <- file.path(tmpdir, "meta.xml")
    eml_path  <- file.path(tmpdir, "eml.xml")

    readr::write_csv(df, core_path, na = "")
    writeLines(build_meta_xml(df, core_filename = "occurrence.txt"),
               meta_path, useBytes = TRUE)
    writeLines(build_eml_xml(df, metadata = metadata),
               eml_path, useBytes = TRUE)

    files <- c(core_path, meta_path, eml_path)
    for (nm in names(extras)) {
        src <- extras[[nm]]
        if (length(src) == 1L && file.exists(src)) {
            dst <- file.path(tmpdir, nm)
            file.copy(src, dst, overwrite = TRUE)
            files <- c(files, dst)
        }
    }

    zip::zipr(zipfile = zip_path, files = files)
    invisible(zip_path)
}

#' Validate and clean scientific names
#'
#' @param names_vector Character vector of scientific names
#' @return Character vector of cleaned names
#' @export
clean_scientific_names <- function(names_vector) {
    # Trim whitespace
    names_vector <- trimws(names_vector)

    # Remove multiple spaces
    names_vector <- gsub("\\s+", " ", names_vector)

    # Remove trailing/leading punctuation
    names_vector <- gsub("^[[:punct:]]+|[[:punct:]]+$", "", names_vector)

    return(names_vector)
}

#' Slugify a dataset name for use in file names
#'
#' Transliterates accents to ASCII, lowercases, and collapses any run of
#' non-alphanumeric characters into a single hyphen (so `"Meu Data Set"` ->
#' `"meu-data-set"`). Returns `""` when there is no usable name.
#'
#' @param x Dataset name (character) or NULL.
#' @return Lowercase, hyphen-separated ASCII slug, or `""`.
#' @noRd
slugify_dataset_name <- function(x) {
    if (is.null(x) || length(x) == 0L) return("")
    s <- as.character(x)[1L]
    if (is.na(s)) return("")
    s <- iconv(s, to = "ASCII//TRANSLIT")
    if (is.na(s)) return("")
    s <- tolower(s)
    s <- gsub("[^a-z0-9]+", "-", s)
    s <- gsub("^-+|-+$", "", s)
    s
}

#' Export bundle file names, grouped by role
#'
#' Single source of truth for what the DwC-A download contains, so the Export
#' tab summary and the download handler never drift apart. The Darwin Core
#' Archive core trio keeps its standard names (IPT/GBIF require them); the
#' convenience siblings are renamed after the dataset so a user can tell whose
#' files these are once unzipped (e.g. `meu-data-set-sensitive-coords.csv`).
#'
#' @param dataset_name Dataset name (from the `datasetName` constant), or NULL.
#' @param has_sensitive Whether any record was generalized (adds the private
#'   real-coordinates CSV to the auxiliary group).
#' @return List with `slug`, `zip` (download file name), `dwca` (standard core
#'   trio) and `auxiliary` (named character vector: `xlsx`, `mapping_guide`,
#'   and `sensitive_coords` when `has_sensitive`).
#' @noRd
export_bundle_filenames <- function(dataset_name = NULL, has_sensitive = FALSE) {
    slug <- slugify_dataset_name(dataset_name)
    if (!nzchar(slug)) slug <- "saira"

    # A list (not a named vector) so absent slots read back as NULL instead of
    # erroring on `[[`.
    auxiliary <- list(
        xlsx = paste0(slug, "-occurrences.xlsx"),
        mapping_guide = paste0(slug, "-mapping-guide.txt")
    )
    if (isTRUE(has_sensitive)) {
        auxiliary[["sensitive_coords"]] <- paste0(slug, "-sensitive-coords.csv")
    }

    list(
        slug = slug,
        zip = paste0(slug, "-dwc-archive.zip"),
        dwca = c("occurrence.txt", "meta.xml", "eml.xml"),
        auxiliary = auxiliary
    )
}
