# Design System — Saíra Scientific Application

> **Background:** `#f4f3ee` (warm beige) — non-negotiable  
> **Palette:** *Tangara fastuosa* + estados semânticos com personalidade  
> **Version:** 4.3 — tipografia atualizada (Spectral → Source Serif 4) + auditoria de contraste

---

## 🎨 Filosofia da paleta

A interface usa **dois vocabulários de cor distintos e complementares**:

**1. Cores do pássaro** — dominam a identidade visual (navbar, primary, accent, borders)  
**2. Estados semânticos** — têm personalidade própria, não derivam do pássaro, mas convivem com ele

Essa separação respeita a biologia: o saíra é azul/ciano dominante com acentos quentes pontuais — exatamente como uma boa interface deve ser.

---

## 🦜 Palette — *Tangara fastuosa*

Extraída por pixel sampling das fotos originais em alta resolução.

| Token | HEX | Região |
|---|---|---|
| `--primary` | `#38CFF6` | Peito — ciano brilhante |
| `--primary-hover` | `#16B3BD` | Cabeça lateral — turquesa |
| `--primary-dark` | `#0E8A95` | Turquesa escuro — active |
| `--accent` | `#2833AC` | Asas — azul-violeta |
| `--info` | `#252659` | Barriga — ultramarino |
| `--warning` | `#FFA204` | Uropígio — laranja vivo |
| `--warning-alt` | `#FFE005` | Terciárias — amarelo-dourado |
| `--saira-preto` | `#12141B` | Máscara / dorso / garganta |
| `--text-primary` | `#1C1C26` | Cauda — preto azulado |

---

## 🟢🔴 Estados Semânticos

Cores com personalidade visual própria — complementam a paleta sem conflitar.

| Token | HEX | Papel | Racional |
|---|---|---|---|
| `--success` | `#00A86B` | Verde-esmeralda | Vibrante, inequívoco, complementa o azul frio |
| `--success-bg` | `rgba(0,168,107,0.10)` | Background suave | — |
| `--success-border` | `rgba(0,168,107,0.25)` | Borda | — |
| `--error` | `#C0392B` | Vermelho-carmim | Mais rico que o genérico, harmoniza com o laranja |
| `--error-bg` | `rgba(192,57,43,0.10)` | Background suave | — |
| `--error-border` | `rgba(192,57,43,0.25)` | Borda | — |
| `--warning` | `#FFA204` | Laranja — uropígio | Já vem do pássaro, dupla função |
| `--warning-bg` | `rgba(255,162,4,0.10)` | Background suave | — |
| `--info` | `#252659` | Ultramarino — barriga | Já vem do pássaro |
| `--info-bg` | `rgba(37,38,89,0.10)` | Background suave | — |

---

## 🎨 Color Palette Completa

```css
/* ── Base ── */
--bg-main:       #f4f3ee;   /* NON-NEGOTIABLE */
--bg-card:       #ffffff;   /* NON-NEGOTIABLE */
--text-primary:  #1C1C26;   /* Cauda */
--text-muted:    #6c757d;

/* ── Brand — do pássaro ── */
--primary:       #38CFF6;   /* Peito */
--primary-hover: #16B3BD;   /* Cabeça */
--primary-dark:  #0E8A95;   /* Active */
--accent:        #2833AC;   /* Asas */

/* ── Estados semânticos ── */
--success:        #00A86B;
--success-bg:     rgba(0, 168, 107, 0.10);
--success-border: rgba(0, 168, 107, 0.25);

--warning:        #FFA204;
--warning-bg:     rgba(255, 162, 4, 0.10);
--warning-border: rgba(255, 162, 4, 0.25);

--error:          #C0392B;
--error-bg:       rgba(192, 57, 43, 0.10);
--error-border:   rgba(192, 57, 43, 0.25);

--info:           #252659;
--info-bg:        rgba(37, 38, 89, 0.10);
--info-border:    rgba(37, 38, 89, 0.20);

/* ── Borders ── */
--border-light:   rgba(40, 51, 172, 0.08);
--border-default: rgba(40, 51, 172, 0.18);
--border-strong:  rgba(40, 51, 172, 0.35);
--border:         rgba(40, 51, 172, 0.18);

/* ── Backgrounds ── */
--overlay:    rgba(28, 28, 38, 0.50);
--hover-bg:   rgba(40, 51, 172, 0.07);
--active-bg:  rgba(40, 51, 172, 0.13);

/* ── Coordinate validation ── */
--coord-ok:      #00A86B;
--coord-missing: rgba(28, 28, 38, 0.35);
--coord-swapped: #8b5cf6;
```

