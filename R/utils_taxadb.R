# Title: Taxonomic Validation Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-15
# Version: 1.0

validate_bool_flag <- function(value, name) {
    if (!is.logical(value) || length(value) != 1L || is.na(value)) {
        stop(sprintf("%s must be a single TRUE or FALSE value.", name))
    }
}

taxadb_expected_columns <- function() {
    c(
        "taxonID",
        "scientificName",
        "taxonRank",
        "acceptedNameUsageID",
        "taxonomicStatus",
        "update_date",
        "kingdom",
        "phylum",
        "class",
        "order",
        "family",
        "genus",
        "specificEpithet",
        "vernacularName",
        "infraspecificEpithet"
    )
}

strip_taxadb_token <- function(token) {
    gsub("^[^A-Za-z0-9x.-]+|[^A-Za-z0-9x.-]+$", "", token)
}

format_scientific_tokens <- function(tokens, rank_tokens) {
    if (length(tokens) == 0L) {
        return(tokens)
    }

    formatted <- tokens
    for (idx in seq_along(tokens)) {
        token <- tokens[[idx]]
        lower <- tolower(token)

        if (lower %in% rank_tokens) {
            formatted[[idx]] <- lower
            next
        }

        if (lower %in% c("x")) {
            formatted[[idx]] <- lower
            next
        }

        if (idx == 1L) {
            formatted[[idx]] <- paste0(toupper(substr(lower, 1, 1)), substr(lower, 2, nchar(lower)))
        } else {
            formatted[[idx]] <- lower
        }
    }

    formatted
}

normalize_scientific_name <- function(
  name,
  remove_authors = TRUE,
  ignore_qualifiers = TRUE
) {
    validate_bool_flag(remove_authors, "remove_authors")
    validate_bool_flag(ignore_qualifiers, "ignore_qualifiers")

    if (is_blank_value(name)) {
        return(NA_character_)
    }

    value <- as.character(name)
    value <- gsub("\\|", " ", value)
    value <- gsub("\\s+", " ", trimws(value))

    if (!nzchar(value)) {
        return(NA_character_)
    }

    if (remove_authors) {
        value <- gsub("\\([^\\)]*\\)", " ", value)
    }

    value <- gsub("\\s+", " ", trimws(value))
    if (!nzchar(value)) {
        return(NA_character_)
    }

    tokens <- strsplit(value, " ", fixed = TRUE)[[1]]
    tokens <- trimws(tokens)
    tokens <- vapply(tokens, strip_taxadb_token, FUN.VALUE = character(1))
    tokens <- tokens[nzchar(tokens)]

    if (length(tokens) == 0L) {
        return(NA_character_)
    }

    rank_tokens <- c("subsp", "subsp.", "var", "var.", "f", "f.", "forma")
    qualifier_tokens <- c("cf", "cf.", "aff", "aff.", "nr", "nr.", "sp", "sp.", "spp", "spp.")

    if (remove_authors) {
        author_connectors <- c("ex", "in", "et", "al.", "and", "&")
        keep <- logical(length(tokens))
        for (idx in seq_along(tokens)) {
            token <- tokens[[idx]]
            lower <- tolower(token)

            if (idx == 1L) {
                keep[[idx]] <- TRUE
                next
            }

            if (lower %in% rank_tokens) {
                keep[[idx]] <- TRUE
                next
            }

            if (lower %in% author_connectors) {
                keep[[idx]] <- FALSE
                next
            }

            if (grepl("^[0-9]{4}$", token)) {
                keep[[idx]] <- FALSE
                next
            }

            if (grepl("^[A-Z]", token)) {
                keep[[idx]] <- FALSE
                next
            }

            keep[[idx]] <- TRUE
        }
        tokens <- tokens[keep]
    }

    if (length(tokens) == 0L) {
        return(NA_character_)
    }

    if (ignore_qualifiers) {
        had_sp_marker <- any(tolower(tokens) %in% c("sp", "sp.", "spp", "spp."))
        tokens <- tokens[!(tolower(tokens) %in% qualifier_tokens)]
        if (length(tokens) == 1L && had_sp_marker) {
            return(NA_character_)
        }
    }

    tokens <- tokens[nzchar(tokens)]
    if (length(tokens) == 0L) {
        return(NA_character_)
    }

    tokens <- format_scientific_tokens(tokens, rank_tokens)
    normalized <- gsub("\\s+", " ", trimws(paste(tokens, collapse = " ")))

    if (!nzchar(normalized)) {
        return(NA_character_)
    }

    normalized
}

