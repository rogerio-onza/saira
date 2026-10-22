# Title: Rostrum Template Utilities
# Author: Rogerio Nunes Oliveira
# Date: 2026-03-02
# Version: 1.0

rostrum_app_version <- function() {
    as.character(utils::packageVersion("saira"))
}

#' Magic header for the export bundle's mapping_guide.txt (ADR-087)
#'
#' Used to discriminate Saira mapping-guide uploads from regular data CSVs.
#' Must match exactly (modulo trailing whitespace) on line 1 of the file.
#' @keywords internal
#' @noRd
SAIRA_MAPPING_GUIDE_MAGIC_V1 <- "# saira:mapping:v1"

#' Magic header for the v2 mapping guide (PR-A3)
#'
#' v2 groups mappings by DwC class, adds a dedicated constants section
#' (\code{= value -> term}) and a coverage legend. The parser reads both v1
#' and v2; v1 files remain importable.
#' @keywords internal
#' @noRd
SAIRA_MAPPING_GUIDE_MAGIC_V2 <- "# saira:mapping:v2"

#' Detect whether a file looks like a Saira mapping guide
#'
#' Reads only the first non-empty line; safe for large CSVs (no full read).
#'
#' @param path Character path to the candidate file.
#' @return TRUE when line 1 matches the v1 or v2 magic header. FALSE otherwise
#'   (including when the file is unreadable).
#' @export
is_saira_mapping_guide <- function(path) {
    if (length(path) != 1L || is.na(path) || !nzchar(path) || !file.exists(path)) {
        return(FALSE)
    }
    first <- tryCatch(
        readLines(path, n = 1L, encoding = "UTF-8", warn = FALSE),
        error = function(e) character(0)
    )
    if (length(first) == 0L) return(FALSE)
    magic_re <- "^\\s*# saira:mapping:v[12]\\s*$"
    grepl(magic_re, first[[1]], perl = TRUE)
}

