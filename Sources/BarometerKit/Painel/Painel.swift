// O painel que abre ao clicar no ícone: preto, com os números em anéis, o gráfico
// das últimas horas e as listas compactas. Feito em SwiftUI porque o menu nativo
// do macOS não deixa nada disso (fundo, gráfico de verdade, linha fina com ×
// só ao passar o mouse).
//
// O painel só desenha: quem lê o sistema é a `Sonda`, a `Maquina` e os
// `Sensores` (pastas Leitores e Sistema), e quem age (fechar, encerrar, abrir) é a `Barra`,
// pelas `Acoes`.

import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

/// O tamanho do painel, para a janela acompanhar quando muda de aba ou de cartões.
struct TamanhoDoPainel: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

struct Painel: View {
    @ObservedObject var estado: Estado
    let acoes: Acoes

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if estado.boasVindas {
                BoasVindas(estado: estado, comecar: acoes.terminarBoasVindas)
            } else {
                cabecalho
                BarraDeAbas(estado: estado).zIndex(1)
                VStack(alignment: .leading, spacing: 12) { conteudo }
                    .id(estado.abaAtual.rawValue + (estado.editandoGeral ? "-editando" : ""))
                    .transition(Mexer.entrada)
                rodape
            }
        }
        // Trocou a paleta ou o destaque: o painel inteiro se redesenha com as cores novas.
        .id(estado.aparencia.chaveDasCores)
        .padding(14)
        .frame(width: 360)
        .background(FundoDoPainel(ap: estado.aparencia, paraImagem: estado.paraImagem, deslocamento: estado.deslocamentoNaFoto))
        .overlay {
            // O vidro líquido já desenha a própria borda de luz.
            if estado.aparencia.fundoReal == .solido || estado.aparencia.fundoReal == .fosco {
                RoundedRectangle(cornerRadius: estado.aparencia.cantos, style: .continuous).strokeBorder(Tinta.borda, lineWidth: 1)
            }
        }
        .animation(Mexer.troca, value: estado.abaAtual)
        .animation(Mexer.troca, value: estado.editandoGeral)
        .animation(Mexer.troca, value: estado.geral)
        .animation(Mexer.troca, value: estado.aparencia.cantos)
        .scaleEffect(estado.apareceu ? 1 : (estado.aparencia.movimento == .mola ? 0.9 : 0.96), anchor: .top)
        .blur(radius: estado.apareceu || estado.aparencia.movimento != .mola ? 0 : 6)
        .opacity(estado.apareceu ? 1 : 0)
        .background(GeometryReader { g in Color.clear.preference(key: TamanhoDoPainel.self, value: g.size) })
        .onPreferenceChange(TamanhoDoPainel.self) { acoes.redimensionar($0) }
        .environment(\.colorScheme, estado.aparencia.escuroAgora ? .dark : .light)
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
                        .background(Capsule().fill(estado.editandoGeral ? Tinta.texto : Tinta.tinta.opacity(0.07)))
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
            CartaoDeSugestoes(estado: estado, acoes: acoes)
            CartaoDaLimpeza(estado: estado, acoes: acoes)
        case .aparencia:
            AbaDeAparencia(estado: estado)
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
            Botaozinho(simbolo: "arrow.clockwise", dica: "Atualizar agora", lado: .topLeading, acao: acoes.atualizar)
            Botaozinho(simbolo: estado.mostrarTudo ? "eye.fill" : "eye", dica: "Mostrar todas as portas", cor: Tinta.porta, acao: acoes.virarTudo)
            Botaozinho(simbolo: "gauge.with.dots.needle.33percent", dica: "Abrir o Monitor de Atividade", cor: Tinta.cpu, acao: acoes.monitor)
            Botaozinho(simbolo: "doc.on.clipboard", dica: "Copiar a lista de portas", cor: Tinta.memoria, acao: acoes.copiar)
            Spacer()
            Botaozinho(simbolo: "gearshape", dica: "Ajustes", lado: .topTrailing, acao: acoes.ajustes)
        }
        .padding(.top, 2)
    }
}
