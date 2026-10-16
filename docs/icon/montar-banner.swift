// Monta a imagem larga do topo do README: o Geral no centro, CPU e Memória dos lados, no mesmo cinza de fundo das
// fotos (que saem do `barometer --retrato`).
// Uso: swift docs/icon/montar-banner.swift <pasta-das-fotos> <saida.png> [centro esquerda direita]
import AppKit

let pasta = CommandLine.arguments[1]
func foto(_ nome: String) -> NSImage { NSImage(contentsOfFile: "\(pasta)/\(nome)")! }
let nomes = CommandLine.arguments.count >= 6 ? Array(CommandLine.arguments[3...5]) : ["overview.png", "cpu.png", "memory.png"]
let (centro, esquerda, direita) = (foto(nomes[0]), foto(nomes[1]), foto(nomes[2]))
let largura: CGFloat = 2400, altura: CGFloat = 1640
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(largura), pixelsHigh: Int(altura), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(srgbRed: 0.16, green: 0.16, blue: 0.16, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: largura, height: altura).fill()
func desenhar(_ img: NSImage, escala: CGFloat, centroX: CGFloat) {
    let w = img.size.width * escala, h = img.size.height * escala
    img.draw(in: NSRect(x: centroX - w / 2, y: (altura - h) / 2, width: w, height: h))
}
let escalaDoCentro = 1560 / centro.size.height
let larguraDoCentro = centro.size.width * escalaDoCentro
let escalaDosLados = escalaDoCentro * 0.84
let larguraDoLado = esquerda.size.width * escalaDosLados
desenhar(esquerda, escala: escalaDosLados, centroX: largura / 2 - larguraDoCentro / 2 - 10 - larguraDoLado / 2)
desenhar(direita, escala: escalaDosLados, centroX: largura / 2 + larguraDoCentro / 2 + 10 + larguraDoLado / 2)
desenhar(centro, escala: escalaDoCentro, centroX: largura / 2)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [.compressionFactor: 0.9])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
