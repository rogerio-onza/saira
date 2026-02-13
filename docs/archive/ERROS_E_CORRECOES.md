# Finch App - Erros e Correções

> Documento de referência com todos os erros encontrados durante o desenvolvimento e suas correções.

---

## 1. DESCRIPTION - Linhas Vazias

**Erro:**
```
Error: Empty lines found in DESCRIPTION file
```

**Causa:** O arquivo DESCRIPTION continha linhas em branco entre seções, o que não é permitido pelo padrão de pacotes R.

**Correção:** Remover todas as linhas vazias do arquivo DESCRIPTION. Cada campo deve seguir imediatamente após o anterior.

```diff
- License: MIT + file LICENSE
- 
- Imports:
+ License: MIT + file LICENSE
+ Imports:
```

---

## 2. DESCRIPTION - Dependência Faltando (`here`)

**Erro:**
```
Error in here::here() : could not find package 'here'
```

**Causa:** O pacote `here` era usado nos arquivos R mas não estava listado no DESCRIPTION.

**Correção:** Adicionar `here (>= 1.0.0)` na seção `Imports` do DESCRIPTION.

---

## 3. Função `nav_spacer()` Não Encontrada

**Erro:**
```
Error in nav_spacer() : could not find function "nav_spacer"
```

**Causa:** A função `nav_spacer()` pertence ao pacote `bslib` mas foi chamada sem o prefixo de namespace.

**Correção:** Em `R/app_ui.R`, alterar:
```diff
- nav_spacer(),
+ bslib::nav_spacer(),
```

---

## 4. `utils_dwc.R` - Contagem Incompatível de Vetores

**Erro:**
```
Error in data.frame() : arguments imply differing number of rows: 50, 51
```

**Causa:** O vetor `class` declarava `rep("Taxon", 15)` mas a seção Taxon na lista `term` tinha apenas 14 termos.

**Correção:** Em `R/utils_dwc.R`, alterar todas as referências de 15 para 14 nas seções Taxon:

```diff
- rep("Taxon", 15),
+ rep("Taxon", 14),
```

Aplicar em: `class`, `required`, e `data_type`.

---

## 5. Diretório de Trabalho Incorreto

**Erro:**
```
Error: Could not find a root 'DESCRIPTION' file that starts with '^Package'
```

**Causa:** O comando `pkgload::load_all()` foi executado no diretório pai em vez do diretório do pacote.

**Correção:** Definir o diretório correto antes de carregar:
```r
setwd("c:/Users/Admin/OneDrive/Finch - Claude/finch")
pkgload::load_all()
```

---

## Resumo de Arquivos Modificados

| Arquivo | Tipo de Correção |
|---------|------------------|
| `DESCRIPTION` | Linhas vazias + dependências |
| `R/app_ui.R` | Namespace bslib:: |
| `R/utils_dwc.R` | Contagem de vetores |

---

## Como Executar o App

```r
setwd("c:/Users/Admin/OneDrive/Finch - Claude/finch")
pkgload::load_all()
run_app()
```

---

## 6. Correções da Página Inicial (08/02/2026)

**Solicitação:**
- Adicionar logo do Finch no navbar
- Usar ícones FontAwesome classic solid em todo o app
- Reestruturar página inicial em duas colunas

### 6.1 Logo Atualizado

**Alteração:** Em `R/app_ui.R`, alterado logo de `finch_alone.png` para `hexagon_logo.png`.

```diff
- src = "www/images/finch_alone.png",
- height = "32px",
+ src = "www/images/hexagon_logo.png",
+ height = "36px",
```

### 6.2 FontAwesome CDN

**Alteração:** Adicionado link para FontAwesome 6.5.1 (classic solid) no `tags$head` em `R/app_ui.R`.

```r
shiny::tags$link(
    rel = "stylesheet",
    href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"
)
```

### 6.3 Layout de Duas Colunas

**Alteração:** `R/mod_upload.R` completamente reescrito.

**Coluna 1 - Dados:**
- Título: `[fa-database] Dados`
- Botão upload: Apenas ícone `[fa-upload]`
- Box de especificações:
  - Tamanho máximo: 1 GB
  - Encodings: UTF-8, Latin-1
- Alert de privacidade: `[fa-lock] Todos os dados processados localmente`
- Recomendação: `[fa-lightbulb] Utilize ; como separador`

**Coluna 2 - Bem-vindo:**
- Título: "Bem-vindo ao Finch!"
- Descrição do objetivo (padronização DwC)
- Workflow com 4 passos:
  1. `[fa-upload]` Upload
  2. `[fa-arrows-alt]` Mapeamento
  3. `[fa-check-circle]` Validação
  4. `[fa-download]` Exportar
- Logos de financiamento (Observatório, Zhouse, Humanize)

### 6.4 Novas Strings i18n

**Alteração:** `R/data_dictionary.R` atualizado com 50+ novas strings para suportar PT/EN.

Novas chaves:
- `upload_data_title`, `upload_max_size`, `upload_encoding_info`
- `upload_no_file`, `upload_privacy_alert`, `upload_recommendation`
- `welcome_title`, `welcome_description`
- `workflow_title`, `workflow_step1..4`, `workflow_step1_desc..4_desc`
- `financing_title`

### 6.5 Novos Estilos CSS

**Alteração:** `inst/app/www/custom.css` expandido com ~200 linhas de novos estilos.

Novos componentes:
- `.upload-section` - Container do upload
- `.file-specs-box` - Caixa de especificações de arquivo
- `.privacy-alert` - Alert de privacidade
- `.recommendation-box` - Caixa de recomendações
- `.workflow-steps`, `.workflow-step`, `.step-icon`, `.step-content` - Workflow
- `.financing-logos`, `.logo-row`, `.logo-item`, `.logo-round`, `.logo-rect` - Logos

---

## Resumo de Arquivos Modificados (Atualizado)

| Arquivo | Tipo de Correção |
|---------|------------------|
| `DESCRIPTION` | Linhas vazias + dependências |
| `R/app_ui.R` | Namespace bslib::, Logo, FontAwesome |
| `R/utils_dwc.R` | Contagem de vetores |
| `R/mod_upload.R` | Layout duas colunas, novos componentes |
| `R/data_dictionary.R` | +50 novas strings i18n |
| `inst/app/www/custom.css` | +200 linhas de estilos |

---

## Como Executar o App

```r
setwd("c:/Users/Admin/OneDrive/Finch - Claude/finch")
pkgload::load_all()
run_app()
```

---

## 7. Correções de Interface - Rodada 2 (08/02/2026)

**Solicitações do usuário:**
1. Logo do Finch maior (como nos pacotes R)
2. Abas do header à esquerda, seletor de idioma à direita
3. Alinhar elementos do header com logo e nome
4. Colunas da página inicial preenchendo todo o espaço
5. Coluna "Bem-vindo" maior que coluna "Dados"
6. Espaço entre botão de upload e caixa de arquivo
7. Texto placeholder "Nenhum arquivo selecionado"
8. Corrigir limite de upload para 500 MB
9. Corrigir texto de tamanho máximo para 1 GB

### 7.1 Logo Maior (56px)

**Arquivo:** `R/app_ui.R`

```diff
- height = "36px",
- style = "margin-right: 8px;",
+ height = "56px",
+ class = "navbar-logo",
```

### 7.2 Header Alinhado

**Arquivo:** `inst/app/www/custom.css`

Adicionados estilos para:
- `.navbar-logo` - Logo 56px com alinhamento vertical
- `.navbar-title` - Título "Finch" alinhado
- `.navbar-nav` - Alinhamento de itens
- `.navbar .nav-item:has(.form-select)` - Seletor de idioma à direita com `margin-left: auto`

