import AppKit
import Combine
import IOKit
import ServiceManagement
import SwiftUI

/// As últimas seis horas, uma amostra por minuto: o gráfico do menu. Fica só na
/// memória do app (360 pontos não pesam) e recomeça quando o app reabre.
final class Historico {
    struct Ponto {
        let quando: Date
        let memoria: Double
        let cpu: Double
        let chip: Double?
        var gpu: Double = 0
        /// Leitura mais escrita do disco, em bytes por segundo.
        var disco: Double = 0
    }
    private(set) var pontos: [Ponto] = []
    let maximo = 360

    func anotar(memoria: Double, cpu: Double, chip: Double?, gpu: Double = 0, disco: Double = 0) {
        pontos.append(Ponto(quando: Date(), memoria: memoria, cpu: cpu, chip: chip, gpu: gpu, disco: disco))
        if pontos.count > maximo { pontos.removeFirst(pontos.count - maximo) }
    }

    /// Duas linhas sobre a mesma grade: memória usada (azul) e CPU (laranja),
    /// de 0 a 100%. A largura representa sempre seis horas, para o gráfico não
    /// "esticar" uma hora como se fossem seis.
    func imagem(largura: CGFloat = 260, altura: CGFloat = 54) -> NSImage {
        let img = NSImage(size: NSSize(width: largura, height: altura))
        img.lockFocus()
        let area = NSRect(x: 0.5, y: 0.5, width: largura - 1, height: altura - 1)
        NSColor.secondaryLabelColor.withAlphaComponent(0.25).setStroke()
        let moldura = NSBezierPath(roundedRect: area, xRadius: 4, yRadius: 4)
        moldura.lineWidth = 1
        moldura.stroke()
        for frac in [0.5] {
            let y = area.minY + area.height * frac
            let meio = NSBezierPath()
            meio.move(to: NSPoint(x: area.minX + 4, y: y))
            meio.line(to: NSPoint(x: area.maxX - 4, y: y))
            meio.setLineDash([2, 3], count: 2, phase: 0)
            meio.lineWidth = 0.5
            meio.stroke()
        }
        func linha(_ valor: (Ponto) -> Double?, _ cor: NSColor) {
            guard pontos.count > 1 else { return }
            let passo = (area.width - 8) / CGFloat(maximo - 1)
            let inicio = area.maxX - 4 - passo * CGFloat(pontos.count - 1)
            let caminho = NSBezierPath()
            var comecou = false
            for (i, p) in pontos.enumerated() {
                guard let v = valor(p) else { comecou = false; continue }
                let pt = NSPoint(x: inicio + passo * CGFloat(i),
                                 y: area.minY + 3 + (area.height - 6) * CGFloat(min(1, max(0, v))))
                comecou ? caminho.line(to: pt) : caminho.move(to: pt)
                comecou = true
            }
            cor.setStroke()
            caminho.lineWidth = 1.5
            caminho.lineJoinStyle = .round
            caminho.stroke()
        }
        linha({ $0.cpu }, .systemOrange)
        linha({ $0.memoria }, .systemBlue)
        // Temperatura do chip na mesma grade: 20 °C embaixo, 100 °C em cima.
        linha({ $0.chip.map { ($0 - 20) / 80 } }, .systemRed)
        img.unlockFocus()
        return img
    }
}
