import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary

public final class KanaKanjiAdapter {
    private let converter: KanaKanjiConverter
    private let zenzaiWeightURL: URL?
    private let supportURL: URL
    public let coldStartMs: Double

    public init(zenzaiWeightURL: URL? = nil, supportDirectoryURL: URL? = nil) {
        self.zenzaiWeightURL = zenzaiWeightURL
        self.supportURL = supportDirectoryURL
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("KeyboardCore", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.supportURL, withIntermediateDirectories: true)

        var localConverter: KanaKanjiConverter?
        let start = DispatchTime.now().uptimeNanoseconds
        localConverter = KanaKanjiConverter.withDefaultDictionary()
        let end = DispatchTime.now().uptimeNanoseconds
        self.coldStartMs = Double(end - start) / 1_000_000
        self.converter = localConverter!
    }

    public func convert(_ input: AdapterInput) -> AdapterOutput {
        var composingText = ComposingText()
        composingText.insertAtCursorPosition(input.kana, inputStyle: .direct)

        let zenzaiMode: ConvertRequestOptions.ZenzaiMode
        if let zenzaiWeightURL, input.conversionMode == .zenzaiV3 {
            zenzaiMode = .on(
                weight: zenzaiWeightURL,
                inferenceLimit: 5,
                requestRichCandidates: false,
                personalizationMode: nil,
                versionDependentMode: .v3(.init(leftSideContext: input.contextBefore))
            )
        } else {
            zenzaiMode = .off
        }

        var resultCandidates: [String] = []
        let start = DispatchTime.now().uptimeNanoseconds
        let results = converter.requestCandidates(composingText, options: .init(
            N_best: input.maxCandidates,
            requireJapanesePrediction: false,
            requireEnglishPrediction: false,
            keyboardLanguage: .ja_JP,
            englishCandidateInRoman2KanaInput: true,
            fullWidthRomanCandidate: false,
            halfWidthKanaCandidate: false,
            learningType: .nothing,
            maxMemoryCount: 0,
            shouldResetMemory: false,
            memoryDirectoryURL: supportURL,
            sharedContainerURL: supportURL,
            textReplacer: .withDefaultEmojiDictionary(),
            specialCandidateProviders: KanaKanjiConverter.defaultSpecialCandidateProviders,
            zenzaiMode: zenzaiMode,
            metadata: .init(versionString: "KeyboardCore/0.1")
        ))
        resultCandidates = Array(results.mainResults.prefix(input.maxCandidates).map(\.text))
        let end = DispatchTime.now().uptimeNanoseconds
        let requestLatencyMs = Double(end - start) / 1_000_000

        return AdapterOutput(
            input: input,
            mainCandidate: resultCandidates.first ?? input.kana,
            candidates: resultCandidates,
            segments: [],
            coldStartMs: coldStartMs,
            requestLatencyMs: requestLatencyMs,
            contextPassed: input.contextBefore
        )
    }
}
