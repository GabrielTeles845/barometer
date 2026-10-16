// Leituras: o que é lido do sistema, quando, e só o que aparece.

import AppKit
import Foundation

extension Barra {
    func amostrar() {
        guard let m = Maquina.memoria() else { return }
        let cpu = Maquina.cpu()
        if let cpu { cpusDoMinuto.append(cpu) }
        let temp = Sensores.ler()
        estado.memoria = m
        estado.pressao = Maquina.pressao()
        estado.swap = Maquina.swap()
        if let cpu { estado.cpu = cpu }
        estado.temperatura = temp
        let gpu = LeitorDeGPU.ler()
        let disco = leitorDeDisco.ler()
        estado.gpu = gpu
        estado.disco = disco
        if estado.naBarra.contains(.bateria) { estado.bateria = leitorDeBateria.ler(comOficial: false) }
        gpusDoMinuto.append(gpu?.uso ?? 0)
        discosDoMinuto.append(disco.leituraPorSegundo + disco.escritaPorSegundo)
        leituras += 1
        // Uma por minuto (a média do minuto). Nos primeiros 5 minutos, uma a cada leitura (10 s): o gráfico já
        // nasce desenhado, em vez de esperar minutos com o cartão vazio.
        if leituras % 6 == 1 || leituras <= 30 {
            let media = { (v: [Double], reserva: Double) in v.isEmpty ? reserva : v.reduce(0, +) / Double(v.count) }
            historico.anotar(memoria: m.usada / Maquina.total, cpu: media(cpusDoMinuto, estado.cpu ?? 0), chip: temp.chip,
                             gpu: media(gpusDoMinuto, 0), disco: media(discosDoMinuto, 0))
            cpusDoMinuto.removeAll(); gpusDoMinuto.removeAll(); discosDoMinuto.removeAll()
            estado.pontos = historico.pontos
        }
        desenharIcone()
    }

    /// O que a tela aberta mostra agora (ver `NaTela`).
    func naTela(_ leitura: Leitura) -> Bool {
        NaTela.mostra(leitura, aba: estado.abaAtual, editando: estado.editandoGeral, geral: estado.geral)
    }

    var painelAberto: Bool { janela?.isVisible == true }

    /// As portas (`lsof`, um processo novo a cada vez): com o painel fechado, só se o número delas está na barra;
    /// com ele aberto, só se a tela mostra as portas.
    var precisaDasPortas: Bool {
        painelAberto ? naTela(.portas) || naTela(.sugestoes) || estado.naBarra.contains(.portas) : estado.naBarra.contains(.portas)
    }

    /// Com o painel aberto, a cada 2 s: só o que está na tela. Núcleos, GPU, disco e bateria ao vivo (a velocidade
    /// do disco é a dos últimos 2 s), e a lista de quem mais gasta (um `ps` só para as duas listas). A saúde
    /// oficial da bateria (system_profiler) só com a bateria na tela.
    func lerGastos() {
        if naTela(.cpu) { estado.cpuDetalhada = leitorDeCPU.ler() }
        if naTela(.gpu) { estado.gpu = LeitorDeGPU.ler() }
        if naTela(.disco) { estado.disco = leitorDeDisco.ler() }
        if naTela(.bateria) { estado.bateria = leitorDeBateria.ler(comOficial: true) }
        if naTela(.sugestoes) { lerSugestoes() }
        guard naTela(.processos) else { return }
        fila.async { [weak self] in
            guard let self else { return }
            var (porMemoria, porCPU) = Maquina.quemMaisGasta()
            for i in porMemoria.indices where porMemoria[i].app == nil && porMemoria[i].meu {
                if let pasta = self.sonda.pastaDoProcesso(porMemoria[i].pid) { porMemoria[i].projeto = self.sonda.projeto(de: pasta) }
            }
            for i in porCPU.indices where porCPU[i].app == nil && porCPU[i].meu {
                if let pasta = self.sonda.pastaDoProcesso(porCPU[i].pid) { porCPU[i].projeto = self.sonda.projeto(de: pasta) }
            }
            DispatchQueue.main.async {
                self.estado.gastos = porMemoria
                self.estado.gastosCPU = porCPU
            }
        }
    }

    /// Apps parados e servidores antigos. Mudam devagar: no máximo a cada 30 s, com a aba Limpeza aberta.
    func lerSugestoes() {
        guard Date().timeIntervalSince(sugestoesEm) > 30 else { return }
        sugestoesEm = Date()
        let abertos = usoDosApps.abertos()
        let portas = self.portas
        fila.async { [weak self] in
            let agora = Date()
            // A lista inteira de apps (não só os 8 do painel): app parado pode não estar entre os que mais gastam.
            let gastos = Maquina.quemMaisGasta(200).memoria
            let lista = Sugestoes.apps(abertos, gastos: gastos, agora: agora)
                + Sugestoes.servidores(portas, inicio: Maquina.inicio, agora: agora)
            DispatchQueue.main.async { self?.estado.sugestoes = lista }
        }
    }

    func varrer(depois: (() -> Void)? = nil) {
        let tudo = Pref.tudo
        fila.async { [weak self] in
            guard let self else { return }
            let achadas = self.sonda.varrer(tudo: tudo)
            DispatchQueue.main.async {
                if achadas.lista.map(\.numero) != self.portas.map(\.numero) {
                    Diario.anotar("varredura: " + achadas.lista.map { "\($0.numero)" }.joined(separator: ", "))
                }
                self.portas = achadas.lista
                self.ocultas = achadas.ocultas
                self.desenharIcone()
                depois?()
            }
        }
    }
}
