// O que dá para fechar: apps abertos e parados há tempo, e servidores ligados há muito tempo (o `npm run dev` de
// ontem). Só sugere; quem fecha é a pessoa, pelo × de sempre, que confirma antes.

import Foundation

struct Sugestao: Identifiable {
    enum Tipo {
        case app(Maquina.Gasto)
        case porta(Porta)
    }

    let id: String
    let nome: String
    /// Há quanto tempo está parado (app) ou ligado (servidor).
    let tempo: TimeInterval
    let bytes: Double?
    let tipo: Tipo
}

enum Sugestoes {
    struct AppAberto {
        let caminho: String
        let nome: String
        let ultimoUso: Date
    }

    /// App sem uso há mais de 1 hora entra na lista.
    static let appParado: TimeInterval = 3600
    /// Servidor ligado há mais de 12 horas entra na lista.
    static let servidorAntigo: TimeInterval = 12 * 3600
    static let maximo = 5

    /// Os apps parados há mais de `appParado`, os que mais ocupam memória primeiro. A memória vem da lista de
    /// quem mais gasta (o app com todos os ajudantes dele); app que não está nela não entra (gasta pouco).
    static func apps(_ abertos: [AppAberto], gastos: [Maquina.Gasto], agora: Date) -> [Sugestao] {
        let porCaminho = Dictionary(gastos.compactMap { g in g.app.map { ($0, g) } }, uniquingKeysWith: { a, _ in a })
        return abertos.compactMap { app -> Sugestao? in
            let parado = agora.timeIntervalSince(app.ultimoUso)
            guard parado >= appParado, let g = porCaminho[app.caminho], g.meu else { return nil }
            return Sugestao(id: "app:" + app.caminho, nome: app.nome, tempo: parado, bytes: g.bytes, tipo: .app(g))
        }
        .sorted { ($0.bytes ?? 0) > ($1.bytes ?? 0) }
        .prefix(maximo).map { $0 }
    }

    /// As portas de processos ligados há mais de `servidorAntigo`, os mais velhos primeiro. Docker fica de fora
    /// (container costuma ser de propósito).
    static func servidores(_ portas: [Porta], inicio: (Int32) -> Date?, agora: Date) -> [Sugestao] {
        portas.compactMap { p -> Sugestao? in
            guard !p.doDocker, let comeco = inicio(p.pid) else { return nil }
            let ligado = agora.timeIntervalSince(comeco)
            guard ligado >= servidorAntigo else { return nil }
            return Sugestao(id: "porta:\(p.numero)", nome: "\(p.numero) " + (p.projeto ?? p.comando), tempo: ligado,
                            bytes: nil, tipo: .porta(p))
        }
        .sorted { $0.tempo > $1.tempo }
        .prefix(maximo).map { $0 }
    }
}
