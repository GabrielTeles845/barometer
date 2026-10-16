// A aparência guardada: o que vem de fábrica, o que sobrevive a uma versão nova e os limites da transparência.

import Foundation
import Testing
@testable import BarometerKit

@Suite("Aparência")
struct AparenciaTests {
    @Test("De fábrica: preto sólido, sem transparência, paleta padrão")
    func padrao() {
        let a = Aparencia()
        #expect(a.fundo == .solido)
        #expect(a.coberturaAtual == 1)
        #expect(a.paletaAtual.id == Paleta.padrao.id)
        #expect(a.movimento == .suave)
        #expect(!a.iconeColorido)
    }

    @Test("Cada fundo guarda a sua transparência")
    func coberturaPorFundo() {
        var a = Aparencia()
        a.fundo = .vidro
        a.coberturaAtual = 0.3
        a.fundo = .solido
        #expect(a.coberturaAtual == 1)
        a.fundo = .vidro
        #expect(a.coberturaAtual == 0.3)
    }

    @Test("A transparência para antes de o texto sumir", arguments: [-1.0, 0, 0.05, 2])
    func limites(valor: Double) {
        var a = Aparencia()
        a.coberturaAtual = valor
        #expect(a.coberturaAtual >= 0.1 && a.coberturaAtual <= 1)
    }

    @Test("Preferência de uma versão antiga, com campo faltando, não perde o resto")
    func decodificaParcial() throws {
        let json = #"{"fundo": "vidro", "paleta": "neon"}"#.data(using: .utf8)!
        let a = try JSONDecoder().decode(Aparencia.self, from: json)
        #expect(a.fundo == .vidro)
        #expect(a.paleta == "neon")
        #expect(a.cantos == 14)
        #expect(a.movimento == .suave)
    }

    @Test("Valor estranho guardado volta ao padrão em vez de quebrar")
    func decodificaEstranho() throws {
        let json = #"{"fundo": "holograma", "cantos": "muitos"}"#.data(using: .utf8)!
        let a = try JSONDecoder().decode(Aparencia.self, from: json)
        #expect(a.fundo == .solido)
        #expect(a.cantos == 14)
    }

    @Test("Ida e volta pelo JSON dá a mesma aparência")
    func idaEVolta() throws {
        var a = Aparencia()
        a.fundo = .fosco; a.paleta = "oceano"; a.destaque = "rosa"; a.cantos = 22; a.movimento = .mola
        a.iconeColorido = true; a.coberturaAtual = 0.4
        let volta = try JSONDecoder().decode(Aparencia.self, from: JSONEncoder().encode(a))
        #expect(volta == a)
    }

    @Test("Paleta desconhecida cai na padrão; destaque desconhecido, no da paleta")
    func desconhecidos() {
        var a = Aparencia()
        a.paleta = "nao-existe"
        a.destaque = "nao-existe"
        #expect(a.paletaAtual.id == Paleta.padrao.id)
        #expect(a.corDeDestaque == Paleta.padrao.destaque)
    }

    @Test("Paletas e destaques sem nome repetido")
    func semRepetidos() {
        #expect(Set(Paleta.todas.map(\.id)).count == Paleta.todas.count)
        #expect(Set(Paleta.destaques.map(\.id)).count == Paleta.destaques.count)
    }

    @Test("Mudar a paleta ou o destaque troca a chave que redesenha o painel; o resto não")
    func chaveDasCores() {
        let a = Aparencia()
        var b = a
        b.cantos = 22
        #expect(a.chaveDasCores == b.chaveDasCores)
        b.paleta = "neon"
        #expect(a.chaveDasCores != b.chaveDasCores)
    }
}
