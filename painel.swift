// O painel que abre ao clicar no ícone: preto, com os números em anéis, o gráfico
// das últimas horas e as listas compactas. Feito em SwiftUI porque o menu nativo
// do macOS não deixa nada disso (fundo, gráfico de verdade, linha fina com ×
// só ao passar o mouse).
//
// O painel só desenha: quem lê o sistema é a `Sonda`, a `Maquina` e os
// `Sensores` (barra.swift), e quem age (fechar, encerrar, abrir) é a `Barra`,
// pelas `Acoes`.

import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

// MARK: - O que o painel mostra

final class Estado: ObservableObject {
    @Published var portas: [Porta] = []
    @Published var ocultas: [(numero: Int, nome: String)] = []
    @Published var pontos: [Historico.Ponto] = []
    @Published var memoria: Maquina.Memoria?
    @Published var pressao = 1
    @Published var swap: Double = 0
    @Published var cpu: Double?
    @Published var temperatura = Sensores.Leitura(chip: nil, chipMaximo: nil, ssd: nil, bateria: nil)
    @Published var gastos: [Maquina.Gasto] = []
    @Published var gastosCPU: [Maquina.Gasto] = []
    @Published var cpuDetalhada: CPUDetalhada?
    @Published var gpu: GPU?
    @Published var disco: Disco?
    @Published var bateria: Bateria?
    /// "MacBook Pro · M3 Pro · 18 GB · macOS 27.0.1", embaixo do título do Geral.
    @Published var sobreMac: String?
    @Published var limpeza: [ItemDeLimpeza] = []
    @Published var medindoLimpeza = false
    /// Quanto a última limpeza liberou, para o aviso no topo da aba.
    @Published var liberado: Double?
    @Published var abaAtual: Aba = .geral
    @Published var editandoGeral = false
    /// Desenhando o painel como imagem (`--retrato`): o que não se desenha fora da tela fica de fora.
    var paraImagem = false
    /// O cartão que está sendo arrastado no editor do Geral.
    @Published var arrastando: String?
    /// Os cartões do Geral, na ordem escolhida, cada um ligado ou não. Gravados a cada mudança.
    @Published var geral: [ItemGeral] = Pref.geral { didSet { Pref.geral = geral } }
    /// Para a animação de abrir: o painel nasce um pouco menor e transparente e cresce até o tamanho.
    @Published var apareceu = true
    @Published var abaProcessos = 0
    @Published var favoritas: [Int] = []
    @Published var mostrarTudo = false
    @Published var abrirAoLigar = false
    @Published var memoriaNaBarra = true
    // O que o mouse está tocando e a aba do gráfico. Ficam aqui, e não em `@State`: as ferramentas de linha de
    // comando da Apple não trazem o plug-in de macro que o `@State` usa nesta versão do SwiftUI.
    @Published var sobre: String?
    @Published var sobreX: String?
    @Published var aba = 0
}

enum Aba: String, CaseIterable {
    case geral, cpu, memoria, gpu, disco, bateria, portas, limpeza

    var titulo: String { t(tituloEmPortugues) }

    private var tituloEmPortugues: String {
        switch self {
        case .geral: return "Geral"
        case .cpu: return "CPU"
        case .memoria: return "Memória"
        case .gpu: return "GPU"
        case .disco: return "Disco"
        case .bateria: return "Bateria"
        case .portas: return "Portas"
        case .limpeza: return "Limpeza"
        }
    }

    var simbolo: String {
        switch self {
        case .geral: return "square.grid.2x2"
        case .cpu: return "cpu"
        case .memoria: return "memorychip"
        case .gpu: return "cube.transparent"
        case .disco: return "internaldrive"
        case .bateria: return "battery.75percent"
        case .portas: return "point.3.connected.trianglepath.dotted"
        case .limpeza: return "trash"
        }
    }
}

/// Um cartão do Geral.
struct ItemGeral: Identifiable, Codable, Equatable {
    let id: String
    var ligado: Bool

    var nome: String { t(ItemGeral.nomes[id] ?? id) }

    static let nomes: [String: String] = [
        "aneis": "Visão rápida", "grafico": "Histórico", "disco": "Disco", "bateria": "Bateria",
        "memoria": "Memória por partes", "cpu": "Núcleos da CPU", "gpu": "GPU", "temperaturas": "Temperaturas",
        "processos": "O que mais usa", "portas": "Portas", "limpeza": "Limpeza",
    ]
    /// A ordem e o que vem ligado na primeira vez.
    static let padrao: [ItemGeral] = [
        .init(id: "aneis", ligado: true), .init(id: "grafico", ligado: true), .init(id: "disco", ligado: true),
        .init(id: "bateria", ligado: true), .init(id: "memoria", ligado: true), .init(id: "processos", ligado: true),
        .init(id: "portas", ligado: true), .init(id: "cpu", ligado: false), .init(id: "gpu", ligado: false),
        .init(id: "temperaturas", ligado: false), .init(id: "limpeza", ligado: false),
    ]
}

/// O tamanho do painel, para a janela acompanhar quando muda de aba ou de cartões.
struct TamanhoDoPainel: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// O que os botões do painel pedem à `Barra`.
struct Acoes {
    var abrirPorta: (Porta) -> Void = { _ in }
    var encerrarPorta: (Porta) -> Void = { _ in }
    var fechar: (Maquina.Gasto) -> Void = { _ in }
    var atualizar: () -> Void = {}
    var virarTudo: () -> Void = {}
    var virarAbrirAoLigar: () -> Void = {}
    var virarMemoriaNaBarra: () -> Void = {}
    var virarFavorita: (Int) -> Void = { _ in }
    var outraFavorita: () -> Void = {}
    var copiar: () -> Void = {}
    var monitor: () -> Void = {}
    /// A engrenagem abre um menu nativo (o `Menu` do SwiftUI não se desenha fora da tela, e a conferência é por imagem).
    var ajustes: () -> Void = {}
    var sair: () -> Void = {}
    var redimensionar: (CGSize) -> Void = { _ in }
    var limpar: (String) -> Void = { _ in }
    var limparTudo: () -> Void = {}
}

// MARK: - Cores

