import AppKit
import Combine
import IOKit
import ServiceManagement
import SwiftUI

/// Roda o `lsof` e monta a lista. Vive numa fila própria e guarda o que é caro
/// de descobrir: a pasta e a linha de comando de um PID não mudam enquanto ele
/// vive, e perguntar de novo a cada três segundos seria um `lsof` por processo
/// por ciclo, à toa.
final class Sonda {
    private var pastaDe: [Int32: String] = [:]
    private var detalheDe: [Int32: String] = [:]
    private var containerDe: [Int: (nome: String, imagem: String, projeto: String)] = [:]
    private var containersEm = Date.distantPast

    /// Processos que ouvem porta e nunca são o que você procura. Sem esta lista
    /// o menu abre com o AirPlay e o Handoff da Apple na frente do seu servidor
    /// — na 5000 e na 7000, que por azar são portas de aparência muito "dev".
    private static let ruido: Set<String> = [
        "rapportd", "ControlCenter", "sharingd", "AirPlayXPCHelper", "remoted",
        "identityservicesd", "launchd", "mDNSResponder", "netbiosd", "sshd",
        "cupsd", "Spotify", "Dropbox", "Google Chrome", "Music", "TV",
        "AppleSpell", "distnoted", "coreaudiod", "ScreenSharing",
    ]

    /// O helper do VS Code abre porta em número alto e com nome que varia
    /// ("Code Helper", "Code Helper (Plugin)"); o prefixo pega todos.
    private static let ruidoPorPrefixo = ["Code Helper", "Electron Helper",
                                          "Chrome Helper", "com.apple."]

    /// O que é cada processo de sistema, em português, para o aviso de ocultas
    /// dizer "5000 AirPlay" em vez de só "5000".
    static func nomeDeSistema(_ comando: String) -> String { t(nomeDeSistemaEmPortugues(comando)) }

    private static func nomeDeSistemaEmPortugues(_ comando: String) -> String {
        let nomes: [String: String] = [
            "ControlCenter": "AirPlay", "rapportd": "Handoff", "sharingd": "Compartilhamento",
            "AirPlayXPCHelper": "AirPlay", "remoted": "Mac remoto", "launchd": "macOS",
            "mDNSResponder": "Bonjour", "sshd": "SSH", "cupsd": "Impressão", "Spotify": "Spotify",
            "Dropbox": "Dropbox", "Google Chrome": "Chrome", "ScreenSharing": "Compartilhar tela",
        ]
        if let n = nomes[comando] { return n }
        if comando.hasPrefix("Code Helper") { return "VS Code" }
        if comando.hasPrefix("Chrome Helper") { return "Chrome" }
        if comando.hasPrefix("com.apple.") { return "macOS" }
        return comando
    }

    private static func ehRuido(_ comando: String) -> Bool {
        if ruido.contains(comando) { return true }
        return ruidoPorPrefixo.contains { comando.hasPrefix($0) }
    }

    /// A regra de "faixa de dev", em uma linha: **porta abaixo de 10000 e
    /// processo que não é ruído.** Foi escolhida assim, e não como uma lista de
    /// intervalos, porque lista de intervalo sempre esquece a porta esquisita que
    /// você usou naquele dia — e porque acima de 10000 mora só porta efêmera,
    /// que o sistema sorteia e ninguém digita no navegador.
    private static func interessa(_ p: Porta) -> Bool {
        !ehRuido(p.comando) && p.numero < 10000
    }

