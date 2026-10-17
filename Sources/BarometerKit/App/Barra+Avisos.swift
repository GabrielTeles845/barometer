// Os avisos do macOS (o que a `Vigia` decide) e o atalho que abre o painel de qualquer app.

import AppKit
import UserNotifications

extension Barra {
    func ligarAtalhoEAvisos() {
        ouvido = OuvidoDoAtalho { [weak self] in self?.alternar() }
        if ouvido?.usar(Pref.atalho) == false { Diario.anotar("atalho \(Pref.atalho.rawValue) já é de outro app") }
        vigia.ligados = Pref.avisos
    }

    /// A cada leitura de 10 s. Só lê algo a mais (bateria, portas) se o aviso dela está ligado.
    func vigiar() {
        guard !vigia.ligados.isEmpty else { return }
        var l = LeituraDoVigia(pressao: estado.pressao, chip: estado.temperatura.chip)
        if let d = estado.disco { l.disco = (d.livre, d.total) }
        if vigia.ligados.contains(.bateria) {
            let b = estado.naBarra.contains(.bateria) ? estado.bateria : leitorDeBateria.ler(comOficial: false)
            if let b, b.existe { l.bateria = (b.nivel, b.naTomada) }
        }
        if vigia.ligados.contains(.porta) {
            let favoritas = Set(Pref.favoritas)
            let nomes = Pref.nomesDasPortas
            var ocupadas: [Int: String] = [:]
            for p in portas where favoritas.contains(p.numero) { ocupadas[p.numero] = nomes[p.numero] ?? p.projeto ?? p.comoChamar }
            for o in ocultas where favoritas.contains(o.numero) { ocupadas[o.numero] = nomes[o.numero] ?? o.nome }
            l.portas = ocupadas
            // Com as portas fora da barra e o painel fechado, ninguém mais as lê: o aviso pede uma leitura.
            if !precisaDasPortas { varrer() }
        }
        for d in vigia.olhar(l) { avisar(d) }
    }

    private func avisar(_ d: Disparo) {
        Diario.anotar("aviso: \(d.titulo)")
        let c = UNMutableNotificationContent()
        c.title = d.titulo
        c.body = d.texto
        c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: d.id, content: c, trigger: nil)) { erro in
            if let erro { Diario.anotar("aviso não saiu: \(erro.localizedDescription)") }
        }
    }

    @objc func ajusteAtalho(_ mi: NSMenuItem) {
        guard let a = Atalho(rawValue: mi.representedObject as? String ?? "") else { return }
        if ouvido?.usar(a) == false {
            ouvido?.usar(Pref.atalho)
            let alerta = NSAlert()
            alerta.messageText = t("Outro app já usa \(a.nome)")
            alerta.informativeText = t("Escolha outra combinação.")
            alerta.runModal()
            return
        }
        Pref.atalho = a
    }

    @objc func ajusteAviso(_ mi: NSMenuItem) {
        guard let a = Aviso(rawValue: mi.representedObject as? String ?? "") else { return }
        var ligados = Pref.avisos
        if ligados.contains(a) { ligados.remove(a) } else { ligados.insert(a) }
        Pref.avisos = ligados
        vigia.ligados = ligados
        // A permissão do macOS é pedida só quando a pessoa liga o primeiro aviso.
        if !ligados.isEmpty {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
                if !ok { Diario.anotar("avisos sem permissão do macOS") }
            }
        }
    }

    /// Os dois submenus da engrenagem: o atalho e os avisos.
    func menusDeAtalhoEAvisos(_ item: (String, Selector, Bool?) -> NSMenuItem) -> [NSMenuItem] {
        let atalhos = NSMenu()
        for a in Atalho.allCases {
            let mi = item(a.nome, #selector(ajusteAtalho(_:)), Pref.atalho == a)
            mi.representedObject = a.rawValue
            atalhos.addItem(mi)
        }
        let paiAtalho = NSMenuItem(title: t("Atalho para abrir"), action: nil, keyEquivalent: "")
        paiAtalho.submenu = atalhos

        let avisos = NSMenu()
        for a in Aviso.allCases {
            let mi = item(a.nome, #selector(ajusteAviso(_:)), Pref.avisos.contains(a))
            mi.representedObject = a.rawValue
            avisos.addItem(mi)
        }
        let paiAvisos = NSMenuItem(title: t("Avisos"), action: nil, keyEquivalent: "")
        paiAvisos.submenu = avisos
        return [paiAtalho, paiAvisos]
    }
}
