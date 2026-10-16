// O estilo personalizado: uma fileira de cores para cada leitura, com a miniatura mudando junto.

import SwiftUI

struct EditorDeCores: View {
    @ObservedObject var estado: Estado
    /// Dentro de "Do meu jeito" ele aparece sem o cabeçalho de voltar.
    var comCabecalho = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if comCabecalho {
                HStack {
                    Button {
                        withAnimation(Mexer.troca) { estado.editandoCores = false }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                            Text(t("Estilos")).font(.system(size: 11.5, weight: .medium))
                        }
                        .foregroundStyle(Tinta.apagado)
                        .padding(.horizontal, 8).frame(height: 26)
                        .background(Capsule().fill(Tinta.tinta.opacity(0.06)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(t("Suas cores")).font(.system(size: 12, weight: .semibold)).foregroundStyle(Tinta.texto)
                }
                MiniaturaDoEstilo(aparencia: estado.aparencia, escuro: Tinta.escuro).frame(height: 62)
            }
            ForEach(Paleta.pintaveis, id: \.id) { leitura in
                HStack(spacing: 0) {
                    Text(t(leitura.nome)).font(.system(size: 11)).foregroundStyle(Tinta.apagado)
                        .frame(width: 62, alignment: .leading)
                    ForEach(Paleta.amostras, id: \.self) { hex in
                        Spacer(minLength: 0)
                        bolinha(hex, leitura: leitura.id)
                    }
                }
            }
        }
    }

    private func bolinha(_ hex: String, leitura: String) -> some View {
        let escolhida = estado.aparencia.cores[leitura] == hex
        return Button {
            estado.aparencia.cores[leitura] = hex
            estado.aparencia.paleta = Paleta.personalizadaId
        } label: {
            ZStack {
                Circle().fill(Paleta.cor(hex: hex) ?? .gray).frame(width: 17, height: 17)
                Circle().strokeBorder(escolhida ? Tinta.texto : .clear, lineWidth: 1.5).frame(width: 24, height: 24)
            }
            .frame(width: 24, height: 24)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
