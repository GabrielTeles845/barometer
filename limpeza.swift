// Limpeza: o que dá para apagar sem perder nada seu. Só entra o que se refaz
// sozinho (cache dos apps e dos gerenciadores de pacote, dados derivados do
// Xcode, registros) e a Lixeira. Documentos, downloads e fotos nunca entram.
// Nada é apagado sem confirmação, e a Lixeira tem a sua própria, porque não
// tem volta.

import AppKit
import Foundation

struct ItemDeLimpeza: Identifiable {
    let id: String
    /// Nome e explicação em português; o painel passa pelo `t()`.
    let nome: String
    let explicacao: String
    let pasta: URL
    var bytes: Double?

    var ehLixeira: Bool { id == "lixeira" }
}

enum Limpeza {
    private static let casa = FileManager.default.homeDirectoryForCurrentUser

    /// Os lugares conhecidos que existem neste Mac.
    static func itens() -> [ItemDeLimpeza] {
        let todos: [(String, String, String, String)] = [
            ("caches", "Caches dos apps", "Os apps refazem sozinhos; podem abrir um pouco mais devagar na primeira vez.", "Library/Caches"),
            ("npm", "Cache do npm", "Os pacotes são baixados de novo quando um projeto precisar.", ".npm/_cacache"),
            ("bun", "Cache do Bun", "Os pacotes são baixados de novo quando um projeto precisar.", ".bun/install/cache"),
            ("pnpm", "Cache do pnpm", "Os pacotes são baixados de novo quando um projeto precisar.", "Library/pnpm/store"),
            ("xcode", "Dados derivados do Xcode", "O Xcode recompila na próxima vez que abrir cada projeto.", "Library/Developer/Xcode/DerivedData"),
            ("simuladores", "Cache dos simuladores", "Os simuladores do Xcode refazem quando abrirem.", "Library/Developer/CoreSimulator/Caches"),
            ("registros", "Registros dos apps", "Arquivos de log antigos; os apps criam novos.", "Library/Logs"),
            ("lixeira", "Lixeira", "Esvazia a Lixeira. Não tem volta.", ".Trash"),
        ]
        return todos.compactMap { id, nome, explicacao, caminho in
            let url = casa.appendingPathComponent(caminho)
            var pasta: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &pasta), pasta.boolValue else { return nil }
            return ItemDeLimpeza(id: id, nome: nome, explicacao: explicacao, pasta: url)
        }
    }

    /// O espaço que a pasta ocupa de verdade no disco. Pasta sem permissão (a Lixeira, sem Acesso Total ao Disco)
    /// devolve nil, e o painel mostra que não deu para medir.
    static func tamanho(_ url: URL) -> Double? {
        guard (try? FileManager.default.contentsOfDirectory(atPath: url.path)) != nil else { return nil }
        let chaves: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: chaves, options: [],
                                                     errorHandler: { _, _ in true }) else { return nil }
        var total: Double = 0
        for case let arquivo as URL in e {
            if let v = try? arquivo.resourceValues(forKeys: Set(chaves)), v.isRegularFile == true {
                total += Double(v.totalFileAllocatedSize ?? 0)
            }
        }
        return total
    }

    /// Apaga o que está dentro da pasta (a pasta fica). O que estiver em uso e não sair fica para trás, sem erro.
    /// Devolve quanto foi liberado.
    static func limpar(_ item: ItemDeLimpeza) -> Double {
        let antes = tamanho(item.pasta)
        if item.ehLixeira, antes == nil {
            // Sem permissão para ler a Lixeira: o Finder esvazia (o macOS pergunta uma vez se o app pode).
            NSAppleScript(source: "tell application \"Finder\" to empty trash")?.executeAndReturnError(nil)
            return 0
        }
        let fm = FileManager.default
        for nome in (try? fm.contentsOfDirectory(atPath: item.pasta.path)) ?? [] {
            try? fm.removeItem(at: item.pasta.appendingPathComponent(nome))
        }
        return max(0, (antes ?? 0) - (tamanho(item.pasta) ?? 0))
    }
}

/// O modelo do Mac, para o topo do painel: "MacBook Pro · M3 Pro · 18 GB · macOS 27.0.1".
enum SobreEsteMac {
    private(set) static var resumo: String?

    /// O `system_profiler` leva meio segundo: uma vez, fora da thread principal, ao abrir o app.
    static func ler(_ pronto: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            p.arguments = ["SPHardwareDataType", "-json"]
            let cano = Pipe()
            p.standardOutput = cano
            p.standardError = FileHandle.nullDevice
            var partes: [String] = []
            if (try? p.run()) != nil {
                let dados = cano.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                if let json = try? JSONSerialization.jsonObject(with: dados) as? [String: Any],
                   let d = (json["SPHardwareDataType"] as? [[String: Any]])?.first {
                    if let nome = d["machine_name"] as? String { partes.append(nome) }
                    if let chip = d["chip_type"] as? String { partes.append(chip.replacingOccurrences(of: "Apple ", with: "")) }
                    if let memoria = d["physical_memory"] as? String { partes.append(memoria) }
                }
            }
            let v = ProcessInfo.processInfo.operatingSystemVersion
            partes.append("macOS \(v.majorVersion).\(v.minorVersion)" + (v.patchVersion > 0 ? ".\(v.patchVersion)" : ""))
            let texto = partes.joined(separator: " · ")
            DispatchQueue.main.async {
                resumo = texto
                pronto(texto)
            }
        }
    }
}
