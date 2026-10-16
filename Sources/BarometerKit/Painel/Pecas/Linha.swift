import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

struct Secao: View {
    let titulo: String
    let dica: String

    var body: some View {
        HStack {
            Text(t(titulo).uppercased()).font(.system(size: 9.5, weight: .semibold)).tracking(0.6).foregroundStyle(Tinta.fraco)
            Spacer()
            Text(t(dica)).font(.system(size: 9.5)).foregroundStyle(Tinta.fraco.opacity(0.8))
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}

/// Uma linha fina (24 pt) que acende ao passar o mouse e mostra o × só aí.
struct Linha<Conteudo: View>: View {
    let id: String
    let podeFechar: Bool
    let fechar: () -> Void
    var clique: (() -> Void)?
    @ViewBuilder let conteudo: () -> Conteudo
    @EnvironmentObject var estado: Estado
    private var sobre: Bool { estado.sobre == id }
    private var sobreX: Bool { estado.sobreX == id }

    var body: some View {
        HStack(spacing: 4) {
            conteudo()
            if podeFechar {
                Button(action: fechar) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                        .foregroundStyle(sobreX ? Color.white : Tinta.apagado)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(sobreX ? Tinta.calor.opacity(0.85) : Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .opacity(sobre ? 1 : 0)
                .onHover { estado.sobreX = $0 ? id : (estado.sobreX == id ? nil : estado.sobreX) }
            }
            else {
                // Sem ×, o mesmo espaço: os valores ficam na mesma coluna das outras linhas.
                Color.clear.frame(width: 18, height: 18)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 24)
        .background(RoundedRectangle(cornerRadius: 6).fill(sobre ? Color.white.opacity(0.07) : .clear))
        .animation(.easeOut(duration: 0.12), value: sobre)
        .animation(.easeOut(duration: 0.12), value: sobreX)
        .contentShape(Rectangle())
        .onHover { estado.sobre = $0 ? id : (estado.sobre == id ? nil : estado.sobre) }
        .onTapGesture { clique?() }
    }
}
