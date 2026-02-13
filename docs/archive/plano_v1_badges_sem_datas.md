# Plano de Implementacao - V1 + Badges (sem datas/horarios)

## 1) Objetivo
Entregar um auto-mapeamento mais inteligente no Finch sem aumentar risco de regressao no app Shiny.

No V1, ao clicar em "Auto-mapear", o sistema deve:
- analisar nome da coluna + amostra de valores;
- autopreencher mapeamentos com confianca alta e media;
- mostrar badge visual por termo (`AUTO`, `SUGERIDO`, `MANUAL`);
- manter revisao humana simples antes de exportar.

## 2) Experiencia do usuario (visao leiga)
Fluxo esperado:
1. Usuario sobe CSV.
2. Clica em `Auto-mapear`.
3. Finch preenche varios campos DwC automaticamente.
4. Cada campo aparece com um badge:
- `AUTO` (verde): confianca alta, pode seguir.
- `SUGERIDO` (amarelo): preencheu, mas vale revisar.
- `EDITADO` (azul): alterado pelo usuario (override manual).
- `MANUAL` (cinza): sem confianca suficiente, usuario escolhe.
5. Usuario revisa rapidamente os amarelos e cinzas.
6. Campos editados manualmente ganham badge azul para clareza.
7. Vai para Preview/Validacao/Export como hoje.

## 3) Escopo Fechado do V1
### 3.1 Em escopo
- Stage 1 apenas (mapeamento simples 1:1).
- Score hibrido: nome + conteudo.
- Thresholds:
- `AUTO`: score >= 0.90.
- `SUGERIDO`: 0.75 a 0.89.
- `MANUAL`: < 0.75.
- Conflito basico entre candidatos (escolher melhor coluna por termo).
- Badges visuais no modulo de mapeamento.
- Explicacao curta por badge (motivo principal + score).
- Override manual total: usuario sempre pode trocar selecao.

### 3.2 Fora de escopo no V1
- Inferencia para datas/horarios.
- Stage 2 (composicao de termos).
- Stage 3 completo (ambiguidade avancada e perdedor para verbatim*).
- Aprendizado local (aliases por usuario/instituicao).
- Governanca multiusuario.

## 4) Regra explicita para datas/horarios
No V1, o motor NAO vai inferir nem sugerir automaticamente estes termos:
- `eventDate`
- `year`
- `month`
- `day`
- `modified`
- `dateIdentified`

Comportamento:
- Se o nome da coluna for identico ao termo DwC (match exato), pode preencher.
- Fora isso, fica `MANUAL`.

Motivo:
- reduzir falso positivo;
- evitar regressao na logica atual de datas;
- simplificar entrega.

## 5) scientificName - status e decisao
Status atual no codigo:
- Ja existe tratamento para `scientificName` com selecao unica no mapping UI.
- Ja existe extracao de `genus`, `specificEpithet` e `taxonRank` a partir de `scientificName` no processamento final.

Decisao para este V1:
- `scientificName` continua em escopo para score de mapeamento (nome + conteudo).
- Mantemos a extracao atual de componentes apos o mapeamento.
- Nao implementar composicao `genus + specificEpithet -> scientificName` neste ciclo.

Conclusao objetiva:
- `scientificName` esta resolvido para o fluxo atual do Finch.
- O que fica pendente (intencionalmente) e composicao avancada, que e escopo de fase futura.

## 6) Regras tecnicas do motor (Stage 1)
### 6.1 Entrada
- Colunas do CSV carregado.
- Lista de termos DwC do `dwc_terms.rds`.
- Dicionario de sinonimos V1.

### 6.2 Name score (0 a 1)
Ordem de prioridade:
1. Match exato normalizado (case/acento/simbolos): 1.00
2. Sinonimo conhecido: 0.90 a 0.98
3. Overlap de tokens: 0.55 a 0.80
4. Similaridade textual (distancia): 0.30 a 0.60

### 6.3 Value score (0 a 1)
Estrategia de Performance (Amostragem Otimizada):
- regra geral: ignora vazios e NAs;
- **Fast-path**: se `name_score >= 0.98` (match exato), validar apenas 30 valores iniciais para confirmacao de tipo basica.
- **Amostragem Adaptativa**:
  - se `0.85 <= name_score < 0.98`: amostra de 100 valores (`50 iniciais + 50 aleatorios`);
  - se `0.70 <= name_score < 0.85`: amostra de 200 valores (`100 iniciais + 100 aleatorios`);
  - se `name_score < 0.70`: nao autoaplica; manter `MANUAL` (sem custo de processamento).
- **Implementacao**: realizar a amostragem diretamente sobre o `data.frame` em memoria (evitar IO repetido).

Objetivo da amostragem:
- nao e para entender cabecalho;
- e para confirmar se o conteudo da coluna combina com o termo sugerido;
- reduzir falso positivo em cabecalhos ambiguos (`y`, `data`, `record`, `campo1`).

