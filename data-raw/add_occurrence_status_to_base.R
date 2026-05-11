# Title: Add occurrenceStatus to base DwC terms
# Author: Rogerio Nunes Oliveira
# Date: 2026-05-08
#
# One-shot patch: occurrenceStatus is a standard DwC term (Occurrence class)
# but was missing from inst/extdata/dwc_terms.rds. This script appends it so
# the term is available natively in the mapping UI without requiring users to
# add it as a session-extra term.
#
# Idempotent: running twice has no effect.
#
# Run with:
#   source(here::here("data-raw/add_occurrence_status_to_base.R"))

base_path <- file.path("inst", "extdata", "dwc_terms.rds")
base <- readRDS(base_path)

if ("occurrenceStatus" %in% base$term) {
  message("occurrenceStatus already present in dwc_terms.rds — nothing to do.")
} else {
  new_row <- data.frame(
    term          = "occurrenceStatus",
    class         = "Occurrence",
    definition_en = "A statement about the presence or absence of a Taxon at a Location.",
    definition_pt = "Declaracao sobre a presenca ou ausencia de um Taxon em um Local.",
    examples      = "present | absent",
    required      = FALSE,
    data_type     = "string",
    stringsAsFactors = FALSE
  )

  # Insert after the last Occurrence row to keep class blocks contiguous
  occ_rows <- which(base$class == "Occurrence")
  if (length(occ_rows) > 0L) {
    insert_at <- max(occ_rows)
    out <- rbind(
      base[seq_len(insert_at), , drop = FALSE],
      new_row,
      base[seq.int(insert_at + 1L, nrow(base)), , drop = FALSE]
    )
  } else {
    out <- rbind(base, new_row)
  }

  rownames(out) <- NULL
  saveRDS(out, base_path)
  message(sprintf(
    "Added occurrenceStatus. dwc_terms.rds now has %d terms.", nrow(out)
  ))
}

# Re-sync dwc_full_catalog.rds with the new base so the test invariants hold:
#   1. Every base term keeps its definition_pt / required / data_type
#   2. Base terms appear in the first nrow(base) rows, in base order
#   3. Extras follow, sorted alphabetically (matches build_dwc_full_catalog.R)
catalog_path <- file.path("inst", "extdata", "dwc_full_catalog.rds")
base <- readRDS(base_path)
catalog <- readRDS(catalog_path)

for (col in c("definition_pt", "required", "data_type")) {
  idx <- match(base$term, catalog$term)
  valid <- !is.na(idx)
  catalog[idx[valid], col] <- base[[col]][valid]
}

base_order <- match(base$term, catalog$term)
base_order <- base_order[!is.na(base_order)]
extra_idx <- setdiff(seq_len(nrow(catalog)), base_order)
extra_sorted <- extra_idx[order(catalog$term[extra_idx])]
catalog <- catalog[c(base_order, extra_sorted), , drop = FALSE]
rownames(catalog) <- NULL

saveRDS(catalog, catalog_path)
message(sprintf(
  "Re-synced dwc_full_catalog.rds: %d total terms, %d with PT translation.",
  nrow(catalog), sum(nzchar(catalog$definition_pt))
))
