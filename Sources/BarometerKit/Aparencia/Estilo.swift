// Os estilos prontos: uma aparência inteira com nome, para escolher num clique (nas boas-vindas e na aba
// Aparência). Depois dá para ajustar cada parte em "Do meu jeito".

import Foundation

struct Estilo: Identifiable {
    let id: String
    let nome: String
    let descricao: String
    let aparencia: Aparencia

    static let todos: [Estilo] = [
        Estilo(id: "meia-noite", nome: "Meia-noite", descricao: "Preto, direto ao ponto.", aparencia: Aparencia()),
        Estilo(id: "papel", nome: "Papel", descricao: "Claro e limpo, para o dia.", aparencia: montar {
            $0.modo = .claro
        }),
        Estilo(id: "automatico", nome: "Junto com o Mac", descricao: "Claro de dia, escuro à noite.", aparencia: montar {
            $0.modo = .automatico
        }),
        Estilo(id: "vidro", nome: "Vidro", descricao: "O vidro líquido do macOS.", aparencia: montar {
            $0.fundo = .vidro; $0.coberturaAtual = 0.4; $0.paleta = "oceano"; $0.cantos = 22; $0.movimento = .mola
        }),
        Estilo(id: "neon", nome: "Neon", descricao: "Cores fortes, ícone colorido.", aparencia: montar {
            $0.paleta = "neon"; $0.destaque = "rosa"; $0.movimento = .mola; $0.iconeColorido = true
        }),
        Estilo(id: "grafite", nome: "Grafite", descricao: "Só cinza, cantos retos.", aparencia: montar {
            $0.fundo = .fosco; $0.coberturaAtual = 0.6; $0.paleta = "mono"; $0.cantos = 8
        }),
        Estilo(id: "entardecer", nome: "Entardecer", descricao: "Laranja e rosa sobre vidro.", aparencia: montar {
            $0.fundo = .vidroClaro; $0.coberturaAtual = 0.35; $0.paleta = "entardecer"; $0.cantos = 22
        }),
        Estilo(id: "oceano-claro", nome: "Maré", descricao: "Azuis e verdes no claro.", aparencia: montar {
            $0.modo = .claro; $0.paleta = "oceano"; $0.cantos = 22; $0.movimento = .mola
        }),
    ]

    private static func montar(_ ajustar: (inout Aparencia) -> Void) -> Aparencia {
        var a = Aparencia()
        ajustar(&a)
        return a
    }

    /// O estilo que a aparência atual é, se for exatamente um deles.
    static func atual(_ a: Aparencia) -> Estilo? { todos.first { $0.aparencia == a } }
}