#' Parse a Saira mapping_guide.txt into metadata + (source -> term) pairs
#'
#' Companion to \code{build_mapping_guide_txt()}. Format expected:
#' line 1 = magic header (\code{# saira:mapping:v1}); subsequent comment
#' lines starting with \code{#} carry metadata (key: value); body lines
#' matching the regex \code{^([^\\s][^\\->]*?)\\s*->\\s*(\\S.*)$} are
#' (source_column, dwc_term) pairs. Lines that don't match are ignored
#' with a warning.
#'
#' @param path Character path to the .txt file.
#' @return Named list:
#'   \itemize{
#'     \item \code{meta}: named list of metadata strings (created_at, source_file, ...).
#'     \item \code{pairs}: data.frame with columns \code{source_column},
#'       \code{dwc_term}, \code{kind} ("column" or "constant"), and
#'       \code{constant_value}. For column mappings \code{source_column} holds
#'       the raw source (\code{"a + b"} for concatenations) and
#'       \code{constant_value} is \code{NA}; for constants the reverse holds.
#'   }
#' @export
parse_mapping_guide_txt <- function(path) {
    if (!is_saira_mapping_guide(path)) {
        stop(
            "parse_mapping_guide_txt: file does not start with the magic ",
            "header '", SAIRA_MAPPING_GUIDE_MAGIC_V1, "' or '",
            SAIRA_MAPPING_GUIDE_MAGIC_V2, "'."
        )
    }

    lines <- readLines(path, encoding = "UTF-8", warn = FALSE)

    meta <- list()
    pairs_src <- character(0)
    pairs_term <- character(0)
    pairs_kind <- character(0)
    pairs_const <- character(0)
    invalid_lines <- 0L

    meta_re <- "^#\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*:\\s*(.*?)\\s*$"
    # Term is the trailing camelCase token; source is everything before the
    # final '->' (so column names may contain '-', '+', or '=' constants).
    body_re <- "^(.*?)\\s*->\\s*([A-Za-z][A-Za-z0-9_]*)\\s*$"

    # Skip line 1 (the magic header itself).
    if (length(lines) >= 2L) {
        for (line in lines[-1L]) {
            if (!nzchar(trimws(line))) next

            if (startsWith(trimws(line), "#")) {
                m <- regmatches(line, regexec(meta_re, line, perl = TRUE))[[1]]
                if (length(m) == 3L && nzchar(m[2L])) {
                    meta[[m[2L]]] <- m[3L]
                }
                next
            }

            # Bare lines without '->' are informational (e.g., the unmapped
            # columns list at the tail of build_mapping_guide_txt). Skip
            # silently. Warn only on lines that LOOK like mappings (contain
            # '->') but fail the strict regex.
            if (!grepl("->", line, fixed = TRUE)) next

            m <- regmatches(line, regexec(body_re, line, perl = TRUE))[[1]]
            if (length(m) == 3L && nzchar(trimws(m[2L])) && nzchar(m[3L])) {
                src <- trimws(m[2L])
                if (startsWith(src, "=")) {
                    # Constant: `= value -> term` (value may be double-quoted).
                    val <- trimws(sub("^=", "", src))
                    if (startsWith(val, "\"") && endsWith(val, "\"") && nchar(val) >= 2L) {
                        val <- substr(val, 2L, nchar(val) - 1L)
                    }
                    pairs_src   <- c(pairs_src, NA_character_)
                    pairs_const <- c(pairs_const, val)
                    pairs_kind  <- c(pairs_kind, "constant")
                } else {
                    pairs_src   <- c(pairs_src, src)
                    pairs_const <- c(pairs_const, NA_character_)
                    pairs_kind  <- c(pairs_kind, "column")
                }
                pairs_term <- c(pairs_term, trimws(m[3L]))
            } else {
                invalid_lines <- invalid_lines + 1L
            }
        }
    }

    if (invalid_lines > 0L) {
        warning(
            "parse_mapping_guide_txt: ignored ", invalid_lines,
            " malformed mapping line(s) (contain '->' but don't match 'source -> term')."
        )
    }

    list(
        meta = meta,
        pairs = data.frame(
            source_column  = pairs_src,
            dwc_term       = pairs_term,
            kind           = pairs_kind,
            constant_value = pairs_const,
            stringsAsFactors = FALSE
        )
    )
}