enum Tinta {
    static let fundo = Color(red: 0.035, green: 0.035, blue: 0.04)
    static let cartao = Color.white.opacity(0.045)
    static let borda = Color.white.opacity(0.08)
    static let texto = Color.white.opacity(0.92)
    static let apagado = Color.white.opacity(0.5)
    static let fraco = Color.white.opacity(0.3)
    static let memoria = Color(red: 0.36, green: 0.62, blue: 1.0)
    static let cpu = Color(red: 1.0, green: 0.62, blue: 0.27)
    static let calor = Color(red: 1.0, green: 0.36, blue: 0.36)
    static let porta = Color(red: 0.35, green: 0.85, blue: 0.6)
    static let fixa = Color(red: 0.66, green: 0.5, blue: 1.0)
    static let eficiencia = Color(red: 0.32, green: 0.83, blue: 0.86)
    static let gpu = Color(red: 0.78, green: 0.45, blue: 1.0)
    static let disco = Color(red: 0.4, green: 0.86, blue: 0.62)
    static let comprimida = Color(red: 1.0, green: 0.82, blue: 0.36)
    static let bateria = Color(red: 0.42, green: 0.9, blue: 0.45)

    static func pressao(_ n: Int) -> Color { n >= 4 ? calor : (n >= 2 ? cpu : porta) }
}

// MARK: - O painel

struct Painel: View {
    @ObservedObject var estado: Estado
    let acoes: Acoes

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cabecalho
            BarraDeAbas(estado: estado)
            VStack(alignment: .leading, spacing: 12) { conteudo }
                .id(estado.abaAtual.rawValue + (estado.editandoGeral ? "-editando" : ""))
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 8)), removal: .opacity))
            rodape
        }
        .padding(14)
        .frame(width: 360)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Tinta.fundo))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Tinta.borda, lineWidth: 1))
        .animation(.snappy(duration: 0.28), value: estado.abaAtual)
        .animation(.snappy(duration: 0.28), value: estado.editandoGeral)
        .animation(.snappy(duration: 0.28), value: estado.geral)
        .scaleEffect(estado.apareceu ? 1 : 0.96, anchor: .top)
        .opacity(estado.apareceu ? 1 : 0)
        .background(GeometryReader { g in Color.clear.preference(key: TamanhoDoPainel.self, value: g.size) })
        .onPreferenceChange(TamanhoDoPainel.self) { acoes.redimensionar($0) }
        .environment(\.colorScheme, .dark)
        .environmentObject(estado)
    }

    private var cabecalho: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(estado.abaAtual == .geral ? t("Este Mac") : estado.abaAtual.titulo)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Tinta.texto)
                if estado.abaAtual == .geral, let sobre = estado.sobreMac {
                    Text(sobre).font(.system(size: 10.5)).foregroundStyle(Tinta.fraco).fixedSize()
                }
            }
            Spacer()
            if estado.abaAtual == .geral {
                Button {
                    estado.editandoGeral.toggle()
                } label: {
                    Text(t(estado.editandoGeral ? "Pronto" : "Editar"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(estado.editandoGeral ? Tinta.fundo : Tinta.apagado)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Capsule().fill(estado.editandoGeral ? Tinta.texto : Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var conteudo: some View {
        switch estado.abaAtual {
        case .geral:
            if estado.editandoGeral {
                EditorDoGeral(estado: estado)
            } else {
                ForEach(estado.geral.filter(\.ligado)) { item in cartao(item.id) }
            }
        case .cpu:
            if let c = estado.cpuDetalhada, !c.nucleos.isEmpty { CartaoDaCPU(cpu: c) }
            Grafico(pontos: estado.pontos, aba: $estado.aba, fixa: 1)
            CartaoDeTemperaturas(t: estado.temperatura)
            Processos(estado: estado, fechar: acoes.fechar, fixo: 1)
        case .memoria:
            CartaoDaMemoria(estado: estado)
            Grafico(pontos: estado.pontos, aba: $estado.aba, fixa: 0)
            Processos(estado: estado, fechar: acoes.fechar, fixo: 0)
        case .gpu:
            if let g = estado.gpu { CartaoDaGPU(gpu: g) }
            Grafico(pontos: estado.pontos, aba: $estado.aba, fixa: 2)
        case .disco:
            if let d = estado.disco { CartaoDoDisco(disco: d); DetalhesDoDisco(disco: d) }
            Grafico(pontos: estado.pontos, aba: $estado.aba, fixa: 4)
        case .bateria:
            if let b = estado.bateria, b.existe { CartaoDaBateria(b: b) } else {
                Text(t("Este Mac não tem bateria.")).font(.system(size: 12)).foregroundStyle(Tinta.apagado)
            }
        case .portas:
            Portas(estado: estado, acoes: acoes)
        case .limpeza:
            CartaoDaLimpeza(estado: estado, acoes: acoes)
        }
    }

    @ViewBuilder private func cartao(_ id: String) -> some View {
        switch id {
        case "aneis": Aneis(estado: estado)
        case "grafico": Grafico(pontos: estado.pontos, aba: $estado.aba)
        case "disco": if let d = estado.disco { CartaoDoDisco(disco: d) }
        case "bateria": if let b = estado.bateria, b.existe { ResumoDaBateria(b: b) }
        case "memoria": if let m = estado.memoria { BarraDeMemoria(memoria: m, swap: estado.swap) }
        case "cpu": if let c = estado.cpuDetalhada, !c.nucleos.isEmpty { CartaoDaCPU(cpu: c) }
        case "gpu": if let g = estado.gpu { CartaoDaGPU(gpu: g) }
        case "temperaturas": CartaoDeTemperaturas(t: estado.temperatura)
        case "processos": Processos(estado: estado, fechar: acoes.fechar)
        case "portas": Portas(estado: estado, acoes: acoes)
        case "limpeza": ResumoDaLimpeza(estado: estado)
        default: EmptyView()
        }
    }

    private var rodape: some View {
        HStack(spacing: 4) {
            Botaozinho(simbolo: "arrow.clockwise", dica: "Atualizar agora", acao: acoes.atualizar)
            Botaozinho(simbolo: estado.mostrarTudo ? "eye.fill" : "eye", dica: "Mostrar todas as portas", acao: acoes.virarTudo)
            Botaozinho(simbolo: "gauge.with.dots.needle.33percent", dica: "Abrir o Monitor de Atividade", acao: acoes.monitor)
            Botaozinho(simbolo: "doc.on.clipboard", dica: "Copiar a lista de portas", acao: acoes.copiar)
            Spacer()
            Botaozinho(simbolo: "gearshape", dica: "Ajustes", acao: acoes.ajustes)
        }
        .padding(.top, 2)
    }
}

/// As abas: um ícone para cada área, o nome ao passar o mouse.
struct BarraDeAbas: View {
    @ObservedObject var estado: Estado

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Aba.allCases, id: \.self) { aba in
                let escolhida = estado.abaAtual == aba
                let sobre = estado.sobre == "aba:" + aba.rawValue
                Button {
                    estado.abaAtual = aba
                    if aba != .geral { estado.editandoGeral = false }
                } label: {
                    Image(systemName: aba.simbolo).font(.system(size: 12, weight: escolhida ? .semibold : .regular))
                        .foregroundStyle(escolhida ? Tinta.texto : (sobre ? Tinta.apagado.opacity(1.4) : Tinta.apagado))
                        .frame(maxWidth: .infinity).frame(height: 26)
                        .background(RoundedRectangle(cornerRadius: 7).fill(escolhida ? Color.white.opacity(0.11) : (sobre ? Color.white.opacity(0.05) : .clear)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(aba.titulo)
                .onHover { estado.sobre = $0 ? "aba:" + aba.rawValue : (estado.sobre == "aba:" + aba.rawValue ? nil : estado.sobre) }
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.04)))
        .animation(.easeOut(duration: 0.15), value: estado.abaAtual)
        .animation(.easeOut(duration: 0.12), value: estado.sobre)
    }
}

/// Escolher e arrastar os cartões do Geral, como a Central de Controle: segure uma linha e leve para cima ou
/// para baixo; as outras abrem espaço enquanto ela passa. Linhas próprias, e não a `List` do sistema: a da lista
/// nativa destoava do painel preto e não se desenha na conferência por imagem.
struct EditorDoGeral: View {
    @ObservedObject var estado: Estado

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("Ligue o que quer ver no Geral. Segure e arraste para mudar a ordem."))
                .font(.system(size: 11)).foregroundStyle(Tinta.apagado)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 4) {
                ForEach(estado.geral) { item in
                    if estado.paraImagem {
                        // O desenho como imagem não sabe desenhar o arrastar; a linha é a mesma.
                        linha(item)
                    } else {
                        linha(item)
                            .opacity(estado.arrastando == item.id ? 0.35 : 1)
                            .onDrag {
                                estado.arrastando = item.id
                                return NSItemProvider(object: item.id as NSString)
                            }
                            .onDrop(of: [.text], delegate: Reordenar(alvo: item.id, estado: estado))
                    }
                }
            }
            .animation(.snappy(duration: 0.22), value: estado.geral)
            Button { estado.geral = ItemGeral.padrao } label: {
                Text(t("Voltar ao padrão")).font(.system(size: 11)).foregroundStyle(Tinta.fraco)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    private func linha(_ item: ItemGeral) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal").font(.system(size: 11, weight: .medium)).foregroundStyle(Tinta.fraco)
            Text(item.nome).font(.system(size: 12)).foregroundStyle(item.ligado ? Tinta.texto : Tinta.apagado)
            Spacer()
            Interruptor(ligado: item.ligado) {
                if let i = estado.geral.firstIndex(where: { $0.id == item.id }) { estado.geral[i].ligado.toggle() }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(item.ligado ? 0.06 : 0.03)))
        .contentShape(Rectangle())
    }
}