    /// Devolve o que mostrar **e** o que foi escondido. A segunda metade não
    /// existia, e a falta dela fazia o menu parecer errado: quem sabe que tem
    /// coisa na 5000 e não a vê no menu conclui que o app não está vendo, e não
    /// que ele escolheu não mostrar. Filtro invisível é o app mentindo por
    /// omissão.
    func varrer(tudo: Bool) -> (lista: [Porta], ocultas: [(numero: Int, nome: String)]) {
        guard let lsof = Ferramenta.lsof else { return ([], []) }
        let saida = rodar(lsof, ["-nP", "+c", "0", "-iTCP", "-sTCP:LISTEN"])

        var achadas: [Int: Porta] = [:]   // por número: IPv4 e IPv6 são a mesma porta
        for linha in saida.split(separator: "\n") {
            guard let p = interpretar(String(linha)) else { continue }
            // `*:3000` e `127.0.0.1:3000` do mesmo processo são uma porta só.
            // Fica a de escopo mais largo, que é a que realmente responde.
            if let antes = achadas[p.numero], antes.endereco == "*" { continue }
            achadas[p.numero] = p
        }

        var lista = Array(achadas.values)
        var ocultas: [(numero: Int, nome: String)] = []
        if !tudo {
            // As escondidas não são enriquecidas (um `ps` por porta de sistema
            // seria gasto puro), mas levam o nome: só o número não dizia nada.
            ocultas = lista.filter { !Sonda.interessa($0) }
                .map { (numero: $0.numero, nome: Sonda.nomeDeSistema($0.comando)) }
                .sorted { $0.numero < $1.numero }
            lista = lista.filter(Sonda.interessa)
        }

        let doDocker = lista.filter { Porta.ehDocker($0.comando) }
        if !doDocker.isEmpty {
            // Container que acabou de subir não estava no mapa de 20 s atrás: sem
            // isto ele aparecia como "docker" e o × recusava parar.
            let faltando = doDocker.contains { containerDe[$0.numero] == nil }
            atualizarContainers(forcar: faltando)
        }
        for i in lista.indices {
            enriquecer(&lista[i])
        }
        // Descartar o PID que morreu entre o `lsof` e o `ps` — acontece, e uma
        // linha sem nome nenhum no menu é pior que linha nenhuma.
        lista.removeAll { $0.detalhe.isEmpty && $0.comando.isEmpty }
        return (lista.sorted { $0.numero < $1.numero }, ocultas)
    }

    /// Uma linha do `lsof` em modo normal. Colunas: COMMAND PID USER FD TYPE
    /// DEVICE SIZE/OFF NODE NAME (LISTEN). Cortar por espaço é seguro porque o
    /// `lsof` escapa o espaço do nome do processo como `\x20` — "Code Helper"
    /// chega como um único pedaço.
    private func interpretar(_ linha: String) -> Porta? {
        guard linha.hasSuffix("(LISTEN)") else { return nil }
        let campos = linha.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard campos.count >= 10, let pid = Int32(campos[1]) else { return nil }

        // O endereço é o penúltimo campo, antes do "(LISTEN)": `*:3000`,
        // `127.0.0.1:18090`, `[::1]:6379`. A porta é o que vem depois do
        // ÚLTIMO dois-pontos — endereço IPv6 tem vários pelo caminho.
        let alvo = campos[campos.count - 2]
        guard let corte = alvo.lastIndex(of: ":"),
              let numero = Int(alvo[alvo.index(after: corte)...]) else { return nil }
        var endereco = String(alvo[..<corte])
        if endereco.hasPrefix("[") { endereco = String(endereco.dropFirst().dropLast()) }

        let comando = campos[0].replacingOccurrences(of: "\\x20", with: " ")
        return Porta(numero: numero, pid: pid, comando: comando, endereco: endereco)
    }

    /// Completa o que o `lsof` não conta: a linha de comando, a pasta e, se for
    /// Docker, de qual container aquela porta é.
    private func enriquecer(_ p: inout Porta) {
        if Porta.ehDocker(p.comando), let c = containerDe[p.numero] {
            p.container = c.nome
            p.composto = c.projeto
            // `postgres:17-alpine` → `postgres`. O resto é versão, e versão não
            // ajuda a reconhecer o que é aquilo.
            p.detalhe = c.imagem.split(separator: ":").first.map(String.init) ?? c.imagem
            return
        }

        if let pronto = detalheDe[p.pid] {
            p.detalhe = pronto
        } else if let ps = Ferramenta.ps {
            let bruto = rodar(ps, ["-p", String(p.pid), "-o", "command="])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let curto = resumir(bruto, nomeDoProcesso: p.comando)
            detalheDe[p.pid] = curto
            p.detalhe = curto
        }

        if let pronta = pastaDe[p.pid] {
            p.pasta = pronta
        } else if let lsof = Ferramenta.lsof {
            // `-Fn` devolve `pPID`, `fcwd`, `n/caminho` — uma linha cada.
            let saida = rodar(lsof, ["-a", "-p", String(p.pid), "-d", "cwd", "-Fn"])
            if let n = saida.split(separator: "\n").last(where: { $0.hasPrefix("n") }) {
                let caminho = String(n.dropFirst())
                pastaDe[p.pid] = caminho
                p.pasta = caminho
            }
        }
        if let pasta = p.pasta { p.projeto = projeto(de: pasta) }
    }

    private var projetoDe: [String: String] = [:]

