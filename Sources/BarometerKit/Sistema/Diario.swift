import AppKit
import Combine
import IOKit
import ServiceManagement
import SwiftUI

/// Um registro do que aconteceu, em arquivo, porque menu não se depura.
///
/// Não há como pôr ponto de parada num clique de menu, nem ler stdout de um
/// app de barra, nem fotografar o menu aberto. Sem isto, todo diagnóstico daqui
/// é chute — e chute já custou três correções erradas no realce e uma no ×,
/// que durante dias pareceu ligado e nunca chegou a ser chamado.
enum Diario {
    static let arquivo = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/barometer.log")

    /// Escreve uma linha e mantém o arquivo nas últimas 400 — diário que cresce
    /// sem limite é diário que ninguém abre.
    static func anotar(_ texto: String) {
        let quando = ISO8601DateFormatter().string(from: Date())
        let linha = "\(quando)  \(texto)"
        DispatchQueue.global(qos: .utility).async {
            var linhas = (try? String(contentsOf: arquivo, encoding: .utf8))?
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init) ?? []
            linhas.append(linha)
            if linhas.count > 400 { linhas = Array(linhas.suffix(400)) }
            try? FileManager.default.createDirectory(
                at: arquivo.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? linhas.joined(separator: "\n").write(to: arquivo, atomically: true,
                                                      encoding: .utf8)
        }
    }
}
