// O teclado com o painel aberto.

import Foundation
import Testing
@testable import BarometerKit

@Suite("Teclado")
struct TecladoTests {
    @Test("⌘1 a ⌘9 levam a cada aba, na ordem da barra")
    func numeros() {
        for (i, aba) in Aba.allCases.enumerated() {
            #expect(Teclado.acao(letra: "\(i + 1)", codigo: 0, comando: true) == .aba(aba))
        }
        #expect(Teclado.acao(letra: "0", codigo: 29, comando: true) == nil)
        // Sem o ⌘, número não faz nada (não briga com o que se digita).
        #expect(Teclado.acao(letra: "1", codigo: 18, comando: false) == nil)
    }

    @Test("Setas, ⌘R, ⌘, e Esc")
    func atalhos() {
        #expect(Teclado.acao(letra: nil, codigo: Teclado.esquerda, comando: false) == .anterior)
        #expect(Teclado.acao(letra: nil, codigo: Teclado.direita, comando: false) == .proxima)
        #expect(Teclado.acao(letra: "r", codigo: 15, comando: true) == .atualizar)
        #expect(Teclado.acao(letra: "R", codigo: 15, comando: true) == .atualizar)
        #expect(Teclado.acao(letra: ",", codigo: 43, comando: true) == .ajustes)
        #expect(Teclado.acao(letra: nil, codigo: Teclado.esc, comando: false) == .fechar)
        #expect(Teclado.acao(letra: "r", codigo: 15, comando: false) == nil)
    }

    @Test("As setas dão a volta nas pontas")
    func volta() {
        #expect(Teclado.vizinha(de: Aba.allCases.last!, 1) == Aba.allCases.first!)
        #expect(Teclado.vizinha(de: Aba.allCases.first!, -1) == Aba.allCases.last!)
        #expect(Teclado.vizinha(de: .geral, 1) == .cpu)
    }
}

@Suite("Arrasto da pílula das abas")
struct ArrastoDaPilulaTests {
    let m = ArrastoDaPilula(largura: 36, espaco: 2, quantas: 9)

    @Test("Solta onde o mouse está, sem sair das pontas")
    func indice() {
        #expect(m.indice(em: 10) == 0)
        #expect(m.indice(em: 38 * 4 + 5) == 4)
        #expect(m.indice(em: -50) == 0)
        #expect(m.indice(em: 5000) == 8)
    }

    @Test("A pílula segue o mouse pelo meio e para nas bordas")
    func inicio() {
        #expect(m.inicio(em: 100) == 82)
        #expect(m.inicio(em: 0) == 0)
        #expect(m.inicio(em: 5000) == CGFloat(38 * 8))
    }

    @Test("Estica com a velocidade, até 40%")
    func estico() {
        #expect(ArrastoDaPilula.estico(velocidade: 0) == 0)
        #expect(ArrastoDaPilula.estico(velocidade: -400) == 0.2)
        #expect(ArrastoDaPilula.estico(velocidade: 99999) == 0.4)
    }
}