### 7.3 Layout de Colunas Expandido

**Arquivo:** `R/mod_upload.R`

```diff
- class = "container-fluid",
- style = "max-width: 1200px; margin: 2rem auto;",
+ class = "container-fluid homepage-container",
```

```diff
- width = 6,  # Coluna Dados
+ width = 5,  # Coluna Dados (menor)
```

```diff
- width = 6,  # Coluna Bem-vindo
+ width = 7,  # Coluna Bem-vindo (maior)
```

### 7.4 Espaçamento do Upload

**Arquivo:** `inst/app/www/custom.css`

Novos estilos:
- `.homepage-container` - Container com padding adequado
- `.upload-section .shiny-input-container` - Flexbox com gap de 1rem
- `.upload-section .btn-file` - Padding maior, alinhamento com ícone e texto
- `.upload-section .form-control` - Caixa de placeholder estilizada

**Arquivo:** `R/mod_upload.R`

```diff
- buttonLabel = shiny::tags$span(
-     shiny::icon("upload", class = "fa-solid"),
-     style = "padding: 0 4px;"
- ),
- placeholder = ""
+ buttonLabel = shiny::tags$span(
+     shiny::icon("upload", class = "fa-solid"),
+     " ",
+     shiny::uiOutput(ns("upload_btn_text"), inline = TRUE)
+ ),
+ placeholder = shiny::uiOutput(ns("file_placeholder_text"), inline = TRUE)
```

### 7.5 Limite de Upload 500 MB

**Arquivo:** `R/run_app.R`

```r
run_app <- function(...) {
    # Set max upload file size to 500 MB
    options(shiny.maxRequestSize = 500 * 1024^2)
    # ...
}
```

### 7.6 Nova String i18n

**Arquivo:** `R/data_dictionary.R`

```r
upload_btn_label = list(
    pt = "Enviar",
    en = "Upload"
),
```

---

## Resumo de Arquivos Modificados (Rodada 2)

| Arquivo | Modificações |
|---------|--------------|
| `R/app_ui.R` | Logo 56px, classes navbar-logo e navbar-title |
| `R/mod_upload.R` | Layout 5+7, homepage-container, botão com texto |
| `R/run_app.R` | Limite 500 MB |
| `R/data_dictionary.R` | String upload_btn_label |
| `inst/app/www/custom.css` | +60 linhas: navbar, homepage-container, upload-section |

---

## 8. Correções de Layout e Hierarquia Visual - Rodada 3 (08/02/2026)

**Solicitações do usuário:**
1. Logo significativamente maior
2. Menu de navegação movido para a esquerda
3. Seletor de idioma no extremo direito
4. Botões de upload com CSS corrigido
5. Texto informativo: "500 MB" (não "1 GB")
6. Terceiro card mostra tamanho do arquivo (não encoding)
7. Cards de status compactos (não esticados)
8. Lista "Como funciona" com largura limitada

### 8.1 Header Reorganizado

**Arquivo:** `R/app_ui.R`

- Logo aumentado para **72px**
- Todos os `nav_panel` vêm ANTES do `nav_spacer`
- `nav_spacer()` + seletor de idioma agora são os **últimos itens**
- Novo wrapper: `navbar-brand-wrapper`

```diff
- title = shiny::tags$span(
+ title = shiny::tags$div(
+     class = "navbar-brand-wrapper",
      shiny::tags$img(
-         height = "56px",
+         height = "72px",
          ...
      )
  )
```

### 8.2 Texto de Tamanho Máximo Corrigido

**Arquivo:** `R/data_dictionary.R`

```diff
- pt = "Tamanho máximo de arquivo: 1 GB"
+ pt = "Tamanho máximo de arquivo: 500 MB"
```

### 8.3 Card de Estatísticas: Tamanho do Arquivo

**Arquivo:** `R/mod_upload.R`

```r
# Cálculo do tamanho do arquivo
file_size_bytes <- file.info(input$file$datapath)$size
file_size_mb <- round(file_size_bytes / (1024 * 1024), 1)
file_size_str <- paste0(file_size_mb, " MB")
```

Substituído terceiro card de "UTF-8" por tamanho do arquivo.

### 8.4 Cards de Status Compactos

**Arquivo:** `R/mod_upload.R`

```diff
- shiny::fluidRow(
-     class = "mt-4",
-     shiny::column(width = 4, ...)
- )
+ shiny::div(
+     class = "stats-container",
+     shiny::div(class = "stat-box", ...)
+ )
```

**Arquivo:** `inst/app/www/custom.css`

```css
.stats-container {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-4);
}

.stat-box {
  min-width: 100px;
  max-width: 140px;
  flex: 0 0 auto;
}
```

### 8.5 Workflow Steps com Largura Limitada

**Arquivo:** `inst/app/www/custom.css`

```css
.workflow-steps {
  max-width: 500px;
}
```

### 8.6 Navbar CSS Atualizado

```css
.navbar {
  min-height: 80px;
}

.navbar-brand-wrapper {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.navbar-logo {
  height: 72px;
}

.navbar-title {
  font-size: 1.5rem;
}
```

---

## Resumo de Arquivos Modificados (Rodada 3)

| Arquivo | Modificações |
|---------|--------------|
| `R/app_ui.R` | Logo 72px, navbar-brand-wrapper, tabs antes de nav_spacer |
| `R/mod_upload.R` | stats-container, cálculo de tamanho de arquivo em MB |
| `R/data_dictionary.R` | Texto "500 MB", label upload_stats_size |
| `inst/app/www/custom.css` | navbar 80px, stat-box compacto, workflow max-width |

---

## 9. Correção de Regressões CSS - Rodada 4 (08/02/2026)

**Problemas reportados:**
1. Botões de upload quebrados (texto ilegível, amarelo sobre amarelo)
2. Cards de estatísticas muito compactados (sem espaço interno)

### 9.1 Correção do Input Group de Upload

**Arquivo:** `inst/app/www/custom.css`

O Shiny `fileInput` gera um `input-group` do Bootstrap. Corrigido para:

```css
/* Input group - container para botão + filename */
.upload-section .input-group {
  display: flex;
  align-items: stretch;
  gap: var(--space-3);
  flex-wrap: nowrap;
}

/* Botão de upload com cores explícitas */
.upload-section .btn-file,
.upload-section .input-group .btn {
  background-color: var(--primary) !important;
  border-color: var(--primary) !important;
  color: var(--text-primary) !important;
  white-space: nowrap;
}

/* Caixa de nome do arquivo */
.upload-section .form-control {
  color: var(--text-primary) !important;
  min-width: 200px;
}
```

### 9.2 Cards de Estatísticas Restaurados

**Problema:** Cards "Registros", "Colunas", "Tamanho" muito espremidos.

**Correção:**

```diff
  .stat-box {
-   padding: var(--space-4);
-   min-width: 100px;
-   max-width: 140px;
+   padding: var(--space-5) var(--space-6);
+   min-width: 140px;
+   /* removido max-width para permitir crescimento natural */
  }

  .stat-box .stat-value {
+   margin-bottom: var(--space-1);
  }
```

---

## Resumo de Arquivos Modificados (Rodada 4)

| Arquivo | Modificações |
|---------|--------------|
| `inst/app/www/custom.css` | input-group styling, stat-box padding ampliado, cores explícitas |

---

## 10. Botão de Upload Icon-Only e Alinhamento - Rodada 5 (08/02/2026)

**Solicitações:**
1. Botão apenas com ícone (sem texto "Enviar")
2. Botão quadrado/compacto (40px)
3. Altura sincronizada com caixa de arquivo
4. Gap mínimo (4px) entre elementos
5. Barra de progresso com texto escuro

