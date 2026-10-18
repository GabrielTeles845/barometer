// A Limpeza não entra nas pastas da Apple dentro dos caches: o macOS pergunta pelo Apple Music só de abrir
// `com.apple.Music` (18/10).

import Foundation
import Testing
@testable import BarometerKit

@Suite("Limpeza")
struct LimpezaTests {
    @Test("Pasta da Apple fica fora da medida e da limpeza")
    func pulaPastaDaApple() throws {
        let fm = FileManager.default
        let raiz = fm.temporaryDirectory.appendingPathComponent("limpeza-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: raiz) }
        let musica = raiz.appendingPathComponent("com.apple.Music")
        let outro = raiz.appendingPathComponent("com.exemplo.app")
        try fm.createDirectory(at: musica, withIntermediateDirectories: true)
        try fm.createDirectory(at: outro, withIntermediateDirectories: true)
        try Data(count: 64_000).write(to: musica.appendingPathComponent("a"))
        try Data(count: 64_000).write(to: outro.appendingPathComponent("b"))

        let medida = try #require(Limpeza.tamanho(raiz))
        #expect(medida >= 64_000 && medida < 128_000)

        _ = Limpeza.limpar(ItemDeLimpeza(id: "caches", nome: "", explicacao: "", pasta: raiz))
        #expect(fm.fileExists(atPath: musica.appendingPathComponent("a").path))
        #expect(!fm.fileExists(atPath: outro.path))
    }
}
