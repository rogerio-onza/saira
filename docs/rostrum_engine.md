# Proposta Integrada Final: Motor de Mapeamento Inteligente DwC

## 1. Princípios Fundamentais

### 1.1 Arquitetura Baseada em Regras (Não IA)
O motor deve ser **100% explicável**. Quando mapeia `lat` → `decimalLatitude`, o usuário precisa ver:
- Por que foi mapeado (sinônimo exato, score de conteúdo)
- Qual foi o score (0.92 = auto-aplicado)
- Que alternativas foram descartadas

**Justificativa**: Dados científicos exigem auditoria. Publicações dependem dessa rastreabilidade.

### 1.2 Processamento Local
- Zero dependência de APIs externas
- Funciona offline (essencial para trabalho de campo)
- Privacidade total dos dados institucionais

### 1.3 Conservadorismo nos Thresholds
Dado o custo de erro em dados biológicos:
- **Auto-aplicar**: score ≥ 0.90 (alta confiança)
- **Sugerir**: 0.75-0.89 (revisão humana)
- **Rejeitar**: < 0.75 (mapeamento manual)

---

## 2. Arquitetura do Motor em 3 Estágios

### Stage 1: Mapeamento Simples (1:1)
Identifica colunas que correspondem diretamente a um termo DwC.

**Processo**:
1. Normalizar headers (lowercase, sem acentos, sem símbolos)
2. Tokenizar (`decimal_latitude` → `["decimal", "latitude"]`)
3. Calcular `name_score` (distância Levenshtein ou Jaccard + dicionário de sinônimos)
4. Calcular `value_score` (validação de conteúdo com amostragem)
5. Aplicar penalidades semânticas
6. Aplicar veto se necessário
7. Computar score final

**Output**: Lista de candidatos por coluna com scores.

### Stage 2: Síntese de Termos Compostos
Constrói termos DwC complexos a partir de colunas já mapeadas no Stage 1.

**Exemplos**:
- `scientificName` = `genus` + `specificEpithet` (+ `infraspecificEpithet`)
- `eventDate` = composição de ano + mês + dia
- `verbatimCoordinates` = lat + lon em formato texto

**Regras**:
- Só executa se as peças necessárias foram identificadas
- Valida se termo composto já não existe no dataset original
- Aplica lógica específica por termo (não concatenação cega)

**IMPORTANTE - Prevenção de Circularidade**:

Stage 2 só executa **DEPOIS** que Stage 1 terminou completamente. Isso evita deadlocks lógicos onde:
- `scientificName` precisa de `genus`
- Mas `genus` ainda não foi identificado
- Resultado: circularidade

**Ordem de execução garantida**:
1. Stage 1 mapeia "genus" → `genus` (completo)
2. Stage 1 mapeia "species" → `specificEpithet` (completo)
3. **Só então** Stage 2 inicia
4. Stage 2 verifica: "Falta `scientificName`? Sim."
5. Stage 2 verifica: "Existe `genus` mapeado? Sim."
6. Stage 2 compõe: `scientificName` ← `genus` + `specificEpithet`

**Regra adicional**: Termos compostos não "roubam" colunas já mapeadas. Se `genus` foi mapeado no Stage 1, ele permanece mapeado E é usado na composição.

### Stage 3: Resolução de Conflitos
Lida com múltiplas colunas candidatas para o mesmo termo DwC.

**Critérios de priorização**:
1. **Tipo de dado**: numérico > texto (para coordenadas)
2. **Completude**: menos valores missing/vazios
3. **Score de validação**: range/regex mais consistente
4. **Especificidade do nome**: nome mais específico vence genérico
5. **Token exato vs. substring**: token exato tem prioridade

**Casos especiais**:
- Se scores diferem < 0.1 → marcar como **ambiguidade legítima**, sugerir ambos
- Se uma coluna já foi usada em composição → descartar para mapeamento simples

---

## 3. Sistema de Scoring Híbrido

### 3.1 Name Score (Peso: 0.5)

**Hierarquia de Tipos de Match** (do mais confiável ao menos):

#### 1. Exact Match Normalizado (score = 1.0)
Após normalização (lowercase, sem acentos, sem símbolos), a string é idêntica ao termo DwC ou sinônimo.

