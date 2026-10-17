import AppKit
import Combine
import IOKit
import ServiceManagement
import SwiftUI

enum Pref {
    /// Onde as escolhas ficam. Os testes trocam por um armazém próprio, para não mexer nas escolhas de quem usa.
    /// Só muda nos testes de preferência, que rodam um de cada vez; o app nunca troca.
    nonisolated(unsafe) static var armazem = UserDefaults.standard

    /// Já passou pelas boas-vindas (a escolha do estilo na primeira abertura).
    static var viuBoasVindas: Bool {
        get { armazem.bool(forKey: "viuBoasVindas") }
        set { armazem.set(newValue, forKey: "viuBoasVindas") }
    }

    /// A pessoa desligou o "abrir ao ligar o Mac": o app não liga de novo sozinho.
    static var desligouLogin: Bool {
        get { armazem.bool(forKey: "desligouLogin") }
        set { armazem.set(newValue, forKey: "desligouLogin") }
    }

    /// Fundo, cores e animações do painel (aba Aparência).
    static var aparencia: Aparencia {
        get {
            guard let dados = armazem.data(forKey: "aparencia"),
                  let a = try? JSONDecoder().decode(Aparencia.self, from: dados) else { return Aparencia() }
            return a
        }
        set { armazem.set(try? JSONEncoder().encode(newValue), forKey: "aparencia") }
    }

    /// Os cartões do Geral. Junta com o padrão: cartão novo de uma versão nova aparece no fim, desligado.
    static var geral: [ItemGeral] {
        get {
            guard let dados = armazem.data(forKey: "geral"),
                  let salvos = try? JSONDecoder().decode([ItemGeral].self, from: dados) else { return ItemGeral.padrao }
            let conhecidos = salvos.filter { ItemGeral.nomes[$0.id] != nil }
            let novos = ItemGeral.padrao.filter { p in !conhecidos.contains { $0.id == p.id } }.map { ItemGeral(id: $0.id, ligado: false) }
            return conhecidos + novos
        }
        set { armazem.set(try? JSONEncoder().encode(newValue), forKey: "geral") }
    }

    /// O que aparece na barra de menus. Quem tinha desligado o uso no ícone (versão antiga) começa só com as portas.
    static var naBarra: [ItemDaBarra] {
        get {
            if let dados = armazem.data(forKey: "naBarra"),
               let itens = try? JSONDecoder().decode([ItemDaBarra].self, from: dados) { return Array(itens.prefix(ItemDaBarra.maximo)) }
            return memoriaNaBarra ? ItemDaBarra.padrao : [.portas]
        }
        set { armazem.set(try? JSONEncoder().encode(newValue), forKey: "naBarra") }
    }

    static var memoriaNaBarra: Bool {
        get { armazem.object(forKey: "memoriaNaBarra") as? Bool ?? true }
        set { armazem.set(newValue, forKey: "memoriaNaBarra") }
    }

    static var tudo: Bool {
        get { armazem.bool(forKey: "mostrarTudo") }
        set { armazem.set(newValue, forKey: "mostrarTudo") }
    }

    /// As portas que você quer ver mesmo quando estão livres — a resposta
    /// direta para "tem coisa na 3000 e na 3006?".
    /// Quantos processos a lista de quem mais usa mostra (3, 5 ou 8).
    static let opcoesDeProcessos = [3, 5, 8]
    static var quantosProcessos: Int {
        get { let n = armazem.integer(forKey: "quantosProcessos"); return opcoesDeProcessos.contains(n) ? n : 8 }
        set { armazem.set(newValue, forKey: "quantosProcessos") }
    }

    static var favoritas: [Int] {
        get {
            if armazem.object(forKey: "favoritas") == nil {
                return [3000, 3001, 3006, 5173, 8000]
            }
            return (armazem.array(forKey: "favoritas") as? [Int] ?? []).sorted()
        }
        set { armazem.set(Array(Set(newValue)).sorted(), forKey: "favoritas") }
    }

    /// O atalho que abre o painel de qualquer app.
    static var atalho: Atalho {
        get { Atalho(rawValue: armazem.string(forKey: "atalho") ?? "") ?? .padrao }
        set { armazem.set(newValue.rawValue, forKey: "atalho") }
    }

    /// Os avisos ligados. Todos desligados de fábrica: aviso que ninguém pediu vira barulho.
    static var avisos: Set<Aviso> {
        get { Set((armazem.stringArray(forKey: "avisos") ?? []).compactMap(Aviso.init(rawValue:))) }
        set { armazem.set(newValue.map(\.rawValue).sorted(), forKey: "avisos") }
    }

    /// Os nomes que a pessoa deu às portas (3100 → "painel Evollute"). Gravados com a chave em texto (o
    /// UserDefaults não guarda dicionário com chave número).
    static var nomesDasPortas: [Int: String] {
        get {
            let salvos = armazem.dictionary(forKey: "nomesDasPortas") as? [String: String] ?? [:]
            return salvos.reduce(into: [:]) { r, par in if let n = Int(par.key) { r[n] = par.value } }
        }
        set { armazem.set(Dictionary(uniqueKeysWithValues: newValue.map { (String($0.key), $0.value) }), forKey: "nomesDasPortas") }
    }

    /// Dá nome a uma porta; nome vazio tira o que havia. No máximo 40 letras, para caber na linha.
    static func darNome(_ nome: String, aPorta n: Int) {
        var nomes = nomesDasPortas
        let limpo = String(nome.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        nomes[n] = limpo.isEmpty ? nil : limpo
        nomesDasPortas = nomes
    }

    static func virarFavorita(_ n: Int) {
        var f = favoritas
        if let i = f.firstIndex(of: n) { f.remove(at: i) } else { f.append(n) }
        favoritas = f
    }
}
