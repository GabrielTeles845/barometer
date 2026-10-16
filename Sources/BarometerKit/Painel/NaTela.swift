// O que a tela aberta do painel mostra. Com o painel aberto, o app lê a cada 2 s só o que aparece aqui; o resto
// espera a pessoa ir até lá.

import Foundation

/// O que pode ser lido com o painel aberto.
enum Leitura: CaseIterable {
    case cpu, gpu, disco, bateria, processos, portas, sugestoes
}

enum NaTela {
    /// A aba aberta, ou os cartões ligados do Geral, mostram esta leitura?
    static func mostra(_ leitura: Leitura, aba: Aba, editando: Bool, geral: [ItemGeral]) -> Bool {
        switch aba {
        case .geral:
            if editando { return false }
            let ligados = Set(geral.filter(\.ligado).map(\.id))
            switch leitura {
            case .cpu: return ligados.contains("cpu")
            // Os anéis do Geral também mostram o uso da GPU.
            case .gpu: return ligados.contains("gpu") || ligados.contains("aneis")
            case .disco: return ligados.contains("disco")
            case .bateria: return ligados.contains("bateria")
            case .processos: return ligados.contains("processos")
            case .portas: return ligados.contains("portas")
            case .sugestoes: return false
            }
        case .cpu: return leitura == .cpu || leitura == .processos
        case .memoria: return leitura == .processos
        case .gpu: return leitura == .gpu
        case .disco: return leitura == .disco
        case .bateria: return leitura == .bateria
        case .portas: return leitura == .portas
        case .limpeza: return leitura == .sugestoes
        case .aparencia: return false
        }
    }
}
