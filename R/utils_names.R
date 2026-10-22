# Utils names

format_genus_token <- function(token) {
    if (is_blank_value(token)) {
        return(NA_character_)
    }

    cleaned <- gsub("^[^A-Za-z]+|[^A-Za-z-]+$", "", as.character(token))
    if (!nzchar(cleaned)) {
        return(NA_character_)
    }

    paste0(
        toupper(substr(cleaned, 1, 1)),
        tolower(substr(cleaned, 2, nchar(cleaned)))
    )
}

format_epithet_token <- function(token) {
    if (is_blank_value(token)) {
        return(NA_character_)
    }

    cleaned <- gsub("^[^A-Za-z]+|[^A-Za-z-]+$", "", as.character(token))
    cleaned <- tolower(cleaned)

    if (!grepl("^[a-z][a-z-]*$", cleaned)) {
        return(NA_character_)
    }

    cleaned
}

#' Vectorized companions to format_genus_token() / format_epithet_token()
#'
#' Straight transliterations: every operation the scalars use (gsub, toupper,
#' tolower, substr, nchar, grepl) is already vectorized in base R, so no
#' unique/expand step is needed. Called per row the closure and dispatch overhead
#' dominated; over a column it is a handful of vectorized passes. Names are
#' dropped, matching what the paste() at the call site expects.
#'
#' @param token Character vector of raw name tokens
#' @return Character vector the same length as the input, NA where the token has
#'   no usable letters
#' @noRd
format_genus_token_vec <- function(token) {
    values <- as.character(token)
    n <- length(values)
    out <- rep(NA_character_, n)
    if (n == 0L) {
        return(out)
    }

    keep <- !(is.na(values) | !nzchar(trimws(values)))
    if (!any(keep)) {
        return(out)
    }

    cleaned <- gsub("^[^A-Za-z]+|[^A-Za-z-]+$", "", values[keep])
    ok <- nzchar(cleaned)
    resolved <- rep(NA_character_, length(cleaned))
    resolved[ok] <- paste0(
        toupper(substr(cleaned[ok], 1, 1)),
        tolower(substr(cleaned[ok], 2, nchar(cleaned[ok])))
    )

    out[keep] <- resolved
    out
}

#' @rdname format_genus_token_vec
#' @noRd
format_epithet_token_vec <- function(token) {
    values <- as.character(token)
    n <- length(values)
    out <- rep(NA_character_, n)
    if (n == 0L) {
        return(out)
    }

    keep <- !(is.na(values) | !nzchar(trimws(values)))
    if (!any(keep)) {
        return(out)
    }

    cleaned <- tolower(gsub("^[^A-Za-z]+|[^A-Za-z-]+$", "", values[keep]))
    ok <- grepl("^[a-z][a-z-]*$", cleaned)
    resolved <- rep(NA_character_, length(cleaned))
    resolved[ok] <- cleaned[ok]

    out[keep] <- resolved
    out
}

# Taxon terms derived from scientificName by extract_scientific_name_components().
# The mapping cards lock these once scientificName is mapped, so the single list
# lives here rather than being spelled out at each card call site.
derived_taxon_terms <- function() {
    c("genus", "specificEpithet", "infraspecificEpithet", "taxonRank")
}

# Terms whose card is locked when scientificName is mapped. genus is excluded:
# it stays user-mappable because a dataset may carry a genus column that
# disagrees with the parsed name, and fill_missing_character_values() lets the
# mapped value win.
locked_taxon_terms <- function() {
    c("specificEpithet", "infraspecificEpithet", "taxonRank")
}

# Rank markers that may introduce an infraspecific epithet, mapped to the DwC
# taxonRank each one implies.
infraspecific_rank_markers <- function() {
    c(
        "subsp" = "subspecies", "subsp." = "subspecies",
        "ssp" = "subspecies", "ssp." = "subspecies",
        "var" = "variety", "var." = "variety",
        "f" = "form", "f." = "form", "forma" = "form"
    )
}

# The marker as the name writes it, for each taxonRank.
infraspecific_marker_text <- c(subspecies = "subsp.", variety = "var.", form = "f.")

