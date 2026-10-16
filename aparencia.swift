// Aparência: o fundo do painel (preto, fosco ou vidro líquido), quanto ele deixa ver atrás, as cores, os cantos,
// o jeito de mexer e o ícone colorido na barra. Tudo fica na aba Aparência e vale na hora, sem reabrir.
//
// O vidro líquido é o material do macOS 26 (`glassEffect`). Em Mac mais antigo, as duas opções de vidro
// aparecem apagadas e o painel fica no fosco.

import AppKit
import SwiftUI

struct Aparencia: Codable, Equatable {
    enum Fundo: String, Codable, CaseIterable {
        case solido, fosco, vidro, vidroClaro

        var nome: String {
            switch self {
            case .solido: return t("Sólido")
            case .fosco: return t("Fosco")
            case .vidro: return t("Vidro")
            case .vidroClaro: return t("Vidro claro")
            }
        }

        /// O vidro líquido só existe do macOS 26 em diante.
        var existe: Bool {
            switch self {
            case .solido, .fosco: return true
            case .vidro, .vidroClaro:
                if #available(macOS 26, *) { return true }
                return false
            }
        }

        /// Quanto o fundo cobre quando a pessoa ainda não mexeu: o sólido fecha, o vidro deixa ver.
        var coberturaPadrao: Double {
            switch self {
            case .solido: return 1
            case .fosco: return 0.55
            case .vidro: return 0.4
            case .vidroClaro: return 0.3
            }
        }
    }

    enum Movimento: String, Codable, CaseIterable {
        case suave, mola, nenhum

        var nome: String {
            switch self {
            case .suave: return t("Suave")
            case .mola: return t("Com mola")
            case .nenhum: return t("Sem animação")
            }
        }
    }

    var fundo: Fundo = .solido
    /// Quanto cada fundo cobre (1 = nada passa), guardado por fundo: trocar de vidro para sólido não perde o ajuste.
    var cobertura: [String: Double] = [:]
    var paleta: String = Paleta.padrao.id
    /// nil = a cor de destaque da paleta.
    var destaque: String?
    var cantos: Double = 14
    var movimento: Movimento = .suave
    var iconeColorido = false

    var coberturaAtual: Double {
        get { cobertura[fundo.rawValue] ?? fundo.coberturaPadrao }
        set { cobertura[fundo.rawValue] = min(1, max(0.1, newValue)) }
    }

    /// O fundo que de fato aparece: vidro em Mac sem vidro vira fosco.
    var fundoReal: Fundo { fundo.existe ? fundo : .fosco }

    var paletaAtual: Paleta { Paleta.todas.first { $0.id == paleta } ?? .padrao }

    var corDeDestaque: Color {
        if let destaque, let cor = Paleta.destaques.first(where: { $0.id == destaque }) { return cor.cor }
        return paletaAtual.destaque
    }

    /// O que muda as cores do painel inteiro: quando muda, o painel se redesenha de cima a baixo.
    var chaveDasCores: String { paleta + "-" + (destaque ?? "") }

    /// A aparência em uso, para as cores (`Tinta`) e as animações (`Mexer`), que não recebem o `Estado`.
    static var atual: Aparencia = Pref.aparencia

    /// Decodifica campo a campo: campo novo de uma versão nova não apaga o que a pessoa já tinha escolhido.
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        fundo = (try? c.decode(Fundo.self, forKey: .fundo)) ?? .solido
        cobertura = (try? c.decode([String: Double].self, forKey: .cobertura)) ?? [:]
        paleta = (try? c.decode(String.self, forKey: .paleta)) ?? Paleta.padrao.id
        destaque = try? c.decode(String.self, forKey: .destaque)
        cantos = (try? c.decode(Double.self, forKey: .cantos)) ?? 14
        movimento = (try? c.decode(Movimento.self, forKey: .movimento)) ?? .suave
        iconeColorido = (try? c.decode(Bool.self, forKey: .iconeColorido)) ?? false
    }
}

/// As cores de cada leitura. O vermelho do calor não muda: é aviso, e aviso tem de continuar parecendo aviso.
struct Paleta: Identifiable {
    let id: String
    let nome: String
    let cpu: Color
    let memoria: Color
    let gpu: Color
    let disco: Color
    let bateria: Color
    let porta: Color
    let fixa: Color
    let eficiencia: Color
    let comprimida: Color
    let destaque: Color

