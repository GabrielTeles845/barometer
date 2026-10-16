// A CPU em detalhe: uso de cada núcleo (eficiência e desempenho), frequência de
// cada grupo de núcleos, usuário e sistema, carga média, tempo ligado e estado
// térmico. Só roda com o painel aberto, a cada 2 s; fechado, o ícone usa a CPU
// total, que é mais barata.
//
// A frequência vem do IOReport (interface interna da Apple, a mesma do Stats e
// do macmon, ambos MIT): o tempo que cada grupo passou em cada estado de
// desempenho, vezes a frequência daquele estado, que está na tabela do
// controlador de energia ("pmgr"). Conferido num M3 Pro em 16/10/2026.

import Foundation
import IOKit

// MARK: - IOReport

@_silgen_name("IOReportCopyChannelsInGroup") private func IOReportCopyChannelsInGroup(_ g: CFString?, _ s: CFString?, _ a: UInt64, _ b: UInt64, _ c: UInt64) -> Unmanaged<CFMutableDictionary>?
@_silgen_name("IOReportCreateSubscription") private func IOReportCreateSubscription(_ a: UnsafeMutableRawPointer?, _ ch: CFMutableDictionary, _ sub: UnsafeMutablePointer<Unmanaged<CFMutableDictionary>?>, _ x: UInt64, _ d: CFTypeRef?) -> OpaquePointer?
@_silgen_name("IOReportCreateSamples") private func IOReportCreateSamples(_ s: OpaquePointer, _ ch: CFMutableDictionary, _ d: CFTypeRef?) -> Unmanaged<CFDictionary>?
@_silgen_name("IOReportCreateSamplesDelta") private func IOReportCreateSamplesDelta(_ a: CFDictionary, _ b: CFDictionary, _ d: CFTypeRef?) -> Unmanaged<CFDictionary>?
@_silgen_name("IOReportChannelGetSubGroup") private func IOReportChannelGetSubGroup(_ c: CFDictionary) -> Unmanaged<CFString>?
@_silgen_name("IOReportChannelGetChannelName") private func IOReportChannelGetChannelName(_ c: CFDictionary) -> Unmanaged<CFString>?
@_silgen_name("IOReportStateGetCount") private func IOReportStateGetCount(_ c: CFDictionary) -> Int32
@_silgen_name("IOReportStateGetNameForIndex") private func IOReportStateGetNameForIndex(_ c: CFDictionary, _ i: Int32) -> Unmanaged<CFString>?
@_silgen_name("IOReportStateGetResidency") private func IOReportStateGetResidency(_ c: CFDictionary, _ i: Int32) -> Int64

// MARK: - Os núcleos

struct Nucleo {
    let eficiencia: Bool
    let uso: Double
}

struct CPUDetalhada {
    var nucleos: [Nucleo] = []
    var usuario: Double = 0
    var sistema: Double = 0
    /// Frequência média de cada grupo enquanto ativo, em GHz.
    var ghzE: Double?
    var ghzP: Double?
    var ghzMaxE: Double?
    var ghzMaxP: Double?
    var carga: (Double, Double, Double) = (0, 0, 0)
    var ligadoDesde: Date?
    var termico: ProcessInfo.ThermalState = .nominal
}

final class LeitorDeCPU {
    /// Quais núcleos são de eficiência, pela ordem lógica: o `cluster-type` de cada `cpuN` na árvore de
    /// dispositivos. Sem ela, os primeiros `hw.perflevel1.logicalcpu` (é a ordem no Apple Silicon).
    private let ehEficiencia: [Bool]
    private var ticksAntes: [(UInt32, UInt32, UInt32, UInt32)] = []
    private var assinatura: OpaquePointer?
    private var canais: CFMutableDictionary?
    private var amostraAntes: CFDictionary?
    private let tabelas: [[Double]]

    init() {
        ehEficiencia = LeitorDeCPU.tiposDosNucleos()
        tabelas = LeitorDeCPU.tabelasDeFrequencia()
        if let grupo = IOReportCopyChannelsInGroup("CPU Stats" as CFString, nil, 0, 0, 0)?.takeRetainedValue() {
            var sub: Unmanaged<CFMutableDictionary>?
            assinatura = IOReportCreateSubscription(nil, grupo, &sub, 0, nil)
            canais = sub?.takeRetainedValue()
        }
    }

    private static func tiposDosNucleos() -> [Bool] {
        var tipos: [Int: Bool] = [:]
        let raiz = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/cpus")
        if raiz != 0 {
            var it: io_iterator_t = 0
            if IORegistryEntryGetChildIterator(raiz, kIODeviceTreePlane, &it) == KERN_SUCCESS {
                var e = IOIteratorNext(it)
                while e != 0 {
                    let id = (IORegistryEntryCreateCFProperty(e, "logical-cpu-id" as CFString, kCFAllocatorDefault, 0)?
                        .takeRetainedValue() as? NSNumber)?.intValue
                    let tipo = (IORegistryEntryCreateCFProperty(e, "cluster-type" as CFString, kCFAllocatorDefault, 0)?
                        .takeRetainedValue() as? Data).flatMap { String(data: $0, encoding: .ascii) }
                    if let id, let tipo { tipos[id] = tipo.hasPrefix("E") }
                    IOObjectRelease(e)
                    e = IOIteratorNext(it)
                }
                IOObjectRelease(it)
            }
            IOObjectRelease(raiz)
        }
        let total = ProcessInfo.processInfo.processorCount
        if tipos.count == total { return (0..<total).map { tipos[$0] ?? false } }
        var e: Int32 = 0
        var t = MemoryLayout<Int32>.size
        sysctlbyname("hw.perflevel1.logicalcpu", &e, &t, nil, 0)
        return (0..<total).map { $0 < Int(e) }
    }

