// Tamanhos e velocidades do jeito que se lê.

import Testing
@testable import BarometerKit

@Suite("Medidas")
struct MedidaTests {
    @Test("Velocidade do disco")
    func velocidade() {
        #expect(Medida.velocidade(0) == "0")
        #expect(Medida.velocidade(1000) == "0")
        #expect(Medida.velocidade(860_160) == "840 KB/s")
        #expect(Medida.velocidade(50 * 1_048_576) == "50 MB/s")
    }

    @Test("Espaço em disco como o Finder conta (1 GB = 1000³)")
    func espaco() {
        #expect(Medida.espaco(460_000_000_000) == "460 GB")
        #expect(Medida.espaco(217_400_000_000) == "217 GB")
    }

    @Test("Memória em GB, ou MB abaixo de 1 GB")
    func memoria() {
        #expect(Maquina.gb(512 * 1_048_576) == "512 MB")
    }
}
