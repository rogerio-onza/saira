# Title: Darwin Core Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-14
# Version: 1.1

#' @include utils_common.R
NULL
dwc_terms_cache      <- create_rds_cache("dwc_terms")
dwc_full_cat_cache   <- create_rds_cache("dwc_full_catalog")

basis_of_record_vocab_catalog <- list(
    list(
        term = "PreservedSpecimen",
        label_en = "Preserved Specimen",
        label_pt = "Esp\u00E9cime Preservado",
        desc_en = "Specimen preserved in a biological collection.",
        desc_pt = "Esp\u00E9cime preservado em cole\u00E7\u00E3o biol\u00F3gica."
    ),
    list(
        term = "FossilSpecimen",
        label_en = "Fossil Specimen",
        label_pt = "Esp\u00E9cime F\u00F3ssil",
        desc_en = "Preserved specimen that is a fossil.",
        desc_pt = "Esp\u00E9cime preservado que \u00E9 f\u00F3ssil."
    ),
    list(
        term = "LivingSpecimen",
        label_en = "Living Specimen",
        label_pt = "Esp\u00E9cime Vivo",
        desc_en = "Specimen that is currently alive.",
        desc_pt = "Esp\u00E9cime atualmente vivo."
    ),
    list(
        term = "HumanObservation",
        label_en = "Human Observation",
        label_pt = "Observa\u00E7\u00E3o por Humano",
        desc_en = "Direct observation performed by a person.",
        desc_pt = "Observa\u00E7\u00E3o direta realizada por pessoa."
    ),
    list(
        term = "MachineObservation",
        label_en = "Machine Observation",
        label_pt = "Observa\u00E7\u00E3o por M\u00E1quina",
        desc_en = "Observation produced by camera, sensor, or recorder.",
        desc_pt = "Observa\u00E7\u00E3o gerada por c\u00E2mera, sensor ou gravador."
    ),
    list(
        term = "MaterialSample",
        label_en = "Material Sample",
        label_pt = "Amostra",
        desc_en = "Physical result obtained from a sampling event.",
        desc_pt = "Resultado f\u00EDsico obtido em evento de amostragem."
    ),
    list(
        term = "MaterialCitation",
        label_en = "Material Citation",
        label_pt = "Cita\u00E7\u00E3o de Material",
        desc_en = "Reference to material cited in publications.",
        desc_pt = "Refer\u00EAncia a material citado em publica\u00E7\u00F5es."
    ),
    list(
        term = "Occurrence",
        label_en = "Occurrence",
        label_pt = "Ocorr\u00EAncia",
        desc_en = "Record of organism existence at place and time.",
        desc_pt = "Registro de exist\u00EAncia de organismo em lugar e tempo."
    )
)

#' @noRd
resolve_dwc_full_catalog_path <- function() {
    candidates <- c(
        system.file("extdata", "dwc_full_catalog.rds", package = "saira"),
        file.path("inst", "extdata", "dwc_full_catalog.rds"),
        file.path("..", "..", "inst", "extdata", "dwc_full_catalog.rds")
    )
    candidates <- unique(candidates[nzchar(candidates)])
    path <- candidates[file.exists(candidates)][1]
    if (is.null(path) || !file.exists(path)) {
        stop("dwc_full_catalog.rds not found in expected locations.")
    }
    path
}

#' @noRd
resolve_dwc_terms_path <- function() {
    candidates <- c(
        system.file("extdata", "dwc_terms.rds", package = "saira"),
        file.path("inst", "extdata", "dwc_terms.rds"),
        file.path("..", "..", "inst", "extdata", "dwc_terms.rds")
    )
    candidates <- unique(candidates[nzchar(candidates)])
    path <- candidates[file.exists(candidates)][1]

    if (is.null(path) || !file.exists(path)) {
        stop("dwc_terms.rds not found in expected locations.")
    }

    path
}

#' @noRd
validate_force_flag <- function(force) {
    if (!is.logical(force) || length(force) != 1L || is.na(force)) {
        stop("force must be a single TRUE or FALSE value.")
    }
}

#' @noRd
reset_dwc_terms_cache <- function() {
    dwc_terms_cache$reset()
}

#' @noRd
dwc_terms_cache_state <- function() {
    dwc_terms_cache$state()
}

