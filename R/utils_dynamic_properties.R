# Utils dynamic properties

#' Escape a character vector for embedding inside JSON double-quoted strings
#'
#' Implements the strict JSON string escape table (RFC 8259). UTF-8 multi-byte
#' sequences are preserved as-is (legal in JSON). NA values are passed through.
#'
#' @param x Character vector.
#' @return Character vector of the same length with JSON-safe contents.
#' @keywords internal
#' @noRd
json_escape_string <- function(x) {
    x <- as.character(x)
    out <- x
    # Fast path: skip per-class gsub when no character in any element needs
    # escaping. Cheap single grepl is faster than running every gsub blindly.
    if (any(grepl("[\\\\\"\x01-\x1f]", out, perl = TRUE), na.rm = TRUE)) {
        out <- gsub("\\\\", "\\\\\\\\", out, perl = TRUE)
        out <- gsub("\"", "\\\\\"", out, perl = TRUE)
        out <- gsub("\b", "\\b", out, fixed = TRUE)
        out <- gsub("\f", "\\f", out, fixed = TRUE)
        out <- gsub("\n", "\\n", out, fixed = TRUE)
        out <- gsub("\r", "\\r", out, fixed = TRUE)
        out <- gsub("\t", "\\t", out, fixed = TRUE)
        has_other_ctrl <- grepl("[\x01-\x07\x0b\x0e-\x1f]", out, perl = TRUE)
        if (any(has_other_ctrl, na.rm = TRUE)) {
            idx <- which(has_other_ctrl)
            out[idx] <- vapply(out[idx], function(s) {
                chars <- strsplit(s, "", fixed = TRUE)[[1]]
                codes <- utf8ToInt(s)
                ctrl <- which(codes < 32 & !(codes %in% c(8, 9, 10, 12, 13)))
                chars[ctrl] <- sprintf("\\u%04x", codes[ctrl])
                paste(chars, collapse = "")
            }, character(1), USE.NAMES = FALSE)
        }
    }
    out[is.na(x)] <- NA_character_
    out
}

#' Derive a JSON-safe key from a source column name
#'
#' Lowercases, transliterates accents to ASCII via iconv, replaces any run of
#' non-alphanumeric characters with a single underscore, trims leading/trailing
#' underscores, and falls back to "field" if the result is empty.
#'
#' @param column_name Character vector of column names.
#' @return Character vector of normalized JSON keys, same length as input.
#' @keywords internal
#' @noRd
derive_dynprops_key <- function(column_name) {
    x <- tolower(as.character(column_name))
    translit <- iconv(x, to = "ASCII//TRANSLIT")
    has_translit <- !is.na(translit)
    x[has_translit] <- translit[has_translit]
    x <- gsub("[^a-z0-9]+", "_", x, perl = TRUE)
    x <- gsub("_+", "_", x, perl = TRUE)
    x <- gsub("^_|_$", "", x, perl = TRUE)
    x[!nzchar(x)] <- "field"
    x
}

