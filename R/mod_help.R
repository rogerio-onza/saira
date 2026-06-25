# Title: Help Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-23
# Version: 2.0

help_or_default <- function(value, default) {
    if (is.null(value) || !length(value) || all(is.na(value))) {
        return(default)
    }

    first <- trimws(as.character(value[[1]]))
    if (!nzchar(first)) {
        return(default)
    }

    first
}

help_get_author_meta <- function() {
    default_name <- "Rog\u00E9rio Nunes Oliveira"
    default_email <- "rogerio.onza@outlook.com"
    default_repo <- "https://github.com/rogerio-onza/saira"

    desc <- tryCatch(
        utils::packageDescription("saira"),
        error = function(e) NULL
    )

    version_value <- tryCatch(
        as.character(utils::packageVersion("saira")),
        error = function(e) {
            if (!is.null(desc)) {
                help_or_default(desc$Version, "0.1.0")
            } else {
                "0.1.0"
            }
        }
    )

    if (is.null(desc)) {
        return(list(
            name = default_name,
            email = default_email,
            github_repo = default_repo,
            initials = "RN",
            version = version_value
        ))
    }

    author_name <- help_or_default(desc$Author, default_name)
    if (grepl("^person\\(", author_name, perl = TRUE)) {
        author_name <- default_name
    }
    author_name <- gsub("\\s*\\[[^\\]]*\\]", "", author_name, perl = TRUE)
    author_name <- trimws(author_name)
    if (grepl("\u00C3", author_name, fixed = TRUE)) {
        author_name <- default_name
    }

    author_email <- default_email

    name_tokens <- unlist(strsplit(author_name, "\\s+"))
    name_tokens <- name_tokens[nzchar(name_tokens)]
    initials <- if (length(name_tokens) >= 2L) {
        toupper(paste0(substr(name_tokens[[1]], 1L, 1L), substr(name_tokens[[length(name_tokens)]], 1L, 1L)))
    } else if (length(name_tokens) == 1L) {
        toupper(substr(name_tokens[[1]], 1L, min(2L, nchar(name_tokens[[1]]))))
    } else {
        "FN"
    }

    list(
        name = author_name,
        email = author_email,
        github_repo = default_repo,
        initials = initials,
        version = version_value
    )
}

# Language-aware website URL for tutorials/FAQ pages.
help_site_url <- function(lang, path_pt, path_en) {
    base <- "https://rogerio-onza.github.io/saira"
    paste0(base, if (identical(lang, "en")) path_en else path_pt)
}

help_link_item <- function(link_item, lang) {
    shiny::tags$a(
        href = link_item$href,
        class = "help-link-item",
        target = "_blank",
        rel = "noopener noreferrer",
        `aria-label` = paste0(tr("a11y_help_external_link", lang), ": ", link_item$label),
        shiny::tags$span(
            class = paste("help-link-icon-wrap", paste0("help-link-icon-wrap--", link_item$theme)),
            shiny::tags$i(class = link_item$icon, `aria-hidden` = "true")
        ),
        shiny::tags$span(class = "help-link-text", link_item$label),
        shiny::tags$span(
            class = "help-link-arrow",
            shiny::tags$i(class = "fa-solid fa-arrow-up-right-from-square", `aria-hidden` = "true")
        )
    )
}

help_tutorials_card <- function(lang) {
    shiny::div(
        class = "help-resource-card help-tutorials-card",
        shiny::div(
            class = "help-resource-head",
            shiny::tags$i(class = "fa-solid fa-graduation-cap", `aria-hidden` = "true"),
            shiny::tags$h2(class = "help-resource-title", tr("help_tutorials_title", lang))
        ),
        shiny::p(class = "help-resource-body", tr("help_tutorials_body", lang)),
        shiny::tags$a(
            href = help_site_url(lang, "/tutoriais/", "/en/tutorials/"),
            class = "help-tutorials-button",
            target = "_blank",
            rel = "noopener noreferrer",
            shiny::tags$i(class = "fa-solid fa-arrow-up-right-from-square", `aria-hidden` = "true"),
            tr("help_tutorials_link", lang)
        )
    )
}

