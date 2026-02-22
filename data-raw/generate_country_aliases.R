# Generate country alias data for coordinate validation.
# Output: inst/extdata/country_aliases.rds

normalize_country_token <- function(x) {
    out <- as.character(x)
    out[is.na(out)] <- ""
    out <- trimws(out)
    out <- iconv(out, from = "", to = "ASCII//TRANSLIT")
    out[is.na(out)] <- ""
    out <- tolower(out)
    out <- gsub("[^a-z0-9]+", " ", out)
    trimws(out)
}

country_aliases <- data.frame(
    alias = c(
        "brasil", "brazil",
        "eua", "estados unidos", "united states", "united states of america", "usa", "u s a", "u.s.a",
        "reino unido", "united kingdom", "uk", "u k", "great britain", "inglaterra",
        "espanha", "spain",
        "alemanha", "germany",
        "franca", "france",
        "mexico",
        "argentina",
        "chile",
        "peru",
        "colombia",
        "equador", "ecuador",
        "paraguai", "paraguay",
        "uruguai", "uruguay",
        "bolivia",
        "venezuela",
        "paises baixos", "holanda", "netherlands",
        "cote d ivoire", "cote divoire", "cote d'ivoire",
        "sao tome e principe"
    ),
    iso3c = c(
        "BRA", "BRA",
        "USA", "USA", "USA", "USA", "USA", "USA", "USA",
        "GBR", "GBR", "GBR", "GBR", "GBR", "GBR",
        "ESP", "ESP",
        "DEU", "DEU",
        "FRA", "FRA",
        "MEX",
        "ARG",
        "CHL",
        "PER",
        "COL",
        "ECU", "ECU",
        "PRY", "PRY",
        "URY", "URY",
        "BOL",
        "VEN",
        "NLD", "NLD", "NLD",
        "CIV", "CIV", "CIV",
        "STP"
    ),
    stringsAsFactors = FALSE
)

country_aliases$alias <- normalize_country_token(country_aliases$alias)
country_aliases$iso3c <- toupper(trimws(as.character(country_aliases$iso3c)))
country_aliases <- country_aliases[nzchar(country_aliases$alias) & grepl("^[A-Z]{3}$", country_aliases$iso3c), , drop = FALSE]
country_aliases <- country_aliases[!duplicated(country_aliases$alias), , drop = FALSE]
rownames(country_aliases) <- NULL

dir.create(file.path("inst", "extdata"), recursive = TRUE, showWarnings = FALSE)
saveRDS(country_aliases, file = file.path("inst", "extdata", "country_aliases.rds"), version = 2)

message(sprintf("Saved %d aliases to inst/extdata/country_aliases.rds", nrow(country_aliases)))
