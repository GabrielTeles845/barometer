// Uma opção de ligar e desligar: título, uma linha explicando e o interruptor, num cartão.

import SwiftUI

struct LinhaDeInterruptor: View {
    let titulo: String
    let explicacao: String
    let ligado: Bool
    let virar: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t(titulo)).font(.system(size: 12)).foregroundStyle(Tinta.texto)
                Text(t(explicacao)).font(.system(size: 10.5)).foregroundStyle(Tinta.fraco)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Interruptor(ligado: ligado, virar: virar)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9).fill(Tinta.cartao))
    }
}
