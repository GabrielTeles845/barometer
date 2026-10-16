// A lista de quem mais gasta, a partir da saída do `ps`.

import Foundation
import Testing
@testable import BarometerKit

@Suite("Quem mais gasta")
struct MaquinaTests {
    static let eu: uid_t = 501
    static let saida = """
     512000  12.5  100  501 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
     256000  30.0  101  501 /Applications/Google Chrome.app/Contents/Frameworks/Helper.app/Contents/MacOS/Helper
     128000   1.0  102  501 /Applications/Google Chrome.app/Contents/Frameworks/Helper.app/Contents/MacOS/Helper
     600000   0.5  200  501 /usr/local/bin/node
     300000  80.0  300    0 /usr/sbin/WindowServer
          0   0.0  400  501 linha que não se lê
    """

    @Test("O app e os ajudantes dele viram uma linha só")
    func agrupaApp() throws {
        let (memoria, _) = Maquina.agrupar(Self.saida, eu: Self.eu)
        let chrome = try #require(memoria.first { $0.nome == "Google Chrome" })
        #expect(chrome.processos == 3)
        #expect(chrome.bytes == Double(512000 + 256000 + 128000) * 1024)
        #expect(chrome.app == "/Applications/Google Chrome.app")
        // O processo que se encerra é o de maior memória do grupo.
        #expect(chrome.pid == 100)
    }

    @Test("Ordem por memória e por CPU")
    func ordens() {
        let (memoria, cpu) = Maquina.agrupar(Self.saida, eu: Self.eu)
        #expect(memoria.first?.nome == "Google Chrome")
        #expect(cpu.first?.nome == "WindowServer")
    }

    @Test("Processo de outro usuário não é seu (não ganha ×)")
    func deOutroUsuario() throws {
        let (memoria, _) = Maquina.agrupar(Self.saida, eu: Self.eu)
        #expect(try #require(memoria.first { $0.nome == "WindowServer" }).meu == false)
        #expect(try #require(memoria.first { $0.nome == "node" }).meu == true)
    }

    @Test("Respeita o tamanho pedido")
    func quantos() {
        #expect(Maquina.agrupar(Self.saida, eu: Self.eu, quantos: 2).memoria.count == 2)
    }

    @Test("Dois processos soltos com o mesmo nome são duas linhas, cada uma com a sua identidade")
    func mesmoNome() {
        let saida = """
         600000  1.0  700  501 /usr/local/bin/claude
         500000  2.0  701  501 /usr/local/bin/claude
        """
        let (memoria, _) = Maquina.agrupar(saida, eu: Self.eu)
        #expect(memoria.filter { $0.nome == "claude" }.count == 2)
        #expect(Set(memoria.map(\.id)).count == memoria.count)
        // E a ordem por memória vale entre eles também.
        #expect(memoria.map(\.pid) == [700, 701])
    }

    @Test("Saída vazia não quebra")
    func vazia() {
        let (memoria, cpu) = Maquina.agrupar("", eu: Self.eu)
        #expect(memoria.isEmpty && cpu.isEmpty)
    }
}
