import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

enum Aba: String, CaseIterable {
    case geral, cpu, memoria, gpu, disco, bateria, portas, limpeza, aparencia

    var titulo: String { t(tituloEmPortugues) }

    private var tituloEmPortugues: String {
        switch self {
        case .geral: return "Geral"
        case .cpu: return "CPU"
        case .memoria: return "Memória"
        case .gpu: return "GPU"
        case .disco: return "Disco"
        case .bateria: return "Bateria"
        case .portas: return "Portas"
        case .limpeza: return "Limpeza"
        case .aparencia: return "Aparência"
        }
    }

    var simbolo: String {
        switch self {
        case .geral: return "square.grid.2x2"
        case .cpu: return "cpu"
        case .memoria: return "memorychip"
        case .gpu: return "cube.transparent"
        case .disco: return "internaldrive"
        case .bateria: return "battery.75percent"
        case .portas: return "point.3.connected.trianglepath.dotted"
        case .limpeza: return "trash"
        case .aparencia: return "paintpalette"
        }
    }

    /// A cor do ícone com "ícones coloridos" ligado: a cor da leitura de cada aba.
    var cor: Color {
        switch self {
        case .geral, .aparencia: return Tinta.destaque
        case .cpu: return Tinta.cpu
        case .memoria: return Tinta.memoria
        case .gpu: return Tinta.gpu
        case .disco: return Tinta.disco
        case .bateria: return Tinta.bateria
        case .portas: return Tinta.porta
        case .limpeza: return Tinta.calor
        }
    }
}

/// O que pode aparecer na barra de menus, até 3 de uma vez, cada um com o seu ícone.
enum ItemDaBarra: String, CaseIterable, Codable {
    case barrinhas, cpu, memoria, gpu, chip, bateria, disco, portas

    var nome: String {
        switch self {
        case .barrinhas: return t("CPU + RAM")
        case .cpu: return "CPU"
        case .memoria: return t("Memória")
        case .gpu: return "GPU"
        case .chip: return t("Temperatura do chip")
        case .bateria: return t("Bateria")
        case .disco: return t("Disco livre")
        case .portas: return t("Portas abertas")
        }
    }

    var simbolo: String {
        switch self {
        case .barrinhas: return "chart.bar.fill"
        case .cpu: return "cpu"
        case .memoria: return "memorychip"
        case .gpu: return "cube.transparent"
        case .chip: return "thermometer.medium"
        case .bateria: return "battery.75percent"
        case .disco: return "internaldrive"
        case .portas: return "point.3.connected.trianglepath.dotted"
        }
    }

    /// A cor no ícone colorido.
    var cor: Color? {
        switch self {
        case .barrinhas: return nil
        case .cpu: return Tinta.cpu
        case .memoria: return Tinta.memoria
        case .gpu: return Tinta.gpu
        case .chip: return Tinta.calor
        case .bateria: return Tinta.bateria
        case .disco: return Tinta.disco
        case .portas: return Tinta.porta
        }
    }

    static let maximo = 3
    static let padrao: [ItemDaBarra] = [.barrinhas, .portas]
}

/// Um cartão do Geral.
struct ItemGeral: Identifiable, Codable, Equatable {
    let id: String
    var ligado: Bool

    var nome: String { t(ItemGeral.nomes[id] ?? id) }

    static let nomes: [String: String] = [
        "aneis": "Visão rápida", "grafico": "Histórico", "disco": "Disco", "bateria": "Bateria",
        "memoria": "Memória por partes", "cpu": "Núcleos da CPU", "gpu": "GPU", "temperaturas": "Temperaturas",
        "processos": "O que mais usa", "portas": "Portas", "limpeza": "Limpeza",
    ]
    /// A ordem e o que vem ligado na primeira vez.
    static let padrao: [ItemGeral] = [
        .init(id: "aneis", ligado: true), .init(id: "grafico", ligado: true), .init(id: "disco", ligado: true),
        .init(id: "bateria", ligado: true), .init(id: "memoria", ligado: true), .init(id: "processos", ligado: true),
        .init(id: "portas", ligado: true), .init(id: "cpu", ligado: false), .init(id: "gpu", ligado: false),
        .init(id: "temperaturas", ligado: false), .init(id: "limpeza", ligado: false),
    ]
}
