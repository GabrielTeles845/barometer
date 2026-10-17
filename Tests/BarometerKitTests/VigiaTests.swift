// Os avisos: quando saem, e que saem uma vez só.

import Foundation
import Testing
@testable import BarometerKit

@Suite("Vigia")
struct VigiaTests {
    @Test("Desligado não avisa nada")
    func desligado() {
        var v = Vigia()
        for _ in 0..<20 { #expect(v.olhar(LeituraDoVigia(pressao: 4, chip: 110, disco: (1, 100))).isEmpty) }
    }

    @Test("Memória: só depois de 1 minuto no limite, e uma vez só até voltar ao normal")
    func memoria() {
        var v = Vigia(ligados: [.memoria])
        let limite = LeituraDoVigia(pressao: 4)
        for _ in 1..<Vigia.leiturasDaMemoria { #expect(v.olhar(limite).isEmpty) }
        #expect(v.olhar(limite).map(\.aviso) == [.memoria])
        for _ in 0..<10 { #expect(v.olhar(limite).isEmpty) }
        // Apertada (2) não rearma; só o normal (1).
        _ = v.olhar(LeituraDoVigia(pressao: 2))
        for _ in 0..<Vigia.leiturasDaMemoria { #expect(v.olhar(limite).isEmpty) }
        _ = v.olhar(LeituraDoVigia(pressao: 1))
        let avisos = (0..<Vigia.leiturasDaMemoria).flatMap { _ in v.olhar(limite) }
        #expect(avisos.count == 1)
    }

    @Test("Um pico de calor não avisa; 30 s acima de 95° avisa")
    func calor() {
        var v = Vigia(ligados: [.calor])
        #expect(v.olhar(LeituraDoVigia(chip: 99)).isEmpty)
        #expect(v.olhar(LeituraDoVigia(chip: 70)).isEmpty)
        #expect(v.olhar(LeituraDoVigia(chip: 96)).isEmpty)
        #expect(v.olhar(LeituraDoVigia(chip: 97)).isEmpty)
        #expect(v.olhar(LeituraDoVigia(chip: 98)).map(\.aviso) == [.calor])
        // Cair para 90 não rearma (folga até 85).
        _ = v.olhar(LeituraDoVigia(chip: 90))
        for _ in 0..<5 { #expect(v.olhar(LeituraDoVigia(chip: 97)).isEmpty) }
    }

    @Test("Disco abaixo de 10% avisa na hora; rearma acima de 12%")
    func disco() {
        var v = Vigia(ligados: [.disco])
        #expect(v.olhar(LeituraDoVigia(disco: (20, 100))).isEmpty)
        #expect(v.olhar(LeituraDoVigia(disco: (9, 100))).map(\.aviso) == [.disco])
        #expect(v.olhar(LeituraDoVigia(disco: (11, 100))).isEmpty)
        #expect(v.olhar(LeituraDoVigia(disco: (9, 100))).isEmpty)
        _ = v.olhar(LeituraDoVigia(disco: (13, 100)))
        #expect(v.olhar(LeituraDoVigia(disco: (9, 100))).count == 1)
    }

    @Test("Bateria: avisa em 20% fora da tomada; na tomada, nunca")
    func bateria() {
        var v = Vigia(ligados: [.bateria])
        #expect(v.olhar(LeituraDoVigia(bateria: (20, true))).isEmpty)
        #expect(v.olhar(LeituraDoVigia(bateria: (21, false))).isEmpty)
        #expect(v.olhar(LeituraDoVigia(bateria: (20, false))).map(\.aviso) == [.bateria])
        #expect(v.olhar(LeituraDoVigia(bateria: (15, false))).isEmpty)
        _ = v.olhar(LeituraDoVigia(bateria: (15, true)))
        #expect(v.olhar(LeituraDoVigia(bateria: (14, false))).count == 1)
    }

    @Test("Porta favorita: avisa quando quem ouvia sai, uma vez por porta")
    func porta() {
        var v = Vigia(ligados: [.porta])
        #expect(v.olhar(LeituraDoVigia(portas: [3000: "painel", 5173: "site"])).isEmpty)
        let caiu = v.olhar(LeituraDoVigia(portas: [5173: "site"]))
        #expect(caiu.map(\.id) == ["porta3000"])
        #expect(caiu.first?.texto.contains("painel") == true)
        #expect(v.olhar(LeituraDoVigia(portas: [5173: "site"])).isEmpty)
        // Sem leitura das portas (nil), nada muda.
        #expect(v.olhar(LeituraDoVigia()).isEmpty)
        #expect(v.olhar(LeituraDoVigia(portas: [:])).map(\.id) == ["porta5173"])
    }

    @Test("Os textos dos avisos têm tradução", arguments: [Idioma.en, .es])
    func traduzidos(idioma: Idioma) {
        for frase in ["O chip está em 97°. O Mac vai ficar mais lento para esfriar.", "Restam 12 GB livres.", "Bateria em 20%",
                      "A porta 3000 caiu", "painel parou de ouvir nela.", "Outro app já usa ⌃⌥B"] {
            #expect(Traducao.traduzir(frase, para: idioma) != nil, "\(frase)")
        }
    }
}
