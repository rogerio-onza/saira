# Utils rostrum template contracts

rostrum_template_trim_scalar <- function(value, field_name, required = FALSE) {
    value_chr <- trimws(as.character(value))
    if (length(value_chr) == 0L || is.na(value_chr[[1]]) || !nzchar(value_chr[[1]])) {
        if (isTRUE(required)) {
            stop("Template field '", field_name, "' must be a non-empty string.")
        }
        return(NA_character_)
    }
    value_chr[[1]]
}

rostrum_template_has_column <- function(conn, table_name, column_name) {
    if (is.null(conn) || !DBI::dbIsValid(conn)) {
        return(FALSE)
    }

    info <- tryCatch(
        DBI::dbGetQuery(conn, paste0("PRAGMA table_info(", table_name, ")")),
        error = function(e) data.frame(name = character(0), stringsAsFactors = FALSE)
    )

    "name" %in% names(info) && column_name %in% as.character(info$name)
}

rostrum_template_validate_version_window <- function(
    app_min_version = NA_character_,
    app_max_version = NA_character_,
    current_version = rostrum_app_version()
) {
    current <- rostrum_template_trim_scalar(
        current_version,
        field_name = "current_version",
        required = TRUE
    )
    app_min <- rostrum_template_trim_scalar(
        app_min_version,
        field_name = "app_min_version",
        required = FALSE
    )
    app_max <- rostrum_template_trim_scalar(
        app_max_version,
        field_name = "app_max_version",
        required = FALSE
    )

    if (!is.na(app_min) && !is.na(app_max) &&
        utils::compareVersion(app_min, app_max) > 0L) {
        stop("Template app_min_version (", app_min, ") cannot be greater than app_max_version (", app_max, ").")
    }

    if (!is.na(app_min) && utils::compareVersion(current, app_min) < 0L) {
        stop(
            "Template requires app_min_version ", app_min,
            ", but current app version is ", current, "."
        )
    }

    if (!is.na(app_max) && utils::compareVersion(current, app_max) > 0L) {
        warning(
            "Template app_max_version ", app_max,
            " is older than current app version ", current,
            ". Template will still be loaded.",
            call. = FALSE
        )
    }

    list(
        current_version = current,
        app_min_version = app_min,
        app_max_version = app_max
    )
}

rostrum_template_normalize_source_columns <- function(source_columns, item_index) {
    source_raw <- unlist(source_columns, recursive = TRUE, use.names = FALSE)
    source_chr <- trimws(as.character(source_raw))
    source_chr <- source_chr[!is.na(source_chr) & nzchar(source_chr)]

    if (length(source_chr) == 0L) {
        stop("Template item #", item_index, " must include at least one source column.")
    }

    unique(source_chr)
}

rostrum_template_normalize_item <- function(item, item_index) {
    if (!is.list(item)) {
        stop("Template item #", item_index, " must be an object.")
    }

    if (!("dwc_term" %in% names(item))) {
        stop("Template item #", item_index, " is missing required field 'dwc_term'.")
    }
    if (!("source_columns" %in% names(item))) {
        stop("Template item #", item_index, " is missing required field 'source_columns'.")
    }

    dwc_term <- rostrum_template_trim_scalar(
        item$dwc_term,
        field_name = paste0("items[", item_index, "].dwc_term"),
        required = TRUE
    )
    source_columns <- rostrum_template_normalize_source_columns(
        item$source_columns,
        item_index = item_index
    )
    transform_kind <- rostrum_template_trim_scalar(
        item$transform_kind,
        field_name = paste0("items[", item_index, "].transform_kind"),
        required = FALSE
    )

    transform_params <- item$transform_params
    if (is.null(transform_params)) {
        transform_params <- list()
    }
    if (!is.list(transform_params)) {
        stop("Template item #", item_index, " field 'transform_params' must be an object.")
    }

    priority <- suppressWarnings(as.integer(item$priority))
    if (length(priority) != 1L || is.na(priority)) {
        priority <- 0L
    }

    required <- isTRUE(item$required)

    list(
        dwc_term = dwc_term,
        source_columns = source_columns,
        transform_kind = transform_kind,
        transform_params = transform_params,
        priority = priority,
        required = required
    )
}

