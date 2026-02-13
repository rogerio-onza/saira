# Changelog

Todas as mudanÃ§as notÃ¡veis do Finch sÃ£o documentadas aqui.
Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

---

## [0.1.0] - 2026-02-13

### Adicionado
- **Auto-mapping Rostrum (beta)**: Motor proprietÃ¡rio de mapeamento automÃ¡tico com scoring por nome + conteÃºdo
- **Badges de confianÃ§a**: Indicadores visuais (`AUTO`, `SUGERIDO`, `MANUAL`, `EDITADO`) nos campos mapeados
- **Synonyms table**: Suporte a sinÃ´nimos via `dwc_synonyms_v1.rds` para matching fuzzy
- **Loading bloqueante**: Modal com progresso, frases rotativas e Ã­cones contextuais durante auto-map
- **Toggle Rostrum**: Switch `bslib::input_switch` para ativar/desativar motor V1
- **AbreviaÃ§Ã£o de licenÃ§as**: CC URLs â†’ labels curtas (`CC0`, `CC-BY`, `CC-BY-NC`) no preview e export
- **Testes automatizados**: `test-utils-mapping.R` (58 testes) e `test-mod-mapping-server.R` (16 testes)

### Corrigido
- Badges sumindo apÃ³s desmarcar/remarcar categorias (leitura isolada â†’ reativa)
- `scientificName` aceitava mÃºltiplas colunas (agora seleÃ§Ã£o Ãºnica)
- `NA` literal no CSV exportado â†’ cÃ©lulas vazias com `readr::write_csv(na = "")`
- Filtro de categorias: seleÃ§Ã£o vazia mostrava todos os cards (agora mostra nenhum)
- Categoria fantasma `Organism` removida do filtro
- `shiny::toJSON` â†’ `jsonlite::toJSON` (compatibilidade)
- Estabilidade de pacote/deploy: remocao de `source()` em `R/*.R`
- Test helper compativel com tarball de check (sem path local para `R/*.R`)
- `DESCRIPTION`: `jsonlite` adicionado em `Imports`
- `mod_preview`: `head(...)` substituido por `utils::head(...)`
- `utils_i18n::tr()`: resolucao de `i18n_dict` via ambiente/namespace sem `source()`

---

## [0.0.5] - 2026-02-12

### Adicionado
- **Campos especiais no mapeamento**: `datasetName` (dropdown + texto), `modified` (checkbox + calendÃ¡rio), `license` (checkboxes CC), `language` (checkboxes `pt`/`en`/`es`)
- **ConcatenaÃ§Ã£o DwC padronizada**: `;` como separador de entrada, ` | ` como saÃ­da
- **Parser de eventDate**: 4 colunas â†’ `YYYY-MM/YYYY-MM` com fallback para valor bruto
- **Indicador visual de mapeamento**: Borda verde em cards mapeados, sem barra laranja
- FunÃ§Ãµes puras: `normalize_semicolon_tokens`, `collapse_mapped_values`, `build_eventdate_interval`, `detect_eventdate_roles`, `parse_month_to_number`
- FunÃ§Ãµes de derivaÃ§Ã£o: `extract_scientific_name_components`, `fill_missing_character_values`, `replace_na_with_blank`

### Corrigido
- CabeÃ§alhos de categoria invisÃ­veis: variÃ¡veis CSS `--primary-dark`, `--text-muted`, `--border` nÃ£o definidas
- Category header redesenhado (gradiente azul escuro com alto contraste)
- Bug de re-render resetando seleÃ§Ãµes em campos customizados (fix com `isolate(input$...)`)
- SeleÃ§Ã£o Ãºnica forÃ§ada para `license` e `language` via observeEvent server-side

---

## [0.0.4] - 2026-02-09

### Alterado
- Escala tipogrÃ¡fica final: `--text-xs: 0.75rem` atÃ© `--text-2xl: 1.75rem`
- Navbar title maior que card headers (`--text-2xl` vs `--text-lg`)
- Card header padding aumentado
- DwC fields em layout horizontal (flex) em vez de grid 4 colunas
- Campos DwC obrigatÃ³rios com boxes compactos e padding adequado

### Corrigido
- Encoding corrompido em `data_dictionary.R` (`obrigatÃƒÂ³rios` â†’ `obrigatÃ³rios`)

---

## [0.0.3] - 2026-02-09

### Adicionado
- Dashboard de Qualidade de Dados apÃ³s upload (colunas vazias, tipos detectados)
- NotificaÃ§Ã£o de sucesso em verde (`#2d6a4f`)
- Alertas e notificaÃ§Ãµes em negrito

### Alterado
- Nav "Upload" â†’ "InÃ­cio" com Ã­cone `fa-home`
- Font base aumentada para `1rem`
- Stats boxes em largura completa (`flex: 1 1 0`)
- Input group de upload com botÃ£o/campo conectados (sem gap)

### Removido
- RodapÃ© com logos de financiamento (ObservatÃ³rio, Zhouse, Humanize)

---

## [0.0.2] - 2026-02-08

### Adicionado
- Logo hexagonal no navbar (72px)
- FontAwesome 6.5.1 CDN (classic solid)
- Layout de duas colunas na home: Dados (5) + Bem-vindo (7)
- Workflow visual com 4 passos (Upload â†’ Mapeamento â†’ ValidaÃ§Ã£o â†’ Exportar)
- Privacy alert: "Todos os dados processados localmente"
- 50+ strings i18n no `data_dictionary.R`
- ~200 linhas de CSS para novos componentes

### Corrigido
- BotÃ£o de upload: texto ilegÃ­vel (amarelo sobre amarelo) â†’ cores explÃ­citas com `!important`
- Cards de estatÃ­sticas compactados â†’ padding restaurado
- Limite de upload: 500 MB (antes sem limite definido)
- BotÃ£o de upload: icon-only (40Ã—40px) com height sincronizada

---

## [0.0.1] - 2026-02-08

### Corrigido
- `DESCRIPTION`: linhas vazias entre seÃ§Ãµes removidas
- `DESCRIPTION`: dependÃªncia `here` adicionada ao Imports
- `app_ui.R`: `nav_spacer()` â†’ `bslib::nav_spacer()` (namespace)
- `utils_dwc.R`: contagem de vetores incompatÃ­vel (`rep("Taxon", 15)` â†’ `14`)
