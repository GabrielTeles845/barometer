import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

struct CartaoDaGPU: View {
    let gpu: GPU

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(verbatim: "GPU").font(.system(size: 9.5, weight: .bold)).foregroundStyle(Tinta.gpu)
                Text([gpu.modelo, gpu.nucleos.map { "\($0) núcleos" }].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 9.5)).foregroundStyle(Tinta.fraco)
                Spacer()
                Text(t("memória \(Maquina.gb(gpu.memoriaEmUso))")).font(.system(size: 9.5, weight: .medium)).foregroundStyle(Tinta.apagado)
            }
            barra("uso", gpu.uso)
            barra("renderer", gpu.renderer)
            barra("tiler", gpu.tiler)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }

    private func barra(_ rotulo: String, _ v: Double) -> some View {
        HStack(spacing: 8) {
            Text(t(rotulo)).font(.system(size: 10)).foregroundStyle(Tinta.fraco).frame(width: 52, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Tinta.tinta.opacity(0.06))
                    Capsule().fill(Tinta.degrade([Tinta.gpu.opacity(0.6), Tinta.gpu], de: .leading, ate: .trailing, chapada: Tinta.gpu))
                        .frame(width: max(3, g.size.width * CGFloat(min(1, v))))
                        .animation(.easeOut(duration: 0.45), value: v)
                }
            }
            .frame(height: 5)
            Text(t("\(Int((v * 100).rounded()))%")).font(.system(size: 10, weight: .medium)).monospacedDigit()
                .foregroundStyle(Tinta.apagado).frame(width: 32, alignment: .trailing)
        }
    }
}