# Words that sit where an epithet goes but name no taxon: a qualifier, a life
# stage, a sex. "Leopardus pardalis juvenile" is not a subspecies.
name_non_epithet_words <- c(
    "sp", "sp.", "spp", "spp.", "cf", "cf.", "aff", "aff.", "nr", "nr.", "x",
    "indet", "indet.", "juvenile", "juvenil", "jovem", "adult", "adulto",
    "adulta", "macho", "femea", "male", "female"
)

# Diacritics have no place in a scientific name (ICN Art. 60.6, ICZN Art. 27):
# "araraúna" is "ararauna" and "onça" is "onca". The old token filter cut the
# accented letter and sent the rest of the epithet to authorship.
fold_name_diacritics <- function(x) {
    chartr(
        paste0(
            "\u00e1\u00e0\u00e2\u00e3\u00e4\u00e9\u00e8\u00ea\u00eb\u00ed\u00ec\u00ee",
            "\u00ef\u00f3\u00f2\u00f4\u00f5\u00f6\u00fa\u00f9\u00fb\u00fc\u00e7\u00f1",
            "\u00c1\u00c0\u00c2\u00c3\u00c4\u00c9\u00c8\u00ca\u00cb\u00cd\u00cc\u00ce",
            "\u00cf\u00d3\u00d2\u00d4\u00d5\u00d6\u00da\u00d9\u00db\u00dc\u00c7\u00d1"
        ),
        "aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN",
        x
    )
}

# Values in a name column that are not a name. The parser leaves them blank
# and names validation ignores them, instead of genus "Null" or "Indet".
name_placeholder_re <- paste0(
    "^(null|nil|none|na|n/a|n\\.a\\.?|nd|n/d|s/i|-+|\\?+|\\.+|",
    "indet\\.?|indeterminad[oa]s?|indeterminate|nao identificad[oa]s?|",
    "sem identificacao|desconhecid[oa]s?|unidentified|unknown|",
    "[0-9 .,:/-]+)$"
)

# Leading words that make the rest a coarse identification:
# "unidentified Felidae" names Felidae.
name_unidentified_prefix_re <- "^(unidentified|indet\\.?|indeterminad[oa]|nao identificad[oa]) "

#' Classify a name cell before it is parsed
#'
#' @param x Character vector of scientificName values.
#' @return Character vector: "blank", "placeholder" (NULL, N/A, indet.,
#'   digits, a footer), "multiple" (two names joined by /, | or ;), "hybrid"
#'   (a formula with x or the multiplication sign), "abbreviated" ("P. onca")
#'   or "name".
#' @noRd
scientific_name_kind <- function(x) {
    v <- tolower(fold_name_diacritics(gsub("\\s+", " ", trimws(as.character(x)))))
    kind <- rep("name", length(v))
    kind[is.na(v) | !nzchar(v)] <- "blank"
    set_kind <- function(hit, label) {
        kind[kind == "name" & hit] <<- label
    }
    set_kind(grepl(name_placeholder_re, v) | grepl(":", v, fixed = TRUE), "placeholder")
    set_kind(grepl("[/|;]", v), "multiple")
    set_kind(grepl("(^| )x( |$)", v) | grepl("\u00d7", v, fixed = TRUE), "hybrid")
    set_kind(grepl("^[a-z]{1,2}\\. ", v), "abbreviated")
    kind
}

# A capitalised word after the genus is an author only with evidence: a
# trailing comma or period ("Oken, 1816", "L."), an apostrophe ("d'Orbigny"),
# or a year or connector next. Without it, it is an epithet typed with a
# capital ("Panthera Onca", "Mimus Saturninus (Lichtenstein, 1823)").
author_evidence <- function(tokens, i) {
    if (grepl("[,.]$|'", tokens[[i]])) return(TRUE)
    if (i < length(tokens)) {
        nxt <- tokens[[i + 1L]]
        if (grepl("^\\(?[0-9]{4}\\)?[,.;]?$", nxt)) return(TRUE)
        if (tolower(nxt) %in% c("&", "ex", "et", "and", "in")) return(TRUE)
    }
    FALSE
}

