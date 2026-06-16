# Saíra 🐦

Saíra é um aplicativo em R/Shiny para padronizar planilhas de ocorrências de
biodiversidade no padrão Darwin Core (DwC) e publicá-las no GBIF e no SiBBr.
A interface é visual e bilíngue (PT-BR/EN-US); não é preciso programar para usar.

[🇧🇷 Português](#português) · [🇺🇸 English](#english)

---

## Português

### 🔎 O que é

Você tem uma planilha (CSV ou Excel) com registros de espécies e precisa
publicá-la no Darwin Core — o conjunto de nomes de colunas e formatos que o GBIF
e o SiBBr esperam. O Saíra carrega a planilha, ajuda a associar suas colunas aos
termos do Darwin Core, valida nomes e coordenadas e gera o arquivo final.

O app abre no navegador; você usa por menus, botões e tabelas. Código, só na
instalação.

### 🔄 Como funciona

1. **Upload** — carregue seu CSV ou Excel.
2. **Mapeamento** — associe cada coluna a um termo do Darwin Core (com sugestões automáticas).
3. **Validação** — confira nomes científicos e coordenadas.
4. **Exportar** — baixe o arquivo padronizado, pronto para o GBIF/IPT.

### ✨ Recursos

- Lê CSV e Excel.
- Mapeamento de colunas com sugestões automáticas para os termos Darwin Core.
- Verificação de nomes científicos contra bases taxonômicas (grafia e sinônimos).
- Validação de coordenadas: faixas de lat/lon, pontos no mar, país e coordenadas
  trocadas, com correção em um clique.
- Exporta um Darwin Core Archive (`occurrence.txt`, `meta.xml`, `eml.xml`) pronto
  para o GBIF/IPT, mais uma cópia em `.xlsx` e o guia de mapeamento. O `eml.xml`
  já traz a área geográfica e o intervalo de datas calculados dos seus dados.
- `occurrenceID` estável: preenche IDs faltantes de forma determinística (a mesma
  combinação gera sempre o mesmo ID), então republicar no GBIF conta como
  atualização, não como registro novo.
- Armadilhas fotográficas (opcional): importa pacotes Camtrap DP e exportações do
  Wildlife Insights. Requer o pacote `camtrapdp` (`install.packages("camtrapdp")`).

### 📦 Instalação

O Saíra roda em R. Se você nunca usou R, faça isto uma vez:

1. Instale o R (4.1.0 ou mais recente): <https://cloud.r-project.org>.
2. Instale o RStudio Desktop — onde você cola e roda os comandos:
   <https://posit.co/download/rstudio-desktop/>.
3. Abra o RStudio e, no Console, cole e execute:

   ```r
   # florabr e faunabr não estão no CRAN; este options() torna o R-universe visível
   options(repos = c(
     ropensci = "https://ropensci.r-universe.dev",
     CRAN     = "https://cloud.r-project.org"
   ))

   install.packages("remotes")
   remotes::install_github("rogerio-onza/saira")
   ```

A primeira instalação pode levar alguns minutos.

### ▶️ Como abrir

```r
library(saira)
run_app()
```

O app abre no navegador.

Notas:

- **Primeira verificação de nomes:** o Saíra baixa uma base taxonômica local na
  primeira vez (uma vez só, precisa de internet); essa verificação inicial demora
  mais.
- **Linux (Debian/Ubuntu):** a dependência `sf` precisa de GDAL, GEOS e PROJ.
  Instale antes: `sudo apt-get install -y libgdal-dev libgeos-dev libproj-dev libudunits2-dev`.
  No Windows e no macOS não há nada extra a fazer.

### 🛠️ Desenvolvimento

```bash
git clone https://github.com/rogerio-onza/saira.git
cd saira
```

```r
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
renv::restore()
pkgload::load_all()
run_app()
```

Testes:

```r
devtools::test()                            # tudo
devtools::test(filter = "rostrum-stage1")   # um arquivo
```

```bash
RUN_PERF=true Rscript -e "devtools::test(filter = 'performance')"  # performance
RUN_E2E=true  Rscript -e "devtools::test(filter = 'e2e')"          # ponta a ponta (shinytest2 + navegador)
```

Antes de abrir um pull request, leia [CONTRIBUTING.md](CONTRIBUTING.md).

### 🧩 Tecnologias e créditos

O Saíra usa pacotes R de código aberto (Shiny, `taxadb`/`florabr`/`faunabr`,
`CoordinateCleaner`/`sf`/`terra`, entre outros) e embute dados de fontes públicas
(camada Natural Earth, termos Darwin Core do TDWG sob CC-BY, Lista Nacional de
Espécies Ameaçadas da Portaria MMA nº 148/2022). Duas correções de coordenadas são
reimplementações independentes inspiradas na abordagem do pacote `bdc`, **sem
reutilização de código nem dependência dele**. A lista completa, com links e
licenças, está em
[Tecnologias e créditos](https://rogerio-onza.github.io/saira/tecnologias.html).

### 📄 Licença

GNU General Public License v3.0 (GPL-3) — veja [LICENSE.md](LICENSE.md).

---

## English

### 🔎 What it is

You have a spreadsheet (CSV or Excel) with species records and need to publish it
in Darwin Core — the set of column names and formats that GBIF and SiBBr expect.
Saíra loads the spreadsheet, helps you map your columns to Darwin Core terms,
validates names and coordinates, and produces the final archive.

The app opens in your browser; you work through menus, buttons, and tables. Code,
only at install time.

### 🔄 How it works

1. **Upload** — load your CSV or Excel file.
2. **Mapping** — match each column to a Darwin Core term (with automatic suggestions).
3. **Validation** — check scientific names and coordinates.
4. **Export** — download the standardized file, ready for GBIF/IPT.

### ✨ Features

- Reads CSV and Excel.
- Column mapping with automatic suggestions for Darwin Core terms.
- Scientific-name verification against taxonomic backbones (spelling and synonyms).
- Coordinate validation: lat/lon ranges, points at sea, country, and swapped
  coordinates, with one-click correction.
- Exports a Darwin Core Archive (`occurrence.txt`, `meta.xml`, `eml.xml`) ready
  for GBIF/IPT, plus an `.xlsx` copy and the mapping guide. The `eml.xml` already
  carries the geographic bounding box and date range computed from your data.
- Stable `occurrenceID`: fills missing IDs deterministically (the same combination
  always yields the same ID), so republishing to GBIF counts as an update, not a
  new record.
- Camera-trap data (optional): imports Camtrap DP packages and Wildlife Insights
  exports. Requires the `camtrapdp` package (`install.packages("camtrapdp")`).

### 📦 Installation

Saíra runs in R. If you have never used R, do this once:

1. Install R (4.1.0 or newer): <https://cloud.r-project.org>.
2. Install RStudio Desktop — where you paste and run commands:
   <https://posit.co/download/rstudio-desktop/>.
3. Open RStudio and, in the Console, paste and run:

   ```r
   # florabr and faunabr are not on CRAN; this options() makes the R-universe visible
   options(repos = c(
     ropensci = "https://ropensci.r-universe.dev",
     CRAN     = "https://cloud.r-project.org"
   ))

   install.packages("remotes")
   remotes::install_github("rogerio-onza/saira")
   ```

The first install may take a few minutes.

### ▶️ Running it

```r
library(saira)
run_app()
```

The app opens in your browser.

Notes:

- **First name check:** Saíra downloads a local taxonomic database the first time
  (one time, needs network); that initial check takes longer.
- **Linux (Debian/Ubuntu):** the `sf` dependency needs GDAL, GEOS, and PROJ.
  Install them first: `sudo apt-get install -y libgdal-dev libgeos-dev libproj-dev libudunits2-dev`.
  On Windows and macOS there is nothing extra to do.

### 🛠️ Development

```bash
git clone https://github.com/rogerio-onza/saira.git
cd saira
```

```r
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
renv::restore()
pkgload::load_all()
run_app()
```

Tests:

```r
devtools::test()                            # everything
devtools::test(filter = "rostrum-stage1")   # a single file
```

```bash
RUN_PERF=true Rscript -e "devtools::test(filter = 'performance')"  # performance
RUN_E2E=true  Rscript -e "devtools::test(filter = 'e2e')"          # end-to-end (shinytest2 + browser)
```

Before opening a pull request, read [CONTRIBUTING.md](CONTRIBUTING.md).

### 🧩 Technologies and credits

Saíra uses open-source R packages (Shiny, `taxadb`/`florabr`/`faunabr`,
`CoordinateCleaner`/`sf`/`terra`, among others) and bundles data from public
sources (Natural Earth layer, Darwin Core terms from TDWG under CC-BY, the
Brazilian Official List of Threatened Species from Portaria MMA nº 148/2022). Two
coordinate corrections are independent reimplementations inspired by the `bdc`
package's approach, **with no code reuse and no dependency on it**. The full list,
with links and licenses, is in [Technologies and credits](https://rogerio-onza.github.io/saira/en/technologies.html).

### 📄 License

GNU General Public License v3.0 (GPL-3) — see [LICENSE.md](LICENSE.md).
