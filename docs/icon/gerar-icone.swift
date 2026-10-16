// Desenha o ícone do Barometer (1024 px): o quadrado arredondado do macOS em preto, com as duas barrinhas da
// barra de menus (CPU em laranja, memória em azul) e um anel fino, o "mostrador".
// Uso: swift docs/icon/gerar-icone.swift saida.png
import AppKit

let lado: CGFloat = 1024
let img = NSImage(size: NSSize(width: lado, height: lado), flipped: false) { _ in
    // Fundo: o quadrado do macOS (824 px dentro de 1024, cantos de 185), com um leve degradê e borda clara.
    let quadro = NSRect(x: 100, y: 100, width: 824, height: 824)
    let forma = NSBezierPath(roundedRect: quadro, xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let sombra = NSShadow()
    sombra.shadowColor = NSColor.black.withAlphaComponent(0.45)
    sombra.shadowBlurRadius = 28
    sombra.shadowOffset = NSSize(width: 0, height: -12)
    sombra.set()
    NSColor.black.setFill()
    forma.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [NSColor(white: 0.13, alpha: 1), NSColor(white: 0.03, alpha: 1)])!.draw(in: forma, angle: -90)
    NSColor.white.withAlphaComponent(0.10).setStroke()
    forma.lineWidth = 4
    forma.stroke()

    // O anel: um mostrador quase fechado, em cinza, atrás das barras.
    let centro = NSPoint(x: 512, y: 512)
    let anel = NSBezierPath()
    anel.appendArc(withCenter: centro, radius: 292, startAngle: 225, endAngle: -45, clockwise: true)
    anel.lineWidth = 34
    anel.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.10).setStroke()
    anel.stroke()
    let ponteiro = NSBezierPath()
    ponteiro.appendArc(withCenter: centro, radius: 292, startAngle: 225, endAngle: 40, clockwise: true)
    ponteiro.lineWidth = 34
    ponteiro.lineCapStyle = .round
    NSColor(red: 0.42, green: 0.9, blue: 0.45, alpha: 1).setStroke()
    ponteiro.stroke()

    // As duas barrinhas, como na barra de menus.
    func barra(x: CGFloat, nivel: CGFloat, cor: NSColor) {
        let trilho = NSRect(x: x, y: 330, width: 104, height: 360)
        NSColor.white.withAlphaComponent(0.12).setFill()
        NSBezierPath(roundedRect: trilho, xRadius: 52, yRadius: 52).fill()
        let cheio = NSRect(x: x, y: 330, width: 104, height: 360 * nivel)
        NSGradient(colors: [cor.withAlphaComponent(0.75), cor])!.draw(in: NSBezierPath(roundedRect: cheio, xRadius: 52, yRadius: 52), angle: 90)
    }
    barra(x: 380, nivel: 0.55, cor: NSColor(red: 1.0, green: 0.62, blue: 0.27, alpha: 1))
    barra(x: 540, nivel: 0.82, cor: NSColor(red: 0.36, green: 0.62, blue: 1.0, alpha: 1))
    return true
}
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: 1024, height: 1024)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
img.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