#' Import a parsed mapping guide into rostrum_aliases
#'
#' For each pair in \code{payload$pairs}, calls \code{rostrum_upsert_alias()}
#' with \code{scope = "personal"}, \code{confidence = 1.0}, \code{reviewed = TRUE}.
#' Re-importing the same guide updates rows in place (no duplicates) thanks
#' to the SELECT-then-INSERT/UPDATE logic of \code{rostrum_upsert_alias()}.
#'
#' Multi-column source entries (e.g., produced by \code{build_mapping_guide_txt()}
#' as \code{"colA + colB -> term"}) are split on \code{" + "} and inserted as
#' independent aliases, one per source column.
#'
#' @param payload Output of \code{parse_mapping_guide_txt()}.
#' @param conn Optional open DBI connection. When NULL (default), a new
#'   connection is opened via \code{rostrum_connect()} and closed on exit.
#' @param scope Character, default "personal".
#' @param user_id Character, default \code{Sys.getenv("SAIRA_USER", unset = "anonymous")}.
#' @param available_columns Optional column names of the loaded data. A source
#'   that is one of them stays whole, so \code{"lat + gps"} is one alias.
#'   If NULL, the function uses the headers that the guide records (ADR-171).
#' @return Invisibly: integer count of (source, term) pairs upserted.
#' @export
import_mapping_guide_to_aliases <- function(
    payload,
    conn = NULL,
    scope = "personal",
    user_id = NULL,
    available_columns = NULL
) {
    if (!is.list(payload) || is.null(payload$pairs) || !is.data.frame(payload$pairs)) {
        stop("import_mapping_guide_to_aliases: 'payload' must come from parse_mapping_guide_txt().")
    }
    pairs <- payload$pairs
    if (nrow(pairs) == 0L) return(invisible(0L))

    if (is.null(available_columns) && !is.null(payload$meta$source_columns)) {
        columns <- tryCatch(jsonlite::fromJSON(payload$meta$source_columns), error = function(e) NULL)
        if (is.character(columns)) available_columns <- columns
    }

    if (is.null(user_id) || !nzchar(user_id)) {
        user_id <- Sys.getenv("SAIRA_USER", unset = "anonymous")
        if (!nzchar(user_id)) user_id <- "anonymous"
    }

    own_conn <- is.null(conn)
    if (own_conn) {
        conn <- rostrum_connect()
        on.exit(try(DBI::dbDisconnect(conn), silent = TRUE), add = TRUE)
    }

    n <- 0L
    for (i in seq_len(nrow(pairs))) {
        # Constants (`= value -> term`) carry no source column; they are not
        # aliases and are restored separately by the mapping module.
        if (!is.null(pairs$kind) && identical(pairs$kind[[i]], "constant")) next
        src_raw <- pairs$source_column[[i]]
        if (is.na(src_raw)) next
        term    <- pairs$dwc_term[[i]]
        # Split multi-column composites ("colA + colB") into independent aliases.
        sources <- guide_source_columns(src_raw, available_columns)
        for (src in sources) {
            tryCatch(
                {
                    rostrum_upsert_alias(
                        conn      = conn,
                        col_name  = src,
                        dwc_term  = term,
                        confidence = 1.0,
                        scope     = scope,
                        reviewed  = TRUE,
                        user_id   = user_id,
                        action    = "alias_imported_from_guide"
                    )
                    n <- n + 1L
                },
                error = function(e) {
                    warning(
                        "import_mapping_guide_to_aliases: skipping ('",
                        src, "' -> '", term, "'): ", conditionMessage(e)
                    )
                }
            )
        }
    }
    invisible(n)
}

rostrum_export_template_payload <- function(
    map_values,
    map_meta = list(),
    template_id,
    name,
    scope = "personal",
    schema_version = "1.0.0",
    owner_id = Sys.getenv("SAIRA_USER", unset = ""),
    institution_id = Sys.getenv("SAIRA_INSTITUTION", unset = ""),
    app_min_version = rostrum_app_version(),
    app_max_version = NA_character_,
    description = NA_character_,
    use_case = NA_character_
) {
    if (!is.list(map_values)) {
        stop("map_values must be a named list of mapping selections.")
    }

    terms <- names(map_values)
    if (is.null(terms) || length(terms) == 0L) {
        stop("map_values must include named term entries.")
    }

    normalize_selected <- function(value) {
        selected <- trimws(as.character(unlist(value, recursive = TRUE, use.names = FALSE)))
        selected <- selected[!is.na(selected) & nzchar(selected)]
        unique(selected)
    }

    items <- list()
    for (term in terms) {
        cols <- normalize_selected(map_values[[term]])
        if (length(cols) == 0L) {
            next
        }

        meta <- map_meta[[term]]
        score <- suppressWarnings(as.numeric(meta$score))
        if (length(score) != 1L || is.na(score)) {
            score <- 0
        }
        priority <- as.integer(round(score * 100))

        items[[length(items) + 1L]] <- list(
            dwc_term = as.character(term),
            source_columns = cols,
            transform_kind = if (length(cols) > 1L) "concat" else NA_character_,
            transform_params = list(),
            priority = priority,
            required = FALSE
        )
    }

    if (length(items) == 0L) {
        stop("Cannot export template: no mapped terms found in map_values.")
    }

    payload <- list(
        template_id = template_id,
        name = name,
        scope = scope,
        owner_id = owner_id,
        institution_id = institution_id,
        schema_version = schema_version,
        app_min_version = app_min_version,
        app_max_version = app_max_version,
        is_active = TRUE,
        description = description,
        use_case = use_case,
        items = items
    )

    rostrum_validate_template_payload(payload)
}

