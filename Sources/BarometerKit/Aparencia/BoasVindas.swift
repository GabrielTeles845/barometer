// A primeira abertura: o painel abre sozinho, mostra os estilos prontos e o modo, e some com "Começar".
// Tudo continua na aba Aparência depois.

import SwiftUI

struct BoasVindas: View {
    @ObservedObject var estado: Estado
    let comecar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Boas-vindas ao Barometer")).font(.system(size: 17, weight: .semibold)).foregroundStyle(Tinta.texto)
                Text(t("Escolha um estilo para começar. Dá para mudar quando quiser, na aba Aparência."))
                    .font(.system(size: 11.5)).foregroundStyle(Tinta.apagado)
                    .fixedSize(horizontal: false, vertical: true)
            }
            GradeDeEstilos(estado: estado)
            VStack(alignment: .leading, spacing: 7) {
                Text(t("MODO")).font(.system(size: 9.5, weight: .semibold)).tracking(0.6).foregroundStyle(Tinta.fraco)
                Escolha(opcoes: Aparencia.Modo.allCases.map { ($0.nome, $0) }, atual: estado.aparencia.modo,
                        vidro: estado.aparencia.fundoReal != .solido && !estado.paraImagem) { estado.aparencia.modo = $0 }
            }
            Button(action: comecar) {
                Text(t("Começar")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Tinta.fundo)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Tinta.texto))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
