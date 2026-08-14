#!/usr/bin/env Rscript
# Smoke report: run the pure pipeline over a spreadsheet and print what fired.
#
#   Rscript scripts/smoke_report.R                     # the public demo dataset
#   Rscript scripts/smoke_report.R path/to/file.csv    # any other spreadsheet
#
# Purpose: answer "did my change break something?" before opening the app.
# Every number below is produced by the same pure functions the Shiny modules
# call, so a regression in mapping, occurrenceID, eventDate, coordinates or
# license shows up here as a changed count.
#
# Deliberately offline and Shiny-free. Name validation queries GBIF and taxadb
# over the network, so it is NOT part of this report -- that is the one screen
# still worth opening by hand.

suppressMessages(pkgload::load_all(".", quiet = TRUE))

args <- commandArgs(trailingOnly = TRUE)
path <- if (length(args) >= 1L) args[[1L]] else
    "website/assets/exemplo/ocorrencias-demo.csv"

if (!file.exists(path)) {
    stop("file not found: ", path)
}

rule <- function(title) {
    cat("\n", title, "\n", strrep("-", nchar(title)), "\n", sep = "")
}
kv <- function(label, value) cat(sprintf("  %-34s %s\n", label, value))
tally <- function(x, empty = "(none)") {
    x <- x[!is.na(x) & nzchar(as.character(x))]
    if (length(x) == 0L) return(empty)
    tab <- sort(table(x), decreasing = TRUE)
    paste(sprintf("%s=%d", names(tab), as.integer(tab)), collapse = "  ")
}

# --- File --------------------------------------------------------------------
raw <- read_biodiversity_csv(path)
rule("File")
kv("path", path)
kv("rows x columns", sprintf("%d x %d", nrow(raw), ncol(raw)))

# --- Auto-mapping ------------------------------------------------------------
# Rostrum runs with conn = NULL so the report never reads or writes the user's
# alias database, which would make the numbers depend on local history.
terms_df <- get_active_dwc_terms()
engine <- run_rostrum_engine(
    df = raw, dwc_terms_df = terms_df, options = rostrum_options(),
    context = list(), conn = NULL
)
decisions <- engine$data

rule("Auto-mapping (Rostrum)")
kv("engine success", isTRUE(engine$success))
kv("status", tally(decisions$status))

applied <- decisions[decisions$applied %in% TRUE, , drop = FALSE]
applied <- applied[!is.na(applied$selected_col) & nzchar(applied$selected_col), , drop = FALSE]
map_values <- stats::setNames(
    as.list(as.character(applied$selected_col)),
    as.character(applied$term)
)
kv("terms auto-mapped", length(map_values))

# Terms Rostrum refuses to decide on its own: license is a manual_only_term,
# eventDate is temporal_manual_only, and occurrenceID needs no_confident_match
# rather than a guess. Nothing downstream of them runs until a human picks a
# column, so the report picks for them -- otherwise it would report "not
# mapped" for the very rules it exists to watch. Only fills terms the engine
# left empty, and only from columns the file actually has.
manual_picks <- list(
    occurrenceID = "numero_tombo",
    eventDate = c("dia_inicio", "mes_inicio", "ano_inicio"),
    countryCode = "codigo_pais"
)
picked <- character(0)
for (term in names(manual_picks)) {
    cols <- manual_picks[[term]]
    if (!is.null(map_values[[term]]) || !all(cols %in% names(raw))) next
    map_values[[term]] <- cols
    picked <- c(picked, sprintf("%s<-%s", term, paste(cols, collapse = "+")))
}
kv("filled in as a user would",
   if (length(picked)) paste(picked, collapse = "  ") else "(nothing to fill)")

# --- occurrenceID ------------------------------------------------------------
ids <- resolve_occurrence_ids(raw, map_values = map_values)
counts <- attr(ids, "id_counts")
dups <- sum(duplicated(ids))

rule("occurrenceID")
kv("source column", occurrence_id_source_column(raw, map_values) %||% "(none)")
kv("strategy", attr(ids, "id_strategy"))
kv("preserved / generated / total",
   sprintf("%d / %d / %d", counts$preserved, counts$generated, counts$total))
kv("duplicate identifiers", dups)

# Same input, same identifiers: the property that makes a re-upload reproduce
# the previous export instead of minting new ids.
kv("stable across a second run",
   identical(as.character(ids),
             as.character(resolve_occurrence_ids(raw, map_values = map_values))))