**Exemplos**:
```
"decimalLatitude" → normaliza → "decimallatitude"
Dicionário tem "decimal latitude" → normaliza → "decimallatitude"
→ Match exato! score = 1.0

"stateprovince" (erro comum, sem espaço)
Dicionário tem "state province" → normaliza → "stateprovince"  
→ Match exato! score = 1.0
```

#### 2. Synonym Match (score = 0.9-0.95)
Match direto no dicionário de sinônimos, com confiança variável.

**Exemplos**:
```
"lat" → dicionário → decimalLatitude (confidence: 0.95)
→ score = 0.95

"y" → dicionário → decimalLatitude (confidence: 0.6, contexto cartesiano)
→ score = 0.6 (requer validação forte de conteúdo)
```

#### 3. Token Overlap Completo (score = 0.7-0.8)
Todos os tokens da coluna estão presentes no termo DwC.

**Exemplos**:
```
"decimal lat" → tokens: ["decimal", "lat"]
decimalLatitude → tokens: ["decimal", "latitude"]
"lat" é substring de "latitude" ✓
→ score = 0.75

"lat decimal" (ordem inversa)
→ mesma lógica, score = 0.75
```

**Penalização por substring**: Se token é apenas substring (não match exato), aplicar penalidade de -0.1.
```
Coluna: "record"
Candidato 1: recordNumber 
  → "record" é token exato ✓✓
  → score base = 0.8

Candidato 2: recordedBy
  → "record" é substring de "recorded" ✓
  → score base = 0.7 (penalidade de -0.1 aplicada)
  
recordNumber vence por especificidade.
```

#### 4. Token Overlap Parcial (score = 0.4-0.6)
Apenas alguns tokens correspondem.

**Exemplos**:
```
"coord y" → tokens: ["coord", "y"]
decimalLatitude → tokens: ["decimal", "latitude"]
Overlap: "y" ~ "latitude" (parcial)
→ score = 0.5
```

#### 5. Distância de Levenshtein (score = 0.3-0.5)
Similaridade por edição de caracteres.

**Exemplos**:
```
"latitud" (falta 'e')
vs. "latitude"
→ 1 caractere diferente, score = 0.45

"latiude" (erro de digitação)
vs. "latitude"  
→ 2 caracteres diferentes, score = 0.35
```

**REGRA ESPECIAL - Token Overlap Requer Validação Forte**:

Se `name_score` ≤ 0.7 (indica que vem apenas de token overlap, não exact/synonym):
- **Exigir `value_score` mínimo de 0.8** (não 0.3 padrão)
- Isso evita falsos positivos em nomes genéricos

**Exemplo**:
```
Coluna: "coord y"
Match com decimalLatitude via tokens: name_score = 0.5

Cenário A: value_score = 0.95 (valores claramente latitude)
→ Score final = 0.5*0.5 + 0.5*0.95 = 0.725 ✓ (sugerido)

Cenário B: value_score = 0.7 (valores ambíguos)
→ Rejeitado (value_score abaixo de 0.8 necessário para token overlap)
```

### 3.2 Value Score (Peso: 0.5)

**Princípios**:
1. **Amostragem estratificada** (não apenas `head()`):
   - Se coluna tem ≤ 1000 linhas → valida todas
   - Se > 1000 → amostra uniformemente início, meio e fim
   - Sempre remove NAs antes da amostragem

2. **Validações por termo DwC**:

| Termo | Validação | Threshold |
|-------|-----------|-----------|
| `decimalLatitude` | Range -90..90 + padrão numérico | 95% das amostras válidas |
| `decimalLongitude` | Range -180..180 + padrão numérico | 95% das amostras válidas |
| `eventDate` | Regex ISO 8601 (`YYYY`, `YYYY-MM`, `YYYY-MM-DD`) + datas válidas | 90% das amostras válidas |
| `scientificName` | Padrão binomial (`Genus species`) + sem números isolados | 80% das amostras válidas |
| `year` | Range 1600..2100 + inteiro | 95% das amostras válidas |
| `individualCount` | Inteiro positivo | 100% das amostras válidas |

3. **Cálculo do score**:
```
value_score = (n_válidos / n_amostrados) * fator_de_confiança

Onde fator_de_confiança considera:
- Consistência (desvio padrão do tipo de dado)
- Ausência de valores obviamente errados
```

