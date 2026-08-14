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

# establishmentMeans controlled vocabulary (TDWG, 2026-05-26).
# http://rs.tdwg.org/dwcem/values/ -- controlled values are normative;
# labels and descriptions here are condensed for the assistant UI.
establishment_means_vocab_catalog <- list(
    list(
        term = "native",
        label_en = "native (indigenous)",
        label_pt = "nativa (ind\u00EDgena)",
        desc_en = "A taxon occurring within its natural range.",
        desc_pt = "T\u00E1xon que ocorre dentro de sua distribui\u00E7\u00E3o natural."
    ),
    list(
        term = "nativeEndemic",
        label_en = "native: endemic",
        label_pt = "nativa: end\u00EAmica",
        desc_en = "A taxon with a natural distribution restricted to a single geographical area.",
        desc_pt = "T\u00E1xon com distribui\u00E7\u00E3o natural restrita a uma \u00FAnica \u00E1rea geogr\u00E1fica."
    ),
    list(
        term = "nativeReintroduced",
        label_en = "native: reintroduced",
        label_pt = "nativa: reintroduzida",
        desc_en = "A taxon re-established by humans in an area that was once part of its natural range, but from where it had become extinct.",
        desc_pt = "T\u00E1xon restabelecido por a\u00E7\u00E3o humana em \u00E1rea que j\u00E1 fez parte de sua distribui\u00E7\u00E3o natural, mas de onde havia sido extinto."
    ),
    list(
        term = "introduced",
        label_en = "introduced (alien, exotic, non-native)",
        label_pt = "introduzida (ex\u00F3tica, n\u00E3o nativa)",
        desc_en = "Establishment of a taxon by human agency into an area that is not part of its natural range.",
        desc_pt = "Estabelecimento de um t\u00E1xon por a\u00E7\u00E3o humana em \u00E1rea que n\u00E3o faz parte de sua distribui\u00E7\u00E3o natural."
    ),
    list(
        term = "introducedAssistedColonisation",
        label_en = "introduced: assisted colonisation",
        label_pt = "introduzida: coloniza\u00E7\u00E3o assistida",
        desc_en = "Establishment of a taxon specifically to create a self-sustaining wild population outside its natural range.",
        desc_pt = "Estabelecimento de um t\u00E1xon com a inten\u00E7\u00E3o espec\u00EDfica de criar popula\u00E7\u00E3o silvestre autossustent\u00E1vel fora de sua distribui\u00E7\u00E3o natural."
    ),
    list(
        term = "vagrant",
        label_en = "vagrant (casual)",
        label_pt = "vagante (casual)",
        desc_en = "The temporary occurrence of a taxon far outside its natural or migratory range.",
        desc_pt = "Ocorr\u00EAncia tempor\u00E1ria de um t\u00E1xon muito al\u00E9m de sua distribui\u00E7\u00E3o natural ou migrat\u00F3ria."
    ),
    list(
        term = "uncertain",
        label_en = "uncertain (unknown, cryptogenic)",
        label_pt = "incerta (desconhecida, criptog\u00EAnica)",
        desc_en = "The origin of the occurrence of the taxon in an area is obscure.",
        desc_pt = "A origem da ocorr\u00EAncia do t\u00E1xon na \u00E1rea \u00E9 obscura."
    )
)

