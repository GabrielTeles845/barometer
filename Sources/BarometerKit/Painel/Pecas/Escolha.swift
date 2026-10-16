import AppKit
import SwiftUI

/// Opções lado a lado com a pílula escolhida deslizando de uma para a outra. Com fundo de vidro, a pílula é de
/// vidro líquido também.
struct Escolha<V: Equatable>: View {
    let opcoes: [(String, V)]
    let atual: V
    let vidro: Bool
    let escolher: (V) -> Void

    var body: some View {
        let i = opcoes.firstIndex { $0.1 == atual } ?? 0
        GeometryReader { g in
            let largura = (g.size.width - 6) / CGFloat(max(1, opcoes.count))
            ZStack(alignment: .leading) {
                pilula.frame(width: largura, height: g.size.height - 6).offset(x: 3 + CGFloat(i) * largura)
                    .animation(Mexer.leve, value: i)
                HStack(spacing: 0) {
                    ForEach(Array(opcoes.enumerated()), id: \.offset) { n, o in
                        Button { escolher(o.1) } label: {
                            Text(o.0).font(.system(size: 11, weight: n == i ? .semibold : .regular))
                                .foregroundStyle(n == i ? Tinta.texto : Tinta.apagado)
                                .frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
            }
        }
        .frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 9).fill(Tinta.tinta.opacity(0.04)))
    }

    @ViewBuilder private var pilula: some View {
        let forma = RoundedRectangle(cornerRadius: 7, style: .continuous)
        if vidro, #available(macOS 26, *) {
            Color.clear.glassEffect(.regular.interactive(), in: forma)
        } else {
            forma.fill(Tinta.tinta.opacity(0.11))
        }
    }
}
