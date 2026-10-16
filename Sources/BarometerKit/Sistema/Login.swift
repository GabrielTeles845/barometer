import AppKit
import Combine
import IOKit
import ServiceManagement
import SwiftUI

/// O LaunchAgent que abre o app ao entrar na conta. `open -a` e não o binário
/// direto: assim o macOS abre o app como app (uma instância só), e o caminho
/// continua certo depois de reinstalar por cima.
enum Login {
    static let arquivo = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/com.gabrielteles.barometer.plist")
    static var ligado: Bool { FileManager.default.fileExists(atPath: arquivo.path) }

    static func ligar() throws {
        let plist: [String: Any] = [
            "Label": "com.gabrielteles.barometer",
            "ProgramArguments": ["/usr/bin/open", "-a", Bundle.main.bundlePath],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
        ]
        let dados = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: arquivo.deletingLastPathComponent(), withIntermediateDirectories: true)
        try dados.write(to: arquivo)
    }

    static func desligar() throws {
        if ligado { try FileManager.default.removeItem(at: arquivo) }
    }
}