    /// A pasta de trabalho de um PID (com o mesmo guardado da varredura).
    func pastaDoProcesso(_ pid: Int32) -> String? {
        if let pronta = pastaDe[pid] { return pronta }
        guard let lsof = Ferramenta.lsof else { return nil }
        let saida = rodar(lsof, ["-a", "-p", String(pid), "-d", "cwd", "-Fn"])
        guard let n = saida.split(separator: "\n").last(where: { $0.hasPrefix("n") }) else { return nil }
        let caminho = String(n.dropFirst())
        pastaDe[pid] = caminho
        return caminho
    }

    /// Sobe da pasta até achar a raiz do projeto: o `name` do package.json, ou o
    /// nome da pasta que tem `.git`, `Cargo.toml`, `go.mod` ou `pyproject.toml`.
    /// Para no diretório pessoal: acima dele não há projeto de ninguém.
    func projeto(de pasta: String) -> String? {
        if let pronto = projetoDe[pasta] { return pronto.isEmpty ? nil : pronto }
        let fm = FileManager.default
        let casa = NSHomeDirectory()
        var atual = pasta
        var achado = ""
        while atual.count > 1, atual != casa, atual.hasPrefix(casa) || atual == pasta {
            let pacote = (atual as NSString).appendingPathComponent("package.json")
            if let dados = fm.contents(atPath: pacote),
               let json = try? JSONSerialization.jsonObject(with: dados) as? [String: Any],
               let nome = json["name"] as? String, !nome.isEmpty,
               // Pasta de dentro de um monorepo ("apps/web") ainda é melhor que nada,
               // mas o nome genérico de modelo ("my-app", "app") diz pouco: usa a pasta.
               !["app", "my-app", "web", "frontend", "backend", "server", "client"].contains(nome) {
                achado = nome
                break
            }
            if [".git", "Cargo.toml", "go.mod", "pyproject.toml", "package.json"].contains(where: {
                fm.fileExists(atPath: (atual as NSString).appendingPathComponent($0))
            }) {
                achado = (atual as NSString).lastPathComponent
                break
            }
            atual = (atual as NSString).deletingLastPathComponent
        }
        projetoDe[pasta] = achado
        return achado.isEmpty ? nil : achado
    }

    /// Uma linha de comando inteira não cabe no menu e não informa: o que
    /// importa está sempre nas primeiras palavras, e o caminho absoluto do
    /// binário é ruído. `/usr/bin/node /caminho/longo/next start` viraria
    /// `node next start`.
    private func resumir(_ bruto: String, nomeDoProcesso: String) -> String {
        guard !bruto.isEmpty else { return nomeDoProcesso }
        // O Next, o Vite e companhia reescrevem o próprio título do processo
        // para algo já pronto — `next-server (v14.2.24)`. Quando vem assim, não
        // há o que resumir: é a melhor descrição que existe.
        if !bruto.hasPrefix("/") && !bruto.contains(" /") && bruto.count <= 42 { return bruto }

        var partes = bruto.split(separator: " ").map(String.init)
        partes = partes.prefix(3).map { pedaco in
            pedaco.hasPrefix("/") ? (pedaco as NSString).lastPathComponent : pedaco
        }
        let junto = partes.joined(separator: " ")
        return junto.count > 46 ? String(junto.prefix(45)) + "…" : junto
    }

    /// Qual container publica qual porta. Vale por vinte segundos: subir e
    /// descer container é coisa de minuto, e cada consulta é um processo novo.
    private func atualizarContainers(forcar: Bool = false) {
        guard let docker = Ferramenta.docker,
              forcar || Date().timeIntervalSince(containersEm) > 20 else { return }
        containersEm = Date()
        var mapa: [Int: (nome: String, imagem: String, projeto: String)] = [:]
        let saida = rodar(docker, ["ps", "--format",
                                   "{{.Names}}|{{.Image}}|{{.Ports}}|{{.Label \"com.docker.compose.project\"}}"])
        for linha in saida.split(separator: "\n") {
            let c = linha.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard c.count >= 3 else { continue }
            // `0.0.0.0:5433->5432/tcp, [::]:5433->5432/tcp`: a porta da máquina é
            // a que está ANTES da flecha. A de depois é a de dentro do container
            // e não existe aqui fora.
            for trecho in c[2].split(separator: ",") {
                guard let flecha = trecho.range(of: "->") else { continue }
                let hospede = trecho[..<flecha.lowerBound]
                guard let corte = hospede.lastIndex(of: ":"),
                      let n = Int(hospede[hospede.index(after: corte)...]) else { continue }
                mapa[n] = (nome: c[0], imagem: c[1], projeto: c.count > 3 ? c[3] : "")
            }
        }
        containerDe = mapa
    }


