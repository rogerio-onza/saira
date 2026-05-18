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

    # Add occurrence IDs if missing
    df <- add_occurrence_ids(df)

    # Normalize known Creative Commons license URLs to short labels
    df <- abbreviate_license_column(df)

    # Reorder columns to canonical DwC sequence (occurrenceID first,
    # scientificName leading the Taxon block, etc.)
    df <- order_columns_dwc_canonical(df)

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
    cbind(out, extras)
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
#' @return character vector (uma entrada por linha), encoding UTF-8.
#' @export
build_mapping_guide_txt <- function(map_values,
                                    raw_data,
                                    lang = "pt",
                                    required_terms = c("scientificName", "eventDate",
                                                       "decimalLatitude", "decimalLongitude",
                                                       "basisOfRecord"),
                                    source_file = NA_character_) {
    if (is.function(lang)) lang <- lang()
    lang <- as.character(lang)[1L]
    if (!lang %in% c("pt", "en")) lang <- "pt"

    if (!is.list(map_values)) map_values <- list()
    if (!is.data.frame(raw_data)) raw_data <- data.frame()

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

    raw_cols <- names(raw_data)
    unmapped_cols <- setdiff(raw_cols, used_sources)
    mapped_terms <- vapply(pairs, function(p) p$term, character(1))
    missing_required <- setdiff(required_terms, mapped_terms)

    n_total <- length(raw_cols)
    n_mapped <- length(used_sources)
    n_unmapped <- length(unmapped_cols)
    n_rows <- if (is.data.frame(raw_data)) nrow(raw_data) else 0L

    L <- if (lang == "pt") {
        list(
            title        = "#   SAIRA \u00b7 Guia de Mapeamento Darwin Core",
            url          = "#   github.com/sibbr/saira",
            tagline      = "#   Vocabulario de mapeamento compartilhavel - sem dados de registros",
            how_to_use   = "#   como usar",
            step_1       = "#     1. No Saira (aba Inicio), suba este .txt no dropzone de dados.",
            step_2       = "#     2. Confirme o guia de mapeamento detectado.",
            step_3       = "#     3. Cada linha vira um alias pessoal (scope=personal, reviewed).",
            step_4       = "#     4. Suba seu CSV e clique em Auto-Mapear.",
            section_map  = "#   mapeamentos   (coluna_origem -> termo_DwC)",
            section_miss = "#   termos DwC obrigatorios ainda nao mapeados",
            section_unmp = "#   colunas brutas nao usadas (mantidas no fim do CSV)",
            none         = "(nenhum)"
        )
    } else {
        list(
            title        = "#   SAIRA \u00b7 Darwin Core Mapping Guide",
            url          = "#   github.com/sibbr/saira",
            tagline      = "#   Shareable mapping vocabulary - contains no record data",
            how_to_use   = "#   how to use",
            step_1       = "#     1. In Saira (Home tab), upload this .txt in the data dropzone.",
            step_2       = "#     2. Confirm the detected mapping guide.",
            step_3       = "#     3. Each line becomes a personal alias (scope=personal, reviewed).",
            step_4       = "#     4. Upload your CSV and click Auto-Map.",
            section_map  = "#   mappings   (source_column -> DwC_term)",
            section_miss = "#   required DwC terms not yet mapped",
            section_unmp = "#   unused raw columns (kept at end of CSV)",
            none         = "(none)"
        )
    }

    out <- c(
        "# saira:mapping:v1",
        "#",
        L$title,
        L$url,
        L$tagline,
        "#",
        sprintf("# created_at: %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
        sprintf("# source_file: %s", if (is.na(source_file)) "" else source_file),
        sprintf("# n_cols_total: %d  n_cols_mapped: %d  n_cols_unmapped: %d  n_rows: %d",
                n_total, n_mapped, n_unmapped, n_rows),
        "#",
        L$how_to_use,
        L$step_1,
        L$step_2,
        L$step_3,
        L$step_4,
        "#",
        L$section_map,
        "#"
    )

    if (length(pairs) == 0L) {
        out <- c(out, paste0("#     ", L$none))
    } else {
        col_width <- max(nchar(vapply(pairs, function(p) p$source, character(1))))
        col_width <- max(col_width, 16L)
        for (p in pairs) {
            out <- c(out, sprintf("%-*s -> %s", col_width, p$source, p$term))
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
        "ResourceRelationship"
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
            "occurrenceID", "catalogNumber", "recordNumber",
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
            "verbatimIdentification", "identificationQualifier", "vernacularName"
        ),
        Identification = c(
            "identifiedBy", "dateIdentified", "identificationRemarks", "typeStatus"
        )
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

    lookup_class <- function(col) {
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

#' Add occurrence IDs if missing
#'
#' @param df Data frame
#' @return Data frame with occurrenceID column
#' @export
add_occurrence_ids <- function(df) {
    if (!"occurrenceID" %in% names(df)) {
        # Generate UUIDs for each row
        df$occurrenceID <- ids::uuid(n = nrow(df))
    } else {
        # Fill missing IDs
        missing <- is.na(df$occurrenceID) | df$occurrenceID == ""
        if (any(missing)) {
            df$occurrenceID[missing] <- ids::uuid(n = sum(missing))
        }
    }

    return(df)
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
