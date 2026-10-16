import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

/// Duas barrinhas, CPU e memória, que sobem e descem com o uso, e o número de
/// portas ao lado. Imagem "modelo" (só a forma): o macOS pinta de branco ou
/// preto conforme o fundo da barra.
enum Icone {
    /// Um item da barra: o ícone (ou as barrinhas), o número e a cor dele no ícone colorido.
    struct Pedaco {
        let simbolo: String?
        let texto: String
        let barrinhas: (Double, Double)?
        let cor: Color?
        init(_ simbolo: String?, _ texto: String, _ barrinhas: (Double, Double)?, cor: Color?) {
            self.simbolo = simbolo; self.texto = texto; self.barrinhas = barrinhas; self.cor = cor
        }
    }

    /// A barra de menus inteira numa imagem só (os ícones e os números). Texto em pedaços com imagem anexada não
    /// acompanha a cor da barra; uma imagem só acompanha.
    /// Colorido: os ícones e as barrinhas com as cores da paleta, e o texto na cor da barra (branco ou preto).
    /// Sem cor, a imagem é "modelo" e o macOS pinta tudo de uma cor só.
    static func barra(_ pedacos: [Pedaco], colorido: Bool = false) -> NSImage {
        let fonte = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let configuracao = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let medir: [NSAttributedString.Key: Any] = [.font: fonte]
        var largura: CGFloat = 0
        var medidas: [(NSImage?, CGFloat, CGFloat)] = []
        for p in pedacos {
            var config = configuracao
            if colorido, let cor = p.cor { config = config.applying(.init(paletteColors: [NSColor(cor)])) }
            let simbolo = p.barrinhas != nil ? nil : p.simbolo.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil)?.withSymbolConfiguration(config) }
            let larguraDoIcone: CGFloat = p.barrinhas != nil ? 14 : (simbolo.map { $0.size.width * 14 / max($0.size.height, 1) } ?? 0)
            let larguraDoTexto = p.texto.isEmpty ? 0 : (p.texto as NSString).size(withAttributes: medir).width
            medidas.append((simbolo, larguraDoIcone, larguraDoTexto))
            largura += larguraDoIcone + (larguraDoTexto > 0 ? 3 + larguraDoTexto : 0)
        }
        largura += CGFloat(max(0, pedacos.count - 1)) * 9
        let img = NSImage(size: NSSize(width: max(16, ceil(largura)), height: 18), flipped: false) { _ in
            // Desenhado na hora de aparecer: o `labelColor` já é o da barra (claro ou escuro).
            let atributos: [NSAttributedString.Key: Any] = [.font: fonte, .foregroundColor: colorido ? NSColor.labelColor : NSColor.black]
            var x: CGFloat = 0
            for (i, p) in pedacos.enumerated() {
                let (simbolo, larguraDoIcone, larguraDoTexto) = medidas[i]
                if let (cpu, memoria) = p.barrinhas {
                    desenharBarrinhas(em: NSRect(x: x, y: 2, width: 14, height: 14), cpu: cpu, memoria: memoria,
                                      cores: colorido ? (NSColor(Tinta.cpu), NSColor(Tinta.memoria)) : nil)
                } else if let simbolo {
                    let altura: CGFloat = 14
                    simbolo.draw(in: NSRect(x: x, y: (18 - altura) / 2, width: larguraDoIcone, height: altura))
                }
                x += larguraDoIcone
                if larguraDoTexto > 0 {
                    (p.texto as NSString).draw(at: NSPoint(x: x + 3, y: (18 - fonte.capHeight) / 2 - 2.5), withAttributes: atributos)
                    x += 3 + larguraDoTexto
                }
                x += 9
            }
            return true
        }
        img.isTemplate = !colorido
        return img
    }

    private static func desenharBarrinhas(em r: NSRect, cpu: Double, memoria: Double, cores: (NSColor, NSColor)? = nil) {
        for (i, v) in [cpu, memoria].enumerated() {
            let x = r.minX + 2 + CGFloat(i) * 6
            let cor = cores.map { i == 0 ? $0.0 : $0.1 } ?? NSColor.black
            (cores == nil ? NSColor.black.withAlphaComponent(0.32) : NSColor.labelColor.withAlphaComponent(0.25)).setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: r.minY, width: 3.6, height: r.height - 2), xRadius: 1.8, yRadius: 1.8).fill()
            cor.setFill()
            let altura = max(2.5, (r.height - 2) * CGFloat(min(1, max(0, v))))
            NSBezierPath(roundedRect: NSRect(x: x, y: r.minY, width: 3.6, height: altura), xRadius: 1.8, yRadius: 1.8).fill()
        }
    }

    static func desenhar(cpu: Double, memoria: Double, mostrarUso: Bool) -> NSImage {
        let largura: CGFloat = mostrarUso ? 15 : 16
        let img = NSImage(size: NSSize(width: largura, height: 16), flipped: false) { _ in
            NSColor.black.setFill()
            NSColor.black.setStroke()
            if mostrarUso {
                // Trilho apagado (35%) e o nível cheio: a forma dá para ler mesmo a 16 px.
                for (i, v) in [cpu, memoria].enumerated() {
                    let x: CGFloat = 3 + CGFloat(i) * 6
                    NSColor.black.withAlphaComponent(0.32).setFill()
                    NSBezierPath(roundedRect: NSRect(x: x, y: 2, width: 3.6, height: 12), xRadius: 1.8, yRadius: 1.8).fill()
                    NSColor.black.setFill()
                    let altura = max(2.5, 12 * CGFloat(min(1, max(0, v))))
                    NSBezierPath(roundedRect: NSRect(x: x, y: 2, width: 3.6, height: altura), xRadius: 1.8, yRadius: 1.8).fill()
                }
            } else {
                // Sem o uso: um anel com um ponto, a "porta".
                let anel = NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 12, height: 12))
                anel.lineWidth = 1.6
                anel.stroke()
                NSBezierPath(ovalIn: NSRect(x: 6, y: 6, width: 4, height: 4)).fill()
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}
