import EnglishKeyboardCore
import KeyboardKit
import UIKit

final class KeyboardViewController: KeyboardInputViewController {
    private let suggestions = EnglishSuggestionState()
    private let textChecker = UITextChecker()
    private var userLexiconEntries: Set<String> = []
    private lazy var bilingualComposer = BilingualComposer(converter: AzooKeyJapaneseConverter())
    private var cachedJapaneseSuggestionContext: String?
    private var cachedJapaneseSuggestionItems: [SuggestionItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        suggestions.onSelect = { [weak self] item in
            self?.applySuggestion(item)
        }
        requestSupplementaryLexicon { [weak self] lexicon in
            Task { @MainActor in
                self?.userLexiconEntries = Set(lexicon.entries.flatMap {
                    [$0.documentText.lowercased(), $0.userInput.lowercased()]
                })
                self?.refreshSuggestionsAfterInput()
            }
        }
    }

    override func viewWillSetupKeyboardKit() {
        setupKeyboardKit(for: .englishMVP) { [weak self] _ in
            guard let self else { return }
            self.services.actionHandler = EnglishActionHandler(controller: self)
        }
    }

    override func viewWillSetupKeyboardView() {
        let suggestions = suggestions
        setupKeyboardView { controller in
            EnglishKeyboardView(
                services: controller.services,
                suggestions: suggestions
            )
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshSuggestionsAfterInput()
    }

    func handleSpaceAction() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        if shouldApplyDoubleSpacePeriod(beforeInput: before) {
            textDocumentProxy.deleteBackward()
            textDocumentProxy.insertText(". ")
            refreshSuggestionsAfterInput()
            return
        }

        if currentTraits.allowsAutocorrection,
           textDocumentProxy.selectedText?.isEmpty ?? true,
           let japaneseCommit = bilingualComposer.commitForSpace(beforeInput: before) {
            deleteCharacters(japaneseCommit.deleteCount)
            textDocumentProxy.insertText(japaneseCommit.replacementText)
            textDocumentProxy.insertText(" ")
            suggestions.clear()
            return
        }

        if let topCorrection = topCorrectionForTrailingWord(in: before) {
            deleteTrailingWord(from: before)
            textDocumentProxy.insertText(topCorrection)
        }

        textDocumentProxy.insertText(" ")
        refreshSuggestionsAfterInput()
    }

    func refreshSuggestionsAfterInput() {
        guard currentTraits.allowsAutocorrection else {
            suggestions.clear()
            return
        }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        if let selected = textDocumentProxy.selectedText, !selected.isEmpty {
            suggestions.clear()
            return
        }

        let japaneseItems = japaneseSuggestionItems(beforeInput: before)
        if !japaneseItems.isEmpty {
            suggestions.items = japaneseItems
            return
        }

        let word = Self.trailingEnglishWord(in: before)
        guard !word.isEmpty else {
            suggestions.clear()
            return
        }
        suggestions.items = suggestionResult(for: word).displayCandidates.map {
            SuggestionItem(
                title: $0,
                replacementText: $0,
                deleteCount: word.count,
                kind: .english
            )
        }
    }

    private func applySuggestion(_ item: SuggestionItem) {
        switch item.kind {
        case .english:
            replaceTrailingWord(with: item.replacementText)
        case .japanese:
            replaceTrailingConvertibleToken(with: item.replacementText, deleteCount: item.deleteCount)
        }
    }

    private func replaceTrailingWord(with candidate: String) {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        guard !Self.trailingEnglishWord(in: before).isEmpty else { return }
        deleteTrailingWord(from: before)
        textDocumentProxy.insertText(candidate)
        suggestions.clear()
    }

    private func replaceTrailingConvertibleToken(with replacement: String, deleteCount: Int) {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        guard BilingualComposer.trailingConvertibleToken(in: before).count == deleteCount else {
            refreshSuggestionsAfterInput()
            return
        }
        deleteCharacters(deleteCount)
        textDocumentProxy.insertText(replacement)
        suggestions.clear()
    }

    private func deleteTrailingWord(from context: String) {
        let word = Self.trailingEnglishWord(in: context)
        deleteCharacters(word.count)
    }

    private func deleteCharacters(_ count: Int) {
        guard count > 0 else { return }
        for _ in 0 ..< count {
            textDocumentProxy.deleteBackward()
        }
    }

    private func topCorrectionForTrailingWord(in context: String) -> String? {
        let word = Self.trailingEnglishWord(in: context)
        guard !word.isEmpty else { return nil }
        let result = suggestionResult(for: word)
        guard !result.isTypedWordValid else { return nil }
        return result.topCorrection
    }

    private func japaneseSuggestionItems(beforeInput context: String) -> [SuggestionItem] {
        if cachedJapaneseSuggestionContext == context {
            return cachedJapaneseSuggestionItems
        }
        let items = bilingualComposer.suggestions(beforeInput: context).map {
            SuggestionItem(
                title: $0.replacementText,
                replacementText: $0.replacementText,
                deleteCount: $0.deleteCount,
                kind: .japanese
            )
        }
        cachedJapaneseSuggestionContext = context
        cachedJapaneseSuggestionItems = items
        return items
    }