# degreeOfEstablishment controlled vocabulary (TDWG, 2026-05-26).
# http://rs.tdwg.org/dwcdoe/values/ -- ordered along the introduction
# pathway (Blackburn et al. categories A to E), which is the order the
# assistant presents them in.
degree_of_establishment_vocab_catalog <- list(
    list(
        term = "native",
        label_en = "native (category A)",
        label_pt = "nativa (categoria A)",
        desc_en = "Not transported beyond limits of native range.",
        desc_pt = "N\u00E3o transportada al\u00E9m dos limites de sua distribui\u00E7\u00E3o nativa."
    ),
    list(
        term = "captive",
        label_en = "captive (category B1)",
        label_pt = "em cativeiro (categoria B1)",
        desc_en = "Individuals in captivity or quarantine, with explicit measures of containment in place.",
        desc_pt = "Indiv\u00EDduos em cativeiro ou quarentena, com medidas expl\u00EDcitas de conten\u00E7\u00E3o."
    ),
    list(
        term = "cultivated",
        label_en = "cultivated (category B2)",
        label_pt = "cultivada (categoria B2)",
        desc_en = "Individuals in cultivation, with measures to prevent dispersal limited at best.",
        desc_pt = "Indiv\u00EDduos em cultivo, com medidas limitadas para impedir a dispers\u00E3o."
    ),
    list(
        term = "released",
        label_en = "released (category B3)",
        label_pt = "solta (categoria B3)",
        desc_en = "Individuals directly released into a novel environment.",
        desc_pt = "Indiv\u00EDduos soltos diretamente em ambiente novo."
    ),
    list(
        term = "failing",
        label_en = "failing (category C0)",
        label_pt = "em decl\u00EDnio (categoria C0)",
        desc_en = "Individuals released outside captivity or cultivation, but incapable of surviving for a significant period.",
        desc_pt = "Indiv\u00EDduos soltos fora de cativeiro ou cultivo, incapazes de sobreviver por per\u00EDodo significativo."
    ),
    list(
        term = "casual",
        label_en = "casual (category C1)",
        label_pt = "casual (categoria C1)",
        desc_en = "Individuals surviving outside captivity or cultivation, with no reproduction.",
        desc_pt = "Indiv\u00EDduos sobrevivendo fora de cativeiro ou cultivo, sem reprodu\u00E7\u00E3o."
    ),
    list(
        term = "reproducing",
        label_en = "reproducing (category C2)",
        label_pt = "reprodutiva (categoria C2)",
        desc_en = "Reproduction is occurring, but the population is not self-sustaining.",
        desc_pt = "H\u00E1 reprodu\u00E7\u00E3o, mas a popula\u00E7\u00E3o n\u00E3o \u00E9 autossustent\u00E1vel."
    ),
    list(
        term = "established",
        label_en = "established (category C3)",
        label_pt = "estabelecida (categoria C3)",
        desc_en = "Reproduction occurring and population self-sustaining.",
        desc_pt = "Reprodu\u00E7\u00E3o ocorrendo e popula\u00E7\u00E3o autossustent\u00E1vel."
    ),
    list(
        term = "colonising",
        label_en = "colonising (category D1)",
        label_pt = "colonizadora (categoria D1)",
        desc_en = "Self-sustaining population, with individuals surviving a significant distance from the original point of introduction.",
        desc_pt = "Popula\u00E7\u00E3o autossustent\u00E1vel, com indiv\u00EDduos sobrevivendo a dist\u00E2ncia significativa do ponto original de introdu\u00E7\u00E3o."
    ),
    list(
        term = "invasive",
        label_en = "invasive (category D2)",
        label_pt = "invasora (categoria D2)",
        desc_en = "Self-sustaining population, with individuals surviving and reproducing a significant distance from the original point of introduction.",
        desc_pt = "Popula\u00E7\u00E3o autossustent\u00E1vel, com indiv\u00EDduos sobrevivendo e se reproduzindo a dist\u00E2ncia significativa do ponto original de introdu\u00E7\u00E3o."
    ),
    list(
        term = "widespreadInvasive",
        label_en = "widespread invasive (category E)",
        label_pt = "invasora disseminada (categoria E)",
        desc_en = "Fully invasive species, dispersing, surviving and reproducing at multiple sites across a spectrum of habitats.",
        desc_pt = "Esp\u00E9cie plenamente invasora, dispersando, sobrevivendo e se reproduzindo em m\u00FAltiplos locais e h\u00E1bitats."
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
#' Short card text for each term, falling back to the full definition
#'
#' `card_hint_pt`/`card_hint_en` are filled only for the terms whose definition
#' is too long for a mapping card (see data-raw/build_dwc_terms.R). Everywhere
#' else the card shows the definition itself. Returns `desc` unchanged when the
#' columns are absent, so an older cached rds still works.
#'
#' @param terms_df DwC terms data frame.
#' @param lang Language code ("pt" or "en").
#' @param desc Character vector of definitions, already resolved for `lang`.
#' @return Character vector the same length as `desc`.
#' @noRd
dwc_card_hints <- function(terms_df, lang, desc) {
    col <- if (identical(lang, "pt")) "card_hint_pt" else "card_hint_en"
    if (!col %in% names(terms_df)) {
        return(desc)
    }
    hint <- as.character(terms_df[[col]])
    hint[is.na(hint)] <- ""
    ifelse(nzchar(hint), hint, desc)
}

#' Get Darwin Core terms as list
#'
#' Returns DwC terms in list format for the mapping module UI. Each item has:
#' `term`, `category`, `desc`, `hint`, `sep`, `required`.
#'
#' @param lang Language code ("pt" or "en").
#' @return Named list of DwC term definitions.
#' @export
get_dwc_terms_list <- function(lang = "en") {
    terms_df <- load_dwc_terms_rds()

    # Columns are extracted once and zipped with Map(); the previous per-row
    # lapply re-indexed the data frame four times per term.
    n <- nrow(terms_df)
    desc <- if (lang == "pt" && "definition_pt" %in% names(terms_df)) {
        as.character(terms_df$definition_pt)
    } else if ("definition_en" %in% names(terms_df)) {
        as.character(terms_df$definition_en)
    } else {
        rep("", n)
    }

    terms_list <- Map(
        function(term, category, desc, hint, required) {
            list(
                term = term,
                category = category,
                desc = desc,
                hint = hint,
                sep = "",
                required = required
            )
        },
        as.character(terms_df$term),
        as.character(terms_df$class),
        desc,
        dwc_card_hints(terms_df, lang, desc),
        dwc_required_flags(terms_df),
        USE.NAMES = FALSE
    )

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

    # Same column-wise construction as get_dwc_terms_list(), with the extra
    # rule that a blank Portuguese definition falls back to English.
    n <- nrow(terms_df)
    desc <- if (lang == "pt" && "definition_pt" %in% names(terms_df)) {
        pt <- as.character(terms_df$definition_pt)
        en <- as.character(terms_df$definition_en)
        ifelse(nzchar(pt), pt, en)
    } else if ("definition_en" %in% names(terms_df)) {
        as.character(terms_df$definition_en)
    } else {
        rep("", n)
    }

    terms_list <- Map(
        function(term, category, desc, hint, required) {
            list(
                term     = term,
                category = category,
                desc     = desc,
                hint     = hint,
                sep      = "",
                required = required
            )
        },
        as.character(terms_df$term),
        as.character(terms_df$class),
        desc,
        dwc_card_hints(terms_df, lang, desc),
        dwc_required_flags(terms_df),
        USE.NAMES = FALSE
    )

    names(terms_list) <- terms_df$term
    terms_list
}

# Per-term `required` flag as a logical vector. Mirrors the previous per-row
# isTRUE(): TRUE only for a non-NA logical TRUE, FALSE for anything else
# (missing column, or a column that is not logical at all).
dwc_required_flags <- function(terms_df) {
    n <- nrow(terms_df)
    if (!"required" %in% names(terms_df)) {
        return(rep(FALSE, n))
    }
    required <- terms_df$required
    if (!is.logical(required)) {
        return(rep(FALSE, n))
    }
    !is.na(required) & required
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

#' Dataset-level terms eligible for a fixed (constant) value
#'
#' Single source of truth for the terms whose mapping card offers an opt-in
#' "use a fixed value" input applied to every row (extends ADR-005). Consumed by
#' the card builder, the value collector, the meta observers and the export
#' injector. `datasetName`/`modified`/`license`/`language` keep their own
#' dedicated inputs and are intentionally excluded here; `countryCode` is
#' derived during coordinate validation and `basisOfRecord` has the per-value
#' assistant, so both are excluded too.
#'
#' @return Character vector of DwC term names.
#' @noRd
constant_value_terms <- function() {
    c(
        "rightsHolder", "institutionCode", "collectionCode", "country",
        "references", "bibliographicCitation", "geodeticDatum"
    )
}

#' Terms the mapping screen treats as required
#'
#' Single source of truth for the sidebar readiness strip, the card state
#' modifier and the "next pending" queue, so the three never disagree about
#' what is missing. Narrower than the `required` flag in dwc_terms.rds, which
#' also covers the IPT publishing minimum.
#'
#' @return Character vector of DwC term names.
#' @noRd
required_mapping_terms <- function() {
    c(
        "scientificName", "eventDate", "decimalLatitude",
        "decimalLongitude", "basisOfRecord", "occurrenceID"
    )
}

#' Terms whose mapping card spans two grid tracks
#'
#' `dynamicProperties` builds one `bslib::layout_columns(col_widths = c(5, 7))`
#' row per selected column, and bslib breakpoints follow the viewport rather
#' than the container: inside a one-track card at 1440px the two columns stay
#' side by side and the key input drops to roughly 198px. Spanning two tracks
#' keeps it at the width it had under the old two-column grid. The other cards
#' with their own block (license, language, modified, the fixed-value input and
#' the two assistant buttons) are full-width inside the card and need no span.
#'
#' @return Character vector of DwC term names.
#' @noRd
wide_card_terms <- function() {
    c("dynamicProperties")
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

# The establishment vocabularies share basisOfRecord's catalog shape, so the
# accessors below take the catalog instead of being copied per vocabulary.
dwc_vocab_terms <- function(catalog) {
    vapply(catalog, function(item) item$term, FUN.VALUE = character(1))
}

is_valid_dwc_vocab_term <- function(value, catalog) {
    if (is.null(value) || length(value) == 0) {
        return(FALSE)
    }
    value_chr <- trimws(as.character(value)[[1]])
    nzchar(value_chr) && value_chr %in% dwc_vocab_terms(catalog)
}

# Choices for a controlled-vocabulary select: "term - description", value =
# term. The leading blank entry is what "not set" looks like in the assistant.
dwc_vocab_choices <- function(catalog, lang = "en", include_skip = TRUE, skip_label = NULL) {
    use_lang <- if (identical(lang, "pt")) "pt" else "en"
    labels <- vapply(
        catalog,
        function(item) {
            desc <- if (use_lang == "pt") item$desc_pt else item$desc_en
            paste0(item$term, " - ", desc)
        },
        FUN.VALUE = character(1)
    )
    choices <- stats::setNames(dwc_vocab_terms(catalog), labels)
    if (isTRUE(include_skip)) {
        final_skip_label <- skip_label
        if (is.null(final_skip_label) || !nzchar(as.character(final_skip_label))) {
            final_skip_label <- if (identical(lang, "pt")) "-- N\u00E3o definir --" else "-- Not set --"
        }
        choices <- c(stats::setNames("", final_skip_label), choices)
    }
    choices
}

get_establishment_means_terms <- function() {
    dwc_vocab_terms(establishment_means_vocab_catalog)
}

get_degree_of_establishment_terms <- function() {
    dwc_vocab_terms(degree_of_establishment_vocab_catalog)
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