rostrum_save_template <- function(conn, payload, replace = TRUE, current_version = rostrum_app_version()) {
    if (is.null(conn) || !DBI::dbIsValid(conn)) {
        stop("conn must be a valid DBI connection.")
    }

    normalized <- rostrum_validate_template_payload(
        payload = payload,
        current_version = current_version
    )
    now_utc <- rostrum_now_utc()
    has_use_case <- rostrum_template_has_column(conn, "rostrum_templates", "use_case")

    DBI::dbExecute(conn, "BEGIN IMMEDIATE")
    committed <- FALSE
    on.exit(
        {
            if (!committed) {
                try(DBI::dbExecute(conn, "ROLLBACK"), silent = TRUE)
            }
        },
        add = TRUE
    )

    tryCatch(
        {
            existing <- DBI::dbGetQuery(
                conn,
                "SELECT template_id, created_at FROM rostrum_templates WHERE template_id = ?",
                params = list(normalized$template_id)
            )
            if (nrow(existing) > 0L && !isTRUE(replace)) {
                stop("Template already exists and replace=FALSE: ", normalized$template_id)
            }

            if (nrow(existing) > 0L) {
                DBI::dbExecute(
                    conn,
                    "DELETE FROM rostrum_template_items WHERE template_id = ?",
                    params = list(normalized$template_id)
                )
                DBI::dbExecute(
                    conn,
                    "DELETE FROM rostrum_templates WHERE template_id = ?",
                    params = list(normalized$template_id)
                )
            }

            created_at <- if (nrow(existing) > 0L) {
                as.character(existing$created_at[[1]])
            } else {
                now_utc
            }

            if (isTRUE(has_use_case)) {
                DBI::dbExecute(
                    conn,
                    paste(
                        "INSERT INTO rostrum_templates",
                        "(template_id, name, scope, owner_id, institution_id, schema_version,",
                        " app_min_version, app_max_version, is_active, description, use_case, created_at, updated_at)",
                        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                    ),
                    params = list(
                        normalized$template_id,
                        normalized$name,
                        normalized$scope,
                        normalized$owner_id,
                        normalized$institution_id,
                        normalized$schema_version,
                        normalized$app_min_version,
                        normalized$app_max_version,
                        as.integer(isTRUE(normalized$is_active)),
                        normalized$description,
                        normalized$use_case,
                        created_at,
                        now_utc
                    )
                )
            } else {
                DBI::dbExecute(
                    conn,
                    paste(
                        "INSERT INTO rostrum_templates",
                        "(template_id, name, scope, owner_id, institution_id, schema_version,",
                        " app_min_version, app_max_version, is_active, description, created_at, updated_at)",
                        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                    ),
                    params = list(
                        normalized$template_id,
                        normalized$name,
                        normalized$scope,
                        normalized$owner_id,
                        normalized$institution_id,
                        normalized$schema_version,
                        normalized$app_min_version,
                        normalized$app_max_version,
                        as.integer(isTRUE(normalized$is_active)),
                        normalized$description,
                        created_at,
                        now_utc
                    )
                )
            }

            for (item in normalized$items) {
                DBI::dbExecute(
                    conn,
                    paste(
                        "INSERT INTO rostrum_template_items",
                        "(template_id, dwc_term, source_columns_json, transform_kind, transform_params_json, priority, required)",
                        "VALUES (?, ?, ?, ?, ?, ?, ?)"
                    ),
                    params = list(
                        normalized$template_id,
                        item$dwc_term,
                        as.character(jsonlite::toJSON(item$source_columns, auto_unbox = TRUE)),
                        item$transform_kind,
                        as.character(jsonlite::toJSON(item$transform_params, auto_unbox = TRUE, null = "null")),
                        as.integer(item$priority),
                        as.integer(isTRUE(item$required))
                    )
                )
            }

            DBI::dbExecute(conn, "COMMIT")
            committed <- TRUE
            invisible(normalized)
        },
        error = function(e) {
            stop("Failed to save template: ", e$message, call. = FALSE)
        }
    )
}

