// Barometer — o Mac em tempo real, na barra de menus: memória, CPU, GPU, disco, bateria, temperatura,
// o que mais gasta e o que está ouvindo nas portas.
//
// Nada de estimativa aqui: cada número vem de onde o próprio macOS lê. As portas,
// do `lsof` (a tabela de sockets do kernel); memória e CPU, de chamadas diretas
// ao kernel; temperatura, GPU, disco e bateria, do IORegistry; a frequência da
// CPU, do IOReport. Este arquivo lê e age; o painel (painel.swift) só desenha.

import AppKit
import IOKit
import SwiftUI
import Combine
import ServiceManagement

// MARK: - Sensores de temperatura

/* Nos Macs com chip da Apple, a temperatura não está no SMC antigo: os sensores
   aparecem como serviços HID do fabricante (página 0xff00, uso 5). As funções
   abaixo existem no IOKit, mas não estão nos cabeçalhos públicos; são as mesmas
   que o Stats e o Monitor de Atividade usam. Conferido num M3 Pro em 16/10/2026:
   "PMU tdie1…10" (os núcleos do chip), "PMU tdev1…8" (outras partes da placa),
   "NAND CH0 temp" (SSD) e "gas gauge battery" (bateria). */
@_silgen_name("IOHIDEventSystemClientCreate") private func IOHIDEventSystemClientCreate(_ a: CFAllocator?) -> Unmanaged<AnyObject>?
@_silgen_name("IOHIDEventSystemClientSetMatching") private func IOHIDEventSystemClientSetMatching(_ c: AnyObject, _ m: CFDictionary) -> Int32
@_silgen_name("IOHIDEventSystemClientCopyServices") private func IOHIDEventSystemClientCopyServices(_ c: AnyObject) -> Unmanaged<CFArray>?
@_silgen_name("IOHIDServiceClientCopyProperty") private func IOHIDServiceClientCopyProperty(_ s: AnyObject, _ k: CFString) -> Unmanaged<AnyObject>?
@_silgen_name("IOHIDServiceClientCopyEvent") private func IOHIDServiceClientCopyEvent(_ s: AnyObject, _ t: Int64, _ o: Int32, _ ts: Int64) -> Unmanaged<AnyObject>?
@_silgen_name("IOHIDEventGetFloatValue") private func IOHIDEventGetFloatValue(_ e: AnyObject, _ f: Int32) -> Double

enum Sensores {
    struct Leitura { let chip: Double?; let chipMaximo: Double?; let ssd: Double?; let bateria: Double? }

    private static let tipoTemperatura: Int64 = 15
    /// O cliente fica vivo enquanto o app vive: os sensores pertencem a ele, e com ele liberado a leitura
    /// usava um objeto já desfeito e o app caía ao abrir (16/10).
    private static let cliente: AnyObject? = IOHIDEventSystemClientCreate(kCFAllocatorDefault)?.takeRetainedValue()
    /// Os serviços (sensores) não mudam com o Mac ligado: lidos uma vez.
    private static let servicos: [(nome: String, servico: AnyObject)] = {
        guard let cliente else { return [] }
        _ = IOHIDEventSystemClientSetMatching(cliente, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
        guard let lista = IOHIDEventSystemClientCopyServices(cliente)?.takeRetainedValue() as? [AnyObject] else { return [] }
        return lista.map { s in
            ((IOHIDServiceClientCopyProperty(s, "Product" as CFString)?.takeRetainedValue() as? String) ?? "", s)
        }
    }()

    static func ler() -> Leitura {
        var chip: [Double] = [], ssd: [Double] = [], bateria: [Double] = []
        for (nome, servico) in servicos {
            guard let evento = IOHIDServiceClientCopyEvent(servico, tipoTemperatura, 0, 0)?.takeRetainedValue() else { continue }
            let graus = IOHIDEventGetFloatValue(evento, Int32(tipoTemperatura << 16))
            // Leitura fora do razoável (sensor desligado devolve 0 ou valores absurdos) fica de fora.
            guard graus > 5, graus < 130 else { continue }
            let n = nome.lowercased()
            if n.contains("tdie") || n.contains("cpu") || n.contains("soc") { chip.append(graus) }
            else if n.contains("nand") || n.contains("ssd") { ssd.append(graus) }
            else if n.contains("battery") { bateria.append(graus) }
        }
        let media = { (v: [Double]) -> Double? in v.isEmpty ? nil : v.reduce(0, +) / Double(v.count) }
        return Leitura(chip: media(chip), chipMaximo: chip.max(), ssd: media(ssd), bateria: media(bateria))
    }
}

// MARK: - Onde ficam as ferramentas

/// Um aplicativo aberto pelo Finder ou pelo login **não herda o seu PATH**: ele
/// recebe `/usr/bin:/bin:/usr/sbin:/sbin` e nada mais. Então nada de chamar por
/// nome — cada ferramenta é procurada nos lugares onde ela realmente mora.
enum Ferramenta {
    static let lsof = achar(["/usr/sbin/lsof", "/usr/bin/lsof"])
    static let ps = achar(["/bin/ps"])
    static let docker = achar(["/usr/local/bin/docker",
                               "/opt/homebrew/bin/docker",
                               NSHomeDirectory() + "/.docker/bin/docker"])

    private static func achar(_ candidatos: [String]) -> String? {
        candidatos.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}


// MARK: - Diário

/// Um registro do que aconteceu, em arquivo, porque menu não se depura.
///
/// Não há como pôr ponto de parada num clique de menu, nem ler stdout de um
/// app de barra, nem fotografar o menu aberto. Sem isto, todo diagnóstico daqui
/// é chute — e chute já custou três correções erradas no realce e uma no ×,
/// que durante dias pareceu ligado e nunca chegou a ser chamado.
enum Diario {
    static let arquivo = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/barometer.log")

    /// Escreve uma linha e mantém o arquivo nas últimas 400 — diário que cresce
    /// sem limite é diário que ninguém abre.
    static func anotar(_ texto: String) {
        let quando = ISO8601DateFormatter().string(from: Date())
        let linha = "\(quando)  \(texto)"
        DispatchQueue.global(qos: .utility).async {
            var linhas = (try? String(contentsOf: arquivo, encoding: .utf8))?
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init) ?? []
            linhas.append(linha)
            if linhas.count > 400 { linhas = Array(linhas.suffix(400)) }
            try? FileManager.default.createDirectory(
                at: arquivo.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? linhas.joined(separator: "\n").write(to: arquivo, atomically: true,
                                                      encoding: .utf8)
        }
    }
}

// MARK: - Uma porta ouvindo

struct Porta {
    let numero: Int
    let pid: Int32
    /// Como o `lsof` chama o processo, com `+c 0` para vir inteiro em vez de
    /// truncado em nove letras ("com.docke", "ControlCe").
    let comando: String
    /// A linha de comando resumida: é onde aparece o que interessa de verdade,
    /// tipo `next-server (v14.2.24)` em vez de só `node`.
    var detalhe: String = ""
    /// A pasta de trabalho do processo — o que responde "de qual projeto é isso".
    var pasta: String?
    /// Nome do container, quando a porta é publicada pelo Docker.
    var container: String?
    /// O projeto: o `name` do package.json, ou a pasta que tem o `.git`, subindo
    /// a partir da pasta de trabalho. "minha-loja-api" diz mais que "src".
    var projeto: String?
    /// O projeto do docker compose (o rótulo `com.docker.compose.project`): é o
    /// que diz que o `postgres` da 5433 é do "minha-loja", e não de outro.
    var composto: String?
    /// `*` (todas as interfaces) ou um endereço específico como `127.0.0.1`.
    let endereco: String

    var doDocker: Bool { container != nil || Porta.ehDocker(comando) }

    static func ehDocker(_ c: String) -> Bool {
        let n = c.lowercased()
        return n.hasPrefix("com.docker") || n.contains("docker") || n.hasPrefix("vpnkit")
    }

    /// O que escrever depois do número. Preferir sempre a informação mais
    /// específica que se conseguiu: container > linha de comando > nome do
    /// processo. `com.docker.backend` não diz nada; `postgres` diz tudo.
    var comoChamar: String {
        if doDocker { return detalhe.isEmpty ? "docker" : detalhe }
        return detalhe.isEmpty ? comando : detalhe
    }

    /// Só faz sentido abrir no navegador o que provavelmente fala HTTP. Abrir
    /// `localhost:5432` no Safari não mostra o Postgres; mostra erro.
    var web: Bool {
        if doDocker && (numero == 5432 || numero == 5433 || numero == 3306
                        || numero == 6379 || numero == 6380 || numero == 27017) { return false }
        switch numero {
        case 5432, 5433, 3306, 6379, 6380, 27017, 11211, 9200, 5672: return false
        default: return true
        }
    }

    /// Endereço curto para a segunda linha: a pasta, quando existe, é o que
    /// identifica o projeto; senão o container; senão nada.
    var contexto: String? {
        if let c = container {
            // "minha-loja · minha-loja-postgres" repete; o nome do container já diz o projeto.
            if let k = composto, !k.isEmpty, !c.lowercased().hasPrefix(k.lowercased()) { return "\(k) · \(c)" }
            return c
        }
        if let p = projeto, !p.isEmpty { return p }
        if let p = pasta, !p.isEmpty { return (p as NSString).lastPathComponent }
        return nil
    }

