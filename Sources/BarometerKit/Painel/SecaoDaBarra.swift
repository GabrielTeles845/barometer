import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

/// Escolher até 3 coisas para a barra de menus, cada uma com o ícone dela.
struct SecaoDaBarra: View {
    @ObservedObject var estado: Estado

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t("NA BARRA DE MENUS")).font(.system(size: 9.5, weight: .semibold)).tracking(0.6).foregroundStyle(Tinta.fraco)
                Spacer()
                Text(t("até 3")).font(.system(size: 9.5)).foregroundStyle(Tinta.fraco)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                ForEach(ItemDaBarra.allCases, id: \.self) { item in
                    let escolhido = estado.naBarra.contains(item)
                    let cheio = !escolhido && estado.naBarra.count >= ItemDaBarra.maximo
                    Button {
                        if let i = estado.naBarra.firstIndex(of: item) { estado.naBarra.remove(at: i) }
                        else if !cheio { estado.naBarra.append(item) }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: item.simbolo).font(.system(size: 11))
                                .foregroundStyle(escolhido ? Tinta.texto : Tinta.apagado).frame(width: 16)
                            Text(item.nome).font(.system(size: 11)).foregroundStyle(escolhido ? Tinta.texto : Tinta.apagado)
                                .lineLimit(1).minimumScaleFactor(0.85)
                            Spacer(minLength: 0)
                            if let n = estado.naBarra.firstIndex(of: item) {
                                Text(verbatim: String(n + 1)).font(.system(size: 9, weight: .bold)).foregroundStyle(Tinta.fundo)
                                    .frame(width: 15, height: 15).background(Circle().fill(Tinta.destaque))
                            }
                        }
                        .padding(.horizontal, 8).frame(height: 30)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Tinta.tinta.opacity(escolhido ? 0.1 : 0.035)))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(escolhido ? Tinta.destaque.opacity(0.5) : .clear, lineWidth: 1))
                        .opacity(cheio ? 0.5 : 1)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(cheio)
                }
            }
            .animation(.snappy(duration: 0.2), value: estado.naBarra)
        }
    }
}