# A higher taxon given as one word goes to taxonRank, not to genus.
higher_rank_of <- function(word) {
    w <- tolower(word)
    if (grepl("(idae|aceae)$", w)) return("family")
    if (grepl("(inae|oideae)$", w)) return("subfamily")
    if (grepl("(formes|ales)$", w)) return("order")
    if (w %in% c("aves", "mammalia", "reptilia", "amphibia", "insecta",
                 "arachnida", "actinopterygii", "chondrichthyes", "magnoliopsida",
                 "liliopsida", "gastropoda", "bivalvia", "malacostraca")) {
        return("class")
    }
    if (w %in% c("chordata", "arthropoda", "mollusca", "annelida", "cnidaria",
                 "tracheophyta", "bryophyta")) {
        return("phylum")
    }
    if (w %in% c("animalia", "plantae", "fungi")) return("kingdom")
    NA_character_
}

# Text after the name that reads as an authorship: it opens with a capital,
# a bracket and a capital, or a surname particle, and holds only letters,
# digits and the usual punctuation. "(cultivado)", "[antigo]" and an emoji
# are not authorship.
plausible_authorship <- function(rest) {
    grepl("^\\(?([A-Z]|d'|de |da |do |du |van |von |la |le )", rest) &&
        grepl("^[[:alpha:][:space:].,&'()0-9-]+$", rest)
}

# Resolve the infraspecific part of a name from the tokens sitting after the
# specific epithet. Two shapes are accepted: an explicit marker plus an epithet
# ("Puma concolor subsp. concolor") and the bare trinomial the zoological code
# uses ("Dasypus septemcinctus hybridus").
#
# The bare form has to be told apart from authorship, which occupies the same
# position: "Dasypus novemcinctus Linnaeus, 1758". Only a token starting with a
# lowercase letter and made of letters/hyphen counts as an epithet.
# format_epithet_token() cannot make that call because it lowercases before
# validating, so "Linnaeus" would sail through it.
extract_infraspecific_part <- function(tokens, start) {
    if (length(tokens) < start) {
        return(NULL)
    }

    markers <- infraspecific_rank_markers()
    marker_idx <- match(tolower(tokens[[start]]), names(markers))
    if (!is.na(marker_idx)) {
        if (length(tokens) < start + 1L) {
            return(NULL)
        }
        epithet <- format_epithet_token(tokens[[start + 1L]])
        if (is.na(epithet)) {
            return(NULL)
        }
        rank <- unname(markers[[marker_idx]])
        return(list(
            infraspecificEpithet = epithet,
            taxonRank = rank,
            marker = unname(infraspecific_marker_text[[rank]])
        ))
    }

    if (!grepl("^[a-z][a-z-]*$", tokens[[start]]) ||
        tolower(tokens[[start]]) %in% name_non_epithet_words) {
        return(NULL)
    }
    epithet <- format_epithet_token(tokens[[start]])
    if (is.na(epithet)) {
        return(NULL)
    }
    list(infraspecificEpithet = epithet, taxonRank = "subspecies", marker = NA_character_)
}

