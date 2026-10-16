import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

struct Botaozinho: View {
    let simbolo: String
    let dica: String
    /// De que lado o balão do nome se apoia: o primeiro botão para a direita, a engrenagem para a esquerda.
    var lado: Alignment = .top
    /// A cor com "ícones coloridos" ligado.
    var cor: Color = Tinta.destaque
    let acao: () -> Void
    @EnvironmentObject var estado: Estado
    private var sobre: Bool { estado.sobre == "b:" + simbolo }

    var body: some View {
        Button(action: acao) {
            Image(systemName: simbolo).font(.system(size: 12))
                .foregroundStyle(Tinta.icone(cor, senao: sobre ? Tinta.texto : Tinta.apagado))
                .frame(width: 28, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(sobre ? Tinta.tinta.opacity(0.08) : .clear))
        }
        .buttonStyle(.plain)
        .overlay(alignment: lado) { if sobre { Dica(texto: t(dica)).offset(y: -30) } }
        .zIndex(sobre ? 1 : 0)
        .onHover { estado.sobre = $0 ? "b:" + simbolo : (estado.sobre == "b:" + simbolo ? nil : estado.sobre) }
    }
}
