import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

struct CartaoDaMemoria: View {
    @ObservedObject var estado: Estado

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let m = estado.memoria {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Maquina.gb(m.usada)).font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Tinta.texto)
                    Text(t("de \(Maquina.gb(Maquina.total)) em uso")).font(.system(size: 12)).foregroundStyle(Tinta.apagado)
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(Tinta.pressao(estado.pressao)).frame(width: 6, height: 6)
                        Text(t(estado.pressao >= 4 ? "no limite" : estado.pressao >= 2 ? "apertada" : "folgada"))
                            .font(.system(size: 11)).foregroundStyle(Tinta.apagado)
                    }
                }
                BarraDeMemoria(memoria: m, swap: estado.swap)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }
}

struct BarraDeMemoria: View {
    let memoria: Maquina.Memoria
    let swap: Double

    var body: some View {
        let partes: [(String, Double, Color)] = [
            ("apps", memoria.apps, Tinta.memoria), ("fixa", memoria.fixa, Tinta.fixa),
            ("comprimida", memoria.comprimida, Tinta.comprimida), ("cache", memoria.cache, Tinta.tinta.opacity(0.22)),
        ]
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { g in
                HStack(spacing: 1.5) {
                    ForEach(partes, id: \.0) { p in
                        RoundedRectangle(cornerRadius: 2).fill(p.2)
                            .frame(width: max(2, g.size.width * CGFloat(p.1 / Maquina.total)))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 7)
            .background(RoundedRectangle(cornerRadius: 3).fill(Tinta.tinta.opacity(0.05)))
            // Duas linhas de três, com o valor alinhado: numa linha só não cabia e cortava com reticências.
            let itens = partes.map { ($0.0, Maquina.gb($0.1), $0.2) } + (swap > 0 ? [("swap", Maquina.gb(swap), Tinta.tinta.opacity(0.1))] : [])
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 3) {
                ForEach(Array(stride(from: 0, to: itens.count, by: 3)), id: \.self) { inicio in
                    GridRow {
                        ForEach(inicio..<min(inicio + 3, itens.count), id: \.self) { i in
                            HStack(spacing: 5) {
                                Circle().fill(itens[i].2).frame(width: 5, height: 5)
                                Text(t(itens[i].0)).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
                                Text(itens[i].1).font(.system(size: 10, weight: .medium)).monospacedDigit().foregroundStyle(Tinta.apagado)
                            }
                            .fixedSize()
                        }
                    }
                }
            }
        }
    }
}
