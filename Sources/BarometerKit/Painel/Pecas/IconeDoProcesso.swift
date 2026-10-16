import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

/// O ícone de verdade do aplicativo (o do Finder); processo solto ganha o de terminal.
struct IconeDoProcesso: View {
    let app: String?

    /// O ícone do Finder vem num espaço de cor amplo, e com ele o desenho do painel como imagem saía todo
    /// clareado. Redesenhado uma vez em sRGB, 32 px, e guardado (no máximo 64, para não crescer sem fim).
    private static var guardados: [String: NSImage] = [:]
    static func emSRGB(_ caminho: String) -> NSImage {
        if let pronto = guardados[caminho] { return pronto }
        if guardados.count >= 64 { guardados.removeAll() }
        let original = doProprioApp(caminho) ?? NSWorkspace.shared.icon(forFile: caminho)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)?
            .retagging(with: .sRGB) else { return original }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        original.draw(in: NSRect(x: 0, y: 0, width: 32, height: 32))
        NSGraphicsContext.restoreGraphicsState()
        let img = NSImage(size: NSSize(width: 32, height: 32))
        img.addRepresentation(rep)
        guardados[caminho] = img
        return img
    }

    /// O ícone que o próprio app traz (o arquivo que o Info.plist aponta). O do Finder pode vir genérico por um
    /// tempo depois de instalar, enquanto o cache dele não atualiza: foi o que aconteceu com o Barometer.
    private static func doProprioApp(_ caminho: String) -> NSImage? {
        guard let pacote = Bundle(path: caminho), var nome = pacote.object(forInfoDictionaryKey: "CFBundleIconFile") as? String
        else { return nil }
        if !nome.hasSuffix(".icns") { nome += ".icns" }
        return pacote.resourcePath.flatMap { NSImage(contentsOfFile: ($0 as NSString).appendingPathComponent(nome)) }
    }

    var body: some View {
        if let app {
            Image(nsImage: IconeDoProcesso.emSRGB(app)).resizable().interpolation(.high)
                .frame(width: 15, height: 15)
        } else {
            Image(systemName: "terminal").font(.system(size: 9, weight: .medium)).foregroundStyle(Tinta.fraco)
                .frame(width: 15, height: 15)
                .background(RoundedRectangle(cornerRadius: 3.5).fill(Tinta.tinta.opacity(0.07)))
        }
    }
}
