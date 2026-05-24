import EnglishKeyboardCore
import KeyboardPreferences
import KeyboardKit
import UIKit

final class KeyboardViewController: KeyboardInputViewController {
    private let suggestions = EnglishSuggestionState()
    private let textChecker = UITextChecker()
    private var userLexiconEntries: Set<String> = []
    private let displayPreviewClassifier = BilingualLanguageClassifier(embeddedEnglishMinimumWordLength: 5)
    private let japaneseDetectionClassifier = BilingualLanguageClassifier()
    private let japaneseSuggestionWorker = JapaneseSuggestionWorker()
    private lazy var bilingualComposer = BilingualComposer(converter: AzooKeyJapaneseConverter())
    private var cachedJapaneseSuggestionContext: String?
    private var cachedJapaneseSuggestionMode: CompositionDisplayMode?
    private var cachedJapaneseSuggestionItems: [SuggestionItem] = []
    private var cachedKeepRawSuggestion: BilingualSuggestion?
    private var japaneseSuggestionTask: Task<Void, Never>?
    private var pendingJapaneseSuggestionContext: String?
    private var pendingJapaneseSuggestionMode: CompositionDisplayMode?
    private var rawConfirmedContext: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        suggestions.onSelect = { [weak self] item in
            self?.applySuggestion(item)
        }
        let completion: (UILexicon) -> Void = { [weak self] lexicon in
            Task { @MainActor in
                guard let self else { return }
                let entries = Set(lexicon.entries.flatMap {
                    [$0.documentText.lowercased(), $0.userInput.lowercased()]
                })
                self.userLexiconEntries = entries
                self.refreshSuggestionsAfterInput()
            }
        }
        requestSupplementaryLexicon(completion: completion)
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
                keyboardContext: controller.state.keyboardContext,
                suggestions: suggestions
            )
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshSuggestionsAfterInput()
    }

    func handleSpaceAction() {
        guard let proxy = activeTextDocumentProxy else { return }
        let before = proxy.documentContextBeforeInput ?? ""
        let displayMode = currentDisplayMode
        let canCommitBilingualConversion = allowsBilingualConversionCommit(
            beforeInput: before,
            displayMode: displayMode
        )

        if rawConfirmedContext == before {
            rawConfirmedContext = nil
            proxy.insertText(" ")
            refreshSuggestionsAfterInput()
            return
        }

        if displayMode.isJapaneseHeavy,
           canCommitBilingualConversion,
           proxy.selectedText?.isEmpty ?? true {
            if let cachedCommit = cachedJapaneseCommit(beforeInput: before, displayMode: displayMode) {
                commitSuggestionReplacement(cachedCommit, beforeInput: before, appendSpace: false)
                return
            }
            if let japaneseCommit = bilingualComposer.commitForSpace(beforeInput: before) {
                commitJapanese(japaneseCommit, appendSpace: false)
                return
            }
        }

        if shouldApplyDoubleSpacePeriod(beforeInput: before) {
            proxy.deleteBackward()
            proxy.insertText(". ")
            rawConfirmedContext = nil
            refreshSuggestionsAfterInput()
            return
        }

        if canCommitBilingualConversion,
           proxy.selectedText?.isEmpty ?? true {
            if let cachedCommit = cachedJapaneseCommit(beforeInput: before, displayMode: displayMode) {
                commitSuggestionReplacement(cachedCommit, beforeInput: before, appendSpace: true)
                return
            }
            if let japaneseCommit = bilingualComposer.commitForSpace(beforeInput: before) {
                commitJapanese(japaneseCommit, appendSpace: true)
                return
            }
        }

        if currentTraits.allowsAutocorrection,
           let topCorrection = topCorrectionForTrailingWord(in: before) {
            deleteTrailingWord(from: before)
            proxy.insertText(topCorrection)
        }

        proxy.insertText(" ")
        rawConfirmedContext = nil
        refreshSuggestionsAfterInput()
    }

    func handleReturnAction() -> Bool {
        guard let proxy = activeTextDocumentProxy else { return false }
        guard proxy.selectedText?.isEmpty ?? true else { return false }
        let before = proxy.documentContextBeforeInput ?? ""
        let displayMode = currentDisplayMode
        guard allowsBilingualConversionCommit(beforeInput: before, displayMode: displayMode) else {
            return false
        }
        if displayMode.isJapaneseHeavy {
            if let cachedCommit = cachedJapaneseCommit(beforeInput: before, displayMode: displayMode) {
                commitSuggestionReplacement(
                    cachedCommit,
                    beforeInput: before,
                    appendSpace: false,
                    rawDictionaryInsertsSpace: false
                )
                return true
            }
            guard let japaneseCommit = bilingualComposer.commitForSpace(beforeInput: before) else {
                return false
            }
            commitJapanese(
                japaneseCommit,
                appendSpace: false,
                rawDictionaryInsertsSpace: false
            )
            return true
        }
        guard let keepItem = keepRawSuggestion(beforeInput: before) else {
            return false
        }
        guard BilingualComposer.trailingConvertibleToken(in: before).count == keepItem.deleteCount else {
            refreshSuggestionsAfterInput()
            return true
        }
        confirmRawContext(before)
        return true
    }

    func handleLongVowelAction() {
        guard let proxy = activeTextDocumentProxy else { return }
        proxy.insertText("-")
        rawConfirmedContext = nil
        refreshSuggestionsAfterInput()
    }

    func refreshSuggestionsAfterInput() {
        let displayMode = currentDisplayMode
        guard let proxy = activeTextDocumentProxy else {
            cancelPendingJapaneseSuggestions()
            suggestions.update(displayMode: displayMode, previewTitle: nil, items: [])
            setKeepReturnKeyActive(false)
            rawConfirmedContext = nil
            return
        }
        let traits = currentTraits
        guard traits.allowsBilingualConversionSuggestions else {
            cancelPendingJapaneseSuggestions()
            suggestions.update(displayMode: displayMode, previewTitle: nil, items: [])
            setKeepReturnKeyActive(false)
            rawConfirmedContext = nil
            return
        }
        let before = proxy.documentContextBeforeInput ?? ""
        if rawConfirmedContext == before {
            cancelPendingJapaneseSuggestions()
            suggestions.update(displayMode: displayMode, previewTitle: nil, items: [])
            setKeepReturnKeyActive(false)
            return
        }
        rawConfirmedContext = nil
        if let selected = proxy.selectedText, !selected.isEmpty {
            cancelPendingJapaneseSuggestions()
            suggestions.update(displayMode: displayMode, previewTitle: nil, items: [])
            setKeepReturnKeyActive(false)
            return
        }

        let previewTitle = BilingualComposer.displayPreview(
            beforeInput: before,
            displayMode: displayMode,
            classifier: displayPreviewClassifier
        )
        let shouldRequestJapanese = shouldRequestJapaneseSuggestions(
            beforeInput: before,
            displayMode: displayMode,
            previewTitle: previewTitle
        )

        if shouldRequestJapanese,
           let cachedJapanese = cachedJapaneseSuggestionResult(beforeInput: before, displayMode: displayMode) {
            if !cachedJapanese.items.isEmpty {
                suggestions.update(displayMode: displayMode, previewTitle: previewTitle, items: cachedJapanese.items)
                setKeepReturnKeyActive(!displayMode.isJapaneseHeavy && cachedJapanese.keepRawSuggestion != nil)
                return
            }
        } else if shouldRequestJapanese {
            suggestions.update(displayMode: displayMode, previewTitle: previewTitle, items: [])
            setKeepReturnKeyActive(false)
            scheduleJapaneseSuggestions(beforeInput: before, displayMode: displayMode)
            return
        }

        cancelPendingJapaneseSuggestions()

        guard traits.allowsAutocorrection else {
            suggestions.update(displayMode: displayMode, previewTitle: previewTitle, items: [])
            setKeepReturnKeyActive(false)
            return
        }

        let word = Self.trailingEnglishWord(in: before)
        guard !word.isEmpty else {
            suggestions.update(displayMode: displayMode, previewTitle: previewTitle, items: [])
            setKeepReturnKeyActive(false)
            return
        }
        let items = suggestionResult(for: word).displayCandidates.map {
            SuggestionItem(
                title: $0,
                replacementText: $0,
                deleteCount: word.count,
                kind: .english
            )
        }
        suggestions.update(displayMode: displayMode, previewTitle: previewTitle, items: items)
        setKeepReturnKeyActive(false)
    }

    private func applySuggestion(_ item: SuggestionItem) {
        switch item.kind {
        case .dictionary:
            applyDictionarySuggestion(item)
        case .english:
            replaceTrailingWord(with: item.replacementText)
        case .keepRaw:
            confirmRawSuggestion(item)
        case .japanese:
            replaceTrailingConvertibleToken(with: item.replacementText, deleteCount: item.deleteCount)
        }
    }

    private func replaceTrailingWord(with candidate: String) {
        guard let proxy = activeTextDocumentProxy else { return }
        let before = proxy.documentContextBeforeInput ?? ""
        guard !Self.trailingEnglishWord(in: before).isEmpty else { return }
        deleteTrailingWord(from: before)
        proxy.insertText(candidate)
        cancelPendingJapaneseSuggestions()
        suggestions.clear()
        setKeepReturnKeyActive(false)
        rawConfirmedContext = nil
    }

    private func applyDictionarySuggestion(_ item: SuggestionItem) {
        guard let proxy = activeTextDocumentProxy else { return }
        let before = proxy.documentContextBeforeInput ?? ""
        let rawToken = BilingualComposer.trailingConvertibleToken(in: before)
        guard rawToken.count == item.deleteCount else {
            refreshSuggestionsAfterInput()
            return
        }
        if item.replacementText == rawToken {
            confirmRawContext(before)
        } else {
            replaceTrailingConvertibleToken(
                with: item.replacementText,
                deleteCount: item.deleteCount,
                recordConversion: true
            )
        }
    }

    private func replaceTrailingConvertibleToken(
        with replacement: String,
        deleteCount: Int,
        recordConversion: Bool = true
    ) {
        guard let proxy = activeTextDocumentProxy else { return }
        let before = proxy.documentContextBeforeInput ?? ""
        guard BilingualComposer.trailingConvertibleToken(in: before).count == deleteCount else {
            refreshSuggestionsAfterInput()
            return
        }
        deleteCharacters(deleteCount)
        proxy.insertText(replacement)
        if recordConversion {
            ConversionStats.shared.recordJapaneseConversion()
        }
        cancelPendingJapaneseSuggestions()
        suggestions.clear()
        setKeepReturnKeyActive(false)
        rawConfirmedContext = nil
    }

    private func commitJapanese(
        _ commit: BilingualCommit,
        appendSpace: Bool,
        rawDictionaryInsertsSpace: Bool = true
    ) {
        if commit.kind == .dictionary, commit.replacementText == commit.rawToken {
            commitRawDictionary(shouldInsertSpace: rawDictionaryInsertsSpace)
        } else {
            commitJapaneseReplacement(
                commit.replacementText,
                deleteCount: commit.deleteCount,
                appendSpace: appendSpace,
                recordConversion: true
            )
        }
    }

    private func commitSuggestionReplacement(
        _ item: SuggestionItem,
        beforeInput context: String,
        appendSpace: Bool,
        rawDictionaryInsertsSpace: Bool = true
    ) {
        let rawToken = BilingualComposer.trailingConvertibleToken(in: context)
        if item.kind == .dictionary, item.replacementText == rawToken {
            commitRawDictionary(shouldInsertSpace: rawDictionaryInsertsSpace, context: context)
        } else {
            commitJapaneseReplacement(
                item.replacementText,
                deleteCount: item.deleteCount,
                appendSpace: appendSpace,
                recordConversion: true
            )
        }
    }

    private func commitRawDictionary(shouldInsertSpace: Bool, context: String? = nil) {
        if !shouldInsertSpace {
            confirmRawContext(context ?? activeTextDocumentProxy?.documentContextBeforeInput ?? "")
            return
        }
        guard let proxy = activeTextDocumentProxy else { return }
        proxy.insertText(" ")
        cancelPendingJapaneseSuggestions()
        suggestions.clear()
        setKeepReturnKeyActive(false)
        rawConfirmedContext = nil
    }

    private func commitJapaneseReplacement(
        _ replacementText: String,
        deleteCount: Int,
        appendSpace: Bool,
        recordConversion: Bool
    ) {
        guard let proxy = activeTextDocumentProxy else { return }
        deleteCharacters(deleteCount)
        proxy.insertText(replacementText)
        if appendSpace {
            proxy.insertText(" ")
        }
        if recordConversion {
            ConversionStats.shared.recordJapaneseConversion()
        }
        cancelPendingJapaneseSuggestions()
        suggestions.clear()
        setKeepReturnKeyActive(false)
        rawConfirmedContext = nil
    }

    private func cachedJapaneseCommit(
        beforeInput context: String,
        displayMode: CompositionDisplayMode
    ) -> SuggestionItem? {
        guard cachedJapaneseSuggestionContext == context,
              cachedJapaneseSuggestionMode == displayMode,
              let item = cachedJapaneseSuggestionItems.first(where: { $0.kind == .dictionary || $0.kind == .japanese }) else {
            return nil
        }
        return item
    }

    private func confirmRawSuggestion(_ item: SuggestionItem) {
        guard let proxy = activeTextDocumentProxy else { return }
        let before = proxy.documentContextBeforeInput ?? ""
        guard BilingualComposer.trailingConvertibleToken(in: before).count == item.deleteCount else {
            refreshSuggestionsAfterInput()
            return
        }
        confirmRawContext(before)
    }

    private func confirmRawContext(_ context: String) {
        rawConfirmedContext = context
        cancelPendingJapaneseSuggestions()
        suggestions.clear()
        setKeepReturnKeyActive(false)
    }

    private func deleteTrailingWord(from context: String) {
        let word = Self.trailingEnglishWord(in: context)
        deleteCharacters(word.count)
    }

    private func deleteCharacters(_ count: Int) {
        guard let proxy = activeTextDocumentProxy else { return }
        guard count > 0 else { return }
        for _ in 0 ..< count {
            proxy.deleteBackward()
        }
    }

    private func topCorrectionForTrailingWord(in context: String) -> String? {
        let word = Self.trailingEnglishWord(in: context)
        guard !word.isEmpty else { return nil }
        let result = suggestionResult(for: word)
        guard !result.isTypedWordValid else { return nil }
        return result.topCorrection
    }

    private func cachedJapaneseSuggestionResult(
        beforeInput context: String,
        displayMode: CompositionDisplayMode
    ) -> (items: [SuggestionItem], keepRawSuggestion: BilingualSuggestion?)? {
        if cachedJapaneseSuggestionContext == context,
           cachedJapaneseSuggestionMode == displayMode {
            return (cachedJapaneseSuggestionItems, cachedKeepRawSuggestion)
        }
        return nil
    }

    private func japaneseSuggestionItems(beforeInput context: String) -> [SuggestionItem] {
        let displayMode = currentDisplayMode
        if cachedJapaneseSuggestionContext == context,
           cachedJapaneseSuggestionMode == displayMode {
            return cachedJapaneseSuggestionItems
        }
        let set = bilingualComposer.suggestionSet(beforeInput: context)
        var items = set.japanese.map {
            SuggestionItem(
                title: $0.replacementText,
                replacementText: $0.replacementText,
                deleteCount: $0.deleteCount,
                kind: $0.kind == .dictionary ? .dictionary : .japanese
            )
        }
        if displayMode.isJapaneseHeavy,
           let keepRaw = set.keepRaw,
           !items.isEmpty {
            items.insert(SuggestionItem(
                title: keepRaw.replacementText,
                replacementText: keepRaw.replacementText,
                deleteCount: keepRaw.deleteCount,
                kind: .keepRaw
            ), at: 0)
        }
        cachedJapaneseSuggestionContext = context
        cachedJapaneseSuggestionMode = displayMode
        cachedJapaneseSuggestionItems = items
        cachedKeepRawSuggestion = set.keepRaw
        return items
    }

    private func keepRawSuggestion(beforeInput context: String) -> BilingualSuggestion? {
        if cachedJapaneseSuggestionContext == context,
           cachedJapaneseSuggestionMode == currentDisplayMode {
            return cachedKeepRawSuggestion
        }
        _ = japaneseSuggestionItems(beforeInput: context)
        return cachedKeepRawSuggestion
    }

    private func shouldRequestJapaneseSuggestions(
        beforeInput context: String,
        displayMode: CompositionDisplayMode,
        previewTitle: String?
    ) -> Bool {
        if displayMode.isJapaneseHeavy, previewTitle != nil {
            return true
        }
        return BilingualComposer.containsJapaneseSpan(
            beforeInput: context,
            classifier: japaneseDetectionClassifier
        )
    }

    private func allowsBilingualConversionCommit(
        beforeInput context: String,
        displayMode: CompositionDisplayMode
    ) -> Bool {
        let traits = currentTraits
        guard traits.allowsBilingualConversionSuggestions else { return false }
        guard traits.contentKind == .url else { return true }

        let previewTitle = BilingualComposer.displayPreview(
            beforeInput: context,
            displayMode: displayMode,
            classifier: displayPreviewClassifier
        )
        return shouldRequestJapaneseSuggestions(
            beforeInput: context,
            displayMode: displayMode,
            previewTitle: previewTitle
        )
    }

    private func scheduleJapaneseSuggestions(
        beforeInput context: String,
        displayMode: CompositionDisplayMode
    ) {
        if pendingJapaneseSuggestionContext == context,
           pendingJapaneseSuggestionMode == displayMode {
            return
        }
        pendingJapaneseSuggestionContext = context
        pendingJapaneseSuggestionMode = displayMode
        japaneseSuggestionTask?.cancel()

        let worker = japaneseSuggestionWorker
        japaneseSuggestionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 25_000_000)
            guard !Task.isCancelled else { return }
            let result = await worker.suggestions(beforeInput: context, displayMode: displayMode)
            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return }
                self.applyJapaneseSuggestionResult(result)
            }
        }
    }

    private func applyJapaneseSuggestionResult(_ result: JapaneseSuggestionComputation) {
        pendingJapaneseSuggestionContext = nil
        pendingJapaneseSuggestionMode = nil
        guard let proxy = activeTextDocumentProxy,
              (proxy.documentContextBeforeInput ?? "") == result.context,
              currentDisplayMode == result.displayMode else {
            return
        }

        cachedJapaneseSuggestionContext = result.context
        cachedJapaneseSuggestionMode = result.displayMode
        cachedJapaneseSuggestionItems = result.items
        cachedKeepRawSuggestion = result.keepRawSuggestion

        let previewTitle = BilingualComposer.displayPreview(
            beforeInput: result.context,
            displayMode: result.displayMode,
            classifier: displayPreviewClassifier
        )
        suggestions.update(
            displayMode: result.displayMode,
            previewTitle: previewTitle,
            items: result.items
        )
        setKeepReturnKeyActive(
            !result.displayMode.isJapaneseHeavy &&
            result.keepRawSuggestion != nil &&
            !result.items.isEmpty
        )
    }

    private func cancelPendingJapaneseSuggestions() {
        pendingJapaneseSuggestionContext = nil
        pendingJapaneseSuggestionMode = nil
        japaneseSuggestionTask?.cancel()
        japaneseSuggestionTask = nil
    }

    private func setKeepReturnKeyActive(_ active: Bool) {
        state.keyboardContext.returnKeyTypeOverride = active ? .custom(title: "Keep") : nil
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
        let before = activeTextDocumentProxy?.documentContextBeforeInput ?? ""
        let contextBeforeWord = String(before.dropLast(word.count))
        return !NativeKeyboardPolicy.shouldAutoCapitalize(
            after: contextBeforeWord,
            mode: currentTraits.autocapitalization,
            contentKind: currentTraits.contentKind
        )
    }

    private func shouldApplyDoubleSpacePeriod(beforeInput context: String) -> Bool {
        if let selected = activeTextDocumentProxy?.selectedText, !selected.isEmpty {
            return false
        }
        return NativeKeyboardPolicy.shouldApplyDoubleSpacePeriod(
            beforeInput: context,
            autocorrectionEnabled: currentTraits.autocorrectionEnabled,
            contentKind: currentTraits.contentKind
        )
    }

    private var activeTextDocumentProxy: UITextDocumentProxy? {
        originalTextDocumentProxy
    }

    private var currentTraits: TraitState {
        TraitState.read(from: activeTextDocumentProxy)
    }

    private var currentDisplayMode: CompositionDisplayMode {
        KeyboardSettingsStore.readCompositionDisplayMode()
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

        var allowsBilingualConversionSuggestions: Bool {
            NativeKeyboardPolicy.allowsBilingualConversionSuggestions(contentKind: contentKind)
        }

        @MainActor
        static func read(from proxy: UITextDocumentProxy?) -> TraitState {
            let contentKind = Self.contentKind(
                keyboardType: proxy?.keyboardType ?? .default,
                textContentType: proxy?.textContentType
            )
            return TraitState(
                autocapitalization: Self.autocapitalization(proxy?.autocapitalizationType ?? .sentences),
                autocorrectionEnabled: (proxy?.autocorrectionType ?? .default) != .no,
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
