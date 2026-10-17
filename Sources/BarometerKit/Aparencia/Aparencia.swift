// Aparência: o fundo do painel (preto, fosco ou vidro líquido), quanto ele deixa ver atrás, as cores, os cantos,
// o jeito de mexer e o ícone colorido na barra. Tudo fica na aba Aparência e vale na hora, sem reabrir.
//
// O vidro líquido é o material do macOS 26 (`glassEffect`). Em Mac mais antigo, as duas opções de vidro
// aparecem apagadas e o painel fica no fosco.

import AppKit
import SwiftUI

struct Aparencia: Codable, Equatable {
    enum Fundo: String, Codable, CaseIterable {
        case solido, fosco, vidro, vidroClaro

        var nome: String {
            switch self {
            case .solido: return t("Sólido")
            case .fosco: return t("Fosco")
            case .vidro: return t("Vidro")
            case .vidroClaro: return t("Vidro claro")
            }
        }

        /// O vidro líquido só existe do macOS 26 em diante.
        var existe: Bool {
            switch self {
            case .solido, .fosco: return true
            case .vidro, .vidroClaro:
                if #available(macOS 26, *) { return true }
                return false
            }
        }

        /// Quanto o fundo cobre quando a pessoa ainda não mexeu: o sólido fecha, o vidro deixa ver.
        var coberturaPadrao: Double {
            switch self {
            case .solido: return 1
            case .fosco: return 0.55
            case .vidro: return 0.4
            case .vidroClaro: return 0.3
            }
        }
    }

    /// Claro, escuro, ou o do Mac (muda junto quando o macOS troca, à noite por exemplo).
    enum Modo: String, Codable, CaseIterable {
        case automatico, escuro, claro

        var nome: String {
            switch self {
            case .automatico: return t("Automático")
            case .escuro: return t("Escuro")
            case .claro: return t("Claro")
            }
        }
    }

    enum Movimento: String, Codable, CaseIterable {
        case suave, mola, nenhum

        var nome: String {
            switch self {
            case .suave: return t("Suave")
            case .mola: return t("Com mola")
            case .nenhum: return t("Sem animação")
            }
        }
    }

    var fundo: Fundo = .solido
    /// Quanto cada fundo cobre (1 = nada passa), guardado por fundo: trocar de vidro para sólido não perde o ajuste.
    var cobertura: [String: Double] = [:]
    var paleta: String = Paleta.padrao.id
    /// nil = a cor de destaque da paleta.
    var destaque: String?
    var cantos: Double = 14
    /// As cores de cada leitura quando a paleta é a personalizada (id da leitura → cor em hex, "FF9F45").
    var cores: [String: String] = [:]
    var movimento: Movimento = .suave
    var iconeColorido = false
    /// Cores chapadas: sem degradê, sem brilho e sem vidro nos botões.
    var chapado = false
    /// Cada aba e cada botão do painel com a cor dele (CPU laranja, memória azul…).
    var iconesColoridos = false
    var modo: Modo = .escuro

    /// O macOS está no escuro? A `Barra` acompanha a troca do sistema e atualiza aqui.
    nonisolated(unsafe) static var sistemaEscuro = true

    /// O painel está escuro agora (o modo escolhido, ou o do Mac no automático).
    var escuroAgora: Bool {
        switch modo {
        case .escuro: return true
        case .claro: return false
        case .automatico: return Aparencia.sistemaEscuro
        }
    }

    /// Quanto o fundo cobre. O sólido é sempre fechado: sem desfoque, o que passa por trás embaralha o texto (17/10);
    /// para ver atrás existem o fosco e o vidro.
    var coberturaAtual: Double {
        get { fundo == .solido ? 1 : (cobertura[fundo.rawValue] ?? fundo.coberturaPadrao) }
        set { if fundo != .solido { cobertura[fundo.rawValue] = min(1, max(0.1, newValue)) } }
    }

    /// O fundo que de fato aparece: vidro em Mac sem vidro vira fosco.
    var fundoReal: Fundo { fundo.existe ? fundo : .fosco }

    var paletaAtual: Paleta {
        if paleta == Paleta.personalizadaId { return Paleta.personalizada(cores) }
        return Paleta.todas.first { $0.id == paleta } ?? .padrao
    }

    /// Igual a outra tirando o modo: os estilos tratam de cores e fundo, o modo é escolha à parte.
    func igualTirandoModo(_ outra: Aparencia) -> Bool {
        var a = self, b = outra
        a.modo = .escuro; b.modo = .escuro
        return a == b
    }

    var corDeDestaque: Color {
        if let destaque, let cor = Paleta.destaques.first(where: { $0.id == destaque }) { return cor.cor }
        return paletaAtual.paraOModo(escuro: escuroAgora).destaque
    }

    /// O que muda as cores do painel inteiro: quando muda, o painel se redesenha de cima a baixo.
    var chaveDasCores: String {
        paleta + "-" + (destaque ?? "") + (escuroAgora ? "-escuro" : "-claro") + (chapado ? "-chapado" : "")
            + (iconesColoridos ? "-icones" : "")
            + (paleta == Paleta.personalizadaId ? "-" + cores.sorted { $0.key < $1.key }.map { $0.value }.joined() : "")
    }

    /// A aparência em uso, para as cores (`Tinta`) e as animações (`Mexer`), que não recebem o `Estado`.
    static var atual: Aparencia = Pref.aparencia

    /// Decodifica campo a campo: campo novo de uma versão nova não apaga o que a pessoa já tinha escolhido.
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        fundo = (try? c.decode(Fundo.self, forKey: .fundo)) ?? .solido
        cobertura = (try? c.decode([String: Double].self, forKey: .cobertura)) ?? [:]
        paleta = (try? c.decode(String.self, forKey: .paleta)) ?? Paleta.padrao.id
        destaque = try? c.decode(String.self, forKey: .destaque)
        cantos = (try? c.decode(Double.self, forKey: .cantos)) ?? 14
        cores = (try? c.decode([String: String].self, forKey: .cores)) ?? [:]
        movimento = (try? c.decode(Movimento.self, forKey: .movimento)) ?? .suave
        iconeColorido = (try? c.decode(Bool.self, forKey: .iconeColorido)) ?? false
        modo = (try? c.decode(Modo.self, forKey: .modo)) ?? .escuro
        chapado = (try? c.decode(Bool.self, forKey: .chapado)) ?? false
        iconesColoridos = (try? c.decode(Bool.self, forKey: .iconesColoridos)) ?? false
    }
}
