import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

struct CartaoDaLimpeza: View {
    @ObservedObject var estado: Estado
    let acoes: Acoes

    var body: some View {
        let total = estado.limpeza.filter { !$0.ehLixeira }.compactMap(\.bytes).reduce(0, +)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if estado.medindoLimpeza && estado.limpeza.allSatisfy({ $0.bytes == nil }) {
                    Text(t("Medindo…")).font(.system(size: 13)).foregroundStyle(Tinta.apagado)
                } else {
                    Text(Maquina.gb(total)).font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Tinta.texto)
                    Text(t("podem sair sem perder nada seu")).font(.system(size: 11)).foregroundStyle(Tinta.apagado)
                }
                Spacer()
            }
            if let l = estado.liberado {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Tinta.porta)
                    Text(t("Liberou \(Maquina.gb(l)).")).font(.system(size: 11, weight: .medium)).foregroundStyle(Tinta.texto)
                }
                .transition(.opacity)
            }
            VStack(spacing: 4) {
                ForEach(estado.limpeza) { item in
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t(item.nome)).font(.system(size: 12, weight: .medium)).foregroundStyle(Tinta.texto)
                            Text(t(item.explicacao)).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 6)
                        Text(item.bytes.map(Maquina.gb) ?? (estado.medindoLimpeza ? "…" : "–"))
                            .font(.system(size: 11, weight: .medium)).monospacedDigit().foregroundStyle(Tinta.apagado)
                            
                        Button { acoes.limpar(item.id) } label: {
                            Text(t(item.ehLixeira ? "Esvaziar" : "Limpar")).font(.system(size: 11, weight: .medium))
                                .foregroundStyle(item.ehLixeira ? Tinta.calor : Tinta.texto)
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .background(Capsule().fill(Tinta.tinta.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .disabled((item.bytes ?? 1) == 0)
                        .opacity((item.bytes ?? 1) == 0 ? 0.35 : 1)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Tinta.tinta.opacity(0.035)))
                }
            }
            Button(action: acoes.limparTudo) {
                Text(t("Limpar tudo (menos a Lixeira)")).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tinta.fundo)
                    .frame(maxWidth: .infinity).frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Tinta.texto))
            }
            .buttonStyle(.plain)
            .disabled(total == 0)
            .opacity(total == 0 ? 0.4 : 1)
            Text(t("Documentos, downloads e fotos nunca entram aqui. Cada limpeza pede confirmação."))
                .font(.system(size: 10)).foregroundStyle(Tinta.fraco).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
        .animation(.snappy, value: estado.liberado)
    }
}

/// A limpeza numa linha, para o Geral: quanto dá para liberar, e um toque leva para a aba.
struct ResumoDaLimpeza: View {
    @ObservedObject var estado: Estado

    var body: some View {
        let total = estado.limpeza.filter { !$0.ehLixeira }.compactMap(\.bytes).reduce(0, +)
        Button { estado.abaAtual = .limpeza } label: {
            HStack(spacing: 10) {
                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Tinta.comprimida)
                Text(total > 0 ? t("\(Maquina.gb(total)) para limpar") : t("Limpeza"))
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Tinta.texto)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Tinta.fraco)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
