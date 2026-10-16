import AppKit
import Combine
import IOKit
import ServiceManagement
import SwiftUI

/// Um aplicativo aberto pelo Finder ou pelo login **não herda o seu PATH**: ele
/// recebe `/usr/bin:/bin:/usr/sbin:/sbin` e nada mais. Então nada de chamar por
/// nome — cada ferramenta é procurada nos lugares onde ela realmente mora.
enum Ferramenta {
    static let lsof = achar(["/usr/sbin/lsof", "/usr/bin/lsof"])
    static let ps = achar(["/bin/ps"])
    static let docker = achar(["/usr/local/bin/docker",
                               "/opt/homebrew/bin/docker",
                               NSHomeDirectory() + "/.docker/bin/docker"])

    private static func achar(_ candidatos: [String]) -> String? {
        candidatos.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
