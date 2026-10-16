// O gráfico guarda 6 horas, uma leitura por minuto.

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
