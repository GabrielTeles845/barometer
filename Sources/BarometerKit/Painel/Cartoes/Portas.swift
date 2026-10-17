import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

struct Portas: View {
    @ObservedObject var estado: Estado
    let acoes: Acoes

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Secao(titulo: estado.portas.isEmpty ? "Nenhuma porta ouvindo" : "Portas ouvindo",
                  dica: estado.portas.isEmpty ? "" : "clique abre · × encerra")
            ForEach(estado.portas, id: \.numero) { p in
                Linha(id: "p:\(p.numero)", podeFechar: true, fechar: { acoes.encerrarPorta(p) }, clique: { acoes.abrirPorta(p) },
                      editar: { acoes.nomearPorta(p.numero) }) {
                    HStack(spacing: 8) {
                        Text(verbatim: String(p.numero)).font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Tinta.porta).frame(width: 44, alignment: .leading)
                        // Com nome dado pela pessoa, ele vem primeiro; o processo fica ao lado, apagado.
                        if let nome = estado.nomesDasPortas[p.numero] {
                            Text(nome).font(.system(size: 12, weight: .medium)).foregroundStyle(Tinta.texto).lineLimit(1)
                            Text(p.comoChamar).font(.system(size: 10)).foregroundStyle(Tinta.fraco).lineLimit(1)
                        } else {
                            Text(p.comoChamar).font(.system(size: 12)).foregroundStyle(Tinta.texto).lineLimit(1)
                            if let c = p.contexto, c != p.comoChamar {
                                Text(c).font(.system(size: 10)).foregroundStyle(Tinta.fraco).lineLimit(1)
                            }
                        }
                        Spacer(minLength: 4)
                        if p.doDocker {
                            Text(verbatim: "docker").font(.system(size: 9, weight: .medium)).foregroundStyle(Tinta.memoria)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(Tinta.memoria.opacity(0.14)))
                        }
                    }
                }
            }
            let livres = estado.favoritas.filter { n in !estado.portas.contains { $0.numero == n } }
            if !livres.isEmpty {
                Text(t("livres: " + livres.map { n in estado.nomesDasPortas[n].map { "\(n) \($0)" } ?? String(n) }.joined(separator: " · ")))
                    .font(.system(size: 10)).foregroundStyle(Tinta.fraco).padding(.horizontal, 6).padding(.top, 2)
            }
            if !estado.ocultas.isEmpty {
                Text(t("ocultas: " + estado.ocultas.prefix(5).map { "\($0.numero) \($0.nome)" }.joined(separator: " · "))
                     + (estado.ocultas.count > 5 ? t(" e mais \(estado.ocultas.count - 5)") : ""))
                    .font(.system(size: 10)).foregroundStyle(Tinta.fraco).lineLimit(2).padding(.horizontal, 6)
            }
        }
    }
}
