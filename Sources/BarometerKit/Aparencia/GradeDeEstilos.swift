// A grade dos estilos prontos, mais o personalizado no fim. Cada miniatura é desenhada com as cores e o fundo
// do estilo, no modo de agora (claro ou escuro): dá para comparar todos lado a lado. Escolher um estilo nunca
// muda o modo.

import SwiftUI

struct GradeDeEstilos: View {
    @ObservedObject var estado: Estado

    var body: some View {
        if estado.editandoCores {
            EditorDeCores(estado: estado)
        } else {
          VStack(spacing: 8) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Estilo.todos) { e in
                    CartaoDeEstilo(nome: e.nome, descricao: e.descricao, aparencia: e.aplicado(em: estado.aparencia),
                                   escolhido: e.aparencia.igualTirandoModo(estado.aparencia)) {
                        withAnimation(Mexer.troca) { estado.aparencia = e.aplicado(em: estado.aparencia) }
                    }
                }
            }
            CartaoPersonalizado(aparencia: personalizada, escolhido: estado.aparencia.paleta == Paleta.personalizadaId) {
                withAnimation(Mexer.troca) {
                    estado.aparencia = personalizada
                    estado.editandoCores = true
                }
            }
          }
        }
    }

    /// A aparência de agora com a paleta personalizada; na primeira vez, começa das cores que a pessoa está vendo.
    private var personalizada: Aparencia {
        var a = estado.aparencia
        if a.cores.isEmpty { a.cores = Paleta.coresDePartida(de: a.paletaAtual) }
        a.paleta = Paleta.personalizadaId
        return a
    }
}

/// O personalizado, largo, embaixo dos estilos: a miniatura com as cores escolhidas e o convite para escolher.
struct CartaoPersonalizado: View {
    let aparencia: Aparencia
    let escolhido: Bool
    let escolher: () -> Void

    var body: some View {
        Button(action: escolher) {
            HStack(spacing: 10) {
                MiniaturaDoEstilo(aparencia: aparencia, escuro: Tinta.escuro).frame(width: 140, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Personalizado")).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Tinta.texto)
                    Text(t("Escolha a cor de cada leitura.")).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Tinta.fraco)
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.tinta.opacity(escolhido ? 0.08 : 0.035)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(escolhido ? Tinta.destaque : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CartaoDeEstilo: View {
    let nome: String
    let descricao: String
    let aparencia: Aparencia
    let escolhido: Bool
    let escolher: () -> Void

    var body: some View {
        Button(action: escolher) {
            VStack(alignment: .leading, spacing: 6) {
                MiniaturaDoEstilo(aparencia: aparencia, escuro: Tinta.escuro).frame(height: 62)
                VStack(alignment: .leading, spacing: 1) {
                    Text(t(nome)).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Tinta.texto)
                    Text(t(descricao)).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
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
    let escuro: Bool

    var body: some View {
        let tinta: Color = escuro ? .white : .black
        let fundo = escuro ? Color(red: 0.035, green: 0.035, blue: 0.04) : Color(red: 0.965, green: 0.965, blue: 0.972)
        let paleta = aparencia.paletaAtual.paraOModo(escuro: escuro)
        let deixaVer = aparencia.fundoReal != .solido
        let forma = RoundedRectangle(cornerRadius: min(aparencia.cantos, 14) * 0.6, style: .continuous)
        ZStack {
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
                forma.strokeBorder(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.05), .white.opacity(0.25)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
        }
        .clipShape(forma)
        .overlay(forma.strokeBorder(tinta.opacity(0.08), lineWidth: 1))
    }
}
