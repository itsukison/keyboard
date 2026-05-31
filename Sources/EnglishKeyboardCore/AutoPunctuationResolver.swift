import Foundation

public enum AutoPunctuationLanguage: Equatable, Sendable {
    case english
    case japanese
}

public struct AutoPunctuationSet: Equatable, Sendable {
    public let language: AutoPunctuationLanguage
    public let comma: String
    public let period: String
    public let questionMark: String
    public let exclamationMark: String

    public static let english = AutoPunctuationSet(
        language: .english,
        comma: ",",
        period: ".",
        questionMark: "?",
        exclamationMark: "!"
    )

    public static let japanese = AutoPunctuationSet(
        language: .japanese,
        comma: "、",
        period: "。",
        questionMark: "？",
        exclamationMark: "！"
    )
}

public enum AutoPunctuationResolver {
    public static func punctuationSet(
        beforeInput context: String,
        classifier: BilingualLanguageClassifier = .init()
    ) -> AutoPunctuationSet {
        let trimmed = context.trimmingTrailingWhitespace()
        guard let last = trimmed.last else { return .english }
        if last.hasJapaneseTextScalar || last.isJapanesePunctuation {
            return .japanese
        }

        let token = BilingualComposer.trailingConvertibleToken(in: trimmed)
        guard !token.isEmpty else { return .english }

        let contextBeforeToken = String(trimmed.dropLast(token.count))
        let spans = classifier.spans(in: token, contextBefore: contextBeforeToken)
        return spans.last?.language == .japanese ? .japanese : .english
    }
}

private extension String {
    func trimmingTrailingWhitespace() -> String {
        var end = endIndex
        while end > startIndex {
            let previous = index(before: end)
            guard self[previous].isWhitespace else { break }
            end = previous
        }
        return String(self[..<end])
    }
}

private extension Character {
    var hasJapaneseTextScalar: Bool {
        unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(scalar.value) || (0x4E00...0x9FFF).contains(scalar.value)
        }
    }

    var isJapanesePunctuation: Bool {
        guard !unicodeScalars.isEmpty else { return false }
        return unicodeScalars.allSatisfy { scalar in
            (0x3000...0x303F).contains(scalar.value) ||
                (0xFF01...0xFF0F).contains(scalar.value) ||
                (0xFF1A...0xFF20).contains(scalar.value) ||
                (0xFF3B...0xFF40).contains(scalar.value) ||
                (0xFF5B...0xFF65).contains(scalar.value)
        }
    }
}
