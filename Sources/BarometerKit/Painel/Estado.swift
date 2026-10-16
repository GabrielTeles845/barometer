import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

final class Estado: ObservableObject {
    @Published var portas: [Porta] = []
    @Published var ocultas: [(numero: Int, nome: String)] = []
    @Published var pontos: [Historico.Ponto] = []
    @Published var memoria: Maquina.Memoria?
    @Published var pressao = 1
    @Published var swap: Double = 0
    @Published var cpu: Double?
    @Published var temperatura = Sensores.Leitura(chip: nil, chipMaximo: nil, ssd: nil, bateria: nil)
    @Published var gastos: [Maquina.Gasto] = []
    @Published var gastosCPU: [Maquina.Gasto] = []
    @Published var cpuDetalhada: CPUDetalhada?
    @Published var gpu: GPU?
    @Published var disco: Disco?
    @Published var bateria: Bateria?
    /// "MacBook Pro · M3 Pro · 18 GB · macOS 27.0.1", embaixo do título do Geral.
    @Published var sobreMac: String?
    @Published var limpeza: [ItemDeLimpeza] = []
    /// O que dá para fechar (aba Limpeza): apps parados e servidores ligados há muito tempo.
    @Published var sugestoes: [Sugestao] = []
    @Published var medindoLimpeza = false
    /// Quanto a última limpeza liberou, para o aviso no topo da aba.
    @Published var liberado: Double?
    @Published var abaAtual: Aba = .geral
    @Published var editandoGeral = false
    /// Desenhando o painel como imagem (`--retrato`): o que não se desenha fora da tela fica de fora.
    var paraImagem = false
    /// Na foto de vidro: onde o painel fica sobre o papel de parede, para o desfoque de dentro casar com o de fora.
    var deslocamentoNaFoto: CGSize = .zero
    /// O cartão que está sendo arrastado no editor do Geral.
    @Published var arrastando: String?
    /// Os cartões do Geral, na ordem escolhida, cada um ligado ou não. Gravados a cada mudança.
    @Published var geral: [ItemGeral] = Pref.geral { didSet { Pref.geral = geral } }
    /// O que aparece na barra de menus, na ordem.
    @Published var naBarra: [ItemDaBarra] = Pref.naBarra { didSet { if !paraImagem { Pref.naBarra = naBarra }; aoMudarABarra?() } }
    var aoMudarABarra: (() -> Void)?
    /// Para a animação de abrir: o painel nasce um pouco menor e transparente e cresce até o tamanho.
    @Published var apareceu = true
    @Published var abaProcessos = 0
    @Published var favoritas: [Int] = []
    @Published var mostrarTudo = false
    @Published var abrirAoLigar = false
    @Published var memoriaNaBarra = true
    // O que o mouse está tocando e a aba do gráfico. Ficam aqui, e não em `@State`: as ferramentas de linha de
    // comando da Apple não trazem o plug-in de macro que o `@State` usa nesta versão do SwiftUI.
    @Published var sobre: String?
    @Published var sobreX: String?
    @Published var aba = 0
    /// Na aba Aparência: 0 = estilos prontos, 1 = do meu jeito.
    @Published var abaAparencia = 0
    /// As boas-vindas da primeira abertura (escolher um estilo).
    @Published var boasVindas = false
    /// O editor do estilo personalizado aberto, no lugar da grade de estilos.
    @Published var editandoCores = false
    /// Quantos processos a lista mostra.
    @Published var quantosProcessos = Pref.quantosProcessos { didSet { if !paraImagem { Pref.quantosProcessos = quantosProcessos } } }
    /// Fundo, transparência, cores, cantos e animações (aba Aparência). Vale na hora e fica gravado.
    @Published var aparencia: Aparencia = Aparencia.atual {
        didSet {
            Aparencia.atual = aparencia
            if !paraImagem { Pref.aparencia = aparencia }
            if aparencia.iconeColorido != oldValue.iconeColorido || aparencia.chaveDasCores != oldValue.chaveDasCores { aoMudarABarra?() }
        }
    }
}