### 10.1 Botão Icon-Only

**Arquivo:** `R/mod_upload.R`

```diff
- buttonLabel = shiny::tags$span(
-     shiny::icon("upload", class = "fa-solid"),
-     " ",
-     shiny::uiOutput(ns("upload_btn_text"), inline = TRUE)
- )
+ buttonLabel = shiny::icon("upload", class = "fa-solid")
```

### 10.2 CSS: Layout em Duas Linhas

**Arquivo:** `inst/app/www/custom.css`

```css
/* Container flex-column */
.upload-section .shiny-input-container {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

/* Row 1: botão + filename alinhados */
.upload-section .input-group {
  display: flex;
  align-items: stretch;
  gap: 4px;
}

/* Botão quadrado 40x40px */
.upload-section .btn-file {
  width: 40px;
  height: 40px;
  padding: 0;
  justify-content: center;
}

/* Caixa de arquivo - mesma altura */
.upload-section .form-control {
  height: 40px;
  font-family: var(--font-mono);
}

/* Row 2: Barra de progresso com texto escuro */
.upload-section .progress-bar {
  color: var(--text-primary) !important;
}
```

---

## Resumo de Arquivos Modificados (Rodada 5)

| Arquivo | Modificações |
|---------|--------------|
| `R/mod_upload.R` | buttonLabel icon-only |
| `inst/app/www/custom.css` | flex-column layout, 40px heights, progress text dark |

---

## 11. Melhorias de UX/UI - Rodada 6 (09/02/2026)

