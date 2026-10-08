# Title: Help Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-23
# Version: 3.0
#
# Four bands (ADR-146): who makes Saira and how to cite it, where to start,
# the R packages it is built with, and the bundled data and methods.

# Language-aware website URL: one path per language, English when the language
# has no page of its own (the same fallback as tr()).
help_site_url <- function(lang, ...) {
    paths <- list(...)
    path <- paths[[as.character(lang)[1L]]] %||% paths[["en"]]
    paste0("https://rogerio-onza.github.io/saira", path)
}

help_external_link <- function(href, ..., class = NULL, label = NULL) {
    shiny::tags$a(
        href = href,
        class = class,
        target = "_blank",
        rel = "noopener noreferrer",
        `aria-label` = label,
        ...
    )
}

help_external_icon <- function() {
    shiny::tags$i(class = "ph ph-arrow-square-out", `aria-hidden` = "true")
}

help_copy_button <- function(text, label, done, aria_label = NULL, icon = NULL) {
    shiny::tags$button(
        type = "button",
        class = "help-button help-button--outline",
        `data-copy` = text,
        `data-done` = done,
        `aria-label` = aria_label,
        if (!is.null(icon)) shiny::tags$i(class = icon, `aria-hidden` = "true"),
        shiny::tags$span(class = "copy-label", `aria-live` = "polite", label)
    )
}

# -- Band 1: made by, how to cite --------------------------------------------

help_credits_band <- function(lang, meta) {
    citation <- credits_citation(meta)
    repo_label <- sub("^https?://", "", meta$repo)

    shiny::tags$section(
        class = "help-band help-band--card",
        shiny::div(
            class = "help-band-inner help-credits",
            shiny::tags$h1(class = "visually-hidden", tr("nav_help", lang)),
            shiny::div(
                class = "help-author",
                shiny::div(class = "help-eyebrow", tr("help_made_by", lang)),
                shiny::div(
                    class = "help-author-id",
                    shiny::div(class = "help-avatar", `aria-hidden` = "true", meta$initials),
                    shiny::div(
                        shiny::tags$h2(class = "help-author-name", meta$name),
                        shiny::div(class = "help-author-role", tr("help_author_role", lang))
                    )
                ),
                shiny::div(
                    class = "help-chips",
                    shiny::tags$a(
                        class = "help-chip",
                        href = paste0("mailto:", meta$email),
                        shiny::tags$i(class = "ph ph-envelope-simple", `aria-hidden` = "true"),
                        meta$email
                    ),
                    help_external_link(
                        meta$repo,
                        class = "help-chip",
                        label = paste0(tr("a11y_help_external_link", lang), ": ", repo_label),
                        shiny::tags$i(class = "ph ph-github-logo", `aria-hidden` = "true"),
                        repo_label
                    ),
                    help_external_link(
                        paste0(meta$repo, "/blob/main/LICENSE.md"),
                        class = "help-chip",
                        paste(tr("help_license_label", lang), meta$license)
                    ),
                    shiny::tags$span(
                        class = "help-chip help-chip--version",
                        title = paste(tr("help_author_version_label", lang), meta$version),
                        paste0("v", meta$version)
                    )
                )
            ),
            shiny::div(
                class = "help-cite",
                shiny::tags$h2(class = "help-cite-title", tr("help_cite_title", lang)),
                shiny::tags$p(class = "help-cite-text", citation$text),
                shiny::div(
                    class = "help-cite-actions",
                    help_copy_button(
                        citation$text,
                        label = tr("help_cite_copy", lang),
                        done = tr("help_cite_copied", lang),
                        icon = "ph ph-copy"
                    ),
                    help_copy_button(
                        citation$bibtex,
                        label = "BibTeX",
                        done = tr("help_cite_copied", lang),
                        aria_label = tr("a11y_help_cite_bibtex", lang)
                    )
                )
            )
        )
    )
}

# -- Band 2: tutorials, FAQ, report a problem --------------------------------

