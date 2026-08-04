# Title: Build the base DwC term set (mapping default)
# Author: Saira maintainers
# Output: inst/extdata/dwc_terms.rds
#
# The default column-mapping term set/order is the "Rede Felinos do Brasil"
# occurrence template (modelo-ocorrencia-rede-felinos-brasil.xlsx, 51 terms),
# plus a curated set of commonly-needed terms kept in the default so that
# date-part composition (year/month/day), high taxonomy, verbatim coordinates,
# catalog identifiers, etc. still work out of the box. Terms dropped from the
# default (disposition, preparations, infraspecificEpithet, verbatimIdentification)
# remain one click away via the "Add term" modal (full catalog).
#
# Metadata strategy:
#   - Terms already in the previous base keep their tuned definition_pt,
#     examples, required and data_type (from the previous dwc_terms.rds).
#   - `class` is taken from the full catalog (TDWG-authoritative) for every
#     term, so the by-class mapping UI groups coherently (e.g. eventDate,
#     year/month/day and sampling terms group under Event; identification
#     terms group under Identification).
#   - The 17 new template terms are pulled entirely from
#     inst/extdata/dwc_full_catalog.rds (PT definition guaranteed).
#
# To regenerate (from the project root):
#   Rscript data-raw/build_dwc_terms.R

# Ordered default term list. xlsx template order, with the kept extras slotted
# into their class so the by-class mapping UI stays coherent. Typos in the xlsx
# header (decimaLatitude, "family ") are corrected to canonical DwC terms.
ordered_terms <- c(
  # Occurrence identifiers
  "occurrenceID", "catalogNumber",
  # Record-level metadata
  "datasetName", "modified", "type", "license", "rightsHolder", "language",
  "institutionCode", "collectionCode", "basisOfRecord", "informationWithheld",
  # Occurrence
  "occurrenceStatus", "recordedBy",
  # Location
  "locationID", "country", "stateProvince", "county", "locality",
  "decimalLatitude", "decimalLongitude", "verbatimLatitude", "verbatimLongitude",
  "coordinateUncertaintyInMeters", "locationRemarks",
  # Event
  "eventID", "parentEventID", "eventDate", "eventTime", "year", "month", "day",
  "samplingEffort", "sampleSizeValue", "sampleSizeUnit", "samplingProtocol",
  "habitat", "fieldNotes",
  # Record-level (dynamic)
  "dynamicProperties",
  # Taxon
  "kingdom", "phylum", "class", "order", "family", "genus", "specificEpithet",
  "taxonRank", "scientificName", "scientificNameAuthorship", "vernacularName",
  "taxonRemarks",
  # Occurrence (organism traits)
  "individualCount", "sex", "lifeStage", "reproductiveCondition", "behavior",
  # Occurrence (establishment). Both carry a TDWG controlled vocabulary and are
  # filled together by the per-species assistant (ADR-110), so they belong in
  # the default set: having to hunt for them in "Add term" first would defeat
  # the assistant's purpose.
  "establishmentMeans", "degreeOfEstablishment",
  # Identification
  "identifiedBy", "identifiedByID", "dateIdentified", "identificationRemarks",
  "identificationQualifier",
  # Occurrence (media / references / remarks)
  "associatedMedia", "associatedReferences", "occurrenceRemarks"
)

stopifnot(!any(duplicated(ordered_terms)))

base_path <- file.path("inst", "extdata", "dwc_terms.rds")
full_path <- file.path("inst", "extdata", "dwc_full_catalog.rds")
prev <- readRDS(base_path)
full <- readRDS(full_path)

missing <- setdiff(ordered_terms, c(prev$term, full$term))
if (length(missing) > 0L) {
  stop("Terms not found in previous base or full catalog: ",
       paste(missing, collapse = ", "))
}

row_for <- function(term) {
  fc_class <- full$class[match(term, full$term)]
  if (term %in% prev$term) {
    r <- prev[prev$term == term, , drop = FALSE]
    # TDWG-authoritative class for coherent by-class grouping.
    if (!is.na(fc_class) && nzchar(fc_class)) r$class <- fc_class
    r
  } else {
    full[match(term, full$term), names(prev), drop = FALSE]
  }
}

new_base <- do.call(rbind, lapply(ordered_terms, row_for))
rownames(new_base) <- NULL

# Assertions -----------------------------------------------------------------
stopifnot(identical(names(new_base), names(prev)))
stopifnot(nrow(new_base) == length(ordered_terms))
stopifnot(identical(new_base$term, ordered_terms))
stopifnot(!any(is.na(new_base$definition_pt) | !nzchar(trimws(new_base$definition_pt))))

