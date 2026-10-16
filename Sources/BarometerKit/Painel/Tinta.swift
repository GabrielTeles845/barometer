// As cores do painel. Tudo o que é texto, cartão, borda e trilho sai da `tinta` (branca no escuro, preta no claro),
// para o modo claro e o escuro usarem as mesmas peças. As cores das leituras vêm da paleta escolhida.

import SwiftUI

enum Tinta {
    static var escuro: Bool { Aparencia.atual.escuroAgora }

    /// A base de tudo que é neutro: branca no escuro, preta no claro, sempre com opacidade.
    static var tinta: Color { escuro ? .white : .black }
    static var fundo: Color { escuro ? Color(red: 0.035, green: 0.035, blue: 0.04) : Color(red: 0.965, green: 0.965, blue: 0.972) }
    static var cartao: Color { tinta.opacity(escuro ? 0.045 : 0.045) }
    static var borda: Color { tinta.opacity(escuro ? 0.08 : 0.1) }
    static var texto: Color { tinta.opacity(escuro ? 0.92 : 0.86) }
    static var apagado: Color { tinta.opacity(escuro ? 0.5 : 0.55) }
    static var fraco: Color { tinta.opacity(escuro ? 0.3 : 0.4) }
    /// O balão com o nome dos ícones.
    static var dica: Color { escuro ? Color(white: 0.17) : .white }
    /// Aviso: o vermelho não muda com a paleta, para continuar parecendo aviso.
    static let calor = Color(red: 1.0, green: 0.36, blue: 0.36)

    private static var paleta: Paleta { Aparencia.atual.paletaAtual.paraOModo(escuro: escuro) }
    static var memoria: Color { paleta.memoria }
    static var cpu: Color { paleta.cpu }
    static var porta: Color { paleta.porta }
    static var fixa: Color { paleta.fixa }
    static var eficiencia: Color { paleta.eficiencia }
    static var gpu: Color { paleta.gpu }
    static var disco: Color { paleta.disco }
    static var comprimida: Color { paleta.comprimida }
    static var bateria: Color { paleta.bateria }
    /// Interruptores, o que está escolhido e os marcadores.
    static var destaque: Color { Aparencia.atual.corDeDestaque }

    static func pressao(_ n: Int) -> Color { n >= 4 ? calor : (n >= 2 ? cpu : porta) }
}
