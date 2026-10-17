// O que o Barometer sugere fechar: só app parado há mais de 1 hora e servidor ligado há mais de 12.

import Foundation
import Testing
@testable import BarometerKit

@Suite("Sugestões do que fechar")
struct SugestoesTests {
    let agora = Date(timeIntervalSince1970: 1_800_000_000)

    func gasto(_ nome: String, app: String?, mb: Double, meu: Bool = true, pid: Int32 = 1) -> Maquina.Gasto {
        Maquina.Gasto(nome: nome, bytes: mb * 1_048_576, processos: 1, pid: pid, app: app, meu: meu)
    }

    @Test("Só app parado há mais de 1 hora, o que mais ocupa primeiro")
    func appsParados() {
        let abertos = [
            Sugestoes.AppAberto(caminho: "/A.app", nome: "A", ultimoUso: agora.addingTimeInterval(-7200)),
            Sugestoes.AppAberto(caminho: "/B.app", nome: "B", ultimoUso: agora.addingTimeInterval(-600)),
            Sugestoes.AppAberto(caminho: "/C.app", nome: "C", ultimoUso: agora.addingTimeInterval(-90_000)),
        ]
        let gastos = [gasto("A", app: "/A.app", mb: 300), gasto("B", app: "/B.app", mb: 900), gasto("C", app: "/C.app", mb: 800)]
        let lista = Sugestoes.apps(abertos, gastos: gastos, agora: agora)
        #expect(lista.map(\.nome) == ["C", "A"])
        #expect(lista.first?.tempo == 90_000)
    }

    @Test("App de outro usuário ou que não está entre os que gastam não entra")
    func appsQueNaoEntram() {
        let abertos = [
            Sugestoes.AppAberto(caminho: "/Sistema.app", nome: "Sistema", ultimoUso: agora.addingTimeInterval(-9000)),
            Sugestoes.AppAberto(caminho: "/Leve.app", nome: "Leve", ultimoUso: agora.addingTimeInterval(-9000)),
        ]
        let gastos = [gasto("Sistema", app: "/Sistema.app", mb: 500, meu: false)]
        #expect(Sugestoes.apps(abertos, gastos: gastos, agora: agora).isEmpty)
    }

    @Test("Servidor ligado há mais de 12 horas entra; recente e Docker, não")
    func servidores() {
        let velho = Porta(numero: 3000, pid: 10, comando: "node", endereco: "*")
        let novo = Porta(numero: 5173, pid: 11, comando: "node", endereco: "*")
        let docker = Porta(numero: 5432, pid: 12, comando: "com.docker.backend", endereco: "*")
        let inicios: [Int32: Date] = [10: agora.addingTimeInterval(-50_000), 11: agora.addingTimeInterval(-60),
                                      12: agora.addingTimeInterval(-90_000)]
        let lista = Sugestoes.servidores([velho, novo, docker], inicio: { inicios[$0] }, agora: agora)
        #expect(lista.map(\.id) == ["porta:3000"])
        // Com nome dado pela pessoa, é ele que aparece.
        let comNome = Sugestoes.servidores([velho], inicio: { inicios[$0] }, agora: agora, nomes: [3000: "painel"])
        #expect(comNome.first?.nome == "3000 painel")
    }

    @Test("No máximo cinco de cada")
    func maximo() {
        let abertos = (0..<9).map { Sugestoes.AppAberto(caminho: "/\($0).app", nome: "\($0)", ultimoUso: agora.addingTimeInterval(-9000)) }
        let gastos = (0..<9).map { gasto("\($0)", app: "/\($0).app", mb: Double(100 + $0), pid: Int32($0)) }
        #expect(Sugestoes.apps(abertos, gastos: gastos, agora: agora).count == Sugestoes.maximo)
    }

    @Test("Duração em minutos, horas e dias")
    func duracao() {
        #expect(Medida.duracao(45 * 60) == "45 min")
        #expect(Medida.duracao(3 * 3600 + 120) == "3 h")
        #expect(Medida.duracao(2 * 86_400 + 5 * 3600) == "2 d 5 h")
        #expect(Medida.duracao(-5) == "0 min")
    }

    @Test("O início de um processo vem do kernel (este próprio teste está rodando)")
    func inicioDoProcesso() throws {
        let comeco = try #require(Maquina.inicio(ProcessInfo.processInfo.processIdentifier))
        #expect(comeco <= Date())
        #expect(Maquina.inicio(-1) == nil)
    }
}