/// Enquanto a linha arrastada passa por cima de outra, troca as duas de lugar (com animação).
struct Reordenar: DropDelegate {
    let alvo: String
    let estado: Estado

    func dropEntered(info: DropInfo) {
        guard let de = estado.arrastando, de != alvo,
              let a = estado.geral.firstIndex(where: { $0.id == de }),
              let b = estado.geral.firstIndex(where: { $0.id == alvo }) else { return }
        withAnimation(.snappy(duration: 0.22)) {
            estado.geral.move(fromOffsets: IndexSet(integer: a), toOffset: b > a ? b + 1 : b)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        estado.arrastando = nil
        return true
    }
}

/// Interruptor no estilo do painel (o do sistema fica cinza-claro sobre o preto).
struct Interruptor: View {
    let ligado: Bool
    let virar: () -> Void

    var body: some View {
        Button(action: virar) {
            ZStack(alignment: ligado ? .trailing : .leading) {
                Capsule().fill(ligado ? Tinta.porta.opacity(0.85) : Color.white.opacity(0.12))
                Circle().fill(Color.white).padding(2).shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
            }
            .frame(width: 30, height: 17)
            .animation(.snappy(duration: 0.2), value: ligado)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Anéis

struct Aneis: View {
    @ObservedObject var estado: Estado

    var body: some View {
        let mem = estado.memoria.map { $0.usada / Maquina.total }
        // Quatro colunas do mesmo tamanho; o que não cabe no rótulo vai para dentro do anel, em letra pequena.
        HStack(spacing: 0) {
            Anel(valor: estado.cpu ?? 0, cor: Tinta.cpu,
                 texto: estado.cpu.map { "\(Int(($0 * 100).rounded()))%" } ?? "…", rotulo: "CPU")
            Anel(valor: mem ?? 0, cor: Tinta.memoria,
                 texto: mem.map { "\(Int(($0 * 100).rounded()))%" } ?? "…",
                 rotulo: "Memória", detalhe: estado.memoria.map { Maquina.gb($0.usada) },
                 ponto: Tinta.pressao(estado.pressao))
            Anel(valor: estado.gpu?.uso ?? 0, cor: Tinta.gpu,
                 texto: estado.gpu.map { "\(Int(($0.uso * 100).rounded()))%" } ?? "–", rotulo: "GPU")
            Anel(valor: estado.temperatura.chip.map { ($0 - 20) / 80 } ?? 0, cor: Tinta.calor,
                 texto: estado.temperatura.chip.map { "\(Int($0.rounded()))°" } ?? "–",
                 rotulo: "Chip", detalhe: estado.temperatura.chipMaximo.map { "máx \(Int($0.rounded()))°" })
        }
    }
}

struct Anel: View {
    let valor: Double
    let cor: Color
    let texto: String
    let rotulo: String
    /// Segunda linha, pequena, dentro do anel ("8,8 GB", "máx 46°").
    var detalhe: String?
    /// A bolinha da pressão da memória, ao lado do rótulo (verde, laranja, vermelho).
    var ponto: Color?
    var tamanho: CGFloat = 56

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.07), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(min(1, max(0.001, valor))))
                    .stroke(AngularGradient(colors: [cor.opacity(0.5), cor], center: .center,
                                            startAngle: .degrees(0), endAngle: .degrees(360 * max(0.05, valor))),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: cor.opacity(0.35), radius: 4)
                    .animation(.spring(response: 0.7, dampingFraction: 0.85), value: valor)
                VStack(spacing: 0) {
                    Text(texto).font(.system(size: tamanho > 60 ? 18 : 13.5, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Tinta.texto)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: texto)
                    if let detalhe {
                        Text(t(detalhe)).font(.system(size: 8.5, weight: .medium)).monospacedDigit().foregroundStyle(Tinta.fraco)
                            .fixedSize()
                    }
                }
            }
            .frame(width: tamanho, height: tamanho)
            HStack(spacing: 3) {
                if let ponto { Circle().fill(ponto).frame(width: 5, height: 5) }
                Text(t(rotulo)).font(.system(size: 10)).foregroundStyle(Tinta.apagado).fixedSize()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Gráfico

struct Grafico: View {
    let pontos: [Historico.Ponto]
    @Binding var aba: Int
    /// Na aba de uma área, o gráfico é só dela: sem as pílulas, com o título.
    var fixa: Int? = nil
    private var atual: Int { fixa ?? aba }

    private var titulo: [(String, Color)] {
        [("Memória", Tinta.memoria), ("CPU", Tinta.cpu), ("GPU", Tinta.gpu), ("Temp.", Tinta.calor), ("Disco", Tinta.disco)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                if let fixa {
                    Text(t("Histórico")).font(.system(size: 11, weight: .semibold)).foregroundStyle(Tinta.texto)
                    Circle().fill(titulo[fixa].1).frame(width: 6, height: 6).padding(.leading, 4)
                }
                ForEach(fixa == nil ? Array(0..<titulo.count) : [], id: \.self) { i in
                    Button { aba = i } label: {
                        Text(t(titulo[i].0)).font(.system(size: 10.5, weight: aba == i ? .semibold : .regular))
                            .foregroundStyle(aba == i ? Tinta.texto : Tinta.apagado)
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(Capsule().fill(aba == i ? Color.white.opacity(0.1) : .clear))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(t(alcance)).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
            }
            if pontos.count < 2 {
                Text(t("Juntando as primeiras leituras (uma por minuto)."))
                    .font(.system(size: 11)).foregroundStyle(Tinta.fraco)
                    .frame(maxWidth: .infinity, minHeight: 96)
            } else {
                grafico.frame(height: 96)
                    .animation(.easeInOut(duration: 0.35), value: aba)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }

    private var alcance: String {
        guard let primeiro = pontos.first?.quando else { return "últimas 6 h" }
        let minutos = Int(Date().timeIntervalSince(primeiro) / 60)
        return minutos < 60 ? "últimos \(max(1, minutos)) min" : "últimas \(min(6, minutos / 60)) h"
    }

    private func valor(_ p: Historico.Ponto) -> Double? {
        switch atual {
        case 0: return p.memoria * 100
        case 1: return p.cpu * 100
        case 2: return p.gpu * 100
        case 3: return p.chip
        default: return p.disco / 1_048_576
        }
    }

    private var grafico: some View {
        let aba = atual
        let cor = titulo[aba].1
        // Disco em MB/s, com o teto do maior pico (no mínimo 10 MB/s, para o ruído não virar montanha).
        let picoDisco = max(10, (pontos.map(\.disco).max() ?? 0) / 1_048_576 * 1.1)
        let dominio: ClosedRange<Double> = aba == 3 ? 20...100 : (aba == 4 ? 0...picoDisco : 0...100)
        let marcas: [Double] = aba == 3 ? [40, 70, 100] : (aba == 4 ? [0, (picoDisco / 2).rounded(), picoDisco.rounded()] : [0, 50, 100])
        let unidade = aba == 3 ? "°" : (aba == 4 ? "" : "%")
        return Chart {
            ForEach(Array(pontos.enumerated()), id: \.offset) { _, p in
                if let v = valor(p) {
                    AreaMark(x: .value("hora", p.quando), yStart: .value("base", dominio.lowerBound), yEnd: .value("valor", v))
                        .foregroundStyle(LinearGradient(colors: [cor.opacity(0.35), cor.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("hora", p.quando), y: .value("valor", v))
                        .foregroundStyle(cor)
                        .lineStyle(StrokeStyle(lineWidth: 1.6))
                        .interpolationMethod(.monotone)
                }
            }
        }
        .chartYScale(domain: dominio)
        .chartYAxis {
            AxisMarks(position: .trailing, values: marcas) { v in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel {
                    Text("\(Int(v.as(Double.self) ?? 0))\(unidade)\(aba == 4 && (v.as(Double.self) ?? 0) > 0 ? " MB/s" : "")")
                        .font(.system(size: 9)).foregroundStyle(Tinta.fraco)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { v in
                AxisValueLabel(format: .dateTime.hour().minute()).font(.system(size: 9)).foregroundStyle(Tinta.fraco)
            }
        }
    }
}

// MARK: - Disco e GPU

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
                    Capsule().fill(Color.white.opacity(0.06))
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

struct CartaoDaGPU: View {
    let gpu: GPU

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(t("GPU")).font(.system(size: 9.5, weight: .bold)).foregroundStyle(Tinta.gpu)
                Text([gpu.modelo, gpu.nucleos.map { "\($0) núcleos" }].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 9.5)).foregroundStyle(Tinta.fraco)
                Spacer()
                Text(t("memória \(Maquina.gb(gpu.memoriaEmUso))")).font(.system(size: 9.5, weight: .medium)).foregroundStyle(Tinta.apagado)
            }
            barra("uso", gpu.uso)
            barra("renderer", gpu.renderer)
            barra("tiler", gpu.tiler)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }

    private func barra(_ rotulo: String, _ v: Double) -> some View {
        HStack(spacing: 8) {
            Text(t(rotulo)).font(.system(size: 10)).foregroundStyle(Tinta.fraco).frame(width: 52, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule().fill(LinearGradient(colors: [Tinta.gpu.opacity(0.6), Tinta.gpu], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(3, g.size.width * CGFloat(min(1, v))))
                        .animation(.easeOut(duration: 0.45), value: v)
                }
            }
            .frame(height: 5)
            Text(t("\(Int((v * 100).rounded()))%")).font(.system(size: 10, weight: .medium)).monospacedDigit()
                .foregroundStyle(Tinta.apagado).frame(width: 32, alignment: .trailing)
        }
    }
}

// MARK: - Bateria, temperaturas e memória em destaque

struct CartaoDaBateria: View {
    let b: Bateria

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Anel(valor: Double(b.nivel) / 100, cor: corDaCarga, texto: "\(b.nivel)%", rotulo: "", tamanho: 78)
                    .frame(width: 80)
                VStack(alignment: .leading, spacing: 4) {
                    Text(t(situacao)).font(.system(size: 14, weight: .semibold)).foregroundStyle(Tinta.texto)
                    if let r = restante { Text(t(r)).font(.system(size: 11)).foregroundStyle(Tinta.apagado) }
                    if b.naTomada, let nome = b.carregador ?? b.carregadorWatts.map({ "carregador de \($0) W" }) {
                        Text(t(nome)).font(.system(size: 10)).foregroundStyle(Tinta.fraco).fixedSize()
                    }
                    if let w = b.consumo {
                        Text(t("o Mac está gastando \(numero(w, casas: 1)) W")).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
                    }
                }
                Spacer(minLength: 0)
            }
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    Ladrilho(titulo: "Saúde", valor: b.saudeOficial.map { "\($0)%" } ?? saudeCalculada ?? "–",
                             detalhe: b.condicaoOficial ?? "da capacidade original", cor: Tinta.bateria,
                             barra: b.saudeOficial.map { Double($0) / 100 })
                    Ladrilho(titulo: "Ciclos", valor: b.ciclos.map(String.init) ?? "–",
                             detalhe: b.ciclosDeProjeto.map { "de \($0) previstos" } ?? "",
                             cor: Tinta.comprimida,
                             barra: b.ciclos.flatMap { c in b.ciclosDeProjeto.map { Double(c) / Double($0) } })
                }
                GridRow {
                    Ladrilho(titulo: "Capacidade", valor: b.capacidadeAtual.map { "\(milhar($0)) mAh" } ?? "–",
                             detalhe: b.capacidadeDeProjeto.map { "de \(milhar($0)) mAh de fábrica" } ?? "", cor: Tinta.memoria)
                    Ladrilho(titulo: "Temperatura", valor: b.temperatura.map { "\(Int($0.rounded())) °C" } ?? "–",
                             detalhe: "da bateria", cor: Tinta.calor)
                }
                GridRow {
                    Ladrilho(titulo: "Voltagem", valor: b.volts.map { "\(numero($0, casas: 2)) V" } ?? "–", detalhe: "agora", cor: Tinta.eficiencia)
                    Ladrilho(titulo: "Corrente", valor: b.amperes.map { "\(numero($0, casas: 2)) A" } ?? "–",
                             detalhe: (b.amperes ?? 0) < 0 ? "saindo da bateria" : ((b.amperes ?? 0) > 0 ? "entrando" : "parada"), cor: Tinta.gpu)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }

    private var corDaCarga: Color { b.nivel <= 15 ? Tinta.calor : (b.nivel <= 30 ? Tinta.comprimida : Tinta.bateria) }

    private var situacao: String {
        if b.carregando { return "Carregando" }
        if b.naTomada { return b.carregada || b.nivel >= 100 ? "Carregada, na tomada" : "Na tomada, sem carregar" }
        return "Na bateria"
    }

    private var restante: String? {
        guard let m = b.minutosRestantes else {
            return b.naTomada && !b.carregando && b.nivel < 100 ? "carga otimizada pelo macOS" : nil
        }
        let t = m >= 60 ? "\(m / 60) h \(m % 60) min" : "\(m) min"
        return b.carregando ? "cheia em \(t)" : "\(t) restantes"
    }

    private var saudeCalculada: String? {
        guard let a = b.capacidadeAtual, let p = b.capacidadeDeProjeto, p > 0 else { return nil }
        return "\(Int((Double(a) / Double(p) * 100).rounded()))%"
    }

    private func numero(_ v: Double, casas: Int) -> String { decimal(v, casas: casas) }
}

/// A bateria numa linha, para o Geral.
struct ResumoDaBateria: View {
    let b: Bateria

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).stroke(Tinta.apagado, lineWidth: 1).frame(width: 26, height: 13)
                RoundedRectangle(cornerRadius: 1.5).fill(b.nivel <= 15 ? Tinta.calor : Tinta.bateria)
                    .frame(width: max(2, 22 * CGFloat(b.nivel) / 100), height: 9).padding(.leading, 2)
                    .animation(.easeOut(duration: 0.5), value: b.nivel)
            }
            Text(t("\(b.nivel)%")).font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(Tinta.texto)
                .contentTransition(.numericText())
            Text(t(b.carregando ? "carregando" : (b.naTomada ? "na tomada" : "na bateria")))
                .font(.system(size: 11)).foregroundStyle(Tinta.apagado)
            Spacer()
            if let c = b.ciclos { Text(t("\(c) ciclos")).font(.system(size: 10)).foregroundStyle(Tinta.fraco) }
            if let s = b.saudeOficial { Text(t("saúde \(s)%")).font(.system(size: 10, weight: .medium)).foregroundStyle(Tinta.apagado) }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }
}

struct CartaoDeTemperaturas: View {
    let t: Sensores.Leitura