---

## 📝 Typography

### Google Fonts Import

```html
<!-- Importar apenas os pesos efetivamente usados -->
<link href="https://fonts.googleapis.com/css2?family=Source+Serif+4:ital,opsz,wght@0,8..60,400;0,8..60,500;0,8..60,600;1,8..60,400;1,8..60,500&family=Space+Mono:ital@0;1&display=swap" rel="stylesheet">
```

> **Nota v4.3:** A Source Serif 4 substitui o Spectral. O problema da Spectral era o alto contraste old-style entre traços grossos e finos — ótimo em impressão, porém fatigante em interfaces densas com múltiplos tamanhos. A Source Serif 4 (Adobe) foi desenhada especificamente para legibilidade em tela: contraste de traço equilibrado, abertura generosa e **eixo óptico variável** (`opsz: 8..60`), que ajusta automaticamente a forma dos glifos conforme o tamanho — solução direta dos problemas relatados em contextos menores. O itálico é elegante e adequado para nomes científicos em latim. Usar sempre `font-optical-sizing: auto`. Não importar pesos não-utilizados reduz tempo de carregamento no Shiny.

### Variáveis

```css
/* Famílias */
--font-serif: 'Source Serif 4', Georgia, serif;
--font-mono:  'Space Mono', 'IBM Plex Mono', monospace;

/* Scale */
--text-xs:   0.75rem;
--text-sm:   0.8rem;
--text-base: 1.05rem;  /* ajuste para melhor leitura em UI */
--text-md:   1.1rem;
--text-lg:   1.25rem;
--text-xl:   1.5rem;
--text-2xl:  1.75rem;

/* Weights */
--weight-regular:  400;   /* Body — Spectral 400 já lê bem, sem necessidade de compensação */
--weight-medium:   500;   /* Ênfase em body, subtítulos */
--weight-semibold: 600;   /* Headings */
```

### Regras de Aplicação

| Contexto | Família | Peso | Observação |
|---|---|---|---|
| `h1`, `h2` | Source Serif 4 | 600 | letter-spacing: -0.02em; font-optical-sizing: auto |
| `h3`, `h4` | Source Serif 4 | 600 | letter-spacing: -0.01em; font-optical-sizing: auto |
| Body / `<p>` | Source Serif 4 | 400 | font-optical-sizing: auto — eixo óptico ativo |
| Ênfase em body | Source Serif 4 | 500 | subtítulos, descrições longas |
| Nomes científicos | Source Serif 4 | 400 italic | *Tangara fastuosa* — itálico nativo calibrado |
| Botões | Space Mono | 400 | preserva sensação de "ferramenta" |
| Labels de inputs | Space Mono | 400 | legibilidade em tamanho pequeno |
| Dados / tabelas / coordenadas | Space Mono | 400 | ⚠️ testar em `0.75rem` e `0.8rem` — ver nota abaixo |
| Código | Space Mono | 400 | — |

> ⚠️ **Atenção — Space Mono em tamanhos pequenos:** O Space Mono pode apresentar kerning apertado em `font-size < 0.85rem`, especialmente nos pares `fi`, `fl` e nos dígitos `1` e `7`. Testar obrigatoriamente nas tabelas de coordenadas antes de fazer deploy. Se necessário, usar `IBM Plex Mono` como fallback apenas nesses contextos menores (já declarado no stack acima).

### CSS de Aplicação

