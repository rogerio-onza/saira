

#' Process data for DwC-compliant export
#'
#' @param df Data frame with mapped columns
#' @return Data frame with ISO dates, cleaned separators, UUIDs, canonical column order
#' @examples
#' \dontrun{
#'   # Processes mapped data for export (uses spatial packages)
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

    # The published file carries the license name the publisher picked on the
    # card, not the URI (ADR-125). The URI survives in the EML <ulink url>,
    # which is where GBIF reads the dataset license from.
    df <- abbreviate_license_column(df)

    # Populate geodeticDatum for rows with valid lat/lon (DwC GBIF expectation).
    df <- apply_geodetic_datum(df)

    # Convert countryCode from internal ISO alpha-3 to DwC-required alpha-2.
    # Internal pipeline keeps alpha-3 for CoordinateCleaner compatibility;
    # this is the single export-time boundary that emits alpha-2.
    df <- derive_country_code(df)
    df <- convert_country_code_to_alpha2(df)

    # Reorder columns to canonical DwC sequence (occurrenceID first,
    # scientificName leading the Taxon block, etc.). Subsetting strips
    # custom attrs, so reattach the id_strategy after.
    df <- order_columns_dwc_canonical(df)
    attr(df, "id_strategy") <- id_strategy

    return(df)
}

#' Raw columns no DwC term draws from
#'
#' The columns `process_for_export_with_unmapped()` appends to the right of the
#' export. They stay in the CSV but get no `<field>` in `meta.xml`, so GBIF
#' ignores them; the export screen and the mapping guide both report that, and
#' both call this so they cannot disagree on which columns are affected.
#'
#' @param raw_data Data frame with the original uploaded columns.
#' @param map_values Named list keyed by DwC term, values are source columns.
#' @param exclude Character vector of column names already in the export.
#' @param overridden_terms Character vector of terms whose fixed value won over
#'   their column mapping (`overridden_mapping_terms()`). Their source column
#'   was never read, so it is unused and belongs in the tail of the CSV.
#' @return Character vector of column names, possibly empty.
#' @export
unmapped_raw_columns <- function(raw_data, map_values, exclude = character(0),
                                 overridden_terms = character(0)) {
    if (!is.data.frame(raw_data) || ncol(raw_data) == 0L || !is.list(map_values)) {
        return(character(0))
    }

    # A selected column is not a consumed column. Counting the selection is what
    # made a column mapped to a term with a fixed value fall between the two
    # steps: skipped by the builder, then excluded from the tail as "used".
    if (length(overridden_terms) > 0L) {
        overridden <- intersect(names(map_values), overridden_terms)
        # A rescued column can be named after the very term that overrode it
        # (a `country` column mapped to `country`). The caller put that term in
        # `exclude` because the export carries it, so leaving it there would
        # drop the raw values a second time, one step further down.
        exclude <- setdiff(exclude, map_value_sources(map_values[overridden]))
        map_values <- map_values[setdiff(names(map_values), overridden_terms)]
    }

    left <- setdiff(setdiff(names(raw_data), map_value_sources(map_values)), exclude)
    if (length(left) == 0L) {
        return(left)
    }

    # A column with no value in any row is not data left behind. Reporting it
    # buried the columns that do carry something: a spreadsheet exported from a
    # fixed Occurrence template arrives with a dozen empty terms, and the export
    # screen listed all of them as "GBIF will ignore these". Filtering here
    # rather than in the warning keeps the single source this function exists to
    # be (ADR-120), so the notice, the guide and the file still agree.
    left[vapply(
        left,
        function(col) {
            v <- raw_data[[col]]
            any(!is.na(v) & nzchar(trimws(as.character(v))))
        },
        logical(1)
    )]
}

