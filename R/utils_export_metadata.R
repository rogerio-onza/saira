# Utils export metadata

# Dublin Core terms used in DwC (everything else lives under dwc:).
.dc_terms <- c(
    "type", "modified", "language", "license", "rights", "rightsHolder",
    "accessRights", "bibliographicCitation", "references"
)

# Audiovisual Core terms recommended by DwC. fundingAttribution is organised
# under the Provenance class but its authoritative IRI is ac:, not dwc:.
.ac_terms <- c("fundingAttribution")

#' Map a DwC/DC column name to its full term URI
#'
#' @param column Character vector of column names.
#' @return Character vector of term URIs, NA where the column is not a
#'   recognized DwC or DC term.
#' @export
dwc_term_uri <- function(column) {
    catalog <- tryCatch(get_dwc_full_catalog(), error = function(e) NULL)
    known <- if (is.data.frame(catalog)) as.character(catalog$term) else character(0)

    out <- ifelse(
        column %in% .dc_terms,
        paste0("http://purl.org/dc/terms/", column),
        ifelse(
            column %in% .ac_terms,
            paste0("http://rs.tdwg.org/ac/terms/", column),
            ifelse(
                column %in% known,
                paste0("http://rs.tdwg.org/dwc/terms/", column),
                NA_character_
            )
        )
    )
    out
}

#' Build a Darwin Core Archive meta.xml descriptor
#'
#' Generates the DwC-A `meta.xml` document describing the `occurrence.txt`
#' core file. Only columns recognized as DwC or Dublin Core terms get a
#' `<field>` declaration; extras stay in the CSV but are not declared (GBIF
#' will ignore them per spec).
#'
#' @param df Data frame whose columns describe the rows that will be written
#'   to `occurrence.txt`.
#' @param core_filename Name of the core CSV file referenced by `meta.xml`.
#'   Default `"occurrence.txt"`.
#' @return Character scalar containing the serialized XML document.
#' @export
build_meta_xml <- function(df, core_filename = "occurrence.txt") {
    if (!is.data.frame(df)) stop("build_meta_xml: 'df' must be a data.frame.")

    cols <- names(df)
    uris <- dwc_term_uri(cols)

    doc <- xml2::xml_new_root(
        "archive",
        xmlns = "http://rs.tdwg.org/dwc/text/",
        metadata = "eml.xml"
    )
    core <- xml2::xml_add_child(
        doc, "core",
        encoding = "UTF-8",
        fieldsTerminatedBy = ",",
        linesTerminatedBy = "\\n",
        fieldsEnclosedBy = "\"",
        ignoreHeaderLines = "1",
        rowType = "http://rs.tdwg.org/dwc/terms/Occurrence"
    )
    files <- xml2::xml_add_child(core, "files")
    xml2::xml_add_child(files, "location", core_filename)

    id_idx <- match("occurrenceID", cols)
    if (!is.na(id_idx)) {
        xml2::xml_add_child(core, "id", index = as.character(id_idx - 1L))
    }

    for (i in seq_along(cols)) {
        if (is.na(uris[i])) next
        xml2::xml_add_child(
            core, "field",
            index = as.character(i - 1L),
            term = uris[i]
        )
    }

    as.character(doc)
}

