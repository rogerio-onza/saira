# Changelog

Todas as mudancas notaveis do Finch sao documentadas aqui.
Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

---

## [0.1.1] - 2026-02-14

### Alterado
#### Onda 3 - performance de datas
- `parse_dates_to_iso()` refatorada para parsing vetorizado por formato com mascaras estritas
- Regra `DD/MM/YY` com cutoff dinamico por ano atual (`YY <= ano atual (2 digitos) -> 20YY`, senao `19YY`)
- `fix_dates_to_iso()` passa a delegar parsing para `parse_dates_to_iso()` nas colunas `eventDate`, `dateIdentified` e `modified`

#### Onda 4 - modularizacao de mod_mapping
- `processed_data` do `mod_mapping` foi centralizado na funcao pura `build_processed_mapping_df()` em `R/utils_mapping.R`
- Helpers puros de estado/mapeamento foram extraidos para `R/utils_mapping.R` (`has_selected_value`, `sanitize_map_selection`, `default_meta`, `empty_map_values`, `empty_map_meta`, `build_manual_meta`)
- `mod_mapping_server()` manteve assinatura e retorno (`reactive(data.frame)`), preservando wiring reativo e comportamento de UI

### Corrigido
- Semantica de export preservada para invalidos nao vazios: valor bruto mantido em `fix_dates_to_iso()`
- `NA` e string vazia continuam resultando em `NA` nas colunas de data do export

### Adicionado
- Novos testes de regressao: `tests/testthat/test-utils-io.R` e `tests/testthat/test-utils-export.R`
- Script de benchmark 100k: `tests/bench/benchmark_dates_onda3.R`
- Relatorio comparativo da Onda 3: `docs/archive/benchmark_onda3_2026-02-14.md`
- Novos testes de regressao da Onda 4 em `tests/testthat/test-utils-mapping.R` e `tests/testthat/test-mod-mapping-server.R`

---

## [0.1.0] - 2026-02-13

### Adicionado
- **Auto-mapping Rostrum (beta)**: Motor proprietario de mapeamento automatico com scoring por nome + conteudo
- **Badges de confianca**: Indicadores visuais (`AUTO`, `SUGERIDO`, `MANUAL`, `EDITADO`) nos campos mapeados
- **Synonyms table**: Suporte a sinonimos via `dwc_synonyms_v1.rds` para matching fuzzy
- **Loading bloqueante**: Modal com progresso, frases rotativas e icones contextuais durante auto-map
- **Toggle Rostrum**: Switch `bslib::input_switch` para ativar/desativar motor V1
- **Abreviacao de licencas**: CC URLs -> labels curtas (`CC0`, `CC-BY`, `CC-BY-NC`) no preview e export
- **Testes automatizados**: `test-utils-mapping.R` (58 testes) e `test-mod-mapping-server.R` (16 testes)

### Corrigido
#### Onda 2 - i18n consistente
- `app_server` usa `tr("nav_validate", lang_r())` e a tab inicial usa `tr("nav_home", lang_r())`
- `mod_validate_names` e `mod_validate_coords` removem condicionais `if (lang == "pt")` para warnings/sucesso
- `mod_wiki` com placeholder, filtro de classe e headers da tabela traduzidos via `tr()`
- `mod_preview` com textos do DataTable (`search`, `lengthMenu`, `info`) externalizados no dicionario
- `mod_mapping` com placeholders e labels de categorias/idioma ligados ao dicionario
- Novo teste `tests/testthat/test-utils-i18n.R` validando chaves e resolucao PT/EN da Onda 2

#### Ajustes complementares da release
- Badges sumindo apos desmarcar/remarcar categorias (leitura isolada -> reativa)
- `scientificName` aceitava multiplas colunas (agora selecao unica)
- `NA` literal no CSV exportado -> celulas vazias com `readr::write_csv(na = "")`
- Filtro de categorias: selecao vazia mostrava todos os cards (agora mostra nenhum)
- Categoria fantasma `Organism` removida do filtro

