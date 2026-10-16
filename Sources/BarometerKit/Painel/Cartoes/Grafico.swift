import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

struct Grafico: View {
    let pontos: [Historico.Ponto]
    @Binding var aba: Int
    /// Na aba de uma área, o gráfico é só dela: sem as pílulas, com o título.
    var fixa: Int? = nil
    private var atual: Int { fixa ?? aba }

    private var titulo: [(String, Color)] {
        [("Memória", Tinta.memoria), ("CPU", Tinta.cpu), ("GPU", Tinta.gpu), ("Temp.", Tinta.calor), ("Disco", Tinta.disco)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                if let fixa {
                    Text(t("Histórico")).font(.system(size: 11, weight: .semibold)).foregroundStyle(Tinta.texto)
                    Circle().fill(titulo[fixa].1).frame(width: 6, height: 6).padding(.leading, 4)
                }
                ForEach(fixa == nil ? Array(0..<titulo.count) : [], id: \.self) { i in
                    Button { aba = i } label: {
                        Text(t(titulo[i].0)).font(.system(size: 10.5, weight: aba == i ? .semibold : .regular))
                            .foregroundStyle(aba == i ? Tinta.texto : Tinta.apagado)
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(Capsule().fill(aba == i ? Color.white.opacity(0.1) : .clear))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(t(alcance)).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
            }
            grafico.frame(height: 96)
                .animation(Mexer.valor(.easeInOut(duration: 0.35)), value: aba)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }

    /// Com uma leitura só (o app acabou de abrir), a linha sai reta no valor de agora, até chegar a segunda.
    private var serie: [Historico.Ponto] {
        guard pontos.count == 1, let p = pontos.first else { return pontos }
        return [Historico.Ponto(quando: p.quando.addingTimeInterval(-10), memoria: p.memoria, cpu: p.cpu, chip: p.chip,
                                gpu: p.gpu, disco: p.disco), p]
    }

    private var alcance: String {
        guard let primeiro = pontos.first?.quando, pontos.count > 1 else { return "agora" }
        let minutos = Int(Date().timeIntervalSince(primeiro) / 60)
        return minutos < 60 ? "últimos \(max(1, minutos)) min" : "últimas \(min(6, minutos / 60)) h"
    }

    private func valor(_ p: Historico.Ponto) -> Double? {
        switch atual {
        case 0: return p.memoria * 100
        case 1: return p.cpu * 100
        case 2: return p.gpu * 100
        case 3: return p.chip
        default: return p.disco / 1_048_576
        }
    }

    private var grafico: some View {
        let aba = atual
        let cor = titulo[aba].1
        // Disco em MB/s, com o teto do maior pico (no mínimo 10 MB/s, para o ruído não virar montanha).
        let pontos = serie
        let picoDisco = max(10, (pontos.map(\.disco).max() ?? 0) / 1_048_576 * 1.1)
        let dominio: ClosedRange<Double> = aba == 3 ? 20...100 : (aba == 4 ? 0...picoDisco : 0...100)
        let marcas: [Double] = aba == 3 ? [40, 70, 100] : (aba == 4 ? [0, (picoDisco / 2).rounded(), picoDisco.rounded()] : [0, 50, 100])
        let unidade = aba == 3 ? "°" : (aba == 4 ? "" : "%")
        return Chart {
            ForEach(Array(pontos.enumerated()), id: \.offset) { _, p in
                if let v = valor(p) {
                    AreaMark(x: .value("hora", p.quando), yStart: .value("base", dominio.lowerBound), yEnd: .value("valor", v))
                        .foregroundStyle(LinearGradient(colors: [cor.opacity(0.35), cor.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("hora", p.quando), y: .value("valor", v))
                        .foregroundStyle(cor)
                        .lineStyle(StrokeStyle(lineWidth: 1.6))
                        .interpolationMethod(.monotone)
                }
            }
            // A leitura mais recente, marcada na ponta da linha.
            if let ultimo = pontos.last, let v = valor(ultimo) {
                PointMark(x: .value("hora", ultimo.quando), y: .value("valor", v))
                    .foregroundStyle(cor).symbolSize(28)
            }
        }
        .chartYScale(domain: dominio)
        .chartYAxis {
            AxisMarks(position: .trailing, values: marcas) { v in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel {
                    Text("\(Int(v.as(Double.self) ?? 0))\(unidade)\(aba == 4 && (v.as(Double.self) ?? 0) > 0 ? " MB/s" : "")")
                        .font(.system(size: 9)).foregroundStyle(Tinta.fraco)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: EixoDoTempo.marcas(de: pontos.first?.quando, ate: pontos.last?.quando)) { v in
                AxisValueLabel(format: .dateTime.hour().minute()).font(.system(size: 9)).foregroundStyle(Tinta.fraco)
            }
        }
    }
}
