import Foundation
import AppKit

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
