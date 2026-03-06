# Generate DwC synonym bundle for the Rostrum auto-mapping engine.
# Output: inst/extdata/dwc_synonyms_v1.rds
#
# Rules enforced by sanitize_synonyms_table():
#   - name_score in [0.90, 0.98]
#   - lang in {"pt", "en", "any"}
#   - No duplicated active (term, synonym, lang) triples after normalization
#
# Conventions for this bundle:
#   - New aliases use "pt" or "en" only (never "any")
#   - Existing "any" entries retained for backward compatibility
#   - No aliases that are generic/ambiguous standalone tokens
#     (avoided: "id", "name", "type", "data", "local" as sole alias)
#   - No alias identical to the DwC term name (normalization-aware)
#
# To regenerate:
#   setwd(here::here()); source("data-raw/generate_rostrum_synonyms.R")

dwc_synonyms <- data.frame(
    term = c(
        # --- scientificName ---
        "scientificName", "scientificName", "scientificName",
        "scientificName", "scientificName",
        # --- decimalLatitude ---
        "decimalLatitude", "decimalLatitude", "decimalLatitude",
        # --- decimalLongitude ---
        "decimalLongitude", "decimalLongitude", "decimalLongitude",
        # --- individualCount ---
        "individualCount", "individualCount", "individualCount",
        # --- recordedBy (base) ---
        "recordedBy", "recordedBy",
        # --- basisOfRecord (base) ---
        "basisOfRecord", "basisOfRecord",
        # --- samplingProtocol ---
        "samplingProtocol",
        # --- samplingEffort ---
        "samplingEffort",
        # --- catalogNumber (base) ---
        "catalogNumber",
        # --- collectionCode (base) ---
        "collectionCode",
        # --- institutionCode (base) ---
        "institutionCode",
        # --- datasetName ---
        "datasetName",
        # --- rightsHolder ---
        "rightsHolder",
        # --- dynamicProperties ---
        "dynamicProperties",
        # --- eventDate (base) ---
        "eventDate",
        # --- year / month / day ---
        "year", "month", "day",
        # --- dateIdentified ---
        "dateIdentified",

        # ===== REINFORCEMENT: eventDate =====
        "eventDate", "eventDate", "eventDate", "eventDate", "eventDate",

        # ===== REINFORCEMENT: recordedBy =====
        "recordedBy", "recordedBy", "recordedBy", "recordedBy",

        # ===== REINFORCEMENT: basisOfRecord =====
        "basisOfRecord", "basisOfRecord", "basisOfRecord",

        # ===== REINFORCEMENT: catalogNumber =====
        "catalogNumber", "catalogNumber", "catalogNumber", "catalogNumber",

        # ===== REINFORCEMENT: collectionCode =====
        "collectionCode", "collectionCode", "collectionCode",

        # ===== REINFORCEMENT: institutionCode =====
        "institutionCode", "institutionCode", "institutionCode",

        # ===== NEW: type =====
        "type", "type", "type", "type",

        # ===== NEW: disposition =====
        "disposition", "disposition", "disposition", "disposition",

        # ===== NEW: preparations =====
        "preparations", "preparations", "preparations", "preparations",

        # ===== NEW: occurrenceRemarks =====
        "occurrenceRemarks", "occurrenceRemarks", "occurrenceRemarks", "occurrenceRemarks",

        # ===== NEW: kingdom =====
        "kingdom", "kingdom",

        # ===== NEW: phylum =====
        "phylum", "phylum", "phylum",

        # ===== NEW: class =====
        "class", "class",

        # ===== NEW: order =====
        "order", "order",

        # ===== NEW: family =====
        "family", "family",

        # ===== NEW: genus =====
        "genus", "genus",

        # ===== NEW: specificEpithet =====
        "specificEpithet", "specificEpithet", "specificEpithet",

        # ===== NEW: infraspecificEpithet =====
        "infraspecificEpithet", "infraspecificEpithet",
        "infraspecificEpithet", "infraspecificEpithet",

        # ===== NEW: taxonRank =====
        "taxonRank", "taxonRank", "taxonRank", "taxonRank",

        # ===== NEW: scientificNameAuthorship =====
        "scientificNameAuthorship", "scientificNameAuthorship",
        "scientificNameAuthorship", "scientificNameAuthorship",
        "scientificNameAuthorship",

        # ===== NEW: verbatimIdentification =====
        "verbatimIdentification", "verbatimIdentification",
        "verbatimIdentification", "verbatimIdentification",

        # ===== NEW: identificationQualifier =====
        "identificationQualifier", "identificationQualifier",
        "identificationQualifier", "identificationQualifier",

        # ===== NEW: vernacularName =====
        "vernacularName", "vernacularName", "vernacularName",
        "vernacularName", "vernacularName",

        # ===== NEW: identifiedBy =====
        "identifiedBy", "identifiedBy", "identifiedBy", "identifiedBy",

        # ===== NEW: country =====
        "country", "country", "country", "country",

        # ===== NEW: stateProvince =====
        "stateProvince", "stateProvince", "stateProvince",
        "stateProvince", "stateProvince",

        # ===== NEW: county =====
        "county", "county", "county",

        # ===== NEW: locality =====
        "locality", "locality", "locality",

        # ===== NEW: locationRemarks =====
        "locationRemarks", "locationRemarks", "locationRemarks", "locationRemarks",

        # ===== NEW: verbatimLatitude =====
        "verbatimLatitude", "verbatimLatitude", "verbatimLatitude",

        # ===== NEW: verbatimLongitude =====
        "verbatimLongitude", "verbatimLongitude", "verbatimLongitude",

        # ===== NEW: fieldNotes =====
        "fieldNotes", "fieldNotes", "fieldNotes", "fieldNotes",

        # ===== NEW: habitat =====
        "habitat", "habitat", "habitat"
    ),
    synonym = c(
        # --- scientificName ---
        "nome cientifico", "species name", "taxon name",
        "species", "especie",
        # --- decimalLatitude ---
        "latitude", "lat", "latitude decimal",
        # --- decimalLongitude ---
        "longitude", "lon", "long",
        # --- individualCount ---
        "count", "abundance", "numero individuos",
        # --- recordedBy (base) ---
        "collector", "collected by",
        # --- basisOfRecord (base) ---
        "record type", "basis record",
        # --- samplingProtocol ---
        "sampling method",
        # --- samplingEffort ---
        "effort",
        # --- catalogNumber (base) ---
        "catalog id",
        # --- collectionCode (base) ---
        "collection id",
        # --- institutionCode (base) ---
        "institution id",
        # --- datasetName ---
        "dataset",
        # --- rightsHolder ---
        "rights owner",
        # --- dynamicProperties ---
        "additional properties",
        # --- eventDate (base) ---
        "data coleta",
        # --- year / month / day ---
        "ano", "mes", "dia",
        # --- dateIdentified ---
        "data identificacao",

        # ===== REINFORCEMENT: eventDate =====
        "data de coleta", "data da coleta", "collection date", "date collected", "event date",

        # ===== REINFORCEMENT: recordedBy =====
        "coletor", "coletores", "collectors", "coletado por",

        # ===== REINFORCEMENT: basisOfRecord =====
        "base do registro", "tipo de registro", "basis of record",

        # ===== REINFORCEMENT: catalogNumber =====
        "numero de catalogo", "numero tombo", "catalog number", "specimen number",

        # ===== REINFORCEMENT: collectionCode =====
        "codigo da colecao", "sigla da colecao", "collection code",

        # ===== REINFORCEMENT: institutionCode =====
        "codigo da instituicao", "sigla da instituicao", "institution code",

        # ===== NEW: type =====
        "tipo de objeto", "tipo de recurso", "object type", "resource type",

        # ===== NEW: disposition =====
        "disposicao do especime", "condicao do especime",
        "sample disposition", "specimen condition",

        # ===== NEW: preparations =====
        "preparacoes", "tipo de preparacao", "preparation method", "preserved in",

        # ===== NEW: occurrenceRemarks =====
        "notas de ocorrencia", "observacoes de ocorrencia",
        "occurrence notes", "occurrence remarks",

        # ===== NEW: kingdom =====
        "reino", "taxonomic kingdom",

        # ===== NEW: phylum =====
        "filo", "divisao", "taxonomic phylum",

        # ===== NEW: class =====
        "classe", "taxonomic class",

        # ===== NEW: order =====
        "ordem", "taxonomic order",

        # ===== NEW: family =====
        "familia", "taxonomic family",

        # ===== NEW: genus =====
        "genero", "taxonomic genus",

        # ===== NEW: specificEpithet =====
        # NOTE: "especie"/"species" movidos para scientificName (mais correto semanticamente)
        "epiteto especifico", "specific epithet", "species epithet",

        # ===== NEW: infraspecificEpithet =====
        "epiteto infraespecifico", "subespecie",
        "infraspecific epithet", "subspecies epithet",

        # ===== NEW: taxonRank =====
        "categoria taxonomica", "nivel taxonomico", "taxon rank", "taxonomic rank",

        # ===== NEW: scientificNameAuthorship =====
        "autoria", "autor do nome", "authorship",
        "name authorship", "scientific name author",

        # ===== NEW: verbatimIdentification =====
        "identificacao original", "identificacao verbatim",
        "verbatim identification", "original identification",

        # ===== NEW: identificationQualifier =====
        "qualificador de identificacao", "incerteza de identificacao",
        "identification qualifier", "identification uncertainty",

        # ===== NEW: vernacularName =====
        "nome popular", "nome comum", "nome vulgar",
        "common name", "popular name",

        # ===== NEW: identifiedBy =====
        "identificado por", "determinador", "identified by", "determined by",

        # ===== NEW: country =====
        "pais", "nacao", "country name", "pais de coleta",

        # ===== NEW: stateProvince =====
        "estado", "provincia", "uf", "state province", "province",

        # ===== NEW: county =====
        "municipio", "cidade", "municipality",

        # ===== NEW: locality =====
        "localidade", "local de coleta", "collection locality",

        # ===== NEW: locationRemarks =====
        "observacoes de local", "notas de localidade",
        "location notes", "location remarks",

        # ===== NEW: verbatimLatitude =====
        "latitude original", "latitude verbatim", "verbatim latitude",

        # ===== NEW: verbatimLongitude =====
        "longitude original", "longitude verbatim", "verbatim longitude",

        # ===== NEW: fieldNotes =====
        "notas de campo", "caderneta de campo", "field notes", "field notebook",

        # ===== NEW: habitat =====
        "ambiente", "tipo de habitat", "habitat type"
    ),
    name_score = c(
        # scientificName
        0.98, 0.96, 0.95, 0.93, 0.93,
        # decimalLatitude
        0.98, 0.97, 0.95,
        # decimalLongitude
        0.98, 0.97, 0.95,
        # individualCount
        0.97, 0.95, 0.94,
        # recordedBy base
        0.95, 0.94,
        # basisOfRecord base
        0.94, 0.93,
        # samplingProtocol
        0.94,
        # samplingEffort
        0.93,
        # catalogNumber base
        0.94,
        # collectionCode base
        0.94,
        # institutionCode base
        0.94,
        # datasetName
        0.93,
        # rightsHolder
        0.93,
        # dynamicProperties
        0.92,
        # eventDate base
        0.95,
        # year/month/day
        0.95, 0.95, 0.95,
        # dateIdentified
        0.95,

        # REINFORCEMENT: eventDate
        0.95, 0.94, 0.94, 0.93, 0.93,

        # REINFORCEMENT: recordedBy
        0.95, 0.93, 0.93, 0.92,

        # REINFORCEMENT: basisOfRecord
        0.93, 0.93, 0.94,

        # REINFORCEMENT: catalogNumber
        0.94, 0.93, 0.94, 0.92,

        # REINFORCEMENT: collectionCode
        0.93, 0.92, 0.93,

        # REINFORCEMENT: institutionCode
        0.93, 0.91, 0.93,

        # NEW: type
        0.91, 0.91, 0.91, 0.91,

        # NEW: disposition
        0.92, 0.91, 0.92, 0.91,

        # NEW: preparations
        0.93, 0.92, 0.92, 0.91,

        # NEW: occurrenceRemarks
        0.92, 0.91, 0.92, 0.93,

        # NEW: kingdom
        0.95, 0.93,

        # NEW: phylum
        0.95, 0.91, 0.92,

        # NEW: class
        0.95, 0.92,

        # NEW: order
        0.94, 0.92,

        # NEW: family
        0.95, 0.93,

        # NEW: genus
        0.95, 0.93,

        # NEW: specificEpithet
        0.93, 0.93, 0.92,

        # NEW: infraspecificEpithet
        0.93, 0.91, 0.93, 0.91,

        # NEW: taxonRank
        0.92, 0.91, 0.92, 0.91,

        # NEW: scientificNameAuthorship
        0.92, 0.91, 0.92, 0.91, 0.92,

        # NEW: verbatimIdentification
        0.92, 0.91, 0.92, 0.91,

        # NEW: identificationQualifier
        0.91, 0.91, 0.92, 0.91,

        # NEW: vernacularName
        0.94, 0.93, 0.92, 0.93, 0.92,

        # NEW: identifiedBy
        0.93, 0.91, 0.93, 0.92,

        # NEW: country
        0.95, 0.91, 0.93, 0.92,

        # NEW: stateProvince
        0.94, 0.93, 0.92, 0.93, 0.92,

        # NEW: county
        0.95, 0.90, 0.93,

        # NEW: locality
        0.95, 0.92, 0.92,

        # NEW: locationRemarks
        0.91, 0.91, 0.91, 0.92,

        # NEW: verbatimLatitude
        0.93, 0.91, 0.93,

        # NEW: verbatimLongitude
        0.93, 0.91, 0.93,

        # NEW: fieldNotes
        0.93, 0.91, 0.93, 0.91,

        # NEW: habitat
        0.91, 0.91, 0.92
    ),
    lang = c(
        # scientificName
        "pt", "en", "any", "en", "pt",
        # decimalLatitude
        "any", "any", "any",
        # decimalLongitude
        "any", "any", "any",
        # individualCount
        "any", "en", "pt",
        # recordedBy base
        "en", "en",
        # basisOfRecord base
        "en", "en",
        # samplingProtocol
        "en",
        # samplingEffort
        "en",
        # catalogNumber base
        "en",
        # collectionCode base
        "en",
        # institutionCode base
        "en",
        # datasetName
        "en",
        # rightsHolder
        "en",
        # dynamicProperties
        "en",
        # eventDate base
        "pt",
        # year/month/day
        "pt", "pt", "pt",
        # dateIdentified
        "pt",

        # REINFORCEMENT: eventDate
        "pt", "pt", "en", "en", "en",

        # REINFORCEMENT: recordedBy
        "pt", "pt", "en", "pt",

        # REINFORCEMENT: basisOfRecord
        "pt", "pt", "en",

        # REINFORCEMENT: catalogNumber
        "pt", "pt", "en", "en",

        # REINFORCEMENT: collectionCode
        "pt", "pt", "en",

        # REINFORCEMENT: institutionCode
        "pt", "pt", "en",

        # NEW: type
        "pt", "pt", "en", "en",

        # NEW: disposition
        "pt", "pt", "en", "en",

        # NEW: preparations
        "pt", "pt", "en", "en",

        # NEW: occurrenceRemarks
        "pt", "pt", "en", "en",

        # NEW: kingdom
        "pt", "en",

        # NEW: phylum
        "pt", "pt", "en",

        # NEW: class
        "pt", "en",

        # NEW: order
        "pt", "en",

        # NEW: family
        "pt", "en",

        # NEW: genus
        "pt", "en",

        # NEW: specificEpithet
        "pt", "en", "en",

        # NEW: infraspecificEpithet
        "pt", "pt", "en", "en",

        # NEW: taxonRank
        "pt", "pt", "en", "en",

        # NEW: scientificNameAuthorship
        "pt", "pt", "en", "en", "en",

        # NEW: verbatimIdentification
        "pt", "pt", "en", "en",

        # NEW: identificationQualifier
        "pt", "pt", "en", "en",

        # NEW: vernacularName
        "pt", "pt", "pt", "en", "en",

        # NEW: identifiedBy
        "pt", "pt", "en", "en",

        # NEW: country
        "pt", "pt", "en", "pt",

        # NEW: stateProvince
        "pt", "pt", "pt", "en", "en",

        # NEW: county
        "pt", "pt", "en",

        # NEW: locality
        "pt", "pt", "en",

        # NEW: locationRemarks
        "pt", "pt", "en", "en",

        # NEW: verbatimLatitude
        "pt", "pt", "en",

        # NEW: verbatimLongitude
        "pt", "pt", "en",

        # NEW: fieldNotes
        "pt", "pt", "en", "en",

        # NEW: habitat
        "pt", "pt", "en"
    ),
    active = TRUE,
    stringsAsFactors = FALSE
)

# Validate with the production sanitizer before saving
pkgload::load_all(quiet = TRUE)
sanitize_synonyms_table(dwc_synonyms)

dir.create(file.path("inst", "extdata"), recursive = TRUE, showWarnings = FALSE)
saveRDS(dwc_synonyms, file = file.path("inst", "extdata", "dwc_synonyms_v1.rds"), version = 2)

message(sprintf(
    "Saved %d synonym entries (%d unique terms) to inst/extdata/dwc_synonyms_v1.rds",
    nrow(dwc_synonyms),
    length(unique(dwc_synonyms$term))
))