help_links_card <- function(lang) {
    links <- list(
        list(
            label = tr("help_links_dwc", lang),
            href = "https://dwc.tdwg.org/terms/",
            icon = "fa-solid fa-book-open",
            theme = "dwc"
        ),
        list(
            label = tr("help_links_sibbr", lang),
            href = "https://sibbr.gov.br/",
            icon = "fa-solid fa-leaf",
            theme = "sibbr"
        ),
        list(
            label = tr("help_links_gbif", lang),
            href = "https://www.gbif.org/darwin-core",
            icon = "fa-solid fa-globe",
            theme = "gbif"
        ),
        list(
            label = tr("help_links_issues", lang),
            href = "https://github.com/rogerio-onza/saira/issues",
            icon = "fa-brands fa-github",
            theme = "issues"
        )
    )

    shiny::div(
        class = "help-resource-card help-links-card",
        shiny::div(
            class = "help-resource-head",
            shiny::tags$i(class = "fa-solid fa-up-right-from-square", `aria-hidden` = "true"),
            shiny::tags$h2(class = "help-resource-title", tr("help_links_title", lang))
        ),
        shiny::div(
            class = "help-links-grid",
            lapply(links, function(link_item) help_link_item(link_item, lang))
        )
    )
}

help_refs_card <- function(lang) {
    refs <- list(
        list(
            title = "Current Best Practices for Generalizing Sensitive Species Occurrence Data",
            authors = "Chapman (2020) · GBIF",
            href = "https://doi.org/10.15468/doc-5jp4-5g10"
        ),
        list(
            title = "Georeferencing Best Practices",
            authors = "Chapman & Wieczorek (2020) · GBIF",
            href = "https://doi.org/10.15468/doc-gg7h-s853"
        ),
        list(
            title = "Georeferencing Quick Reference Guide",
            authors = "Zermoglio et al. (2020) · GBIF",
            href = "https://doi.org/10.35035/e09p-h128"
        )
    )

    shiny::div(
        class = "help-resource-card help-refs-card",
        shiny::div(
            class = "help-resource-head",
            shiny::tags$i(class = "fa-solid fa-file-pdf", `aria-hidden` = "true"),
            shiny::tags$h2(class = "help-resource-title", tr("help_refs_title", lang))
        ),
        shiny::p(class = "help-resource-subtitle", tr("help_refs_subtitle", lang)),
        shiny::div(
            class = "help-refs-list",
            lapply(refs, function(ref) {
                shiny::tags$a(
                    href = ref$href,
                    class = "help-ref-item",
                    target = "_blank",
                    rel = "noopener noreferrer",
                    shiny::tags$span(
                        class = "help-ref-icon",
                        shiny::tags$i(class = "fa-solid fa-file-pdf", `aria-hidden` = "true")
                    ),
                    shiny::tags$span(
                        class = "help-ref-text",
                        shiny::tags$span(class = "help-ref-title", ref$title),
                        shiny::tags$span(class = "help-ref-authors", ref$authors)
                    ),
                    shiny::tags$i(class = "fa-solid fa-arrow-up-right-from-square help-ref-arrow", `aria-hidden` = "true")
                )
            })
        )
    )
}

help_faq_card <- function(lang) {
    faq_items <- lapply(seq_len(6), function(i) {
        list(
            q = tr(paste0("help_faq_q", i), lang),
            a = tr(paste0("help_faq_a", i), lang)
        )
    })

    shiny::div(
        class = "help-resource-card help-faq-card",
        shiny::div(
            class = "help-resource-head",
            shiny::tags$i(class = "fa-solid fa-circle-question", `aria-hidden` = "true"),
            shiny::tags$h2(class = "help-resource-title", tr("help_faq", lang))
        ),
        shiny::p(class = "help-resource-subtitle", tr("help_faq_subtitle", lang)),
        shiny::tags$details(
            class = "help-faq-toggle",
            shiny::tags$summary(
                class = "help-faq-summary",
                shiny::tags$span(tr("help_faq_toggle", lang)),
                shiny::tags$i(class = "fa-solid fa-chevron-down help-faq-chevron", `aria-hidden` = "true")
            ),
            shiny::div(
                class = "help-faq-list",
                lapply(faq_items, function(item) {
                    shiny::tags$details(
                        class = "help-faq-item",
                        shiny::tags$summary(
                            class = "help-faq-question",
                            shiny::tags$span(item$q),
                            shiny::tags$i(class = "fa-solid fa-chevron-down help-faq-chevron", `aria-hidden` = "true")
                        ),
                        shiny::div(class = "help-faq-answer", item$a)
                    )
                })
            ),
            shiny::tags$a(
                href = help_site_url(lang, "/faq.html", "/en/faq.html"),
                class = "help-faq-view-all",
                target = "_blank",
                rel = "noopener noreferrer",
                tr("help_faq_view_all", lang),
                shiny::tags$i(class = "fa-solid fa-arrow-up-right-from-square", `aria-hidden` = "true")
            )
        )
    )
}

