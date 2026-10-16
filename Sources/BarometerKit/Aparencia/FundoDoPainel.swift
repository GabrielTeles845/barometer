import AppKit
import SwiftUI

/// Atrás de tudo no painel. Na tela, o fosco é o material do macOS e o vidro é o vidro líquido de verdade.
/// Na imagem (`--retrato`), nenhum dos dois se desenha fora da tela: o que está atrás (o `PapelDeParede` da foto)
/// é desfocado à mão, e a borda de luz do vidro é desenhada por cima. É só para a foto.
struct FundoDoPainel: View {
    let ap: Aparencia
    let paraImagem: Bool
    /// Na foto: onde o painel está sobre o papel de parede, para o desfoque casar com o que está atrás.
    var deslocamento: CGSize = .zero

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: ap.cantos, style: .continuous)
        let cobertura = ap.coberturaAtual
        switch ap.fundoReal {
        case .solido:
            if paraImagem && cobertura < 1 {
                ZStack { desfoqueDaFoto(raio: 2); forma.fill(Tinta.fundo.opacity(cobertura)) }.clipShape(forma)
            } else {
                forma.fill(Tinta.fundo.opacity(cobertura))
            }
        case .fosco:
            ZStack {
                if paraImagem { desfoqueDaFoto(raio: 30) } else { Fosco(cantos: ap.cantos, escuro: ap.escuroAgora) }
                forma.fill(Tinta.fundo.opacity(cobertura))
            }
            .clipShape(forma)
        case .vidro, .vidroClaro:
            if !paraImagem, #available(macOS 26, *) {
                Color.clear
                    .glassEffect((ap.fundo == .vidro ? Glass.regular : Glass.clear).tint(Tinta.fundo.opacity(cobertura)), in: forma)
            } else {
                ZStack {
                    desfoqueDaFoto(raio: ap.fundo == .vidro ? 22 : 9)
                    forma.fill(Tinta.fundo.opacity(cobertura * 0.9))
                    // A luz na borda e o reflexo de cima, como o vidro líquido desenha.
                    forma.strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.06), .white.opacity(0.22)],
                                                      startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                    forma.fill(LinearGradient(colors: [.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center))
                }
                .clipShape(forma)
            }
        }
    }

    private func desfoqueDaFoto(raio: CGFloat) -> some View {
        Color.clear.overlay(alignment: .topLeading) {
            PapelDeParede().offset(x: -deslocamento.width, y: -deslocamento.height).blur(radius: raio)
        }
    }
}

/// O fosco do macOS (o mesmo material dos menus em HUD), com os cantos do painel.
struct Fosco: NSViewRepresentable {
    let cantos: Double
    let escuro: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.blendingMode = .behindWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.masksToBounds = true
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = escuro ? .hudWindow : .popover
        v.appearance = NSAppearance(named: escuro ? .darkAqua : .aqua)
        v.layer?.cornerRadius = cantos
        v.layer?.cornerCurve = .continuous
    }
}

/// O que fica atrás do painel nas fotos de vidro: uma mesa escura com manchas de cor, para dar o que o vidro
/// mostrar. Tamanho fixo, para o desfoque de dentro do painel casar com o de fora.
struct PapelDeParede: View {
    static let tamanho = CGSize(width: 1100, height: 2200)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.07, green: 0.08, blue: 0.09)
            mancha(Color(red: 1.0, green: 0.55, blue: 0.2), 520, x: -170, y: 0)
            mancha(Color(red: 0.1, green: 0.75, blue: 0.7), 480, x: 200, y: 260)
            mancha(Color(red: 0.95, green: 0.3, blue: 0.45), 440, x: -140, y: 640)
            mancha(Color(red: 0.25, green: 0.55, blue: 1.0), 520, x: 190, y: 960)
            mancha(Color(red: 0.95, green: 0.8, blue: 0.3), 400, x: -120, y: 1320)
            mancha(Color(red: 0.2, green: 0.8, blue: 0.45), 460, x: 230, y: 1580)
            mancha(Color(red: 1.0, green: 0.45, blue: 0.25), 440, x: -100, y: 1880)
            // Riscos finos, para o vidro ter linha para entortar e desfocar.
            ForEach(0..<20, id: \.self) { i in
                Rectangle().fill(Color.white.opacity(0.05)).frame(width: PapelDeParede.tamanho.width, height: 1.5)
                    .offset(y: CGFloat(i) * 110 + 30)
            }
        }
        .frame(width: PapelDeParede.tamanho.width, height: PapelDeParede.tamanho.height, alignment: .topLeading)
        .clipped()
    }

    private func mancha(_ cor: Color, _ d: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle().fill(RadialGradient(colors: [cor.opacity(0.95), cor.opacity(0)], center: .center, startRadius: 0, endRadius: d / 2))
            .frame(width: d, height: d).offset(x: x, y: y)
    }
}