#' Compose dynamicProperties JSON from one or more source columns
#'
#' Builds a strict TDWG-compatible JSON object per row of the form
#' `{"key1":"value1","key2":"value2"}` (no whitespace). Blank cells are
#' omitted from that row's JSON. A row in which every selected column is
#' blank produces an empty string `""` (not `"{}"`).
#'
#' @param df Data frame containing the source columns.
#' @param cols Character vector of source column names (length >= 1).
#' @param keys Optional named character vector (or list) mapping
#'   `cols[i]` to a user-overridden JSON key. Entries that are NULL,
#'   NA, blank, or contain a literal double-quote are ignored and the
#'   key is auto-derived via [derive_dynprops_key()].
#' @return Character vector of length `nrow(df)`.
#' @keywords internal
#' @noRd
build_dynamic_properties_json <- function(df, cols, keys = NULL) {
    if (length(cols) == 0) {
        return(rep("", nrow(df)))
    }

    missing_cols <- setdiff(cols, names(df))
    if (length(missing_cols) > 0) {
        stop("Columns not found in data frame: ", paste(missing_cols, collapse = ", "))
    }

    key_overrides <- if (is.null(keys)) list() else as.list(keys)

    resolved_keys <- vapply(cols, function(col_name) {
        override <- key_overrides[[col_name]]
        if (!is.null(override) && length(override) == 1L) {
            override_str <- as.character(override)
            if (!is.na(override_str) && nzchar(trimws(override_str)) &&
                !grepl("\"", override_str, fixed = TRUE)) {
                return(trimws(override_str))
            }
        }
        derive_dynprops_key(col_name)
    }, character(1), USE.NAMES = FALSE)

    dup_mask <- duplicated(resolved_keys)
    if (any(dup_mask)) {
        collisions <- unique(resolved_keys[dup_mask])
        details <- vapply(collisions, function(k) {
            paste0("'", k, "' <- ", paste(cols[resolved_keys == k], collapse = ", "))
        }, character(1), USE.NAMES = FALSE)
        warning(
            "build_dynamic_properties_json: key collision after normalization. ",
            "First column wins; later duplicates dropped. Conflicts: ",
            paste(details, collapse = "; ")
        )
        keep_idx <- which(!dup_mask)
        cols <- cols[keep_idx]
        resolved_keys <- resolved_keys[keep_idx]
    }

    n <- nrow(df)
    if (n == 0L) {
        return(character(0))
    }

    n_cols <- length(cols)

    # Vectorized row build: per column, pre-format `"key":"value"` strings,
    # mark blank cells with "" (sentinel). Join columns with a control-char
    # sentinel \x01, then strip empty pieces and surrounding sentinels via
    # regex, swap the sentinel for ',', and wrap non-empty rows in {...}.
    sentinel <- "\x01"
    parts_per_col <- vector("list", n_cols)
    for (j in seq_len(n_cols)) {
        v <- df[[cols[[j]]]]
        blank <- is.na(v) | !nzchar(trimws(as.character(v)))
        escaped <- json_escape_string(v)
        piece <- paste0("\"", resolved_keys[[j]], "\":\"", escaped, "\"")
        # A cell that already holds an object (a re-imported
        # dynamicProperties) gives its members, not one escaped string (AUD-08).
        members <- json_object_members(v)
        is_obj <- !is.na(members)
        piece[is_obj] <- members[is_obj]
        piece[blank | (is_obj & !nzchar(members))] <- ""
        parts_per_col[[j]] <- piece
    }

    joined <- do.call(paste, c(parts_per_col, list(sep = sentinel)))
    joined <- gsub(paste0(sentinel, "+"), sentinel, joined, perl = TRUE)
    joined <- gsub(
        paste0("^", sentinel, "|", sentinel, "$"), "", joined, perl = TRUE
    )
    joined <- gsub(sentinel, ",", joined, fixed = TRUE)

    out <- character(n)
    keep <- nzchar(joined)
    out[keep] <- paste0("{", joined[keep], "}")
    out
}

# A JSON string, and a flat JSON object: string, number, boolean or null
# values, no nesting.
json_str_re <- "\"(?:[^\"\\\\]|\\\\.)*\""

json_flat_object_re <- local({
    val <- paste0("(?:", json_str_re,
                  "|-?(?:0|[1-9][0-9]*)(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|true|false|null)")
    mem <- paste0("\\s*", json_str_re, "\\s*:\\s*", val, "\\s*")
    paste0("^\\{(?:", mem, "(?:,", mem, ")*|\\s*)\\}$")
})

# The members of a cell that holds a JSON object, minified and without the
# outer braces ("" for `{}`), or NA for any other value. A regex reads the
# flat objects in one pass. jsonlite reads the nested ones, one at a time.
json_object_members <- function(x) {
    x <- as.character(x)
    out <- rep(NA_character_, length(x))
    cand <- which(grepl("{", x, fixed = TRUE))
    if (!length(cand)) return(out)
    cell <- trimws(x[cand])
    flat <- grepl(json_flat_object_re, cell, perl = TRUE)
    tight <- gsub(paste0("(", json_str_re, ")|\\s+"), "\\1", cell[flat], perl = TRUE)
    out[cand[flat]] <- substr(tight, 2L, nchar(tight) - 1L)
    for (i in which(!flat & startsWith(cell, "{") & endsWith(cell, "}"))) {
        if (isTRUE(jsonlite::validate(cell[[i]]))) {
            out[[cand[[i]]]] <- sub("^\\{(.*)\\}$", "\\1", as.character(jsonlite::minify(cell[[i]])))
        }
    }
    out
}

