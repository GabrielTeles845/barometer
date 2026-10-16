// Quando cada app foi usado pela última vez: o Barometer anota toda vez que você troca de app. O macOS não guarda
// isso em lugar nenhum que se possa ler, então vale do momento em que o Barometer abriu em diante; antes disso,
// conta a hora em que o app abriu.

import AppKit

final class UsoDosApps {
    private(set) var ultimoUso: [String: Date] = [:]
    private var vigia: NSObjectProtocol?
    let desde = Date()

    init() {
        if let ativo = NSWorkspace.shared.frontmostApplication?.bundleURL?.path { ultimoUso[ativo] = Date() }
        vigia = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                                  object: nil, queue: .main) { [weak self] aviso in
            let app = aviso.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if let caminho = app?.bundleURL?.path { self?.ultimoUso[caminho] = Date() }
        }
    }

    deinit { if let vigia { NSWorkspace.shared.notificationCenter.removeObserver(vigia) } }

    /// Os apps abertos agora (os de janela, não os de fundo), com o último uso de cada um. Sem uso anotado,
    /// conta a partir de quando o Barometer abriu: ele não sabe o que aconteceu antes. A foto (`--retrato`) usa a
    /// hora em que o app abriu, para ter o que mostrar.
    func abertos(contarDesdeQueAbriu: Bool = false) -> [Sugestoes.AppAberto] {
        let ativo = NSWorkspace.shared.frontmostApplication?.bundleURL?.path
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular, let caminho = app.bundleURL?.path, caminho != ativo,
                  caminho != Bundle.main.bundlePath else { return nil }
            let abriu = app.launchDate ?? desde
            let uso = ultimoUso[caminho] ?? (contarDesdeQueAbriu ? abriu : max(abriu, desde))
            return Sugestoes.AppAberto(caminho: caminho, nome: app.localizedName ?? (caminho as NSString).lastPathComponent,
                                       ultimoUso: uso)
        }
    }
}
