import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

/// As abas: um ícone para cada área, o nome ao passar o mouse.
struct BarraDeAbas: View {
    @ObservedObject var estado: Estado

    var body: some View {
        let abas = Aba.allCases
        let i = abas.firstIndex(of: estado.abaAtual) ?? 0
        GeometryReader { g in
            // Uma pílula só, que desliza até a aba escolhida (com fundo de vidro, ela é de vidro líquido).
            let largura = (g.size.width - CGFloat(abas.count - 1) * 2) / CGFloat(abas.count)
            ZStack(alignment: .leading) {
                pilula.frame(width: largura, height: 26).offset(x: CGFloat(i) * (largura + 2))
                    .animation(Mexer.leve, value: i)
                HStack(spacing: 2) {
                    ForEach(abas, id: \.self) { aba in
                        let escolhida = estado.abaAtual == aba
                        let sobre = estado.sobre == "aba:" + aba.rawValue
                        let lado: Alignment = aba == abas.first ? .bottomLeading : (aba == abas.last ? .bottomTrailing : .bottom)
                        Button {
                            estado.abaAtual = aba
                            if aba != .geral { estado.editandoGeral = false }
                        } label: {
                            Image(systemName: aba.simbolo).font(.system(size: 12, weight: escolhida ? .semibold : .regular))
                                .foregroundStyle(escolhida ? Tinta.texto : (sobre ? Tinta.apagado.opacity(1.4) : Tinta.apagado))
                                .scaleEffect(sobre && !escolhida && estado.aparencia.movimento == .mola ? 1.12 : 1)
                                .frame(maxWidth: .infinity).frame(height: 26)
                                .background(RoundedRectangle(cornerRadius: 7).fill(!escolhida && sobre ? Tinta.tinta.opacity(0.05) : .clear))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: lado) { if sobre { Dica(texto: aba.titulo).offset(y: 32) } }
                        .zIndex(sobre ? 1 : 0)
                        .onHover { estado.sobre = $0 ? "aba:" + aba.rawValue : (estado.sobre == "aba:" + aba.rawValue ? nil : estado.sobre) }
                    }
                }
            }
        }
        .frame(height: 26)
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 9).fill(Tinta.tinta.opacity(0.04)))
        .animation(Mexer.leve, value: estado.sobre)
    }

    @ViewBuilder private var pilula: some View {
        let forma = RoundedRectangle(cornerRadius: 7, style: .continuous)
        if estado.aparencia.fundoReal != .solido, !estado.paraImagem, #available(macOS 26, *) {
            Color.clear.glassEffect(.regular.interactive(), in: forma)
        } else {
            forma.fill(Tinta.tinta.opacity(0.11))
        }
    }
}
