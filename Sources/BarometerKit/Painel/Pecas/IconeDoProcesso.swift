import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

/// O ícone de verdade do aplicativo (o do Finder); processo solto ganha o de terminal.
struct IconeDoProcesso: View {
    let app: String?

    /// O ícone do Finder vem num espaço de cor amplo, e com ele o desenho do painel como imagem saía todo
    /// clareado. Redesenhado uma vez em sRGB, 32 px, e guardado.
    private static var guardados: [String: NSImage] = [:]
    static func emSRGB(_ caminho: String) -> NSImage {
        if let pronto = guardados[caminho] { return pronto }
        let original = NSWorkspace.shared.icon(forFile: caminho)
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
