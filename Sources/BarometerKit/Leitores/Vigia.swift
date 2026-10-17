// Os avisos: memória no limite, chip muito quente, disco quase cheio, bateria acabando e porta favorita que caiu.
// Tipo puro: recebe a leitura de 10 em 10 s e diz o que avisar. Quem manda a notificação é a `Barra`.
//
// Cada aviso só sai quando a condição dura um tempo (um pico de 2 s não é problema) e uma vez só: para avisar de
// novo, a condição tem de sumir (com folga, para não piscar no limite) e voltar.

import Foundation

enum Aviso: String, CaseIterable, Codable {
    case memoria, calor, disco, bateria, porta

    var nome: String {
        switch self {
        case .memoria: return t("Memória no limite")
        case .calor: return t("Chip acima de 95°")
        case .disco: return t("Disco com menos de 10% livre")
        case .bateria: return t("Bateria abaixo de 20%")
        case .porta: return t("Porta favorita que caiu")
        }
    }
}

struct LeituraDoVigia {
    var pressao = 1
    var chip: Double?
    var disco: (livre: Double, total: Double)?
    /// Nível de 0 a 100 e se está na tomada. Nil quando o Mac não tem bateria.
    var bateria: (nivel: Int, naTomada: Bool)?
    /// As favoritas com alguém ouvindo agora, e quem (para dizer quem caiu). Nil quando as portas não foram lidas.
    var portas: [Int: String]?
}

struct Disparo: Equatable {
    let aviso: Aviso
    let titulo: String
    let texto: String
    /// Para a notificação substituir a anterior do mesmo assunto.
    var id: String { aviso.rawValue + chave }
    var chave = ""
}

struct Vigia {
    /// Quantas leituras seguidas (de 10 s) a condição precisa durar.
    static let leiturasDaMemoria = 6
    static let leiturasDoCalor = 3

    var ligados: Set<Aviso> = []
    private var seguidas: [Aviso: Int] = [:]
    private var avisado: Set<Aviso> = []
    private var portasAntes: [Int: String]?

    init(ligados: Set<Aviso> = []) { self.ligados = ligados }

    mutating func olhar(_ l: LeituraDoVigia) -> [Disparo] {
        var saida: [Disparo] = []

        // Memória: pressão crítica (a vermelha do Monitor de Atividade) por 1 minuto; rearma quando volta ao normal.
        if condicao(.memoria, ativa: l.pressao >= 4, folga: l.pressao <= 1, leituras: Self.leiturasDaMemoria) != nil {
            saida.append(Disparo(aviso: .memoria, titulo: t("Memória no limite"),
                                 texto: t("O Mac está sem memória livre há 1 minuto. Fechar um app pesado ajuda.")))
        }
        if let chip = l.chip, condicao(.calor, ativa: chip >= 95, folga: chip < 85, leituras: Self.leiturasDoCalor) != nil {
            saida.append(Disparo(aviso: .calor, titulo: t("Chip muito quente"),
                                 texto: t("O chip está em \(Int(chip.rounded()))°. O Mac vai ficar mais lento para esfriar.")))
        }
        if let d = l.disco, d.total > 0 {
            let fracao = d.livre / d.total
            if condicao(.disco, ativa: fracao < 0.10, folga: fracao > 0.12, leituras: 1) != nil {
                saida.append(Disparo(aviso: .disco, titulo: t("Disco quase cheio"),
                                     texto: t("Restam \(Medida.espaco(d.livre)) livres.")))
            }
        }
        if let b = l.bateria {
            let ativa = b.nivel <= 20 && !b.naTomada
            if condicao(.bateria, ativa: ativa, folga: b.naTomada || b.nivel > 25, leituras: 1) != nil {
                saida.append(Disparo(aviso: .bateria, titulo: t("Bateria em \(b.nivel)%"), texto: t("Ligue o carregador.")))
            }
        }
        if let agora = l.portas {
            if ligados.contains(.porta), let antes = portasAntes {
                for (n, quem) in antes.sorted(by: { $0.key < $1.key }) where agora[n] == nil {
                    saida.append(Disparo(aviso: .porta, titulo: t("A porta \(n) caiu"),
                                         texto: t("\(quem) parou de ouvir nela."), chave: "\(n)"))
                }
            }
            portasAntes = agora
        }
        return saida
    }

    /// Conta as leituras seguidas com a condição ativa e diz quando avisar (uma vez). Rearma com a folga.
    private mutating func condicao(_ a: Aviso, ativa: Bool, folga: Bool, leituras: Int) -> Aviso? {
        guard ligados.contains(a) else { seguidas[a] = 0; avisado.remove(a); return nil }
        if folga { avisado.remove(a) }
        seguidas[a] = ativa ? (seguidas[a] ?? 0) + 1 : 0
        guard ativa, (seguidas[a] ?? 0) >= leituras, !avisado.contains(a) else { return nil }
        avisado.insert(a)
        return a
    }
}
