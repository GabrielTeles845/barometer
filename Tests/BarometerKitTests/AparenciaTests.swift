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

@Suite("Estilos prontos")
struct EstilosTests {
    @Test("Nomes e ids sem repetir")
    func semRepetidos() {
        #expect(Set(Estilo.todos.map(\.id)).count == Estilo.todos.count)
        #expect(Set(Estilo.todos.map(\.nome)).count == Estilo.todos.count)
    }

    @Test("Todo estilo tem nome e descrição em inglês e espanhol")
    func traduzidos() {
        for e in Estilo.todos {
            for frase in [e.nome, e.descricao] {
                #expect(Traducao.traduzir(frase, para: .en) != nil, "sem inglês: \(frase)")
                #expect(Traducao.traduzir(frase, para: .es) != nil, "sem espanhol: \(frase)")
            }
        }
    }

    @Test("O primeiro estilo é o de fábrica: quem nunca mexeu aparece com ele escolhido")
    func primeiroEhOPadrao() {
        #expect(Estilo.todos.first?.aparencia == Aparencia())
        #expect(Estilo.atual(Aparencia())?.id == Estilo.todos.first?.id)
    }

    @Test("Cada estilo é diferente dos outros (senão dois aparecem escolhidos)")
    func todosDiferentes() {
        for (i, a) in Estilo.todos.enumerated() {
            for b in Estilo.todos[(i + 1)...] { #expect(a.aparencia != b.aparencia, "\(a.id) = \(b.id)") }
        }
    }
}

@Suite("Modo claro e escuro")
struct ModoTests {
    @Test("Claro e escuro valem sempre; o automático segue o Mac")
    func escuroAgora() {
        var a = Aparencia()
        a.modo = .claro
        #expect(!a.escuroAgora)
        a.modo = .escuro
        #expect(a.escuroAgora)
    }

    @Test("Trocar o modo troca a chave que redesenha o painel")
    func chave() {
        var a = Aparencia(), b = Aparencia()
        b.modo = .claro
        #expect(a.chaveDasCores != b.chaveDasCores)
        a.modo = .claro
        #expect(a.chaveDasCores == b.chaveDasCores)
    }

    @Test("A Grafite fica escura no claro, para não sumir no fundo branco")
    func grafiteNoClaro() throws {
        let mono = try #require(Paleta.todas.first { $0.id == "mono" })
        #expect(mono.paraOModo(escuro: false).cpu != mono.cpu)
        #expect(mono.paraOModo(escuro: true).cpu == mono.cpu)
        #expect(Paleta.padrao.paraOModo(escuro: false).cpu == Paleta.padrao.cpu)
    }
}

@Suite("Estilo personalizado")
struct PersonalizadoTests {
    @Test("Usa as cores escolhidas; o que não foi escolhido fica como na padrão")
    func usaAsCores() {
        var a = Aparencia()
        a.paleta = Paleta.personalizadaId
        a.cores = ["cpu": "FF5F5F"]
        #expect(a.paletaAtual.cpu == Paleta.cor(hex: "FF5F5F"))
        #expect(a.paletaAtual.memoria == Paleta.padrao.memoria)
    }

    @Test("Cor em hex: válida vira cor, inválida vira nil")
    func hex() {
        #expect(Paleta.cor(hex: "FF9F45") != nil)
        #expect(Paleta.cor(hex: "XYZ") == nil)
        #expect(Paleta.cor(hex: "FF9F4") == nil)
    }

    @Test("O editor começa das cores que a pessoa está vendo, uma para cada leitura")
    func partida() {
        let cores = Paleta.coresDePartida(de: .padrao)
        #expect(Set(cores.keys) == Set(Paleta.pintaveis.map(\.id)))
        #expect(cores.values.allSatisfy { Paleta.amostras.contains($0) })
        #expect(cores["cpu"] == "FF9F45")     // o laranja da padrão
    }

    @Test("As cores escolhidas sobrevivem ao JSON")
    func guarda() throws {
        var a = Aparencia()
        a.paleta = Paleta.personalizadaId
        a.cores = ["cpu": "4C9BFF", "porta": "FFD54A"]
        let volta = try JSONDecoder().decode(Aparencia.self, from: JSONEncoder().encode(a))
        #expect(volta.cores == a.cores)
    }

    @Test("Trocar uma cor redesenha o painel")
    func chave() {
        var a = Aparencia()
        a.paleta = Paleta.personalizadaId
        a.cores = ["cpu": "4C9BFF"]
        var b = a
        b.cores["cpu"] = "FF5F5F"
        #expect(a.chaveDasCores != b.chaveDasCores)
    }
}

@Suite("Estilo não mexe no modo")
struct EstiloEModoTests {
    @Test("Aplicar um estilo guarda o modo escolhido", arguments: Aparencia.Modo.allCases)
    func guardaOModo(modo: Aparencia.Modo) {
        var atual = Aparencia()
        atual.modo = modo
        for e in Estilo.todos { #expect(e.aplicado(em: atual).modo == modo, "\(e.id) mudou o modo") }
    }

    @Test("O estilo continua marcado em qualquer modo")
    func marcadoEmQualquerModo() {
        for e in Estilo.todos {
            var a = e.aparencia
            a.modo = .claro
            #expect(Estilo.atual(a)?.id == e.id)
        }
    }

    @Test("Nenhum estilo pronto é só um modo (todos com modo de fábrica)")
    func nenhumEhModo() {
        #expect(Estilo.todos.allSatisfy { $0.aparencia.modo == Aparencia().modo })
    }
}
