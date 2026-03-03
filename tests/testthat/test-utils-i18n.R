# Title: Tests for i18n dictionary and translations
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-14
# Version: 1.0

testthat::test_that("onda 2 i18n keys exist with pt/en translations", {
    dict <- get("i18n_dict", envir = asNamespace("saira"))

    required_keys <- c(
        "nav_home",
        "nav_validate",
        "mapping_dataset_placeholder",
        "mapping_separator_placeholder",
        "preview_datatable_search",
        "preview_datatable_length_menu",
        "preview_datatable_info",
        "preview_stats_total_rows",
        "preview_stats_with_coords",
        "preview_stats_with_date",
        "preview_stats_unique_ids",
        "preview_stats_duplicates",
        "preview_readiness_title",
        "preview_readiness_present",
        "preview_readiness_missing",
        "preview_exporting",
        "preview_no_data_title",
        "preview_datatable_empty",
        "preview_datatable_zero_records",
        "preview_datatable_first",
        "preview_datatable_last",
        "preview_datatable_next",
        "preview_datatable_prev",
        "validate_names_missing_scientific_name",
        "validate_names_loading_title",
        "validate_names_loading_status",
        "validate_names_loading_phase_prepare",
        "validate_names_loading_phase_provider",
        "validate_names_loading_phase_consolidate",
        "validate_names_loading_phase_finalize",
        "validate_names_loading_phase_done",
        "validate_names_loading_phase_failed",
        "validate_names_unique_notice",
        "validate_names_provider_used_summary",
        "validate_names_provider_none_summary",
        "validate_names_provider_failed_warning",
        "validate_names_providers_card_title",
        "validate_names_provider_gbif_full",
        "validate_names_provider_gbif_desc",
        "validate_names_provider_priority_badge",
        "validate_names_priority_reset_notice",
        "validate_names_options_card_title",
        "validate_names_action_card_title",
        "validate_names_action_metric_providers",
        "validate_names_action_metric_unique",
        "validate_names_action_metric_options",
        "validate_names_run_cta",
        "validate_names_ready_hint_title",
        "validate_names_ready_hint_body",
        "validate_names_progress_title",
        "validate_names_progress_label",
        "validate_names_progress_counter",
        "validate_names_progress_meta_line1",
        "validate_names_progress_meta_line2",
        "validate_names_progress_phase_provider_query_batch",
        "validate_names_stream_title",
        "validate_names_stream_panel_title",
        "validate_names_stream_empty_filter",
        "validate_names_stream_filter_all",
        "validate_names_stream_filter_problems",
        "validate_names_stream_filter_not_found",
        "validate_names_stream_filter_ambiguous",
        "validate_names_stream_filter_synonym",
        "validate_names_stream_filter_ignored",
        "validate_names_stream_window_note",
        "validate_names_provider_failed_stream_item",
        "validate_names_report_title",
        "validate_names_report_search_placeholder",
        "validate_names_report_show_n",
        "validate_names_report_empty",
        "validate_names_table_col_scientific_name",
        "validate_names_table_col_status",
        "validate_names_table_col_provider",
        "validate_names_table_col_taxonomic_status",
        "validate_names_table_col_query_name",
        "validate_names_table_col_input_name",
        "validate_names_status_badge_accepted",
        "validate_names_status_badge_synonym",
        "validate_names_status_badge_not_found",
        "validate_names_status_badge_ambiguous",
        "validate_names_status_badge_ignored",
        "validate_names_status_badge_manual_revision",
        "validate_names_review_action",
        "validate_names_review_problem_not_found",
        "validate_names_review_problem_ambiguous",
        "validate_names_review_problem_synonym",
        "validate_names_review_question_not_found",
        "validate_names_review_question_ambiguous",
        "validate_names_review_question_synonym",
        "validate_names_review_helper_not_found",
        "validate_names_review_helper_ambiguous",
        "validate_names_review_helper_synonym",
        "validate_names_review_confirm_title",
        "validate_names_review_confirm_subtitle",
        "validate_names_review_switch_to_edit",
        "validate_names_review_confirm_btn",
        "validate_names_review_back",
        "validate_names_review_edit_label",
        "validate_names_review_reason_placeholder",
        "validate_names_review_save_correction",
        "validate_names_review_toast_confirm",
        "validate_names_review_toast_correct",
        "validate_names_review_empty_title",
        "validate_names_review_empty_message",
        "validate_names_review_empty_export",
        "validate_names_review_reason_confirmed_by_user",
        "validate_names_review_replaced_prefix",
        "validate_names_datatable_search",
        "validate_names_datatable_length_menu",
        "validate_names_datatable_info",
        "validate_names_datatable_empty",
        "validate_names_datatable_zero_records",
        "validate_names_datatable_first",
        "validate_names_datatable_last",
        "validate_names_datatable_next",
        "validate_names_datatable_prev",
        "validate_names_cancelled_notice",
        "validate_names_all_valid",
        "validate_coords_missing_columns",
        "validate_coords_all_valid",
        "validate_coords_datatable_search",
        "validate_coords_datatable_length_menu",
        "validate_coords_datatable_info",
        "validate_coords_datatable_empty",
        "validate_coords_datatable_zero_records",
        "validate_coords_datatable_first",
        "validate_coords_datatable_last",
        "validate_coords_datatable_next",
        "validate_coords_datatable_prev",
        "wiki_search_placeholder",
        "wiki_datatable_search",
        "wiki_datatable_length_menu",
        "wiki_datatable_info",
        "wiki_datatable_empty",
        "wiki_datatable_zero_records",
        "wiki_datatable_first",
        "wiki_datatable_last",
        "wiki_datatable_next",
        "wiki_datatable_prev",
        "wiki_class_all",
        "wiki_term",
        "wiki_required_badge_required",
        "wiki_required_badge_optional",
        "wiki_header_eyebrow",
        "wiki_header_link_label",
        "wiki_stats_terms_label",
        "wiki_stats_required_label",
        "wiki_stats_classes_label",
        "wiki_show_label",
        "wiki_records_label",
        "a11y_wiki_page_length_label",
        "help_header_eyebrow",
        "help_header_title_prefix",
        "help_header_title_highlight",
        "help_header_subtitle",
        "help_search_placeholder",
        "help_empty_state",
        "help_section_dwc_title",
        "help_section_faq_title",
        "help_section_formats_title",
        "help_section_separator_title",
        "help_dwc_term_label",
        "help_dwc_p1_prefix",
        "help_dwc_p1_suffix",
        "help_dwc_p2",
        "help_dwc_bullet_occurrence",
        "help_dwc_bullet_location",
        "help_dwc_bullet_taxonomy",
        "help_dwc_bullet_event",
        "help_dwc_p3_prefix",
        "help_dwc_p3_suffix",
        "help_link_tdwg",
        "help_link_sibbr",
        "help_faq_q1",
        "help_faq_a1",
        "help_faq_q2",
        "help_faq_a2",
        "help_faq_q3",
        "help_faq_a3_prefix",
        "help_faq_a3_suffix",
        "help_faq_q4",
        "help_faq_a4",
        "help_formats_p1",
        "help_formats_p2",
        "help_formats_bullet_1",
        "help_formats_bullet_2",
        "help_formats_bullet_3",
        "help_formats_bullet_4",
        "help_separator_p1",
        "help_separator_p2",
        "help_separator_demo_input",
        "help_separator_bullet_1",
        "help_separator_bullet_2",
        "help_separator_bullet_3",
        "help_author_role",
        "help_author_contact_email",
        "help_author_contact_repository",
        "help_author_version_label",
        "help_bug_title",
        "help_bug_body",
        "help_bug_button",
        "help_links_title",
        "help_links_dwc",
        "help_links_sibbr",
        "help_links_gbif",
        "help_links_ala",
        "help_stack_title",
        "help_stack_r",
        "help_stack_shiny",
        "help_stack_bslib",
        "help_stack_dt",
        "help_stack_leaflet",
        "help_stack_coordinatecleaner",
        "help_stack_taxadb",
        "help_stack_codex",
        "help_stack_sonnet",
        "bor_assistant_button",
        "bor_assistant_title",
        "bor_assistant_skip_option",
        "bor_assistant_progress",
        "bor_assistant_preview_title",
        "bor_vocab_humanobservation",
        "bor_desc_humanobservation"
    )

    missing_keys <- setdiff(required_keys, names(dict))
    testthat::expect_equal(
        length(missing_keys),
        0L,
        info = paste("Missing keys:", paste(missing_keys, collapse = ", "))
    )

    for (key in required_keys) {
        testthat::expect_true(
            !is.null(dict[[key]][["pt"]]) && nzchar(dict[[key]][["pt"]]),
            info = paste("Missing pt value for key:", key)
        )
        testthat::expect_true(
            !is.null(dict[[key]][["en"]]) && nzchar(dict[[key]][["en"]]),
            info = paste("Missing en value for key:", key)
        )
    }
})