**Exemplo - Caso problemático resolvido por amostragem estratificada**:
```
Coluna: "depth_m"
Total: 1000 linhas
Primeiras 50: NA
Linhas 51-100: -80, -75, -62, -58 (parecem latitude!)
Linhas 101-1000: -4500, -3200, -800 (profundidade real)

Amostragem estratificada (1000 amostras):
- Índices: seq(1, 1000, length.out = 1000)
- Pega distribuição uniforme: início, meio, fim

Sample captura:
- ~5% NAs (ignorados)
- ~5% valores -80..-58 (falso positivo)
- ~90% valores -5000..-200 (profundidade)

value_score para decimalLatitude:
- Apenas 50/950 amostras em range -90..90 = 0.05
→ MUITO abaixo do threshold de 0.95 ✓ Rejeitado corretamente
```

### 3.3 Penalidades Semânticas

Reduzem score quando há evidência contextual contrária.

**Regras**:
- Nome contém `temp`, `temperatura` → penalidade -0.3 para coordenadas
- Nome contém `depth`, `profund`, `altura` → penalidade -0.3 para coordenadas
- Nome contém `count`, `numero`, `qtd` → penalidade -0.2 para datas
- Nome é genérico (`campo1`, `col_a`) → penalidade -0.1 para qualquer termo

**Aplicação**:
```
base_score = 0.5 * name_score + 0.5 * value_score
final_score = max(0, base_score + sum(penalidades))
```

### 3.4 Sistema de Veto

**Veto hard** (score = 0 imediato, ignora tudo):
- `value_score < 0.3` → validação de conteúdo falhou
- Tipo de dado incompatível (texto onde precisa numérico)
- 100% valores missing/vazios

**Nota sobre threshold de veto**: Veto em 0.3 (não 0.0) permite tolerância a erros de digitação comuns em dados reais. Um threshold de 0.0 seria excessivamente rígido e rejeitaria colunas com poucos valores inválidos (~5-10%), que são aceitáveis na prática.

**Veto soft** (força revisão manual):
- Detecção de múltiplos padrões conflitantes na mesma coluna
- Ambiguidade com score diff < 0.1 entre dois termos

---

## 4. Dicionário de Sinônimos

### 4.1 Estrutura do Dicionário

**Formato CSV**:
```csv
term,synonym,language,context,confidence,validation_regex,notes
decimalLatitude,lat,en,geographic,0.95,"^-?([0-8]?[0-9]|90)(\.[0-9]+)?$",
decimalLatitude,latitude,en,geographic,1.0,"^-?([0-8]?[0-9]|90)(\.[0-9]+)?$",
decimalLatitude,y,en,cartesian,0.6,"^-?([0-8]?[0-9]|90)(\.[0-9]+)?$",Menor confiança (pode ser eixo genérico)
decimalLatitude,lat_decimal,pt,geographic,0.95,"^-?([0-8]?[0-9]|90)(\.[0-9]+)?$",
decimalLongitude,lon,en,geographic,0.95,"^-?((1[0-7][0-9])|([0-9]{1,2})|180)(\.[0-9]+)?$",
decimalLongitude,long,en,geographic,0.9,"^-?((1[0-7][0-9])|([0-9]{1,2})|180)(\.[0-9]+)?$",Ambíguo com "longitude" tipo de dado
eventDate,data,pt,temporal,0.95,"^\d{4}(-\d{2}(-\d{2})?)?$",
eventDate,date,en,temporal,0.95,"^\d{4}(-\d{2}(-\d{2})?)?$",
eventDate,fecha,es,temporal,0.95,"^\d{4}(-\d{2}(-\d{2})?)?$",
scientificName,especie,es,taxonomic,0.85,"^[A-Z][a-z]+ [a-z]+",
scientificName,nome_cientifico,pt,taxonomic,0.9,"^[A-Z][a-z]+ [a-z]+",
```

**Campos**:
- `term`: Termo DwC canônico
- `synonym`: Variação em header de dados reais
- `language`: pt/en/es (permite filtrar por idioma do dataset)
- `context`: Tipo de contexto (geographic, temporal, taxonomic, measurement)
- `confidence`: 0..1 (quanto confiar nesse sinônimo)
- `validation_regex`: Regex para validar conteúdo
- `notes`: Observações sobre casos edge

### 4.2 Uso do Contexto

