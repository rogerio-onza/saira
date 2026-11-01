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
    members_per_col <- vector("list", n_cols)
    obj_rows <- logical(n)
    for (j in seq_len(n_cols)) {
        v <- as.character(df[[cols[[j]]]])
        blank <- is.na(v) | !nzchar(trimws(v))
        # A cell that already holds an object (a re-imported
        # dynamicProperties) gives its members, not one escaped string (AUD-08).
        members <- json_object_member_list(v)
        is_obj <- grepl("{", v, fixed = TRUE)
        is_obj[is_obj] <- !vapply(members[is_obj], is.null, logical(1))
        piece <- character(n)
        text <- !blank & !is_obj
        piece[text] <- paste0(
            "\"", json_escape_string(resolved_keys[[j]]), "\":\"", json_escape_string(v[text]), "\""
        )
        parts_per_col[[j]] <- piece
        members_per_col[[j]] <- members
        obj_rows <- obj_rows | is_obj
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

    # A row with an object cell can repeat a key across cells, so its members
    # go through the same first-wins rule as the column keys.
    rows <- which(obj_rows)
    if (length(rows)) {
        members <- vector("list", n_cols)
        row_id <- vector("list", n_cols)
        col_id <- vector("list", n_cols)
        for (j in seq_len(n_cols)) {
            cell <- members_per_col[[j]][rows]
            obj <- !vapply(cell, is.null, logical(1))
            plain <- which(!obj & nzchar(parts_per_col[[j]][rows]))
            obj <- which(obj)
            members[[j]] <- c(unlist(cell[obj], use.names = FALSE), parts_per_col[[j]][rows][plain])
            row_id[[j]] <- c(rep.int(obj, lengths(cell[obj])), plain)
            col_id[[j]] <- rep.int(j, length(row_id[[j]]))
        }
        row_id <- unlist(row_id, use.names = FALSE)
        # Stable sort: within a row the columns keep their order, and so do
        # the members of one cell.
        ord <- order(row_id, unlist(col_id, use.names = FALSE), method = "radix")
        out[rows] <- json_objects_from_members(
            unlist(members, use.names = FALSE)[ord], row_id[ord], length(rows),
            "build_dynamic_properties_json"
        )
    }
    out
}

# A JSON string, and a flat JSON object: string, number, boolean or null
# values, no nesting. A string takes only the escapes and characters that RFC
# 8259 allows, so a cell with any other one is read as text.
json_str_re <- "\"(?:[^\"\\\\\\x00-\\x1f]|\\\\(?:[\"\\\\/bfnrt]|u[0-9a-fA-F]{4}))*\""

json_flat_object_re <- local({
    val <- paste0("(?:", json_str_re,
                  "|-?(?:0|[1-9][0-9]*)(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|true|false|null)")
    mem <- paste0("\\s*", json_str_re, "\\s*:\\s*", val, "\\s*")
    paste0("^\\{(?:", mem, "(?:,", mem, ")*|\\s*)\\}$")
})

# The members of a cell that holds a JSON object, minified and without the
# outer braces ("" for `{}`), or NA for any other value. A regex reads the
# flat objects in one pass. jsonlite reads the nested ones, one at a time.
# The "flat" attribute marks the bodies whose values hold no array or object.
json_object_members <- function(x) {
    x <- as.character(x)
    out <- rep(NA_character_, length(x))
    is_flat <- logical(length(x))
    cand <- which(grepl("{", x, fixed = TRUE))
    if (!length(cand)) return(structure(out, flat = is_flat))
    cell <- trimws(x[cand])
    flat <- grepl(json_flat_object_re, cell, perl = TRUE)
    is_flat[cand[flat]] <- TRUE
    tight <- gsub(paste0("(", json_str_re, ")|\\s+"), "\\1", cell[flat], perl = TRUE)
    out[cand[flat]] <- substr(tight, 2L, nchar(tight) - 1L)
    for (i in which(!flat & startsWith(cell, "{") & endsWith(cell, "}"))) {
        if (isTRUE(jsonlite::validate(cell[[i]]))) {
            out[[cand[[i]]]] <- sub("^\\{(.*)\\}$", "\\1", as.character(jsonlite::minify(cell[[i]])))
        }
    }
    structure(out, flat = is_flat)
}

# The members of each value that holds a JSON object: one minified
# `"key":value` string per top-level member, or NULL for any other value. This
# is the one reader of object members: the builder and the merge both use it,
# so they agree on what a key is.
json_object_member_list <- function(x) {
    x <- as.character(x)
    uniq <- unique(x)
    inner <- json_object_members(uniq)
    out <- vector("list", length(uniq))
    flat <- which(attr(inner, "flat"))
    nested <- setdiff(which(!is.na(inner)), flat)
    if (length(flat)) {
        # Split on the commas outside the strings: PCRE skips each string.
        out[flat] <- strsplit(
            inner[flat], "\"(?:[^\"\\\\]|\\\\.)*\"(*SKIP)(*FAIL)|,", perl = TRUE
        )
    }
    if (length(nested)) {
        out[nested] <- json_split_nested_members(inner[nested])
    }
    out[match(x, uniq)]
}

