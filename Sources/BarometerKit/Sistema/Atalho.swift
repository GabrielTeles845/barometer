// O atalho do teclado que abre o painel de qualquer app. Pelo Carbon (`RegisterEventHotKey`): é o único jeito de
// ouvir uma combinação global sem pedir a permissão de Acessibilidade, e o macOS só entrega aquela combinação.

import Carbon.HIToolbox
import Foundation

enum Atalho: String, CaseIterable, Codable {
    case desligado, controleOpcaoB, opcaoComandoB, controleOpcaoEspaco, controleOpcaoM

    /// O de fábrica: ⌃⌥B quase nenhum app usa (⌥⌘B é o gerenciador de favoritos do Chrome).
    static let padrao = Atalho.controleOpcaoB

    var nome: String {
        switch self {
        case .desligado: return t("Desligado")
        case .controleOpcaoB: return "⌃⌥B"
        case .opcaoComandoB: return "⌥⌘B"
        case .controleOpcaoEspaco: return "⌃⌥" + t("Espaço")
        case .controleOpcaoM: return "⌃⌥M"
        }
    }

    /// A tecla (código do teclado) e os modificadores do Carbon.
    var combinacao: (tecla: UInt32, modificadores: UInt32)? {
        switch self {
        case .desligado: return nil
        case .controleOpcaoB: return (UInt32(kVK_ANSI_B), UInt32(controlKey | optionKey))
        case .opcaoComandoB: return (UInt32(kVK_ANSI_B), UInt32(optionKey | cmdKey))
        case .controleOpcaoEspaco: return (UInt32(kVK_Space), UInt32(controlKey | optionKey))
        case .controleOpcaoM: return (UInt32(kVK_ANSI_M), UInt32(controlKey | optionKey))
        }
    }
}

/// Registra um atalho por vez; trocar desfaz o anterior.
final class OuvidoDoAtalho {
    private var registro: EventHotKeyRef?
    private var manipulador: EventHandlerRef?
    /// O Carbon chama uma função C, sem contexto: o que fazer fica aqui (só existe um ouvido no app).
    nonisolated(unsafe) private static var aoApertar: (() -> Void)?

    init(aoApertar: @escaping () -> Void) {
        Self.aoApertar = aoApertar
        var tipo = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { OuvidoDoAtalho.aoApertar?() }
            return noErr
        }, 1, &tipo, nil, &manipulador)
    }

    /// Devolve falso quando outro app já tomou a combinação.
    @discardableResult
    func usar(_ atalho: Atalho) -> Bool {
        if let r = registro { UnregisterEventHotKey(r); registro = nil }
        guard let c = atalho.combinacao else { return true }
        let id = EventHotKeyID(signature: OSType(0x4241524F), id: 1) // "BARO"
        return RegisterEventHotKey(c.tecla, c.modificadores, id, GetApplicationEventTarget(), 0, &registro) == noErr
    }
}
