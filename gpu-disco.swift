// GPU e disco. Os dois são leitura direta do IORegistry, barata: o driver da GPU
// (IOAccelerator) publica uso e memória em "PerformanceStatistics", e o
// controlador do SSD (IOBlockStorageDriver) publica os bytes lidos e escritos
// desde que o Mac ligou, que viram velocidade pela diferença entre leituras.
//
// A frequência da GPU ficou de fora: no M3 Pro o IOReport mostra 15 estados e a
// tabela do controlador de energia tem 13 valores. Sem como casar os dois, o
// número seria inventado.

import Foundation
import IOKit

struct GPU {
    var uso: Double = 0
    var renderer: Double = 0
    var tiler: Double = 0
    var memoriaEmUso: Double = 0
    var memoriaAlocada: Double = 0
    var nucleos: Int?
    var modelo: String?
}

enum LeitorDeGPU {
    static func ler() -> GPU? {
        var it: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &it) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(it) }
        var gpu: GPU?
        var e = IOIteratorNext(it)
        while e != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(e, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let d = props?.takeRetainedValue() as? [String: Any],
               let p = d["PerformanceStatistics"] as? [String: Any] {
                let n = { (k: String) in (p[k] as? NSNumber)?.doubleValue ?? 0 }
                var g = GPU()
                g.uso = n("Device Utilization %") / 100
                g.renderer = n("Renderer Utilization %") / 100
                g.tiler = n("Tiler Utilization %") / 100
                g.memoriaEmUso = n("In use system memory")
                g.memoriaAlocada = n("Alloc system memory")
                g.nucleos = (d["gpu-core-count"] as? NSNumber)?.intValue
                g.modelo = d["model"] as? String
                gpu = g
            }
            IOObjectRelease(e)
            e = IOIteratorNext(it)
        }
        return gpu
    }
}

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

enum Medida {
    /// "12 MB/s", "840 KB/s", "0".
    static func velocidade(_ bytes: Double) -> String {
        if bytes < 1024 { return "0" }
        if bytes < 1_048_576 { return "\(Int(bytes / 1024)) KB/s" }
        let mb = bytes / 1_048_576
        return (mb < 10 ? decimal(mb) : "\(Int(mb.rounded()))") + " MB/s"
    }

    /// "460 GB", "1,2 TB".
    static func espaco(_ bytes: Double) -> String {
        let gb = bytes / 1_000_000_000
        if gb >= 1000 { return decimal(gb / 1000) + " TB" }
        return "\(Int(gb.rounded())) GB"
    }
}
