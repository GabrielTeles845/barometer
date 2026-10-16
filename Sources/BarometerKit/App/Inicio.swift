// A partida do app: um aplicativo só de barra (sem Dock e sem janela), com a `Barra` no comando.

import AppKit

public enum Inicio {
    @MainActor
    public static func rodar() {
        if CommandLine.arguments.contains(ArnesDoEncerrar.opcao) { ArnesDoEncerrar.rodar(CommandLine.arguments) }
        let app = NSApplication.shared
        let dono = Barra()
        app.delegate = dono
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
