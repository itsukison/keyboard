import Foundation
import KeyboardCore

public enum BilingualLanguage: Equatable, Sendable {
    case english
    case japanese
}

public struct BilingualSpan: Equatable, Sendable {
    public let raw: String
    public let language: BilingualLanguage
    public let kana: String?

    public init(raw: String, language: BilingualLanguage, kana: String?) {
        self.raw = raw
        self.language = language
        self.kana = kana
    }
}

public struct BilingualLanguageClassifier: Sendable {
    public var englishWords: Set<String>
    private let detector: BilingualSpanDetector
    private static let maxContextWords = 2
    private static let maxContextScanLength = 120
    private static let maxContextWordLength = 32
    private static let protectedStandaloneEnglish: Set<String> = [
        "be", "he", "me", "we",
    ]

    public init(
        englishWords: Set<String> = Self.defaultEnglishWords,
        embeddedEnglishMinimumWordLength: Int = 4
    ) {
        self.englishWords = englishWords
        self.detector = BilingualSpanDetector(
            englishWords: englishWords,
            embeddedEnglishSplitPolicy: embeddedEnglishMinimumWordLength >= 5 ? .japaneseHeavy : .balanced
        )
    }

    public func spans(in token: String, contextBefore: String = "") -> [BilingualSpan] {
        let clean = token.lowercased()
        if englishWords.contains(clean),
           Self.hasPostJapaneseEnglishIsland(before: contextBefore) {
            return [BilingualSpan(raw: token, language: .english, kana: nil)]
        }

        let prior = Self.documentPrior(from: contextBefore)
        guard let window = Self.contextWindow(before: contextBefore, activeToken: token) else {
            return Self.bilingualSpans(from: detector.detect(token, documentPrior: prior))
        }

        let windowSpans = detector.detect(window, documentPrior: prior)
        let active = Self.activeSpans(from: windowSpans, activeTokenLength: token.count)
        guard !active.isEmpty else {
            return Self.bilingualSpans(from: detector.detect(token, documentPrior: prior))
        }

        if active.count == 1,
           active[0].language == .japanese,
           Self.protectedStandaloneEnglish.contains(token.lowercased()),
           englishWords.contains(token.lowercased()) {
            return [BilingualSpan(raw: token, language: .english, kana: nil)]
        }
        return active
    }

    public func likelyLanguage(of token: String, contextBefore: String = "") -> BilingualLanguage {
        let spans = spans(in: token, contextBefore: contextBefore)
        let japaneseCount = spans.filter { $0.language == .japanese }.map(\.raw.count).reduce(0, +)
        let englishCount = spans.filter { $0.language == .english }.map(\.raw.count).reduce(0, +)
        return japaneseCount > englishCount ? .japanese : .english
    }

    private static func contextWindow(before context: String, activeToken token: String) -> String? {
        guard !token.isEmpty else { return nil }
        let words = trailingConvertibleWords(in: context, maxWords: maxContextWords)
        guard !words.isEmpty else { return nil }
        return (words + [token]).joined(separator: " ")
    }

    private static func trailingConvertibleWords(in context: String, maxWords: Int) -> [String] {
        guard maxWords > 0, !context.isEmpty else { return [] }
        let suffix = context.suffix(maxContextScanLength)
        let parts = suffix.split(whereSeparator: \.isWhitespace)
        var words: [String] = []

        for part in parts.reversed() {
            let word = String(part)
            guard word.count <= maxContextWordLength else { break }
            guard word.allSatisfy(\.isConvertibleContextCharacter) else { break }
            words.append(word)
            if words.count == maxWords { break }
        }
        return words.reversed()
    }

    private static func activeSpans(
        from spans: [DetectedSpan],
        activeTokenLength: Int
    ) -> [BilingualSpan] {
        guard activeTokenLength > 0 else { return [] }
        var remaining = activeTokenLength
        var result: [BilingualSpan] = []

        for span in spans.reversed() {
            guard remaining > 0 else { break }
            let rawCount = span.raw.count
            if rawCount <= remaining {
                result.append(bilingualSpan(from: span))
                remaining -= rawCount
                continue
            }

            let suffix = String(span.raw.suffix(remaining))
            result.append(BilingualSpan(
                raw: suffix,
                language: span.kind == .japanese ? .japanese : .english,
                kana: span.kind == .japanese ? Romaji.toKana(suffix) : nil
            ))
            remaining = 0
        }

        guard remaining == 0 else { return [] }
        return result.reversed()
    }

    private static func bilingualSpans(from spans: [DetectedSpan]) -> [BilingualSpan] {
        spans.map(bilingualSpan(from:))
    }

    private static func bilingualSpan(from span: DetectedSpan) -> BilingualSpan {
        BilingualSpan(
            raw: span.raw,
            language: span.kind == .japanese ? .japanese : .english,
            kana: span.kana
        )
    }

    private static func documentPrior(from context: String) -> LanguagePrior {
        guard !context.isEmpty else {
            return LanguagePrior(jaBias: 0, enBias: 0.9)
        }
        let suffix = context.suffix(80)
        let japaneseScalars = suffix.unicodeScalars.filter {
            (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value)
        }.count
        let asciiLetters = suffix.unicodeScalars.filter {
            (65...90).contains($0.value) || (97...122).contains($0.value)
        }.count

        if japaneseScalars >= 2 {
            return LanguagePrior(jaBias: 0.9, enBias: 0)
        }
        if asciiLetters >= 8 {
            return LanguagePrior(jaBias: 0, enBias: 0.9)
        }
        return .neutral
    }

    private static func hasPostJapaneseEnglishIsland(before context: String) -> Bool {
        guard let lastJapaneseIndex = context.indices.last(where: { context[$0].hasJapaneseScalar }) else {
            return false
        }
        let afterJapanese = context.index(after: lastJapaneseIndex)
        guard afterJapanese < context.endIndex else { return false }

        let suffix = context[afterJapanese...]
        guard suffix.first?.isWhitespace == true else { return false }
        return suffix.allSatisfy { $0.isWhitespace || $0.isConvertibleContextCharacter }
    }

    public static let defaultEnglishWords: Set<String> = BilingualSpanDetector.defaultEnglishWords
}

private extension Character {
    var hasJapaneseScalar: Bool {
        unicodeScalars.contains {
            (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value)
        }
    }

    var isConvertibleContextCharacter: Bool {
        guard unicodeScalars.count == 1, let scalar = unicodeScalars.first else { return false }
        let value = scalar.value
        let isLetter = (65...90).contains(value) || (97...122).contains(value)
        let isNumber = (48...57).contains(value)
        return isLetter || isNumber || self == "'" || self == "-"
    }
}