    // MARK: O trabalho por trás da porta

    /// Interpretadores de comando. A subida da árvore **para** no primeiro
    /// deles, e nenhum grupo liderado por um deles é morto.
    ///
    /// Esta é a regra que impede o desastre. Num terminal de verdade o trabalho
    /// em primeiro plano tem grupo próprio, e o shell fica no grupo dele — então
    /// líder de grupo nunca é o shell, e recusar esse caso não custa nada. Mas
    /// quando o job control está desligado (script, sessão não interativa) o
    /// grupo é o DO SHELL, e mandar sinal para ele derruba o terminal inteiro.
    /// Aconteceu enquanto isto era escrito: um `kill -TERM -$PGID` de teste
    /// matou o próprio shell que rodava o teste.
    private static let conchas: Set<String> = [
        "zsh", "bash", "sh", "dash", "fish", "ksh", "csh", "tcsh",
    ]

    /// O que nunca se mata: o sistema, o terminal, o editor, a sessão remota.
    private static let barreiras: Set<String> = [
        "launchd", "login", "sshd", "tmux", "screen", "sudo", "su", "init",
        "Terminal", "iTerm2", "ghostty", "Warp", "WarpTerminal", "kitty",
        "Hyper", "alacritty", "Electron", "Code", "claude",
    ]

    private static func ehConcha(_ e: Elo) -> Bool {
        // Shell de login chega como `-zsh`: o traço é a marca, e sem esta linha
        // ele não casa com nenhum nome da lista.
        conchas.contains(e.nome) || (e.nome.hasPrefix("-")
                                     && conchas.contains(String(e.nome.dropFirst())))
    }

    private static func ehBarreira(_ e: Elo) -> Bool {
        if e.pid <= 1 { return true }
        if barreiras.contains(e.nome) { return true }
        return ["Code Helper", "iTerm", "Terminal", "Visual Studio Code"]
            .contains { e.nome.hasPrefix($0) }
    }

    /// Todos os processos, numa chamada só. Subir a árvore com um `ps` por elo
    /// custaria um processo novo por nível, e isto roda no clique.
    private func tabela() -> [Int32: Elo] {
        guard let ps = Ferramenta.ps else { return [:] }
        var t: [Int32: Elo] = [:]
        for linha in rodar(ps, ["-axo", "pid=,ppid=,pgid=,command="]).split(separator: "\n") {
            let campos = linha.split(separator: " ", omittingEmptySubsequences: true)
            guard campos.count >= 4, let pid = Int32(campos[0]),
                  let ppid = Int32(campos[1]), let pgid = Int32(campos[2]) else { continue }
            t[pid] = Elo(pid: pid, ppid: ppid, pgid: pgid,
                         comando: campos.dropFirst(3).joined(separator: " "))
        }
        return t
    }

    /// De que trabalho aquele processo faz parte, e como encerrá-lo.
    ///
    /// Duas saídas, e a ordem importa:
    ///
    ///  1. **pelo grupo**, quando o líder do grupo é um antepassado (ou ele
    ///     mesmo) e não é shell nem barreira. É o caso do `npm run dev` num
    ///     terminal: o líder é o `npm`, e o grupo tem o `npm`, o `next dev` e o
    ///     `next-server`. Sinal para o grupo é o Ctrl+C.
    ///  2. **um a um**, subindo de quem ouve até o primeiro shell. É o que
    ///     sobra quando o grupo não serve, e é de propósito mais conservador:
    ///     mata de menos em vez de matar o terminal.
    func trabalho(de pid: Int32) -> (plano: Plano, membros: [Elo])? {
        let t = tabela()
        guard let quemOuve = t[pid] else { return nil }

        /* A subida para no primeiro shell ou barreira — mas se ela chegar a
           NÓS, algo está muito errado na leitura da árvore, e o certo é não
           matar nada além de quem ouve. Um app que se mata a meio caminho de
           matar outra coisa deixa o trabalho pela metade e sem quem conte o que
           aconteceu. */
        let eu = ProcessInfo.processInfo.processIdentifier
        var meusAntepassados: Set<Int32> = [eu]
        var subindo = t[eu]
        while let e = subindo, e.pid > 1 {
            meusAntepassados.insert(e.pid)
            subindo = t[e.ppid]
        }

        var linhagem = [quemOuve]
        var atual = quemOuve
        while let pai = t[atual.ppid], !Sonda.ehConcha(pai), !Sonda.ehBarreira(pai),
              !meusAntepassados.contains(pai.pid) {
            linhagem.append(pai)
            atual = pai
        }

        if let lider = t[quemOuve.pgid],
           linhagem.contains(where: { $0.pid == lider.pid }),
           !Sonda.ehConcha(lider), !Sonda.ehBarreira(lider),
           !meusAntepassados.contains(lider.pid),
           // E nenhum membro do grupo pode ser nós ou quem nos sustenta: o
           // grupo é grande, e basta um intruso para o sinal voltar contra o
           // próprio app.
           !t.values.contains(where: { $0.pgid == lider.pgid
                                       && meusAntepassados.contains($0.pid) }) {
            let membros = t.values.filter { $0.pgid == lider.pgid }.sorted { $0.pid < $1.pid }
            return (.grupo(lider.pgid), membros)
        }
        return (.processos, linhagem)
    }


