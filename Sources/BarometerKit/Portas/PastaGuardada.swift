// Pastas que o macOS guarda: entrar nelas faz o sistema perguntar se o Barometer pode ver o Apple Music, as fotos
// ou os dados de outros apps. Nenhum projeto de ninguém mora ali, então a sonda nem procura.

import Foundation

extension Sonda {
    static func pastaGuardada(_ pasta: String, casa: String) -> Bool {
        ["Library", "Music", "Movies", "Pictures"].contains {
            pasta == casa + "/" + $0 || pasta.hasPrefix(casa + "/" + $0 + "/")
        }
    }
}
