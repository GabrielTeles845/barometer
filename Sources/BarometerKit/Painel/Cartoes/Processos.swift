import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

struct Processos: View {
    @ObservedObject var estado: Estado
    let fechar: (Maquina.Gasto) -> Void
    /// Na aba CPU ou Memória, a lista é só daquela medida.
    var fixo: Int? = nil

    var body: some View {
        let porCPU = (fixo ?? estado.abaProcessos) == 1
        let gastos = porCPU ? estado.gastosCPU : estado.gastos
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Text(t("O QUE MAIS USA") + (fixo.map { " " + t($0 == 1 ? "CPU" : "memória").uppercased() } ?? ""))
                    .font(.system(size: 9.5, weight: .semibold)).tracking(0.6).foregroundStyle(Tinta.fraco)
                    .padding(.trailing, 4)
                ForEach(fixo == nil ? Array(["Memória", "CPU"].indices) : [], id: \.self) { i in
                    Button { estado.abaProcessos = i } label: {
                        Text(t(["memória", "CPU"][i])).font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(estado.abaProcessos == i ? Tinta.texto : Tinta.fraco)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(estado.abaProcessos == i ? Color.white.opacity(0.1) : .clear))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(t("× fecha")).font(.system(size: 9.5)).foregroundStyle(Tinta.fraco.opacity(0.8))
            }
            .padding(.horizontal, 6).padding(.top, 4).padding(.bottom, 2)
            let maior = max(0.0001, gastos.map { porCPU ? $0.cpu : $0.bytes }.max() ?? 1)
            ForEach(gastos, id: \.nome) { g in
                Linha(id: "g:" + g.nome + "\(g.pid)", podeFechar: g.meu, fechar: { fechar(g) }) {
                    HStack(spacing: 6) {
                        IconeDoProcesso(app: g.app)
                        // O nome nunca corta; a descrição some quando não cabe (nada de reticências).
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) {
                                Text(Self.nomeCurto(g.nome)).font(.system(size: 12)).foregroundStyle(Tinta.texto).fixedSize()
                                Text(t(detalhe(g))).font(.system(size: 10)).foregroundStyle(Tinta.fraco).fixedSize()
                            }
                            Text(Self.nomeCurto(g.nome)).font(.system(size: 12)).foregroundStyle(Tinta.texto).fixedSize()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Capsule().fill((porCPU ? Tinta.cpu : Tinta.memoria).opacity(0.7))
                            .frame(width: 34 * CGFloat((porCPU ? g.cpu : g.bytes) / maior), height: 3)
                            .frame(width: 34, alignment: .trailing)
                        Text(porCPU ? "\(Int(g.cpu.rounded()))%" : Maquina.gb(g.bytes))
                            .font(.system(size: 11, weight: .medium)).monospacedDigit()
                            .foregroundStyle(Tinta.apagado).frame(width: 52, alignment: .trailing)
                            
                    }
                }
            }
        }
        .animation(.snappy(duration: 0.3), value: gastos.map(\.nome))
    }

    /// "com.apple.AppleUserHIDDrivers" vira "AppleUserHIDDrivers": o prefixo não diz nada e empurra o resto.
    static func nomeCurto(_ nome: String) -> String {
        nome.hasPrefix("com.") ? (nome.split(separator: ".").last.map(String.init) ?? nome) : nome
    }

    private func detalhe(_ g: Maquina.Gasto) -> String {
        if g.pid == ProcessInfo.processInfo.processIdentifier || g.nome == "Barometer" { return "este app" }
        if let o = Maquina.doSistema[g.nome].map(t) { return g.meu ? o : t("sistema") + " · " + o }
        if !g.meu { return "sistema" }
        if g.processos > 1 { return "\(g.processos) proc." }
        return g.projeto ?? ""
    }
}
