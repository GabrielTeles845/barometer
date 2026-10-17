// As escolhas guardadas. Cada teste usa um armazém próprio: nunca as escolhas de quem roda os testes.

import Foundation
import Testing
@testable import BarometerKit

@Suite("Preferências", .serialized)
struct PrefTests {
    /// Roda o teste com um armazém vazio e devolve o de antes no fim.
    private func comArmazemNovo(_ corpo: () throws -> Void) rethrows {
        let nome = "barometer-testes-\(UUID().uuidString)"
        let antes = Pref.armazem
        Pref.armazem = UserDefaults(suiteName: nome)!
        defer {
            Pref.armazem.removePersistentDomain(forName: nome)
            Pref.armazem = antes
        }
        try corpo()
    }

    @Test("Primeira vez: os cartões e a barra de fábrica")
    func primeiraVez() {
        comArmazemNovo {
            #expect(Pref.geral == ItemGeral.padrao)
            #expect(Pref.naBarra == ItemDaBarra.padrao)
            #expect(Pref.aparencia == Aparencia())
        }
    }

    @Test("Cartão novo de uma versão nova aparece no fim, desligado")
    func cartaoNovo() throws {
        try comArmazemNovo {
            let antigos = [ItemGeral(id: "portas", ligado: true), ItemGeral(id: "aneis", ligado: false)]
            Pref.armazem.set(try JSONEncoder().encode(antigos), forKey: "geral")
            let geral = Pref.geral
            #expect(geral.prefix(2).map(\.id) == ["portas", "aneis"])
            #expect(geral.count == ItemGeral.padrao.count)
            #expect(geral.dropFirst(2).allSatisfy { !$0.ligado })
        }
    }

    @Test("Cartão que deixou de existir some")
    func cartaoRemovido() throws {
        try comArmazemNovo {
            Pref.armazem.set(try JSONEncoder().encode([ItemGeral(id: "coisa-velha", ligado: true)]), forKey: "geral")
            #expect(!Pref.geral.contains { $0.id == "coisa-velha" })
        }
    }

    @Test("Na barra, no máximo três")
    func maximoNaBarra() throws {
        try comArmazemNovo {
            Pref.naBarra = [.cpu, .memoria, .gpu, .disco]
            #expect(Pref.naBarra.count == ItemDaBarra.maximo)
        }
    }

    @Test("A aparência gravada volta igual")
    func aparenciaGuardada() {
        comArmazemNovo {
            var a = Aparencia()
            a.fundo = .vidroClaro
            a.paleta = "mono"
            Pref.aparencia = a
            #expect(Pref.aparencia == a)
        }
    }

    @Test("Nome de porta: grava, limpa os espaços, corta em 40 letras e some quando vazio")
    func nomesDasPortas() {
        comArmazemNovo {
            #expect(Pref.nomesDasPortas.isEmpty)
            Pref.darNome("  painel Evollute ", aPorta: 3100)
            #expect(Pref.nomesDasPortas == [3100: "painel Evollute"])
            Pref.darNome(String(repeating: "a", count: 60), aPorta: 5173)
            #expect(Pref.nomesDasPortas[5173]?.count == 40)
            Pref.darNome("   ", aPorta: 3100)
            #expect(Pref.nomesDasPortas[3100] == nil)
        }
    }
}
