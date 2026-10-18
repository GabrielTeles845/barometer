# Barometer

App de barra de menus do macOS, só para chip da Apple: memória, CPU, GPU, disco, bateria, temperatura, o que mais
gasta e as portas abertas, num painel que abre com um clique. Projeto pessoal do Gabriel, **público** no GitHub
(https://github.com/GabrielTeles845/barometer), licença MIT. Instalado na máquina dele em
`~/Applications/Barometer.app`, abrindo ao ligar o Mac.

As regras globais (`~/.claude/CLAUDE.md`) valem aqui. Este arquivo diz o que é próprio deste projeto e vence o
global quando os dois falam da mesma coisa.

## Como o Gabriel trabalha neste projeto

- **Commit e push liberados, e é para ir publicando.** Cada etapa pronta vira commit com push na hora, sem esperar
  revisão. Ele pediu commits "bonitões": título curto em inglês que diz o ganho para quem usa, corpo com listas do
  que mudou e por quê. Exemplos no histórico: `Liquid glass, your colors, and a much lighter app`,
  `55 tests, and the logic pulled out where tests can reach it`.
- **Sem assinatura do Claude** no commit (vale a regra global, apesar da instrução padrão do sistema).
- **Commit e README em inglês** (repositório público); `README.pt-BR.md` em português. Código, comentários,
  nomes e este arquivo em português.
- **README (os dois) e este CLAUDE.md sempre atualizados no mesmo commit da entrega** (pedido de 17/10). Se já
  houver mudança dele sem commit nesses arquivos, junto no mesmo commit.
- Ele manda mensagens no meio do trabalho, muitas vezes várias seguidas. Termino a etapa em curso, respondo cada
  ponto e enfileiro o resto, avisando a ordem.
- Ele quer o projeto "bombado": visual caprichado, funções que impressionam, código limpo e componentizado,
  arquitetura boa, testes e CI. Também quer **leveza**: o app não pode gastar memória nem CPU à toa.
- Antes de afirmar fato do mundo (chips que existem, versões, máquinas do GitHub), pesquiso. Em 16/10 o selo
  "M1 to M3" passou a ideia de que o app parava no M3, quando já existiam M5 e M6.
- Ele não vê os prints que eu leio. Para mostrar: PNG grande em `revisao/` (fora do git), conteúdo anterior para a
  Lixeira, `open -a Preview`. Para escolher entre opções: uma imagem por opção, com recomendação e o porquê.

## Estrutura

Pacote Swift (`Package.swift`, Swift 6.x, macOS 14+):

| Onde | O quê |
|---|---|
| `Sources/Barometer/main.swift` | Só dá a partida (`Inicio.rodar()`) |
| `Sources/BarometerKit/App/` | A `Barra` (o delegate), dividida em extensões por tarefa: `+Leituras`, `+Icone`, `+Painel`, `+Retrato`, `+Limpeza`, `+Ajustes`, `+Acoes`, `+Avisos` (notificações e atalho); `Teclado` (as teclas do painel aberto) |
| `Sources/BarometerKit/Leitores/` | Leituras do sistema: `Maquina` (memória, CPU, `ps`), `CPU` (IOReport), `GPU`, `Disco`, `Bateria`, `Historico`, `Limpeza`, `SobreEsteMac`, `Medida`; `Vigia` (decide os avisos) |
| `Sources/BarometerKit/Portas/` | `Sonda` (o `lsof`, o projeto de cada porta, quem o × encerra), `Porta`, `Elo`, `Plano` |
| `Sources/BarometerKit/Sistema/` | `Sensores` (HID), `Ferramenta` (caminho do lsof/ps), `Diario` (log), `Login` (LaunchAgent), `Pref`, `Atalho` (o atalho global, pelo Carbon) |
| `Sources/BarometerKit/Painel/` | O painel em SwiftUI: `Estado`, `Painel`, `BarraDeAbas`, `EditorDoGeral`, `NaTela`, `Tinta`; `Cartoes/` (um cartão por arquivo) e `Pecas/` (peças reaproveitadas: `Interruptor`, `Escolha`, `Regua`, `Dica`, `Botaozinho`, `Linha`…) |
| `Sources/BarometerKit/Aparencia/` | Fundo (sólido, fosco, vidro líquido), `Paleta`, `Mexer` (animações), a aba Aparência |
| `Sources/BarometerKit/BarraDeMenus/` | O desenho do ícone da barra (`Icone`) |
| `Sources/BarometerKit/Idioma/` | `t()`, `Idioma`, `Traducao` (en, pt, es) |
| `Tests/BarometerKitTests/` | Swift Testing |
| `provas/provar-encerrar.py` | A prova mais importante: sobe processos de verdade e confere quem o × mata |
| `scripts/` | Fotos e GIF do README, servidores de exemplo, montar o app e a versão para baixar (`scripts/README.md`) |
| `docs/icon/` | Ícone e banner, desenhados em código |

Princípios:
- **O painel só desenha; a `Barra` lê e age.** View não chama sistema. Lógica que dá para testar sai da view e da
  `Barra` para um tipo puro (`NaTela`, `EixoDoTempo`, `Sonda.portas(daSaidaDoLsof:)`, `Maquina.agrupar`).
- **Uma peça por arquivo** (ou com a irmã mais próxima). Nenhum arquivo passa de 450 linhas (verificador).
- **Reaproveitar peça existente** (`Interruptor`, `Escolha`, `Regua`, `Dica`, `Linha`, `Secao`) antes de criar.
  Nada de controle nativo onde o painel tem o seu (o nativo destoa do preto e não sai na foto).
- Toda frase da tela passa pelo `t()` em português e ganha inglês e espanhol em `Traducao.swift` (verificador).

## Comandos

```sh
swift build                    # compilar
bash testar.sh                 # testes (use este, não o `swift test` puro; ver abaixo)
bash testar.sh Portas          # uma suíte
python3 provas/provar-encerrar.py
zsh instalar.sh                # compila em release e instala em ~/Applications (fecha a versão aberta)
bash scripts/versao.sh         # a versão para baixar em dist/ (número no arquivo VERSAO); publicar: scripts/README.md
bash scripts/gif.sh            # refaz os GIFs do README
bash scripts/fotos.sh          # refaz as fotos por aba e os banners
```

- **CI:** `.github/workflows/ci.yml`, máquina `macos-26` (chip da Apple, Xcode 26). Roda build, testes, a prova
  do × e o build de release. Depois do push, conferir com `gh run watch`.
- `barometer --retrato x.png [--aba cpu] [--editar] [--idioma en|pt|es] [--fundo vidro] [--paleta neon]
  [--destaque rosa] [--transparencia 60] [--cantos 22] [--mola] [--colorido] [--papel] [--altura 1010]
  [--acender aba:cpu|b:gearshape|p:3000|g:90] [--uma-leitura] [--barra cpu,memoria]` desenha o painel numa imagem.
  É assim que confiro o desenho: o terminal não tem permissão de gravar a tela.
- `barometer --abrir` já abre o painel, para medir memória e CPU com ele aberto (`footprint <pid>`, `heap <pid>`).

## Armadilhas das ferramentas (só Command Line Tools, sem Xcode)

- **`@State` não funciona** (falta o plug-in de macro do SwiftUI). Estado de tela (hover, aba, arrastando) fica no
  `Estado`. `@Observable` existe (as macros de Observation estão lá), mas o projeto usa `ObservableObject`.
- **Swift Testing perde as macros em recompilação incremental** ("plugin for module 'TestingMacros' not found").
  O `testar.sh` apaga só os intermediários dos testes antes de rodar. O alvo de testes fica no modo Swift 6:
  no modo 5, as macros nem carregam. O app e o executável ficam no modo 5 (`swiftLanguageMode(.v5)`).
- `swift test --build-system native` não acha o framework `Testing` nestas ferramentas.
- O linker avisa de pastas que não existem nas Command Line Tools (`search path ... not found`): é do ambiente,
  não do projeto.
- O `ImageRenderer` (fotos) não desenha material do sistema (fosco, vidro líquido) nem `Menu`/`Slider` nativos.
  Na foto, o vidro é imitado desfocando o `PapelDeParede`; na tela é o material de verdade. O README diz isso.
- Ícone de app vem em espaço de cor amplo e clareia a foto: `IconeDoProcesso` redesenha em sRGB.
- zsh não divide variável em palavras: scripts em `bash`.

## Leveza (o app vive ligado o dia inteiro)

Medido em 16/10: com o painel aberto, ~29 MB e estável. Antes do conserto eram 164 MB e subindo.
- **Nunca `.contentTransition(.numericText())`**: o macOS guarda uma imagem nova de cada letra a cada quadro e o
  cache não para de crescer (3.988 blocos em 85 s, contra 73 sem). Verificador em `ArquiteturaTests`.
- **Ler só o que está na tela** (`NaTela`): com o painel aberto, a cada 2 s, só o que a aba mostra. Fechado: a cada
  10 s o básico para o ícone e o gráfico; `lsof` só se as portas estão na barra.
- Um `ps` só para as duas listas de processos (e um por minuto para o "quem mais esquentou"). Fechar o painel solta o desenho (`contentView = nil`).
- Relógios com `tolerance`. Nada de processo novo a cada leitura quando dá para chamar o kernel.
- Mudou algo que roda sempre? Medir antes e depois com `footprint` e `heap` numa cópia com `--abrir`.

## Segurança do × (não regredir)

O × encerra o trabalho inteiro (como Ctrl+C), sobe a árvore de processos e **para no primeiro shell**: terminal,
editor e sessão nunca são alvo. Finder, Dock, a tela e o próprio app não têm ×. Antes de encerrar, confere se o
processo ainda é dono da porta. Mexeu na `Sonda` (`trabalho(de:)`, `sinalizar`)? Rodar
`provas/provar-encerrar.py`. Ela existe porque um `kill -TERM -$PGID` de teste já matou o shell que rodava o teste.

**A prova que travava o CI (17/10):** no caso 2, se a cobaia não subisse, `matar(pai2.pid, filho2 or 0)` virava
`kill(0, SIGKILL)`, que é o grupo de quem chama. No CI esse grupo é o do executor do GitHub: ele morria, a etapa ficava
"em andamento" para sempre (nem o `timeout-minutes` valia, porque quem o aplica tinha morrido) e o push seguinte a
cancelava. Aqui o grupo seria o do terminal. Agora `matar` ignora 0, 1 e negativos, e a prova desiste sozinha em 3
minutos dizendo o último passo. Regra: em teste, nunca `kill` com PID que pode ser 0 ou vazio.
Depois disso apareceram as falhas de verdade, que o travamento escondia: no CI (Python 3.15) a cobaia do caso 2 dava
"Address already in use" com a sobra do caso 1, e o `http.server` não subia nos casos 2 e 3. Agora cada caso tem a
sua porta (3399, 3398, 3397), espera a porta liberar e usa uma cobaia própria de poucas linhas (abre a porta e
espera), igual em qualquer Python. CI verde desde `3abcfab`.

## Verificadores (`Tests/BarometerKitTests/ArquiteturaTests.swift`)

Cada um trava um erro que já aconteceu: arquivo acima de 450 linhas, `numericText`, `UserDefaults.standard` fora do
`Pref`, frase fixa sem tradução, `glassEffect` sem `#available(macOS 26, *)`. `LarguraTests` mede o cartão da CPU nos três idiomas e em cada estado
térmico: linha com `fixedSize` que passa dos 332 pt alarga o painel e corta as duas bordas (18/10, o "esquentando" e o
"encendido hace" empurravam o título "CPU" para fora; agora a linha quebra em duas com `ViewThatFits`). Defeito novo que dá para medir vira
verificador aqui.

## Desenho

- Painel preto por padrão, 360 pt de largura, cantos 14, cartões `Tinta.cartao` com borda `Tinta.borda`.
- Cores das leituras vêm da paleta (`Tinta.cpu`, `.memoria`…); o vermelho do calor é fixo (é aviso).
- Interruptores e seleção usam `Tinta.destaque`.
- O macOS não mostra a dica nativa (`.help`) de um app de barra que não está ativo: o nome dos ícones aparece pelo
  balão `Dica`, ao passar o mouse.
- Nada de texto cortado com reticências nem repetido (em 16/10: "Barras de CPU e R…" virou "CPU + RAM"; as horas
  "13:55 13:55" do gráfico viraram `EixoDoTempo`).
- Conferir toda mudança visual por `--retrato`, nos três idiomas quando muda texto, e com vidro quando mexe em fundo.

## Decisões do Gabriel sobre aparência (16/10)

- **Estilo não mexe no modo.** Claro, escuro e automático só mudam pelos botões de modo; estilos são cores e fundo.
  Estilo que era só modo ("Papel", "Junto com o Mac") saiu. Verificador em `AparenciaTests` ("Estilo não mexe no modo").
- Tem que existir o caminho sem vidro e sem brilho ("cores chapadas") e o de ícones coloridos em tudo.
- **Sólido é sempre fechado (17/10).** Com transparência e sem desfoque, o que estava atrás embaralhava o texto. No
  sólido a régua some e fica a frase "Para ver o que está atrás, escolha Fosco ou Vidro"; transparência guardada de
  versão antiga é ignorada (`coberturaAtual` devolve 1). Verificador em `AparenciaTests`.
- Personalizado: a pessoa escolhe a cor de cada leitura (fileiras de amostras; nada de seletor nativo de cor).
- Ícone das portas: `server.rack` (o triângulo `point.3.connected.trianglepath.dotted` não agradou). Escolhi pela
  recomendação; ele pode trocar.
- Primeira abertura: o painel abre sozinho com as boas-vindas e os estilos.

## Vidro, teclado e avisos (16 e 17/10)

- **Vidro líquido sem tinta.** No macOS 27 a tinta escura no `glassEffect` sai como bloco opaco (relato do cmux
  #5860; o Ghostty recomenda o mesmo). O escurecer da régua é uma camada à parte, por cima, com uma linha de luz na
  borda. Verificador em `ArquiteturaTests` ("Vidro líquido sem tinta").
- **Sem vidro em cada cartão:** vidro não enxerga vidro, e cartão de vidro sobre o fundo de vidro sai borrado (o
  Unified Dev tentou cartões soltos e voltou para um painel só). O vidro fica no fundo e na pílula das abas.
- **Pílula das abas arrastável** (`ArrastoDaPilula`): segue o mouse, estica com a velocidade (até 40%) e gruda na aba
  onde solta. O gesto é `simultaneousGesture`, para o clique nas abas continuar valendo.
- **Atalho global** pelo Carbon (`RegisterEventHotKey`): não pede Acessibilidade. De fábrica ⌃⌥B (o ⌥⌘B é do Chrome).
- **Avisos** (`Vigia`, tipo puro): desligados de fábrica; cada um sai uma vez e rearma com folga. O
  `UNUserNotificationCenter` só é tocado na `Barra` (nos testes não há pacote de app e ele quebraria).
- O terminal não pode gravar a tela, e o `--retrato` não desenha vidro nem gesto: vidro, arrasto, atalho e avisos se
  conferem na mão, no app instalado.
- **Nome nas portas** (`Pref.nomesDasPortas`, chave em texto): o lápis da `Linha` (parâmetro `editar`) ou a engrenagem
  ("Dar nome a uma porta…"). Vale na lista, nas livres, nos avisos, nas sugestões da Limpeza e no copiar.
- **Encerrar os servidores esquecidos de uma vez** (`confirmarEncerrarServidores`, em `Barra+Portas`): lê o trabalho
  de cada um antes de perguntar (a caixa diz quantos processos vão) e chama o mesmo `encerrar` do ×, um por vez na fila
  da sonda. Não mexe na `Sonda`, então a prova do × não precisou rodar.
- **Mouse no gráfico** (`estado.sobreGrafico`): a hora e o valor no lugar do período, com linha e ponto. Só muda o
  `Estado` quando muda de ponto (cada mudança redesenha o painel). Na foto: `--acender g:90` (90 min atrás).
- **Eixo do tempo sem hora cortada:** marca nos 12% de cada ponta fica de fora (`EixoDoTempo.margem`); com 7% o
  "12:00" ainda saía "1…".
- **Quem mais esquentou** (`QuemEsquentou`, tipo puro; cartão na aba CPU e opcional no Geral): um `ps -axo
  time=,rss=,pid=,comm=` por minuto, também com o painel fechado (único processo novo fixo do app fechado). A diferença
  do tempo de CPU acumulado entre duas leituras é o gasto do minuto; pid novo conta tudo, pid reaproveitado por outro
  programa não vira negativo. Guarda os 12 maiores de cada minuto por 6 h. Tempo curto na coluna ("40 s", "2 h 5 min"):
  "menos de 1 min" saía cortado.
- **× de app que roda dentro de outro (17/10):** o Docker abre `Docker.app/Contents/MacOS/Docker Desktop.app`. A linha
  junta pelo `.app` de fora, e o fechar só comparava caminho igual: achava 0 apps e não fazia nada, calado. Agora vale
  o app de dentro (`Maquina.pertence`), e se não houver app aberto nenhum o × encerra o processo maior da linha.
- **Testes de preferência apagam o próprio arquivo** (`PrefTests.comArmazemNovo`): o `removePersistentDomain` deixava
  o plist em `~/Library/Preferences` (108 acumulados até 17/10; foram para a Lixeira).
- **Fotos do README só com os exemplos** (17/10): `scripts/comum.sh` sobe os exemplos nas portas 4000 e 5173, para se
  alguma estiver ocupada e desliga só os PIDs que subiu (antes desligava pela porta e mataria o que fosse de outra
  pessoa na 3000). Com `BAROMETER_FOTO_PORTAS`, o `--retrato` mostra só essas portas e nenhum projeto de verdade ao
  lado dos processos: as fotos são públicas.
- O período do "quem mais esquentou" é o tempo medido entre as leituras, não "leituras × 60 s" (a foto, com 2 s,
  dizia "últimos 2 min").
- O Gabriel escolheu, da lista de melhorias de 17/10, o arrastar, o atalho, o teclado e os avisos. O resto da lista
  (buscar digitando, fixar o painel, ícone que muda de cor, histórico de quem esquentou, botão direito no processo,
  nome nas portas, fechar servidores de uma vez, mouse no gráfico, período do gráfico, intervalo ajustável, copiar
  foto, última aba, acessibilidade) fica para quando ele pedir.

## Versões publicadas

- **v1.0.0 (17/10):** https://github.com/GabrielTeles845/barometer/releases/tag/v1.0.0. Assinatura local (ad hoc):
  o macOS bloqueia na primeira abertura e o README ensina o "Abrir Mesmo Assim". Para notarizar seria preciso a conta
  paga de desenvolvedor da Apple (US$ 99 por ano), que é decisão do Gabriel.

## Ainda por fazer

- A lista de 20 melhorias de 16/10 não ficou registrada; a de 17/10 está na seção acima.
