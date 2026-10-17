// Quem mais esquentou o Mac nas últimas horas: o tempo de CPU que cada app (ou processo solto) gastou, somado
// minuto a minuto. A lista "O que mais usa" é a de agora; esta responde "o que pesou a tarde inteira?".
//
// Uma vez por minuto, um `ps` com o tempo de CPU acumulado de cada processo (o mesmo `ps` que o painel já usa,
// com outra coluna). A diferença entre um minuto e o outro é o que cada um gastou naquele minuto: pega até o build
// que durou 40 segundos entre duas leituras. Guarda só os maiores de cada minuto, por 6 horas.

import Foundation

struct QuemEsquentou {
    struct Quente: Identifiable, Equatable {
        var id: String { nome }
        let nome: String
        let app: String?
        /// Segundos de CPU somados (100% de um núcleo por 1 minuto = 60).
        let cpu: Double
        /// O maior uso de memória visto no período.
        let pico: Double
    }

    struct Grupo: Equatable {
        var cpu: Double
        var bytes: Double
        var app: String?
    }

    static let minutosGuardados = 360
    /// Quantos guardar por minuto: o resto gastou pouco e não chega ao topo.
    static let porMinuto = 12

    private var antes: [Int32: (cpu: Double, chave: String)] = [:]
    private var ultima: Date?
    /// Cada leitura com o tempo que ela cobre de verdade (60 s no app; o Mac dormindo pode esticar).
    private(set) var minutos: [(quando: Date, duracao: TimeInterval, grupos: [String: Grupo])] = []

    /// "416:39.44" (minutos:segundos) em segundos. Com hora ("1:02:03.4"), também.
    static func segundos(_ texto: Substring) -> Double? {
        var total = 0.0
        for parte in texto.split(separator: ":") {
            guard let v = Double(parte.replacingOccurrences(of: ",", with: ".")) else { return nil }
            total = total * 60 + v
        }
        return total
    }

    /// Uma leitura do `ps -axo time=,rss=,pid=,comm=`. A primeira só guarda o ponto de partida.
    mutating func anotar(_ saida: String, quando: Date) {
        var agora: [Int32: (cpu: Double, chave: String)] = [:]
        var grupos: [String: Grupo] = [:]
        let primeira = antes.isEmpty
        for linha in saida.split(separator: "\n") {
            let partes = linha.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard partes.count == 4, let cpu = Self.segundos(partes[0]), let kb = Double(partes[1]), let pid = Int32(partes[2])
            else { continue }
            let caminho = String(partes[3])
            if pid == Maquina.escondido { continue }
            var app: String?
            let chave: String
            if let fim = caminho.range(of: ".app/") {
                app = String(caminho[..<fim.lowerBound]) + ".app"
                chave = (app! as NSString).deletingPathExtension.split(separator: "/").last.map(String.init) ?? caminho
            } else {
                chave = (caminho as NSString).lastPathComponent
            }
            agora[pid] = (cpu, chave)
            // Processo novo desde a última leitura: tudo o que ele gastou foi neste minuto.
            let gasto: Double
            if let a = antes[pid], a.chave == chave { gasto = max(0, cpu - a.cpu) } else { gasto = primeira ? 0 : cpu }
            var g = grupos[chave] ?? Grupo(cpu: 0, bytes: 0, app: app)
            g.cpu += gasto
            g.bytes += kb * 1024
            grupos[chave] = g
        }
        antes = agora
        let desde = ultima
        ultima = quando
        guard !primeira, let desde else { return }
        let maiores = grupos.sorted { $0.value.cpu > $1.value.cpu }.prefix(Self.porMinuto).filter { $0.value.cpu > 0 }
        minutos.append((quando, max(0, quando.timeIntervalSince(desde)), Dictionary(uniqueKeysWithValues: maiores.map { ($0.key, $0.value) })))
        if minutos.count > Self.minutosGuardados { minutos.removeFirst(minutos.count - Self.minutosGuardados) }
    }

    /// Os que mais gastaram CPU no período guardado, e quanto tempo esse período cobre.
    func ranking(_ quantos: Int = 5) -> (lista: [Quente], periodo: TimeInterval) {
        var soma: [String: Grupo] = [:]
        for m in minutos {
            for (chave, g) in m.grupos {
                var s = soma[chave] ?? Grupo(cpu: 0, bytes: 0, app: g.app)
                s.cpu += g.cpu
                s.bytes = max(s.bytes, g.bytes)
                soma[chave] = s
            }
        }
        let lista = soma.sorted { $0.value.cpu > $1.value.cpu }.prefix(quantos)
            .map { Quente(nome: $0.key, app: $0.value.app, cpu: $0.value.cpu, pico: $0.value.bytes) }
        return (lista, minutos.map(\.duracao).reduce(0, +))
    }

    /// "40 s", "38 min", "2 h 5 min": curto, para caber na coluna sem cortar.
    static func tempo(_ segundos: Double) -> String {
        let m = Int(segundos / 60)
        if m < 1 { return "\(max(1, Int(segundos.rounded()))) s" }
        if m < 60 { return "\(m) min" }
        return t("\(m / 60) h \(m % 60) min")
    }
}