#' Source column names a mapping selection points at
#'
#' Flattens one or more `map_values` entries (concatenations included) into the
#' unique, trimmed column names they draw from.
#'
#' @param map_values Named list keyed by DwC term, values are source columns.
#' @return Character vector of column names, possibly empty.
#' @noRd
map_value_sources <- function(map_values) {
    out <- unique(unlist(
        lapply(map_values, function(v) {
            chr <- as.character(unlist(v, recursive = TRUE, use.names = FALSE))
            chr <- chr[!is.na(chr)]
            chr <- trimws(chr)
            chr[nzchar(chr)]
        }),
        use.names = FALSE
    ))
    if (is.null(out)) character(0) else out
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
#' @param overridden_terms Character vector of terms whose fixed value won over
#'   their column mapping (`overridden_mapping_terms()`).
#' @param sensitive_rows Integer rows whose coordinates the mask generalized or
#'   withheld. Their coordinate-like raw values are blanked.
#' @param sensitive_points Optional data frame aligned with `sensitive_rows`:
#'   the real `decimalLatitude`, `decimalLongitude` and the mask `grid`.
#' @return Data frame: process_for_export(df_processed) + tail of unused raw cols.
#' @export
process_for_export_with_unmapped <- function(df_processed, raw_data, map_values,
                                             overridden_terms = character(0),
                                             sensitive_rows = integer(0),
                                             sensitive_points = NULL) {
    out <- process_for_export(df_processed)
    id_strategy <- attr(out, "id_strategy")

    # No `exclude`: a raw `decimalLatitude` column that the mapping did not
    # read keeps its values as `decimalLatitude_original` (B22).
    extra_cols <- unmapped_raw_columns(raw_data, map_values,
                                       overridden_terms = overridden_terms)
    if (length(extra_cols) == 0L) return(out)

    extras <- blank_coordinate_like_cells(raw_data[, extra_cols, drop = FALSE], sensitive_rows,
                                          sensitive_points)
    # A rescued column can carry the same name as the DwC term whose fixed
    # value replaced it. Both belong in the file, so the raw one takes an
    # `_original` suffix rather than a duplicate header the IPT cannot read.
    clash <- names(extras) %in% names(out)
    names(extras)[clash] <- paste0(names(extras)[clash], "_original")
    unique_names <- make.unique(c(names(out), names(extras)), sep = "_")
    names(extras) <- unique_names[-seq_along(names(out))]
    combined <- cbind(out, extras)
    attr(combined, "id_strategy") <- id_strategy
    combined
}

# A raw column whose name has a coordinate word ("Latitude", "CoordX",
# "Lat_GPS", "decimalLongitude", "UTM", "WKT", "Y_sul"). The test reads whole
# words, so "Longo", "Lontra" and "Lateral" do not match (B59).
coordinate_like_column <- function(names) {
    words <- c("lat", "latitude", "latitud", "lon", "long", "longitude", "longitud",
               "lng", "x", "y", "utm", "wkt", "gps", "easting", "northing", "footprint")
    split <- tolower(gsub("([a-z])([A-Z])", "\\1 \\2", names))
    tokens <- strsplit(split, "[^a-z0-9]+")
    vapply(tokens, function(t) any(t %in% words) || any(startsWith(t, "coord")), logical(1))
}

# On the rows the mask generalized or withheld, blank every unmapped value
# that can hold the exact point (B45): all cells of a coordinate-like column,
# and in the other columns a degree sign or a number closer to the real point
# than the row grid. A pH of 6.5 stays, a copy of -23.5505 goes (B52). A copy
# inside a longer text, such as "GPS -23.5505, -46.6333", gets the published
# value (AUD-02).
blank_coordinate_like_cells <- function(extras, rows, points = NULL) {
    ok <- !is.na(rows) & rows >= 1L & rows <= nrow(extras)
    rows <- rows[ok]
    if (!length(rows) || ncol(extras) == 0L) {
        return(extras)
    }
    near_point <- function(num) rep(FALSE, length(num))
    redact <- function(cell) cell
    if (is.data.frame(points) && nrow(points) == length(ok)) {
        points <- points[ok, , drop = FALSE]
        lat <- as_coord_numeric(points$decimalLatitude)$num
        lon <- as_coord_numeric(points$decimalLongitude)$num
        tol <- suppressWarnings(as.numeric(points$grid))
        tol[is.na(tol) | tol <= 0] <- 1e-6
        near_point <- function(num) {
            !is.na(num) & ((!is.na(lat) & abs(num - lat) < tol) |
                               (!is.na(lon) & abs(num - lon) < tol))
        }
        # The published point, or "" for a point the mask withheld.
        pub_lat <- pub_lon <- rep("", length(rows))
        movable <- sensitive_point_ok(lat, lon)
        for (g in unique(tol[movable])) {
            at <- movable & tol == g
            pub_lat[at] <- as.character(generalize_coord(lat[at], g))
            pub_lon[at] <- as.character(generalize_coord(lon[at], g))
        }
        redact <- function(cell) redact_point_numbers(cell, lat, lon, tol, pub_lat, pub_lon)
    }
    by_name <- coordinate_like_column(names(extras))
    for (j in seq_along(extras)) {
        v <- as.character(extras[[j]])
        hit <- if (by_name[[j]]) {
            rep(TRUE, length(rows))
        } else {
            cell <- trimws(v[rows])
            num <- suppressWarnings(as.numeric(sub(",", ".", cell, fixed = TRUE)))
            near_point(num) | grepl("\u00b0", cell, fixed = TRUE)
        }
        hit[is.na(hit)] <- FALSE
        cell <- v[rows]
        cell[hit] <- NA_character_
        cell[!hit] <- redact(cell)[!hit]
        if (!identical(cell, v[rows])) {
            v[rows] <- cell
            extras[[j]] <- v
        }
    }
    extras
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
#' @param lang Character scalar from `get_languages()` (ou reactive — extraido com `()` se for).
#' @param required_terms Character vector de termos DwC obrigatorios (default = required do preview).
#' @param source_file Optional character: nome do arquivo de origem para metadados.
#' @param id_strategy Optional character: occurrenceID strategy used at export,
#'   as named by `occurrence_id_strategy_label()`. When supplied, an "Identifier
#'   Strategy" section is appended explaining the consequence for GBIF
#'   republication.
#' @param id_counts Optional named list from `resolve_occurrence_ids()`'s
#'   `id_counts` attribute (`total`, `preserved`, `generated`). Reported
#'   verbatim so the reader can check the claim against the file.
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
                                    constants = NULL,
                                    id_counts = NULL) {
    if (is.function(lang)) lang <- lang()
    lang <- as.character(lang)[1L]
    if (!lang %in% get_languages()) lang <- "en"

    if (!is.list(map_values)) map_values <- list()
    if (!is.data.frame(raw_data)) raw_data <- data.frame()
    if (!is.list(constants)) constants <- list()

    # A term whose fixed value won never read its column, so the guide must not
    # claim the column is published under that term -- it lands in the unused
    # section instead, matching what the CSV actually carries.
    overridden <- overridden_mapping_terms(constants)

    # Column mappings: one entry per mapped term (concatenations joined " + ").
    pairs <- list()
    used_sources <- character(0)
    for (term in setdiff(names(map_values), overridden)) {
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

    # Constants: typed/selected literal values applied to every row. `modified`
    # is left out: the card always holds a date, so serializing it would stamp
    # the export day into a dataset-independent template and restore a stale
    # date on the next import.
    const_pairs <- list()
    for (term in setdiff(names(constants), "modified")) {
        val <- constants[[term]]
        if (is.null(val) || length(val) == 0L) next
        val <- trimws(as.character(val)[[1]])
        if (is.na(val) || !nzchar(val)) next
        const_pairs[[length(const_pairs) + 1L]] <- list(value = val, term = term)
    }

    raw_cols <- names(raw_data)
    unmapped_cols <- setdiff(raw_cols, used_sources)
    # ADR-120 makes unmapped_raw_columns() the single source for which columns
    # the CSV actually carries, and it leaves out a column empty in every row.
    # Listing that column under "kept at end of CSV" promised a column the file
    # does not have, so the guide reads it from the same place the file does.
    kept_cols <- unmapped_raw_columns(raw_data, map_values, overridden_terms = overridden)
    empty_cols <- setdiff(unmapped_cols, kept_cols)
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

    # Like the Portuguese text, the Spanish text stays ASCII: the guide is a
    # plain .txt that people open in any editor.
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
            unmp_empty   = "#     Vazias em todas as linhas, entao ficam fora do arquivo:",
            unmp_note_1  = "#     Estas colunas seguem no arquivo, mas NAO sao declaradas no meta.xml,",
            unmp_note_2  = "#     entao o GBIF vai ignora-las. Para publica-las, mapeie cada uma para",
            unmp_note_3  = "#     um termo DwC ou inclua o conteudo em dynamicProperties.",
            coverage     = "# cobertura: %d termo(s) DwC mapeado(s), %d constante(s), %d obrigatorio(s) faltando",
            none         = "(nenhum)"
        )
    } else if (lang == "es") {
        list(
            title        = "#   SAIRA \u00b7 Guia de Mapeo Darwin Core",
            url          = "#   github.com/sibbr/saira",
            tagline      = "#   Vocabulario de mapeo compartible - sin datos de registros",
            how_to_use   = "#   como usar",
            step_1       = "#     1. Cargue su CSV de datos en Saira y abra la pestana Mapeo.",
            step_2       = "#     2. En la barra lateral, haga clic en Importar modelo y elija este .txt.",
            step_3       = "#     3. El mapeo se reconstruye en las tarjetas (concatenaciones y constantes).",
            step_4       = "#     4. Revise y exporte. (Cada columna tambien se vuelve un alias personal reutilizable.)",
            section_map  = "#   mapeos por clase DwC   (columna_origen -> termino_DwC)",
            legend       = "#   las concatenaciones de columnas se unen con el separador \" | \"",
            section_const= "#   constantes   (valor escrito/elegido aplicado a todas las filas)",
            section_miss = "#   terminos DwC obligatorios todavia sin mapear",
            section_unmp = "#   columnas originales sin usar (se mantienen al final del CSV)",
            unmp_empty   = "#     Vacias en todas las filas, por eso quedan fuera del archivo:",
            unmp_note_1  = "#     Estas columnas siguen en el archivo, pero NO se declaran en meta.xml,",
            unmp_note_2  = "#     por eso GBIF las va a ignorar. Para publicarlas, mapee cada una a un",
            unmp_note_3  = "#     termino DwC o incluya su contenido en dynamicProperties.",
            coverage     = "# cobertura: %d termino(s) DwC mapeado(s), %d constante(s), %d obligatorio(s) faltante(s)",
            none         = "(ninguno)"
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
            unmp_empty   = "#     Empty in every row, so they stay out of the file:",
            unmp_note_1  = "#     These columns stay in the file but are NOT declared in meta.xml,",
            unmp_note_2  = "#     so GBIF will ignore them. To publish them, map each one to a DwC",
            unmp_note_3  = "#     term or fold its content into dynamicProperties.",
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
        # Without a loaded sheet, Home reads these headers to tell a name
        # with '+' from a concatenation (ADR-171).
        paste0("# source_columns: ", jsonlite::toJSON(raw_cols, auto_unbox = FALSE)),
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
    if (length(kept_cols) == 0L) {
        out <- c(out, paste0("#     ", L$none))
    } else {
        for (col in kept_cols) {
            out <- c(out, paste0("#     - ", col))
        }
        # Preserving the columns in the CSV is only half the promise: GBIF reads
        # meta.xml, and an undeclared column is invisible in the published
        # dataset. Say so here rather than letting the file imply otherwise.
        out <- c(out, "#", L$unmp_note_1, L$unmp_note_2, L$unmp_note_3)
    }
    # An empty column is still one of the n_cols_unmapped counted in the header.
    # Naming it keeps that arithmetic legible and tells the reader why it is
    # absent, instead of dropping it from the guide without a word.
    if (length(empty_cols) > 0L) {
        out <- c(out, "#", L$unmp_empty,
                 paste0("#       ", paste(empty_cols, collapse = ", ")))
    }

    if (!is.na(id_strategy) && nzchar(id_strategy)) {
        strategy_section <- if (lang == "es") {
            list(
                header = "#   estrategia de occurrenceID",
                explainers = list(
                    user_supplied = "#     Estrategia: user_supplied. Todos los occurrenceID vinieron de sus datos y se conservaron literalmente.",
                    user_supplied_with_generated = "#     Estrategia: user_supplied_with_generated. Los identificadores de sus datos se conservaron; las filas que no tenian uno, o que lo repetian, recibieron un identificador generado por Saira.",
                    generated = "#     Estrategia: generated. Sus datos no tenian identificadores unicos, por eso Saira derivo uno del contenido de cada fila. Volver a cargar la misma hoja de calculo reproduce los mismos identificadores; corregir un valor cambia el identificador de esa fila."
                ),
                counts = "#     Conteo: %d de %d conservados de sus datos, %d generados.",
                roundtrip = c(
                    "#",
                    "#     Para mantener estos identificadores en la proxima exportacion, vuelva a",
                    "#     importar ESTE archivo (o copie la columna occurrenceID a su hoja de",
                    "#     calculo) y mapee occurrenceID. Los existentes se conservan y solo las",
                    "#     ocurrencias nuevas reciben un ID."
                )
            )
        } else if (lang == "pt") {
            list(
                header = "#   estrategia de occurrenceID",
                explainers = list(
                    user_supplied = "#     Estrategia: user_supplied. Todos os occurrenceID vieram dos seus dados e foram preservados literalmente.",
                    user_supplied_with_generated = "#     Estrategia: user_supplied_with_generated. Os identificadores do seu dado foram preservados; as linhas que estavam sem um, ou que repetiam um, receberam um identificador gerado pela Saira.",
                    generated = "#     Estrategia: generated. O seu dado nao carregava identificadores unicos, entao a Saira derivou um do conteudo de cada linha. Reenviar a mesma planilha reproduz os mesmos identificadores; corrigir um valor muda o identificador daquela linha."
                ),
                counts = "#     Contagem: %d de %d preservados do seu dado, %d gerados.",
                roundtrip = c(
                    "#",
                    "#     Para manter estes identificadores na proxima exportacao, reimporte",
                    "#     ESTE arquivo (ou copie a coluna occurrenceID para a sua planilha) e",
                    "#     mapeie occurrenceID. Os existentes sao preservados e so as ocorrencias",
                    "#     novas recebem um ID."
                )
            )
        } else {
            list(
                header = "#   identifier strategy (occurrenceID)",
                explainers = list(
                    user_supplied = "#     Strategy: user_supplied. Every occurrenceID came from your data and was preserved verbatim.",
                    user_supplied_with_generated = "#     Strategy: user_supplied_with_generated. Identifiers from your data were preserved; rows that had none, or repeated one, received one generated by Saira.",
                    generated = "#     Strategy: generated. Your data carried no unique identifiers, so Saira derived one from each row content. Re-uploading the same spreadsheet reproduces the same identifiers; correcting a value changes that row identifier."
                ),
                counts = "#     Counts: %d of %d preserved from your data, %d generated.",
                roundtrip = c(
                    "#",
                    "#     To keep these identifiers on your next export, re-import THIS file",
                    "#     (or copy the occurrenceID column back into your spreadsheet) and map",
                    "#     occurrenceID. Existing ones are preserved and only newly added",
                    "#     occurrences receive an ID."
                )
            )
        }
        out <- c(out, "#", strategy_section$header, "#")
        explainer <- strategy_section$explainers[[id_strategy]]
        if (is.null(explainer)) explainer <- sprintf("#     Strategy: %s.", id_strategy)
        out <- c(out, explainer)

        # The label alone used to be the whole section, and it was wrong often
        # enough to matter. The counts are the check the reader can run against
        # the file itself.
        if (is.list(id_counts) && !is.null(id_counts$total)) {
            out <- c(out, sprintf(
                strategy_section$counts,
                id_counts$preserved %||% 0L, id_counts$total,
                id_counts$generated %||% 0L
            ))
        }
        out <- c(out, strategy_section$roundtrip)
    }

    out
}

#' Canonical names for the three Creative Commons licenses GBIF accepts
#'
#' The short name is what the publisher reads and what the bundle writes: the
#' license card, the `license` data column, the mapping guide and the preview
#' all take their string from this one table (ADR-125). The URI stays in
#' `cc_license_uris()`, where it is a link target rather than a value.
#'
#' @return Named character vector keyed by short token.
#' @export
cc_license_names <- function() {
    c(
        "CC0" = "CC0",
        "CC-BY" = "CC BY 4.0",
        "CC-BY-NC" = "CC BY-NC 4.0"
    )
}

#' Canonical URIs for the three Creative Commons licenses GBIF accepts
#'
#' `http://` plus the `/legalcode` suffix is the machine-readable form GBIF
#' documents and the IPT emits. Only the EML `<intellectualRights>` uses it,
#' as the `<ulink url>` GBIF reads to register the dataset license.
#'
#' @return Named character vector keyed by short token.
#' @export
cc_license_uris <- function() {
    c(
        "CC0" =
            "http://creativecommons.org/publicdomain/zero/1.0/legalcode",
        "CC-BY" = "http://creativecommons.org/licenses/by/4.0/legalcode",
        "CC-BY-NC" = "http://creativecommons.org/licenses/by-nc/4.0/legalcode"
    )
}

#' Resolve any accepted spelling of a CC license to its short token
#'
#' Accepts the short token itself ("CC-BY", "CC-BY-4.0"), either URL scheme,
#' and the URL with or without the `/legalcode` suffix or a trailing slash.
#' Anything else resolves to `NA`, which keeps unknown licenses verbatim
#' wherever this is used.
#'
#' @param x Character vector with license values.
#' @return Character vector of `"CC0"`, `"CC-BY"`, `"CC-BY-NC"` or `NA`.
#' @export
normalize_license_key <- function(x) {
    norm <- tolower(trimws(as.character(x)))
    norm <- gsub("^https?://", "", norm)
    norm <- gsub("/legalcode/?$", "", norm)
    norm <- gsub("/+$", "", norm)

    out <- rep(NA_character_, length(norm))
    out[norm %in% c("cc0", "cc0-1.0", "cc0 1.0",
                    "creativecommons.org/publicdomain/zero/1.0")] <- "CC0"
    out[norm %in% c("cc-by", "cc-by-4.0", "cc by 4.0",
                    "creativecommons.org/licenses/by/4.0")] <- "CC-BY"
    out[norm %in% c("cc-by-nc", "cc-by-nc-4.0", "cc by-nc 4.0",
                    "creativecommons.org/licenses/by-nc/4.0")] <- "CC-BY-NC"
    out
}

#' Abbreviate Creative Commons license values
#'
#' Resolves any accepted spelling to the name in `cc_license_names()`. The
#' preview and the published file both call this, so what the publisher reads
#' on screen is what the file carries (ADR-125). Unknown values pass through.
#'
#' @param x Character vector with license values
#' @return Character vector with known licenses named
#' @export
abbreviate_license <- function(x) {
    x_chr <- as.character(x)
    key <- normalize_license_key(x_chr)
    known <- !is.na(key)

    out <- x_chr
    out[known] <- unname(cc_license_names()[key[known]])
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

#' Populate `occurrenceID`, preserving what the data already carries
#'
#' Thin wrapper over `resolve_occurrence_ids()`, which holds the single rule:
#' an identifier the row already carries wins, and Saira derives one from the
#' row's own content for the gaps. Kept because `process_for_export()` is also
#' called directly (tests, `build_dwca_bundle()`) on frames that never passed
#' through the mapping stage.
#'
#' The returned data frame carries `id_strategy` and `id_counts` attributes
#' documenting what happened; the mapping guide reports them.
#'
#' @param df Data frame.
#' @return Data frame with `occurrenceID` populated.
#' @export
generate_occurrence_ids <- function(df) {
    ids <- resolve_occurrence_ids(df)
    df$occurrenceID <- as.character(ids)
    attr(df, "id_strategy") <- attr(ids, "id_strategy")
    attr(df, "id_counts") <- attr(ids, "id_counts")
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

# Fill a blank countryCode from country (D08). The Coordinates tab resolves
# each country to ISO3 but never wrote the code, so a sheet with only a country
# column published no countryCode. A value the publisher mapped stays, and a
# country the cascade cannot resolve leaves the cell blank.
derive_country_code <- function(df) {
    if (!is.data.frame(df) || nrow(df) == 0L || !"country" %in% names(df)) {
        return(df)
    }
    code <- if ("countryCode" %in% names(df)) {
        as.character(df$countryCode)
    } else {
        rep(NA_character_, nrow(df))
    }
    blank <- is.na(code) | !nzchar(trimws(code))
    if (!any(blank)) {
        return(df)
    }
    iso3 <- tryCatch(coords_country_to_iso3(df$country[blank]), error = function(e) NULL)
    if (is.null(iso3)) {
        return(df)
    }
    code[blank] <- iso3
    if (!"countryCode" %in% names(df) && all(is.na(code))) {
        return(df)
    }
    df$countryCode <- code
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

# An Excel sheet has 1,048,576 rows and the header takes one. writexl stops
# the whole download on a larger table.
xlsx_max_records <- 1048575L

#' Export bundle file names, grouped by role
#'
#' Single source of truth for what the DwC-A download contains, so the Export
#' tab summary and the download handler never drift apart. The Darwin Core
#' Archive core trio keeps its standard names (IPT/GBIF require them); the
#' convenience siblings are renamed after the dataset so a user can tell whose
#' files these are once unzipped (e.g. `meu-data-set-occurrences.xlsx`).
#'
#' @param dataset_name Dataset name (from the `datasetName` constant), or NULL.
#' @param has_sensitive Whether any record was generalized (adds the private
#'   real-coordinates download).
#' @param n_records Number of records. Above `xlsx_max_records` the bundle has
#'   no Excel mirror (AUD-16).
#' @param has_changes Whether the export corrects a value (adds the changes
#'   list).
#' @return List with `slug`, `zip` (download file name), `dwca` (standard core
#'   trio), `auxiliary` (list: `xlsx` when it fits, `mapping_guide`, `changes`
#'   when `has_changes`) and, when
#'   `has_sensitive`, `private` (the real-coordinates `.xlsx`). The private
#'   file has its own download, so a shared bundle never carries the exact
#'   points (ADR-163).
#' @noRd
export_bundle_filenames <- function(dataset_name = NULL, has_sensitive = FALSE,
                                    n_records = 0L, has_changes = FALSE) {
    slug <- slugify_dataset_name(dataset_name)
    if (!nzchar(slug)) slug <- "saira"

    # A list (not a named vector) so absent slots read back as NULL instead of
    # erroring on `[[`.
    auxiliary <- list(
        xlsx = paste0(slug, "-occurrences.xlsx"),
        mapping_guide = paste0(slug, "-mapping-guide.txt")
    )
    if (isTRUE(n_records > xlsx_max_records)) auxiliary$xlsx <- NULL
    if (isTRUE(has_changes)) auxiliary$changes <- paste0(slug, "-changes.csv")
    private <- if (isTRUE(has_sensitive)) paste0(slug, "-sensitive-coords.xlsx")

    list(
        slug = slug,
        zip = paste0(slug, "-dwc-archive.zip"),
        dwca = c("occurrence.txt", "meta.xml", "eml.xml"),
        auxiliary = auxiliary,
        private = private
    )
}