# Top-level members of minified object bodies with nested values. Commas
# inside strings, arrays and objects do not split. Each body is balanced, so
# one running depth over all the bodies is 0 at every body boundary.
json_split_nested_members <- function(inner) {
    tok <- gregexpr(paste0(json_str_re, "|[][{},]"), inner, perl = TRUE)
    body_id <- rep.int(seq_along(inner), lengths(tok))
    pos <- unlist(tok, use.names = FALSE)
    len <- unlist(lapply(tok, attr, "match.length"), use.names = FALSE)
    ch <- substr(inner[body_id], pos, pos)
    ch[len > 1L] <- ""
    step <- (ch == "{" | ch == "[") - (ch == "}" | ch == "]")
    cut <- ch == "," & cumsum(step) - step == 0L
    n_body <- length(inner)
    start_id <- c(seq_len(n_body), body_id[cut])
    start <- c(rep.int(1L, n_body), pos[cut] + 1L)
    end_id <- c(body_id[cut], seq_len(n_body))
    end <- c(pos[cut] - 1L, nchar(inner))
    so <- order(start_id, start, method = "radix")
    eo <- order(end_id, end, method = "radix")
    members <- substring(inner[start_id[so]], start[so], end[eo])
    unname(split(members, factor(start_id[so], levels = seq_len(n_body))))
}

# The decoded key of each member string, so "k" and "\u006b" are one key.
json_member_keys <- function(members) {
    # A member starts with its key, so the match is at 1.
    end <- attr(regexpr(json_str_re, members, perl = TRUE), "match.length")
    keys <- substr(members, 2L, end - 1L)
    escaped <- grepl("\\", keys, fixed = TRUE)
    keys[escaped] <- vapply(
        substr(members[escaped], 1L, end[escaped]), jsonlite::parse_json,
        character(1), USE.NAMES = FALSE
    )
    keys
}

# `n` JSON objects from member strings in row order (`row_id` sorted). The
# first member of a key wins and the later ones go, with one warning that
# names the keys. A row with no members gives "".
json_objects_from_members <- function(members, row_id, n, caller) {
    keys <- json_member_keys(members)
    # A stable sort by row and key puts each repeat right after the first one.
    dup <- logical(length(keys))
    if (length(keys) > 1L) {
        o <- order(row_id, keys, method = "radix")
        dup[o[-1L]] <- row_id[o[-1L]] == row_id[o[-length(o)]] & keys[o[-1L]] == keys[o[-length(o)]]
    }
    if (any(dup)) {
        warning(
            caller, ": a key repeats in one record. First value wins; later ",
            "duplicates dropped. Keys: ", paste(unique(keys[dup]), collapse = ", ")
        )
        members <- members[!dup]
        row_id <- row_id[!dup]
    }
    out <- character(n)
    if (!length(members)) {
        return(out)
    }
    # One paste and one split instead of a paste per row. A member never
    # holds a raw control character, so \x02 cannot occur inside one.
    last <- c(row_id[-1L] != row_id[-length(row_id)], TRUE)
    body <- strsplit(
        paste0(members, ifelse(last, "\x02", ","), collapse = ""), "\x02", fixed = TRUE
    )[[1]]
    out[row_id[last]] <- paste0("{", body, "}")
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
    # finds two values for it (AUD-09). Only an object whose text names the
    # key, or carries an escape that could spell it, can hold it.
    cand <- which(obj & (
        grepl(paste0("\"", key, "\""), existing, fixed = TRUE) |
            grepl("\\u", existing, fixed = TRUE)
    ))
    inner <- json_object_members(existing[cand])
    # Fast path for a flat body with no escape: a regex marks each copy of
    # the key, the first mark takes the pair and the others go. It gives the
    # same result as the member path below (tested).
    flat <- attr(inner, "flat") & !grepl("\\u", inner, fixed = TRUE)
    if (any(flat)) {
        body <- inner[flat]
        p <- pair[cand[flat]]
        member <- paste0("(?:^|(?<=,))\"\\Q", key, "\\E\":(?:", json_str_re, "|[^,]*)")
        marked <- gsub(member, "\x02", body, perl = TRUE)
        at <- regexpr("\x02", marked, fixed = TRUE)
        hit <- at > 0L
        body[hit] <- gsub(",\x02", "", paste0(
            substr(marked[hit], 1L, at[hit] - 1L), p[hit], substring(marked[hit], at[hit] + 1L)
        ), fixed = TRUE)
        body[!hit] <- ifelse(nzchar(body[!hit]), paste0(body[!hit], ",", p[!hit]), p[!hit])
        out[cand[flat]] <- paste0("{", body, "}")
        obj[cand[flat]] <- FALSE
    }
    rows <- cand[!is.na(inner) & !flat]
    if (length(rows)) {
        listed <- json_object_member_list(existing[rows])
        members <- unlist(listed, use.names = FALSE)
        row_id <- rep.int(seq_along(rows), lengths(listed))
        hit <- which(json_member_keys(members) == key)
        first <- hit[!duplicated(row_id[hit])]
        members[first] <- pair[rows][row_id[first]]
        append <- setdiff(seq_along(rows), row_id[first])
        drop <- setdiff(hit, first)
        if (length(drop)) {
            members <- members[-drop]
            row_id <- row_id[-drop]
        }
        members <- c(members, pair[rows][append])
        row_id <- c(row_id, append)
        ord <- order(row_id, method = "radix")
        out[rows] <- json_objects_from_members(
            members[ord], row_id[ord], length(rows), "merge_dynamic_property"
        )
        obj[rows] <- FALSE
    }
    # Existing object -> splice the pair in before the closing brace.
    inner <- sub("\\}$", "", sub("^\\{", "", existing[obj]))
    joined <- ifelse(nzchar(inner), paste0(inner, ",", pair[obj]), pair[obj])
    out[obj] <- paste0("{", joined, "}")
    out
}
