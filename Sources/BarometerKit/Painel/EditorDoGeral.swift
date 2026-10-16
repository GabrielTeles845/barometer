import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

/// Escolher e arrastar os cartões do Geral, como a Central de Controle: segure uma linha e leve para cima ou
/// para baixo; as outras abrem espaço enquanto ela passa. Linhas próprias, e não a `List` do sistema: a da lista
/// nativa destoava do painel preto e não se desenha na conferência por imagem.
struct EditorDoGeral: View {
    @ObservedObject var estado: Estado

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SecaoDaBarra(estado: estado)
            Text(t("NO GERAL")).font(.system(size: 9.5, weight: .semibold)).tracking(0.6).foregroundStyle(Tinta.fraco)
                .padding(.top, 8)
            Text(t("Ligue o que quer ver no Geral. Segure e arraste para mudar a ordem."))
                .font(.system(size: 11)).foregroundStyle(Tinta.apagado)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 4) {
                ForEach(estado.geral) { item in
                    if estado.paraImagem {
                        // O desenho como imagem não sabe desenhar o arrastar; a linha é a mesma.
                        linha(item)
                    } else {
                        linha(item)
                            .opacity(estado.arrastando == item.id ? 0.35 : 1)
                            .onDrag {
                                estado.arrastando = item.id
                                return NSItemProvider(object: item.id as NSString)
                            }
                            .onDrop(of: [.text], delegate: Reordenar(alvo: item.id, estado: estado))
                    }
                }
            }
            .animation(.snappy(duration: 0.22), value: estado.geral)
            Button { estado.geral = ItemGeral.padrao } label: {
                Text(t("Voltar ao padrão")).font(.system(size: 11)).foregroundStyle(Tinta.fraco)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    private func linha(_ item: ItemGeral) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal").font(.system(size: 11, weight: .medium)).foregroundStyle(Tinta.fraco)
            Text(item.nome).font(.system(size: 12)).foregroundStyle(item.ligado ? Tinta.texto : Tinta.apagado)
            Spacer()
            Interruptor(ligado: item.ligado) {
                if let i = estado.geral.firstIndex(where: { $0.id == item.id }) { estado.geral[i].ligado.toggle() }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(item.ligado ? 0.06 : 0.03)))
        .contentShape(Rectangle())
    }
}

/// Enquanto a linha arrastada passa por cima de outra, troca as duas de lugar (com animação).
struct Reordenar: DropDelegate {
    let alvo: String
    let estado: Estado

    func dropEntered(info: DropInfo) {
        guard let de = estado.arrastando, de != alvo,
              let a = estado.geral.firstIndex(where: { $0.id == de }),
              let b = estado.geral.firstIndex(where: { $0.id == alvo }) else { return }
        withAnimation(.snappy(duration: 0.22)) {
            estado.geral.move(fromOffsets: IndexSet(integer: a), toOffset: b > a ? b + 1 : b)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        estado.arrastando = nil
        return true
    }
}
