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
    default_repo <- "https://github.com/rogerio-onza/finch"

    desc <- tryCatch(
        utils::packageDescription("finch"),
        error = function(e) NULL
    )

    version_value <- tryCatch(
        as.character(utils::packageVersion("finch")),
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

help_bullet_item <- function(text) {
    shiny::div(
        class = "help-bullet-item",
        shiny::tags$span(class = "help-bullet-dot"),
        shiny::tags$span(class = "help-bullet-text", text)
    )
}

help_faq_card <- function(question, answer) {
    shiny::div(
        class = "help-faq-card",
        shiny::div(class = "help-faq-question", question),
        shiny::div(class = "help-faq-answer", answer)
    )
}

help_separator_tokens <- function(tokens, separator_symbol) {
    if (!length(tokens)) {
        return(list())
    }

    parts <- list()
    for (idx in seq_along(tokens)) {
        parts[[length(parts) + 1L]] <- shiny::tags$span(tokens[[idx]])
        if (idx < length(tokens)) {
            parts[[length(parts) + 1L]] <- shiny::tags$span(
                class = "help-separator-demo-emph",
                separator_symbol
            )
        }
    }

    parts
}

help_dwc_content <- function(lang) {
    bullet_items <- lapply(
        X = c(
            tr("help_dwc_bullet_occurrence", lang),
            tr("help_dwc_bullet_location", lang),
            tr("help_dwc_bullet_taxonomy", lang),
            tr("help_dwc_bullet_event", lang)
        ),
        FUN = help_bullet_item
    )

    shiny::tagList(
        shiny::p(
            shiny::strong(tr("help_dwc_term_label", lang)),
            " ",
            tr("help_dwc_p1_prefix", lang),
            " ",
            shiny::tags$a(
                href = "https://www.tdwg.org/",
                target = "_blank",
                rel = "noopener noreferrer",
                tr("help_link_tdwg", lang)
            ),
            tr("help_dwc_p1_suffix", lang)
        ),
        shiny::p(tr("help_dwc_p2", lang)),
        shiny::div(class = "help-bullet-list", bullet_items),
        shiny::p(
            tr("help_dwc_p3_prefix", lang),
            " ",
            shiny::tags$a(
                href = "https://sibbr.gov.br/",
                target = "_blank",
                rel = "noopener noreferrer",
                tr("help_link_sibbr", lang)
            ),
            tr("help_dwc_p3_suffix", lang)
        )
    )
}

help_faq_content <- function(lang) {
    shiny::div(
        class = "help-faq-grid",
        help_faq_card(
            tr("help_faq_q1", lang),
            tr("help_faq_a1", lang)
        ),
        help_faq_card(
            tr("help_faq_q2", lang),
            tr("help_faq_a2", lang)
        ),
        help_faq_card(
            tr("help_faq_q3", lang),
            shiny::tagList(
                tr("help_faq_a3_prefix", lang),
                " ",
                shiny::tags$code("eventDate"),
                " ",
                tr("help_faq_a3_suffix", lang)
            )
        ),
        help_faq_card(
            tr("help_faq_q4", lang),
            tr("help_faq_a4", lang)
        )
    )
}

help_formats_content <- function(lang) {
    format_items <- lapply(
        X = c(
            tr("help_formats_bullet_1", lang),
            tr("help_formats_bullet_2", lang),
            tr("help_formats_bullet_3", lang),
            tr("help_formats_bullet_4", lang)
        ),
        FUN = help_bullet_item
    )

    shiny::tagList(
        shiny::p(tr("help_formats_p1", lang)),
        shiny::p(tr("help_formats_p2", lang)),
        shiny::div(class = "help-bullet-list", format_items)
    )
}

help_separator_content <- function(lang) {
    input_tokens <- c("catalogNumber", "fieldNumber", "recordNumber")
    output_tokens <- c("catalogNumber", "fieldNumber", "recordNumber")

    separator_items <- lapply(
        X = c(
            tr("help_separator_bullet_1", lang),
            tr("help_separator_bullet_2", lang),
            tr("help_separator_bullet_3", lang)
        ),
        FUN = help_bullet_item
    )

    shiny::tagList(
        shiny::p(tr("help_separator_p1", lang)),
        shiny::div(
            class = "help-separator-demo",
            shiny::tags$span(class = "help-separator-demo-label", tr("help_separator_demo_input", lang)),
            shiny::tags$span(
                class = "help-separator-demo-input-value",
                help_separator_tokens(input_tokens, ";")
            ),
            shiny::tags$span(
                class = "help-separator-demo-arrow",
                shiny::tags$i(class = "fa-solid fa-arrow-right", `aria-hidden` = "true")
            ),
            shiny::tags$span(
                class = "help-separator-demo-output-value",
                help_separator_tokens(output_tokens, "|")
            )
        ),
        shiny::p(tr("help_separator_p2", lang)),
        shiny::div(class = "help-bullet-list", separator_items)
    )
}

help_panels <- function(lang) {
    is_pt <- identical(lang, "pt")

    list(
        list(
            value = "dwc",
            title = tr("help_section_dwc_title", lang),
            icon = "fa-solid fa-book-open",
            theme = "dwc",
            search_text = if (is_pt) {
                "darwin core dwc tdwg sibbr biodiversidade taxonomia ocorrencia localizacao coleta"
            } else {
                "darwin core dwc tdwg sibbr biodiversity taxonomy occurrence location collection"
            },
            content = help_dwc_content(lang)
        ),
        list(
            value = "faq",
            title = tr("help_section_faq_title", lang),
            icon = "fa-solid fa-circle-question",
            theme = "faq",
            search_text = if (is_pt) {
                "faq perguntas frequentes csv tamanho arquivo automapeamento privacidade eventdate"
            } else {
                "faq questions csv file size auto-mapping privacy eventdate"
            },
            content = help_faq_content(lang)
        ),
        list(
            value = "formats",
            title = tr("help_section_formats_title", lang),
            icon = "fa-solid fa-file-csv",
            theme = "formats",
            search_text = if (is_pt) {
                "formatos csv utf-8 delimitador separador virgula ponto e virgula colunas"
            } else {
                "formats csv utf-8 delimiter separator semicolon columns"
            },
            content = help_formats_content(lang)
        ),
        list(
            value = "separator",
            title = tr("help_section_separator_title", lang),
            icon = "fa-solid fa-exchange-alt",
            theme = "separator",
            search_text = if (is_pt) {
                "separador multiplos valores ponto e virgula pipe mapeamento dwc"
            } else {
                "separator multiple values semicolon pipe mapping dwc"
            },
            content = help_separator_content(lang)
        )
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
            href = "https://github.com/rogerio-onza/finch/issues",
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

help_sidebar_links_card <- function(lang) {
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
        )
    )

    shiny::div(
        class = "help-sidebar-card help-links-card",
        shiny::div(
            class = "help-links-header",
            shiny::tags$i(class = "fa-solid fa-up-right-from-square", `aria-hidden` = "true"),
            shiny::span(tr("help_links_title", lang))
        ),
        lapply(links, function(link_item) {
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
        })
    )
}

help_chip_logo_svg <- function(path_d) {
    shiny::tags$svg(
        class = "help-stack-chip-logo",
        xmlns = "http://www.w3.org/2000/svg",
        viewBox = "0 0 512 512",
        fill = "currentColor",
        `aria-hidden` = "true",
        shiny::tags$path(d = path_d)
    )
}

help_chip_logo_openai <- function() {
    help_chip_logo_svg("M196.4 185.8l0-48.6c0-4.1 1.5-7.2 5.1-9.2l97.8-56.3c13.3-7.7 29.2-11.3 45.6-11.3 61.4 0 100.4 47.6 100.4 98.3 0 3.6 0 7.7-.5 11.8L343.3 111.1c-6.1-3.6-12.3-3.6-18.4 0L196.4 185.8zM424.7 375.2l0-116.2c0-7.2-3.1-12.3-9.2-15.9L287 168.4 329 144.3c3.6-2 6.7-2 10.2 0L437 200.7c28.2 16.4 47.1 51.2 47.1 85 0 38.9-23 74.8-59.4 89.6l0 0zM166.2 272.8l-42-24.6c-3.6-2-5.1-5.1-5.1-9.2l0-112.6c0-54.8 42-96.3 98.8-96.3 21.5 0 41.5 7.2 58.4 20L175.4 108.5c-6.1 3.6-9.2 8.7-9.2 15.9l0 148.5 0 0zm90.4 52.2l-60.2-33.8 0-71.7 60.2-33.8 60.2 33.8 0 71.7-60.2 33.8zm38.7 155.7c-21.5 0-41.5-7.2-58.4-20l100.9-58.4c6.1-3.6 9.2-8.7 9.2-15.9l0-148.5 42.5 24.6c3.6 2 5.1 5.1 5.1 9.2l0 112.6c0 54.8-42.5 96.3-99.3 96.3l0 0zM173.8 366.5L76.1 310.2c-28.2-16.4-47.1-51.2-47.1-85 0-39.4 23.6-74.8 59.9-89.6l0 116.7c0 7.2 3.1 12.3 9.2 15.9l128 74.2-42 24.1c-3.6 2-6.7 2-10.2 0zm-5.6 84c-57.9 0-100.4-43.5-100.4-97.3 0-4.1 .5-8.2 1-12.3l100.9 58.4c6.1 3.6 12.3 3.6 18.4 0l128.5-74.2 0 48.6c0 4.1-1.5 7.2-5.1 9.2l-97.8 56.3c-13.3 7.7-29.2 11.3-45.6 11.3l0 0zm127 60.9c62 0 113.7-44 125.4-102.4 57.3-14.9 94.2-68.6 94.2-123.4 0-35.8-15.4-70.7-43-95.7 2.6-10.8 4.1-21.5 4.1-32.3 0-73.2-59.4-128-128-128-13.8 0-27.1 2-40.4 6.7-23-22.5-54.8-36.9-89.6-36.9-62 0-113.7 44-125.4 102.4-57.3 14.8-94.2 68.6-94.2 123.4 0 35.8 15.4 70.7 43 95.7-2.6 10.8-4.1 21.5-4.1 32.3 0 73.2 59.4 128 128 128 13.8 0 27.1-2 40.4-6.7 23 22.5 54.8 36.9 89.6 36.9z")
}

help_chip_logo_claude <- function() {
    help_chip_logo_svg("M100.4 340.5l100.7-56.5 1.7-4.9-1.7-2.7-4.9 0-16.8-1-57.5-1.6-49.9-2.1-48.3-2.6-12.2-2.6-11.4-15 1.2-7.5 10.2-6.9 14.7 1.3c18.9 1.3 45.9 3.1 81 5.6l35.2 2.1 52.2 5.4 8.3 0 1.2-3.4-2.8-2.1-2.2-2.1-50.3-34.1-54.4-36-28.5-20.7-15.4-10.5-7.8-9.8-3.4-21.5 14-15.4 18.8 1.3 4.8 1.3 19 14.7 40.7 31.5 53.1 39.1 7.8 6.5 3.1-2.2 .4-1.6-3.5-5.8-28.9-52.2-30.8-53.1-13.7-22-3.6-13.2c-1.3-5.4-2.2-10-2.2-15.5l15.9-21.6 8.8-2.8 21.2 2.8 8.9 7.8 13.2 30.2 21.4 47.5 33.2 64.6 9.7 19.2 5.2 17.8 1.9 5.4 3.4 0 0-3.1 2.7-36.4 5-44.7 4.9-57.5 1.7-16.2 8-19.4 15.9-10.5 12.4 5.9 10.2 14.7-1.4 9.5-6.1 39.5-11.9 61.9-7.8 41.5 4.5 0 5.2-5.2 21-27.8 35.2-44.1 15.5-17.5 18.1-19.3 11.6-9.2 22 0 16.2 24.1-7.3 24.9-22.7 28.7-18.8 24.4-27 36.3-16.8 29 1.6 2.3 4-.4 60.9-13 32.9-5.9 39.3-6.7 17.8 8.3 1.9 8.4-7 17.2-42 10.4-49.2 9.8-73.3 17.3-.9 .7 1 1.3 33 3.1 14.1 .8 34.6 0 64.4 4.8 16.8 11.1 10.1 13.6-1.7 10.4-25.9 13.2c-15.5-3.7-54.4-12.9-116.6-27.7l-28-7-3.9 0 0 2.3 23.3 22.8 42.7 38.6 53.5 49.8 2.7 12.3-6.9 9.7-7.3-1-47-35.4-18.1-15.9-41.1-34.6-2.7 0 0 3.6 9.5 13.9 50 75.2 2.6 23-3.6 7.5-13 4.5-14.2-2.6-29.3-41.1-30.2-46.3-24.4-41.5-3 1.7-14.4 154.8-6.7 7.9-15.5 5.9-13-9.8-6.9-15.9 6.9-31.5 8.3-41.1 6.7-32.7 6.1-40.6 3.6-13.5-.2-.9-3 .4-30.6 42-46.5 62.9-36.8 39.4-8.8 3.5-15.3-7.9 1.4-14.1 8.5-12.6 50.9-64.8 30.7-40.2 19.8-23.2-.1-3.4-1.2 0-135.3 87.8-24.1 3.1-10.4-9.7 1.3-15.9 4.9-5.2 40.7-28-.1 .1 0 .1z")
}

help_sidebar_stack_card <- function(lang) {
    base_stack <- c(
        tr("help_stack_r", lang),
        tr("help_stack_shiny", lang),
        tr("help_stack_bslib", lang),
        tr("help_stack_dt", lang),
        tr("help_stack_leaflet", lang),
        tr("help_stack_coordinatecleaner", lang),
        tr("help_stack_taxadb", lang)
    )

    shiny::div(
        class = "help-sidebar-card help-stack-card",
        shiny::div(class = "help-stack-title", tr("help_stack_title", lang)),
        shiny::div(
            class = "help-stack-chip-list",
            lapply(base_stack, function(chip) {
                shiny::tags$span(class = "help-stack-chip", chip)
            }),
            shiny::tags$span(
                class = "help-stack-chip help-stack-chip--ai help-stack-chip--codex",
                help_chip_logo_openai(),
                tr("help_stack_codex", lang)
            ),
            shiny::tags$span(
                class = "help-stack-chip help-stack-chip--ai help-stack-chip--sonnet",
                help_chip_logo_claude(),
                tr("help_stack_sonnet", lang)
            )
        )
    )
}

help_accordion_item <- function(panel, idx, ns, open = FALSE) {
    panel_id <- ns(paste0("help_acc_", panel$value))
    button_id <- ns(paste0("help_acc_btn_", panel$value))
    body_id <- ns(paste0("help_acc_body_", panel$value))

    shiny::tags$section(
        id = panel_id,
        class = paste("help-acc-item", if (open) "is-open" else ""),
        `data-help-acc-item` = "true",
        `data-value` = panel$value,
        shiny::tags$button(
            id = button_id,
            class = "help-acc-header",
            type = "button",
            `data-help-acc-toggle` = "true",
            `aria-controls` = body_id,
            `aria-expanded` = if (open) "true" else "false",
            shiny::tags$span(
                class = paste("help-acc-icon-wrap", paste0("help-acc-icon-wrap--", panel$theme)),
                shiny::tags$i(class = panel$icon, `aria-hidden` = "true")
            ),
            shiny::tags$span(class = "help-acc-seq", sprintf("%02d", idx)),
            shiny::tags$span(class = "help-acc-title", panel$title),
            shiny::tags$span(
                class = "help-acc-chevron",
                shiny::tags$i(class = "fa-solid fa-chevron-down", `aria-hidden` = "true")
            )
        ),
        shiny::tags$div(
            id = body_id,
            class = "help-acc-body",
            `data-help-acc-body` = "true",
            role = "region",
            `aria-labelledby` = button_id,
            `aria-hidden` = if (open) "false" else "true",
            panel$content
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
                        shiny::div(
                            class = "help-search-card",
                            shiny::div(
                                class = "help-search-input-wrap",
                                shiny::tags$span(
                                    class = "help-search-icon",
                                    shiny::tags$i(class = "fa-solid fa-magnifying-glass", `aria-hidden` = "true")
                                ),
                                shiny::uiOutput(ns("help_search_input"))
                            )
                        ),
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
        ns <- session$ns

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

        output$help_search_input <- shiny::renderUI({
            shiny::div(
                class = "help-search-native",
                shiny::tags$label(
                    `for` = ns("help_search"),
                    class = "visually-hidden",
                    tr("a11y_help_search_label", lang_r())
                ),
                shiny::tags$input(
                    id = ns("help_search"),
                    type = "search",
                    class = "form-control",
                    placeholder = tr("help_search_placeholder", lang_r()),
                    autocomplete = "off",
                    spellcheck = "false",
                    `aria-label` = tr("a11y_help_search_label", lang_r())
                )
            )
        })

        output$help_content <- shiny::renderUI({
            search_value <- if (is.null(input$help_search)) "" else as.character(input$help_search)
            search_query <- tolower(trimws(search_value))

            panels <- help_panels(lang_r())
            if (nzchar(search_query)) {
                panels <- Filter(
                    f = function(panel) grepl(search_query, tolower(panel$search_text), fixed = TRUE),
                    x = panels
                )
            }

            if (length(panels) == 0L) {
                return(
                    shiny::div(
                        class = "help-empty-state",
                        tr("help_empty_state", lang_r())
                    )
                )
            }

            panel_tags <- lapply(seq_along(panels), function(idx) {
                help_accordion_item(
                    panel = panels[[idx]],
                    idx = idx,
                    ns = ns,
                    open = idx == 1L
                )
            })

            shiny::div(
                id = ns("help_accordion"),
                class = "help-accordion",
                `data-help-accordion` = "true",
                panel_tags
            )
        })

        output$help_sidebar <- shiny::renderUI({
            author_meta <- help_get_author_meta()

            shiny::div(
                class = "help-sidebar",
                help_sidebar_author_card(lang_r(), author_meta),
                help_sidebar_bug_card(lang_r()),
                help_sidebar_links_card(lang_r()),
                help_sidebar_stack_card(lang_r())
            )
        })
    })
}
