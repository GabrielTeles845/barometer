// Idiomas: inglês, português e espanhol. O código escreve em português e passa pelo `t()`, que devolve a frase
// no idioma escolhido (o do Mac, ou o que a pessoa escolheu na engrenagem).
//
// Frase com número no meio ("217 GB livres") vale como padrão: "%1 livres" casa com qualquer coisa no lugar do %1
// e a tradução põe o mesmo pedaço no mesmo lugar ("217 GB free"). Assim cada tela continua escrevendo a frase
// inteira, sem montar pedaço por pedaço.

import Foundation

enum Idioma: String, CaseIterable {
    case automatico, en, pt, es

    var nome: String {
        switch self {
        case .automatico: return t("Automático (o do Mac)")
        case .en: return "English"
        case .pt: return "Português"
        case .es: return "Español"
        }
    }

    /// O idioma em uso: o escolhido, ou o primeiro do Mac que o app fala (inglês quando nenhum).
    /// Para a foto (`--retrato --idioma en`): passa por cima do escolhido e do Mac.
    nonisolated(unsafe) static var forcado: Idioma?

    static var atual: Idioma {
        if let forcado { return forcado }
        let escolhido = Idioma(rawValue: Pref.armazem.string(forKey: "idioma") ?? "") ?? .automatico
        if escolhido != .automatico { return escolhido }
        for codigo in Locale.preferredLanguages {
            if codigo.hasPrefix("pt") { return .pt }
            if codigo.hasPrefix("es") { return .es }
            if codigo.hasPrefix("en") { return .en }
        }
        return .en
    }

    static var escolhido: Idioma {
        get { Idioma(rawValue: Pref.armazem.string(forKey: "idioma") ?? "") ?? .automatico }
        set { Pref.armazem.set(newValue.rawValue, forKey: "idioma") }
    }
}

/// Número com a vírgula ou o ponto do idioma: "8,9" em português e espanhol, "8.9" em inglês.
func decimal(_ v: Double, casas: Int = 1, em idioma: Idioma = Idioma.atual) -> String {
    let texto = String(format: "%.\(casas)f", v)
    return idioma == .en ? texto : texto.replacingOccurrences(of: ".", with: ",")
}

/// Milhar com o separador do idioma: "5.786" em português e espanhol, "5,786" em inglês.
func milhar(_ n: Int, em idioma: Idioma = Idioma.atual) -> String {
    guard n >= 1000 else { return String(n) }
    return "\(n / 1000)\(idioma == .en ? "," : ".")\(String(format: "%03d", n % 1000))"
}

/// A frase no idioma em uso. O português é a chave.
func t(_ frase: String) -> String { t(frase, em: Idioma.atual) }

/// A frase num idioma escolhido. Sem tradução, fica em português (melhor que vazio).
func t(_ frase: String, em idioma: Idioma) -> String {
    idioma == .pt ? frase : (Traducao.traduzir(frase, para: idioma) ?? frase)
}