prepare_taxadb_inputs <- function(
  names_vec,
  remove_authors = TRUE,
  ignore_qualifiers = TRUE
) {
    validate_bool_flag(remove_authors, "remove_authors")
    validate_bool_flag(ignore_qualifiers, "ignore_qualifiers")

    input_chr <- as.character(names_vec)
    row_id <- seq_along(input_chr)

    # Normalize only unique raw names, then map back to all rows.
    unique_input <- unique(input_chr)
    unique_query <- vapply(
        unique_input,
        function(value) {
            normalize_scientific_name(
                value,
                remove_authors = remove_authors,
                ignore_qualifiers = ignore_qualifiers
            )
        },
        FUN.VALUE = character(1)
    )
    query_name <- unname(unique_query[match(input_chr, unique_input)])

    query_name[is.na(query_name) | !nzchar(query_name)] <- NA_character_

    skip_reason <- rep(NA_character_, length(input_chr))
    blank_idx <- is.na(input_chr) | !nzchar(trimws(input_chr))
    skip_reason[blank_idx] <- "blank"
    skip_reason[!blank_idx & is.na(query_name)] <- "ignored"

    data.frame(
        row_id = row_id,
        input_name = input_chr,
        query_name = query_name,
        skip_reason = skip_reason,
        stringsAsFactors = FALSE,
        row.names = NULL
    )
}

ensure_taxadb_columns <- function(df) {
    expected_cols <- taxadb_expected_columns()
    missing_cols <- setdiff(expected_cols, names(df))
    if (length(missing_cols) > 0L) {
        for (col_name in missing_cols) {
            df[[col_name]] <- NA_character_
        }
    }
    df
}

fetch_taxadb_matches <- function(query_names, provider) {
    if (length(query_names) == 0L) {
        return(data.frame())
    }

    if (is_blank_value(provider)) {
        stop("provider must be provided.")
    }

    names_chr <- unique(as.character(query_names))
    names_chr <- names_chr[!is.na(names_chr) & nzchar(names_chr)]
    if (length(names_chr) == 0L) {
        return(data.frame())
    }

    db <- tryCatch(
        taxadb::td_create(provider),
        error = function(e) {
            stop(sprintf("Failed to initialize taxadb provider '%s': %s", provider, e$message))
        }
    )

    matches <- taxadb::filter_name(names_chr, provider = provider, db = db)
    matches_df <- as.data.frame(matches, stringsAsFactors = FALSE)

    if (nrow(matches_df) == 0L) {
        return(data.frame())
    }

    matches_df$provider <- provider

    if (!"query_name" %in% names(matches_df)) {
        candidate_cols <- c(
            "input",
            "input_name",
            "inputName",
            "query",
            "query_name",
            "search_term",
            "searched_name",
            "matched_name",
            "name"
        )
        matched_col <- candidate_cols[candidate_cols %in% names(matches_df)][1]

        if (!is.na(matched_col) && nzchar(matched_col)) {
            matches_df$query_name <- as.character(matches_df[[matched_col]])
        } else if ("scientificName" %in% names(matches_df)) {
            name_lookup <- stats::setNames(names_chr, tolower(names_chr))
            lower_sn <- tolower(as.character(matches_df$scientificName))
            mapped <- unname(name_lookup[lower_sn])
            mapped[is.na(mapped)] <- as.character(matches_df$scientificName)[is.na(mapped)]
            matches_df$query_name <- mapped
        } else {
            matches_df$query_name <- NA_character_
        }
    }

    matches_df
}

normalize_taxonomic_status <- function(status) {
    if (is_blank_value(status)) {
        return("unresolved")
    }

    status_lower <- tolower(as.character(status))
    if (identical(status_lower, "accepted")) {
        return("accepted")
    }

    if (grepl("synonym|misspell|misappl|invalid|unaccepted|provision", status_lower)) {
        return("synonym")
    }

    "unresolved"
}

