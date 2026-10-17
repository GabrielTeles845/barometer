// Nomes das portas e encerrar de uma vez os servidores esquecidos.

import AppKit

extension Barra {
    /// Dar nome a uma porta. Sem número (pela engrenagem), pergunta também qual porta.
    func pedirNome(porta: Int?) {
        let alerta = NSAlert()
        alerta.messageText = porta.map { t("Nome da porta \($0)") } ?? t("Dar nome a uma porta")
        alerta.informativeText = t("Aparece na lista, nos avisos e na Limpeza. Deixe em branco para tirar.")
        let numero = NSTextField(frame: NSRect(x: 0, y: 30, width: 220, height: 24))
        numero.placeholderString = "3100"
        let nome = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        nome.placeholderString = t("painel da loja")
        if let porta { nome.stringValue = Pref.nomesDasPortas[porta] ?? "" }
        let caixa = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: porta == nil ? 54 : 24))
        if porta == nil { caixa.addSubview(numero) }
        caixa.addSubview(nome)
        alerta.accessoryView = caixa
        alerta.addButton(withTitle: t("Salvar"))
        alerta.addButton(withTitle: t("Cancelar"))
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            alerta.window.initialFirstResponder = porta == nil ? numero : nome
            guard alerta.runModal() == .alertFirstButtonReturn,
                  let n = porta ?? Int(numero.stringValue.trimmingCharacters(in: .whitespaces)), n > 0, n < 65536 else { return }
            Pref.darNome(nome.stringValue, aPorta: n)
            self?.estado.nomesDasPortas = Pref.nomesDasPortas
        }
    }

    /// Os servidores esquecidos da Limpeza, de uma vez. Cada um vai como no ×: o trabalho inteiro (TERM, e KILL
    /// só se não soltar), conferindo antes se o processo ainda é dono da porta. A caixa diz quantos processos vão.
    func confirmarEncerrarServidores() {
        let lista = Sugestoes.servidoresDa(estado.sugestoes).filter { !$0.porta.doDocker }
        guard !lista.isEmpty else { return }
        let trabalhos = lista.map { (porta: $0.porta, tempo: $0.tempo, trabalho: sonda.trabalho(de: $0.porta.pid)) }
        let processos = trabalhos.map { max(1, $0.trabalho?.membros.count ?? 1) }.reduce(0, +)
        let nomes = Pref.nomesDasPortas
        let alerta = NSAlert()
        alerta.messageText = t("Encerrar os \(lista.count) servidores?")
        var texto = trabalhos.map { item in
            "· \(item.porta.numero) " + (nomes[item.porta.numero] ?? item.porta.projeto ?? item.porta.comoChamar)
                + " — " + t("aberto há \(Medida.duracao(item.tempo))")
        }.joined(separator: "\n")
        texto += "\n\n" + t("Cada um vai como no ×: o trabalho inteiro, como o Ctrl+C no terminal. São \(processos) processos no total.")
        alerta.informativeText = texto
        alerta.addButton(withTitle: t("Encerrar"))
        alerta.addButton(withTitle: t("Cancelar"))
        alerta.buttons.first?.hasDestructiveAction = true
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            guard alerta.runModal() == .alertFirstButtonReturn else { Diario.anotar("encerrar servidores: cancelado"); return }
            Diario.anotar("encerrar servidores: " + lista.map { "\($0.porta.numero)" }.joined(separator: ", "))
            // A fila da sonda é serial: um de cada vez, cada um com a sua conferência e o seu aviso se falhar.
            for item in trabalhos { self?.encerrar(item.porta, item.trabalho) }
            self?.sugestoesEm = .distantPast
        }
    }
}
