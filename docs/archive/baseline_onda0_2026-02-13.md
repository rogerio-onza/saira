# Baseline Onda 0 - 2026-02-13

## 1) devtools::test()
- Status: PASS
- Resultado: 98 testes passando, 0 falhas.

## 2) devtools::check(document = FALSE, manual = FALSE)
- Status: ERROR
- Resumo: 1 ERROR, 6 WARNINGs, 3 NOTEs.
- Erro principal: falha em `tests/testthat/helper-source-utils.R` ao tentar carregar `R/utils_mapping.R` no tarball de check.
- Warning relevante de onda 1: `jsonlite` usado com `::` sem declaração em DESCRIPTION.

## 3) Benchmark de datas (100k)
- Linhas: 100000
- Iterações: 3
- parse_dates_to_iso() tempos (s): 16.470, 14.980, 14.980
- parse_dates_to_iso() stats: min=14.980, median=14.980, mean=15.477, max=16.470
- fix_dates_to_iso() tempos (s): 36.500, 38.050, 39.220
- fix_dates_to_iso() stats: min=36.500, median=38.050, mean=37.923, max=39.220

## Gate Onda 0
- Baseline coletado: SIM
- Lista de falhas atual confirmada: SIM
