# Title: Export i18n Dictionary to JSON
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-28
# Version: 1.0
# Onda 5, Item 5.7 — One-shot script to convert data_dictionary.R -> i18n.json
#
# Usage: Rscript data-raw/export_i18n.R
# (run from project root)

message("[Saira] Loading current data_dictionary.R ...")
source("R/data_dictionary.R")

if (!exists("i18n_dict") || !is.list(i18n_dict)) {
    stop("[Saira] i18n_dict not found after sourcing data_dictionary.R")
}

message("[Saira] Found ", length(i18n_dict), " i18n keys")

output_path <- file.path("inst", "extdata", "i18n.json")

# Write with pretty-print; jsonlite handles \uXXXX escaping for non-ASCII
jsonlite::write_json(
    i18n_dict,
    path = output_path,
    auto_unbox = TRUE,
    pretty = TRUE
)

message("[Saira] Exported i18n.json -> ", output_path, " (", length(i18n_dict), " keys)")
