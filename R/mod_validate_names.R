# Title: Validate Names Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-26
# Version: 2.3

#' @include mod_validate_names_helpers.R
NULL

#' Validate Names Module Server
#'
#' @param id Module ID
#' @param mapped_data_r Reactive data frame with mapped data
#' @param lang_r Reactive language value
#' @param validation_gate_r Optional lightweight gate reactive from mapping module
#' @param reset_signal_r Optional reactive reset signal from the mapping module.
#'   When it fires, module-local state and inputs are cleared.
#' @return A reactive with legacy attributes by default, or a named list of
#'   reactives when return_contract is \code{"list"}.
#' @param return_contract Return a legacy reactive (default) or a named list of reactives.
#' @export
mod_validate_names_server <- function(id, mapped_data_r, lang_r, validation_gate_r = NULL, reset_signal_r = NULL, return_contract = c("legacy", "list")) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        provider_catalog <- list(
            list(id = "florabr", short = "Flora BR", full_key = "validate_names_provider_florabr_full", desc_key = "validate_names_provider_florabr_desc", icon = "seedling",      locked = FALSE, type = "br"),
            list(id = "faunabr", short = "Fauna BR", full_key = "validate_names_provider_faunabr_full", desc_key = "validate_names_provider_faunabr_desc", icon = "paw",           locked = FALSE, type = "br"),
            list(id = "gbif",    short = "GBIF",     full_key = "validate_names_provider_gbif_full",    desc_key = "validate_names_provider_gbif_desc",    icon = "earth-americas", locked = TRUE,  type = "colxr")
        )
        provider_ids <- vapply(provider_catalog, function(item) item$id, FUN.VALUE = character(1))
        # GBIF is the fallback of every run, so the user cannot turn it off.
        locked_provider_ids <- provider_ids[vapply(provider_catalog, function(item) isTRUE(item$locked), logical(1))]
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
            # GBIF is always on (locked); any BR provider already downloaded
            # to the on-disk cache is pre-selected so the user's last download
            # persists across app restarts (the RDS cache is the persistence).
            selected_providers = c(
                "gbif",
                br_provider_ids[vapply(br_provider_ids, brprovider_data_available, logical(1))]
            ),
            starting = FALSE,
            start_requested = FALSE,
            running = FALSE,
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
        # Plain environment, not reactive: the run tick reads and writes it
        # ~16 times a second, and no output may depend on that.
        run_card <- new.env(parent = emptyenv())
        run_card$last_sent <- NULL
        run_card$fade_report <- FALSE

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

        # Poll the BR provider caches only during a run or a background update.
        # A run can start an update that continues after the run, so the end
        # of a run reads the status again and an update keeps the poll on.
        shiny::observe({
            active <- isTRUE(rv$running) || isTRUE(rv$starting)
            previous <- shiny::isolate(rv$provider_runtime_status)
            updated <- refresh_provider_runtime_status(poll = TRUE)
            has_running_update <- is.list(updated) && any(vapply(
                br_provider_ids,
                function(id) identical(as.character((updated[[id]] %||% list())$status %||% ""), "update_in_progress"),
                FUN.VALUE = logical(1)
            ))
            if (active || has_running_update) {
                shiny::invalidateLater(1200, session)
            }

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
        # Synonyms of MMA-listed species (B18), resolved once per validation.
        synonym_entries_r <- shiny::reactive({
            synonym_sensitivity_entries(validation_result())
        })

        # The manual overrides win over a synonym entry for the same name.
        sensitivity_entries_df <- function() {
            manual <- manual_sensitivity_entries_df()
            syn <- tryCatch(synonym_entries_r(), error = function(e) NULL)
            if (!is.data.frame(syn) || nrow(syn) == 0L) {
                return(manual)
            }
            taken <- build_sensitive_match_keys(manual$scientificName)
            syn <- syn[!build_sensitive_match_keys(syn$scientificName) %in% taken, , drop = FALSE]
            rbind(manual, syn)
        }

        manual_sensitivity_entries_df <- function() {
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
            if (provider_id %in% locked_provider_ids) {
                return(invisible(NULL))
            }
            selected <- as.character(rv$selected_providers)
            selected <- selected[!is.na(selected) & nzchar(selected)]
            if (provider_id %in% selected) selected <- selected[selected != provider_id] else selected <- c(selected, provider_id)
            rv$selected_providers <- selected
        }

        for (provider_id in setdiff(provider_ids, locked_provider_ids)) {
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

        can_run_validation <- shiny::reactive({
            prep <- quick_inputs()
            length(rv$selected_providers) > 0L && identical(prep$status, "ok") && !isTRUE(rv$running) && !isTRUE(rv$starting)
        })

        has_validation_output <- shiny::reactive({
            report <- validation_result()
            is.data.frame(report) && nrow(report) > 0L
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

            # The stream has no suggestion column, so it comes from the report.
            report_df <- validation_result()
            suggested_name <- if (is.data.frame(report_df) && "suggestedName" %in% names(report_df)) {
                as.character(report_df$suggestedName[match(query_name, as.character(report_df$query_name))])
            } else {
                NA_character_
            }

            list(
                query_name = query_name,
                status_key = status_key,
                scientific_name = query_name,
                suggested_name = suggested_name
            )
        }

        show_review_modal <- function(mode = "confirm") {
            rv$review_mode <- as.character(mode %||% "confirm")
            show_names_review_modal(rv$review_mode, rv$review_target, ns, lang_r)
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

        # One row of the answer list. data-key lets vnStreamSync change the
        # rows of a run in place.

        # The pill counts and the rows of the active filter. The counts take
        # every answered name, also while the list shows only the newest.
        # After a run, the names it left unchecked go to their own block.

        # The rows and counts of a run, sent when an answer arrives. The
        # panel above stays in the page.
        shiny::observe({
            if (!isTRUE(rv$running)) {
                return(invisible(NULL))
            }
            view <- stream_view()
            lang <- shiny::isolate(lang_r())
            rows <- view$filtered_df
            n_rows <- if (is.data.frame(rows)) nrow(rows) else 0L
            has_stream <- is.data.frame(view$stream_df) && nrow(view$stream_df) > 0L
            empty_key <- if (has_stream) "validate_names_stream_empty_filter" else "validate_names_stream_waiting"
            session$sendCustomMessage("vnStreamSync", list(
                id = ns("stream_panel"),
                pill_prefix = ns("stream_filter_"),
                counts = as.list(view$counts),
                rows = lapply(seq_len(n_rows), function(i) {
                    row <- rows[i, , drop = FALSE]
                    list(
                        key = as.character(row$query_name[[1]]),
                        html = as.character(stream_item_ui(row, view$review_keys, view$exiting_keys, lang))
                    )
                }),
                empty = as.character(shiny::div(class = "vn-stream-empty", tr(empty_key, lang)))
            ))
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
                #
                # Guarded because this runs inside an observer: an untrapped
                # error here ends the whole Shiny session, so a defect anywhere
                # upstream in the mapping pipeline closed the app instead of
                # reporting itself. `req()` upstream raises a silent error by
                # design, which means "no data yet" and must stay silent.
                prep <- tryCatch(
                    prepared_inputs(),
                    error = function(e) {
                        if (inherits(e, "shiny.silent.error")) {
                            return(NULL)
                        }
                        shiny::showNotification(
                            sprintf(tr("validate_names_failed", lang_r()), as.character(e$message)),
                            type = "error"
                        )
                        NULL
                    }
                )
                if (is.null(prep)) {
                    rv$starting <- FALSE
                    rv$last_run_status <- "idle"
                    return(invisible(NULL))
                }
                if (prep$valid_count == 0L) {
                    rv$starting <- FALSE
                    rv$last_run_status <- "idle"
                    shiny::showNotification(tr("validate_names_no_valid_queries", lang_r()), type = "warning")
                    return(invisible(NULL))
                }

                run_state <- tryCatch(
                    init_taxadb_run_state(input_df = prep$unique_df, providers = rv$selected_providers, batch_size = 20L),
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

                run_card$last_sent <- NULL
                rv$running <- TRUE
                rv$starting <- FALSE
                rv$run_state <- run_state
                rv$stream_df <- empty_validation_stream()
                rv$last_run_status <- "running"
                rv$last_error <- NA_character_
            },
            ignoreInit = TRUE
        )

        shiny::observe({
            # rv$run_state is read under isolate(): the tick writes it, and a
            # dependency would start the next tick in the same flush. The
            # session would then stay busy, and Shiny sends no output value
            # until the run ends (ADR-159).
            state <- shiny::isolate(rv$run_state)
            if (!isTRUE(rv$running) || is.null(state)) {
                return(invisible(NULL))
            }
            shiny::invalidateLater(60, session)

            state <- tryCatch(next_taxadb_run_step(state), error = function(e) {
                state$error_message <- as.character(e$message)
                state$phase <- "failed"
                state$completed <- TRUE
                state
            })

            rv$run_state <- state
            rv$stream_df <- vn_settled_stream(state)
            if (!is_taxadb_run_done(state)) {
                # Send only what changed: most ticks leave the count as it is.
                progress <- vn_run_progress(state, shiny::isolate(lang_r()))
                if (!identical(progress, run_card$last_sent)) {
                    run_card$last_sent <- progress
                    session$sendCustomMessage("vnRunProgress", progress)
                }
                return(invisible(NULL))
            }

            run_card$fade_report <- TRUE
            rv$running <- FALSE
            rv$starting <- FALSE

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

            # With unchecked names, the block above the answer list tells the
            # failure and has the retry button. A notification tells it only
            # when another provider checked every name.
            failure_text <- vn_provider_failure_message(finalized$meta, lang_r())
            if (is.null(failure_text)) {
                rv$last_run_status <- "success"
            } else {
                rv$last_run_status <- "partial"
                if (length(finalized$meta$unchecked) == 0L) {
                    shiny::showNotification(failure_text, type = "warning", duration = NULL)
                }
            }
        })

        # The retry keeps the reviews and the answers of the run before it.
        shiny::observeEvent(input$retry_unchecked,
            {
                if (isTRUE(rv$running) || isTRUE(rv$starting)) {
                    return(invisible(NULL))
                }
                run_state <- tryCatch(
                    init_taxadb_retry_state(rv$run_state),
                    error = function(e) {
                        shiny::showNotification(sprintf(tr("validate_names_failed", lang_r()), as.character(e$message)), type = "error")
                        NULL
                    }
                )
                if (is.null(run_state)) {
                    return(invisible(NULL))
                }
                run_card$last_sent <- NULL
                rv$stream_df <- vn_settled_stream(run_state)
                rv$running <- TRUE
                rv$run_state <- run_state
                rv$last_run_status <- "running"
                rv$last_error <- NA_character_
            },
            ignoreInit = TRUE
        )

        review_export_payload <- shiny::reactive({
            list(
                entries = review_entries_df(),
                ranks = name_rank_table(validation_result()),
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
        # The IUCN lookup reuses the COL XR matches of the names run (session memo).
        conservation_payload <- shiny::reactive({
            selected <- as.character(rv$selected_providers)
            list(
                include_mma = length(intersect(selected, br_provider_ids)) > 0L,
                include_iucn = "gbif" %in% selected
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
            }, ignoreInit = TRUE)
        }

        presentation <- mount_mod_validate_names_presentation(
            active_stream_filter = active_stream_filter,
            br_provider_ids = br_provider_ids,
            can_run_validation = can_run_validation,
            effective_report = effective_report,
            exiting_query_keys = exiting_query_keys,
            input = input,
            lang_r = lang_r,
            ns = ns,
            output = output,
            problem_status_values = problem_status_values,
            provider_button_id = provider_button_id,
            provider_catalog = provider_catalog,
            provider_runtime_status_for = provider_runtime_status_for,
            quick_inputs = quick_inputs,
            reviewed_query_keys = reviewed_query_keys,
            sensitivity_entries_df = sensitivity_entries_df,
            session = session,
            stream_window_limit = stream_window_limit,
            validation_meta = validation_meta,
            view = list(
                run_state = shiny::reactive(rv$run_state),
                running = shiny::reactive(rv$running),
                selected_providers = shiny::reactive(rv$selected_providers),
                starting = shiny::reactive(rv$starting),
                stream_df = shiny::reactive(rv$stream_df)
            ),
            consume_report_fade = function() {
                fade <- run_card$fade_report
                run_card$fade_report <- FALSE
                fade
            }
        )
        stream_item_ui <- presentation$stream_item_ui
        stream_view <- presentation$stream_view
        provider_runtime_badge <- presentation$provider_runtime_badge

        result_r <- shiny::reactive(validation_result())
        module_result_return(
            new_module_result(result_r, reviews_r = review_export_payload, sensitivity_r = sensitivity_payload, conservation_r = conservation_payload),
            c("review_export_payload" = "reviews_r", "sensitivity_payload" = "sensitivity_r", "conservation_payload" = "conservation_r"), return_contract
        )
    })
}
