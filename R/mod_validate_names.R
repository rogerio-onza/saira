# Title: Validate Names Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-26
# Version: 2.3

#' @include mod_validate_names_helpers.R
NULL

#' Validate Names Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_validate_names_ui <- function(id) {
    ns <- shiny::NS(id)

    shiny::tagList(
        shiny::div(
            class = "container-fluid validate-names-page",
            shiny::uiOutput(ns("title")),
            shiny::uiOutput(ns("subtitle")),
            shiny::div(
                class = "validate-names-workspace",
                shiny::uiOutput(ns("config_panel")),
                shiny::uiOutput(ns("stream_panel")),
                shiny::uiOutput(ns("report_panel"))
            ),
            shiny::tags$script(shiny::HTML(
                "$(function() {
                    if (window.__vnCleanupRegistered) { return; }
                    window.__vnCleanupRegistered = true;
                    Shiny.addCustomMessageHandler('vnCleanupBackdrop', function(msg) {
                        if (document.body) {
                            document.body.classList.remove('vn-review-open');
                        }
                        var backdrops = document.querySelectorAll('.modal-backdrop');
                        backdrops.forEach(function(el) { el.remove(); });
                        document.body.style.removeProperty('overflow');
                        document.body.style.removeProperty('padding-right');
                        document.body.classList.remove('modal-open');
                    });
                });"
            ))
        )
    )
}