#' Validate coordinates (legacy wrapper)
#'
#' Legacy API wrapper around `validate_coords_df()`. Kept for backward
#' compatibility with existing callers that pass latitude/longitude vectors.
#'
#' @param lat Numeric vector of latitudes
#' @param lon Numeric vector of longitudes
#' @return Data frame with validation results
#' @examples
#' \dontrun{
#'   # Validates coordinate pairs using CoordinateCleaner (can be slow)
#'   lat_vec <- c(-23.5505, -22.9068, 91)  # Note: 91 is invalid
#'   lon_vec <- c(-46.6333, -43.1729, 0)
#'   result <- validate_coords(lat_vec, lon_vec)
#'   # $valid: c(TRUE, TRUE, FALSE)
#' }
#' @export
validate_coords <- function(lat, lon) {
    input_df <- data.frame(
        decimalLatitude = lat,
        decimalLongitude = lon,
        stringsAsFactors = FALSE
    )

    result_df <- validate_coords_df(
        df = input_df,
        lat_col = "decimalLatitude",
        lon_col = "decimalLongitude"
    )

    legacy_error_map <- c(
        ok = NA_character_,
        missing = "Missing coordinates",
        lat_range = "Latitude out of range (-90 to 90)",
        lon_range = "Longitude out of range (-180 to 180)",
        zero_zero = "Zero-zero coordinates",
        swapped = "Possible latitude/longitude swap",
        identical_all = "Identical coordinates in all rows"
    )
    issue_key <- as.character(result_df$issue_type)
    issue_key[is.na(issue_key) | !nzchar(issue_key)] <- "missing"
    legacy_error <- unname(legacy_error_map[issue_key])
    legacy_error[issue_key == "ok"] <- NA_character_

    data.frame(
        decimalLatitude = result_df$decimalLatitude,
        decimalLongitude = result_df$decimalLongitude,
        valid = result_df$valid,
        issue_type = result_df$issue_type,
        error_key = result_df$error_key,
        error = legacy_error,
        stringsAsFactors = FALSE
    )
}

#' Check for unique occurrence IDs
#'
#' @param ids Character vector of occurrence IDs
#' @return Logical vector indicating uniqueness
#' @export
validate_occurrence_id <- function(ids) {
    !duplicated(ids) & !is.na(ids) & ids != ""
}

#' Load Darwin Core terms from RDS
#'
#' @param force Logical scalar. If TRUE, invalidate cache and reload from disk.
#' @return Data frame with DwC terms
#' @export
load_dwc_terms_rds <- function(force = FALSE) {
    validate_force_flag(force)

    if (!isTRUE(force) && !is.null(dwc_terms_cache$get())) {
        return(dwc_terms_cache$get())
    }

    path <- resolve_dwc_terms_path()
    terms <- readRDS(path)

    dwc_terms_cache$set(terms, path = path)

    terms
}

#' Get Darwin Core terms for SiBBr
#'
#' @return Data frame with DwC terms
#' @export
get_dwc_terms <- function() {
    load_dwc_terms_rds()
}

#' Get required Darwin Core terms
#'
#' @return Data frame with required DwC terms
#' @export
get_required_dwc_terms <- function() {
    terms <- load_dwc_terms_rds()
    terms[terms$required, , drop = FALSE]
}

#' Get complete Darwin Core term catalog (TDWG dwc: + dcterms:)
#'
#' Returns all ~218 recommended DwC properties including terms beyond the
#' 50-term mapping base set. Used by the wiki and the "add term" search modal.
#' Base terms appear first; extras are sorted alphabetically.
#'
#' @return Data frame with columns: term, class, definition_en, definition_pt,
#'   examples, required, data_type
#' @export
get_dwc_full_catalog <- function() {
    cached <- dwc_full_cat_cache$get()
    if (!is.null(cached)) return(cached)
    path <- resolve_dwc_full_catalog_path()
    cat_df <- readRDS(path)
    dwc_full_cat_cache$set(cat_df, path = path)
    cat_df
}

#' Get active DwC term list for the current mapping session
#'
#' Combines the 50 base terms with any extra terms added by the user in the
#' current session. Returns a data frame in the same schema as
#' \code{get_dwc_terms()} so all existing consumers work without change.
#'
#' @param extra Character vector of extra term names to append (default: none)
#' @return Data frame with the same 7-column schema as \code{get_dwc_terms()}
#' @export
get_active_dwc_terms <- function(extra = character(0)) {
    base <- get_dwc_terms()
    if (length(extra) == 0L) return(base)
    full <- get_dwc_full_catalog()
    extra_df <- full[full$term %in% extra & !full$term %in% base$term, ,
                     drop = FALSE]
    rbind(base, extra_df)
}

#' Get Darwin Core terms as list
#'
#' Returns DwC terms in list format for the mapping module UI.
#' Each item has: term, category, desc, sep
#'
#' @param lang Language code ("pt" or "en")
#' @return Named list of DwC term definitions
#' @export
get_dwc_terms_list <- function(lang = "en") {
    terms_df <- load_dwc_terms_rds()

    terms_list <- lapply(seq_len(nrow(terms_df)), function(i) {
        term_val <- as.character(terms_df$term[i])
        class_val <- as.character(terms_df$class[i])

        desc <- if (lang == "pt" && "definition_pt" %in% names(terms_df)) {
            as.character(terms_df$definition_pt[i])
        } else if ("definition_en" %in% names(terms_df)) {
            as.character(terms_df$definition_en[i])
        } else {
            ""
        }

        required_val <- if ("required" %in% names(terms_df)) {
            isTRUE(terms_df$required[i])
        } else {
            FALSE
        }

        list(
            term = term_val,
            category = class_val,
            desc = desc,
            sep = "",
            required = required_val
        )
    })

    names(terms_list) <- terms_df$term
    terms_list
}

