import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

struct CartaoDeTemperaturas: View {
    let t: Sensores.Leitura

    var body: some View {
        HStack(spacing: 8) {
            Ladrilho(titulo: "Chip", valor: t.chip.map { "\(Int($0.rounded()))°" } ?? "–",
                     detalhe: t.chipMaximo.map { "máx \(Int($0.rounded()))°" } ?? "", cor: Tinta.calor)
            Ladrilho(titulo: "SSD", valor: t.ssd.map { "\(Int($0.rounded()))°" } ?? "–", detalhe: "disco", cor: Tinta.disco)
            Ladrilho(titulo: "Bateria", valor: t.bateria.map { "\(Int($0.rounded()))°" } ?? "–", detalhe: "célula", cor: Tinta.bateria)
        }
    }
}
