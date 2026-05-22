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
        .library(name: "EnglishKeyboardCore", targets: ["EnglishKeyboardCore"]),
        .library(name: "KeyboardPreferences", targets: ["KeyboardPreferences"]),
        .executable(name: "KanaKanjiHarness", targets: ["KanaKanjiHarness"]),
        .executable(name: "TrigramBuilder", targets: ["TrigramBuilder"]),
        .executable(name: "TrigramProbe", targets: ["TrigramProbe"]),
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
                "KeyboardPreferences",
                .product(
                    name: "KanaKanjiConverterModuleWithDefaultDictionary",
                    package: "AzooKeyKanaKanjiConverter"
                ),
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        .executableTarget(
            name: "TrigramBuilder",
            path: "tools/build-trigrams",
            exclude: ["data"]
        ),
        .target(
            name: "KeyboardPreferences"
        ),
        .target(
            name: "EnglishKeyboardCore",
            dependencies: [
                "KeyboardCore",
                "KeyboardPreferences",
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
            name: "TrigramProbe",
            dependencies: ["KeyboardCore"],
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
        .testTarget(
            name: "KeyboardCoreTests",
            dependencies: [
                "KeyboardCore",
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        .testTarget(
            name: "EnglishKeyboardCoreTests",
            dependencies: [
                "EnglishKeyboardCore",
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        .testTarget(
            name: "KeyboardPreferencesTests",
            dependencies: [
                "KeyboardPreferences",
            ]
        ),
    ]
)
