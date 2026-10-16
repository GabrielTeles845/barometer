import AppKit
import Combine
import IOKit
import ServiceManagement
import SwiftUI

/// Memória, CPU e o que mais gasta, lidos do kernel do mesmo jeito que o Monitor
/// de Atividade (as contas da memória são as dele: "usada" = apps + fixa +
/// comprimida; "cache" = arquivos guardados, que o sistema devolve quando
/// precisa). Nada de processo novo aqui: são chamadas diretas, baratas.
enum Maquina {
    static let total = Double(ProcessInfo.processInfo.physicalMemory)

    struct Memoria { let usada, apps, fixa, comprimida, cache: Double }

    static func memoria() -> Memoria? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let r = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard r == KERN_SUCCESS else { return nil }
        let pagina = Double(vm_kernel_page_size)
        let apps = max(0, Double(stats.internal_page_count) - Double(stats.purgeable_count)) * pagina
        let fixa = Double(stats.wire_count) * pagina
        let comprimida = Double(stats.compressor_page_count) * pagina
        let cache = (Double(stats.external_page_count) + Double(stats.purgeable_count)) * pagina
        return Memoria(usada: apps + fixa + comprimida, apps: apps, fixa: fixa, comprimida: comprimida, cache: cache)
    }

    static func swap() -> Double {
        var x = xsw_usage()
        var t = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &x, &t, nil, 0) == 0 else { return 0 }
        return Double(x.xsu_used)
    }

    /// 1 normal, 2 atenção, 4 crítica: a mesma cor do gráfico de "Pressão" do
    /// Monitor de Atividade. É o número que diz se a memória está faltando de
    /// verdade; memória "usada" alta com pressão normal é o Mac aproveitando.
    static func pressao() -> Int {
        var n: Int32 = 0
        var t = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &n, &t, nil, 0) == 0 else { return 1 }
        return Int(n)
    }

    private static var ticksAntes: (UInt32, UInt32, UInt32, UInt32)?

    /// CPU de todos os núcleos juntos desde a leitura anterior (0 a 1).
    static func cpu() -> Double? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let r = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard r == KERN_SUCCESS else { return nil }
        let agora = info.cpu_ticks
        defer { ticksAntes = agora }
        guard let a = ticksAntes else { return nil }
        let usuario = Double(agora.0 &- a.0), sistema = Double(agora.1 &- a.1)
        let ocioso = Double(agora.2 &- a.2), nice = Double(agora.3 &- a.3)
        let soma = usuario + sistema + ocioso + nice
        return soma > 0 ? (usuario + sistema + nice) / soma : nil
    }

    struct Gasto: Identifiable {
        /// Nome e processo: dois processos soltos com o mesmo nome (dois `claude`) são duas linhas.
        var id: String { "\(nome)#\(pid)" }
        let nome: String
        let bytes: Double
        let processos: Int
        /// O processo de maior memória do grupo: é o que se encerra quando não é aplicativo.
        let pid: Int32
        /// O caminho do .app, quando é aplicativo: fecha-se o app (como o Cmd+Q), não processo a processo.
        let app: String?
        /// Todos os processos são da sua conta. Os do sistema (root e afins) aparecem, mas sem o ×: o macOS não
        /// deixa um app comum encerrá-los, e nem deveria.
        let meu: Bool
        /// O projeto do processo solto (preenchido pela Barra, que tem a Sonda).
        var projeto: String? = nil
        /// CPU do grupo, em % de um núcleo (o mesmo número do Monitor de Atividade: 250% = dois núcleos e meio).
        var cpu: Double = 0
    }

    /// O que nunca ganha ×: sem eles a tela, o Dock ou a própria barra somem.
    static let intocaveis: Set<String> = [
        "Finder", "Dock", "SystemUIServer", "WindowServer", "loginwindow", "ControlCenter",
        "NotificationCenter", "Barometer", "barometer", "launchd", "kernel_task",
    ]

    /// Quem mais gasta memória, agrupado por aplicativo: o Chrome são trinta
    /// processos "Helper", e o que interessa é o Chrome inteiro. Processo solto
    /// (node, bun, postgres) fica sozinho, com o projeto ao lado.
    /// O que é cada serviço do macOS que costuma aparecer no topo: "deleted" ou "mds_stores" sozinhos não dizem nada.
    static let doSistema: [String: String] = [
        "WindowServer": "desenha a tela", "kernel_task": "núcleo do macOS", "deleted": "libera espaço em disco",
        "deleted_helper": "libera espaço em disco", "mds": "Spotlight", "mds_stores": "Spotlight", "mdworker": "Spotlight",
        "mdworker_shared": "Spotlight", "corespotlightd": "Spotlight", "mediaanalysisd": "analisa as fotos",
        "photoanalysisd": "analisa as fotos", "photolibraryd": "biblioteca do Fotos", "launchservicesd": "abre os apps",
        "backupd": "Time Machine", "cloudd": "iCloud", "bird": "iCloud Drive", "softwareupdated": "atualização do macOS",
        "trustd": "certificados", "syspolicyd": "segurança dos apps", "XprotectService": "antivírus do macOS",
        "coreaudiod": "som", "bluetoothd": "Bluetooth", "airportd": "Wi-Fi", "logd": "registros do sistema",
        "powerd": "energia", "suggestd": "sugestões da Siri", "knowledge-agent": "Siri", "Spotlight": "Spotlight",
        "MenuBarAgent": "barra de menus", "ControlCenter": "Central de Controle", "Dock": "Dock", "Finder": "Finder",
    ]

    /// Um processo a esconder da lista: o do retrato, que desenha o painel e aparece gastando CPU à toa.
    static var escondido: Int32 = -1

    /// As duas listas (por memória e por CPU) saem de um `ps` só.
    static func quemMaisGasta(_ quantos: Int = 8) -> (memoria: [Gasto], cpu: [Gasto]) {
        guard let ps = Ferramenta.ps else { return ([], []) }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ps)
        p.arguments = ["-axo", "rss=,pcpu=,pid=,uid=,comm="]
        let cano = Pipe()
        p.standardOutput = cano
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return ([], []) }
        let dados = cano.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return agrupar(String(data: dados, encoding: .utf8) ?? "", eu: getuid(), quantos: quantos)
    }

    /// A saída do `ps -axo rss=,pcpu=,pid=,uid=,comm=` agrupada: cada aplicativo vira uma linha só (o Chrome com
    /// os seus trinta ajudantes), processo solto fica sozinho. Devolve os maiores por memória e por CPU.
    static func agrupar(_ saida: String, eu: uid_t, quantos: Int = 8) -> (memoria: [Gasto], cpu: [Gasto]) {
        struct Soma { var bytes: Double; var n: Int; var pid: Int32; var maior: Double; var app: String?; var meu: Bool; var cpu: Double }
        var grupos: [String: Soma] = [:]
        for linha in saida.split(separator: "\n") {
            let partes = linha.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard partes.count == 5, let kb = Double(partes[0]), let pcpu = Double(partes[1].replacingOccurrences(of: ",", with: ".")),
                  let pid = Int32(partes[2]), let uid = UInt32(partes[3]) else { continue }
            let caminho = String(partes[4])
            if escondido == pid { continue }
            let bytes = kb * 1024
            let chave: String
            var app: String?
            if let fim = caminho.range(of: ".app/") {
                app = String(caminho[..<fim.lowerBound]) + ".app"
                chave = (app! as NSString).deletingPathExtension.split(separator: "/").last.map(String.init) ?? caminho
            } else {
                chave = (caminho as NSString).lastPathComponent + "#\(pid)"
            }
            var g = grupos[chave] ?? Soma(bytes: 0, n: 0, pid: pid, maior: 0, app: app, meu: true, cpu: 0)
            g.bytes += bytes
            g.cpu += pcpu
            g.n += 1
            if bytes > g.maior { g.maior = bytes; g.pid = pid }
            if uid != eu { g.meu = false }
            grupos[chave] = g
        }
        func lista(_ antes: (Soma, Soma) -> Bool) -> [Gasto] {
            grupos.sorted { antes($0.value, $1.value) }.prefix(quantos).map {
                let nome = $0.key.split(separator: "#").first.map(String.init) ?? $0.key
                let v = $0.value
                return Gasto(nome: nome, bytes: v.bytes, processos: v.n, pid: v.pid, app: v.app,
                             meu: v.meu && !intocaveis.contains(nome), cpu: v.cpu)
            }
        }
        return (lista { $0.bytes > $1.bytes }, lista { $0.cpu > $1.cpu })
    }

    static func gb(_ bytes: Double) -> String {
        let v = bytes / 1_073_741_824
        if v < 1 { return "\(Int((bytes / 1_048_576).rounded())) MB" }
        return decimal(v) + " GB"
    }

}
