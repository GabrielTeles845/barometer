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
| `Sources/BarometerKit/App/` | A `Barra` (o delegate), dividida em extensões por tarefa: `+Leituras`, `+Icone`, `+Painel`, `+Retrato`, `+Limpeza`, `+Ajustes`, `+Acoes` |
| `Sources/BarometerKit/Leitores/` | Leituras do sistema: `Maquina` (memória, CPU, `ps`), `CPU` (IOReport), `GPU`, `Disco`, `Bateria`, `Historico`, `Limpeza`, `SobreEsteMac`, `Medida` |
| `Sources/BarometerKit/Portas/` | `Sonda` (o `lsof`, o projeto de cada porta, quem o × encerra), `Porta`, `Elo`, `Plano` |
| `Sources/BarometerKit/Sistema/` | `Sensores` (HID), `Ferramenta` (caminho do lsof/ps), `Diario` (log), `Login` (LaunchAgent), `Pref` |
| `Sources/BarometerKit/Painel/` | O painel em SwiftUI: `Estado`, `Painel`, `BarraDeAbas`, `EditorDoGeral`, `NaTela`, `Tinta`; `Cartoes/` (um cartão por arquivo) e `Pecas/` (peças reaproveitadas: `Interruptor`, `Escolha`, `Regua`, `Dica`, `Botaozinho`, `Linha`…) |
| `Sources/BarometerKit/Aparencia/` | Fundo (sólido, fosco, vidro líquido), `Paleta`, `Mexer` (animações), a aba Aparência |
| `Sources/BarometerKit/BarraDeMenus/` | O desenho do ícone da barra (`Icone`) |
| `Sources/BarometerKit/Idioma/` | `t()`, `Idioma`, `Traducao` (en, pt, es) |
| `Tests/BarometerKitTests/` | Swift Testing |
| `provas/provar-encerrar.py` | A prova mais importante: sobe processos de verdade e confere quem o × mata |
| `scripts/` | Fotos e GIF do README, servidores de exemplo (`scripts/README.md`) |
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
bash scripts/gif.sh            # refaz os GIFs do README
bash scripts/fotos.sh          # refaz as fotos por aba e os banners
```

- **CI:** `.github/workflows/ci.yml`, máquina `macos-26` (chip da Apple, Xcode 26). Roda build, testes, a prova
  do × e o build de release. Depois do push, conferir com `gh run watch`.
- `barometer --retrato x.png [--aba cpu] [--editar] [--idioma en|pt|es] [--fundo vidro] [--paleta neon]
  [--destaque rosa] [--transparencia 60] [--cantos 22] [--mola] [--colorido] [--papel] [--altura 1010]
  [--acender aba:cpu|b:gearshape|p:3000] [--uma-leitura] [--barra cpu,memoria]` desenha o painel numa imagem.
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
- Um `ps` só para as duas listas de processos. Fechar o painel solta o desenho (`contentView = nil`).
- Relógios com `tolerance`. Nada de processo novo a cada leitura quando dá para chamar o kernel.
- Mudou algo que roda sempre? Medir antes e depois com `footprint` e `heap` numa cópia com `--abrir`.

## Segurança do × (não regredir)

O × encerra o trabalho inteiro (como Ctrl+C), sobe a árvore de processos e **para no primeiro shell**: terminal,
editor e sessão nunca são alvo. Finder, Dock, a tela e o próprio app não têm ×. Antes de encerrar, confere se o
processo ainda é dono da porta. Mexeu na `Sonda` (`trabalho(de:)`, `sinalizar`)? Rodar
`provas/provar-encerrar.py`. Ela existe porque um `kill -TERM -$PGID` de teste já matou o shell que rodava o teste.

## Verificadores (`Tests/BarometerKitTests/ArquiteturaTests.swift`)

Cada um trava um erro que já aconteceu: arquivo acima de 450 linhas, `numericText`, `UserDefaults.standard` fora do
`Pref`, frase fixa sem tradução, `glassEffect` sem `#available(macOS 26, *)`. Defeito novo que dá para medir vira
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

## Ainda por fazer (pedidos do Gabriel em 16/10)

- Escolher o ícone das portas (o triângulo `point.3.connected.trianglepath.dotted` não agradou). Opções em
  `revisao/`; recomendei `server.rack`.
- Estilos prontos para escolher logo na primeira abertura, e modo claro além do escuro.
- Sugerir o que limpar ou fechar (app aberto e parado há tempo, por exemplo).
- Uma lista de 20 melhorias para ele escolher.
