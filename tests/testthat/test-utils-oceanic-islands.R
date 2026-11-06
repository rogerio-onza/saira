# Oceanic islands rule for the establishmentMeans assistant (ADR-143).

test_that("oceanic_island_for places points inside each archipelago box", {
    lat <- c("-3.85", "-3,87", "-20.5", "0.92", "-15.8", NA, "abc")
    lon <- c("-32.42", "-33.8", "-29.3", "-29.34", "-47.9", "-32.4", "-32.4")
    expect_equal(
        oceanic_island_for(lat, lon),
        c("Fernando de Noronha", "Atol das Rocas", "Trindade e Martim Vaz",
          "São Pedro e São Paulo", NA, NA, NA)
    )
    expect_equal(oceanic_island_for(character(0), character(0)), character(0))
})

test_that("island_rule_applies covers non-marine translocated natives only", {
    expect_equal(
        island_rule_applies(c(
            "Nasua nasua", "Sus scrofa", "Hypsoblennius invemar", "Panthera onca"
        )),
        c(TRUE, FALSE, FALSE, FALSE)
    )
})

test_that("establishment_island_rows marks covered records on an island", {
    species <- c("Nasua nasua", "Nasua nasua", "Sus scrofa", "Panthera onca")
    lat <- c(-3.85, -19.9, -3.85, -3.85)
    lon <- c(-32.42, -43.9, -32.42, -32.42)
    expect_equal(
        establishment_island_rows(species, lat, lon),
        c("Fernando de Noronha", NA, NA, NA)
    )
})

test_that("establishment_island_rows_for_df needs both coordinates mapped", {
    df <- data.frame(sp = "Nasua nasua", la = "-3.85", lo = "-32.42")
    expect_null(establishment_island_rows_for_df(
        df, list(decimalLatitude = "la"), df$sp
    ))
    expect_equal(
        establishment_island_rows_for_df(
            df, list(decimalLatitude = "la", decimalLongitude = "lo"), df$sp
        ),
        "Fernando de Noronha"
    )
})

test_that("add_island_counts counts island records per species", {
    species <- c("Nasua nasua", "Nasua nasua", "Nasua nasua", "Sus scrofa")
    islands <- c("Fernando de Noronha", NA, "Fernando de Noronha", NA)
    entries <- add_island_counts(extract_species_entries(species), species, islands)
    expect_equal(entries$n_island, c(2L, 0L))
    expect_equal(entries$island_names, c("Fernando de Noronha", ""))

    none <- add_island_counts(extract_species_entries(species), species, NULL)
    expect_equal(none$n_island, c(0L, 0L))
})
