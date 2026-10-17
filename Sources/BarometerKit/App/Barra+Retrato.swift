// A foto do painel (`--retrato`), para conferir o desenho e montar o README.

import AppKit
import SwiftUI

extension Barra {
    /// `--retrato arquivo.png`: desenha o painel numa imagem e sai. É como se confere o desenho sem acesso à
    /// tela (gravação de tela pede permissão). O gráfico usa as leituras de verdade se houver; senão, uma
    /// curva de exemplo, marcada no próprio painel como exemplo.
    @MainActor
    func retrato(em arquivo: String) {
        Maquina.escondido = ProcessInfo.processInfo.processIdentifier
        if let i = CommandLine.arguments.firstIndex(of: "--idioma"), i + 1 < CommandLine.arguments.count {
            Idioma.forcado = Idioma(rawValue: CommandLine.arguments[i + 1])
        }
        estado.paraImagem = true
        _ = Maquina.cpu()
        Thread.sleep(forTimeInterval: 1)
        amostrar()
        let agora = Date()
        // --uma-leitura: o gráfico como fica logo depois de o app abrir (sem a curva de exemplo).
        if CommandLine.arguments.contains("--uma-leitura") {
            estado.pontos = historico.pontos
        } else if historico.pontos.count < 2 {
            for i in 0..<240 {
                let t = Double(i)
                historico.anotar(memoria: 0.45 + 0.12 * sin(t / 30) + 0.03 * sin(t / 4),
                                 cpu: max(0.03, 0.18 + 0.15 * sin(t / 11) + (i % 37 == 0 ? 0.4 : 0)),
                                 chip: 42 + 8 * sin(t / 25),
                                 gpu: max(0, 0.1 + 0.1 * sin(t / 17)),
                                 disco: max(0, 2_000_000 + 1_500_000 * sin(t / 9) + (i % 41 == 0 ? 40_000_000 : 0)))
            }
            let total = historico.pontos.count
            estado.pontos = historico.pontos.enumerated().map { i, p in
                Historico.Ponto(quando: agora.addingTimeInterval(Double(i - total) * 60), memoria: p.memoria, cpu: p.cpu, chip: p.chip,
                                gpu: p.gpu, disco: p.disco)
            }
        }
        estado.portas = sonda.varrer(tudo: false).lista
        var (gastos, gastosCPU) = Maquina.quemMaisGasta()
        for i in gastos.indices where gastos[i].app == nil && gastos[i].meu {
            if let pasta = sonda.pastaDoProcesso(gastos[i].pid) { gastos[i].projeto = sonda.projeto(de: pasta) }
        }
        estado.gastos = gastos
        estado.gastosCPU = gastosCPU
        _ = leitorDeCPU.ler()
        Thread.sleep(forTimeInterval: 1)
        estado.cpuDetalhada = leitorDeCPU.ler()
        estado.disco = leitorDeDisco.ler()
        estado.gpu = LeitorDeGPU.ler()
        if let i = CommandLine.arguments.firstIndex(of: "--aba"), i + 1 < CommandLine.arguments.count,
           let aba = Aba(rawValue: CommandLine.arguments[i + 1]) { estado.abaAtual = aba }
        if CommandLine.arguments.contains("--editar") { estado.editandoGeral = true }
        if CommandLine.arguments.contains("--boas-vindas") { estado.boasVindas = true }
        if CommandLine.arguments.contains("--do-meu-jeito") { estado.abaAparencia = 1 }
        // A foto sai com a aparência padrão, mais o que vier pedido: --fundo vidro --paleta neon --destaque rosa
        // --transparencia 60 --cantos 22 --mola --colorido --modo claro.
        var ap = Aparencia()
        func argumento(_ nome: String) -> String? {
            guard let i = CommandLine.arguments.firstIndex(of: nome), i + 1 < CommandLine.arguments.count else { return nil }
            return CommandLine.arguments[i + 1]
        }
        if let f = argumento("--fundo").flatMap(Aparencia.Fundo.init(rawValue:)) { ap.fundo = f }
        if let p = argumento("--paleta") { ap.paleta = p }
        if let d = argumento("--destaque") { ap.destaque = d }
        if let v = argumento("--transparencia").flatMap(Double.init) { ap.coberturaAtual = 1 - v / 100 }
        if let v = argumento("--cantos").flatMap(Double.init) { ap.cantos = v }
        if CommandLine.arguments.contains("--mola") { ap.movimento = .mola }
        if CommandLine.arguments.contains("--colorido") { ap.iconeColorido = true }
        if let m = argumento("--modo").flatMap(Aparencia.Modo.init(rawValue:)) { ap.modo = m }
        if CommandLine.arguments.contains("--chapado") { ap.chapado = true }
        if CommandLine.arguments.contains("--icones-coloridos") { ap.iconesColoridos = true }
        if ap.paleta == Paleta.personalizadaId { ap.cores = Paleta.coresDePartida(de: Paleta.todas[1]) }
        if CommandLine.arguments.contains("--editar-cores") { estado.editandoCores = true }
        if estado.abaAtual == .limpeza {
            estado.sugestoes = Sugestoes.apps(usoDosApps.abertos(contarDesdeQueAbriu: true), gastos: Maquina.quemMaisGasta(200).memoria,
                                              agora: Date())
                + Sugestoes.servidores(estado.portas, inicio: Maquina.inicio, agora: Date())
        }
        if let n = argumento("--processos").flatMap(Int.init) { estado.quantosProcessos = n }
        estado.aparencia = ap
        // A saúde oficial chega em segundo plano (system_profiler): espera por ela, até 3 s.
        _ = leitorDeBateria.ler(comOficial: true)
        let limite = Date().addingTimeInterval(3)
        while leitorDeBateria.ler(comOficial: false).saudeOficial == nil, Date() < limite {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        estado.bateria = leitorDeBateria.ler(comOficial: false)
        estado.apareceu = true
        var sobre: String?
        SobreEsteMac.ler { sobre = $0 }
        let limiteSobre = Date().addingTimeInterval(4)
        while sobre == nil, Date() < limiteSobre { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
        estado.sobreMac = sobre
        if estado.abaAtual == .limpeza || estado.geral.contains(where: { $0.id == "limpeza" && $0.ligado }) {
            estado.limpeza = Limpeza.itens().map { var i = $0; i.bytes = Limpeza.tamanho($0.pasta); return i }
        }
        if let i = CommandLine.arguments.firstIndex(of: "--acender"), i + 1 < CommandLine.arguments.count {
            estado.sobre = CommandLine.arguments[i + 1]
            // --acender g:90 = o mouse no gráfico, 90 minutos atrás.
            if estado.sobre?.hasPrefix("g:") == true, let min = Double(estado.sobre!.dropFirst(2)), let fim = estado.pontos.last?.quando {
                estado.sobreGrafico = fim.addingTimeInterval(-min * 60)
            }
        }
        if CommandLine.arguments.contains("--cpu") { estado.abaProcessos = 1 }
        if let i = CommandLine.arguments.firstIndex(of: "--grafico"), i + 1 < CommandLine.arguments.count {
            estado.aba = Int(CommandLine.arguments[i + 1]) ?? 0
        }
        estado.favoritas = Pref.favoritas
        // Fundo que deixa ver atrás: a foto põe o painel sobre o papel de parede, com mais margem para ele aparecer.
        // --papel faz o mesmo com o sólido, e --altura fixa a altura da foto (os quadros do GIF têm de ter uma só).
        let deixaVer = ap.fundoReal != .solido || ap.coberturaAtual < 1 || CommandLine.arguments.contains("--papel")
        let margem: CGFloat = deixaVer ? 48 : 20
        let altura = argumento("--altura").flatMap(Double.init).map { CGFloat($0) }
        estado.deslocamentoNaFoto = CGSize(width: margem, height: margem)
        let renderizador = ImageRenderer(content: Painel(estado: estado, acoes: Acoes()).padding(margem)
            .frame(height: altura, alignment: .top)
            .background(alignment: .topLeading) {
                if deixaVer { PapelDeParede() } else { Color(white: ap.escuroAgora ? 0.16 : 0.84) }
            }
            .clipped())
        renderizador.scale = 2
        // Cor não linear e direto do bitmap: com ícone de app na tela, o renderizador trocava o espaço de cor e o
        // preto saía cinza na imagem (só na imagem; na tela, não).
        renderizador.colorMode = .nonLinear
        if let cg = renderizador.cgImage,
           let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: arquivo))
        }
        // A barra de menus: o ícone e o número de portas, em branco sobre a faixa escura, como na tela.
        // Em 4x: no README a faixa aparece grande e nítida. A largura acompanha o que está na barra.
        let k: CGFloat = 4
        if let i = CommandLine.arguments.firstIndex(of: "--barra"), i + 1 < CommandLine.arguments.count {
            estado.naBarra = CommandLine.arguments[i + 1].split(separator: ",").compactMap { ItemDaBarra(rawValue: String($0)) }
        }
        portas = estado.portas
        let colorido = estado.aparencia.iconeColorido
        let icone = Icone.barra(pedacosDaBarra(), colorido: colorido)
        let largura = icone.size.width * k
        let faixa = NSImage(size: NSSize(width: largura + 60 * k, height: 30 * k))
        faixa.lockFocus()
        NSColor(white: 0.12, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: largura + 60 * k, height: 30 * k).fill()
        let onde = NSRect(x: 30 * k, y: 6 * k, width: largura, height: 18 * k)
        if colorido {
            // Colorido: as cores ficam, e o texto sai branco como numa barra escura.
            NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance { icone.draw(in: onde) }
        } else {
            let branco = NSImage(size: icone.size, flipped: false) { r in
                icone.draw(in: r)
                NSColor.white.set()
                r.fill(using: .sourceAtop)
                return true
            }
            branco.draw(in: onde)
        }
        faixa.unlockFocus()
        if let tiff = faixa.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: (arquivo as NSString).deletingPathExtension + "-icone.png"))
        }
        NSApp.terminate(nil)
    }
}