    /// Manda o sinal para o trabalho. Mora aqui, e não na tela, porque é a
    /// parte que a prova precisa executar de verdade: teste que reimplementa o
    /// `kill` não prova o `kill` do botão — prova o do teste.
    /// Devolve se algum sinal foi recusado por permissão (EPERM): processo de
    /// outro usuário, como o root. Antes o retorno do `kill` era ignorado e o ×
    /// parecia não fazer nada.
    @discardableResult
    func sinalizar(_ plano: Plano, _ membros: [Elo], _ sinal: Int32) -> Bool {
        var semPermissao = false
        switch plano {
        case .grupo(let pgid):
            // O menos na frente do PID é o que faz o sinal ir para o GRUPO.
            // Toda a segurança disso está em `trabalho(de:)`, que só devolve
            // `.grupo` quando o líder não é shell, nem barreira, nem nós.
            if kill(-pgid, sinal) != 0 && errno == EPERM { semPermissao = true }
        case .processos:
            /* De fora para dentro, e não o contrário: matar o filho primeiro dá
               ao supervisor a chance de subir outro antes de ele mesmo morrer —
               foi assim que a porta voltou com PID novo, 300ms depois, no teste
               que revelou este bug. */
            for e in membros.reversed() where kill(e.pid, sinal) != 0 && errno == EPERM {
                semPermissao = true
            }
        }
        return semPermissao
    }

    /// Quem ouve a porta agora (depois de encerrar): o PID e o comando do pai,
    /// para dizer quem a subiu de novo.
    func donoAgora(_ porta: Int) -> (pid: Int32, pai: String)? {
        guard let lsof = Ferramenta.lsof else { return nil }
        let saida = rodar(lsof, ["-nP", "-t", "-iTCP:\(porta)", "-sTCP:LISTEN"])
        guard let pid = saida.split(separator: "\n").first.flatMap({ Int32($0) }) else { return nil }
        let t = tabela()
        let pai = t[pid].flatMap { t[$0.ppid] }
        return (pid, pai?.nome ?? "")
    }

    /// Confere, no instante do clique, se aquele PID ainda é o dono daquela
    /// porta. PID guardado envelhece: o processo morre, o sistema reaproveita o
    /// número, e um clique em lista velha mataria um estranho.
    func aindaDono(pid: Int32, porta: Int) -> Bool {
        guard let lsof = Ferramenta.lsof else { return false }
        let saida = rodar(lsof, ["-nP", "-p", String(pid), "-iTCP:\(porta)", "-sTCP:LISTEN"])
        return saida.contains("LISTEN")
    }

    func ocupada(_ porta: Int) -> Bool {
        guard let lsof = Ferramenta.lsof else { return false }
        return rodar(lsof, ["-nP", "-iTCP:\(porta)", "-sTCP:LISTEN"]).contains("LISTEN")
    }

    /// Devolve se o container parou. Antes a saída era descartada e uma falha
    /// (Docker fechado, container que não existe mais) passava calada.
    func parar(container: String) -> Bool {
        guard let docker = Ferramenta.docker else { return false }
        _ = rodar(docker, ["stop", container])
        let ainda = rodar(docker, ["ps", "-q", "--filter", "name=^\(container)$"])
        return ainda.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @discardableResult
    private func rodar(_ exe: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        let cano = Pipe()
        p.standardOutput = cano
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        // Ler ANTES de esperar. Esperar primeiro com o cano cheio travaria o
        // filho na escrita e nós na espera, para sempre — o clássico.
        let dados = cano.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: dados, encoding: .utf8) ?? ""
    }
}