resolve_taxadb_matches <- function(matches_df) {
    if (is.null(matches_df) || nrow(matches_df) == 0L) {
        return(data.frame())
    }

    if (!"query_name" %in% names(matches_df)) {
        stop("matches_df must include query_name.")
    }

    matches_df <- ensure_taxadb_columns(matches_df)
    split_matches <- split(matches_df, matches_df$query_name)

    resolved <- lapply(names(split_matches), function(query_name) {
        slice <- split_matches[[query_name]]
        match_count <- nrow(slice)

        if (match_count == 1L) {
            row <- slice[1, , drop = FALSE]
            row$validation_status <- normalize_taxonomic_status(row$taxonomicStatus)
            row$match_count <- as.integer(match_count)
            row$query_name <- query_name
            return(row)
        }

        row <- slice[1, , drop = FALSE]
        row[, ] <- NA
        row$query_name <- query_name
        if ("provider" %in% names(slice)) {
            row$provider <- slice$provider[[1]]
        }
        row$scientificName <- query_name
        row$validation_status <- "ambiguous"
        row$match_count <- as.integer(match_count)
        row
    })

    do.call(rbind, resolved)
}

build_taxadb_placeholder <- function(query_names, status) {
    if (length(query_names) == 0L) {
        return(data.frame())
    }

    query_names <- as.character(query_names)
    df <- data.frame(
        query_name = query_names,
        stringsAsFactors = FALSE
    )

    for (col_name in taxadb_expected_columns()) {
        df[[col_name]] <- NA_character_
    }

    df$scientificName <- query_names
    df$provider <- NA_character_
    df$validation_status <- status
    df$match_count <- 0L
    df
}

run_taxadb_cascade <- function(
  query_names,
  providers,
  fetch_fun = fetch_taxadb_matches
) {
    provider_failures <- data.frame(
        provider = character(0),
        error = character(0),
        stringsAsFactors = FALSE
    )

    attach_metadata <- function(df, attempted, failures) {
        attr(df, "provider_attempted") <- attempted
        attr(df, "provider_failures") <- failures
        df
    }

    if (length(query_names) == 0L) {
        return(attach_metadata(data.frame(), character(0), provider_failures))
    }

    providers <- providers[!is.na(providers) & nzchar(providers)]
    if (length(providers) == 0L) {
        stop("providers must include at least one provider.")
    }

    remaining <- unique(as.character(query_names))
    remaining <- remaining[!is.na(remaining) & nzchar(remaining)]

    resolved_list <- list()

    for (provider in providers) {
        if (length(remaining) == 0L) {
            break
        }

        matches <- tryCatch(
            fetch_fun(remaining, provider),
            error = function(e) {
                provider_failures <<- rbind(
                    provider_failures,
                    data.frame(
                        provider = as.character(provider),
                        error = as.character(e$message),
                        stringsAsFactors = FALSE
                    )
                )
                NULL
            }
        )
        if (is.null(matches) || nrow(matches) == 0L) {
            next
        }

        resolved <- resolve_taxadb_matches(matches)
        if (nrow(resolved) == 0L) {
            next
        }

        resolved_list[[length(resolved_list) + 1L]] <- resolved
        resolved_names <- unique(resolved$query_name)
        remaining <- setdiff(remaining, resolved_names)
    }

    if (length(remaining) > 0L) {
        resolved_list[[length(resolved_list) + 1L]] <- build_taxadb_placeholder(
            remaining,
            status = "not_found"
        )
    }

    if (length(resolved_list) == 0L) {
        return(attach_metadata(data.frame(), providers, provider_failures))
    }

    all_cols <- unique(unlist(lapply(resolved_list, names), use.names = FALSE))
    resolved_list <- lapply(resolved_list, function(df) {
        missing_cols <- setdiff(all_cols, names(df))
        if (length(missing_cols) > 0L) {
            for (col_name in missing_cols) {
                df[[col_name]] <- NA
            }
        }
        df <- df[, all_cols, drop = FALSE]
        rownames(df) <- NULL
        df
    })

    combined <- do.call(rbind, resolved_list)
    attach_metadata(combined, providers, provider_failures)
}

