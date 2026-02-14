# Benchmark Onda 3 - 2026-02-14

## 1) Contexto
- Objetivo: comparar desempenho de normalizacao de datas apos vetorizar `parse_dates_to_iso()` e delegar `fix_dates_to_iso()` para o parser vetorizado.
- Baseline de referencia: `docs/archive/baseline_onda0_2026-02-13.md`.
- Script reprodutivel: `tests/bench/benchmark_dates_onda3.R`.

## 2) Configuracao do benchmark
- Linhas: 100000
- Iteracoes: 3
- Dataset sintetico: mistura de formatos validos (`YYYY-MM-DD`, `DD/MM/YYYY`, `DD-MM-YYYY`, `DD.MM.YYYY`, `DD/MM/YY`), invalidos, `NA` e string vazia.
- Data de execucao: 2026-02-14

## 3) Resultados Onda 3
- `parse_dates_to_iso()` tempos (s): 0.880, 0.840, 0.840
- `parse_dates_to_iso()` stats: min=0.840, median=0.840, mean=0.853, max=0.880
- `fix_dates_to_iso()` tempos (s): 2.540, 2.630, 2.550
- `fix_dates_to_iso()` stats: min=2.540, median=2.550, mean=2.573, max=2.630

## 4) Comparativo vs baseline Onda 0
- Baseline `parse_dates_to_iso()` median: 14.980s
- Onda 3 `parse_dates_to_iso()` median: 0.840s
- Ganho: **17.83x** mais rapido

- Baseline `fix_dates_to_iso()` median: 38.050s
- Onda 3 `fix_dates_to_iso()` median: 2.550s
- Ganho: **14.92x** mais rapido

## 5) Conclusao
- Gate de performance da Onda 3 atendido com ganho mensuravel em 100k linhas.
- Benchmark continua sendo indicador de componente (funcao isolada), nao SLA do app completo.
