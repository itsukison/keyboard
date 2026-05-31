import Foundation
import KeyboardPreferences

public struct BilingualCommit: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case dictionary
        case japanese
    }

    public let rawToken: String
    public let replacementText: String
    public let deleteCount: Int
    public let candidates: [String]
    public let spans: [BilingualSpan]
    public let kind: Kind

    public init(
        rawToken: String,
        replacementText: String,
        deleteCount: Int,
        candidates: [String],
        spans: [BilingualSpan],
        kind: Kind = .japanese
    ) {
        self.rawToken = rawToken
        self.replacementText = replacementText
        self.deleteCount = deleteCount
        self.candidates = candidates
        self.spans = spans
        self.kind = kind
    }
}

public struct BilingualSuggestion: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case dictionary
        case keepRaw
        case japanese
    }

    public let rawToken: String
    public let replacementText: String
    public let deleteCount: Int
    public let kind: Kind

    public init(
        rawToken: String,
        replacementText: String,
        deleteCount: Int,
        kind: Kind = .japanese
    ) {
        self.rawToken = rawToken
        self.replacementText = replacementText
        self.deleteCount = deleteCount
        self.kind = kind
    }
}

public struct BilingualSuggestionSet: Equatable, Sendable {
    public let keepRaw: BilingualSuggestion?
    public let japanese: [BilingualSuggestion]

    public init(keepRaw: BilingualSuggestion?, japanese: [BilingualSuggestion]) {
        self.keepRaw = keepRaw
        self.japanese = japanese
    }
}

public final class BilingualComposer {
    private let classifier: BilingualLanguageClassifier
    private let displayClassifier: BilingualLanguageClassifier
    private let converter: JapaneseCandidateConverting
    private let dictionaryEntries: @Sendable () -> [UserDictionaryEntry]
    private let conversionPreferenceEntries: @Sendable () -> [ConversionPreferenceEntry]

    public init(
        classifier: BilingualLanguageClassifier = .init(),
        converter: JapaneseCandidateConverting,
        dictionaryEntries: @escaping @Sendable () -> [UserDictionaryEntry] = {
            UserDictionaryStore.readEntries()
        },
        conversionPreferenceEntries: @escaping @Sendable () -> [ConversionPreferenceEntry] = {
            ConversionPreferenceStore.readEntries()
        }
    ) {
        self.classifier = classifier
        self.displayClassifier = BilingualLanguageClassifier(
            englishWords: classifier.englishWords,
            embeddedEnglishMinimumWordLength: 5
        )
        self.converter = converter
        self.dictionaryEntries = dictionaryEntries
        self.conversionPreferenceEntries = conversionPreferenceEntries
    }

    public func commitForSpace(beforeInput context: String) -> BilingualCommit? {
        let token = Self.trailingConvertibleToken(in: context)
        if let entry = dictionaryEntry(for: token) {
            return BilingualCommit(
                rawToken: token,
                replacementText: entry.replacementText,
                deleteCount: token.count,
                candidates: [entry.replacementText],
                spans: [],
                kind: .dictionary
            )
        }
        guard !prefersRawJapaneseToken(token) else { return nil }

        guard let analysis = analyze(beforeInput: context) else { return nil }
        guard analysis.primaryReplacement != analysis.rawToken else { return nil }
        return BilingualCommit(
            rawToken: analysis.rawToken,
            replacementText: analysis.primaryReplacement,
            deleteCount: analysis.rawToken.count,
            candidates: analysis.firstJapaneseCandidates,
            spans: analysis.spans
        )
    }

    public func keepRawSuggestion(beforeInput context: String) -> BilingualSuggestion? {
        suggestionSet(beforeInput: context).keepRaw
    }

    public func suggestions(beforeInput context: String) -> [BilingualSuggestion] {
        suggestionSet(beforeInput: context).japanese
    }

