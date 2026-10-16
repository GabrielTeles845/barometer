import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

struct Aneis: View {
    @ObservedObject var estado: Estado

    var body: some View {
        let mem = estado.memoria.map { $0.usada / Maquina.total }
        // Quatro colunas do mesmo tamanho; o que não cabe no rótulo vai para dentro do anel, em letra pequena.
        HStack(spacing: 0) {
            Anel(valor: estado.cpu ?? 0, cor: Tinta.cpu,
                 texto: estado.cpu.map { "\(Int(($0 * 100).rounded()))%" } ?? "…", rotulo: "CPU")
            Anel(valor: mem ?? 0, cor: Tinta.memoria,
                 texto: mem.map { "\(Int(($0 * 100).rounded()))%" } ?? "…",
                 rotulo: "Memória", detalhe: estado.memoria.map { Maquina.gb($0.usada) },
                 ponto: Tinta.pressao(estado.pressao))
            Anel(valor: estado.gpu?.uso ?? 0, cor: Tinta.gpu,
                 texto: estado.gpu.map { "\(Int(($0.uso * 100).rounded()))%" } ?? "–", rotulo: "GPU")
            Anel(valor: estado.temperatura.chip.map { ($0 - 20) / 80 } ?? 0, cor: Tinta.calor,
                 texto: estado.temperatura.chip.map { "\(Int($0.rounded()))°" } ?? "–",
                 rotulo: "Chip", detalhe: estado.temperatura.chipMaximo.map { "máx \(Int($0.rounded()))°" })
        }
    }
}

struct Anel: View {
    let valor: Double
    let cor: Color
    let texto: String
    let rotulo: String
    /// Segunda linha, pequena, dentro do anel ("8,8 GB", "máx 46°").
    var detalhe: String?
    /// A bolinha da pressão da memória, ao lado do rótulo (verde, laranja, vermelho).
    var ponto: Color?
    var tamanho: CGFloat = 56

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Tinta.tinta.opacity(0.07), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(min(1, max(0.001, valor))))
                    .stroke(Tinta.chapado ? AnyShapeStyle(cor)
                            : AnyShapeStyle(AngularGradient(colors: [cor.opacity(0.5), cor], center: .center,
                                                            startAngle: .degrees(0), endAngle: .degrees(360 * max(0.05, valor)))),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: cor.opacity(Tinta.chapado ? 0 : 0.35), radius: 4)
                    .animation(.spring(response: 0.7, dampingFraction: 0.85), value: valor)
                VStack(spacing: 0) {
                    Text(texto).font(.system(size: tamanho > 60 ? 18 : 13.5, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Tinta.texto)
                        
                        .animation(.snappy, value: texto)
                    if let detalhe {
                        Text(t(detalhe)).font(.system(size: 8.5, weight: .medium)).monospacedDigit().foregroundStyle(Tinta.fraco)
                            .fixedSize()
                    }
                }
            }
            .frame(width: tamanho, height: tamanho)
            HStack(spacing: 3) {
                if let ponto { Circle().fill(ponto).frame(width: 5, height: 5) }
                Text(t(rotulo)).font(.system(size: 10)).foregroundStyle(Tinta.apagado).fixedSize()
            }
        }
        .frame(maxWidth: .infinity)
    }
}
