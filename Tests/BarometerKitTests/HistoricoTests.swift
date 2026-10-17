// O gráfico guarda 6 horas, uma leitura por minuto.

import Foundation
import Testing
@testable import BarometerKit

@Suite("Histórico")
struct HistoricoTests {
    @Test("Guarda no máximo 360 pontos e descarta os mais velhos")
    func limite() {
        let h = Historico()
        for i in 0..<400 { h.anotar(memoria: Double(i) / 400, cpu: 0, chip: nil) }
        #expect(h.pontos.count == h.maximo)
        #expect(h.pontos.first?.memoria == 40.0 / 400)
        #expect(h.pontos.last?.memoria == 399.0 / 400)
    }

    @Test("Guarda GPU, disco e a temperatura de cada ponto")
    func campos() {
        let h = Historico()
        h.anotar(memoria: 0.5, cpu: 0.2, chip: 45, gpu: 0.1, disco: 2048)
        let p = h.pontos[0]
        #expect(p.memoria == 0.5 && p.cpu == 0.2 && p.chip == 45 && p.gpu == 0.1 && p.disco == 2048)
    }
}

@Suite("Mouse no gráfico")
struct MouseNoGraficoTests {
    @Test("Acha o ponto mais perto da hora do mouse; sem pontos, nenhum")
    func maisPerto() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let pontos = (0..<5).map { Historico.Ponto(quando: base.addingTimeInterval(Double($0) * 60), memoria: 0, cpu: Double($0) / 10, chip: nil) }
        #expect(Historico.maisPerto(pontos, de: base.addingTimeInterval(130))?.cpu == 0.2)
        #expect(Historico.maisPerto(pontos, de: base.addingTimeInterval(-500))?.cpu == 0)
        #expect(Historico.maisPerto([], de: base) == nil)
    }

    @Test("O valor do ponto em cada aba: %, ° e MB/s")
    func texto() {
        #expect(Grafico.texto(37.6, aba: 1) == "38%")
        #expect(Grafico.texto(64.2, aba: 3) == "64°")
        #expect(Grafico.texto(12, aba: 4) == "12 MB/s")
    }
}