    public func suggestionSet(beforeInput context: String) -> BilingualSuggestionSet {
        let token = Self.trailingConvertibleToken(in: context)
        guard token.count >= 2 else {
            return BilingualSuggestionSet(keepRaw: nil, japanese: [])
        }
        let dictionaryEntry = dictionaryEntry(for: token)
        if dictionaryEntry == nil, prefersRawJapaneseToken(token) {
            return BilingualSuggestionSet(keepRaw: nil, japanese: [])
        }
        let analysis = analyze(beforeInput: context)
        guard dictionaryEntry != nil || analysis != nil else {
            return BilingualSuggestionSet(keepRaw: nil, japanese: [])
        }

        let rawToken = analysis?.rawToken ?? token
        var seen: Set<String> = []
        var suggestions: [BilingualSuggestion] = []

        if let dictionaryEntry {
            suggestions.append(BilingualSuggestion(
                rawToken: rawToken,
                replacementText: dictionaryEntry.replacementText,
                deleteCount: rawToken.count,
                kind: .dictionary
            ))
            seen.insert(dictionaryEntry.replacementText)
        }

        if let analysis {
            for candidate in analysis.firstJapaneseCandidates where !candidate.isEmpty {
                let replacement = analysis.replacement(firstJapaneseCandidate: candidate)
                guard replacement != rawToken else { continue }
                guard seen.insert(replacement).inserted else { continue }
                suggestions.append(BilingualSuggestion(
                    rawToken: rawToken,
                    replacementText: replacement,
                    deleteCount: rawToken.count,
                    kind: .japanese
                ))
                if suggestions.count >= 8 { break }
            }
        }

        let keepRaw: BilingualSuggestion?
        if analysis != nil, dictionaryEntry?.replacementText != rawToken {
            keepRaw = BilingualSuggestion(
                rawToken: rawToken,
                replacementText: rawToken,
                deleteCount: rawToken.count,
                kind: .keepRaw
            )
        } else {
            keepRaw = nil
        }
        return BilingualSuggestionSet(keepRaw: keepRaw, japanese: suggestions)
    }

    public func displayPreview(
        beforeInput context: String,
        displayMode: CompositionDisplayMode
    ) -> String? {
        Self.displayPreview(
            beforeInput: context,
            displayMode: displayMode,
            classifier: displayClassifier
        )
    }

    public static func displayPreview(
        beforeInput context: String,
        displayMode: CompositionDisplayMode,
        classifier: BilingualLanguageClassifier = .init(embeddedEnglishMinimumWordLength: 5)
    ) -> String? {
        guard displayMode.isJapaneseHeavy else { return nil }
        let token = Self.trailingConvertibleToken(in: context)
        guard !token.isEmpty else { return nil }

        let contextBeforeToken = String(context.dropLast(token.count))
        let spans = classifier.spans(in: token, contextBefore: contextBeforeToken)
        guard spans.contains(where: { $0.language == .japanese }) else { return nil }

        let preview = spans.reduce(into: "") { output, span in
            switch span.language {
            case .english:
                output += span.raw
            case .japanese:
                output += JapaneseRomaji.toLiveKana(span.raw)
            }
        }
        return preview == token ? nil : preview
    }

    public static func containsJapaneseSpan(
        beforeInput context: String,
        classifier: BilingualLanguageClassifier = .init()
    ) -> Bool {
        let token = Self.trailingConvertibleToken(in: context)
        guard token.count >= 2 else { return false }
        let contextBeforeToken = String(context.dropLast(token.count))
        return classifier
            .spans(in: token, contextBefore: contextBeforeToken)
            .contains { $0.language == .japanese }
    }

    public static func endsWithJapaneseText(_ text: String) -> Bool {
        for ch in text.reversed() {
            if ch.isWhitespace || ch.isJapaneseTrailingPunctuation {
                continue
            }
            return ch.hasJapaneseTextScalar
        }
        return false
    }

    private struct Analysis {
        let rawToken: String
        let spans: [BilingualSpan]
        let convertedSpans: [ConvertedSpan]
        let firstJapaneseIndex: Int
        let firstJapaneseCandidates: [String]

        var primaryReplacement: String {
            replacement(firstJapaneseCandidate: firstJapaneseCandidates.first)
        }

        func replacement(firstJapaneseCandidate: String?) -> String {
            var output = ""
            for index in convertedSpans.indices {
                let span = convertedSpans[index]
                if index == firstJapaneseIndex, let firstJapaneseCandidate {
                    output += firstJapaneseCandidate
                } else {
                    output += span.mainText
                }
            }
            return output
        }
    }

    private struct ConvertedSpan {
        let mainText: String
        let candidates: [String]
    }

    private func dictionaryEntry(for token: String) -> UserDictionaryEntry? {
        UserDictionaryStore.lookupEntry(for: token, in: dictionaryEntries())
    }

    private func prefersRawJapaneseToken(_ token: String) -> Bool {
        ConversionPreferenceStore.shouldPreferRaw(
            scope: .japanese,
            input: token,
            entries: conversionPreferenceEntries()
        )
    }

