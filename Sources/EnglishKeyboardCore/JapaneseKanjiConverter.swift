import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary

public struct JapaneseConversionInput: Equatable, Sendable {
    public let kana: String
    public let contextBefore: String
    public let maxCandidates: Int

    public init(kana: String, contextBefore: String = "", maxCandidates: Int = 8) {
        self.kana = kana
        self.contextBefore = contextBefore
        self.maxCandidates = maxCandidates
    }
}

public struct JapaneseConversionResult: Equatable, Sendable {
    public let input: JapaneseConversionInput
    public let candidates: [String]

    public init(input: JapaneseConversionInput, candidates: [String]) {
        self.input = input
        self.candidates = candidates
    }

    public var mainCandidate: String {
        candidates.first ?? input.kana
    }
}

public protocol JapaneseCandidateConverting: AnyObject {
    func convert(_ input: JapaneseConversionInput) -> JapaneseConversionResult
}

public final class AzooKeyJapaneseConverter: JapaneseCandidateConverting {
    private let converter: KanaKanjiConverter
    private let supportURL: URL

    public init(supportDirectoryURL: URL? = nil) {
        self.supportURL = supportDirectoryURL
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("EnglishKeyboardCore", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        self.converter = KanaKanjiConverter.withDefaultDictionary()
    }

    public func convert(_ input: JapaneseConversionInput) -> JapaneseConversionResult {
        var composingText = ComposingText()
        composingText.insertAtCursorPosition(input.kana, inputStyle: .direct)

        let results = converter.requestCandidates(composingText, options: .init(
            N_best: input.maxCandidates,
            needTypoCorrection: false,
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
            zenzaiMode: .off,
            metadata: .init(versionString: "EnglishKeyboardCore/0.1")
        ))
        let candidates = Array(results.mainResults.prefix(input.maxCandidates).map(\.text))
        return JapaneseConversionResult(input: input, candidates: candidates.isEmpty ? [input.kana] : candidates)
    }
}
