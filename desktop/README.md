# Saíra desktop

Este piloto parte de `release/v1.0.0`. O `build-info.json` de cada build grava o
commit, o branch e se havia arquivos sem commit (campo `source`). O `desktop-info.json`
leva o commit para o relatório de falha do app.
O worker da atualização usa `callr`, sem socket de rede, então o Windows não
pede acesso do R às redes públicas (ADR-177).
O `DESCRIPTION` da base ainda informa `0.11.2`. O instalador usa a versão
`1.0.0-rc.1` para identificar o candidato, sem antecipar a release do pacote. No
corte, a versão passa a `1.0.0`. O nome, o `slug` e o `app_id` não mudam depois da
primeira publicação (ADR-192).

Não há workflow, push, publicação nem atualização automática nesta etapa.
O empacotamento usa Windows x64 ou Linux x64 e `runtime_strategy: bundled`. O R e as
dependências são incluídos no aplicativo; o usuário final não precisa instalar R.

## Preparar o kit no WSL

Na raiz desta worktree:

```bash
Rscript --vanilla desktop/build.R --check
Rscript --vanilla desktop/prepare-windows.R
```

O `prepare-windows.R` grava o branch, o commit do HEAD e o estado sem commit no
`toolchain.dcf` do kit. O pacote-fonte vem do `R CMD build` da worktree, então arquivos do pacote
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

O build para se a árvore tiver arquivos sem commit. Numa prévia, aceite esse estado
com `--allow-dirty` (`-AllowDirty` no `build.ps1`). Uma versão final, sem sufixo,
sempre exige árvore limpa.

O shinyelectron fica fixado por commit e SHA-256 em `toolchain.dcf`.
O R embarcado é 4.6.1 e o Electron é 45.2.3. Os comandos gerados pelo
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

### Snapshot da Flora BR e da Fauna BR

O snapshot do pacote (ADR-153) envelhece entre as releases. Com mais de 30 dias,
a primeira checagem de nomes de uma instalação nova espera o download das duas
bases. Por isso, o build baixa as versões do IPT com o R embarcado e as grava no
saira embarcado. As versões ficam em `br_snapshot` no `build-info.json`. Se o IPT
não responder, o build avisa e mantém o snapshot do pacote.

### Pacotes npm, assinatura e fuses

`desktop/node-package-lock.json` é o lockfile npm aprovado. O build para sem esse
arquivo. O build o copia antes do `npm install` e para antes do electron-builder se
o npm resolver outra versão ou outro hash. Para aprovar uma mudança, revise o
`package-lock.json` de `bundle/electron-app` no destino e copie-o para
`desktop/node-package-lock.json`.

O override leva ao minimatch 11 as versões 9 e 10 que o electron-builder pede, e o
`npm audit` fica sem alertas. O minimatch 3 e 5 ficam: estão fora da faixa do
advisory (ADR-191). Não rode `npm audit fix --force`: ele propõe um
electron-builder antigo.

Com um certificado em `WIN_CSC_LINK` ou `CSC_LINK` e a senha em
`WIN_CSC_KEY_PASSWORD` ou `CSC_KEY_PASSWORD`, o electron-builder assina o app.
Sem certificado, o build não assina. Nos dois casos, `dist\SHA256SUMS.txt` tem o
SHA-256 de cada instalador.

O `package.json` liga os fuses do Electron: sem `ELECTRON_RUN_AS_NODE`,
`NODE_OPTIONS` e `--inspect`, e com o processo principal carregado do `app.asar`.
O `main.js` e o backend ficam nesse arquivo. O R, as bibliotecas e o app Shiny ficam
em `app.asar.unpacked`, porque precisam existir como arquivos no disco. Os fuses
não verificam essa pasta. O Electron só confere a integridade do `app.asar` no
Windows e no macOS, e não no Linux (ADR-191). Se o app não abrir depois de uma
mudança nos fuses, investigue a causa: desligar um fuse tira uma proteção do pacote.

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

## Gerar o app Linux

O build Linux roda no WSL ou num Linux x64, na raiz desta worktree, sem kit:

```bash
Rscript --vanilla desktop/bootstrap.R
Rscript --vanilla desktop/build.R
```

O `bootstrap.R` instala o shinyelectron e o Node fixado em `desktop/_tools`.
O destino padrão é `~/.local/share/saira-desktop-builds`. Em
`bundle/electron-app/dist` ficam o `.AppImage`, o `.deb` e `linux-unpacked`.

O shinyelectron não tem R portátil para Linux. Por isso, o build:

- baixa o R 4.6.1 do Posit r-builds (`.deb` do Ubuntu 24.04), com o SHA-256 do
  `toolchain.dcf`, e o torna relocável: `bin/R` e `bin/Rscript` acham o
  `R_HOME` pelo próprio caminho;
- instala os pacotes binários do snapshot P3M `__linux__/noble` na data do
  `renv.lock`;
- copia para `R_HOME/syslib` as bibliotecas que o `ldd` lista, menos glibc,
  OpenGL, X11/xcb, fontconfig, freetype, harfbuzz e expat, que vêm do sistema;
- copia os dados do PROJ e do GDAL para `syslib/share`.

O app precisa de glibc 2.39 ou mais nova: Ubuntu 24.04, Debian 13, Fedora 40
ou posterior. A glibc da máquina de build define esse mínimo. O `.deb`
declara `libc6 (>= 2.39)` além das dependências padrão do electron-builder, e
o build para se algum ELF do app pedir uma glibc mais nova. O `.deb` instala
em `/opt/Saíra`.

O build muda dois arquivos gerados (`desktop_apply_shell()` e
`desktop_patch_apprun()`). Se o texto original mudar numa versão nova do
shinyelectron ou do electron-builder, o build para:

- o R abre um grupo de processos próprio, e o encerramento sinaliza o grupo,
  então os workers do R param junto;
- o `AppRun` do AppImage não abre o app sem a sandbox do Chromium. Num sistema
  que bloqueia namespaces de usuário (Ubuntu 24.04 com AppArmor), o AppImage
  mostra uma mensagem e pede o `.deb`, que instala um perfil AppArmor. O texto
  da mensagem fica em `desktop/apprun-sandbox.sh`.

## Shell do desktop

`desktop/shell` substitui o `main.js`, o `preload.js` e a tela de abertura do
shinyelectron. O build copia esses arquivos sobre o app gerado. O shell:

- isola o R da instalação pessoal: roda só o R do bundle, com `--vanilla`, e usa
  biblioteca só do bundle. Sem o R do bundle, o app mostra um erro e não procura
  outro R;
- se o Electron morrer à força, o R nota a saída em até 5 s e encerra (ADR-192);
- guarda os dados em `%LOCALAPPDATA%\saira-desktop` (no Linux,
  `~/.local/share/saira-desktop`), separados do uso convencional em R;
- no Linux, usa `C.UTF-8` se o locale não for UTF-8, porque o R não lê o
  caminho com acento no locale C;
- abre com a foto da saíra-pintor e as etapas da partida do R, no tema
  escolhido na última sessão;
- não tem barra de menu, mas mantém os atalhos de edição, zoom, tela cheia e
  `Ctrl+Q`;
- abre links externos no navegador e mantém a janela no app local;
- pede uma pasta ao baixar arquivos, com o tipo do arquivo no filtro;
- ao fechar com dados que não foram exportados, avisa quantos registros serão
  perdidos e oferece "Ir para Exportação". Depois de um download da Exportação,
  só pergunta se pode fechar;
- encerra o R e os workers em até 10 s, numa janela pequena "Fechando o Saíra".
  No Linux, o shell sinaliza o grupo do R e espera o grupo sumir. O worker da
  atualização BR (`callr`) roda em sessão própria, e o supervisor dele o encerra
  em até 3 s depois do R;
- divide o log do dia em partes de 10 MB e abre um log novo na virada do dia. Apaga
  logs com mais de 30 dias e, acima de 50 MB no total, os logs mais antigos. Um erro
  no arquivo de log para só o log em arquivo;