rostrum_get_template <- function(
    conn,
    template_id,
    include_inactive = FALSE,
    current_version = rostrum_app_version()
) {
    if (is.null(conn) || !DBI::dbIsValid(conn)) {
        stop("conn must be a valid DBI connection.")
    }

    template_id_chr <- rostrum_template_trim_scalar(template_id, "template_id", required = TRUE)
    has_use_case <- rostrum_template_has_column(conn, "rostrum_templates", "use_case")

    select_sql <- if (isTRUE(has_use_case)) {
        paste(
            "SELECT template_id, name, scope, owner_id, institution_id, schema_version,",
            "       app_min_version, app_max_version, is_active, description, use_case, created_at, updated_at",
            "FROM rostrum_templates WHERE template_id = ?"
        )
    } else {
        paste(
            "SELECT template_id, name, scope, owner_id, institution_id, schema_version,",
            "       app_min_version, app_max_version, is_active, description,",
            "       created_at, updated_at",
            "FROM rostrum_templates WHERE template_id = ?"
        )
    }

    template_df <- DBI::dbGetQuery(conn, select_sql, params = list(template_id_chr))
    if (nrow(template_df) == 0L) {
        return(NULL)
    }
    if (!isTRUE(include_inactive) && as.integer(template_df$is_active[[1]]) != 1L) {
        return(NULL)
    }

    items_df <- DBI::dbGetQuery(
        conn,
        paste(
            "SELECT dwc_term, source_columns_json, transform_kind, transform_params_json, priority, required",
            "FROM rostrum_template_items",
            "WHERE template_id = ?",
            "ORDER BY priority DESC, dwc_term ASC"
        ),
        params = list(template_id_chr)
    )
    if (nrow(items_df) == 0L) {
        return(NULL)
    }

    items <- lapply(seq_len(nrow(items_df)), function(i) {
        source_columns <- tryCatch(
            jsonlite::fromJSON(as.character(items_df$source_columns_json[[i]])),
            error = function(e) character(0)
        )
        source_columns <- as.character(source_columns)

        transform_params <- tryCatch(
            jsonlite::fromJSON(as.character(items_df$transform_params_json[[i]]), simplifyVector = FALSE),
            error = function(e) list()
        )
        if (!is.list(transform_params)) {
            transform_params <- list()
        }

        list(
            dwc_term = as.character(items_df$dwc_term[[i]]),
            source_columns = source_columns,
            transform_kind = rostrum_template_trim_scalar(
                items_df$transform_kind[[i]],
                field_name = "transform_kind",
                required = FALSE
            ),
            transform_params = transform_params,
            priority = suppressWarnings(as.integer(items_df$priority[[i]])),
            required = as.integer(items_df$required[[i]]) > 0L
        )
    })

    payload <- list(
        template_id = as.character(template_df$template_id[[1]]),
        name = as.character(template_df$name[[1]]),
        scope = as.character(template_df$scope[[1]]),
        owner_id = rostrum_template_trim_scalar(template_df$owner_id[[1]], "owner_id", required = FALSE),
        institution_id = rostrum_template_trim_scalar(template_df$institution_id[[1]], "institution_id", required = FALSE),
        schema_version = as.character(template_df$schema_version[[1]]),
        app_min_version = rostrum_template_trim_scalar(template_df$app_min_version[[1]], "app_min_version", required = FALSE),
        app_max_version = rostrum_template_trim_scalar(template_df$app_max_version[[1]], "app_max_version", required = FALSE),
        is_active = as.integer(template_df$is_active[[1]]) > 0L,
        description = rostrum_template_trim_scalar(template_df$description[[1]], "description", required = FALSE),
        use_case = if (isTRUE(has_use_case)) {
            rostrum_template_trim_scalar(template_df$use_case[[1]], "use_case", required = FALSE)
        } else {
            NA_character_
        },
        items = items
    )

    rostrum_validate_template_payload(payload, current_version = current_version)
}

