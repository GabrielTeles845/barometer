import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

/// Uma barra por núcleo, os de eficiência (E) e os de desempenho (P) em cores diferentes, a frequência de cada
/// grupo e os números miúdos: usuário, sistema, carga, tempo ligado e estado térmico.
struct CartaoDaCPU: View {
    let cpu: CPUDetalhada

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                grupo(cpu.nucleos.filter(\.eficiencia), cor: Tinta.eficiencia, rotulo: "E", ghz: cpu.ghzE)
                grupo(cpu.nucleos.filter { !$0.eficiencia }, cor: Tinta.cpu, rotulo: "P", ghz: cpu.ghzP)
            }
            HStack(spacing: 10) {
                miudo("usuário", "\(Int((cpu.usuario * 100).rounded()))%")
                miudo("sistema", "\(Int((cpu.sistema * 100).rounded()))%")
                miudo("carga", decimal(cpu.carga.0))
                if let d = cpu.ligadoDesde { miudo("ligado há", tempo(desde: d)) }
                Spacer(minLength: 0)
                // O estado térmico só aparece quando sai do normal: "tudo bem" o tempo todo é ruído.
                if cpu.termico != .nominal {
                    HStack(spacing: 4) {
                        Circle().fill(corTermica).frame(width: 5, height: 5)
                        Text(t(textoTermico)).font(.system(size: 10, weight: .medium)).foregroundStyle(corTermica)
                    }
                    .fixedSize()
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }

    private func grupo(_ nucleos: [Nucleo], cor: Color, rotulo: String, ghz: Double?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(rotulo).font(.system(size: 9.5, weight: .bold)).foregroundStyle(cor)
                Text(t(rotulo == "E" ? "eficiência" : "desempenho")).font(.system(size: 9.5)).foregroundStyle(Tinta.fraco)
                Spacer(minLength: 2)
                if let ghz {
                    Text(decimal(ghz, casas: 2) + " GHz")
                        .font(.system(size: 9.5, weight: .medium)).monospacedDigit().foregroundStyle(Tinta.apagado)
                }
            }
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(nucleos.indices, id: \.self) { i in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 2).fill(Tinta.tinta.opacity(0.06))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Tinta.degrade([cor, cor.opacity(0.55)], de: .top, ate: .bottom, chapada: cor))
                            .frame(height: max(2, 34 * CGFloat(min(1, nucleos[i].uso))))
                            .animation(.easeOut(duration: 0.45), value: nucleos[i].uso)
                    }
                    .frame(height: 34)
                }
            }
        }
    }

    private func miudo(_ rotulo: String, _ valor: String) -> some View {
        HStack(spacing: 3) {
            Text(t(rotulo)).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
            Text(valor).font(.system(size: 10, weight: .medium)).monospacedDigit().foregroundStyle(Tinta.apagado)
        }
        .fixedSize()
    }

    private func tempo(desde d: Date) -> String {
        let m = Int(Date().timeIntervalSince(d) / 60)
        if m < 60 { return "\(m) min" }
        if m < 60 * 24 { return "\(m / 60) h" }
        return "\(m / 1440) d \(m / 60 % 24) h"
    }

    private var textoTermico: String {
        switch cpu.termico {
        case .nominal: return "temperatura ok"
        case .fair: return "esquentando"
        case .serious: return "quente, reduzindo"
        default: return "muito quente"
        }
    }

    private var corTermica: Color {
        switch cpu.termico {
        case .nominal: return Tinta.porta
        case .fair: return Tinta.comprimida
        case .serious: return Tinta.cpu
        default: return Tinta.calor
        }
    }
}