clean_provider_ids <- function(providers) {
    providers_chr <- as.character(providers)
    providers_chr <- providers_chr[!is.na(providers_chr) & nzchar(providers_chr)]
    unique(providers_chr)
}

split_query_batches <- function(query_names, batch_size = 200L) {
    if (length(query_names) == 0L) {
        return(list())
    }

    size_int <- suppressWarnings(as.integer(batch_size))
    if (is.na(size_int) || size_int < 1L) {
        size_int <- 200L
    }

    split(
        query_names,
        ceiling(seq_along(query_names) / size_int)
    )
}

init_taxadb_provider <- function(provider) {
    if (is_blank_value(provider)) {
        stop("provider must be provided.")
    }

    tryCatch(
        taxadb::td_create(provider),
        error = function(e) {
            stop(sprintf("Failed to initialize taxadb provider '%s': %s", provider, e$message))
        }
    )
}

query_taxadb_batch <- function(query_names, provider, db) {
    names_chr <- unique(as.character(query_names))
    names_chr <- names_chr[!is.na(names_chr) & nzchar(names_chr)]

    if (length(names_chr) == 0L) {
        return(data.frame())
    }

    matches <- taxadb::filter_name(names_chr, provider = provider, db = db)
    matches_df <- as.data.frame(matches, stringsAsFactors = FALSE)
    if (nrow(matches_df) == 0L) {
        return(data.frame())
    }

    matches_df$provider <- provider

    if (!"query_name" %in% names(matches_df)) {
        candidate_cols <- c(
            "input",
            "input_name",
            "inputName",
            "query",
            "query_name",
            "search_term",
            "searched_name",
            "matched_name",
            "name"
        )
        matched_col <- candidate_cols[candidate_cols %in% names(matches_df)][1]

        if (!is.na(matched_col) && nzchar(matched_col)) {
            matches_df$query_name <- as.character(matches_df[[matched_col]])
        } else if ("scientificName" %in% names(matches_df)) {
            lookup <- stats::setNames(names_chr, tolower(names_chr))
            lower_sn <- tolower(as.character(matches_df$scientificName))
            mapped <- unname(lookup[lower_sn])
            mapped[is.na(mapped)] <- as.character(matches_df$scientificName)[is.na(mapped)]
            matches_df$query_name <- mapped
        } else {
            matches_df$query_name <- NA_character_
        }
    }

    matches_df
}

empty_validation_stream <- function() {
    data.frame(
        query_name = character(0),
        validation_status = character(0),
        provider = character(0),
        updated_at = as.POSIXct(character(0), tz = "UTC"),
        display_order = integer(0),
        stringsAsFactors = FALSE
    )
}

merge_taxadb_frames <- function(frames) {
    if (length(frames) == 0L) {
        return(data.frame())
    }

    all_cols <- unique(unlist(lapply(frames, names), use.names = FALSE))
    aligned <- lapply(frames, function(df) {
        missing_cols <- setdiff(all_cols, names(df))
        if (length(missing_cols) > 0L) {
            for (col_name in missing_cols) {
                df[[col_name]] <- NA
            }
        }

        df <- df[, all_cols, drop = FALSE]
        rownames(df) <- NULL
        df
    })

    do.call(rbind, aligned)
}