    private struct SuggestionResult {
        let isTypedWordValid: Bool
        let topCorrection: String?
        let displayCandidates: [String]
    }

    private func suggestionResult(for word: String) -> SuggestionResult {
        let nsWord = word as NSString
        let range = NSRange(location: 0, length: nsWord.length)
        let bad = textChecker.rangeOfMisspelledWord(
            in: word,
            range: range,
            startingAt: 0,
            wrap: false,
            language: "en_US"
        )
        let inLexicon = userLexiconEntries.contains(word.lowercased())
        let isValid = bad.location == NSNotFound || inLexicon

        let completions = textChecker.completions(
            forPartialWordRange: range,
            in: word,
            language: "en_US"
        ) ?? []
        let guesses: [String]
        if !isValid {
            guesses = textChecker.guesses(forWordRange: bad, in: word, language: "en_US") ?? []
        } else {
            guesses = []
        }

        var seen: Set<String> = []
        var display: [String] = []
        for candidate in guesses + completions where !candidate.isEmpty {
            if seen.insert(candidate).inserted {
                display.append(candidate)
            }
            if display.count >= 8 { break }
        }

        let suppress = EnglishAutocorrectGate.shouldSuppressAutocorrectionForManualCapitalization(
            typed: word,
            hasManualCapitalization: hasManualCapitalization(for: word)
        )
        let top: String?
        if !isValid,
           !suppress,
           let candidate = guesses.first,
           EnglishAutocorrectGate.correctionPassesGate(typed: word, candidate: candidate) {
            top = candidate
        } else {
            top = nil
        }

        return SuggestionResult(
            isTypedWordValid: isValid,
            topCorrection: top,
            displayCandidates: display
        )
    }

    private func hasManualCapitalization(for word: String) -> Bool {
        guard word.contains(where: { $0.isUppercase }) else { return false }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let contextBeforeWord = String(before.dropLast(word.count))
        return !NativeKeyboardPolicy.shouldAutoCapitalize(
            after: contextBeforeWord,
            mode: currentTraits.autocapitalization,
            contentKind: currentTraits.contentKind
        )
    }

    private func shouldApplyDoubleSpacePeriod(beforeInput context: String) -> Bool {
        if let selected = textDocumentProxy.selectedText, !selected.isEmpty {
            return false
        }
        return NativeKeyboardPolicy.shouldApplyDoubleSpacePeriod(
            beforeInput: context,
            autocorrectionEnabled: currentTraits.autocorrectionEnabled,
            contentKind: currentTraits.contentKind
        )
    }

    private var currentTraits: TraitState {
        TraitState.read(from: textDocumentProxy)
    }

    private struct TraitState {
        let autocapitalization: NativeAutocapitalization
        let autocorrectionEnabled: Bool
        let contentKind: NativeKeyboardContentKind

        var allowsAutocorrection: Bool {
            NativeKeyboardPolicy.allowsAutocorrection(
                autocorrectionEnabled: autocorrectionEnabled,
                contentKind: contentKind
            )
        }

        @MainActor
        static func read(from proxy: UITextDocumentProxy) -> TraitState {
            let contentKind = Self.contentKind(
                keyboardType: proxy.keyboardType ?? .default,
                textContentType: proxy.textContentType
            )
            return TraitState(
                autocapitalization: Self.autocapitalization(proxy.autocapitalizationType ?? .sentences),
                autocorrectionEnabled: (proxy.autocorrectionType ?? .default) != .no,
                contentKind: contentKind
            )
        }

        private static func autocapitalization(_ type: UITextAutocapitalizationType) -> NativeAutocapitalization {
            switch type {
            case .none: return .none
            case .words: return .words
            case .sentences: return .sentences
            case .allCharacters: return .allCharacters
            @unknown default: return .sentences
            }
        }

        private static func contentKind(
            keyboardType: UIKeyboardType,
            textContentType: UITextContentType?
        ) -> NativeKeyboardContentKind {
            if textContentType == .URL { return .url }
            if textContentType == .emailAddress { return .email }

            switch keyboardType {
            case .URL:
                return .url
            case .emailAddress:
                return .email
            case .numberPad, .decimalPad, .numbersAndPunctuation, .asciiCapableNumberPad:
                return .numeric
            case .phonePad, .namePhonePad:
                return .phone
            case .webSearch:
                return .webSearch
            default:
                return .prose
            }
        }
    }

    private static func trailingEnglishWord(in text: String) -> String {
        var collected: [Character] = []
        for ch in text.reversed() {
            guard ch.isEnglishWordCharacter else { break }
            collected.append(ch)
        }
        return String(collected.reversed())
    }
}

private extension Character {
    var isEnglishWordCharacter: Bool {
        guard unicodeScalars.count == 1, let scalar = unicodeScalars.first else { return false }
        let value = scalar.value
        let isLetter = (65...90).contains(value) || (97...122).contains(value)
        return isLetter || self == "'" || self == "-"
    }
}
