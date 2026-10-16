// Com o painel aberto, o app só lê o que a tela mostra.

import Testing
@testable import BarometerKit

@Suite("Só o que está na tela")
struct NaTelaTests {
    let padrao = ItemGeral.padrao

    @Test("Aparência e Limpeza não leem nada")
    func abasSemLeitura() {
        for aba in [Aba.aparencia, .limpeza] {
            for l in Leitura.allCases {
                #expect(!NaTela.mostra(l, aba: aba, editando: false, geral: padrao), "\(aba) leu \(l)")
            }
        }
    }

    @Test("Cada aba lê só o que é dela")
    func cadaAba() {
        #expect(NaTela.mostra(.cpu, aba: .cpu, editando: false, geral: padrao))
        #expect(NaTela.mostra(.processos, aba: .cpu, editando: false, geral: padrao))
        #expect(!NaTela.mostra(.disco, aba: .cpu, editando: false, geral: padrao))
        #expect(NaTela.mostra(.processos, aba: .memoria, editando: false, geral: padrao))
        #expect(!NaTela.mostra(.portas, aba: .memoria, editando: false, geral: padrao))
        #expect(NaTela.mostra(.portas, aba: .portas, editando: false, geral: padrao))
        #expect(!NaTela.mostra(.processos, aba: .portas, editando: false, geral: padrao))
    }

    @Test("No Geral, segue os cartões ligados")
    func geralSegueCartoes() {
        var geral = padrao
        #expect(!NaTela.mostra(.cpu, aba: .geral, editando: false, geral: geral))   // núcleos vêm desligados
        geral[geral.firstIndex { $0.id == "cpu" }!].ligado = true
        #expect(NaTela.mostra(.cpu, aba: .geral, editando: false, geral: geral))
        geral[geral.firstIndex { $0.id == "processos" }!].ligado = false
        #expect(!NaTela.mostra(.processos, aba: .geral, editando: false, geral: geral))
    }

    @Test("Os anéis do Geral pedem a GPU")
    func aneisPedemGPU() {
        let soAneis = padrao.map { ItemGeral(id: $0.id, ligado: $0.id == "aneis") }
        #expect(NaTela.mostra(.gpu, aba: .geral, editando: false, geral: soAneis))
    }

    @Test("Editando o Geral, nada é lido")
    func editando() {
        for l in Leitura.allCases {
            #expect(!NaTela.mostra(l, aba: .geral, editando: true, geral: padrao))
        }
    }
}
