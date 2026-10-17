// Abrir, acompanhar o tamanho e fechar o painel.

import AppKit
import SwiftUI

extension Barra {
    @objc func alternar() {
        if janela?.isVisible == true { fecharPainel() } else { abrirPainel() }
    }

    var acoes: Acoes {
        var a = Acoes()
        a.abrirPorta = { [weak self] p in self?.abrir(p) }
        a.encerrarPorta = { [weak self] p in self?.fecharPainel(); self?.confirmarEncerrar(p) }
        a.fechar = { [weak self] g in self?.fecharPainel(); self?.confirmarFechar(g) }
        a.atualizar = { [weak self] in self?.varrer(); self?.lerGastos(); self?.amostrar() }
        a.virarTudo = { [weak self] in Pref.tudo.toggle(); self?.estado.mostrarTudo = Pref.tudo; self?.varrer() }
        a.virarAbrirAoLigar = { [weak self] in self?.virarLogin() }
        a.virarMemoriaNaBarra = { [weak self] in
            Pref.memoriaNaBarra.toggle(); self?.estado.memoriaNaBarra = Pref.memoriaNaBarra; self?.desenharIcone()
        }
        a.virarFavorita = { [weak self] n in Pref.virarFavorita(n); self?.estado.favoritas = Pref.favoritas }
        a.outraFavorita = { [weak self] in self?.fecharPainel(); self?.pedirFavorita() }
        a.encerrarServidores = { [weak self] in self?.fecharPainel(); self?.confirmarEncerrarServidores() }
        a.nomearPorta = { [weak self] n in self?.fecharPainel(); self?.pedirNome(porta: n) }
        a.copiar = { [weak self] in self?.copiar() }
        a.monitor = { [weak self] in
            self?.fecharPainel()
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
        }
        a.sair = { NSApp.terminate(nil) }
        a.ajustes = { [weak self] in self?.mostrarAjustes() }
        a.redimensionar = { [weak self] tamanho in self?.redimensionar(tamanho) }
        a.limpar = { [weak self] id in self?.confirmarLimpeza(ids: [id]) }
        a.terminarBoasVindas = { [weak self] in
            Pref.viuBoasVindas = true
            withAnimation(Mexer.troca) { self?.estado.boasVindas = false }
        }
        a.limparTudo = { [weak self] in
            guard let self else { return }
            self.confirmarLimpeza(ids: self.estado.limpeza.filter { !$0.ehLixeira && ($0.bytes ?? 0) > 0 }.map(\.id))
        }
        return a
    }

    func abrirPainel() {
        guard let botao = item.button, let janelaDoBotao = botao.window else { return }
        // Ainda fechado aqui: lê o que a aba vai mostrar (as portas sempre, para o número da barra ficar certo).
        varrer()
        lerGastos()
        let vista = NSHostingView(rootView: Painel(estado: estado, acoes: acoes))
        vista.layoutSubtreeIfNeeded()
        let tamanho = vista.fittingSize
        let base = janelaDoBotao.convertToScreen(botao.convert(botao.bounds, to: nil))
        let tela = janelaDoBotao.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var x = base.midX - tamanho.width / 2
        x = min(max(tela.minX + 8, x), tela.maxX - tamanho.width - 8)
        let quadro = NSRect(x: x, y: base.minY - tamanho.height - 6, width: tamanho.width, height: tamanho.height)

        let j = janela ?? {
            let nova = JanelaDoPainel(contentRect: quadro, styleMask: [.borderless, .nonactivatingPanel],
                                      backing: .buffered, defer: false)
            nova.isOpaque = false
            nova.backgroundColor = .clear
            nova.hasShadow = true
            nova.level = .popUpMenu
            nova.collectionBehavior = [.canJoinAllSpaces, .transient]
            nova.isMovable = false
            return nova
        }()
        j.contentView = vista
        j.setFrame(quadro, display: true)
        // Abre com um leve crescimento e esmaecendo para dentro.
        estado.apareceu = false
        j.alphaValue = 0
        j.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            j.animator().alphaValue = 1
        }
        DispatchQueue.main.async { [weak self] in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { self?.estado.apareceu = true }
        }
        janela = j
        botao.highlight(true)

        // Fecha ao clicar fora, apertar Esc ou ao a janela deixar de ser a ativa.
        vigiaDeClique = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.fecharPainel()
        }
        vigiaDeTecla = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            let mods = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let comando = mods.contains(.command) && mods.isDisjoint(with: [.option, .control])
            guard let self, let tecla = Teclado.acao(letra: e.charactersIgnoringModifiers, codigo: e.keyCode, comando: comando)
            else { return e }
            self.apertou(tecla)
            return nil
        }
        // Enquanto está aberto, a lista de quem gasta e as portas se renovam.
        aberto = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.lerGastos() }
        aberto?.tolerance = 0.5
    }

    func apertou(_ tecla: Tecla) {
        switch tecla {
        case .fechar: fecharPainel()
        case .atualizar: acoes.atualizar()
        case .ajustes: mostrarAjustes()
        case .aba(let aba): irPara(aba)
        case .anterior: irPara(Teclado.vizinha(de: estado.abaAtual, -1))
        case .proxima: irPara(Teclado.vizinha(de: estado.abaAtual, 1))
        }
    }

    private func irPara(_ aba: Aba) {
        guard !estado.boasVindas else { return }
        estado.abaAtual = aba
        if aba != .geral { estado.editandoGeral = false }
    }

    /// O painel mudou de altura (outra aba, cartão ligado ou desligado): a janela acompanha, presa pelo topo.
    func redimensionar(_ tamanho: CGSize) {
        guard let j = janela, tamanho.height > 10 else { return }
        var quadro = j.frame
        let topo = quadro.maxY
        quadro.size = NSSize(width: tamanho.width, height: tamanho.height)
        quadro.origin.y = topo - tamanho.height
        j.setFrame(quadro, display: true, animate: false)
    }

    func fecharPainel() {
        janela?.orderOut(nil)
        // Fechado, o desenho inteiro sai da memória (o SwiftUI guarda texto, ícones e gráfico desenhados);
        // ao abrir de novo ele é refeito a partir do `Estado`, que continua aqui.
        janela?.contentView = nil
        item.button?.highlight(false)
        if let v = vigiaDeClique { NSEvent.removeMonitor(v); vigiaDeClique = nil }
        if let v = vigiaDeTecla { NSEvent.removeMonitor(v); vigiaDeTecla = nil }
        aberto?.invalidate()
        aberto = nil
    }
}