    /// Uma linha só, para onde não cabe a segunda linha (favoritas, dica da barra).
    var resumo: String {
        if let c = contexto, c != comoChamar { return "\(comoChamar) · \(c)" }
        return comoChamar
    }
}


// MARK: - O trabalho por trás da porta

/// Um processo, para subir a árvore e descobrir de que **trabalho** ele faz
/// parte.
///
/// Existe porque matar quem ouve a porta muitas vezes não resolve nada: num
/// `npm run dev`, quem ouve é um neto. O pai o ressuscita em menos de um
/// segundo e o terminal nunca volta ao prompt — medido, a porta voltava com
/// PID novo em 300ms.
struct Elo {
    let pid: Int32
    let ppid: Int32
    let pgid: Int32
    let comando: String

    /// O executável, sem caminho e sem argumentos.
    var nome: String {
        let primeiro = comando.split(separator: " ").first.map(String.init) ?? comando
        return (primeiro as NSString).lastPathComponent
    }

    /// Cabe numa linha da caixa de confirmação.
    var resumo: String {
        let limpo = comando.split(separator: " ").map { pedaco -> String in
            pedaco.hasPrefix("/") ? (pedaco as NSString).lastPathComponent : String(pedaco)
        }.joined(separator: " ")
        return limpo.count > 56 ? String(limpo.prefix(55)) + "\u{2026}" : limpo
    }
}

/// Como encerrar.
enum Plano {
    /// O trabalho tem grupo de processos próprio, e mandar sinal para o grupo
    /// é **exatamente** o que o Ctrl+C no terminal faz. É o caminho bom.
    case grupo(Int32)
    /// Sem grupo confiável: um a um, do mais de fora para o mais de dentro.
    case processos
}

// MARK: - A varredura

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

// MARK: - O que se pode ligar e desligar

/// O LaunchAgent que abre o app ao entrar na conta. `open -a` e não o binário
/// direto: assim o macOS abre o app como app (uma instância só), e o caminho
/// continua certo depois de reinstalar por cima.
enum Login {
    static let arquivo = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/com.gabrielteles.barometer.plist")
    static var ligado: Bool { FileManager.default.fileExists(atPath: arquivo.path) }

    static func ligar() throws {
        let plist: [String: Any] = [
            "Label": "com.gabrielteles.barometer",
            "ProgramArguments": ["/usr/bin/open", "-a", Bundle.main.bundlePath],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
        ]
        let dados = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: arquivo.deletingLastPathComponent(), withIntermediateDirectories: true)
        try dados.write(to: arquivo)
    }

    static func desligar() throws {
        if ligado { try FileManager.default.removeItem(at: arquivo) }
    }
}

enum Pref {
    /// Fundo, cores e animações do painel (aba Aparência).
    static var aparencia: Aparencia {
        get {
            guard let dados = UserDefaults.standard.data(forKey: "aparencia"),
                  let a = try? JSONDecoder().decode(Aparencia.self, from: dados) else { return Aparencia() }
            return a
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "aparencia") }
    }

    /// Os cartões do Geral. Junta com o padrão: cartão novo de uma versão nova aparece no fim, desligado.
    static var geral: [ItemGeral] {
        get {
            guard let dados = UserDefaults.standard.data(forKey: "geral"),
                  let salvos = try? JSONDecoder().decode([ItemGeral].self, from: dados) else { return ItemGeral.padrao }
            let conhecidos = salvos.filter { ItemGeral.nomes[$0.id] != nil }
            let novos = ItemGeral.padrao.filter { p in !conhecidos.contains { $0.id == p.id } }.map { ItemGeral(id: $0.id, ligado: false) }
            return conhecidos + novos
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "geral") }
    }

    /// O que aparece na barra de menus. Quem tinha desligado o uso no ícone (versão antiga) começa só com as portas.
    static var naBarra: [ItemDaBarra] {
        get {
            if let dados = UserDefaults.standard.data(forKey: "naBarra"),
               let itens = try? JSONDecoder().decode([ItemDaBarra].self, from: dados) { return Array(itens.prefix(ItemDaBarra.maximo)) }
            return memoriaNaBarra ? ItemDaBarra.padrao : [.portas]
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "naBarra") }
    }

    static var memoriaNaBarra: Bool {
        get { UserDefaults.standard.object(forKey: "memoriaNaBarra") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "memoriaNaBarra") }
    }

    static var tudo: Bool {
        get { UserDefaults.standard.bool(forKey: "mostrarTudo") }
        set { UserDefaults.standard.set(newValue, forKey: "mostrarTudo") }
    }

    /// As portas que você quer ver mesmo quando estão livres — a resposta
    /// direta para "tem coisa na 3000 e na 3006?".
    static var favoritas: [Int] {
        get {
            if UserDefaults.standard.object(forKey: "favoritas") == nil {
                return [3000, 3001, 3006, 5173, 8000]
            }
            return (UserDefaults.standard.array(forKey: "favoritas") as? [Int] ?? []).sorted()
        }
        set { UserDefaults.standard.set(Array(Set(newValue)).sorted(), forKey: "favoritas") }
    }

    static func virarFavorita(_ n: Int) {
        var f = favoritas
        if let i = f.firstIndex(of: n) { f.remove(at: i) } else { f.append(n) }
        favoritas = f
    }
}

/// Onde o cursor está, dentro de uma linha. Era um booleano `noX`, e deixou de
/// caber quando a linha ganhou o segundo botão: dois booleanos independentes
/// permitem o estado impossível "no × e no ↻ ao mesmo tempo", e estado
/// impossível sempre acaba na tela.
// MARK: - Aplicativo


// MARK: - A máquina

/// Memória, CPU e o que mais gasta, lidos do kernel do mesmo jeito que o Monitor
/// de Atividade (as contas da memória são as dele: "usada" = apps + fixa +
/// comprimida; "cache" = arquivos guardados, que o sistema devolve quando
/// precisa). Nada de processo novo aqui: são chamadas diretas, baratas.
enum Maquina {
    static let total = Double(ProcessInfo.processInfo.physicalMemory)

    struct Memoria { let usada, apps, fixa, comprimida, cache: Double }

