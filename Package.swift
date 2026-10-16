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
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                // A frequência da CPU (interface interna da Apple, sem cabeçalho público).
                .linkedLibrary("IOReport"),
            ]
        ),
        .executableTarget(name: "Barometer", dependencies: ["BarometerKit"]),
        .testTarget(name: "BarometerKitTests", dependencies: ["BarometerKit"]),
    ],
    swiftLanguageModes: [.v5]
)
