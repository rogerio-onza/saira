# Utils identifiers

# Position of each element within its group of equal values, without splitting
# the vector. ave(FUN = seq_along) is the readable form but builds one group per
# distinct value, which on a 40k-row upload of mostly unique content is the
# dominant cost. One sort does the same work.
seq_within_groups <- function(x) {
    n <- length(x)
    if (n == 0L) {
        return(integer(0))
    }
    o <- order(x)
    sorted <- x[o]
    starts <- c(TRUE, sorted[-1L] != sorted[-n])
    out <- integer(n)
    out[o] <- sequence(diff(c(which(starts), n + 1L)))
    out
}

# Build the identifier for rows that carry none.
#
# Deterministic by construction: the identifier is derived from the row's own
# content, so re-uploading the same spreadsheet reproduces the same identifiers
# instead of minting new ones. That is the requirement -- an identifier that
# stays the same across exports, so republishing updates a record rather than
# creating a duplicate.
#
# Rows whose content is identical are routine in aggregated datasets (the same
# taxon, at the same point, on the same date, arriving from different source
# studies), and Darwin Core requires occurrenceID to be unique within the
# dataset. Each is therefore disambiguated by its occurrence number within its
# content group. The cost is stated plainly rather than hidden: correcting a
# value changes that row's identifier, and reordering rows that are identical in
# every column can swap their identifiers between them.
#
# The encoding is confined to this function on purpose: swapping UUID v5 for a
# ULID or another digest must not reach any caller, or the vocabulary the user
# reads.
generate_persistent_ids <- function(df, rows = NULL, exclude = NULL) {
    n <- if (is.data.frame(df)) nrow(df) else 0L
    if (n == 0L) {
        return(character(0))
    }
    if (is.null(rows)) rows <- rep(TRUE, n)
    if (!any(rows)) {
        return(character(0))
    }

    # The identifier column itself never feeds the hash: a row that has no
    # identifier must hash the same whether the column is absent or blank.
    cols <- setdiff(names(df), c(exclude, "occurrenceID"))
    # ASCII unit/record separators join the parts. A plain concatenation would
    # let ("ab", "c") and ("a", "bc") hash to the same key; these bytes cannot
    # occur in spreadsheet cells, so the join is unambiguous.
    content <- if (length(cols) == 0L) {
        rep("", sum(rows))
    } else {
        do.call(paste, c(
            lapply(cols, function(col) as.character(df[[col]])[rows]),
            list(sep = "\u001f")
        ))
    }

    keys <- paste0(content, "\u001e", seq_within_groups(content))

    # UUID v5 is itself SHA-1 over (namespace + name), so the key goes in as the
    # name and no separate digest step is needed. Feed the distinct keys only,
    # in one vectorized call: UUIDfromName over a 40k vector is ~80x the loop.
    uniq <- unique(keys)
    hashed <- paste0("urn:uuid:", uuid::UUIDfromName(saira_id_namespace(), uniq))
    hashed[match(keys, uniq)]
}

# RFC 4122 URL namespace. Fixed forever: changing it would re-mint every
# identifier Saira has ever generated.
saira_id_namespace <- function() {
    "6ba7b811-9dad-11d1-80b4-00c04fd430c8"
}

# Resolve which column the occurrenceID should be taken from. The user's mapping
# wins, because the identifier column is rarely called "occurrenceID" in a
# publisher's own spreadsheet. The literal column is the fallback, which is what
# a re-imported Saira export and any already-standardized DwC file ship.
occurrence_id_source_column <- function(df, map_values = NULL) {
    if (!is.data.frame(df)) {
        return(NULL)
    }

    if (is.list(map_values)) {
        selected <- sanitize_map_selection(
            "occurrenceID", map_values[["occurrenceID"]]
        )
        if (has_selected_value(selected) && selected[[1]] %in% names(df)) {
            return(selected[[1]])
        }
    }
    if ("occurrenceID" %in% names(df)) {
        return("occurrenceID")
    }
    NULL
}

occurrence_id_source_values <- function(df, map_values = NULL) {
    col <- occurrence_id_source_column(df, map_values)
    if (is.null(col)) {
        return(NULL)
    }
    trimws(as.character(df[[col]]))
}