**Solicitações do usuário:**
1. Navegação "Início" em vez de "Upload" no header
2. Dashboard de Qualidade de Dados após upload
3. Aumentar tamanho base da fonte (+0.2rem)
4. Notificação de sucesso em verde (#2d6a4f)
5. Texto de alertas em negrito
6. Remover rodapé com logos de financiamento
7. Stats boxes ocupando largura completa
8. Input de upload com botão/campo conectados

### 11.1 Header: Botão "Início"

**Arquivo:** `R/app_ui.R`

```diff
-        # Tab: Upload (comes first - left side)
-        bslib::nav_panel(
-            title = shiny::uiOutput("nav_upload_title"),
-            value = "upload",
-            icon = shiny::icon("upload"),
+        # Tab: Início (Home) - first item on left side
+        bslib::nav_panel(
+            title = shiny::tags$span(
+                shiny::icon("home", class = "fa-solid"),
+                " Início"
+            ),
+            value = "upload",
```

### 11.2 CSS: Tipografia e Cores

**Arquivo:** `inst/app/www/custom.css`

```diff
 body {
-  font-size: var(--text-base);  /* 0.9rem */
+  font-size: 1rem;  /* Increased from 0.9rem */
 }

 .shiny-notification-message {
-  background-color: var(--info-bg);
-  border-left: 4px solid var(--info);
-  color: var(--info);
+  background-color: var(--success-bg);
+  border-left: 4px solid var(--success);
+  color: var(--success);
 }

 .alert {
+  font-weight: var(--weight-bold);
 }

+.shiny-notification {
+  font-weight: var(--weight-bold);
+}
```

### 11.3 CSS: Stats em Largura Completa

**Arquivo:** `inst/app/www/custom.css`

```diff
 .stats-container {
-  flex-wrap: wrap;
+  flex-wrap: nowrap;
+  justify-content: space-between;
+  width: 100%;
 }

 .stat-box {
-  min-width: 140px;
-  flex: 0 0 auto;
+  flex: 1 1 0;
+  min-width: 0;
 }
```

### 11.4 CSS: Input Group Conectado

**Arquivo:** `inst/app/www/custom.css`

```css
.upload-section .input-group {
  gap: 0;  /* Remove gap */
}

.upload-section .btn-file {
  border-radius: var(--radius) 0 0 var(--radius);  /* Right flat */
}

.upload-section .form-control {
  border-left: none;
  border-radius: 0 var(--radius) var(--radius) 0;  /* Left flat */
}
```

### 11.5 Remoção do Rodapé de Financiamento

**Arquivo:** `R/mod_upload.R`

Removida toda a seção `financing-logos` contendo logos de Observatório, Zhouse e Humanize.

### 11.6 Dashboard de Qualidade de Dados

**Arquivo:** `R/mod_upload.R`

Nova seção `data_quality` adicionada na coluna "Bem-vindo" que exibe:
- Contagem de colunas vazias
- Total de linhas
- Tipos detectados (numeric, text, date)

### 11.7 Novas Strings i18n

**Arquivo:** `R/data_dictionary.R`

```r
data_quality_title = list(pt = "Qualidade dos Dados", en = "Data Quality"),
data_quality_empty_cols = list(pt = "Colunas Vazias", en = "Empty Columns"),
data_quality_types = list(pt = "Tipos Detectados", en = "Detected Types"),
data_quality_rows = list(pt = "Total de Linhas", en = "Total Rows")
```

---

## Resumo de Arquivos Modificados (Rodada 6)

| Arquivo | Modificações |
|---------|--------------|
| `R/app_ui.R` | Nav "Início" com ícone home |
| `R/mod_upload.R` | Removido footer, adicionado data_quality |
| `R/data_dictionary.R` | +4 strings i18n para dashboard |
| `inst/app/www/custom.css` | font 1rem, green notifications, bold alerts, full-width stats, connected input |

---

## 12. Correções de Tipografia e Layout - Rodada 7 (09/02/2026)

**Solicitações do usuário:**
1. Diminuir escala tipográfica em 0.1rem de maneira harmônica
2. Aumentar padding nos boxes de header dos campos obrigatórios DwC
3. Aumentar espaçamento entre os boxes
4. Corrigir encoding do texto "Campos obrigatórios" (caracteres corrompidos)
5. Ajustar layout para caber na página sem scroll

### 12.1 Escala Tipográfica Reduzida

**Arquivo:** `inst/app/www/custom.css`

```diff
- --text-xs: 0.8rem;
- --text-sm: 0.95rem;
- --text-base: 1.15rem;
- --text-md: 1.3rem;
- --text-lg: 1.45rem;
- --text-xl: 1.6rem;
- --text-2xl: 1.8rem;
+ --text-xs: 0.7rem;
+ --text-sm: 0.85rem;
+ --text-base: 1.05rem;
+ --text-md: 1.2rem;
+ --text-lg: 1.35rem;
+ --text-xl: 1.5rem;
+ --text-2xl: 1.7rem;
```

### 12.2 Layout DwC Campos Obrigatórios

**Arquivo:** `inst/app/www/custom.css`

```diff
  .dwc-required {
-   margin-top: var(--space-5);
-   padding-top: var(--space-4);
+   margin-top: var(--space-3);
+   padding-top: var(--space-2);
  }

+ .dwc-required h5 {
+   font-size: var(--text-base);
+   margin-bottom: var(--space-1);
+ }

  .dwc-required-hint {
-   font-size: var(--text-sm);
-   margin-bottom: var(--space-3);
+   font-size: var(--text-xs);
+   margin-bottom: var(--space-2);
  }

  .dwc-required-groups {
-   grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
-   gap: var(--space-3);
+   grid-template-columns: repeat(4, 1fr);
+   gap: var(--space-4);
  }

  .dwc-group {
-   padding: var(--space-3);
+   padding: var(--space-4) var(--space-5);
  }
```

### 12.3 Correção de Encoding

**Arquivo:** `R/data_dictionary.R`

```diff
- dwc_required_title = list(pt = "Campos obrigatÃ³rios do DwC", ...)
+ dwc_required_title = list(pt = "Campos obrigatórios do DwC", ...)

- pt = "Passe o mouse para ver a definiÃ§Ã£o de cada termo."
+ pt = "Passe o mouse para ver a definição de cada termo."

- pt = "Nenhum campo obrigatÃ³rio encontrado."
+ pt = "Nenhum campo obrigatório encontrado."
```

---

## Resumo de Arquivos Modificados (Rodada 7)

| Arquivo | Modificações |
|---------|--------------|
| `inst/app/www/custom.css` | Escala tipográfica -0.1rem, layout DwC compacto, padding/gap aumentados |
| `R/data_dictionary.R` | Encoding UTF-8 corrigido nas strings DwC |

---

## 13. Hierarquia Tipográfica Harmoniosa - Rodada 8 (09/02/2026)

**Solicitações do usuário:**
1. Título do header (Finch) maior que títulos das colunas
2. Campos DwC em linha horizontal (não colunas)
3. Boxes compactos, não ocupando largura total
4. Padding maior nos card headers
5. Proposta de tamanhos harmoniosos para todo o app

### 13.1 Nova Escala Tipográfica

**Arquivo:** `inst/app/www/custom.css`

| Variável | Antes | Depois | Uso |
|----------|-------|--------|-----|
| `--text-xs` | 0.7rem | 0.75rem | Chips, badges |
| `--text-sm` | 0.85rem | 0.8rem | Hints, labels |
| `--text-base` | 1.05rem | 0.95rem | Body text |
| `--text-md` | 1.2rem | 1.1rem | Section titles |
| `--text-lg` | 1.35rem | 1.25rem | Card headers |
| `--text-xl` | 1.5rem | 1.5rem | (inalterado) |
| `--text-2xl` | 1.7rem | 1.75rem | Navbar title |

### 13.2 Navbar Title Maior

```diff
  .navbar-title, .navbar-brand {
-   font-size: var(--text-xl);  /* 1.5rem */
+   font-size: var(--text-2xl); /* 1.75rem */
  }
```

### 13.3 Card Header Padding Aumentado

```diff
  .card-header {
-   padding: var(--space-4) var(--space-5);
+   padding: var(--space-5) var(--space-6);
  }
```

### 13.4 DwC Fields em Layout Horizontal

```diff
  .dwc-required-groups {
-   display: grid;
-   grid-template-columns: repeat(4, 1fr);
-   gap: var(--space-4);
+   display: flex;
+   flex-wrap: wrap;
+   gap: var(--space-3);
  }

  .dwc-group {
-   padding: var(--space-4) var(--space-5);
+   padding: var(--space-3) var(--space-4);
+   flex: 0 0 auto;
  }
```

---

## Resumo de Arquivos Modificados (Rodada 8)

| Arquivo | Modificações |
|---------|--------------|
| `inst/app/www/custom.css` | Nova escala tipográfica, navbar 1.75rem, card-header padding, DwC flex horizontal |

---

## 14. Cabeçalhos de Categoria Invisíveis no Mapeamento - Rodada 9 (10/02/2026)

**Problema reportado:**
Os cabeçalhos das categorias ("Record-level", "Occurrence", "Event", etc.) não apareciam na tela de mapeamento de colunas. Os campos estavam todos listados sem separação visual por categoria.

### 14.1 Diagnóstico

**Causa raiz:** O CSS usava 3 variáveis CSS **não definidas** no `:root`:

| Variável ausente | Onde era usada | Impacto |
|------------------|----------------|---------|
| `--primary-dark` | `.category-header` (gradiente de fundo) | Gradiente quebrado → fundo amarelo puro com texto branco = ilegível |
| `--text-muted` | `.field-desc`, `.stats-label` | Descrições dos campos sem cor definida |
| `--border` | `.field-card`, `.stats-box`, `.selectize-input` | Bordas sem estilo consistente |

O código R em `mod_mapping.R` (linha 178) gerava corretamente os cabeçalhos:
```r
shiny::div(class = "category-header", cat)
```

Mas o CSS em `custom.css` definia:
```css
.category-header {
  background: linear-gradient(135deg, var(--primary) 0%, var(--primary-dark) 100%);
  color: white;
}
```

Como `--primary-dark` não existia, o gradiente resultava em fundo amarelo (#ffc300) com texto branco — praticamente invisível.

### 14.2 Correção: Variáveis CSS Adicionadas

**Arquivo:** `inst/app/www/custom.css`

Adicionadas ao `:root`:
```css
--primary-dark: #cc9c00;    /* Versão escura do amarelo */
--border: rgba(0, 53, 102, 0.15);  /* Igual ao --border-default */
--text-muted: #6c757d;      /* Cinza padrão para texto secundário */
```

### 14.3 Correção: Category Header Redesenhado

**Arquivo:** `inst/app/www/custom.css`

```diff
  .category-header {
-   background: linear-gradient(135deg, var(--primary) 0%, var(--primary-dark) 100%);
-   color: white;
-   padding: var(--space-3) var(--space-4);
-   margin: var(--space-4) 0 var(--space-3) 0;
+   background: linear-gradient(135deg, var(--accent) 0%, var(--text-primary) 100%);
+   color: #ffffff;
+   padding: var(--space-3) var(--space-5);
+   margin: var(--space-6) 0 var(--space-3) 0;
+   font-family: var(--font-mono);
+   box-shadow: var(--shadow);
  }

+ .category-header:first-child {
+   margin-top: 0;
+ }
```

Agora usa gradiente azul escuro (`--accent` → `--text-primary`) com texto branco — alto contraste e legível.

---

## Resumo de Arquivos Modificados (Rodada 9)

| Arquivo | Modificações |
|---------|--------------|
| `inst/app/www/custom.css` | +3 variáveis CSS faltantes, category-header redesenhado (azul escuro) |

---

## 15. Campos Especiais no Mapeamento Record-Level - Rodada 10 (10/02/2026)

**Solicitação:** 4 campos do Record-level precisam de inputs customizados no mapeamento.

### 15.1 datasetName — Dropdown + Campo de Texto

**Arquivo:** `R/mod_mapping.R`

Dropdown de colunas do CSV (sem label acima), com `textInput` separado abaixo para digitar/colar valor fixo. Texto digitado tem **prioridade** sobre dropdown.

### 15.2 modified — Checkbox "Usar data de hoje" + Calendário (sempre visível)

**Arquivo:** `R/mod_mapping.R`

- `checkboxInput` **desmarcado por padrão** — o usuário deve escolher ativamente
- `dateInput` sempre visível abaixo (sem conditionalPanel)
- Se checkbox marcado → `Sys.time()` em **ISO 8601** (`YYYY-MM-DDTHH:MM:SSZ`)
- Se checkbox desmarcado → usa a data escolhida no calendário (`YYYY-MM-DD`)

### 15.3 license — Checkboxes Quadrados (seleção única)

**Arquivo:** `R/mod_mapping.R`

- Usa `checkboxGroupInput` para obter checkboxes quadrados (padrão visual do app)
- **Seleção única forçada** via `observeEvent` server-side (mantém apenas o último selecionado)
- Três opções com URLs oficiais Creative Commons:
  - CC0 (Public Domain), CC-BY 4.0, CC-BY-NC 4.0

### 15.4 language — Checkboxes Quadrados Inline (seleção única)

**Arquivo:** `R/mod_mapping.R`

- Mesmo padrão do license: `checkboxGroupInput` + seleção única forçada
- Três opções inline: `pt`, `en`, `es`

### 15.5 Correção de Bug: re-render resetava seleções

**Causa:** `output$mapping_ui` é `renderUI` que re-renderiza a cada mudança de input. Inputs customizados eram recriados com defaults fixos, perdendo a seleção do usuário.

**Solução:** `isolate(input$...)` para preservar valores do usuário entre re-renders.

### 15.6 Dropdown arrow para todos os selectize

**Arquivo:** `inst/app/www/custom.css`

Adicionado indicador `▾` via CSS pseudo-element para todos os `selectize-control.multi` dentro de `.field-card`.

### 15.7 Novas Strings i18n

**Arquivo:** `R/data_dictionary.R`

```
field_or_type_value, field_use_today_date, field_choose_date,
field_choose_license, field_choose_language, field_map_column
```

---

## Resumo de Arquivos Modificados (Rodada 10)

| Arquivo | Modificações |
|---------|--------------|
| `R/mod_mapping.R` | 4 campos customizados, isolate(), single-select enforcers, is_mapped fix |
| `R/data_dictionary.R` | +6 strings i18n |
| `inst/app/www/custom.css` | dropdown arrow, custom-field-label, checkbox/date styles |

---

## 16. Indicador Visual de Mapeamento nos Cards - Rodada 11 (11/02/2026)

**Solicitacao:**
- Remover a barra laranja lateral dos campos nao mapeados
- Destacar campos mapeados com borda verde suave ao redor de todo o card

### 16.1 Classe de estado no modulo de mapeamento

**Arquivo:** `R/mod_mapping.R`

Atribuicao de classe atualizada para explicitar os dois estados:

```diff
- class = paste("field-card no-break", cat_class, if (!is_mapped) "field-unmapped" else ""),
+ class = paste("field-card no-break", cat_class, if (is_mapped) "field-mapped" else "field-unmapped"),
```

### 16.2 CSS dos cards de mapeamento

**Arquivo:** `inst/app/www/custom.css`

Removida a barra lateral laranja de nao mapeado:

```diff
  .field-card.field-unmapped {
    opacity: 0.7;
-   border-left: 3px solid var(--warning);
  }
```

Adicionado highlight verde sutil para cards mapeados (usando `--success`):

```css
.field-card.field-mapped {
  border-color: var(--success);
  box-shadow: 0 0 0 2px rgba(45, 106, 79, 0.12);
}

.field-card.field-mapped:hover {
  border-color: var(--success);
  box-shadow: 0 0 0 2px rgba(45, 106, 79, 0.18);
}
```

### 16.3 Token de cor utilizado

- Cor principal do destaque: `var(--success)`
- Definicao no design system: `--success: #2d6a4f`

---

## 20. Correcoes do Rostrum + Loading Bloqueante + Badges (12/02/2026)

**Solicitacoes do usuario:**
1. Trocar seletor "Novo auto-map (beta)" por toggle real.
2. Renomear para "Rostrum (beta)" e atualizar descricao objetiva.
3. Ao clicar em `Auto-mapear`, bloquear a tela com modal de carregamento, progresso e frases.
4. Corrigir bug onde badges somem apos desmarcar/remarcar categorias.

### 20.1 Toggle do motor novo para switch real

**Erro observado:**
- O controle do motor V1 aparecia como checkbox padrao e nao como toggle on/off.

**Causa:**
- O modulo usava `shiny::checkboxInput(...)` para `enable_automap_v1`.

**Correcao aplicada:**
- Em `R/mod_mapping.R`, substituido por `bslib::input_switch(...)`.
- `inputId` mantido como `enable_automap_v1` para preservar compatibilidade com observers e testes existentes.
- Em `R/data_dictionary.R`:
  - `toggle_automap_v1_label` atualizado para `Rostrum (beta)` (PT/EN).
  - `toggle_automap_v1_help` atualizado para texto objetivo:
    - PT: `Motor proprietario para mapear colunas da planilha aos termos DwC.`
    - EN equivalente.

**Validacao:**
- Fluxo reativo de toggle permanece funcional sem alterar contrato do modulo.

### 20.2 Loading bloqueante no Auto-mapear com progresso

**Erro observado:**
- O processamento de auto-mapeamento nao bloqueava interacao da tela durante execucao.

**Causa:**
- Uso exclusivo de `withProgress(...)`, sem modal dedicado com bloqueio visual total.

**Correcao aplicada:**
- Em `R/mod_mapping.R`:
  - Adicionados helpers para abrir/fechar modal bloqueante com `showModal(modalDialog(..., easyClose = FALSE, footer = NULL))`.
  - Adicionado estado reativo de progresso:
    - `rv$automap_progress`
    - `rv$automap_phrase_idx`
  - Progresso atualizado dentro dos loops dos dois motores (legado e Rostrum/V1), com percentual real.
  - Frases amigaveis rotativas exibidas durante o processamento.
  - Fechamento garantido do modal com `on.exit(...)` em sucesso e erro.
- Em `R/data_dictionary.R`, adicionadas chaves i18n:
  - `loading_automap_title`
  - `loading_automap_status`
  - `loading_automap_phrase_1..4`
- Em `inst/app/www/custom.css`, criados estilos do modal:
  - logo Finch + icone de mapeamento
  - barra de progresso com transicao suave
  - tipografia e espacamento responsivos
  - animacao leve no icone

**Validacao:**
- Modal abre em qualquer clique de `Auto-mapear` (toggle OFF e ON), acompanha progresso e fecha corretamente no fim.

### 20.3 Bug de badges sumindo apos filtro de categorias

**Erro observado:**
- Depois de auto-mapear com V1 e desmarcar/remarcar categorias, badges podiam desaparecer na UI.

**Causa:**
- Leitura isolada de metadados de badge no `renderUI` de mapeamento, reduzindo estabilidade reativa de renderizacao.

**Correcao aplicada:**
- Em `R/mod_mapping.R`, removido `isolate(...)` na leitura de `rv$map_meta[[term]]` no bloco de render dos cards.
- Leitura passou a ser reativa e com fallback seguro para metadado padrao quando necessario.

**Validacao:**
- Novo teste de regressao em `tests/testthat/test-mod-mapping-server.R`:
  - Liga V1, executa auto-map, desmarca/remarca categorias.
  - Verifica que `rv$map_meta$scientificName$status` nao vira `NA` e permanece estavel.

---

## 20. scientificName - Selecao unica e valores vazios no output

### 20.1 Problema reportado

Comportamentos indesejados identificados:

1. `scientificName` aceitava multiplas colunas no `selectInput`, o que podia gerar concatenacao com ` | ` para um campo que deve ser tratado como nome taxonomico unico.
2. Valores ausentes apareciam como `NA` no fluxo de saida, inclusive no CSV exportado.
3. Quando havia derivacao de `genus`, `specificEpithet` e `taxonRank` a partir de `scientificName`, faltantes nao eram padronizados como celula em branco.

### 20.2 Correcao aplicada

**Arquivos:** `R/mod_mapping.R`, `R/utils_mapping.R`, `R/mod_preview.R`

1. **Lock de selecao unica para `scientificName`**
   - Em `R/mod_mapping.R`, o `selectInput` generico agora usa:
     - `multiple = term != "scientificName"`
   - Se houver estado antigo com multiplos valores para `scientificName`, o primeiro valor e mantido.

2. **Hardening no processamento de `scientificName`**
   - No processamento reativo, se `scientificName` vier com mais de uma coluna, o sistema reduz para a primeira coluna antes de mapear.
   - Mantida a derivacao automatica para:
     - `genus`
     - `specificEpithet`
     - `taxonRank`
   - Mantida a regra nao destrutiva: apenas completa campos vazios/`NA`; nao sobrescreve valores ja preenchidos.

3. **Padronizacao global de ausentes como vazio**
   - Nova funcao utilitaria: `replace_na_with_blank(df)` em `R/utils_mapping.R`.
   - Ao final do `processed_data`, apos decidir colunas que permanecem no resultado, todos os `NA` sao convertidos para `""`.
   - Isso aplica de forma geral para qualquer coluna do dataset final mapeado.

4. **Export CSV sem literal `NA`**
   - Em `R/mod_preview.R`, `readr::write_csv` passou a usar `na = ""`.
   - Garante celulas vazias no arquivo final, sem escrever `NA` em texto.

### 20.3 Testes adicionados/atualizados

**Arquivo:** `tests/testthat/test-utils-mapping.R`

Cobertura adicional:

1. Parsing de `scientificName`:
   - `Lycalopex gymnocercus` -> `genus=Lycalopex`, `specificEpithet=gymnocercus`, `taxonRank=species`
   - `Leopardus sp` / `Leopardus sp.` -> `genus=Leopardus`, `specificEpithet=NA`, `taxonRank=genus`
2. `fill_missing_character_values` mantendo valores existentes e preenchendo apenas faltantes.
3. `replace_na_with_blank` convertendo ausentes para string vazia (incluindo coluna numerica convertida para output textual).

### 20.4 Validacao executada

Comandos executados:

```r
Rscript -e "parse(file='R/utils_mapping.R'); cat('OK utils_mapping.R\n')"
Rscript -e "parse(file='R/mod_mapping.R'); cat('OK mod_mapping.R\n')"
Rscript -e "parse(file='R/mod_preview.R'); cat('OK mod_preview.R\n')"
Rscript -e "source('R/utils_mapping.R'); testthat::test_file('tests/testthat/test-utils-mapping.R')"
```

Resultados:
- `OK utils_mapping.R`
- `OK mod_mapping.R`
- `OK mod_preview.R`
- Testes `test-utils-mapping.R`: `FAIL 0 | WARN 0 | SKIP 0 | PASS 58`

---

## Resumo de Arquivos Modificados (Rodada 11)

| Arquivo | Modificacoes |
|---------|--------------|
| `R/mod_mapping.R` | Nova classe `field-mapped` para campos preenchidos |
| `inst/app/www/custom.css` | Remocao da barra laranja e highlight verde no card mapeado |

---

## 17. Correcao de Filtro por Categoria - Rodada 12 (11/02/2026)

**Solicitacoes:**
- Quando nenhuma categoria estiver selecionada, nao mostrar nenhum card
- Remover checkbox fantasma `Organism` do filtro de categorias

### 17.1 Bug de logica: selecao vazia mostrava todos os cards

**Arquivo:** `R/mod_mapping.R`

**Problema:** no bloco `Apply category filter`, quando `input$filter_categories` vinha `NULL`, a logica fazia fallback para todas as categorias.

```diff
- if (is.null(selected_categories)) {
-     selected_categories <- all_filter_categories
- }
+ if (is.null(selected_categories)) {
+     selected_categories <- character(0)
+ }
```

Com isso, o fluxo ja existente passa a funcionar corretamente:
- `length(selected_categories) == 0` -> `fields_to_show <- list()`
- Resultado: nenhum card renderizado quando a selecao estiver vazia

### 17.2 Remocao de `Organism` no filtro (substituicao da configuracao anterior)

**Arquivo:** `R/mod_mapping.R`

`Organism` estava hardcoded no filtro, mas nao existe no `data/dwc_terms.rds` (classes reais: `Record-level`, `Occurrence`, `Event`, `Location`, `Taxon`, `Identification`).

Foram removidos:
1. `choices` de `checkboxGroupInput("filter_categories")`
2. `selected` inicial do mesmo input
3. vetor `all_filter_categories` no server

Isso substitui a configuracao anterior que ainda incluia `Organism`.

### 17.3 Validacao executada

```r
Rscript -e "parse(file='R/mod_mapping.R'); cat('OK mod_mapping.R\n')"
```

Retorno: `OK mod_mapping.R`.

---

## Resumo de Arquivos Modificados (Rodada 12)

| Arquivo | Modificacoes |
|---------|--------------|
| `R/mod_mapping.R` | Correcao de filtro vazio (`NULL` -> `character(0)`) e remocao de `Organism` do filtro |

---

## 18. Ajuste Visual do Filtro de Categorias - Rodada 13 (11/02/2026)

**Solicitacao:**
- Alinhar visualmente `Selecionar todos` com os demais checkboxes de categoria
- Manter a logica de filtro e sincronizacao exatamente como estava

### 18.1 Escopo visual no sidebar de mapeamento

**Arquivo:** `R/mod_mapping.R`

No `bslib::sidebar(...)` do modulo de mapeamento, foi adicionada classe para escopo local de estilos:

```diff
- sidebar = bslib::sidebar(
-     width = 280,
+ sidebar = bslib::sidebar(
+     width = 280,
+     class = "mapping-sidebar",
```

### 18.2 Estrutura semantica do bloco de filtro

**Arquivo:** `R/mod_mapping.R`

O bloco de categorias foi agrupado em wrappers para separar responsabilidades visuais:

- `category-filter-block`
- `category-filter-select-all`
- `category-filter-options`

Os IDs e a ordem funcional foram mantidos:
- `select_all_categories`
- `filter_categories`

### 18.3 CSS escopado para alinhamento e hierarquia

**Arquivo:** `inst/app/www/custom.css`

Adicionadas regras em `.mapping-sidebar` para:

1. Normalizar margens de `checkboxInput` e `checkboxGroupInput`
2. Alinhar checkbox + texto com `display: inline-flex; align-items: center;`
3. Uniformizar tipografia (`font-size`, `line-height`, `font-weight`) entre `Selecionar todos` e categorias
4. Inserir divisor discreto abaixo de `Selecionar todos` com:
   - `border-bottom: 1px solid var(--border-light)`
   - `padding-bottom` e `margin-bottom`

### 18.4 Validacao executada

```r
Rscript -e "parse(file='R/mod_mapping.R'); cat('OK mod_mapping.R\n')"
```

Retorno: `OK mod_mapping.R`.

### 18.5 Impacto funcional

- Nenhuma mudanca na logica de filtro
- Observers de sincronizacao mantidos:
  - `observeEvent(input$select_all_categories, ...)`
  - `observeEvent(input$filter_categories, ...)`

---

## Resumo de Arquivos Modificados (Rodada 13)

| Arquivo | Modificacoes |
|---------|--------------|
| `R/mod_mapping.R` | Classe `mapping-sidebar` e wrappers semanticos do filtro |
| `inst/app/www/custom.css` | CSS escopado para alinhamento de checkboxes e divisor visual |

---

## 19. Implementacao Balanceada de Concatenacao DwC - Rodada 14 (11/02/2026)

**Solicitacao:**
- Padronizar concatenacao no mapeamento para alto volume de planilhas com variacao de escrita
- Definir regra global com `;` como separador de entrada e ` | ` como saida DwC
- Tratar `eventDate` como excecao com parser de 4 colunas (`YYYY-MM/YYYY-MM`)
- Em falha de parse de `eventDate`, manter valor bruto e avisar sem bloquear o fluxo
- Manter consistencia entre Preview e Export (sem duplicar transformacao no export)

### 19.1 Novo utilitario puro de mapeamento

**Arquivo:** `R/utils_mapping.R` (novo)

Foi criado um utilitario dedicado para concentrar e testar a logica de concatenacao e parser de `eventDate`, com funcoes puras:

1. `normalize_semicolon_tokens(x, out_sep = " | ")`
   - split apenas por `;`
   - remove tokens vazios
   - recompõe em ` | `
   - nao quebra por virgula
2. `collapse_mapped_values(df, cols, out_sep = " | ")`
   - aplica normalizacao por coluna
   - concatena por linha mantendo ordem das colunas
3. `detect_eventdate_roles(col_names)`
   - heuristica para `start/end` + `month/year`
   - fallback para ordem selecionada `(1,2,3,4)` quando necessario
4. `parse_month_to_number(x)`
   - aceita mes numerico, PT e EN, abreviado e completo
5. `build_eventdate_interval(df, cols, fallback_raw = TRUE)`
   - gera `YYYY-MM/YYYY-MM` para 4 colunas
   - em linha invalida, mantem valor bruto concatenado e registra falha

Funcoes auxiliares internas adicionadas para robustez:
- `is_blank_value()`
- `split_semicolon_tokens()`
- `split_output_tokens()`
- `normalize_for_matching()`
- `parse_year_to_number()`

### 19.2 Integracao no modulo de mapeamento

**Arquivo:** `R/mod_mapping.R`

Alteracoes aplicadas:

1. Novo source de dependencia:
```diff
+ source(here::here("R", "utils_mapping.R"), local = TRUE)
```

2. `reactiveValues` expandido para controle de falhas de `eventDate`:
```diff
- rv <- shiny::reactiveValues(uuid_generated = FALSE)
+ rv <- shiny::reactiveValues(
+   uuid_generated = FALSE,
+   eventdate_parse_failures = 0L,
+   last_eventdate_warn_count = NA_integer_
+ )
```

3. Novo observer para aviso nao bloqueante quando houver falhas:
- `showNotification(..., type = "warning")`
- dispara apenas quando contagem muda
- nao interrompe mapeamento/preview/export

4. Reescrita da regra de processamento generico:
- `length(user_cols) == 1`: usa `normalize_semicolon_tokens(...)`
- `length(user_cols) > 1` e `term != "eventDate"`: usa `collapse_mapped_values(...)`
- `term == "eventDate"` e `length(user_cols) == 4`: usa `build_eventdate_interval(...)`
- `term == "eventDate"` com outra quantidade de colunas: cai na regra geral de concatenacao

5. Acumulo de falhas por lote:
- contador local `eventdate_failure_count`
- sincronizado com `rv$eventdate_parse_failures` ao final da reatividade

### 19.3 i18n e orientacao ao usuario

**Arquivo:** `R/data_dictionary.R`

Novas/ajustadas chaves:

1. Nova chave de aviso:
- `notif_eventdate_parse_warning`
  - PT: informa quantidade de linhas nao convertidas e que valor bruto foi mantido
  - EN: equivalente

2. Reforco de recomendacao na pagina inicial:
- `upload_recommendation` atualizado para explicitar:
  - entrada recomendada com `;`
  - saida padronizada DwC com ` | `

### 19.4 Preview e Export

**Arquivos:** `R/mod_preview.R`, `R/utils_export.R`

- Sem mudanca de contrato/assinatura.
- A transformacao de concatenacao foi centralizada no `mod_mapping`.
- Preview e CSV final passam a refletir o mesmo dado ja processado.

### 19.5 Testes automatizados reais

**Arquivos novos:**
- `tests/testthat.R`
- `tests/testthat/test-utils-mapping.R`

Cobertura implementada:

1. `;` vira ` | ` em coluna unica
2. virgula nao e tratada como delimitador
3. concatenacao de duas colunas com conteudo misto
4. `eventDate` padrao de 4 colunas -> `YYYY-MM/YYYY-MM`
5. meses PT/EN abreviado e completo
6. fallback por ordem quando nomes nao ajudam
7. linha invalida em `eventDate` mantendo bruto
8. `NA`/vazios resultando em `NA` final
9. preservacao da ordem dos tokens

### 19.6 Validacao executada

Comandos executados:

```r
Rscript -e "parse(file='R/utils_mapping.R'); cat('OK utils_mapping.R\n')"
Rscript -e "parse(file='R/mod_mapping.R'); cat('OK mod_mapping.R\n')"
Rscript -e "parse(file='R/data_dictionary.R'); cat('OK data_dictionary.R\n')"
Rscript -e "source('R/utils_mapping.R'); testthat::test_file('tests/testthat/test-utils-mapping.R')"
```

Resultados:
- `OK utils_mapping.R`
- `OK mod_mapping.R`
- `OK data_dictionary.R`
- Testes `test-utils-mapping.R`: `FAIL 0 | WARN 0 | SKIP 0 | PASS 34`

---

## Resumo de Arquivos Modificados (Rodada 14)

| Arquivo | Modificacoes |
|---------|--------------|
| `R/utils_mapping.R` | Novo utilitario puro para normalizacao de `;`, concatenacao em ` | ` e parser especial de `eventDate` |
| `R/mod_mapping.R` | Integracao do utilitario, regra especial de `eventDate`, aviso nao bloqueante e contagem de falhas |
| `R/data_dictionary.R` | Nova chave i18n (`notif_eventdate_parse_warning`) e reforco da orientacao de separador |
| `tests/testthat.R` | Runner de testes do pacote |
| `tests/testthat/test-utils-mapping.R` | Suite de testes de concatenacao e `eventDate` |

---

## 21. Correcoes UI/UX do Mapeamento + Export de Licenca (12/02/2026)

**Solicitacoes atendidas:**
1. Ajuste de alinhamento e espacamento do bloco `Rostrum (beta)` no sidebar.
2. Correcoes de estado visual de mapeamento (cards, badges e scroll).
3. Correcoes no loading bloqueante do `Auto-mapear`.
4. Abreviacao de `license` no Preview e no CSV exportado.

### 21.1 Scroll da area de mapeamento

**Arquivo:** `R/mod_mapping.R`, `inst/app/www/custom.css`

- Removido `style` inline da area rolavel do mapeamento.
- Adicionado hook CSS dedicado:
  - classe `mapping-scroll-container`
  - `max-height: calc(100vh - 200px)`
  - `overflow-y: auto`
  - `padding-right: 15px`
  - `scrollbar-gutter: stable`

Objetivo: evitar sobreposicao da barra de rolagem sobre os cards.

### 21.2 Badges e estado visual dos cards

**Arquivo:** `R/mod_mapping.R`, `inst/app/www/custom.css`

- `occurrenceID` deixou de renderizar badge de status (mesmo com V1 ligado).
- `renderUI` passou a ler `rv$map_values[[term]]` sem `isolate`, melhorando reatividade visual.
- Cards mapeados:
  - classe `field-mapped` com **apenas** borda verde.
  - fundo mantido em `var(--bg-card)`, sem sombrear o card inteiro.
- Cards nao mapeados:
  - classe `field-unmapped` com fundo `var(--bg-card)` e borda padrao `var(--border)`.

### 21.3 Sincronizacao de status manual para campos customizados

**Arquivo:** `R/mod_mapping.R`

Foi adicionada a funcao auxiliar `set_custom_term_meta(term, has_value)` para manter `rv$map_meta` consistente em campos especiais:

- `datasetName`
- `modified`
- `license`
- `language`

Regra aplicada:
- com valor -> `status = "EDITADO"`, `reason = "manual_adjust"`, `source = "manual"`
- sem valor -> `status = "MANUAL"`, `reason = "manual_cleared"`, `source = "manual"`

Protecao mantida para updates programaticos:
- respeita `rv$is_programmatic_update`.

### 21.4 Loading bloqueante do Auto-mapear

**Arquivo:** `R/mod_mapping.R`, `inst/app/www/custom.css`, `R/data_dictionary.R`

Melhorias aplicadas:

- Logo do modal reduzida para 48px (44px em mobile).
- Frase com melhor legibilidade (`line-height` maior e `min-height`).
- Icone do modal passou a ser dinamico conforme etapa/frase.
- Frases de loading passaram a rodar com ordem randomizada por execucao.

Novas frases i18n adicionadas:
- `loading_automap_phrase_1` ate `loading_automap_phrase_8`

### 21.5 Export e Preview de licenca abreviada

**Arquivo:** `R/utils_export.R`, `R/mod_preview.R`

Novas funcoes puras:
- `abbreviate_license(x)`
- `abbreviate_license_column(df, col = "license")`

Integracao:
- `process_for_export(df)` agora aplica abreviacao de licenca no pipeline final.
- `preview_data` em `mod_preview` tambem aplica abreviacao antes de renderizar.

Mapeamento suportado:
- `creativecommons.org/publicdomain/zero/1.0` -> `CC0`
- `creativecommons.org/licenses/by/4.0` -> `CC-BY`
- `creativecommons.org/licenses/by-nc/4.0` -> `CC-BY-NC`

Comportamento:
- aceita variacoes com/sem `http(s)`, com/sem `legalcode`, com/sem `/` final
- valores fora do mapeamento permanecem inalterados

### 21.6 Validacao executada

Comandos executados:

```r
Rscript -e "parse(file='R/mod_mapping.R'); cat('OK mod_mapping.R\n')"
Rscript -e "parse(file='R/utils_export.R'); cat('OK utils_export.R\n')"
Rscript -e "parse(file='R/mod_preview.R'); cat('OK mod_preview.R\n')"
Rscript -e "parse(file='R/data_dictionary.R'); cat('OK data_dictionary.R\n')"
Rscript -e "source('R/utils_export.R'); x<-c('https://creativecommons.org/publicdomain/zero/1.0/legalcode','http://creativecommons.org/licenses/by/4.0/','https://creativecommons.org/licenses/by-nc/4.0','custom'); print(abbreviate_license(x))"
```

Resultados:
- `OK mod_mapping.R`
- `OK utils_export.R`
- `OK mod_preview.R`
- `OK data_dictionary.R`
- teste rapido de `abbreviate_license()` retornou: `CC0`, `CC-BY`, `CC-BY-NC`, `custom`

---

## 22. Ajustes Finos (12/02/2026)

**Solicitacoes pontuais atendidas:**
1. Alinhamento do bloco `Rostrum (beta)` com texto auxiliar ancorado na borda esquerda do toggle.
2. Texto de ajuda colado ao toggle como nota de rodape.
3. Remocao do amarelo no selectize mapeado, com pilula neutra destacada.
4. Troca do icone fixo do loading por icones de engine em funcionamento.
5. Randomizacao de frases do loading com match de icones.
6. Cor dos contadores no sidebar: apenas numeros em azul.

### 22.1 Sidebar do Rostrum

**Arquivo:** `inst/app/www/custom.css`

Correcao final aplicada para eliminar o "buraco" entre toggle e texto auxiliar:

- `.mapping-sidebar .rostrum-switch-block > .shiny-input-container`
  - `margin-bottom: 0` (sem `!important`)
- `.mapping-sidebar .rostrum-switch-block`
  - `margin-bottom: 0`
- `.mapping-beta-help`
  - `margin-top: 0` para deixar o texto colado ao toggle
  - estilo de nota mantido (`font-size` menor, `color` secundaria, `font-style: italic`)
- blindagem para `uiOutput`:
  - `.mapping-beta-help p { margin: 0; }`
  - `.mapping-beta-help .shiny-html-output { margin: 0; }`

Resultado:
- texto auxiliar fica imediatamente abaixo de `[Toggle] Rostrum (beta)`;
- inicio horizontal do texto permanece alinhado com a borda esquerda do toggle;
- sem uso de `!important` nessa correcao.

### 22.2 Selectize mapeado sem amarelo

**Arquivo:** `inst/app/www/custom.css`

Ajustado estilo visual dos campos mapeados para remover destaque amarelo:

- `.field-card.field-mapped .selectize-input.has-items`
- `.field-card.field-mapped .selectize-input .item`

Com isso:
- o dropdown mapeado nao recebe mais sombra/fundo amarelo;
- a pilula do item selecionado passa a ser branca, com borda neutra e halo branco discreto para destaque sobre fundo bege.

### 22.3 Loading do Rostrum - correcao final (13/02/2026)

**Arquivos:** `R/mod_mapping.R`, `inst/app/www/custom.css`

**Problemas observados apos a rodada anterior:**
1. Fundo do app com efeito "debaixo d'agua" durante o loading.
2. Barra de progresso nao aparecia no modal.

**Causas identificadas:**
1. O overlay do modal aplicava `backdrop-filter: blur(8px)`, gerando efeito visual indesejado.
2. Barra/status estavam em `uiOutput`/`textOutput` dentro de fluxo bloqueante do auto-map; em execucoes pesadas, o browser nao recebia render parcial a tempo.

**Correcao aplicada:**
1. Backdrop sem blur, com escurecimento neutro:
   - `.automap-loading-open .modal-backdrop.show { background-color: rgba(0, 0, 0, 0.45); }`
2. Barra e status convertidos para HTML estatico no modal (render imediato):
   - `div` da barra com id `automap_loading_progress_bar`
   - `span` do status com id `automap_loading_status_text`
3. Atualizacao client-side no mesmo script de rotacao:
   - funcao JS `applyProgress(...)` atualiza largura da barra e `%`
   - incremento visual continuo ate 92%% durante o processamento
   - prefixo de status derivado da string i18n `loading_automap_status`
4. Comportamentos mantidos:
   - frases continuam randomizadas por execucao
   - icone segue contextual por frase, com pulsacao leve
   - limpeza de classes/timers no fechamento do modal
5. Fix de compatibilidade:
   - troca de `shiny::toJSON(...)` para `jsonlite::toJSON(...)`.

**Observacao tecnica:**
- Em Shiny sincrono, progresso real por iteracao nao e garantido no browser durante loop bloqueante unico.
- O ajuste final prioriza feedback visual continuo, estavel e imediatamente visivel.

### 22.4 Cor dos contadores do sidebar

**Arquivo:** `inst/app/www/custom.css`

- `.stats-number` alterado para `var(--accent)` (azul recomendado).
- `.stats-label` mantido em `var(--text-muted)`.

Com isso, apenas os numeros dos cards de estatistica mudam de amarelo para azul.

### 22.5 Validacao executada

Comandos:

```r
Rscript -e "parse(file='R/mod_mapping.R'); cat('OK mod_mapping.R\\n')"
Rscript -e "devtools::test(filter='mod-mapping-server')"
```

Resultados:
- `OK mod_mapping.R`
- `FAIL 0 | WARN 0 | SKIP 0 | PASS 16`

---

## Resumo de Arquivos Modificados (Rodadas 21 e 22)

| Arquivo | Modificacoes |
|---------|--------------|
| `R/mod_mapping.R` | Hook de scroll, ocultacao de badge em `occurrenceID`, sincronizacao de metadados manuais, loading com frases/icones no cliente + barra/status estaticos no modal |
| `inst/app/www/custom.css` | Scroll container, card mapeado sem sombreado de fundo, selectize sem amarelo, ajuste final do bloco Rostrum, numeros dos contadores em azul, overlay do loading sem blur |
| `R/utils_export.R` | Novas funcoes `abbreviate_license()` e `abbreviate_license_column()`, integradas ao `process_for_export()` |
| `R/mod_preview.R` | Preview passa a aplicar abreviacao de `license` |
| `R/data_dictionary.R` | Novas frases `loading_automap_phrase_1..8` |

---
