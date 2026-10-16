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
