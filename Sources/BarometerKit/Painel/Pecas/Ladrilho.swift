import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

/// Um número com título e uma linha de contexto; com `barra`, uma barrinha de proporção embaixo.
struct Ladrilho: View {
    let titulo: String
    let valor: String
    let detalhe: String
    let cor: Color
    var barra: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(t(titulo).uppercased()).font(.system(size: 8.5, weight: .semibold)).tracking(0.5).foregroundStyle(cor.opacity(0.85))
            Text(valor).font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(Tinta.texto)
            if let barra {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Tinta.tinta.opacity(0.07))
                        Capsule().fill(cor).frame(width: max(3, g.size.width * CGFloat(min(1, barra))))
                            .animation(.easeOut(duration: 0.5), value: barra)
                    }
                }
                .frame(height: 3)
            }
            Text(t(detalhe)).font(.system(size: 9.5)).foregroundStyle(Tinta.fraco).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 9).fill(Tinta.tinta.opacity(0.035)))
    }
}
