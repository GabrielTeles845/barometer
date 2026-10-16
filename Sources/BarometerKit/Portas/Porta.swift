import AppKit
import Combine
import IOKit
import ServiceManagement
import SwiftUI

struct Porta {
    let numero: Int
    let pid: Int32
    /// Como o `lsof` chama o processo, com `+c 0` para vir inteiro em vez de
    /// truncado em nove letras ("com.docke", "ControlCe").
    let comando: String
    /// A linha de comando resumida: é onde aparece o que interessa de verdade,
    /// tipo `next-server (v14.2.24)` em vez de só `node`.
    var detalhe: String = ""
    /// A pasta de trabalho do processo — o que responde "de qual projeto é isso".
    var pasta: String?
    /// Nome do container, quando a porta é publicada pelo Docker.
    var container: String?
    /// O projeto: o `name` do package.json, ou a pasta que tem o `.git`, subindo
    /// a partir da pasta de trabalho. "minha-loja-api" diz mais que "src".
    var projeto: String?
    /// O projeto do docker compose (o rótulo `com.docker.compose.project`): é o
    /// que diz que o `postgres` da 5433 é do "minha-loja", e não de outro.
    var composto: String?
    /// `*` (todas as interfaces) ou um endereço específico como `127.0.0.1`.
    let endereco: String

    var doDocker: Bool { container != nil || Porta.ehDocker(comando) }

    static func ehDocker(_ c: String) -> Bool {
        let n = c.lowercased()
        return n.hasPrefix("com.docker") || n.contains("docker") || n.hasPrefix("vpnkit")
    }

    /// O que escrever depois do número. Preferir sempre a informação mais
    /// específica que se conseguiu: container > linha de comando > nome do
    /// processo. `com.docker.backend` não diz nada; `postgres` diz tudo.
    var comoChamar: String {
        if doDocker { return detalhe.isEmpty ? "docker" : detalhe }
        return detalhe.isEmpty ? comando : detalhe
    }

    /// Só faz sentido abrir no navegador o que provavelmente fala HTTP. Abrir
    /// `localhost:5432` no Safari não mostra o Postgres; mostra erro.
    var web: Bool {
        if doDocker && (numero == 5432 || numero == 5433 || numero == 3306
                        || numero == 6379 || numero == 6380 || numero == 27017) { return false }
        switch numero {
        case 5432, 5433, 3306, 6379, 6380, 27017, 11211, 9200, 5672: return false
        default: return true
        }
    }

    /// Endereço curto para a segunda linha: a pasta, quando existe, é o que
    /// identifica o projeto; senão o container; senão nada.
    var contexto: String? {
        if let c = container {
            // "minha-loja · minha-loja-postgres" repete; o nome do container já diz o projeto.
            if let k = composto, !k.isEmpty, !c.lowercased().hasPrefix(k.lowercased()) { return "\(k) · \(c)" }
            return c
        }
        if let p = projeto, !p.isEmpty { return p }
        if let p = pasta, !p.isEmpty { return (p as NSString).lastPathComponent }
        return nil
    }

    /// Uma linha só, para onde não cabe a segunda linha (favoritas, dica da barra).
    var resumo: String {
        if let c = contexto, c != comoChamar { return "\(comoChamar) · \(c)" }
        return comoChamar
    }
}

/// Um processo, para subir a árvore e descobrir de que **trabalho** ele faz
/// parte.
///
/// Existe porque matar quem ouve a porta muitas vezes não resolve nada: num
/// `npm run dev`, quem ouve é um neto. O pai o ressuscita em menos de um
/// segundo e o terminal nunca volta ao prompt — medido, a porta voltava com
/// PID novo em 300ms.
struct Elo {
    let pid: Int32
    let ppid: Int32
    let pgid: Int32
    let comando: String

    /// O executável, sem caminho e sem argumentos.
    var nome: String {
        let primeiro = comando.split(separator: " ").first.map(String.init) ?? comando
        return (primeiro as NSString).lastPathComponent
    }

    /// Cabe numa linha da caixa de confirmação.
    var resumo: String {
        let limpo = comando.split(separator: " ").map { pedaco -> String in
            pedaco.hasPrefix("/") ? (pedaco as NSString).lastPathComponent : String(pedaco)
        }.joined(separator: " ")
        return limpo.count > 56 ? String(limpo.prefix(55)) + "\u{2026}" : limpo
    }
}

/// Como encerrar.
enum Plano {
    /// O trabalho tem grupo de processos próprio, e mandar sinal para o grupo
    /// é **exatamente** o que o Ctrl+C no terminal faz. É o caminho bom.
    case grupo(Int32)
    /// Sem grupo confiável: um a um, do mais de fora para o mais de dentro.
    case processos
}