    static func memoria() -> Memoria? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let r = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard r == KERN_SUCCESS else { return nil }
        let pagina = Double(vm_kernel_page_size)
        let apps = max(0, Double(stats.internal_page_count) - Double(stats.purgeable_count)) * pagina
        let fixa = Double(stats.wire_count) * pagina
        let comprimida = Double(stats.compressor_page_count) * pagina
        let cache = (Double(stats.external_page_count) + Double(stats.purgeable_count)) * pagina
        return Memoria(usada: apps + fixa + comprimida, apps: apps, fixa: fixa, comprimida: comprimida, cache: cache)
    }

    static func swap() -> Double {
        var x = xsw_usage()
        var t = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &x, &t, nil, 0) == 0 else { return 0 }
        return Double(x.xsu_used)
    }

    /// 1 normal, 2 atenção, 4 crítica: a mesma cor do gráfico de "Pressão" do
    /// Monitor de Atividade. É o número que diz se a memória está faltando de
    /// verdade; memória "usada" alta com pressão normal é o Mac aproveitando.
    static func pressao() -> Int {
        var n: Int32 = 0
        var t = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &n, &t, nil, 0) == 0 else { return 1 }
        return Int(n)
    }

    private static var ticksAntes: (UInt32, UInt32, UInt32, UInt32)?

    /// CPU de todos os núcleos juntos desde a leitura anterior (0 a 1).
    static func cpu() -> Double? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let r = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard r == KERN_SUCCESS else { return nil }
        let agora = info.cpu_ticks
        defer { ticksAntes = agora }
        guard let a = ticksAntes else { return nil }
        let usuario = Double(agora.0 &- a.0), sistema = Double(agora.1 &- a.1)
        let ocioso = Double(agora.2 &- a.2), nice = Double(agora.3 &- a.3)
        let soma = usuario + sistema + ocioso + nice
        return soma > 0 ? (usuario + sistema + nice) / soma : nil
    }

    struct Gasto {
        let nome: String
        let bytes: Double
        let processos: Int
        /// O processo de maior memória do grupo: é o que se encerra quando não é aplicativo.
        let pid: Int32
        /// O caminho do .app, quando é aplicativo: fecha-se o app (como o Cmd+Q), não processo a processo.
        let app: String?
        /// Todos os processos são da sua conta. Os do sistema (root e afins) aparecem, mas sem o ×: o macOS não
        /// deixa um app comum encerrá-los, e nem deveria.
        let meu: Bool
        /// O projeto do processo solto (preenchido pela Barra, que tem a Sonda).
        var projeto: String? = nil
        /// CPU do grupo, em % de um núcleo (o mesmo número do Monitor de Atividade: 250% = dois núcleos e meio).
        var cpu: Double = 0
    }

    /// O que nunca ganha ×: sem eles a tela, o Dock ou a própria barra somem.
    static let intocaveis: Set<String> = [
        "Finder", "Dock", "SystemUIServer", "WindowServer", "loginwindow", "ControlCenter",
        "NotificationCenter", "Barometer", "barometer", "launchd", "kernel_task",
    ]

    /// Quem mais gasta memória, agrupado por aplicativo: o Chrome são trinta
    /// processos "Helper", e o que interessa é o Chrome inteiro. Processo solto
    /// (node, bun, postgres) fica sozinho, com o projeto ao lado.
    /// O que é cada serviço do macOS que costuma aparecer no topo: "deleted" ou "mds_stores" sozinhos não dizem nada.
    static let doSistema: [String: String] = [
        "WindowServer": "desenha a tela", "kernel_task": "núcleo do macOS", "deleted": "libera espaço em disco",
        "deleted_helper": "libera espaço em disco", "mds": "Spotlight", "mds_stores": "Spotlight", "mdworker": "Spotlight",
        "mdworker_shared": "Spotlight", "corespotlightd": "Spotlight", "mediaanalysisd": "analisa as fotos",
        "photoanalysisd": "analisa as fotos", "photolibraryd": "biblioteca do Fotos", "launchservicesd": "abre os apps",
        "backupd": "Time Machine", "cloudd": "iCloud", "bird": "iCloud Drive", "softwareupdated": "atualização do macOS",
        "trustd": "certificados", "syspolicyd": "segurança dos apps", "XprotectService": "antivírus do macOS",
        "coreaudiod": "som", "bluetoothd": "Bluetooth", "airportd": "Wi-Fi", "logd": "registros do sistema",
        "powerd": "energia", "suggestd": "sugestões da Siri", "knowledge-agent": "Siri", "Spotlight": "Spotlight",
        "MenuBarAgent": "barra de menus", "ControlCenter": "Central de Controle", "Dock": "Dock", "Finder": "Finder",
    ]

    /// Um processo a esconder da lista: o do retrato, que desenha o painel e aparece gastando CPU à toa.
    static var escondido: Int32 = -1

    /// As duas listas (por memória e por CPU) saem de um `ps` só.
    static func quemMaisGasta(_ quantos: Int = 8) -> (memoria: [Gasto], cpu: [Gasto]) {
        guard let ps = Ferramenta.ps else { return ([], []) }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ps)
        p.arguments = ["-axo", "rss=,pcpu=,pid=,uid=,comm="]
        let cano = Pipe()
        p.standardOutput = cano
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return ([], []) }
        let dados = cano.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let eu = getuid()
        struct Soma { var bytes: Double; var n: Int; var pid: Int32; var maior: Double; var app: String?; var meu: Bool; var cpu: Double }
        var grupos: [String: Soma] = [:]
        for linha in (String(data: dados, encoding: .utf8) ?? "").split(separator: "\n") {
            let partes = linha.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard partes.count == 5, let kb = Double(partes[0]), let pcpu = Double(partes[1].replacingOccurrences(of: ",", with: ".")),
                  let pid = Int32(partes[2]), let uid = UInt32(partes[3]) else { continue }
            let caminho = String(partes[4])
            if escondido == pid { continue }
            let bytes = kb * 1024
            let chave: String
            var app: String?
            if let fim = caminho.range(of: ".app/") {
                app = String(caminho[..<fim.lowerBound]) + ".app"
                chave = (app! as NSString).deletingPathExtension.split(separator: "/").last.map(String.init) ?? caminho
            } else {
                chave = (caminho as NSString).lastPathComponent + "#\(pid)"
            }
            var g = grupos[chave] ?? Soma(bytes: 0, n: 0, pid: pid, maior: 0, app: app, meu: true, cpu: 0)
            g.bytes += bytes
            g.cpu += pcpu
            g.n += 1
            if bytes > g.maior { g.maior = bytes; g.pid = pid }
            if uid != eu { g.meu = false }
            grupos[chave] = g
        }
        func lista(_ antes: (Soma, Soma) -> Bool) -> [Gasto] {
            grupos.sorted { antes($0.value, $1.value) }.prefix(quantos).map {
                let nome = $0.key.split(separator: "#").first.map(String.init) ?? $0.key
                let v = $0.value
                return Gasto(nome: nome, bytes: v.bytes, processos: v.n, pid: v.pid, app: v.app,
                             meu: v.meu && !intocaveis.contains(nome), cpu: v.cpu)
            }
        }
        return (lista { $0.bytes > $1.bytes }, lista { $0.cpu > $1.cpu })
    }

    static func gb(_ bytes: Double) -> String {
        let v = bytes / 1_073_741_824
        if v < 1 { return "\(Int((bytes / 1_048_576).rounded())) MB" }
        return decimal(v) + " GB"
    }

}

/// As últimas seis horas, uma amostra por minuto: o gráfico do menu. Fica só na
/// memória do app (360 pontos não pesam) e recomeça quando o app reabre.
final class Historico {
    struct Ponto {
        let quando: Date
        let memoria: Double
        let cpu: Double
        let chip: Double?
        var gpu: Double = 0
        /// Leitura mais escrita do disco, em bytes por segundo.
        var disco: Double = 0
    }
    private(set) var pontos: [Ponto] = []
    let maximo = 360

    func anotar(memoria: Double, cpu: Double, chip: Double?, gpu: Double = 0, disco: Double = 0) {
        pontos.append(Ponto(quando: Date(), memoria: memoria, cpu: cpu, chip: chip, gpu: gpu, disco: disco))
        if pontos.count > maximo { pontos.removeFirst(pontos.count - maximo) }
    }

    /// Duas linhas sobre a mesma grade: memória usada (azul) e CPU (laranja),
    /// de 0 a 100%. A largura representa sempre seis horas, para o gráfico não
    /// "esticar" uma hora como se fossem seis.
    func imagem(largura: CGFloat = 260, altura: CGFloat = 54) -> NSImage {
        let img = NSImage(size: NSSize(width: largura, height: altura))
        img.lockFocus()
        let area = NSRect(x: 0.5, y: 0.5, width: largura - 1, height: altura - 1)
        NSColor.secondaryLabelColor.withAlphaComponent(0.25).setStroke()
        let moldura = NSBezierPath(roundedRect: area, xRadius: 4, yRadius: 4)
        moldura.lineWidth = 1
        moldura.stroke()
        for frac in [0.5] {
            let y = area.minY + area.height * frac
            let meio = NSBezierPath()
            meio.move(to: NSPoint(x: area.minX + 4, y: y))
            meio.line(to: NSPoint(x: area.maxX - 4, y: y))
            meio.setLineDash([2, 3], count: 2, phase: 0)
            meio.lineWidth = 0.5
            meio.stroke()
        }
        func linha(_ valor: (Ponto) -> Double?, _ cor: NSColor) {
            guard pontos.count > 1 else { return }
            let passo = (area.width - 8) / CGFloat(maximo - 1)
            let inicio = area.maxX - 4 - passo * CGFloat(pontos.count - 1)
            let caminho = NSBezierPath()
            var comecou = false
            for (i, p) in pontos.enumerated() {
                guard let v = valor(p) else { comecou = false; continue }
                let pt = NSPoint(x: inicio + passo * CGFloat(i),
                                 y: area.minY + 3 + (area.height - 6) * CGFloat(min(1, max(0, v))))
                comecou ? caminho.line(to: pt) : caminho.move(to: pt)
                comecou = true
            }
            cor.setStroke()
            caminho.lineWidth = 1.5
            caminho.lineJoinStyle = .round
            caminho.stroke()
        }
        linha({ $0.cpu }, .systemOrange)
        linha({ $0.memoria }, .systemBlue)
        // Temperatura do chip na mesma grade: 20 °C embaixo, 100 °C em cima.
        linha({ $0.chip.map { ($0 - 20) / 80 } }, .systemRed)
        img.unlockFocus()
        return img
    }
}

/// O painel é uma janela sem moldura, e não um `NSMenu`: menu não deixa fundo preto, gráfico nem linha fina com
/// × só ao passar o mouse. Ela pode virar a janela ativa (para o mouse acender as linhas), mas sem trazer o app
/// para a frente.
final class JanelaDoPainel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class Barra: NSObject, NSApplicationDelegate {

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let sonda = Sonda()
    /// Toda chamada ao `lsof` acontece aqui, uma por vez e fora da thread
    /// principal: varredura no main trava a barra do Mac inteira.
    private let fila = DispatchQueue(label: "barometer.sonda", qos: .utility)
    private let estado = Estado()
    private let historico = Historico()
    private var janela: JanelaDoPainel?
    private var vigiaDeClique: Any?
    private var vigiaDeTecla: Any?
    private var relogio: Timer?
    private var amostrador: Timer?
    private var aberto: Timer?
    private var leituras = 0
    private lazy var leitorDeCPU = LeitorDeCPU()
    private var vigiaDaAba: AnyCancellable?
    private var limpezaMedidaEm = Date.distantPast
    private let leitorDeDisco = LeitorDeDisco()
    private let leitorDeBateria = LeitorDeBateria()
    private var gpusDoMinuto: [Double] = []
    private var discosDoMinuto: [Double] = []
    private var cpusDoMinuto: [Double] = []

    private var portas: [Porta] = [] { didSet { estado.portas = portas } }
    private var ocultas: [(numero: Int, nome: String)] = [] { didSet { estado.ocultas = ocultas } }

