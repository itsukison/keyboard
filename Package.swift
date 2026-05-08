// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "KeyboardConversionHarness",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "KeyboardCore", targets: ["KeyboardCore"]),
        .executable(name: "KanaKanjiHarness", targets: ["KanaKanjiHarness"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/azooKey/AzooKeyKanaKanjiConverter",
            .upToNextMinor(from: "0.11.1"),
            traits: ["Zenzai"]
        ),
    ],
    targets: [
        .target(
            name: "KeyboardCore",
            dependencies: [
                .product(
                    name: "KanaKanjiConverterModuleWithDefaultDictionary",
                    package: "AzooKeyKanaKanjiConverter"
                ),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        .executableTarget(
            name: "KanaKanjiHarness",
            dependencies: [
                "KeyboardCore",
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
    ]
)