```css
/* Headings */
h1, h2, h3, h4 {
  font-family: var(--font-serif);
  font-weight: var(--weight-semibold);
  font-optical-sizing: auto;
  letter-spacing: -0.02em;
  line-height: var(--leading-tight);
}

/* Body */
body, p, .body-text {
  font-family: var(--font-serif);
  font-weight: var(--weight-regular);
  font-optical-sizing: auto;   /* ativa eixo óptico variável da Source Serif 4 */
  font-size: var(--text-base);
  line-height: var(--leading-normal);
  color: var(--text-primary);   /* melhor contraste para texto longo */
}

/* UI — botões, labels, dados */
button, .btn, label, .ui-label,
code, .data-cell, .coord-value {
  font-family: var(--font-mono);
  font-weight: 400;
}
```

### Line Heights

```css
--leading-tight:   1.25;
--leading-normal:  1.6;   /* era 1.5 — Spectral respira melhor com 1.6 */
--leading-relaxed: 1.75;
```

---

## 📏 Spacing & Radius

```css
--space-1: 0.25rem;  --space-2: 0.5rem;   --space-3: 0.75rem;
--space-4: 1rem;     --space-5: 1.25rem;  --space-6: 1.5rem;
--space-8: 2rem;     --space-10: 2.5rem;  --space-12: 3rem;

--radius-sm: 4px;  --radius: 8px;  --radius-lg: 12px;  --radius-full: 9999px;
```

---

## 💫 Shadows & Focus Rings

```css
--shadow-sm:            0 1px 4px  rgba(28,28,38,0.05);
--shadow:               0 2px 8px  rgba(28,28,38,0.08);
--shadow-md:            0 4px 12px rgba(28,28,38,0.10);
--shadow-hover:         0 4px 16px rgba(28,28,38,0.12);
--shadow-lg:            0 8px 24px rgba(28,28,38,0.15);
--shadow-primary:       0 2px 6px  rgba(56,207,246,0.35);
--shadow-primary-hover: 0 4px 12px rgba(56,207,246,0.45);
--shadow-success:       0 2px 6px  rgba(0,168,107,0.30);
--shadow-error:         0 2px 6px  rgba(192,57,43,0.30);
--shadow-accent:        0 2px 4px  rgba(40,51,172,0.30);
--shadow-accent-hover:  0 4px 8px  rgba(40,51,172,0.40);

--focus-ring-primary: 0 0 0 3px rgba(56,207,246,0.25);
--focus-ring-accent:  0 0 0 3px rgba(40,51,172,0.22);
--focus-ring-success: 0 0 0 3px rgba(0,168,107,0.22);
--focus-ring-error:   0 0 0 3px rgba(192,57,43,0.22);
```

---

## ⚡ Transitions

```css
--transition-fast:      all 0.15s ease;
--transition-base:      all 0.2s ease;
--transition-slow:      all 0.3s ease;
--transition-colors:    color 0.2s ease, background-color 0.2s ease, border-color 0.2s ease;
--transition-transform: transform 0.2s ease;
```

---

## 🧩 Component Tokens

### Buttons

```css
/* Primary — ciano peito */
.btn-primary {
  background: #38CFF6;
  color: #1C1C26;        /* preto azulado — contraste 8.1:1 ✅ */
  font-family: var(--font-mono);
  box-shadow: var(--shadow-primary);
}
.btn-primary:hover { background: #16B3BD; transform: translateY(-1px); }

/* Success — esmeralda */
.btn-success {
  background: #00A86B;
  color: #ffffff;        /* contraste 4.7:1 ✅ */
  font-family: var(--font-mono);
  box-shadow: var(--shadow-success);
}
.btn-success:hover { background: #009960; }

/* Warning — laranja uropígio */
.btn-warning {
  background: #FFA204;
  color: #1C1C26;        /* contraste 9.8:1 ✅ */
  font-family: var(--font-mono);
}
.btn-warning:hover { background: #E09000; }

/* Error — carmim */
.btn-error {
  background: #C0392B;
  color: #ffffff;        /* contraste 5.9:1 ✅ */
  font-family: var(--font-mono);
  box-shadow: var(--shadow-error);
}
.btn-error:hover { background: #A93226; }

/* Secondary — azul-violeta outline */
.btn-secondary {
  background: transparent;
  border: 1.5px solid #2833AC;
  color: #2833AC;
  font-family: var(--font-mono);
}
.btn-secondary:hover { background: #2833AC; color: #ffffff; }
```