# --- Processed export --------------------------------------------------------
# Returns a list, not a data frame: $data plus the eventDate failure counter.
mapped <- build_processed_mapping_df(
    df = raw, dwc_terms = get_dwc_terms_list("en"), map_values = map_values,
    occurrence_ids = as.character(ids),
    # license is a special field: the app applies one license to the whole
    # dataset from a picker, never per row from a column. Passing it here is
    # what the picker does, and is the only way expand_license() gets exercised.
    custom_license = "CC-BY"
)
final <- process_for_export_with_unmapped(mapped$data, raw, map_values)

# --- eventDate ---------------------------------------------------------------
rule("eventDate")
if ("eventDate" %in% names(final)) {
    ev <- as.character(final$eventDate)
    ev_filled <- ev[!is.na(ev) & nzchar(ev)]
    iso <- grepl("^\\d{4}(-\\d{2}(-\\d{2})?)?$", ev_filled)
    kv("mapped from", paste(map_values[["eventDate"]], collapse = " + "))
    kv("rows that failed to compose", mapped$eventdate_failure_count)
    kv("filled rows", length(ev_filled))
    kv("ISO 8601 (full or partial)", sum(iso))
    kv("kept raw (not composed)", sum(!iso))
    if (any(!iso)) kv("example kept raw", ev_filled[!iso][[1]])
    if (any(iso)) kv("example composed", ev_filled[iso][[1]])
} else {
    kv("eventDate", "not mapped")
}

# --- Coordinates -------------------------------------------------------------
rule("Coordinates")
if (all(c("decimalLatitude", "decimalLongitude") %in% names(final))) {
    coord_df <- validate_coords_df(
        df = final, lat_col = "decimalLatitude", lon_col = "decimalLongitude"
    )
    kv("issue type", tally(coord_df$issue_type, empty = "(all ok)"))
    kv("valid", sum(coord_df$valid %in% TRUE))

    # The CoordinateCleaner pass: sea, country mismatch, capitals, centroids.
    # Offline -- it reads the Natural Earth layer bundled in inst/extdata.
    if ("country" %in% names(final)) {
        cc <- tryCatch(
            validate_coords_cc_df(
                final, lat_col = "decimalLatitude",
                lon_col = "decimalLongitude", country_col = "country"
            ),
            error = function(e) {
                kv("CoordinateCleaner", paste("skipped:", conditionMessage(e)))
                NULL
            }
        )
        if (!is.null(cc) && "diagnostic" %in% names(cc)) {
            kv("CoordinateCleaner diagnosis", tally(cc$diagnostic, "(all clean)"))
        }
    }
} else {
    kv("coordinates", "not mapped")
}

if ("country" %in% names(final)) {
    ctry <- as.character(final$country)
    kv("country blank", sum(is.na(ctry) | !nzchar(trimws(ctry))))
    kv("country distinct", tally(ctry))
}

# --- License -----------------------------------------------------------------
rule("License")
if ("license" %in% names(final)) {
    lic <- as.character(final$license)
    kv("published values", tally(lic))
    kv("expanded to a CC URI", sum(!is.na(normalize_license_key(lic))))
    kv("passed through unknown",
       sum(is.na(normalize_license_key(lic)) & nzchar(lic)))
} else {
    kv("license", "not mapped")
}

# --- Embedded species lists --------------------------------------------------
# Offline lookups against the two bundled tables. These are what drive the
# generalization screen and the establishmentMeans assistant.
rule("Species lists (offline lookups)")
if ("scientificName" %in% names(final)) {
    sci <- as.character(final$scientificName)
    cat_mma <- sensitive_category_for(sci)
    kv("MMA threatened rows", sum(!is.na(cat_mma) & nzchar(cat_mma)))
    kv("MMA categories", tally(cat_mma))
    kv("Horus list rows", sum(flag_invasive_species(sci) %in% TRUE))
    kv("distinct names", length(unique(sci)))
    kv("trinomials", sum(lengths(strsplit(trimws(sci), "\\s+")) >= 3L))
} else {
    kv("scientificName", "not mapped")
}

# --- Unmapped columns --------------------------------------------------------
rule("Unmapped raw columns")
unmapped <- unmapped_raw_columns(raw, map_values)
kv("count", length(unmapped))
if (length(unmapped) > 0L) kv("names", paste(unmapped, collapse = ", "))

rule("Export shape")
kv("rows x columns", sprintf("%d x %d", nrow(final), ncol(final)))
cat("\n")
