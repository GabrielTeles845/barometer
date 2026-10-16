// O arnês da prova do × (provas/provar-encerrar.py): `barometer --arnes-encerrar <pid> [--matar]` imprime o que a
// `Sonda` decide encerrar para aquele processo e, com `--matar`, encerra pelo MESMO caminho do botão. A prova sobe
// processos de verdade e confere quem morre; aqui não há reimplementação: é o código do app.

import Foundation

enum ArnesDoEncerrar {
    static let opcao = "--arnes-encerrar"

    static func rodar(_ argumentos: [String]) -> Never {
        guard let i = argumentos.firstIndex(of: opcao), i + 1 < argumentos.count, let alvo = Int32(argumentos[i + 1]) else {
            print("uso: barometer \(opcao) <pid> [--matar]")
            exit(2)
        }
        let sonda = Sonda()
        guard let trab = sonda.trabalho(de: alvo) else {
            print("plano=nenhum")
            exit(0)
        }
        if argumentos.contains("--matar") {
            _ = sonda.sinalizar(trab.plano, trab.membros, SIGTERM)
            print("sinal=TERM")
        }
        switch trab.plano {
        case .grupo(let g): print("plano=grupo \(g)")
        case .processos: print("plano=processos")
        }
        for m in trab.membros { print("membro \(m.pid) \(m.nome) :: \(m.comando)") }
        exit(0)
    }
}
