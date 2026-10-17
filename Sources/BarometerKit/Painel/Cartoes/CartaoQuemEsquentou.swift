// "Quem mais esquentou": o tempo de CPU de cada app nas últimas horas, e a média e o pico de memória ao lado.

import SwiftUI

struct CartaoQuemEsquentou: View {
    @ObservedObject var estado: Estado

    var body: some View {
        let periodo = estado.periodoQuente
        VStack(alignment: .leading, spacing: 2) {
            Secao(titulo: "Quem mais esquentou", dica: periodo < 60 ? "" : periodoTexto(periodo))
            if estado.quentes.isEmpty {
                Text(t(periodo < 60 ? "Em 2 minutos aparece quem mais gastou." : "Nada gastou CPU de verdade."))
                    .font(.system(size: 11)).foregroundStyle(Tinta.fraco)
                    .padding(.horizontal, 6).padding(.vertical, 4)
            }
            let maior = max(1, estado.quentes.map(\.cpu).max() ?? 1)
            ForEach(estado.quentes) { q in
                Linha(id: "q:" + q.nome, podeFechar: false, fechar: {}) {
                    HStack(spacing: 6) {
                        IconeDoProcesso(app: q.app)
                        // A média só aparece quando diz algo (0% em todos é barulho).
                        let media = Int((q.cpu / max(60, periodo) * 100).rounded())
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) {
                                Text(Processos.nomeCurto(q.nome)).font(.system(size: 12)).foregroundStyle(Tinta.texto).fixedSize()
                                if media >= 1 {
                                    Text(t("média \(media)%")).font(.system(size: 10)).foregroundStyle(Tinta.fraco).fixedSize()
                                }
                            }
                            Text(Processos.nomeCurto(q.nome)).font(.system(size: 12)).foregroundStyle(Tinta.texto).fixedSize()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Capsule().fill(Tinta.cpu.opacity(0.7))
                            .frame(width: 34 * CGFloat(q.cpu / maior), height: 3)
                            .frame(width: 34, alignment: .trailing)
                        Text(QuemEsquentou.tempo(q.cpu)).font(.system(size: 11, weight: .medium)).monospacedDigit()
                            .foregroundStyle(Tinta.apagado).frame(width: 72, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }

    private func periodoTexto(_ s: TimeInterval) -> String {
        let m = Int(s / 60)
        return m < 60 ? "últimos \(m) min" : "últimas \(m / 60) h"
    }
}
