// "Dá para fechar", no topo da aba Limpeza: apps abertos e parados há mais de 1 hora (os que mais ocupam memória
// primeiro) e servidores ligados há mais de 12 horas. O × é o de sempre: confirma antes de fechar.

import SwiftUI

struct CartaoDeSugestoes: View {
    @ObservedObject var estado: Estado
    let acoes: Acoes

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Secao(titulo: "Dá para fechar", dica: estado.sugestoes.isEmpty ? "" : "× fecha")
            if estado.sugestoes.isEmpty {
                Text(t("Nada parado há mais de 1 hora."))
                    .font(.system(size: 11)).foregroundStyle(Tinta.fraco)
                    .padding(.horizontal, 6).padding(.vertical, 4)
            }
            ForEach(estado.sugestoes) { s in
                Linha(id: "s:" + s.id, podeFechar: true, fechar: { fechar(s) }) {
                    HStack(spacing: 6) {
                        icone(s)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) {
                                Text(s.nome).font(.system(size: 12)).foregroundStyle(Tinta.texto).fixedSize()
                                Text(t(texto(s))).font(.system(size: 10)).foregroundStyle(Tinta.fraco).fixedSize()
                            }
                            Text(s.nome).font(.system(size: 12)).foregroundStyle(Tinta.texto).fixedSize()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if let b = s.bytes {
                            Text(Maquina.gb(b)).font(.system(size: 11, weight: .medium)).monospacedDigit()
                                .foregroundStyle(Tinta.apagado).frame(width: 52, alignment: .trailing)
                        }
                    }
                }
            }
            let servidores = Sugestoes.servidoresDa(estado.sugestoes).count
            if servidores >= 2 {
                Button(action: acoes.encerrarServidores) {
                    Text(t("Encerrar os \(servidores) servidores")).font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Tinta.texto)
                        .frame(maxWidth: .infinity).frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Tinta.tinta.opacity(0.08)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 2)
            }
        }
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }

    private func texto(_ s: Sugestao) -> String {
        switch s.tipo {
        case .app: return "parado há \(Medida.duracao(s.tempo))"
        case .porta: return "aberto há \(Medida.duracao(s.tempo))"
        }
    }

    @ViewBuilder private func icone(_ s: Sugestao) -> some View {
        switch s.tipo {
        case .app(let g): IconeDoProcesso(app: g.app)
        case .porta:
            Image(systemName: "server.rack").font(.system(size: 9, weight: .medium)).foregroundStyle(Tinta.porta)
                .frame(width: 15, height: 15)
        }
    }

    private func fechar(_ s: Sugestao) {
        switch s.tipo {
        case .app(let g): acoes.fechar(g)
        case .porta(let p): acoes.encerrarPorta(p)
        }
    }
}
