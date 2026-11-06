# Utils publication check
#
# Compares the archive sent to the IPT with what the portal shows. A portal can
# lose records during ingestion with no error on the IPT side: the SiBBr portal
# showed 195 fewer Neotropical Carnivores records than the archive had. Both
# portals list the occurrenceID values of a dataset in public, with no login.

GBIF_OCCURRENCE_SEARCH <- "https://api.gbif.org/v1/occurrence/search"
SIBBR_OCCURRENCE_SEARCH <- "https://biocache-service.sibbr.gov.br/biocache-service/occurrences/search"
# One facet page of 5,000 IDs takes about 5 s on both portals. A larger page
# made the SiBBr service time out (502) and then refuse requests for a while.
PUBLICATION_PAGE_SIZE <- 5000L
PUBLICATION_TIMEOUT_S <- 120

#' Compare a sent archive with the records a portal published
#'
#' Reads the `occurrenceID` of the archive that went to the IPT and the
#' `occurrenceID` the portal shows for the dataset, then lists the records
#' that did not arrive. The dataset key selects the portal: a GBIF dataset key
#' (UUID) or a SiBBr data resource uid (`dr` and a number). Both portals
#' answer without a login. A portal error stops the check, because a partial
#' list of IDs would report records as missing when they are not.
#'
#' @param archive Path to the Darwin Core Archive that was sent: the `.zip`
#'   file or its unzipped folder. The folder must hold `meta.xml`.
#' @param dataset GBIF dataset key or SiBBr data resource uid.
#' @return A list with `portal` (`"gbif"` or `"sibbr"`), `dataset`, `sent`
#'   (rows in the archive core), `published` (records the portal counts),
#'   `missing` (archive IDs the portal does not show) and `unexpected` (portal
#'   IDs the archive does not have).
#' @examples
#' \dontrun{
#' res <- check_publication("neotropical-carnivores.zip", "dr1451")
#' res$missing
#' }
#' @export
check_publication <- function(archive, dataset) {
    portal <- publication_portal(dataset)
    sent <- read_archive_occurrence_ids(archive)
    ids <- unique(sent[!is.na(sent) & nzchar(sent)])
    published <- published_occurrence_ids(portal, dataset)
    list(
        portal = portal,
        dataset = dataset,
        sent = length(sent),
        published = attr(published, "count"),
        missing = setdiff(ids, published),
        unexpected = setdiff(published, ids)
    )
}

publication_portal <- function(dataset) {
    key <- trimws(as.character(dataset))
    uuid <- "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
    if (length(key) == 1L && grepl(uuid, key, ignore.case = TRUE)) return("gbif")
    if (length(key) == 1L && grepl("^dr[0-9]+$", key)) return("sibbr")
    stop("check_publication: 'dataset' must be a GBIF dataset key (UUID) ",
         "or a SiBBr data resource uid such as 'dr1451'.", call. = FALSE)
}