testthat::test_that("tr resolves onda 2 keys in pt and en", {
    tr_fn <- saira:::tr

    keys <- c(
        "nav_home",
        "nav_validate",
        "mapping_dataset_placeholder",
        "preview_datatable_length_menu",
        "preview_stats_total_rows",
        "preview_readiness_title",
        "preview_exporting",
        "preview_datatable_empty",
        "preview_datatable_next",
        "validate_names_loading_title",
        "validate_names_loading_status",
        "validate_names_unique_notice",
        "validate_names_progress_title",
        "validate_names_progress_label",
        "validate_names_stream_title",
        "validate_names_stream_panel_title",
        "validate_names_stream_filter_problems",
        "validate_names_status_badge_not_found",
        "validate_names_review_action",
        "validate_names_review_question_not_found",
        "validate_names_review_confirm_btn",
        "validate_names_review_save_correction",
        "validate_names_datatable_length_menu",
        "validate_names_cancelled_notice",
        "validate_names_provider_used_summary",
        "validate_names_all_valid",
        "validate_names_report_title",
        "validate_names_report_search_placeholder",
        "validate_names_report_show_n",
        "validate_names_report_empty",
        "validate_coords_all_valid",
        "validate_coords_datatable_length_menu",
        "wiki_class_all",
        "wiki_datatable_length_menu",
        "wiki_datatable_empty",
        "wiki_required_badge_required",
        "wiki_term",
        "wiki_header_eyebrow",
        "wiki_stats_required_label",
        "wiki_show_label",
        "wiki_records_label",
        "help_header_eyebrow",
        "help_search_placeholder",
        "help_section_dwc_title",
        "help_faq_q1",
        "help_formats_p1",
        "help_separator_p1",
        "help_bug_title",
        "help_links_title",
        "help_stack_title",
        "bor_assistant_title",
        "bor_assistant_progress",
        "bor_assistant_preview_title",
        "bor_assistant_skip_option"
    )

    for (key in keys) {
        pt_value <- tr_fn(key, "pt")
        en_value <- tr_fn(key, "en")

        testthat::expect_type(pt_value, "character")
        testthat::expect_true(nzchar(pt_value), info = paste("Empty pt translation for", key))
        testthat::expect_type(en_value, "character")
        testthat::expect_true(nzchar(en_value), info = paste("Empty en translation for", key))
    }
})

