// Cartão que pede mais largura do que o painel tem alarga o painel e corta as duas bordas (18/10: o "esquentando" da
// aba CPU empurrava o "CPU" do título para fora). Aqui cada caso difícil é medido na largura de verdade.

import AppKit
import SwiftUI
import Testing
@testable import BarometerKit

@MainActor
@Suite("Largura", .serialized)
struct LarguraTests {
    /// 360 do painel, menos 14 de margem de cada lado.
    static let largura: CGFloat = 332

    private func largura<V: View>(de view: V) -> CGFloat {
        NSHostingController(rootView: view).sizeThatFits(in: CGSize(width: Self.largura, height: 2000)).width
    }

    @Test("O cartão da CPU cabe no painel, com o Mac esquentando, em todos os idiomas",
          arguments: [Idioma.pt, .en, .es])
    func cartaoDaCPUCabe(idioma: Idioma) {
        Idioma.forcado = idioma
        defer { Idioma.forcado = nil }
        for termico in [ProcessInfo.ThermalState.nominal, .fair, .serious, .critical] {
            var cpu = CPUDetalhada()
            cpu.nucleos = (0..<6).map { Nucleo(eficiencia: $0 < 4, uso: 0.9) } + (0..<12).map { _ in
                Nucleo(eficiencia: false, uso: 0.9) }
            cpu.ghzE = 2.75; cpu.ghzP = 4.06
            cpu.usuario = 0.63; cpu.sistema = 0.35; cpu.carga = (117.4, 0, 0)
            cpu.ligadoDesde = Date().addingTimeInterval(-(23 * 86_400 + 23 * 3600))
            cpu.termico = termico
            let medida = largura(de: CartaoDaCPU(cpu: cpu))
            #expect(medida <= Self.largura, "\(idioma) \(termico.rawValue): \(medida) pt")
        }
    }
}