    private func analyze(beforeInput context: String) -> Analysis? {
        let token = Self.trailingConvertibleToken(in: context)
        guard token.count >= 2 else { return nil }

        let contextBeforeToken = String(context.dropLast(token.count))
        let spans = classifier.spans(in: token, contextBefore: contextBeforeToken)
        guard spans.contains(where: { $0.language == .japanese }) else { return nil }

        var convertedSpans: [ConvertedSpan] = []
        var firstJapaneseIndex: Int?
        var runningJapaneseContext = Self.japaneseOnlySuffix(from: contextBeforeToken)
        let preferenceEntries = conversionPreferenceEntries()

        for span in spans {
            switch span.language {
            case .english:
                convertedSpans.append(ConvertedSpan(mainText: span.raw, candidates: []))
            case .japanese:
                guard let kana = span.kana, !kana.isEmpty else { return nil }
                let result = converter.convert(.init(
                    kana: kana,
                    contextBefore: runningJapaneseContext,
                    maxCandidates: 8
                ))
                convertedSpans.append(ConvertedSpan(mainText: result.mainCandidate, candidates: result.candidates))
                runningJapaneseContext += result.mainCandidate
                if firstJapaneseIndex == nil {
                    firstJapaneseIndex = convertedSpans.count - 1
                }
            }
        }

        guard let firstJapaneseIndex else { return nil }
        let firstJapaneseCandidates = Self.rerankedFirstJapaneseCandidates(
            rawToken: token,
            convertedSpans: convertedSpans,
            firstJapaneseIndex: firstJapaneseIndex,
            preferenceEntries: preferenceEntries
        )
        return Analysis(
            rawToken: token,
            spans: spans,
            convertedSpans: convertedSpans,
            firstJapaneseIndex: firstJapaneseIndex,
            firstJapaneseCandidates: firstJapaneseCandidates
        )
    }

    private static func rerankedFirstJapaneseCandidates(
        rawToken: String,
        convertedSpans: [ConvertedSpan],
        firstJapaneseIndex: Int,
        preferenceEntries: [ConversionPreferenceEntry]
    ) -> [String] {
        let candidates = convertedSpans[firstJapaneseIndex].candidates
        guard candidates.count > 1 else { return candidates }

        var replacementToCandidate: [String: String] = [:]
        var replacements: [String] = []
        for candidate in candidates {
            let replacement = replacement(
                convertedSpans: convertedSpans,
                firstJapaneseIndex: firstJapaneseIndex,
                firstJapaneseCandidate: candidate
            )
            guard replacementToCandidate[replacement] == nil else { continue }
            replacementToCandidate[replacement] = candidate
            replacements.append(replacement)
        }

        let rankedReplacements = ConversionPreferenceStore.rerank(
            scope: .japanese,
            input: rawToken,
            candidates: replacements,
            entries: preferenceEntries
        )
        return rankedReplacements.compactMap { replacementToCandidate[$0] }
    }

    private static func replacement(
        convertedSpans: [ConvertedSpan],
        firstJapaneseIndex: Int,
        firstJapaneseCandidate: String
    ) -> String {
        var output = ""
        for index in convertedSpans.indices {
            if index == firstJapaneseIndex {
                output += firstJapaneseCandidate
            } else {
                output += convertedSpans[index].mainText
            }
        }
        return output
    }

    public static func trailingConvertibleToken(in text: String) -> String {
        var collected: [Character] = []
        for ch in text.reversed() {
            guard ch.isConvertibleTokenCharacter else { break }
            collected.append(ch)
        }
        return String(collected.reversed())
    }

    private static func japaneseOnlySuffix(from text: String) -> String {
        let suffix = text.suffix(80)
        return String(suffix.filter { ch in
            ch.unicodeScalars.contains { scalar in
                (0x3040...0x30FF).contains(scalar.value) || (0x4E00...0x9FFF).contains(scalar.value)
            }
        })
    }
}

private extension Character {
    var hasJapaneseTextScalar: Bool {
        unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(scalar.value) || (0x4E00...0x9FFF).contains(scalar.value)
        }
    }

    var isJapaneseTrailingPunctuation: Bool {
        guard !unicodeScalars.isEmpty else { return false }
        return unicodeScalars.allSatisfy { scalar in
            (0x3000...0x303F).contains(scalar.value) ||
                (0xFF01...0xFF0F).contains(scalar.value) ||
                (0xFF1A...0xFF20).contains(scalar.value) ||
                (0xFF3B...0xFF40).contains(scalar.value) ||
                (0xFF5B...0xFF65).contains(scalar.value)
        }
    }

    var isConvertibleTokenCharacter: Bool {
        guard unicodeScalars.count == 1, let scalar = unicodeScalars.first else { return false }
        let value = scalar.value
        let isLetter = (65...90).contains(value) || (97...122).contains(value)
        let isNumber = (48...57).contains(value)
        return isLetter || isNumber || self == "'" || self == "-"
    }
}
