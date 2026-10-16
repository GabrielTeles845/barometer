import AppKit
import Combine
import IOKit
import ServiceManagement
import SwiftUI

/// O painel é uma janela sem moldura, e não um `NSMenu`: menu não deixa fundo preto, gráfico nem linha fina com
/// × só ao passar o mouse. Ela pode virar a janela ativa (para o mouse acender as linhas), mas sem trazer o app
/// para a frente.
final class JanelaDoPainel: NSPanel {
    override var canBecomeKey: Bool { true }
}
