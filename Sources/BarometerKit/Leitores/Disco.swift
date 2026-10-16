import Foundation
import IOKit

struct Disco {
    var nome = "Macintosh HD"
    var total: Double = 0
    /// O espaço livre "de verdade": o que o macOS libera para uso importante, contando o que dá para apagar
    /// (cache, cópias locais do Time Machine). É o número do Finder.
    var livre: Double = 0
    var leituraPorSegundo: Double = 0
    var escritaPorSegundo: Double = 0
    /// Desde que o Mac ligou.
    var lidoTotal: Double = 0
    var escritoTotal: Double = 0
    var operacoesLeitura: Double = 0
    var operacoesEscrita: Double = 0
}

final class LeitorDeDisco {
    private var antes: (quando: Date, lido: Double, escrito: Double)?

    func ler() -> Disco {
        var d = Disco()
        let raiz = URL(fileURLWithPath: "/")
        if let v = try? raiz.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeNameKey]) {
            d.total = Double(v.volumeTotalCapacity ?? 0)
            d.livre = Double(v.volumeAvailableCapacityForImportantUsage ?? 0)
            d.nome = v.volumeName ?? d.nome
        }

        var it: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &it) == KERN_SUCCESS {
            var e = IOIteratorNext(it)
            while e != 0 {
                if let s = IORegistryEntryCreateCFProperty(e, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? [String: Any] {
                    let n = { (k: String) in (s[k] as? NSNumber)?.doubleValue ?? 0 }
                    d.lidoTotal += n("Bytes (Read)")
                    d.escritoTotal += n("Bytes (Write)")
                    d.operacoesLeitura += n("Operations (Read)")
                    d.operacoesEscrita += n("Operations (Write)")
                }
                IOObjectRelease(e)
                e = IOIteratorNext(it)
            }
            IOObjectRelease(it)
        }
        let agora = Date()
        if let a = antes {
            let segundos = agora.timeIntervalSince(a.quando)
            if segundos > 0 {
                d.leituraPorSegundo = max(0, d.lidoTotal - a.lido) / segundos
                d.escritaPorSegundo = max(0, d.escritoTotal - a.escrito) / segundos
            }
        }
        antes = (agora, d.lidoTotal, d.escritoTotal)
        return d
    }
}