#' Compute geographic and temporal extents for EML coverage
#'
#' Reads `decimalLatitude`/`decimalLongitude` for the geographic bounding box
#' and `eventDate` for the temporal range. Placeholder points and future dates
#' are skipped. Returns NA for any extent that cannot be derived from the data.
#'
#' @param df Data frame.
#' @return Named list with `bbox` (named numeric vector: west/east/north/south)
#'   and `dates` (named character vector: begin/end, ISO YYYY-MM-DD).
#' @export
compute_dataset_extents <- function(df) {
    bbox <- c(west = NA_real_, east = NA_real_, north = NA_real_, south = NA_real_)
    if (all(c("decimalLatitude", "decimalLongitude") %in% names(df))) {
        lat <- suppressWarnings(as.numeric(df$decimalLatitude))
        lon <- suppressWarnings(as.numeric(df$decimalLongitude))
        # The same test the mask uses, so (0,0) and a lat == lon placeholder
        # do not stretch the box. A pole or antimeridian corner is a filler
        # value, not a collecting site (B41).
        valid <- sensitive_point_ok(lat, lon) & abs(lat) < 90 & abs(lon) < 180
        if (any(valid)) {
            bbox[["west"]]  <- min(lon[valid])
            bbox[["east"]]  <- max(lon[valid])
            bbox[["north"]] <- max(lat[valid])
            bbox[["south"]] <- min(lat[valid])
        }
    }

    dates <- c(begin = NA_character_, end = NA_character_)
    if ("eventDate" %in% names(df)) {
        raw <- trimws(as.character(df$eventDate))
        raw <- raw[!is.na(raw) & nzchar(raw) & is_dwc_date_value(raw)]
        # An interval counts by both ends, and "2020" or "2020-05" by the
        # first and last day it covers (B53).
        parts <- strsplit(raw, "/", fixed = TRUE)
        start <- vapply(parts, `[`, character(1), 1L)
        end <- vapply(parts, function(p) p[length(p)], character(1))
        end <- expand_interval_end(start, end)
        parsed <- c(iso_date_bound(start, last = FALSE), iso_date_bound(end, last = TRUE))
        # A future date is a typing error, and it must not end the coverage.
        parsed[!is.na(parsed) & parsed > Sys.Date()] <- NA
        if (any(!is.na(parsed))) {
            dates[["begin"]] <- format(min(parsed, na.rm = TRUE), "%Y-%m-%d")
            dates[["end"]]   <- format(max(parsed, na.rm = TRUE), "%Y-%m-%d")
        }
    }

    list(bbox = bbox, dates = dates)
}

# The first (or last) day an ISO date covers: "2020" -> 2020-01-01 or
# 2020-12-31, "2020-02" -> 2020-02-01 or 2020-02-29. The time part is dropped.
iso_date_bound <- function(x, last) {
    x <- substr(x, 1L, 10L)
    out <- suppressWarnings(as.Date(x, format = "%Y-%m-%d"))
    out[!grepl("^\\d{4}-\\d{2}-\\d{2}$", x)] <- NA
    month <- grepl("^\\d{4}-\\d{2}$", x)
    year <- grepl("^\\d{4}$", x)
    first <- suppressWarnings(as.Date(paste0(x[month], "-01"), format = "%Y-%m-%d"))
    out[month] <- if (last) as.Date(format(first + 31L, "%Y-%m-01")) - 1L else first
    out[year] <- as.Date(paste0(x[year], if (last) "-12-31" else "-01-01"), format = "%Y-%m-%d")
    out
}

# Escape text for safe insertion into XML content or a double-quoted attribute.
.xml_escape <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    gsub("\"", "&quot;", x, fixed = TRUE)
}

# Build the <intellectualRights> element for a chosen license, following the
# GBIF/IPT convention: a <para> with a <ulink url><citetitle> naming the
# license. Accepts either the short token ("CC-BY-4.0") or the full Creative
# Commons URL the mapping card stores. Only the three GBIF-accepted licenses
# (CC0 1.0, CC-BY 4.0, CC-BY-NC 4.0) get a canonical statement; any other value
# is cited verbatim so the EML never silently claims CC0/public domain for a
# dataset the publisher licensed differently. Returns a serialized XML string.
build_intellectual_rights_xml <- function(license_value) {
    key <- normalize_license_key(license_value)
    uris <- cc_license_uris()

    para <- if (identical(key, "CC0")) {
        paste0(
            "<para>To the extent possible under law, the publisher has waived ",
            "all rights to these data and has dedicated them to the ",
            "<ulink url=\"", uris[["CC0"]], "\">",
            "<citetitle>Public Domain (CC0 1.0)</citetitle></ulink>. Users may ",
            "copy, modify, distribute and use the work, including for commercial ",
            "purposes, without restriction.</para>"
        )
    } else if (identical(key, "CC-BY")) {
        paste0(
            "<para>This work is licensed under a ",
            "<ulink url=\"", uris[["CC-BY"]], "\">",
            "<citetitle>Creative Commons Attribution (CC-BY) 4.0 License</citetitle>",
            "</ulink>.</para>"
        )
    } else if (identical(key, "CC-BY-NC")) {
        paste0(
            "<para>This work is licensed under a ",
            "<ulink url=\"", uris[["CC-BY-NC"]], "\">",
            "<citetitle>Creative Commons Attribution Non Commercial (CC-BY-NC) 4.0 License</citetitle>",
            "</ulink>.</para>"
        )
    } else {
        val <- trimws(as.character(license_value))
        esc <- .xml_escape(val)
        if (grepl("^https?://", val)) {
            paste0(
                "<para>This work is released under the license at ",
                "<ulink url=\"", esc, "\"><citetitle>", esc,
                "</citetitle></ulink>.</para>"
            )
        } else {
            paste0("<para>This work is released under the following license: ",
                   esc, ".</para>")
        }
    }

    paste0("<intellectualRights>", para, "</intellectualRights>")
}