# Resolve the occurrenceID vector for a dataset.
#
# The whole rule, in one place: an identifier the row already carries wins, and
# Saira fills only the gaps. That is the TDWG guidance for the term ("in the
# absence of a persistent global unique identifier, construct one") and it is
# what makes the round trip work -- export, add rows, re-import, and everything
# already published keeps its identifier while only the new rows get one.
#
# Any stable string qualifies: Darwin Core requires occurrenceID to be unique
# within the dataset, not globally, so a publisher's own "ABBA_00001" is a
# perfectly good identifier and is preserved verbatim rather than rewritten.
#
# `map_values` is what makes the mapping authoritative; before it was threaded
# through, a source column named anything other than "occurrenceID" was silently
# replaced while the mapping guide still reported the ids as user-supplied.
#
# Returns the character vector with `id_strategy` and `id_counts` attributes
# describing what actually happened, which the mapping guide reports verbatim.
resolve_occurrence_ids <- function(df, n = NULL, map_values = NULL) {
    n <- n %||% (if (is.data.frame(df)) nrow(df) else length(df))

    # Generate only the identifiers actually needed. Building n and then
    # overwriting the supplied ones made a file that ships a complete column pay
    # for a full set and discard every one.
    out <- character(n)
    keep <- rep(FALSE, n)

    src_col <- occurrence_id_source_column(df, map_values)
    if (!is.null(src_col)) {
        src <- trimws(as.character(df[[src_col]]))
        if (length(src) == n) {
            keep <- !is.na(src) & nzchar(src)
            out[keep] <- src[keep]
        }
    }

    n_preserved <- sum(keep)
    if (n_preserved < n) {
        out[!keep] <- generate_persistent_ids(df, rows = !keep, exclude = src_col)
    }

    attr(out, "id_strategy") <- occurrence_id_strategy_label(n_preserved, n)
    attr(out, "id_counts") <- list(
        total = n,
        preserved = n_preserved,
        generated = n - n_preserved
    )
    out
}

# Replace the occurrenceIDs that still repeat after the Preview corrections.
#
# Darwin Core requires occurrenceID to be unique within the dataset, so an
# identifier that two rows share is not an identifier, and the TDWG note for
# the term applies: construct one. The person can correct the rows in the
# Preview first. Every row that still repeats an identifier gets one, the first
# row too, because which row comes first depends on the row order. The ids
# come from `basis` (the mapped rows before the Preview corrections), so a
# correction in the Preview does not change them (ADR-152).
#
# `ignore` holds rows that leave the package at export (exact copies the
# person leaves out). They do not count as a repeat and keep their id, so the
# row they copy keeps its own id.
#
# Returns `df`, with the `ids_replaced` attribute (the count of rows changed)
# when it changes a row.
replace_repeated_ids <- function(df, basis = df, ignore = integer(0)) {
    if (!is.data.frame(df) || !"occurrenceID" %in% names(df)) {
        return(df)
    }
    v <- trimws(as.character(df$occurrenceID))
    v[intersect(as.integer(ignore), seq_along(v))] <- NA_character_
    repeated <- !is.na(v) & nzchar(v) & (duplicated(v, incomparables = NA) |
        duplicated(v, fromLast = TRUE, incomparables = NA))
    if (any(repeated)) {
        df$occurrenceID[repeated] <- generate_persistent_ids(basis, rows = repeated)
        attr(df, "ids_replaced") <- sum(repeated)
    }
    df
}

# The identifier counts of the mapping stage, after `replace_repeated_ids()`
# changed `replaced` of the preserved ids.
occurrence_id_counts_after_repeats <- function(counts, replaced) {
    if (!is.list(counts) || is.null(counts$total) || !isTRUE(replaced > 0L)) {
        return(counts)
    }
    counts$preserved <- max(counts$preserved - replaced, 0L)
    counts$generated <- counts$total - counts$preserved
    counts
}

# Name what produced a dataset's identifiers. The mapping guide keys its
# explanation off this label.
occurrence_id_strategy_label <- function(n_preserved, n_total) {
    if (n_preserved == n_total) {
        # Covers the empty frame too: nothing was generated.
        return("user_supplied")
    }
    if (n_preserved == 0L) {
        return("generated")
    }
    "user_supplied_with_generated"
}

# Darwin Core requires occurrenceID to be unique within a dataset, so the card
# reports collisions: pointing at a column that repeats is a GBIF blocker, and
# it is not obvious from looking at the data. Blank rows are counted apart from
# collisions -- a blank is not a duplicate, it just gets a generated id.
check_occurrence_id_uniqueness <- function(values) {
    v <- trimws(as.character(values))
    v[is.na(values)] <- ""
    filled <- nzchar(v)
    n_filled <- sum(filled)

    list(
        total = length(v),
        filled = n_filled,
        blank = sum(!filled),
        duplicates = n_filled - length(unique(v[filled])),
        ok = n_filled == length(unique(v[filled]))
    )
}