#' List the Rostrum Template Catalog
#'
#' Returns a data frame of template metadata from the SQLite database,
#' optionally filtered by scope, institution, use-case, or active status.
#'
#' @param conn A DBI connection from \code{rostrum_connect()}.
#' @param scope Optional character. Filter by scope level.
#' @param institution_id Optional character. Filter by institution.
#' @param use_case Optional character. Filter by use-case tag.
#' @param include_inactive Logical. Include inactive templates (default FALSE).
#' @return A data frame of template metadata rows.
#' @export
rostrum_list_template_catalog <- function(
    conn,
    scope = NULL,
    institution_id = NULL,
    use_case = NULL,
    include_inactive = FALSE
) {
    if (is.null(conn) || !DBI::dbIsValid(conn)) {
        stop("conn must be a valid DBI connection.")
    }

    has_use_case <- rostrum_template_has_column(conn, "rostrum_templates", "use_case")
    select_sql <- if (isTRUE(has_use_case)) {
        paste(
            "SELECT template_id, name, scope, owner_id, institution_id, schema_version,",
            "       app_min_version, app_max_version, is_active, description, use_case, created_at, updated_at",
            "FROM rostrum_templates"
        )
    } else {
        paste(
            "SELECT template_id, name, scope, owner_id, institution_id, schema_version,",
            "       app_min_version, app_max_version, is_active, description, created_at, updated_at",
            "FROM rostrum_templates"
        )
    }

    where_parts <- character(0)
    params <- list()

    if (!is.null(scope) && nzchar(trimws(as.character(scope)))) {
        where_parts <- c(where_parts, "scope = ?")
        params <- c(params, list(rostrum_validate_scope(scope)))
    }

    if (!is.null(institution_id) && nzchar(trimws(as.character(institution_id)))) {
        where_parts <- c(where_parts, "institution_id = ?")
        params <- c(params, list(trimws(as.character(institution_id))))
    }

    if (!isTRUE(include_inactive)) {
        where_parts <- c(where_parts, "is_active = 1")
    }

    if (isTRUE(has_use_case) && !is.null(use_case) && nzchar(trimws(as.character(use_case)))) {
        where_parts <- c(where_parts, "use_case = ?")
        params <- c(params, list(trimws(as.character(use_case))))
    }

    query <- select_sql
    if (length(where_parts) > 0L) {
        query <- paste(query, "WHERE", paste(where_parts, collapse = " AND "))
    }
    query <- paste(query, "ORDER BY updated_at DESC, name ASC")

    DBI::dbGetQuery(conn, query, params = params)
}

#' Import a Template from JSON
#'
#' Parses and validates a JSON template payload, then persists it to the
#' SQLite template catalog.
#'
#' @param conn A DBI connection from \code{rostrum_connect()}.
#' @param json_payload Character. JSON string produced by \code{rostrum_export_template_json()}.
#' @param replace Logical. Replace existing template with same ID (default TRUE).
#' @param current_version Character. App version for compatibility check.
#' @return Invisibly, the template ID string.
#' @export
rostrum_import_template_json <- function(
    conn,
    json_payload,
    replace = TRUE,
    current_version = rostrum_app_version()
) {
    payload <- rostrum_template_from_json(
        json_payload = json_payload,
        current_version = current_version
    )
    rostrum_save_template(conn = conn, payload = payload, replace = replace, current_version = current_version)
}

