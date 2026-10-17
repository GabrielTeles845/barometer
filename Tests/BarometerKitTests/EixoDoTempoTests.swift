// As horas embaixo do gráfico: redondas e nunca repetidas.

import Foundation
import Testing
@testable import BarometerKit

@Suite("Eixo do tempo")
struct EixoDoTempoTests {
    let inicio = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Menos de 2 minutos: nenhuma hora (seria a mesma repetida)")
    func curtoDemais() {
        #expect(EixoDoTempo.marcas(de: inicio, ate: inicio.addingTimeInterval(90)).isEmpty)
        #expect(EixoDoTempo.marcas(de: nil, ate: nil).isEmpty)
    }

    @Test("Nunca mais de 4 marcas, e nenhuma repetida no relógio", arguments: [3.0, 7, 25, 61, 180, 360])
    func semRepetir(minutos: Double) {
        let marcas = EixoDoTempo.marcas(de: inicio, ate: inicio.addingTimeInterval(minutos * 60))
        #expect(!marcas.isEmpty)
        #expect(marcas.count <= 4)
        let formato = DateFormatter()
        formato.dateFormat = "HH:mm"
        let textos = marcas.map(formato.string(from:))
        #expect(Set(textos).count == textos.count, "horas repetidas: \(textos)")
    }

    @Test("Marcas em minutos redondos, dentro do intervalo")
    func redondas() {
        let fim = inicio.addingTimeInterval(4 * 3600)
        for m in EixoDoTempo.marcas(de: inicio, ate: fim) {
            #expect(m.timeIntervalSince1970.truncatingRemainder(dividingBy: 60) == 0)
            #expect(m >= inicio && m <= fim)
        }
    }

    @Test("Nenhuma marca colada nas pontas (a hora sairia cortada)", arguments: [7.0, 25, 61, 180, 240, 360])
    func longeDasPontas(minutos: Double) {
        let fim = Date(timeIntervalSince1970: 1_800_000_000 + 37)
        let inicio = fim.addingTimeInterval(-minutos * 60)
        let folga = minutos * 60 * EixoDoTempo.margem
        for m in EixoDoTempo.marcas(de: inicio, ate: fim) {
            #expect(m.timeIntervalSince(inicio) >= folga && fim.timeIntervalSince(m) >= folga)
        }
    }
}