#' Validate Names Module Server
#'
#' @param id Module ID
#' @param mapped_data_r Reactive data frame with mapped data
#' @param lang_r Reactive language value
#' @param validation_gate_r Optional lightweight gate reactive from mapping module
#' @param reset_signal_r Optional reactive reset signal from the mapping module.
#'   When it fires, module-local state and inputs are cleared.
#' @return Reactive validation report data frame
#' @export
mod_validate_names_server <- function(id, mapped_data_r, lang_r, validation_gate_r = NULL, reset_signal_r = NULL) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        provider_catalog <- list(
            list(id = "florabr", short = "Flora BR", full_key = "validate_names_provider_florabr_full", desc_key = "validate_names_provider_florabr_desc", icon = "seedling",      recommended = FALSE, type = "br"),
            list(id = "faunabr", short = "Fauna BR", full_key = "validate_names_provider_faunabr_full", desc_key = "validate_names_provider_faunabr_desc", icon = "paw",           recommended = FALSE, type = "br"),
            list(id = "gbif",    short = "GBIF",     full_key = "validate_names_provider_gbif_full",    desc_key = "validate_names_provider_gbif_desc",    icon = "earth-americas", recommended = TRUE,  type = "taxadb")
        )
        provider_ids <- vapply(provider_catalog, function(item) item$id, FUN.VALUE = character(1))
        br_provider_ids <- c("florabr", "faunabr")
        initial_provider_runtime_status <- tryCatch(
            brprovider_cache_statuses(br_provider_ids, poll = FALSE),
            error = function(e) {
                stats::setNames(
                    lapply(br_provider_ids, function(id) list(provider_id = id, status = "never_downloaded", local_version = NA_character_)),
                    br_provider_ids
                )
            }
        )
        stream_window_limit <- .vn_stream_window_limit
        stream_filter_values <- .vn_stream_filter_values
        problem_status_values <- .vn_problem_status_values
        review_exit_ms <- .vn_review_exit_ms

        validation_result <- shiny::reactiveVal(NULL)
        validation_meta <- shiny::reactiveVal(NULL)

        # Empty schemas reused by the rv init, the validate-click reset, and the
        # upstream reset observer so the three stay in lockstep.
        empty_manual_reviews <- function() {
            data.frame(
                query_name = character(0),
                review_type = character(0),
                original_name = character(0),
                corrected_name = character(0),
                reason = character(0),
                reviewed_at = as.POSIXct(character(0), tz = "UTC"),
                stringsAsFactors = FALSE
            )
        }
        empty_exiting_reviews <- function() {
            data.frame(
                query_name = character(0),
                expires_at = as.POSIXct(character(0), tz = "UTC"),
                stringsAsFactors = FALSE
            )
        }

        rv <- shiny::reactiveValues(
            # GBIF is always on (priority 1); any BR provider already downloaded
            # to the on-disk cache is pre-selected so the user's last download
            # persists across app restarts (the RDS cache is the persistence).
            selected_providers = c(
                "gbif",
                br_provider_ids[vapply(br_provider_ids, brprovider_data_available, logical(1))]
            ),
            starting = FALSE,
            start_requested = FALSE,
            running = FALSE,
            abort_requested = FALSE,
            run_state = NULL,
            stream_df = empty_validation_stream(),
            stream_filter = "all",
            last_run_status = "idle",
            last_error = NA_character_,
            manual_reviews = empty_manual_reviews(),
            review_target = NULL,
            review_mode = "confirm",
            sensitivity_overrides = list(),
            exiting_reviews = empty_exiting_reviews(),
            provider_runtime_status = initial_provider_runtime_status
        )

        provider_button_id <- function(provider_id) paste0("provider_card_", provider_id)

        provider_runtime_status_for <- function(provider_id) {
            status_map <- rv$provider_runtime_status
            if (!is.list(status_map) || is.null(status_map[[provider_id]])) {
                return(list(provider_id = provider_id, status = "never_downloaded", local_version = NA_character_))
            }
            status_map[[provider_id]]
        }

        refresh_provider_runtime_status <- function(poll = TRUE) {
            fresh <- tryCatch(
                brprovider_cache_statuses(br_provider_ids, poll = poll),
                error = function(e) {
                    status_map <- rv$provider_runtime_status
                    if (!is.list(status_map)) status_map <- list()
                    status_map
                }
            )
            rv$provider_runtime_status <- fresh
            fresh
        }

        provider_runtime_badge <- function(status_obj) {
            key <- tolower(as.character(status_obj$status %||% "never_downloaded"))
            if (identical(key, "up_to_date")) {
                return(shiny::tags$span(class = "vn-status-badge badge-success", tr("validate_names_provider_status_up_to_date", lang_r())))
            }
            if (identical(key, "update_in_progress")) {
                return(shiny::tags$span(class = "vn-status-badge badge-info", tr("validate_names_provider_status_updating", lang_r())))
            }
            if (identical(key, "update_failed")) {
                return(shiny::tags$span(class = "vn-status-badge badge-warning", tr("validate_names_provider_status_update_failed", lang_r())))
            }
            shiny::tags$span(class = "vn-status-badge badge-muted", tr("validate_names_provider_status_not_downloaded", lang_r()))
        }

        shiny::observe({
            selected <- as.character(rv$selected_providers)
            selected_br <- intersect(selected, br_provider_ids)
            current_map <- rv$provider_runtime_status
            has_running_update <- is.list(current_map) && any(vapply(
                br_provider_ids,
                function(id) identical(as.character((current_map[[id]] %||% list())$status %||% ""), "update_in_progress"),
                FUN.VALUE = logical(1)
            ))

            if (length(selected_br) == 0L && !isTRUE(rv$running) && !isTRUE(rv$starting) && !isTRUE(has_running_update)) {
                return(invisible(NULL))
            }

            shiny::invalidateLater(1200, session)
            previous <- rv$provider_runtime_status
            updated <- refresh_provider_runtime_status(poll = TRUE)

            for (provider_id in br_provider_ids) {
                prev_obj <- if (is.list(previous)) previous[[provider_id]] else NULL
                curr_obj <- if (is.list(updated)) updated[[provider_id]] else NULL
                prev_status <- tolower(as.character((prev_obj %||% list())$status %||% ""))
                curr_status <- tolower(as.character((curr_obj %||% list())$status %||% ""))
                prev_version <- as.character((prev_obj %||% list())$local_version %||% "")
                curr_version <- as.character((curr_obj %||% list())$local_version %||% "")

                if (identical(prev_status, "update_in_progress") && identical(curr_status, "up_to_date")) {
                    label <- format_provider_labels(provider_id)
                    label_chr <- if (length(label) > 0L) label[[1L]] else provider_id
                    suffix <- if (!is.na(curr_version) && nzchar(curr_version)) paste0(" (v", curr_version, ")") else ""
                    shiny::showNotification(
                        sprintf(tr("validate_names_provider_notify_updated", lang_r()), label_chr, suffix),
                        type = "message",
                        duration = 3
                    )
                }

                if (identical(prev_status, "update_in_progress") && identical(curr_status, "update_failed")) {
                    if (!identical(prev_version, curr_version) || !identical(prev_status, curr_status)) {
                        label <- format_provider_labels(provider_id)
                        label_chr <- if (length(label) > 0L) label[[1L]] else provider_id
                        shiny::showNotification(
                            sprintf(tr("validate_names_provider_notify_update_failed", lang_r()), label_chr),
                            type = "warning",
                            duration = 4
                        )
                    }
                }
            }
        })

        review_entries_df <- function() {
            out <- rv$manual_reviews
            if (!is.data.frame(out) || nrow(out) == 0L) {
                return(data.frame(
                    query_name = character(0),
                    review_type = character(0),
                    original_name = character(0),
                    corrected_name = character(0),
                    reason = character(0),
                    reviewed_at = as.POSIXct(character(0), tz = "UTC"),
                    stringsAsFactors = FALSE
                ))
            }

            required_cols <- c("query_name", "review_type", "original_name", "corrected_name", "reason", "reviewed_at")
            for (col_name in setdiff(required_cols, names(out))) {
                if (identical(col_name, "reviewed_at")) {
                    out[[col_name]] <- as.POSIXct(character(nrow(out)), tz = "UTC")
                } else {
                    out[[col_name]] <- rep("", nrow(out))
                }
            }
            out <- out[, required_cols, drop = FALSE]
            out$query_name <- as.character(out$query_name)
            out$review_type <- as.character(out$review_type)
            out$original_name <- as.character(out$original_name)
            out$corrected_name <- as.character(out$corrected_name)
            out$reason <- as.character(out$reason)
            out$reviewed_at <- as.POSIXct(out$reviewed_at, tz = "UTC")
            out <- out[!is.na(out$query_name) & nzchar(out$query_name), , drop = FALSE]
            rownames(out) <- NULL
            out
        }

        # Per-species sensitivity overrides (ADR-092, simplified by the
        # Chapman 2020 flat-tier UI). The store keys on the resolved
        # scientificName; entries here win over the MMA auto-match in
        # `mask_sensitive_coordinates()`. Only the boolean "treat as
        # sensitive" survives -- the masking grid is global (chosen on the
        # Preview tab), so per-species category is no longer editable here.
        sensitivity_entries_df <- function() {
            store <- rv$sensitivity_overrides
            empty <- data.frame(
                scientificName = character(0),
                sensitive = logical(0),
                category = character(0),
                stringsAsFactors = FALSE
            )
            if (!is.list(store) || length(store) == 0L) {
                return(empty)
            }
            data.frame(
                scientificName = names(store),
                sensitive = vapply(
                    store, function(x) isTRUE(x$sensitive), logical(1)
                ),
                # User-chosen MMA threat level for species NOT on the MMA list
                # (NA otherwise). sensitive_resolve() honours this so the
                # Generalization tab groups the species under the chosen level
                # instead of the "Other" bucket.
                category = vapply(
                    store, function(x) {
                        cc <- x$category
                        if (is.null(cc) || length(cc) == 0L || is.na(cc)) {
                            NA_character_
                        } else {
                            as.character(cc)
                        }
                    }, character(1)
                ),
                stringsAsFactors = FALSE
            )
        }

        register_sensitivity_override <- function(name, sensitive,
                                                  category = NA_character_) {
            name <- trimws(as.character(name))
            if (!nzchar(name)) {
                return(invisible(NULL))
            }
            store <- rv$sensitivity_overrides
            if (!is.list(store)) store <- list()
            store[[name]] <- list(
                sensitive = isTRUE(sensitive),
                category = category
            )
            rv$sensitivity_overrides <- store
            invisible(NULL)
        }

        reviewed_query_keys <- function() {
            entries <- review_entries_df()
            if (!is.data.frame(entries) || nrow(entries) == 0L) {
                return(character(0))
            }
            unique(as.character(entries$query_name))
        }

        exiting_query_keys <- function() {
            out <- rv$exiting_reviews
            if (!is.data.frame(out) || nrow(out) == 0L) {
                return(character(0))
            }
            expires <- as.POSIXct(out$expires_at, tz = "UTC")
            keep <- !is.na(expires) & expires > Sys.time()
            if (!all(keep)) {
                rv$exiting_reviews <- out[keep, , drop = FALSE]
                out <- rv$exiting_reviews
            }
            if (!is.data.frame(out) || nrow(out) == 0L) {
                return(character(0))
            }
            unique(as.character(out$query_name))
        }

        register_review_exit <- function(query_name) {
            key <- as.character(query_name %||% "")
            if (!nzchar(key)) {
                return(invisible(NULL))
            }

            out <- rv$exiting_reviews
            if (!is.data.frame(out)) {
                out <- data.frame(
                    query_name = character(0),
                    expires_at = as.POSIXct(character(0), tz = "UTC"),
                    stringsAsFactors = FALSE
                )
            }
            out <- out[as.character(out$query_name) != key, , drop = FALSE]
            out <- rbind(
                out,
                data.frame(
                    query_name = key,
                    expires_at = Sys.time() + (review_exit_ms / 1000),
                    stringsAsFactors = FALSE
                )
            )
            rownames(out) <- NULL
            rv$exiting_reviews <- out
            invisible(NULL)
        }

        register_manual_review <- function(query_name, review_type, original_name, corrected_name, reason = "") {
            key <- as.character(query_name %||% "")
            if (!nzchar(key)) {
                return(invisible(NULL))
            }

            type_key <- tolower(as.character(review_type %||% ""))
            if (!(type_key %in% c("confirm", "correct"))) {
                return(invisible(NULL))
            }

            original_chr <- as.character(original_name %||% key)
            if (!nzchar(original_chr)) original_chr <- key
            corrected_chr <- as.character(corrected_name %||% original_chr)
            if (!nzchar(corrected_chr)) corrected_chr <- original_chr
            reason_chr <- as.character(reason %||% "")

            out <- review_entries_df()
            idx <- match(key, out$query_name)
            row <- data.frame(
                query_name = key,
                review_type = type_key,
                original_name = original_chr,
                corrected_name = corrected_chr,
                reason = reason_chr,
                reviewed_at = Sys.time(),
                stringsAsFactors = FALSE
            )
            if (is.na(idx)) out <- rbind(out, row) else out[idx, ] <- row
            rownames(out) <- NULL
            rv$manual_reviews <- out
            register_review_exit(key)
            invisible(NULL)
        }

        toggle_provider_selection <- function(provider_id) {
            selected <- as.character(rv$selected_providers)
            selected <- selected[!is.na(selected) & nzchar(selected)]
            if (provider_id %in% selected) selected <- selected[selected != provider_id] else selected <- c(selected, provider_id)
            rv$selected_providers <- selected
        }

        for (provider_id in provider_ids) {
            local({
                id_local <- provider_id
                shiny::observeEvent(input[[provider_button_id(id_local)]],
                    {
                        if (isTRUE(rv$running)) {
                            return(invisible(NULL))
                        }
                        toggle_provider_selection(id_local)
                    },
                    ignoreInit = TRUE
                )
            })
        }

        prepared_inputs <- shiny::reactive({
            df <- mapped_data_r()
            if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
                return(list(status = "no_data", unique_df = data.frame(), valid_queries = character(0), valid_count = 0L))
            }
            if (!"scientificName" %in% names(df)) {
                return(list(status = "missing_scientific", unique_df = data.frame(), valid_queries = character(0), valid_count = 0L))
            }

            input_df <- prepare_taxadb_inputs(
                names_vec = df$scientificName,
                remove_authors = isTRUE(input$remove_authors %||% TRUE),
                ignore_qualifiers = isTRUE(input$ignore_qualifiers %||% TRUE)
            )
            dedupe_key <- ifelse(is.na(input_df$query_name) | !nzchar(input_df$query_name), paste0("NA__", input_df$input_name), input_df$query_name)
            unique_df <- input_df[!duplicated(dedupe_key), , drop = FALSE]

            valid_queries <- unique(as.character(unique_df$query_name))
            valid_queries <- valid_queries[!is.na(valid_queries) & nzchar(valid_queries)]
            list(status = "ok", unique_df = unique_df, valid_queries = valid_queries, valid_count = length(valid_queries))
        })

        # Keep tab rendering fast: do not inspect scientific names on initial paint.
        quick_inputs <- shiny::reactive({
            if (!is.null(validation_gate_r) && shiny::is.reactive(validation_gate_r)) {
                gate <- validation_gate_r()
                gate_status <- as.character(gate$status %||% "")
                if (identical(gate_status, "ok")) {
                    return(list(status = "ok"))
                }
                if (identical(gate_status, "no_data")) {
                    return(list(status = "no_data"))
                }
                return(list(status = "missing_scientific"))
            }

            df <- mapped_data_r()
            if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
                return(list(status = "no_data"))
            }
            if (!"scientificName" %in% names(df)) {
                return(list(status = "missing_scientific"))
            }

            list(status = "ok")
        })

        active_options_count <- shiny::reactive({
            sum(c(isTRUE(input$remove_authors %||% TRUE), isTRUE(input$ignore_qualifiers %||% TRUE)))
        })

        can_run_validation <- shiny::reactive({
            prep <- quick_inputs()
            length(rv$selected_providers) > 0L && identical(prep$status, "ok") && !isTRUE(rv$running) && !isTRUE(rv$starting)
        })

        has_validation_output <- shiny::reactive({
            report <- validation_result()
            is.data.frame(report) && nrow(report) > 0L
        })

        is_pre_validation_state <- shiny::reactive({
            !isTRUE(rv$running) &&
                !isTRUE(rv$starting) &&
                is.null(rv$run_state) &&
                !isTRUE(has_validation_output())
        })

        active_stream_filter <- shiny::reactive({
            key <- as.character(rv$stream_filter %||% "all")
            if (!(key %in% stream_filter_values)) key <- "all"
            key
        })

        for (filter_key in stream_filter_values) {
            local({
                key_local <- filter_key
                shiny::observeEvent(input[[paste0("stream_filter_", key_local)]],
                    {
                        rv$stream_filter <- key_local
                    },
                    ignoreInit = TRUE
                )
            })
        }

        effective_report <- shiny::reactive({
            report_df <- validation_result()
            if (!is.data.frame(report_df) || nrow(report_df) == 0L) {
                return(data.frame())
            }

            out <- report_df
            if (!"validation_status" %in% names(out)) {
                out$validation_status <- rep("not_found", nrow(out))
            }
            out$validation_status <- normalize_status_vec(out$validation_status)

            if (!"query_name" %in% names(out)) {
                scientific_name <- if ("scientificName" %in% names(out)) as.character(out$scientificName) else rep("", nrow(out))
                remove_authors_opt <- isTRUE(input$remove_authors %||% TRUE)
                ignore_qualifiers_opt <- isTRUE(input$ignore_qualifiers %||% TRUE)
                # normalize_scientific_name() is scalar and datasets repeat names
                # heavily, so normalise the distinct names and map back by index.
                unique_names <- unique(scientific_name)
                unique_query <- vapply(unique_names, function(value) {
                    normalized <- normalize_scientific_name(
                        value,
                        remove_authors = remove_authors_opt,
                        ignore_qualifiers = ignore_qualifiers_opt
                    )
                    if (is.na(normalized) || !nzchar(normalized)) as.character(value %||% "") else normalized
                }, FUN.VALUE = character(1), USE.NAMES = FALSE)
                out$query_name <- unique_query[match(scientific_name, unique_names)]
            } else {
                out$query_name <- as.character(out$query_name)
            }

            scientific_name <- if ("scientificName" %in% names(out)) as.character(out$scientificName) else rep("", nrow(out))
            scientific_name[is.na(scientific_name)] <- ""
            out$scientificName <- scientific_name
            out$manual_review <- FALSE
            out$review_type <- ""
            out$review_reason <- ""
            out$reviewed_at <- as.POSIXct(rep(NA_character_, nrow(out)), tz = "UTC")
            out$review_original_name <- ""
            out$scientificName_display <- scientific_name
            out$display_status <- out$validation_status
            out$.row_order <- seq_len(nrow(out))

            entries <- review_entries_df()
            if (is.data.frame(entries) && nrow(entries) > 0L) {
                idx <- match(out$query_name, entries$query_name)
                has_review <- !is.na(idx)
                if (any(has_review)) {
                    out$manual_review[has_review] <- TRUE
                    out$review_type[has_review] <- as.character(entries$review_type[idx[has_review]])
                    out$review_reason[has_review] <- as.character(entries$reason[idx[has_review]])
                    out$reviewed_at[has_review] <- as.POSIXct(entries$reviewed_at[idx[has_review]], tz = "UTC")
                    out$review_original_name[has_review] <- as.character(entries$original_name[idx[has_review]])

                    corrected_idx <- has_review & out$review_type == "correct"
                    corrected_values <- rep("", nrow(out))
                    corrected_values[has_review] <- as.character(entries$corrected_name[idx[has_review]])
                    has_corrected <- corrected_idx & !is.na(corrected_values) & nzchar(trimws(corrected_values))
                    out$scientificName_display[has_corrected] <- corrected_values[has_corrected]
                    out$display_status[has_review & out$review_type == "confirm"] <- "accepted_manual"
                    out$display_status[has_review & out$review_type == "correct"] <- "manual_revision"
                }
            }

            if (any(out$manual_review)) {
                reviewed_num <- as.numeric(out$reviewed_at)
                reviewed_num[is.na(reviewed_num)] <- -Inf
                ord <- order(!out$manual_review, -reviewed_num, out$.row_order)
                out <- out[ord, , drop = FALSE]
                rownames(out) <- NULL
            }

            out
        }) |> shiny::bindCache(
            validation_result(),
            rv$manual_reviews,
            input$remove_authors,
            input$ignore_qualifiers
        )

        report_status_counts <- function(report_df) {
            out <- c(valid = 0L, invalid = 0L, unresolved = 0L, total = 0L)
            if (!is.data.frame(report_df) || nrow(report_df) == 0L) {
                return(out)
            }

            status_vec <- normalize_status_vec(report_df$validation_status)
            reviewed_vec <- if ("manual_review" %in% names(report_df)) as.logical(report_df$manual_review) else rep(FALSE, length(status_vec))
            reviewed_vec[is.na(reviewed_vec)] <- FALSE
            out[["total"]] <- as.integer(length(status_vec))
            out[["valid"]] <- as.integer(sum(status_vec == "accepted" | reviewed_vec, na.rm = TRUE))
            out[["invalid"]] <- as.integer(sum(status_vec == "ignored", na.rm = TRUE))
            out[["unresolved"]] <- as.integer(sum(status_vec %in% problem_status_values & !reviewed_vec, na.rm = TRUE))
            out
        }

        progress_snapshot <- function() {
            state <- rv$run_state
            report <- validation_result()
            total_unique <- 0L
            resolved_unique <- 0L
            batch_idx <- 0L
            batch_total <- 0L
            provider_text <- tr("validate_names_loading_provider_unknown", lang_r())
            phase_text <- tr("validate_names_progress_idle", lang_r())

            if (!is.null(state)) {
                total_unique <- suppressWarnings(as.integer(state$total_unique %||% 0L))
                resolved_unique <- suppressWarnings(as.integer(state$resolved_unique %||% 0L))
                batch_idx <- suppressWarnings(as.integer(state$provider_batch_idx %||% 0L))
                batch_total <- suppressWarnings(as.integer(state$provider_batch_total %||% 0L))
                if (is.na(total_unique) || total_unique < 0L) total_unique <- 0L
                if (is.na(resolved_unique) || resolved_unique < 0L) resolved_unique <- 0L
                if (is.na(batch_idx) || batch_idx < 0L) batch_idx <- 0L
                if (is.na(batch_total) || batch_total < 0L) batch_total <- 0L
                provider_label <- format_provider_labels(state$current_provider %||% "")
                if (length(provider_label) > 0L) provider_text <- provider_label[[1]]
                phase_text <- phase_label(state, lang_r())
            } else if (is.data.frame(report) && nrow(report) > 0L) {
                total_unique <- nrow(report)
                resolved_unique <- total_unique
                phase_text <- tr("validate_names_progress_phase_done", lang_r())
            }

            progress_pct <- if (total_unique > 0L) as.integer(round((resolved_unique / total_unique) * 100)) else 0L
            progress_pct <- max(0L, min(100L, progress_pct))
            batch_text <- if (batch_total > 0L) sprintf("%d/%d", batch_idx, batch_total) else "-"

            list(
                total_unique = total_unique,
                resolved_unique = resolved_unique,
                progress_pct = progress_pct,
                provider_text = provider_text,
                phase_text = phase_text,
                batch_text = batch_text
            )
        }

        shiny::observe({
            exiting <- rv$exiting_reviews
            if (!is.data.frame(exiting) || nrow(exiting) == 0L) {
                return(invisible(NULL))
            }
            shiny::invalidateLater(120, session)
            exiting_query_keys()
            invisible(NULL)
        })

        resolve_review_target <- function(payload) {
            if (is.null(payload)) {
                return(NULL)
            }

            payload_obj <- payload
            if (is.character(payload) && length(payload) == 1L && grepl("^\\s*\\{", payload)) {
                parsed <- tryCatch(
                    jsonlite::fromJSON(payload),
                    error = function(e) NULL
                )
                if (is.list(parsed)) payload_obj <- parsed
            }

            query_name <- ""
            if (is.list(payload_obj) && !is.null(payload_obj$query_name)) {
                query_name <- as.character(payload_obj$query_name[[1]] %||% "")
            } else {
                query_name <- as.character(payload_obj[[1]] %||% "")
            }
            query_name <- trimws(query_name)
            if (!nzchar(query_name)) {
                return(NULL)
            }

            # Try stream first, fall back to validation report if stream is stale
            source_df <- NULL
            stream_df <- rv$stream_df
            if (is.data.frame(stream_df) && nrow(stream_df) > 0L) {
                idx <- match(query_name, as.character(stream_df$query_name))
                if (!is.na(idx)) source_df <- stream_df
            }
            if (is.null(source_df)) {
                report_df <- validation_result()
                if (is.data.frame(report_df) && nrow(report_df) > 0L && "query_name" %in% names(report_df)) {
                    idx <- match(query_name, as.character(report_df$query_name))
                    if (!is.na(idx)) source_df <- report_df
                }
            }
            if (is.null(source_df)) {
                return(NULL)
            }

            status_key <- normalize_status_for_filter(source_df$validation_status[[idx]])
            if (!(status_key %in% problem_status_values)) {
                return(NULL)
            }

            list(
                query_name = query_name,
                status_key = status_key,
                scientific_name = query_name
            )
        }

        show_review_modal <- function(mode = "confirm") {
            target <- rv$review_target
            if (is.null(target) || !is.list(target) || !nzchar(as.character(target$query_name %||% ""))) {
                return(invisible(NULL))
            }
            rv$review_mode <- as.character(mode %||% "confirm")
            ctx <- review_status_context(target$status_key %||% "not_found", lang_r())

            lifecycle_script <- sprintf(
                "(function() {
                    var modalEl = document.getElementById('%s');
                    if (!modalEl) { return; }
                    if (document.body) { document.body.classList.add('vn-review-open'); }
                    var cleanup = function () {
                        if (document.body) { document.body.classList.remove('vn-review-open'); }
                    };
                    var modalHost = modalEl.closest('.modal');
                    if (modalHost) {
                        modalHost.addEventListener('hidden.bs.modal', cleanup, { once: true });
                    } else {
                        modalEl.addEventListener('hidden.bs.modal', cleanup, { once: true });
                    }
                })();",
                ns("review_modal_root")
            )

            if (identical(rv$review_mode, "edit")) {
                input_id <- ns("review_corrected_name")
                save_id <- ns("review_save_correction")
                original_json <- jsonlite::toJSON(as.character(target$scientific_name %||% ""), auto_unbox = TRUE)
                edit_script <- sprintf(
                    "(function() {
                        var inputEl = document.getElementById('%s');
                        var btnEl = document.getElementById('%s');
                        var original = %s;
                        if (!inputEl || !btnEl) { return; }
                        var sync = function () {
                            var changed = String(inputEl.value || '').trim() !== String(original || '').trim();
                            btnEl.disabled = !changed;
                        };
                        inputEl.addEventListener('input', sync);
                        sync();
                        window.setTimeout(function () {
                            inputEl.focus();
                            inputEl.select();
                        }, 50);
                    })();",
                    input_id,
                    save_id,
                    original_json
                )

                shiny::showModal(shiny::modalDialog(
                    shiny::div(
                        id = ns("review_modal_root"),
                        class = "vn-review-modal",
                        shiny::div(
                            class = "vn-review-back-row",
                            shiny::actionButton(
                                ns("review_back_to_confirm"),
                                label = tr("validate_names_review_back", lang_r()),
                                class = "btn btn-secondary vn-review-back-btn"
                            )
                        ),
                        shiny::div(class = "vn-review-edit-label", tr("validate_names_review_edit_label", lang_r())),
                        shiny::tags$input(
                            id = ns("review_corrected_name"),
                            type = "text",
                            class = "vn-review-edit-input form-control",
                            value = as.character(target$scientific_name %||% ""),
                            spellcheck = "false",
                            autocomplete = "off"
                        ),
                        shiny::div(
                            class = "vn-review-edit-hint",
                            render_review_name_em(target$scientific_name)
                        ),
                        shiny::tags$textarea(
                            id = ns("review_correction_reason"),
                            class = "vn-review-edit-textarea form-control",
                            placeholder = tr("validate_names_review_reason_placeholder", lang_r())
                        ),
                        shiny::div(
                            class = "vn-review-footer",
                            shiny::tags$button(
                                type = "button",
                                class = "btn vn-review-cancel-btn",
                                `data-bs-dismiss` = "modal",
                                tr("btn_cancel", lang_r())
                            ),
                            shiny::actionButton(
                                ns("review_save_correction"),
                                label = tr("validate_names_review_save_correction", lang_r()),
                                class = "btn btn-success vn-review-save-btn",
                                disabled = "disabled"
                            )
                        ),
                        shiny::tags$script(shiny::HTML(edit_script)),
                        shiny::tags$script(shiny::HTML(lifecycle_script))
                    ),
                    easyClose = TRUE,
                    footer = NULL,
                    fade = TRUE
                ))
                return(invisible(NULL))
            }

            confirm_script <- sprintf(
                "(function() {
                    var block = document.getElementById('%s');
                    var checkbox = document.getElementById('%s');
                    var confirmBtn = document.getElementById('%s');
                    if (!block || !checkbox || !confirmBtn) { return; }
                    var sync = function () {
                        var checked = !!checkbox.checked;
                        confirmBtn.disabled = !checked;
                    };
                    block.addEventListener('click', function (e) {
                        if (e.target && e.target.id === checkbox.id) { return; }
                        checkbox.checked = !checkbox.checked;
                        sync();
                    });
                    checkbox.addEventListener('change', sync);
                    sync();
                })();",
                ns("review_confirm_block"),
                ns("review_confirm_checkbox"),
                ns("review_confirm_keep")
            )

            shiny::showModal(shiny::modalDialog(
                shiny::div(
                    id = ns("review_modal_root"),
                    class = "vn-review-modal",
                    shiny::div(
                        class = trimws(paste("vn-review-header", ctx$header_class)),
                        shiny::div(
                            class = "vn-review-header-icon",
                            status_style_map(target$status_key)$icon_symbol
                        ),
                        shiny::div(
                            class = "vn-review-header-text",
                            shiny::div(
                                class = "vn-review-header-name",
                                render_review_name_em(target$scientific_name)
                            ),
                            shiny::div(
                                class = "vn-review-header-problem",
                                ctx$problem_label
                            )
                        )
                    ),
                    shiny::div(
                        class = "vn-review-body",
                        shiny::div(class = "vn-review-question", ctx$question),
                        shiny::div(class = "vn-review-helper", ctx$helper),
                        shiny::div(
                            id = ns("review_confirm_block"),
                            class = "vn-review-confirm-block",
                            shiny::tags$input(
                                id = ns("review_confirm_checkbox"),
                                type = "checkbox",
                                class = "vn-review-confirm-checkbox"
                            ),
                            shiny::div(
                                class = "vn-review-confirm-text",
                                shiny::div(class = "vn-review-confirm-title", tr("validate_names_review_confirm_title", lang_r())),
                                shiny::div(class = "vn-review-confirm-subtitle", tr("validate_names_review_confirm_subtitle", lang_r()))
                            )
                        ),
                        shiny::actionButton(
                            ns("review_switch_to_edit"),
                            label = tr("validate_names_review_switch_to_edit", lang_r()),
                            class = "btn btn-secondary vn-review-edit-btn"
                        )
                    ),
                    shiny::div(
                        class = "vn-review-footer",
                        shiny::tags$button(
                            type = "button",
                            class = "btn vn-review-cancel-btn",
                            `data-bs-dismiss` = "modal",
                            tr("btn_cancel", lang_r())
                        ),
                        shiny::actionButton(
                            ns("review_confirm_keep"),
                            label = tr("validate_names_review_confirm_btn", lang_r()),
                            class = "btn btn-success vn-review-confirm-btn",
                            disabled = "disabled"
                        )
                    ),
                    shiny::tags$script(shiny::HTML(confirm_script)),
                    shiny::tags$script(shiny::HTML(lifecycle_script))
                ),
                easyClose = TRUE,
                footer = NULL,
                fade = TRUE
            ))
            invisible(NULL)
        }

        shiny::observeEvent(input$open_review_target, {
            target <- resolve_review_target(input$open_review_target)
            if (is.null(target)) {
                # Defensive cleanup: remove stale backdrop from previous modal
                session$sendCustomMessage("vnCleanupBackdrop", list())
                shiny::showNotification(
                    tr("validate_names_review_target_not_found", lang_r()),
                    type = "warning",
                    duration = 4
                )
                return(invisible(NULL))
            }
            rv$review_target <- target
            rv$review_mode <- "confirm"
            tryCatch(
                show_review_modal("confirm"),
                error = function(e) {
                    session$sendCustomMessage("vnCleanupBackdrop", list())
                    shiny::showNotification(
                        sprintf(tr("validate_names_review_open_error", lang_r()), as.character(e$message)),
                        type = "error",
                        duration = 7
                    )
                }
            )
        })

        shiny::observeEvent(input$review_switch_to_edit,
            {
                if (is.null(rv$review_target)) {
                    return(invisible(NULL))
                }
                show_review_modal("edit")
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$review_back_to_confirm,
            {
                if (is.null(rv$review_target)) {
                    return(invisible(NULL))
                }
                show_review_modal("confirm")
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$review_confirm_keep,
            {
                target <- rv$review_target
                if (is.null(target)) {
                    return(invisible(NULL))
                }
                if (!isTRUE(input$review_confirm_checkbox %||% FALSE)) {
                    return(invisible(NULL))
                }

                register_manual_review(
                    query_name = target$query_name,
                    review_type = "confirm",
                    original_name = target$scientific_name,
                    corrected_name = target$scientific_name,
                    reason = tr("validate_names_review_reason_confirmed_by_user", lang_r())
                )
                shiny::removeModal()
                rv$review_target <- NULL
                shiny::showNotification(tr("validate_names_review_toast_confirm", lang_r()), type = "message", duration = 3)
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$review_save_correction,
            {
                target <- rv$review_target
                if (is.null(target)) {
                    return(invisible(NULL))
                }

                original_name <- as.character(target$scientific_name %||% "")
                corrected_name <- trimws(as.character(input$review_corrected_name %||% ""))
                if (!nzchar(corrected_name) || identical(corrected_name, original_name)) {
                    return(invisible(NULL))
                }

                reason_text <- trimws(as.character(input$review_correction_reason %||% ""))
                register_manual_review(
                    query_name = target$query_name,
                    review_type = "correct",
                    original_name = original_name,
                    corrected_name = corrected_name,
                    reason = reason_text
                )
                shiny::removeModal()
                rv$review_target <- NULL
                shiny::showNotification(tr("validate_names_review_toast_correct", lang_r()), type = "message", duration = 3)
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$go_preview_export,
            {
                bslib::nav_select("main_nav", selected = "preview")
            },
            ignoreInit = TRUE
        )

        # Per-species sensitivity editor (ADR-092). Opened from the pill /
        # "+ mark" affordance in the report table; writes an override that
        # wins over the MMA auto-match at export time.
        sensitivity_target <- shiny::reactiveVal(NULL)

        shiny::observeEvent(input$open_sensitivity_target, {
            name <- trimws(as.character(input$open_sensitivity_target %||% ""))
            if (!nzchar(name)) {
                return(invisible(NULL))
            }
            sensitivity_target(name)
            dec <- sensitive_resolve(name, sensitivity_entries_df())
            is_sens <- isTRUE(dec$sensitive[1])
            on_mma <- !is.na(sensitive_category_for(name)[1])
            stored <- rv$sensitivity_overrides[[name]]
            existing_cat <- if (is.list(stored)) stored$category else NULL
            if (is.null(existing_cat) || length(existing_cat) == 0L ||
                is.na(existing_cat) || !nzchar(existing_cat)) {
                existing_cat <- "VU"
            }
            lang <- lang_r()
            level_choices <- stats::setNames(
                c("VU", "EN", "CR", "CR (PEX)"),
                c(tr("sensitive_level_vu", lang), tr("sensitive_level_en", lang),
                  tr("sensitive_level_cr", lang), tr("sensitive_level_crpex", lang))
            )

            shiny::showModal(shiny::modalDialog(
                title = tr("sensitive_panel_title", lang),
                shiny::div(
                    class = "vn-sensitivity-modal",
                    shiny::div(
                        class = "vn-sensitivity-name",
                        shiny::tags$em(name)
                    ),
                    shiny::checkboxInput(
                        ns("sensitivity_is"),
                        label = tr("validate_names_status_badge_sensitive", lang),
                        value = is_sens
                    ),
                    # Species off the MMA list have no auto-category, so let the
                    # researcher pick the threat level the generalization tab
                    # should group it under (only relevant while marked sensitive).
                    if (!isTRUE(on_mma)) {
                        shiny::conditionalPanel(
                            condition = sprintf(
                                "input['%s'] == true", ns("sensitivity_is")
                            ),
                            shiny::selectInput(
                                ns("sensitivity_category"),
                                label = tr("sensitive_pick_level_label", lang),
                                choices = level_choices,
                                selected = existing_cat
                            )
                        )
                    },
                    if (isTRUE(on_mma)) {
                        shiny::div(
                            class = "vn-sensitivity-warning",
                            tr("sensitive_unmark_mma_warning", lang)
                        )
                    }
                ),
                easyClose = TRUE,
                footer = shiny::tagList(
                    shiny::tags$button(
                        type = "button",
                        class = "btn vn-review-cancel-btn",
                        `data-bs-dismiss` = "modal",
                        tr("btn_cancel", lang_r())
                    ),
                    shiny::actionButton(
                        ns("sensitivity_save"),
                        label = tr("btn_save", lang_r()),
                        class = "btn btn-success"
                    )
                )
            ))
        })

        shiny::observeEvent(input$sensitivity_save,
            {
                name <- sensitivity_target()
                if (is.null(name) || !nzchar(name)) {
                    return(invisible(NULL))
                }
                is_sens <- isTRUE(input$sensitivity_is %||% FALSE)
                # Store the chosen level only for an off-MMA species marked
                # sensitive; MMA species (no category input) keep their auto
                # category, and unmarking clears the override level.
                on_mma <- !is.na(sensitive_category_for(name)[1])
                category <- if (is_sens && !isTRUE(on_mma)) {
                    val <- trimws(as.character(input$sensitivity_category %||% ""))
                    if (nzchar(val)) val else NA_character_
                } else {
                    NA_character_
                }
                register_sensitivity_override(
                    name = name,
                    sensitive = is_sens,
                    category = category
                )
                shiny::removeModal()
                sensitivity_target(NULL)
                shiny::showNotification(
                    tr("sensitive_saved_toast", lang_r()),
                    type = "message",
                    duration = 3
                )
            },
            ignoreInit = TRUE
        )

        output$title <- shiny::renderUI({
            shiny::h3(
                shiny::icon("microscope", class = "me-2"),
                tr("validate_names_title", lang_r()),
                class = "text-mono mb-2"
            )
        })

        output$subtitle <- shiny::renderUI({
            shiny::p(tr("validate_names_subtitle", lang_r()), class = "text-accent mb-4")
        })

        output$config_panel <- shiny::renderUI({
            selected <- as.character(rv$selected_providers)
            selected <- selected[!is.na(selected) & nzchar(selected)]
            is_busy <- isTRUE(rv$running) || isTRUE(rv$starting)
            quick <- quick_inputs()
            # Deliberately does NOT read progress_snapshot(), rv$run_state or
            # validation_result(). The run loop rewrites rv$run_state every 60ms,
            # and reactiveValues invalidate on write whether or not the value
            # changed -- so a single read here, even one whose result is thrown
            # away, rebuilds this whole panel ~16 times a second during a run,
            # recreating the two input_switch widgets below each time. The
            # progress bar lives in output$progress_block for exactly this
            # reason; keep the two dependency sets apart.
            run_label <- if (is_busy) tr("validate_names_run_running", lang_r()) else tr("validate_names_run_cta", lang_r())
            can_run <- isTRUE(can_run_validation())

            helper_text <- if (isTRUE(rv$running) && isTRUE(rv$abort_requested)) {
                tr("validate_names_cancel_requested", lang_r())
            } else if (isTRUE(rv$starting)) {
                tr("validate_names_run_running", lang_r())
            } else if (length(selected) == 0L) {
                tr("validate_names_providers_required", lang_r())
            } else if (!identical(quick$status, "ok")) {
                if (identical(quick$status, "missing_scientific")) {
                    tr("validate_names_missing_scientific_name", lang_r())
                } else {
                    ""
                }
            } else {
                tr("validate_names_action_ready", lang_r())
            }

            shiny::div(
                class = "vn-config-panel",
                shiny::div(
                    class = "vn-config-section vn-config-section-providers",
                    shiny::div(class = "vn-section-label", tr("validate_names_providers_card_title", lang_r())),
                    shiny::div(
                        class = "vn-provider-list",
                        lapply(provider_catalog, function(item) {
                            priority <- match(item$id, selected)
                            is_selected <- !is.na(priority)
                            is_priority_one <- is_selected && identical(as.integer(priority), 1L)
                            card_class <- trimws(paste(
                                "vn-provider-card",
                                if (is_selected) "is-selected" else "",
                                if (is_priority_one) "is-priority-1" else "",
                                if (is_busy) "is-disabled" else ""
                            ))

                            badges <- list()
                            if (isTRUE(item$recommended)) {
                                badges[[length(badges) + 1L]] <- shiny::tags$span(
                                    class = "vn-status-badge badge-success",
                                    tr("validate_names_provider_recommended", lang_r())
                                )
                            }
                            if (is_priority_one) {
                                badges[[length(badges) + 1L]] <- shiny::tags$span(
                                    class = "vn-status-badge badge-info",
                                    sprintf(tr("validate_names_provider_priority_badge", lang_r()), 1L)
                                )
                            }
                            if (identical(item$type, "br")) {
                                badges[[length(badges) + 1L]] <- provider_runtime_badge(
                                    provider_runtime_status_for(item$id)
                                )
                            }

                            shiny::actionButton(
                                inputId = ns(provider_button_id(item$id)),
                                icon = NULL,
                                label = shiny::div(
                                    class = "vn-provider-card-content",
                                    shiny::span(
                                        class = "vn-provider-icon-wrap",
                                        shiny::icon(item$icon, class = "vn-provider-icon")
                                    ),
                                    shiny::div(
                                        class = "vn-provider-text-wrap",
                                        shiny::span(class = "vn-provider-name", item$short),
                                        shiny::span(class = "vn-provider-desc", tr(item$desc_key, lang_r()))
                                    ),
                                    shiny::div(class = "vn-provider-badges", badges)
                                ),
                                class = card_class,
                                disabled = is_busy
                            )
                        })
                    ),
                    shiny::div(
                        class = "vn-provider-note",
                        shiny::span(class = "vn-note-icon", shiny::HTML("&#8505;")),
                        if (any(c("florabr", "faunabr") %in% selected)) {
                            tr("validate_names_cascade_br_notice", lang_r())
                        } else {
                            tr("validate_names_priority_notice", lang_r())
                        }
                    ),
                    {
                        in_progress <- br_provider_ids[vapply(
                            br_provider_ids,
                            function(id) {
                                status_obj <- provider_runtime_status_for(id)
                                identical(as.character(status_obj$status %||% ""), "update_in_progress")
                            },
                            FUN.VALUE = logical(1)
                        )]
                        if (length(in_progress) > 0L) {
                            label <- format_provider_labels(in_progress)
                            label <- label[!is.na(label) & nzchar(label)]
                            shiny::div(
                                class = "vn-provider-note",
                                shiny::span(class = "vn-note-icon", shiny::HTML("&#8635;")),
                                paste0("Background update in progress: ", paste(label, collapse = ", "))
                            )
                        }
                    }
                ),
                shiny::div(
                    class = "vn-config-section vn-config-section-options",
                    shiny::div(class = "vn-section-label", tr("validate_names_options_card_title", lang_r())),
                    shiny::div(
                        class = "vn-toggle-list",
                        # isolate() on both reads: this renderUI RECREATES these
                        # switches, so an un-isolated read makes each toggle
                        # rebuild the widget that produced it. The value is still
                        # carried across a legitimate re-render (a language
                        # switch) because it is read back here -- it just no
                        # longer invalidates the panel. Checked against the
                        # ADR-111 trap before isolating: no observer needs to
                        # re-run in the same flush as this recreation, because
                        # nothing syncs these two inputs into rv -- they are read
                        # directly by report_df and review_export_payload.
                        shiny::div(
                            class = "vn-toggle-item",
                            bslib::input_switch(
                                ns("remove_authors"),
                                tr("validate_names_remove_authors", lang_r()),
                                value = isTRUE(shiny::isolate(input$remove_authors) %||% TRUE)
                            ),
                            shiny::p(tr("validate_names_remove_authors_desc", lang_r()), class = "vn-toggle-desc")
                        ),
                        shiny::div(
                            class = "vn-toggle-item",
                            bslib::input_switch(
                                ns("ignore_qualifiers"),
                                tr("validate_names_ignore_qualifiers", lang_r()),
                                value = isTRUE(shiny::isolate(input$ignore_qualifiers) %||% TRUE)
                            ),
                            shiny::p(tr("validate_names_ignore_qualifiers_desc", lang_r()), class = "vn-toggle-desc")
                        )
                    ),
                    shiny::div(
                        class = "vn-options-note",
                        shiny::span(class = "vn-note-icon", shiny::HTML("&#11015;")),
                        tr("validate_names_download_notice", lang_r())
                    )
                ),
                shiny::div(
                    class = "vn-config-section vn-config-section-action",
                    shiny::actionButton(
                        inputId = ns("validate"),
                        label = run_label,
                        class = "vn-run-btn w-100",
                        disabled = !can_run
                    ),
                    if (isTRUE(rv$running)) {
                        shiny::actionButton(
                            inputId = ns("cancel_validation"),
                            label = tr("validate_names_cancel", lang_r()),
                            icon = shiny::icon("stop"),
                            class = "vn-cancel-btn w-100 mt-2",
                            disabled = isTRUE(rv$abort_requested)
                        )
                    },
                    shiny::div(
                        class = "vn-mini-stats",
                        shiny::div(
                            class = "vn-mini-stat",
                            shiny::div(class = "vn-mini-stat-value", as.integer(length(selected))),
                            shiny::div(class = "vn-mini-stat-label", tr("validate_names_action_metric_providers", lang_r()))
                        ),
                        shiny::div(
                            class = "vn-mini-stat",
                            shiny::div(class = "vn-mini-stat-value", as.integer(active_options_count())),
                            shiny::div(class = "vn-mini-stat-label", tr("validate_names_action_metric_options", lang_r()))
                        )
                    ),
                    shiny::uiOutput(ns("progress_block")),
                    shiny::div(class = "vn-action-helper", helper_text)
                )
            )
        })

        # Split out of output$config_panel so the 60ms run tick repaints only the
        # bar. This is the ONLY output allowed to depend on rv$run_state; keeping
        # it small is the whole point.
        output$progress_block <- shiny::renderUI({
            snapshot <- progress_snapshot()

            shiny::div(
                class = "vn-progress-block",
                shiny::div(
                    class = "vn-progress-header",
                    shiny::span(class = "vn-progress-title", tr("validate_names_progress_label", lang_r())),
                    shiny::span(class = "vn-progress-percent", sprintf("%d%%", snapshot$progress_pct))
                ),
                shiny::div(
                    class = "vn-progress-track",
                    shiny::div(class = "vn-progress-fill", style = paste0("width: ", snapshot$progress_pct, "%;"))
                ),
                if (isTRUE(rv$running) && !is.null(rv$run_state)) {
                    shiny::div(
                        class = "vn-progress-phrase-row",
                        shiny::icon(vn_phase_icon(rv$run_state), class = "fa-solid vn-progress-phrase-icon"),
                        shiny::span(class = "vn-progress-phrase-text", vn_phase_text(rv$run_state, lang_r()))
                    )
                }
            )
        })

        output$stream_panel <- shiny::renderUI({
            stream_df <- stream_window(
                rv$stream_df,
                limit = if (isTRUE(rv$running)) stream_window_limit else NULL
            )
            review_keys <- reviewed_query_keys()
            exiting_keys <- exiting_query_keys()
            counts <- stream_filter_counts(stream_df, reviewed_keys = review_keys)
            active_filter <- active_stream_filter()
            filtered_df <- filter_stream_df(
                stream_df,
                active_filter,
                reviewed_keys = review_keys,
                exiting_keys = exiting_keys
            )

            pill_defs <- list(
                list(key = "all", class = "pill-all", label_key = "validate_names_stream_filter_all"),
                list(key = "problems", class = "pill-problems", label_key = "validate_names_stream_filter_problems"),
                list(key = "not_found", class = "pill-error", label_key = "validate_names_stream_filter_not_found"),
                list(key = "ambiguous", class = "pill-warning", label_key = "validate_names_stream_filter_ambiguous"),
                list(key = "synonym", class = "pill-info", label_key = "validate_names_stream_filter_synonym"),
                list(key = "accepted", class = "pill-success", label_key = "validate_names_stream_filter_accepted"),
                list(key = "invasive", class = "pill-invasive", label_key = "validate_names_stream_filter_invasive"),
                list(key = "translocated", class = "pill-translocated", label_key = "validate_names_stream_filter_translocated")
            )

            pills_ui <- shiny::div(
                class = "vn-stream-pills",
                lapply(pill_defs, function(item) {
                    count_value <- suppressWarnings(as.integer(counts[[item$key]]))
                    if (is.na(count_value) || count_value < 0L) count_value <- 0L
                    is_active <- identical(active_filter, item$key)
                    shiny::actionButton(
                        inputId = ns(paste0("stream_filter_", item$key)),
                        label = shiny::tagList(
                            tr(item$label_key, lang_r()),
                            shiny::tags$span(class = "vn-pill-count", count_value)
                        ),
                        class = trimws(paste("vn-stream-pill", item$class, if (is_active) "is-active" else ""))
                    )
                })
            )

            unresolved_count <- suppressWarnings(as.integer(counts[["problems"]]))
            if (is.na(unresolved_count) || unresolved_count < 0L) unresolved_count <- 0L
            all_resolved <- isTRUE(unresolved_count == 0L) && is.data.frame(stream_df) && nrow(stream_df) > 0L

            stream_body <- if (!is.data.frame(stream_df) || nrow(stream_df) == 0L) {
                shiny::div(
                    class = "vn-stream-empty",
                    if (isTRUE(rv$running)) tr("validate_names_stream_waiting", lang_r()) else tr("validate_names_stream_empty", lang_r())
                )
            } else if (isTRUE(all_resolved)) {
                shiny::div(
                    class = "vn-review-empty-state",
                    shiny::div(class = "vn-review-empty-icon", shiny::icon("party-horn", class = "fa-solid")),
                    shiny::div(class = "vn-review-empty-title", tr("validate_names_review_empty_title", lang_r())),
                    shiny::div(class = "vn-review-empty-message", tr("validate_names_review_empty_message", lang_r())),
                    shiny::actionButton(
                        ns("go_preview_export"),
                        label = tr("validate_names_review_empty_export", lang_r()),
                        class = "btn btn-primary vn-review-empty-export"
                    )
                )
            } else if (!is.data.frame(filtered_df) || nrow(filtered_df) == 0L) {
                shiny::div(class = "vn-stream-empty", tr("validate_names_stream_empty_filter", lang_r()))
            } else {
                shiny::div(
                    class = "vn-stream-list",
                    lapply(seq_len(nrow(filtered_df)), function(i) {
                        row <- filtered_df[i, , drop = FALSE]
                        style <- status_style_map(row$validation_status[[1]])
                        provider_label <- format_provider_labels(row$provider[[1]])
                        if (length(provider_label) == 0L) provider_label <- tr("validate_names_loading_provider_unknown", lang_r()) else provider_label <- provider_label[[1]]
                        updated_value <- row$updated_at[[1]]
                        updated_text <- if (inherits(updated_value, "POSIXct")) format(updated_value, "%H:%M:%S") else "--:--:--"
                        status_text <- tr(style$label_key, lang_r())
                        query_name <- as.character(row$query_name[[1]] %||% "")
                        status_key <- normalize_status_for_filter(row$validation_status[[1]])
                        is_problem_unreviewed <- status_key %in% problem_status_values && !(query_name %in% review_keys)
                        is_exiting <- query_name %in% exiting_keys
                        shiny::div(
                            class = trimws(paste("vn-stream-item", style$item_class, if (isTRUE(is_exiting)) "vn-review-item-exit" else "")),
                            shiny::span(class = trimws(paste("vn-stream-status-icon", paste0("vn-stream-status-icon-", style$key))), style$icon_symbol),
                            shiny::div(
                                class = "vn-stream-item-main",
                                shiny::div(class = "vn-stream-item-name", row$query_name[[1]]),
                                invasive_stream_note_ui(query_name, lang_r()),
                                shiny::div(
                                    class = "vn-stream-item-meta",
                                    shiny::span(status_text),
                                    shiny::span(class = "vn-dot"),
                                    shiny::span(provider_label),
                                    shiny::span(class = "vn-dot"),
                                    shiny::span(updated_text)
                                )
                            ),
                            shiny::div(
                                class = "vn-stream-item-actions",
                                if (isTRUE(is_problem_unreviewed) && !isTRUE(is_exiting)) {
                                    shiny::tags$button(
                                        type = "button",
                                        class = "btn btn-secondary vn-review-trigger",
                                        onclick = sprintf(
                                            "Shiny.setInputValue('%s', %s, {priority: 'event'});",
                                            ns("open_review_target"),
                                            jsonlite::toJSON(query_name, auto_unbox = TRUE)
                                        ),
                                        tr("validate_names_review_action", lang_r())
                                    )
                                },
                                shiny::span(class = trimws(paste("vn-status-badge", style$badge_class)), status_text)
                            )
                        )
                    })
                )
            }

            shiny::div(
                class = "vn-stream-panel",
                shiny::div(
                    class = "vn-stream-header",
                    shiny::div(class = "vn-stream-title", tr("validate_names_stream_panel_title", lang_r())),
                    pills_ui
                ),
                shiny::div(
                    class = "vn-stream-body",
                    stream_body
                )
            )
        })

        output$report_panel <- shiny::renderUI({
            report <- effective_report()
            has_report <- is.data.frame(report) && nrow(report) > 0L
            counts <- report_status_counts(report)

            shiny::div(
                class = "vn-report-panel",
                shiny::div(
                    class = "vn-report-statbar",
                    shiny::div(
                        class = "vn-report-statcell",
                        shiny::div(class = "vn-report-statvalue vn-report-statvalue-valid", as.integer(counts[["valid"]])),
                        shiny::div(class = "vn-report-statlabel", tr("validate_names_valid", lang_r()))
                    ),
                    shiny::div(
                        class = "vn-report-statcell",
                        shiny::div(class = "vn-report-statvalue vn-report-statvalue-invalid", as.integer(counts[["invalid"]])),
                        shiny::div(class = "vn-report-statlabel", tr("validate_names_invalid", lang_r()))
                    ),
                    shiny::div(
                        class = "vn-report-statcell",
                        shiny::div(class = "vn-report-statvalue vn-report-statvalue-unresolved", as.integer(counts[["unresolved"]])),
                        shiny::div(class = "vn-report-statlabel", tr("validate_names_unresolved", lang_r()))
                    )
                ),
                if (has_report) conservation_status_summary_ui(report, as.character(rv$selected_providers), br_provider_ids, lang_r()),
                shiny::div(
                    class = "vn-report-header",
                    shiny::div(class = "vn-report-title", tr("validate_names_report_title", lang_r())),
                    shiny::div(
                        class = "vn-report-controls",
                        shiny::tags$input(
                            id = ns("report_search"),
                            type = "search",
                            class = "vn-report-search",
                            placeholder = tr("validate_names_report_search_placeholder", lang_r()),
                            autocomplete = "off",
                            spellcheck = "false"
                        ),
                        shiny::tags$select(
                            id = ns("report_page_length"),
                            class = "vn-report-select",
                            lapply(c(10L, 25L, 50L, 100L), function(size) {
                                if (identical(size, 10L)) {
                                    shiny::tags$option(value = size, selected = "selected", sprintf(tr("validate_names_report_show_n", lang_r()), size))
                                } else {
                                    shiny::tags$option(value = size, sprintf(tr("validate_names_report_show_n", lang_r()), size))
                                }
                            })
                        )
                    )
                ),
                shiny::div(
                    class = "vn-report-table-shell",
                    if (has_report) {
                        DT::dataTableOutput(ns("report_table"))
                    } else {
                        shiny::div(class = "vn-report-empty", tr("validate_names_report_empty", lang_r()))
                    }
                )
            )
        })

        output$report_table <- DT::renderDataTable({
            report <- effective_report()
            shiny::req(is.data.frame(report), nrow(report) > 0L)

            status_vec <- if ("display_status" %in% names(report)) {
                as.character(report$display_status)
            } else {
                normalize_status_vec(report$validation_status)
            }
            scientific_name <- if ("scientificName_display" %in% names(report)) as.character(report$scientificName_display) else if ("scientificName" %in% names(report)) as.character(report$scientificName) else rep("", nrow(report))
            taxonomic_status <- if ("taxonomicStatus" %in% names(report)) as.character(report$taxonomicStatus) else rep("", nrow(report))
            review_original_name <- if ("review_original_name" %in% names(report)) as.character(report$review_original_name) else rep("", nrow(report))
            sensitive_source <- if ("scientificName" %in% names(report)) as.character(report$scientificName) else scientific_name
            # Resolve over unique names only -- per-row normalisation is O(n)
            # per render; mapping back by index keeps the same result in
            # O(unique names).
            u_sens <- unique(sensitive_source)
            du <- sensitive_resolve(u_sens, sensitivity_entries_df())
            sens_idx <- match(sensitive_source, u_sens)
            # Pill shows MMA category as a visual hint when present; researcher
            # overrides for non-MMA species fall back to an em-dash so the
            # downstream JS template ("Sensible \u00b7 {cat}") stays clean.
            cat_for_pill <- du$category[sens_idx]
            cat_for_pill[is.na(cat_for_pill) | !nzchar(cat_for_pill)] <- "\u2014"
            is_sensitive_vec <- ifelse(du$sensitive[sens_idx], cat_for_pill, "")
            # Invasive species (Instituto Horus). The cell carries the
            # origin_class, not a boolean, so the badge can say "alien
            # invasive" only where the list actually asserts it.
            # invasive_info_for() dedupes internally, so the same unique-name
            # economy applies.
            is_invasive_vec <- invasive_origin_class_for(sensitive_source)
            is_invasive_vec[is.na(is_invasive_vec)] <- ""
            # Natural range and introduction reason, resolved over unique names
            # like everything else in this cell and joined with a newline the
            # renderer splits. Empty for taxa the source leaves blank.
            u_inv <- unique(sensitive_source)
            u_detail <- vapply(
                u_inv,
                function(nm) paste(invasive_detail_lines(nm, lang_r()), collapse = "\n"),
                FUN.VALUE = character(1),
                USE.NAMES = FALSE
            )
            invasive_reason_vec <- u_detail[match(sensitive_source, u_inv)]

            table_df <- data.frame(
                scientificName = scientific_name,
                validation_status = status_vec,
                taxonomicStatus = taxonomic_status,
                review_original_name = review_original_name,
                is_sensitive = is_sensitive_vec,
                sensitive_name = sensitive_source,
                is_invasive = is_invasive_vec,
                invasive_reason = invasive_reason_vec,
                stringsAsFactors = FALSE
            )

            colnames(table_df) <- c(
                tr("validate_names_table_col_scientific_name", lang_r()),
                tr("validate_names_table_col_status", lang_r()),
                tr("validate_names_table_col_taxonomic_status", lang_r()),
                ".review_original_name",
                ".is_sensitive",
                ".sensitive_name",
                ".is_invasive",
                ".invasive_reason"
            )

            status_labels <- list(
                accepted = tr("validate_names_status_badge_accepted", lang_r()),
                accepted_manual = tr("validate_names_status_badge_accepted", lang_r()),
                manual_revision = tr("validate_names_status_badge_manual_revision", lang_r()),
                synonym = tr("validate_names_status_badge_synonym", lang_r()),
                not_found = tr("validate_names_status_badge_not_found", lang_r()),
                ambiguous = tr("validate_names_status_badge_ambiguous", lang_r()),
                ignored = tr("validate_names_status_badge_ignored", lang_r())
            )

            replaced_prefix_json <- jsonlite::toJSON(tr("validate_names_review_replaced_prefix", lang_r()), auto_unbox = TRUE)
            sensitive_label_json <- jsonlite::toJSON(tr("validate_names_status_badge_sensitive", lang_r()), auto_unbox = TRUE)
            sensitive_mark_json <- jsonlite::toJSON(tr("sensitive_mark_label", lang_r()), auto_unbox = TRUE)
            invasive_label_json <- jsonlite::toJSON(tr("validate_names_status_badge_invasive", lang_r()), auto_unbox = TRUE)
            translocated_label_json <- jsonlite::toJSON(tr("validate_names_status_badge_translocated", lang_r()), auto_unbox = TRUE)
            invasive_tooltip_json <- jsonlite::toJSON(tr("validate_names_invasive_tooltip", lang_r()), auto_unbox = TRUE)
            translocated_tooltip_json <- jsonlite::toJSON(tr("validate_names_translocated_tooltip", lang_r()), auto_unbox = TRUE)

            status_badge_js <- DT::JS(
                sprintf(
                    paste0(
                        "function(data, type, row) {",
                        "  var status = String(data === null || data === undefined ? '' : data).toLowerCase();",
                        "  if (type !== 'display') return status;",
                        "  var labels = %s;",
                        "  var clsMap = {accepted:'badge-success', accepted_manual:'badge-success', manual_revision:'badge-warning', synonym:'badge-info', not_found:'badge-error', ambiguous:'badge-warning', ignored:'badge-muted'};",
                        "  var cls = clsMap[status] || 'badge-muted';",
                        "  var label = labels[status] || String(data || '');",
                        "  var escaped = $('<div/>').text(label).html();",
                        "  return '<span class=\"vn-status-badge ' + cls + '\">' + escaped + '</span>';",
                        "}"
                    ),
                    jsonlite::toJSON(status_labels, auto_unbox = TRUE)
                )
            )

            scientific_name_js <- DT::JS(
                sprintf(
                    paste0(
                        "function(data, type, row) {",
                        "  if (type !== 'display') return data;",
                        "  if (data === null || data === undefined) return '';",
                        "  var escaped = $('<div/>').text(String(data)).html();",
                        "  var content = '<span class=\"vn-cell-scientific\" title=\"' + escaped + '\">' + escaped + '</span>';",
                        "  var status = String(row[1] === null || row[1] === undefined ? '' : row[1]).toLowerCase();",
                        "  var original = String(row[3] === null || row[3] === undefined ? '' : row[3]);",
                        "  if (status === 'manual_revision' && original.trim().length > 0) {",
                        "    var prefix = %s;",
                        "    var originalEscaped = $('<div/>').text(original).html();",
                        "    content += '<div class=\"vn-cell-review-original\"><em>' + $('<div/>').text(String(prefix)).html() + ' ' + originalEscaped + '</em></div>';",
                        "  }",
                        "  var sensitive = String(row[4] === null || row[4] === undefined ? '' : row[4]).trim();",
                        "  var sn = encodeURIComponent(String(row[5] === null || row[5] === undefined ? '' : row[5]));",
                        "  if (sensitive.length > 0) {",
                        "    var sLabel = %s;",
                        "    var catEsc = $('<div/>').text(sensitive).html();",
                        "    content += '<div class=\"vn-cell-sensitive\"><span class=\"vn-status-badge badge-warning vn-sensitive-trigger\" role=\"button\" tabindex=\"0\" data-sname=\"' + sn + '\">' + $('<div/>').text(String(sLabel)).html() + ' \\u00b7 ' + catEsc + '</span></div>';",
                        "  } else {",
                        "    var mLabel = %s;",
                        "    content += '<div class=\"vn-cell-sensitive\"><span class=\"vn-sensitive-trigger vn-sensitive-add\" role=\"button\" tabindex=\"0\" data-sname=\"' + sn + '\">+ ' + $('<div/>').text(String(mLabel)).html() + '</span></div>';",
                        "  }",
                        "  var invasive = String(row[6] === null || row[6] === undefined ? '' : row[6]).trim();",
                        "  if (invasive.length > 0) {",
                        "    var alien = (invasive === 'alien');",
                        "    var iLabel = alien ? %s : %s;",
                        "    var iTip = alien ? %s : %s;",
                        "    var iClass = alien ? 'badge-error' : 'badge-translocated';",
                        "    var tipEsc = $('<div/>').text(String(iTip)).html().replace(/\"/g, '&quot;');",
                        "    content += '<div class=\"vn-cell-invasive\"><span class=\"vn-status-badge ' + iClass + '\" title=\"' + tipEsc + '\">' + $('<div/>').text(String(iLabel)).html() + '</span>';",
                        "    var iDetail = String(row[7] === null || row[7] === undefined ? '' : row[7]).trim();",
                        "    if (iDetail.length > 0) {",
                        "      iDetail.split('\\n').forEach(function(line) {",
                        "        if (line.length === 0) return;",
                        "        content += '<div class=\"vn-cell-invasive-reason\">' + $('<div/>').text(line).html() + '</div>';",
                        "      });",
                        "    }",
                        "    content += '</div>';",
                        "  }",
                        "  return content;",
                        "}"
                    ),
                    replaced_prefix_json,
                    sensitive_label_json,
                    sensitive_mark_json,
                    invasive_label_json,
                    translocated_label_json,
                    invasive_tooltip_json,
                    translocated_tooltip_json
                )
            )

            taxonomic_status_js <- DT::JS(
                "function(data, type, row) {",
                "  if (type !== 'display') return data;",
                "  if (data === null || data === undefined) return '';",
                "  var escaped = $('<div/>').text(String(data)).html();",
                "  return '<span class=\"vn-cell-taxonomic\" title=\"' + escaped + '\">' + escaped + '</span>';",
                "}"
            )

            row_callback_js <- DT::JS(
                "function(row, data) {",
                "  var status = String(data[1] === null || data[1] === undefined ? '' : data[1]).toLowerCase();",
                "  var classes = ['vn-row-accepted','vn-row-synonym','vn-row-not-found','vn-row-ambiguous','vn-row-ignored','vn-row-manual'];",
                "  for (var i = 0; i < classes.length; i++) { $(row).removeClass(classes[i]); }",
                "  var classMap = {accepted:'vn-row-accepted', accepted_manual:'vn-row-accepted', manual_revision:'vn-row-manual', synonym:'vn-row-synonym', not_found:'vn-row-not-found', ambiguous:'vn-row-ambiguous', ignored:'vn-row-ignored'};",
                "  var cls = classMap[status];",
                "  if (cls) { $(row).addClass(cls); }",
                "}"
            )

            header_callback_js <- DT::JS(
                paste0(
                    "function(thead) {",
                    "  $(thead).find('th').each(function() {",
                    "    var $th = $(this);",
                    "    var label = $th.text();",
                    "    if ($th.find('.vn-th-content').length === 0) {",
                    "      $th.html(\"<span class='vn-th-content'><span class='vn-th-label'>\" + label + \"</span><span class='vn-th-sort'>&#8597;</span></span>\");",
                    "    }",
                    "  });",
                    "}"
                )
            )

            filter_callback_js <- DT::JS(
                sprintf(
                    paste0(
                        "var searchId = %s;",
                        "var pageId = %s;",
                        "var sensId = %s;",
                        "var searchSelector = '#' + searchId;",
                        "var pageSelector = '#' + pageId;",
                        "var nsSafe = searchId.replace(/[^a-zA-Z0-9_-]/g, '');",
                        "var eventNs = '.vnReport.' + nsSafe;",
                        "var $doc = $(document);",
                        "$doc.off('input' + eventNs, searchSelector);",
                        "$doc.off('keyup' + eventNs, searchSelector);",
                        "$doc.off('search' + eventNs, searchSelector);",
                        "$doc.off('change' + eventNs, pageSelector);",
                        "$doc.off('click' + eventNs, '.vn-sensitive-trigger');",
                        "$doc.off('keydown' + eventNs, '.vn-sensitive-trigger');",
                        "var fireSensitive = function(el) {",
                        "  var sn = decodeURIComponent($(el).attr('data-sname') || '');",
                        "  if (sn.length > 0) { Shiny.setInputValue(sensId, sn, {priority: 'event'}); }",
                        "};",
                        "$doc.on('click' + eventNs, '.vn-sensitive-trigger', function() {",
                        "  fireSensitive(this);",
                        "});",
                        "$doc.on('keydown' + eventNs, '.vn-sensitive-trigger', function(e) {",
                        "  if (e.key === 'Enter' || e.key === ' ' || e.keyCode === 13 || e.keyCode === 32) {",
                        "    e.preventDefault();",
                        "    fireSensitive(this);",
                        "  }",
                        "});",
                        "$doc.on('input' + eventNs, searchSelector, function() {",
                        "  table.search(String(this.value || '')).draw(false);",
                        "});",
                        "$doc.on('keyup' + eventNs, searchSelector, function() {",
                        "  table.search(String(this.value || '')).draw(false);",
                        "});",
                        "$doc.on('search' + eventNs, searchSelector, function() {",
                        "  table.search(String(this.value || '')).draw(false);",
                        "});",
                        "$doc.on('change' + eventNs, pageSelector, function() {",
                        "  var len = parseInt(this.value, 10);",
                        "  if (!isNaN(len) && len > 0) {",
                        "    if (table.page.len() !== len) { table.page.len(len); }",
                        "    table.page('first').draw('page');",
                        "  }",
                        "});",
                        "var $search = $(searchSelector);",
                        "if ($search.length) { table.search(String($search.val() || '')).draw(false); }",
                        "var $page = $(pageSelector);",
                        "if ($page.length) {",
                        "  var selectedLen = parseInt($page.val(), 10);",
                        "  if (isNaN(selectedLen) || selectedLen <= 0) {",
                        "    selectedLen = table.page.len();",
                        "    $page.val(String(selectedLen));",
                        "  }",
                        "  table.page.len(selectedLen);",
                        "  table.page('first').draw('page');",
                        "}"
                    ),
                    jsonlite::toJSON(ns("report_search"), auto_unbox = TRUE),
                    jsonlite::toJSON(ns("report_page_length"), auto_unbox = TRUE),
                    jsonlite::toJSON(ns("open_sensitivity_target"), auto_unbox = TRUE)
                )
            )

            DT::datatable(
                table_df,
                options = list(
                    pageLength = 10,
                    lengthMenu = c(10, 25, 50, 100),
                    autoWidth = FALSE,
                    dom = "t<'vn-report-pagination'ip>",
                    columnDefs = list(
                        list(targets = 0, render = scientific_name_js, className = "vn-col-scientific", width = "56%"),
                        list(targets = 1, render = status_badge_js, className = "vn-col-status", width = "16%"),
                        list(targets = 2, render = taxonomic_status_js, className = "vn-col-taxonomic", width = "28%"),
                        list(targets = 3, visible = FALSE, searchable = FALSE),
                        list(targets = 4, visible = FALSE, searchable = FALSE),
                        list(targets = 5, visible = FALSE, searchable = FALSE),
                        list(targets = 6, visible = FALSE, searchable = FALSE),
                        list(targets = 7, visible = FALSE, searchable = FALSE)
                    ),
                    rowCallback = row_callback_js,
                    headerCallback = header_callback_js,
                    language = list(
                        search = tr("validate_names_datatable_search", lang_r()),
                        lengthMenu = tr("validate_names_datatable_length_menu", lang_r()),
                        info = tr("validate_names_datatable_info", lang_r()),
                        emptyTable = tr("validate_names_datatable_empty", lang_r()),
                        zeroRecords = tr("validate_names_datatable_zero_records", lang_r()),
                        paginate = list(
                            first = tr("validate_names_datatable_first", lang_r()),
                            last = tr("validate_names_datatable_last", lang_r()),
                            `next` = tr("validate_names_datatable_next", lang_r()),
                            previous = tr("validate_names_datatable_prev", lang_r())
                        )
                    )
                ),
                callback = filter_callback_js,
                class = "display compact validate-results-table vn-report-table",
                rownames = FALSE,
                escape = FALSE
            )
        })

        shiny::observeEvent(input$validate,
            {
                if (isTRUE(rv$running) || isTRUE(rv$starting)) {
                    return(invisible(NULL))
                }

                quick <- quick_inputs()
                if (!identical(quick$status, "ok")) {
                    msg <- if (identical(quick$status, "missing_scientific")) tr("validate_names_missing_scientific_name", lang_r()) else tr("validate_names_no_data", lang_r())
                    shiny::showNotification(msg, type = "warning")
                    return(invisible(NULL))
                }
                if (length(rv$selected_providers) == 0L) {
                    shiny::showNotification(tr("validate_names_providers_required", lang_r()), type = "warning")
                    return(invisible(NULL))
                }
                # Guard: verify BR packages are installed before starting.
                br_pkg_ids <- intersect(rv$selected_providers, c("florabr", "faunabr"))
                for (br_pkg in br_pkg_ids) {
                    if (!requireNamespace(br_pkg, quietly = TRUE)) {
                        shiny::showNotification(
                            sprintf(tr("validate_names_br_not_installed", lang_r()), br_pkg),
                            type = "error"
                        )
                        return(invisible(NULL))
                    }
                }
                # Enter "starting" phase first so the UI can show immediate feedback.
                rv$starting <- TRUE
                rv$last_run_status <- "starting"
                rv$last_error <- NA_character_
                validation_result(NULL)
                validation_meta(NULL)
                rv$manual_reviews <- empty_manual_reviews()
                rv$review_target <- NULL
                rv$review_mode <- "confirm"
                rv$exiting_reviews <- empty_exiting_reviews()
                rv$stream_filter <- "all"
                shiny::showNotification(tr("validate_names_progress_status_running", lang_r()), type = "message", duration = 2)

                session$onFlushed(function() {
                    rv$start_requested <- TRUE
                }, once = TRUE)
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(rv$start_requested,
            {
                if (!isTRUE(rv$start_requested)) {
                    return(invisible(NULL))
                }
                rv$start_requested <- FALSE

                # Heavy normalization stays deferred until explicit validate click.
                prep <- prepared_inputs()
                if (prep$valid_count == 0L) {
                    rv$starting <- FALSE
                    rv$last_run_status <- "idle"
                    shiny::showNotification(tr("validate_names_no_valid_queries", lang_r()), type = "warning")
                    return(invisible(NULL))
                }

                run_state <- tryCatch(
                    init_taxadb_run_state(input_df = prep$unique_df, providers = rv$selected_providers, batch_size = 200L),
                    error = function(e) {
                        shiny::showNotification(sprintf(tr("validate_names_failed", lang_r()), as.character(e$message)), type = "error")
                        NULL
                    }
                )
                if (is.null(run_state)) {
                    rv$starting <- FALSE
                    rv$last_run_status <- "failed"
                    return(invisible(NULL))
                }

                rv$running <- TRUE
                rv$starting <- FALSE
                rv$abort_requested <- FALSE
                rv$run_state <- run_state
                rv$stream_df <- empty_validation_stream()
                rv$last_run_status <- "running"
                rv$last_error <- NA_character_
            },
            ignoreInit = TRUE
        )

        shiny::observeEvent(input$cancel_validation,
            {
                if (!isTRUE(rv$running)) {
                    return(invisible(NULL))
                }
                rv$abort_requested <- TRUE
            },
            ignoreInit = TRUE
        )

        shiny::observe({
            if (!isTRUE(rv$running) || is.null(rv$run_state)) {
                return(invisible(NULL))
            }
            shiny::invalidateLater(60, session)

            state <- rv$run_state
            if (isTRUE(rv$abort_requested)) state$aborted <- TRUE

            state <- tryCatch(next_taxadb_run_step(state), error = function(e) {
                state$error_message <- as.character(e$message)
                state$phase <- "failed"
                state$completed <- TRUE
                state
            })

            rv$run_state <- state
            rv$stream_df <- state$stream_df
            if (!is_taxadb_run_done(state)) {
                return(invisible(NULL))
            }

            rv$running <- FALSE
            rv$starting <- FALSE
            rv$abort_requested <- FALSE

            if (identical(state$phase, "failed")) {
                rv$last_run_status <- "failed"
                rv$last_error <- sprintf(tr("validate_names_failed", lang_r()), as.character(state$error_message %||% tr("validate_names_error_unknown", lang_r())))
                shiny::showNotification(rv$last_error, type = "error")
                return(invisible(NULL))
            }

            finalized <- finalize_taxadb_run(state)
            validation_result(finalized$report)
            validation_meta(finalized$meta)
            rv$stream_df <- finalized$stream_df
            rv$stream_filter <- stream_filter_after_completion(finalized$report)

            if (isTRUE(finalized$meta$aborted)) {
                rv$last_run_status <- "cancelled"
                shiny::showNotification(tr("validate_names_cancelled_notice", lang_r()), type = "warning")
            } else {
                rv$last_run_status <- "success"
            }
        })

        review_export_payload <- shiny::reactive({
            list(
                entries = review_entries_df(),
                normalize_opts = list(
                    remove_authors = isTRUE(input$remove_authors %||% TRUE),
                    ignore_qualifiers = isTRUE(input$ignore_qualifiers %||% TRUE)
                )
            )
        })

        sensitivity_payload <- shiny::reactive({
            sensitivity_entries_df()
        })

        # Conservation-status enrichment for the export's dynamicProperties.
        # MMA (local) when a BR provider is selected; IUCN (GBIF network) when
        # GBIF is selected -- GBIF is pre-selected, so IUCN is on by default.
        # taxon_keys carries the GBIF usageKey (taxonID) per resolved name so the
        # export can query IUCN without re-resolving rows GBIF already matched.
        conservation_payload <- shiny::reactive({
            selected <- as.character(rv$selected_providers)
            report <- validation_result()
            key_cols <- c("scientificName", "taxonID", "provider")
            taxon_keys <- if (is.data.frame(report) && all(key_cols %in% names(report))) {
                report[, key_cols, drop = FALSE]
            } else {
                data.frame(
                    scientificName = character(0),
                    taxonID = character(0),
                    provider = character(0),
                    stringsAsFactors = FALSE
                )
            }
            list(
                include_mma = length(intersect(selected, br_provider_ids)) > 0L,
                include_iucn = "gbif" %in% selected,
                taxon_keys = taxon_keys
            )
        })

        # A re-upload or a confirmed Mapping reset invalidates the dataset
        # baseline: drop every decision made for the previous dataset so nothing
        # leaks into the new one. Provider selection and runtime status are kept
        # (they mirror the on-disk download cache, not dataset work).
        if (!is.null(reset_signal_r)) {
            shiny::observeEvent(reset_signal_r(), {
                validation_result(NULL)
                validation_meta(NULL)
                sensitivity_target(NULL)
                rv$manual_reviews <- empty_manual_reviews()
                rv$review_target <- NULL
                rv$review_mode <- "confirm"
                rv$sensitivity_overrides <- list()
                rv$exiting_reviews <- empty_exiting_reviews()
                rv$stream_df <- empty_validation_stream()
                rv$stream_filter <- "all"
                rv$run_state <- NULL
                rv$last_run_status <- "idle"
                rv$last_error <- NA_character_
                rv$starting <- FALSE
                rv$running <- FALSE
                rv$start_requested <- FALSE
                rv$abort_requested <- FALSE
            }, ignoreInit = TRUE)
        }

        result_r <- shiny::reactive(validation_result())
        attr(result_r, "review_export_payload") <- review_export_payload
        attr(result_r, "sensitivity_payload") <- sensitivity_payload
        attr(result_r, "conservation_payload") <- conservation_payload
        result_r
    })
}
