import AppKit
import SwiftUI

/// As animações do painel, conforme o "jeito de mexer" escolhido. `nil` desliga.
enum Mexer {
    /// Trocar de aba, abrir o editor, ligar e desligar cartões.
    static var troca: Animation? {
        switch Aparencia.atual.movimento {
        case .suave: return .snappy(duration: 0.28)
        case .mola: return .spring(response: 0.42, dampingFraction: 0.68)
        case .nenhum: return nil
        }
    }

    /// Coisas pequenas (passar o mouse, a pílula da aba, interruptor).
    static var leve: Animation? {
        switch Aparencia.atual.movimento {
        case .suave: return .snappy(duration: 0.2)
        case .mola: return .spring(response: 0.32, dampingFraction: 0.62)
        case .nenhum: return nil
        }
    }

    /// Um número ou uma barra mudando de valor: com "Sem animação", pula direto.
    static func valor(_ a: Animation) -> Animation? { Aparencia.atual.movimento == .nenhum ? nil : a }

    /// O conteúdo que entra ao trocar de aba: sobe um pouco e sai do desfoque.
    static var entrada: AnyTransition {
        switch Aparencia.atual.movimento {
        case .nenhum: return .identity
        case .suave: return .asymmetric(insertion: .opacity.combined(with: .offset(y: 8)), removal: .opacity)
        case .mola:
            return .asymmetric(
                insertion: .modifier(active: Desfoque(raio: 8, escala: 0.97), identity: Desfoque(raio: 0, escala: 1))
                    .combined(with: .opacity).combined(with: .offset(y: 10)),
                removal: .opacity)
        }
    }
}

struct Desfoque: ViewModifier {
    let raio: CGFloat
    let escala: CGFloat
    func body(content: Content) -> some View { content.blur(radius: raio).scaleEffect(escala, anchor: .top) }
}
