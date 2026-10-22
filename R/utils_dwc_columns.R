# Utils dwc columns

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

dwc_class_translation_keys <- function() c(
            "Record-level"          = "class_record",
            "Occurrence"            = "class_occurrence",
            "Event"                 = "class_event",
            "Location"              = "class_location",
            "Taxon"                 = "class_taxon",
            "Identification"        = "class_identification",
            "GeologicalContext"     = "class_geologicalcontext",
            "MaterialEntity"        = "class_materialentity",
            "MaterialSample"        = "class_materialsample",
            "MeasurementOrFact"     = "class_measurementorfact",
            "Organism"              = "class_organism",
            "ResourceRelationship"  = "class_resourcerelationship",
            "Agent"                 = "class_agent",
            "Assertion"             = "class_assertion",
            "BibliographicResource" = "class_bibliographicresource",
            "MolecularProtocol"     = "class_molecularprotocol",
            "NucleotideAnalysis"    = "class_nucleotideanalysis",
            "NucleotideSequence"    = "class_nucleotidesequence",
            "OrganismInteraction"   = "class_organisminteraction",
            "Protocol"              = "class_protocol",
            "Provenance"            = "class_provenance"
        )