extract_scientific_name_components <- function(scientific_names) {
    # Parse over UNIQUE names and expand back: the genus/epithet/rank of a row
    # depends only on its scientificName, and a dataset repeats a handful of
    # species across thousands of rows (camera traps especially). The per-name
    # regex (gsub/sub/trimws via format_*_token) is otherwise the dominant cost
    # of build_processed_mapping_df. (LESSONS: unique -> resolve -> match back.)
    sn <- as.character(scientific_names)
    if (length(sn) > 1L) {
        u <- unique(sn)
        if (length(u) < length(sn)) {
            res_u <- extract_scientific_name_components(u)
            out <- res_u[match(sn, u), , drop = FALSE]
            rownames(out) <- NULL
            return(out)
        }
    }

    unknown_markers <- c("sp", "sp.", "spp", "spp.")
    qualifier_markers <- c("cf", "cf.", "aff", "aff.", "nr", "nr.")
    fields <- c(
        "genus", "specificEpithet", "infraspecificEpithet", "taxonRank",
        "scientificNameAuthorship", "identificationQualifier", "canonicalName",
        "nameIssue"
    )
    blank_result <- stats::setNames(as.list(rep(NA_character_, length(fields))), fields)

    # An epithet and a bare author occupy the same position ("Panthera onca" vs
    # "Panthera Oken, 1816"), and format_epithet_token() cannot judge because it
    # lowercases before validating (ADR-119). Capitalisation decides, but only
    # where it carries information: a name shouted in caps ("PANTHERA ONCA") is
    # routine in spreadsheets, so an all-caps token stays an epithet. A token
    # capitalised the way a surname is - initial capital, lowercase after - is
    # authorship when author_evidence() finds a comma, a year or a connector.
    looks_like_author <- function(tokens, i) {
        token <- tokens[[i]]
        grepl("^[A-Z]", token) && !identical(token, toupper(token)) &&
            author_evidence(tokens, i)
    }

    # canonicalName is the name without authorship. It is NA when the text
    # after the name is not an authorship: the cell then keeps the value as
    # typed, and Preview shows the issue.
    make_result <- function(genus, specific = NA_character_, infra = NULL,
                            rank, rest = NA_character_, qualifier = NA_character_,
                            uninomial = NA_character_) {
        out <- blank_result
        out$genus <- genus
        out$specificEpithet <- specific
        out$infraspecificEpithet <- if (is.null(infra)) NA_character_ else infra$infraspecificEpithet
        out$taxonRank <- rank
        out$identificationQualifier <- qualifier
        marker <- if (is.null(infra)) NA_character_ else infra$marker
        pieces <- c(uninomial, genus, specific, marker, out$infraspecificEpithet)
        out$canonicalName <- paste(pieces[!is.na(pieces)], collapse = " ")
        if (!is.na(rest)) {
            if (!plausible_authorship(rest)) {
                out$nameIssue <- "extra_text"
                out$canonicalName <- NA_character_
                return(out)
            }
            # A shouted authorship ("(LINNAEUS, 1758)") gets the usual case.
            if (identical(rest, toupper(rest))) {
                rest <- gsub("\\b([A-Z])([A-Z]+)\\b", "\\1\\L\\2", rest, perl = TRUE)
            }
            opens <- lengths(regmatches(rest, gregexpr("(", rest, fixed = TRUE)))
            closes <- lengths(regmatches(rest, gregexpr(")", rest, fixed = TRUE)))
            if (opens != closes) out$nameIssue <- "authorship"
            out$scientificNameAuthorship <- rest
        }
        out
    }

    # Whatever follows the name itself is the authorship: "(Linnaeus, 1758)" or
    # a bare "Linnaeus, 1771". `start` is the first token the name did not
    # consume, so this never has to recognise an author -- it only collects what
    # the epithet rules already refused (ADR-119). It reads the typed tokens, so
    # "Müller" keeps its accent.
    rest_from <- function(raw_tokens, start) {
        if (length(raw_tokens) < start) {
            return(NA_character_)
        }
        rest <- trimws(paste(raw_tokens[start:length(raw_tokens)], collapse = " "))
        if (!nzchar(rest)) NA_character_ else rest
    }

    qualifier_text <- function(token) paste0(sub("\\.$", "", tolower(token)), ".")
    join_qualifier <- function(a, b) {
        q <- c(a, b)
        q <- q[!is.na(q)]
        if (length(q) == 0L) NA_character_ else paste(q, collapse = " ")
    }

    parse_one <- function(value) {
        if (is_blank_value(value)) {
            return(blank_result)
        }
        raw <- gsub("\\s+", " ", trimws(as.character(value)))
        kind <- scientific_name_kind(raw)
        if (kind == "blank") {
            return(blank_result)
        }
        if (kind != "name") {
            out <- blank_result
            out$nameIssue <- kind
            return(out)
        }

        doubt <- NA_character_
        if (grepl("\\?$", raw)) {
            doubt <- "?"
            raw <- trimws(sub("\\?+$", "", raw))
        }
        # fold_name_diacritics() keeps the character count, so the prefix
        # found on the folded text has the same length in the typed text.
        prefix <- regmatches(
            tolower(fold_name_diacritics(raw)),
            regexpr(name_unidentified_prefix_re, tolower(fold_name_diacritics(raw)))
        )
        if (length(prefix) == 1L) raw <- substr(raw, nchar(prefix) + 1L, nchar(raw))

        raw_tokens <- strsplit(raw, " ", fixed = TRUE)[[1]]
        raw_tokens <- raw_tokens[nzchar(raw_tokens)]
        if (length(raw_tokens) == 0L) {
            return(blank_result)
        }
        tokens <- fold_name_diacritics(raw_tokens)

        if (tolower(tokens[[1]]) %in% unknown_markers) {
            return(blank_result)
        }
        genus <- format_genus_token(tokens[[1]])
        if (is.na(genus)) {
            return(blank_result)
        }

        # `start` is the first token the genus did not account for, so a name
        # given at genus rank still yields its author ("Panthera Oken, 1816").
        genus_only <- function(start, qualifier = doubt) {
            rank <- higher_rank_of(genus)
            if (!is.na(rank)) {
                return(make_result(NA_character_, rank = rank,
                                   rest = rest_from(raw_tokens, start),
                                   qualifier = qualifier, uninomial = genus))
            }
            make_result(genus, rank = "genus", rest = rest_from(raw_tokens, start),
                        qualifier = qualifier)
        }

        if (length(tokens) == 1) {
            return(genus_only(2L))
        }

        second_lower <- tolower(tokens[[2]])
        if (second_lower %in% unknown_markers) {
            # "Panthera sp." names no species. The marker and what follows it
            # ("sp. nov. 1", "sp. (cultivado)") are the identification
            # qualifier, not authorship.
            q <- paste(raw_tokens[2:length(raw_tokens)], collapse = " ")
            return(make_result(genus, rank = "genus", qualifier = join_qualifier(q, doubt)))
        }

        epithet_at <- 2L
        qualifier <- NA_character_
        if (second_lower %in% qualifier_markers) {
            if (length(tokens) < 3) {
                return(genus_only(3L, qualifier = join_qualifier(qualifier_text(tokens[[2]]), doubt)))
            }
            qualifier <- qualifier_text(tokens[[2]])
            epithet_at <- 3L
        }
        qualifier_all <- join_qualifier(qualifier, doubt)

        if (looks_like_author(tokens, epithet_at)) {
            return(genus_only(epithet_at, qualifier = qualifier_all))
        }
        specific <- format_epithet_token(tokens[[epithet_at]])
        if (is.na(specific) || tolower(tokens[[epithet_at]]) %in% name_non_epithet_words) {
            return(genus_only(epithet_at, qualifier = qualifier_all))
        }

        start <- epithet_at + 1L
        infra <- extract_infraspecific_part(tokens, start)
        # An infraspecific epithet consumes tokens; authorship is whatever sits
        # after it. The marker form ("subsp. concolor") consumes two.
        if (!is.null(infra)) {
            start <- start + if (is.na(infra$marker)) 1L else 2L
        }
        # A qualifier typed after the name ("Panthera onca cf").
        if (length(tokens) >= start && tolower(tokens[[start]]) %in% qualifier_markers) {
            qualifier_all <- join_qualifier(qualifier_text(tokens[[start]]), qualifier_all)
            start <- start + 1L
        }
        make_result(
            genus, specific, infra,
            rank = if (is.null(infra)) "species" else infra$taxonRank,
            rest = rest_from(raw_tokens, start),
            qualifier = qualifier_all
        )
    }

    parsed <- lapply(scientific_names, parse_one)

    pluck <- function(field) {
        vapply(parsed, function(x) x[[field]], FUN.VALUE = character(1))
    }

    out <- lapply(fields, pluck)
    names(out) <- fields
    as.data.frame(out, stringsAsFactors = FALSE)
}

#' Rebuild the scientific name from its parsed parts, without authorship
#'
#' @param parts Data frame from `extract_scientific_name_components()`.
#' @return Character vector, `NA` where the name was not parsed or carries
#'   text that is not an authorship.
#' @noRd
scientific_name_without_authorship <- function(parts) {
    if (!is.data.frame(parts) || nrow(parts) == 0L) {
        return(character(0))
    }
    out <- as.character(parts$canonicalName)
    out[!is.na(out) & !nzchar(out)] <- NA_character_
    out
}