#' Export a Mapping Template to JSON
#'
#' Serialises a column mapping (map_values + map_meta) as a versioned JSON
#' template suitable for storage, sharing, or import via
#' \code{rostrum_import_template_json()}.
#'
#' @param map_values Named list or character vector of column mappings.
#' @param map_meta List of mapping metadata (status, scores, etc.).
#' @param template_id Character. Unique template identifier.
#' @param name Character. Human-readable template name.
#' @param scope Character. Scope: \code{"personal"}, \code{"institution"}, or \code{"public"}.
#' @param schema_version Character. Schema version string (default \code{"1.0.0"}).
#' @param owner_id Character. Owner user ID.
#' @param institution_id Character. Institution identifier.
#' @param app_min_version Character. Minimum compatible app version.
#' @param app_max_version Character. Maximum compatible app version (NA = no upper bound).
#' @param description Character. Optional free-text description.
#' @param use_case Character. Optional use-case tag.
#' @param pretty Logical. Pretty-print JSON output (default TRUE).
#' @return A JSON character string.
#' @export
rostrum_export_template_json <- function(
    map_values,
    map_meta = list(),
    template_id,
    name,
    scope = "personal",
    schema_version = "1.0.0",
    owner_id = Sys.getenv("SAIRA_USER", unset = ""),
    institution_id = Sys.getenv("SAIRA_INSTITUTION", unset = ""),
    app_min_version = rostrum_app_version(),
    app_max_version = NA_character_,
    description = NA_character_,
    use_case = NA_character_,
    pretty = TRUE
) {
    payload <- rostrum_export_template_payload(
        map_values = map_values,
        map_meta = map_meta,
        template_id = template_id,
        name = name,
        scope = scope,
        schema_version = schema_version,
        owner_id = owner_id,
        institution_id = institution_id,
        app_min_version = app_min_version,
        app_max_version = app_max_version,
        description = description,
        use_case = use_case
    )

    rostrum_template_to_json(payload, pretty = pretty)
}

rostrum_resolve_template_payload <- function(conn = NULL, context = list(), current_version = rostrum_app_version()) {
    if (is.list(context) && !is.null(context$template_payload)) {
        return(rostrum_validate_template_payload(
            payload = context$template_payload,
            current_version = current_version
        ))
    }

    template_id <- NA_character_
    if (is.list(context) && !is.null(context$template_id)) {
        template_id <- rostrum_template_trim_scalar(context$template_id, "template_id", required = FALSE)
    }
    if (is.na(template_id)) {
        return(NULL)
    }
    if (is.null(conn) || !DBI::dbIsValid(conn)) {
        stop("Template id provided in context, but conn is missing or invalid.")
    }

    rostrum_get_template(
        conn = conn,
        template_id = template_id,
        include_inactive = FALSE,
        current_version = current_version
    )
}

rostrum_template_pick_column <- function(source_columns, df = NULL) {
    source_chr <- trimws(as.character(source_columns))
    source_chr <- source_chr[!is.na(source_chr) & nzchar(source_chr)]
    if (length(source_chr) == 0L) {
        return(NA_character_)
    }

    if (is.null(df) || !is.data.frame(df)) {
        return(source_chr[[1]])
    }

    available <- source_chr[source_chr %in% names(df)]
    if (length(available) == 0L) {
        return(NA_character_)
    }

    available[[1]]
}