- num erro fatal do processo principal, encerra o R antes de sair;
- mostra as últimas linhas do R e um botão para copiar os detalhes se o R parar;
- permite só uma janela e lembra o tamanho, a posição e o tema.

As ferramentas de desenvolvedor só aparecem com `SAIRA_DESKTOP_DEVTOOLS=1`.

O ícone é o S itálico do logotipo sobre o cinza do app
(`desktop/shell/assets/icon.ico`, de 16 a 256 px, e `icon.png`, 256 px, para o
Linux). Para gerar de novo, rode
`Rscript desktop/icon.R` num ambiente com chromote e Chrome. O build só copia
o arquivo. As fontes vêm de `inst/app/www/vendor/fonts` e a foto vem de
`website/assets/img/landing`. O `prepare-windows.R` copia as duas para o kit.

## Testar o app

O aplicativo aparece como **Saíra** e usa identidade de instalação própria. O lançador não altera configurações permanentes do Windows.

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

Sem certificado, o app não é assinado, e o Windows pode exibir o aviso de
editor desconhecido. Atualizações e distribuição pública ficam para uma etapa
posterior. Os algoritmos do pacote permanecem os da base, para separar
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

No Linux, rode o `smoke.R` com o R do `linux-unpacked`. Esse caminho não testa o
lançador:

```bash
R=<build>/bundle/electron-app/dist/linux-unpacked/resources/app.asar.unpacked/runtime/R
RENV_CONFIG_AUTOLOADER_ENABLED=FALSE "$R"/portable-r-4.6.1-linux-x64/bin/Rscript \
  --vanilla desktop/smoke.R --library="$R/library"
```

### Teste do shell sem Electron

`desktop/shell-check.mjs` confere o encerramento da árvore de processos, a
limpeza de logs e o arquivo de log, sem abrir janela. Rode no Linux e com o Node do
Windows:

```bash
node desktop/shell-check.mjs desktop/shell/process-tree.js desktop/shell/log-retention.js desktop/shell/log-writer.js
```

### Teste ponta a ponta

`desktop/e2e.mjs` abre o `win-unpacked` e percorre o app como um usuário.
Ele não usa pacotes npm: controla a janela pelo CDP e o processo principal pelo
inspector do Node. Rode com o Node do Windows, a partir de uma pasta do Windows:

```powershell
node .\desktop\e2e.mjs 'C:\caminho\do\build\bundle\electron-app\dist\win-unpacked\saira-desktop.exe' .\desktop\examples\ocorrencias-e2e.csv
```

O executável distribuído ignora `--inspect` (fuse do Electron). O teste confere
os fuses, copia o `win-unpacked` para a pasta do teste e liga só esse fuse na
cópia. O CSV precisa passar o bloqueio da exportação. O kit traz
`ocorrencias-e2e.csv`: é o exemplo do site sem os dois bloqueios de propósito.
O teste cria uma pasta nova ao lado do CSV, com `LOCALAPPDATA`, downloads,
`shell-stdout.log` e `results.json`. Ele verifica a abertura, a janela sem
barra de menu, a importação com mapeamento automático, a validação de nomes,
os links externos, o aviso ao fechar antes de exportar (com o app em inglês),
o download do DwC-A, a pergunta ao fechar depois da exportação e o
encerramento do R. Depois ele mata o renderer no app e na tela de início, e
confere a tela de reinício, a tela de erro de uma carga recusada, o diálogo
nativo e um só R após o reinício. O teste substitui o diálogo nativo e o navegador por stubs,
então nada abre fora do app.

No Linux, rode com `desktop/_tools/node-linux/bin/node`. O teste precisa do
`WebSocket` global, e o Node do sistema pode não ter essa API.

## Referências

- [shinyelectron: runtime bundled](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/runtime-strategies.html)
- [shinyelectron: pacotes locais](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/configuration.html#local-r-packages)
- [Código do empacotador fixado neste piloto](https://github.com/coatless-rpkg/shinyelectron/tree/b334020d9e84b5f9b9eb6d804b846753880cdbc8)