    var body: some View {
        HStack(spacing: 8) {
            Ladrilho(titulo: "Chip", valor: t.chip.map { "\(Int($0.rounded()))°" } ?? "–",
                     detalhe: t.chipMaximo.map { "máx \(Int($0.rounded()))°" } ?? "", cor: Tinta.calor)
            Ladrilho(titulo: "SSD", valor: t.ssd.map { "\(Int($0.rounded()))°" } ?? "–", detalhe: "disco", cor: Tinta.disco)
            Ladrilho(titulo: "Bateria", valor: t.bateria.map { "\(Int($0.rounded()))°" } ?? "–", detalhe: "célula", cor: Tinta.bateria)
        }
    }
}

struct CartaoDaMemoria: View {
    @ObservedObject var estado: Estado

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let m = estado.memoria {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Maquina.gb(m.usada)).font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Tinta.texto).contentTransition(.numericText())
                    Text(t("de \(Maquina.gb(Maquina.total)) em uso")).font(.system(size: 12)).foregroundStyle(Tinta.apagado)
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(Tinta.pressao(estado.pressao)).frame(width: 6, height: 6)
                        Text(estado.pressao >= 4 ? "no limite" : estado.pressao >= 2 ? "apertada" : "folgada")
                            .font(.system(size: 11)).foregroundStyle(Tinta.apagado)
                    }
                }
                BarraDeMemoria(memoria: m, swap: estado.swap)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }
}

