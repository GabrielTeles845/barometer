// Quem mais esquentou: o tempo de CPU somado minuto a minuto.

import Foundation
import Testing
@testable import BarometerKit

@Suite("Quem mais esquentou")
struct QuemEsquentouTests {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("O tempo do ps em segundos", arguments: [("0:01.50", 1.5), ("416:39.44", 25_000 - 0.56), ("1:02:03.4", 3723.4)])
    func segundos(texto: String, esperado: Double) {
        #expect(abs((QuemEsquentou.segundos(Substring(texto)) ?? -1) - esperado) < 0.001)
    }

    @Test("A primeira leitura só marca o ponto de partida")
    func primeira() {
        var q = QuemEsquentou()
        q.anotar(" 10:00.00 1024 1 /usr/bin/node\n", quando: t0)
        #expect(q.ranking().lista.isEmpty)
        #expect(q.ranking().periodo == 0)
    }

    @Test("Soma o que cada um gastou entre as leituras, agrupando o app com seus ajudantes")
    func soma() {
        var q = QuemEsquentou()
        let chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        let ajudante = "/Applications/Google Chrome.app/Contents/Frameworks/Helper.app/Contents/MacOS/Helper"
        q.anotar("1:00.00 1000 10 \(chrome)\n0:10.00 500 11 \(ajudante)\n5:00.00 200 20 /opt/bin/node\n", quando: t0)
        q.anotar("1:30.00 1000 10 \(chrome)\n0:20.00 500 11 \(ajudante)\n5:05.00 200 20 /opt/bin/node\n", quando: t0.addingTimeInterval(60))
        let r = q.ranking()
        #expect(r.lista.map(\.nome) == ["Google Chrome", "node"])
        #expect(r.lista.first?.cpu == 40)
        #expect(r.lista.first?.app == "/Applications/Google Chrome.app")
        #expect(r.periodo == 60)
    }

    @Test("Processo novo conta tudo; pid reaproveitado por outro programa não vira negativo")
    func novos() {
        var q = QuemEsquentou()
        q.anotar("1:00.00 100 10 /bin/a\n", quando: t0)
        q.anotar("1:10.00 100 10 /bin/a\n0:30.00 100 11 /bin/build\n", quando: t0.addingTimeInterval(60))
        q.anotar("0:02.00 100 10 /bin/outro\n", quando: t0.addingTimeInterval(120))
        let r = Dictionary(uniqueKeysWithValues: q.ranking(10).lista.map { ($0.nome, $0.cpu) })
        #expect(r["build"] == 30)
        #expect(r["a"] == 10)
        #expect(r["outro"] == 2)
    }

    @Test("Guarda no máximo 6 horas")
    func limite() {
        var q = QuemEsquentou()
        for i in 0...400 { q.anotar("\(i):00.00 100 10 /bin/a\n", quando: t0.addingTimeInterval(Double(i) * 60)) }
        #expect(q.minutos.count == QuemEsquentou.minutosGuardados)
        #expect(q.ranking().lista.first?.cpu == Double(360 * 60))
    }

    @Test("O tempo escrito para gente")
    func tempo() {
        #expect(QuemEsquentou.tempo(30) == "30 s")
        #expect(QuemEsquentou.tempo(0.2) == "1 s")
        #expect(QuemEsquentou.tempo(38 * 60) == "38 min")
        #expect(QuemEsquentou.tempo(125 * 60) == "2 h 5 min")
    }
}