append_stream_items <- function(stream_df, resolved_df, now = Sys.time()) {
    if (is.null(resolved_df) || nrow(resolved_df) == 0L) {
        return(stream_df)
    }

    out <- stream_df
    if (is.null(out) || !is.data.frame(out)) {
        out <- empty_validation_stream()
    }
    if (!"query_name" %in% names(resolved_df)) {
        return(out)
    }

    query_name <- as.character(resolved_df$query_name)
    keep <- !is.na(query_name) & nzchar(query_name)
    if (!any(keep)) {
        return(out)
    }

    status <- if ("validation_status" %in% names(resolved_df)) {
        as.character(resolved_df$validation_status)
    } else {
        rep("not_found", nrow(resolved_df))
    }
    status[is.na(status) | !nzchar(status)] <- "not_found"

    provider <- if ("provider" %in% names(resolved_df)) {
        as.character(resolved_df$provider)
    } else {
        rep("", nrow(resolved_df))
    }
    provider[is.na(provider)] <- ""

    updates <- data.frame(
        query_name = query_name[keep],
        validation_status = status[keep],
        provider = provider[keep],
        stringsAsFactors = FALSE
    )

    # If the same query appears more than once in a batch, keep the latest status.
    updates <- updates[!duplicated(updates$query_name, fromLast = TRUE), , drop = FALSE]

    idx <- match(updates$query_name, out$query_name)
    existing_mask <- !is.na(idx)

    if (any(existing_mask)) {
        existing_idx <- idx[existing_mask]
        out$validation_status[existing_idx] <- updates$validation_status[existing_mask]
        out$provider[existing_idx] <- updates$provider[existing_mask]
        out$updated_at[existing_idx] <- as.POSIXct(now, tz = "UTC")
    }

    new_updates <- updates[!existing_mask, , drop = FALSE]
    if (nrow(new_updates) > 0L) {
        if (nrow(out) == 0L) {
            start_order <- 1L
        } else {
            max_order <- suppressWarnings(max(out$display_order, na.rm = TRUE))
            if (is.infinite(max_order) || is.na(max_order)) {
                max_order <- 0L
            }
            start_order <- as.integer(max_order) + 1L
        }

        new_updates$updated_at <- as.POSIXct(now, tz = "UTC")
        new_updates$display_order <- seq.int(
            from = start_order,
            length.out = nrow(new_updates)
        )

        new_updates <- new_updates[, c("query_name", "validation_status", "provider", "updated_at", "display_order"), drop = FALSE]
        out <- rbind(out, new_updates)
    }

    rownames(out) <- NULL
    out
}

init_taxadb_run_state <- function(
  input_df,
  providers,
  batch_size = 200L,
  run_id = as.numeric(Sys.time()) * 1000
) {
    if (is.null(input_df) || !is.data.frame(input_df)) {
        stop("input_df must be a data.frame.")
    }
    if (!"query_name" %in% names(input_df)) {
        stop("input_df must include query_name.")
    }

    provider_ids <- clean_provider_ids(providers)
    if (length(provider_ids) == 0L) {
        stop("providers must include at least one provider.")
    }

    valid_queries <- unique(as.character(input_df$query_name))
    valid_queries <- valid_queries[!is.na(valid_queries) & nzchar(valid_queries)]
    batches <- split_query_batches(valid_queries, batch_size = batch_size)

    list(
        run_id = as.numeric(run_id),
        phase = "prepare",
        completed = FALSE,
        aborted = FALSE,
        providers = provider_ids,
        provider_idx = 0L,
        current_provider = "",
        current_provider_db = NULL,
        current_batches = batches,
        provider_batch_idx = 0L,
        provider_batch_total = length(batches),
        pending_queries = valid_queries,
        total_unique = length(valid_queries),
        resolved_unique = 0L,
        batch_size = suppressWarnings(as.integer(batch_size)),
        input_df = input_df,
        resolved_frames = list(),
        cascade_results = data.frame(),
        provider_attempted = character(0),
        provider_failures = data.frame(
            provider = character(0),
            error = character(0),
            stringsAsFactors = FALSE
        ),
        stream_df = empty_validation_stream(),
        error_message = NA_character_
    )
}

is_taxadb_run_done <- function(state) {
    isTRUE(state$completed) || identical(state$phase, "done") || identical(state$phase, "failed")
}

