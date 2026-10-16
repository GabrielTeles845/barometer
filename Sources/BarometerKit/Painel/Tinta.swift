import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

enum Tinta {
    static let fundo = Color(red: 0.035, green: 0.035, blue: 0.04)
    static let cartao = Color.white.opacity(0.045)
    static let borda = Color.white.opacity(0.08)
    static let texto = Color.white.opacity(0.92)
    static let apagado = Color.white.opacity(0.5)
    static let fraco = Color.white.opacity(0.3)
    static let calor = Color(red: 1.0, green: 0.36, blue: 0.36)
    // As cores das leituras vêm da paleta escolhida na aba Aparência.
    private static var paleta: Paleta { Aparencia.atual.paletaAtual }
    static var memoria: Color { paleta.memoria }
    static var cpu: Color { paleta.cpu }
    static var porta: Color { paleta.porta }
    static var fixa: Color { paleta.fixa }
    static var eficiencia: Color { paleta.eficiencia }
    static var gpu: Color { paleta.gpu }
    static var disco: Color { paleta.disco }
    static var comprimida: Color { paleta.comprimida }
    static var bateria: Color { paleta.bateria }
    /// Interruptores, o que está escolhido e os marcadores.
    static var destaque: Color { Aparencia.atual.corDeDestaque }

    static func pressao(_ n: Int) -> Color { n >= 4 ? calor : (n >= 2 ? cpu : porta) }
}
