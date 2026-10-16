import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

/// O que os botões do painel pedem à `Barra`.
struct Acoes {
    var abrirPorta: (Porta) -> Void = { _ in }
    var encerrarPorta: (Porta) -> Void = { _ in }
    var fechar: (Maquina.Gasto) -> Void = { _ in }
    var atualizar: () -> Void = {}
    var virarTudo: () -> Void = {}
    var virarAbrirAoLigar: () -> Void = {}
    var virarMemoriaNaBarra: () -> Void = {}
    var virarFavorita: (Int) -> Void = { _ in }
    var outraFavorita: () -> Void = {}
    var copiar: () -> Void = {}
    var monitor: () -> Void = {}
    /// A engrenagem abre um menu nativo (o `Menu` do SwiftUI não se desenha fora da tela, e a conferência é por imagem).
    var ajustes: () -> Void = {}
    var sair: () -> Void = {}
    var redimensionar: (CGSize) -> Void = { _ in }
    var limpar: (String) -> Void = { _ in }
    var limparTudo: () -> Void = {}
    /// "Começar", nas boas-vindas da primeira abertura.
    var terminarBoasVindas: () -> Void = {}
}
