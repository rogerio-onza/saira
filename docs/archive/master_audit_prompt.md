# 🦅 Saira Project - Master Audit Prompt

Este documento contém um prompt estruturado para realizar uma varredura completa ("deep-dive audit") no projeto Saira. Ele foi desenhado para ser utilizado em uma ferramenta de IA (como Gemini ou Claude) para identificar gargalos, redundâncias e violações arquiteturais.

---

## 🎯 Objetivo da Auditoria
Avaliar a saúde técnica do projeto Saira, garantindo conformidade estrita com as diretrizes de desenvolvimento (`claude.md`), arquitetura (`architecture.md`) e padrões de codificação (`skill.md`), focando em:
1.  **Conformidade Arquitetural** (Modularização e Golem-style).
2.  **Redundância de Código** (Lógica duplicada ou "Distributed Monolith").
3.  **Otimização de Performance** (Vetorização e I/O).
4.  **Qualidade e Segurança** (i18n, tratamento de erros e dependências).

---

## 📋 Como usar este Prompt
Copie e cole o bloco abaixo em uma nova sessão de chat com sua IA preferida, garantindo que ela tenha acesso aos arquivos mencionados (`R/`, `tests/`, `DESCRIPTION`, etc.).

---

### 🚀 [COPIAR ABAIXO] 🚀

"Atue como um Arquiteto de Software R especialista em Shiny (Golem/Package-based) e Biodiversity Informatics. Seu objetivo é realizar um **Code Review de Segurança e Arquitetura** abrangente no projeto **Saira**.

### 📖 Contexto de Referência
Você deve basear todas as suas análises nos seguintes arquivos mestres que definem as 'leis' deste projeto:
- `claude.md`: Regras de modularização e ciclo de desenvolvimento.
- `architecture.md`: Estrutura de arquivos e decisões críticas.
- `skill.md`: Padrões de estilo, performance e segurança.

### 🔍 Tarefas da Auditoria

#### 1. Verificação de Estrutura e Modularização (Conformidade `claude.md`)
- Verifique se há lógica de negócios dentro de arquivos `mod_*.R`. Se houver, sugira a extração para uma função pura em `utils_*.R`.
- Analise o `app_server.R`. Ele deve conter **apenas** chamadas de módulos. Identifique qualquer reatividade ou lógica 'solta' que viole o princípio do orquestrador puro.
- Identifique o uso de variáveis globais (`<<-`) ou `reactiveValues` circulando entre módulos (o que viola o padrão de 'Chain of Reactivity').

#### 2. Detecção de Redundância e Lógica Duplicada
- Escaneie os arquivos `R/utils_*.R`. Há funções que fazem tarefas similares? Identifique sobreposições, especialmente em manipulação de datas, strings e validação de DwC.
- Verifique se o sistema `i18n` está sendo usado uniformemente. Identifique hardcoded strings (ex: `h3('Texto')`) que deveriam ser `tr('chave', lang)`.

#### 3. Auditoria de Padrões e Segurança (Conformidade `skill.md`)
- Verifique se os headers obrigatórios estão presentes em todos os arquivos `.R`.
- Identifique chamadas de `library()` em qualquer arquivo dentro de `R/`. Elas devem ser substituídas pelo operador `::` e as dependências devem estar no `DESCRIPTION`.
- Procure por `setwd()` ou caminhos absolutos. Sugira a substituição por `here::here()`.
- Verifique o tratamento de erros em operações críticas (I/O). Estão usando `tryCatch` com feedback bilíngue (`shinyFeedback`/`showNotification`)?

#### 4. Otimização de Performance
- Identifique loops (`for`, `apply`, `sapply`) que podem ser vetorizados.
- Analise o `mod_preview.R`. Ele está limitando o processamento para as primeiras 100 linhas de forma eficiente?
- Verifique se dados estáticos pesados estão sendo carregados erroneamente dentro do `server` em vez do `sysdata.rda` ou `global.R` (embora `architecture.md` prefira `sysdata.rda`).

#### 5. Cobertura de Testes
- Compare as funções em `utils_*.R` com os arquivos em `tests/testthat/`. Liste funções importantes que ainda não possuem testes unitários.

### ⚠️ Restrição Importante
**NÃO quebre o app funcional.** Suas sugestões devem ser evolutivas e baseadas em refatoração segura. Para cada ponto de melhoria, forneça:
1. **O Problema**: O que está errado e qual arquivo/linha.
2. **A Justificativa**: Qual regra do projeto está sendo violada.
3. **A Solução (Snippet)**: Código refatorado seguindo os padrões do projeto.

--- 

Aguardarei sua análise detalhada em formato Markdown."

### 🚀 [FIM DO PROMPT] 🚀