#### Onda 1 - estabilidade de pacote/deploy
- `shiny::toJSON` -> `jsonlite::toJSON` (compatibilidade)
- Estabilidade de pacote/deploy: remocao de `source()` em `R/*.R`
- Test helper compativel com tarball de check (sem path local para `R/*.R`)
- `DESCRIPTION`: `jsonlite` adicionado em `Imports`
- `mod_preview`: `head(...)` substituido por `utils::head(...)`
- `utils_i18n::tr()`: resolucao de `i18n_dict` via ambiente/namespace sem `source()`

---

## [0.0.5] - 2026-02-12

### Adicionado
- **Campos especiais no mapeamento**: `datasetName` (dropdown + texto), `modified` (checkbox + calendario), `license` (checkboxes CC), `language` (checkboxes `pt`/`en`/`es`)
- **Concatenacao DwC padronizada**: `;` como separador de entrada, ` | ` como saida
- **Parser de eventDate**: 4 colunas -> `YYYY-MM/YYYY-MM` com fallback para valor bruto
- **Indicador visual de mapeamento**: Borda verde em cards mapeados, sem barra laranja
- Funcoes puras: `normalize_semicolon_tokens`, `collapse_mapped_values`, `build_eventdate_interval`, `detect_eventdate_roles`, `parse_month_to_number`
- Funcoes de derivacao: `extract_scientific_name_components`, `fill_missing_character_values`, `replace_na_with_blank`

### Corrigido
- Cabecalhos de categoria invisiveis: variaveis CSS `--primary-dark`, `--text-muted`, `--border` nao definidas
- Category header redesenhado (gradiente azul escuro com alto contraste)
- Bug de re-render resetando selecoes em campos customizados (fix com `isolate(input$...)`)
- Selecao unica forcada para `license` e `language` via observeEvent server-side

---

## [0.0.4] - 2026-02-09

### Alterado
- Escala tipografica final: `--text-xs: 0.75rem` ate `--text-2xl: 1.75rem`
- Navbar title maior que card headers (`--text-2xl` vs `--text-lg`)
- Card header padding aumentado
- DwC fields em layout horizontal (flex) em vez de grid 4 colunas
- Campos DwC obrigatorios com boxes compactos e padding adequado

### Corrigido
- Encoding corrompido em `data_dictionary.R` (caracteres acentuados restaurados)

---

## [0.0.3] - 2026-02-09

### Adicionado
- Dashboard de Qualidade de Dados apos upload (colunas vazias, tipos detectados)
- Notificacao de sucesso em verde (`#2d6a4f`)
- Alertas e notificacoes em negrito

### Alterado
- Nav "Upload" -> "Inicio" com icone `fa-home`
- Font base aumentada para `1rem`
- Stats boxes em largura completa (`flex: 1 1 0`)
- Input group de upload com botao/campo conectados (sem gap)

### Removido
- Rodape com logos de financiamento (Observatorio, Zhouse, Humanize)

---

## [0.0.2] - 2026-02-08

### Adicionado
- Logo hexagonal no navbar (72px)
- FontAwesome 6.5.1 CDN (classic solid)
- Layout de duas colunas na home: Dados (5) + Bem-vindo (7)
- Workflow visual com 4 passos (Upload -> Mapeamento -> Validacao -> Exportar)
- Privacy alert: "Todos os dados processados localmente"
- 50+ strings i18n no `data_dictionary.R`
- ~200 linhas de CSS para novos componentes

### Corrigido
- Botao de upload: texto ilegivel (amarelo sobre amarelo) -> cores explicitas com `!important`
- Cards de estatisticas compactados -> padding restaurado
- Limite de upload: 500 MB (antes sem limite definido)
- Botao de upload: icon-only (40x40px) com height sincronizada

---

## [0.0.1] - 2026-02-08

### Corrigido
- `DESCRIPTION`: linhas vazias entre secoes removidas
- `DESCRIPTION`: dependencia `here` adicionada ao Imports
- `app_ui.R`: `nav_spacer()` -> `bslib::nav_spacer()` (namespace)
- `utils_dwc.R`: contagem de vetores incompativel (`rep("Taxon", 15)` -> `14`)