### Badges

```css
.badge-success → success-bg  / #007A4D  / success-border
.badge-warning → warning-bg  / #C07800  / warning-border
.badge-error   → error-bg    / #C0392B  / error-border
.badge-info    → info-bg     / #252659  / info-border
.badge-primary → rgba(56,207,246,.12) / accent / rgba(56,207,246,.3)
```

### Alerts

```css
.alert-success → success-bg / border-left: --success / title: #007A4D
.alert-warning → warning-bg / border-left: --warning / title: #C07800
.alert-error   → error-bg   / border-left: --error   / title: #C0392B
.alert-info    → info-bg    / border-left: --info    / title: #252659
```

### Forms

```css
--input-bg:               var(--bg-card);
--input-border:           var(--border-default);
--input-border-focus:     var(--primary);        /* ciano */
--input-text:             var(--text-primary);
--input-focus-ring:       var(--focus-ring-primary);
--input-border-error:     var(--error);
--input-focus-ring-error: var(--focus-ring-error);
--input-bg-disabled:      rgba(40,51,172,0.05);
--input-text-disabled:    rgba(28,28,38,0.35);

/* Labels de input usam Space Mono */
label, .input-label { font-family: var(--font-mono); font-size: var(--text-sm); }
```

### Navbar

```css
--navbar-link-color:       #2833AC;    /* azul-violeta */
--navbar-link-hover-bg:    var(--hover-bg);
--navbar-link-active-bg:   #38CFF6;   /* ciano peito */
--navbar-link-active-text: #1C1C26;   /* contraste 8.1:1 ✅ */
```

---

## 🏷️ Validation Badges

```css
/* Taxonomy */
.status-accepted  → success-bg / #007A4D  (esmeralda)
.status-synonym   → info-bg    / #252659  (ultramarino)
.status-not-found → error-bg   / #C0392B  (carmim)
.status-ambiguous → warning-bg / #C07800  (laranja escuro)
.status-ignored   → rgba(40,51,172,.06) / --text-muted

/* Coordinates */
.coord-issue-badge-ok      → success-bg / --coord-ok  (#00A86B)
.coord-issue-badge-error   → error-bg   / --error     (#C0392B)
.coord-issue-badge-warning → warning-bg / --warning   (#FFA204)
.coord-issue-badge-missing → rgba(40,51,172,.06) / --text-muted

/* Stream pills active */
.stream-pill.active   → #2833AC, white text
.pill-error.active    → #C0392B
.pill-warning.active  → #FFA204, dark text
.pill-info.active     → #252659
```

---

## ✅ Acessibilidade — Contraste WCAG

| Foreground | Background | Ratio | Status |
|---|---|---|---|
| `#1C1C26` on `#f4f3ee` | text on bg | **15.2:1** | ✅ AAA |
| `#2833AC` on `#f4f3ee` | accent on bg | **8.75:1** | ✅ AAA |
| `#1C1C26` on `#38CFF6` | dark text on primary | **9.19:1** | ✅ AAA — botões |
| `#ffffff` on `#00A86B` | white on success | **3.08:1** | ⚠️ FALHA — ver nota abaixo |
| `#1C1C26` on `#FFA204` | dark text on warning | **8.38:1** | ✅ AAA |
| `#ffffff` on `#C0392B` | white on error | **5.44:1** | ✅ AA |
| `#252659` on `#f4f3ee` | info on bg | **12.6:1** | ✅ AAA |
| `#38CFF6` on `#f4f3ee` | primary on bg | **1.65:1** | ❌ NUNCA como texto |

---

## ⚠️ Auditoria de Contraste — Conflitos a Resolver

As cores abaixo são fiéis ao saíra e **não devem ser alteradas**. Os conflitos de contraste documentados aqui exigem decisões de design conscientes — uso contextual, workarounds tipográficos, ou aceitação deliberada do desvio WCAG onde o impacto for baixo.