help_resources_content <- function(lang) {
    shiny::tagList(
        help_tutorials_card(lang),
        help_links_card(lang),
        help_refs_card(lang),
        help_faq_card(lang)
    )
}

help_sidebar_author_card <- function(lang, author_meta) {
    repo_label <- gsub("^https://github.com/", "", author_meta$github_repo)

    shiny::div(
        class = "help-sidebar-card help-author-card",
        shiny::div(
            class = "help-author-card-header",
            shiny::div(class = "help-author-avatar", author_meta$initials),
            shiny::div(
                class = "help-author-meta",
                shiny::div(class = "help-author-name", author_meta$name),
                shiny::div(class = "help-author-role", tr("help_author_role", lang))
            )
        ),
        shiny::div(
            class = "help-author-body",
            shiny::div(
                class = "help-author-contact-item",
                shiny::tags$i(class = "fa-solid fa-envelope", `aria-hidden` = "true"),
                shiny::tags$span(tr("help_author_contact_email", lang)),
                shiny::tags$a(
                    href = paste0("mailto:", author_meta$email),
                    author_meta$email
                )
            ),
            shiny::div(
                class = "help-author-contact-item",
                shiny::tags$i(class = "fa-brands fa-github", `aria-hidden` = "true"),
                shiny::tags$span(tr("help_author_contact_repository", lang)),
                shiny::tags$a(
                    href = author_meta$github_repo,
                    target = "_blank",
                    rel = "noopener noreferrer",
                    repo_label
                )
            )
        ),
        shiny::div(class = "help-author-divider"),
        shiny::div(
            class = "help-author-footer",
            shiny::span(class = "help-author-version-label", tr("help_author_version_label", lang)),
            shiny::span(class = "help-author-version-badge", paste0("v", author_meta$version))
        )
    )
}

help_sidebar_bug_card <- function(lang) {
    shiny::div(
        class = "help-sidebar-card help-bug-card",
        shiny::div(
            class = "help-bug-card-header",
            shiny::div(
                class = "help-bug-icon-wrap",
                shiny::tags$i(class = "fa-solid fa-bug", `aria-hidden` = "true")
            ),
            shiny::div(class = "help-bug-title", tr("help_bug_title", lang))
        ),
        shiny::div(
            class = "help-bug-card-body",
            shiny::p(tr("help_bug_body", lang))
        ),
        shiny::a(
            href = "https://github.com/rogerio-onza/saira/issues",
            class = "help-bug-button",
            target = "_blank",
            rel = "noopener noreferrer",
            `aria-label` = tr("a11y_help_bug_link", lang),
            shiny::tags$svg(
                class = "help-bug-button-logo",
                xmlns = "http://www.w3.org/2000/svg",
                viewBox = "0 0 512 512",
                fill = "currentColor",
                `aria-hidden` = "true",
                shiny::tags$path(d = "M173.9 397.4c0 2-2.3 3.6-5.2 3.6-3.3 .3-5.6-1.3-5.6-3.6 0-2 2.3-3.6 5.2-3.6 3-.3 5.6 1.3 5.6 3.6zm-31.1-4.5c-.7 2 1.3 4.3 4.3 4.9 2.6 1 5.6 0 6.2-2s-1.3-4.3-4.3-5.2c-2.6-.7-5.5 .3-6.2 2.3zm44.2-1.7c-2.9 .7-4.9 2.6-4.6 4.9 .3 2 2.9 3.3 5.9 2.6 2.9-.7 4.9-2.6 4.6-4.6-.3-1.9-3-3.2-5.9-2.9zM252.8 8c-138.7 0-244.8 105.3-244.8 244 0 110.9 69.8 205.8 169.5 239.2 12.8 2.3 17.3-5.6 17.3-12.1 0-6.2-.3-40.4-.3-61.4 0 0-70 15-84.7-29.8 0 0-11.4-29.1-27.8-36.6 0 0-22.9-15.7 1.6-15.4 0 0 24.9 2 38.6 25.8 21.9 38.6 58.6 27.5 72.9 20.9 2.3-16 8.8-27.1 16-33.7-55.9-6.2-112.3-14.3-112.3-110.5 0-27.5 7.6-41.3 23.6-58.9-2.6-6.5-11.1-33.3 2.6-67.9 20.9-6.5 69 27 69 27 20-5.6 41.5-8.5 62.8-8.5s42.8 2.9 62.8 8.5c0 0 48.1-33.6 69-27 13.7 34.7 5.2 61.4 2.6 67.9 16 17.7 25.8 31.5 25.8 58.9 0 96.5-58.9 104.2-114.8 110.5 9.2 7.9 17 22.9 17 46.4 0 33.7-.3 75.4-.3 83.6 0 6.5 4.6 14.4 17.3 12.1 100-33.2 167.8-128.1 167.8-239 0-138.7-112.5-244-251.2-244zM105.2 352.9c-1.3 1-1 3.3 .7 5.2 1.6 1.6 3.9 2.3 5.2 1 1.3-1 1-3.3-.7-5.2-1.6-1.6-3.9-2.3-5.2-1zm-10.8-8.1c-.7 1.3 .3 2.9 2.3 3.9 1.6 1 3.6 .7 4.3-.7 .7-1.3-.3-2.9-2.3-3.9-2-.6-3.6-.3-4.3 .7zm32.4 35.6c-1.6 1.3-1 4.3 1.3 6.2 2.3 2.3 5.2 2.6 6.5 1 1.3-1.3 .7-4.3-1.3-6.2-2.2-2.3-5.2-2.6-6.5-1zm-11.4-14.7c-1.6 1-1.6 3.6 0 5.9s4.3 3.3 5.6 2.3c1.6-1.3 1.6-3.9 0-6.2-1.4-2.3-4-3.3-5.6-2z")
            ),
            tr("help_bug_button", lang)
        )
    )
}