Quando há múltiplos matches, contexto desempata:
```
Header: "y"
Matches:
1. decimalLatitude (context: geographic, confidence: 0.6)
2. year (context: temporal, confidence: 0.3)

Se value_score indica ano (valores 2020-2024):
→ Escolhe year

Se value_score indica coordenada (valores -23..-15):
→ Escolhe decimalLatitude
```

### 4.3 Cobertura Mínima V1

**Top 20 termos DwC prioritários** (cobrem ~85% dos datasets reais):
- Geográficos: `decimalLatitude`, `decimalLongitude`, `coordinateUncertaintyInMeters`, `geodeticDatum`
- Temporais: `eventDate`, `year`, `month`, `day`
- Taxonômicos: `scientificName`, `genus`, `specificEpithet`, `infraspecificEpithet`, `taxonRank`
- Identificação: `recordedBy`, `identifiedBy`, `catalogNumber`, `recordNumber`
- Quantitativos: `individualCount`, `organismQuantity`

---

## 5. Composição de Termos Complexos

### 5.1 scientificName

**Não é concatenação simples**. Precisa lidar com:

**Casos válidos**:
- `Genus species` (padrão binomial básico)
- `Genus species subsp. subspecies` (trinomial)
- `Genus sp.` (espécie indeterminada)
- `Genus cf. species` (identificação incerta - *confer*)
- `Genus aff. species` (afinidade taxonômica - *affinis*)
- `Genus species Author, Year` (com autoria)

**Lógica de composição**:
1. **Validar genus** (obrigatório, primeira letra maiúscula)
2. **Processar specificEpithet**:
   - Se = "sp." ou "spp." → parar aqui (`Genus sp.`)
   - Se começa com "cf." ou "aff." → incluir qualificador
   - Caso contrário → incluir normalmente
3. **Processar infraspecificEpithet** (só se specificEpithet não for indeterminado):
   - Adicionar rank (`subsp.`, `var.`, `f.`) se disponível
   - Incluir epíteto infraespecífico
4. **Adicionar authorship** (opcional, no final)

**Validação final**:
- Verificar padrão com regex
- Confirmar ausência de números isolados
- Checar capitalização (Genus maiúscula, resto minúscula exceto autoria)

### 5.2 eventDate

**Já existe lógica no código atual** (4 colunas: ano, mês, dia, data completa).

**Refinamento necessário**:
- Validar se mês está entre 1-12
- Validar se dia é válido para aquele mês/ano (considerar anos bissextos)
- Formato de saída ISO 8601 estrito
- Lidar com datas parciais (`2023`, `2023-05`, `2023-05-12`)

### 5.3 Outras Composições Potenciais

**verbatimCoordinates** (baixa prioridade):
- Combinar lat + lon em formato textual
- Útil quando coordenadas originais são em graus/minutos/segundos

**habitat** (baixa prioridade):
- Concatenar múltiplos campos descritivos
- Exige separador claro (` | ` ou ` ; `)

---

## 6. Resolução de Múltiplos Candidatos

### 6.1 Cenário Problemático
```
Dataset tem:
- "lat_decimal" (numérico, -23.5, -22.8, ...)
- "lat_gms" (texto, "23°30'S", "22°48'S", ...)
- "coordenada_y" (numérico, -23.5, -22.8, ...)

Todos têm score alto para decimalLatitude.
```

### 6.2 Critérios de Desempate (ordem de aplicação)

#### 1. Preferência por tipo de dado
- Para coordenadas: numérico > texto
- Para datas: ISO 8601 > outros formatos

#### 2. Completude
- Contar NAs, strings vazias, valores "NULL"
- Preferir coluna com menos missing

#### 3. Score de validação
- Percentual de valores válidos no `value_score`
- Preferir maior consistência

#### 4. Especificidade do nome
- `lat_decimal` (específico) > `coordenada_y` (genérico)
- Match exato de sinônimo > match parcial

#### 5. Token exato vs. substring
**Penalizar matches de substring isolada**:
```
Coluna: "record"

Candidato 1: recordNumber
  → "record" é token exato no termo ✓✓
  → score += 0.1 (bonus de especificidade)

Candidato 2: recordedBy
  → "record" é apenas substring de "recorded" ✓
  → score -= 0.1 (penalidade por substring)

Resultado: recordNumber vence por ser match mais específico.
```

**Regra geral**: Token exato tem prioridade sobre substring. Aplicar bonus de +0.1 para token exato e penalidade de -0.1 para substring.