    /// O app se chamava "Portas na Barra": as escolhas de lá (favoritas, ordem do Geral, filtro) vêm junto uma vez,
    /// e o "abrir ao ligar o Mac" antigo dá lugar ao novo.
    private func trazerDoNomeAntigo() {
        let novo = UserDefaults.standard
        guard !novo.bool(forKey: "trouxeDoNomeAntigo") else { return }
        novo.set(true, forKey: "trouxeDoNomeAntigo")
        if let antigo = UserDefaults(suiteName: "com.gabrielteles.portas-na-barra") {
            for chave in ["favoritas", "mostrarTudo", "memoriaNaBarra", "geral", "desligouLogin"] {
                if let v = antigo.object(forKey: chave), novo.object(forKey: chave) == nil { novo.set(v, forKey: chave) }
            }
        }
        let agenteAntigo = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.gabrielteles.portas-na-barra.plist")
        if FileManager.default.fileExists(atPath: agenteAntigo.path) {
            try? FileManager.default.removeItem(at: agenteAntigo)
            if !novo.bool(forKey: "desligouLogin") { try? Login.ligar() }
        }
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        if let i = CommandLine.arguments.firstIndex(of: "--retrato"), i + 1 < CommandLine.arguments.count {
            let arquivo = CommandLine.arguments[i + 1]
            MainActor.assumeIsolated { retrato(em: arquivo) }
            return
        }
        trazerDoNomeAntigo()
        SobreEsteMac.ler { [weak self] in self?.estado.sobreMac = $0 }
        // A aba de Limpeza mede as pastas ao abrir (pode levar uns segundos; nunca com ela fechada).
        // Trocou de aba com o painel aberto: lê na hora o que a aba nova mostra (o resto parou de ser lido).
        vigiaDaAba = estado.$abaAtual.sink { [weak self] aba in
            DispatchQueue.main.async {
                guard let self, self.painelAberto else { return }
                if aba == .limpeza { self.medirLimpeza() }
                self.lerGastos()
                if self.precisaDasPortas { self.varrer() }
            }
        }
        item.button?.target = self
        item.button?.action = #selector(alternar)
        estado.favoritas = Pref.favoritas
        estado.mostrarTudo = Pref.tudo
        estado.memoriaNaBarra = Pref.memoriaNaBarra
        estado.aoMudarABarra = { [weak self] in self?.desenharIcone() }
        estado.abrirAoLigar = Login.ligado

        relogio = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            if self?.precisaDasPortas == true { self?.varrer() }
        }
        relogio?.tolerance = 1
        varrer()

