import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

struct CartaoDoDisco: View {
    let disco: Disco

    var body: some View {
        let usado = max(0, disco.total - disco.livre)
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "internaldrive").font(.system(size: 11)).foregroundStyle(Tinta.disco)
                Text(disco.nome).font(.system(size: 12, weight: .medium)).foregroundStyle(Tinta.texto)
                Spacer()
                Text(t("\(Medida.espaco(disco.livre)) livres")).font(.system(size: 11, weight: .medium)).foregroundStyle(Tinta.texto)
                Text(t("de \(Medida.espaco(disco.total))")).font(.system(size: 11)).foregroundStyle(Tinta.fraco)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Tinta.tinta.opacity(0.06))
                    Capsule().fill(LinearGradient(colors: [Tinta.disco.opacity(0.65), Tinta.disco], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, g.size.width * CGFloat(disco.total > 0 ? usado / disco.total : 0)))
                }
            }
            .frame(height: 5)
            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down").font(.system(size: 9, weight: .bold)).foregroundStyle(Tinta.disco)
                    Text(t("leitura")).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
                    Text(Medida.velocidade(disco.leituraPorSegundo)).font(.system(size: 10, weight: .medium)).monospacedDigit().foregroundStyle(Tinta.apagado)
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up").font(.system(size: 9, weight: .bold)).foregroundStyle(Tinta.comprimida)
                    Text(t("escrita")).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
                    Text(Medida.velocidade(disco.escritaPorSegundo)).font(.system(size: 10, weight: .medium)).monospacedDigit().foregroundStyle(Tinta.apagado)
                }
                Spacer()
                Text(t("\(Int((disco.total > 0 ? usado / disco.total : 0) * 100))% usado")).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }
}

struct DetalhesDoDisco: View {
    let disco: Disco

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(t("DISCO")).font(.system(size: 9.5, weight: .bold)).foregroundStyle(Tinta.disco)
                Text(t("desde que o Mac ligou")).font(.system(size: 9.5)).foregroundStyle(Tinta.fraco)
                Spacer()
                Text(disco.nome).font(.system(size: 9.5, weight: .medium)).foregroundStyle(Tinta.apagado)
            }
            HStack(spacing: 0) {
                numero("lido", Medida.espaco(disco.lidoTotal), Tinta.disco)
                numero("escrito", Medida.espaco(disco.escritoTotal), Tinta.comprimida)
                numero("leituras", Self.milhares(disco.operacoesLeitura), Tinta.apagado)
                numero("escritas", Self.milhares(disco.operacoesEscrita), Tinta.apagado)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }

    private func numero(_ rotulo: String, _ valor: String, _ cor: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(valor).font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(cor)
            Text(t(rotulo)).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func milhares(_ n: Double) -> String {
        n >= 1_000_000 ? decimal(n / 1_000_000) + " mi"
                       : (n >= 1000 ? "\(Int(n / 1000)) mil" : "\(Int(n))")
    }
}