#### 6. Ambiguidade legítima (score diff < 0.1)
- **Não escolher automaticamente**
- Marcar como "ambiguidade legítima"
- Apresentar ambas opções ao usuário com justificativa

### 6.3 Casos Especiais

**Coluna já usada em composição**:
```
Se "genus" foi usado para compor scientificName:
→ Não permitir mapeamento simples de "genus" também
→ Evita duplicação de informação
```

**Mapeamento de coluna perdedora para termo relacionado**:

Quando há conflito entre duas colunas candidatas e uma vence, a perdedora pode ser mapeada para um termo DwC relacionado:
```
Cenário:
- "lat" (score 0.90) vs. "latitude" (score 0.95)
- Ambas candidatas para decimalLatitude

Resolução:
✓ "latitude" → decimalLatitude (vencedor)
✓ "lat" → verbatimLatitude (perdedor mapeado para termo relacionado)

Outros exemplos:
- "lon" perdeu → verbatimLongitude
- "data" perdeu → verbatimEventDate  
- "coordinates" perdeu → verbatimCoordinates
```

**Lógica de mapeamento do perdedor**:
1. Verificar se existe termo DwC "verbatim*" correspondente
2. Validar se coluna perdedora tem formato diferente (texto vs. numérico)
3. Mapear automaticamente se score >= 0.75
4. Caso contrário, sugerir ao usuário

**Benefício**: Preserva informação original mesmo quando há formato padronizado preferido.

---

## 7. Aprendizado Local (Aliases de Usuário)

### 7.1 Estrutura de Armazenamento

**Arquivo CSV por usuário/instituição**:
```csv
user_id,institution,col_name,dwc_term,confidence,created_at,created_by,reviewed
user123,INPA,coleta_data,eventDate,0.95,2025-02-10,user123,FALSE
user123,INPA,coletor,recordedBy,1.0,2025-02-10,user123,TRUE
```

**Campos**:
- `user_id`: Identificador do usuário
- `institution`: Namespace institucional (permite compartilhamento)
- `col_name`: Nome da coluna original (normalizado)
- `dwc_term`: Termo DwC mapeado
- `confidence`: Score da correção (calculado retroativamente)
- `created_at`: Timestamp da criação
- `created_by`: Quem fez a correção
- `reviewed`: Se foi revisado por supervisor/curador

### 7.2 Namespace e Permissões

**Níveis de compartilhamento**:
1. **Pessoal**: Aliases visíveis só para o usuário
2. **Institucional**: Aliases compartilhados na mesma instituição
3. **Público**: Aliases validados/revisados disponíveis para todos

**Regra de precedência**:
```
Pessoal > Institucional > Público > Dicionário base
```

### 7.3 Controle de Qualidade

**Auditoria**:
- Dashboard mostrando "aliases em uso" por instituição
- Curador pode revisar/reverter aliases suspeitos
- Flag automático se alias tem baixo `confidence` (<0.7)

**Reversão**:
```
Se alias "collector" → decimalLatitude foi erro:
1. Marcar como "reviewed = FALSE, deprecated = TRUE"
2. Não deletar (manter histórico)
3. Próximos uploads não usam esse alias
4. Notificar usuário que criou
```

**Aprendizado incremental**:
- Quando usuário **confirma** sugestão (score 0.75-0.89):
  - Criar alias com `confidence = score_original`
  - Marcar como `reviewed = TRUE` (foi validado por humano)
- Quando usuário **corrige** mapeamento automático:
  - Criar alias com `confidence = 1.0` (correção explícita)
  - Investigar por que motor errou (logging)

### 7.4 Implementação Técnica em Shiny

**Considerações**:
- Em Shiny Server multi-usuário: arquivo por usuário em pasta com permissões
- Em Desktop: arquivo local em `~/.finch/user_aliases.csv`
- Evitar localStorage do navegador (problemático em Shiny)
- Usar `flock` ou similar para evitar condições de corrida em escrita

**V1 mínima viável**:
- Apenas namespace pessoal
- Sem compartilhamento institucional (deixar para V2)
- Arquivo local simples, sem banco de dados

---

## 8. Interface de Usuário

### 8.1 Badges de Confiança

Cada campo mapeado mostra badge visual:

