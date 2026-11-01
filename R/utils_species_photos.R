# Title: Species photos
# Author: Rogerio Nunes Oliveira
# Date: 2026-10-10
#
# Six threatened species of the MMA list, one for each biome. They are the
# photos of the help site home page. Each license asks for the author and the
# license next to the photo, so the credit is part of the tag.

#' The six species photos
#'
#' The common name of each species is in \code{species_common_<slug>} in
#' i18n.json, with dashes as underscores.
#'
#' @return Data frame with \code{slug}, \code{scientific_name}, \code{credit}
#'   and \code{position} (the CSS \code{object-position} of the crop).
#' @noRd
species_photos <- function() {
    data.frame(
        slug = c(
            "podocnemis-sextuberculata", "micranthocereus-polyanthus", "boana-buriti",
            "tangara-fastuosa", "acanthochelys-macrocephala", "leopardus-munoai"
        ),
        scientific_name = c(
            "Podocnemis sextuberculata", "Micranthocereus polyanthus", "Boana buriti",
            "Tangara fastuosa", "Acanthochelys macrocephala", "Leopardus munoai"
        ),
        credit = c(
            "Rafael Bernhard \u00b7 CC BY 4.0", "Brian Williams \u00b7 CC BY 4.0",
            "Reuber Brand\u00e3o \u00b7 CC BY 4.0", "Renato Bandeira \u00b7 CC BY 4.0",
            "Thomas Galewski \u00b7 CC BY 4.0", "Felipe Peters \u00b7 CC BY-NC 4.0"
        ),
        position = c("70% 40%", "45% 50%", "50% 54%", "50% 28%", "62% 55%", "50% 65%"),
        stringsAsFactors = FALSE
    )
}

#' One species photo
#'
#' @param slug Photo slug. \code{NULL} picks one photo at random.
#' @return One-row list of \code{species_photos()}.
#' @noRd
species_photo <- function(slug = NULL) {
    photos <- species_photos()
    idx <- if (is.null(slug)) sample.int(nrow(photos), 1L) else match(slug, photos$slug)
    if (is.na(idx)) stop("Unknown species photo: ", slug, call. = FALSE)
    as.list(photos[idx, , drop = FALSE])
}

#' Photo with its credit on top
#'
#' The photo is decorative (\code{alt = ""}): the credit line names the species.
#'
#' @param photo One photo from \code{species_photo()}.
#' @param lang Language code.
#' @param class Extra class for the figure, which sets the size.
#' @return A \code{figure} tag.
#' @noRd
species_photo_tag <- function(photo, lang, class = NULL) {
    common_key <- paste0("species_common_", gsub("-", "_", photo$slug, fixed = TRUE))
    shiny::tags$figure(
        class = trimws(paste("species-photo", class %||% "")),
        shiny::tags$img(
            src = paste0("www/images/species/", photo$slug, ".webp"),
            alt = "",
            style = paste0("object-position: ", photo$position, ";")
        ),
        shiny::tags$figcaption(
            class = "species-photo-credit",
            shiny::tags$em(photo$scientific_name),
            paste0(" \u00b7 ", tr(common_key, lang), " \u00b7 ", photo$credit)
        )
    )
}
