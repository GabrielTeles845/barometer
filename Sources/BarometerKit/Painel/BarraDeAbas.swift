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
            // Uma pílula só, que desliza até a aba escolhida (com fundo de vidro, ela é de vidro líquido). Dá para
            // segurar e arrastar: ela segue o mouse, estica com a velocidade e gruda na aba onde você solta.
            let largura = (g.size.width - CGFloat(abas.count - 1) * 2) / CGFloat(abas.count)
            let medida = ArrastoDaPilula(largura: largura, espaco: 2, quantas: abas.count)
            let arrasto = estado.arrastoDaAba
            let alvo = arrasto.map(medida.indice(em:)) ?? i
            let estico = largura * estado.esticoDaAba
            ZStack(alignment: .leading) {
                pilula.frame(width: largura + estico, height: 26)
                    .scaleEffect(arrasto == nil ? 1 : 1.06)
                    .offset(x: (arrasto.map(medida.inicio(em:)) ?? CGFloat(i) * medida.passo) - estico / 2)
                    .animation(arrasto == nil ? Mexer.leve : Mexer.valor(.interactiveSpring(response: 0.18, dampingFraction: 0.8)),
                               value: arrasto ?? CGFloat(i))
                    .animation(Mexer.leve, value: estado.esticoDaAba)
                HStack(spacing: 2) {
                    ForEach(abas, id: \.self) { aba in
                        let escolhida = abas[alvo] == aba
                        let sobre = estado.sobre == "aba:" + aba.rawValue
                        let lado: Alignment = aba == abas.first ? .bottomLeading : (aba == abas.last ? .bottomTrailing : .bottom)
                        Button {
                            estado.abaAtual = aba
                            if aba != .geral { estado.editandoGeral = false }
                        } label: {
                            Image(systemName: aba.simbolo).font(.system(size: 12, weight: escolhida ? .semibold : .regular))
                                .foregroundStyle(Tinta.icone(aba.cor.opacity(escolhida || sobre ? 1 : 0.8),
                                                             senao: escolhida ? Tinta.texto : (sobre ? Tinta.apagado.opacity(1.4) : Tinta.apagado)))
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
            .simultaneousGesture(arrastar(abas, medida))
        }
        .frame(height: 26)
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 9).fill(Tinta.tinta.opacity(0.04)))
        .animation(Mexer.leve, value: estado.sobre)
    }

    private func arrastar(_ abas: [Aba], _ medida: ArrastoDaPilula) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { v in
                estado.arrastoDaAba = v.location.x
                estado.esticoDaAba = ArrastoDaPilula.estico(velocidade: v.velocity.width)
            }
            .onEnded { v in
                let aba = abas[medida.indice(em: v.location.x)]
                estado.arrastoDaAba = nil
                estado.esticoDaAba = 0
                estado.abaAtual = aba
                if aba != .geral { estado.editandoGeral = false }
            }
    }

    @ViewBuilder private var pilula: some View {
        let forma = RoundedRectangle(cornerRadius: 7, style: .continuous)
        if estado.aparencia.fundoReal != .solido, !estado.aparencia.chapado, !estado.paraImagem, #available(macOS 26, *) {
            Color.clear.glassEffect(.regular.interactive(), in: forma)
        } else {
            forma.fill(Tinta.tinta.opacity(0.11))
        }
    }
}

/// A conta do arrasto da pílula, fora da view para os testes chegarem.
struct ArrastoDaPilula {
    let largura: CGFloat
    let espaco: CGFloat
    let quantas: Int

    var passo: CGFloat { largura + espaco }

    /// A aba debaixo do mouse.
    func indice(em x: CGFloat) -> Int { min(max(0, Int((x / passo).rounded(.down))), quantas - 1) }

    /// Onde a pílula começa com o mouse em `x` (centrada nele, sem sair da barra).
    func inicio(em x: CGFloat) -> CGFloat { min(max(0, x - largura / 2), CGFloat(quantas - 1) * passo) }

    /// Quanto a pílula estica (fração da largura) com a velocidade do arrasto: o "líquido" do vidro.
    static func estico(velocidade: CGFloat) -> CGFloat { min(0.4, abs(velocidade) / 2000) }
}
