import AppKit
import SwiftUI

/// As cores de cada leitura. O vermelho do calor não muda: é aviso, e aviso tem de continuar parecendo aviso.
struct Paleta: Identifiable {
    let id: String
    let nome: String
    let cpu: Color
    let memoria: Color
    let gpu: Color
    let disco: Color
    let bateria: Color
    let porta: Color
    let fixa: Color
    let eficiencia: Color
    let comprimida: Color
    let destaque: Color

    private static func c(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }

    /// "FF9F45" → cor. Texto que não é cor dá nil.
    static func cor(hex: String) -> Color? {
        guard hex.count == 6, let n = UInt32(hex, radix: 16) else { return nil }
        return c(n)
    }

    // MARK: A personalizada

    static let personalizadaId = "personalizada"

    /// As leituras que a pessoa pinta, na ordem do editor.
    static let pintaveis: [(id: String, nome: String)] = [
        ("cpu", "CPU"), ("memoria", "Memória"), ("gpu", "GPU"), ("disco", "Disco"), ("bateria", "Bateria"), ("porta", "Portas"),
    ]

    /// As cores para escolher, uma fileira por leitura.
    static let amostras = ["FF9F45", "FF5F5F", "FF6FAE", "C77DFF", "7F9CFF", "4C9BFF", "3FD4E0", "5AD99A", "B5E35A", "FFD54A"]

    /// A paleta das cores escolhidas; o que não foi escolhido fica como na padrão.
    static func personalizada(_ cores: [String: String]) -> Paleta {
        func pega(_ id: String, _ reserva: Color) -> Color { cores[id].flatMap(cor(hex:)) ?? reserva }
        let p = padrao
        return Paleta(id: personalizadaId, nome: "Personalizada", cpu: pega("cpu", p.cpu), memoria: pega("memoria", p.memoria),
                      gpu: pega("gpu", p.gpu), disco: pega("disco", p.disco), bateria: pega("bateria", p.bateria),
                      porta: pega("porta", p.porta), fixa: p.fixa, eficiencia: p.eficiencia, comprimida: p.comprimida,
                      destaque: pega("porta", p.destaque))
    }

    /// As cores de partida do editor: as da paleta que a pessoa está vendo, na amostra mais parecida.
    static func coresDePartida(de p: Paleta) -> [String: String] {
        let fontes: [String: Color] = ["cpu": p.cpu, "memoria": p.memoria, "gpu": p.gpu, "disco": p.disco, "bateria": p.bateria, "porta": p.porta]
        return fontes.mapValues { maisParecida($0) }
    }

    private static func maisParecida(_ cor: Color) -> String {
        let alvo = NSColor(cor).usingColorSpace(.sRGB)
        func distancia(_ hex: String) -> Double {
            guard let a = alvo, let b = Paleta.cor(hex: hex).flatMap({ NSColor($0).usingColorSpace(.sRGB) }) else { return .infinity }
            return pow(a.redComponent - b.redComponent, 2) + pow(a.greenComponent - b.greenComponent, 2) + pow(a.blueComponent - b.blueComponent, 2)
        }
        return amostras.min { distancia($0) < distancia($1) } ?? amostras[0]
    }

    static let padrao = Paleta(
        id: "padrao", nome: "Padrão",
        cpu: Color(red: 1.0, green: 0.62, blue: 0.27), memoria: Color(red: 0.36, green: 0.62, blue: 1.0),
        gpu: Color(red: 0.78, green: 0.45, blue: 1.0), disco: Color(red: 0.4, green: 0.86, blue: 0.62),
        bateria: Color(red: 0.42, green: 0.9, blue: 0.45), porta: Color(red: 0.35, green: 0.85, blue: 0.6),
        fixa: Color(red: 0.66, green: 0.5, blue: 1.0), eficiencia: Color(red: 0.32, green: 0.83, blue: 0.86),
        comprimida: Color(red: 1.0, green: 0.82, blue: 0.36), destaque: Color(red: 0.35, green: 0.85, blue: 0.6))

    static let todas: [Paleta] = [
        padrao,
        Paleta(id: "neon", nome: "Neon", cpu: c(0xFF6A2B), memoria: c(0x2F8CFF), gpu: c(0xD04DFF), disco: c(0x12F0A8),
               bateria: c(0x8CFF3F), porta: c(0x12F0A8), fixa: c(0xA35CFF), eficiencia: c(0x00E5FF),
               comprimida: c(0xFFE433), destaque: c(0x12F0A8)),
        Paleta(id: "pastel", nome: "Pastel", cpu: c(0xFFB894), memoria: c(0xA3C8FF), gpu: c(0xD9BBFF), disco: c(0xA9E7CB),
               bateria: c(0xBDE9A6), porta: c(0xA3E3C8), fixa: c(0xCBB9FF), eficiencia: c(0xA9E4EA),
               comprimida: c(0xFFE2A6), destaque: c(0xA3C8FF)),
        Paleta(id: "oceano", nome: "Oceano", cpu: c(0xFFA26E), memoria: c(0x4FC3F7), gpu: c(0x7F9CFF), disco: c(0x26C6DA),
               bateria: c(0x4DD0B1), porta: c(0x4DD0E1), fixa: c(0x8C9EFF), eficiencia: c(0x84E1EC),
               comprimida: c(0xFFD180), destaque: c(0x4FC3F7)),
        Paleta(id: "entardecer", nome: "Entardecer", cpu: c(0xFF7A59), memoria: c(0xFF5C93), gpu: c(0xC77DFF), disco: c(0xFFB547),
               bateria: c(0xFFD166), porta: c(0xFF9E7A), fixa: c(0xE0609F), eficiencia: c(0xFFC07A),
               comprimida: c(0xFFE08A), destaque: c(0xFF7A59)),
        Paleta(id: "mono", nome: "Grafite", cpu: Color(white: 0.92), memoria: Color(white: 0.72), gpu: Color(white: 0.58),
               disco: Color(white: 0.82), bateria: Color(white: 0.88), porta: Color(white: 0.9), fixa: Color(white: 0.5),
               eficiencia: Color(white: 0.66), comprimida: Color(white: 0.42), destaque: Color(white: 0.92)),
    ]

    /// No modo claro, a Grafite (toda em cinza claro) sumiria no fundo branco: vira cinza escuro. As outras ficam.
    func paraOModo(escuro: Bool) -> Paleta {
        guard !escuro, id == "mono" else { return self }
        return Paleta(id: id, nome: nome, cpu: Color(white: 0.15), memoria: Color(white: 0.35), gpu: Color(white: 0.5),
                      disco: Color(white: 0.25), bateria: Color(white: 0.2), porta: Color(white: 0.18), fixa: Color(white: 0.55),
                      eficiencia: Color(white: 0.42), comprimida: Color(white: 0.62), destaque: Color(white: 0.15))
    }

    /// A cor dos interruptores, do que está escolhido e dos marcadores. "Da paleta" fica de fora (é o nil).
    struct Destaque: Identifiable {
        let id: String
        let cor: Color
    }

    static let destaques: [Destaque] = [
        .init(id: "verde", cor: c(0x5AD99A)), .init(id: "azul", cor: c(0x4C9BFF)), .init(id: "ciano", cor: c(0x3FD4E0)),
        .init(id: "roxo", cor: c(0xA77BFF)), .init(id: "rosa", cor: c(0xFF6FAE)), .init(id: "vermelho", cor: c(0xFF5F5F)),
        .init(id: "laranja", cor: c(0xFF9F45)), .init(id: "amarelo", cor: c(0xFFD54A)),
    ]
}
