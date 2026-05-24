import Foundation

public enum NativeAutocapitalization: Sendable {
    case none
    case words
    case sentences
    case allCharacters
}

public enum NativeKeyboardContentKind: Sendable {
    case prose
    case url
    case email
    case numeric
    case phone
    case webSearch
}

public enum NativeKeyboardPolicy {
    public static func shouldAutoCapitalize(
        after context: String,
        mode: NativeAutocapitalization,
        contentKind: NativeKeyboardContentKind
    ) -> Bool {
        guard allowsAutomaticCapitalization(contentKind: contentKind) else { return false }

        switch mode {
        case .none:
            return false
        case .allCharacters:
            return true
        case .sentences:
            return isSentenceStart(after: context)
        case .words:
            return isWordStart(after: context)
        }
    }

    public static func allowsAutocorrection(
        autocorrectionEnabled: Bool,
        contentKind: NativeKeyboardContentKind
    ) -> Bool {
        guard autocorrectionEnabled else { return false }
        switch contentKind {
        case .prose, .webSearch:
            return true
        case .url, .email, .numeric, .phone:
            return false
        }
    }

    public static func allowsBilingualConversionSuggestions(
        contentKind: NativeKeyboardContentKind
    ) -> Bool {
        switch contentKind {
        case .prose, .webSearch, .url:
            return true
        case .email, .numeric, .phone:
            return false
        }
    }

    public static func shouldApplyDoubleSpacePeriod(
        beforeInput context: String,
        autocorrectionEnabled: Bool,
        contentKind: NativeKeyboardContentKind
    ) -> Bool {
        guard allowsAutocorrection(autocorrectionEnabled: autocorrectionEnabled, contentKind: contentKind) else {
            return false
        }
        guard context.hasSuffix(" ") else { return false }
        guard !context.hasSuffix("  ") else { return false }
        guard !context.hasSuffix("\n "), !context.hasSuffix("\r ") else { return false }

        let beforeSpace = context.dropLast()
        guard let previous = beforeSpace.last else { return false }
        guard previous.isASCIIEnglishLetter || previous.isNumber else { return false }

        let terminators: Set<Character> = [".", "!", "?"]
        return !terminators.contains(previous)
    }

    private static func allowsAutomaticCapitalization(contentKind: NativeKeyboardContentKind) -> Bool {
        switch contentKind {
        case .prose, .webSearch:
            return true
        case .url, .email, .numeric, .phone:
            return false
        }
    }

    private static func isSentenceStart(after context: String) -> Bool {
        if context.isEmpty { return true }
        let terminators: Set<Character> = [".", "!", "?"]
        for ch in context.reversed() {
            if ch == "\n" || ch == "\r" { return true }
            if ch.isWhitespace { continue }
            return terminators.contains(ch)
        }
        return true
    }

    private static func isWordStart(after context: String) -> Bool {
        guard let previous = context.last else { return true }
        return previous.isWhitespace || previous == "-" || previous == "/" || previous == "(" || previous == "["
    }
}

private extension Character {
    var isASCIIEnglishLetter: Bool {
        guard unicodeScalars.count == 1, let scalar = unicodeScalars.first else { return false }
        return (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
    }
}
