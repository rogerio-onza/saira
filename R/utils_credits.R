# Title: Credits for the Help tab
# Author: Rogerio Nunes Oliveira
# Date: 2026-10-05
# Version: 1.0
#
# The author, the citation and the R packages come from the installed
# DESCRIPTION files, so the Help tab cannot drift from the package (ADR-146).

#' R packages of the Help tab, by group
#'
#' Each name is a group key for \code{help_pkg_group_<key>} in i18n.json.
#' Every package has a purpose in \code{help_pkg_<lowercase name>}.
#'
#' @return Named list of character vectors.
#' @noRd
credits_package_groups <- function() {
    list(
        ui = c("shiny", "bslib", "htmltools", "htmlwidgets", "DT", "leaflet"),
        io = c("readr", "readxl", "writexl", "zip", "xml2", "jsonlite"),
        taxonomy = c("taxadb", "florabr", "faunabr"),
        coords = c(
            "CoordinateCleaner", "sf", "terra", "countrycode",
            "rnaturalearth", "rnaturalearthdata"
        ),
        utils = c("stringr", "digest", "uuid", "withr", "DBI", "RSQLite"),
        camtrap = "camtrapdp"
    )
}

#' Version, maintainer and home page of one R package
#'
#' @param pkg Package name.
#' @return List with \code{name}, \code{version} and \code{maintainer}
#'   (\code{NA} when the package is not installed) and \code{href}.
#' @noRd
credits_package_meta <- function(pkg) {
    # A package that is not installed gives NA and a warning.
    desc <- suppressWarnings(utils::packageDescription(pkg, fields = c("Version", "Maintainer")))
    installed <- is.list(desc)
    maintainer <- if (installed) desc$Maintainer else NA_character_
    if (!is.na(maintainer)) {
        maintainer <- trimws(gsub("\\s+", " ", gsub("<[^>]*>", "", maintainer)))
    }

    list(
        name = pkg,
        version = if (installed) desc$Version else NA_character_,
        maintainer = maintainer,
        href = if (identical(pkg, "faunabr")) {
            "https://github.com/wevertonbio/faunabr"
        } else {
            paste0("https://cran.r-project.org/package=", pkg)
        }
    )
}

#' Author, version and links of Saira
#'
#' @param desc A \code{packageDescription} of Saira. Tests give a list.
#' @return List with \code{given}, \code{family}, \code{name}, \code{initials},
#'   \code{email}, \code{title}, \code{version}, \code{license}, \code{repo},
#'   \code{issues} and \code{year}.
#' @noRd
credits_saira_meta <- function(desc = utils::packageDescription("saira")) {
    field <- function(name) {
        value <- desc[[name]]
        if (is.null(value) || is.na(value)) NA_character_ else trimws(gsub("\\s+", " ", value))
    }

    # Authors@R is R code. Only person() and c() are available to it.
    people <- eval(
        parse(text = field("Authors@R")),
        envir = list2env(list(person = utils::person, c = c), parent = emptyenv())
    )
    roles <- lapply(seq_along(people), function(i) people[i]$role)
    author <- people[which(vapply(roles, function(r) "cre" %in% r, logical(1)))[1]]

    given <- paste(author$given, collapse = " ")
    family <- paste(author$family, collapse = " ")
    family_words <- strsplit(family, " ", fixed = TRUE)[[1]]
    # The year of the build. A source checkout has no build date.
    built <- c(field("Date/Publication"), field("Date"), field("Packaged"))
    built <- built[!is.na(built)]

    list(
        given = given,
        family = family,
        name = paste(given, family),
        initials = toupper(paste0(substr(given, 1L, 1L), substr(family_words[length(family_words)], 1L, 1L))),
        email = author$email[1],
        title = field("Title"),
        version = field("Version"),
        license = field("License"),
        repo = strsplit(field("URL"), "\\s*,\\s*")[[1]][1],
        issues = field("BugReports"),
        year = if (length(built)) substr(built[1], 1L, 4L) else format(Sys.Date(), "%Y")
    )
}

#' Citation of Saira as plain text and as BibTeX
#'
#' @param meta Output of \code{credits_saira_meta()}.
#' @return List with \code{text} and \code{bibtex}.
#' @noRd
credits_citation <- function(meta) {
    title <- paste0("Sa\u00EDra: ", meta$title)
    text <- sprintf(
        "%s, %s. (%s). %s. R package version %s. %s",
        meta$family, substr(meta$given, 1L, 1L), meta$year, title, meta$version, meta$repo
    )
    # Braces keep the two-word family name as one name in BibTeX.
    bibtex <- paste0(
        "@Manual{saira,\n",
        "  title = {", title, "},\n",
        "  author = {", meta$given, " {", meta$family, "}},\n",
        "  year = {", meta$year, "},\n",
        "  note = {R package version ", meta$version, "},\n",
        "  url = {", meta$repo, "},\n",
        "}"
    )
    list(text = text, bibtex = bibtex)
}