# The occurrenceID column of the archive core, as meta.xml describes it. An
# IPT archive uses tabs with no quotes and keeps the ID in a column apart from
# the <id> one, so the file layout comes from meta.xml, never from a guess.
read_archive_occurrence_ids <- function(archive) {
    if (!file.exists(archive)) {
        stop("check_publication: archive not found: ", archive, call. = FALSE)
    }
    dir <- archive
    if (!dir.exists(archive)) {
        dir <- tempfile("saira_check_")
        on.exit(unlink(dir, recursive = TRUE), add = TRUE)
        zip::unzip(archive, exdir = dir)
    }
    meta_path <- file.path(dir, "meta.xml")
    if (!file.exists(meta_path)) {
        stop("check_publication: the archive has no meta.xml.", call. = FALSE)
    }

    meta <- xml2::read_xml(meta_path)
    core <- xml2::xml_find_first(meta, "//*[local-name()='core']")
    location <- xml2::xml_text(xml2::xml_find_first(core, ".//*[local-name()='location']"))
    terms <- xml2::xml_attr(xml2::xml_find_all(core, "./*[local-name()='field']"), "term")
    indexes <- xml2::xml_attr(xml2::xml_find_all(core, "./*[local-name()='field']"), "index")
    index <- indexes[match("http://rs.tdwg.org/dwc/terms/occurrenceID", terms)]
    if (is.na(index)) {
        index <- xml2::xml_attr(xml2::xml_find_first(core, "./*[local-name()='id']"), "index")
    }
    if (is.na(location) || is.na(index)) {
        stop("check_publication: meta.xml declares no occurrenceID column.", call. = FALSE)
    }

    unescape <- function(x) {
        if (is.na(x)) x <- ""
        x <- gsub("\\t", "\t", x, fixed = TRUE)
        gsub("\\n", "\n", x, fixed = TRUE)
    }
    delim <- unescape(xml2::xml_attr(core, "fieldsTerminatedBy"))
    quote <- unescape(xml2::xml_attr(core, "fieldsEnclosedBy"))
    skip <- suppressWarnings(as.integer(xml2::xml_attr(core, "ignoreHeaderLines")))
    encoding <- xml2::xml_attr(core, "encoding")

    ids <- readr::read_delim(
        file.path(dir, location),
        delim = if (nzchar(delim)) delim else ",",
        quote = quote,
        col_names = FALSE,
        col_select = as.integer(index) + 1L,
        col_types = readr::cols(.default = readr::col_character()),
        skip = if (is.na(skip)) 0L else skip,
        na = character(0),
        locale = readr::locale(encoding = if (is.na(encoding)) "UTF-8" else encoding),
        progress = FALSE
    )[[1]]
    trimws(ids)
}

# Every occurrenceID the portal shows for the dataset, read in facet pages.
# The attribute `count` is the number of records the portal counts.
published_occurrence_ids <- function(portal, dataset) {
    pages <- list()
    offset <- 0L
    repeat {
        page <- publication_id_page(portal, dataset, offset)
        pages[[length(pages) + 1L]] <- page$ids
        if (length(page$ids) < PUBLICATION_PAGE_SIZE) break
        offset <- offset + PUBLICATION_PAGE_SIZE
    }
    structure(unique(unlist(pages, use.names = FALSE)), count = page$count)
}

# One page of the occurrenceID facet. GBIF caps record paging at 100,000, but
# not facet paging, so both portals take the same path at any dataset size.
publication_id_page <- function(portal, dataset, offset) {
    if (identical(portal, "gbif")) {
        req <- httr2::request(GBIF_OCCURRENCE_SEARCH) |>
            httr2::req_url_query(
                datasetKey = dataset, limit = 0L, facet = "occurrenceId",
                occurrenceId.facetLimit = PUBLICATION_PAGE_SIZE,
                occurrenceId.facetOffset = offset
            )
    } else {
        req <- httr2::request(SIBBR_OCCURRENCE_SEARCH) |>
            httr2::req_url_query(
                q = paste0("data_resource_uid:", dataset), pageSize = 0L,
                facets = "occurrence_id", flimit = PUBLICATION_PAGE_SIZE,
                foffset = offset, fsort = "index"
            )
    }
    body <- req |>
        httr2::req_timeout(PUBLICATION_TIMEOUT_S) |>
        httr2::req_user_agent("saira R package") |>
        httr2::req_retry(max_tries = 3L) |>
        httr2::req_perform() |>
        httr2::resp_body_json()

    if (identical(portal, "gbif")) {
        values <- if (length(body$facets)) body$facets[[1]]$counts else list()
        list(count = body$count, ids = vapply(values, `[[`, character(1), "name"))
    } else {
        values <- if (length(body$facetResults)) body$facetResults[[1]]$fieldResult else list()
        list(count = body$totalRecords, ids = vapply(values, `[[`, character(1), "label"))
    }
}