    /// As tabelas de frequência (em GHz) do controlador de energia: `voltage-states*-sram` são pares
    /// (frequência em Hz, tensão). Qual tabela é de qual grupo se acha pelo número de estados.
    private static func tabelasDeFrequencia() -> [[Double]] {
        var it: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceNameMatching("pmgr"), &it) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(it) }
        var tabelas: [[Double]] = []
        var e = IOIteratorNext(it)
        while e != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(e, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let d = props?.takeRetainedValue() as? [String: Any] {
                for k in d.keys.sorted() where k.hasPrefix("voltage-states") && k.hasSuffix("-sram") {
                    guard let dados = d[k] as? Data else { continue }
                    let v = dados.withUnsafeBytes { Array($0.bindMemory(to: UInt32.self)) }
                    let ghz = stride(from: 0, to: v.count, by: 2).map { Double(v[$0]) / 1e9 }
                    // No M4 em diante a tabela vem em kHz; a correção é pelo tamanho do número.
                    tabelas.append(ghz.map { $0 < 0.01 ? $0 * 1000 : $0 })
                }
            }
            IOObjectRelease(e)
            e = IOIteratorNext(it)
        }
        return tabelas
    }

    func ler() -> CPUDetalhada {
        var r = CPUDetalhada()

        // Uso por núcleo: a diferença dos contadores desde a última leitura.
        var numero: natural_t = 0
        var info: processor_info_array_t?
        var tamanho: mach_msg_type_number_t = 0
        if host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numero, &info, &tamanho) == KERN_SUCCESS, let info {
            var agora: [(UInt32, UInt32, UInt32, UInt32)] = []
            for i in 0..<Int(numero) {
                let b = Int(CPU_STATE_MAX) * i
                agora.append((UInt32(bitPattern: info[b + Int(CPU_STATE_USER)]), UInt32(bitPattern: info[b + Int(CPU_STATE_SYSTEM)]),
                              UInt32(bitPattern: info[b + Int(CPU_STATE_IDLE)]), UInt32(bitPattern: info[b + Int(CPU_STATE_NICE)])))
            }
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(tamanho) * MemoryLayout<integer_t>.stride))
            if ticksAntes.count == agora.count {
                var somaU = 0.0, somaS = 0.0, somaT = 0.0
                for (i, (a, b)) in zip(ticksAntes, agora).enumerated() {
                    let u = Double(b.0 &- a.0), s = Double(b.1 &- a.1), o = Double(b.2 &- a.2), n = Double(b.3 &- a.3)
                    let t = u + s + o + n
                    r.nucleos.append(Nucleo(eficiencia: i < ehEficiencia.count ? ehEficiencia[i] : false,
                                            uso: t > 0 ? (u + s + n) / t : 0))
                    somaU += u + n
                    somaS += s
                    somaT += t
                }
                if somaT > 0 { r.usuario = somaU / somaT; r.sistema = somaS / somaT }
            }
            ticksAntes = agora
        }

        // Frequência de cada grupo.
        if let assinatura, let canais, let nova = IOReportCreateSamples(assinatura, canais, nil)?.takeRetainedValue() {
            if let antes = amostraAntes,
               let delta = IOReportCreateSamplesDelta(antes, nova, nil)?.takeRetainedValue() as NSDictionary? {
                for c in (delta["IOReportChannels"] as? [NSDictionary]) ?? [] {
                    let cd = c as CFDictionary
                    guard (IOReportChannelGetSubGroup(cd)?.takeUnretainedValue() as String?) == "CPU Complex Performance States",
                          let nome = IOReportChannelGetChannelName(cd)?.takeUnretainedValue() as String?,
                          nome == "ECPU" || nome == "PCPU" else { continue }
                    var tempos: [Int64] = []
                    for i in 0..<IOReportStateGetCount(cd) {
                        let estado = IOReportStateGetNameForIndex(cd, i)?.takeUnretainedValue() as String? ?? ""
                        if ["IDLE", "DOWN", "OFF"].contains(estado) { continue }
                        tempos.append(IOReportStateGetResidency(cd, i))
                    }
                    guard let tabela = tabelas.first(where: { $0.count == tempos.count }) else { continue }
                    let ativo = Double(tempos.reduce(0, +))
                    let media = ativo > 0 ? zip(tempos, tabela).map { Double($0) * $1 }.reduce(0, +) / ativo : tabela.first
                    if nome == "ECPU" { r.ghzE = media; r.ghzMaxE = tabela.last } else { r.ghzP = media; r.ghzMaxP = tabela.last }
                }
            }
            amostraAntes = nova
        }

        var cargas = [Double](repeating: 0, count: 3)
        if getloadavg(&cargas, 3) == 3 { r.carga = (cargas[0], cargas[1], cargas[2]) }
        var boot = timeval()
        var t = MemoryLayout<timeval>.size
        if sysctlbyname("kern.boottime", &boot, &t, nil, 0) == 0 {
            r.ligadoDesde = Date(timeIntervalSince1970: TimeInterval(boot.tv_sec))
        }
        r.termico = ProcessInfo.processInfo.thermalState
        return r
    }
}