help_faq_item <- function(i, lang) {
    shiny::tags$details(
        class = "help-faq-item",
        shiny::tags$summary(
            class = "help-faq-question",
            shiny::tags$span(tr(paste0("help_faq_q", i), lang)),
            shiny::tags$i(class = "ph ph-plus help-faq-icon", `aria-hidden` = "true")
        ),
        shiny::div(class = "help-faq-answer", tr(paste0("help_faq_a", i), lang))
    )
}

help_start_band <- function(lang, issues_url) {
    shiny::tags$section(
        class = "help-band",
        shiny::div(
            class = "help-band-inner",
            shiny::div(class = "help-eyebrow", tr("help_start_here", lang)),
            shiny::div(
                class = "help-start",
                shiny::div(
                    class = "help-card",
                    shiny::tags$h2(class = "help-card-title", tr("help_tutorials_title", lang)),
                    shiny::tags$p(class = "help-card-body", tr("help_tutorials_body", lang)),
                    help_external_link(
                        help_site_url(lang, pt = "/tutoriais/", en = "/en/tutorials/", es = "/es/tutoriales/"),
                        class = "help-button help-button--accent",
                        tr("help_tutorials_link", lang),
                        help_external_icon()
                    )
                ),
                shiny::div(
                    class = "help-card",
                    shiny::tags$h2(class = "help-card-title", tr("help_faq", lang)),
                    shiny::div(class = "help-faq", lapply(1:4, help_faq_item, lang = lang)),
                    help_external_link(
                        help_site_url(lang, pt = "/faq.html", en = "/en/faq.html", es = "/es/faq.html"),
                        class = "help-link help-faq-all",
                        tr("help_faq_view_all", lang),
                        help_external_icon()
                    )
                ),
                shiny::div(
                    class = "help-card",
                    shiny::tags$h2(class = "help-card-title", tr("help_bug_title", lang)),
                    shiny::tags$p(class = "help-card-body", tr("help_bug_body", lang)),
                    help_external_link(
                        issues_url,
                        class = "help-button help-button--danger",
                        label = tr("a11y_help_bug_link", lang),
                        tr("help_bug_button", lang),
                        help_external_icon()
                    )
                )
            )
        )
    )
}

# -- Band 3: built with ------------------------------------------------------

help_package_item <- function(pkg, lang) {
    purpose <- tr(paste0("help_pkg_", tolower(pkg$name)), lang)
    installed <- !is.na(pkg$version)

    shiny::tags$li(
        class = "help-pkg",
        shiny::div(
            class = "help-pkg-head",
            help_external_link(pkg$href, class = "help-pkg-name", pkg$name),
            shiny::tags$span(
                class = "help-pkg-version",
                if (installed) pkg$version else tr("help_pkg_not_installed", lang)
            )
        ),
        shiny::div(
            class = "help-pkg-meta",
            paste(c(purpose, if (installed && !is.na(pkg$maintainer)) pkg$maintainer), collapse = " \u00B7 ")
        )
    )
}

help_stack_band <- function(lang, packages) {
    n_pkg <- sum(lengths(packages))

    shiny::tags$section(
        class = "help-band help-band--card",
        shiny::div(
            class = "help-band-inner",
            shiny::div(
                class = "help-band-head",
                shiny::tags$h2(class = "help-band-title", tr("help_stack_title", lang)),
                help_external_link(
                    help_site_url(lang, pt = "/tecnologias.html", en = "/en/technologies.html", es = "/es/tecnologias.html"),
                    class = "help-link",
                    tr("help_stack_full_list", lang),
                    help_external_icon()
                )
            ),
            shiny::tags$p(class = "help-band-lead", sprintf(tr("help_stack_body", lang), n_pkg)),
            shiny::div(
                class = "help-pkg-groups",
                lapply(names(packages), function(group) {
                    shiny::div(
                        class = "help-pkg-group",
                        shiny::tags$h3(class = "help-eyebrow", tr(paste0("help_pkg_group_", group), lang)),
                        shiny::tags$ul(
                            class = "help-pkg-list",
                            lapply(packages[[group]], help_package_item, lang = lang)
                        )
                    )
                })
            )
        )
    )
}

# -- Band 4: data and methods ------------------------------------------------

