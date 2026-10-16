// Os estilos prontos: cores e fundo com nome, para escolher num clique (nas boas-vindas e na aba Aparência).
// Estilo não mexe no modo: claro, escuro ou automático é a escolha de baixo, e vale para todos os estilos.
// O último é o personalizado, em que a pessoa escolhe a cor de cada leitura.

import Foundation

struct Estilo: Identifiable {
    let id: String
    let nome: String
    let descricao: String
    let aparencia: Aparencia

    static let personalizadoId = "personalizado"

    static let todos: [Estilo] = [
        Estilo(id: "classico", nome: "Clássico", descricao: "As cores de sempre.", aparencia: Aparencia()),
        Estilo(id: "vidro", nome: "Vidro", descricao: "O vidro líquido do macOS.", aparencia: montar {
            $0.fundo = .vidro; $0.coberturaAtual = 0.4; $0.paleta = "oceano"; $0.cantos = 22; $0.movimento = .mola
        }),
        Estilo(id: "neon", nome: "Neon", descricao: "Cores fortes, ícone colorido.", aparencia: montar {
            $0.paleta = "neon"; $0.destaque = "rosa"; $0.movimento = .mola; $0.iconeColorido = true
        }),
        Estilo(id: "entardecer", nome: "Entardecer", descricao: "Laranja e rosa sobre vidro.", aparencia: montar {
            $0.fundo = .vidroClaro; $0.coberturaAtual = 0.35; $0.paleta = "entardecer"; $0.cantos = 22
        }),
        Estilo(id: "mare", nome: "Maré", descricao: "Azuis e verdes.", aparencia: montar {
            $0.paleta = "oceano"; $0.destaque = "ciano"; $0.cantos = 22
        }),
        Estilo(id: "pastel", nome: "Pastel", descricao: "Cores suaves, cantos redondos.", aparencia: montar {
            $0.paleta = "pastel"; $0.destaque = "roxo"; $0.cantos = 22; $0.movimento = .mola
        }),
        Estilo(id: "plano", nome: "Plano", descricao: "Cores chapadas, ícones coloridos.", aparencia: montar {
            $0.chapado = true; $0.iconesColoridos = true; $0.cantos = 8; $0.destaque = "azul"
        }),
        Estilo(id: "grafite", nome: "Grafite", descricao: "Só cinza, cantos retos.", aparencia: montar {
            $0.fundo = .fosco; $0.coberturaAtual = 0.6; $0.paleta = "mono"; $0.cantos = 8
        }),
    ]

    private static func montar(_ ajustar: (inout Aparencia) -> Void) -> Aparencia {
        var a = Aparencia()
        ajustar(&a)
        return a
    }

    /// A aparência do estilo, guardando o modo que a pessoa escolheu.
    func aplicado(em atual: Aparencia) -> Aparencia {
        var a = aparencia
        a.modo = atual.modo
        return a
    }

    /// O estilo que a aparência atual é, se for exatamente um deles (tirando o modo).
    static func atual(_ a: Aparencia) -> Estilo? { todos.first { $0.aparencia.igualTirandoModo(a) } }
}
