// O tradutor: frases exatas, frases com número no meio, e os números no jeito de cada idioma.

import Foundation
import Testing
@testable import BarometerKit

@Suite("Idioma")
struct IdiomaTests {
    @Test("Português é a chave: volta igual")
    func portuguesVoltaIgual() {
        #expect(t("Memória", em: .pt) == "Memória")
    }

    @Test("Frase exata nos três idiomas")
    func fraseExata() {
        #expect(t("Memória", em: .en) == "Memory")
        #expect(t("Memória", em: .es) == "Memoria")
        #expect(t("Aparência", em: .en) == "Appearance")
    }

    @Test("Frase com número no meio leva o número para o lugar certo")
    func padraoComNumero() {
        #expect(t("Liberou 3 GB.", em: .en) == "Freed 3 GB.")
        #expect(t("Limpar Cache do npm?", em: .es) == "¿Limpiar Cache do npm?")
        #expect(t("últimos 12 min", em: .en) == "last 12 min")
    }

    @Test("Sem tradução, fica em português em vez de sumir")
    func semTraducao() {
        #expect(t("uma frase que não existe", em: .en) == "uma frase que não existe")
        #expect(Traducao.traduzir("uma frase que não existe", para: .en) == nil)
    }

    @Test("Decimal com vírgula em português e espanhol, ponto em inglês")
    func decimais() {
        #expect(decimal(8.94, em: .pt) == "8,9")
        #expect(decimal(8.94, em: .es) == "8,9")
        #expect(decimal(8.94, em: .en) == "8.9")
        #expect(decimal(2, casas: 2, em: .en) == "2.00")
    }

    @Test("Milhar com o separador de cada idioma")
    func milhares() {
        #expect(milhar(999, em: .pt) == "999")
        #expect(milhar(5786, em: .pt) == "5.786")
        #expect(milhar(5786, em: .en) == "5,786")
        #expect(milhar(12005, em: .es) == "12.005")
    }

    @Test("Nenhuma tradução vazia")
    func nenhumaVazia() {
        for (pt, par) in Traducao.exatas {
            #expect(!par.0.isEmpty, "sem inglês: \(pt)")
            #expect(!par.1.isEmpty, "sem espanhol: \(pt)")
        }
    }

    @Test("Os padrões levam todos os %n para a tradução")
    func padroesCompletos() {
        for p in Traducao.padroes {
            let marcas = (1...4).filter { p.regex.pattern.components(separatedBy: "(.+?)").count > $0 }
            for n in marcas {
                #expect(p.en.contains("%\(n)"), "inglês sem %\(n): \(p.regex.pattern)")
                #expect(p.es.contains("%\(n)"), "espanhol sem %\(n): \(p.regex.pattern)")
            }
        }
    }
}