        // Memória, CPU e temperatura a cada 10 s (é o que mexe o ícone); o gráfico guarda uma por minuto,
        // com a média da CPU do minuto. Tudo chamada direta ao kernel, sem processo novo.
        _ = Maquina.cpu()
        amostrar()
        amostrador = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.amostrar() }
        amostrador?.tolerance = 2

        abrirNoLoginNaPrimeiraVez()
        // --abrir: já abre o painel (para medir memória e CPU com ele aberto, sem precisar clicar).
        if CommandLine.arguments.contains("--abrir") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.abrirPainel() }
        }
        let t = Sensores.ler()
        Diario.anotar("aberto; sensores: chip \(t.chip.map { String(format: "%.1f", $0) } ?? "-"), SSD \(t.ssd.map { String(format: "%.1f", $0) } ?? "-"), bateria \(t.bateria.map { String(format: "%.1f", $0) } ?? "-")")
    }

    // MARK: Leituras

    private func amostrar() {
        guard let m = Maquina.memoria() else { return }
        let cpu = Maquina.cpu()
        if let cpu { cpusDoMinuto.append(cpu) }
        let temp = Sensores.ler()
        estado.memoria = m
        estado.pressao = Maquina.pressao()
        estado.swap = Maquina.swap()
        if let cpu { estado.cpu = cpu }
        estado.temperatura = temp
        let gpu = LeitorDeGPU.ler()
        let disco = leitorDeDisco.ler()
        estado.gpu = gpu
        estado.disco = disco
        if estado.naBarra.contains(.bateria) { estado.bateria = leitorDeBateria.ler(comOficial: false) }
        gpusDoMinuto.append(gpu?.uso ?? 0)
        discosDoMinuto.append(disco.leituraPorSegundo + disco.escritaPorSegundo)
        leituras += 1
        // Uma por minuto (a média do minuto). Nos primeiros 5 minutos, uma a cada leitura (10 s): o gráfico já
        // nasce desenhado, em vez de esperar minutos com o cartão vazio.
        if leituras % 6 == 1 || leituras <= 30 {
            let media = { (v: [Double], reserva: Double) in v.isEmpty ? reserva : v.reduce(0, +) / Double(v.count) }
            historico.anotar(memoria: m.usada / Maquina.total, cpu: media(cpusDoMinuto, estado.cpu ?? 0), chip: temp.chip,
                             gpu: media(gpusDoMinuto, 0), disco: media(discosDoMinuto, 0))
            cpusDoMinuto.removeAll(); gpusDoMinuto.removeAll(); discosDoMinuto.removeAll()
            estado.pontos = historico.pontos
        }
        desenharIcone()
    }

    /// O que a tela aberta mostra agora: a aba, ou os cartões ligados do Geral. Só isso é lido enquanto o
    /// painel está aberto; o resto espera a pessoa ir até lá.
    private func naTela(_ coisa: String) -> Bool {
        switch estado.abaAtual {
        case .geral:
            if estado.editandoGeral { return false }
            let ligados = Set(estado.geral.filter(\.ligado).map(\.id))
            switch coisa {
            case "gpu": return ligados.contains("gpu") || ligados.contains("aneis")
            default: return ligados.contains(coisa)
            }
        case .cpu: return coisa == "cpu" || coisa == "processos"
        case .memoria: return coisa == "processos"
        case .gpu: return coisa == "gpu"
        case .disco: return coisa == "disco"
        case .bateria: return coisa == "bateria"
        case .portas: return coisa == "portas"
        case .limpeza, .aparencia: return false
        }
    }

    private var painelAberto: Bool { janela?.isVisible == true }

    /// As portas (`lsof`, um processo novo a cada vez): com o painel fechado, só se o número delas está na barra;
    /// com ele aberto, só se a tela mostra as portas.
    private var precisaDasPortas: Bool { painelAberto ? naTela("portas") || estado.naBarra.contains(.portas) : estado.naBarra.contains(.portas) }

    /// Com o painel aberto, a cada 2 s: só o que está na tela. Núcleos, GPU, disco e bateria ao vivo (a velocidade
    /// do disco é a dos últimos 2 s), e a lista de quem mais gasta (um `ps` só para as duas listas). A saúde
    /// oficial da bateria (system_profiler) só com a bateria na tela.
    private func lerGastos() {
        if naTela("cpu") { estado.cpuDetalhada = leitorDeCPU.ler() }
        if naTela("gpu") { estado.gpu = LeitorDeGPU.ler() }
        if naTela("disco") { estado.disco = leitorDeDisco.ler() }
        if naTela("bateria") { estado.bateria = leitorDeBateria.ler(comOficial: true) }
        guard naTela("processos") else { return }
        fila.async { [weak self] in
            guard let self else { return }
            var (porMemoria, porCPU) = Maquina.quemMaisGasta()
            for i in porMemoria.indices where porMemoria[i].app == nil && porMemoria[i].meu {
                if let pasta = self.sonda.pastaDoProcesso(porMemoria[i].pid) { porMemoria[i].projeto = self.sonda.projeto(de: pasta) }
            }
            for i in porCPU.indices where porCPU[i].app == nil && porCPU[i].meu {
                if let pasta = self.sonda.pastaDoProcesso(porCPU[i].pid) { porCPU[i].projeto = self.sonda.projeto(de: pasta) }
            }
            DispatchQueue.main.async {
                self.estado.gastos = porMemoria
                self.estado.gastosCPU = porCPU
            }
        }
    }

    private func varrer(depois: (() -> Void)? = nil) {
        let tudo = Pref.tudo
        fila.async { [weak self] in
            guard let self else { return }
            let achadas = self.sonda.varrer(tudo: tudo)
            DispatchQueue.main.async {
                if achadas.lista.map(\.numero) != self.portas.map(\.numero) {
                    Diario.anotar("varredura: " + achadas.lista.map { "\($0.numero)" }.joined(separator: ", "))
                }
                self.portas = achadas.lista
                self.ocultas = achadas.ocultas
                self.desenharIcone()
                depois?()
            }
        }
    }

    private func desenharIcone() {
        guard let botao = item.button else { return }
        botao.title = ""
        botao.imagePosition = .imageOnly
        botao.image = Icone.barra(pedacosDaBarra(), colorido: estado.aparencia.iconeColorido)
        var dica = [t("CPU \(Int(((estado.cpu ?? 0) * 100).rounded()))% · memória \(Int(((estado.memoria?.usada ?? 0) / Maquina.total * 100).rounded()))%")]
        if let c = estado.temperatura.chip { dica[0] += " · chip \(Int(c.rounded())) °C" }
        dica += portas.map { "\($0.numero) — \($0.resumo)" }
        botao.toolTip = dica.joined(separator: "\n")
    }

    /// Cada item escolhido para a barra: o ícone (ou as barrinhas) e o número.
    private func pedacosDaBarra() -> [Icone.Pedaco] {
        let cpu = estado.cpu ?? 0
        let memoria = (estado.memoria?.usada ?? 0) / Maquina.total
        let pct = { (v: Double) in "\(Int((v * 100).rounded()))%" }
        var pedacos: [Icone.Pedaco] = []
        for item in estado.naBarra {
            switch item {
            case .barrinhas: pedacos.append(.init(nil, "", (cpu, memoria), cor: nil))
            case .cpu: pedacos.append(.init(item.simbolo, pct(cpu), nil, cor: item.cor))
            case .memoria: pedacos.append(.init(item.simbolo, pct(memoria), nil, cor: item.cor))
            case .gpu: pedacos.append(.init(item.simbolo, pct(estado.gpu?.uso ?? 0), nil, cor: item.cor))
            case .chip: pedacos.append(.init(item.simbolo, estado.temperatura.chip.map { "\(Int($0.rounded()))°" } ?? "–", nil, cor: item.cor))
            case .bateria:
                if let b = estado.bateria ?? leitorDeBateria.ler(comOficial: false) as Bateria?, b.existe {
                    pedacos.append(.init(b.carregando ? "battery.100percent.bolt" : item.simbolo, "\(b.nivel)%", nil, cor: item.cor))
                }
            case .disco: pedacos.append(.init(item.simbolo, estado.disco.map { Medida.espaco($0.livre) } ?? "–", nil, cor: item.cor))
            // Sem porta aberta mostra 0: o ícone sozinho, sem número, ninguém sabe o que é.
            case .portas: pedacos.append(.init(item.simbolo, String(portas.count), nil, cor: item.cor))
            }
        }
        if pedacos.isEmpty { pedacos = [.init(nil, "", (cpu, memoria), cor: nil)] }
        return pedacos
    }

    // MARK: O painel

    @objc private func alternar() {
        if janela?.isVisible == true { fecharPainel() } else { abrirPainel() }
    }

    private var acoes: Acoes {
        var a = Acoes()
        a.abrirPorta = { [weak self] p in self?.abrir(p) }
        a.encerrarPorta = { [weak self] p in self?.fecharPainel(); self?.confirmarEncerrar(p) }
        a.fechar = { [weak self] g in self?.fecharPainel(); self?.confirmarFechar(g) }
        a.atualizar = { [weak self] in self?.varrer(); self?.lerGastos(); self?.amostrar() }
        a.virarTudo = { [weak self] in Pref.tudo.toggle(); self?.estado.mostrarTudo = Pref.tudo; self?.varrer() }
        a.virarAbrirAoLigar = { [weak self] in self?.virarLogin() }
        a.virarMemoriaNaBarra = { [weak self] in
            Pref.memoriaNaBarra.toggle(); self?.estado.memoriaNaBarra = Pref.memoriaNaBarra; self?.desenharIcone()
        }
        a.virarFavorita = { [weak self] n in Pref.virarFavorita(n); self?.estado.favoritas = Pref.favoritas }
        a.outraFavorita = { [weak self] in self?.fecharPainel(); self?.pedirFavorita() }
        a.copiar = { [weak self] in self?.copiar() }
        a.monitor = { [weak self] in
            self?.fecharPainel()
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
        }
        a.sair = { NSApp.terminate(nil) }
        a.ajustes = { [weak self] in self?.mostrarAjustes() }
        a.redimensionar = { [weak self] tamanho in self?.redimensionar(tamanho) }
        a.limpar = { [weak self] id in self?.confirmarLimpeza(ids: [id]) }
        a.limparTudo = { [weak self] in
            guard let self else { return }
            self.confirmarLimpeza(ids: self.estado.limpeza.filter { !$0.ehLixeira && ($0.bytes ?? 0) > 0 }.map(\.id))
        }
        return a
    }

    private func abrirPainel() {
        guard let botao = item.button, let janelaDoBotao = botao.window else { return }
        // Ainda fechado aqui: lê o que a aba vai mostrar (as portas sempre, para o número da barra ficar certo).
        varrer()
        lerGastos()
        let vista = NSHostingView(rootView: Painel(estado: estado, acoes: acoes))
        vista.layoutSubtreeIfNeeded()
        let tamanho = vista.fittingSize
        let base = janelaDoBotao.convertToScreen(botao.convert(botao.bounds, to: nil))
        let tela = janelaDoBotao.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var x = base.midX - tamanho.width / 2
        x = min(max(tela.minX + 8, x), tela.maxX - tamanho.width - 8)
        let quadro = NSRect(x: x, y: base.minY - tamanho.height - 6, width: tamanho.width, height: tamanho.height)

        let j = janela ?? {
            let nova = JanelaDoPainel(contentRect: quadro, styleMask: [.borderless, .nonactivatingPanel],
                                      backing: .buffered, defer: false)
            nova.isOpaque = false
            nova.backgroundColor = .clear
            nova.hasShadow = true
            nova.level = .popUpMenu
            nova.collectionBehavior = [.canJoinAllSpaces, .transient]
            nova.isMovable = false
            return nova
        }()
        j.contentView = vista
        j.setFrame(quadro, display: true)
        // Abre com um leve crescimento e esmaecendo para dentro.
        estado.apareceu = false
        j.alphaValue = 0
        j.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            j.animator().alphaValue = 1
        }
        DispatchQueue.main.async { [weak self] in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { self?.estado.apareceu = true }
        }
        janela = j
        botao.highlight(true)

        // Fecha ao clicar fora, apertar Esc ou ao a janela deixar de ser a ativa.
        vigiaDeClique = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.fecharPainel()
        }
        vigiaDeTecla = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.keyCode == 53 { self?.fecharPainel(); return nil }
            return e
        }
        // Enquanto está aberto, a lista de quem gasta e as portas se renovam.
        aberto = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.lerGastos() }
        aberto?.tolerance = 0.5
    }

    /// O painel mudou de altura (outra aba, cartão ligado ou desligado): a janela acompanha, presa pelo topo.
    private func redimensionar(_ tamanho: CGSize) {
        guard let j = janela, tamanho.height > 10 else { return }
        var quadro = j.frame
        let topo = quadro.maxY
        quadro.size = NSSize(width: tamanho.width, height: tamanho.height)
        quadro.origin.y = topo - tamanho.height
        j.setFrame(quadro, display: true, animate: false)
    }

    private func fecharPainel() {
        janela?.orderOut(nil)
        // Fechado, o desenho inteiro sai da memória (o SwiftUI guarda texto, ícones e gráfico desenhados);
        // ao abrir de novo ele é refeito a partir do `Estado`, que continua aqui.
        janela?.contentView = nil
        item.button?.highlight(false)
        if let v = vigiaDeClique { NSEvent.removeMonitor(v); vigiaDeClique = nil }
        if let v = vigiaDeTecla { NSEvent.removeMonitor(v); vigiaDeTecla = nil }
        aberto?.invalidate()
        aberto = nil
    }

    /// `--retrato arquivo.png`: desenha o painel numa imagem e sai. É como se confere o desenho sem acesso à
    /// tela (gravação de tela pede permissão). O gráfico usa as leituras de verdade se houver; senão, uma
    /// curva de exemplo, marcada no próprio painel como exemplo.
    @MainActor
    private func retrato(em arquivo: String) {
        Maquina.escondido = ProcessInfo.processInfo.processIdentifier
        if let i = CommandLine.arguments.firstIndex(of: "--idioma"), i + 1 < CommandLine.arguments.count {
            Idioma.forcado = Idioma(rawValue: CommandLine.arguments[i + 1])
        }
        estado.paraImagem = true
        _ = Maquina.cpu()
        Thread.sleep(forTimeInterval: 1)
        amostrar()
        let agora = Date()
        // --uma-leitura: o gráfico como fica logo depois de o app abrir (sem a curva de exemplo).
        if CommandLine.arguments.contains("--uma-leitura") {
            estado.pontos = historico.pontos
        } else if historico.pontos.count < 2 {
            for i in 0..<240 {
                let t = Double(i)
                historico.anotar(memoria: 0.45 + 0.12 * sin(t / 30) + 0.03 * sin(t / 4),
                                 cpu: max(0.03, 0.18 + 0.15 * sin(t / 11) + (i % 37 == 0 ? 0.4 : 0)),
                                 chip: 42 + 8 * sin(t / 25),
                                 gpu: max(0, 0.1 + 0.1 * sin(t / 17)),
                                 disco: max(0, 2_000_000 + 1_500_000 * sin(t / 9) + (i % 41 == 0 ? 40_000_000 : 0)))
            }
            let total = historico.pontos.count
            estado.pontos = historico.pontos.enumerated().map { i, p in
                Historico.Ponto(quando: agora.addingTimeInterval(Double(i - total) * 60), memoria: p.memoria, cpu: p.cpu, chip: p.chip,
                                gpu: p.gpu, disco: p.disco)
            }
        }
        estado.portas = sonda.varrer(tudo: false).lista
        var (gastos, gastosCPU) = Maquina.quemMaisGasta()
        for i in gastos.indices where gastos[i].app == nil && gastos[i].meu {
            if let pasta = sonda.pastaDoProcesso(gastos[i].pid) { gastos[i].projeto = sonda.projeto(de: pasta) }
        }
        estado.gastos = gastos
        estado.gastosCPU = gastosCPU
        _ = leitorDeCPU.ler()
        Thread.sleep(forTimeInterval: 1)
        estado.cpuDetalhada = leitorDeCPU.ler()
        estado.disco = leitorDeDisco.ler()
        estado.gpu = LeitorDeGPU.ler()
        if let i = CommandLine.arguments.firstIndex(of: "--aba"), i + 1 < CommandLine.arguments.count,
           let aba = Aba(rawValue: CommandLine.arguments[i + 1]) { estado.abaAtual = aba }
        if CommandLine.arguments.contains("--editar") { estado.editandoGeral = true }
        // A foto sai com a aparência padrão, mais o que vier pedido: --fundo vidro --paleta neon --destaque rosa
        // --transparencia 60 --cantos 22 --mola --colorido.
        var ap = Aparencia()
        func argumento(_ nome: String) -> String? {
            guard let i = CommandLine.arguments.firstIndex(of: nome), i + 1 < CommandLine.arguments.count else { return nil }
            return CommandLine.arguments[i + 1]
        }
        if let f = argumento("--fundo").flatMap(Aparencia.Fundo.init(rawValue:)) { ap.fundo = f }
        if let p = argumento("--paleta") { ap.paleta = p }
        if let d = argumento("--destaque") { ap.destaque = d }
        if let v = argumento("--transparencia").flatMap(Double.init) { ap.coberturaAtual = 1 - v / 100 }
        if let v = argumento("--cantos").flatMap(Double.init) { ap.cantos = v }
        if CommandLine.arguments.contains("--mola") { ap.movimento = .mola }
        if CommandLine.arguments.contains("--colorido") { ap.iconeColorido = true }
        estado.aparencia = ap
        // A saúde oficial chega em segundo plano (system_profiler): espera por ela, até 3 s.
        _ = leitorDeBateria.ler(comOficial: true)
        let limite = Date().addingTimeInterval(3)
        while leitorDeBateria.ler(comOficial: false).saudeOficial == nil, Date() < limite {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        estado.bateria = leitorDeBateria.ler(comOficial: false)
        estado.apareceu = true
        var sobre: String?
        SobreEsteMac.ler { sobre = $0 }
        let limiteSobre = Date().addingTimeInterval(4)
        while sobre == nil, Date() < limiteSobre { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
        estado.sobreMac = sobre
        if estado.abaAtual == .limpeza || estado.geral.contains(where: { $0.id == "limpeza" && $0.ligado }) {
            estado.limpeza = Limpeza.itens().map { var i = $0; i.bytes = Limpeza.tamanho($0.pasta); return i }
        }
        if let i = CommandLine.arguments.firstIndex(of: "--acender"), i + 1 < CommandLine.arguments.count {
            estado.sobre = CommandLine.arguments[i + 1]
        }
        if CommandLine.arguments.contains("--cpu") { estado.abaProcessos = 1 }
        if let i = CommandLine.arguments.firstIndex(of: "--grafico"), i + 1 < CommandLine.arguments.count {
            estado.aba = Int(CommandLine.arguments[i + 1]) ?? 0
        }
        estado.favoritas = Pref.favoritas
        // Fundo que deixa ver atrás: a foto põe o painel sobre o papel de parede, com mais margem para ele aparecer.
        // --papel faz o mesmo com o sólido, e --altura fixa a altura da foto (os quadros do GIF têm de ter uma só).
        let deixaVer = ap.fundoReal != .solido || ap.coberturaAtual < 1 || CommandLine.arguments.contains("--papel")
        let margem: CGFloat = deixaVer ? 48 : 20
        let altura = argumento("--altura").flatMap(Double.init).map { CGFloat($0) }
        estado.deslocamentoNaFoto = CGSize(width: margem, height: margem)
        let renderizador = ImageRenderer(content: Painel(estado: estado, acoes: Acoes()).padding(margem)
            .frame(height: altura, alignment: .top)
            .background(alignment: .topLeading) {
                if deixaVer { PapelDeParede() } else { Color(white: 0.16) }
            }
            .clipped())
        renderizador.scale = 2
        // Cor não linear e direto do bitmap: com ícone de app na tela, o renderizador trocava o espaço de cor e o
        // preto saía cinza na imagem (só na imagem; na tela, não).
        renderizador.colorMode = .nonLinear
        if let cg = renderizador.cgImage,
           let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: arquivo))
        }
        // A barra de menus: o ícone e o número de portas, em branco sobre a faixa escura, como na tela.
        // Em 4x: no README a faixa aparece grande e nítida. A largura acompanha o que está na barra.
        let k: CGFloat = 4
        if let i = CommandLine.arguments.firstIndex(of: "--barra"), i + 1 < CommandLine.arguments.count {
            estado.naBarra = CommandLine.arguments[i + 1].split(separator: ",").compactMap { ItemDaBarra(rawValue: String($0)) }
        }
        portas = estado.portas
        let colorido = estado.aparencia.iconeColorido
        let icone = Icone.barra(pedacosDaBarra(), colorido: colorido)
        let largura = icone.size.width * k
        let faixa = NSImage(size: NSSize(width: largura + 60 * k, height: 30 * k))
        faixa.lockFocus()
        NSColor(white: 0.12, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: largura + 60 * k, height: 30 * k).fill()
        let onde = NSRect(x: 30 * k, y: 6 * k, width: largura, height: 18 * k)
        if colorido {
            // Colorido: as cores ficam, e o texto sai branco como numa barra escura.
            NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance { icone.draw(in: onde) }
        } else {
            let branco = NSImage(size: icone.size, flipped: false) { r in
                icone.draw(in: r)
                NSColor.white.set()
                r.fill(using: .sourceAtop)
                return true
            }
            branco.draw(in: onde)
        }
        faixa.unlockFocus()
        if let tiff = faixa.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: (arquivo as NSString).deletingPathExtension + "-icone.png"))
        }
        NSApp.terminate(nil)
    }

    // MARK: Limpeza

    /// Mede cada pasta fora da thread principal e vai mostrando conforme termina. Se mediu há menos de 2 minutos,
    /// não mede de novo.
    private func medirLimpeza(forcar: Bool = false) {
        guard forcar || Date().timeIntervalSince(limpezaMedidaEm) > 120 || estado.limpeza.isEmpty else { return }
        limpezaMedidaEm = Date()
        let itens = Limpeza.itens()
        let antigos = Dictionary(estado.limpeza.map { ($0.id, $0.bytes) }, uniquingKeysWith: { a, _ in a })
        estado.limpeza = itens.map { var i = $0; i.bytes = antigos[$0.id] ?? nil; return i }
        estado.medindoLimpeza = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            for item in itens {
                let bytes = Limpeza.tamanho(item.pasta)
                DispatchQueue.main.async {
                    guard let self, let i = self.estado.limpeza.firstIndex(where: { $0.id == item.id }) else { return }
                    self.estado.limpeza[i].bytes = bytes
                }
            }
            DispatchQueue.main.async { self?.estado.medindoLimpeza = false }
        }
    }

    private func confirmarLimpeza(ids: [String]) {
        let itens = estado.limpeza.filter { ids.contains($0.id) }
        guard !itens.isEmpty else { return }
        fecharPainel()
        let total = itens.compactMap(\.bytes).reduce(0, +)
        let alerta = NSAlert()
        if itens.count == 1, let item = itens.first {
            if item.ehLixeira {
                alerta.messageText = t("Esvaziar a Lixeira?")
                alerta.informativeText = t("Os arquivos da Lixeira são apagados de vez. Não tem como recuperar depois.")
                alerta.addButton(withTitle: t("Esvaziar"))
            } else {
                alerta.messageText = t("Limpar \(t(item.nome))?")
                alerta.informativeText = t("Vão sair \(Maquina.gb(item.bytes ?? 0)). \(t(item.explicacao))")
                alerta.addButton(withTitle: t("Limpar"))
            }
        } else {
            alerta.messageText = t("Limpar tudo, \(Maquina.gb(total))?")
            alerta.informativeText = t("Saem os caches dos apps e dos gerenciadores de pacote, os dados do Xcode e os registros. A Lixeira fica.")
            alerta.addButton(withTitle: t("Limpar"))
        }
        alerta.addButton(withTitle: t("Cancelar"))
        alerta.buttons.first?.hasDestructiveAction = true
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            guard alerta.runModal() == .alertFirstButtonReturn else { return }
            Diario.anotar("limpeza: " + itens.map(\.id).joined(separator: ", "))
            DispatchQueue.global(qos: .utility).async {
                let liberado = itens.map(Limpeza.limpar).reduce(0, +)
                DispatchQueue.main.async {
                    Diario.anotar("limpeza liberou \(Int(liberado / 1_048_576)) MB")
                    self?.estado.liberado = liberado
                    self?.medirLimpeza(forcar: true)
                    self?.amostrar()
                }
            }
        }
    }

    // MARK: Ajustes

    @objc private func ajusteAbrirAoLigar() { virarLogin() }
    @objc private func ajusteUsoNoIcone() { Pref.memoriaNaBarra.toggle(); estado.memoriaNaBarra = Pref.memoriaNaBarra; desenharIcone() }
    @objc private func ajusteFavorita(_ mi: NSMenuItem) { Pref.virarFavorita(mi.tag); estado.favoritas = Pref.favoritas }
    @objc private func ajusteOutraFavorita() { fecharPainel(); pedirFavorita() }
    @objc private func ajusteSair() { NSApp.terminate(nil) }
    @objc private func ajusteNaBarra(_ mi: NSMenuItem) {
        guard let opcao = ItemDaBarra(rawValue: mi.representedObject as? String ?? "") else { return }
        if let i = estado.naBarra.firstIndex(of: opcao) { estado.naBarra.remove(at: i) }
        else if estado.naBarra.count < ItemDaBarra.maximo { estado.naBarra.append(opcao) }
    }
    @objc private func ajusteIdioma(_ mi: NSMenuItem) {
        Idioma.escolhido = Idioma(rawValue: mi.representedObject as? String ?? "") ?? .automatico
        // Tudo o que está na tela passa pelo `t()` de novo.
        estado.objectWillChange.send()
        desenharIcone()
    }

    private func mostrarAjustes() {
        let m = NSMenu()
        func item(_ t: String, _ sel: Selector, ligado: Bool? = nil) -> NSMenuItem {
            let mi = NSMenuItem(title: t, action: sel, keyEquivalent: "")
            mi.target = self
            if let ligado { mi.state = ligado ? .on : .off }
            return mi
        }
        m.addItem(item(t("Abrir ao ligar o Mac"), #selector(ajusteAbrirAoLigar), ligado: Login.ligado))
        let naBarra = NSMenu()
        for opcao in ItemDaBarra.allCases {
            let mi = item(opcao.nome, #selector(ajusteNaBarra(_:)), ligado: estado.naBarra.contains(opcao))
            mi.representedObject = opcao.rawValue
            mi.image = NSImage(systemSymbolName: opcao.simbolo, accessibilityDescription: nil)
            if !estado.naBarra.contains(opcao) && estado.naBarra.count >= ItemDaBarra.maximo { mi.action = nil }
            naBarra.addItem(mi)
        }
        let paiBarra = NSMenuItem(title: t("Na barra de menus (até 3)"), action: nil, keyEquivalent: "")
        paiBarra.submenu = naBarra
        m.addItem(paiBarra)
        let favoritas = NSMenu()
        let sugeridas = [3000, 3001, 3002, 3003, 3006, 4000, 5173, 5432, 6379, 8000, 8080]
        for n in Array(Set(sugeridas).union(Pref.favoritas)).sorted() {
            let mi = item("\(n)", #selector(ajusteFavorita(_:)), ligado: Pref.favoritas.contains(n))
            mi.tag = n
            favoritas.addItem(mi)
        }
        favoritas.addItem(.separator())
        favoritas.addItem(item(t("Outra porta…"), #selector(ajusteOutraFavorita)))
        let pai = NSMenuItem(title: t("Portas favoritas"), action: nil, keyEquivalent: "")
        pai.submenu = favoritas
        m.addItem(pai)
        let idiomas = NSMenu()
        for idioma in Idioma.allCases {
            let mi = item(idioma.nome, #selector(ajusteIdioma(_:)), ligado: Idioma.escolhido == idioma)
            mi.representedObject = idioma.rawValue
            idiomas.addItem(mi)
        }
        let paiIdioma = NSMenuItem(title: t("Idioma"), action: nil, keyEquivalent: "")
        paiIdioma.submenu = idiomas
        m.addItem(paiIdioma)
        m.addItem(.separator())
        m.addItem(item(t("Sair"), #selector(ajusteSair)))
        m.appearance = NSAppearance(named: .darkAqua)
        if let j = janela, let vista = j.contentView {
            m.popUp(positioning: nil, at: NSPoint(x: vista.bounds.maxX - 40, y: 40), in: vista)
        }
    }

    // MARK: Ações

    private func abrir(_ p: Porta) {
        fecharPainel()
        if p.web, let u = URL(string: "http://localhost:\(p.numero)") {
            NSWorkspace.shared.open(u)
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("localhost:\(p.numero)", forType: .string)
        }
    }

    private func virarLogin() {
        do {
            if Login.ligado {
                try Login.desligar()
                UserDefaults.standard.set(true, forKey: "desligouLogin")
            } else {
                try Login.ligar()
                UserDefaults.standard.set(false, forKey: "desligouLogin")
            }
            estado.abrirAoLigar = Login.ligado
        } catch {
            avisar("Não consegui mudar o abrir ao ligar o Mac", error.localizedDescription)
        }
    }

    /// Abrir sozinho ao ligar o Mac. Era pelo `SMAppService`, que para este app
    /// (assinado só localmente, em ~/Applications) responde "não achado": ele
    /// nunca abriu sozinho. Agora é um LaunchAgent, um arquivo que o macOS lê
    /// ao entrar na conta e que só abre o app. Liga sozinho na primeira vez; quem
    /// desligar no menu continua desligado.
    private func abrirNoLoginNaPrimeiraVez() {
        guard !UserDefaults.standard.bool(forKey: "desligouLogin"), !Login.ligado else { return }
        do { try Login.ligar(); Diario.anotar("abrir ao ligar o Mac: ligado") }
        catch { Diario.anotar("abrir ao ligar o Mac: falhou: \(error.localizedDescription)") }
    }

    /// O × pede confirmação e então faz a coisa certa para cada caso — e o caso
    /// do Docker é a razão de esta função não ser um `kill` de três linhas.
    ///
    /// Quem "ouve" uma porta publicada por container **não é o container**: é o
    /// `com.docker.backend`, um processo só para todos eles. Matá-lo derruba o
    /// Docker Desktop inteiro, com todos os outros containers de brinde, e a
    /// porta continua ocupada quando ele voltar. Container se para com
    /// `docker stop`.
    private func confirmarEncerrar(_ p: Porta) {
        let alerta = NSAlert()
        let acao: () -> Void

        if let container = p.container {
            alerta.messageText = t("Parar o container \(container)?")
            alerta.informativeText = t("""
                Ele publica a porta \(p.numero). Vai um `docker stop`, não um \
                kill — quem ouve a porta é o Docker inteiro, e matar aquele \
                processo derrubaria todos os outros containers junto.
                """)
            Diario.anotar("porta \(p.numero) é do container \(container); docker stop")
            acao = { [weak self] in
                self?.fila.async {
                    let parou = self?.sonda.parar(container: container) ?? false
                    Diario.anotar(parou ? "container \(container) parado" : "container \(container) NÃO parou")
                    DispatchQueue.main.async {
                        self?.varrer()
                        if !parou {
                            self?.avisar("O container \(container) não parou",
                                         "Confira se o Docker está aberto. No Terminal: docker stop \(container)")
                        }
                    }
                }
            }
        } else if p.doDocker {
            // Docker sem container identificado: ou o `docker` não está no
            // PATH, ou a porta é de algo que o `docker ps` não mostra. Matar o
            // backend às cegas é justamente o que não se quer.
            alerta.messageText = t("Não vou matar este processo")
            alerta.informativeText = t("""
                A porta \(p.numero) é publicada pelo Docker, e quem a ouve é o \
                processo do Docker inteiro — matá-lo derrubaria todos os \
                containers. Não descobri de qual container ela é. Use \
                `docker ps` e pare o container pelo nome.
                """)
            alerta.addButton(withTitle: t("Entendi"))
            DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true); alerta.runModal() }
            return
        } else {
            /* Descobrir o trabalho ANTES de perguntar, e não depois: a caixa
               precisa dizer quantos processos vão embora. Matar três quando a
               pergunta falava de um é o tipo de surpresa que faz a pessoa
               desconfiar do botão para sempre. */
            let trab = sonda.trabalho(de: p.pid)
            switch trab?.plano {
            case .grupo(let g):
                Diario.anotar("porta \(p.numero): plano GRUPO \(g), "
                    + "\(trab?.membros.count ?? 0) membros: "
                    + (trab?.membros.map { "\($0.pid) \($0.nome)" }.joined(separator: ", ") ?? ""))
            case .processos:
                Diario.anotar("porta \(p.numero): plano PROCESSOS, "
                    + (trab?.membros.map { "\($0.pid) \($0.nome)" }.joined(separator: ", ") ?? ""))
            case nil:
                Diario.anotar("porta \(p.numero): não li a árvore de processos")
            }
            alerta.messageText = t("Encerrar o que está na porta \(p.numero)?")

            var texto = t("\(p.comoChamar), processo \(p.pid).")
            if let p2 = p.pasta { texto += "\n\(p2)" }

            switch trab?.plano {
            case .grupo:
                let membros = trab?.membros ?? []
                texto += "\n\n" + t(membros.count == 1 ? "Vai embora 1 processo do mesmo trabalho — é o que o Ctrl+C no terminal faria:"
                                                     : "Vão embora \(membros.count) processos do mesmo trabalho — é o que o Ctrl+C no terminal faria:") + "\n"
                texto += membros.map { "  · \($0.resumo)" }.joined(separator: "\n")
            case .processos:
                let membros = trab?.membros ?? []
                if membros.count > 1 {
                    texto += "\n\n" + t("E com ele os \(membros.count - 1) que o mantêm de pé:") + "\n"
                    texto += membros.dropFirst().map { "  · \($0.resumo)" }
                        .joined(separator: "\n")
                } else {
                    /* Honestidade sobre o caminho conservador: quando não se
                       acha o trabalho, vai só quem ouve — e um supervisor
                       (`npm run dev`) sobe outro em menos de um segundo. */
                    texto += "\n\n" + t("Só o processo que ouve a porta. Se houver um supervisor no terminal, ele pode subir outro.")
                }
            case nil:
                texto += "\n\n" + t("Não consegui ler a árvore de processos; vai só quem ouve.")
            }
            alerta.informativeText = texto
            acao = { [weak self] in self?.encerrar(p, trab) }
        }

        alerta.addButton(withTitle: t(p.container != nil ? "Parar" : "Encerrar"))
        alerta.addButton(withTitle: t("Cancelar"))
        alerta.buttons.first?.hasDestructiveAction = true
        /* O menu acabou de ser fechado pelo clique no ×. Pedir a caixa no mesmo
           ciclo a faz nascer atrás do menu que ainda está saindo de cena. */
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            Diario.anotar("abrindo a caixa de confirmação")
            guard alerta.runModal() == .alertFirstButtonReturn else {
                Diario.anotar("cancelado na caixa")
                return
            }
            Diario.anotar("confirmado; executando")
            acao()
        }
    }

    /// TERM, quatro segundos de espera, e só então KILL. Processo travado —
    /// que é justamente o que se quer matar — não responde ao primeiro sinal;
    /// processo são fecha arquivo e salva o que tinha com o primeiro, e levar
    /// KILL de cara seria perder isso à toa.
    ///
    /// O sinal vai para o **trabalho**, não só para quem ouve a porta. Matar só
    /// quem ouve não resolvia: num `npm run dev` quem ouve é um neto, o pai o
    /// ressuscita — medido, a porta voltava com PID novo em 300ms — e o
    /// terminal nunca voltava ao prompt.
    private func encerrar(_ p: Porta, _ t: (plano: Plano, membros: [Elo])?) {
        fila.async { [weak self] in
            guard let self else { return }
            // Confere na hora: a lista pode ser de três segundos atrás, e nesse
            // tempo o processo pode ter morrido e o número ter sido reciclado.
            guard self.sonda.aindaDono(pid: p.pid, porta: p.numero) else {
                Diario.anotar("pid \(p.pid) já não é dono da \(p.numero); nada a fazer")
                DispatchQueue.main.async { self.varrer() }
                return
            }
            Diario.anotar("mandando TERM")
            let semPermissao = self.sinalizar(p, t, SIGTERM)
            for _ in 0..<8 {
                Thread.sleep(forTimeInterval: 0.5)
                if !self.sonda.ocupada(p.numero) { break }
            }
            if self.sonda.aindaDono(pid: p.pid, porta: p.numero) {
                Diario.anotar("não soltou em 4s; mandando KILL")
                self.sinalizar(p, t, SIGKILL)
                Thread.sleep(forTimeInterval: 0.5)
            }
            let ainda = self.sonda.ocupada(p.numero)
            Diario.anotar(ainda ? "AINDA OCUPADA a \(p.numero) — o encerramento falhou" : "porta \(p.numero) livre")
            // Antes a falha ia só para o log e o × parecia não fazer nada.
            let dono = ainda ? self.sonda.donoAgora(p.numero) : nil
            DispatchQueue.main.async {
                self.varrer()
                guard ainda else { return }
                if semPermissao {
                    self.avisar("A porta \(p.numero) é de outro usuário",
                                "O processo \(p.pid) não é seu (é do sistema ou do root), e o macOS não deixa um app comum encerrá-lo. No Terminal: sudo kill \(p.pid)")
                } else if let d = dono, d.pid != p.pid {
                    let texto = d.pai == "launchd"
                        ? "Encerrei, mas o próprio macOS (launchd) subiu de novo: costuma ser serviço do Homebrew (brew services stop …) ou um app que reinicia sozinho. Encerre quem o sobe, ou clique no × de novo."
                        : "Encerrei, mas o processo \(d.pai.isEmpty ? "pai" : d.pai) subiu outro (pid \(d.pid)). Encerre quem o sobe, ou clique no × de novo."
                    self.avisar("A porta \(p.numero) voltou a ser ocupada", texto)
                } else {
                    self.avisar("A porta \(p.numero) continua ocupada",
                                "Mandei encerrar e o processo \(p.pid) não soltou. No Terminal: kill -9 \(p.pid)")
                }
            }
        }
    }

    private func sinalizar(_ p: Porta, _ t: (plano: Plano, membros: [Elo])?, _ sinal: Int32) -> Bool {
        guard let t else { return kill(p.pid, sinal) != 0 && errno == EPERM }
        return sonda.sinalizar(t.plano, t.membros, sinal)
    }

    private func copiar() {
        var linhas = portas.map { p -> String in
            var t = String(format: "%-6d %@", p.numero, p.comoChamar)
            if p.doDocker { t += " (docker)" }
            t += "  ·  pid \(p.pid)"
            if let c = p.contexto { t += "  ·  \(c)" }
            return t
        }
        let livres = Pref.favoritas.filter { n in !portas.contains { $0.numero == n } }
        if !livres.isEmpty {
            linhas.append("")
            linhas.append("livres: " + livres.map(String.init).joined(separator: ", "))
        }
        if linhas.isEmpty { linhas = ["nenhuma porta ouvindo"] }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(linhas.joined(separator: "\n"), forType: .string)
    }

    private func pedirFavorita() {
        let alerta = NSAlert()
        alerta.messageText = t("Acompanhar qual porta?")
        alerta.informativeText = t("Ela aparece na lista de favoritas mesmo quando está livre.")
        let campo = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        campo.placeholderString = "3006"
        alerta.accessoryView = campo
        alerta.addButton(withTitle: t("Adicionar"))
        alerta.addButton(withTitle: t("Cancelar"))
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            alerta.window.initialFirstResponder = campo
            guard alerta.runModal() == .alertFirstButtonReturn,
                  let n = Int(campo.stringValue.trimmingCharacters(in: .whitespaces)),
                  n > 0, n < 65536 else { return }
            Pref.favoritas = Pref.favoritas + [n]
        }
    }

    /// O × da lista de memória. Aplicativo fecha como o Cmd+Q (ele salva e pergunta o que precisar); se não
    /// fechar em 5 s, oferece forçar. Processo solto vai como o das portas: o trabalho inteiro, TERM e depois KILL.
    private func confirmarFechar(_ g: Maquina.Gasto) {
        let alerta = NSAlert()
        if let caminho = g.app {
            alerta.messageText = t("Fechar o \(g.nome)?")
            alerta.informativeText = t("Como o Cmd+Q: ele fecha as janelas e pergunta se houver algo sem salvar. Usa \(Maquina.gb(g.bytes)) agora.")
            alerta.addButton(withTitle: t("Fechar"))
            alerta.addButton(withTitle: t("Cancelar"))
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                guard alerta.runModal() == .alertFirstButtonReturn else { return }
                let apps = NSWorkspace.shared.runningApplications.filter { $0.bundleURL?.path == caminho }
                Diario.anotar("fechar app \(g.nome): \(apps.count) instância(s)")
                apps.forEach { $0.terminate() }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) { [weak self] in
                    guard apps.contains(where: { !$0.isTerminated }) else { return }
                    DispatchQueue.main.async {
                        let forcar = NSAlert()
                        forcar.messageText = t("O \(g.nome) não fechou")
                        forcar.informativeText = t("Pode estar esperando uma resposta numa janela dele. Forçar fecha na hora e perde o que não foi salvo.")
                        forcar.addButton(withTitle: t("Forçar"))
                        forcar.addButton(withTitle: t("Esperar"))
                        NSApp.activate(ignoringOtherApps: true)
                        if forcar.runModal() == .alertFirstButtonReturn {
                            apps.forEach { $0.forceTerminate() }
                            Diario.anotar("app \(g.nome) forçado")
                        }
                        self?.varrer()
                    }
                }
            }
            return
        }
        let trab = sonda.trabalho(de: g.pid)
        alerta.messageText = t("Encerrar \(g.nome) (pid \(g.pid))?")
        var texto = t("Usa \(Maquina.gb(g.bytes)).")
        if let pasta = sonda.pastaDoProcesso(g.pid) { texto += "\n\(pasta)" }
        if let membros = trab?.membros, membros.count > 1 {
            texto += "\n\n" + t("Vão embora \(membros.count) processos do mesmo trabalho (como o Ctrl+C no terminal):") + "\n"
            texto += membros.map { "  · \($0.resumo)" }.joined(separator: "\n")
        }
        alerta.informativeText = texto
        alerta.addButton(withTitle: t("Encerrar"))
        alerta.addButton(withTitle: t("Cancelar"))
        alerta.buttons.first?.hasDestructiveAction = true
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            guard alerta.runModal() == .alertFirstButtonReturn else { return }
            self.encerrarProcesso(g.pid, nome: g.nome, trab)
        }
    }

    private func encerrarProcesso(_ pid: Int32, nome: String, _ t: (plano: Plano, membros: [Elo])?) {
        fila.async { [weak self] in
            guard let self else { return }
            let vivo = { kill(pid, 0) == 0 }
            Diario.anotar("encerrar processo \(nome) \(pid)")
            let semPermissao = t.map { self.sonda.sinalizar($0.plano, $0.membros, SIGTERM) }
                ?? (kill(pid, SIGTERM) != 0 && errno == EPERM)
            for _ in 0..<8 where vivo() { Thread.sleep(forTimeInterval: 0.5) }
            if vivo() {
                if let t { self.sonda.sinalizar(t.plano, t.membros, SIGKILL) } else { kill(pid, SIGKILL) }
                Thread.sleep(forTimeInterval: 0.5)
            }
            let ficou = vivo()
            DispatchQueue.main.async {
                self.varrer()
                if ficou {
                    self.avisar("O \(nome) continua aberto",
                                semPermissao ? "Ele não é seu (é do sistema ou do root). No Terminal: sudo kill \(pid)"
                                             : "Mandei encerrar e ele não saiu. No Terminal: kill -9 \(pid)")
                }
            }
        }
    }

    private func avisar(_ titulo: String, _ texto: String) {
        DispatchQueue.main.async {
            let a = NSAlert()
            a.messageText = t(titulo)
            a.informativeText = t(texto)
            a.addButton(withTitle: t("Entendi"))
            NSApp.activate(ignoringOtherApps: true)
            a.runModal()
        }
    }
}

@main
enum Inicio {
    static func main() {
        let app = NSApplication.shared
        let dono = Barra()
        app.delegate = dono
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
