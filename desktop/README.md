# Saíra desktop: prévia local da v1.0

Este piloto parte de `release/v1.0.0`, commit
`3af52af1` (#225). A base inclui as passagens exatas antes da busca aproximada
(#219), a atualização da Flora BR e da Fauna BR num processo R separado (#220),
o nome sugerido com o nome aceito (#221), a View Transition sem
`InvalidStateError` (#222), a consulta ao IPT a cada 30 dias (#223), as cópias
exatas fora do pacote (#224) e a lista de correções do Pacote (#225).
O worker da atualização usa `callr`, sem socket de rede, então o Windows não
pede acesso do R às redes públicas (ADR-177).
O `DESCRIPTION` da base ainda informa `0.11.2`. O instalador usa a versão
`1.0.0-desktop.5` para identificar a prévia, sem antecipar a release do pacote.

Não há workflow, push, publicação nem atualização automática nesta etapa.
O empacotamento usa Windows x64 e `runtime_strategy: bundled`. O R e as
dependências são incluídos no aplicativo; o usuário final não precisa instalar R.

## Preparar o kit no WSL

Na raiz desta worktree:

```bash
Rscript --vanilla desktop/build.R --check
Rscript --vanilla desktop/prepare-windows.R
```

O `prepare-windows.R` grava o branch e o commit do HEAD no `toolchain.dcf` do
kit. O pacote-fonte vem do `R CMD build` da worktree, então arquivos do pacote
ainda sem commit também entram no kit. Nesse caso, o script
mostra um aviso com a lista desses arquivos.

O ZIP fica em `desktop/_build/saira-desktop-windows-kit.zip`. Ele inclui um
pacote-fonte do Saíra, o shell com as fontes e a foto, o lançador e os scripts
de build. Não inclui a
biblioteca Linux, o autoloader do renv, o histórico Git, os mockups ou arquivos
locais do checkout original. É possível escolher outro destino com
`--output=/caminho/kit.zip`.

Copie o ZIP para o Windows e extraia numa pasta curta de um disco Windows,
por exemplo `C:\saira-local`. Não compile diretamente de `\\wsl.localhost\...`.
O kit funciona sem clonar ou enviar o projeto ao GitHub.

## Gerar o instalador no Windows

Na máquina de build, use R >= 4.5.0, Node >= 22 e npm >= 11.5.0.
R 4.5.2 e Node 24 são adequados para este piloto. A preparação precisa de internet
para baixar ferramentas, R portátil e pacotes. Isso não equivale a publicar o app.

Abra o PowerShell na pasta extraída que contém `DESCRIPTION` e `desktop`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\desktop\build.ps1
```

O script encontra o R instalado, prepara o shinyelectron em `desktop/_tools`
e gera uma pasta nova em `%LOCALAPPDATA%\saira-desktop-builds`. Para escolher
outro destino ou R:

```powershell
.\desktop\build.ps1 -OutputDirectory C:\saira-local\build-01 -Rscript 'C:\Program Files\R\R-4.5.2\bin\Rscript.exe'
```

O destino precisa ser novo. Um build existente nunca é apagado pelo script.
O instalador `.exe` fica em `bundle\electron-app\dist` dentro do destino.
Também existe `win-unpacked` para testes sem instalação.

O shinyelectron fica fixado por commit e SHA-256 em `toolchain.dcf`.
O R embarcado é 4.5.2 e o Electron é 45.0.0. Os comandos gerados pelo
shinyelectron usam `electron-builder --publish never`.

### Versões dos pacotes

O build instala os pacotes do snapshot do CRAN na data do `renv.lock`
(`packagemanager.posit.co/cran/2026-10-22`). Depois, `desktop_check_versions()`
compara a biblioteca embarcada com o `renv.lock`. O build para se:

- um pacote embarcado não estiver no `renv.lock`;
- uma versão for diferente do lock, exceto nos pacotes do r-universe e nos
  pacotes recomendados do R. O snapshot só tem releases do CRAN.

As diferenças aceitas ficam em `version-differences.csv`. O build também grava
`build-info.json`, `source-renv.lock`, `node-package-lock.json` e
`bundled-packages.csv` para comparação.

### Tamanho

`desktop_prune_library()` remove `doc`, `help`, `html`, `examples`, `demo` e
`include` de cada pacote. O app não lê essas pastas. O Electron leva só os
idiomas pt-BR, en-US, es e es-419, em vez de 55. A biblioteca R tem 140 pacotes;
`sf`, `terra` e `V8` somam cerca de 300 MB dos 504 MB. Os DLLs de `sf` e `terra`
(109 e 114 MB) não têm símbolos de depuração, e os dois pacotes vêm de
`CoordinateCleaner`, `rnaturalearth`, `florabr`, `faunabr` e `leaflet`.

`desktop_prune_runtime()` tira do R portátil o Tcl/Tk, as traduções das
mensagens do R, a ajuda dos pacotes base e os pacotes recomendados que nenhum
pacote do bundle carrega (Depends, Imports ou LinkingTo). Na prévia 5, isso
soma 75 MB. As mensagens de erro do R ficam em inglês.

## Shell do desktop

`desktop/shell` substitui o `main.js`, o `preload.js` e a tela de abertura do
shinyelectron. O build copia esses arquivos sobre o app gerado. O shell:

- isola o R da instalação pessoal: biblioteca só do bundle, sem `.Rprofile`
  nem `.Renviron` do usuário;
- guarda os dados em `%LOCALAPPDATA%\saira-desktop-preview`, separados do uso
  convencional em R;
- abre com a foto da saíra-pintor e as etapas da partida do R, no tema
  escolhido na última sessão;
- não tem barra de menu, mas mantém os atalhos de edição, zoom, tela cheia e
  `Ctrl+Q`;
- abre links externos no navegador e mantém a janela no app local;
- pede uma pasta ao baixar arquivos, com o tipo do arquivo no filtro;
- ao fechar com dados que não foram exportados, avisa quantos registros serão
  perdidos e oferece "Ir para Exportação". Depois de um download da Exportação,
  só pergunta se pode fechar;
- encerra o R e os workers em até 10 s, numa janela pequena "Fechando o Saíra";
- mostra as últimas linhas do R e um botão para copiar os detalhes se o R parar;
- permite só uma janela e lembra o tamanho, a posição e o tema.

As ferramentas de desenvolvedor só aparecem com `SAIRA_DESKTOP_DEVTOOLS=1`.

O ícone é o S itálico do logotipo sobre o cinza do app
(`desktop/shell/assets/icon.ico`, de 16 a 256 px). Para gerar de novo, rode
`Rscript desktop/icon.R` num ambiente com chromote e Chrome. O build só copia
o arquivo. As fontes vêm de `inst/app/www/vendor/fonts` e a foto vem de
`website/assets/img/landing`. O `prepare-windows.R` copia as duas para o kit.

## Testar a prévia

O aplicativo aparece como **Saíra (prévia)** e usa identidade de instalação
própria. O lançador não altera configurações permanentes do Windows.

Teste no Windows com uma planilha real:

- Abrir pelo ícone, importar a planilha e percorrer Mapeamento, Pré-visualização,
  Nomes, Coordenadas, Generalização e Exportação.
- Gerar o DwC-A, o XLSX e o arquivo privado de coordenadas, quando aplicável.
  Conferir nomes dos arquivos, conteúdo e pasta escolhida.
- Repetir com XLSX e Camtrap DP/Wildlife Insights.
- Iniciar sem internet. Mapeamento, bases brasileiras e verificações locais
  devem funcionar; COL XR/IUCN e mapas externos continuam dependendo de rede.
- Testar janelas menores, escala 125%/150%, teclado e troca PT/EN/ES.
- Fechar e reabrir. Conferir que o processo R iniciado pelo app encerra e que
  modelos exportados persistem.
- Testar planilhas maiores e anotar tempo de abertura, importação, validação,
  exportação e memória total da árvore de processos.
- Testar também numa máquina/VM sem R e Node para confirmar a independência do bundle.

Esta prévia é local e não assinada; o Windows pode exibir o aviso de editor
desconhecido. Assinatura, atualizações e distribuição pública ficam para uma
etapa posterior. Os algoritmos do pacote permanecem os da base, para separar
problemas de empacotamento de alterações funcionais.

### Smoke test

Depois do build, há um teste sem abrir a janela do Electron:

```powershell
.\desktop\smoke.ps1 -BuildDirectory 'C:\caminho\do\build'
```

Ele usa o R de `win-unpacked`, verifica que as dependências vêm do bundle e
exercita bibliotecas nativas, CSV, coordenadas, XLSX e DwC-A com dados fictícios.
Também confere que o worker `callr` carrega o bundle sem socket de escuta fora
do loopback, e que a verificação offline
de nomes sugere *Euterpe edulis*. Por fim, inicia o lançador empacotado numa
porta local temporária e confere a página e o CSS. Os logs ficam em `diagnostics`.

### Teste ponta a ponta

`desktop/e2e.mjs` abre o `win-unpacked` e percorre o app como um usuário.
Ele não usa pacotes npm: controla a janela pelo CDP e o processo principal pelo
inspector do Node. Rode com o Node do Windows, a partir de uma pasta do Windows:

```powershell
node .\desktop\e2e.mjs 'C:\caminho\do\build\bundle\electron-app\dist\win-unpacked\saira-desktop-preview.exe' .\desktop\examples\ocorrencias-e2e.csv
```

O CSV precisa passar o bloqueio da exportação. O kit traz
`ocorrencias-e2e.csv`: é o exemplo do site sem os dois bloqueios de propósito.
O teste cria uma pasta nova ao lado do CSV, com `LOCALAPPDATA`, downloads,
`shell-stdout.log` e `results.json`. Ele verifica a abertura, a janela sem
barra de menu, a importação com mapeamento automático, a validação de nomes,
os links externos, o aviso ao fechar antes de exportar (com o app em inglês),
o download do DwC-A, a pergunta ao fechar depois da exportação e o
encerramento do R. O teste substitui o diálogo nativo e o navegador por stubs,
então nada abre fora do app.

## Referências

- [shinyelectron: runtime bundled](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/runtime-strategies.html)
- [shinyelectron: pacotes locais](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/configuration.html#local-r-packages)
- [Código do empacotador fixado neste piloto](https://github.com/coatless-rpkg/shinyelectron/tree/b334020d9e84b5f9b9eb6d804b846753880cdbc8)
