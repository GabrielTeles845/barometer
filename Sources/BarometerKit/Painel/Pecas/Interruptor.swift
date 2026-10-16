import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

/// Interruptor no estilo do painel (o do sistema fica cinza-claro sobre o preto).
struct Interruptor: View {
    let ligado: Bool
    let virar: () -> Void

    var body: some View {
        Button(action: virar) {
            ZStack(alignment: ligado ? .trailing : .leading) {
                Capsule().fill(ligado ? Tinta.destaque.opacity(0.85) : Tinta.tinta.opacity(0.12))
                Circle().fill(Color.white).padding(2).shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
            }
            .frame(width: 30, height: 17)
            .animation(Mexer.leve, value: ligado)
        }
        .buttonStyle(.plain)
    }
}
