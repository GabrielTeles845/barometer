// Barometer — o Mac em tempo real, na barra de menus: memória, CPU, GPU, disco, bateria, temperatura,
// o que mais gasta e o que está ouvindo nas portas.
//
// Nada de estimativa aqui: cada número vem de onde o próprio macOS lê. As portas,
// do `lsof` (a tabela de sockets do kernel); memória e CPU, de chamadas diretas
// ao kernel; temperatura, GPU, disco e bateria, do IORegistry; a frequência da
// CPU, do IOReport. A `Barra` lê e age; o painel (pasta Painel) só desenha.

import AppKit
import Combine
import IOKit
import ServiceManagement
import SwiftUI

final class Barra: NSObject, NSApplicationDelegate {

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let sonda = Sonda()
    /// Toda chamada ao `lsof` acontece aqui, uma por vez e fora da thread
    /// principal: varredura no main trava a barra do Mac inteira.
    let fila = DispatchQueue(label: "barometer.sonda", qos: .utility)
    let estado = Estado()
    let historico = Historico()
    var janela: JanelaDoPainel?
    var vigiaDeClique: Any?
    var vigiaDeTecla: Any?
    var relogio: Timer?
    var amostrador: Timer?
    var aberto: Timer?
    var leituras = 0
    lazy var leitorDeCPU = LeitorDeCPU()
    var vigiaDaAba: AnyCancellable?
    /// O macOS trocou entre claro e escuro: no modo automático, o painel acompanha.
    var vigiaDoTema: NSKeyValueObservation?
    /// Quando cada app foi usado pela última vez (para sugerir o que está parado).
    let usoDosApps = UsoDosApps()
    var sugestoesEm = Date.distantPast
    var limpezaMedidaEm = Date.distantPast
    let leitorDeDisco = LeitorDeDisco()
    let leitorDeBateria = LeitorDeBateria()
    var gpusDoMinuto: [Double] = []
    var discosDoMinuto: [Double] = []
    var cpusDoMinuto: [Double] = []
    var ouvido: OuvidoDoAtalho?
    var vigia = Vigia()

    var portas: [Porta] = [] { didSet { estado.portas = portas } }
    var ocultas: [(numero: Int, nome: String)] = [] { didSet { estado.ocultas = ocultas } }

    /// O app se chamava "Portas na Barra": as escolhas de lá (favoritas, ordem do Geral, filtro) vêm junto uma vez,
    /// e o "abrir ao ligar o Mac" antigo dá lugar ao novo.
    func trazerDoNomeAntigo() {
        let novo = Pref.armazem
        guard !novo.bool(forKey: "trouxeDoNomeAntigo") else { return }
        novo.set(true, forKey: "trouxeDoNomeAntigo")
        if let antigo = UserDefaults(suiteName: "com.gabrielteles.portas-na-barra") {
            for chave in ["favoritas", "mostrarTudo", "memoriaNaBarra", "geral", "desligouLogin"] {
                if let v = antigo.object(forKey: chave), novo.object(forKey: chave) == nil { novo.set(v, forKey: chave) }
            }
        }
        let agenteAntigo = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.gabrielteles.portas-na-barra.plist")
        if FileManager.default.fileExists(atPath: agenteAntigo.path) {
            try? FileManager.default.removeItem(at: agenteAntigo)
            if !novo.bool(forKey: "desligouLogin") { try? Login.ligar() }
        }
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        if let i = CommandLine.arguments.firstIndex(of: "--retrato"), i + 1 < CommandLine.arguments.count {
            let arquivo = CommandLine.arguments[i + 1]
            MainActor.assumeIsolated { retrato(em: arquivo) }
            return
        }
        trazerDoNomeAntigo()
        SobreEsteMac.ler { [weak self] in self?.estado.sobreMac = $0 }
        // A aba de Limpeza mede as pastas ao abrir (pode levar uns segundos; nunca com ela fechada).
        // Trocou de aba com o painel aberto: lê na hora o que a aba nova mostra (o resto parou de ser lido).
        vigiaDaAba = estado.$abaAtual.sink { [weak self] aba in
            DispatchQueue.main.async {
                guard let self, self.painelAberto else { return }
                if aba == .limpeza { self.medirLimpeza() }
                self.lerGastos()
                if self.precisaDasPortas { self.varrer() }
            }
        }
        vigiaDoTema = NSApp.observe(\.effectiveAppearance, options: [.initial, .new]) { [weak self] app, _ in
            let escuro = app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            DispatchQueue.main.async {
                guard Aparencia.sistemaEscuro != escuro else { return }
                Aparencia.sistemaEscuro = escuro
                self?.estado.objectWillChange.send()
            }
        }
        item.button?.target = self
        item.button?.action = #selector(alternar)
        estado.favoritas = Pref.favoritas
        estado.mostrarTudo = Pref.tudo
        estado.memoriaNaBarra = Pref.memoriaNaBarra
        estado.aoMudarABarra = { [weak self] in self?.desenharIcone() }
        estado.abrirAoLigar = Login.ligado

        relogio = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            if self?.precisaDasPortas == true { self?.varrer() }
        }
        relogio?.tolerance = 1
        varrer()

        // Memória, CPU e temperatura a cada 10 s (é o que mexe o ícone); o gráfico guarda uma por minuto,
        // com a média da CPU do minuto. Tudo chamada direta ao kernel, sem processo novo.
        _ = Maquina.cpu()
        amostrar()
        amostrador = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.amostrar() }
        amostrador?.tolerance = 2

        ligarAtalhoEAvisos()
        abrirNoLoginNaPrimeiraVez()
        // Primeira abertura: o painel abre sozinho com as boas-vindas (escolher um estilo).
        if !Pref.viuBoasVindas {
            estado.boasVindas = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.abrirPainel() }
        }
        // --abrir: já abre o painel (para medir memória e CPU com ele aberto, sem precisar clicar).
        if CommandLine.arguments.contains("--abrir") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.abrirPainel() }
        }
        let t = Sensores.ler()
        Diario.anotar("aberto; sensores: chip \(t.chip.map { String(format: "%.1f", $0) } ?? "-"), SSD \(t.ssd.map { String(format: "%.1f", $0) } ?? "-"), bateria \(t.bateria.map { String(format: "%.1f", $0) } ?? "-")")
    }
}