/// Um número com título e uma linha de contexto; com `barra`, uma barrinha de proporção embaixo.
struct Ladrilho: View {
    let titulo: String
    let valor: String
    let detalhe: String
    let cor: Color
    var barra: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(t(titulo).uppercased()).font(.system(size: 8.5, weight: .semibold)).tracking(0.5).foregroundStyle(cor.opacity(0.85))
            Text(valor).font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(Tinta.texto).contentTransition(.numericText())
            if let barra {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.07))
                        Capsule().fill(cor).frame(width: max(3, g.size.width * CGFloat(min(1, barra))))
                            .animation(.easeOut(duration: 0.5), value: barra)
                    }
                }
                .frame(height: 3)
            }
            Text(t(detalhe)).font(.system(size: 9.5)).foregroundStyle(Tinta.fraco).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.035)))
    }
}

// MARK: - Limpeza

struct CartaoDaLimpeza: View {
    @ObservedObject var estado: Estado
    let acoes: Acoes

    var body: some View {
        let total = estado.limpeza.filter { !$0.ehLixeira }.compactMap(\.bytes).reduce(0, +)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if estado.medindoLimpeza && estado.limpeza.allSatisfy({ $0.bytes == nil }) {
                    Text(t("Medindo…")).font(.system(size: 13)).foregroundStyle(Tinta.apagado)
                } else {
                    Text(Maquina.gb(total)).font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Tinta.texto).contentTransition(.numericText())
                    Text(t("podem sair sem perder nada seu")).font(.system(size: 11)).foregroundStyle(Tinta.apagado)
                }
                Spacer()
            }
            if let l = estado.liberado {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Tinta.porta)
                    Text(t("Liberou \(Maquina.gb(l)).")).font(.system(size: 11, weight: .medium)).foregroundStyle(Tinta.texto)
                }
                .transition(.opacity)
            }
            VStack(spacing: 4) {
                ForEach(estado.limpeza) { item in
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t(item.nome)).font(.system(size: 12, weight: .medium)).foregroundStyle(Tinta.texto)
                            Text(t(item.explicacao)).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 6)
                        Text(item.bytes.map(Maquina.gb) ?? (estado.medindoLimpeza ? "…" : "–"))
                            .font(.system(size: 11, weight: .medium)).monospacedDigit().foregroundStyle(Tinta.apagado)
                            .contentTransition(.numericText())
                        Button { acoes.limpar(item.id) } label: {
                            Text(t(item.ehLixeira ? "Esvaziar" : "Limpar")).font(.system(size: 11, weight: .medium))
                                .foregroundStyle(item.ehLixeira ? Tinta.calor : Tinta.texto)
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .disabled((item.bytes ?? 1) == 0)
                        .opacity((item.bytes ?? 1) == 0 ? 0.35 : 1)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.035)))
                }
            }
            Button(action: acoes.limparTudo) {
                Text(t("Limpar tudo (menos a Lixeira)")).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tinta.fundo)
                    .frame(maxWidth: .infinity).frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Tinta.texto))
            }
            .buttonStyle(.plain)
            .disabled(total == 0)
            .opacity(total == 0 ? 0.4 : 1)
            Text(t("Documentos, downloads e fotos nunca entram aqui. Cada limpeza pede confirmação."))
                .font(.system(size: 10)).foregroundStyle(Tinta.fraco).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
        .animation(.snappy, value: estado.liberado)
    }
}