#' Get active DwC terms as list (mapping module format)
#'
#' Combines base terms with session-extra terms and returns the named list
#' format expected by \code{build_field_card()} and \code{build_processed_mapping_df()}.
#'
#' @param extra Character vector of extra term names added in the session
#' @param lang Language code ("pt" or "en")
#' @return Named list of DwC term definitions (same format as get_dwc_terms_list)
#' @export
get_active_dwc_terms_list <- function(extra = character(0), lang = "en") {
    terms_df <- get_active_dwc_terms(extra = extra)

    terms_list <- lapply(seq_len(nrow(terms_df)), function(i) {
        term_val  <- as.character(terms_df$term[i])
        class_val <- as.character(terms_df$class[i])

        desc <- if (lang == "pt" && "definition_pt" %in% names(terms_df)) {
            pt <- as.character(terms_df$definition_pt[i])
            if (nzchar(pt)) pt else as.character(terms_df$definition_en[i])
        } else if ("definition_en" %in% names(terms_df)) {
            as.character(terms_df$definition_en[i])
        } else {
            ""
        }

        required_val <- if ("required" %in% names(terms_df)) {
            isTRUE(terms_df$required[i])
        } else {
            FALSE
        }

        list(
            term     = term_val,
            category = class_val,
            desc     = desc,
            sep      = "",
            required = required_val
        )
    })

    names(terms_list) <- terms_df$term
    terms_list
}

#' Detect uploaded columns that are valid DwC terms outside the base set
#'
#' Returns the subset of \code{columns} whose names are valid Darwin Core terms
#' present in the full catalog but not in the curated base set. These can be
#' auto-registered as session extra terms so they become first-class mapping
#' targets instead of being treated as unknown columns. The main driver is
#' camera-trap ingestion: \code{camtrapdp::write_dwc()} emits terms such as
#' \code{geodeticDatum}, \code{taxonID}, \code{organismID},
#' \code{coordinatePrecision} and \code{identificationVerificationStatus} that
#' are real DwC terms but not in Saira's default list.
#'
#' @param columns Character vector of uploaded column names.
#' @return Character vector of catalog-valid, non-base term names (input order).
#' @export
detect_extra_dwc_terms <- function(columns) {
    columns <- unique(as.character(columns))
    columns <- columns[!is.na(columns) & nzchar(columns)]
    if (length(columns) == 0L) return(character(0))
    base_terms <- get_dwc_terms()$term
    catalog_terms <- get_dwc_full_catalog()$term
    columns[columns %in% catalog_terms & !columns %in% base_terms]
}

get_basis_of_record_vocab <- function(lang = "en") {
    use_lang <- if (identical(lang, "pt")) "pt" else "en"

    lapply(basis_of_record_vocab_catalog, function(item) {
        list(
            term = item$term,
            label = if (use_lang == "pt") item$label_pt else item$label_en,
            description = if (use_lang == "pt") item$desc_pt else item$desc_en,
            label_pt = item$label_pt,
            label_en = item$label_en,
            desc_pt = item$desc_pt,
            desc_en = item$desc_en
        )
    })
}

get_basis_of_record_terms <- function() {
    vapply(
        basis_of_record_vocab_catalog,
        FUN = function(item) item$term,
        FUN.VALUE = character(1)
    )
}

is_valid_basis_of_record_term <- function(value) {
    if (is.null(value) || length(value) == 0) {
        return(FALSE)
    }

    value_chr <- trimws(as.character(value)[[1]])
    nzchar(value_chr) && value_chr %in% get_basis_of_record_terms()
}

get_basis_of_record_term_choices <- function(lang = "en", include_skip = TRUE, with_description = TRUE, skip_label = NULL) {
    vocab <- get_basis_of_record_vocab(lang = lang)

    labels <- vapply(
        vocab,
        FUN = function(item) {
            if (isTRUE(with_description)) {
                paste0(item$term, " - ", item$description)
            } else {
                item$term
            }
        },
        FUN.VALUE = character(1)
    )
    values <- vapply(vocab, function(item) item$term, FUN.VALUE = character(1))

    choices <- stats::setNames(values, labels)
    if (isTRUE(include_skip)) {
        final_skip_label <- skip_label
        if (is.null(final_skip_label) || !nzchar(as.character(final_skip_label))) {
            final_skip_label <- if (identical(lang, "pt")) "-- N\u00E3o mapear --" else "-- Skip --"
        }
        choices <- c(stats::setNames("", final_skip_label), choices)
    }

    choices
}
