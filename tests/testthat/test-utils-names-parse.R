# One corpus for the two projections of parse_scientific_name() (SP-09):
# canonicalName for the mapping and the query for the name lookups. A row
# where the two differ says why in `why`.

name_cases <- data.frame(
    input = c(
        "Puma concolor", "PUMA CONCOLOR", "Mimus Saturninus",
        "Puma concolor subsp. Concolor", "Puma concolor ssp. concolor",
        "Abies alba var alba", "Abies alba forma alba", "Dasypus septemcinctus hybridus",
        "Puma concolor (Linnaeus, 1771)", "Dasypus novemcinctus Linnaeus, 1758",
        "Panthera Oken, 1816", "Panthera (Panthera) onca", "Panthera cf. onca",
        "Panthera onca cf", "Panthera onca?", "indet. Panthera onca", "Panthera onca.",
        "Tangara arara\u00fana", "Felidae",
        "Inga nobilis Willd. subsp. nobilis", "Curtia tenuifolia (Aubl.) Knobl. subsp. tenuifolia",
        "Sapium biglandulosum var. pallidum f. oblongifolium M\u00fcll. Arg.",
        "Rechsteineria canescens Hoehne subsp. canescens form. obovata",
        "Helicteres L.", "Brignolia DC.", "Typhlotanais G. O. Sars, 1882",
        "Magelona papillicornis F. M\u00fcller, 1858", "Phasma (Craspedonia) Westwood, 1841",
        "Leptodictyum (Schimp.) Warnst.", "Arrenurus (Incertae sedis) acutiepimeratus Viets, 1954",
        "Cornurella fonsecae da Silva, da Silva, Esteves & Decraemer, 2017",
        "Kubitzkia macrantha (Kosterm.) van der Werff", "Schochia Brunner von Wattenwyl, 1895",
        "Panthera sp.", "Scinax sp. nov. 1",
        "Panthera onca juvenile", "Panthera onca (cultivado)", "Scinax 1",
        "Panthera x leo", "Panthera onca / Puma concolor", "P. onca", "NA"
    ),
    canonical = c(
        "Puma concolor", "Puma concolor", "Mimus saturninus",
        "Puma concolor subsp. concolor", "Puma concolor subsp. concolor",
        "Abies alba var. alba", "Abies alba f. alba", "Dasypus septemcinctus hybridus",
        "Puma concolor", "Dasypus novemcinctus",
        "Panthera", "Panthera onca", "Panthera onca",
        "Panthera onca", "Panthera onca", "Panthera onca", "Panthera onca",
        "Tangara ararauna", "Felidae",
        "Inga nobilis subsp. nobilis", "Curtia tenuifolia subsp. tenuifolia",
        "Sapium biglandulosum var. pallidum f. oblongifolium",
        "Rechsteineria canescens subsp. canescens f. obovata",
        "Helicteres", "Brignolia", "Typhlotanais",
        "Magelona papillicornis", "Phasma",
        "Leptodictyum", "Arrenurus acutiepimeratus",
        "Cornurella fonsecae",
        "Kubitzkia macrantha", "Schochia",
        "Panthera", "Scinax",
        NA, NA, NA,
        NA, NA, NA, NA
    ),
    query = c(
        "Puma concolor", "Puma concolor", "Mimus saturninus",
        "Puma concolor subsp. concolor", "Puma concolor subsp. concolor",
        "Abies alba var. alba", "Abies alba f. alba", "Dasypus septemcinctus hybridus",
        "Puma concolor", "Dasypus novemcinctus",
        "Panthera", "Panthera onca", "Panthera onca",
        "Panthera onca", "Panthera onca", "Panthera onca", "Panthera onca",
        "Tangara ararauna", "Felidae",
        "Inga nobilis subsp. nobilis", "Curtia tenuifolia subsp. tenuifolia",
        "Sapium biglandulosum var. pallidum f. oblongifolium",
        "Rechsteineria canescens subsp. canescens f. obovata",
        "Helicteres", "Brignolia", "Typhlotanais",
        "Magelona papillicornis", "Phasma",
        "Leptodictyum", "Arrenurus acutiepimeratus",
        "Cornurella fonsecae",
        "Kubitzkia macrantha", "Schochia",
        NA, NA,
        "Panthera onca", "Panthera onca", "Scinax",
        NA, NA, NA, NA
    ),
    why = c(
        rep("", 33),
        rep("no species to look up, the genus stays in the cell", 2),
        rep("the cell stays as typed, the lookup still reads the name", 3),
        rep("", 4)
    ),
    stringsAsFactors = FALSE
)

testthat::test_that("the mapping and the name query read the same parse", {
    parts <- saira:::extract_scientific_name_components(name_cases$input)
    query <- vapply(name_cases$input, saira:::normalize_scientific_name, character(1),
                    USE.NAMES = FALSE)
    for (i in seq_len(nrow(name_cases))) {
        testthat::expect_identical(parts$canonicalName[[i]], name_cases$canonical[[i]],
                                   info = name_cases$input[[i]])
        testthat::expect_identical(query[[i]], name_cases$query[[i]], info = name_cases$input[[i]])
    }
    # Every intentional difference is written down.
    differ <- !mapply(identical, parts$canonicalName, name_cases$query, USE.NAMES = FALSE)
    testthat::expect_identical(differ, nzchar(name_cases$why))
})

testthat::test_that("a rank chain names the last rank and keeps the right author", {
    parts <- saira:::extract_scientific_name_components(c(
        "Inga nobilis Willd. subsp. nobilis",
        "Inga nobilis Willd. subsp. quaternata (Poepp.) T.D.Penn.",
        "Sapium biglandulosum var. pallidum f. oblongifolium M\u00fcll. Arg."
    ))
    testthat::expect_identical(parts$taxonRank, c("subspecies", "subspecies", "form"))
    testthat::expect_identical(parts$infraspecificEpithet, c("nobilis", "quaternata", "oblongifolium"))
    # The species author stands only when the infraspecific taxon has none.
    testthat::expect_identical(parts$scientificNameAuthorship,
                               c("Willd.", "(Poepp.) T.D.Penn.", "M\u00fcll. Arg."))
})

testthat::test_that("the query options add the qualifier and the authorship as typed", {
    norm <- saira:::normalize_scientific_name
    testthat::expect_identical(norm("Panthera onca cf", ignore_qualifiers = FALSE), "Panthera cf. onca")
    testthat::expect_identical(norm("Panthera sp.", ignore_qualifiers = FALSE), "Panthera sp.")
    testthat::expect_identical(norm("Panthera onca?", ignore_qualifiers = FALSE), "Panthera onca")
    testthat::expect_identical(norm("Puma concolor (Linnaeus, 1771)", remove_authors = FALSE),
                               "Puma concolor (Linnaeus, 1771)")
    # Extra text is not an authorship, so it never reaches the query.
    testthat::expect_identical(norm("Panthera onca (cultivado)", remove_authors = FALSE), "Panthera onca")
})
