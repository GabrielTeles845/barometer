// O menu da engrenagem.

import AppKit
import Foundation

extension Barra {
    @objc func ajusteAbrirAoLigar() { virarLogin() }
    @objc func ajusteUsoNoIcone() { Pref.memoriaNaBarra.toggle(); estado.memoriaNaBarra = Pref.memoriaNaBarra; desenharIcone() }
    @objc func ajusteFavorita(_ mi: NSMenuItem) { Pref.virarFavorita(mi.tag); estado.favoritas = Pref.favoritas }
    @objc func ajusteOutraFavorita() { fecharPainel(); pedirFavorita() }
    @objc func ajusteNomeDaPorta() { fecharPainel(); pedirNome(porta: nil) }
    @objc func ajusteSair() { NSApp.terminate(nil) }
    @objc func ajusteNaBarra(_ mi: NSMenuItem) {
        guard let opcao = ItemDaBarra(rawValue: mi.representedObject as? String ?? "") else { return }
        if let i = estado.naBarra.firstIndex(of: opcao) { estado.naBarra.remove(at: i) }
        else if estado.naBarra.count < ItemDaBarra.maximo { estado.naBarra.append(opcao) }
    }
    @objc func ajusteIdioma(_ mi: NSMenuItem) {
        Idioma.escolhido = Idioma(rawValue: mi.representedObject as? String ?? "") ?? .automatico
        // Tudo o que está na tela passa pelo `t()` de novo.
        estado.objectWillChange.send()
        desenharIcone()
    }

    func mostrarAjustes() {
        let m = NSMenu()
        func item(_ t: String, _ sel: Selector, ligado: Bool? = nil) -> NSMenuItem {
            let mi = NSMenuItem(title: t, action: sel, keyEquivalent: "")
            mi.target = self
            if let ligado { mi.state = ligado ? .on : .off }
            return mi
        }
        m.addItem(item(t("Abrir ao ligar o Mac"), #selector(ajusteAbrirAoLigar), ligado: Login.ligado))
        let naBarra = NSMenu()
        for opcao in ItemDaBarra.allCases {
            let mi = item(opcao.nome, #selector(ajusteNaBarra(_:)), ligado: estado.naBarra.contains(opcao))
            mi.representedObject = opcao.rawValue
            mi.image = NSImage(systemSymbolName: opcao.simbolo, accessibilityDescription: nil)
            if !estado.naBarra.contains(opcao) && estado.naBarra.count >= ItemDaBarra.maximo { mi.action = nil }
            naBarra.addItem(mi)
        }
        let paiBarra = NSMenuItem(title: t("Na barra de menus (até 3)"), action: nil, keyEquivalent: "")
        paiBarra.submenu = naBarra
        m.addItem(paiBarra)
        menusDeAtalhoEAvisos { item($0, $1, ligado: $2) }.forEach(m.addItem)
        let favoritas = NSMenu()
        let sugeridas = [3000, 3001, 3002, 3003, 3006, 4000, 5173, 5432, 6379, 8000, 8080]
        for n in Array(Set(sugeridas).union(Pref.favoritas)).sorted() {
            let mi = item(Pref.nomesDasPortas[n].map { "\(n) · \($0)" } ?? "\(n)", #selector(ajusteFavorita(_:)), ligado: Pref.favoritas.contains(n))
            mi.tag = n
            favoritas.addItem(mi)
        }
        favoritas.addItem(.separator())
        favoritas.addItem(item(t("Outra porta…"), #selector(ajusteOutraFavorita)))
        favoritas.addItem(item(t("Dar nome a uma porta…"), #selector(ajusteNomeDaPorta)))
        let pai = NSMenuItem(title: t("Portas favoritas"), action: nil, keyEquivalent: "")
        pai.submenu = favoritas
        m.addItem(pai)
        let idiomas = NSMenu()
        for idioma in Idioma.allCases {
            let mi = item(idioma.nome, #selector(ajusteIdioma(_:)), ligado: Idioma.escolhido == idioma)
            mi.representedObject = idioma.rawValue
            idiomas.addItem(mi)
        }
        let paiIdioma = NSMenuItem(title: t("Idioma"), action: nil, keyEquivalent: "")
        paiIdioma.submenu = idiomas
        m.addItem(paiIdioma)
        m.addItem(.separator())
        m.addItem(item(t("Sair"), #selector(ajusteSair)))
        m.appearance = NSAppearance(named: .darkAqua)
        if let j = janela, let vista = j.contentView {
            m.popUp(positioning: nil, at: NSPoint(x: vista.bounds.maxX - 40, y: 40), in: vista)
        }
    }
}