# Short card hints -----------------------------------------------------------
# The mapping card grid is three columns wide, so a card gets about 339px at
# 1440px and the description is clamped to two lines. Of the 66 base
# definitions the median is 66 characters, but eleven run past 90 and would be
# cut mid-sentence. Those eleven get a short line written for the card.
#
# definition_pt/definition_en are never edited: the Wiki (mod_wiki.R) and the
# upload requirements panel (utils_upload.R) render the same columns, and there
# the full normative text is what is wanted. The card falls back to the
# definition wherever the hint is empty, and the "?" tooltip always shows the
# definition in full.
#
# What was dropped from each is the usage qualification, not the meaning.
card_hints <- rbind(
  data.frame(
    term = "coordinateUncertaintyInMeters",
    card_hint_pt = "Raio de incerteza das coordenadas, em metros. Zero não é válido.",
    card_hint_en = "Radius of coordinate uncertainty, in meters. Zero is not valid.",
    stringsAsFactors = FALSE
  ),
  data.frame(
    term = "eventID",
    card_hint_pt = "Identificador do evento de amostragem (um local e um tempo).",
    card_hint_en = "Identifier for the sampling event (one place, one time).",
    stringsAsFactors = FALSE
  ),
  data.frame(
    term = "locationID",
    card_hint_pt = "Identificador do conjunto de informações de Localização.",
    card_hint_en = "Identifier for the set of Location information.",
    stringsAsFactors = FALSE
  ),
  data.frame(
    term = "establishmentMeans",
    card_hint_pt = "Se o organismo foi introduzido por ação humana no local.",
    card_hint_en = "Whether the organism was introduced by human activity.",
    stringsAsFactors = FALSE
  ),
  data.frame(
    term = "associatedReferences",
    card_hint_pt = "Literatura associada à Ocorrência: DOI, citação ou URI.",
    card_hint_en = "Literature associated with the Occurrence: DOI, citation or URI.",
    stringsAsFactors = FALSE
  ),
  data.frame(
    term = "sampleSizeValue",
    card_hint_pt = "Valor numérico do tamanho da amostra no evento.",
    card_hint_en = "Numeric value for the sample size in the event.",
    stringsAsFactors = FALSE
  ),
  data.frame(
    term = "identifiedByID",
    card_hint_pt = "Identificadores únicos globais de quem atribuiu o táxon.",
    card_hint_en = "Global unique identifiers of whoever assigned the taxon.",
    stringsAsFactors = FALSE
  ),
  data.frame(
    term = "sampleSizeUnit",
    card_hint_pt = "Unidade de medida do tamanho da amostra.",
    card_hint_en = "Unit of measurement for the sample size.",
    stringsAsFactors = FALSE
  ),
  data.frame(
    term = "associatedMedia",
    card_hint_pt = "Mídias associadas à Ocorrência: URI, DOI ou identificador.",
    card_hint_en = "Media associated with the Occurrence: URI, DOI or identifier.",
    stringsAsFactors = FALSE
  ),
  data.frame(
    term = "lifeStage",
    card_hint_pt = "Classe etária ou estágio de vida do organismo no registro.",
    card_hint_en = "Age class or life stage of the organism when recorded.",
    stringsAsFactors = FALSE
  ),
  data.frame(
    term = "degreeOfEstablishment",
    card_hint_pt = "Grau em que o organismo se estabelece no local.",
    card_hint_en = "Degree to which the organism establishes at the place.",
    stringsAsFactors = FALSE
  )
)

stopifnot(!any(duplicated(card_hints$term)))
stopifnot(all(card_hints$term %in% ordered_terms))

add_card_hints <- function(df) {
  idx <- match(df$term, card_hints$term)
  df$card_hint_pt <- ifelse(is.na(idx), "", card_hints$card_hint_pt[idx])
  df$card_hint_en <- ifelse(is.na(idx), "", card_hints$card_hint_en[idx])
  df
}

new_base <- add_card_hints(new_base)

# A hint that is not shorter than the definition it replaces would only add a
# tooltip for nothing.
hinted <- new_base[nzchar(new_base$card_hint_pt), , drop = FALSE]
stopifnot(all(nchar(hinted$card_hint_pt) < nchar(hinted$definition_pt)))
stopifnot(all(nchar(hinted$card_hint_en) < nchar(hinted$definition_en)))

# Required terms (validation gate + IPT minimum) must stay required.
required_terms <- c(
  "occurrenceID", "license", "institutionCode", "basisOfRecord", "recordedBy",
  "eventDate", "scientificName", "country", "stateProvince", "locality",
  "decimalLatitude", "decimalLongitude"
)
stopifnot(all(new_base$required[match(required_terms, new_base$term)]))

saveRDS(new_base, base_path)
message("Saved: ", base_path, " (", nrow(new_base), " terms, ",
        sum(new_base$required), " required)")

# Keep dwc_full_catalog.rds's "base terms first" invariant in sync with the new
# base (same content, re-ordered: the new base prefix, then the remaining
# recommended terms sorted alphabetically).
extra_rows <- full[!full$term %in% ordered_terms, , drop = FALSE]
extra_rows <- extra_rows[order(extra_rows$term), , drop = FALSE]
# Same columns as the base, so a term pulled in through "Add term" carries the
# hint columns too (empty for all of them today).
extra_rows <- add_card_hints(extra_rows)
new_full <- rbind(new_base, extra_rows)
rownames(new_full) <- NULL
stopifnot(nrow(new_full) == nrow(full))
stopifnot(identical(new_full$term[seq_len(length(ordered_terms))], ordered_terms))
stopifnot(!any(duplicated(new_full$term)))
saveRDS(new_full, full_path)
message("Synced: ", full_path, " (", nrow(new_full), " terms, base-first)")
