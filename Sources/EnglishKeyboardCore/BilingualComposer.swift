import Foundation

public struct BilingualCommit: Equatable, Sendable {
    public let rawToken: String
    public let replacementText: String
    public let deleteCount: Int
    public let candidates: [String]
    public let spans: [BilingualSpan]

    public init(
        rawToken: String,
        replacementText: String,
        deleteCount: Int,
        candidates: [String],
        spans: [BilingualSpan]
    ) {
        self.rawToken = rawToken
        self.replacementText = replacementText
        self.deleteCount = deleteCount
        self.candidates = candidates
        self.spans = spans
    }
}

public struct BilingualSuggestion: Equatable, Sendable {
    public let rawToken: String
    public let replacementText: String
    public let deleteCount: Int

    public init(rawToken: String, replacementText: String, deleteCount: Int) {
        self.rawToken = rawToken
        self.replacementText = replacementText
        self.deleteCount = deleteCount
    }
}

public final class BilingualComposer {
    private let classifier: BilingualLanguageClassifier
    private let converter: JapaneseCandidateConverting

    public init(
        classifier: BilingualLanguageClassifier = .init(),
        converter: JapaneseCandidateConverting
    ) {
        self.classifier = classifier
        self.converter = converter
    }

    public func commitForSpace(beforeInput context: String) -> BilingualCommit? {
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

    public func suggestions(beforeInput context: String) -> [BilingualSuggestion] {
        guard let analysis = analyze(beforeInput: context) else { return [] }
        var seen: Set<String> = []
        var suggestions: [BilingualSuggestion] = []

        for candidate in analysis.firstJapaneseCandidates where !candidate.isEmpty {
            let replacement = analysis.replacement(firstJapaneseCandidate: candidate)
            guard seen.insert(replacement).inserted else { continue }
            suggestions.append(BilingualSuggestion(
                rawToken: analysis.rawToken,
                replacementText: replacement,
                deleteCount: analysis.rawToken.count
            ))
            if suggestions.count >= 8 { break }
        }

        return suggestions
    }

    private struct Analysis {
        let rawToken: String
        let spans: [BilingualSpan]
        let convertedSpans: [ConvertedSpan]
        let firstJapaneseIndex: Int

        var firstJapaneseCandidates: [String] {
            convertedSpans[firstJapaneseIndex].candidates
        }

        var primaryReplacement: String {
            replacement(firstJapaneseCandidate: nil)
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

    private func analyze(beforeInput context: String) -> Analysis? {
        let token = Self.trailingConvertibleToken(in: context)
        guard token.count >= 2 else { return nil }

        let contextBeforeToken = String(context.dropLast(token.count))
        let spans = classifier.spans(in: token, contextBefore: contextBeforeToken)
        guard spans.contains(where: { $0.language == .japanese }) else { return nil }

        var convertedSpans: [ConvertedSpan] = []
        var firstJapaneseIndex: Int?
        var runningJapaneseContext = Self.japaneseOnlySuffix(from: contextBeforeToken)

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
        return Analysis(
            rawToken: token,
            spans: spans,
            convertedSpans: convertedSpans,
            firstJapaneseIndex: firstJapaneseIndex
        )
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
    var isConvertibleTokenCharacter: Bool {
        guard unicodeScalars.count == 1, let scalar = unicodeScalars.first else { return false }
        let value = scalar.value
        let isLetter = (65...90).contains(value) || (97...122).contains(value)
        let isNumber = (48...57).contains(value)
        return isLetter || isNumber || self == "'" || self == "-"
    }
}
