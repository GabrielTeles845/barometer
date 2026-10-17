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
}
