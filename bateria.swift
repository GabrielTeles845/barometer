// A bateria: carga, tempo restante, ciclos, capacidade original e atual, saúde,
// voltagem, corrente, carregador e quanto o Mac está gastando em watts.
//
// Quase tudo vem do controlador da bateria (AppleSmartBattery, no IORegistry),
// leitura direta e barata. A "capacidade máxima" e a "condição" oficiais não
// estão lá: o macOS calcula à parte (no M3 Pro conferido, o registro dá 90% ou
// 93% conforme a conta, e os Ajustes dizem 94%). Para o número bater com o do
// sistema, os dois vêm do `system_profiler`, só com a aba Bateria aberta e
// guardados por 10 minutos.

import Foundation
import IOKit
import IOKit.ps

struct Bateria {
    var existe = false
    var nivel = 0
    var carregando = false
    var naTomada = false
    var carregada = false
    /// Até acabar (na bateria) ou até encher (carregando). Nil enquanto o macOS ainda calcula.
    var minutosRestantes: Int?
    var ciclos: Int?
    var ciclosDeProjeto: Int?
    var capacidadeDeProjeto: Int?
    var capacidadeAtual: Int?
    var cargaAtual: Int?
    var volts: Double?
    /// Negativa descarregando.
    var amperes: Double?
    /// O que o Mac está consumindo agora, em watts (da tomada ou da bateria).
    var consumo: Double?
    var carregador: String?
    var carregadorWatts: Int?
    var saudeOficial: Int?
    var condicaoOficial: String?
    var temperatura: Double?
}

final class LeitorDeBateria {
    private var oficial: (quando: Date, saude: Int?, condicao: String?)?
    private var lendoOficial = false

    func ler(comOficial: Bool) -> Bateria {
        var b = Bateria()
        b.temperatura = Sensores.ler().bateria

        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let lista = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for fonte in lista {
                guard let d = IOPSGetPowerSourceDescription(info, fonte)?.takeUnretainedValue() as? [String: Any],
                      (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
                b.existe = true
                b.nivel = d[kIOPSCurrentCapacityKey] as? Int ?? 0
                b.carregando = d[kIOPSIsChargingKey] as? Bool ?? false
                b.naTomada = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
                b.carregada = d[kIOPSIsChargedKey] as? Bool ?? false
                let minutos = b.carregando ? d[kIOPSTimeToFullChargeKey] as? Int : d[kIOPSTimeToEmptyKey] as? Int
                if let m = minutos, m > 0 { b.minutosRestantes = m }
            }
        }

        let servico = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if servico != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(servico, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let d = props?.takeRetainedValue() as? [String: Any] {
                let dados = d["BatteryData"] as? [String: Any] ?? [:]
                let inteiro = { (k: String) -> Int? in ((d[k] ?? dados[k]) as? NSNumber).map { Int($0.int64Value) } }
                b.ciclos = inteiro("CycleCount")
                b.ciclosDeProjeto = inteiro("DesignCycleCount9C")
                b.capacidadeDeProjeto = inteiro("DesignCapacity")
                b.capacidadeAtual = inteiro("NominalChargeCapacity") ?? inteiro("AppleRawMaxCapacity")
                b.cargaAtual = inteiro("AppleRawCurrentCapacity") ?? inteiro("RemainingCapacity")
                b.volts = inteiro("Voltage").map { Double($0) / 1000 }
                // A corrente chega como número sem sinal; o negativo (descarregando) vem dobrado em 64 bits.
                if let a = (d["InstantAmperage"] ?? d["Amperage"]) as? NSNumber { b.amperes = Double(a.int64Value) / 1000 }
                if let t = d["PowerTelemetryData"] as? [String: Any], let w = t["SystemPowerIn"] as? NSNumber, w.int64Value > 0 {
                    b.consumo = Double(w.int64Value) / 1000
                } else if let v = b.volts, let a = b.amperes, a < 0 {
                    b.consumo = v * -a
                }
                if let adaptador = d["AdapterDetails"] as? [String: Any] {
                    b.carregadorWatts = (adaptador["Watts"] as? NSNumber)?.intValue
                    b.carregador = (adaptador["Name"] as? String)?.trimmingCharacters(in: .whitespaces)
                }
            }
            IOObjectRelease(servico)
        }

        if comOficial { atualizarOficial() }
        b.saudeOficial = oficial?.saude
        b.condicaoOficial = oficial?.condicao
        return b
    }

    /// O `system_profiler` leva meio segundo: roda fora da thread principal, no máximo a cada 10 minutos.
    private func atualizarOficial() {
        if lendoOficial { return }
        if let o = oficial, Date().timeIntervalSince(o.quando) < 600 { return }
        lendoOficial = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            p.arguments = ["SPPowerDataType", "-json"]
            let cano = Pipe()
            p.standardOutput = cano
            p.standardError = FileHandle.nullDevice
            var saude: Int?
            var condicao: String?
            if (try? p.run()) != nil {
                let dados = cano.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                if let json = try? JSONSerialization.jsonObject(with: dados) as? [String: Any],
                   let itens = json["SPPowerDataType"] as? [[String: Any]] {
                    for item in itens {
                        guard let saudeInfo = item["sppower_battery_health_info"] as? [String: Any] else { continue }
                        if let texto = saudeInfo["sppower_battery_health_maximum_capacity"] as? String {
                            saude = Int(texto.filter(\.isNumber))
                        }
                        switch saudeInfo["sppower_battery_health"] as? String {
                        case "Good": condicao = "Normal"
                        case "Fair": condicao = "Razoável"
                        case "Poor", "Check Battery": condicao = "Precisa de manutenção"
                        case let outra?: condicao = outra
                        default: break
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                self?.oficial = (Date(), saude, condicao)
                self?.lendoOficial = false
            }
        }
    }
}