/// A limpeza numa linha, para o Geral: quanto dá para liberar, e um toque leva para a aba.
struct ResumoDaLimpeza: View {
    @ObservedObject var estado: Estado

    var body: some View {
        let total = estado.limpeza.filter { !$0.ehLixeira }.compactMap(\.bytes).reduce(0, +)
        Button { estado.abaAtual = .limpeza } label: {
            HStack(spacing: 10) {
                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Tinta.comprimida)
                Text(total > 0 ? t("\(Maquina.gb(total)) para limpar") : t("Limpeza"))
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Tinta.texto)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Tinta.fraco)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Memória numa barra

struct BarraDeMemoria: View {
    let memoria: Maquina.Memoria
    let swap: Double

    var body: some View {
        let partes: [(String, Double, Color)] = [
            ("apps", memoria.apps, Tinta.memoria), ("fixa", memoria.fixa, Tinta.fixa),
            ("comprimida", memoria.comprimida, Tinta.comprimida), ("cache", memoria.cache, Color.white.opacity(0.22)),
        ]
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { g in
                HStack(spacing: 1.5) {
                    ForEach(partes, id: \.0) { p in
                        RoundedRectangle(cornerRadius: 2).fill(p.2)
                            .frame(width: max(2, g.size.width * CGFloat(p.1 / Maquina.total)))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 7)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.05)))
            // Duas linhas de três, com o valor alinhado: numa linha só não cabia e cortava com reticências.
            let itens = partes.map { ($0.0, Maquina.gb($0.1), $0.2) } + (swap > 0 ? [("swap", Maquina.gb(swap), Color.white.opacity(0.1))] : [])
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 3) {
                ForEach(Array(stride(from: 0, to: itens.count, by: 3)), id: \.self) { inicio in
                    GridRow {
                        ForEach(inicio..<min(inicio + 3, itens.count), id: \.self) { i in
                            HStack(spacing: 5) {
                                Circle().fill(itens[i].2).frame(width: 5, height: 5)
                                Text(t(itens[i].0)).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
                                Text(itens[i].1).font(.system(size: 10, weight: .medium)).monospacedDigit().foregroundStyle(Tinta.apagado)
                            }
                            .fixedSize()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Processos

struct Processos: View {
    @ObservedObject var estado: Estado
    let fechar: (Maquina.Gasto) -> Void
    /// Na aba CPU ou Memória, a lista é só daquela medida.
    var fixo: Int? = nil

    var body: some View {
        let porCPU = (fixo ?? estado.abaProcessos) == 1
        let gastos = porCPU ? estado.gastosCPU : estado.gastos
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Text(t("O QUE MAIS USA") + (fixo.map { " " + t($0 == 1 ? "CPU" : "memória").uppercased() } ?? ""))
                    .font(.system(size: 9.5, weight: .semibold)).tracking(0.6).foregroundStyle(Tinta.fraco)
                    .padding(.trailing, 4)
                ForEach(fixo == nil ? Array(["Memória", "CPU"].indices) : [], id: \.self) { i in
                    Button { estado.abaProcessos = i } label: {
                        Text(t(["memória", "CPU"][i])).font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(estado.abaProcessos == i ? Tinta.texto : Tinta.fraco)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(estado.abaProcessos == i ? Color.white.opacity(0.1) : .clear))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(t("× fecha")).font(.system(size: 9.5)).foregroundStyle(Tinta.fraco.opacity(0.8))
            }
            .padding(.horizontal, 6).padding(.top, 4).padding(.bottom, 2)
            let maior = max(0.0001, gastos.map { porCPU ? $0.cpu : $0.bytes }.max() ?? 1)
            ForEach(gastos, id: \.nome) { g in
                Linha(id: "g:" + g.nome + "\(g.pid)", podeFechar: g.meu, fechar: { fechar(g) }) {
                    HStack(spacing: 6) {
                        IconeDoProcesso(app: g.app)
                        // O nome nunca corta; a descrição some quando não cabe (nada de reticências).
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) {
                                Text(Self.nomeCurto(g.nome)).font(.system(size: 12)).foregroundStyle(Tinta.texto).fixedSize()
                                Text(t(detalhe(g))).font(.system(size: 10)).foregroundStyle(Tinta.fraco).fixedSize()
                            }
                            Text(Self.nomeCurto(g.nome)).font(.system(size: 12)).foregroundStyle(Tinta.texto).fixedSize()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Capsule().fill((porCPU ? Tinta.cpu : Tinta.memoria).opacity(0.7))
                            .frame(width: 34 * CGFloat((porCPU ? g.cpu : g.bytes) / maior), height: 3)
                            .frame(width: 34, alignment: .trailing)
                        Text(porCPU ? "\(Int(g.cpu.rounded()))%" : Maquina.gb(g.bytes))
                            .font(.system(size: 11, weight: .medium)).monospacedDigit()
                            .foregroundStyle(Tinta.apagado).frame(width: 52, alignment: .trailing)
                            .contentTransition(.numericText())
                    }
                }
            }
        }
        .animation(.snappy(duration: 0.3), value: gastos.map(\.nome))
    }

    /// "com.apple.AppleUserHIDDrivers" vira "AppleUserHIDDrivers": o prefixo não diz nada e empurra o resto.
    static func nomeCurto(_ nome: String) -> String {
        nome.hasPrefix("com.") ? (nome.split(separator: ".").last.map(String.init) ?? nome) : nome
    }

    private func detalhe(_ g: Maquina.Gasto) -> String {
        if g.pid == ProcessInfo.processInfo.processIdentifier || g.nome == "Barometer" { return "este app" }
        if let o = Maquina.doSistema[g.nome].map(t) { return g.meu ? o : t("sistema · ") + o }
        if !g.meu { return "sistema" }
        if g.processos > 1 { return "\(g.processos) proc." }
        return g.projeto ?? ""
    }
}

// MARK: - CPU

/// Uma barra por núcleo, os de eficiência (E) e os de desempenho (P) em cores diferentes, a frequência de cada
/// grupo e os números miúdos: usuário, sistema, carga, tempo ligado e estado térmico.
struct CartaoDaCPU: View {
    let cpu: CPUDetalhada

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                grupo(cpu.nucleos.filter(\.eficiencia), cor: Tinta.eficiencia, rotulo: "E", ghz: cpu.ghzE)
                grupo(cpu.nucleos.filter { !$0.eficiencia }, cor: Tinta.cpu, rotulo: "P", ghz: cpu.ghzP)
            }
            HStack(spacing: 10) {
                miudo("usuário", "\(Int((cpu.usuario * 100).rounded()))%")
                miudo("sistema", "\(Int((cpu.sistema * 100).rounded()))%")
                miudo("carga", decimal(cpu.carga.0))
                if let d = cpu.ligadoDesde { miudo("ligado há", tempo(desde: d)) }
                Spacer(minLength: 0)
                // O estado térmico só aparece quando sai do normal: "tudo bem" o tempo todo é ruído.
                if cpu.termico != .nominal {
                    HStack(spacing: 4) {
                        Circle().fill(corTermica).frame(width: 5, height: 5)
                        Text(t(textoTermico)).font(.system(size: 10, weight: .medium)).foregroundStyle(corTermica)
                    }
                    .fixedSize()
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tinta.cartao))
    }

    private func grupo(_ nucleos: [Nucleo], cor: Color, rotulo: String, ghz: Double?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(rotulo).font(.system(size: 9.5, weight: .bold)).foregroundStyle(cor)
                Text(t(rotulo == "E" ? "eficiência" : "desempenho")).font(.system(size: 9.5)).foregroundStyle(Tinta.fraco)
                Spacer(minLength: 2)
                if let ghz {
                    Text(decimal(ghz, casas: 2) + " GHz")
                        .font(.system(size: 9.5, weight: .medium)).monospacedDigit().foregroundStyle(Tinta.apagado)
                }
            }
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(nucleos.indices, id: \.self) { i in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(colors: [cor, cor.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                            .frame(height: max(2, 34 * CGFloat(min(1, nucleos[i].uso))))
                            .animation(.easeOut(duration: 0.45), value: nucleos[i].uso)
                    }
                    .frame(height: 34)
                }
            }
        }
    }

    private func miudo(_ rotulo: String, _ valor: String) -> some View {
        HStack(spacing: 3) {
            Text(t(rotulo)).font(.system(size: 10)).foregroundStyle(Tinta.fraco)
            Text(valor).font(.system(size: 10, weight: .medium)).monospacedDigit().foregroundStyle(Tinta.apagado)
        }
        .fixedSize()
    }

    private func tempo(desde d: Date) -> String {
        let m = Int(Date().timeIntervalSince(d) / 60)
        if m < 60 { return "\(m) min" }
        if m < 60 * 24 { return "\(m / 60) h" }
        return "\(m / 1440) d \(m / 60 % 24) h"
    }

    private var textoTermico: String {
        switch cpu.termico {
        case .nominal: return "temperatura ok"
        case .fair: return "esquentando"
        case .serious: return "quente, reduzindo"
        default: return "muito quente"
        }
    }

    private var corTermica: Color {
        switch cpu.termico {
        case .nominal: return Tinta.porta
        case .fair: return Tinta.comprimida
        case .serious: return Tinta.cpu
        default: return Tinta.calor
        }
    }
}

