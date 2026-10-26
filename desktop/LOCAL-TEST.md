# Validação local do bundle

## Quarta prévia: 26/10/2026

Base: `release/v1.0.0` em `46ba53e87c3853baa9f8ffdd2a1844f02fb56164` (#223).
O kit saiu de `1147727` com os arquivos de #222 e #223 ainda sem commit. Esses
arquivos são iguais aos de `46ba53e`.

- Prévia desktop: `1.0.0-desktop.4`, pacote `saira 0.11.2`.
- Shell: sem a seta de ajuda e sem a janela Sobre. A ajuda fica no botão do app.
- Instalador: 349 MB. `win-unpacked`: 977 MB.

O `smoke.ps1` passou. O `e2e.mjs` passou 11 de 11 verificações:

| Etapa | Resultado |
| --- | --- |
| Abertura até o Shiny conectado | 8 s |
| Barra de menu | Oculta; edição, zoom, tela cheia e sair continuam |
| Importação e mapeamento automático | `scientificName` <- `especie`, 18 s |
| Validação de nomes | 56 nomes, 42 s |
| Links externos | Vão para o navegador; a janela fica no app |
| Fechar antes de exportar | Aviso em inglês com 1.105 registros; "Go to Export" abre a aba |
| Download do DwC-A | `saira-dwc-archive.zip`, 7 s |
| Fechar depois de exportar | Cancelar mantém a janela; Fechar sai em 1 s, código 0 |
| R | Porta fechada, nenhum processo do build restante |

Na primeira execução, o teste fechou a janela 58 ms antes do evento `done` do
download, e o shell ainda avisou que os dados não foram exportados. O `.zip` já
estava no disco. Agora o E2E espera a linha `Download completed` do shell.

O snapshot da Flora BR e da Fauna BR é de 23/09/2026, com mais de 30 dias.
Por isso, a primeira validação de nomes ainda inicia a atualização dos dois
catálogos (ADR-174).

## Terceira prévia: 26/10/2026

Base: a mesma da segunda prévia, mais duas correções do pacote ainda sem commit:
`motion.js` e `theme-switch.js` sem `InvalidStateError` na View Transition, e a
verificação da Flora BR e da Fauna BR no máximo a cada 30 dias.

- Prévia desktop: `1.0.0-desktop.3`, pacote `saira 0.11.2`.
- Shell novo: abertura com foto, tela de erro com o log do R, aviso ao fechar
  sem exportar, janela "Fechando", janela Sobre, menu de ajuda na barra do app,
  ícone próprio e licença `GPL-3.0-only` no `package.json`.
- Instalador: 349 MB. `win-unpacked`: 977 MB.

O `smoke.ps1` passou. O `e2e.mjs` passou 17 de 17 verificações:

| Etapa | Resultado |
| --- | --- |
| Abertura até o Shiny conectado | 8 s |
| Barra de menu | Oculta; edição, zoom, tela cheia e sair continuam |
| Menu de ajuda | PT, EN e ES acompanham o idioma do app |
| Novidades e Sobre | Novidades vai para o navegador; OK fecha o Sobre |
| Importação e mapeamento automático | `scientificName` <- `especie`, 12 s |
| Validação de nomes | 56 nomes, 33 s |
| Fechar antes de exportar | Aviso com 1.105 registros; "Ir para Exportação" abre a aba |
| Download do DwC-A | `saira-dwc-archive.zip`, 6 s |
| Fechar depois de exportar | Cancelar mantém a janela; Fechar sai em 1 s, código 0 |
| R | Porta fechada, nenhum processo do build restante |

## Segunda prévia: 26/10/2026

Base: `release/v1.0.0` em `11477277e69485428595d62e882f20bed46c8399` (#221).

- Prévia desktop: `1.0.0-desktop.2`, pacote `saira 0.11.2`.
- Windows x64; R portátil 4.5.2; Electron 45.0.0; electron-builder 26.
- Instalador: 348 MB (antes 411 MB). `win-unpacked`: 976 MB (antes 1123 MB).
- Biblioteca R: 504 MB (antes 604 MB), 140 pacotes. Electron: 4 idiomas (antes 55).
- Versões: iguais ao `renv.lock`, exceto pacotes do r-universe e recomendados
  (`version-differences.csv`).

O `smoke.ps1` passou: dependências do bundle, bibliotecas nativas, CSV,
coordenadas, XLSX, DwC-A, workers R, verificação offline de nomes e lançador.

O `e2e.mjs` passou 13 de 13 verificações no `win-unpacked`, com
`ocorrencias-e2e.csv` e uma pasta de dados vazia:

| Etapa | Resultado |
| --- | --- |
| Abertura até o Shiny conectado | 9 a 11 s |
| Menus | PT, EN e ES acompanham o idioma do app |
| Importação e mapeamento automático | `scientificName` <- `especie`, 14 a 16 s |
| Validação de nomes | 49 nomes, 25 s |
| Links externos | Vão para o navegador; a janela fica no app |
| Download do DwC-A | `saira-dwc-archive.zip`, 5 arquivos, 8 s |
| Fechar | Cancelar mantém a janela; Fechar sai em 1 s, código 0 |
| R | Porta fechada, nenhum processo do build restante |

Na primeira validação de nomes, o app atualiza a Flora BR e a Fauna BR em
segundo plano por cerca de 2 min. Durante esse tempo, o módulo de nomes lê o
estado a cada 1,2 s. Se o app fechar no meio da atualização, o lock fica no
disco. Com esse lock, `brprovider_cache_status()` lê os dois catálogos como
`up_to_date`, e a validação usa o cache existente.

## Primeira prévia: 24/10/2026

Base: `release/v1.0.0` em `b5d63a4ab1c685b2d4f4abd1258173bea95e1e02`.

- Prévia desktop: `1.0.0-desktop.1`, pacote `saira 0.11.2`.
- Biblioteca embarcada: 140 entradas, incluindo o próprio Saíra.
- O `npm audit` final não reportou vulnerabilidades nas dependências verificadas.

No R embarcado, as 28 dependências diretas carregaram da biblioteca do bundle.
Passaram sf, terra, SQLite, CSV, coordenadas 10m, XLSX, DwC-A, a construção do
app Shiny e o lançador de `win-unpacked`. A janela do Electron abriu uma sessão
Shiny conectada em `pt-BR`. O primeiro build usou o Electron 41; o alerta do
npm motivou a troca para 45.0.0.

## Rodada manual ainda necessária

Ainda precisam de teste manual: instalação e desinstalação pelo `.exe`, máquina
sem R, uso sem conexão, escalas de tela e conjuntos grandes. O ícone é próprio
desde a terceira prévia, mas falta conferir no menu Iniciar, na barra de
tarefas e com escala de 150%. Esta prévia não é assinada.

Todas as alterações e artefatos permanecem locais. Não houve push, workflow,
tag nem release no GitHub.
