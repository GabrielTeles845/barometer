// O teclado com o painel aberto: ⌘1 a ⌘9 vão direto para uma aba, as setas passam de uma para a outra,
// ⌘R atualiza, ⌘, abre os ajustes e o Esc fecha. Tipo puro, para os testes chegarem sem janela.

import Foundation

enum Tecla: Equatable {
    case aba(Aba)
    case anterior, proxima
    case atualizar, ajustes, fechar
}

enum Teclado {
    static let esc: UInt16 = 53
    static let esquerda: UInt16 = 123
    static let direita: UInt16 = 124

    /// - Parameters:
    ///   - letra: a tecla sem modificadores (`charactersIgnoringModifiers`).
    ///   - comando: o ⌘ está apertado (sem ⌥ nem ⌃, que ficam para os atalhos dos outros apps).
    static func acao(letra: String?, codigo: UInt16, comando: Bool) -> Tecla? {
        if codigo == esc { return .fechar }
        if !comando {
            if codigo == esquerda { return .anterior }
            if codigo == direita { return .proxima }
            return nil
        }
        switch letra?.lowercased() {
        case "r": return .atualizar
        case ",": return .ajustes
        case let l?:
            guard let n = Int(l), n >= 1, n <= Aba.allCases.count else { return nil }
            return .aba(Aba.allCases[n - 1])
        case nil: return nil
        }
    }

    /// A aba ao lado, dando a volta nas pontas.
    static func vizinha(de aba: Aba, _ passo: Int) -> Aba {
        let abas = Aba.allCases
        let i = abas.firstIndex(of: aba) ?? 0
        return abas[(i + passo + abas.count) % abas.count]
    }
}