rostrum_apply_template_to_decisions <- function(decision_df, template_payload, df = NULL) {
    if (!is.data.frame(decision_df)) {
        stop("decision_df must be a data.frame.")
    }

    normalized <- rostrum_validate_template_payload(template_payload)
    data <- rostrum_ensure_engine_columns(decision_df)
    warnings <- character(0)
    applied_n <- 0L
    conflict_n <- 0L

    for (item in normalized$items) {
        idx <- rostrum_term_index(data, item$dwc_term)
        if (is.na(idx)) {
            warnings <- c(
                warnings,
                paste0(
                    "Template item for term '", item$dwc_term,
                    "' ignored because term is not present in decision_df."
                )
            )
            next
        }

        selected_col <- rostrum_template_pick_column(item$source_columns, df = df)
        if (is.na(selected_col) || !nzchar(selected_col)) {
            warnings <- c(
                warnings,
                paste0(
                    "Template item for term '", item$dwc_term,
                    "' has no source column available in current dataset."
                )
            )
            next
        }

        existing_col <- rostrum_selected_column(data, item$dwc_term)
        if (!is.na(existing_col) && nzchar(existing_col) && !identical(existing_col, selected_col)) {
            conflict_n <- conflict_n + 1L
            warnings <- c(
                warnings,
                paste0(
                    "Template priority override for term '", item$dwc_term,
                    "': '", existing_col, "' replaced by '", selected_col, "'."
                )
            )
        }

        data$selected_col[[idx]] <- selected_col
        data$name_score[[idx]] <- 1
        data$value_score[[idx]] <- 1
        data$penalty_score[[idx]] <- 0
        data$veto_code[[idx]] <- ""
        data$final_score[[idx]] <- 1
        data$status[[idx]] <- "TEMPLATE"
        data$reason[[idx]] <- "template_priority_override"
        data$applied[[idx]] <- TRUE
        data$alternatives_json[[idx]] <- as.character(jsonlite::toJSON(
            list(list(
                source = "template",
                template_id = normalized$template_id,
                selected_col = selected_col,
                candidate_columns = item$source_columns,
                priority = as.integer(item$priority)
            )),
            auto_unbox = TRUE,
            null = "null"
        ))
        data$explain_json[[idx]] <- rostrum_update_explain_json(
            data$explain_json[[idx]],
            patch = list(template = list(
                template_id = normalized$template_id,
                template_name = normalized$name,
                selected_col = selected_col,
                source_columns = item$source_columns,
                priority = as.integer(item$priority),
                use_case = normalized$use_case
            ))
        )

        applied_n <- applied_n + 1L
    }

    list(
        data = data,
        warnings = unique(warnings),
        applied_n = as.integer(applied_n),
        conflict_n = as.integer(conflict_n),
        template_id = normalized$template_id
    )
}

rostrum_apply_template_overrides <- function(
    stage_data,
    df = NULL,
    conn = NULL,
    context = list(),
    current_version = rostrum_app_version()
) {
    payload <- rostrum_resolve_template_payload(
        conn = conn,
        context = context,
        current_version = current_version
    )
    if (is.null(payload)) {
        return(list(
            data = stage_data,
            warnings = character(0),
            applied_n = 0L,
            conflict_n = 0L,
            template_id = NA_character_
        ))
    }

    rostrum_apply_template_to_decisions(
        decision_df = stage_data,
        template_payload = payload,
        df = df
    )
}

#' Find extra DwC terms a template needs that are not yet active
#'
#' Used before running the engine or applying a template to pre-activate
#' any terms that exist in the full catalog but not in the current active set.
#' Terms not in the full catalog at all are returned in \code{$unknown}.
#'
#' @param template_payload Validated template payload list (from
#'   \code{rostrum_validate_template_payload()})
#' @param active_terms Character vector of currently active term names
#' @return Named list with \code{$to_activate} (character, safe to add to
#'   \code{rv$extra_terms}) and \code{$unknown} (character, terms not in
#'   the full catalog)
#' @export
rostrum_extra_terms_from_template <- function(template_payload, active_terms) {
    if (!is.list(template_payload) || is.null(template_payload$items)) {
        return(list(to_activate = character(0), unknown = character(0)))
    }

    template_terms <- vapply(
        template_payload$items,
        function(x) as.character(x$dwc_term),
        FUN.VALUE = character(1)
    )

    full_catalog   <- get_dwc_full_catalog()
    catalog_terms  <- full_catalog$term
    needs_activate <- setdiff(template_terms, active_terms)

    list(
        to_activate = needs_activate[needs_activate %in% catalog_terms],
        unknown     = needs_activate[!needs_activate %in% catalog_terms]
    )
}