#' Build an EML 2.2.0 dataset descriptor for a Saira export
#'
#' Produces a minimal-but-valid EML document with required GBIF/IPT fields:
#' title, creator, contact, pubDate, abstract, intellectualRights, and
#' coverage (geographic + temporal). Geographic and temporal coverage are
#' computed automatically from the data via `compute_dataset_extents()`;
#' callers supply the editable fields (title/creator/license/abstract) via
#' `metadata`.
#'
#' @param df Data frame that will become `occurrence.txt`.
#' @param metadata Named list with optional entries: `title` (string),
#'   `creator` (named list with `name`, `email`, `organization`), `license`
#'   (string, default `"CC0-1.0"`), `abstract` (string).
#' @param package_id Optional UUID for the EML packageId; defaults to a
#'   freshly generated UUID.
#' @return Character scalar containing the serialized EML document.
#' @export
build_eml_xml <- function(df, metadata = list(), package_id = NULL) {
    ext <- compute_dataset_extents(df)

    title <- metadata$title %||% paste0("Saira export ", format(Sys.Date(), "%Y-%m-%d"))
    creator <- metadata$creator %||% list(name = "", email = "", organization = "")
    creator$name         <- creator$name         %||% ""
    creator$email        <- creator$email        %||% ""
    creator$organization <- creator$organization %||% ""
    # Reflect the license the user chose in the mapping (default CC0 only when
    # no license was set). Mapped to the GBIF/IPT intellectualRights form below.
    license  <- metadata$license  %||% "CC0-1.0"
    abstract <- metadata$abstract %||% sprintf(
        "Biodiversity occurrence dataset standardized to Darwin Core via Saira v%s.",
        utils::packageVersion("saira")
    )
    pkg_id <- package_id %||% paste0("urn:uuid:", uuid::UUIDgenerate())

    # Split creator name into given/sur for EML structure.
    name_parts <- strsplit(trimws(creator$name), "\\s+")[[1]]
    if (length(name_parts) == 0L) {
        given <- ""
        sur   <- ""
    } else if (length(name_parts) == 1L) {
        given <- name_parts[1L]
        sur   <- ""
    } else {
        given <- paste(name_parts[-length(name_parts)], collapse = " ")
        sur   <- name_parts[length(name_parts)]
    }

    doc <- xml2::xml_new_root(
        "eml:eml",
        "xmlns:eml" = "https://eml.ecoinformatics.org/eml-2.2.0",
        "xmlns:dc"  = "http://purl.org/dc/terms/",
        "xmlns:xsi" = "http://www.w3.org/2001/XMLSchema-instance",
        "xsi:schemaLocation" = "https://eml.ecoinformatics.org/eml-2.2.0 https://eml.ecoinformatics.org/eml-2.2.0/eml.xsd",
        packageId = pkg_id,
        system = "saira",
        scope = "system",
        "xml:lang" = "eng"
    )
    ds <- xml2::xml_add_child(doc, "dataset")
    title_el <- xml2::xml_add_child(ds, "title", title)
    xml2::xml_set_attr(title_el, "xml:lang", "eng")

    cr <- xml2::xml_add_child(ds, "creator")
    ind <- xml2::xml_add_child(cr, "individualName")
    if (nzchar(given)) xml2::xml_add_child(ind, "givenName", given)
    if (nzchar(sur))   xml2::xml_add_child(ind, "surName", sur)
    if (!nzchar(given) && !nzchar(sur)) xml2::xml_add_child(ind, "surName", "Unknown")
    if (nzchar(creator$organization)) {
        xml2::xml_add_child(cr, "organizationName", creator$organization)
    }
    if (nzchar(creator$email)) {
        xml2::xml_add_child(cr, "electronicMailAddress", creator$email)
    }

    xml2::xml_add_child(ds, "pubDate", format(Sys.Date(), "%Y-%m-%d"))

    abs_el <- xml2::xml_add_child(ds, "abstract")
    xml2::xml_add_child(abs_el, "para", abstract)

    # Access constraints for generalized sensitive records (Chapman 2020 sec.
    # 5.1). Emitted only when the export actually masked rows. Placed before
    # intellectualRights to honour the EML 2.2.0 resource sequence.
    sens <- metadata$sensitivity
    if (is.list(sens) && !is.null(sens$n_masked) && sens$n_masked > 0L) {
        review <- sens$review_date %||% format(Sys.Date() + 730, "%Y-%m-%d")
        note <- sprintf(
            tr("sensitive_eml_access_note", sens$lang %||% "en"),
            sens$n_masked, review
        )
        ai_el <- xml2::xml_add_child(ds, "additionalInfo")
        xml2::xml_add_child(ai_el, "para", note)
    }

    xml2::xml_add_child(ds, xml2::read_xml(build_intellectual_rights_xml(license)))

    cov <- xml2::xml_add_child(ds, "coverage")
    if (all(is.finite(ext$bbox))) {
        geo <- xml2::xml_add_child(cov, "geographicCoverage")
        xml2::xml_add_child(geo, "geographicDescription",
            "Bounding box computed from decimalLatitude/decimalLongitude.")
        bc <- xml2::xml_add_child(geo, "boundingCoordinates")
        xml2::xml_add_child(bc, "westBoundingCoordinate",
            format(ext$bbox[["west"]], nsmall = 6))
        xml2::xml_add_child(bc, "eastBoundingCoordinate",
            format(ext$bbox[["east"]], nsmall = 6))
        xml2::xml_add_child(bc, "northBoundingCoordinate",
            format(ext$bbox[["north"]], nsmall = 6))
        xml2::xml_add_child(bc, "southBoundingCoordinate",
            format(ext$bbox[["south"]], nsmall = 6))
    }
    if (!is.na(ext$dates[["begin"]]) && !is.na(ext$dates[["end"]])) {
        tmp <- xml2::xml_add_child(cov, "temporalCoverage")
        if (ext$dates[["begin"]] == ext$dates[["end"]]) {
            sd <- xml2::xml_add_child(tmp, "singleDateTime")
            xml2::xml_add_child(sd, "calendarDate", ext$dates[["begin"]])
        } else {
            rd <- xml2::xml_add_child(tmp, "rangeOfDates")
            bd <- xml2::xml_add_child(rd, "beginDate")
            xml2::xml_add_child(bd, "calendarDate", ext$dates[["begin"]])
            ed <- xml2::xml_add_child(rd, "endDate")
            xml2::xml_add_child(ed, "calendarDate", ext$dates[["end"]])
        }
    }

    # Contact mirrors the creator block. The dataset sequence puts contact
    # before methods.
    ct <- xml2::xml_add_child(ds, "contact")
    ct_ind <- xml2::xml_add_child(ct, "individualName")
    if (nzchar(given)) xml2::xml_add_child(ct_ind, "givenName", given)
    xml2::xml_add_child(ct_ind, "surName", if (nzchar(sur)) sur else "Unknown")
    if (nzchar(creator$organization)) {
        xml2::xml_add_child(ct, "organizationName", creator$organization)
    }
    if (nzchar(creator$email)) {
        xml2::xml_add_child(ct, "electronicMailAddress", creator$email)
    }

    methods <- xml2::xml_add_child(ds, "methods")
    ms <- xml2::xml_add_child(methods, "methodStep")
    desc <- xml2::xml_add_child(ms, "description")
    xml2::xml_add_child(desc, "para", sprintf(
        "Dataset prepared with Saira v%s (https://github.com/rogerio-onza/saira). Fields validated and mapped to Darwin Core; coordinates checked with CoordinateCleaner; taxonomy reconciled against the Catalogue of Life (COL XR) through the GBIF API.",
        utils::packageVersion("saira")
    ))

    as.character(doc)
}

