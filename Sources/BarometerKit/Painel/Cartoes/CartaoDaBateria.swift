import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

struct CartaoDaBateria: View {
    let b: Bateria

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Anel(valor: Double(b.nivel) / 100, cor: corDaCarga, texto: "\(b.nivel)%", rotulo: "", tamanho: 78)
                    .frame(width: 80)
                VStack(alignment: .leading, spacing: 4) {
                    Text(t(situacao)).font(.system(size: 14, weight: .semibold)).foregroundStyle(Tinta.texto)
                    if let r = restante { Text(t(r)).font(.system(size: 11)).foregroundStyle(Tinta.apagado) }
                    if b.naTomada, let nome = b.carregador ?? b.carregadorWatts.map({ "carregador de \($0) W" }) {
                        Text(t(nome)).font(.system(size: 10)).foregroundStyle(Tinta.fraco).fixedSize()
                    }
                    if let w = b.consumo {
                        Text(t("o Mac está gastando \(numero(w, casas: 1)) W")).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
                    }
                }
                Spacer(minLength: 0)
            }
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    Ladrilho(titulo: "Saúde", valor: b.saudeOficial.map { "\($0)%" } ?? saudeCalculada ?? "–",
                             detalhe: b.condicaoOficial ?? "da capacidade original", cor: Tinta.bateria,
                             barra: b.saudeOficial.map { Double($0) / 100 })
                    Ladrilho(titulo: "Ciclos", valor: b.ciclos.map(String.init) ?? "–",
                             detalhe: b.ciclosDeProjeto.map { "de \($0) previstos" } ?? "",
                             cor: Tinta.comprimida,
                             barra: b.ciclos.flatMap { c in b.ciclosDeProjeto.map { Double(c) / Double($0) } })
                }
                GridRow {
                    Ladrilho(titulo: "Capacidade", valor: b.capacidadeAtual.map { "\(milhar($0)) mAh" } ?? "–",
                             detalhe: b.capacidadeDeProjeto.map { "de \(milhar($0)) mAh de fábrica" } ?? "", cor: Tinta.memoria)
                    Ladrilho(titulo: "Temperatura", valor: b.temperatura.map { "\(Int($0.rounded())) °C" } ?? "–",
                             detalhe: "da bateria", cor: Tinta.calor)
                }
                GridRow {
                    Ladrilho(titulo: "Voltagem", valor: b.volts.map { "\(numero($0, casas: 2)) V" } ?? "–", detalhe: "agora", cor: Tinta.eficiencia)
                    Ladrilho(titulo: "Corrente", valor: b.amperes.map { "\(numero($0, casas: 2)) A" } ?? "–",
                             detalhe: (b.amperes ?? 0) < 0 ? "saindo da bateria" : ((b.amperes ?? 0) > 0 ? "entrando" : "parada"), cor: Tinta.gpu)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }

    private var corDaCarga: Color { b.nivel <= 15 ? Tinta.calor : (b.nivel <= 30 ? Tinta.comprimida : Tinta.bateria) }

    private var situacao: String {
        if b.carregando { return "Carregando" }
        if b.naTomada { return b.carregada || b.nivel >= 100 ? "Carregada, na tomada" : "Na tomada, sem carregar" }
        return "Na bateria"
    }

    private var restante: String? {
        guard let m = b.minutosRestantes else {
            return b.naTomada && !b.carregando && b.nivel < 100 ? "carga otimizada pelo macOS" : nil
        }
        let t = m >= 60 ? "\(m / 60) h \(m % 60) min" : "\(m) min"
        return b.carregando ? "cheia em \(t)" : "\(t) restantes"
    }

    private var saudeCalculada: String? {
        guard let a = b.capacidadeAtual, let p = b.capacidadeDeProjeto, p > 0 else { return nil }
        return "\(Int((Double(a) / Double(p) * 100).rounded()))%"
    }

    private func numero(_ v: Double, casas: Int) -> String { decimal(v, casas: casas) }
}

/// A bateria numa linha, para o Geral.
struct ResumoDaBateria: View {
    let b: Bateria

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).stroke(Tinta.apagado, lineWidth: 1).frame(width: 26, height: 13)
                RoundedRectangle(cornerRadius: 1.5).fill(b.nivel <= 15 ? Tinta.calor : Tinta.bateria)
                    .frame(width: max(2, 22 * CGFloat(b.nivel) / 100), height: 9).padding(.leading, 2)
                    .animation(.easeOut(duration: 0.5), value: b.nivel)
            }
            Text(t("\(b.nivel)%")).font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(Tinta.texto)
                
            Text(t(b.carregando ? "carregando" : (b.naTomada ? "na tomada" : "na bateria")))
                .font(.system(size: 11)).foregroundStyle(Tinta.apagado)
            Spacer()
            if let c = b.ciclos { Text(t("\(c) ciclos")).font(.system(size: 10)).foregroundStyle(Tinta.fraco) }
            if let s = b.saudeOficial { Text(t("saúde \(s)%")).font(.system(size: 10, weight: .medium)).foregroundStyle(Tinta.apagado) }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }
}