#' Merge one key/value pair into existing dynamicProperties JSON
#'
#' Folds `"key":"value"` into each element of `existing` — a vector of flat
#' dynamicProperties JSON strings produced by [build_dynamic_properties_json()]
#' (`{"k":"v"}`) or `""`/NA. Used on export to add conservation-status entries
#' without hand-concatenating strings: the value is JSON-escaped and the object
#' reserialized (same no-whitespace convention). Rows whose `value` is NA or
#' blank are returned unchanged, so empty keys are never emitted. A key the
#' object already has at the top level takes the new value.
#'
#' @param existing Character vector of dynamicProperties JSON strings.
#' @param key Single JSON key, assumed ASCII-safe (e.g. a DwC-style term).
#' @param value Character vector of length 1 or `length(existing)`.
#' @return Character vector the same length as `existing`.
#' @keywords internal
#' @noRd
merge_dynamic_property <- function(existing, key, value) {
    n <- length(existing)
    if (n == 0L) {
        return(character(0))
    }
    existing <- as.character(existing)
    existing[is.na(existing)] <- ""
    value <- as.character(value)
    if (length(value) == 1L) {
        value <- rep(value, n)
    }
    out <- existing
    add <- !is.na(value) & nzchar(trimws(value))
    if (!any(add)) {
        return(out)
    }
    pair <- paste0("\"", key, "\":\"", json_escape_string(value), "\"")
    # Empty target -> wrap the pair as a fresh object.
    fresh <- add & !nzchar(existing)
    out[fresh] <- paste0("{", pair[fresh], "}")
    obj <- add & nzchar(existing)
    # A key the object already has takes the new value, so a reader never
    # finds two values for it (AUD-09). In a flat object a regex marks each
    # copy of the key, the first mark takes the pair and the others go.
    has_key <- obj & grepl(paste0("\"", key, "\":"), existing, fixed = TRUE)
    flat <- which(has_key & grepl(json_flat_object_re, existing, perl = TRUE))
    if (length(flat)) {
        member <- paste0("(?<=[{,])\"", key, "\":(?:", json_str_re, "|[^,}]*)")
        marked <- gsub(member, "\x02", existing[flat], perl = TRUE)
        at <- regexpr("\x02", marked, fixed = TRUE)
        hit <- at > 0L
        flat <- flat[hit]
        out[flat] <- gsub(",\x02", "", paste0(
            substr(marked[hit], 1L, at[hit] - 1L), pair[flat], substring(marked[hit], at[hit] + 1L)
        ), fixed = TRUE)
        obj[flat] <- FALSE
        has_key[flat] <- FALSE
    }
    for (i in which(has_key & obj)) {
        parsed <- tryCatch(jsonlite::parse_json(existing[[i]]), error = function(e) NULL)
        if (is.list(parsed) && key %in% names(parsed)) {
            parsed <- parsed[names(parsed) != key | seq_along(parsed) == match(key, names(parsed))]
            parsed[[key]] <- value[[i]]
            out[[i]] <- as.character(jsonlite::toJSON(
                parsed, auto_unbox = TRUE, digits = NA, null = "null", na = "null"
            ))
            obj[[i]] <- FALSE
        }
    }
    # Existing object -> splice the pair in before the closing brace.
    inner <- sub("\\}$", "", sub("^\\{", "", existing[obj]))
    joined <- ifelse(nzchar(inner), paste0(inner, ",", pair[obj]), pair[obj])
    out[obj] <- paste0("{", joined, "}")
    out
}

