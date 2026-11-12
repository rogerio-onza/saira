# Chapman assessment rules (Chapman 2020, Table 5). No Shiny or presentation
# dependencies.

# Category label -> stable key for the per-group answers.
sensitive_category_code <- function(category) {
    code <- gsub("[^a-z0-9]", "", tolower(as.character(category)))
    ifelse(nzchar(code), code, "other")
}

# Chapman Table 5 cascade -> tier, CAPPED at Category 2 (4.3->high ...
# 4.5->low; all-no -> not_sensitive). Category 1 (extreme) is never produced
# here: it is reachable only via an explicit, justified per-species
# exception. NA while the cascade is still unanswered.
chapman_tier <- function(a3, a4, a5) {
    done <- function(x) !is.null(x) && nzchar(x)
    if (!done(a3)) return(NA_character_)
    if (identical(a3, "yes")) return("high")
    if (!done(a4)) return(NA_character_)
    if (identical(a4, "yes")) return("medium")
    if (!done(a5)) return(NA_character_)
    if (identical(a5, "yes")) return("low")
    "not_sensitive"
}

# Tier per species: the group answer, then the species exception on top.
resolve_generalization_levels <- function(overview, group_levels, overrides) {
    if (is.null(overview) || nrow(overview) == 0L) {
        return(stats::setNames(character(0), character(0)))
    }
    # An open group keeps NA, so no `%||%` here (it also replaces NA).
    tiers <- vapply(overview$code, function(code) {
        tier <- group_levels[[code]]
        if (is.null(tier)) "not_sensitive" else tier
    }, character(1))
    for (i in seq_len(nrow(overview))) {
        override <- overrides[[overview$scientificName[i]]]
        if (!is.null(override)) tiers[i] <- override
    }
    stats::setNames(tiers, overview$scientificName)
}
