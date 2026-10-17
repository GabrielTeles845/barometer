// As horas embaixo do gráfico.

import Foundation

enum EixoDoTempo {
    /// Os passos possíveis, em minutos: o menor que deixa caber o máximo de marcas.
    static let passos: [Double] = [1, 2, 5, 10, 15, 30, 60, 120]
    /// Marca colada numa ponta sai cortada ("1…" no lugar de "12:00", 17/10): fica de fora a que cai nos 12% de cada
    /// ponta, onde metade da hora escrita não cabe.
    static let margem = 0.12

    /// Marcas em minutos redondos e nunca repetidas: o passo cresce com o intervalo (1, 2, 5, 10… minutos) para
    /// caberem até `maximo`. Com menos de 2 minutos de leitura, nenhuma (seriam a mesma hora repetida).
    static func marcas(de inicio: Date?, ate fim: Date?, maximo: Int = 4) -> [Date] {
        guard let inicio, let fim else { return [] }
        let minutos = fim.timeIntervalSince(inicio) / 60
        guard minutos >= 2 else { return [] }
        let passo = passos.first { minutos / $0 <= Double(maximo) } ?? passos.last!
        let segundos = passo * 60
        var marca = (inicio.timeIntervalSince1970 / segundos).rounded(.up) * segundos
        var marcas: [Date] = []
        let folga = fim.timeIntervalSince(inicio) * margem
        while marca <= fim.timeIntervalSince1970 {
            if marca >= inicio.timeIntervalSince1970 + folga && marca <= fim.timeIntervalSince1970 - folga {
                marcas.append(Date(timeIntervalSince1970: marca))
            }
            marca += segundos
        }
        return marcas
    }
}