/// O ícone de verdade do aplicativo (o do Finder); processo solto ganha o de terminal.
struct IconeDoProcesso: View {
    let app: String?

    /// O ícone do Finder vem num espaço de cor amplo, e com ele o desenho do painel como imagem saía todo
    /// clareado. Redesenhado uma vez em sRGB, 32 px, e guardado.
    private static var guardados: [String: NSImage] = [:]
    static func emSRGB(_ caminho: String) -> NSImage {
        if let pronto = guardados[caminho] { return pronto }
        let original = NSWorkspace.shared.icon(forFile: caminho)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)?
            .retagging(with: .sRGB) else { return original }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        original.draw(in: NSRect(x: 0, y: 0, width: 32, height: 32))
        NSGraphicsContext.restoreGraphicsState()
        let img = NSImage(size: NSSize(width: 32, height: 32))
        img.addRepresentation(rep)
        guardados[caminho] = img
        return img
    }

    var body: some View {
        if let app {
            Image(nsImage: IconeDoProcesso.emSRGB(app)).resizable().interpolation(.high)
                .frame(width: 15, height: 15)
        } else {
            Image(systemName: "terminal").font(.system(size: 9, weight: .medium)).foregroundStyle(Tinta.fraco)
                .frame(width: 15, height: 15)
                .background(RoundedRectangle(cornerRadius: 3.5).fill(Color.white.opacity(0.07)))
        }
    }
}

