// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "KeyboardConversionHarness",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .executable(name: "KanaKanjiHarness", targets: ["KanaKanjiHarness"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/azooKey/AzooKeyKanaKanjiConverter",
            .upToNextMinor(from: "0.11.1")
        ),
    ],
    targets: [
        .executableTarget(
            name: "KanaKanjiHarness",
            dependencies: [
                .product(
                    name: "KanaKanjiConverterModuleWithDefaultDictionary",
                    package: "AzooKeyKanaKanjiConverter"
                ),
            ]
        ),
    ]
)
