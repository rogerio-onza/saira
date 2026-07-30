pkg_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/", mustWork = TRUE)

test_data_path <- function(filename) {
    installed_path <- system.file("extdata", filename, package = "saira")
    if (nzchar(installed_path) && file.exists(installed_path)) {
        return(installed_path)
    }

    local_candidates <- c(
        file.path(pkg_root, "inst", "extdata", filename),
        file.path("inst", "extdata", filename),
        file.path(pkg_root, "data", filename),
        file.path("data", filename)
    )
    existing <- local_candidates[file.exists(local_candidates)]

    if (length(existing) > 0) {
        return(normalizePath(existing[[1]], winslash = "/", mustWork = TRUE))
    }

    stop(sprintf("Test data file not found: %s", filename))
}

helper_env <- environment()
needed_functions <- c(
    "has_selected_value",
    "sanitize_map_selection",
    "normalize_basis_of_record_key",
    "sanitize_basis_of_record_term",
    "auto_suggest_basis_of_record_term",
    "sanitize_basis_of_record_map",
    "extract_basis_of_record_unique_entries",
    "map_basis_of_record_values",
    "default_meta",
    "empty_map_values",
    "empty_map_meta",
    "build_manual_meta",
    "build_processed_mapping_df",
    "normalize_semicolon_tokens",
    "collapse_mapped_values",
    "detect_eventdate_roles",
    "parse_month_to_number",
    "parse_month_to_number_vec",
    "parse_year_to_number",
    "parse_year_to_number_vec",
    "format_genus_token",
    "format_genus_token_vec",
    "format_epithet_token",
    "format_epithet_token_vec",
    "build_eventdate_interval",
    "extract_scientific_name_components",
    "fill_missing_character_values",
    "replace_na_with_blank",
    "load_dwc_synonyms_v1",
    "load_dwc_terms_rds",
    "get_basis_of_record_vocab",
    "get_basis_of_record_terms",
    "get_basis_of_record_term_choices",
    "is_valid_basis_of_record_term",
    "compute_name_score",
    "compute_value_score",
    "run_rostrum_stage1",
    "mod_mapping_server"
)

for (fn_name in needed_functions) {
    if (!exists(fn_name, envir = helper_env, mode = "function", inherits = FALSE)) {
        assign(fn_name, get(fn_name, envir = asNamespace("saira"), inherits = FALSE), envir = helper_env)
    }
}
