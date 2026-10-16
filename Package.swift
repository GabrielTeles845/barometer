// swift-tools-version:6.0
// Barometer: a biblioteca (BarometerKit) tem o app inteiro, separado por assunto em pastas; o executável só dá a
// partida; os testes usam a biblioteca direto.

import PackageDescription

let package = Package(
    name: "Barometer",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "barometer", targets: ["Barometer"]),
    ],
    targets: [
        .target(
            name: "BarometerKit",
            // O app ainda segue as regras de concorrência do Swift 5 (a passagem para o 6 é um trabalho à parte).
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                // A frequência da CPU (interface interna da Apple, sem cabeçalho público).
                .linkedLibrary("IOReport"),
            ]
        ),
        .executableTarget(name: "Barometer", dependencies: ["BarometerKit"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "BarometerKitTests", dependencies: ["BarometerKit"]),
        // Os testes ficam no modo 6: no modo 5, estas ferramentas não acham as macros do Swift Testing.
    ]
)
