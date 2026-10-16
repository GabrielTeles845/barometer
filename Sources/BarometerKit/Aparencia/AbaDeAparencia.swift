import AppKit
import SwiftUI

struct AbaDeAparencia: View {
    @ObservedObject var estado: Estado

    var body: some View {
        let ap = estado.aparencia
        VStack(alignment: .leading, spacing: 14) {
            secao("FUNDO") {
                HStack(spacing: 6) {
                    ForEach(Aparencia.Fundo.allCases, id: \.self) { f in amostraDeFundo(f, escolhido: ap.fundo == f) }
                }
                if !Aparencia.Fundo.vidro.existe {
                    Text(t("O vidro líquido precisa do macOS 26 ou mais novo."))
                        .font(.system(size: 10.5)).foregroundStyle(Tinta.fraco)
                }
            }
            secao("TRANSPARÊNCIA", valor: "\(Int(((1 - ap.coberturaAtual) * 100).rounded()))%") {
                Regua(valor: 1 - ap.coberturaAtual, limite: 0.9) { estado.aparencia.coberturaAtual = 1 - $0 }
                HStack {
                    Text(t("fechado")); Spacer(); Text(t("transparente"))
                }
                .font(.system(size: 9.5)).foregroundStyle(Tinta.fraco)
            }
            secao("CORES") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                          spacing: 6) {
                    ForEach(Paleta.todas) { p in amostraDePaleta(p, escolhida: ap.paleta == p.id) }
                }
            }
            secao("DESTAQUE") {
                HStack(spacing: 0) {
                    bolinha(nil, cor: ap.paletaAtual.destaque, escolhida: ap.destaque == nil, dica: "Da paleta")
                    ForEach(Paleta.destaques) { d in
                        Spacer(minLength: 0)
                        bolinha(d.id, cor: d.cor, escolhida: ap.destaque == d.id, dica: nil)
                    }
                }
            }
            secao("CANTOS") {
                Escolha(opcoes: [(t("Retos"), 8.0), (t("Médios"), 14.0), (t("Redondos"), 22.0)],
                        atual: ap.cantos, vidro: ap.fundoReal != .solido && !estado.paraImagem) { estado.aparencia.cantos = $0 }
            }
            secao("MOVIMENTO") {
                Escolha(opcoes: Aparencia.Movimento.allCases.map { ($0.nome, $0) },
                        atual: ap.movimento, vidro: ap.fundoReal != .solido && !estado.paraImagem) { estado.aparencia.movimento = $0 }
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Ícone colorido na barra")).font(.system(size: 12)).foregroundStyle(Tinta.texto)
                    Text(t("As barrinhas e os ícones com as cores do painel."))
                        .font(.system(size: 10.5)).foregroundStyle(Tinta.fraco)
                }
                Spacer()
                Interruptor(ligado: ap.iconeColorido) { estado.aparencia.iconeColorido.toggle() }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 9).fill(Tinta.cartao))
            if ap != Aparencia() {
                Button {
                    withAnimation(Mexer.troca) { estado.aparencia = Aparencia() }
                } label: {
                    Text(t("Voltar ao padrão")).font(.system(size: 11, weight: .medium)).foregroundStyle(Tinta.apagado)
                        .frame(maxWidth: .infinity).frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .animation(Mexer.leve, value: estado.aparencia)
    }

    private func secao<C: View>(_ titulo: String, valor: String? = nil, @ViewBuilder _ conteudo: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(t(titulo)).font(.system(size: 9.5, weight: .semibold)).tracking(0.6).foregroundStyle(Tinta.fraco)
                Spacer()
                if let valor {
                    Text(valor).font(.system(size: 10.5, weight: .medium)).monospacedDigit().foregroundStyle(Tinta.apagado)
                        
                }
            }
            conteudo()
        }
    }

    /// Um quadradinho com o fundo de verdade em miniatura: preto, fosco, vidro e vidro claro sobre manchas de cor.
    private func amostraDeFundo(_ f: Aparencia.Fundo, escolhido: Bool) -> some View {
        let forma = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return Button {
            guard f.existe else { return }
            estado.aparencia.fundo = f
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    // As mesmas manchas para os quatro: a diferença é o quanto cada fundo deixa passar.
                    ZStack {
                        Color(red: 0.1, green: 0.11, blue: 0.12)
                        Circle().fill(Color(red: 1.0, green: 0.55, blue: 0.2)).frame(width: 30).offset(x: -16, y: -10)
                        Circle().fill(Color(red: 0.1, green: 0.75, blue: 0.7)).frame(width: 34).offset(x: 18, y: 12)
                    }
                    .blur(radius: f == .fosco ? 7 : f == .vidro ? 4 : f == .vidroClaro ? 1.5 : 0)
                    forma.fill(Tinta.fundo.opacity(f == .solido ? 1 : f == .fosco ? 0.5 : f == .vidro ? 0.35 : 0.2))
                    if f == .vidro || f == .vidroClaro {
                        forma.strokeBorder(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.05), .white.opacity(0.25)],
                                                          startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    }
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.5)).frame(width: 22, height: 3).offset(y: -6)
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.25)).frame(width: 30, height: 3).offset(y: 2)
                }
                .frame(height: 46)
                .clipShape(forma)
                .overlay(forma.strokeBorder(escolhido ? Tinta.destaque : Tinta.borda, lineWidth: escolhido ? 1.5 : 1))
                Text(f.nome).font(.system(size: 10.5, weight: escolhido ? .semibold : .regular))
                    .foregroundStyle(escolhido ? Tinta.texto : Tinta.apagado).lineLimit(1).minimumScaleFactor(0.8)
            }
            .opacity(f.existe ? 1 : 0.35)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(f.existe ? f.nome : t("O vidro líquido precisa do macOS 26 ou mais novo."))
    }

    private func amostraDePaleta(_ p: Paleta, escolhida: Bool) -> some View {
        Button {
            estado.aparencia.paleta = p.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 3) {
                    ForEach(Array([p.cpu, p.memoria, p.gpu, p.disco, p.bateria].enumerated()), id: \.offset) { _, cor in
                        Capsule().fill(cor).frame(height: 14)
                    }
                }
                Text(t(p.nome)).font(.system(size: 10.5, weight: escolhida ? .semibold : .regular))
                    .foregroundStyle(escolhida ? Tinta.texto : Tinta.apagado)
            }
            .padding(7)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(escolhida ? 0.09 : 0.035)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(escolhida ? Tinta.destaque.opacity(0.7) : .clear, lineWidth: 1.2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func bolinha(_ id: String?, cor: Color, escolhida: Bool, dica: String?) -> some View {
        Button {
            estado.aparencia.destaque = id
        } label: {
            ZStack {
                if id == nil {
                    // "Da paleta": a bolinha com as cores da paleta em gomos, para não parecer só mais uma cor.
                    let p = estado.aparencia.paletaAtual
                    Circle().fill(AngularGradient(colors: [p.cpu, p.memoria, p.gpu, p.disco, p.cpu], center: .center))
                        .frame(width: 20, height: 20)
                } else {
                    Circle().fill(cor).frame(width: 20, height: 20)
                }
                Circle().strokeBorder(escolhida ? Tinta.texto : .clear, lineWidth: 1.5).frame(width: 27, height: 27)
            }
            .frame(width: 28, height: 28)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(dica.map(t) ?? "")
    }
}
