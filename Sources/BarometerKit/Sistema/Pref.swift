import AppKit
import Combine
import IOKit
import ServiceManagement
import SwiftUI

enum Pref {
    /// Fundo, cores e animações do painel (aba Aparência).
    static var aparencia: Aparencia {
        get {
            guard let dados = UserDefaults.standard.data(forKey: "aparencia"),
                  let a = try? JSONDecoder().decode(Aparencia.self, from: dados) else { return Aparencia() }
            return a
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "aparencia") }
    }

    /// Os cartões do Geral. Junta com o padrão: cartão novo de uma versão nova aparece no fim, desligado.
    static var geral: [ItemGeral] {
        get {
            guard let dados = UserDefaults.standard.data(forKey: "geral"),
                  let salvos = try? JSONDecoder().decode([ItemGeral].self, from: dados) else { return ItemGeral.padrao }
            let conhecidos = salvos.filter { ItemGeral.nomes[$0.id] != nil }
            let novos = ItemGeral.padrao.filter { p in !conhecidos.contains { $0.id == p.id } }.map { ItemGeral(id: $0.id, ligado: false) }
            return conhecidos + novos
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "geral") }
    }

    /// O que aparece na barra de menus. Quem tinha desligado o uso no ícone (versão antiga) começa só com as portas.
    static var naBarra: [ItemDaBarra] {
        get {
            if let dados = UserDefaults.standard.data(forKey: "naBarra"),
               let itens = try? JSONDecoder().decode([ItemDaBarra].self, from: dados) { return Array(itens.prefix(ItemDaBarra.maximo)) }
            return memoriaNaBarra ? ItemDaBarra.padrao : [.portas]
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "naBarra") }
    }

    static var memoriaNaBarra: Bool {
        get { UserDefaults.standard.object(forKey: "memoriaNaBarra") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "memoriaNaBarra") }
    }

    static var tudo: Bool {
        get { UserDefaults.standard.bool(forKey: "mostrarTudo") }
        set { UserDefaults.standard.set(newValue, forKey: "mostrarTudo") }
    }

    /// As portas que você quer ver mesmo quando estão livres — a resposta
    /// direta para "tem coisa na 3000 e na 3006?".
    static var favoritas: [Int] {
        get {
            if UserDefaults.standard.object(forKey: "favoritas") == nil {
                return [3000, 3001, 3006, 5173, 8000]
            }
            return (UserDefaults.standard.array(forKey: "favoritas") as? [Int] ?? []).sorted()
        }
        set { UserDefaults.standard.set(Array(Set(newValue)).sorted(), forKey: "favoritas") }
    }

    static func virarFavorita(_ n: Int) {
        var f = favoritas
        if let i = f.firstIndex(of: n) { f.remove(at: i) } else { f.append(n) }
        favoritas = f
    }
}