# Runtime dependencies (DESCRIPTION Imports) with a link per package.
help_dependency_packages <- function() {
    pkgs <- c(
        "shiny", "htmltools", "bslib", "readr", "stringr", "taxadb",
        "CoordinateCleaner", "countrycode", "sf", "terra", "rnaturalearth",
        "rnaturalearthdata", "DT", "leaflet", "ids", "jsonlite", "DBI",
        "RSQLite", "digest", "withr", "florabr", "faunabr", "writexl", "zip",
        "uuid", "xml2"
    )
    overrides <- list(faunabr = "https://github.com/wevertonbio/faunabr")
    lapply(pkgs, function(name) {
        href <- overrides[[name]]
        if (is.null(href)) {
            href <- paste0("https://cran.r-project.org/package=", name)
        }
        list(name = name, href = href)
    })
}

help_sidebar_stack_card <- function(lang) {
    packages <- help_dependency_packages()

    shiny::div(
        class = "help-sidebar-card help-stack-card",
        shiny::div(class = "help-stack-title", tr("help_stack_title", lang)),
        shiny::div(class = "help-stack-subtitle", tr("help_stack_subtitle", lang)),
        shiny::div(
            class = "help-stack-chip-list",
            lapply(packages, function(pkg) {
                shiny::tags$a(
                    class = "help-stack-chip",
                    href = pkg$href,
                    target = "_blank",
                    rel = "noopener noreferrer",
                    pkg$name
                )
            })
        )
    )
}

#' Help Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_help_ui <- function(id) {
    ns <- shiny::NS(id)

    shiny::tagList(
        shiny::div(
            class = "container-fluid help-module",
            shiny::div(
                class = "help-layout-wrapper",
                shiny::div(
                    class = "help-layout",
                    shiny::div(
                        class = "help-main-column",
                        shiny::uiOutput(ns("help_header_card")),
                        shiny::uiOutput(ns("help_content"))
                    ),
                    shiny::div(
                        class = "help-sidebar-column",
                        shiny::uiOutput(ns("help_sidebar"))
                    )
                )
            )
        )
    )
}

#' Help Module Server
#'
#' @param id Module ID
#' @param lang_r Reactive language value
#' @export
mod_help_server <- function(id, lang_r) {
    shiny::moduleServer(id, function(input, output, session) {
        output$help_header_card <- shiny::renderUI({
            shiny::div(
                class = "help-page-header-card",
                shiny::div(class = "help-page-header-eyebrow", tr("help_header_eyebrow", lang_r())),
                shiny::tags$h1(
                    class = "help-page-header-title",
                    tr("help_header_title_prefix", lang_r()),
                    " ",
                    shiny::tags$span(class = "help-page-header-title-accent", tr("help_header_title_highlight", lang_r()))
                ),
                shiny::div(class = "help-page-header-subtitle", tr("help_header_subtitle", lang_r()))
            )
        })

        output$help_content <- shiny::renderUI({
            help_resources_content(lang_r())
        })

        output$help_sidebar <- shiny::renderUI({
            author_meta <- help_get_author_meta()

            shiny::div(
                class = "help-sidebar",
                help_sidebar_author_card(lang_r(), author_meta),
                help_sidebar_bug_card(lang_r()),
                help_sidebar_stack_card(lang_r())
            )
        })
    })
}