Heuristicas iniciais:
- Coordenadas (`decimalLatitude`, `decimalLongitude`): faixa numerica valida.
- `scientificName`: padrao taxonomico simples (Genus species, Genus sp., Genus cf. species).
- `individualCount`: inteiro nao negativo (tolerancia de ruido no limiar, sem exigir 100%).
- Demais termos V1: valor neutro quando nao houver validador especifico.

### 6.4 Score final
- `final_score = 0.5 * name_score + 0.5 * value_score`.
- Guardrails:
- se tipo incompatvel (ex.: texto puro para coordenada), bloquear `AUTO`.
- se coluna 100% vazia, score 0.

### 6.5 Decisao
- `AUTO` >= 0.90
- `SUGERIDO` 0.75-0.89
- `MANUAL` < 0.75

No clique em `Auto-mapear`:
- AUTO e SUGERIDO sao autopreenchidos no select.
- MANUAL permanece sem selecao.

## 7) Resolucao basica de conflitos
Quando duas colunas concorrerem para o mesmo termo:
1. maior `final_score` vence;
2. empate tecnico: maior `value_score` vence;
3. persistindo empate: preferir nome mais especifico (mais tokens relevantes).

No V1, a coluna "perdedora" nao e mapeada automaticamente para outro termo.

## 8) Badges e comportamento de UI
Badge por card DwC no modulo de mapeamento (alinhado com `custom.css`):
- `AUTO` (verde) -> `--success`
- `SUGERIDO` (amarelo) -> `--warning`
- `EDITADO` (azul) -> `--info`
- `MANUAL` (cinza) -> `--text-muted`

Tooltip/ajuda curta por badge:
- score final;
- motivo: "Match exato", "Sinonimo conhecido", "Validado por conteudo" ou "Ajustado pelo usuario".

Regra de override:
- Se o usuario alterar a selecao de um campo que era `AUTO` ou `SUGERIDO`, o estado muda imediatamente para `EDITADO`.
- Se o campo estava vazio e o usuario preenche, vira `EDITADO`.

## 9) Compatibilidade com o app atual
Compatibilidade obrigatoria:
- manter contrato de saida do `mod_mapping_server` como `reactive(data.frame)`;
- nao quebrar Preview, Validate Names e Validate Coords;
- preservar funcionamento atual de `eventDate` em modo manual/existente;
- manter contadores e filtro "show only mapped" coerentes com selects preenchidos.

## 10) Arquivos a alterar
Arquivos principais previstos:
- `R/utils_mapping.R`
- `R/mod_mapping.R`
- `R/data_dictionary.R`
- `inst/app/www/custom.css`
- `tests/testthat/test-utils-mapping.R`

Arquivo novo previsto:
- `data/dwc_synonyms_v1.csv` (ou `.rds`) com sinonimos iniciais curados.

## 11) Casos de teste obrigatorios
### 11.1 Unitarios (motor)
- Match exato por normalizacao.
- Match por sinonimo.
- Score de coordenadas validas vs invalidas.
- Score de `scientificName` valido vs ruido.
- Conflito com duas colunas candidatas para mesmo termo.
- Exclusao de termos temporais de inferencia automatica.

### 11.2 Integracao (modulo)
- Clique em `Auto-mapear` preenche AUTO e SUGERIDO.
- Badges aparecem corretamente por card.
- Override manual troca estado visual e nao quebra preview.
- Fluxo completo Upload -> Mapping -> Preview segue funcional.

## 12) Criterios de aceite
Pronto para merge quando:
1. Fluxo do usuario funciona como descrito na secao 2.
2. Nenhuma regressao critica em preview/validacoes/export.
3. Termos de data/hora nao sao inferidos automaticamente (exceto match exato).
4. `scientificName` continua funcionando no fluxo atual.
5. Testes novos passam.

## 13) Estimativa realista
Estimativa V1 + badges sem datas/horarios:
- 2 a 3 semanas de implementacao.
- 1 semana de validacao, ajuste de thresholds e testes.

Total esperado: 3 a 4 semanas.

## 14) Riscos e mitigacao
Risco:
- sugestoes demais em campos ambiguos.
Mitigacao:
- thresholds conservadores e bloqueio por tipo.

Risco:
- incoerencia entre badge e select manual.
Mitigacao:
- fonte unica de estado (metadata por termo + sincronizacao apos updateSelectInput).

Risco:
- regressao em `eventDate`.
Mitigacao:
- remover inferencia temporal do V1 e manter logica atual intacta.

## 15) Proxima fase (apos V1)
- Stage 2: composicao controlada (incluindo decisoes sobre `scientificName` bidirecional e datas).
- Stage 3: ambiguidade avancada e explicabilidade expandida.
- Aliases locais somente quando houver desenho claro de identidade/persistencia.