// MARK: - Portas

struct Portas: View {
    @ObservedObject var estado: Estado
    let acoes: Acoes

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Secao(titulo: estado.portas.isEmpty ? "Nenhuma porta ouvindo" : "Portas ouvindo",
                  dica: estado.portas.isEmpty ? "" : "clique abre · × encerra")
            ForEach(estado.portas, id: \.numero) { p in
                Linha(id: "p:\(p.numero)", podeFechar: true, fechar: { acoes.encerrarPorta(p) }, clique: { acoes.abrirPorta(p) }) {
                    HStack(spacing: 8) {
                        Text(verbatim: String(p.numero)).font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Tinta.porta).frame(width: 44, alignment: .leading)
                        Text(p.comoChamar).font(.system(size: 12)).foregroundStyle(Tinta.texto).lineLimit(1)
                        if let c = p.contexto, c != p.comoChamar {
                            Text(c).font(.system(size: 10)).foregroundStyle(Tinta.fraco).lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        if p.doDocker {
                            Text(t("docker")).font(.system(size: 9, weight: .medium)).foregroundStyle(Tinta.memoria)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(Tinta.memoria.opacity(0.14)))
                        }
                    }
                }
            }
            let livres = estado.favoritas.filter { n in !estado.portas.contains { $0.numero == n } }
            if !livres.isEmpty {
                Text(t("livres: " + livres.map(String.init).joined(separator: " · ")))
                    .font(.system(size: 10)).foregroundStyle(Tinta.fraco).padding(.horizontal, 6).padding(.top, 2)
            }
            if !estado.ocultas.isEmpty {
                Text(t("ocultas: " + estado.ocultas.prefix(5).map { "\($0.numero) \($0.nome)" }.joined(separator: " · "))
                     + (estado.ocultas.count > 5 ? t(" e mais \(estado.ocultas.count - 5)") : ""))
                    .font(.system(size: 10)).foregroundStyle(Tinta.fraco).lineLimit(2).padding(.horizontal, 6)
            }
        }
    }
}

// MARK: - Peças

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

struct Botaozinho: View {
    let simbolo: String
    let dica: String
    let acao: () -> Void
    @EnvironmentObject var estado: Estado
    private var sobre: Bool { estado.sobre == "b:" + simbolo }

    var body: some View {
        Button(action: acao) {
            Image(systemName: simbolo).font(.system(size: 12))
                .foregroundStyle(sobre ? Tinta.texto : Tinta.apagado)
                .frame(width: 28, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(sobre ? Color.white.opacity(0.08) : .clear))
        }
        .buttonStyle(.plain)
        .help(t(dica))
        .onHover { estado.sobre = $0 ? "b:" + simbolo : (estado.sobre == "b:" + simbolo ? nil : estado.sobre) }
    }
}

// MARK: - O ícone da barra

/// Duas barrinhas, CPU e memória, que sobem e descem com o uso, e o número de
/// portas ao lado. Imagem "modelo" (só a forma): o macOS pinta de branco ou
/// preto conforme o fundo da barra.
enum Icone {
    static func desenhar(cpu: Double, memoria: Double, mostrarUso: Bool) -> NSImage {
        let largura: CGFloat = mostrarUso ? 15 : 16
        let img = NSImage(size: NSSize(width: largura, height: 16), flipped: false) { _ in
            NSColor.black.setFill()
            NSColor.black.setStroke()
            if mostrarUso {
                // Trilho apagado (35%) e o nível cheio: a forma dá para ler mesmo a 16 px.
                for (i, v) in [cpu, memoria].enumerated() {
                    let x: CGFloat = 3 + CGFloat(i) * 6
                    NSColor.black.withAlphaComponent(0.32).setFill()
                    NSBezierPath(roundedRect: NSRect(x: x, y: 2, width: 3.6, height: 12), xRadius: 1.8, yRadius: 1.8).fill()
                    NSColor.black.setFill()
                    let altura = max(2.5, 12 * CGFloat(min(1, max(0, v))))
                    NSBezierPath(roundedRect: NSRect(x: x, y: 2, width: 3.6, height: altura), xRadius: 1.8, yRadius: 1.8).fill()
                }
            } else {
                // Sem o uso: um anel com um ponto, a "porta".
                let anel = NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 12, height: 12))
                anel.lineWidth = 1.6
                anel.stroke()
                NSBezierPath(ovalIn: NSRect(x: 6, y: 6, width: 4, height: 4)).fill()
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}