| Badge | Score | Significado | Cor |
|-------|-------|-------------|-----|
| 🤖 AUTO | ≥ 0.90 | Aplicado automaticamente | Verde |
| 💡 SUGERIDO | 0.75-0.89 | Precisa revisão | Amarelo |
| ⚠️ AMBÍGUO | Múltiplos candidatos score ~igual | Escolha manual necessária | Laranja |
| ✋ MANUAL | < 0.75 | Mapeamento manual | Cinza |
| 👤 ALIAS | - | Vem de aprendizado local | Azul |

### 8.2 Explicabilidade

Ao clicar no badge, mostrar popup com:
```
decimalLatitude ← "lat_decimal" [AUTO - 0.92]

Justificativa:
✓ Nome: "lat_decimal" é sinônimo exato (score: 0.95)
✓ Conteúdo: 98% dos valores em range -90..90 (score: 0.98)
✓ Tipo: Numérico (preferido para coordenadas)

Alternativas descartadas:
- year (score: 0.12) - valores fora de range esperado
- day (score: 0.08) - nome não corresponde
```

### 8.3 Resolução de Ambiguidade

Para campos marcados como AMBÍGUO:
```
⚠️ Ambiguidade detectada para "data"

Opções:
○ eventDate (score: 0.82)
  Justificativa: Padrão ISO 8601, valores 2020-2024
  
○ dateIdentified (score: 0.79)
  Justificativa: Contexto taxonômico, sinônimo parcial

[ Escolher ] [ Ver amostras ] [ Mapear manualmente ]
```

---

## 9. Performance e Otimização

### 9.1 Amostragem de Conteúdo

**Estratégia**:
```
Para cada coluna:
1. Remover NAs
2. Se n ≤ 1000: validar todos
3. Se n > 1000:
   - Calcular índices estratificados: seq(1, n, length.out = 1000)
   - Amostrar nessas posições (início, meio, fim)
4. Aplicar validações no sample
```

**Justificativa**:
- Evita viés de `head()` (apenas início)
- Captura variação ao longo do dataset
- Custo computacional fixo (sempre ~1000 validações)

**Alternativa mais rápida (menos precisa)**: 100 linhas do início + 100 aleatórias. Usar apenas se performance for crítica e datasets forem > 100k linhas.

### 9.2 Cache de Validações

Para datasets grandes com múltiplas tentativas de mapeamento:
```
Cache de value_score por coluna:
- Chave: hash(col_name + primeiras 100 linhas)
- Valor: value_score calculado
- Invalidar se coluna mudar
```

### 9.3 Processamento Paralelo (Futuro)

Para datasets > 50 colunas:
- Paralelizar cálculo de scores com `future`/`furrr`
- Cada coluna é independente no Stage 1
- Stage 2 e 3 são sequenciais (dependências)

---

## 10. Testes e Validação

### 10.1 Testes Unitários Essenciais

**Normalização e tokenização**:
```
Entrada: "Latitude_Decimal"
Esperado: c("latitude", "decimal")

Entrada: "data coleta"
Esperado: c("data", "coleta")
```

**Name score (hierarquia de tipos)**:
```
Exact match:
"decimallatitude" vs decimalLatitude → 1.0

Synonym match:
"lat" vs decimalLatitude → 0.95
"latitude_deg" vs decimalLatitude → 0.95

Token overlap completo:
"decimal lat" vs decimalLatitude → 0.75

Token overlap parcial:
"coord y" vs decimalLatitude → 0.5

Substring vs. token exato:
"record" vs recordNumber (token exato) → 0.8 + 0.1 bonus = 0.9
"record" vs recordedBy (substring) → 0.7 - 0.1 penalidade = 0.6
```

**Value score**:
```
Coluna [-23.5, -22.8, -21.3] → decimalLatitude: ≥ 0.95
Coluna ["2023-01-15", "2023-02-20"] → eventDate: ≥ 0.95
Coluna ["Panthera onca", "Tapirus terrestris"] → scientificName: ≥ 0.9
```

**Penalidades**:
```
"temp_air" + valores -5..35 → decimalLatitude: score ≤ 0.3
"profundidade" + valores -80..-60 → decimalLatitude: score ≤ 0.4
```

**Veto**:
```
Coluna de texto ["a", "b", "c"] → decimalLatitude: score = 0
Coluna 100% NA → qualquer termo: score = 0
```