next_taxadb_run_step <- function(state) {
    if (is_taxadb_run_done(state)) {
        return(state)
    }

    if (isTRUE(state$aborted) && !identical(state$phase, "consolidate")) {
        state$phase <- "consolidate"
    }

    if (identical(state$phase, "prepare")) {
        if (state$total_unique == 0L || length(state$pending_queries) == 0L) {
            state$phase <- "consolidate"
        } else {
            state$phase <- "provider_init"
        }
        return(state)
    }

    if (identical(state$phase, "provider_init")) {
        if (length(state$pending_queries) == 0L) {
            state$phase <- "consolidate"
            return(state)
        }

        next_idx <- as.integer(state$provider_idx) + 1L
        if (next_idx > length(state$providers)) {
            state$phase <- "consolidate"
            return(state)
        }

        provider <- state$providers[[next_idx]]
        state$provider_idx <- next_idx
        state$current_provider <- provider
        state$provider_attempted <- unique(c(state$provider_attempted, provider))
        state$provider_batch_idx <- 0L

        state$current_batches <- split_query_batches(
            state$pending_queries,
            batch_size = state$batch_size
        )
        state$provider_batch_total <- length(state$current_batches)

        db <- NULL
        provider_error <- NULL
        tryCatch(
            {
                db <- init_taxadb_provider(provider)
            },
            error = function(e) {
                provider_error <<- as.character(e$message)
            }
        )

        if (!is.null(provider_error)) {
            state$provider_failures <- rbind(
                state$provider_failures,
                data.frame(
                    provider = provider,
                    error = provider_error,
                    stringsAsFactors = FALSE
                )
            )
        }

        if (is.null(db)) {
            state$current_provider_db <- NULL
            state$phase <- "provider_finalize"
            return(state)
        }

        state$current_provider_db <- db
        if (state$provider_batch_total == 0L) {
            state$phase <- "provider_finalize"
        } else {
            state$phase <- "provider_query_batch"
        }
        return(state)
    }

    if (identical(state$phase, "provider_query_batch")) {
        if (is.null(state$current_provider_db)) {
            state$phase <- "provider_finalize"
            return(state)
        }

        next_batch <- as.integer(state$provider_batch_idx) + 1L
        if (next_batch > state$provider_batch_total) {
            state$phase <- "provider_finalize"
            return(state)
        }

        state$provider_batch_idx <- next_batch
        batch_queries <- state$current_batches[[next_batch]]

        matches <- NULL
        batch_error <- NULL
        tryCatch(
            {
                matches <- query_taxadb_batch(
                    query_names = batch_queries,
                    provider = state$current_provider,
                    db = state$current_provider_db
                )
            },
            error = function(e) {
                batch_error <<- as.character(e$message)
            }
        )

        if (!is.null(batch_error)) {
            state$provider_failures <- rbind(
                state$provider_failures,
                data.frame(
                    provider = state$current_provider,
                    error = batch_error,
                    stringsAsFactors = FALSE
                )
            )
        }

        if (is.null(matches)) {
            state$phase <- "provider_finalize"
            return(state)
        }

        if (nrow(matches) > 0L) {
            resolved <- resolve_taxadb_matches(matches)
            if (nrow(resolved) > 0L) {
                state$resolved_frames[[length(state$resolved_frames) + 1L]] <- resolved
                resolved_names <- unique(as.character(resolved$query_name))
                state$pending_queries <- setdiff(state$pending_queries, resolved_names)
                state$resolved_unique <- state$total_unique - length(state$pending_queries)
                state$stream_df <- append_stream_items(state$stream_df, resolved, now = Sys.time())
            }
        }

        if (state$provider_batch_idx >= state$provider_batch_total) {
            state$phase <- "provider_finalize"
        }
        return(state)
    }

    if (identical(state$phase, "provider_finalize")) {
        state$current_provider_db <- NULL
        if (length(state$pending_queries) == 0L) {
            state$phase <- "consolidate"
            return(state)
        }

        if (state$provider_idx >= length(state$providers)) {
            state$phase <- "consolidate"
            return(state)
        }

        state$phase <- "provider_init"
        return(state)
    }

    if (identical(state$phase, "consolidate")) {
        if (length(state$pending_queries) > 0L) {
            placeholders <- build_taxadb_placeholder(state$pending_queries, status = "not_found")
            state$resolved_frames[[length(state$resolved_frames) + 1L]] <- placeholders
            state$stream_df <- append_stream_items(state$stream_df, placeholders, now = Sys.time())
            state$pending_queries <- character(0)
            state$resolved_unique <- state$total_unique
        }

        combined <- merge_taxadb_frames(state$resolved_frames)
        state$cascade_results <- combined
        state$phase <- "done"
        state$completed <- TRUE
        return(state)
    }

    state$error_message <- "Unknown taxadb run phase."
    state$phase <- "failed"
    state$completed <- TRUE
    state
}

