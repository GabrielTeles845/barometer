// A grade dos estilos prontos, cada um com uma miniatura desenhada com as cores e o fundo dele (e não com os
// do momento): dá para comparar todos lado a lado.

import SwiftUI

struct GradeDeEstilos: View {
    @ObservedObject var estado: Estado

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(Estilo.todos) { e in
                CartaoDeEstilo(estilo: e, escolhido: estado.aparencia == e.aparencia) {
                    withAnimation(Mexer.troca) { estado.aparencia = e.aparencia }
                }
            }
        }
    }
}

struct CartaoDeEstilo: View {
    let estilo: Estilo
    let escolhido: Bool
    let escolher: () -> Void

    var body: some View {
        Button(action: escolher) {
            VStack(alignment: .leading, spacing: 6) {
                MiniaturaDoEstilo(aparencia: estilo.aparencia).frame(height: 62)
                VStack(alignment: .leading, spacing: 1) {
                    Text(t(estilo.nome)).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Tinta.texto)
                    Text(t(estilo.descricao)).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                .padding(.horizontal, 2)
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.tinta.opacity(escolhido ? 0.08 : 0.035)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(escolhido ? Tinta.destaque : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Um painel de brinquedo: o fundo do estilo (com manchas de cor atrás, quando deixa ver), três anéis com as
/// cores da paleta e duas linhas de texto.
struct MiniaturaDoEstilo: View {
    let aparencia: Aparencia

    var body: some View {
        // A miniatura do "Junto com o Mac" é o mesmo painel, escuro na metade esquerda e claro na direita.
        if aparencia.modo == .automatico {
            ZStack {
                painel(escuro: true)
                painel(escuro: false).mask(HStack(spacing: 0) { Color.clear; Color.black })
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            painel(escuro: aparencia.modo == .escuro)
                .clipShape(RoundedRectangle(cornerRadius: min(aparencia.cantos, 14) * 0.6, style: .continuous))
        }
    }

    private func painel(escuro: Bool) -> some View {
        let tinta: Color = escuro ? .white : .black
        let fundo = escuro ? Color(red: 0.035, green: 0.035, blue: 0.04) : Color(red: 0.965, green: 0.965, blue: 0.972)
        let paleta = aparencia.paletaAtual.paraOModo(escuro: escuro)
        let deixaVer = aparencia.fundoReal != .solido
        return ZStack {
            if deixaVer {
                ZStack {
                    Color(red: 0.1, green: 0.11, blue: 0.12)
                    Circle().fill(Color(red: 1.0, green: 0.55, blue: 0.2)).frame(width: 46).offset(x: -34, y: -14)
                    Circle().fill(Color(red: 0.1, green: 0.75, blue: 0.7)).frame(width: 52).offset(x: 36, y: 16)
                }
                .blur(radius: aparencia.fundoReal == .fosco ? 9 : (aparencia.fundoReal == .vidro ? 5 : 2))
            }
            fundo.opacity(deixaVer ? aparencia.coberturaAtual : 1)
            HStack(spacing: 7) {
                ForEach(Array([paleta.cpu, paleta.memoria, paleta.gpu].enumerated()), id: \.offset) { i, cor in
                    ZStack {
                        Circle().stroke(tinta.opacity(0.1), lineWidth: 3)
                        Circle().trim(from: 0, to: [0.35, 0.65, 0.2][i]).stroke(cor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 20, height: 20)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().fill(tinta.opacity(0.55)).frame(width: 26, height: 3)
                    Capsule().fill(tinta.opacity(0.25)).frame(width: 18, height: 3)
                }
            }
            if aparencia.fundoReal == .vidro || aparencia.fundoReal == .vidroClaro {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.05), .white.opacity(0.25)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(tinta.opacity(0.08), lineWidth: 1))
    }
}