    private static func c(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }

    static let padrao = Paleta(
        id: "padrao", nome: "Padrão",
        cpu: Color(red: 1.0, green: 0.62, blue: 0.27), memoria: Color(red: 0.36, green: 0.62, blue: 1.0),
        gpu: Color(red: 0.78, green: 0.45, blue: 1.0), disco: Color(red: 0.4, green: 0.86, blue: 0.62),
        bateria: Color(red: 0.42, green: 0.9, blue: 0.45), porta: Color(red: 0.35, green: 0.85, blue: 0.6),
        fixa: Color(red: 0.66, green: 0.5, blue: 1.0), eficiencia: Color(red: 0.32, green: 0.83, blue: 0.86),
        comprimida: Color(red: 1.0, green: 0.82, blue: 0.36), destaque: Color(red: 0.35, green: 0.85, blue: 0.6))

    static let todas: [Paleta] = [
        padrao,
        Paleta(id: "neon", nome: "Neon", cpu: c(0xFF6A2B), memoria: c(0x2F8CFF), gpu: c(0xD04DFF), disco: c(0x12F0A8),
               bateria: c(0x8CFF3F), porta: c(0x12F0A8), fixa: c(0xA35CFF), eficiencia: c(0x00E5FF),
               comprimida: c(0xFFE433), destaque: c(0x12F0A8)),
        Paleta(id: "pastel", nome: "Pastel", cpu: c(0xFFB894), memoria: c(0xA3C8FF), gpu: c(0xD9BBFF), disco: c(0xA9E7CB),
               bateria: c(0xBDE9A6), porta: c(0xA3E3C8), fixa: c(0xCBB9FF), eficiencia: c(0xA9E4EA),
               comprimida: c(0xFFE2A6), destaque: c(0xA3C8FF)),
        Paleta(id: "oceano", nome: "Oceano", cpu: c(0xFFA26E), memoria: c(0x4FC3F7), gpu: c(0x7F9CFF), disco: c(0x26C6DA),
               bateria: c(0x4DD0B1), porta: c(0x4DD0E1), fixa: c(0x8C9EFF), eficiencia: c(0x84E1EC),
               comprimida: c(0xFFD180), destaque: c(0x4FC3F7)),
        Paleta(id: "entardecer", nome: "Entardecer", cpu: c(0xFF7A59), memoria: c(0xFF5C93), gpu: c(0xC77DFF), disco: c(0xFFB547),
               bateria: c(0xFFD166), porta: c(0xFF9E7A), fixa: c(0xE0609F), eficiencia: c(0xFFC07A),
               comprimida: c(0xFFE08A), destaque: c(0xFF7A59)),
        Paleta(id: "mono", nome: "Grafite", cpu: Color(white: 0.92), memoria: Color(white: 0.72), gpu: Color(white: 0.58),
               disco: Color(white: 0.82), bateria: Color(white: 0.88), porta: Color(white: 0.9), fixa: Color(white: 0.5),
               eficiencia: Color(white: 0.66), comprimida: Color(white: 0.42), destaque: Color(white: 0.92)),
    ]

    /// A cor dos interruptores, do que está escolhido e dos marcadores. "Da paleta" fica de fora (é o nil).
    struct Destaque: Identifiable {
        let id: String
        let cor: Color
    }

    static let destaques: [Destaque] = [
        .init(id: "verde", cor: c(0x5AD99A)), .init(id: "azul", cor: c(0x4C9BFF)), .init(id: "ciano", cor: c(0x3FD4E0)),
        .init(id: "roxo", cor: c(0xA77BFF)), .init(id: "rosa", cor: c(0xFF6FAE)), .init(id: "vermelho", cor: c(0xFF5F5F)),
        .init(id: "laranja", cor: c(0xFF9F45)), .init(id: "amarelo", cor: c(0xFFD54A)),
    ]
}

/// As animações do painel, conforme o "jeito de mexer" escolhido. `nil` desliga.
enum Mexer {
    /// Trocar de aba, abrir o editor, ligar e desligar cartões.
    static var troca: Animation? {
        switch Aparencia.atual.movimento {
        case .suave: return .snappy(duration: 0.28)
        case .mola: return .spring(response: 0.42, dampingFraction: 0.68)
        case .nenhum: return nil
        }
    }

