// A partida do app: um aplicativo só de barra (sem Dock e sem janela), com a `Barra` no comando.

import AppKit

public enum Inicio {
    @MainActor
    public static func rodar() {
        let app = NSApplication.shared
        let dono = Barra()
        app.delegate = dono
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
