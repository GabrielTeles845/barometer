import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

/// O nome de um ícone, num balão, ao passar o mouse. A dica nativa do macOS (`.help`) não aparece aqui: o
/// Barometer vive na barra e quase nunca é o app ativo, e o macOS só mostra dica do app ativo.
struct Dica: View {
    let texto: String

    var body: some View {
        Text(texto).font(.system(size: 11, weight: .medium)).foregroundStyle(Tinta.texto)
            .fixedSize()
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(white: 0.17)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            .allowsHitTesting(false)
            .transition(.opacity)
    }
}