**Regra especial token overlap**:
```
name_score = 0.5 (token overlap), value_score = 0.7
→ Rejeitado (value_score < 0.8 necessário para token overlap)

name_score = 0.5 (token overlap), value_score = 0.85
→ Aceito como sugestão (score final = 0.675)
```

### 10.2 Testes de Integração

**Datasets sintéticos**:
```
Dataset 1 (ideal):
- lat (numérico -90..90)
- lon (numérico -180..180)  
- data (ISO 8601)
- especie (binomial)
Esperado: 100% auto-mapeado

Dataset 2 (problemático):
- campo1 (valores -23..-15) 
- campo2 (valores -46..-40)
- campo3 (valores 2020-2024)
Esperado: ≥ 50% sugerido com ambiguidade

Dataset 3 (caótico):
- col_a, col_b, col_c (sem padrão)
Esperado: 0% auto-mapeado, 100% manual

Dataset 4 (conflito):
- lat (numérico) vs latitude (numérico)
Esperado: latitude → decimalLatitude, lat → verbatimLatitude
```

### 10.3 Validação com Dados Reais

**Coleções de referência**:
- GBIF: baixar 5 datasets de instituições brasileiras
- SpeciesLink: 5 datasets diversos
- iNaturalist: exports com headers variados

**Métricas de sucesso**:
- **Precisão**: Mapeamentos auto ≥ 95% corretos (validação manual)
- **Cobertura**: ≥ 60% de campos mapeados automaticamente
- **Redução de esforço**: Tempo de mapeamento manual reduz ≥ 70%

---

## 11. Roadmap de Implementação

### V1 - MVP (4-6 semanas)
**Objetivo**: Motor básico funcional

1. ✅ Dicionário de sinônimos estático (top 20 termos)
2. ✅ Normalização + tokenização robusta
3. ✅ Name score com hierarquia de tipos (exact, synonym, token overlap, Levenshtein)
4. ✅ Regra especial: token overlap requer value_score ≥ 0.8
5. ✅ Penalização substring vs. token exato
6. ✅ Value score com amostragem estratificada
7. ✅ Sistema de veto
8. ✅ Stage 1 (mapeamento simples)
9. ✅ UI com badges de confiança
10. ✅ Testes unitários básicos

**Não incluir**:
- Penalidades semânticas (adicionar depois)
- Stage 2 (composição)
- Aprendizado local

### V2 - Refinamento (2-3 semanas)
**Objetivo**: Robustez e inteligência

11. ✅ Penalidades semânticas
12. ✅ Stage 2 (composição de scientificName e eventDate com prevenção de circularidade)
13. ✅ Stage 3 (resolução de conflitos com mapeamento de perdedores)
14. ✅ Dicionário expandido (50+ termos)
15. ✅ Detecção de ambiguidade legítima
16. ✅ Testes de integração com datasets reais

### V3 - Aprendizado (3-4 semanas)
**Objetivo**: Melhoria contínua

17. ✅ Aliases de usuário (namespace pessoal)
18. ✅ Dashboard de auditoria
19. ✅ Sistema de revisão/reversão
20. ✅ Logging de erros do motor para análise

### V4+ - Futuro (conforme demanda)
- Namespace institucional (compartilhamento)
- Aliases públicos validados
- Processamento paralelo
- Suporte a mais idiomas (francês, alemão)
- Machine learning para casos não-estruturados (opcional, só se regras falharem consistentemente)

---

## 12. Critérios de Sucesso

### Métricas Quantitativas
- **≥ 60%** de campos mapeados automaticamente (score ≥ 0.90)
- **≥ 25%** de campos com sugestões úteis (score 0.75-0.89)
- **≤ 5%** de falsos positivos em mapeamento automático
- **≥ 70%** redução em tempo de mapeamento manual

### Métricas Qualitativas
- Usuários confiam no motor (não desmapeiam sugestões auto)
- Explicações são compreensíveis para não-programadores
- Motor funciona bem com headers em PT, EN e ES
- Aprendizado local melhora performance sem criar débito técnico

### Critérios de Rejeição (Red Flags)
- Taxa de falsos positivos > 10%
- Usuários preferem mapear manualmente (motor atrapalha mais que ajuda)
- Performance inaceitável (> 5s para processar 50 colunas)
- Aliases locais criam mais problemas que soluções