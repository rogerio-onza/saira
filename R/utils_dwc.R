# Title: Darwin Core Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-14
# Version: 1.1

dwc_terms_cache_env <- new.env(parent = emptyenv())
dwc_terms_cache_env$value <- NULL
dwc_terms_cache_env$path <- NULL
dwc_terms_cache_env$load_count <- 0L

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

resolve_dwc_terms_path <- function() {
    candidates <- c(
        system.file("extdata", "dwc_terms.rds", package = "finch"),
        here::here("inst", "extdata", "dwc_terms.rds"),
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

validate_force_flag <- function(force) {
    if (!is.logical(force) || length(force) != 1L || is.na(force)) {
        stop("force must be a single TRUE or FALSE value.")
    }
}

reset_dwc_terms_cache <- function() {
    dwc_terms_cache_env$value <- NULL
    dwc_terms_cache_env$path <- NULL
    dwc_terms_cache_env$load_count <- 0L
    invisible(TRUE)
}

dwc_terms_cache_state <- function() {
    list(
        has_value = !is.null(dwc_terms_cache_env$value),
        path = dwc_terms_cache_env$path,
        load_count = as.integer(dwc_terms_cache_env$load_count)
    )
}

#' Validate coordinates (WGS84)
#'
#' @param lat Numeric vector of latitudes
#' @param lon Numeric vector of longitudes
#' @return Data frame with validation results
#' @export
validate_coords <- function(lat, lon) {
    # Convert to numeric if needed
    lat <- suppressWarnings(as.numeric(gsub(",", ".", lat)))
    lon <- suppressWarnings(as.numeric(gsub(",", ".", lon)))

    # Check ranges
    lat_valid <- !is.na(lat) & lat >= -90 & lat <= 90
    lon_valid <- !is.na(lon) & lon >= -180 & lon <= 180

    # Combined validity
    valid <- lat_valid & lon_valid

    # Generate error messages
    error <- rep(NA_character_, length(lat))
    error[!lat_valid & !is.na(lat)] <- "Latitude out of range (-90 to 90)"
    error[!lon_valid & !is.na(lon)] <- "Longitude out of range (-180 to 180)"
    error[is.na(lat) | is.na(lon)] <- "Missing coordinates"

    data.frame(
        decimalLatitude = lat,
        decimalLongitude = lon,
        valid = valid,
        error = error,
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

    if (!isTRUE(force) && !is.null(dwc_terms_cache_env$value)) {
        return(dwc_terms_cache_env$value)
    }

    path <- resolve_dwc_terms_path()
    terms <- readRDS(path)

    dwc_terms_cache_env$value <- terms
    dwc_terms_cache_env$path <- path
    dwc_terms_cache_env$load_count <- as.integer(dwc_terms_cache_env$load_count) + 1L

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