testthat::test_that("pt-en alternation yields distinct navigation labels", {
    tr_fn <- saira:::tr

    testthat::expect_false(identical(tr_fn("nav_home", "pt"), tr_fn("nav_home", "en")))
    testthat::expect_false(identical(tr_fn("nav_validate", "pt"), tr_fn("nav_validate", "en")))
    testthat::expect_false(identical(tr_fn("validate_names_all_valid", "pt"), tr_fn("validate_names_all_valid", "en")))
    testthat::expect_false(identical(tr_fn("validate_coords_all_valid", "pt"), tr_fn("validate_coords_all_valid", "en")))
})

testthat::test_that("tr returns key placeholder and warning for missing key", {
    tr_fn <- saira:::tr

    testthat::expect_warning(
        value <- tr_fn("nonexistent_wave6_key", "en"),
        "Translation key not found: nonexistent_wave6_key"
    )
    testthat::expect_identical(value, "[nonexistent_wave6_key]")
})

testthat::test_that("tr falls back to english and warns for missing language entry", {
    tr_fn <- saira:::tr

    expected_en <- tr_fn("nav_home", "en")
    testthat::expect_warning(
        out <- tr_fn("nav_home", "es"),
        "Translation missing for nav_home in es"
    )
    testthat::expect_identical(out, expected_en)
})

testthat::test_that("get_languages returns supported language codes", {
    testthat::expect_identical(get_languages(), c("pt", "en"))
})

testthat::test_that("get_language_name resolves known and unknown language codes", {
    testthat::expect_identical(get_language_name("pt"), "Português")
    testthat::expect_identical(get_language_name("en"), "English")
    testthat::expect_identical(get_language_name("es"), "es")
})

testthat::test_that("all dictionary keys contain non-empty pt and en translations", {
    dict <- get("i18n_dict", envir = asNamespace("saira"))

    for (key in names(dict)) {
        testthat::expect_true(
            !is.null(dict[[key]][["pt"]]) && nzchar(dict[[key]][["pt"]]),
            info = paste("Missing pt translation for key:", key)
        )
        testthat::expect_true(
            !is.null(dict[[key]][["en"]]) && nzchar(dict[[key]][["en"]]),
            info = paste("Missing en translation for key:", key)
        )
    }
})
