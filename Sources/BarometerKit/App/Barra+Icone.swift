// O ícone na barra de menus: o desenho e a dica.

import AppKit
import Foundation

extension Barra {
    func desenharIcone() {
        guard let botao = item.button else { return }
        botao.title = ""
        botao.imagePosition = .imageOnly
        botao.image = Icone.barra(pedacosDaBarra(), colorido: estado.aparencia.iconeColorido)
        var dica = [t("CPU \(Int(((estado.cpu ?? 0) * 100).rounded()))% · memória \(Int(((estado.memoria?.usada ?? 0) / Maquina.total * 100).rounded()))%")]
        if let c = estado.temperatura.chip { dica[0] += " · chip \(Int(c.rounded())) °C" }
        dica += portas.map { "\($0.numero) — \($0.resumo)" }
        botao.toolTip = dica.joined(separator: "\n")
    }

    /// Cada item escolhido para a barra: o ícone (ou as barrinhas) e o número.
    func pedacosDaBarra() -> [Icone.Pedaco] {
        let cpu = estado.cpu ?? 0
        let memoria = (estado.memoria?.usada ?? 0) / Maquina.total
        let pct = { (v: Double) in "\(Int((v * 100).rounded()))%" }
        var pedacos: [Icone.Pedaco] = []
        for item in estado.naBarra {
            switch item {
            case .barrinhas: pedacos.append(.init(nil, "", (cpu, memoria), cor: nil))
            case .cpu: pedacos.append(.init(item.simbolo, pct(cpu), nil, cor: item.cor))
            case .memoria: pedacos.append(.init(item.simbolo, pct(memoria), nil, cor: item.cor))
            case .gpu: pedacos.append(.init(item.simbolo, pct(estado.gpu?.uso ?? 0), nil, cor: item.cor))
            case .chip: pedacos.append(.init(item.simbolo, estado.temperatura.chip.map { "\(Int($0.rounded()))°" } ?? "–", nil, cor: item.cor))
            case .bateria:
                if let b = estado.bateria ?? leitorDeBateria.ler(comOficial: false) as Bateria?, b.existe {
                    pedacos.append(.init(b.carregando ? "battery.100percent.bolt" : item.simbolo, "\(b.nivel)%", nil, cor: item.cor))
                }
            case .disco: pedacos.append(.init(item.simbolo, estado.disco.map { Medida.espaco($0.livre) } ?? "–", nil, cor: item.cor))
            // Sem porta aberta mostra 0: o ícone sozinho, sem número, ninguém sabe o que é.
            case .portas: pedacos.append(.init(item.simbolo, String(portas.count), nil, cor: item.cor))
            }
        }
        if pedacos.isEmpty { pedacos = [.init(nil, "", (cpu, memoria), cor: nil)] }
        return pedacos
    }
}
