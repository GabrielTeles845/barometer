// A aba Limpeza: medir as pastas e confirmar antes de apagar.

import AppKit
import Foundation

extension Barra {
    /// Mede cada pasta fora da thread principal e vai mostrando conforme termina. Se mediu há menos de 2 minutos,
    /// não mede de novo.
    func medirLimpeza(forcar: Bool = false) {
        guard forcar || Date().timeIntervalSince(limpezaMedidaEm) > 120 || estado.limpeza.isEmpty else { return }
        limpezaMedidaEm = Date()
        let itens = Limpeza.itens()
        let antigos = Dictionary(estado.limpeza.map { ($0.id, $0.bytes) }, uniquingKeysWith: { a, _ in a })
        estado.limpeza = itens.map { var i = $0; i.bytes = antigos[$0.id] ?? nil; return i }
        estado.medindoLimpeza = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            for item in itens {
                let bytes = Limpeza.tamanho(item.pasta)
                DispatchQueue.main.async {
                    guard let self, let i = self.estado.limpeza.firstIndex(where: { $0.id == item.id }) else { return }
                    self.estado.limpeza[i].bytes = bytes
                }
            }
            DispatchQueue.main.async { self?.estado.medindoLimpeza = false }
        }
    }

    func confirmarLimpeza(ids: [String]) {
        let itens = estado.limpeza.filter { ids.contains($0.id) }
        guard !itens.isEmpty else { return }
        fecharPainel()
        let total = itens.compactMap(\.bytes).reduce(0, +)
        let alerta = NSAlert()
        if itens.count == 1, let item = itens.first {
            if item.ehLixeira {
                alerta.messageText = t("Esvaziar a Lixeira?")
                alerta.informativeText = t("Os arquivos da Lixeira são apagados de vez. Não tem como recuperar depois.")
                alerta.addButton(withTitle: t("Esvaziar"))
            } else {
                alerta.messageText = t("Limpar \(t(item.nome))?")
                alerta.informativeText = t("Vão sair \(Maquina.gb(item.bytes ?? 0)). \(t(item.explicacao))")
                alerta.addButton(withTitle: t("Limpar"))
            }
        } else {
            alerta.messageText = t("Limpar tudo, \(Maquina.gb(total))?")
            alerta.informativeText = t("Saem os caches dos apps e dos gerenciadores de pacote, os dados do Xcode e os registros. A Lixeira fica.")
            alerta.addButton(withTitle: t("Limpar"))
        }
        alerta.addButton(withTitle: t("Cancelar"))
        alerta.buttons.first?.hasDestructiveAction = true
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            guard alerta.runModal() == .alertFirstButtonReturn else { return }
            Diario.anotar("limpeza: " + itens.map(\.id).joined(separator: ", "))
            DispatchQueue.global(qos: .utility).async {
                let liberado = itens.map(Limpeza.limpar).reduce(0, +)
                DispatchQueue.main.async {
                    Diario.anotar("limpeza liberou \(Int(liberado / 1_048_576)) MB")
                    self?.estado.liberado = liberado
                    self?.medirLimpeza(forcar: true)
                    self?.amostrar()
                }
            }
        }
    }
}