    /// Coisas pequenas (passar o mouse, a pílula da aba, interruptor).
    static var leve: Animation? {
        switch Aparencia.atual.movimento {
        case .suave: return .snappy(duration: 0.2)
        case .mola: return .spring(response: 0.32, dampingFraction: 0.62)
        case .nenhum: return nil
        }
    }

    /// Um número ou uma barra mudando de valor: com "Sem animação", pula direto.
    static func valor(_ a: Animation) -> Animation? { Aparencia.atual.movimento == .nenhum ? nil : a }

    /// O conteúdo que entra ao trocar de aba: sobe um pouco e sai do desfoque.
    static var entrada: AnyTransition {
        switch Aparencia.atual.movimento {
        case .nenhum: return .identity
        case .suave: return .asymmetric(insertion: .opacity.combined(with: .offset(y: 8)), removal: .opacity)
        case .mola:
            return .asymmetric(
                insertion: .modifier(active: Desfoque(raio: 8, escala: 0.97), identity: Desfoque(raio: 0, escala: 1))
                    .combined(with: .opacity).combined(with: .offset(y: 10)),
                removal: .opacity)
        }
    }
}

struct Desfoque: ViewModifier {
    let raio: CGFloat
    let escala: CGFloat
    func body(content: Content) -> some View { content.blur(radius: raio).scaleEffect(escala, anchor: .top) }
}

// MARK: - O fundo do painel

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
                if paraImagem { desfoqueDaFoto(raio: 30) } else { Fosco(cantos: ap.cantos) }
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

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.appearance = NSAppearance(named: .darkAqua)
        v.wantsLayer = true
        v.layer?.masksToBounds = true
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
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

// MARK: - A aba Aparência

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

/// Opções lado a lado com a pílula escolhida deslizando de uma para a outra. Com fundo de vidro, a pílula é de
/// vidro líquido também.
struct Escolha<V: Equatable>: View {
    let opcoes: [(String, V)]
    let atual: V
    let vidro: Bool
    let escolher: (V) -> Void

    var body: some View {
        let i = opcoes.firstIndex { $0.1 == atual } ?? 0
        GeometryReader { g in
            let largura = (g.size.width - 6) / CGFloat(max(1, opcoes.count))
            ZStack(alignment: .leading) {
                pilula.frame(width: largura, height: g.size.height - 6).offset(x: 3 + CGFloat(i) * largura)
                    .animation(Mexer.leve, value: i)
                HStack(spacing: 0) {
                    ForEach(Array(opcoes.enumerated()), id: \.offset) { n, o in
                        Button { escolher(o.1) } label: {
                            Text(o.0).font(.system(size: 11, weight: n == i ? .semibold : .regular))
                                .foregroundStyle(n == i ? Tinta.texto : Tinta.apagado)
                                .frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
            }
        }
        .frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.04)))
    }

    @ViewBuilder private var pilula: some View {
        let forma = RoundedRectangle(cornerRadius: 7, style: .continuous)
        if vidro, #available(macOS 26, *) {
            Color.clear.glassEffect(.regular.interactive(), in: forma)
        } else {
            forma.fill(Color.white.opacity(0.11))
        }
    }
}

/// Uma régua de arrastar, no desenho do painel (o controle do sistema destoava do preto e não sai na foto).
struct Regua: View {
    let valor: Double
    /// O máximo que dá para arrastar (a transparência para em 90%, senão o texto some no fundo).
    var limite: Double = 1
    let mudar: (Double) -> Void

    var body: some View {
        GeometryReader { g in
            let x = CGFloat(min(valor, limite) / limite) * (g.size.width - 18)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1)).frame(height: 5)
                Capsule().fill(LinearGradient(colors: [Tinta.destaque.opacity(0.6), Tinta.destaque], startPoint: .leading, endPoint: .trailing))
                    .frame(width: x + 9, height: 5)
                Circle().fill(Color.white).frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .offset(x: x)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let p = min(1, max(0, (v.location.x - 9) / max(1, g.size.width - 18)))
                mudar(Double(p) * limite)
            })
        }
        .frame(height: 22)
    }
}