finalize_taxadb_run <- function(state) {
    if (is.null(state$input_df) || !is.data.frame(state$input_df)) {
        stop("state must include input_df.")
    }

    cascade_results <- state$cascade_results
    if (is.null(cascade_results)) {
        cascade_results <- data.frame()
    }

    report <- build_validation_report(state$input_df, cascade_results)

    list(
        report = report,
        meta = list(
            provider_attempted = unique(as.character(state$provider_attempted)),
            provider_failures = state$provider_failures,
            aborted = isTRUE(state$aborted)
        ),
        stream_df = state$stream_df
    )
}

build_validation_report <- function(input_df, cascade_results) {
    if (is.null(input_df) || nrow(input_df) == 0L) {
        return(data.frame())
    }

    if (!"query_name" %in% names(input_df)) {
        stop("input_df must include query_name.")
    }

    if (is.null(cascade_results) || nrow(cascade_results) == 0L) {
        cascade_results <- data.frame(query_name = character(0), stringsAsFactors = FALSE)
    }

    merged <- merge(
        input_df,
        cascade_results,
        by = "query_name",
        all.x = TRUE,
        sort = FALSE
    )

    if ("row_id" %in% names(merged)) {
        merged <- merged[order(merged$row_id), , drop = FALSE]
    }

    if (!"validation_status" %in% names(merged)) {
        merged$validation_status <- NA_character_
    }

    missing_status <- is.na(merged$validation_status) | !nzchar(merged$validation_status)
    missing_status[is.na(missing_status)] <- TRUE

    if ("taxonomicStatus" %in% names(merged)) {
        fallback_idx <- missing_status & !is.na(merged$taxonomicStatus) & nzchar(merged$taxonomicStatus)
        if (any(fallback_idx)) {
            merged$validation_status[fallback_idx] <- vapply(
                merged$taxonomicStatus[fallback_idx],
                normalize_taxonomic_status,
                FUN.VALUE = character(1)
            )
            missing_status <- is.na(merged$validation_status) | !nzchar(merged$validation_status)
            missing_status[is.na(missing_status)] <- TRUE
        }
    }

    if ("skip_reason" %in% names(merged)) {
        blank_idx <- merged$skip_reason == "blank"
        ignored_idx <- !is.na(merged$skip_reason) & merged$skip_reason != "blank"
        merged$validation_status[blank_idx] <- "invalid"
        merged$validation_status[ignored_idx] <- "ignored"
        missing_status <- missing_status & is.na(merged$validation_status)
    }

    merged$validation_status[missing_status] <- "not_found"

    if (!"match_count" %in% names(merged)) {
        merged$match_count <- 0L
    }

    missing_name <- is.na(merged$scientificName) | !nzchar(merged$scientificName)
    if ("input_name" %in% names(merged)) {
        fallback_name <- ifelse(
            !is.na(merged$query_name) & nzchar(merged$query_name),
            merged$query_name,
            merged$input_name
        )
    } else {
        fallback_name <- merged$query_name
    }
    merged$scientificName[missing_name] <- fallback_name[missing_name]

    if (!"provider" %in% names(merged)) {
        merged$provider <- NA_character_
    }
    merged$nameAccordingTo <- ifelse(
        is.na(merged$provider) | !nzchar(merged$provider),
        NA_character_,
        toupper(as.character(merged$provider))
    )

    merged <- ensure_taxadb_columns(merged)

    report_cols <- c(
        "scientificName",
        "taxonomicStatus",
        "acceptedNameUsageID",
        "taxonID",
        "taxonRank",
        "kingdom",
        "phylum",
        "class",
        "order",
        "family",
        "genus",
        "specificEpithet",
        "infraspecificEpithet",
        "vernacularName",
        "nameAccordingTo",
        "validation_status",
        "match_count"
    )

    report_cols <- report_cols[report_cols %in% names(merged)]
    merged[, report_cols, drop = FALSE]
}
