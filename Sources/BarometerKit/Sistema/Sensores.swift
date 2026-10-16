import AppKit
import Combine
import IOKit
import ServiceManagement
import SwiftUI

/* Nos Macs com chip da Apple, a temperatura não está no SMC antigo: os sensores
   aparecem como serviços HID do fabricante (página 0xff00, uso 5). As funções
   abaixo existem no IOKit, mas não estão nos cabeçalhos públicos; são as mesmas
   que o Stats e o Monitor de Atividade usam. Conferido num M3 Pro em 16/10/2026:
   "PMU tdie1…10" (os núcleos do chip), "PMU tdev1…8" (outras partes da placa),
   "NAND CH0 temp" (SSD) e "gas gauge battery" (bateria). */
@_silgen_name("IOHIDEventSystemClientCreate") private func IOHIDEventSystemClientCreate(_ a: CFAllocator?) -> Unmanaged<AnyObject>?
@_silgen_name("IOHIDEventSystemClientSetMatching") private func IOHIDEventSystemClientSetMatching(_ c: AnyObject, _ m: CFDictionary) -> Int32
@_silgen_name("IOHIDEventSystemClientCopyServices") private func IOHIDEventSystemClientCopyServices(_ c: AnyObject) -> Unmanaged<CFArray>?
@_silgen_name("IOHIDServiceClientCopyProperty") private func IOHIDServiceClientCopyProperty(_ s: AnyObject, _ k: CFString) -> Unmanaged<AnyObject>?
@_silgen_name("IOHIDServiceClientCopyEvent") private func IOHIDServiceClientCopyEvent(_ s: AnyObject, _ t: Int64, _ o: Int32, _ ts: Int64) -> Unmanaged<AnyObject>?
@_silgen_name("IOHIDEventGetFloatValue") private func IOHIDEventGetFloatValue(_ e: AnyObject, _ f: Int32) -> Double
enum Sensores {
    struct Leitura { let chip: Double?; let chipMaximo: Double?; let ssd: Double?; let bateria: Double? }

    private static let tipoTemperatura: Int64 = 15
    /// O cliente fica vivo enquanto o app vive: os sensores pertencem a ele, e com ele liberado a leitura
    /// usava um objeto já desfeito e o app caía ao abrir (16/10).
    private static let cliente: AnyObject? = IOHIDEventSystemClientCreate(kCFAllocatorDefault)?.takeRetainedValue()
    /// Os serviços (sensores) não mudam com o Mac ligado: lidos uma vez.
    private static let servicos: [(nome: String, servico: AnyObject)] = {
        guard let cliente else { return [] }
        _ = IOHIDEventSystemClientSetMatching(cliente, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
        guard let lista = IOHIDEventSystemClientCopyServices(cliente)?.takeRetainedValue() as? [AnyObject] else { return [] }
        return lista.map { s in
            ((IOHIDServiceClientCopyProperty(s, "Product" as CFString)?.takeRetainedValue() as? String) ?? "", s)
        }
    }()

    static func ler() -> Leitura {
        var chip: [Double] = [], ssd: [Double] = [], bateria: [Double] = []
        for (nome, servico) in servicos {
            guard let evento = IOHIDServiceClientCopyEvent(servico, tipoTemperatura, 0, 0)?.takeRetainedValue() else { continue }
            let graus = IOHIDEventGetFloatValue(evento, Int32(tipoTemperatura << 16))
            // Leitura fora do razoável (sensor desligado devolve 0 ou valores absurdos) fica de fora.
            guard graus > 5, graus < 130 else { continue }
            let n = nome.lowercased()
            if n.contains("tdie") || n.contains("cpu") || n.contains("soc") { chip.append(graus) }
            else if n.contains("nand") || n.contains("ssd") { ssd.append(graus) }
            else if n.contains("battery") { bateria.append(graus) }
        }
        let media = { (v: [Double]) -> Double? in v.isEmpty ? nil : v.reduce(0, +) / Double(v.count) }
        return Leitura(chip: media(chip), chipMaximo: chip.max(), ssd: media(ssd), bateria: media(bateria))
    }
}