rostrum_validate_template_payload <- function(
    payload,
    current_version = rostrum_app_version()
) {
    payload_obj <- payload
    if (is.character(payload_obj)) {
        if (length(payload_obj) != 1L || is.na(payload_obj) || !nzchar(trimws(payload_obj))) {
            stop("Template payload string must be a non-empty JSON string.")
        }
        payload_obj <- tryCatch(
            jsonlite::fromJSON(payload_obj, simplifyVector = FALSE),
            error = function(e) {
                stop("Template payload JSON parse failed: ", e$message, call. = FALSE)
            }
        )
    }

    if (!is.list(payload_obj)) {
        stop("Template payload must be an object/list.")
    }

    required_top_fields <- c("template_id", "name", "scope", "schema_version", "items")
    missing_fields <- setdiff(required_top_fields, names(payload_obj))
    if (length(missing_fields) > 0L) {
        stop(
            "Template payload is missing required fields: ",
            paste(missing_fields, collapse = ", "), "."
        )
    }

    scope <- rostrum_validate_scope(payload_obj$scope)
    template_id <- rostrum_template_trim_scalar(payload_obj$template_id, "template_id", required = TRUE)
    name <- rostrum_template_trim_scalar(payload_obj$name, "name", required = TRUE)
    schema_version <- rostrum_template_trim_scalar(payload_obj$schema_version, "schema_version", required = TRUE)
    owner_id <- rostrum_template_trim_scalar(payload_obj$owner_id, "owner_id", required = FALSE)
    institution_id <- rostrum_template_trim_scalar(payload_obj$institution_id, "institution_id", required = FALSE)
    description <- rostrum_template_trim_scalar(payload_obj$description, "description", required = FALSE)
    use_case <- rostrum_template_trim_scalar(payload_obj$use_case, "use_case", required = FALSE)

    version_check <- rostrum_template_validate_version_window(
        app_min_version = payload_obj$app_min_version,
        app_max_version = payload_obj$app_max_version,
        current_version = current_version
    )

    is_active <- payload_obj$is_active
    if (is.null(is_active)) {
        is_active <- TRUE
    }
    is_active <- isTRUE(is_active)

    items_raw <- payload_obj$items
    if (!is.list(items_raw) || length(items_raw) == 0L) {
        stop("Template payload field 'items' must be a non-empty list.")
    }

    items <- lapply(seq_along(items_raw), function(i) {
        rostrum_template_normalize_item(items_raw[[i]], item_index = i)
    })

    item_terms <- vapply(items, function(x) x$dwc_term, FUN.VALUE = character(1))
    if (anyDuplicated(item_terms)) {
        dup_terms <- unique(item_terms[duplicated(item_terms)])
        stop("Template payload contains duplicated dwc_term entries: ", paste(dup_terms, collapse = ", "), ".")
    }

    list(
        template_id = template_id,
        name = name,
        scope = scope,
        owner_id = owner_id,
        institution_id = institution_id,
        schema_version = schema_version,
        app_min_version = version_check$app_min_version,
        app_max_version = version_check$app_max_version,
        is_active = is_active,
        description = description,
        use_case = use_case,
        items = items
    )
}

rostrum_template_to_json <- function(payload, pretty = TRUE) {
    normalized <- rostrum_validate_template_payload(payload)
    as.character(jsonlite::toJSON(
        normalized,
        auto_unbox = TRUE,
        null = "null",
        pretty = isTRUE(pretty)
    ))
}

rostrum_template_from_json <- function(json_payload, current_version = rostrum_app_version()) {
    rostrum_validate_template_payload(
        payload = json_payload,
        current_version = current_version
    )
}