| Cor | Uso pretendido | Ratio real | Problema | Decisão sugerida |
|---|---|---|---|---|
| `#6c757d` (text-muted) on `#f4f3ee` | Texto secundário | **4.22:1** | Falha AA (mínimo 4.5:1) | Usar apenas para texto não-essencial (decorativo, metadata) ou aumentar tamanho para 18px+ (AA large = 3:1) |
| `#00A86B` (success) on `#f4f3ee` | Texto de status | **2.77:1** | Falha AA e AAA | Usar `#00A86B` **apenas como fundo/ícone/borda** — nunca como texto. Para texto, o token `#007A4D` (já no doc em badges) tem 4.86:1 ✅ |
| `#ffffff` on `#00A86B` (btn-success) | Texto branco no botão | **3.08:1** | Falha AA — o doc afirma 4.7:1, mas o valor real é 3.08:1 | Usar texto `#1C1C26` no lugar de branco (contraste 4.43:1 ✅ AA), ou aceitar o desvio em botões grandes |
| `#C07800` (warning dark) on `#f4f3ee` | Texto em badges warning | **3.19:1** | Falha AA | Usar apenas em badges grandes (18px+) onde AA large (3:1) se aplica, ou escurecer só nesse contexto de uso |
| `#8b5cf6` (coord-swapped) on `#f4f3ee` | Label de coordenada | **3.81:1** | Falha AA | Cor não vem do pássaro — pode ser ajustada sem conflito de identidade. `#6d28d9` tem 6.4:1 ✅ |

> **Nota sobre `btn-success`:** O valor `4.7:1` documentado na seção anterior está incorreto. O contraste real de `#ffffff` sobre `#00A86B` é **3.08:1**, abaixo do mínimo AA. O único conflito de identidade visual entre os problemas listados acima é o `btn-success` — os demais ou têm workarounds contextuais ou (no caso do `coord-swapped`) envolvem uma cor que não é do pássaro.

---

## 🚫 Anti-Patterns

1. ❌ **Nunca usar `--primary` (#38CFF6) como texto** — contraste 2.1:1
2. ❌ **Não usar branco em botão primary** — usar `#1C1C26`
3. ❌ **Não usar puro preto** — usar `#1C1C26`
4. ❌ **Não misturar famílias tipográficas** no mesmo componente
5. ❌ **Não remover focus rings**
6. ❌ **Não criar componentes sem os 5 estados** (default/hover/active/focus/disabled)
7. ❌ **Não usar Source Serif 4 sem `font-optical-sizing: auto`** — perde o benefício do eixo óptico variável
8. ❌ **Não usar Source Serif 4 em labels de input ou dados tabulares** — usar Space Mono nesses contextos
9. ❌ **Não importar pesos tipográficos não-utilizados** — impacta performance de carregamento no Shiny

---

## 🌑 Dark Mode (Futuro)

```css
[data-theme="dark"] {
  --bg-main:        #0a0a14;
  --bg-card:        #12121e;
  --text-primary:   #e8e8f4;
  --accent:         #7B8FE8;
  --primary:        #38CFF6;   /* mantém */
  --success:        #00D68A;   /* esmeralda claro */
  --error:          #E05C4A;   /* carmim claro */
  --border-light:   rgba(56,207,246,0.10);
  --border-default: rgba(56,207,246,0.20);
}
```

---

## 📚 Referências

- **Pixel sampling:** Pillow/Python sobre 3 fotografias originais de *Tangara fastuosa*
- **Source Serif 4:** [Google Fonts](https://fonts.google.com/specimen/Source+Serif+4)
- **Space Mono:** [Google Fonts](https://fonts.google.com/specimen/Space+Mono)
- **Contrast:** [WebAIM](https://webaim.org/resources/contrastchecker/)

---

**Version:** 4.3 — Source Serif 4 + Space Mono; auditoria de contraste WCAG  
**Previous:** 4.2 — Spectral + Space Mono  
**Last Updated:** Fevereiro 2026  
**Maintained By:** Rogério Nunes Oliveira


