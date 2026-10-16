// Verificadores do próprio código: cada um trava um erro que já aconteceu ou uma regra do projeto.

import Foundation
import Testing
@testable import BarometerKit

@Suite("Arquitetura")
struct ArquiteturaTests {
    /// Os arquivos do app, lidos do disco (a pasta vem do caminho deste teste).
    static let fontes: [(nome: String, texto: String)] = {
        let raiz = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources")
        let e = FileManager.default.enumerator(at: raiz, includingPropertiesForKeys: nil)
        var lista: [(String, String)] = []
        while let url = e?.nextObject() as? URL {
            guard url.pathExtension == "swift", let texto = try? String(contentsOf: url, encoding: .utf8) else { continue }
            lista.append((url.path.replacingOccurrences(of: raiz.path + "/", with: ""), texto))
        }
        return lista.sorted { $0.0 < $1.0 }
    }()

    @Test("Os arquivos foram achados")
    func achou() {
        #expect(Self.fontes.count > 40)
    }

    @Test("Nenhum arquivo passa de 450 linhas: peça grande se divide")
    func arquivosPequenos() {
        for f in Self.fontes {
            let linhas = f.texto.split(separator: "\n", omittingEmptySubsequences: false).count
            #expect(linhas <= 450, "\(f.nome) tem \(linhas) linhas")
        }
    }

    @Test("Sem a animação de número que enchia a memória (cache de letras sem fim, 16/10/2026)")
    func semNumericText() {
        for f in Self.fontes {
            #expect(!f.texto.contains(".numericText("), "\(f.nome) usa .numericText()")
        }
    }

    @Test("Preferência só pelo Pref (os testes trocam o armazém; acesso direto escaparia)")
    func preferenciaSoPeloPref() {
        for f in Self.fontes where !f.nome.hasSuffix("Sistema/Pref.swift") {
            #expect(!f.texto.contains("UserDefaults.standard"), "\(f.nome) usa UserDefaults.standard")
        }
    }

    @Test("Toda frase fixa da tela tem tradução em inglês e espanhol")
    func todaFraseTraduzida() throws {
        let padrao = try NSRegularExpression(pattern: #"\bt\("((?:[^"\\]|\\.)*)"\)"#)
        var faltando: [String] = []
        for f in Self.fontes {
            let alcance = NSRange(f.texto.startIndex..., in: f.texto)
            for achado in padrao.matches(in: f.texto, range: alcance) {
                guard let r = Range(achado.range(at: 1), in: f.texto) else { continue }
                let frase = String(f.texto[r])
                // Frase com pedaço calculado no meio só se confere rodando; a parte fixa é coberta pelos padrões.
                if frase.contains("\\(") || frase.isEmpty { continue }
                if Traducao.traduzir(frase, para: .en) == nil { faltando.append("\(f.nome): \(frase)") }
            }
        }
        #expect(faltando.isEmpty, "sem tradução:\n\(faltando.joined(separator: "\n"))")
    }

    @Test("O vidro líquido sempre com plano B para macOS antigo")
    func vidroComPlanoB() {
        for f in Self.fontes where f.texto.contains(".glassEffect(") {
            #expect(f.texto.contains("#available(macOS 26"), "\(f.nome) usa glassEffect sem #available")
        }
    }
}