help_data_band <- function(lang) {
    data_rows <- list(
        list(tr("help_data_land", lang), "Natural Earth", tr("help_license_public_domain", lang)),
        list(tr("help_data_dwc", lang), "TDWG", "CC BY 4.0"),
        list(tr("help_data_redlist", lang), tr("help_data_redlist_source", lang), tr("help_license_public_record", lang)),
        list(tr("help_data_flora", lang), "JBRJ", "CC BY 4.0"),
        list(tr("help_data_fauna", lang), "JBRJ", "CC BY 4.0"),
        list(tr("help_data_saira", lang), "Sa\u00EDra", "GPL-3")
    )
    methods <- list(
        list("Ribeiro et al. (2022)", tr("help_method_bdc", lang), "10.1111/2041-210X.13868"),
        list(
            "Chapman (2020)",
            "Current Best Practices for Generalizing Sensitive Species Occurrence Data. GBIF.",
            "10.15468/doc-5jp4-5g10"
        ),
        list("Chapman & Wieczorek (2020)", "Georeferencing Best Practices. GBIF.", "10.15468/doc-gg7h-s853"),
        list("Zermoglio et al. (2020)", "Georeferencing Quick Reference Guide. GBIF.", "10.35035/e09p-h128")
    )
    standards <- list(
        list("Darwin Core (TDWG)", "https://dwc.tdwg.org/terms/"),
        list("SiBBr", "https://sibbr.gov.br/"),
        list("GBIF", "https://www.gbif.org/darwin-core")
    )

    shiny::tags$section(
        class = "help-band",
        shiny::div(
            class = "help-band-inner",
            shiny::tags$h2(class = "help-band-title", tr("help_data_title", lang)),
            shiny::div(
                class = "help-data",
                shiny::div(
                    shiny::tags$h3(class = "help-eyebrow", tr("help_data_bundled", lang)),
                    lapply(data_rows, function(row) {
                        shiny::div(
                            class = "help-row help-row--data",
                            shiny::div(
                                shiny::div(class = "help-row-title", row[[1]]),
                                shiny::div(class = "help-row-meta", row[[2]])
                            ),
                            shiny::tags$span(class = "help-chip help-chip--small", row[[3]])
                        )
                    })
                ),
                shiny::div(
                    shiny::tags$h3(class = "help-eyebrow", tr("help_refs_title", lang)),
                    lapply(methods, function(ref) {
                        shiny::div(
                            class = "help-row",
                            shiny::div(class = "help-row-title", ref[[1]]),
                            shiny::div(class = "help-row-text", ref[[2]]),
                            help_external_link(
                                paste0("https://doi.org/", ref[[3]]),
                                class = "help-link",
                                paste0("doi.org/", ref[[3]]),
                                help_external_icon()
                            )
                        )
                    })
                )
            ),
            shiny::div(
                class = "help-chips help-standards",
                lapply(standards, function(link) {
                    help_external_link(
                        link[[2]],
                        class = "help-chip",
                        label = paste0(tr("a11y_help_external_link", lang), ": ", link[[1]]),
                        link[[1]],
                        help_external_icon()
                    )
                })
            )
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

    shiny::div(
        class = "container-fluid help-module",
        shiny::uiOutput(ns("help_page"))
    )
}

#' Help Module Server
#'
#' @param id Module ID
#' @param lang_r Reactive language value
#' @export
mod_help_server <- function(id, lang_r) {
    shiny::moduleServer(id, function(input, output, session) {
        # No reactive inputs: Shiny reads the DESCRIPTION files once, on the
        # first visit to the tab.
        credits_r <- shiny::reactive({
            list(
                meta = credits_saira_meta(),
                packages = lapply(credits_package_groups(), function(pkgs) lapply(pkgs, credits_package_meta))
            )
        })

        output$help_page <- shiny::renderUI({
            lang <- lang_r()
            credits <- credits_r()

            shiny::tagList(
                help_credits_band(lang, credits$meta),
                help_start_band(lang, credits$meta$issues),
                help_stack_band(lang, credits$packages),
                help_data_band(lang)
            )
        })
    })
}
