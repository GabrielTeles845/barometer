import AppKit
import SwiftUI

/// Uma régua de arrastar, no desenho do painel (o controle do sistema destoava do preto e não sai na foto).
struct Regua: View {
    let valor: Double
    /// O máximo que dá para arrastar (a transparência para em 90%, senão o texto some no fundo).
    var limite: Double = 1
    let mudar: (Double) -> Void

    var body: some View {
        GeometryReader { g in
            let x = CGFloat(min(valor, limite) / limite) * (g.size.width - 18)
            ZStack(alignment: .leading) {
                Capsule().fill(Tinta.tinta.opacity(0.1)).frame(height: 5)
                Capsule().fill(Tinta.degrade([Tinta.destaque.opacity(0.6), Tinta.destaque], de: .leading, ate: .trailing, chapada: Tinta.destaque))
                    .frame(width: x + 9, height: 5)
                Circle().fill(Color.white).frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .offset(x: x)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let p = min(1, max(0, (v.location.x - 9) / max(1, g.size.width - 18)))
                mudar(Double(p) * limite)
            })
        }
        .frame(height: 22)
    }
}
